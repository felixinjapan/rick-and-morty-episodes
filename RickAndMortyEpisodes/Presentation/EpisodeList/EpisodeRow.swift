import SwiftUI

struct EpisodeRow: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(episode.name)
                .font(.headline)
            EpisodeMetadata(episode: episode)
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
