import AppIntents
import Consumers

struct WriteMemo: AppIntent {
    static let title: LocalizedStringResource = "Write an Entry"
    static let description = IntentDescription("Saves a private entry to Vesper.")

    @Parameter(title: "Entry", inputOptions: .init(multiline: true))
    var text: String

    @Dependency private var model: AppModel

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await Entries.create(content: text, visibility: .private, photos: [], located: false)
        model.invalidate()
        return .result(dialog: "Saved to Vesper.")
    }
}

struct VesperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WriteMemo(),
            phrases: ["Write in \(.applicationName)", "Add a memo to \(.applicationName)"],
            shortTitle: "Write an Entry",
            systemImageName: "square.and.pencil"
        )
    }
}
