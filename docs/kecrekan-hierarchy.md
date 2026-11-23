# Kecrekan 3D hierarchy and runtime contract

This document is the contract between the Blender source and the Flutter
runtime. It describes the exported glTF scene, the meaning of every node family,
the coordinate system, and how the maths layer drives bead positions.

## Source files

| File | Purpose |
| --- | --- |
| `kecrekan.blend` | Editable Blender scene, studio lights and camera, source of the GLB |
| `kecrekan.glb` | Runtime asset loaded by `flutter_scene` (`assets/3d/kecrekan/kecrekan.glb`) |
| `kecrekan_seaglass.png` | Generated purple sea-glass texture used by the frame |
| `kecrekan_preview.png` | Studio render of the current asset |
| `tools/blender/build_kecrekan.py` | Reproducible generator for all of the above |

Rebuild:

```bash
blender -b -P tools/blender/build_kecrekan.py -- --mode full
```

`--mode poc` builds the small one-rod proof-of-concept instead.

## Scene root and export

The scene has one root empty, `Kecrekan_Root`. All 195 renderable children are
parented to it and exported as a flat node list under that root.

Export settings used by the generator:

- glTF 2.0 binary (`.glb`)
- `use_selection=True` with the whole root tree selected
- modifiers applied, custom properties exported as glTF `extras`
- cameras and lights excluded
- Y-up conversion enabled (`export_yup=True`)
- materials and embedded images exported, animations disabled

Because Blender is Z-up and glTF is Y-up, `ROW_Z` in the generator becomes the
vertical Y coordinate in the GLB. The face, numbers and stickers sit on the
surface that becomes runtime **−Z**; the Flutter camera looks from −Z so the
friendly side faces the child.

## Node families

### Beads — `Bead_R{rod}_{index}`

- `rod` is `0`–`9`, `index` is `00`–`09`.
- 100 nodes total, each independently addressable and movable.
- Meshes are shared for efficiency: five bead colours × deep/light shade = ten
  mesh variants. Sharing meshes does not share transforms.
- Bead origin is the bead centre, so moving a node along local X moves only that
  bead.
- Custom properties:
  - `role = "bead"`
  - `rod_index` (0–9)
  - `bead_index` (0–9)
  - `group` (`5` for index 0–4, `10` for index 5–9)
  - `color` (colour name)
  - `active_value = 1`

Rest state in the GLB has every bead parked on the right-hand side of its rod
(count zero). The runtime overrides node positions after load from the maths
state, so the saved scene is not a gameplay state.

### Rods — `Rod_{rod}`, `RodCap_{rod}_{L|R}`, `FiveMarker_{rod}`

- Ten polished metal cylinders, length `2.70`, radius `0.024`, at
  `x = 0` and the row height.
- Two gold end caps per rod at `x = −1.35` and `+1.35`.
- One slim gold five-marker ring per rod at the centre, so a five split is easy
  to read.

### Frame — `Frame_*`

| Node | Role |
| --- | --- |
| `Frame_Body` | Chunky rounded outer ring with a real opening for the rods; purple striped sea-glass |
| `Frame_LipTop/Bottom/Left/Right` | Gold trim around the bead opening |
| `Frame_Loop_0/1`, `Frame_LoopRim_0/1`, `Frame_EarPearl_0/1` | Two loop “ears” with gold rims and pearl tops |
| `Frame_Face`, `Frame_EyeWhite_0/1`, `Frame_Pupil_0/1`, `Frame_Cheek_0/1`, `Frame_Smile` | Smiling face |
| `Frame_Wing_0/1`, `Frame_Foot_0/1`, `Frame_BottomLobe_0..2` | Friendly lower body and feet |
| `Frame_Number_1..5`, `Frame_NumberPlate_1..5` | Left-side number plates 1–5 |

The frame body, lips, loops and face are separate nodes so the GLB remains
easy to edit, but the runtime never moves them.

### Decor and stickers — `Decor_*`, `Sticker_*`

- `Decor_Coral_*`, `Decor_CoralTip_*`, `Decor_Seaweed_*`,
  `Decor_BaseShell_*`: fixed coral, seaweed and shell details around the frame.
