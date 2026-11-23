# Kecrekan asset

The kecrekan is generated from `tools/blender/build_kecrekan.py`.

## Design

The current design is a clean, sturdy ocean-teal counting frame with rounded
rails, satin-metal rods and larger softly glossy beads. It deliberately removes
the previous butterfly/character decorations so the beads are the visual focus.

## Rebuild

From the repository root:

```bash
blender -b -P tools/blender/build_kecrekan.py -- --mode full
```

This generates:

- `kecrekan.glb` — runtime glTF binary.
- `kecrekan.blend` — editable Blender source.
- `kecrekan_preview.png` — studio preview.

The GLB embeds its materials and is the only model file needed at runtime.

## Runtime contract

- 10 rods × 10 beads.
- Every bead is an independent node named `Bead_R{rod}_{index}`.
- Bead node transforms remain compatible with the existing Flutter controller.
- The contact movement, screen-space picking and counting logic are unchanged.

See [the hierarchy contract](../../../docs/kecrekan-hierarchy.md) for dimensions
and node details.
