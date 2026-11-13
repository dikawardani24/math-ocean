"""
Math Rings — Kecrekan asset builder.

Run headless:
    blender -b -P tools/blender/build_kecrekan.py -- --mode poc
    blender -b -P tools/blender/build_kecrekan.py -- --mode full

The script builds a real counting frame with individually addressable bead
objects.  It deliberately keeps every bead as its own glTF node so the runtime
can move beads independently; the bead meshes themselves are shared (one mesh
per colour) to keep draw-call and memory cost low.

Blender coordinates: X = width, Y = depth, Z = height.  glTF export converts
to Y-up.  Bead objects keep their origins at the bead centre.
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSET_DIR = os.path.join(ROOT, "assets", "3d", "kecrekan")
POC_DIR = os.path.join(ASSET_DIR, "poc")

# Layout contract shared with src/kecrekan/layout.js
# The silhouette follows the reference toy: a chunky, friendly, butterfly-like
# frame with two loop "ears", a smiling face and ten rows of ten beads.
ROD_COUNT = 10
BEADS_PER_ROD = 10
BEAD_SPACING = 0.22
BEAD_RADIUS = 0.095
BEAD_X_SCALE = 0.62
ROD_LENGTH = 2.70
ROD_X = 1.35
ROW_Z = [-1.28 + i * 0.285 for i in range(ROD_COUNT)]
BEAD_LEFT = -1.24
BEAD_RIGHT = 1.24
BEAD_COLORS = [
    ("Turquoise", (0.10, 0.78, 0.82, 1.0), (0.48, 0.96, 0.94, 1.0)),
    ("Coral", (0.95, 0.30, 0.42, 1.0), (1.0, 0.62, 0.68, 1.0)),
    ("SunGold", (0.98, 0.68, 0.16, 1.0), (1.0, 0.86, 0.42, 1.0)),
    ("Seafoam", (0.26, 0.72, 0.40, 1.0), (0.60, 0.94, 0.62, 1.0)),
    ("Tangerine", (0.96, 0.43, 0.13, 1.0), (1.0, 0.70, 0.36, 1.0)),
]


# ---------------------------------------------------------------------------
# scene helpers
# ---------------------------------------------------------------------------

def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.fps = 30


def collection(name: str) -> bpy.types.Collection:
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def move_to_collection(obj: bpy.types.Object, col: bpy.types.Collection) -> None:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    *,
    metallic: float = 0.0,
    roughness: float = 0.35,
    clearcoat: float = 0.0,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = clearcoat
    if "Coat Roughness" in bsdf.inputs:
        bsdf.inputs["Coat Roughness"].default_value = 0.08
    if emission is not None:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    mat.diffuse_color = color
    return mat


def make_seaglass_texture() -> bpy.types.Image:
    """Generate a glossy sea-glass / pearl-swirl surface and save it next to the GLB."""
    size = 512
    img = bpy.data.images.new("KecrekanSeaGlass", width=size, height=size, alpha=False)
    img.colorspace_settings.name = "sRGB"
    pixels = [0.0] * (size * size * 4)
    rng = random.Random(21)
    for y in range(size):
        for x in range(size):
            u = x / size
            v = y / size
            swirl = (
                math.sin((u * 5.0 + math.sin(v * 6.2) * 0.55) * math.pi * 2.0) * 0.5
                + 0.5
            )
            pearl = math.sin((v * 17.0 + u * 3.0) * math.pi * 2.0) * 0.5 + 0.5
            speck = 1.0 if rng.random() > 0.985 else 0.0
            grain = 0.55 * swirl + 0.30 * pearl + 0.15 * speck
            # Friendly sea-glass violet with mint and pearl highlights.
            r = 0.18 + 0.30 * grain
            g = 0.08 + 0.24 * grain
            b = 0.46 + 0.38 * grain
            i = (y * size + x) * 4
            pixels[i] = min(1.0, r)
            pixels[i + 1] = min(1.0, g)
            pixels[i + 2] = min(1.0, b)
            pixels[i + 3] = 1.0
    img.pixels = pixels
    path = os.path.join(ASSET_DIR, "kecrekan_seaglass.png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def seaglass_material(img: bpy.types.Image) -> bpy.types.Material:
    mat = make_material("Frame_SeaGlass", (0.30, 0.16, 0.60, 1.0), roughness=0.30, clearcoat=0.45)
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    tex.location = (-420, 220)
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    uv.location = (-640, 220)
    nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def add_bevel(obj: bpy.types.Object, width: float = 0.04, segments: int = 3) -> None:
    mod = obj.modifiers.new("soft edges", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def cube(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    col: bpy.types.Collection,
    *,
    bevel: float = 0.04,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    add_bevel(obj, bevel)
    obj.data.materials.append(mat)
    move_to_collection(obj, col)
    return obj


def uv_cube(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=1.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


# ---------------------------------------------------------------------------
# asset parts
# ---------------------------------------------------------------------------

def rounded_ring(
    name: str,
    location: tuple[float, float, float],
    outer: tuple[float, float, float],
    inner: tuple[float, float, float],
    mat: bpy.types.Material,
    col: bpy.types.Collection,
) -> bpy.types.Object:
    """A chunky rounded rectangular frame with a real opening."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    body = bpy.context.active_object
    body.name = name
    body.scale = outer
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    hole = bpy.context.active_object
    hole.name = name + "_hole"
    hole.scale = inner
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = body
    mod = body.modifiers.new("opening", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = hole
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(hole, do_unlink=True)
    add_bevel(body, 0.075, 4)
    # A boolean can leave empty material slots behind; keep only the glass slot
    # so the exported primitive actually references the sea-glass material.
    body.data.materials.clear()
    body.data.materials.append(mat)
    move_to_collection(body, col)
    return body


def add_text(
    name: str,
    body: str,
    location: tuple[float, float, float],
    size: float,
    mat: bpy.types.Material,
    col: bpy.types.Collection,
    *,
    extrude: float = 0.012,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name, type="FONT")
    curve.body = body
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = extrude
    curve.resolution_u = 2
    obj = bpy.data.objects.new(name, curve)
    obj.location = location
    # Text is authored in XY; rotate it to face the camera on the -Y front.
    obj.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    obj.data.materials.append(mat)
    col.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    return obj


def make_star_mesh(name: str, points: int = 5, outer: float = 0.16, inner: float = 0.07) -> bpy.types.Mesh:
    verts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = (i / (points * 2)) * math.pi * 2.0 - math.pi / 2.0
        verts.append((math.cos(a) * r, math.sin(a) * r, 0.0))
    faces = [tuple(range(points * 2))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh


def create_frame(mats: dict[str, bpy.types.Material], glass: bpy.types.Image) -> bpy.types.Object:
    col = collection("Kecrekan_Frame")
    frame_parts: list[bpy.types.Object] = []

    # Chunky rounded outer ring with a real opening for the rods.
    body = rounded_ring(
        "Frame_Body",
        (0.0, 0.0, 0.0),
        (3.50, 0.38, 3.45),
        (2.78, 0.50, 3.02),
        mats["glass"],
        col,
    )
    uv_cube(body)
    frame_parts.append(body)

    # Gold lip around the bead opening.
    for name, loc, scale in [
        ("Frame_LipTop", (0.0, -0.205, 1.505), (2.78, 0.035, 0.035)),
        ("Frame_LipBottom", (0.0, -0.205, -1.505), (2.78, 0.035, 0.035)),
        ("Frame_LipLeft", (-1.385, -0.205, 0.0), (0.035, 0.035, 3.01)),
        ("Frame_LipRight", (1.385, -0.205, 0.0), (0.035, 0.035, 3.01)),
    ]:
        lip = cube(name, loc, scale, mats["gold"], col, bevel=0.012)
        frame_parts.append(lip)

    # Two loop "ears" at the top, like the reference counting toy.
    for i, x in enumerate([-0.78, 0.78]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.30,
            minor_radius=0.105,
            major_segments=28,
            minor_segments=10,
            location=(x, 0.0, 1.64),
            rotation=(math.pi / 2.0, 0.0, 0.0),
        )
        loop = bpy.context.active_object
        loop.name = f"Frame_Loop_{i}"
        loop.data.materials.append(mats["glass"])
        bpy.ops.object.shade_smooth()
        move_to_collection(loop, col)
        frame_parts.append(loop)

        # Gold rim on each loop.
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.30,
            minor_radius=0.018,
            major_segments=28,
            minor_segments=6,
            location=(x, -0.108, 1.64),
            rotation=(math.pi / 2.0, 0.0, 0.0),
        )
        rim = bpy.context.active_object
        rim.name = f"Frame_LoopRim_{i}"
        rim.data.materials.append(mats["gold"])
        move_to_collection(rim, col)
        frame_parts.append(rim)

        # A little pearl flower at the top of each ear.
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.055, location=(x, -0.12, 1.96))
        pearl = bpy.context.active_object
        pearl.name = f"Frame_EarPearl_{i}"
        pearl.data.materials.append(mats["pearl_gold"])
        move_to_collection(pearl, col)
        frame_parts.append(pearl)

    # Side wings / fins that widen the silhouette like the butterfly toy.
    for i, x in enumerate([-1.55, 1.55]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=0.5, location=(x, 0.0, 0.02))
        wing = bpy.context.active_object
        wing.name = f"Frame_Wing_{i}"
        wing.scale = (0.42, 0.34, 1.38)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bpy.ops.object.shade_smooth()
        wing.data.materials.append(mats["glass"])
        move_to_collection(wing, col)
        uv_cube(wing)
        frame_parts.append(wing)

    # Bottom butterfly lobes and feet.
    for i, (x, z, sx, sz) in enumerate([
        (0.0, -1.80, 0.52, 0.16),
        (-0.78, -1.72, 0.36, 0.14),
        (0.78, -1.72, 0.36, 0.14),
    ]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.5, location=(x, 0.0, z))
        lobe = bpy.context.active_object
        lobe.name = f"Frame_BottomLobe_{i}"
        lobe.scale = (sx, 0.30, sz)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        lobe.data.materials.append(mats["glass"])
        move_to_collection(lobe, col)
        uv_cube(lobe)
        frame_parts.append(lobe)

    for i, x in enumerate([-1.25, 1.25]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.11, location=(x, -0.02, -1.86))
        foot = bpy.context.active_object
        foot.name = f"Frame_Foot_{i}"
        foot.scale = (1.0, 1.0, 0.62)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        foot.data.materials.append(mats["gold"])
        move_to_collection(foot, col)
        frame_parts.append(foot)

    # Friendly face on the top rail, between the ears.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=0.34, location=(0.0, -0.10, 1.52))
    face = bpy.context.active_object
    face.name = "Frame_Face"
    face.scale = (1.35, 0.40, 0.80)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    face.data.materials.append(mats["glass_light"])
    move_to_collection(face, col)
    frame_parts.append(face)

    for i, x in enumerate([-0.13, 0.13]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.062, location=(x, -0.315, 1.56))
        eye = bpy.context.active_object
        eye.name = f"Frame_EyeWhite_{i}"
        eye.scale = (0.92, 0.55, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        eye.data.materials.append(mats["eye_white"])
        move_to_collection(eye, col)
        frame_parts.append(eye)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.033, location=(x, -0.355, 1.55))
        pupil = bpy.context.active_object
        pupil.name = f"Frame_Pupil_{i}"
        pupil.scale = (1.0, 0.55, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        pupil.data.materials.append(mats["eye_dark"])
        move_to_collection(pupil, col)
        frame_parts.append(pupil)

    # Smile: a tiny bevelled curve converted to mesh.
    curve = bpy.data.curves.new("Frame_SmileCurve", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 6
    curve.bevel_depth = 0.018
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(2)
    for i, (x, y, z) in enumerate([(-0.13, -0.355, 1.45), (0.0, -0.375, 1.40), (0.13, -0.355, 1.45)]):
        bp = spline.bezier_points[i]
        bp.co = (x, y, z)
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
    smile = bpy.data.objects.new("Frame_Smile", curve)
    smile.data.materials.append(mats["coral_pink"])
    col.objects.link(smile)
    bpy.context.view_layer.objects.active = smile
    smile.select_set(True)
    bpy.ops.object.convert(target="MESH")
    smile.select_set(False)
    frame_parts.append(smile)

    # Cheeks.
    for i, x in enumerate([-0.29, 0.29]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.052, location=(x, -0.33, 1.47))
        cheek = bpy.context.active_object
        cheek.name = f"Frame_Cheek_{i}"
        cheek.scale = (1.0, 0.4, 0.7)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        cheek.data.materials.append(mats["cheek"])
        move_to_collection(cheek, col)
        frame_parts.append(cheek)

    # Number plaques 1-5 on the left, like the reference toy.
    for i in range(5):
        z = 1.02 - i * 0.49
        bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=10, radius=0.17, location=(-1.56, -0.19, z))
        plate = bpy.context.active_object
        plate.name = f"Frame_NumberPlate_{i + 1}"
        plate.scale = (0.82, 0.30, 0.92)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        plate.data.materials.append(mats["plate"])
        move_to_collection(plate, col)
        frame_parts.append(plate)
        num = add_text(f"Frame_Number_{i + 1}", str(i + 1), (-1.56, -0.265, z), 0.22, mats["number"], col)
        frame_parts.append(num)

    # Little sea stickers on the right.
    sticker_specs = [
        ("Starfish", "star", 0.18, 1.02, mats["coral_orange"]),
        ("Shell", "shell", 0.16, 0.55, mats["shell"]),
        ("Fish", "fish", 0.16, 0.08, mats["teal_light"]),
        ("Butterfly", "butterfly", 0.16, -0.39, mats["violet"]),
        ("Crab", "crab", 0.15, -0.86, mats["coral_pink"]),
    ]
    for i, (label, kind, size, z, mat) in enumerate(sticker_specs):
        if kind == "star":
            mesh = make_star_mesh(f"StickerStar_{i}", outer=size, inner=size * 0.43)
            obj = bpy.data.objects.new(f"Sticker_{label}", mesh)
            obj.location = (1.55, -0.22, z)
            obj.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
            obj.scale = (1.0, 1.0, 0.32)
            obj.data.materials.append(mat)
            col.objects.link(obj)
        else:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=size, location=(1.55, -0.22, z))
            obj = bpy.context.active_object
            obj.name = f"Sticker_{label}"
            if kind == "shell":
                obj.scale = (1.1, 0.35, 0.75)
            elif kind == "fish":
                obj.scale = (1.3, 0.35, 0.8)
            elif kind == "butterfly":
                obj.scale = (1.35, 0.35, 0.9)
            elif kind == "crab":
                obj.scale = (1.25, 0.35, 0.85)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            obj.data.materials.append(mat)
            move_to_collection(obj, col)
        frame_parts.append(obj)

    # Root empty owns the whole instrument.
    root = bpy.data.objects.new("Kecrekan_Root", None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.4
    collection("Kecrekan_Root").objects.link(root)
    root["asset"] = "math-rings-kecrekan"
    root["version"] = "2.0-butterfly"
    root["beads_per_rod"] = BEADS_PER_ROD
    root["rod_count"] = ROD_COUNT
    root["bead_spacing"] = BEAD_SPACING
    root["rod_length"] = ROD_LENGTH
    for obj in frame_parts:
        obj.parent = root
    return root


def create_rods(mats: dict[str, bpy.types.Material], root: bpy.types.Object) -> None:
    col = collection("Kecrekan_Rods")
    for row in range(ROD_COUNT):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=24,
            radius=0.024,
            depth=ROD_LENGTH,
            location=(0.0, 0.0, ROW_Z[row]),
            rotation=(0.0, math.pi / 2.0, 0.0),
        )
        rod = bpy.context.active_object
        rod.name = f"Rod_{row}"
        rod.data.materials.append(mats["rod"])
        rod["role"] = "rod"
        rod["rod_index"] = row
        rod.parent = root
        move_to_collection(rod, col)

        for side, x in [("L", -ROD_X), ("R", ROD_X)]:
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=16, ring_count=8, radius=0.045, location=(x, 0.0, ROW_Z[row])
            )
            cap = bpy.context.active_object
            cap.name = f"RodCap_{row}_{side}"
            cap.data.materials.append(mats["gold"])
            cap["role"] = "rod_cap"
            cap["rod_index"] = row
            cap.parent = root
            move_to_collection(cap, col)

        # Five-bead marker: a slim gold ring fixed at the middle of the rod.
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.048,
            minor_radius=0.009,
            major_segments=20,
            minor_segments=6,
            location=(0.0, 0.0, ROW_Z[row]),
            rotation=(0.0, math.pi / 2.0, 0.0),
        )
        marker = bpy.context.active_object
        marker.name = f"FiveMarker_{row}"
        marker.data.materials.append(mats["gold"])
        marker["role"] = "five_marker"
        marker["rod_index"] = row
        marker.parent = root
        move_to_collection(marker, col)


