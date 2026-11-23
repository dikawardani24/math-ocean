# Math Ocean — Underwater Discovery Adventure Plan

Phase A audit + implementation plan. Coral Cove ships first; other locations wait until that vertical slice is validated.

---

## 1. Current state (audit summary)

### Live user journey

```
Launch → HomeScreen (reef map cards)
  → StationScreen (Learn / Challenge hub)
    → KecrekanMissionScreen OR JarimatikaScreen
      → Reward sheet → Replay / Next / Map
  → RewardsScreen (Treasure Grotto)
  → Settings sheet
```

No named routes. Navigation is imperative `MaterialPageRoute` pushes.

### What already works (preserve)

| System | Verdict | Notes |
| --- | --- | --- |
| Kecrekan contact physics | **Keep frozen** | 5×5 frame; contact push; midpoint threshold counting; screen-space pick |
| KecrekanStage gestures | **Keep frozen** | `DragStartBehavior.down`; rod-locked drag; tap uses down bead |
| Jarimatika mapping | **Keep frozen** | Right = ones, left = tens; canonical shapes 0–9 |
| Progress persistence | Reuse + fix | Pearls/stars/settings exist; star ID mismatch needs repair |
| Audio / TTS / haptics | Reuse | SFX, ambience, `Feel`, Tala voice hooks |
| Theme / UI kit | Reuse selectively | Baloo2, `OceanColors`, pills, celebration, turtle companion |
| Catalog stories | Mine for content | 16 authored missions + treasure blurbs; mostly unused by live UI |

### Broken or misaligned

1. **Map is a station picker**, not an explorable world (four skill cards + grotto).
2. **StationScreen is an app hub** (Learn/Challenge) — extra decision before play.
3. **Dialogs teach** (mission help `AlertDialog`, guide sheets) instead of in-world teaching.
4. **No creature discovery** — names live in story strings and treasures only.
5. **Progress desync** — Challenge stars use `challenge_*` IDs; `totalStars` only sums `kMissions` IDs, so Finger Reef star gate is effectively unreachable from live UI.
6. **README drift** — still describes 10×10 Kecrekan, spring solver, sequential mission list, free play; runtime is 5×5 contact physics + Learn/Challenge.
7. **Environments are cosmetic** — shared `OceanBackground`; stations differ by color/copy, not biome.
8. **Dead code** — `_MissionRow`, `_FreePlayCard`, unused tip gating.

### Architecture to treat as black boxes

```
KecrekanMath  → packing constants + resting positions
KecrekanController → contact solver + picking (do not rewrite)
KecrekanStage → gestures + SceneView
jarimatika_math.dart → finger shapes + handValue
JarimatikaHand → pose animation
```

Safe extension: listen to `controller.total`, wrap stages in new adventure chrome, add missions/content.

---

## 2. Target experience

### Learning pillars (always intertwined)

1. **Mathematics** — counting / adding / subtracting / Jarimatika inside adventures.
2. **Creature discovery** — name, look, habitat, diet, movement, one interesting fact.
3. **Environment** — habitats, simple relationships, light conservation moments.

### Desired flow (direction, not rigid)

```
Launch → Living underwater map
  → Tap creature / landmark / path
    → Encounter (observe + short narration)
      → Adventure activity (math + interaction)
        → Celebrate discovery
          → Journal updates / new map opportunity
            → Continue exploring
```

### Non-negotiables (from product brief)

- World map stays a place, not a dashboard.
- No dialog-primary teaching.
- No static creature info cards as the discovery UX.
- Math stays inside the adventure.
- Kecrekan physics and Jarimatika mapping preserved.
- Creature facts age-appropriate and scientifically grounded.
- Animations ≠ gameplay.
- Validate Coral Cove before expanding other locations.

---

## 3. Preserve / change / remove

### Preserve as-is

- `lib/kecrekan/*` physics and gesture contracts
- `lib/jarimatika/jarimatika_math.dart` mapping
- `ProgressController` persistence format (migrate carefully)
- AudioService, Feel, theme tokens, TurtleCompanion patterns

### Change

| From | To |
| --- | --- |
| Home station cards | Living world map with hotspots |
| Station Learn/Challenge hub | Direct entry into location adventure |
| Mission help dialogs | In-world show → narrate → highlight → invite |
| Treasure grotto as main collectible | Creature discovery journal + map unlocks |
| Random challenge as primary play | Authored Coral Cove adventure first; randomized variants later |
| Shared generic ocean BG | Per-ecosystem 2D environments |

