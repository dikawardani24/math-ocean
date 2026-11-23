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
# crease (z = 0) to the knuckles (z ~ 0.95); the middle fingertip reaches
# z ~ 1.87.  Proportions follow a relaxed adult right hand: the palm is about
# 1.2 middle-finger lengths, fingers are roughly four times longer than they
# are wide, the index/middle/ring tips form a gentle arc, and the little
# finger is noticeably shorter and thinner.  The thumb is abducted about 40
# degrees with a real web space, so it reads as a thumb rather than a fifth
# finger.
FINGERS = [
    # name, base x, tip x, length, base radius, knuckle z
    ("index", 0.282, 0.330, 0.820, 0.089, 0.948),
    ("middle", 0.094, 0.110, 0.900, 0.092, 0.962),
    ("ring", -0.094, -0.132, 0.850, 0.087, 0.948),
    ("pinky", -0.272, -0.325, 0.685, 0.075, 0.922),
]
FINGERS_BY_NAME = {f[0]: f for f in FINGERS}

# Thumb chain: carpal root, metacarpal head, proximal phalanx, distal phalanx.
# The metacarpal is buried in the thenar mass; the visible thumb leaves the
# palm at the web, angles about 30 degrees from vertical and stops just below
# the index knuckle.  A thumb that reaches as far as the fingers, or sits out
# at 45 degrees like a fifth finger, is what made the old model read as a mitt.
THUMB_POINTS = [
    Vector((0.150, 0.032, 0.150)),
    Vector((0.300, 0.062, 0.360)),
    Vector((0.415, 0.082, 0.560)),
    Vector((0.492, 0.096, 0.780)),
    Vector((0.535, 0.104, 0.915)),
]
FINGER_JOINTS = (0.0, 0.42, 0.73, 1.0)

# Palmar flexion creases, in the XZ plane.  They are carved into the geometry
# and also painted slightly darker, which is what makes them read as creases
# rather than as smudges on a smooth surface.
PALM_LINES = [
    # life line, around the thenar pad
    [Vector((0.300, 0.0, 0.560)), Vector((0.240, 0.0, 0.440)),
     Vector((0.140, 0.0, 0.300)), Vector((0.030, 0.0, 0.180)),
     Vector((0.000, 0.0, 0.105))],
    # head line, across the palm
    [Vector((-0.310, 0.0, 0.660)), Vector((-0.100, 0.0, 0.620)),
     Vector((0.120, 0.0, 0.585)), Vector((0.310, 0.0, 0.545))],
    # heart line, below the fingers
    [Vector((-0.280, 0.0, 0.845)), Vector((-0.060, 0.0, 0.795)),
     Vector((0.140, 0.0, 0.755)), Vector((0.330, 0.0, 0.690))],
    # wrist crease
    [Vector((-0.220, 0.0, 0.025)), Vector((-0.060, 0.0, 0.005)),
     Vector((0.060, 0.0, 0.005)), Vector((0.220, 0.0, 0.025))],
]


def thumb_radius(t: float) -> float:
    """Radius of the thumb chain: broad at the CMC, slim at the tip."""
    radius = 0.150 - 0.060 * t
    # Metacarpophalangeal and interphalangeal swellings.
    radius += 0.010 * math.exp(-(((t - 0.22) / 0.14) ** 2))
    radius += 0.006 * math.exp(-(((t - 0.60) / 0.10) ** 2))
    # The distal tuft is broad and rounded, not a pointed sausage.
    radius += 0.010 * math.exp(-(((t - 0.94) / 0.07) ** 2))
    return radius


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
    return Vector((base_x, -0.004, knuckle_z))


def finger_tip(name: str) -> Vector:
    _, _, tip_x, length, _, knuckle_z = FINGERS_BY_NAME[name]
    return Vector((tip_x, 0.004, knuckle_z + length))


