# Verification and evidence

## Environment

| Item | Value |
| --- | --- |
| Flutter | 3.47.5 (stable) |
| Dart | 3.13.4 |
| Android emulator | Pixel 4, Android API 36 |
| Screen | 1080 × 2280 physical, density 440 (≈392.7 × 829 logical, DPR 2.75) |
| 3D backend | `flutter_scene` 0.24.3 with `--enable-flutter-gpu` |
| Tablet pass | 1600 × 2560 physical, density 320 (≈800 × 1280 logical) |

## Automated checks

```bash
flutter analyze
flutter test
```

Results on the final tree:

- `flutter analyze` — **No issues found.**
- `flutter test` — **18 tests, all passed.**
- `flutter build apk --release` — **Built** `build/app/outputs/flutter-apk/app-release.apk` (62.8 MB).

Coverage:

- `test/kecrekan_math_test.dart` — empty frame, counting to 100, clamping, row
  filling, left/right bead packing and edge-bead selection.
- `test/jarimatika_test.dart` — canonical 0–9 shapes, hand validation,
  ones/tens composition, and number validation.
- `test/progress_test.dart` — best stars, pearls, first-try evidence, station
  unlock order, Jarimatika mastery gate, practice recording, chest costs and
  persistence round-trip.
- `test/widget_test.dart` — home screen brand, reef map, station cards.

## Manual verification

All items below were exercised in the running Android build.

| Area | Checks performed | Result |
| --- | --- | --- |
| 3D asset | GLB loads; purple sea-glass frame, two loop ears, smiling face, 1–5 plates and sea stickers all render | Pass |
| 3D picking | Tap right-side bead increments row; tap counted bead decrements it; total badge updates | Pass |
| 3D drag | Drag a right-side bead left counts several beads; drag back uncounts | Pass |
| Bead packing | Count 7 → 7 beads packed screen-left, 3 packed screen-right with a clear gap | Pass |
| Reset | “Start over” and reset icon return the frame to the mission starting number | Pass |
| Counting mission | Bubble Bop, count 4, first try → 3 stars, +2 pearls, “You counted 4 beads” | Pass |
| Addition mission | Two Pearl Piles, prompt `2 + 3 = ?`, build 5 → sheet shows `2 + 3 = 5`, 3 stars | Pass |
| Subtraction mission | Bubble Pop, start 8, tap three counted beads → 5, sheet shows `8 − 3 = 5`, 3 stars | Pass |
| Answer hiding | Addition/subtraction prompts show `?`; target counter hides `/ target` while playing | Pass |
| Jarimatika | Target 3 using index+middle+ring; target 1 using index only; ones/tens readout correct; “Finger magic!” sheet | Pass |
| Jarimatika gate | Challenge remains locked with less than the required first-try evidence; practice opens regardless | Pass |
| Mastery panel | Shows exact first-try counts and star goal (e.g. 1/3, 0/2, 0/1, 3/8) | Pass |
| Chest | Open with 3 pearls, collect a treasure, pearl balance and collection count update | Pass |
| Persistence | Force-stop and relaunch restores stars, pearls, treasures and station counts | Pass |
| Settings | Sound, voice and ambience toggles persist and are respected at launch | Pass |
| Responsive | Phone portrait and 800 × 1280 tablet portrait render without overflow; content centres with `maxWidth` | Pass |
| Splash | Deep-water splash with pearl-ring mark (Android 12+ and legacy launch background) | Pass |
| App icon | Launcher icon generated for all five Android densities from `assets/images/app-icon.svg` | Pass |

## Audio and TTS note

The generated SFX and ambience assets are present and bundled, and the ocean
ambience loop was verified playing on the emulator. On this emulator the media
preparation future can still time out (`TimeoutException ... Future not
completed`) and TTS reports `not bound to TTS engine`. This is an emulator audio
stack limitation, not a missing asset: playback failures are caught and logged,
the tap path never blocks for more than the 6-second preparation timeout, and
the game remains fully playable. Real-device audio is expected to work; it could
not be audibly confirmed in this environment.

## Evidence inventory

Screenshots (`evidence-out/screenshots/`):

| File | Scene |
| --- | --- |
| `00-splash.png` | Android splash with the pearl-ring app mark |
| `01-home.png` | Ocean map, turtle greeting, stars/pearls |
| `02-station-counting.png` | Coral Cove mission list |
| `03-mission-counting.png` | 3D counting mission with four beads counted |
| `04-success.png` | Counting success sheet (new “You counted 4 beads” copy) |
| `05-finger-reef.png` | Finger Reef station and mastery panel |
| `06-jarimatika-hands.png` | Right hand index open, ones = 1 |
| `07-jarimatika-success.png` | Jarimatika success sheet |
| `08-treasure-grotto.png` | Treasure chest and collection |
| `09-settings.png` | Sound, voice and ambience settings |
| `10-subtraction-mission.png` | Subtraction mission at 5 beads |
| `11-subtraction-success.png` | `8 − 3 = 5` success sheet |
| `12-station-subtraction.png` | Kelp Forest mission list |
| `13-addition-mission.png` | `2 + 3 = ?` addition mission at 5 beads |
| `14-addition-success.png` | `2 + 3 = 5` success sheet |
| `15-tablet-free-play.png` | 800 × 1280 tablet free-play layout |

Recording (`evidence-out/recordings/`):

- `mathocean-demo.mp4` — 30-second capture of the home → Coral Cove → Bubble
  Bop flow, tapping four beads, the live 3D spring motion and the success sheet.

Earlier proof-of-concept renders are kept in `evidence-out/poc/`.

## Reproduce

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <device> --enable-flutter-gpu
```

To regenerate the 3D or audio assets:

```bash
blender -b -P tools/blender/build_kecrekan.py -- --mode full
python3 tools/audio/generate_audio.py
```
