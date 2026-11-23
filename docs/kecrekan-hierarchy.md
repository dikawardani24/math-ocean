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

## Design contract — version 3

The instrument is intentionally simple and tactile:

- Four chunky, rounded ocean-teal rails form a sturdy rectangular frame.
- Two subtle champagne-metal accents finish the inner top and bottom edges.
- Ten satin-silver rods cross the opening.
- Each rod has ten large, rounded, softly glossy beads.
- Five ocean-inspired bead colours alternate by row, with a subtle light/dark
  split to make the five-bead grouping easier to perceive.
- No character face, butterfly wings, loop ears, number plaques, stickers,
  coral props or seaweed ornaments. The beads and their movement are the focus.

The frame is kept visually quiet so the child can identify the beads quickly
and the physical counting action remains the dominant interaction.

## Runtime node names

### Beads — `Bead_R{rod}_{index}`

- 100 nodes total: rods 0–9, bead indices 00–09.
- Every bead remains an independent node with its origin at the bead centre.
- Bead meshes are shared by colour/shade for rendering efficiency.
- Custom properties preserve `role`, `rod_index`, `bead_index`,
  `group`, `color` and `active_value`.

### Rods

- `Rod_{rod}`: ten satin-metal cylinders.
- `RodCap_{rod}_{L|R}`: gold-toned end caps.
- `FiveMarker_{rod}`: slim centre marker for the five/five split.

### Frame

- `Frame_TopRail`, `Frame_BottomRail`
- `Frame_LeftPost`, `Frame_RightPost`
- `Frame_TopAccent`, `Frame_BottomAccent`

The frame and rods never move during play. Only bead node translations are
updated by the controller.

## Coordinates and dimensions

| Quantity | Value |
| --- | --- |
| Rods | 10 |
| Beads per rod | 10 |
| Rod length | 2.70 |
| Rod X extent | −1.35 … +1.35 |
| Bead X extent | −1.10 … +1.10 |
| Bead spacing | 0.22 |
| Bead radius | 0.105 |
| Bead X scale | 0.82 |
| Row height step | 0.285 |

Blender is Z-up; the glTF exporter converts the scene to Y-up. The child-facing
surface is on runtime −Z, matching the Flutter camera.

## Runtime mapping

`lib/kecrekan/kecrekan_math.dart` owns the count state:

```dart
rodCounts[rod] ∈ [0, 10]
total = sum(rodCounts)
```

The controller collects nodes matching `Bead_R*`, then moves only those bead
nodes. The contact solver, touch picking, drag offset and counting thresholds
remain independent of the visual redesign.

## Validation checklist

- Exactly 100 nodes named `Bead_R0_00` … `Bead_R9_09`.
- Every bead has its own transform and remains independently draggable.
- The four frame rails and all rods are visible without horizontal clipping.
- No cameras or lights are included in the exported GLB.
- The exported root contains the frame, rods and beads only.
