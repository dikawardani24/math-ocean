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
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSET_DIR = os.path.join(ROOT, "assets", "3d", "kecrekan")
POC_DIR = os.path.join(ASSET_DIR, "poc")

# Layout contract shared with src/kecrekan/layout.js
# The instrument has five rows of five oversized tactile beads. Runtime
# visibility/layout shows only the number of rows required by each challenge.
ROD_COUNT = 5
BEADS_PER_ROD = 5
BEAD_SPACING = 0.38
BEAD_RADIUS = 0.15
BEAD_X_SCALE = 0.90
ROD_LENGTH = 2.70
ROD_X = 1.35
ROW_Z = [-1.04 + i * 0.52 for i in range(ROD_COUNT)]
BEAD_LEFT = -0.95
BEAD_RIGHT = 0.95
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


def create_frame(mats: dict[str, bpy.types.Material], glass: bpy.types.Image | None = None) -> bpy.types.Object:
    """Build a clean, sturdy counting frame; the beads remain the visual focus."""
    col = collection("Kecrekan_Frame")
    root = bpy.data.objects.new("Kecrekan_Root", None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.4
    collection("Kecrekan_Root").objects.link(root)

    # Four substantial rounded rails. No face, ears, wings, stickers or side
    # ornaments: keep the silhouette readable and leave the full width for play.
    parts = [
        cube("Frame_TopRail", (0.0, 0.0, 1.55), (3.28, 0.38, 0.18), mats["glass"], col, bevel=0.075),
        cube("Frame_BottomRail", (0.0, 0.0, -1.55), (3.28, 0.38, 0.18), mats["glass"], col, bevel=0.075),
        cube("Frame_LeftPost", (-1.55, 0.0, 0.0), (0.18, 0.38, 3.20), mats["glass"], col, bevel=0.075),
        cube("Frame_RightPost", (1.55, 0.0, 0.0), (0.18, 0.38, 3.20), mats["glass"], col, bevel=0.075),
    ]

    # A restrained warm-metal inner edge gives the frame a crafted finish
    # without creating another high-contrast border around every bead.
    parts.extend([
        cube("Frame_TopAccent", (0.0, -0.198, 1.425), (2.92, 0.025, 0.025), mats["gold"], col, bevel=0.01),
        cube("Frame_BottomAccent", (0.0, -0.198, -1.425), (2.92, 0.025, 0.025), mats["gold"], col, bevel=0.01),
    ])

    root["asset"] = "math-ocean-kecrekan"
    root["version"] = "4.0-five-by-five-adaptive"
    root["beads_per_rod"] = BEADS_PER_ROD
    root["rod_count"] = ROD_COUNT
    root["bead_spacing"] = BEAD_SPACING
    root["rod_length"] = ROD_LENGTH
    for obj in parts:
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
    # second-five shade. Every bead remains an independent glTF node.
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
            # Rest state: all beads parked on the right (0 active).  Index 0
            # is furthest right, matching KecrekanMath.beadX.
            x = BEAD_RIGHT - i * BEAD_SPACING
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


def create_decor(mats: dict[str, bpy.types.Material], root: bpy.types.Object) -> None:
    """The new instrument intentionally has no surrounding decorative props."""
    return

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
    # Matte ocean enamel for the frame; restrained metal for rods and trim.
    mats = {
        "glass": make_material("Frame_OceanEnamel", (0.035, 0.34, 0.40, 1.0), roughness=0.30, clearcoat=0.32),
        "gold": make_material("Warm_Champagne_Trim", (0.95, 0.68, 0.34, 1.0), metallic=0.55, roughness=0.28),
        "rod": make_material("Rod_Satin_Silver", (0.72, 0.86, 0.88, 1.0), metallic=0.72, roughness=0.24),
    }
    # Five ocean-friendly bead colours, each with a subtle light/dark split.
    for i, (name, deep, light) in enumerate(BEAD_COLORS):
        mats[f"bead_{i}_deep"] = make_material(
            f"Bead_{name}_Deep", deep, metallic=0.04, roughness=0.22, clearcoat=0.48
        )
        mats[f"bead_{i}_light"] = make_material(
            f"Bead_{name}_Light", light, metallic=0.03, roughness=0.24, clearcoat=0.42
        )
    return mats

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
    root["beads_per_rod"] = BEADS_PER_ROD

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
    for i in range(BEADS_PER_ROD):
        x = BEAD_RIGHT - i * BEAD_SPACING
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
    glass = None

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
