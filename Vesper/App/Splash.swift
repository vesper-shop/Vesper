import SwiftUI
import VesperUI

struct Splash: View {
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var gathered = false

    var body: some View {
        Theme.background
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: Theme.Space.md) {
                    Text("Vesper")
                        .font(Theme.Font.display)
                        .tracking(gathered ? 4 : 14)
                        .foregroundStyle(Theme.foreground)
                        .opacity(gathered ? 1 : 0)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(height: 2)
                        .phaseAnimator(still ? [true] : [false, true]) { line, wide in
                            line.frame(width: wide ? 40 : 12).opacity(wide ? 1 : 0.4)
                        } animation: { _ in
                            .easeInOut(duration: 0.9)
                        }
                        .opacity(gathered ? 1 : 0)
                }
            }
            .onAppear {
                withAnimation(still ? nil : .smooth(duration: 0.8)) { gathered = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    Splash()
}
