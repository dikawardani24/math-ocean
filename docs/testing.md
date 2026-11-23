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
- `flutter test` — **38 tests, all passed.**
- `flutter build apk --release` — **Built** `build/app/outputs/flutter-apk/app-release.apk` (64.8 MB).

Coverage:

- `test/kecrekan_math_test.dart` — empty frame, counting to 100, clamping, row
  filling, left/right bead packing, edge-bead selection, exact-one tap
  add/undo, drag quantisation, one step per slot, drag reversal without drift,
  final bead positions matching the logical count at every value from 0 to 10,
  and the new packing contract: one count equals one slot, ten slots fill the
  ±1.10 span, and a five/five split leaves exactly one empty slot.
- `test/jarimatika_test.dart` — canonical 0–9 shapes, hand validation,
  ones/tens composition, number validation, authored fold angles, extension
  interpolation/clamping, bone-name contracts, projected nearest-finger hit
  testing, the forgiving radius, and segment distance.
- `test/progress_test.dart` — best stars, pearls, first-try evidence, station
  unlock order, Jarimatika mastery gate, practice recording, chest costs and
  persistence round-trip.
- `test/widget_test.dart` — home screen brand, reef map, station cards.

## Manual verification

All items below were exercised in the running Android build. Rows that refer
to the 3D hand name the model revision they were checked against; the final
skin-tone and light pass is evidenced by the studio renders in
`evidence-out/hand/` rather than a fresh device sweep.

| Area | Checks performed | Result |
| --- | --- | --- |
| 3D asset | GLB loads; purple sea-glass frame, two loop ears, smiling face, 1–5 plates and sea stickers all render | Pass |
| Forgiving picking | A tap near a bead (not exactly on the mesh) still selects the nearest projected bead centre; the pick radius scales with the stage and is clamped to 22–32 logical px | Pass |
| Tap ±1 | Tap an uncounted bead → total +1; tap a counted bead → total −1. The badge, `Check my beads` counter and prompt stay in agreement; repeated taps never skip or double-toggle | Pass |
| Short drag | A 1-slot drag moves exactly one bead; a wobble below the pan threshold resolves as one tap, not a random neighbour | Pass |
| One-slot drag | A 49 px (one bead slot) swipe on a rest row raised the total to exactly 1; no three- or four-bead overshoot | Pass |
| Two/three/four-slot drags | Separate 2-, 3- and 4-slot swipes produced totals 2, 3 and 4 exactly | Pass |
| Independent rods | One slot dragged on two different rows gave a total of 2 with one bead moved on each row | Pass |
| Tap undo | Tapping the leftmost counted bead at 4 returned the total to 3 | Pass |
| Continuous drag | One pointer drag counted 0 → 1 → 3 → 5 → 7 beads without lifting; every intermediate badge value was observed | Pass |
| Drag reversal | Still holding the pointer, dragging back retraced 7 → 5 → 3 exactly (no drift, no skipped values); the released state stayed at 3 | Pass |
| Drag anchor | With `DragStartBehavior.down`, four bead-widths of finger travel counts four beads (the touch slop is no longer swallowed) | Pass |
| Bead packing | Count 7 → 7 beads packed screen-left, 3 packed screen-right with a clear gap; no two beads share a slot | Pass |
| Reset | “Start over” and reset icon return the frame to the mission starting number | Pass |
| Counting mission | Bubble Bop, count 4, first try → 3 stars, +2 pearls, “You counted 4 beads” | Pass |
| Addition mission | Two Pearl Piles, prompt `2 + 3 = ?`, build 5 → sheet shows `2 + 3 = 5`, 3 stars | Pass |
| Subtraction mission | Bubble Pop, start 8, tap three counted beads → 5, sheet shows `8 − 3 = 5`, 3 stars | Pass |
| Answer hiding | Addition/subtraction prompts show `?`; target counter hides `/ target` while playing | Pass |
| 3D hand | Locally bundled rigged GLB (`assets/3d/hand/hand.glb`, 2.5 MB, 46 376 triangles) loads on Android with no network; skin, five nails, palm volume, thumb and knuckle creases render | Pass (pre-lighting revision) |
| Hand folding | Every finger and the thumb animate smoothly between straight and folded; the folded thumb tucks across the palm instead of sticking out; the left hand is a runtime mirror and lights/culling correctly | Pass (pre-lighting revision) |
| Jarimatika 0–9 | Every right-hand shape 0–9 was built by tapping the 3D fingers; the ones readout matched exactly (0,1,2,3,4,5,6,7,8,9) | Pass |
| Jarimatika tens | Left index gave 10 tens; with right hand 9 the screen read `10 + 9 = 19` and the hands stayed independent | Pass |
| Jarimatika toggling | Tapping a finger again folds it; invalid combinations show `?` and cannot be checked; Clear resets both hands | Pass |
| Jarimatika gate | Challenge remains locked with less than the required first-try evidence; practice opens regardless | Pass |
| Mastery panel | Shows exact first-try counts and star goal (e.g. 1/3, 0/2, 0/1, 3/8) | Pass |
| Chest | Open with 3 pearls, collect a treasure, pearl balance and collection count update | Pass |
| Persistence | Force-stop and relaunch restores stars, pearls, treasures and station counts | Pass |
| Settings | Sound, voice and ambience toggles persist and are respected at launch | Pass |
| Responsive | Phone portrait and 800 × 1280 tablet portrait render without overflow; content centres with `maxWidth`; the 3D hands and stage remain usable on both | Pass |
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
| `06-jarimatika-hands.png` | 3D hands: left index open (10 tens) plus right hand 9 → `10 + 9 = 19` |
| `07-jarimatika-success.png` | 3D right hand showing 3; “Finger magic!” success sheet |
| `08-treasure-grotto.png` | Treasure chest and collection |
| `09-settings.png` | Sound, voice and ambience settings |
| `10-subtraction-mission.png` | Subtraction mission at 5 beads |
| `11-subtraction-success.png` | `8 − 3 = 5` success sheet |
| `12-station-subtraction.png` | Kelp Forest mission list |
| `13-addition-mission.png` | `2 + 3 = ?` addition mission at 5 beads |
| `14-addition-success.png` | `2 + 3 = 5` success sheet |
| `15-tablet-free-play.png` | 800 × 1280 tablet free-play layout |
| `16-kecrekan-drag-forward-1.png` | Held-pointer drag, one bead counted |
| `17-kecrekan-drag-forward-3.png` | Same gesture, three beads counted |
| `18-kecrekan-drag-forward-5.png` | Same gesture, five beads counted |
| `19-kecrekan-drag-forward-7.png` | Same gesture, seven beads counted; 7 + 3 split visible |
| `20-kecrekan-drag-reverse-5.png` | Still holding, dragged back to five |
| `21-kecrekan-drag-reverse-3.png` | Still holding, dragged back to three |
| `22-kecrekan-drag-final-3.png` | Pointer released at three; badge, counter and beads agree |
| `23-kecrekan-tap-add-1.png` | Tap uncounted bead → 1 |
| `24-kecrekan-tap-undo-0.png` | Tap the counted bead → 0 |
| `25-kecrekan-short-drag-1.png` | Short drag → exactly one bead |
| `26-jarimatika-0.png` … `35-jarimatika-9.png` | Every right-hand shape 0–9 in the final 3D hand, exact ones readout |
| `36-jarimatika-19.png` | Left index (10 tens) + right hand 9 → `10 + 9 = 19` |
| `37-tablet-jarimatika.png` | 800 × 1280 tablet Jarimatika layout |
| `38-tablet-kecrekan.png` | 800 × 1280 tablet Kecrekan layout |
| `39-tablet-kecrekan-tap.png` | Tablet tap selects a bead and increments the total |

