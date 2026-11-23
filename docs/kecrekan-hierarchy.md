# Kecrekan 3D hierarchy and runtime contract

This document describes the Blender source, exported glTF scene and Flutter
runtime contract.

## Source and rebuild

- `tools/blender/build_kecrekan.py`: reproducible Blender asset generator.
- `assets/3d/kecrekan/kecrekan.blend`: editable source scene.
- `assets/3d/kecrekan/kecrekan.glb`: runtime asset loaded by
  `flutter_scene`.

Rebuild from the repository root:

```bash
blender -b -P tools/blender/build_kecrekan.py -- --mode full
```

The rebuild writes the GLB, editable blend file and studio preview.

## Design contract — version 4

The instrument is intentionally simple and tactile:

- Four chunky, rounded ocean-teal rails form a sturdy rectangular frame.
- Two subtle champagne-metal accents finish the inner top and bottom edges.
- Up to five satin-silver rods cross the opening; runtime hides unused rows and compacts the frame around the active challenge.
- Each rod has exactly five large, rounded, softly glossy beads.
- Five ocean-inspired bead colours alternate by row.
- No character face, butterfly wings, loop ears, number plaques, stickers,
  coral props or seaweed ornaments. The beads and their movement are the focus.

The inner faces of the side posts align with the outer bead surfaces at each travel endpoint, eliminating dead space at the ends of the rod. The frame is kept visually quiet so the child can identify the beads quickly
and the physical counting action remains the dominant interaction.

## Runtime node names

### Beads — `Bead_R{rod}_{index}`

- 25 nodes total: rods 0–4, bead indices 00–04.
- Every bead remains an independent node with its origin at the bead centre.
- Bead meshes are shared by row colour for rendering efficiency.
- Custom properties preserve `role`, `rod_index`, `bead_index`,
  `group`, `color` and `active_value`.

### Rods

- `Rod_{rod}`: five satin-metal cylinders.
- `RodCap_{rod}_{L|R}`: gold-toned end caps.
- `FiveMarker_{rod}`: slim centre marker for the five-bead row.

### Frame

- `Frame_TopRail`, `Frame_BottomRail`
- `Frame_LeftPost`, `Frame_RightPost`
- `Frame_TopAccent`, `Frame_BottomAccent`

The controller hides unused rows, repositions the visible rows, and shortens the frame vertically to fit the active challenge. Bead nodes remain independently draggable.

## Coordinates and dimensions

| Quantity | Value |
| --- | --- |
| Maximum rows | 5 |
| Beads per row | 5 |
| Maximum beads | 25 |
| Rod length | 1.80 |
| Rod X extent | −0.90 … +0.90 |
| Bead X extent (centres) | −0.675 … +0.675 |
| Frame inner X extent | −0.81 … +0.81 |
| Bead spacing | 0.27 (touching) |
| Bead radius | 0.15 |
| Bead X scale | 0.90 |
| Active row spacing | 0.52 |

Blender is Z-up; the glTF exporter converts the scene to Y-up. The child-facing
surface is on runtime −Z, matching the Flutter camera.

## Runtime mapping

`lib/kecrekan/kecrekan_math.dart` owns the count state:

```dart
rodCounts[rod] ∈ [0, 5]
total = sum(rodCounts)
```

The controller collects nodes matching `Bead_R*`, then moves only those bead
nodes. The contact solver, touch picking, drag offset and counting thresholds
remain independent of the visual redesign.

## Validation checklist

- Exactly 25 nodes named `Bead_R0_00` … `Bead_R4_04`.
- Every bead has its own transform and remains independently draggable.
- The four frame rails and only the challenge-required rods are visible without clipping.
- No cameras or lights are included in the exported GLB.
- The exported root contains the frame, rods and beads only.
