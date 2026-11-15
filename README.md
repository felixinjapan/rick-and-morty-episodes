# Rick and Morty Episodes (iOS)

A SwiftUI app that lists every *Rick and Morty* episode from the public
[Rick and Morty API](https://rickandmortyapi.com/documentation), shows each episode's characters,
and exports character details to a file other apps can open. Built as the OMRON Healthcare
take-home: small, testable and easy to change.

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

- Xcode 26 or later (built with 27.1), Swift 6 strict concurrency, iOS 17 minimum, no third-party dependencies.
- Open `RickAndMortyEpisodes.xcodeproj` and run, or:

```sh
xcodebuild test -project RickAndMortyEpisodes.xcodeproj -scheme RickAndMortyEpisodes \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Debug builds include `StubData/`: saved API responses (51 episodes, 826 characters) served through
the real `LiveRickAndMortyAPI` on a different `HTTPTransport`, so URL building, status handling and
decoding run as in production. UI tests launch with `-uiTesting` and never use the network
(`-resetCache` starts without a cache, `-networkUnavailable` fails every request). Character images are
left out, because the API's server hosts them. The folder is excluded from archives (`DEVELOPMENT_ASSET_PATHS`).

## Architecture

MVVM with a thin domain layer. Folders are the layers; dependencies point inward.

```
Presentation/  SwiftUI views ──▶ @MainActor @Observable view models
               (EpisodeListViewModel, CharacterDetailViewModel)
                                    │ depend on
                                    ▼
Domain/        Episode, CharacterDetails, DataError,
               EpisodeRepository, CharacterRepository, CharacterExporting (protocols)
                                    ▲ implemented by
                                    │
Data/          DefaultEpisodeRepository (actor)  ◀── App/BackgroundRefresh (BGAppRefreshTask)
               DefaultCharacterRepository (actor, file cache)
                  │                       │
                  ▼                       ▼
               Networking/             Persistence/
               RickAndMortyAPI (protocol)  FileEpisodeStore (actor, JSON file)
               └ LiveRickAndMortyAPI (URLSession via HTTPTransport)

App/           AppDependencies: the composition root that picks the concrete types
Support/       Cross-cutting helpers that belong to no layer (logging)
```

- **Views** display state. A view model exists only where there is logic to test: the list (paging,
  refresh) and the character detail (load, export). The character-ID screen has none; its data is
  already in `Episode`.
- **Domain** holds the entities, `DataError` and the protocols the view models use. It knows nothing
  about JSON, HTTP, files or SwiftUI. There are no use-case classes: with three screens they would only
  forward calls.
- **`DefaultEpisodeRepository`** is the single source of truth for the list, shared by the UI and the
  background task, so it is an actor. It appends and saves each page as it loads. A refresh fetches
  page 1, which also reports how many episodes exist: if the total is unchanged the cached pages after
  page 1 stay; if it grew, whole cached pages stay and the new ones load on scroll; if it shrank, only
  page 1 is kept. A page that arrives after a refresh is dropped. Overlapping refreshes aren't merged:
  each saves a valid list and the store writes one at a time.
- **`DefaultCharacterRepository`** saves each character the user opens as its own file, so opening it
  again makes no request and works offline. Saved details are used while the catalogue is the same size
  as when they were saved and they are under 30 days old; otherwise they are fetched again, and still
  served if that fails. Nothing is downloaded ahead. Both repositories share one API client.
- **Errors** have one vocabulary per layer: `APIError` (network) → `DataError` (domain) → wording in
  `Presentation/Shared/ErrorMessages.swift`. Cancellation passes through, so it is never shown as an error.
- **Networking** maps DTOs to domain entities. The air date is parsed there (`en_US_POSIX`, GMT); an
  unreadable one becomes `nil` for that episode only ("Unknown air date"). Presentation formats it as `dd/MM/yyyy`.
- **Configuration** (API URL, the 12-hour freshness interval for the foreground check and background
  scheduling, timeouts) lives in `AppConfiguration`, read only by the App layer.
- **Dependency injection** is by initialiser, wired in `AppDependencies`. Protocols sit at layer boundaries
  and at the network (so tests control it); the file store has none, because tests give it a temporary folder.

## Key decisions

| Decision | Why | Alternative considered |
|---|---|---|
| Refresh fetches page 1 only, and its total tells whether the cached pages are still valid | One request however many pages exist; fits a background task's short time. Episodes are only added at the end, so an unchanged total means the cached pages are current | Refetch every page: the cost grows with the catalogue and a task may run out of time. Replace the list with page 1: loses the offline tail on every refresh |
| JSON file cache in an actor | About 50 records, always read and written whole; atomic writes, easy to test | SwiftData or Core Data: no benefit at this size |
| Save only the characters the user opened, one file each | The catalogue rarely changes, so there is no reason to download 826 characters for three screens; one file per character means a save rewrites nothing else | Prefetch everything: wasteful. One shared file: rewritten on every open |
| `BGAppRefreshTask` via `.backgroundTask` | Native; cancelled automatically when time runs out | Silent push (needs a server) |
| Foreground refresh when data is over 12 h old | iOS doesn't guarantee background tasks run; the catalogue rarely changes and a refresh is one request | Relying on `BGTaskScheduler` alone |
| Plain-text export in `Documents/Exports` plus a share sheet | Any reader opens it, and Files shows it | `fileExporter`: the user picks a folder, so nothing is stored automatically |
| `AsyncImage` and the system HTTP cache (automatic on iOS 27+) | One image per screen | Nuke or Kingfisher for image-heavy lists |
| Swift Testing for unit tests, XCUITest for UI tests | Current tooling; UI automation still needs XCTest | – |

## Background refresh

The brief asks to refresh the list in the background. The app covers both readings:

- **App in the background:** a `BGAppRefreshTask` saves a fresh page 1, so the list is current the next
  time the app opens. iOS decides when, and whether, it runs; the foreground refresh is what keeps data fresh.
- **App open:** the cached list shows at once, and data over 12 h old refreshes quietly at launch and on
  return ("Updating…" status, no full-screen loader). Network, decoding and file work run off the main thread in actors.

All lifecycle handling is one `scenePhase` switch in `RickAndMortyEpisodesApp`: going to the background
schedules the task (no sooner than 12 h); becoming active calls `refreshIfNeeded()` on the list view model,
which the app owns for that reason. To trigger the task on a device, pause in the debugger after
backgrounding the app and run:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.felixinjapan.RickAndMortyEpisodes.refresh"]
```

## Known limitations and next steps

- Offline, the list reaches only as far as the user has scrolled before; pages never loaded aren't cached.
- Only characters the user has opened work offline; nothing is downloaded ahead of time.
- No automatic retry with backoff and no `NWPathMonitor`; the user retries, and offline is inferred from failed requests.
- The `dd/MM/yyyy` format is fixed, as the assignment requires. English only; the string catalog is ready for more languages.
- Background refresh hasn't been observed on a physical device (the Simulator can't run it); the logic is unit-tested.
- For real health data: stronger file protection where background work allows, no personal data in logs, certificate pinning.
