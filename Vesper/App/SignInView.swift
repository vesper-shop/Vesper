import AuthenticationServices
import Identity
import SwiftUI
import VesperUI

/// Consent and the passkey unlock live on noted-this.date, so signing in hands over to the
/// system web sheet and comes back with the authorization code.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.webAuthenticationSession) private var web
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.xs) {
                Image("Qiye")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                Text("Vesper").font(Theme.Font.headline)
            }
            Spacer()
            Text("Write the day.\nKeep the moment.")
                .font(Theme.Font.hero)
            Text("Memos, photos and the places they happened, sealed by your passkey.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.mutedForeground)
                .padding(.top, Theme.Space.md)
            Spacer()
            if let failure = model.failure {
                Text(failure)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.error)
                    .padding(.bottom, Theme.Space.sm)
            }
            Button { Task { await signIn() } } label: {
                ZStack {
                    Text("Continue with Vesper").opacity(working ? 0 : 1)
                    if working {
                        ProgressView().tint(Theme.background)
                    }
                }
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.foreground, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(working)
            Text("By continuing, you agree to the [Terms](https://noted-this.date/terms) and [Privacy Policy](https://noted-this.date/privacy).")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.mutedForeground)
                .tint(Theme.foreground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Space.sm)
        }
        .foregroundStyle(Theme.foreground)
        .frame(maxWidth: 480)
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func signIn() async {
        working = true
        defer { working = false }
        do {
            let authorization = try await Identity.shared.begin()
            let callback = try await web.authenticate(
                using: authorization.url,
                callbackURLScheme: Identity.callbackScheme,
                preferredBrowserSession: .shared
            )
            model.account = try await Identity.shared.complete(callback, authorization)
            model.failure = nil
        } catch ASWebAuthenticationSessionError.canceledLogin {
        } catch {
            model.failure = error.localizedDescription
        }
    }
}

#Preview {
    SignInView()
        .environment(AppModel())
}
