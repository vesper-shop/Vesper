import SwiftUI

struct ProblemView: View {
    let problem: LoadProblem
    let page: String
    let retry: () async -> Void

    var body: some View {
        switch problem {
        case .signedOut:
            EmptyView()
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
