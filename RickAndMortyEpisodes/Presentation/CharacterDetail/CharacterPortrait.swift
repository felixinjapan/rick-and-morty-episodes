import SwiftUI

enum CharacterPortraitPhase {
    case loading
    case loaded(UIImage)
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
