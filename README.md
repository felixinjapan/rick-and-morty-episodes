# Rick and Morty Episodes (iOS)

A SwiftUI app that lists every *Rick and Morty* episode from the public
[Rick and Morty API](https://rickandmortyapi.com/documentation), shows the characters in each
episode, and exports character details to a file that other apps can open.

Built as the take-home assignment for OMRON Healthcare. It is meant to be a small but
complete app: built for its actual requirements, testable, and easy to change.

| Requirement | Where |
|---|---|
| List all episodes (name, air date `dd/mm/yyyy`, episode code) | `Features/EpisodeList` |
| "End of list" text once everything is loaded | `EpisodeListView` footer |
| Episode → list of character IDs | `Features/EpisodeCharacters` |
| Character ID → detail (image, name, status, species, origin, episode count) | `Features/CharacterDetail` |
| Export character details to a local file other apps can open | `CharacterExporter` |
| Background refresh of the list | `App/BackgroundRefresh.swift` |
| *Extra:* persistence, pull-to-refresh, "last updated" timestamp | `Data/Persistence/`, `EpisodeListViewModel` |
| *Extra:* unit and UI tests | `RickAndMortyEpisodesTests/`, `RickAndMortyEpisodesUITests/` |

## Running

- Xcode 26 or later (built with Xcode 27.1, Swift 6 language mode, strict concurrency).
- Minimum deployment target: iOS 17.
- No third-party dependencies. Open `RickAndMortyEpisodes.xcodeproj` and run.

```sh
xcodebuild test -project RickAndMortyEpisodes.xcodeproj -scheme RickAndMortyEpisodes \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Offline mode and recorded data

`RickAndMortyEpisodes/RecordedResponses/` holds real API responses: all 51 episodes
(3 pages) and the 826 characters they reference. In Debug builds they are served through
the real `LiveRickAndMortyAPI` with a different `HTTPTransport`, so URL building, status
handling and decoding run exactly as in production:

- UI tests launch with `-uiTesting` and never use the network.
- Add `-offline` to the scheme's launch arguments to run the app without Wi-Fi. Character
  images are omitted, because they are served by the API's server.
- The folder is listed in `DEVELOPMENT_ASSET_PATHS`, so it is excluded from archives.

## Architecture

MVVM with a thin domain layer. Folders are the layers; dependencies point inward.

```
Features/  SwiftUI views ──▶ @MainActor @Observable view models
           (EpisodeListViewModel, CharacterDetailViewModel)
                                   │ depend on
                                   ▼
Domain/    Episode, CharacterDetails, EpisodeError,
           EpisodeRepository (protocol)
                                   ▲ implemented by
                                   │
Data/      DefaultEpisodeRepository (actor)  ◀── App/BackgroundRefresh (BGAppRefreshTask)
              │                       │
              ▼                       ▼
           Networking/             Persistence/
           RickAndMortyAPI (protocol)  FileEpisodeStore (actor, JSON file)
           └ LiveRickAndMortyAPI (URLSession via HTTPTransport)

App/       AppDependencies: the composition root that picks the concrete types
```

- **Views** only display state. A view model exists only where there is real logic to
  test: paging and refreshing on the list, and loading and exporting on the detail
  screen. The character ID screen has none, because its data is already in `Episode`.
- **Domain** holds the entities, the `EpisodeRepository` protocol the view models depend
  on, and `EpisodeError`. It knows nothing about JSON, HTTP, files or SwiftUI. There are no
  use-case classes: with three screens they would only forward calls to the repository.
- **`DefaultEpisodeRepository`** is the single source of truth, shared by the UI and the
  background task. It is an actor because both reach it at once. A refresh fetches every
  page and saves only if all of them arrived, so the cache is only ever replaced as a whole.
  Overlapping refreshes are not merged: each saves a complete list, and the store writes
  one at a time.
- **Errors** have one vocabulary per layer. Networking reports `APIError` (offline, HTTP
  status, decoding). The repository translates it into the domain's `EpisodeError`, and
  the presentation layer (`Features/Shared/ErrorMessages.swift`) decides the wording.
  Cancellation passes through unchanged, so it is never shown as an error.
- **Networking** maps JSON DTOs to domain entities, so API changes stay in one layer.
- **Configuration** that is a product or environment decision lives in `AppConfiguration`:
  the API base URL, the 1-hour freshness interval (used by both the foreground staleness
  check and background scheduling) and the request timeouts. Only the App layer reads it;
  the composition root passes the values down as plain parameters.
- **Dependency injection** goes through initialisers, wired in one place (`AppDependencies`).
  Protocols sit at layer boundaries only: the repository (between features and data) and
  the network (so tests control it). The file store has none, because tests point it at
  a temporary folder and exercise real file I/O.
  UI tests launch with `-uiTesting`, which uses recorded API responses.

## Key decisions

| Decision | Why | Alternative considered |
|---|---|---|
| Incremental paging for the first load, full refresh afterwards | The assignment asks for an "end of list" text once all episodes are loaded. After that, a refresh replaces the whole list so it's never half-updated. | Load all pages up front: simpler, but the end text means little then |
| JSON file cache in an actor | About 50 records, always read and written as a whole, with no queries. Atomic writes, easy to test. | SwiftData or Core Data: no benefit at this size, plus concurrency friction |
| Concurrent page fetch in a `TaskGroup` on refresh | Fast, and the result is put back in page order | Fetching pages one by one |
| `BGAppRefreshTask` via SwiftUI `.backgroundTask` | Native, with automatic cancellation when time runs out | Silent push (needs a server) |
| Refresh in the foreground when data is older than 1 h | iOS doesn't guarantee background tasks will run | Relying only on `BGTaskScheduler` |
| Plain-text export in `Documents/Exports`, shown in Files, plus a share sheet | Readable in any document reader, and found in the Files app | `fileExporter`: the user picks a folder, so nothing is stored automatically |
| `AsyncImage` with `URLCache` | One image per screen | Nuke or Kingfisher: worth it for image-heavy lists |
| Swift Testing for unit tests, XCUITest for UI tests | Current tooling; UI automation still needs XCTest | – |

## Background refresh

- All lifecycle handling is in one place: the app's `scenePhase` handler
  (`RickAndMortyEpisodesApp`). Going to the background schedules a `BGAppRefreshTask`
  (no sooner than 1 h); becoming active calls the list view model's `refreshIfNeeded()`.
  The app owns that view model so the handler can reach it.
- The task fetches all pages and saves a new snapshot. When the app comes back to the
  foreground, the list picks up that snapshot, and refreshes if the data is still stale.
- iOS decides when (and whether) to run the task. It is an optimisation; the foreground
  refresh when data is stale is what keeps data fresh.
- To trigger it manually on a device, pause the app in the debugger after it has been in
  the background, then run:

  ```
  e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.felixinjapan.RickAndMortyEpisodes.refresh"]
  ```

## Known limitations and next steps

- Character details are cached in memory only, not persisted.
- No automatic retry with backoff; the user retries manually (Retry button or pull-to-refresh).
- The `dd/MM/yyyy` format is fixed, as the assignment requires, rather than localised.
- No offline indicator based on `NWPathMonitor`; offline state is inferred from failed requests.
- For real health data: encrypt the cache (`.complete` file protection where background
  work allows), avoid logging personal data, and pin certificates.
