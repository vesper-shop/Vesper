import SwiftUI
import WidgetKit

@main
struct VesperWidgets: WidgetBundle {
    var body: some Widget {
        OnThisDay()
        Heatmap()
        WriteControl()
        ShootControl()
    }
}
