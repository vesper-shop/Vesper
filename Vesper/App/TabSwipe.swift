import SwiftUI
import VesperUI

struct TabSwipe: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 80, abs(dx) > abs(dy) * 2,
                          let tab = model.tab.neighbor(dx < 0 ? 1 : -1)
                    else { return }
                    withAnimation(Theme.Motion.gentle) { model.tab = tab }
                }
        )
    }
}

extension View {
    func tabSwipe() -> some View {
        modifier(TabSwipe())
    }
}
