import AppIntents
import SwiftUI
import VesperUI
import WidgetKit

struct WriteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "me.youfind.vesper.write") {
            ControlWidgetButton(action: OpenURLIntent(Route.write.url)) {
                Label("Write an Entry", systemImage: "square.and.pencil")
            }
        }
        .displayName("Write an Entry")
        .description("Opens a new entry in Vesper.")
    }
}

struct ShootControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "me.youfind.vesper.shoot") {
            ControlWidgetButton(action: OpenURLIntent(Route.shoot.url)) {
                Label("Take a Photo", systemImage: "camera")
            }
        }
        .displayName("Take a Photo")
        .description("Opens the camera for a new entry in Vesper.")
    }
}
