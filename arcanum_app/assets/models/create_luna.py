import bpy
import math
from mathutils import Euler

# Limpiar escena
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# Crear esfera luna (1.5u diameter)
bpy.ops.mesh.primitive_uv_sphere_add(
    radius=0.75,  # diameter = 1.5u
    segments=32,
    ring_count=16,
    location=(0, 0, 0)
)
luna = bpy.context.active_object
luna.name = "Luna"

# Material luna blanca
mat_luna = bpy.data.materials.new(name="LunaMaterial")
mat_luna.use_nodes = True
bsdf_luna = mat_luna.node_tree.nodes["Principled BSDF"]
bsdf_luna.inputs["Base Color"].default_value = (0.95, 0.95, 0.95, 1.0)  # Blanco
bsdf_luna.inputs["Metallic"].default_value = 0.1
bsdf_luna.inputs["Roughness"].default_value = 0.3
luna.data.materials.append(mat_luna)

# Aura glow (dorada)
mat_aura = bpy.data.materials.new(name="AuraMaterial")
mat_aura.use_nodes = True
bsdf_aura = mat_aura.node_tree.nodes["Principled BSDF"]
bsdf_aura.inputs["Base Color"].default_value = (1.0, 0.78, 0.39, 1.0)  # Dorado
bsdf_aura.inputs["Metallic"].default_value = 0.0
bsdf_aura.inputs["Roughness"].default_value = 0.2

# Icosphere para aura (glow decorativo)
bpy.ops.mesh.primitive_ico_sphere_add(
    subdivisions=2,
    radius=1.0,
    location=(0, 0, 0)
)
aura = bpy.context.active_object
aura.name = "Aura"
aura.data.materials.append(mat_aura)

# Iluminación: Sun lamp
bpy.ops.object.light_add(type='SUN', location=(3, 3, 4))
sun = bpy.context.active_object
sun.data.energy = 2.0
sun.rotation_euler = Euler((math.radians(45), math.radians(45), 0))

# Cámara
bpy.ops.object.camera_add(location=(0, 0, 2.5))
camera = bpy.context.active_object
bpy.context.scene.camera = camera

# Export GLB
export_path = "D:\\Proyectos\\Arcanum\\arcanum_app\\assets\\models\\luna.glb"
bpy.ops.export_scene.gltf(
    filepath=export_path,
    export_format='GLB'
)

print(f"✓ Luna exportada: {export_path}")
