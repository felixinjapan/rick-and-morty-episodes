import SwiftUI

/// Navigation value for a character's detail page.
struct CharacterRoute: Hashable {
    let id: Int
}

/// Lists the IDs of the characters that appear in an episode.
/// The IDs come from the episode itself, so this screen needs no network request.
struct EpisodeCharactersView: View {
    let episode: Episode


    var body: some View {
        List {
            Section {
                ForEach(episode.characterIDs, id: \.self) { id in
                    NavigationLink(value: CharacterRoute(id: id)) {
                        Label(.characterTitle(id), systemImage: "person.crop.circle")
                    }
                    .accessibilityIdentifier("character.link.\(id)")
                }
            } header: {
                // Data and punctuation only, so nothing to translate.
                Text(verbatim: "\(episode.code) · \(episode.formattedAirDate)")
            } footer: {
                Text(.episodeCharactersCount(episode.characterIDs.count))
            }
        }
        .overlay {
            if episode.characterIDs.isEmpty {
                ContentUnavailableView(.episodeCharactersEmpty, systemImage: "person.slash")
            }
        }
        .navigationTitle(episode.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EpisodeCharactersView(episode: Episode(id: 1, name: "Pilot", airDate: Date(timeIntervalSince1970: 1_385_942_400), code: "S01E01", characterIDs: [1, 2, 35]))
    }
}
