# Tala — 3D sea turtle companion

Generate the animated GLB from the repository root with Blender 5.3+:

\`\`\`bash
blender --background --python tools/blender/build_turtle_companion.py
\`\`\`

The script writes:

- \`assets/3d/characters/tala_sea_turtle.glb\` — runtime model with named clips
- \`artifacts/blender/tala/tala_sea_turtle.blend\` — editable Blender source
- \`artifacts/blender/tala/tala_sea_turtle_preview.png\` — rendered preview

Then run:

\`\`\`bash
flutter pub get
flutter run
\`\`\`

## Animation clips

- \`Idle_Swim\` — gentle flipper and tail movement
- \`Eat_Chew\` — head dip, jaw opening and closing, and flipper reaction
- \`Happy_Reaction\` — short celebratory flipper movement

The Coral Cove adventure switches between these clips based on the current gameplay state. Feeding is serialized: one piece is accepted, the bite clip plays, and only after it finishes is that piece counted as eaten.
