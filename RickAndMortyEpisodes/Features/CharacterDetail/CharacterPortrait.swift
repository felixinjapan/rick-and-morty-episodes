import SwiftUI

struct CharacterPortrait: View {
    let character: CharacterDetails

    var body: some View {
        Group {
            if let url = character.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .accessibilityLabel("Image of \(character.name)")
                    case .empty:
                        ProgressView()
                            .accessibilityLabel("Loading portrait")
                            .accessibilityIdentifier("characterDetail.portraitLoading")
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 200, height: 200)
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: .infinity)
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.square")
            .font(.system(size: 64))
            .foregroundStyle(.secondary)
            .accessibilityLabel("Portrait unavailable for \(character.name)")
            .accessibilityIdentifier("characterDetail.portraitUnavailable")
    }
}
