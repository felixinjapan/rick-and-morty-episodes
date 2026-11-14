import SwiftUI

struct CharacterDetailView: View {
    @State private var viewModel: CharacterDetailViewModel

    init(characterID: Int, repository: any EpisodeRepository) {
        _viewModel = State(initialValue: CharacterDetailViewModel(characterID: characterID, repository: repository))
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
            .alert(
                .characterDetailExportFailedTitle,
                isPresented: Binding(
                    get: { viewModel.exportError != nil },
                    set: { if !$0 { viewModel.exportError = nil } }
                )
            ) {
                Button(role: .cancel) {} label: { Text(.commonOk) }
            } message: {
                Text(viewModel.exportError ?? "")
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
                Button { Task { await viewModel.load() } } label: {
                    Text(.commonRetry).foregroundStyle(Color.onAccent)
                }
                .buttonStyle(.borderedProminent)
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
                            .foregroundStyle(statusColor)
                            .accessibilityHidden(true)
                        Text(character.status)
                    }
                }
                LabeledContent(String(localized: .characterDetailSpecies), value: character.species)
                LabeledContent(String(localized: .characterDetailOrigin), value: character.originName)
                LabeledContent(String(localized: .characterDetailEpisodes), value: character.episodeCount, format: .number)
            }
        }
    }


    private var statusColor: Color {
        switch character.status.lowercased() {
        case "alive": .green
        case "dead": .red
        default: .gray
        }
    }
}

private struct ExportConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let fileURL: URL

    var body: some View {
        NavigationStack {
            // Scrolls so the content stays readable at the largest accessibility text sizes.
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text(.exportSaved)
                        .font(.title2.bold())
                        .accessibilityIdentifier("export.confirmation")
                    // AttributedString(localized:) applies the **bold** markup in the catalog value.
                    Text(AttributedString(localized: .exportMessage(fileURL.lastPathComponent)))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ShareLink(item: fileURL) {
                        Label(.exportShare, systemImage: "square.and.arrow.up")
                            .foregroundStyle(Color.onAccent)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("export.share")
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("export.content")
            .toolbar {
                // The sheet only confirms a finished action, so it is dismissed with Close, not Done.
                ToolbarItem(placement: .cancellationAction) {
                    Button(.commonClose, systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CharacterDetailView(
            characterID: 1,
            repository: DefaultEpisodeRepository(api: RecordedRickAndMortyAPI(), store: .preview)
        )
    }
}
#endif
