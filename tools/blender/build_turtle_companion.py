"""Generate Tala, the reusable animated 3D baby green sea turtle.

Run from repository root:
  blender --background --python tools/blender/build_turtle_companion.py

Writes assets/3d/characters/tala_sea_turtle.glb and local .blend / preview outputs.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets/3d/characters")
ARTIFACTS = os.path.join(ROOT, "artifacts/blender/tala")
os.makedirs(OUT, exist_ok=True)
os.makedirs(ARTIFACTS, exist_ok=True)
GLB = os.path.join(OUT, "tala_sea_turtle.glb")
BLEND = os.path.join(ARTIFACTS, "tala_sea_turtle.blend")
PREVIEW = os.path.join(ARTIFACTS, "tala_sea_turtle_preview.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
engines = {item.identifier for item in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
scene.render.engine = next(e for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES") if e in engines)
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 80
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"
scene.render.film_transparent = False
scene.render.filepath = PREVIEW
scene.frame_start = 1
scene.frame_end = 49

def material(name, color, roughness=0.42, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Metallic"].default_value = metallic
    return m

skin = material("Tala | mint green skin", (0.20, 0.72, 0.49), .34)
skin_light = material("Tala | warm light green", (0.42, 0.88, 0.64), .38)
shell = material("Tala | deep jade shell", (0.035, 0.29, 0.25), .3)
shell_light = material("Tala | shell scutes", (0.13, 0.52, 0.37), .34)
shell_edge = material("Tala | shell rim", (0.025, 0.19, 0.19), .38)
belly = material("Tala | pale plastron", (0.76, 0.83, 0.58), .48)
eye_white = material("Tala | eye whites", (1.0, .98, .86), .22)
pupil = material("Tala | dark pupils", (.012, .045, .05), .18)
shine = material("Tala | eye sparkle", (1, 1, 1), .12)
cheek = material("Tala | coral cheeks", (1, .39, .34), .42)
mouth_mat = material("Tala | mouth", (.045, .20, .16), .5)

def smooth(obj):
    if obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = True

def uv(name, location, scale, mat, segments=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    smooth(obj)
    return obj

def parent_to(root, obj):
    obj.parent = root
    return obj

def make_paddle(name, location, scale, rotation, mat):
    obj = uv(name, location, scale, mat, 28, 18)
    obj.rotation_euler = rotation
    return obj

# A named root makes the asset easy to place and animate in Flutter Scene.
root = bpy.data.objects.new("Tala_Root", None)
scene.collection.objects.link(root)

body = parent_to(root, uv("Tala_Body", (0, 0, 0), (.78, 1.02, .36), skin))
parent_to(root, uv("Tala_Belly", (0, .04, -.22), (.67, .89, .19), belly))

# Shell rim and domed carapace, raised above the body.
parent_to(root, uv("Tala_Shell_Rim", (0, .12, .28), (.94, 1.04, .34), shell_edge, 40, 24))
parent_to(root, uv("Tala_Shell_Dome", (0, .12, .38), (.86, .96, .43), shell, 48, 28))
# Rounded scute plates on the visible dome. Their raised silhouettes read clearly
# at phone size without relying on a high-resolution texture.
scutes = [
    (-.39, -.31, .64, .29, .34), (0, -.39, .72, .34, .36), (.39, -.31, .64, .29, .34),
    (-.48, .13, .62, .27, .34), (0, .12, .79, .35, .37), (.48, .13, .62, .27, .34),
    (-.34, .53, .59, .28, .29), (.34, .53, .59, .28, .29),
]
for i, (x, y, z, sx, sy) in enumerate(scutes):
    plate = uv("Tala_Shell_Scute_%02d" % i, (x, y, z), (sx, sy, .055), shell_light, 24, 14)
    parent_to(root, plate)

# Four broad, rounded flippers with distinct names for animation.
flippers = {}
flippers["FrontLeft"] = parent_to(root, make_paddle("Tala_Front_Flipper_L", (-.72, -.48, -.02), (.31, .67, .16), (0, -.28, -.42), skin))
flippers["FrontRight"] = parent_to(root, make_paddle("Tala_Front_Flipper_R", (.72, -.48, -.02), (.31, .67, .16), (0, .28, .42), skin))
flippers["RearLeft"] = parent_to(root, make_paddle("Tala_Rear_Flipper_L", (-.64, .72, -.02), (.25, .48, .14), (0, -.22, -.38), skin_light))
flippers["RearRight"] = parent_to(root, make_paddle("Tala_Rear_Flipper_R", (.64, .72, -.02), (.25, .48, .14), (0, .22, .38), skin_light))

# Neck and oversized friendly head at the front (-Y).
neck = parent_to(root, uv("Tala_Neck", (0, -.83, .08), (.43, .53, .32), skin))
head = parent_to(root, uv("Tala_Head", (0, -1.18, .18), (.58, .56, .49), skin_light, 40, 28))
# Eyes look slightly forward and outwards.
for side, x in (("L", -.30), ("R", .30)):
    parent_to(root, uv("Tala_EyeWhite_" + side, (x, -1.59, .39), (.19, .105, .22), eye_white))
    parent_to(root, uv("Tala_Pupil_" + side, (x * 1.02, -1.681, .37), (.092, .052, .125), pupil))
    parent_to(root, uv("Tala_EyeSparkle_" + side, (x * 1.02 - .035, -1.727, .425), (.035, .022, .045), shine, 20, 12))
    parent_to(root, uv("Tala_Cheek_" + side, (x * 1.48, -1.55, .08), (.105, .045, .065), cheek, 20, 12))
# Tiny rounded beak and a simple curved smile. Keep the mouth small:
# the eyes and cheek shapes should do most of the character's expression.
beak = parent_to(root, uv(
    "Tala_Upper_Beak",
    (0, -1.715, -.005),
    (.115, .052, .065),
    skin_light,
    32,
    20,
))
# A narrow smile sits directly on the muzzle surface, with raised corners.
mouth_curve = bpy.data.curves.new("Tala_Smile_Seam_Curve", type="CURVE")
mouth_curve.dimensions = "3D"
mouth_curve.resolution_u = 20
mouth_curve.bevel_depth = .009
mouth_curve.bevel_resolution = 4
spline = mouth_curve.splines.new("BEZIER")
spline.bezier_points.add(4)
smile_points = [
    (-.155, -1.697, -.045),
    (-.105, -1.704, -.092),
    (0.0, -1.675, -.115),
    (.105, -1.704, -.092),
    (.155, -1.697, -.045),
]
for point, coordinate in zip(spline.bezier_points, smile_points):
    point.co = coordinate
    point.handle_left_type = "AUTO"
    point.handle_right_type = "AUTO"
smile = bpy.data.objects.new("Tala_Smile_Seam", mouth_curve)
scene.collection.objects.link(smile)
smile.data.materials.append(mouth_mat)
parent_to(root, smile)

# A tiny lower lip/jaw moves down for each chew instead of stretching a large
# dark mouth shape across the face.
jaw = parent_to(root, uv(
    "Tala_Lower_Jaw",
    (0, -1.635, -.155),
    (.145, .072, .045),
    skin,
    28,
    18,
))
# Small tail visible behind the shell.
tail = parent_to(root, uv("Tala_Tail", (0, 1.02, -.02), (.19, .38, .13), skin))

# Keep mesh origins at their own centers. Animate transforms around their natural
# centers for readable flipper paddling and head/jaw movement.
def set_action(obj, action_name, keys, data_path="rotation_euler", index=0):
    obj.animation_data_create()
    action = bpy.data.actions.new(name=action_name + "_" + obj.name)
    obj.animation_data.action = action
    for frame, value in keys:
        if data_path == "scale":
            obj.scale[index] = value
        elif data_path == "location":
            obj.location[index] = value
        else:
            obj.rotation_euler[index] = value
        obj.keyframe_insert(data_path=data_path, index=index, frame=frame, group=action_name)
    # Put the action into an NLA strip so the next action can be authored on the
    # same object. Matching track names across objects combine into one glTF clip.
    track = obj.animation_data.nla_tracks.new()
    track.name = action_name
    strip = track.strips.new(action_name, 1, action)
    strip.name = action_name
    obj.animation_data.action = None

# Every clip has an explicit neutral key at its beginning and end.
for name, obj in flippers.items():
    axis = 1 if "Front" in name else 1
    base = obj.rotation_euler[axis]
    amp = .22 if "Front" in name else .14
    set_action(obj, "Idle_Swim", [(1, base), (13, base + amp), (25, base), (37, base - amp), (49, base)])
    set_action(obj, "Eat_Chew", [(1, base), (7, base + amp * .55), (13, base - amp * .45), (19, base + amp * .4), (25, base)])
    set_action(obj, "Happy_Reaction", [(1, base), (8, base - amp * 1.4), (16, base + amp * 1.4), (24, base), (32, base)])

set_action(head, "Idle_Swim", [(1, 0), (13, .035), (25, 0), (37, -.025), (49, 0)], "rotation_euler", 0)
set_action(head, "Eat_Chew", [(1, 0), (5, .10), (10, -.06), (15, .10), (20, -.04), (25, 0)], "rotation_euler", 0)
set_action(head, "Happy_Reaction", [(1, 0), (8, -.10), (16, .06), (24, 0), (32, -.03)], "rotation_euler", 0)
set_action(jaw, "Eat_Chew", [(1, -.155), (4, -.205), (8, -.155), (12, -.205), (16, -.155), (20, -.205), (24, -.155), (28, -.155)], "location", 2)
set_action(jaw, "Happy_Reaction", [(1, -.155), (8, -.18), (16, -.155), (24, -.175), (32, -.155)], "location", 2)
set_action(tail, "Idle_Swim", [(1, 0), (13, .12), (25, 0), (37, -.12), (49, 0)], "rotation_euler", 2)

# Use NLA tracks as glTF animation clips. All mesh geometry remains shared by the
# model; only compact transform channels vary between clips.
scene.frame_set(1)
bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    if obj.type in {"MESH", "EMPTY"}:
        obj.select_set(True)
bpy.context.view_layer.objects.active = root

# Studio setup for a square preview; lights/camera are excluded from the GLB.
world = bpy.data.worlds.new("Tala studio water")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.025, .22, .29, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .65
scene.world = world
bpy.ops.object.light_add(type="AREA", location=(-4, -5, 7))
key = bpy.context.object
key.name = "Preview_Key"
key.data.energy = 900
key.data.shape = "DISK"
key.data.size = 5
key.rotation_euler = (Vector((0, 0, 0)) - key.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.light_add(type="AREA", location=(4, 1, 4))
fill = bpy.context.object
fill.name = "Preview_Fill"
fill.data.energy = 650
fill.data.size = 4
fill.rotation_euler = (Vector((0, 0, 0)) - fill.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.camera_add(location=(0, -5.8, 2.25))
camera = bpy.context.object
camera.name = "Preview_Camera"
camera.rotation_euler = (Vector((0, -.2, .1)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 4.5
scene.camera = camera
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.render.render(write_still=True)

# Select only character hierarchy for export. NLA strips are exported as named clips.
bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    if obj == root or obj.parent == root:
        obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_animations=True,
    export_nla_strips=True,
    export_force_sampling=True,
    export_frame_range=True,
)
print("Tala 3D turtle generated:", GLB)
