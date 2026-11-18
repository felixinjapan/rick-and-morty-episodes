import SwiftUI

struct CharacterRoute: Hashable {
    let id: Int
    let character: CharacterDetails?
}

struct EpisodeCharactersView: View {
    let episode: Episode
    let repository: any CharacterRepository
    let exporter: any CharacterExporting
    @State private var viewModel: EpisodeCharactersViewModel
    @State private var visibleIDs: Set<Int> = []
    @State private var viewport: CGRect = .zero

    init(episode: Episode, repository: any CharacterRepository, exporter: any CharacterExporting) {
        self.episode = episode
        self.repository = repository
        self.exporter = exporter
        _viewModel = State(initialValue: EpisodeCharactersViewModel(
            characterIDs: episode.characterIDs, repository: repository
        ))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(episode.code)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel(episode.spokenCode)
                    Text(episode.name)
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Label {
                        Text(episode.airedDateLabel)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "calendar")
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.tint.opacity(0.10), in: .rect(cornerRadius: 12))
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

            Section {
                ForEach(episode.characterIDs, id: \.self) { id in
                    EpisodeCharacterRow(
                        id: id,
                        character: viewModel.characters[id],
                        isUnavailable: viewModel.unavailableIDs.contains(id),
                        portraits: viewModel.portraits,
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
        .navigationDestination(for: CharacterRoute.self) { route in
            CharacterDetailView(route: route, repository: repository, exporter: exporter) {
                try await viewModel.character(id: route.id)
            }
        }
        .task(id: visibleIDs) { [visibleIDs] in
            await viewModel.loadVisibleCast(visibleIDs: visibleIDs)
        }
    }
}

private struct EpisodeCharacterRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: Int
    let character: CharacterDetails?
    let isUnavailable: Bool
    let portraits: EpisodeCharacterPortraits
    let viewport: CGRect
    let visibilityChanged: (Bool) -> Void
    @ScaledMetric(relativeTo: .body) private var portraitSize = 52
    @State private var frame: CGRect = .zero

    private var isVisible: Bool {
        frame.height > 0 && frame.intersection(viewport).height >= frame.height / 2
    }

    private var isLoading: Bool { character == nil && !isUnavailable }

    var body: some View {
        Group {
            if isLoading {
                label
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(.characterDetailLoading)
                    .accessibilityIdentifier("episodeCharacters.loading.\(id)")
                    .transition(.opacity)
            } else {
                NavigationLink(value: CharacterRoute(id: id, character: character)) {
                    label
                }
                .accessibilityIdentifier("character.link.\(id)")
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: character != nil)
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
                    CharacterPortraitContent(
                        name: character.name, size: size, phase: portraits.phase(for: character.imageURL)
                    )
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
                if isLoading {
                    textPlaceholder(font: .headline, width: 104)
                    textPlaceholder(font: .caption, width: 64)
                } else {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func textPlaceholder(font: Font, width: CGFloat) -> some View {
        // Keep the height of the text line at the current Dynamic Type size.
        Text(verbatim: " ")
            .font(font)
            .hidden()
            .frame(maxWidth: width)
            .overlay {
                Capsule().fill(.quaternary).frame(height: 7)
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
            repository: AppDependencies.makePreviewRepositories(configuration: .production).characters,
            exporter: AppDependencies.makePreviewExporter()
        )
    }
}

#Preview("Character row states") {
    let portraits = EpisodeCharacterPortraits()
    let repository = AppDependencies.makePreviewRepositories(configuration: .production).characters
    NavigationStack {
        List {
            EpisodeCharacterRow(id: 1, character: PreviewData.character, isUnavailable: false, portraits: portraits, viewport: .zero) { _ in }
            EpisodeCharacterRow(id: 2, character: nil, isUnavailable: false, portraits: portraits, viewport: .zero) { _ in }
            EpisodeCharacterRow(id: 3, character: nil, isUnavailable: true, portraits: portraits, viewport: .zero) { _ in }
        }
        .navigationDestination(for: CharacterRoute.self) { route in
            CharacterDetailView(route: route, repository: repository, exporter: AppDependencies.makePreviewExporter()) {
                try await repository.character(id: route.id)
            }
        }
        .task { await portraits.load(for: [PreviewData.character], from: repository) }
    }
}
#endif
