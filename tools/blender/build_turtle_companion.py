"""Build Tala, a smooth, animated baby sea turtle.

Run from the repository root with:
  blender --background --python tools/blender/build_turtle_companion.py

Outputs the reusable GLB, a Blender source file, and studio/evaluation renders.
"""
import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets/3d/characters")
ARTIFACTS = os.path.join(ROOT, "artifacts/blender/tala")
EVIDENCE = os.path.join(ROOT, "evidence-out/tala-redesign")
for folder in (OUT, ARTIFACTS, EVIDENCE):
    os.makedirs(folder, exist_ok=True)

GLB = os.path.join(OUT, "tala_sea_turtle.glb")
BLEND = os.path.join(ARTIFACTS, "tala_sea_turtle.blend")
PREVIEW = os.path.join(ARTIFACTS, "tala_sea_turtle_preview.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
engines = {item.identifier for item in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
scene.render.engine = next(engine for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES") if engine in engines)
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "AgX"
scene.render.film_transparent = False
scene.frame_start, scene.frame_end = 1, 49
scene.render.image_settings.file_format = "PNG"


def material(name, color, roughness=0.4):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    return result


skin = material("Tala | sea-glass green", (0.25, 0.68, 0.47), .43)
face_skin = material("Tala | soft face green", (0.38, 0.78, 0.56), .42)
flipper_skin = material("Tala | sunlit flippers", (0.31, 0.73, 0.52), .42)
shell_mat = material("Tala | deep lagoon shell", (0.035, 0.34, 0.34), .34)
seam_mat = material("Tala | shell scute seams", (0.025, 0.25, 0.27), .4)
belly_mat = material("Tala | warm sand plastron", (0.89, 0.82, 0.59), .48)
eye_white = material("Tala | warm ivory eyes", (1.0, .96, .82), .22)
iris_mat = material("Tala | amber green irises", (.24, .38, .20), .19)
pupil_mat = material("Tala | deep pupils", (.025, .04, .025), .14)
glint_mat = material("Tala | eye glints", (1.0, 1.0, 1.0), .1)
smile_mat = material("Tala | smile", (.12, .29, .20), .45)
blush_mat = material("Tala | soft coral blush", (.76, .52, .43), .52)


def smooth(obj):
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def parent_preserve_world(obj, parent):
    parent_inverse = parent.matrix_world.inverted()
    obj.parent = parent
    obj.matrix_parent_inverse = parent_inverse
    return obj


def ellipsoid(name, location, scale, mat, parent=None, rotation=(0, 0, 0), segments=40, rings=28):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    smooth(obj)
    if parent:
        parent_preserve_world(obj, parent)
    return obj


def curve(name, points, mat, radius, parent=None, resolution=16, cyclic=False):
    data = bpy.data.curves.new(name + "_Curve", "CURVE")
    data.dimensions = "3D"
    data.resolution_u = resolution
    data.bevel_depth = radius
    data.bevel_resolution = 3
    spline = data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    spline.use_cyclic_u = cyclic
    for point, co in zip(spline.points, points):
        point.co = (*co, 1)
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    data.materials.append(mat)
    if parent:
        parent_preserve_world(obj, parent)
    return obj


root = bpy.data.objects.new("Tala_Root", None)
scene.collection.objects.link(root)

# The plump body sits under a raised, oval carapace with a narrow, soft rim.
body = ellipsoid("Tala_Body", (0, .03, -.03), (.72, .95, .34), skin, root)
ellipsoid("Tala_Plastron", (0, .08, -.245), (.60, .81, .15), belly_mat, root)
ellipsoid("Tala_Shell_Rim", (0, .13, .20), (.87, .97, .075), shell_mat, root)
shell = ellipsoid("Tala_Carapace", (0, .13, .34), (.84, .94, .46), shell_mat, root, segments=56, rings=36)

# Fine inset-like lines divide the dome into a central scute and broad side scutes.
SHELL_A, SHELL_B, SHELL_C = .84, .94, .46
SHELL_Z, SHELL_Y = .34, .13


def shell_surface(x, y, lift=.006):
    q = max(.035, 1 - (x / SHELL_A) ** 2 - (y / SHELL_B) ** 2)
    return (x, SHELL_Y + y, SHELL_Z + SHELL_C * math.sqrt(q) + lift)


def shell_line(name, xy_points):
    closed = xy_points[0] == xy_points[-1]
    controls = xy_points[:-1] if closed else xy_points
    sampled = []
    count = len(controls)
    for i in range(count if closed else count - 1):
        p0 = controls[(i - 1) % count] if closed or i > 0 else controls[i]
        p1 = controls[i]
        p2 = controls[(i + 1) % count]
        p3 = controls[(i + 2) % count] if closed or i + 2 < count else controls[i + 1]
        for step in range(10):
            t = step / 10
            t2, t3 = t * t, t * t * t
            x = .5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2*p0[0] - 5*p1[0] + 4*p2[0] - p3[0]) * t2 + (-p0[0] + 3*p1[0] - 3*p2[0] + p3[0]) * t3)
            y = .5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2*p0[1] - 5*p1[1] + 4*p2[1] - p3[1]) * t2 + (-p0[1] + 3*p1[1] - 3*p2[1] + p3[1]) * t3)
            sampled.append(shell_surface(x, y, .002))
    if not closed:
        sampled.append(shell_surface(*controls[-1], .002))
    curve(name, sampled, seam_mat, .005, root, cyclic=closed)


