import SwiftUI

struct CharacterDetailView: View {
    @State private var viewModel: CharacterDetailViewModel

    init(viewModel: CharacterDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(viewModel.character?.name ?? String(localized: .characterDetailTitle))
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
            CharacterDetailContent(character: character, portraitPhase: viewModel.portraitPhase)
                .task(id: character.imageURL) { await viewModel.loadPortrait() }
        }
    }
}

private struct CharacterDetailContent: View {
    let character: CharacterDetails
    let portraitPhase: CharacterPortraitPhase

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    CharacterPortraitContent(name: character.name, size: 200, phase: portraitPhase)
                    Text(character.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("characterDetail.name")
                    HStack(spacing: 6) {
                        // Only the dot carries the color: system green and red are too light to
                        // read as 15 pt text on white, and the label already names the status.
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .imageScale(.small)
                            .foregroundStyle(character.status.color)
                            .accessibilityHidden(true)
                        Text(character.status.title)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .readableListWidth()
    }
}

#if DEBUG
#Preview("Loaded") {
    characterDetailPreview()
}

#Preview("Offline") {
    characterDetailPreview(networkUnavailable: true)
}

#Preview("Character content") {
    CharacterDetailContent(
        character: PreviewData.character,
        portraitPhase: UIImage(data: RecordedResponses.portrait).map(CharacterPortraitPhase.loaded) ?? .failed
    )
}

@MainActor
private func characterDetailPreview(networkUnavailable: Bool = false) -> some View {
    let screens = AppDependencies.makePreviewScreens(networkUnavailable: networkUnavailable)
    let cast = screens.makeCast(PreviewData.episode)
    return NavigationStack {
        CharacterDetailView(
            viewModel: screens.makeDetail(CharacterRoute(id: 1, character: nil)) {
                try await cast.character(id: 1)
            }
        )
    }
}
#endif
