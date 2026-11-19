import SwiftUI
import VesperUI

struct EmptyState: View {
    let title: LocalizedStringKey
    let message: Text

    init(_ title: LocalizedStringKey, message: Text) {
        self.title = title
        self.message = message
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: Theme.Space.md) {
                Image("Qiye")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96)
                    .padding(Theme.Space.md)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityHidden(true)
                Text(title).font(Theme.Font.title)
            }
        } description: {
            message.font(Theme.Font.detail)
        }
    }
}