def finger_point(name: str, t: float) -> Vector:
    """Sample the finger centreline.  Fingers fan out and bow to the palm."""
    base = finger_base(name)
    tip = finger_tip(name)
    length = (tip.z - base.z)
    fan = (tip.x - base.x) * (t ** 1.5)
    # A relaxed finger is not a ruler: it bows very slightly toward the palm
    # and drops a touch at the tip.  Kept subtle so an extended Jarimatika
    # finger still reads as straight.
    bow = (0.010 * math.sin(math.pi * t) + 0.012 * t * t) * length
    return Vector((base.x + fan, base.y + bow, base.z + length * t))


def finger_radius(name: str, t: float) -> float:
    _, _, _, length, base_radius, _ = FINGERS_BY_NAME[name]
    radius = base_radius * (1.0 - 0.16 * t)
    # Metacarpophalangeal, PIP and DIP joints are a little wider than the
    # shafts between them.  The swell is small; the crease sculpt does the
    # rest of the reading.
    for joint, swell in ((0.0, 0.0035), (0.42, 0.0055), (0.73, 0.0040)):
        radius += swell * math.exp(-(((t - joint) / 0.06) ** 2))
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
    """Lofted palm with the thenar and hypothenar built into the surface.

    The mounds are displaced into the loft instead of being separate
    ellipsoids: a sphere stuck onto a flat slab unions into an obvious oval
    lump, which is exactly what the previous hand looked like.  Here the
    palmar surface swells continuously from the wrist to the knuckles.
    """
    profile = [
        # z, half width, half depth
        (-0.470, 0.196, 0.048),
        (-0.420, 0.212, 0.052),
        (-0.340, 0.226, 0.056),
        (-0.240, 0.242, 0.061),
        (-0.140, 0.260, 0.067),
        (-0.040, 0.282, 0.074),
        (0.080, 0.310, 0.081),
        (0.220, 0.342, 0.088),
        (0.380, 0.370, 0.094),
        (0.540, 0.390, 0.098),
        (0.700, 0.401, 0.098),
        (0.820, 0.401, 0.093),
        (0.890, 0.394, 0.086),
        (0.930, 0.382, 0.078),
        (0.955, 0.366, 0.066),
    ]
    sides = 64
    verts = []
    faces = []
    exponent = 2.2
    for z, rx, ry in profile:
        for i in range(sides):
            a = 2 * math.pi * i / sides
            c, s = math.cos(a), math.sin(a)
            x = math.copysign(abs(c) ** (2 / exponent), c) * rx
            y = math.copysign(abs(s) ** (2 / exponent), s) * ry
            if s > 0.0:
                # Palmar surface only: thenar mound under the thumb, the
                # hypothenar along the little-finger edge, and a shallow
                # hollow down the middle where the palm cups.
                thenar = 0.060 * math.exp(
                    -(((x - 0.235) / 0.150) ** 2 + ((z - 0.330) / 0.255) ** 2)
                )
                hypothenar = 0.036 * math.exp(
                    -(((x + 0.290) / 0.105) ** 2 + ((z - 0.295) / 0.235) ** 2)
                )
                hollow = 0.014 * math.exp(
                    -(((x + 0.010) / 0.155) ** 2 + ((z - 0.480) / 0.220) ** 2)
                )
                fade = s ** 0.65
                y += (thenar + hypothenar - hollow) * fade
            verts.append(Vector((x, y, z)))
    for r in range(len(profile) - 1):
        a = r * sides
        b = (r + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    bottom = len(verts)
    verts.append(Vector((0, 0, profile[0][0] - 0.012)))
    top = len(verts)
    verts.append(Vector((0, 0, profile[-1][0] + 0.008)))
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
    samples = 36
    rings = []
    for i in range(samples):
        t = i / (samples - 1)
        centre = finger_point(name, t)
        radius = finger_radius(name, t)
        direction = (finger_point(name, min(1.0, t + 0.02)) - finger_point(name, max(0.0, t - 0.02)))
        if direction.length < 1e-6:
            direction = Vector((0, 0, 1))
        # The palmar pad swells over the distal third of the finger; the
        # dorsal side stays flatter, so the cross-section is not a sausage.
        pad = 0.0100 * math.exp(-(((t - 0.88) / 0.14) ** 2))
        centre = centre + Vector((0.0, pad * 0.52, 0.0))
        # First radius is depth (palmar-dorsal), second is width.  Fingers are
        # a little wider than they are deep and flatten toward the tip.
        depth = radius * 0.88 + pad * 0.25
        width = radius + pad * 0.12
        rings.append((centre, depth, width, direction))
    return tube_object(label or name, rings, sides=28)


def build_hand_mesh() -> bpy.types.Object:
    parts = [palm_object()]

    for name, base_x, tip_x, length, radius, knuckle_z in FINGERS:
        base = finger_base(name)
        tip = finger_tip(name)
        parts.append(finger_object(name, f"Finger_{name}"))
        tip_radius = finger_radius(name, 1.0)
        tip_dir = (tip - finger_point(name, 0.94)).normalized()
        parts.append(
            ellipsoid_object(
                f"FingerTip_{name}",
                tip - tip_dir * (tip_radius * 0.34),
                Vector((tip_radius * 1.00, tip_radius * 0.90, tip_radius * 0.96)),
            )
        )
        # Fleshy fingertip pulp on the palmar side.  It has to sit proud of the
        # tube surface: a pad buried inside the finger does nothing.
        parts.append(
            ellipsoid_object(
                f"FingerPad_{name}",
                finger_point(name, 0.93) + Vector((0.0, tip_radius * 0.62, 0.0)),
                Vector((tip_radius * 0.78, tip_radius * 0.38, tip_radius * 0.74)),
            )
        )
        # Metacarpophalangeal knuckle: a distinct dorsal dome.  There is no
        # matching palmar ball: a row of spheres across the palm reads as a
        # string of beads, not knuckles.
        parts.append(
            ellipsoid_object(
                f"Knuckle_{name}",
                Vector((base_x, -0.052, knuckle_z + 0.002)),
                Vector((radius * 0.92, 0.026, radius * 0.48)),
            )
        )
        # Interdigital webbing.  It fills the notch between two finger roots,
        # but it must not rise as a ball above the knuckle line.
        if name != "pinky":
            index = [f[0] for f in FINGERS].index(name)
            next_base = finger_base(FINGERS[index + 1][0])
            mid = (base + next_base) * 0.5
            parts.append(
                ellipsoid_object(
                    f"Web_{name}",
                    Vector((mid.x, 0.0, mid.z - 0.020)),
                    Vector((abs(next_base.x - base.x) * 0.52, 0.080, 0.042)),
                )
            )

    # Dorsal interosseous ridges.  They are deliberately faint, but without
    # them the back of the hand is a flat paddle between wrist and knuckles.
    for name, base_x, tip_x, length, radius, knuckle_z in FINGERS:
        parts.append(
            capsule_object(
                f"Tendon_{name}",
                Vector((base_x * 0.30, -0.076, 0.240)),
                Vector((base_x, -0.080, knuckle_z - 0.010)),
                0.020,
                0.008,
            )
        )

    # Soft web where the thumb leaves the palm.  Two overlapping volumes make
    # a deep, curved web space instead of a socket with a visible notch.
    parts.append(
        ellipsoid_object(
            "ThumbWeb",
            Vector((0.330, 0.022, 0.565)),
            Vector((0.112, 0.070, 0.155)),
        )
    )

    # Thumb: the metacarpal is buried in the thenar, so the visible tube starts
    # a little above the CMC joint.  Its cross-section is flattened across the
    # palm so the base does not balloon out of the back of the hand.
    thumb_rings = []
    samples = 30
    for i in range(samples):
        t = 0.18 + 0.82 * i / (samples - 1)
        pos = _sample_polyline(THUMB_POINTS, t)
        direction = _sample_polyline(THUMB_POINTS, min(1.0, t + 0.02)) - _sample_polyline(
            THUMB_POINTS, max(0.0, t - 0.02)
        )
        r = thumb_radius(t)
        thumb_rings.append((pos, r * 0.82, r, direction))
    parts.append(tube_object("Thumb", thumb_rings, sides=28))
    parts.append(
        ellipsoid_object(
            "ThumbTip",
            THUMB_POINTS[-1] - (THUMB_POINTS[-1] - THUMB_POINTS[-2]).normalized() * 0.018,
            Vector((0.086, 0.082, 0.090)),
        )
    )
    # Flat, fleshy pad on the palmar face of the distal thumb.
    parts.append(
        ellipsoid_object(
            "ThumbPad",
            _sample_polyline(THUMB_POINTS, 0.90) + Vector((0.0, 0.040, 0.0)),
            Vector((0.062, 0.036, 0.062)),
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
    # surface, then a light smooth pass removes the voxel stair-stepping.  The
    # voxel has to be small relative to the finger radius (~0.065 at the tip):
    # at 0.0115 the shafts came out lumpy and the webs filled in solid.
    remesh = hand.modifiers.new("VoxelUnion", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.0085
    remesh.use_smooth_shade = True
    bpy.context.view_layer.objects.active = hand
    bpy.ops.object.modifier_apply(modifier=remesh.name)

    smooth = hand.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.5
    smooth.iterations = 2
    bpy.ops.object.modifier_apply(modifier=smooth.name)

    # Keep the silhouette but spend the vertex budget on the palm and fingers
    # rather than the uniform voxel grid.
    decimate = hand.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = 0.32
    bpy.ops.object.modifier_apply(modifier=decimate.name)

    _sculpt_details(hand)
    _paint_skin(hand)
    bpy.context.view_layer.update()
    return hand


# ---------------------------------------------------------------------------
# skin colour and fine detail
# ---------------------------------------------------------------------------


def _crease_mask(p: Vector) -> float:
    """1 on a crease, 0 on smooth skin, used to darken crease pigment."""
    mask = 0.0
    for name, *_ in FINGERS:
        points = [finger_point(name, t) for t in FINGER_JOINTS]
        radius = finger_radius(name, 0.42)
        for joint_index in (1, 2):
            centre = points[joint_index]
            direction = (points[joint_index + 1] - points[joint_index - 1]).normalized()
            relative = p - centre
            along = relative.dot(direction)
            radial = (relative - direction * along).length
            if abs(along) < 0.022 and radial < radius * 1.7:
                weight = 0.55 if p.y < 0.0 else 1.0
                mask = max(mask, weight * math.exp(-((along / 0.010) ** 2)))
    for joint_index in (2, 3):
        centre = THUMB_POINTS[joint_index]
        direction = (
            THUMB_POINTS[joint_index + 1] - THUMB_POINTS[joint_index - 1]
        ).normalized()
        relative = p - centre
        along = relative.dot(direction)
        radial = (relative - direction * along).length
        if abs(along) < 0.022 and radial < 0.125:
            weight = 0.55 if p.y < 0.0 else 1.0
            mask = max(mask, weight * math.exp(-((along / 0.009) ** 2)))
    if p.y > 0.015:
        for line in PALM_LINES:
            for a, b in zip(line[:-1], line[1:]):
                ab = b - a
                t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
                nearest = a + ab * t
                d = math.hypot(p.x - nearest.x, p.z - nearest.z)
                if d < 0.055:
                    mask = max(mask, math.exp(-((d / 0.0190) ** 2)))
    return min(1.0, mask)


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
        base = Vector((0.470, 0.255, 0.198))
        if p.y > 0.095 and p.z > 0.02:
            base = base.lerp(Vector((0.575, 0.360, 0.286)), 0.55)
        elif p.y < -0.045:
            base = base.lerp(Vector((0.420, 0.226, 0.172)), 0.45)
        redness = 0.0
        for joint in joints:
            d = (p - joint).length
            if d < 0.115:
                redness = max(redness, (1.0 - d / 0.115) ** 2)
        base = base.lerp(Vector((0.580, 0.262, 0.205)), 0.34 * redness)
        # Crease pigment: a crease is a line of thin, slightly darker skin.
        crease = _crease_mask(p)
        base *= 1.0 - 0.30 * crease
        variation = field(p * 1.1) * 0.020 + field(p * 3.1) * 0.008
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

    palm_lines = PALM_LINES

    for vertex in mesh.vertices:
        co = vertex.co
        normal = vertex.normal
        depth = 0.0
        # Interphalangeal creases wrap around each finger.  The MCP crease is
        # shallower and only cut on the palmar side.
        for _name, points, radius in finger_data:
            for joint_index in (0, 1, 2):
                centre = points[joint_index]
                direction = (points[joint_index + 1] - points[joint_index - 1]).normalized()
                relative = co - centre
                along = relative.dot(direction)
                radial = (relative - direction * along).length
                if abs(along) < 0.026 and radial < radius * 1.75:
                    if joint_index == 0 and relative.y < 0.0:
                        continue
                    strength = 0.0130 if joint_index else 0.0075
                    depth = max(depth, strength * math.exp(-((along / 0.0075) ** 2)))
        # Thumb creases at the MCP and IP, wrapping around the digit.
        for joint_index in (2, 3):
            centre = THUMB_POINTS[joint_index]
            direction = (
                THUMB_POINTS[joint_index + 1] - THUMB_POINTS[joint_index - 1]
            ).normalized()
            relative = co - centre
            along = relative.dot(direction)
            radial = (relative - direction * along).length
            if abs(along) < 0.024 and radial < 0.130:
                depth = max(depth, 0.0110 * math.exp(-((along / 0.0070) ** 2)))
        # Palm lines: project into the palm plane so the crease follows the
        # thenar/hypothenar curvature instead of needing an exact Y.
        if co.y > 0.015:
            for line in palm_lines:
                for a, b in zip(line[:-1], line[1:]):
                    ab = b - a
                    t = max(0.0, min(1.0, (co - a).dot(ab) / ab.length_squared))
                    nearest = a + ab * t
                    d = math.hypot(co.x - nearest.x, co.z - nearest.z)
                    if d < 0.040:
                        depth = max(depth, 0.0040 * math.exp(-((d / 0.0160) ** 2)))
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

    bsdf.inputs["Roughness"].default_value = 0.52
    bsdf.inputs["IOR"].default_value = 1.40
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = 0.05
        bsdf.inputs["Subsurface Radius"].default_value = (0.14, 0.04, 0.025)
    return mat


def nail_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("Hand_Nails")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    # Nails are not white: they read as translucent keratin over pink skin,
    # a little lighter and cooler than the finger but never chalk.
    bsdf.inputs["Base Color"].default_value = (0.300, 0.160, 0.145, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.46
    bsdf.inputs["IOR"].default_value = 1.45
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.10
        bsdf.inputs["Coat Roughness"].default_value = 0.22
    return mat


# ---------------------------------------------------------------------------
# nails
# ---------------------------------------------------------------------------


def _nail_frame(direction: Vector):
    """Ring frame matching tube_object: local x is dorsal, local y is width."""
    direction = direction.normalized()
    helper = Vector((1, 0, 0)) if abs(direction.x) < 0.9 else Vector((0, 1, 0))
    x_axis = helper.cross(direction).normalized()
    y_axis = direction.cross(x_axis).normalized()
    return x_axis, y_axis


def _nail_shell(
    name: str,
    point_fn,
    radius_fn,
    depth_scale: float,
    t0: float,
    t1: float,
    half_angle: float,
) -> bpy.types.Object:
    """A curved keratin plate that hugs the dorsal surface of a digit.

    The plate is built on the same centreline curve as the finger, so it
    follows the bow of the digit and the rounded tip instead of floating like
    a flat sticker.  It is a thin shell: an outer surface, an inner surface and
    a rim, which reads as a real nail at grazing angles.
    """
    rows, cols = 8, 13
    thickness = 0.0035
    outer = []
    inner = []
    for r in range(rows):
        v = r / (rows - 1)
        t = t0 + (t1 - t0) * v
        centre = point_fn(t)
        tangent = (point_fn(min(1.0, t + 0.02)) - point_fn(max(0.0, t - 0.02))).normalized()
        x_axis, y_axis = _nail_frame(tangent)
        radius = radius_fn(t)
        # Rounded-rectangle outline: wide through the middle, rounded at the
        # cuticle and the free edge, with a little straight run between.
        vv = 0.08 + 0.84 * v
        span = half_angle * (1.0 - abs(2.0 * vv - 1.0) ** 8) ** 0.30
        for c in range(cols):
            u = c / (cols - 1)
            a = -span + 2.0 * span * u
            ca, sa = math.cos(a), math.sin(a)
            # Point on the elliptical finger cross-section.
            p = centre + x_axis * (ca * radius * depth_scale) + y_axis * (sa * radius)
            # Outward normal of that ellipse.
            normal = (
                x_axis * (ca / max(radius * depth_scale, 1e-5))
                + y_axis * (sa / max(radius, 1e-5))
            ).normalized()
            # Lift only a hair above the skin; the shell's rim closes the gap.
            outer.append(p + normal * (thickness + 0.0015))
            inner.append(p + normal * 0.0002)
    faces = []
    for r in range(rows - 1):
        for c in range(cols - 1):
            a = r * cols + c
            b = a + 1
            d = a + cols
            e = d + 1
            faces.append((a, b, e, d))
            base = rows * cols
            faces.append((base + a, base + d, base + e, base + b))
    # Rim: stitch the two surfaces around the perimeter.
    base = rows * cols
    for r in range(rows - 1):
        a = r * cols
        d = a + cols
        faces.append((a, d, base + d, base + a))
        b = r * cols + cols - 1
        e = b + cols
        faces.append((b, base + b, base + e, e))
    for c in range(cols - 1):
        a = c
        b = c + 1
        faces.append((a, base + a, base + b, b))
        d = (rows - 1) * cols + c
        e = d + 1
        faces.append((d, e, base + e, base + d))
    return new_mesh(name, outer + inner, faces)


def build_nails() -> bpy.types.Object:
    """Keratin plates seated on the dorsal tip of every digit."""
    nail_parts = []
    tip_data = []
    for name, *_ in FINGERS:
        nail_parts.append(
            _nail_shell(
                f"Nail_{name}",
                lambda t, n=name: finger_point(n, t),
                lambda t, n=name: finger_radius(n, t),
                0.88,
                0.820,
                0.990,
                0.96,
            )
        )
        tip_data.append((name, finger_tip(name)))

    # Thumbnail: smaller, rounder, and turned with the opposed thumb.
    nail_parts.append(
        _nail_shell(
            "Nail_thumb",
            lambda t: _sample_polyline(THUMB_POINTS, t),
            thumb_radius,
            0.82,
            0.790,
            0.985,
            0.90,
        )
    )
    tip_data.append(("thumb", THUMB_POINTS[-1]))

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
            "radius": lambda t: thumb_radius(t),
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
            # The thumb chain runs through the thenar mass.  Full weight only
            # from the visible base of the thumb upward; deeper vertices stay
            # with the hand so folding the thumb does not drag the palm.
            if chain["name"] == "thumb":
                f *= 0.90 * _clamp01((t - 0.26) / 0.20)
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

    for name, loc, energy, size, colour in [
        ("Key", (-1.6, -2.2 if dorsal else 2.2, 2.9), 150.0, 2.2, (1.0, 0.94, 0.87)),
        ("Fill", (2.2, -1.2 if dorsal else 1.2, 1.3), 48.0, 2.0, (1.0, 0.88, 0.78)),
        ("Rim", (0.4, 2.2 if dorsal else -2.2, 2.4), 95.0, 1.8, (0.80, 0.90, 1.0)),
    ]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = colour
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
    "index": (-0.86, -1.02, -0.92),
    "middle": (-0.82, -1.06, -0.98),
    "ring": (-0.88, -1.04, -0.96),
    "pinky": (-0.94, -1.06, -1.00),
}
THUMB_FOLD = (-0.32, -1.05, -0.85, -0.45)


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