### Remove or demote (after replacements exist)

- Station mode-selection as required gate
- AlertDialog as primary teaching
- Orphaned `_MissionRow` / `_FreePlayCard` once map/adventure owns entry
- Stats-heavy dashboard presentation of progress

---

## 4. World map design

### Concept

One scrollable / pannable underwater scene with connected regions:

| Region | Skill | Biome identity | Starter creatures |
| --- | --- | --- | --- |
| Coral Cove | Counting | Coral reef, anemones, clear water | Clownfish, sea turtle, reef fish |
| Shell Shore | Addition | Sandy seabed, shells, shallows | Hermit crab, sea star |
| Kelp Forest | Subtraction | Tall kelp, filtered light | Seahorse, (later) otter |
| Finger Reef | Jarimatika | Distinctive reef with hand motifs | Guide character + playful hand demos |

### Map interactions

- Tap creature → encounter (not a catalog).
- Tap landmark / path → enter adventure or unlock condition tease.
- Visual progression: new creatures appear, paths open, habitat heals slightly.
- Discovery journal accessible as a secondary overlay (supplement, not home).

### Performance

Prefer efficient 2D layers (gradients, painted reefs, lightweight sprite animation). Keep Kecrekan/Jarimatika 3D for math instruments only.

---

## 5. Creature discovery model

Each creature record (data, not a dialog):

```
id, name, habitat, diet, movement, funFact, appearanceNotes,
encounterScript[], relatedMathActivityId?
```

### Encounter pattern (in-world)

1. Creature appears and performs a behavior (swim, surface, hide).
2. Short TTS narration (1–2 sentences).
3. Highlight interactive affordance.
4. Invite child action.
5. Immediate feedback.
6. Optional help if idle/stuck.
7. Hand off to independent play.

### Coral Cove first creature (vertical slice)

**Sea turtle (Tala can remain guide; introduce a wild turtle encounter too)**

- Lives in warm reefs / open ocean edges.
- Eats seagrass / jellyfish (species-appropriate, keep simple: “she likes crunchy seagrass and soft jellies”).
- Moves with flippers; needs air at the surface.
- Adventure hook: help her count and collect food items → Kecrekan counting.

Second encounter candidate: **clownfish** (anemone home) for a lighter exploration beat before counting.

---

## 6. Mathematics integration

### Coral Cove — Counting

- Child sees N objects (food, fish, shells) in the scene.
- One bead movement = one unit.
- Guided: Tala/turtle demonstrates counting one item → one bead.
- Independent: randomized target within safe range (1–10 first; up to 20 later).
- Win via existing check flow or soft auto-acknowledge when total matches after guided phase.

### Later locations (Phase D only)

- Shell Shore: two visible groups combine; Kecrekan starts at `a`, child adds `b`.
- Kelp Forest: group shrinks; Kecrekan starts at `start`, child removes.
- Finger Reef: progressive Jarimatika learn path already exists — embed in reef encounters, not quiz UI.

---

## 7. Teaching sequence (shared mechanic)

Implement as an adventure `Beat` state machine, not a dialog:

```
demo → narrate → highlight → invite → respond → helpIfNeeded → freePlay
```

Reuse existing delayed TTS + `onInteraction` hooks on KecrekanStage. Gate interactivity with `interactive: false` until invite beat (already used for add/sub reveal).

---

## 8. Progression & collection

### Replace “app progress feel” with discovery feel

- **Discoveries**: creatures unlocked into journal when encounter completes.
- **Map changes**: new hotspot / path / creature after adventure success.
- **Pearls**: keep as soft currency, but chest rewards can become habitat finds.
- **Stars**: keep for mastery, but fix ID accounting so challenges/adventures write IDs that `totalStars` understands.
- **Finger Reef unlock**: keep mastery intent; gate by Coral Cove + later location discoveries rather than unreachable catalog stars.

### Journal

Secondary screen/overlay: creature portrait, 3–5 short facts, “where found.” Not the main loop.

---

## 9. Navigation audit — screens to cut for Coral Cove slice

| Current | Action in Phase B |
| --- | --- |
| Home card grid as only map | Rebuild as living map |
| StationScreen Learn/Challenge | Bypass for Coral Cove; enter adventure directly |
| Mission AlertDialog help | Replace with in-world beats |
| Immediate Challenge randomizer as first play | Authored first adventure; random after mastery |

Keep Settings and a journal/collection entry point, but not as the first beat after launch.

---

## 10. Technical plan

### Package layout (additive)

