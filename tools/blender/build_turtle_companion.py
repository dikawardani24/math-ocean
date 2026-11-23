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

# Green turtles have olive/grey-brown skin with pale margins around many
# head scales. Keep the palette soft and child-friendly, but avoid mint-green
# plastic skin.
skin = material("Tala | muted olive skin", (0.31, 0.39, 0.30), .56)
skin_light = material("Tala | warm olive skin", (0.43, 0.48, 0.34), .52)
skin_scale_edge = material("Tala | pale olive scale margins", (0.62, 0.59, 0.40), .58)
skin_scale_fill = material("Tala | head scale centers", (0.39, 0.45, 0.32), .54)
skin_scale_alt = material("Tala | alternate head scales", (0.34, 0.40, 0.31), .58)
keratin = material("Tala | upper jaw keratin", (0.55, 0.52, 0.39), .48)
keratin_lower = material("Tala | lower jaw keratin", (0.48, 0.47, 0.36), .5)
shell = material("Tala | deep jade shell", (0.035, 0.29, 0.25), .3)
shell_light = material("Tala | shell scutes", (0.13, 0.52, 0.37), .34)
shell_edge = material("Tala | shell rim", (0.025, 0.19, 0.19), .38)
belly = material("Tala | pale plastron", (0.76, 0.83, 0.58), .48)
eye_white = material("Tala | eye whites", (1.0, .98, .86), .22)
pupil = material("Tala | dark pupils", (.012, .045, .05), .18)
shine = material("Tala | eye sparkle", (1, 1, 1), .12)
cheek = material("Tala | soft warm cheek", (.69, .47, .34), .56)
mouth_mat = material("Tala | mouth groove", (.10, .15, .12), .62)
nostril_mat = material("Tala | nostril shadow", (.13, .18, .13), .64)

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

def parent_preserve_world(obj, parent):
    # Attach a facial detail to the animated head without changing its
    # authored world-space position.
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj

HEAD_CENTER = (0.0, -1.18, 0.18)
HEAD_RADII = (.58, .56, .49)

def head_surface_point(x, z, depth=.012):
    # Project facial details onto the front hemisphere of the head. This
    # prevents the mouth/scales from floating in front of the muzzle.
    nx = x / HEAD_RADII[0]
    nz = (z - HEAD_CENTER[2]) / HEAD_RADII[2]
    remaining = max(.025, 1.0 - nx * nx - nz * nz)
    y = HEAD_CENTER[1] - HEAD_RADII[1] * math.sqrt(remaining) - depth
    return (x, y, z)

def surface_patch(name, points, mat, depth=.012, parent=None):
    # glTF materials are front-face culled: normalize polygon winding so the
    # visible surface normal faces the camera (toward -Y).
    signed_area = sum(
        points[i][0] * points[(i + 1) % len(points)][1]
        - points[(i + 1) % len(points)][0] * points[i][1]
        for i in range(len(points))
    )
    if signed_area < 0:
        points = list(reversed(points))
    cx = sum(p[0] for p in points) / len(points)
    cz = sum(p[1] for p in points) / len(points)
    vertices = [head_surface_point(cx, cz, depth + .002)]
    vertices.extend(head_surface_point(x, z, depth) for x, z in points)
    faces = []
    for i in range(len(points)):
        faces.append((0, i + 1, ((i + 1) % len(points)) + 1))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if parent is not None:
        parent_preserve_world(obj, parent)
    return obj

def make_head_scale(name, center_x, center_z, width, height, mat, parent):
    # Small polygonal plates with a soft pale margin echo real green-turtle
    # head scutes without turning the face into hard armour.
    unit = [
        (-.56, -1.0), (.46, -.94), (1.0, -.18), (.74, .70),
        (.02, 1.0), (-.78, .66), (-1.0, -.16),
    ]
    def scaled(factor):
        return [
            (center_x + x * width * factor, center_z + z * height * factor)
            for x, z in unit
        ]
    surface_patch(name + "_Margin", scaled(1.0), skin_scale_edge, .012, parent)
    surface_patch(name, scaled(.87), mat, .019, parent)

