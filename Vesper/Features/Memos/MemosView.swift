import Consumers
import SwiftUI
import VesperUI

struct MemosView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Memo?
    @State private var composing = false
    @State private var deleting: Memo?
    @State private var searching = false
    @State private var toast: ToastMessage?

    var body: some View {
        @Bindable var session = model.memos
        let revision = model.revisions[.memos, default: 0]
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
                            SearchBar(text: $session.filters.search, prompt: "Search memos") {
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
                        .help("Search memos")
                        .disabled(searching)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Picker("Display", selection: $session.filters.display) {
                                ForEach(MemoDisplay.allCases) { display in
                                    Label(display.title, systemImage: display.symbol)
                                }
                            }
                        } label: {
                            Label("Display", systemImage: session.filters.display.symbol)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .help("Show all, public, favorite or archived memos")
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if session.problem != .signedOut {
                        Button { composing = true } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title2.weight(.semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("New Memo")
                        .help("New memo")
                        .padding(Theme.Space.lg)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(Theme.Motion.bouncy, value: session.problem)
                .refreshable {
                    await session.load()
                    await session.syncTags()
                }
                .task(id: MemosQuery(filters: session.filters, revision: revision)) {
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
                .sheet(isPresented: $composing) { MemoEditor(memo: nil) }
                .sheet(item: $editing) { MemoEditor(memo: $0) }
                .alert("Delete Memo?", isPresented: .constant(deleting != nil), presenting: deleting) { memo in
                    Button("Delete Memo", role: .destructive) {
                        deleting = nil
                        Task { await session.delete(memo) }
                    }
                    Button("Cancel", role: .cancel) { deleting = nil }
                } message: { _ in
                    Text("This permanently deletes the memo. It cannot be restored.")
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
    private func content(_ session: MemosSession) -> some View {
        let sections = session.sections
        if session.items.isEmpty {
            if let problem = session.problem {
                ProblemView(problem: problem, page: "Memos") { await session.load() }
            } else if session.loading {
                ScrollView {
                    VStack(spacing: Theme.Space.lg) {
                        MemoCard.Skeleton(lines: [0.96, 1, 0.62], tag: true)
                        MemoCard.Skeleton(lines: [0.84, 0.4], tag: false)
                        MemoCard.Skeleton(lines: [1, 0.92, 0.97, 0.5], tag: true)
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
            } else {
                EmptyState("No Memos", message: Text("Memos you write appear here."))
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                    if !sections.pinned.isEmpty {
                        PinnedHeader(count: sections.pinned.count, open: Bindable(session).pinnedOpen)
                            .padding(.leading, 2)
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
                        MemoCard.Skeleton(lines: [0.94, 0.58], tag: false)
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

    private func card(_ item: MemoItem, _ session: MemosSession) -> some View {
        MemoCard(item: item, busy: session.busy.contains(item.id)) { action in
            switch action {
            case .toggle(.archived):
                Task {
                    guard let updated = await session.toggle(.archived, of: item.memo) else { return }
                    toast = ToastMessage(updated.archived ? "Memo archived" : "Memo restored", action: ToastAction("Undo") {
                        Task {
                            await session.toggle(.archived, of: updated)
                            await session.load()
                        }
                    })
                }
            case .toggle(let flag): Task { await session.toggle(flag, of: item.memo) }
            case .edit: editing = item.memo
            case .delete: deleting = item.memo
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
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MemosView()
        .environment(AppModel())
}
