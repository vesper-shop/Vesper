import SwiftUI

struct ProblemView: View {
    let problem: LoadProblem
    let page: String
    let retry: () async -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        switch problem {
        case .signedOut:
            EmptyState("Sign In to See \(page)", message: Text("Sign in with your you-find.me account in Settings.")) {
                Button("Open Settings") { model.tab = .settings }
                    .buttonStyle(.glassProminent)
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load \(page)", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await retry() } }
                    .buttonStyle(.glass)
            }
        }
    }
}
