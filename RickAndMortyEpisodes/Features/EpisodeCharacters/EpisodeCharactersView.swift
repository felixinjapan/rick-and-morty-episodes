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
                        Label("Character #\(id)", systemImage: "person.crop.circle")
                    }
                }
            } header: {
                Text("\(episode.code) · \(episode.formattedAirDate)")
            } footer: {
                Text("\(episode.characterIDs.count) characters")
            }
        }
        .overlay {
            if episode.characterIDs.isEmpty {
                ContentUnavailableView("No Characters", systemImage: "person.slash")
            }
        }
        .navigationTitle(episode.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EpisodeCharactersView(episode: Episode(id: 1, name: "Pilot", airDate: "December 2, 2013", code: "S01E01", characterIDs: [1, 2, 35]))
    }
}
