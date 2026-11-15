import SwiftUI

struct CharacterPortrait: View {
    private enum Phase {
        case loading
        case loaded(UIImage)
        case failed
    }

    let character: CharacterDetails
    let repository: any CharacterRepository
    @State private var phase: Phase

    init(character: CharacterDetails, repository: any CharacterRepository) {
        self.character = character
        self.repository = repository
        _phase = State(initialValue: character.imageURL == nil ? .failed : .loading)
    }

    var body: some View {
        Group {
            switch phase {
            case .loaded(let image):
                Image(uiImage: image).resizable().scaledToFill()
                    .accessibilityLabel(.portraitImage(character.name))
                    .accessibilityIdentifier("characterDetail.portrait")
            case .loading:
                ProgressView()
                    .accessibilityLabel(.portraitLoading)
                    .accessibilityIdentifier("characterDetail.portraitLoading")
            case .failed:
                placeholder
            }
        }
        .frame(width: 200, height: 200)
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: .infinity)
        .task(id: character.id) { await load() }
    }

    /// The repository reads a saved portrait from disk, or downloads it and saves it.
    private func load() async {
        guard character.imageURL != nil else { return }
        do {
            let data = try await repository.portrait(for: character)
            phase = UIImage(data: data).map(Phase.loaded) ?? .failed
        } catch is CancellationError {
            // The screen went away; `.task` starts again if it comes back.
        } catch {
            phase = .failed
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.square")
            .font(.system(size: 64))
            .foregroundStyle(.secondary)
            .accessibilityLabel(.portraitUnavailable(character.name))
            .accessibilityIdentifier("characterDetail.portraitUnavailable")
    }
}
