"""
Math Rings — Jarimatika hand asset builder.

Builds a locally bundled, rigged human hand for the finger-maths screen.  The
asset is deliberately self-contained: one GLB with a skinned mesh, a skeleton
whose finger joints are addressable by name, and small nail meshes skinned to
the distal bones.  The Flutter runtime poses the bones; no animation clip or
cloud service is involved.

Run headless:
    blender -b -P tools/blender/build_hand.py -- --mode build
    blender -b -P tools/blender/build_hand.py -- --mode preview

Blender coordinates: X = width, Y = depth (palm faces +Y), Z = height.
glTF export converts to Y-up, so the fingers point up and the palm faces -Z.
"""

from __future__ import annotations

import argparse
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSET_DIR = os.path.join(ROOT, "assets", "3d", "hand")
PREVIEW_DIR = os.path.join(ROOT, "evidence-out", "hand")

# Palm and finger measurements in hand units.  The palm runs from the wrist
# crease (z = 0) to the knuckles (z = 1); the middle fingertip reaches z = 1.86.
# Proportions follow a relaxed adult right hand: broad knuckles, a strong
# thenar mass, tapered fingers and a thumb that sits forward of the palm.
FINGERS = [
    # name, base x, tip x, length, base radius, knuckle z
    ("index", 0.300, 0.345, 0.700, 0.104, 1.000),
    ("middle", 0.100, 0.112, 0.790, 0.108, 1.012),
    ("ring", -0.100, -0.132, 0.735, 0.102, 1.000),
    ("pinky", -0.292, -0.350, 0.585, 0.088, 0.962),
]
FINGERS_BY_NAME = {f[0]: f for f in FINGERS}

# Thumb chain: carpal root, metacarpal head, proximal phalanx, distal phalanx.
THUMB_POINTS = [
    Vector((0.050, 0.020, 0.330)),
    Vector((0.235, 0.045, 0.430)),
    Vector((0.405, 0.075, 0.540)),
    Vector((0.525, 0.100, 0.625)),
    Vector((0.585, 0.112, 0.680)),
]
FINGER_JOINTS = (0.0, 0.42, 0.73, 1.0)


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


# ---------------------------------------------------------------------------
# finger geometry — one source of truth for mesh, bones, creases and colour
# ---------------------------------------------------------------------------


def finger_base(name: str) -> Vector:
    _, base_x, _, _, _, knuckle_z = FINGERS_BY_NAME[name]
    return Vector((base_x, -0.010, knuckle_z))


def finger_tip(name: str) -> Vector:
    _, _, tip_x, length, _, knuckle_z = FINGERS_BY_NAME[name]
    return Vector((tip_x, 0.010, knuckle_z + length))


def finger_point(name: str, t: float) -> Vector:
    """Sample the finger centreline.  Fingers fan out and bow to the palm."""
    base = finger_base(name)
    tip = finger_tip(name)
    length = (tip.z - base.z)
    fan = (tip.x - base.x) * (t ** 1.45)
    bow = (0.020 * math.sin(math.pi * t) + 0.026 * t * t) * length
    return Vector((base.x + fan, base.y + bow, base.z + length * t))


def finger_radius(name: str, t: float) -> float:
    _, _, _, length, base_radius, _ = FINGERS_BY_NAME[name]
    radius = base_radius * (1.0 - 0.26 * t)
    # Knuckle, PIP and DIP are slightly wider than the shafts between them.
    for joint, swell in ((0.0, 0.005), (0.42, 0.0065), (0.73, 0.0045)):
        radius += swell * math.exp(-(((t - joint) / 0.055) ** 2))
    return radius


# ---------------------------------------------------------------------------
# mesh building
# ---------------------------------------------------------------------------


