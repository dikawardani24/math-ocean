# Kecrekan asset deliverables

This folder contains the complete source and runtime deliverables for the
Kecrekan counting frame.

| File | Description |
| --- | --- |
| `kecrekan.blend` | Full editable Blender scene: frame, rods, 100 beads, stickers, materials, studio lighting and preview camera |
| `kecrekan.glb` | Runtime glTF binary loaded by the Flutter app; Y-up, no cameras or lights, custom bead properties exported |
| `kecrekan_seaglass.png` | Generated purple striped sea-glass texture for the frame body |
| `kecrekan_preview.png` | Rendered studio preview of the current asset |
| `kecrekan.blend1` | Blender backup file created by the save operation |

## Rebuild

From the repository root:

```bash
blender -b -P tools/blender/build_kecrekan.py -- --mode full
```

The generator is deterministic: it resets the scene, rebuilds every object,
material and texture, saves the `.blend`, exports the `.glb`, and renders the
preview in one pass.

One-rod proof of concept (used during development):

```bash
blender -b -P tools/blender/build_kecrekan.py -- --mode poc
```

POC output is written to `assets/3d/kecrekan/poc/`.

## Runtime contract

- 10 rods × 10 beads, every bead is an independent node named
  `Bead_R{rod}_{index}` and can be moved without affecting any other bead.
- Beads start parked on the right in the GLB; the app recomputes positions from
  the maths state on load.
- Counted beads pack screen-left, uncounted beads pack screen-right.
- Full node names, dimensions, materials and the maths mapping are documented
  in [`../../../docs/kecrekan-hierarchy.md`](../../../docs/kecrekan-hierarchy.md).

## Notes

- The `.blend` is saved with Blender 4.x and uses the Principled BSDF.
- The GLB embeds the sea-glass texture, so copying the `.glb` alone is enough
  for the runtime.
- Bead meshes are shared across nodes for efficiency (five colours × two
  shades), while transforms remain per bead.
