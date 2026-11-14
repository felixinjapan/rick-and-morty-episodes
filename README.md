# Rick and Morty Episodes (iOS)

A SwiftUI app that lists every *Rick and Morty* episode from the public
[Rick and Morty API](https://rickandmortyapi.com/documentation), shows the characters in each
episode, and exports character details to a file that other apps can open.

Built as the take-home assignment for OMRON Healthcare. It is meant to be a small but
complete app: built for its actual requirements, testable, and easy to change.

| Requirement | Where |
|---|---|
| List all episodes (name, air date `dd/mm/yyyy`, episode code) | `Presentation/EpisodeList` |
| "End of list" text once everything is loaded | `EpisodeListView` footer |
| Episode → list of character IDs | `Presentation/EpisodeCharacters` |
| Character ID → detail (image, name, status, species, origin, episode count) | `Presentation/CharacterDetail` |
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
Presentation/  SwiftUI views ──▶ @MainActor @Observable view models
               (EpisodeListViewModel, CharacterDetailViewModel)
                                    │ depend on
                                    ▼
Domain/        Episode, CharacterDetails, DataError,
               EpisodeRepository, CharacterRepository (protocols)
                                    ▲ implemented by
                                    │
Data/          DefaultEpisodeRepository (actor)  ◀── App/BackgroundRefresh (BGAppRefreshTask)
               DefaultCharacterRepository (actor, in-memory cache)
                  │                       │
                  ▼                       ▼
               Networking/             Persistence/
               RickAndMortyAPI (protocol)  FileEpisodeStore (actor, JSON file)
               └ LiveRickAndMortyAPI (URLSession via HTTPTransport)

App/           AppDependencies: the composition root that picks the concrete types
Support/       Cross-cutting helpers that belong to no layer (logging)
```

- **Views** only display state. A view model exists only where there is real logic to
  test: paging and refreshing on the list, and loading and exporting on the detail
  screen. The character ID screen has none, because its data is already in `Episode`.
- **Domain** holds the entities, the repository protocols the view models depend on
  (`EpisodeRepository` for the list, `CharacterRepository` for character details, so each
  view model sees only what it uses), and `DataError`. It knows nothing about JSON, HTTP, files or SwiftUI. There are no
  use-case classes: with three screens they would only forward calls to the repository.
- **`DefaultEpisodeRepository`** is the single source of truth, shared by the UI and the
  background task. It is an actor because both reach it at once. It owns the cached list:
  it loads each next page, appends it and saves the list so far, and a refresh fetches page 1
  only and saves it as the new start of the list. A page that arrives after a refresh is
  dropped rather than saved over the newer list. Overlapping refreshes are not merged: each
  saves a valid first page, and the store writes one at a time.
- **`DefaultCharacterRepository`** fetches character details and keeps them in memory for
  the session. Both repositories share one API client.
- **Errors** have one vocabulary per layer. Networking reports `APIError` (offline, HTTP
  status, decoding). The repositories translate it into the domain's `DataError`, and
  the presentation layer (`Presentation/Shared/ErrorMessages.swift`) decides the wording.
  Cancellation passes through unchanged, so it is never shown as an error.
- **Networking** maps JSON DTOs to domain entities, so API changes stay in one layer. The
  air date is parsed into a `Date` there (`en_US_POSIX`, GMT); an unreadable value becomes
  `nil` for that episode only, shown as "Unknown air date". Presentation formats it as `dd/MM/yyyy`.
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
| Refresh fetches page 1 only; deeper pages load and are cached as the user scrolls | A refresh costs one request however many pages the API has, so it also fits easily in a background task's short time. The "end of list" text still appears once the user has scrolled through every page. | Refetch every page on each refresh: the cache is always complete, but the cost grows with the catalogue (100 pages = 100 requests), and a background task could run out of time and save nothing. Or check page 1 and fetch only new pages: cheaper offline, but more logic. |
| JSON file cache in an actor | About 50 records, always read and written as a whole, with no queries. Atomic writes, easy to test. | SwiftData or Core Data: no benefit at this size, plus concurrency friction |
| `BGAppRefreshTask` via SwiftUI `.backgroundTask` | Native, with automatic cancellation when time runs out | Silent push (needs a server) |
| Refresh in the foreground when data is older than 1 h | iOS doesn't guarantee background tasks will run | Relying only on `BGTaskScheduler` |
| Plain-text export in `Documents/Exports`, shown in Files, plus a share sheet | Readable in any document reader, and found in the Files app | `fileExporter`: the user picks a folder, so nothing is stored automatically |
| `AsyncImage` with `URLCache` | One image per screen | Nuke or Kingfisher: worth it for image-heavy lists |
| Swift Testing for unit tests, XCUITest for UI tests | Current tooling; UI automation still needs XCTest | – |

## Background refresh

The brief asks to "implement refreshing the list content in the background". The app covers
both readings of that:

- **While the app is in the background:** a `BGAppRefreshTask` updates the saved list, so it
  is fresh the next time the app opens (details below).
- **Without blocking the list while it's open:** the cached list shows immediately, stale data
  (older than 1 h) refreshes quietly at launch and on returning to the app, with an
  "Updating…" status instead of a full-screen loader, and all network, decoding and file work
  runs off the main thread in actors.

- All lifecycle handling is in one place: the app's `scenePhase` handler
  (`RickAndMortyEpisodesApp`). Going to the background schedules a `BGAppRefreshTask`
  (no sooner than 1 h); becoming active calls the list view model's `refreshIfNeeded()`.
  The app owns that view model so the handler can reach it.
- The task fetches page 1 and saves it as the new start of the list. When the app comes
  back to the foreground, the list picks up that snapshot, and refreshes if it's still stale.
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