def make_bead_mesh(name: str, mat: bpy.types.Material, band_mat: bpy.types.Material) -> bpy.types.Mesh:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=BEAD_RADIUS, location=(0, 0, 0))
    sphere = bpy.context.active_object
    sphere.name = name
    sphere.scale = (BEAD_X_SCALE, 1.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    sphere.data.materials.append(mat)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=BEAD_RADIUS * 0.98,
        minor_radius=0.010,
        major_segments=24,
        minor_segments=6,
        location=(0, 0, 0),
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    band = bpy.context.active_object
    band.name = name + "_band"
    band.data.materials.append(band_mat)
    bpy.ops.object.shade_smooth()

    # Join the band into the bead mesh: one mesh, two material slots.
    bpy.ops.object.select_all(action="DESELECT")
    sphere.select_set(True)
    band.select_set(True)
    bpy.context.view_layer.objects.active = sphere
    bpy.ops.object.join()
    bead = bpy.context.active_object
    bead.name = name
    return bead.data


def create_beads(mats: dict[str, bpy.types.Material], root: bpy.types.Object) -> None:
    col = collection("Kecrekan_Beads")
    # Ten shared meshes: five colours, each with a deep first-five and a light
    # second-five shade.  Every bead is still an independent glTF node.
    meshes: dict[tuple[int, bool], bpy.types.Mesh] = {}
    for color_index, (name, _deep, _light) in enumerate(BEAD_COLORS):
        for is_deep in (True, False):
            mesh_name = f"BeadMesh_{name}_{'Deep' if is_deep else 'Light'}"
            meshes[(color_index, is_deep)] = make_bead_mesh(
                mesh_name,
                mats[f"bead_{color_index}_{'deep' if is_deep else 'light'}"],
                mats["gold"],
            )
    # Remove the temporary joined objects from the scene; meshes stay in data.
    for obj in list(bpy.context.scene.objects):
        if obj.name in {m.name for m in meshes.values()}:
            bpy.data.objects.remove(obj, do_unlink=True)

    for row in range(ROD_COUNT):
        color_index = row % len(BEAD_COLORS)
        for i in range(BEADS_PER_ROD):
            # Rest state: all beads parked on the right (0 active).
            x = BEAD_RIGHT - (BEADS_PER_ROD - 1 - i) * BEAD_SPACING
            mesh = meshes[(color_index, i < 5)]
            bead = bpy.data.objects.new(f"Bead_R{row}_{i:02d}", mesh)
            bead.location = (x, 0.0, ROW_Z[row])
            bead["role"] = "bead"
            bead["rod_index"] = row
            bead["bead_index"] = i
            bead["group"] = 5 if i < 5 else 10
            bead["color"] = BEAD_COLORS[color_index][0]
            bead["active_value"] = 1
            bead.parent = root
            col.objects.link(bead)


def star_mesh(name: str, points: int = 5, outer: float = 0.16, inner: float = 0.07) -> bpy.types.Mesh:
    verts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = (i / (points * 2)) * math.pi * 2.0 - math.pi / 2.0
        verts.append((math.cos(a) * r, math.sin(a) * r, 0.0))
    faces = [tuple(range(points * 2))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh


def create_decor(mats: dict[str, bpy.types.Material], root: bpy.types.Object) -> None:
    """Small coral companions around the base; the frame itself carries the toy stickers."""
    col = collection("Kecrekan_Decor")

    def add(obj: bpy.types.Object) -> None:
        obj.parent = root
        move_to_collection(obj, col)

    # Coral fans peeking out from behind the lower wings.
    for i, x in enumerate([-1.72, 1.72]):
        for b in range(3):
            length = 0.22 + b * 0.08
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=10,
                radius=0.020,
                depth=length,
                location=(x, 0.18, -1.25 + length * 0.35),
                rotation=(0.2, (0.35 if x < 0 else -0.35), 0.0),
            )
            branch = bpy.context.active_object
            branch.name = f"Decor_Coral_{i}_{b}"
            branch.data.materials.append(mats["coral_pink"] if b % 2 else mats["coral_orange"])
            add(branch)
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=12, ring_count=8, radius=0.055, location=(x + (0.05 if x > 0 else -0.05), 0.18, -1.05)
        )
        tip = bpy.context.active_object
        tip.name = f"Decor_CoralTip_{i}"
        tip.data.materials.append(mats["coral_pink"])
        add(tip)

    # Little shells on the bottom lobes.
    for i, x in enumerate([-0.75, 0.75]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.09, location=(x, -0.28, -1.68))
        shell = bpy.context.active_object
        shell.name = f"Decor_BaseShell_{i}"
        shell.scale = (1.1, 0.65, 0.55)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        shell.data.materials.append(mats["shell"])
        add(shell)

    # Seaweed behind the frame.
    for i, x in enumerate([-1.82, 1.82]):
        for b in range(2):
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=8,
                radius=0.016,
                depth=0.62,
                location=(x, 0.24, -0.65 + b * 0.12),
                rotation=(0.15, 0.15 * (1 if x > 0 else -1), 0.0),
            )
            weed = bpy.context.active_object
            weed.name = f"Decor_Seaweed_{i}_{b}"
            weed.data.materials.append(mats["seaweed"])
            add(weed)


