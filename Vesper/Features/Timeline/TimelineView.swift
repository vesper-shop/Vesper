import Consumers
import SwiftUI
import VesperUI

struct TimelineView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var editing: Entry?
    @State private var deleting: Entry?
    @State private var searching = false
    @State private var toast: ToastMessage?

    var body: some View {
        @Bindable var session = model.timeline
        let revision = model.revision
        NavigationStack {
            content(session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .symmetricInsets()
                .background(Theme.background)
                .navigationTitle(session.filters.display.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .safeAreaBar(edge: .top) {
                    VStack(spacing: 0) {
                        if searching {
                            SearchBar(text: $session.filters.search, prompt: "Search entries") {
                                withAnimation(Theme.Motion.quick) {
                                    session.filters.search = ""
                                    searching = false
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        if !session.tags.isEmpty {
                            TagBar(tags: session.tags.map { .init(name: $0.name, count: $0.count) }, selection: $session.filters.tag)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(Theme.Motion.quick) { searching = true }
                        } label: {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        .help("Search entries")
                        .keyboardShortcut("f")
                        .disabled(searching)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Picker("Display", selection: $session.filters.display) {
                                ForEach(EntryDisplay.allCases) { display in
                                    Label(display.title, systemImage: display.symbol)
                                }
                            }
                        } label: {
                            Label("Display", systemImage: session.filters.display.symbol)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .help("Show all, public, favorite or archived entries")
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if session.problem != .signedOut {
                        Button { model.compose = Compose(camera: false) } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title2.weight(.semibold))
                                .symbolEffect(.bounce, value: model.compose != nil)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .sensoryFeedback(.impact(weight: .light), trigger: model.compose != nil) { _, new in new }
                        .keyboardShortcut("n")
                        .accessibilityLabel("New Entry")
                        .help("New entry")
                        .padding(Theme.Space.lg)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(Theme.Motion.bouncy, value: session.problem)
                .refreshable {
                    await session.load()
                    await session.syncTags()
                }
                .task(id: TimelineQuery(filters: session.filters, revision: revision)) {
                    // Restarting on each keystroke debounces search.
                    if !session.filters.search.isEmpty {
                        do {
                            try await Task.sleep(for: .milliseconds(350))
                        } catch {
                            return
                        }
                    }
                    await session.load()
                }
                .task(id: revision) { await session.syncTags() }
                .sheet(item: $editing) { EntryEditor(entry: $0, camera: false) }
                .photoStacks(zoom)
                .alert("Delete Entry?", isPresented: .constant(deleting != nil), presenting: deleting) { entry in
                    Button("Delete Entry", role: .destructive) {
                        deleting = nil
                        Task { await session.delete(entry) }
                    }
                    Button("Cancel", role: .cancel) { deleting = nil }
                } message: { _ in
                    Text("This permanently deletes the entry and its photos. It cannot be restored.")
                }
                .onChange(of: session.notice) {
                    guard let notice = session.notice else { return }
                    toast = ToastMessage(notice)
                    session.notice = nil
                }
                .toast($toast)
                // Only an archive raises a toast with Undo.
                .sensoryFeedback(trigger: toast) { _, new in new?.action == nil ? nil : .success }
        }
    }

    @ViewBuilder
    private func content(_ session: TimelineSession) -> some View {
        let sections = session.sections
        if session.items.isEmpty {
            if let problem = session.problem {
                ProblemView(problem: problem, page: "Timeline") { await session.load() }
            } else if session.loading {
                ScrollView {
                    VStack(spacing: Theme.Space.lg) {
                        EntryCard.Skeleton(lines: [0.96, 1, 0.62], tag: true)
                        EntryCard.Skeleton(lines: [0.84, 0.4], tag: false)
                        EntryCard.Skeleton(lines: [1, 0.92, 0.97, 0.5], tag: true)
                    }
                    .mask {
                        LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                    }
                    .frame(maxWidth: Theme.readable)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.sm)
                    .frame(maxWidth: .infinity)
                }
                .scrollDisabled(true)
                .transition(.opacity)
            } else if !session.filters.search.isEmpty {
                ContentUnavailableView.search(text: session.filters.search)
            } else if let tag = session.filters.tag {
                EmptyState("Nothing Here", message: Text("Nothing in \(session.filters.display.title) is tagged #\(tag)."))
            } else {
                let blank = session.filters.display.blank
                EmptyState(blank.title, message: Text(blank.message))
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                    if !sections.pinned.isEmpty {
                        PinnedHeader(count: sections.pinned.count, open: Bindable(session).pinnedOpen)
                        Deck(sections.pinned, open: session.pinnedOpen) { card($0, session) }
                            .padding(.bottom, Theme.Space.xs)
                    }
                    ForEach(sections.timeline) { item in
                        card(item, session)
                            .scrollDepth()
                            .onAppear {
                                if item.id == sections.timeline.last?.id {
                                    Task { await session.paginate() }
                                }
                            }
                    }
                    if session.paginating {
                        EntryCard.Skeleton(lines: [0.94, 0.58], tag: false)
                    }
                }
                .frame(maxWidth: Theme.readable)
                .padding(.horizontal, Theme.Space.lg)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, Theme.Space.tail)
                .frame(maxWidth: .infinity)
                .animation(Theme.Motion.gentle, value: sections.timeline.map(\.id))
            }
            .scrollDismissesKeyboard(.immediately)
            .backToTop()
            .tabSwipe()
        }
    }

    private func card(_ item: EntryItem, _ session: TimelineSession) -> some View {
        EntryCard(item: item, busy: session.busy.contains(item.id), zoom: zoom) { action in
            switch action {
            case .toggle(.archived):
                Task {
                    guard let updated = await session.toggle(.archived, of: item.entry) else { return }
                    toast = ToastMessage(updated.archived ? "Entry archived" : "Entry restored", action: ToastAction("Undo") {
                        Task {
                            await session.toggle(.archived, of: updated)
                            await session.load()
                        }
                    })
                }
            case .toggle(let flag): Task { await session.toggle(flag, of: item.entry) }
            case .edit: editing = item.entry
            case .delete: deleting = item.entry
            case .filter(let tag): withAnimation(Theme.Motion.gentle) { session.filters.tag = tag }
            }
        }
    }
}

private struct PinnedHeader: View {
    let count: Int
    @Binding var open: Bool

    var body: some View {
        Button {
            withAnimation(Theme.Motion.bouncy) { open.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(open ? 90 : 0))
                Text("pinned").font(Theme.Font.monoCaption)
                Text("\(count) \(count == 1 ? "entry" : "entries")")
            }
            .font(Theme.Font.meta)
            .foregroundStyle(Theme.mutedForeground)
            .padding(.horizontal, Theme.Space.sm)
            .padding(.vertical, 6)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

#Preview {
    TimelineView()
        .environment(AppModel())
}