def new_mesh(name: str, verts, faces) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def tube_object(name: str, rings, sides: int = 28) -> bpy.types.Object:
    """A capped tube from (centre, radius_x, radius_y, frame_z) rings."""
    verts = []
    faces = []
    for centre, rx, ry, z_axis in rings:
        z_axis = z_axis.normalized()
        helper = Vector((1, 0, 0)) if abs(z_axis.x) < 0.9 else Vector((0, 1, 0))
        x_axis = helper.cross(z_axis).normalized()
        y_axis = z_axis.cross(x_axis).normalized()
        for i in range(sides):
            a = 2 * math.pi * i / sides
            verts.append(centre + x_axis * (math.cos(a) * rx) + y_axis * (math.sin(a) * ry))
    for r in range(len(rings) - 1):
        a = r * sides
        b = (r + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    bottom = len(verts)
    verts.append(rings[0][0] - rings[0][3].normalized() * 0.002)
    top = len(verts)
    verts.append(rings[-1][0] + rings[-1][3].normalized() * 0.002)
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((bottom, j, i))
        last = (len(rings) - 1) * sides
        faces.append((top, last + i, last + j))
    return new_mesh(name, verts, faces)


def capsule_object(
    name: str,
    a: Vector,
    b: Vector,
    radius_x: float,
    radius_y: float,
) -> bpy.types.Object:
    """A rounded bar between two points, used for tendons and knuckle ridges."""
    axis = (b - a).normalized()
    helper = Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))
    x_axis = helper.cross(axis).normalized()
    y_axis = axis.cross(x_axis).normalized()
    rings = []
    steps = 16
    for i in range(steps + 1):
        t = i / steps
        # Round both ends so the bar blends instead of ending in a sharp rim.
        end = min(1.0, min(t, 1.0 - t) / 0.16)
        scale = math.sin(end * math.pi / 2)
        centre = a.lerp(b, t)
        rings.append(
            (
                centre,
                radius_x * scale,
                radius_y * scale,
                axis,
            )
        )
    return tube_object(name, rings, sides=16)


