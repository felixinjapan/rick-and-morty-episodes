import SwiftUI

struct CharacterDetailView: View {
    @State private var viewModel: CharacterDetailViewModel

    init(characterID: Int, repository: any CharacterRepository, exporter: CharacterExporter) {
        _viewModel = State(initialValue: CharacterDetailViewModel(
            characterID: characterID, repository: repository, exporter: exporter
        ))
    }

    var body: some View {
        content
            .navigationTitle(viewModel.character?.name ?? String(localized: .characterTitle(viewModel.characterID)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(.characterDetailExport, systemImage: "square.and.arrow.up") {
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
            .alert(.characterDetailExportFailedTitle, isPresented: $viewModel.isShowingExportError) {
                Button(role: .cancel) {} label: { Text(.commonOk) }
            } message: {
                Text(viewModel.exportErrorMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label(.characterDetailLoadErrorTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(.commonRetry) { Task { await viewModel.load() } }
                    .buttonStyle(.bordered)
            }
        case .loaded(let character):
            CharacterDetailContent(character: character)
        }
    }
}

private struct CharacterDetailContent: View {
    let character: CharacterDetails

    var body: some View {
        List {
            Section {
                CharacterPortrait(character: character)
                    .listRowBackground(Color.clear)
            }

            Section(.characterDetailDetails) {
                LabeledContent(String(localized: .characterDetailName), value: character.name)
                    .accessibilityIdentifier("characterDetail.name")
                LabeledContent(String(localized: .characterDetailStatus)) {
                    // An SF Symbol, not a fixed-size shape, so the dot scales with Dynamic Type.
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .imageScale(.small)
                            .foregroundStyle(character.status.color)
                            .accessibilityHidden(true)
                        Text(character.status.title)
                    }
                }
                LabeledContent(String(localized: .characterDetailSpecies), value: character.species)
                LabeledContent(String(localized: .characterDetailOrigin), value: character.originName)
                LabeledContent(
                    String(localized: .characterDetailEpisodes), value: character.episodeCount, format: .number
                )
                .accessibilityIdentifier("characterDetail.episodeCount")
            }
        }
    }
}

#if DEBUG
#Preview("Loaded") {
    NavigationStack {
        CharacterDetailView(
            characterID: 1,
            repository: AppDependencies.makePreviewRepositories().characters,
            exporter: .preview
        )
    }
}

#Preview("Offline") {
    NavigationStack {
        CharacterDetailView(
            characterID: 1,
            repository: AppDependencies.makePreviewRepositories(networkUnavailable: true).characters,
            exporter: .preview
        )
    }
}
#endif
