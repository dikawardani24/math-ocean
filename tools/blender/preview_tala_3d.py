import bpy
import math
import os
from mathutils import Vector, Euler

GLB = '/Users/intikom/Desktop/math-ocean/assets/3d/characters/tala_sea_turtle.glb'
OUT = '/Users/intikom/Desktop/math-ocean/evidence-out/tala-3d'
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

model = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]

world = bpy.context.scene.world
if world is None:
    world = bpy.data.worlds.new('World')
    bpy.context.scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes['Background']
bg.inputs['Color'].default_value = (0.018, 0.09, 0.12, 1)
bg.inputs['Strength'].default_value = 1.0

key = bpy.data.lights.new('Key', 'AREA')
key.energy = 900
key.size = 5
key_obj = bpy.data.objects.new('Key', key)
bpy.context.collection.objects.link(key_obj)
key_obj.location = (3, -4, 5)
key_obj.rotation_euler = (math.radians(45), 0, math.radians(35))
fill = bpy.data.lights.new('Fill', 'AREA')
fill.energy = 350
fill.size = 6
fill_obj = bpy.data.objects.new('Fill', fill)
bpy.context.collection.objects.link(fill_obj)
fill_obj.location = (-4, -2, 1)
fill_obj.rotation_euler = (math.radians(80), 0, math.radians(-60))
rim = bpy.data.lights.new('Rim', 'AREA')
rim.energy = 500
rim.size = 4
rim_obj = bpy.data.objects.new('Rim', rim)
bpy.context.collection.objects.link(rim_obj)
rim_obj.location = (0, 4, 2)
rim_obj.rotation_euler = (math.radians(-70), 0, 0)

cam_data = bpy.data.cameras.new('Camera')
cam = bpy.data.objects.new('Camera', cam_data)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.film_transparent = False
scene.eevee.taa_render_samples = 32

CAM_POS = (0.55, 0.72, 2.85)
CAM_TARGET = (0.0, 0.02, 0.0)
FOV = 34.0
MODEL_H = 0.7055
# world scale used by the app for a 190 px turtle in a 288 px tall box
WORLD_SCALE = 190.0 / ((288.0 / 1.826) * MODEL_H)


def g2b(p):
    return Vector((p[0], -p[2], p[1]))


def look_at(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()


def set_camera(pos, target):
    cam.location = g2b(pos)
    look_at(cam, g2b(target))
    cam_data.sensor_fit = 'VERTICAL'
    cam_data.angle_y = math.radians(FOV)


def set_pose(yaw_deg=0.0, pitch_deg=0.0, roll_deg=0.0, x=0.0, y=0.0, z=0.0):
    model.rotation_mode = 'XYZ'
    model.rotation_euler = Euler(
        (math.radians(pitch_deg), 0.0, math.radians(yaw_deg)), 'XYZ')
    model.scale = (WORLD_SCALE, WORLD_SCALE, WORLD_SCALE)
    model.location = g2b((x, y, z))


def render(name, w=312, h=288):
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.filepath = os.path.join(OUT, name + '.png')
    bpy.ops.render.render(write_still=True)
    print('RENDERED', scene.render.filepath, 'scale', round(WORLD_SCALE, 3))


set_camera(CAM_POS, CAM_TARGET)

set_pose()
render('10-app-rest')

set_pose(yaw_deg=30)
render('11-app-yaw30')

set_pose(pitch_deg=15)
render('12-app-pitch15')

set_pose(yaw_deg=22, pitch_deg=10, roll_deg=-12)
render('13-app-combo')

# depth: near (+z) and far (-z) around the same screen centre
set_pose(yaw_deg=8, z=0.32)
render('14-app-near')

set_pose(yaw_deg=8, z=-0.32)
render('15-app-far')

# moved to the horizontal and vertical extremes of a 312x288 box
set_pose(yaw_deg=24, x=0.30, y=0.12)
render('16-app-right')

set_pose(yaw_deg=-24, x=-0.30, y=-0.12)
render('17-app-left')

# discovery box 360x252 at the same camera, 185 px turtle
scene.render.resolution_x = 360
set_pose(yaw_deg=-12, pitch_deg=-8, roll_deg=6)
render('18-app-discovery', 360, 252)
