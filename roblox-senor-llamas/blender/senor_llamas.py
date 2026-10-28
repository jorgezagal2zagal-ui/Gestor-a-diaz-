# -*- coding: utf-8 -*-
# =====================================================================
#  EL SEÑOR DE LAS LLAMAS  -  Generador procedural para Blender
# =====================================================================
#  Crea un demonio-rey de fuego (silueta oscura, corona de picos,
#  halo de esferas brillantes, varios brazos con garras, alas rasgadas)
#  parado sobre una CIUDAD MEDIEVAL EN LLAMAS.
#
#  CÓMO USARLO:
#   1. Abre Blender (3.x o 4.x).
#   2. Ve a la pestaña "Scripting".
#   3. Abre este archivo (Text > Open) y presiona "Run Script" (▶).
#      ...o desde terminal:  blender --python senor_llamas.py
#   4. Para Roblox:  File > Export > FBX  (marca "Selected Objects"
#      si quieres exportar solo el monstruo, o deja todo).
#
#  Es una BASE sólida y estilizada. El pulido fino (esculpir, texturas)
#  se hace a mano después en Blender.
# =====================================================================

import bpy
import bmesh
import math
import random
from mathutils import Vector

random.seed(7)

# ---------------------------------------------------------------------
#  UTILIDADES
# ---------------------------------------------------------------------

