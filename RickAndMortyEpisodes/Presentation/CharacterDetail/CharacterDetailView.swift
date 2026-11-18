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
                    Button {
                        viewModel.export()
                    } label: {
                        Label(.characterDetailExport, systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
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
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .imageScale(.small)
                            .accessibilityHidden(true)
                        Text(character.status.title)
                    }
                    .font(.subheadline)
                    .foregroundStyle(character.status.color)
                    .accessibilityIdentifier("characterDetail.status")
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section(.characterDetailDetails) {
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
    characterDetailPreview()
}

#Preview("Offline") {
    characterDetailPreview(networkUnavailable: true)
}

@MainActor
private func characterDetailPreview(networkUnavailable: Bool = false) -> some View {
    let repositories = AppDependencies.makePreviewRepositories(
        configuration: .production, networkUnavailable: networkUnavailable
    )
    return NavigationStack {
        CharacterDetailView(
            route: CharacterRoute(id: 1, name: nil),
            repository: repositories.characters,
            exporter: AppDependencies.makePreviewExporter()
        )
    }
}
#endif
