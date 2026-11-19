import SwiftUI

struct EpisodeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let episode: Episode

    var body: some View {
        let metadataLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        VStack(alignment: .leading, spacing: 6) {
            Text(episode.name)
                .font(.headline)
            metadataLayout {
                Text(episode.code)
                    .font(.caption.monospaced().weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: .capsule)
                    .accessibilityLabel(episode.spokenCode)
                Text(episode.airedDateLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        EpisodeRow(episode: Episode(
            id: 1, name: "Pilot", airDate: Date(timeIntervalSince1970: 1_385_942_400),
            code: "S01E01", characterIDs: [1, 2]
        ))
    }
}
