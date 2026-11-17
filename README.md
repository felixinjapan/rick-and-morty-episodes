# Rick and Morty Episodes (iOS)

A SwiftUI app for browsing *Rick and Morty* episodes, viewing their characters, and exporting character details as a text file.

## UI map

[![Five iPhone screens show how to open Pilot, select Rick Sanchez, export his details, and open the iOS share sheet.](docs/ui-map.png)](docs/ui-map.png)

## Run and test

Requires Xcode 26 or later and iOS 17 or later. Open `RickAndMortyEpisodes.xcodeproj` and run the `RickAndMortyEpisodes` scheme. Run tests in Debug so the app can use the bundled fixtures.

```sh
xcodebuild test -project RickAndMortyEpisodes.xcodeproj -scheme RickAndMortyEpisodes \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17'
```

See the [architecture and decision log](docs/architecture.md) for implementation details.