- `Sticker_Starfish`, `Sticker_Shell`, `Sticker_Fish`, `Sticker_Crab`,
  `Sticker_Butterfly`: five cute sea stickers on the frame.

All decor is visual only and has no gameplay state.

## Coordinates and dimensions

| Quantity | Value |
| --- | --- |
| Rods | 10 |
| Beads per rod | 10 |
| Rod length | 2.70 |
| Rod X extent | −1.35 … +1.35 |
| Bead X extent | −1.10 … +1.10 |
| Bead spacing | 0.22 |
| Bead radius | 0.095 (X scaled to 0.62, giving flattened discs) |
| Row heights (`ROW_Z`) | −1.28, −0.995, −0.71, … +1.285 (step 0.285) |

In the GLB, these become:

- bead `translation = [x, y, 0]` with Y equal to the source `ROW_Z`
- rod 0 at Y ≈ −1.28 and rod 9 at Y ≈ +1.285
- bead X from −0.88 to +1.10 at rest (index 0 furthest right)

The packing span is exactly ten bead slots (`rightX - leftX == 10 * spacing`).
That is deliberate: a bead crossing from the uncounted group to the counted
group moves by one spacing. With a wider span it had to jump a two-slot hole,
which made a one-bead gesture look like three or four beads moving.

## Runtime mapping

`lib/kecrekan/kecrekan_math.dart` owns the state:

```dart
rodCounts[rod] ∈ [0, 10]
total = sum(rodCounts)
```

`KecrekanMath.beadX(index, count)` maps each bead to a slot:

- counted beads (`index >= 10 - count`) pack at
  `leftX + (9 - index) * spacing`, so highest indices are furthest screen-left;
- uncounted beads pack at `rightX - index * spacing`, so index 0 is furthest
  screen-right;
- exactly one empty slot separates the two groups, and the five-bead marker at
  `x = 0` sits in that slot at a five/five split.

The controller (`kecrekan_controller.dart`) imports the GLB, walks the node tree,
collects `Bead_R*` nodes into `KecrekanBead` objects, and then drives every bead
from the maths state. A spring (`tick`) moves each bead toward its target X:

1. Tap a bead: the raycast returns the bead node, and its row count moves by
   one (uncounted → counted, counted → uncounted).
2. Drag a bead: pointer X is projected onto the bead plane, converted to a slot
   delta, and applied to the grabbed row from the pointer-down snapshot.
3. Reset: `resetTo(initialCount)` restores the mission's start and the springs
   animate every bead back into place.
4. The total badge and the mission check always read `math.total`; the 3D scene
   is never the source of truth.

## Material names

`Bead_Turquoise_Deep`, `Bead_Turquoise_Light`, `Bead_Coral_Deep`,
`Bead_Coral_Light`, `Bead_SunGold_Deep`, `Bead_SunGold_Light`,
`Bead_Seafoam_Deep`, `Bead_Seafoam_Light`, `Bead_Tangerine_Deep`,
`Bead_Tangerine_Light`, `Gold_Trim`, `Shell_White`, `Coral_Orange`,
`Coral_Pink`, `Seaweed_Green`, `Frame_SeaGlass`, `Frame_SeaGlassLight`,
`Face_Cheek`, `Face_EyeWhite`, `Face_EyeDark`, `Pearl_Gold`, `Number_Ink`,
`Number_Plate`, `Rod_PolishedMetal`, `Sticker_Violet`, `Turtle_TealLight`.

`Frame_Body` uses `Frame_SeaGlass`, which samples the embedded generated
`kecrekan_seaglass.png` texture. The texture is tiled/striped to read as chunky
purple sea glass rather than flat paint.

## Validation checklist

- 100 `Bead_R*` nodes exist, named `Bead_R0_00` … `Bead_R9_09`.
- Every bead node has its own translation in the GLB.
- The frame faces −Z at runtime (face, numbers, stickers visible from the
  camera).
- The frame opening is empty geometry: beads are not parented to the frame.
- `Kecrekan_Root` is the only scene root and has 195 children.
- The GLB contains no cameras or lights.
