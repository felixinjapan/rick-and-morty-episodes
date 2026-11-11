import SwiftUI

struct CharacterDetailView: View {
    @State private var model: CharacterDetailModel

    init(characterID: Int, repository: EpisodeRepository) {
        _model = State(initialValue: CharacterDetailModel(characterID: characterID, repository: repository))
    }

    var body: some View {
        content
            .navigationTitle(model.character?.name ?? "Character #\(model.characterID)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Export", systemImage: "square.and.arrow.up") {
                        model.export()
                    }
                    .disabled(model.character == nil)
                    .accessibilityIdentifier("characterDetail.export")
                }
            }
            .task { await model.load() }
            .sheet(item: $model.exportedFile) { file in
                ExportConfirmationView(fileURL: file.url)
            }
            .alert(
                "Export Failed",
                isPresented: Binding(
                    get: { model.exportError != nil },
                    set: { if !$0 { model.exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.exportError ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load Character", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button { Task { await model.load() } } label: {
                    Text("Retry").foregroundStyle(Color.onAccent)
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

            Section("Details") {
                LabeledContent("Name", value: character.name)
                    .accessibilityIdentifier("characterDetail.name")
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(character.status)
                    }
                }
                LabeledContent("Species", value: character.species)
                LabeledContent("Origin", value: character.originName)
                LabeledContent("Episodes", value: character.episodeCount, format: .number)
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
                    Text("Saved")
                        .font(.title2.bold())
                        .accessibilityIdentifier("export.confirmation")
                    Text("**\(fileURL.lastPathComponent)** was saved. Find it in Files, in the Episodes folder under Exports.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ShareLink(item: fileURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
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
                    Button("Close", systemImage: "xmark") { dismiss() }
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
            repository: EpisodeRepository(api: RecordedRickAndMortyAPI(), store: .preview)
        )
    }
}
#endif
