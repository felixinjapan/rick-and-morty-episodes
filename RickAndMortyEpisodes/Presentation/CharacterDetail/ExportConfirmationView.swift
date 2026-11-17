import SwiftUI

struct ExportConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let fileURL: URL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text(.exportSaved)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("export.confirmation")
                    Text(fileURL.lastPathComponent)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .accessibilityLabel(.exportFileName(fileURL.lastPathComponent))
                    Text(.exportMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                    ShareLink(item: fileURL) {
                        Label(.exportShare, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("export.share")
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("export.content")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.commonClose, systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
