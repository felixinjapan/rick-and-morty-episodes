import SwiftUI

struct CharacterDetailView: View {
    @State private var viewModel: CharacterDetailViewModel
    private let initialName: String?
    private let repository: any CharacterRepository

    init(
        route: CharacterRoute,
        repository: any CharacterRepository,
        exporter: any CharacterExporting
    ) {
        initialName = route.name
        self.repository = repository
        _viewModel = State(initialValue: CharacterDetailViewModel(
            characterID: route.id, repository: repository, exporter: exporter
        ))
    }

    var body: some View {
        content
            .navigationTitle(viewModel.character?.name ?? initialName ?? String(localized: .characterDetailTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(.characterDetailExport) {
                        viewModel.export()
                    }
                    .disabled(viewModel.character == nil)
                    .accessibilityIdentifier("characterDetail.export")
                }
            }
            .task { await viewModel.load() }
            .sheet(item: $viewModel.exportedFile) { file in
                ExportConfirmationView(fileURL: file.url)
            }
            .alert(.characterDetailExportFailedTitle, item: $viewModel.exportErrorMessage) { _ in
                Button(role: .cancel) {} label: { Text(.commonOk) }
            } message: { message in
                Text(message)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .accessibilityLabel(.characterDetailLoading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label(.characterDetailLoadErrorTitle, systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("characterDetail.loadError")
            } description: {
                Text(message)
            } actions: {
                Button(.commonRetry) { Task { await viewModel.load() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("characterDetail.retry")
            }
        case .loaded(let character):
            CharacterDetailContent(character: character, repository: repository)
        }
    }
}

private struct CharacterDetailContent: View {
    let character: CharacterDetails
    let repository: any CharacterRepository

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    CharacterPortrait(character: character, repository: repository)
                    Text(character.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("characterDetail.name")
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section(.characterDetailDetails) {
                LabeledContent(String(localized: .characterDetailStatus)) {
                    // An SF Symbol, not a fixed-size shape, so the dot scales with Dynamic Type.
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .imageScale(.small)
                            .foregroundStyle(character.status.color)
                            .accessibilityHidden(true)
                        Text(character.status.title)
                            .foregroundStyle(.primary)
                    }
                }
                LabeledContent(String(localized: .characterDetailSpecies)) {
                    Text(character.species).foregroundStyle(.primary)
                }
                LabeledContent(String(localized: .characterDetailOrigin)) {
                    Text(character.originName).foregroundStyle(.primary)
                }
                LabeledContent(String(localized: .characterDetailEpisodes)) {
                    Text(character.episodeCount, format: .number).foregroundStyle(.primary)
                }
                .accessibilityIdentifier("characterDetail.episodeCount")
            }
        }
    }
}

#if DEBUG
#Preview("Loaded") {
    NavigationStack {
        CharacterDetailView(
            route: CharacterRoute(id: 1, name: nil),
            repository: AppDependencies.makePreviewRepositories(configuration: .production).characters,
            exporter: AppDependencies.makePreviewExporter()
        )
    }
}

#Preview("Offline") {
    NavigationStack {
        CharacterDetailView(
            route: CharacterRoute(id: 1, name: nil),
            repository: AppDependencies.makePreviewRepositories(configuration: .production, networkUnavailable: true).characters,
            exporter: AppDependencies.makePreviewExporter()
        )
    }
}
#endif
