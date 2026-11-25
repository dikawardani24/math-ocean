import bpy
import math
import os
from mathutils import Vector

GLB = '/Users/intikom/Desktop/math-ocean/assets/3d/characters/tala_sea_turtle.glb'
OUT = '/Users/intikom/Desktop/math-ocean/evidence-out/tala-behavior'
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
print('MESH COUNT', len(meshes))
mins = Vector((1e9, 1e9, 1e9))
maxs = Vector((-1e9, -1e9, -1e9))
for o in meshes:
    for corner in o.bound_box:
        w = o.matrix_world @ Vector(corner)
        mins = Vector((min(mins.x, w.x), min(mins.y, w.y), min(mins.z, w.z)))
        maxs = Vector((max(maxs.x, w.x), max(maxs.y, w.y), max(maxs.z, w.z)))
print('BOUNDS BLENDER', mins, maxs, 'SIZE', maxs - mins)
center = (mins + maxs) / 2
print('CENTER', center)

# Lighting
world = bpy.context.scene.world
if world is None:
    world = bpy.data.worlds.new('World')
    bpy.context.scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes['Background']
bg.inputs['Color'].default_value = (0.02, 0.10, 0.13, 1)
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

cam_data = bpy.data.cameras.new('Camera')
cam = bpy.data.objects.new('Camera', cam_data)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 900
scene.render.resolution_y = 850
scene.render.film_transparent = False
scene.eevee.taa_render_samples = 32


def look_at(obj, target):
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def render(name, gltf_pos, gltf_target, fov_deg=34, res=(900, 850)):
    # glTF (x,y,z) -> Blender (x,-z,y)
    p = Vector((gltf_pos[0], -gltf_pos[2], gltf_pos[1]))
    t = Vector((gltf_target[0], -gltf_target[2], gltf_target[1]))
    cam.location = p
    look_at(cam, t)
    cam_data.angle_y = math.radians(fov_deg)
    cam_data.lens_unit = 'FOV'
    scene.render.resolution_x = res[0]
    scene.render.resolution_y = res[1]
    scene.render.filepath = os.path.join(OUT, name + '.png')
    bpy.ops.render.render(write_still=True)
    print('RENDERED', scene.render.filepath)


# Current runtime camera
render('01-current', (0, 1.05, -4.05), (0, .2, 0), 34, (420, 395))
# Closer, centered
render('02-close', (0, .85, -2.15), (0, 0, 0), 34, (420, 395))
render('03-closer', (0, .75, -1.75), (0, 0, 0), 34, (420, 395))
# Three-quarter view
render('04-threequarter', (1.25, .65, -1.9), (0, 0, 0), 34, (420, 395))
# Side view for orientation
render('05-side', (4, .2, 0), (0, 0, 0), 34, (600, 500))
# Top view
render('06-top', (0, 5, 0.01), (0, 0, 0), 34, (500, 500))
