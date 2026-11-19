import AuthenticationServices
import Identity
import SwiftUI
import VesperUI

/// Consent and the passkey unlock live on noted-this.date, so signing in hands over to the
/// system web sheet and comes back with the authorization code.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.webAuthenticationSession) private var web
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var working = false
    @State private var shown = false
    @State private var signedIn = false

    var body: some View {
        VStack(spacing: 0) {
            Showcase(shown: shown)
                .frame(maxHeight: .infinity)

            VStack(spacing: Theme.Space.sm) {
                Text("Vesper")
                    .font(Theme.Font.hero)
                Text("Memos, photos and the places they happened, sealed by your passkey.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown || still ? 0 : 16)
            .animation(still ? nil : Theme.Motion.gentle.delay(0.35), value: shown)
            .padding(.bottom, Theme.Space.xl)

            if let failure = model.failure {
                Button {
                    withAnimation(Theme.Motion.quick) { model.failure = nil }
                } label: {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.Font.meta.weight(.medium))
                        .foregroundStyle(Theme.error)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .accessibilityHint("Dismisses the message")
                .padding(.bottom, Theme.Space.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button { Task { await signIn() } } label: {
                HStack(spacing: Theme.Space.xs) {
                    if working {
                        ProgressView().tint(Theme.background)
                    } else {
                        Image(systemName: "person.badge.key.fill")
                    }
                    Text(working ? "Waiting for Vesper…" : "Continue with Vesper")
                        .contentTransition(.opacity)
                }
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity, minHeight: 56)
                // Not tinted glass: the system drops the tint while the window is inactive.
                .background(Theme.foreground, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.press)
            .disabled(working)
            .opacity(shown ? 1 : 0)
            .animation(still ? nil : Theme.Motion.gentle.delay(0.5), value: shown)

            Text(try! AttributedString(markdown: "By continuing, you agree to the [Terms](\(Identity.origin.appending(path: "terms"))) and [Privacy Policy](\(Identity.origin.appending(path: "privacy")))."))
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
        .background { Backdrop() }
        .animation(Theme.Motion.bouncy, value: model.failure)
        .animation(Theme.Motion.quick, value: working)
        .sensoryFeedback(.error, trigger: model.failure) { _, new in new != nil }
        .sensoryFeedback(.success, trigger: signedIn)
        .onAppear { shown = true }
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
            let account = try await Identity.shared.complete(callback, authorization)
            model.failure = nil
            signedIn = true
            withAnimation(Theme.Motion.gentle) { model.account = account }
        } catch ASWebAuthenticationSessionError.canceledLogin {
        } catch {
            model.failure = error.localizedDescription
        }
    }
}

private struct Showcase: View {
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var start = Date.now

    var body: some View {
        SwiftUI.TimelineView(.animation(paused: still)) { context in
            let t = context.date.timeIntervalSince(start)
            let pulse = still ? 0.5 : t.truncatingRemainder(dividingBy: 2) / 2
            ZStack {
                Canvas { context, size in
                    var roads = Path()
                    roads.move(to: CGPoint(x: 0, y: size.height * 0.7))
                    roads.addCurve(to: CGPoint(x: size.width, y: size.height * 0.3), control1: CGPoint(x: size.width * 0.4, y: size.height * 0.9), control2: CGPoint(x: size.width * 0.6, y: 0))
                    roads.move(to: CGPoint(x: size.width * 0.3, y: 0))
                    roads.addLine(to: CGPoint(x: size.width * 0.45, y: size.height))
                    context.stroke(roads, with: .color(Theme.foreground.opacity(0.14)), lineWidth: 5)
                }
                .overlay {
                    ZStack {
                        Circle()
                            .stroke(Theme.accent, lineWidth: 2)
                            .frame(width: 34, height: 34)
                            .scaleEffect(0.4 + pulse)
                            .opacity(1 - pulse)
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 12, height: 12)
                            .overlay { Circle().strokeBorder(Theme.onDark, lineWidth: 2) }
                    }
                    .offset(x: 18, y: -6)
                }
                .overlay(alignment: .bottomLeading) {
                    Label("Atlas", systemImage: "map")
                        .font(Theme.Font.caption.weight(.semibold))
                        .foregroundStyle(Theme.mutedForeground)
                        .padding(12)
                }
                .frame(width: 168, height: 112)
                .modifier(Pane(radius: 22))
                    .rotationEffect(.degrees(-4))
                    .offset(x: -58, y: 124 + 5 * sin(t * 0.8 + 4))
                    .modifier(Arrival(shown: shown, order: 2))
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    LinearGradient(colors: [Theme.accent.opacity(0.85), Theme.lilac], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(alignment: .bottom) {
                            Circle()
                                .fill(Theme.onDark.opacity(0.75))
                                .frame(width: 34)
                                .offset(y: -30)
                        }
                        .overlay(alignment: .bottom) {
                            Theme.foreground.opacity(0.35).frame(height: 30)
                        }
                        .frame(height: 120)
                        .clipShape(.rect(cornerRadius: 14))
                    Label("Keep the moment.", systemImage: "mappin")
                        .font(Theme.Font.caption.weight(.semibold))
                        .padding(.horizontal, 2)
                }
                .padding(10)
                .frame(width: 144)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Pane(radius: 24))
                    .rotationEffect(.degrees(6))
                    .offset(x: 74, y: 16 + 6 * sin(t * 0.7 + 2))
                    .modifier(Arrival(shown: shown, order: 1))
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    HStack(spacing: 6) {
                        Image("Qiye")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .background(Theme.lilac.opacity(0.5), in: .circle)
                        Text("Today")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.mutedForeground)
                    }
                    Text("Write the day.")
                        .font(Theme.Font.headline)
                    Capsule()
                        .fill(Theme.foreground.opacity(0.12))
                        .frame(width: 112, height: 6)
                    Text("#journal")
                        .font(Theme.Font.caption.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
                .padding(14)
                .frame(width: 168, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Pane(radius: 22))
                    .rotationEffect(.degrees(-6))
                    .offset(x: -56, y: -118 + 5 * sin(t * 0.9))
                    .modifier(Arrival(shown: shown, order: 0))
            }
        }
        .frame(width: 320, height: 400)
        .accessibilityHidden(true)
    }
}

/// A material, not Liquid Glass: glass under a rotation renders at the wrong size.
private struct Pane: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Theme.onDark.opacity(0.7), Theme.onDark.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            }
            .shadow(color: Theme.shadow.opacity(0.12), radius: 18, y: 10)
    }
}

private struct Arrival: ViewModifier {
    let shown: Bool
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var still

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || still ? 1 : 0.85)
            .offset(y: shown || still ? 0 : 48)
            .opacity(shown ? 1 : 0)
            .animation(still ? .easeOut(duration: 0.3) : .spring(duration: 0.8, bounce: 0.3).delay(0.12 * Double(order)), value: shown)
    }
}

#Preview {
    SignInView()
        .environment(AppModel())
}