# A curved, closed outline around the central shield and paired lateral scutes.
shell_line("Tala_Scute_Center_Outline", [
    (-.29, -.62), (-.34, -.34), (-.36, .02), (-.31, .37), (-.23, .62),
    (0, .73), (.23, .62), (.31, .37), (.36, .02), (.34, -.34), (.29, -.62), (-.29, -.62),
])
for side in (-1, 1):
    shell_line("Tala_Scute_Side_Outline_%s" % side, [
        (side * .31, -.62), (side * .57, -.52), (side * .73, -.29),
        (side * .78, .02), (side * .72, .34), (side * .54, .57),
        (side * .29, .62), (side * .31, -.62),
    ])
    shell_line("Tala_Scute_Rim_Seam_%s" % side, [
        (side * .55, -.67), (side * .68, -.42), (side * .75, -.10),
        (side * .75, .23), (side * .62, .53),
    ])

# Broad, tapered-looking paddles overlap the body to create one connected silhouette.
flippers = {}
flippers["FrontLeft"] = ellipsoid("Tala_Front_Flipper_L", (-.68, -.47, -.065), (.34, .61, .145), flipper_skin, root, (0, -.18, -.30))
flippers["FrontRight"] = ellipsoid("Tala_Front_Flipper_R", (.68, -.47, -.065), (.34, .61, .145), flipper_skin, root, (0, .18, .30))
flippers["RearLeft"] = ellipsoid("Tala_Rear_Flipper_L", (-.61, .70, -.07), (.28, .46, .13), skin, root, (0, -.16, -.25))
flippers["RearRight"] = ellipsoid("Tala_Rear_Flipper_R", (.61, .70, -.07), (.28, .46, .13), skin, root, (0, .16, .25))
tail = ellipsoid("Tala_Tail", (0, 1.01, -.055), (.15, .34, .105), skin, root)

# A short, broad neck meets a large flattened head; both tuck into the carapace.
ellipsoid("Tala_Neck", (0, -.70, .075), (.39, .40, .29), skin, root)
HEAD = (0, -1.015, .105)
HEAD_SCALE = (.62, .47, .455)
head = ellipsoid("Tala_Head", HEAD, HEAD_SCALE, face_skin, root, segments=56, rings=36)


def face_y(x, z, offset=0):
    nx = (x - HEAD[0]) / HEAD_SCALE[0]
    nz = (z - HEAD[2]) / HEAD_SCALE[2]
    return HEAD[1] - HEAD_SCALE[1] * math.sqrt(max(.035, 1 - nx * nx - nz * nz)) - offset


# Small, close-set eyes follow the same forward-facing plane and look slightly upward.
for side, x in (("L", -.215), ("R", .215)):
    z = .325
    y = face_y(x, z, .008)
    ellipsoid("Tala_Eye_White_" + side, (x, y, z), (.105, .027, .125), eye_white, head, segments=40, rings=28)
    ellipsoid("Tala_Iris_" + side, (x, y - .023, z + .004), (.079, .023, .098), iris_mat, head, segments=36, rings=24)
    ellipsoid("Tala_Pupil_" + side, (x, y - .041, z + .009), (.056, .016, .074), pupil_mat, head, segments=32, rings=20)
    ellipsoid("Tala_Eye_Glint_" + side, (x - .025, y - .056, z + .046), (.020, .009, .024), glint_mat, head, segments=20, rings=14)

# Tiny nostrils sit just above the smile; the muzzle stays part of the head silhouette.
for x in (-.052, .052):
    z = .075
    ellipsoid("Tala_Nostril", (x, face_y(x, z, .010), z), (.008, .006, .009), smile_mat, head, segments=16, rings=10)

smile_points = []
for i in range(13):
    t = -1 + i / 6
    x = .105 * t
    z = -.075 - .038 * (1 - t * t)
    smile_points.append((x, face_y(x, z, .018), z))