def palm_object() -> bpy.types.Object:
    """Lofted palm: narrow wrist, broad knuckles, flattened superellipse."""
    profile = [
        # z, half width, half depth, centre y
        (-0.345, 0.070, 0.050, 0.000),
        (-0.330, 0.105, 0.062, 0.000),
        (-0.305, 0.134, 0.069, 0.000),
        (-0.270, 0.152, 0.074, 0.000),
        (-0.220, 0.166, 0.079, 0.001),
        (-0.130, 0.188, 0.089, 0.002),
        (-0.050, 0.200, 0.098, 0.004),
        (0.040, 0.212, 0.109, 0.007),
        (0.150, 0.229, 0.122, 0.011),
        (0.270, 0.252, 0.135, 0.015),
        (0.390, 0.283, 0.145, 0.017),
        (0.510, 0.318, 0.150, 0.017),
        (0.630, 0.352, 0.149, 0.014),
        (0.750, 0.392, 0.143, 0.009),
        (0.865, 0.414, 0.135, 0.004),
        (0.945, 0.418, 0.127, 0.000),
        (1.005, 0.400, 0.117, -0.004),
    ]
    sides = 48
    verts = []
    faces = []
    exponent = 2.15
    for z, rx, ry, cy in profile:
        for i in range(sides):
            a = 2 * math.pi * i / sides
            c, s = math.cos(a), math.sin(a)
            x = math.copysign(abs(c) ** (2 / exponent), c) * rx
            y = math.copysign(abs(s) ** (2 / exponent), s) * ry
            verts.append(Vector((x, y + cy, z)))
    for r in range(len(profile) - 1):
        a = r * sides
        b = (r + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    bottom = len(verts)
    verts.append(Vector((0, 0, profile[0][0] - 0.035)))
    top = len(verts)
    verts.append(Vector((0, 0, profile[-1][0] + 0.01)))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((bottom, j, i))
        last = (len(profile) - 1) * sides
        faces.append((top, last + i, last + j))
    return new_mesh("Palm", verts, faces)


def ellipsoid_object(
    name: str,
    centre: Vector,
    radii: Vector,
    rotation: Matrix | None = None,
    segments: int = 28,
    rings: int = 18,
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    mat = Matrix.Translation(centre)
    if rotation is not None:
        mat = mat @ rotation
    mat = mat @ Matrix.Diagonal(Vector((radii.x, radii.y, radii.z, 1.0)))
    bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def finger_object(name: str, label: str | None = None) -> bpy.types.Object:
    samples = 26
    rings = []
    for i in range(samples):
        t = i / (samples - 1)
        centre = finger_point(name, t)
        radius = finger_radius(name, t)
        direction = (finger_point(name, min(1.0, t + 0.02)) - finger_point(name, max(0.0, t - 0.02)))
        if direction.length < 1e-6:
            direction = Vector((0, 0, 1))
        # Fingers are a little wider than they are deep.
        rings.append((centre, radius, radius * 0.93, direction))
    return tube_object(label or name, rings, sides=24)


def build_hand_mesh() -> bpy.types.Object:
    parts = [palm_object()]

    # Thenar eminence: the muscular mound at the base of the thumb.  It has to
    # be a real volume, otherwise the thumb springs out of a flat paddle.
    parts.append(
        ellipsoid_object(
            "Thenar", Vector((0.176, 0.086, 0.470)), Vector((0.158, 0.108, 0.235))
        )
    )
    parts.append(
        ellipsoid_object(
            "ThenarCrest", Vector((0.270, 0.048, 0.520)), Vector((0.128, 0.094, 0.155))
        )
    )
    parts.append(
        ellipsoid_object(
            "Hypothenar", Vector((-0.262, 0.052, 0.430)), Vector((0.112, 0.082, 0.238))
        )
    )
    # Wrist heel, rounded off rather than chopped flat.
    parts.append(
        ellipsoid_object(
            "WristPad", Vector((0.0, 0.008, -0.055)), Vector((0.205, 0.094, 0.098))
        )
    )
    parts.append(
        ellipsoid_object(
            "WristEnd", Vector((0.0, 0.004, -0.300)), Vector((0.128, 0.070, 0.060))
        )
    )

    for name, base_x, tip_x, length, radius, knuckle_z in FINGERS:
        base = finger_base(name)
        tip = finger_tip(name)
        parts.append(finger_object(name, f"Finger_{name}"))
        tip_radius = finger_radius(name, 1.0)
        tip_dir = (tip - finger_point(name, 0.94)).normalized()
        parts.append(
            ellipsoid_object(
                f"FingerTip_{name}",
                tip - tip_dir * (tip_radius * 0.32),
                Vector((tip_radius * 1.02, tip_radius * 0.96, tip_radius * 1.05)),
            )
        )
        # Metacarpophalangeal knuckle: a distinct dorsal dome.
        parts.append(
            ellipsoid_object(
                f"Knuckle_{name}",
                Vector((base_x, -0.062, knuckle_z + 0.006)),
                Vector((radius * 1.02, 0.052, radius * 0.72)),
            )
        )
        # Webbing into the neighbouring finger.
        if name != "pinky":
            index = [f[0] for f in FINGERS].index(name)
            next_base = finger_base(FINGERS[index + 1][0])
            mid = (base + next_base) * 0.5
            parts.append(
                ellipsoid_object(
                    f"Web_{name}",
                    Vector((mid.x, 0.014, mid.z + 0.020)),
                    Vector((abs(next_base.x - base.x) * 0.58, 0.094, 0.115)),
                )
            )

    # Soft web where the thumb leaves the palm; without it the tube meets the
    # palm at a hard concave notch.
    parts.append(
        ellipsoid_object(
            "ThumbWeb",
            Vector((0.285, 0.045, 0.455)),
            Vector((0.125, 0.098, 0.150)),
            rotation=Matrix.Rotation(math.radians(-38), 4, "Y"),
        )
    )

    # Thumb: a broad metacarpal rooted in the thenar mass, then two phalanges.
    thumb_rings = []
    samples = 22
    for i in range(samples):
        t = i / (samples - 1)
        pos = _sample_polyline(THUMB_POINTS, t)
        direction = _sample_polyline(THUMB_POINTS, min(1.0, t + 0.02)) - _sample_polyline(
            THUMB_POINTS, max(0.0, t - 0.02)
        )
        # Strong proximal mass tapering to a rounded distal pad.
        r = 0.168 - 0.076 * t
        r += 0.008 * math.exp(-(((t - 0.58) / 0.10) ** 2))
        if t > 0.9:
            r *= 0.86 + 0.14 * (1.0 - t) / 0.1
        thumb_rings.append((pos, r, r * 0.92, direction))
    parts.append(tube_object("Thumb", thumb_rings, sides=24))
    parts.append(
        ellipsoid_object(
            "ThumbTip",
            THUMB_POINTS[-1] - (THUMB_POINTS[-1] - THUMB_POINTS[-2]).normalized() * 0.018,
            Vector((0.086, 0.080, 0.088)),
        )
    )
    parts.append(
        ellipsoid_object(
            "ThumbKnuckle",
            THUMB_POINTS[2] + THUMB_POINTS[3] * 0.0,
            Vector((0.090, 0.084, 0.078)),
        )
    )

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    hand = bpy.context.active_object
    hand.name = "HandMesh"

    # Voxel union turns the overlapping organic pieces into one continuous
    # surface, then a light smooth pass removes the voxel stair-stepping.
    remesh = hand.modifiers.new("VoxelUnion", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.0115
    remesh.use_smooth_shade = True
    bpy.context.view_layer.objects.active = hand
    bpy.ops.object.modifier_apply(modifier=remesh.name)

    smooth = hand.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.45
    smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)

    decimate = hand.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = 0.30
    bpy.ops.object.modifier_apply(modifier=decimate.name)

    _sculpt_details(hand)
    _paint_skin(hand)
    bpy.context.view_layer.update()
    return hand


# ---------------------------------------------------------------------------
# skin colour and fine detail
# ---------------------------------------------------------------------------


def _paint_skin(hand: bpy.types.Object) -> None:
    """Bake anatomical colour variation into a point colour attribute.

    glTF multiplies COLOR_0 into the base colour, so this adds warmer knuckles,
    a slightly lighter palm and mottled skin without another large texture.
    """
    mesh = hand.data
    mesh.update()
    layer = mesh.color_attributes.new(name="SkinColour", type="FLOAT_COLOR", domain="POINT")

    joints = []
    for name, *_ in FINGERS:
        for t in FINGER_JOINTS:
            joints.append(finger_point(name, t))
    joints.extend(THUMB_POINTS)

    def field(p: Vector) -> float:
        return (
            math.sin(p.x * 41.0 + p.z * 13.0)
            * math.sin(p.z * 33.0 + p.y * 47.0)
            * math.sin(p.y * 59.0 + p.x * 19.0)
        )

    for vertex in mesh.vertices:
        p = vertex.co
        # Linear-light warm skin.  The palm is a touch lighter, the dorsum a
        # touch deeper, and joints pick up redness from thin skin.
        base = Vector((0.335, 0.158, 0.112))
        if p.y > 0.085 and p.z > 0.02:
            base = base.lerp(Vector((0.400, 0.198, 0.145)), 0.50)
        elif p.y < -0.05:
            base = base.lerp(Vector((0.300, 0.138, 0.094)), 0.40)
        redness = 0.0
        for joint in joints:
            d = (p - joint).length
            if d < 0.115:
                redness = max(redness, (1.0 - d / 0.115) ** 2)
        base = base.lerp(Vector((0.430, 0.155, 0.112)), 0.24 * redness)
        variation = field(p * 1.1) * 0.020 + field(p * 3.1) * 0.010
        colour = base * (1.0 + variation)
        layer.data[vertex.index].color = (
            max(0.0, min(1.0, colour.x)),
            max(0.0, min(1.0, colour.y)),
            max(0.0, min(1.0, colour.z)),
            1.0,
        )
    mesh.color_attributes.active_color = layer


def _sculpt_details(hand: bpy.types.Object) -> None:
    """Carve joint creases and palm lines into the remeshed surface."""
    mesh = hand.data
    mesh.update()
    finger_data = []
    for name, *_ in FINGERS:
        points = [finger_point(name, t) for t in FINGER_JOINTS]
        finger_data.append((name, points, finger_radius(name, 0.42)))

    palm_lines = [
        # life line, around the thenar pad
        [Vector((0.228, 0.150, 0.575)), Vector((0.198, 0.162, 0.480)),
         Vector((0.136, 0.170, 0.385)), Vector((0.040, 0.172, 0.300))],
        # head line, across the palm
        [Vector((-0.262, 0.158, 0.548)), Vector((-0.078, 0.172, 0.535)),
         Vector((0.096, 0.168, 0.516)), Vector((0.276, 0.150, 0.488))],
        # heart line, below the fingers
        [Vector((-0.292, 0.148, 0.708)), Vector((-0.096, 0.162, 0.680)),
         Vector((0.116, 0.160, 0.656)), Vector((0.300, 0.142, 0.620))],
        # wrist crease
        [Vector((-0.196, 0.104, 0.030)), Vector((-0.070, 0.114, 0.020)),
         Vector((0.070, 0.114, 0.020)), Vector((0.196, 0.102, 0.030))],
    ]

    for vertex in mesh.vertices:
        co = vertex.co
        normal = vertex.normal
        depth = 0.0
        # Interphalangeal creases wrap around each finger.
        for _name, points, radius in finger_data:
            for joint_index in (1, 2):
                centre = points[joint_index]
                direction = (points[joint_index + 1] - points[joint_index - 1]).normalized()
                relative = co - centre
                along = relative.dot(direction)
                radial = (relative - direction * along).length
                if abs(along) < 0.022 and radial < radius * 1.7:
                    depth = max(depth, 0.0068 * math.exp(-((along / 0.0075) ** 2)))
        # Thumb creases at the MCP and IP.
        for centre in THUMB_POINTS[1:4]:
            relative = co - centre
            if relative.length < 0.15:
                depth = max(depth, 0.0042 * math.exp(-((relative.length / 0.018) ** 2)))
        # Palm lines are shallow and only on the palmar surface.
        if co.y > 0.070:
            for line in palm_lines:
                for a, b in zip(line[:-1], line[1:]):
                    ab = b - a
                    t = max(0.0, min(1.0, (co - a).dot(ab) / ab.length_squared))
                    nearest = a + ab * t
                    d = (co - nearest).length
                    if d < 0.032:
                        depth = max(depth, 0.0036 * math.exp(-((d / 0.009) ** 2)))
        if depth > 0.0:
            vertex.co = co - normal * depth
    mesh.update()


def _sample_polyline(points, t: float) -> Vector:
    """Catmull-Rom through the thumb control points."""
    scaled = t * (len(points) - 1)
    i = min(int(scaled), len(points) - 2)
    f = scaled - i
    p0 = points[max(i - 1, 0)]
    p1 = points[i]
    p2 = points[i + 1]
    p3 = points[min(i + 2, len(points) - 1)]
    return 0.5 * (
        2 * p1
        + (-p0 + p2) * f
        + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f
        + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f
    )


# ---------------------------------------------------------------------------
# materials
# ---------------------------------------------------------------------------


def _normal_image(name: str, size: int):
    rng = np.random.default_rng(11)
    h = rng.normal(0.0, 1.0, (size, size))
    for axis in (0, 1):
        h = np.apply_along_axis(
            lambda m: np.convolve(m, np.ones(5) / 5.0, mode="same"), axis, h
        )
    h = h / (np.abs(h).max() + 1e-6)
    gy, gx = np.gradient(h)
    strength = 1.1
    nx, ny = -gx * strength, -gy * strength
    nz = np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=-1)
    rgba = np.concatenate([normal * 0.5 + 0.5, np.ones((size, size, 1))], axis=-1)
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "Non-Color"
    image.pixels = np.clip(rgba, 0, 1).astype(np.float32).ravel()
    image.pack()
    return image


def skin_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("Hand_Skin")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for n in list(nodes):
        nodes.remove(n)
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    colour = nodes.new("ShaderNodeVertexColor")
    colour.layer_name = "SkinColour"
    links.new(colour.outputs["Color"], bsdf.inputs["Base Color"])

    normal = _normal_image("Hand_Skin_Normal", 512)
    ntex = nodes.new("ShaderNodeTexImage")
    ntex.image = normal
    ntex.interpolation = "Linear"
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 0.30
    links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    bsdf.inputs["Roughness"].default_value = 0.60
    bsdf.inputs["IOR"].default_value = 1.40
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = 0.05
        bsdf.inputs["Subsurface Radius"].default_value = (0.14, 0.04, 0.025)
    return mat


def nail_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("Hand_Nails")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    # Nails are not white: they read as translucent keratin over pink skin.
    bsdf.inputs["Base Color"].default_value = (0.470, 0.245, 0.215, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.32
    bsdf.inputs["IOR"].default_value = 1.45
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.22
        bsdf.inputs["Coat Roughness"].default_value = 0.18
    return mat


# ---------------------------------------------------------------------------
# nails
# ---------------------------------------------------------------------------


def _nail_transform(direction: Vector, dorsal: Vector):
    x_axis = dorsal.cross(direction).normalized()
    y_axis = direction
    z_axis = x_axis.cross(y_axis).normalized()
    return Matrix(
        (
            (x_axis.x, y_axis.x, z_axis.x),
            (x_axis.y, y_axis.y, z_axis.y),
            (x_axis.z, y_axis.z, z_axis.z),
        )
    ).to_4x4()


def build_nails() -> bpy.types.Object:
    """Small keratin plates sunk into the dorsal face of each fingertip."""
    nail_parts = []
    dorsal = Vector((0, -1, 0))
    tip_data = []
    for name, *_ in FINGERS:
        tip = finger_tip(name)
        tip_data.append((name, tip))
        direction = (tip - finger_point(name, 0.90)).normalized()
        radius = finger_radius(name, 0.95)
        centre = tip - direction * 0.058 + dorsal * (radius * 0.80)
        rot = _nail_transform(direction, dorsal)
        nail_parts.append(
            ellipsoid_object(
                f"Nail_{name}",
                centre,
                Vector((radius * 0.66, 0.078, 0.006)),
                rotation=rot,
                segments=20,
                rings=10,
            )
        )

    # The thumb plate faces up and slightly toward the viewer.
    tip = THUMB_POINTS[-1]
    direction = (tip - THUMB_POINTS[-2]).normalized()
    thumb_dorsal = Vector((0.30, -0.85, 0.43)).normalized()
    rot = _nail_transform(direction, thumb_dorsal)
    tip_data.append(("thumb", tip))
    nail_parts.append(
        ellipsoid_object(
            "Nail_thumb",
            tip - direction * 0.050 + thumb_dorsal * 0.052,
            Vector((0.052, 0.068, 0.006)),
            rotation=rot,
            segments=20,
            rings=10,
        )
    )

    bpy.ops.object.select_all(action="DESELECT")
    for part in nail_parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = nail_parts[0]
    bpy.ops.object.join()
    nails = bpy.context.active_object
    nails.name = "HandNails"
    nails.data.materials.append(nail_material())
    nails["nail_tips"] = ";".join(f"{name}:{tip.x},{tip.y},{tip.z}" for name, tip in tip_data)
    return nails


# ---------------------------------------------------------------------------
# skeleton
# ---------------------------------------------------------------------------


def build_armature() -> bpy.types.Object:
    arm_data = bpy.data.armatures.new("HandRig")
    arm = bpy.data.objects.new("HandRig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")

    hand = arm_data.edit_bones.new("hand")
    hand.head = (0, 0, -0.20)
    hand.tail = (0, 0, 0.55)

    for name, *_ in FINGERS:
        points = [finger_point(name, t) for t in FINGER_JOINTS]
        parent = hand
        for i in range(3):
            bone = arm_data.edit_bones.new(f"{name}_{i + 1:02d}")
            bone.head = points[i]
            bone.tail = points[i + 1]
            bone.parent = parent
            bone.use_connect = i > 0
            # Roll 0 keeps local X lateral, so negative local-X rotation curls
            # the finger toward the palm.  This is the contract the runtime
            # relies on.
            bone.roll = 0.0
            parent = bone
        leaf = arm_data.edit_bones.new(f"{name}_tip")
        leaf.head = points[-1]
        leaf.tail = points[-1] + (points[-1] - points[-2]).normalized() * 0.055
        leaf.parent = parent
        leaf.use_connect = True
        leaf.roll = 0.0

    # Thumb chain.  Its bend axis is the palm normal only in the sense that the
    # thumb folds across the palm, so align local X with world Y.
    parent = hand
    for i, (head, tail) in enumerate(zip(THUMB_POINTS[:-1], THUMB_POINTS[1:])):
        bone = arm_data.edit_bones.new(f"thumb_{i + 1:02d}")
        bone.head = head
        bone.tail = tail
        bone.parent = parent
        bone.use_connect = i > 0
        direction = (tail - head).normalized()
        roll_axis = Vector((0, 1, 0)).cross(direction)
        if roll_axis.length > 1e-5:
            bone.align_roll(roll_axis.normalized())
        parent = bone
    leaf = arm_data.edit_bones.new("thumb_tip")
    leaf.head = THUMB_POINTS[-1]
    leaf.tail = THUMB_POINTS[-1] + (
        THUMB_POINTS[-1] - THUMB_POINTS[-2]
    ).normalized() * 0.05
    leaf.parent = parent
    leaf.use_connect = True

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def _closest_on_curve(points, p: Vector):
    """Distance from p to a polyline, plus its parameter in [0, 1]."""
    best_d = 1e9
    best_t = 0.0
    segments = len(points) - 1
    for i in range(segments):
        a, b = points[i], points[i + 1]
        ab = b - a
        span = ab.length_squared
        if span < 1e-12:
            continue
        f = max(0.0, min(1.0, (p - a).dot(ab) / span))
        d = (p - (a + ab * f)).length
        if d < best_d:
            best_d = d
            best_t = (i + f) / segments
    return best_d, best_t


def _clamp01(v: float) -> float:
    return max(0.0, min(1.0, v))


def _bone_mix(t: float, joints):
    """Smooth two-bone blend for a point at parameter t along a chain."""
    centres = [(joints[i] + joints[i + 1]) * 0.5 for i in range(len(joints) - 1)]
    span = 0.30
    weights = [max(0.0, 1.0 - abs(t - c) / span) for c in centres]
    total = sum(weights)
    if total <= 0.0:
        # Between curves: fall back to the nearest segment.
        nearest = min(range(len(centres)), key=lambda i: abs(t - centres[i]))
        weights = [0.0] * len(centres)
        weights[nearest] = 1.0
        total = 1.0
    return [w / total for w in weights]


def _skin_chains():
    chains = []
    for name, *_ in FINGERS:
        points = [finger_point(name, i / 32) for i in range(33)]
        chains.append(
            {
                "name": name,
                "points": points,
                "joints": list(FINGER_JOINTS),
                "bones": [f"{name}_{i + 1:02d}" for i in range(3)],
                "radius": lambda t, n=name: finger_radius(n, t),
            }
        )
    thumb_points = [_sample_polyline(THUMB_POINTS, i / 32) for i in range(33)]
    chains.append(
        {
            "name": "thumb",
            "points": thumb_points,
            "joints": [0.0, 0.25, 0.5, 0.75, 1.0],
            "bones": [f"thumb_{i + 1:02d}" for i in range(4)],
            "radius": lambda t: 0.168 - 0.076 * t,
        }
    )
    return chains


def skin_objects(hand: bpy.types.Object, nails: bpy.types.Object, arm: bpy.types.Object):
    """Weight the hand analytically instead of with heat-map auto weights.

    Bone-heat weighting leaks the thumb bones into the palm, so folding the
    thumb tears a crease across the hand.  Driving the weights from the same
    centreline curves that generated the mesh keeps every vertex on the chain
    that actually owns it.
    """
    hand.data.materials.append(skin_material())
    chains = _skin_chains()
    groups = {bone.name: hand.vertex_groups.new(name=bone.name) for bone in arm.data.bones}

    for vertex in hand.data.vertices:
        p = vertex.co
        influences = []
        raw_total = 0.0
        for chain in chains:
            d, t = _closest_on_curve(chain["points"], p)
            radius = max(chain["radius"](t), 0.012)
            norm = d / radius
            # 1.0 inside the finger, fading to 0 a little outside the surface.
            f = _clamp01((1.75 - norm) / 0.55)
            # Vertices below the knuckle belong to the palm.  Without this
            # ramp the thumb root drags the thenar mass across the hand.
            if chain["name"] == "thumb":
                f *= 0.78 * _clamp01((t - 0.05) / 0.16)
            else:
                f *= _clamp01(t / 0.09)
            if f <= 0.0:
                continue
            influences.append((chain, t, f))
            raw_total += f
        if raw_total <= 0.0:
            groups["hand"].add([vertex.index], 1.0, "REPLACE")
            continue
        # Do not let adjacent chains claim more than the whole vertex.
        scale = min(1.0, raw_total) / raw_total
        finger_total = 0.0
        for chain, t, f in influences:
            f *= scale
            finger_total += f
            mix = _bone_mix(t, chain["joints"])
            for bone_name, weight in zip(chain["bones"], mix):
                if weight > 0.0005:
                    groups[bone_name].add([vertex.index], f * weight, "REPLACE")
        hand_weight = max(0.0, 1.0 - finger_total)
        if hand_weight > 0.0005:
            groups["hand"].add([vertex.index], hand_weight, "REPLACE")

    hand.parent = arm
    hand.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = hand.modifiers.new("Armature", "ARMATURE")
    mod.object = arm

    # Nails are rigidly skinned to their distal bones; one extra draw call is
    # cheaper and more robust than five separate nail objects.
    tips = {name: tip for name, tip in _nail_tip_data(nails)}
    nail_groups = {name: nails.vertex_groups.new(name=f"{name}_03") for name in tips if name != "thumb"}
    nail_groups["thumb"] = nails.vertex_groups.new(name="thumb_04")
    for vertex in nails.data.vertices:
        nearest = min(tips, key=lambda n: (vertex.co - tips[n]).length)
        nail_groups[nearest].add([vertex.index], 1.0, "REPLACE")
    nail_mod = nails.modifiers.new("Armature", "ARMATURE")
    nail_mod.object = arm
    nails.parent = arm
    nails.matrix_parent_inverse = arm.matrix_world.inverted()


def _nail_tip_data(nails: bpy.types.Object):
    raw = nails.get("nail_tips", "")
    for item in str(raw).split(";"):
        if not item:
            continue
        name, coords = item.split(":")
        x, y, z = (float(v) for v in coords.split(","))
        yield name, Vector((x, y, z))


# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------


def select_tree(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def export_glb(root: bpy.types.Object, path: str) -> None:
    select_tree(root)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_extras=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_skins=True,
        export_animations=False,
        export_image_format="AUTO",
    )


# ---------------------------------------------------------------------------
# preview
# ---------------------------------------------------------------------------


def setup_studio(dorsal: bool = False, three_quarter: bool = False) -> None:
    col = collection("Hand_Studio")
    if three_quarter:
        location = (1.15, -3.55 if dorsal else 3.55, 1.35)
    else:
        location = (0.35, -4.2 if dorsal else 4.2, 0.95)
    bpy.ops.object.camera_add(location=location)
    cam = bpy.context.active_object
    cam.name = "Hand_Camera"
    if three_quarter:
        cam.data.lens = 75
    else:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 2.55
    target = Vector((0.02, 0.0, 0.90))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    move_to_collection(cam, col)
    bpy.context.scene.camera = cam

    for name, loc, energy, size in [
        ("Key", (-1.6, -2.2 if dorsal else 2.2, 2.9), 380.0, 2.2),
        ("Fill", (2.2, -1.2 if dorsal else 1.2, 1.3), 120.0, 2.0),
        ("Rim", (0.4, 2.2 if dorsal else -2.2, 2.4), 220.0, 1.8),
    ]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        d = Vector((0.05, 0.0, 0.95)) - light.location
        light.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        move_to_collection(light, col)

    world = bpy.data.worlds.new("Hand_World")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.030, 0.065, 0.082, 1.0)
    bg.inputs["Strength"].default_value = 0.85
    bpy.context.scene.world = world

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    try:
        scene.eevee.taa_render_samples = 48
    except Exception:
        pass


# Fold amounts per finger, in radians about the local X axis.  The three
# segments close progressively so the fingertip ends up over the palm.
FOLD = {
    "index": (-0.86, -0.98, -0.42),
    "middle": (-0.82, -1.02, -0.46),
    "ring": (-0.88, -1.00, -0.44),
    "pinky": (-0.94, -1.02, -0.48),
}
THUMB_FOLD = (-0.82, -0.42, -0.28, -0.16)


def set_pose(arm: bpy.types.Object, extensions: dict[str, float]) -> None:
    """Pose the rig.  1 = fully extended, 0 = folded toward the palm."""
    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0, 0, 0)
    for name, extension in extensions.items():
        curl = 1.0 - extension
        if curl <= 0.001:
            continue
        if name == "thumb":
            for i, angle in enumerate(THUMB_FOLD):
                arm.pose.bones[f"thumb_{i + 1:02d}"].rotation_euler.x = angle * curl
        else:
            for i, angle in enumerate(FOLD[name]):
                arm.pose.bones[f"{name}_{i + 1:02d}"].rotation_euler.x = angle * curl
    bpy.context.view_layer.update()