def setup_studio() -> None:
    col = collection("Kecrekan_Studio")
    # Camera
    bpy.ops.object.camera_add(location=(0.0, -6.6, 0.55))
    cam = bpy.context.active_object
    cam.name = "Studio_Camera"
    cam.data.lens = 58
    direction = Vector((0.0, 0.0, -0.05)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    move_to_collection(cam, col)
    bpy.context.scene.camera = cam

    # Soft key, fill and rim lights.
    for name, loc, energy, size, color in [
        ("Studio_Key", (-3.6, -4.4, 4.8), 1100.0, 5.5, (1.0, 0.92, 0.82)),
        ("Studio_Fill", (4.0, -2.8, 1.4), 600.0, 4.5, (0.55, 0.85, 1.0)),
        ("Studio_Rim", (0.0, 3.6, 3.2), 800.0, 3.2, (0.45, 1.0, 0.92)),
    ]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        d = Vector((0.0, 0.0, 0.0)) - light.location
        light.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        move_to_collection(light, col)

    # Soft studio backdrop, not exported.
    bpy.ops.mesh.primitive_plane_add(size=16, location=(0.0, 0.0, -1.95))
    floor = bpy.context.active_object
    floor.name = "Studio_Floor"
    floor.data.materials.append(make_material("Studio_FloorMat", (0.015, 0.07, 0.12, 1.0), roughness=0.55))
    move_to_collection(floor, col)

    world = bpy.data.worlds.new("Kecrekan_World")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.015, 0.08, 0.14, 1.0)
    bg.inputs["Strength"].default_value = 0.6
    bpy.context.scene.world = world

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    try:
        scene.eevee.taa_render_samples = 32
    except Exception:
        pass


