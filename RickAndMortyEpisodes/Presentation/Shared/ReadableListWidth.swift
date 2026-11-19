import SwiftUI

/// Keeps a list's rows at a readable width on wide screens, such as an iPad in landscape. The list
/// itself stays full width, so its background and scroll bar still reach the screen edges; only
/// the content is inset. On an iPhone the margin is zero and nothing changes.
private struct ReadableListWidth: ViewModifier {
    /// Grows with Dynamic Type, so larger text gets a wider column.
    @ScaledMetric(relativeTo: .body) private var maxWidth: CGFloat = 640
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .contentMargins(.horizontal, max(0, (width - maxWidth) / 2), for: .scrollContent)
    }
}

extension View {
    func readableListWidth() -> some View {
        modifier(ReadableListWidth())
    }
}
