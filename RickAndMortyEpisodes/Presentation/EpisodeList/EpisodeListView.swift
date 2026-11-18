import SwiftUI

struct EpisodeListView: View {
    /// Owned by AppCoordinator, which also forwards foreground refreshes to this instance.
    let viewModel: EpisodeListViewModel
    let characterRepository: any CharacterRepository
    let makeCharacterDetail: (CharacterRoute) -> CharacterDetailView
    @State private var viewport: CGRect = .zero

    var body: some View {
        NavigationStack {
            Group {
                if let message = viewModel.emptyListErrorMessage {
                    ContentUnavailableView {
                        Label(.episodeListLoadErrorTitle, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button(.commonRetry) { Task { await viewModel.loadNextPage() } }
                            .buttonStyle(.bordered)
                    }
                    .accessibilityIdentifier("episodeList.loadError")
                } else {
                    episodeList
                }
            }
            .navigationTitle(.episodeListTitle)
            .navigationDestination(for: Episode.self) { episode in
                EpisodeCharactersView(episode: episode, repository: characterRepository)
            }
            .navigationDestination(for: CharacterRoute.self) { route in
                makeCharacterDetail(route)
            }
            .toolbar {
                // A status item in the bottom toolbar (as in Mail) instead of a floating label,
                // so the system bar keeps it legible and it never covers list rows.
                if let lastRefreshedAt = viewModel.lastRefreshedAt {
                    ToolbarItem(placement: .status) {
                        LastUpdatedLabel(date: lastRefreshedAt, isRefreshing: viewModel.isRefreshing)
                    }
                }
            }
            .task { await viewModel.start() }
        }
    }

    private var episodeList: some View {
        List {
            if let refreshErrorMessage = viewModel.refreshErrorMessage {
                RefreshErrorBanner(message: refreshErrorMessage)
            }

            ForEach(viewModel.episodes) { episode in
                NavigationLink(value: episode) {
                    EpisodeRow(episode: episode)
                }
                .accessibilityIdentifier("episode.row.\(episode.id)")
            }

            EpisodeListFooter(viewModel: viewModel, viewport: viewport)
                .id(viewModel.episodes.last?.id)
        }
        .id(viewModel.listIdentity)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { viewport = $0 }
        .refreshable { await viewModel.refresh() }
    }
}

private struct EpisodeListFooter: View {
    let viewModel: EpisodeListViewModel
    let viewport: CGRect
    @State private var frame: CGRect = .zero

    private var isNearViewport: Bool {
        // Allow about two rows of lead time, independent of List's offscreen cell preparation.
        !frame.isEmpty && !viewport.isEmpty
            && frame.maxY > viewport.minY && frame.minY < viewport.maxY + 120
    }

    var body: some View {
        Group {
            switch viewModel.footer {
            case .none:
                EmptyView()
            case .loading(let page):
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(.episodeListLoadingMore)
                    .task(id: isNearViewport ? page : nil) {
                        guard isNearViewport, !Task.isCancelled else { return }
                        await viewModel.loadNextPage()
                    }
            case .failed(let message):
                VStack(spacing: 8) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(.commonRetry) {
                        Task { await viewModel.loadNextPage() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            case .endReached(let count):
                Text(.episodeListEndOfList(count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("episodeList.endOfList")
            }
        }
        .padding(.vertical, 12)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

private struct RefreshErrorBanner: View {
    let message: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(.episodeListRefreshErrorTitle)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)
        }
        .accessibilityIdentifier("episodeList.refreshError")
    }
}

private struct LastUpdatedLabel: View {
    let date: Date
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isRefreshing {
                ProgressView().controlSize(.mini)
                Text(.episodeListUpdating)
            } else {
                Text(.episodeListLastUpdated(date.formatted(date: .abbreviated, time: .shortened)))
                    .accessibilityIdentifier("episodeList.lastUpdated")
            }
        }
        .font(.caption)
        .foregroundStyle(.primary.opacity(0.7))
        // Size to the text so the toolbar doesn't truncate it to "Las…".
        .fixedSize()
    }
}

#if DEBUG
#Preview("Loaded") {
    episodeListPreview()
}

#Preview("Offline") {
    episodeListPreview(networkUnavailable: true)
}

@MainActor
private func episodeListPreview(networkUnavailable: Bool = false) -> some View {
    let configuration = AppConfiguration.production
    let repositories = AppDependencies.makePreviewRepositories(
        configuration: configuration, networkUnavailable: networkUnavailable
    )
    return AppCoordinator(
        repositories: repositories,
        exporter: AppDependencies.makePreviewExporter(),
        freshnessInterval: configuration.freshnessInterval,
        scheduleBackgroundRefresh: {}
    ).rootView
}
#endif
