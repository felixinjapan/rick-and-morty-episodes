import SwiftUI

struct EpisodeListView: View {
    let viewModel: EpisodeListViewModel
    let screens: CharacterScreens
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
                        Button(.commonRetry) { Task { await viewModel.retryFailedLoad() } }
                            .buttonStyle(.bordered)
                    }
                    .accessibilityIdentifier("episodeList.loadError")
                } else {
                    episodeList
                }
            }
            .navigationTitle(.episodeListTitle)
            .navigationDestination(for: Episode.self) { episode in
                EpisodeCharactersView(episode: episode, screens: screens)
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
                RefreshErrorBanner(message: refreshErrorMessage) {
                    await viewModel.refresh()
                }
            }

            ForEach(viewModel.seasonGroups) { group in
                Section {
                    ForEach(group.episodes) { episode in
                        NavigationLink(value: episode) {
                            EpisodeRow(episode: episode)
                        }
                        .accessibilityIdentifier("episode.row.\(episode.id)")
                    }
                } header: {
                    SeasonHeader(season: group.season, count: group.episodes.count)
                }
            }

            if viewModel.isCatalogueEmpty {
                // A row, not an overlay, so the list can still be pulled down to refresh.
                ContentUnavailableView {
                    Label(.episodeListEmptyTitle, systemImage: "tv.slash")
                } description: {
                    Text(.episodeListEmptyDescription)
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("episodeList.empty")
            } else {
                // The footer's task loads the first page too, so it stays in the list while the
                // spinner below stands in for its own.
                EpisodeListFooter(
                    footer: viewModel.footer, isFirstPage: viewModel.isLoadingFirstPage, viewport: viewport
                ) {
                    await viewModel.loadNextPage()
                }
                .listRowBackground(viewModel.isLoadingFirstPage ? Color.clear : nil)
                .id(viewModel.episodes.last?.id)
            }
        }
        .id(viewModel.listIdentity)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { viewport = $0 }
        .refreshable { await viewModel.refresh() }
        .onChange(of: viewModel.refreshErrorMessage) { _, message in
            // The banner appears above the rows, where VoiceOver focus isn't.
            guard let message else { return }
            AccessibilityNotification.Announcement(
                "\(String(localized: .episodeListRefreshErrorTitle)). \(message)"
            ).post()
        }
        .overlay {
            if viewModel.isLoadingFirstPage {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel(.episodeListLoading)
            }
        }
    }
}

private struct SeasonHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let season: Int?
    let count: Int

    var body: some View {
        // Stacked at accessibility sizes, where side by side the title breaks mid-word.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
        layout {
            Text(season.map { .episodeListSeason($0) } ?? .episodeListOtherEpisodes)
                .textCase(.uppercase)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            Text(.episodeListSeasonCount(count))
                .textCase(nil)
                .multilineTextAlignment(.trailing)
        }
        .foregroundStyle(.primary.opacity(0.7))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct EpisodeListFooter: View {
    let footer: EpisodeListViewModel.Footer
    /// The screen shows its own spinner, so this one only has to keep the page request alive.
    let isFirstPage: Bool
    let viewport: CGRect
    let loadNextPage: () async -> Void
    @State private var isNearViewport = false

    var body: some View {
        // The transform captures a copy so it doesn't capture the view itself.
        let viewport = viewport
        Group {
            switch footer {
            case .none:
                EmptyView()
            case .loading(let page):
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .opacity(isFirstPage ? 0 : 1)
                    .accessibilityHidden(isFirstPage)
                    .accessibilityLabel(.episodeListLoadingMore)
                    .task(id: isNearViewport ? page : nil) {
                        guard isNearViewport, !Task.isCancelled else { return }
                        await loadNextPage()
                    }
            case .failed(let message):
                VStack(spacing: 8) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(.commonRetry) {
                        Task { await loadNextPage() }
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
        // Reports only when the answer changes, so scrolling doesn't re-render the footer.
        // Allow about two rows of lead time, independent of List's offscreen cell preparation.
        .onGeometryChange(for: Bool.self) { proxy in
            let frame = proxy.frame(in: .global)
            return !frame.isEmpty && !viewport.isEmpty
                && frame.maxY > viewport.minY && frame.minY < viewport.maxY + 120
        } action: { isNearViewport = $0 }
    }
}

private struct RefreshErrorBanner: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Button(.commonRetry) { Task { await retry() } }
                .buttonStyle(.bordered)
        }
    }
}

private struct LastUpdatedLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        // Size to the text so the toolbar doesn't truncate it to "Las…". At accessibility sizes the
        // text can be wider than the screen, so there it wraps instead.
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
        .multilineTextAlignment(.center)
    }
}

#if DEBUG
#Preview("Loaded") {
    episodeListPreview()
}

#Preview("Offline") {
    episodeListPreview(networkUnavailable: true)
}

#Preview("Episode list components") {
    let date = Date(timeIntervalSince1970: 1_385_942_400)
    List {
        Section {
            RefreshErrorBanner(message: RepositoryError.offline.userMessage) {}
        } header: {
            SeasonHeader(season: 1, count: 11)
        }
        Section("Pagination") {
            EpisodeListFooter(footer: .loading(page: 2), isFirstPage: false, viewport: .zero) {}
            EpisodeListFooter(
                footer: .failed(message: RepositoryError.offline.userMessage), isFirstPage: false, viewport: .zero
            ) {}
            EpisodeListFooter(footer: .endReached(count: 51), isFirstPage: false, viewport: .zero) {}
        }
        Section("Refresh status") {
            LastUpdatedLabel(date: date, isRefreshing: false)
            LastUpdatedLabel(date: date, isRefreshing: true)
        }
    }
}

@MainActor
private func episodeListPreview(networkUnavailable: Bool = false) -> some View {
    let configuration = AppConfiguration.production
    let repositories = AppDependencies.makePreviewRepositories(
        configuration: configuration, networkUnavailable: networkUnavailable
    )
    let root = AppRoot(
        repositories: repositories,
        exporter: AppDependencies.makePreviewExporter().export,
        freshnessInterval: configuration.freshnessInterval,
        scheduleBackgroundRefresh: {}
    )
    return EpisodeListView(viewModel: root.episodeListViewModel, screens: root.characterScreens)
}
#endif