Rigged hand studio previews (`evidence-out/hand/`): dorsal, palmar and
three-quarter renders of poses 0, 1, 2, 4, 5 and 9 from
`tools/blender/build_hand.py`. `glb-minusZ-palmar.png` and
`glb-plusZ-dorsal.png` are renders of the exported GLB from glTF −Z and +Z,
confirming that the palm faces −Z (the runtime camera side) and that the nails
and extensor tendons are on +Z.

Recordings (`evidence-out/recordings/`):

- `mathocean-demo.mp4` — 30-second capture of the home → Coral Cove → Bubble
  Bop flow, tapping four beads, the live 3D spring motion and the success sheet.
- `kecrekan-drag.mp4` — held-pointer drag through five beads, back to three,
  then tap add/undo and a short drag, with the final spring settling.
- `jarimatika-hands.mp4` — building 0 → 8 → 19 on the 3D hands, then an invalid
  shape showing `?` instead of a wrong total.

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
blender -b -P tools/blender/build_hand.py -- --mode build
blender -b -P tools/blender/build_hand.py -- --mode preview
python3 tools/audio/generate_audio.py
```

`build_hand.py --mode preview` writes the six-pose dorsal/palmar/three-quarter
sheet to `evidence-out/hand/`; `--mode build` writes `hand.glb` and `hand.blend`.
The runtime hand angles in `lib/jarimatika/jarimatika_math.dart` mirror the
`FOLD`/`THUMB_FOLD` constants in the generator. The glTF exporter bakes the
thumb's rolled local frame, so `hand_3d.dart` applies the thumb fold about local
`-X`; this is documented at the call site.

## Known limitations

- The hand is a locally generated, rigged low-poly model (46 376 triangles,
  2.5 MB GLB). It is anatomically proportioned and jointed — tapered fingers,
  palmar pads, thenar/hypothenar volume, five curved nails and crease pigment —
  but it is stylised rather than photoreal: there are no pore-level textures,
  and folded fingers read as knuckle/fingertip masses from the palm view.
- The final lighter skin and brighter runtime lights were checked in the studio
  renders and by reading the exported material/vertex colours. At the user's
  request the last pass was not re-exercised on the emulator, so the in-app
  shade may still differ slightly from the studio renders.
- Frame timing was observed visually on the emulator (`flutter_scene` capped at
  60 fps) rather than captured with a hardware GPU profiler. The scene is one
  skinned hand per widget (two on the Jarimatika screen) with a single
  directional plus two point lights.
- Audio/TTS caveats are described above and are unchanged.
