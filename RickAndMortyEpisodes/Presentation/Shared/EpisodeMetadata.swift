import SwiftUI

struct EpisodeMetadata: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let episode: Episode

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text(episode.code)
                .font(.caption.monospaced().weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.12), in: .capsule)
            Text(episode.airedDateLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
