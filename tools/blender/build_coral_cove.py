"""Build the Coral Cove environment GLB for Math Ocean.

Run from the repository root:
  blender --background --python tools/blender/build_coral_cove.py

Writes assets/3d/coral_cove/coral_cove_environment.glb and an editable .blend
plus preview PNG. No external textures or add-ons are required.
"""
import bpy, math, os, random
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets/3d/coral_cove")
ARTIFACTS = os.path.join(ROOT, "artifacts/blender/coral_cove")
os.makedirs(OUT, exist_ok=True)
os.makedirs(ARTIFACTS, exist_ok=True)
GLB = os.path.join(OUT, "coral_cove_environment.glb")
BLEND = os.path.join(ARTIFACTS, "coral_cove_environment.blend")
PREVIEW = os.path.join(ARTIFACTS, "coral_cove_preview.png")
random.seed(23)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
# Blender versions expose different Eevee engine identifiers. Pick the best
# available engine instead of assuming the Blender 4.x identifier exists.
available_engines = {
    item.identifier
    for item in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
}
scene.render.engine = next(
    engine for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES")
    if engine in available_engines
)
scene.render.resolution_x, scene.render.resolution_y = 900, 1440
scene.render.resolution_percentage = 75
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"
scene.render.film_transparent = False

def mat(name, color, rough=.42, metallic=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF"); p.inputs["Base Color"].default_value=(*color,1)
    p.inputs["Roughness"].default_value=rough; p.inputs["Metallic"].default_value=metallic
    return m
sand=mat("Warm pale reef sand",(0.78,.61,.36))
sand2=mat("Sunlit sand",(0.94,.77,.48))
rock=mat("Deep teal reef stone",(.035,.24,.27))
rock2=mat("Turquoise reef stone",(.06,.43,.43))
corals=[mat("Coral pink",(.98,.23,.31)),mat("Coral peach",(1,.48,.27)),mat("Coral violet",(.53,.29,.76)),mat("Coral yellow",(1,.72,.22))]
greens=[mat("Seagrass mint",(.13,.68,.43)),mat("Seagrass lime",(.42,.82,.36)),mat("Kelp deep",(.035,.31,.23))]
fishmat=mat("Clownfish orange",(1,.30,.055),.25)
white=mat("Pearl white",(.94,.98,.91),.18)
blue=mat("Ocean blue",(.015,.19,.29))
def move_col(obj, name):
    c=bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in scene.collection.children: scene.collection.children.link(c)
    for old in list(obj.users_collection): old.objects.unlink(obj)
    c.objects.link(obj)
def smooth(o):
    if o.type=="MESH":
        for p in o.data.polygons: p.use_smooth=True
def uv(name, loc, scale, material, seg=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; o.data.materials.append(material); smooth(o); return o
def cylinder(name,a,b,r,material,vertices=12):
    mid=(Vector(a)+Vector(b))/2; d=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r, radius2=r*.58, depth=d.length, location=mid)
    o=bpy.context.object; o.name=name; o.rotation_euler=d.to_track_quat("Z","Y").to_euler(); o.data.materials.append(material); smooth(o); return o
def coral_branch(x,y,z,material,seed):
    rng=random.Random(seed)
    for j in range(5):
        a=(x,y,z); dx=rng.uniform(-.48,.48); dy=rng.uniform(-.18,.18); h=rng.uniform(.65,1.35)
        b=(x+dx,y+dy,z+h)
        cylinder("Branch coral",a,b,rng.uniform(.09,.15),material)
        for k in range(2):
            t=rng.uniform(.45,.78); p=(x+dx*t,y+dy*t,z+h*t)
            q=(p[0]+rng.uniform(-.35,.35),p[1]+rng.uniform(-.12,.12),p[2]+rng.uniform(.35,.65))
            cylinder("Coral fork",p,q,.075,material)
def grass(x,y,z,material,seed):
    rng=random.Random(seed)
    for i in range(7):
        dx=rng.uniform(-.32,.32); h=rng.uniform(.55,1.5)
        p0=(x+dx*.15,y,z); p1=(x+dx,y,z+h)
        cylinder("Seagrass blade",p0,p1,.07,material,8)
# seabed and distant ocean wall
bpy.ops.mesh.primitive_plane_add(size=18, location=(0,0,-.25)); floor=bpy.context.object
floor.name="Sandy seabed"; floor.data.materials.append(sand); move_col(floor,"01 Environment")
bpy.ops.mesh.primitive_cube_add(size=1, location=(0,7,4), scale=(18,.5,12)); wall=bpy.context.object
wall.name="Ocean distance"; wall.data.materials.append(blue); move_col(wall,"01 Environment")
# rolling reef mounds
for i,(x,y,s) in enumerate([(-5,3,2.4),(-2.8,4.2,2.1),(0,4.5,2.5),(2.8,3.8,2.6),(5,2.5,2.3),(-5,-1.2,2.0),(5,-1.2,2.0),(0,-3.5,1.8)]):
    o=uv("Reef foundation",(x,y,.05),(s,s*.8,s*.55),rock if i%2 else rock2); move_col(o,"02 Reef")
# Foreground reef stones: oversized, readable silhouettes in the portrait play area.
for i, (x, y, sx, sy, sz) in enumerate([
    (-3.7, -4.2, 1.45, 1.05, .95), (-1.8, -4.8, .95, .78, .62),
    (2.0, -4.5, 1.35, .95, .82), (3.8, -3.6, .9, .72, .68),
    (-4.4, -.8, .85, .72, .62), (4.3, .1, .95, .8, .7),
]):
    stone = uv("Foreground reef stone", (x, y, sz * .48), (sx, sy, sz), rock if i % 2 else rock2)
    stone.rotation_euler[2] = random.uniform(-.35, .35)
    move_col(stone, "02 Reef")

# colorful branching coral clusters and bulbous coral heads
for i,(x,y,z) in enumerate([(-4.5,1,.35),(-2.5,2.8,.45),(0,3,.35),(2.5,2.2,.4),(4.5,-.8,.3),(-4.5,-2,.3)]):
    coral_branch(x,y,z,corals[i%4],i+10)
    o=uv("Brain coral",(x+.55,y-.12,z+.12),(.58,.48,.36),corals[(i+1)%4]); move_col(o,"03 Corals")
# kelp forest and collectible seagrass groupings
for i,x in enumerate([-5,-4,-3,3,4,5]):
    for j in range(3):
        grass(x+j*.35,3+j*.22,.05,greens[(i+j)%3],i*10+j); 
for i,x in enumerate([-2.5,0,2.5]):
    grass(x,-2.2,.05,greens[i],100+i)
# anemone tentacles around a central bulb
uv("Anemone base",(-.8,-.2,.22),(.72,.58,.3),corals[2])
for i in range(13):
    a=i*math.tau/13
    p=(-.8+math.cos(a)*.38,-.2+math.sin(a)*.32,.35)
    q=(-.8+math.cos(a)*.62,-.2+math.sin(a)*.5,random.uniform(.75,1.05))
    cylinder("Anemone tentacle",p,q,.075,corals[i%4],10)
# clownfish: body, tail, fins and visible eyes
uv("Clownfish body",(1.6,.0,1.1),(.8,.35,.42),fishmat)
uv("Clownfish tail",(2.45,.03,1.1),(.28,.08,.38),corals[1])
for x in (1.2,1.75):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-.31,1.1),scale=(.12,.035,.72))
    stripe=bpy.context.object; stripe.name="Clownfish white band"; stripe.data.materials.append(white); move_col(stripe,"04 Creatures")