def build_materials() -> dict[str, bpy.types.Material]:
    glass_img = make_seaglass_texture()
    mats = {
        "glass": seaglass_material(glass_img),
        "glass_light": make_material("Frame_SeaGlassLight", (0.62, 0.36, 0.86, 1.0), roughness=0.2, clearcoat=0.7),
        "gold": make_material("Gold_Trim", (1.0, 0.68, 0.25, 1.0), metallic=0.92, roughness=0.22),
        "rod": make_material("Rod_PolishedMetal", (0.72, 0.90, 1.0, 1.0), metallic=0.85, roughness=0.18),
        "pearl_gold": make_material(
            "Pearl_Gold", (1.0, 0.72, 0.26, 1.0), metallic=0.35, roughness=0.12, clearcoat=1.0
        ),
        "coral_pink": make_material("Coral_Pink", (1.0, 0.34, 0.46, 1.0), roughness=0.55),
        "coral_orange": make_material("Coral_Orange", (1.0, 0.55, 0.20, 1.0), roughness=0.55),
        "teal": make_material("Turtle_Teal", (0.04, 0.55, 0.48, 1.0), roughness=0.35, clearcoat=0.3),
        "teal_light": make_material("Turtle_TealLight", (0.24, 0.86, 0.66, 1.0), roughness=0.4),
        "shell": make_material("Shell_White", (0.96, 0.90, 0.78, 1.0), roughness=0.3, clearcoat=0.5),
        "seaweed": make_material("Seaweed_Green", (0.08, 0.50, 0.32, 1.0), roughness=0.7),
        "violet": make_material("Sticker_Violet", (0.62, 0.34, 0.92, 1.0), roughness=0.35, clearcoat=0.4),
        "eye_white": make_material("Face_EyeWhite", (1.0, 1.0, 1.0, 1.0), roughness=0.18),
        "eye_dark": make_material("Face_EyeDark", (0.02, 0.04, 0.08, 1.0), roughness=0.15, clearcoat=0.8),
        "cheek": make_material("Face_Cheek", (1.0, 0.48, 0.58, 1.0), roughness=0.4),
        "plate": make_material("Number_Plate", (0.98, 0.94, 0.82, 1.0), roughness=0.25, clearcoat=0.5),
        "number": make_material("Number_Ink", (1.0, 0.42, 0.30, 1.0), roughness=0.35),
    }
    # A bead mesh per colour shade, shared by every bead of that shade.
    for i, (name, deep, light) in enumerate(BEAD_COLORS):
        mats[f"bead_{i}_deep"] = make_material(
            f"Bead_{name}_Deep", deep, metallic=0.18, roughness=0.10, clearcoat=1.0
        )
        mats[f"bead_{i}_light"] = make_material(
            f"Bead_{name}_Light", light, metallic=0.12, roughness=0.12, clearcoat=1.0
        )
    return mats


# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------

def select_root_tree(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def export_glb(root: bpy.types.Object, path: str) -> None:
    select_root_tree(root)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_extras=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_image_format="AUTO",
        export_animations=False,
    )


def render_preview(path: str) -> None:
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def build_poc(mats: dict[str, bpy.types.Material], glass: bpy.types.Image) -> bpy.types.Object:
    """One rod, ten beads, a small frame — the Phase 2 proof of concept."""
    col = collection("POC_Frame")
    root = bpy.data.objects.new("KecrekanPOC_Root", None)
    collection("POC_Root").objects.link(root)
    root["asset"] = "math-rings-kecrekan-poc"
    root["beads_per_rod"] = 10

    left = cube("POC_LeftPost", (-1.45, 0.0, 0.0), (0.16, 0.28, 0.60), mats["glass"], col)
    right = cube("POC_RightPost", (1.45, 0.0, 0.0), (0.16, 0.28, 0.60), mats["glass"], col)
    top = cube("POC_TopRail", (0.0, 0.0, 0.34), (3.08, 0.30, 0.16), mats["glass"], col)
    bottom = cube("POC_BottomRail", (0.0, 0.0, -0.34), (3.08, 0.30, 0.16), mats["glass"], col)
    for obj in (left, right, top, bottom):
        uv_cube(obj)
        obj.parent = root

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24, radius=0.024, depth=ROD_LENGTH, location=(0.0, 0.0, 0.0),
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    rod = bpy.context.active_object
    rod.name = "POC_Rod_0"
    rod.data.materials.append(mats["rod"])
    rod["role"] = "rod"
    rod["rod_index"] = 0
    rod.parent = root
    move_to_collection(rod, col)

    coral_mesh = make_bead_mesh("POC_BeadMesh_Coral", mats["bead_0_deep"], mats["gold"])
    gold_mesh = make_bead_mesh("POC_BeadMesh_Gold", mats["bead_0_light"], mats["gold"])
    for obj in list(bpy.context.scene.objects):
        if obj.name in {"POC_BeadMesh_Coral", "POC_BeadMesh_Gold"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    for i in range(10):
        x = BEAD_RIGHT - (9 - i) * BEAD_SPACING
        bead = bpy.data.objects.new(f"POC_Bead_R0_{i:02d}", coral_mesh if i < 5 else gold_mesh)
        bead.location = (x, 0.0, 0.0)
        bead["role"] = "bead"
        bead["rod_index"] = 0
        bead["bead_index"] = i
        bead["group"] = 5 if i < 5 else 10
        bead.parent = root
        col.objects.link(bead)
    return root


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["poc", "full"], default="full")
    parsed = parser.parse_args(args)

    os.makedirs(ASSET_DIR, exist_ok=True)
    os.makedirs(POC_DIR, exist_ok=True)
    reset_scene()
    mats = build_materials()
    glass = bpy.data.images.get("KecrekanSeaGlass")

    if parsed.mode == "poc":
        root = build_poc(mats, glass)
        setup_studio()
        export_glb(root, os.path.join(POC_DIR, "kecrekan_poc.glb"))
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(POC_DIR, "kecrekan_poc.blend"))
        render_preview(os.path.join(POC_DIR, "kecrekan_poc_preview.png"))
    else:
        root = create_frame(mats, glass)
        create_rods(mats, root)
        create_beads(mats, root)
        create_decor(mats, root)
        setup_studio()
        export_glb(root, os.path.join(ASSET_DIR, "kecrekan.glb"))
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET_DIR, "kecrekan.blend"))
        render_preview(os.path.join(ASSET_DIR, "kecrekan_preview.png"))

    print("BUILT", parsed.mode)


if __name__ == "__main__":
    main()
