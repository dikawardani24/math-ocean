# Math Ocean — Technical Audit & Architecture Plan

## 1. Codebase Audit Summary

### Architecture Overview
The existing project is a Flutter application built with Provider state management, Flame/CustomPainter 3D rendering for Kecrekan and Hands, audio playback via audioplayers, and persistent progress via SharedPreferences.

### Component Classification

| Component | Path | Verdict | Action |
|---|---|---|---|
| Kecrekan Physics & Controller | `lib/kecrekan/` | **Preserve & Protect** | Keep frozen. 5x5 grid, contact push, rod-locked drag. |
| Jarimatika Math & 3D Hands | `lib/jarimatika/` | **Preserve & Protect** | Keep canonical finger mapping (Right = ones, Left = tens). |
| World Map & Navigation | `lib/screens/`, `lib/world/` | **Redesign** | Transform station picker into an explorable interactive world map. |
| Audio & Feedback | `lib/core/audio_service.dart`, `feedback.dart` | **Preserve & Expand** | Retain SFX and ambience; add contextual narration hooks. |
| Progress Persistence | `lib/core/progress.dart` | **Repair & Reuse** | Fix star ID mismatch between missions and challenges. |
| Adventure / Missions | `lib/adventure/` | **Expand** | Implement in-world adventure beats, creature encounters, and guided teaching. |

---

## 2. Technical Debt & Fixes

1. **Star ID Desync:** `ProgressController` tracks challenge stars using `challenge_*` keys while `totalStars` ignores them. We will unify star calculation.
2. **Navigation Layers:** Flatten deep dialog stacks in favor of direct in-world adventure entry.
3. **Widget Rebuilds:** Optimize 2D canvas renders and gesture listeners during Kecrekan interactions.

---

## 3. Implementation Roadmap

- **Phase 0:** Research (Completed)
- **Phase 1:** Product Design (Completed)
- **Phase 2:** Technical Audit (Completed)
- **Phase 3:** Coral Cove Vertical Slice (World map → Exploration → Creature encounter → Guided teaching → Kecrekan counting → Reward & completion)
- **Phase 4:** Validation & Testing
- **Phase 5:** Expand Shell Shore, Kelp Forest, Finger Reef
- **Phase 6:** Full Integration & Polish
