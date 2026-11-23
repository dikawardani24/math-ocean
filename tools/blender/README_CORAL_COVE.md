# Coral Cove Blender environment

This generator creates the 3D reef environment used by the Coral Cove adventure.

From the repository root, run:

```bash
blender --background --python tools/blender/build_coral_cove.py
```

The generator writes directly to `assets/3d/coral_cove/`:

- `coral_cove_environment.glb` — runtime scene loaded by Flutter
- `artifacts/blender/coral_cove/coral_cove_environment.blend` — editable Blender source
- `artifacts/blender/coral_cove/coral_cove_preview.png` — render for visual review

Then run the app normally:

```bash
flutter pub get
flutter run
```

No manual asset copying or path editing is required. The generated GLB is intentionally
not committed; run the generator once after pulling the branch. The editable .blend
and preview are local outputs too.