```
lib/
  world/           # map models, hotspots, biome painters
  creatures/       # creature data + encounter scripts
  adventure/       # beat runner, Coral Cove adventure screen
  discovery/       # journal + unlock state (extends ProgressController)
  kecrekan/        # UNCHANGED physics
  jarimatika/      # UNCHANGED mapping / hand
  screens/         # migrate home → world map; deprecate station hub gradually
```

### Progress migration

- Extend `ProgressController` with `discoveredCreatures`, `unlockedLocations`, adventure completion flags.
- Fix star aggregation to include adventure/challenge IDs OR write stars under mission IDs used by adventures.
- Keep `math_ocean.progress.v1` backward compatible (new fields optional with defaults).

### Regression tests (before Coral Cove UI lands)

1. Keep existing `kecrekan_math_test` / `jarimatika_test` / `progress_test`.
2. Add pure-logic tests for contact counting thresholds if extractable without Scene GPU.
3. Add adventure beat state-machine unit tests.
4. Add creature fact content tests (required fields present; habitat tags valid).
5. Manual checklist for Kecrekan drag/tap on device (existing evidence flow).

### Performance budget

- Map: 2D only.
- At most one Kecrekan `SceneView` during counting.
- Avoid simultaneous dual-hand Jarimatika during Coral Cove.
- Idle animations via lightweight controllers, not extra 3D scenes.

---

## 11. Phase plan

### Phase A — Audit + plan ✅

This document.

### Phase B — Coral Cove vertical slice

**B0. Safety net**

- Confirm Kecrekan tests green.
- Document frozen APIs in code comments only where helpful (no physics rewrite).
- Fix progress star-ID accounting enough that completion can unlock future content.

**B1. Living map v1**

- Replace home card grid with a single underwater composition.
- Coral Cove hotspot active; others visible but soft-locked with tease.
- Tala present on the map as guide, not a menu mascot only.

**B2. Turtle encounter**

- Enter Coral Cove environment (distinct reef look).
- Turtle swims / surfaces; short narration; child taps to befriend/observe.
- No fact dialog — facts delivered by action + TTS.

**B3. Exploration beat**

- Child helps turtle find food items in the reef (tap-to-collect or follow).
- Countable objects appear in the environment.

**B4. Guided counting with real Kecrekan**

- Show → narrate → highlight beads → invite child.
- One object ↔ one bead.
- Immediate feedback; contextual help if stuck.

**B5. Independent counting**

- New target without full demo; still in same reef scene.
- Meaningful completion: turtle eats / celebrates; creature marked discovered; map gains a new sparkle/path tease.

**B6. Journal stub**

- Minimal discovery journal entry for the turtle (and optional clownfish if time).

### Phase C — Validate

Unfamiliar tester checklist:

- [ ] Can enter the world without explanation
- [ ] Finds Coral Cove by curiosity, not by reading “Counting”
- [ ] Understands bead ↔ object correspondence
- [ ] Completes counting without adult help
- [ ] Learns at least one true turtle fact from the encounter
- [ ] Wants to keep exploring (not dumped to a menu)
- [ ] Kecrekan still feels solid; no physics regression
- [ ] Acceptable performance on a mid-range Android device

### Phase D — Expand (only after C)

1. Shell Shore addition adventure + hermit crab / sea star.
2. Kelp Forest subtraction + seahorse.
3. Finger Reef Jarimatika embedded demos (reuse learnMode progression).
4. Richer journal, conservation micro-moments, randomized variants.

---

## 12. Coral Cove vertical slice — definition of done

A playable build where a child can:

1. Launch into a living map (not a dashboard).
2. Enter Coral Cove.
3. Meet and learn about a sea turtle through encounter (not a dialog card).
4. Explore / help in the reef.
5. Complete a guided counting activity on the real Kecrekan.
6. Complete an independent counting challenge.
7. Receive meaningful feedback and a reason to return to the map.
8. See the turtle appear in a simple discovery journal.

Anything less is a visual prototype, not the vertical slice.

---

## 13. Implementation order (recommended next actions)

1. Freeze Kecrekan: run tests; note frozen surface.
2. Progress model extensions + star ID fix.
3. Creature data for Coral Cove turtle (+ optional clownfish).
4. World map v1 replacing home card layout.
5. Adventure beat runner + Coral Cove screen shell.
6. Wire KecrekanStage into counting beats (black-box).
7. Journal stub + unlock sparkle on map.
8. Manual playtest (Phase C).

Do **not** start Shell Shore / Kelp Forest / Finger Reef redesigns until step 8 passes.
