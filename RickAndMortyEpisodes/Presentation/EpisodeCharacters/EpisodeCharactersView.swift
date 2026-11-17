import SwiftUI

struct CharacterRoute: Hashable {
    let id: Int
}

struct EpisodeCharactersView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let episode: Episode
    let repository: any CharacterRepository

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(episode.name)
                        .font(.title2.bold())
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) { episodeMetadata }
                    } else {
                        HStack(spacing: 12) { episodeMetadata }
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))

            Section {
                ForEach(episode.characterIDs, id: \.self) { id in
                    NavigationLink(value: CharacterRoute(id: id)) {
                        EpisodeCharacterRow(id: id, repository: repository)
                    }
                    .accessibilityIdentifier("character.link.\(id)")
                }
                if episode.characterIDs.isEmpty {
                    ContentUnavailableView(.episodeCharactersEmpty, systemImage: "person.slash")
                }
            } header: {
                Text(.episodeCharactersCount(episode.characterIDs.count))
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(.episodeCharactersTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var episodeMetadata: some View {
        Text(episode.code)
            .font(.caption.monospaced().weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.tint.opacity(0.12), in: .capsule)
        Label(episode.formattedAirDate, systemImage: "calendar")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

private struct EpisodeCharacterRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let id: Int
    let repository: any CharacterRepository
    @ScaledMetric(relativeTo: .body) private var portraitSize = 52
    @State private var character: CharacterDetails?

    var body: some View {
        let size = min(portraitSize, 80)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        layout {
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
                if character != nil {
                    Text(.characterTitle(id))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(.episodeCharactersTapForDetails)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .task(id: id) {
            guard character == nil else { return }
            do {
                let loaded = try await repository.character(id: id)
                guard !Task.isCancelled else { return }
                character = loaded
            } catch {
                // The ID stays tappable when enrichment fails or is cancelled.
            }
        }
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
