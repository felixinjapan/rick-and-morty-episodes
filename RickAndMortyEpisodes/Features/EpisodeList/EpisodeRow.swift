import SwiftUI

struct EpisodeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let episode: Episode

    /// At accessibility text sizes the code and date stack vertically instead of crowding one line.
    private var detailLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.name)
                .font(.headline)
            detailLayout {
                Text(episode.code)
                    .font(.caption.monospaced().weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: .rect(cornerRadius: 4))
                Text(episode.formattedAirDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        EpisodeRow(episode: Episode(id: 1, name: "Pilot", airDate: "December 2, 2013", code: "S01E01", characterIDs: [1, 2]))
    }
}