def limpiar_escena():
    """Borra todo lo que haya en la escena actual."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for bloque in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(bloque):
            if item.users == 0:
                bloque.remove(item)


def material(nombre, color, emision=None, fuerza=0.0, rugosidad=0.85, metalico=0.0):
    """Crea un material Principled. Si 'emision' se da, brilla.
    Compatible con Blender 3.x ('Emission') y 4.x ('Emission Color')."""
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rugosidad
    bsdf.inputs["Metallic"].default_value = metalico
    if emision:
        if "Emission Color" in bsdf.inputs:          # Blender 4.x
            bsdf.inputs["Emission Color"].default_value = (*emision, 1.0)
            bsdf.inputs["Emission Strength"].default_value = fuerza
        elif "Emission" in bsdf.inputs:              # Blender 3.x
            bsdf.inputs["Emission"].default_value = (*emision, 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = fuerza
    return mat


def poner_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def suavizar(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


def mover_a_coleccion(obj, nombre_col):
    col = bpy.data.collections.get(nombre_col)
    if col is None:
        col = bpy.data.collections.new(nombre_col)
        bpy.context.scene.collection.children.link(col)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)


# ---------------------------------------------------------------------
#  PALETA DE MATERIALES
# ---------------------------------------------------------------------
limpiar_escena()

MAT_CUERPO   = material("Cuerpo_Demonio", (0.015, 0.01, 0.01), rugosidad=0.9)
MAT_COSTILLA = material("Costillas",      (0.05, 0.01, 0.005), rugosidad=0.6)
MAT_ALA      = material("Alas",           (0.01, 0.005, 0.005), rugosidad=0.95)
MAT_GARRA    = material("Garras",         (0.12, 0.11, 0.10), rugosidad=0.4)
MAT_CORONA   = material("Corona",         (0.02, 0.01, 0.01), metalico=0.6, rugosidad=0.5)
MAT_OJOS     = material("Ojos",   (1.0, 0.9, 0.3), emision=(1.0, 0.75, 0.15), fuerza=18.0)
MAT_ORBE     = material("Orbes",  (1.0, 0.5, 0.1), emision=(1.0, 0.45, 0.08), fuerza=22.0)
MAT_PIEDRA   = material("Piedra",         (0.06, 0.05, 0.045), rugosidad=1.0)
MAT_TEJADO   = material("Tejado",         (0.09, 0.03, 0.02), rugosidad=0.9)
MAT_LAVA     = material("Lava",   (1.0, 0.35, 0.05), emision=(1.0, 0.3, 0.03), fuerza=10.0)
MAT_FUEGO    = material("Fuego",  (1.0, 0.6, 0.1),  emision=(1.0, 0.55, 0.1), fuerza=16.0)


# ---------------------------------------------------------------------
#  EL MONSTRUO
# ---------------------------------------------------------------------
Z_BASE = 9.0          # altura del centro del torso (enorme sobre la ciudad)
piezas_monstruo = []

def add(obj):
    piezas_monstruo.append(obj)
    return obj


def torso():
    # Tronco alargado tipo cono truncado.
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=2.6, radius2=1.4,
                                    depth=7.0, location=(0, 0, Z_BASE))
    o = bpy.context.active_object
    o.name = "Torso"
    bpy.ops.object.modifier_add(type='SUBSURF')
    o.modifiers["Subdivision"].levels = 2
    o.modifiers["Subdivision"].render_levels = 2
    poner_material(o, MAT_CUERPO)
    suavizar(o)
    # Costillas brillantes marcadas al frente
    for i in range(5):
        bpy.ops.mesh.primitive_cube_add(size=0.5, location=(0, -1.55, Z_BASE + 2.3 - i * 1.2))
        c = bpy.context.active_object
        c.name = f"Costilla_{i}"
        c.scale = (1.6, 0.35, 0.28)
        poner_material(c, MAT_COSTILLA)
        add(c)
    # Caderas / falda inferior que se funde con la ciudad
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=1.4, radius2=3.4,
                                    depth=4.0, location=(0, 0, Z_BASE - 5.0))
    cad = bpy.context.active_object
    cad.name = "Caderas"
    poner_material(cad, MAT_CUERPO)
    suavizar(cad)
    add(cad)
    return add(o)


def cabeza():
    cz = Z_BASE + 4.6
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.5, location=(0, 0, cz))
    cab = bpy.context.active_object
    cab.name = "Cabeza"
    cab.scale = (1.0, 1.05, 1.25)
    bpy.ops.object.shade_smooth()
    poner_material(cab, MAT_CUERPO)
    add(cab)

    # Ojos brillantes (dos óvalos pequeños)
    for lado in (-0.55, 0.55):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(lado, -1.25, cz + 0.1))
        oj = bpy.context.active_object
        oj.name = "Ojo"
        oj.scale = (1.3, 0.6, 0.7)
        bpy.ops.object.shade_smooth()
        poner_material(oj, MAT_OJOS)
        add(oj)

    # CORONA de picos radiales
    n_picos = 11
    for i in range(n_picos):
        ang = (i / n_picos) * math.pi - math.pi / 2       # arco frontal-superior
        inclina = math.radians(55)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.22, radius2=0.0,
                                        depth=2.6 + random.uniform(-0.4, 0.9),
                                        location=(math.cos(ang) * 1.0,
                                                  -0.2,
                                                  cz + 1.4 + math.sin(ang) * 0.6))
        pico = bpy.context.active_object
        pico.name = f"Pico_{i}"
        pico.rotation_euler = (inclina * math.sin(ang) * 0.4, 0, -ang + math.pi / 2)
        poner_material(pico, MAT_CORONA)
        add(pico)
    return cab, cz


def halo_de_orbes(cz):
    """Anillo de esferas de fuego alrededor/detrás de la cabeza."""
    n = 9
    radio = 5.2
    for i in range(n):
        t = (i / (n - 1))
        ang = math.pi * (0.12 + t * 0.76)      # arco superior tipo corona de halo
        x = math.cos(ang) * radio
        z = cz + 0.4 + math.sin(ang) * radio
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, location=(x, 1.2, z))
        orbe = bpy.context.active_object
        orbe.name = f"Orbe_{i}"
        bpy.ops.object.shade_smooth()
        poner_material(orbe, MAT_ORBE)
        add(orbe)
        # pequeña "venita" que conecta el orbe (detalle del arte original)
        bpy.ops.mesh.primitive_cube_add(size=0.2, location=(x * 0.7, 0.9, z - 0.3))
        v = bpy.context.active_object
        v.scale = (0.3, 0.3, 1.4)
        v.rotation_euler = (0, 0, ang)
        poner_material(v, MAT_COSTILLA)
        add(v)


def un_brazo(hombro, ang_z, ang_y, largo=7.5):
    """Brazo largo y delgado que cuelga hacia afuera, con garra."""
    direccion = Vector((math.cos(ang_z), 0, -abs(math.sin(ang_y)))).normalized()
    # Parte alta (hombro->codo)
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.5, radius2=0.32,
                                    depth=largo * 0.5, location=hombro)
    sup = bpy.context.active_object
    sup.name = "BrazoSup"
    sup.rotation_euler = (0, ang_y, ang_z)
    poner_material(sup, MAT_CUERPO)
    suavizar(sup)
    add(sup)
    # Posición del codo
    codo = Vector(hombro) + direccion * (largo * 0.5)
    # Antebrazo (codo->muñeca) más colgante
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.32, radius2=0.18,
                                    depth=largo * 0.55, location=codo)
    inf = bpy.context.active_object
    inf.name = "BrazoInf"
    inf.rotation_euler = (0, ang_y * 0.3, ang_z)
    poner_material(inf, MAT_CUERPO)
    suavizar(inf)
    add(inf)
    muneca = codo + Vector((math.cos(ang_z) * 0.3, 0, -1)) * (largo * 0.55)
    # Garras (3 dedos)
    for d in (-0.3, 0.0, 0.3):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.12, radius2=0.0, depth=1.3,
                                        location=muneca + Vector((d, -0.2, -0.5)))
        g = bpy.context.active_object
        g.name = "Garra"
        g.rotation_euler = (math.radians(200), 0, 0)
        poner_material(g, MAT_GARRA)
        add(g)


def brazos():
    # 4 brazos: un par alto, un par más bajo (como en la referencia)
    hombro_z_alto = Z_BASE + 2.8
    hombro_z_bajo = Z_BASE + 0.6
    un_brazo(( 2.3, 0, hombro_z_alto), ang_z=math.radians(-35), ang_y=math.radians(55), largo=9)
    un_brazo((-2.3, 0, hombro_z_alto), ang_z=math.radians(215), ang_y=math.radians(-55), largo=9)
    un_brazo(( 1.9, 0, hombro_z_bajo), ang_z=math.radians(-50), ang_y=math.radians(70), largo=8)
    un_brazo((-1.9, 0, hombro_z_bajo), ang_z=math.radians(230), ang_y=math.radians(-70), largo=8)


def un_ala(lado):
    """Ala membranosa rasgada construida con bmesh. lado = +1 der, -1 izq."""
    # Contorno: borde superior liso + borde inferior con picos (rasgado)
    sup = [(0, 0), (1.2, 1.4), (3.0, 2.2), (5.0, 2.5), (7.0, 2.2), (8.5, 1.3), (9.5, 0.2)]
    inf = [(9.0, -0.6), (8.3, 0.3), (7.4, -1.3), (6.6, 0.1), (5.7, -1.9),
           (4.9, -0.3), (4.0, -2.3), (3.2, -0.5), (2.3, -2.0), (1.5, -0.6),
           (0.7, -1.4), (0.1, -0.3)]
    pts = sup + inf

    bm = bmesh.new()
    verts = [bm.verts.new((x * lado, 0.0, z)) for (x, z) in pts]
    bm.faces.new(verts)
    bmesh.ops.triangulate(bm, faces=bm.faces)

    me = bpy.data.meshes.new("Ala")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Ala", me)
    bpy.context.scene.collection.objects.link(o)
    # Grosor + un poco de curvatura
    m = o.modifiers.new("Solid", 'SOLIDIFY'); m.thickness = 0.25
    o.location = (lado * 1.6, 1.6, Z_BASE + 3.2)
    o.rotation_euler = (math.radians(8), math.radians(-18 * lado), math.radians(-18 * lado))
    poner_material(o, MAT_ALA)
    add(o)


def alas():
    un_ala(1)
    un_ala(-1)


def cuernos(cz):
    """Dos cuernos curvos saliendo de la cabeza."""
    for lado in (-1, 1):
        for seg in range(5):           # cuerno segmentado que se curva
            t = seg / 4.0
            bpy.ops.mesh.primitive_cone_add(
                vertices=8, radius1=0.35 * (1 - t) + 0.05, radius2=0.28 * (1 - t) + 0.02,
                depth=0.9,
                location=(lado * (0.9 + t * 1.6), -0.3 + t * 0.9, cz + 1.0 + t * 2.4))
            cu = bpy.context.active_object
            cu.name = "Cuerno"
            cu.rotation_euler = (math.radians(-40 - t * 30), 0, math.radians(lado * (15 + t * 25)))
            poner_material(cu, MAT_CORONA)
            suavizar(cu)
            add(cu)


def espinazo():
    """Cresta de espinas por la espalda del torso."""
    for i in range(8):
        z = Z_BASE + 3.0 - i * 1.0
        esc = 1.0 - i * 0.07
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.3 * esc, radius2=0.0,
                                        depth=1.3 * esc, location=(0, 1.3, z))
        e = bpy.context.active_object
        e.name = f"Espina_{i}"
        e.rotation_euler = (math.radians(-110), 0, 0)
        poner_material(e, MAT_CORONA)
        add(e)


def hombreras():
    """Picos grandes sobre los hombros."""
    for lado in (-1, 1):
        for d in (0, 1):
            bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.5 - d * 0.15, radius2=0.0,
                                            depth=2.2 - d * 0.5,
                                            location=(lado * (2.2 + d * 0.5), 0.3, Z_BASE + 3.2 + d * 0.6))
            h = bpy.context.active_object
            h.name = "Hombrera"
            h.rotation_euler = (math.radians(20), 0, math.radians(lado * (35 + d * 15)))
            poner_material(h, MAT_CORONA)
            suavizar(h)
            add(h)


def tendones_base():
    """Tiras/harapos oscuros que cuelgan de la cadera hacia la ciudad."""
    for i in range(14):
        ang = (i / 14) * math.tau
        r = 2.6 + random.uniform(-0.3, 0.4)
        largo = random.uniform(3.0, 6.5)
        x, y = math.cos(ang) * r, math.sin(ang) * r
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.35, radius2=0.05,
                                        depth=largo, location=(x, y, Z_BASE - 6.0 - largo * 0.3))
        t = bpy.context.active_object
        t.name = f"Tendon_{i}"
        t.rotation_euler = (math.radians(180 + random.uniform(-12, 12)),
                            random.uniform(-0.1, 0.1), ang)
        poner_material(t, MAT_ALA)
        add(t)


def brasas_flotantes():
    """Pequeñas esferas de fuego flotando alrededor del demonio."""
    for _ in range(30):
        ang = random.uniform(0, math.tau)
        r = random.uniform(3, 10)
        x, y = math.cos(ang) * r, math.sin(ang) * r
        z = Z_BASE + random.uniform(-4, 8)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=random.uniform(0.12, 0.35), location=(x, y, z))
        b = bpy.context.active_object
        b.name = "Brasa"
        bpy.ops.object.shade_smooth()
        poner_material(b, MAT_ORBE)
        add(b)


# Construir monstruo
torso()
cab, cz = cabeza()
cuernos(cz)
espinazo()
hombreras()
halo_de_orbes(cz)
brazos()
alas()
tendones_base()
brasas_flotantes()

for p in piezas_monstruo:
    mover_a_coleccion(p, "SEÑOR_DE_LAS_LLAMAS")


# ---------------------------------------------------------------------
#  LA CIUDAD EN LLAMAS
# ---------------------------------------------------------------------
piezas_ciudad = []

def suelo():
    bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, -1.0))
    s = bpy.context.active_object
    s.name = "Suelo"
    poner_material(s, MAT_PIEDRA)
    piezas_ciudad.append(s)


def edificio(x, y):
    h = random.uniform(2.0, 6.0)
    w = random.uniform(1.2, 2.4)
    d = random.uniform(1.2, 2.4)
    # Muros
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, h / 2 - 1.0))
    m = bpy.context.active_object
    m.scale = (w, d, h)
    bpy.ops.object.modifier_add(type='BEVEL')
    m.modifiers["Bevel"].width = 0.04
    poner_material(m, MAT_PIEDRA)
    piezas_ciudad.append(m)
    # Tejado a dos aguas (prisma)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=w * 0.78, radius2=0.0,
                                    depth=w * 0.9, location=(x, y, h - 1.0 + w * 0.35))
    t = bpy.context.active_object
    t.rotation_euler = (0, 0, math.radians(45))
    t.scale = (1.3, 1.0, 0.6)
    poner_material(t, MAT_TEJADO)
    piezas_ciudad.append(t)


def ciudad():
    suelo()
    # Rejilla de edificios con un claro en el centro (donde está el demonio)
    for gx in range(-9, 10):
        for gy in range(-9, 10):
            x = gx * 4.5 + random.uniform(-0.8, 0.8)
            y = gy * 4.5 + random.uniform(-0.8, 0.8)
            if math.hypot(x, y) < 10:      # plaza central despejada
                continue
            if math.hypot(x, y) > 42:      # borde circular
                continue
            if random.random() < 0.12:     # algunos huecos (calles)
                continue
            edificio(x, y)

    # Charcos / ríos de LAVA entre las calles
    for _ in range(26):
        ang = random.uniform(0, math.tau)
        r = random.uniform(11, 40)
        x, y = math.cos(ang) * r, math.sin(ang) * r
        bpy.ops.mesh.primitive_plane_add(size=random.uniform(2, 5), location=(x, y, -0.95))
        lv = bpy.context.active_object
        lv.name = "Lava"
        lv.scale = (1.0, random.uniform(0.6, 1.8), 1.0)
        lv.rotation_euler = (0, 0, ang)
        poner_material(lv, MAT_LAVA)
        piezas_ciudad.append(lv)

    # Llamaradas (planos verticales brillantes) saliendo de la ciudad
    for _ in range(40):
        ang = random.uniform(0, math.tau)
        r = random.uniform(9, 40)
        x, y = math.cos(ang) * r, math.sin(ang) * r
        hh = random.uniform(1.5, 4.5)
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, hh / 2 - 1.0))
        fl = bpy.context.active_object
        fl.name = "Llama"
        fl.rotation_euler = (math.radians(90), 0, random.uniform(0, math.tau))
        fl.scale = (random.uniform(1.0, 2.2), hh, 1.0)
        poner_material(fl, MAT_FUEGO)
        piezas_ciudad.append(fl)


ciudad()
for p in piezas_ciudad:
    mover_a_coleccion(p, "CIUDAD_EN_LLAMAS")


# ---------------------------------------------------------------------
#  AMBIENTE: cielo rojo, luces, niebla y cámara
# ---------------------------------------------------------------------
def ambiente():
    # Mundo rojo oscuro
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("Mundo")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.12, 0.02, 0.01, 1.0)
        bg.inputs[1].default_value = 0.4

    # Luz principal cálida desde abajo (el resplandor de la lava)
    bpy.ops.object.light_add(type='AREA', location=(0, 0, 2))
    key = bpy.context.active_object
    key.data.energy = 6000
    key.data.size = 60
    key.data.color = (1.0, 0.35, 0.1)

    # Contraluz para recortar la silueta
    bpy.ops.object.light_add(type='SUN', location=(0, 40, 50))
    sun = bpy.context.active_object
    sun.data.energy = 2.0
    sun.data.color = (1.0, 0.4, 0.25)
    sun.rotation_euler = (math.radians(55), 0, math.radians(180))

    # Niebla volumétrica roja (bruma del incendio)
    try:
        bpy.context.scene.eevee.use_volumetric_lights = True
    except Exception:
        pass

    # Cámara mirando al demonio desde el nivel de la ciudad
    bpy.ops.object.camera_add(location=(0, -55, 8), rotation=(math.radians(82), 0, 0))
    cam = bpy.context.active_object
    bpy.context.scene.camera = cam

    # Motor de render
    try:
        bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'   # Blender 4.2+
    except Exception:
        bpy.context.scene.render.engine = 'BLENDER_EEVEE'
    try:
        bpy.context.scene.eevee.use_bloom = True                 # glow del fuego (3.x/4.0)
    except Exception:
        pass


ambiente()

print("=" * 60)
print("  LISTO: 'El Señor de las Llamas' + ciudad en llamas creados.")
print("  Exporta con File > Export > FBX para llevarlo a Roblox.")
print("=" * 60)
