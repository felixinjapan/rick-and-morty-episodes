import SwiftUI

enum CharacterPortraitPhase {
    case loading
    case loaded(UIImage)
    case failed
}

struct CharacterPortrait: View {
    let character: CharacterDetails
    let repository: any CharacterRepository
    @State private var phase = CharacterPortraitPhase.loading

    var body: some View {
        CharacterPortraitContent(
            name: character.name, size: 200, phase: character.imageURL == nil ? .failed : phase
        )
        .task(id: character.imageURL) {
            guard character.imageURL != nil else { return }
            if case .loaded = phase { return }
            do {
                let data = try await repository.portrait(for: character)
                try Task.checkCancellation()
                phase = UIImage(data: data).map(CharacterPortraitPhase.loaded) ?? .failed
            } catch is CancellationError {
                return
            } catch {
                phase = .failed
            }
        }
    }
}

struct CharacterPortraitContent: View {
    let name: String
    let size: CGFloat
    let phase: CharacterPortraitPhase

    var body: some View {
        Group {
            switch phase {
            case .loaded(let image):
                Image(uiImage: image).resizable().scaledToFill()
                    .accessibilityLabel(.portraitImage(name))
                    .accessibilityIdentifier("characterDetail.portrait")
            case .loading:
                ProgressView()
                    .accessibilityLabel(.portraitLoading)
                    .accessibilityIdentifier("characterDetail.portraitLoading")
            case .failed:
                Image(systemName: "person.crop.square")
                    .font(.system(size: size * 0.32))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(.portraitUnavailable(name))
                    .accessibilityIdentifier("characterDetail.portraitUnavailable")
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: .infinity)
    }
}
