# SPEC: The Series

Storyline D, app first. 40 s, 1920×1080, 30 fps, English on-screen copy, synthesised music and
effects.

## Goal

The app first, the series second. A stranger finishes the film knowing: Vesper brings Memos,
Moment and Atlas to iPhone, iPad and Mac; one you-find.me sign-in holds it together; it belongs
to a wider series on the web and the desktop; and where to follow the maker: @yiming9876 on X. Third person
throughout: no "my", no "I".

## Public view

Only what any visitor can already see:

- Memos shows the **Public** display (`publicOnly=true`) with public memos from
  `assets/data/memos.json`; tag counts are counted from those memos.
- Moment and Atlas use the public photo stream (`assets/data/photos.json`, `assets/photos`).
  "顶楼的公寓" is left out: its pin marks a home.
- The Atlas map is OpenFreeMap positron at `MapCamera.britain` (54.4, −3.2, z4.6) with the paper
  recoloured as `TileMap` does, credited on screen.
- Settings shows the avatar and name; the account's email line is left out.
- Sites are their public pages, signed out, light scheme (`assets/sites/`, captured 2026-11-03);
  you-find.me is cropped to the header and introduction; Moment's Journey map is not used.

## Look

- Ground `#FAF7EB`, ink `#1A1917`, muted `#6B6760`, brand `#963C5A`, icon lavender `#B0A2DB`.
- App icon (`assets/app-icon.png`): opens the film, launches the app on the home screen, heads
  the series column and the end card.
- Wordmark: Instrument Serif italic (`assets/fonts`, OFL), ink falling into brand across the
  letters, a four-point evening star over the r.
- Left column at x = 140: kicker (mono caps, brand), title (SF Pro Display 600, 96 px), sub
  (36 px, muted). Only the opening and end card are centred.
- The device at x = 1210 (450×960); the screen is drawn at 402×874 pt and scaled 1.08. Liquid
  Glass is white at 58% over `backdrop-filter: blur(14px) saturate(1.7)` with a top highlight.

## Shots

| # | Time | Left / centre | Phone / right |
| --- | --- | --- | --- |
| 1 | 0–3.5 | icon lands alone, steps left; wordmark sets beside it; star arcs in and glints | — |
| 2 | 3.5–6.9 | VESPER FOR APPLE · Memos, Moment and Atlas, native on iPhone, iPad and Mac, in Liquid Glass. | a home screen on a dusk wallpaper: twelve apps and a dock, all generic glyphs drawn here except Vesper; Vesper is tapped at 5.5 and opens out of its icon into the splash |
| 3 | 6.9–11.5 | 01 · MEMOS · Write it down. | Public feed docks in; pinned deck opens at 8.4; the feed scrolls |
| 4 | 11.5–16.1 | 02 · MOMENT · Keep the light. | Edinburgh and the Highlands, photos sharpen out of their blur; the stream scrolls |
| 5 | 16.1–22.1 | 03 · ATLAS · Find it again. | Britain, 25 pins land; the calendar opens at 18.8: November with today (the 3rd) outlined, then October's photo days |
| 6 | 22.1–27 | ONE SIGN-IN · you-find.me · OAuth with PKCE; the session stays in the Keychain. | Settings; Sign in with you-find.me at 23.1; the account fills in at 24.35 |
| 7 | 27–33 | icon · PART OF THE VESPER SERIES · One console, every surface. | five pages fanned with depth |
| 8 | 33–40 | icon, wordmark, "for iPhone, iPad and Mac", a pointer presses **Follow @yiming9876 on X** at 35.6 and it turns to Following, `x.com/yiming9876` | — |

## Motion

- Scene in: 0.6 s, `power3.out`, 24 px rise and fade. Scene out: 0.35 s fade.
- App elements dock: drop 40 px with a slight overshoot (`back.out(1.4)`), 0.05 s apart.
- Tabs: a touch dot, the selection capsule slides (`power3.inOut`), the screens cross 30 px.
- The device breathes: from rest, ±10 px and 0.5°, settling before the scene ends.
- Series pages land 0.28 s apart at small tilts; the back two sit out of focus.

## Sound

`scripts/soundtrack.py` synthesises everything into `assets/audio/soundtrack.m4a` (D major,
90 BPM): a pad on Dmaj9 → Bm7 → Gmaj7 → A6, an eighth-note pluck arpeggio from 3.5 to 33, and a
held D chord under the end card. Effects in key: taps at 5.5, 8.4, 11.5, 16.1, 18.8, 22.1, 23.1, 35.6;
whooshes on scene changes; a bell at 2.58 (star), 24.35 (signed in) and 35.7 (followed); sparkles
on the photos (12.1), pins (16.5), the calendar's photo days (19.9) and the follow. Fade in 0.5 s, out 2 s, peak −1 dBFS.

## Banned

Private data; claims beyond the READMEs; centred text on a card; big bounces (overshoot stays
under `back.out(1.8)`); anything implying the public can sign up (the sites are single-owner).

## QA times

0.5, 1.6, 3, 5, 5.9, 6.4, 8, 9.2, 11, 13, 14.5, 16.5, 18, 20, 22.5, 24.5, 29, 34, 36, 39.
