import SwiftUI

struct CharacterDetailView: View {
    @State private var lazyViewModel: LazyValue<CharacterDetailViewModel>

    /// Called at most once per presentation, however often the destination is re-evaluated.
    init(makeViewModel: @escaping () -> CharacterDetailViewModel) {
        _lazyViewModel = State(initialValue: LazyValue(makeViewModel))
    }

    private var viewModel: CharacterDetailViewModel { lazyViewModel.value }

    var body: some View {
        content
            .navigationTitle(viewModel.character?.name ?? String(localized: .characterDetailTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    exportButton
                }
            }
            .task { await viewModel.load() }
    }

    /// The share sheet opens straight away; the file is written when a destination is picked.
    @ViewBuilder
    private var exportButton: some View {
        let label = Label(.characterDetailExport, systemImage: "square.and.arrow.up")
            .labelStyle(.iconOnly)
        if let file = viewModel.exportFile {
            ShareLink(item: file, preview: SharePreview(file.title)) { label }
                .accessibilityIdentifier("characterDetail.export")
        } else {
            Button {} label: { label }
                .disabled(true)
                .accessibilityIdentifier("characterDetail.export")
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
        portraitPhase: UIImage(data: RecordedResponses.portrait)?.cgImage.map(CharacterPortraitPhase.loaded) ?? .failed
    )
}

@MainActor
private func characterDetailPreview(networkUnavailable: Bool = false) -> some View {
    let screens = AppDependencies.makePreviewScreens(networkUnavailable: networkUnavailable)
    let cast = screens.makeCast(PreviewData.episode)
    return NavigationStack {
        CharacterDetailView {
            screens.makeDetail(CharacterRoute(id: 1, character: nil)) {
                try await cast.character(id: 1)
            }
        }
    }
}
#endif
