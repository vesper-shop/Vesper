import Consumers
import CoreLocation
import MapKit
import os
import PhotosUI
import SwiftUI
import VesperUI

/// Laid out as a social post is written: words first, one photo in its square, then rows for
/// where and when it was taken and its tags.
struct PhotoComposer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var photo: ComposedPhoto?
    @State private var place: String?
    @State private var item: PhotosPickerItem?
    @State private var picking = false
    @State private var shooting = false
    @State private var choosing = false
    @State private var title = ""
    @State private var description = ""
    @State private var tags = ""
    @State private var located = true
    @State private var posting = false
    @State private var posted = false
    @State private var error: String?
    @State private var discarding = false
    @FocusState private var focused: Bool
    private let log = Logger(subsystem: "me.youfind.vesper", category: "moment")

    private var edited: Bool {
        photo != nil || !title.isEmpty || !description.isEmpty || !tags.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $title)
                        .focused($focused)
                        .font(Theme.Font.display)
                    TextField("Say something about this moment…", text: $description, axis: .vertical)
                        .focused($focused)
                        .font(Theme.Font.body)
                        .lineLimit(4...12)
                        .padding(.top, 10)

                    Button { choosing = true } label: {
                        Group {
                            if let photo {
                                Image(decorative: photo.preview, scale: 1)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 34, weight: .light))
                                    .foregroundStyle(Theme.mutedForeground)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Theme.muted)
                            }
                        }
                        .frame(width: 112, height: 112)
                        .clipShape(.rect(cornerRadius: Theme.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        if photo != nil {
                            Button { photo = nil } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.onDark)
                                    .frame(width: 22, height: 22)
                                    .background(Theme.scrim, in: .circle)
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                            .accessibilityLabel("Remove Photo")
                        }
                    }
                    .confirmationDialog("Add Photo", isPresented: $choosing) {
                        #if os(iOS)
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Take Photo") { shooting = true }
                        }
                        #endif
                        Button("Choose from Library") { picking = true }
                    }
                    .padding(.top, 20)

                    VStack(spacing: 0) {
                        Divider().overlay(Theme.divider)
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse").frame(width: 22)
                            Text("Location").foregroundStyle(Theme.foreground)
                            Spacer()
                            if let geo = photo?.metadata.geo {
                                Text([place, String(format: "%.4f, %.4f", geo.lat, geo.lng)].compactMap { $0 }.joined(separator: " · "))
                                    .lineLimit(1)
                                Toggle("Include location", isOn: $located)
                                    .labelsHidden()
                            } else {
                                Text(photo == nil ? "From the photo" : "None in this photo")
                            }
                        }
                        .padding(.vertical, 14)
                        Divider().overlay(Theme.divider)
                        HStack(spacing: 12) {
                            Image(systemName: "clock").frame(width: 22)
                            Text("Taken").foregroundStyle(Theme.foreground)
                            Spacer()
                            if let captured = photo?.metadata.captured {
                                Text(captured.prefix(16).replacingOccurrences(of: "T", with: " "))
                                    .monospacedDigit()
                            } else {
                                Text(photo == nil ? "From the photo" : "Not recorded")
                            }
                        }
                        .padding(.vertical, 14)
                        Divider().overlay(Theme.divider)
                        HStack(spacing: 12) {
                            Image(systemName: "number").frame(width: 22)
                            Text("Tags").foregroundStyle(Theme.foreground)
                            TextField("travel scotland", text: $tags)
                                .focused($focused)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                        }
                        .padding(.vertical, 14)
                        Divider().overlay(Theme.divider)
                    }
                    .font(Theme.Font.meta.weight(.medium))
                    .foregroundStyle(Theme.mutedForeground)
                    .tint(Theme.accent)
                    .padding(.top, 28)
                }
                .frame(maxWidth: Theme.readable)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("New Moment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if edited { discarding = true } else { dismiss() }
                    }
                    .confirmationDialog("Discard this moment?", isPresented: $discarding, titleVisibility: .visible) {
                        Button("Discard Moment", role: .destructive) { dismiss() }
                        Button("Keep Editing", role: .cancel) {}
                    }
                        .disabled(posting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if posting {
                        ProgressView()
                    } else {
                        Button("Post") { Task { await post() } }
                            .buttonStyle(.glassProminent)
                            .disabled(photo == nil || title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                #if os(iOS)
                ToolbarSpacer(.flexible, placement: .keyboard)
                ToolbarItem(placement: .keyboard) {
                    Button("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down") { focused = false }
                }
                #endif
            }
            .photosPicker(isPresented: $picking, selection: $item, matching: .images)
            .onChange(of: item) {
                guard let item else { return }
                self.item = nil
                Task {
                    do {
                        guard let source = try await item.loadTransferable(type: Data.self) else {
                            throw CocoaError(.fileReadUnknown)
                        }
                        photo = try ComposedPhoto(source)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            .task(id: photo?.metadata.geo) {
                place = nil
                guard let geo = photo?.metadata.geo else { return }
                do {
                    let items = try await MKReverseGeocodingRequest(location: CLLocation(latitude: geo.lat, longitude: geo.lng))!.mapItems
                    place = items.first?.addressRepresentations?.cityWithContext
                } catch {
                    log.error("Reverse geocoding the new photo failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $shooting) {
                Camera { source in
                    do {
                        photo = try ComposedPhoto(source)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .ignoresSafeArea()
            }
            #endif
            .alert("Couldn't Post", isPresented: .constant(error != nil), presenting: error) { _ in
                Button("OK") { error = nil }
            } message: { error in
                Text(error)
            }
        }
        .interactiveDismissDisabled(posting || edited)
        .sensoryFeedback(.success, trigger: posted)
    }

    private func post() async {
        guard let photo else { return }
        let words = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = tags.split(whereSeparator: { $0 == " " || $0 == "," })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
            .filter { !$0.isEmpty }
        posting = true
        defer { posting = false }
        do {
            try await model.moment.publish(photo.source, input: PhotoInput(
                title: title,
                description: words.isEmpty ? nil : words,
                tags: parsed,
                date: photo.metadata.captured,
                geo: located ? photo.metadata.geo : nil
            ))
            model.invalidate(.moment)
            posted = true
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    PhotoComposer()
        .environment(AppModel())
}
