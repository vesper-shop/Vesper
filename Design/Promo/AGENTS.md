# Vesper promo

A [HyperFrames](https://hyperframes.heygen.com) video: HTML, CSS and seekable GSAP timelines that
the `hyperframes` CLI previews in the browser and renders to MP4. Docs: `npx hyperframes docs
<topic>` or the index at https://hyperframes.heygen.com/llms.txt (do not guess URLs).

## Workflow

1. `STORYLINES.md`: three candidate films. One is picked.
2. `SPEC.md`: the picked film shot by shot: goal, timing, look, motion, each shot's source take
   and time, sound, banned moves, QA times. Nothing is built before it.
3. `assets/`: public data and pages the redraw uses; `scripts/record.sh` takes Simulator
   references to check the redraw against (`footage/README.md`); `scripts/soundtrack.py`
   synthesises the music and effects into `assets/audio/soundtrack.m4a`.
4. `index.html` and `compositions/`: the film. Then check, look at frames, render.
5. `REVIEW.md`: what was measured, what was looked at, what was not checked, the weakest shot.

## Commands

```sh
npm run check                              # lint, runtime, layout, motion, contrast
npx hyperframes@0.8.192 snapshot --at 1,3  # PNG frames to look at before rendering
npx hyperframes@0.8.192 preview --background   # Studio preview; --status, --stop
npm run render                             # MP4 into renders/
```

The CLI is pinned so the film re-renders identically. To move up:
`npx hyperframes@latest upgrade --project . --check`, then without `--check`.

## Rules

1. Every timed element has `data-start` and `data-duration`, and `class="clip"`.
2. One paused root timeline per composition, registered on `window.__timelines["<id>"]`; scene
   timelines added to it are not paused.
3. Sub-compositions are referenced with `data-composition-src="compositions/<file>.html"`.
4. Footage without its own sound is `muted`; music and effects are separate `<audio>`.
5. Deterministic only: no `Date.now()`, `Math.random()` or network fetches.
6. App screens are redrawn in the DOM from the app's SwiftUI source (Theme tokens, layouts,
   copy), so every element can move on its own and stays sharp when pushed in. They show
   public data only (`assets/data`), are checked against real Simulator screenshots, and no
   copy claims more than the app's README.
7. Run `npm run check` after every change and look at snapshots of what changed.
