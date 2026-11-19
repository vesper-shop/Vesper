import Consumers
import Identity
import SwiftUI
import VesperUI

struct SettingsView: View {
    @State private var cached = URLCache.shared.currentDiskUsage

    var body: some View {
        NavigationStack {
            Form {
                AccountSection()
                Section {
                    LabeledContent("Image Cache") {
                        Text(Int64(cached), format: .byteCount(style: .file))
                            .monospacedDigit()
                    }
                    Button("Clear Image Cache", role: .destructive) {
                        URLCache.shared.removeAllCachedResponses()
                        cached = URLCache.shared.currentDiskUsage
                    }
                    .foregroundStyle(Theme.error)
                    .disabled(cached == 0)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Photos are kept on this device so they open instantly; they download again when needed.")
                }
                Section("About") {
                    LabeledContent("Version") {
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
                    }
                    Link(destination: Identity.origin) {
                        Label(Identity.origin.host()!, systemImage: "safari")
                    }
                }
            }
            .formStyle(.grouped)
            .symmetricInsets()
            .tabSwipe()
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { cached = URLCache.shared.currentDiskUsage }
        }
    }
}

private struct AccountSection: View {
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var error: String?

    var body: some View {
        Section {
            if let account = model.account {
                HStack(spacing: Theme.Space.md) {
                    AsyncImage(url: account.picture, transaction: .init(animation: Theme.Motion.gentle)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Theme.muted
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(Theme.border) }
                    VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                        Text(account.name).font(Theme.Font.title)
                        Text(account.handle)
                            .font(Theme.Font.detail)
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }
                .padding(.vertical, Theme.Space.xs)
            }
            Button("Sign Out", role: .destructive) { Task { await signOut() } }
                .foregroundStyle(Theme.error)
            if let error {
                Text(error).foregroundStyle(Theme.error)
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Signed in with your Vesper passkey; widgets and Siri use the same account.")
        }
        .disabled(working)
        .task {
            do {
                model.account = try await Identity.shared.account()
            } catch IdentityError.signedOut {
                model.failure = IdentityError.expired.localizedDescription
                model.signedOut()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func signOut() async {
        working = true
        defer { working = false }
        do {
            try await Identity.shared.signOut()
        } catch {
            model.failure = error.localizedDescription
        }
        withAnimation(Theme.Motion.gentle) { model.signedOut() }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
