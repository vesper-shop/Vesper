import SwiftUI
import VesperUI

struct EmptyState<Actions: View>: View {
    let title: LocalizedStringKey
    let message: Text
    @ViewBuilder let actions: Actions

    init(_ title: LocalizedStringKey, message: Text, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: Theme.Space.md) {
                Image("Qiye")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112)
                    .accessibilityHidden(true)
                Text(title).font(Theme.Font.title)
            }
        } description: {
            message.font(Theme.Font.detail)
        } actions: {
            actions
        }
    }
}
