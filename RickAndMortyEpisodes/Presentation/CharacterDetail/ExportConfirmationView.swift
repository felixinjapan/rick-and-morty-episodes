import SwiftUI

/// Confirms that the export file was saved and offers to share it.
struct ExportConfirmationView: View {
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
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
