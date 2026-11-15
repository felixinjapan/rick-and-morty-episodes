import SwiftUI

struct EpisodeListView: View {
    /// Owned by the app, which also forwards foreground events to it (see `RickAndMortyEpisodesApp`).
    let viewModel: EpisodeListViewModel
    /// Passed on to the character screen this list navigates to.
    let characterRepository: any CharacterRepository
    let exporter: any CharacterExporting

    var body: some View {
        NavigationStack {
            Group {
                // With no episodes to show, the error replaces the list instead of covering it.
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
                EpisodeCharactersView(episode: episode)
            }
            .navigationDestination(for: CharacterRoute.self) { route in
                CharacterDetailView(characterID: route.id, repository: characterRepository, exporter: exporter)
            }
            .toolbar {
                // A status item in the bottom toolbar (as in Mail) instead of a floating label,
                // so the system bar keeps it legible and it never covers list rows.
                if viewModel.lastRefreshedAt != nil || viewModel.isRefreshing {
                    ToolbarItem(placement: .status) {
                        LastUpdatedLabel(date: viewModel.lastRefreshedAt, isRefreshing: viewModel.isRefreshing)
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

            EpisodeListFooter(footer: viewModel.footer, viewModel: viewModel)
        }
        // A new identity rebuilds the list from the top (see `listIdentity`).
        .id(viewModel.listIdentity)
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }
}

/// The last list row: triggers the next page, shows a paging error, or the end-of-list text.
private struct EpisodeListFooter: View {
    let footer: EpisodeListViewModel.Footer
    let viewModel: EpisodeListViewModel

    var body: some View {
        Group {
            switch footer {
            case .none:
                EmptyView()
            case .loading(let page):
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(.episodeListLoadingMore)
                    // Re-runs for each new page while the footer stays visible.
                    .task(id: page) { await viewModel.loadNextPage() }
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
        .listRowSeparator(.hidden)
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
        .listRowBackground(Color.orange.opacity(0.12))
        .accessibilityIdentifier("episodeList.refreshError")
    }
}

private struct LastUpdatedLabel: View {
    let date: Date?
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isRefreshing {
                ProgressView().controlSize(.mini)
                Text(.episodeListUpdating)
            } else if let date {
                Text(.episodeListLastUpdated(date.formatted(date: .abbreviated, time: .shortened)))
                    .accessibilityIdentifier("episodeList.lastUpdated")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        // Size to the text so the toolbar doesn't truncate it to "Las…".
        .fixedSize()
    }
}

#if DEBUG
#Preview("Loaded") {
    episodeListPreview(AppDependencies.makePreviewRepositories())
}

#Preview("Offline") {
    episodeListPreview(AppDependencies.makePreviewRepositories(networkUnavailable: true))
}

@MainActor
private func episodeListPreview(_ repositories: AppDependencies.Repositories) -> some View {
    EpisodeListView(
        viewModel: EpisodeListViewModel(
            repository: repositories.episodes,
            staleInterval: AppConfiguration.current.freshnessInterval
        ),
        characterRepository: repositories.characters,
        exporter: AppDependencies.makePreviewExporter()
    )
}
#endif
