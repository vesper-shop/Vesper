<div align="center">
  <h1>Vesper for Apple</h1>
  <p>Memos, Moment and Atlas, native on iPhone, iPad and Mac.</p>
</div>

## Features

- **Memos** — a card feed with Markdown, pins, search and tags; compose with `#tag` suggestions
- **Moment** — a timeline or grid of photos, with ThumbHash placeholders and a zoomable pager
- **Atlas** — every photo on a calendar and on a map
- **One sign-in** — you-find.me OAuth with PKCE; the token stays in the Keychain

## Develop

Open `Vesper.xcodeproj` in Xcode 26 and press ⌘R, or:

```sh
xcodebuild -project Vesper.xcodeproj -scheme Vesper -destination "platform=iOS Simulator,name=iPhone 18 Pro" build
cd Packages/VesperKit && swift test
```

SwiftUI and Liquid Glass, with the shared logic in `Packages/VesperKit` ·
the promo film in [`Design/Promo`](Design/Promo/AGENTS.md)

Part of [Vesper](https://github.com/vesper-shop)
