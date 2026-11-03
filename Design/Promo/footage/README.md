# Footage

The film redraws the app in the DOM (`compositions/app.html`). These Simulator takes are the
reference the redraw is checked against; they are not committed (`.gitignore`) and the film
does not play them.

| File | What | How |
| --- | --- | --- |
| `memos-feed.mp4` | 3 · Memos, Display → Public: scroll the feed, open the pinned deck | `scripts/record.sh memos-feed` |
| `moment-timeline.mp4` | 4 · Moment timeline: scroll, open a photo, back | `scripts/record.sh moment-timeline` |
| `atlas.mp4` | 5 · Atlas calendar, then the map over Britain (never zoomed on home) | `scripts/record.sh atlas` |
| `signin.mp4` | 6 · Settings: the you-find.me account card | `scripts/record.sh signin` |

Each shot uses 4–5.4 s of its take (`SPEC.md`); record about 8 s and note the chosen start here.

## Before recording

1. **Public only.** Memos and photos on the account are real and some are private. In Memos,
   switch Display (top right) to **Public** before recording, so only public memos are listed.
   Keep Atlas off the home area.
2. **Release build.** It starts faster and drops debug overlays:
   `xcodebuild -project ../../Vesper.xcodeproj -scheme Vesper -configuration Release -destination "platform=iOS Simulator,name=iPhone 18 Pro" -derivedDataPath build build`,
   then `xcrun simctl install "iPhone 18 Pro" build/Build/Products/Release-iphonesimulator/Vesper.app`.
3. **Signed in** on the simulator (Settings → Sign in with you-find.me).

## Recording

```sh
scripts/record.sh morning-memo                 # iPhone 18 Pro, light
APPEARANCE=dark scripts/record.sh dusk-atlas   # the dusk shots
DEVICE="iPhone Duo" DISPLAY_ID=3 scripts/record.sh duo-unfold
```

The script pins the status bar (9:41, full signal, charged), sets the appearance, records until
Ctrl-C, and writes `footage/raw/<name>.mov` (as recorded) and `footage/<name>.mp4` (30 fps,
H.264, 1080 px wide, the size the compositions use). It clears the status bar override after.

## Finding times

- Seek single frames to see what is on screen: `ffmpeg -ss T -i footage/<name>.mp4 -frames:v 1 t.png`.
- Note each shot's source time here once chosen; `data-media-start` in the compositions uses them.
- Touches are not drawn in Simulator recordings; where a tap matters, the SPEC adds a touch dot.
