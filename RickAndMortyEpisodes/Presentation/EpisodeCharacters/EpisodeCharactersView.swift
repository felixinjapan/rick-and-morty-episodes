import SwiftUI

struct CharacterRoute: Hashable {
    let id: Int
    let name: String?
}

struct EpisodeCharactersView: View {
    let episode: Episode
    let repository: any CharacterRepository
    @State private var loader = EpisodeCharactersLoader()
    @State private var visibleIDs: Set<Int> = []
    @State private var viewport: CGRect = .zero

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
                    EpisodeCharacterRow(
                        id: id,
                        character: loader.characters[id],
                        loadsPortrait: visibleIDs.contains(id) && loader.settledIDs.contains(id),
                        repository: repository,
                        viewport: viewport
                    ) { isVisible in
                        if isVisible {
                            visibleIDs.insert(id)
                        } else {
                            visibleIDs.remove(id)
                        }
                    }
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { viewport = $0 }
        .navigationTitle(.episodeCharactersTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: visibleIDs) { [visibleIDs] in
            await loader.load(visibleIDs: visibleIDs, from: repository)
        }
    }
}

private struct EpisodeCharacterRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let id: Int
    let character: CharacterDetails?
    let loadsPortrait: Bool
    let repository: any CharacterRepository
    let viewport: CGRect
    let visibilityChanged: (Bool) -> Void
    @ScaledMetric(relativeTo: .body) private var portraitSize = 52
    @State private var frame: CGRect = .zero

    private var isVisible: Bool {
        frame.height > 0 && frame.intersection(viewport).height >= frame.height / 2
    }

    var body: some View {
        NavigationLink(value: CharacterRoute(id: id, name: character?.name)) {
            label
        }
        .accessibilityIdentifier("character.link.\(id)")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .onChange(of: isVisible) { _, visible in visibilityChanged(visible) }
        .onAppear { visibilityChanged(isVisible) }
        .onDisappear { visibilityChanged(false) }
    }

    private var label: some View {
        let size = min(portraitSize, 80)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return layout {
            Group {
                if let character {
                    CharacterPortrait(character: character, repository: repository, size: size, loadsImage: loadsPortrait)
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
