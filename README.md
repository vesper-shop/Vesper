# Vesper

Native Apple client (SwiftUI) for the Vesper content: memos, moments, knowledge.

- One multiplatform target: iOS / iPadOS and macOS, deployment target 26.0
- Swift 6, main-actor default isolation, approachable concurrency
- The project uses a file-system synchronized group: files added under `Vesper/` are picked up
  without editing `Vesper.xcodeproj`

## Features

- **Memos** — card feed with Markdown bodies, pinned group, search, tag filter, All / Favorites /
  Archive, compose and edit, pin, favorite, archive and delete
- **Moment** — a timeline of photo bubbles by day (after hyoban's 这里) or a staggered grid, tag
  filter, and a full-screen pager with pinch and double-tap zoom
- **Atlas** — every photo on a month calendar, and on a MapLibre vector map (iOS) opening on Britain
- **Settings** — per-service API keys in the Keychain, with a connection test

The app calls the consumer open APIs (`memos.you-find.me`, `moment.you-find.me`) with an access
token from the you-find.me OAuth gateway (my-profile): Settings → Sign in with you-find.me runs an
authorization-code + PKCE sign-in as the public client `vesper` (`vesper://oauth/callback`). One token
carries all three sites as audiences; the refresh token is kept in the Keychain. Photos are posted to
Moment's `/api/photos/upload`, which stores them in R2 server-side.

## Layout

Boundaries follow `my-workspace`: packages own behavior and tokens, the app composes features.

| Path | Responsibility |
| --- | --- |
| `Packages/VesperKit/Sources/Vault` | Keychain credential storage |
| `Packages/VesperKit/Sources/Identity` | you-find.me OAuth sign-in, token refresh and sign-out |
| `Packages/VesperKit/Sources/Consumers` | Consumer endpoints, wire types and API calls |
| `Packages/VesperKit/Sources/VesperMarkdown` | Markdown → flat blocks (memo line breaks, task lists, tables, autolinks) |
| `Packages/VesperKit/Sources/VesperUI` | Palette and semantic tokens, Card, Badge, glass TagBar, MarkdownView |
| `Vesper/App` | Entry point, root `TabView`, shell state and load problems |
| `Vesper/Features/<Feature>` | A session owning state, its views, and the feature's types |

Each module keeps its types in one file (`Types.swift`, or `<Feature>Types.swift` in the app
target). Package tests: `cd Packages/VesperKit && swift test`.

## Promo

`Design/Promo/` holds the promo film as a HyperFrames project: storylines, the recording script for the
Simulator and the compositions. Start with `Design/Promo/AGENTS.md`.

## Run

Open `Vesper.xcodeproj` in Xcode, pick a simulator or My Mac, and press ⌘R.

From the command line (iOS Simulator):

```sh
xcodebuild -project Vesper.xcodeproj -scheme Vesper -destination "platform=iOS Simulator,name=iPhone 18 Pro" \
  -derivedDataPath build/DerivedData build
xcrun simctl install "iPhone 18 Pro" build/DerivedData/Build/Products/Debug-iphonesimulator/Vesper.app
xcrun simctl launch "iPhone 18 Pro" me.youfind.vesper
```

macOS:

```sh
xcodebuild -project Vesper.xcodeproj -scheme Vesper -destination "platform=macOS" \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Vesper.app
```
