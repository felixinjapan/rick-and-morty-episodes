import SwiftUI

enum CharacterPortraitPhase {
    case loading
    case loaded(CGImage)
    case failed
}

struct CharacterPortraitContent: View {
    let name: String
    let size: CGFloat
    let phase: CharacterPortraitPhase

    var body: some View {
        Group {
            switch phase {
            case .loaded(let image):
                Image(image, scale: 1, label: Text(.portraitImage(name)))
                    .resizable().scaledToFill()
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
    }
}

#if DEBUG
#Preview("Portrait states", traits: .sizeThatFitsLayout) {
    HStack {
        if let image = UIImage(data: RecordedResponses.portrait)?.cgImage {
            CharacterPortraitContent(name: PreviewData.character.name, size: 52, phase: .loaded(image))
        }
        CharacterPortraitContent(name: PreviewData.character.name, size: 52, phase: .loading)
        CharacterPortraitContent(name: PreviewData.character.name, size: 52, phase: .failed)
    }
    .padding()
}
#endif
