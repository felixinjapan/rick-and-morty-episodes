import SwiftUI

/// Navigation value for a character's detail page.
struct CharacterRoute: Hashable {
    let id: Int
}

/// Lists the IDs of the characters that appear in an episode.
/// The IDs come from the episode itself, so this screen needs no network request.
struct EpisodeCharactersView: View {
    let episode: Episode

    /// "1 character" or "19 characters", using the plural rules in the string catalog.
    static func characterCountText(_ count: Int) -> String {
        String(localized: "\(count) characters", comment: "Footer below an episode's character list")
    }

    var body: some View {
        List {
            Section {
                ForEach(episode.characterIDs, id: \.self) { id in
                    NavigationLink(value: CharacterRoute(id: id)) {
                        Label("Character #\(id)", systemImage: "person.crop.circle")
                    }
                }
            } header: {
                // Data and punctuation only, so nothing to translate.
                Text(verbatim: "\(episode.code) · \(episode.formattedAirDate)")
            } footer: {
                Text(Self.characterCountText(episode.characterIDs.count))
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
