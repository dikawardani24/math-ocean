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

## Reference-led green sea turtle appearance

Tala is modeled as a stylized juvenile green sea turtle (*Chelonia mydas*), not a hawksbill. The visual direction follows these field-identification details:

- A short, blunt head and a single pair of elongated prefrontal scales between the eyes.
- Olive/gray-brown skin, with pale yellow-olive margins around some head scales rather than a uniform mint-green surface.
- A rounded upper jaw and a distinct lower jaw with a serrated cutting edge. Avoid a long hooked beak, oversized duck bill, or human-style smile.
- Head-scale boundaries should be visible at normal phone viewing size, but remain soft and low-contrast so Tala still reads as a friendly companion.

The Blender model uses shallow, head-conforming polygon plates for the visible scutes. The mouth is a compact beak-like opening with a separate lower jaw mounted on an animated hinge; `Eat_Chew` rotates that jaw through repeated bites instead of translating a fixed chin.

Reference reading:
- [NOAA Fisheries — Green Turtle appearance](https://www.fisheries.noaa.gov/species/green-turtle?page=1)
- [Naturalis — Turtles of the World: *Chelonia mydas*](https://turtles.linnaeus.naturalis.nl/linnaeus_ng/app/views/species/taxon.php?id=7972)
- [Smithsonian Ocean — Sea Turtles](https://ocean.si.edu/ocean-life/reptiles/sea-turtles)
- [Wyneken — The Anatomy of Sea Turtles (NOAA technical memorandum)](https://ibimm.org.br/wp-content/uploads/2017/05/Wyneken-2001-The-anatomy-of-sea-turtles.pdf)