curve("Tala_Sweet_Smile", smile_points, smile_mat, .009, head)

for side, x in (("L", -.39), ("R", .39)):
    z = .035
    ellipsoid("Tala_Cheek_" + side, (x, face_y(x, z, .008), z), (.046, .012, .026), blush_mat, head, segments=28, rings=18)


def add_action(obj, action_name, frames, path="rotation_euler", axis=0):
    animation = obj.animation_data_create()
    action = bpy.data.actions.new(name=action_name + "_" + obj.name)
    animation.action = action
    for frame, value in frames:
        if path == "location":
            obj.location[axis] = value
        else:
            obj.rotation_euler[axis] = value
        obj.keyframe_insert(data_path=path, index=axis, frame=frame, group=action_name)
    track = animation.nla_tracks.new()
    track.name = action_name
    strip = track.strips.new(action_name, 1, action)
    strip.name = action_name
    animation.action = None


for name, flipper in flippers.items():
    axis = 1
    base = flipper.rotation_euler[axis]
    amplitude = .20 if "Front" in name else .12
    add_action(flipper, "Idle_Swim", [(1, base), (13, base + amplitude), (25, base), (37, base - amplitude), (49, base)])
    add_action(flipper, "Eat_Chew", [(1, base), (7, base + amplitude * .55), (13, base - amplitude * .45), (19, base + amplitude * .4), (25, base)])
    add_action(flipper, "Happy_Reaction", [(1, base), (8, base - amplitude * 1.4), (16, base + amplitude * 1.4), (24, base), (32, base)])
add_action(head, "Idle_Swim", [(1, 0), (13, .025), (25, 0), (37, -.02), (49, 0)])
add_action(head, "Eat_Chew", [(1, 0), (5, .08), (10, -.06), (15, .08), (20, -.04), (25, 0)])
add_action(head, "Happy_Reaction", [(1, 0), (8, -.08), (16, .05), (24, 0), (32, -.025)])
add_action(tail, "Idle_Swim", [(1, 0), (13, .12), (25, 0), (37, -.12), (49, 0)], axis=2)

# Clean, pastel underwater studio render; lights and cameras stay out of the GLB selection.
world = bpy.data.worlds.new("Tala | lagoon studio")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.075, .23, .27, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .7
scene.world = world


def aim(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.object.light_add(type="AREA", location=(-4, -5, 6))
key = bpy.context.object
key.name = "Preview_Key"
key.data.energy = 850
key.data.shape = "DISK"
key.data.size = 5
aim(key, (0, 0, .1))
bpy.ops.object.light_add(type="AREA", location=(4, 1, 3.8))
fill = bpy.context.object
fill.name = "Preview_Fill"
fill.data.energy = 520
fill.data.size = 4
aim(fill, (0, 0, .1))
bpy.ops.object.light_add(type="AREA", location=(0, 3, 5))
rim = bpy.context.object
rim.name = "Preview_Rim"
rim.data.energy = 700
rim.data.size = 3
aim(rim, (0, 0, .2))

bpy.ops.object.camera_add(location=(0, -5.7, 1.85))
camera = bpy.context.object
camera.name = "Preview_Camera"
aim(camera, (0, -.05, .16))
camera.data.type = "ORTHO"
camera.data.ortho_scale = 3.9
scene.camera = camera
scene.render.filepath = PREVIEW
scene.frame_set(1)


def render_view(filename, location, target, scale, frame=1):
    scene.frame_set(frame)
    camera.location = location
    aim(camera, target)
    camera.data.ortho_scale = scale
    scene.render.filepath = os.path.join(EVIDENCE, filename)
    bpy.ops.render.render(write_still=True)


render_view("tala_front.png", (0, -5.7, .28), (0, 0, .14), 3.65)
render_view("tala_three_quarter.png", (3.4, -4.7, 1.7), (0, 0, .16), 3.8)
render_view("tala_face.png", (0, -3.4, .34), (0, -1.02, .10), 1.9)
render_view("tala_idle.png", (0, -5.7, .28), (0, 0, .14), 3.65)
render_view("tala_eating.png", (0, -3.4, .34), (0, -1.02, .10), 1.9, frame=5)
render_view("tala_happy.png", (0, -5.7, .28), (0, 0, .14), 3.65, frame=8)

scene.frame_set(1)
camera.location = (0, -5.7, 1.85)
aim(camera, (0, -.05, .16))
camera.data.ortho_scale = 3.9
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

def belongs_to_character(obj):
    current = obj
    while current is not None:
        if current == root:
            return True
        current = current.parent
    return False


bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    if belongs_to_character(obj):
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
print("Generated Tala GLB and evaluation renders:", GLB)
