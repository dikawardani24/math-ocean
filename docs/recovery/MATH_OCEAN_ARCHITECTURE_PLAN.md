# Math Ocean — Architecture & Refactoring Plan

## 1. Architectural Boundaries

- **World Environment (`lib/world/`):** Living map, ambient marine motion, interactive landmarks.
- **Adventure Orchestration (`lib/adventure/`):** State machine for encounters, exploration, teaching, and challenge phases.
- **Kecrekan Physics (`lib/kecrekan/`):** Immutable physics and gesture solver for bead frames.
- **Jarimatika (`lib/jarimatika/`):** Hand pose models and canonical arithmetic mapping.
- **Creature Discovery (`lib/creatures/`, `lib/discovery/`):** Entity catalog and journal state.
- **Persistence (`lib/core/`):** Progress, unlocked status, and audio settings.

---

## 2. Refactoring Steps

1. Remove entry points to legacy `StationScreen` from the world map.
2. Refactor `CoralCoveAdventure` to track individual object collection states.
3. Ensure creature discovery is strictly tied to encounter completion.
4. Verify Kecrekan bead-to-object synchronization.
5. Run test suite and verify build health.
