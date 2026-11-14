import SwiftUI

struct EpisodeListView: View {
    /// Owned by the app, which also forwards foreground events to it (see `RickAndMortyEpisodesApp`).
    let viewModel: EpisodeListViewModel
    let repository: any EpisodeRepository

    /// The end-of-list text, using the plural rules in the string catalog.
    static func endOfListText(count: Int) -> String {
        String(localized: "You've reached the end · \(count) episodes", comment: "Last row of the episode list once every episode is loaded")
    }

    var body: some View {
        NavigationStack {
            List {
                if let refreshError = viewModel.refreshError {
                    RefreshErrorBanner(message: refreshError, lastRefreshed: viewModel.lastRefreshed)
                }

                ForEach(viewModel.episodes) { episode in
                    NavigationLink(value: episode) {
                        EpisodeRow(episode: episode)
                    }
                }

                EpisodeListFooter(footer: viewModel.footer, viewModel: viewModel)
            }
            .listStyle(.plain)
            .overlay {
                if let message = viewModel.emptyListError {
                    ContentUnavailableView {
                        Label("Couldn't Load Episodes", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button { Task { await viewModel.loadNextPage() } } label: {
                            Text("Retry").foregroundStyle(Color.onAccent)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .accessibilityIdentifier("episodeList.loadError")
                }
            }
            .navigationTitle("Episodes")
            .navigationDestination(for: Episode.self) { episode in
                EpisodeCharactersView(episode: episode)
            }
            .navigationDestination(for: CharacterRoute.self) { route in
                CharacterDetailView(characterID: route.id, repository: repository)
            }
            .toolbar {
                // A status item in the bottom toolbar (as in Mail) instead of a floating label,
                // so the system bar keeps it legible and it never covers list rows.
                if viewModel.lastRefreshed != nil || viewModel.isRefreshing {
                    ToolbarItem(placement: .status) {
                        LastUpdatedLabel(date: viewModel.lastRefreshed, isRefreshing: viewModel.isRefreshing)
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.start() }
        }
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
                    .accessibilityLabel("Loading more episodes")
                    // Re-runs for each new page while the footer stays visible.
                    .task(id: page) { await viewModel.loadNextPage() }
            case .failed(let message):
                VStack(spacing: 8) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.loadNextPage() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            case .endReached(let count):
                Text(EpisodeListView.endOfListText(count: count))
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
    let lastRefreshed: Date?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't refresh. Showing saved episodes.")
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
                Text("Updating…")
            } else if let date {
                Text("Last updated \(date.formatted(date: .abbreviated, time: .shortened))")
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
#Preview {
    let repository = DefaultEpisodeRepository(api: RecordedRickAndMortyAPI(), store: .preview)
    EpisodeListView(viewModel: EpisodeListViewModel(repository: repository), repository: repository)
}
#endif
