<div align="center">
  <h1>Vesper for Apple</h1>
  <p>Your Vesper journal, native on iPhone, iPad and Mac.</p>
</div>

## Features

- **Timeline** — entries of Markdown with up to four photos; pins, favorites, archive, search and tags
- **Photos** — every photo as a wall, with ThumbHash placeholders and a zoomable pager
- **Atlas** — every entry on a calendar, every photo on a map
- **Widgets and shortcuts** — On This Day and Heatmap widgets, Control Center buttons to write or shoot, and "Write in Vesper" for Siri
- **One sign-in** — Vesper OAuth with PKCE; the token stays in a Keychain group the widgets share

## Develop

Open `Vesper.xcodeproj` in Xcode 26 and press ⌘R, or:

```sh
xcodebuild -project Vesper.xcodeproj -scheme Vesper -destination "platform=iOS Simulator,name=iPhone 18 Pro" build
xcodebuild -project Vesper.xcodeproj -scheme Vesper -destination "platform=iOS Simulator,name=iPhone 18 Pro" test -only-testing:VesperTests
```

Every test lives in `Tests/`: unit tests in `Tests/Unit`, laid out like the sources, and UI tests in `Tests/UI`.

SwiftUI and Liquid Glass, with the shared logic in `Packages/VesperKit` ·
the promo film in [`Design/Promo`](Design/Promo/AGENTS.md)

Part of [Vesper](https://github.com/vesper-shop)
