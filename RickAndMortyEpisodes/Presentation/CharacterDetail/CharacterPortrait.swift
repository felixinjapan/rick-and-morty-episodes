import SwiftUI

struct CharacterPortrait: View {
    private enum Phase {
        case loading
        case loaded(UIImage)
        case failed
    }

    let character: CharacterDetails
    let repository: any CharacterRepository
    let size: CGFloat
    @State private var phase: Phase

    init(character: CharacterDetails, repository: any CharacterRepository, size: CGFloat = 200) {
        self.character = character
        self.repository = repository
        self.size = size
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
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: .infinity)
        .task(id: character.id) { await load() }
    }

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
            .font(.system(size: size * 0.32))
            .foregroundStyle(.secondary)
            .accessibilityLabel(.portraitUnavailable(character.name))
            .accessibilityIdentifier("characterDetail.portraitUnavailable")
    }
}
