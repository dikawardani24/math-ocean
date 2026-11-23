#!/usr/bin/env python3
"""Procedural cute sea-turtle head for Math Ocean.
Run with Blender 4.x/5.x: blender --background --python tools/blender/build_turtle_head.py
Outputs a standalone .blend, preview PNG, and GLB under assets/3d/turtle_head/.
"""
import bpy, math, os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "3d", "turtle_head")
os.makedirs(OUT, exist_ok=True)

# Front of the face points toward -Y. Keep the model centered and compact.
def mat(name, color, rough=0.38):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    return m

skin = mat("Tala | mint seafoam skin", (0.24, 0.72, 0.48))
skin_light = mat("Tala | muzzle light", (0.42, 0.86, 0.61))
dark = mat("Mouth | deep teal", (0.035, 0.12, 0.13), 0.3)
white = mat("Eyes | warm ivory", (0.98, 0.99, 0.94), 0.22)
iris = mat("Eyes | ocean brown", (0.22, 0.12, 0.055), 0.24)
pupil = mat("Eyes | dark pupil", (0.025, 0.035, 0.04), 0.18)
glint = mat("Eyes | catchlight", (1, 1, 1), 0.1)
pink = mat("Tongue | coral pink", (0.95, 0.34, 0.43))
blush = mat("Cheeks | soft coral", (1.0, 0.43, 0.39))

def smooth(obj):
    if obj.type == "MESH":
        for f in obj.data.polygons: f.use_smooth = True
    return obj

def uv(name, loc, scale, material, seg=48, rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; smooth(o); o.data.materials.append(material
)
    return o

def curve(name, points, radius, material):
    c=bpy.data.curves.new(name, "CURVE"); c.dimensions="3D"; c.resolution_u=24
    c.bevel_depth=radius; c.bevel_resolution=4
    s=c.splines.new("BEZIER"); s.bezier_points.add(len(points)-1)
    for b,p in zip(s.bezier_points,points):
        b.co=p; b.handle_left_type="AUTO"; b.handle_right_type="AUTO"
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.data.materials.append(material); return o

# Clean scene
bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
# Head silhouette: wide forehead, softly tapering toward a rounded muzzle.
head=uv("Head | soft pear-shaped cranium", (0,0,0.15), (0.78,0.53,0.68), skin)
# Muzzle volume is split into two gentle lobes, with no sharp beak/nose.
uv("Muzzle | left cheek-lobe", (-0.18,-0.47,-0.13), (0.39,0.34,0.25), skin_light)
uv("Muzzle | right cheek-lobe", (0.18,-0.47,-0.13), (0.39,0.34,0.25), skin_light)
uv("Muzzle | bridge", (0,-0.48,-0.02), (0.43,0.32,0.24), skin_light)
# Recessed smile cavity in front of lower muzzle; the jaw remains an independent animation part.
mouth=uv("Mouth | cavity", (0,-0.715,-0.30), (0.34,0.105,0.13), dark)
jaw=uv("Jaw | animated lower jaw", (0,-0.57,-0.42), (0.38,0.27,0.16), skin_light)
jaw_pivot=bpy.data.objects.new("Jaw | pivot (animate rotation X)", None); bpy.context.collection.objects.link(jaw_pivot)
jaw_pivot.location=(0,-0.52,-0.35); jaw.parent=jaw_pivot; jaw.location=(0,-0.08,-0.07)
tongue=uv("Mouth | tongue", (0,-0.82,-0.35), (0.13,0.045,0.035), pink)
tongue.parent=jaw_pivot
# Tiny curved smile corners, embedded into the muzzle.
curve("Smile | left corner", [(-0.33,-0.70,-0.28),(-0.29,-0.73,-0.34),(-0.22,-0.72,-0.36)], 0.025, dark)
curve("Smile | right corner", [(0.33,-0.70,-0.28),(0.29,-0.73,-0.34),(0.22,-0.72,-0.36)], 0.025, dark)
# Eyes: oversized but set into the face, not bug-eyed or protruding.
for side, x in [("L",-0.34),("R",0.34)]:
    uv(f"Eye {side} | socket", (x,-0.39,0.43), (0.235,0.19,0.29), skin)
    uv(f"Eye {side} | sclera", (x,-0.51,0.44), (0.185,0.135,0.235), white)
    uv(f"Eye {side} | iris", (x+0.035,-0.625,0.43), (0.105,0.065,0.135), iris)
    uv(f"Eye {side} | pupil", (x+0.04,-0.674,0.43), (0.065,0.038,0.09), pupil)
    uv(f"Eye {side} | sparkle", (x+0.005,-0.706,0.49), (0.035,0.022,0.045), glint)
# Eyebrows subtle and friendly; keep clear of eye shape.
curve("Brow L", [(-0.53,-0.46,0.72),(-0.36,-0.49,0.79),(-0.19,-0.46,0.72)], 0.035, skin_light)
curve("Brow R", [(0.19,-0.46,0.72),(0.36,-0.49,0.79),(0.53,-0.46,0.72)], 0.035, skin_light)
# Tiny nostrils, softened and symmetrical.
for x in [-0.075,0.075]:
    uv("Nostril", (x,-0.765,0.015), (0.026,0.018,0.035), dark, 24, 16)
# Cheek blush: subtle ellipsoids placed on face.
uv("Blush L", (-0.58,-0.48,-0.16), (0.105,0.035,0.07), blush, 32, 20)
uv("Blush R", (0.58,-0.48,-0.16), (0.105,0.035,0.07), blush, 32, 20)

# A short neck stub is included as a connection guide, intended to overlap the body/shell.
neck=uv("Neck | body connection", (0,-0.42,-0.50), (0.43,0.35,0.27), skin)
# Neck goes behind the jaw and can be hidden/trimmed when integrated with existing turtle body.

# Camera, lighting, ground-free transparent render.
bpy.ops.object.camera_add(location=(3.1,-6.4,2.1))
cam=bpy.context.object; cam.name="Preview Camera"
target=Vector((0,-0.18,0.08)); direction=target-cam.location
cam.rotation_euler=direction.to_track_quat("-Z","Y").to_euler(); cam.data.lens=55
bpy.context.scene.camera=cam
for loc,energy,size in [(( -3,-4,4),500,4),((3,-2,2),350,3),((0,2,3),450,3)]:
    bpy.ops.object.light_add(type="AREA", location=loc); l=bpy.context.object; l.data.energy=energy; l.data.shape="DISK"; l.data.size=size; l.rotation_euler=(target-l.location).to_track_quat("-Z","Y").to_euler()
scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE_NEXT"
scene.render.resolution_x=1024; scene.render.resolution_y=1024; scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"; scene.render.film_transparent=True
scene.render.filepath=os.path.join(OUT,"turtle_head_preview.png")
scene.world.color=(0.08,0.08,0.08)
# Neutral studio color management.
scene.view_settings.view_transform="AgX"
# Save a reusable native file and export the head assembly.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"turtle_head.blend"))
bpy.ops.render.render(write_still=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,"turtle_head.glb"), export_format="GLB")
print("Turtle head outputs:", OUT)