def render_preview(path: str) -> None:
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


POSES = {
    "pose-0": {n: 0.0 for n in (*[f[0] for f in FINGERS], "thumb")},
    "pose-1": {**{n: 0.0 for n in [f[0] for f in FINGERS]}, "index": 1.0},
    "pose-2": {
        **{n: 0.0 for n in [f[0] for f in FINGERS]},
        "index": 1.0,
        "middle": 1.0,
    },
    "pose-4": {**{n: 1.0 for n in [f[0] for f in FINGERS]}, "thumb": 0.0},
    "pose-5": {**{n: 0.0 for n in [f[0] for f in FINGERS]}, "thumb": 1.0},
    "pose-9": {**{n: 1.0 for n in [f[0] for f in FINGERS]}, "thumb": 1.0},
}


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("build", "preview"), default="build")
    # Blender 5.x forwards its own flags into sys.argv; only parse our tail.
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    args = parser.parse_args(argv)

    reset_scene()
    os.makedirs(ASSET_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)

    hand = build_hand_mesh()
    nails = build_nails()
    arm = build_armature()
    skin_objects(hand, nails, arm)

    root = bpy.data.objects.new("Hand_Root", None)
    bpy.context.scene.collection.objects.link(root)
    # Keep the armature as the parent of the skinned meshes: the glTF exporter
    # uses that relationship to build skins.  Only the armature hangs off the
    # scene root.
    arm.parent = root

    if args.mode == "preview":
        setup_studio(dorsal=False)
        for name, extensions in POSES.items():
            set_pose(arm, extensions)
            render_preview(os.path.join(PREVIEW_DIR, f"{name}.png"))
        setup_studio(dorsal=True)
        for name, extensions in POSES.items():
            set_pose(arm, extensions)
            render_preview(os.path.join(PREVIEW_DIR, f"{name}-dorsal.png"))
        setup_studio(dorsal=True, three_quarter=True)
        set_pose(arm, POSES["pose-0"])
        render_preview(os.path.join(PREVIEW_DIR, "pose-0-three-quarter.png"))
        set_pose(arm, POSES["pose-9"])
        render_preview(os.path.join(PREVIEW_DIR, "pose-9-three-quarter.png"))
    else:
        export_glb(root, os.path.join(ASSET_DIR, "hand.glb"))
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ASSET_DIR, "hand.blend"))
        tris = sum(len(p.vertices) - 2 for p in hand.data.polygons)
        print(f"BUILT HAND tris={tris} verts={len(hand.data.vertices)}")


if __name__ == "__main__":
    main()
