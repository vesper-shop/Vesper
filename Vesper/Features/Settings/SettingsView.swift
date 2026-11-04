import AuthenticationServices
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
                    Text("Moment photos are kept on this device so they open instantly; they download again when needed.")
                }
                Section("About") {
                    LabeledContent("Version") {
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
                    }
                    ForEach(ConsumerAPI.allCases) { api in
                        Link(destination: api.baseURL) {
                            Label(api.baseURL.host()!, systemImage: "safari")
                        }
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
    @Environment(\.webAuthenticationSession) private var web
    @State private var account: Account?
    /// False until the Keychain has been read, so a signed-in account never flashes Sign In.
    @State private var read = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        Section {
            if !read {
                HStack(spacing: Theme.Space.md) {
                    Circle().fill(Theme.skeleton).frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Bone(width: 120, height: 16)
                        Bone(width: 180, height: 11)
                    }
                }
                .shimmer()
                .padding(.vertical, Theme.Space.xs)
            } else if let account {
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
                        Text(account.email)
                            .font(Theme.Font.detail)
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }
                .padding(.vertical, Theme.Space.xs)
                Button("Sign Out", role: .destructive) { Task { await signOut() } }
                    .foregroundStyle(Theme.error)
            } else {
                Button { Task { await signIn() } } label: {
                    Label("Sign in with you-find.me", systemImage: "person.crop.circle")
                        .foregroundStyle(Theme.accent)
                }
            }
            if let error {
                Text(error).foregroundStyle(Theme.error)
            }
        } header: {
            Text("Account")
        } footer: {
            Text("One you-find.me sign-in opens Memos, Moment and Knowledge.")
        }
        .disabled(working)
        .task {
            do {
                account = try await Identity.shared.account()
            } catch {
                self.error = error.localizedDescription
            }
            withAnimation(Theme.Motion.quick) { read = true }
        }
    }

    private func signIn() async {
        working = true
        defer { working = false }
        let authorization = Identity.shared.begin()
        do {
            let callback = try await web.authenticate(
                using: authorization.url,
                callbackURLScheme: Identity.callbackScheme,
                preferredBrowserSession: .shared
            )
            account = try await Identity.shared.complete(callback, authorization)
            error = nil
            ConsumerAPI.allCases.forEach(model.invalidate)
        } catch ASWebAuthenticationSessionError.canceledLogin {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func signOut() async {
        working = true
        defer { working = false }
        do {
            try await Identity.shared.signOut()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        account = nil
        model.signedOut()
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
