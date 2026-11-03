import SwiftUI

/// A staggered grid: each element goes to the currently shortest lane, sized by its aspect ratio.
/// Lanes are lazy stacks, so long photo streams only build visible cells.
public struct Masonry<Data: RandomAccessCollection, Cell: View>: View where Data.Element: Identifiable {
    let data: Data
    let lanes: Int
    let spacing: CGFloat
    /// Width divided by height.
    let ratio: (Data.Element) -> Double
    @ViewBuilder let cell: (Data.Element) -> Cell

    public init(
        _ data: Data,
        lanes: Int,
        spacing: CGFloat = 8,
        ratio: @escaping (Data.Element) -> Double,
        @ViewBuilder cell: @escaping (Data.Element) -> Cell
    ) {
        self.data = data
        self.lanes = lanes
        self.spacing = spacing
        self.ratio = ratio
        self.cell = cell
    }

    public var body: some View {
        var columns = Array(repeating: [Data.Element](), count: lanes)
        var heights = Array(repeating: 0.0, count: lanes)
        for element in data {
            let shortest = heights.indices.min { heights[$0] < heights[$1] }!
            columns[shortest].append(element)
            heights[shortest] += 1 / ratio(element)
        }
        return HStack(alignment: .top, spacing: spacing) {
            ForEach(columns.indices, id: \.self) { lane in
                LazyVStack(spacing: spacing) {
                    ForEach(columns[lane]) { element in
                        cell(element)
                            .aspectRatio(ratio(element), contentMode: .fit)
                    }
                }
                // Equal lanes: a lazy stack is otherwise only as wide as its cells ask.
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}
