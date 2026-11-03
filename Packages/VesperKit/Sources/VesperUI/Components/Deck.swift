import SwiftUI

/// Cards that rest as a stack: closed, the first card shows in full with the edges of up to two
/// more peeking beneath it; open, every card is laid out. Toggling springs between the two.
public struct Deck<Data: RandomAccessCollection, Card: View>: View where Data.Element: Identifiable {
    let data: Data
    let open: Bool
    @ViewBuilder let card: (Data.Element) -> Card
    @Environment(\.accessibilityReduceMotion) private var still

    public init(_ data: Data, open: Bool, @ViewBuilder card: @escaping (Data.Element) -> Card) {
        self.data = data
        self.open = open
        self.card = card
    }

    public var body: some View {
        VStack(spacing: Theme.Space.lg) {
            if open {
                ForEach(data) { element in
                    card(element)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                }
            } else if let first = data.first {
                let behind = min(data.count - 1, 2)
                card(first)
                    .background(alignment: .bottom) {
                        ZStack(alignment: .bottom) {
                            ForEach((1...max(behind, 1)).reversed(), id: \.self) { depth in
                                if depth <= behind {
                                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                        .fill(Theme.background)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.border)
                                        }
                                        .shadow(color: Theme.shadow.opacity(0.04), radius: 8, y: 2)
                                        .frame(height: 48)
                                        .scaleEffect(x: 1 - CGFloat(depth) * 0.05, y: 1, anchor: .bottom)
                                        .offset(y: CGFloat(depth) * 9)
                                }
                            }
                        }
                    }
                    .padding(.bottom, CGFloat(behind) * 9)
            }
        }
        .animation(still ? nil : Theme.Motion.bouncy, value: open)
    }
}