def surface_curve(name, coordinates, mat, bevel, depth, parent):
    curve = bpy.data.curves.new(name + "_Curve", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 16
    curve.bevel_depth = bevel
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(coordinates) - 1)
    for point, (x, z) in zip(spline.bezier_points, coordinates):
        point.co = head_surface_point(x, z, depth)
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    scene.collection.objects.link(obj)
    curve.materials.append(mat)
    obj.parent = parent
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

# Neck and friendly, slightly blunt head at the front (-Y).
neck = parent_to(root, uv("Tala_Neck", (0, -.83, .08), (.43, .53, .32), skin))
head = parent_to(root, uv("Tala_Head", (0, -1.18, .18), (.58, .56, .49), skin_light, 40, 28))

# A real green turtle has a recognizable pair of elongated prefrontal scales
# between the eyes, plus smaller polygonal plates around the temples and cheeks.
make_head_scale("Tala_Prefrontal_Scale_L", -.085, .51, .073, .105, skin_scale_fill, head)
make_head_scale("Tala_Prefrontal_Scale_R", .085, .51, .073, .105, skin_scale_alt, head)
make_head_scale("Tala_Temporal_Scale_L", -.405, .36, .062, .075, skin_scale_alt, head)
make_head_scale("Tala_Temporal_Scale_R", .405, .36, .062, .075, skin_scale_fill, head)
make_head_scale("Tala_Cheek_Scale_L", -.435, .105, .052, .064, skin_scale_fill, head)
make_head_scale("Tala_Cheek_Scale_R", .435, .105, .052, .064, skin_scale_alt, head)

# Big, soft eyes preserve Tala's friendly expression, but all facial details
# now follow the head's idle/eating motion instead of hovering independently.
for side, x in (("L", -.30), ("R", .30)):
    parent_preserve_world(uv("Tala_EyeWhite_" + side, (x, -1.59, .39), (.19, .105, .22), eye_white), head)
    parent_preserve_world(uv("Tala_Pupil_" + side, (x * 1.02, -1.681, .37), (.092, .052, .125), pupil), head)
    parent_preserve_world(uv("Tala_EyeSparkle_" + side, (x * 1.02 - .035, -1.727, .425), (.035, .022, .045), shine, 20, 12), head)

# Green turtles do not have a duck-like protruding beak or a human smile.
# Their short, rounded upper and lower jaws are covered by keratinous plates.
# These shallow surfaces are projected onto the actual head shape.
upper_jaw_points = [
    (-.18, -.075), (-.166, -.035), (-.105, -.006), (0.0, .004),
    (.105, -.006), (.166, -.035), (.18, -.075), (.125, -.112),
    (0.0, -.125), (-.125, -.112),
]
surface_patch("Tala_Upper_Rhamphotheca", upper_jaw_points, keratin, .021, head)

lower_jaw_points = [
    (-.158, -.137), (-.143, -.177), (-.092, -.211), (0.0, -.222),
    (.092, -.211), (.143, -.177), (.158, -.137), (.112, -.128),
    (0.0, -.134), (-.112, -.128),
]
jaw = surface_patch("Tala_Lower_Rhamphotheca", lower_jaw_points, keratin_lower, .021, head)

# The closed mouth is a very fine jaw junction, not a thick black smile.
# It follows the muzzle surface and is attached to the moving lower jaw so
# the seam separates naturally during the chew animation.
mouth_line = [
    (-.153, -.119), (-.078, -.128), (0.0, -.132),
    (.078, -.128), (.153, -.119),
]
surface_curve("Tala_Jaw_Junction", mouth_line, mouth_mat, .006, .031, jaw)

# Two tiny recessed-looking nostrils sit above the upper jaw.
for x in (-.067, .067):
    nostril_y = head_surface_point(x, .105, .018)[1]
    nostril = uv(
        "Tala_Nostril",
        (x, nostril_y, .105),
        (.012, .007, .009),
        nostril_mat,
        16,
        10,
    )
    parent_preserve_world(nostril, head)

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
set_action(jaw, "Eat_Chew", [(1, 0), (4, -.026), (8, 0), (12, -.026), (16, 0), (20, -.026), (24, 0), (28, 0)], "location", 2)
set_action(jaw, "Happy_Reaction", [(1, 0), (8, -.012), (16, 0), (24, -.009), (32, 0)], "location", 2)
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
