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
                    Button("Export", systemImage: "square.and.arrow.down") {
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
                Button("Retry") { Task { await model.load() } }
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
                AsyncImage(url: character.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.square")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 200, height: 200)
                .clipShape(.rect(cornerRadius: 16))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Image of \(character.name)")
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
    let fileURL: URL

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.title2.bold())
                    .accessibilityIdentifier("export.confirmation")
                Text("**\(fileURL.lastPathComponent)** was saved to Files › On My iPhone › Episodes › Exports.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                ShareLink(item: fileURL) {
                    Label("Open in…", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CharacterDetailView(
            characterID: 1,
            repository: EpisodeRepository(api: RecordedRickAndMortyAPI(), store: InMemoryEpisodeStore())
        )
    }
}
#endif
