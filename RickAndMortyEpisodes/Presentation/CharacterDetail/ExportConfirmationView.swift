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
                        .accessibilityIdentifier("export.confirmation")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(.commonClose, systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
