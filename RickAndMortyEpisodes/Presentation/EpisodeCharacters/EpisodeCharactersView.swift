import SwiftUI

struct CharacterRoute: Hashable {
    let id: Int
    let name: String?
}

struct EpisodeCharactersView: View {
    let episode: Episode
    let repository: any CharacterRepository

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(episode.name)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    EpisodeMetadata(episode: episode)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

            Section {
                ForEach(episode.characterIDs, id: \.self) { id in
                    EpisodeCharacterRow(id: id, repository: repository)
                }
                if episode.characterIDs.isEmpty {
                    ContentUnavailableView(.episodeCharactersEmpty, systemImage: "person.slash")
                }
            } header: {
                Text(.episodeCharactersCount(episode.characterIDs.count))
                    .textCase(nil)
                    .foregroundStyle(.primary.opacity(0.7))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(.episodeCharactersTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EpisodeCharacterRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let id: Int
    let repository: any CharacterRepository
    @ScaledMetric(relativeTo: .body) private var portraitSize = 52
    @State private var character: CharacterDetails?

    var body: some View {
        NavigationLink(value: CharacterRoute(id: id, name: character?.name)) {
            label
        }
        .accessibilityIdentifier("character.link.\(id)")
        .task(id: id) {
            // The ID stays tappable when details fail to load or the task is cancelled.
            guard character == nil,
                  let loaded = try? await repository.character(id: id),
                  !Task.isCancelled else { return }
            character = loaded
        }
    }

    private var label: some View {
        let size = min(portraitSize, 80)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return layout {
            Group {
                if let character {
                    CharacterPortrait(character: character, repository: repository, size: size)
                } else {
                    Image(systemName: "person.crop.square.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(character?.name ?? String(localized: .characterTitle(id)))
                    .font(.headline)
                Group {
                    if character != nil {
                        Text(.characterTitle(id))
                            .font(.caption.monospacedDigit())
                    } else {
                        Text(.episodeCharactersTapForDetails)
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(.primary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Characters") {
    NavigationStack {
        EpisodeCharactersView(
            episode: Episode(
                id: 1, name: "Pilot", airDate: Date(timeIntervalSince1970: 1_385_942_400),
                code: "S01E01", characterIDs: [1, 2, 35]
            ),
            repository: AppDependencies.makePreviewRepositories(configuration: .production).characters
        )
    }
}
#endif
