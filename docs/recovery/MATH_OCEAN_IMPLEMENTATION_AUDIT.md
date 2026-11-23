# Math Ocean — Implementation Audit & Feature Classification

## 1. Audit Overview

This audit evaluates the current implementation against the product vision of Math Ocean as an immersive, narrative-driven, interactive underwater adventure game for young children (ages 4–7).

---

## 2. Feature Classification

| Component / File Path | Classification | Rationale & Action Plan |
|---|---|---|
| **Kecrekan Physics & Controller** (`lib/kecrekan/`) | **KEEP** | Robust 5×5 contact physics, rod-locked drag, and midpoint threshold counting. Protected foundation. |
| **Jarimatika Math & 3D Hands** (`lib/jarimatika/`) | **KEEP** | Canonical finger mapping (Right = ones, Left = tens) and 3D hand poses. |
| **World Map** (`lib/world/world_map_screen.dart`) | **IMPROVE** | Living underwater map established; needs richer environmental touch interactions, ambient life, and seamless transition into adventures without fallback to legacy menus. |
| **Coral Cove Adventure** (`lib/adventure/coral_cove_adventure.dart`) | **IMPROVE** | Vertical slice established. Needs robust object-level collection state tracking, immersive creature encounter behavior, and guided-to-independent Kecrekan integration. |
| **Legacy Station Screen** (`lib/screens/station_screen.dart`) | **REMOVE** | Competing educational worksheet hub. Must be fully replaced by in-world exploration and adventure loops. |
| **Creature Catalog & Journal** (`lib/creatures/`, `lib/discovery/`) | **IMPROVE** | Rich biological data exists; discovery must be strictly tied to actual in-world creature encounters rather than automatic mission completion. |
| **Progress Persistence** (`lib/core/progress.dart`) | **IMPROVE** | Unify star IDs and unlock conditions across adventures and discoveries. |
| **Audio & Narration** (`lib/core/audio_service.dart`) | **KEEP & EXPAND** | Retain SFX, ambience, and Tala voice hooks. |

---

## 3. Key Findings & Remediation

1. **Dual System Conflict:** The app previously maintained separate legacy station screens (`StationScreen`) alongside new adventure flows (`CoralCoveAdventure`). We will eliminate legacy station entry points from the world map so all gameplay occurs in-world.
2. **Collection Bug:** The previous collection logic incremented counts sequentially without tracking individual object identity. We will attach collection state directly to tappable environmental items.
3. **Automatic Discovery:** Creatures were occasionally unlocked without active encounters. We will mandate that discovery happens exclusively through active exploration and interaction.
