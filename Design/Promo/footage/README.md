# Footage

The video shows the app itself, recorded from the iOS Simulator. The recordings are not committed
(`.gitignore`), so re-record them as below before previewing or rendering.

| File | What | How |
| --- | --- | --- |
| _filled in once `SPEC.md` names its shots_ | | `scripts/record.sh <name>` |

## Before recording

1. **Demo content, not personal.** Memos and photos on the account are real and some are
   private. Write a demo set first: private memos tagged `#promo`, photos tagged `promo`. Filter
   the tag bar to `#promo` while recording, then archive or delete the set afterwards.
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