uv("Fish eye",(1.1,-.34,1.22),(.07,.045,.07),white)
# scattered shells, pearls and bubbles
for i in range(18):
    x=random.uniform(-5.5,5.5); y=random.uniform(-4,4)
    o=uv("Scattered pearl",(x,y,.08),(random.uniform(.07,.13),)*3,white,20,12); move_col(o,"05 Details")
for i in range(12):
    x=random.uniform(-5.5,5.5); y=random.uniform(-1,5); z=random.uniform(1,5)
    o=uv("Air bubble",(x,y,z),(.09,.09,.09),white,16,10); move_col(o,"05 Details")
# Lighting and camera
world=bpy.data.worlds.new("Clear tropical water"); world.use_nodes=True
world.node_tree.nodes["Background"].inputs["Color"].default_value=(.025,.22,.31,1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value=.55; scene.world=world
for name,loc,power,size,color in [("Sunlit key",(-6,-8,12),1800,8,(.65,.88,1)),("Warm fill",(8,-1,8),1100,7,(1,.68,.48)),("Reef rim",(0,8,10),1400,6,(.25,.85,1))]:
    bpy.ops.object.light_add(type="AREA",location=loc); l=bpy.context.object; l.name=name; l.data.energy=power; l.data.shape="DISK"; l.data.size=size; l.data.color=color
    l.rotation_euler=(Vector((0,0,0))-l.location).to_track_quat("-Z","Y").to_euler(); move_col(l,"06 Lighting")
bpy.ops.object.camera_add(location=(7,-15,10)); cam=bpy.context.object
cam.name="Coral Cove camera"; cam.rotation_euler=(Vector((0,1,1.1))-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type="ORTHO"; cam.data.ortho_scale=17; scene.camera=cam; move_col(cam,"06 Lighting")
scene.render.filepath=PREVIEW
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active=cam
bpy.ops.export_scene.gltf(filepath=GLB,export_format="GLB",use_selection=True,export_apply=True,export_cameras=False,export_lights=False,export_materials="EXPORT",export_yup=True)
print("Coral Cove generated:", GLB)
