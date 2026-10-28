# =====================================================================
#  ARCANGEL CAIDO DE FUEGO  -  generador para Blender 5.x
#  Jefe "SenorLlamas" para Roblox + efectos de poderes + accesorios.
#
#  Uso (en segundo plano):
#    blender -b --factory-startup --python arcangel.py -- preview
#    blender -b --factory-startup --python arcangel.py -- full
#  preview = modela + renderiza con materiales procedurales
#  full    = modela + hornea texturas + renderiza + exporta FBX + .blend
#
#  Todo sale en la misma carpeta del script.
#  1 unidad de Blender = 1 stud.
# =====================================================================
import bpy, bmesh, math, os, sys, random, json, time, traceback
from mathutils import Vector, Matrix, noise

OUT = os.path.dirname(os.path.abspath(__file__))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
MODE = ARGS[0] if ARGS else "preview"
LOG = os.path.join(OUT, "log_%s.txt" % MODE)
_logf = open(LOG, "w", encoding="utf-8")
T0 = time.time()


def log(*a):
    s = "[%6.1fs] " % (time.time() - T0) + " ".join(str(x) for x in a)
    print(s)
    _logf.write(s + "\n")
    _logf.flush()


random.seed(7)
V = Vector

# ---------------------------------------------------------------------
#  LIMPIEZA
# ---------------------------------------------------------------------
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 1.0


# ---------------------------------------------------------------------
#  MESH BUILDER  (geometria propia, nada de primitivas sueltas)
# ---------------------------------------------------------------------
class MB:
    def __init__(self):
        self.v = []      # Vector
        self.g = []      # glow por vertice (0..1)
        self.f = []      # tuplas de indices
        self.m = []      # indice de material por cara

    def add_v(self, p, glow=0.0):
        self.v.append(V(p))
        self.g.append(glow)
        return len(self.v) - 1

    def add_f(self, idx, mat=0):
        self.f.append(tuple(idx))
        self.m.append(mat)

    def extend(self, other):
        off = len(self.v)
        self.v += other.v
        self.g += other.g
        self.f += [tuple(i + off for i in fc) for fc in other.f]
        self.m += other.m

    def transformed(self, M, flip=False):
        o = MB()
        o.v = [M @ p for p in self.v]
        o.g = list(self.g)
        o.f = [tuple(reversed(fc)) if flip else fc for fc in self.f]
        o.m = list(self.m)
        return o

    def add_mesh_data(self, me, mat_map=None, glow=0.0):
        off = len(self.v)
        for vv in me.vertices:
            self.v.append(vv.co.copy())
            self.g.append(glow)
        for p in me.polygons:
            self.f.append(tuple(off + i for i in p.vertices))
            mi = p.material_index
            self.m.append(mat_map[mi] if mat_map else mi)

    def to_object(self, name, mats, smooth=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.v], [], self.f)
        me.validate(clean_customdata=False)
        for i, p in enumerate(me.polygons):
            p.material_index = self.m[i] if i < len(self.m) else 0
            p.use_smooth = smooth
        attr = me.color_attributes.new("glow", 'FLOAT_COLOR', 'POINT')
        for i, d in enumerate(attr.data):
            gg = self.g[i] if i < len(self.g) else 0.0
            d.color = (gg, gg, gg, 1.0)
        for mt in mats:
            me.materials.append(mt)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# ---------------------------------------------------------------------
#  HELPERS GEOMETRICOS
# ---------------------------------------------------------------------
def lerp(a, b, t):
    return a + (b - a) * t


def smooth_path(ctrl, n):
    """Catmull-Rom por puntos de control -> n puntos."""
    pts = [V(c) for c in ctrl]
    if len(pts) == 2:
        return [pts[0].lerp(pts[1], i / (n - 1)) for i in range(n)]
    P = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    segs = len(pts) - 1
    out = []
    for i in range(n):
        t = i / (n - 1) * segs
        k = min(int(t), segs - 1)
        u = t - k
        p0, p1, p2, p3 = P[k], P[k + 1], P[k + 2], P[k + 3]
        u2, u3 = u * u, u * u * u
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3))
    return out


def loft(mb, path, radii, sides=8, flat=1.0, up=None, mat=0, glow=None,
         cap_start=True, tip=True, twist=0.0, rfunc=None):
    """Tubo a lo largo de path. radii: lista (misma long) o funcion(u).
    flat escala la seccion en el eje 'up' (para plumas/hojas).
    glow: funcion(u)->0..1. rfunc(u, ang)->multiplicador de radio."""
    n = len(path)
    T = []
    for i in range(n):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, n - 1)]
        t = (b - a)
        T.append(t.normalized() if t.length > 1e-6 else V((0, 0, 1)))
    # marco
    if up is not None:
        upv = V(up).normalized()
        N0 = upv - T[0] * upv.dot(T[0])
        if N0.length < 1e-4:
            N0 = T[0].orthogonal()
    else:
        N0 = T[0].orthogonal()
    N0.normalize()
    frames = []
    N = N0
    for i in range(n):
        if up is not None:
            Ni = upv - T[i] * upv.dot(T[i])
            if Ni.length < 1e-4:
                Ni = N
            N = Ni.normalized()
        else:
            if i > 0:
                N = N - T[i] * N.dot(T[i])
                if N.length < 1e-6:
                    N = T[i].orthogonal()
                N.normalize()
        B = T[i].cross(N).normalized()
        frames.append((N, B))
    rings = []
    last = n - 1
    for i in range(n):
        u = i / (n - 1)
        r = radii(u) if callable(radii) else radii[i]
        gl = glow(u) if glow else 0.0
        if tip and i == last:
            rings.append([mb.add_v(path[i], gl)])
            continue
        Nn, Bb = frames[i]
        ring = []
        tw = twist * u
        for k in range(sides):
            ang = 2 * math.pi * k / sides + tw
            rr = r * (rfunc(u, ang) if rfunc else 1.0)
            p = path[i] + Bb * (math.cos(ang) * rr) + Nn * (math.sin(ang) * rr * flat)
            ring.append(mb.add_v(p, gl))
        rings.append(ring)
    for i in range(n - 1):
        A, Bq = rings[i], rings[i + 1]
        # caras con normales hacia afuera (Roblox dibuja una sola cara)
        if len(Bq) == 1:
            for k in range(sides):
                mb.add_f((Bq[0], A[(k + 1) % sides], A[k]), mat)
        else:
            for k in range(sides):
                mb.add_f((Bq[k], Bq[(k + 1) % sides], A[(k + 1) % sides], A[k]), mat)
    if cap_start and len(rings[0]) > 1:
        c = mb.add_v(path[0], glow(0) if glow else 0.0)
        A = rings[0]
        for k in range(sides):
            mb.add_f((c, A[k], A[(k + 1) % sides]), mat)
    return mb


def ellipsoid(mb, center, rad, seg=24, rings=14, mat=0, deform=None, glow=0.0, rot=None):
    c = V(center)
    R = rot if rot is not None else Matrix.Identity(3)
    top = mb.add_v(c + R @ V((0, 0, rad[2])), glow)
    grid = []
    for j in range(1, rings):
        th = math.pi * j / rings
        row = []
        for i in range(seg):
            ph = 2 * math.pi * i / seg
            p = V((math.sin(th) * math.cos(ph) * rad[0], math.sin(th) * math.sin(ph) * rad[1], math.cos(th) * rad[2]))
            if deform:
                p = deform(p)
            row.append(mb.add_v(c + R @ p, glow))
        grid.append(row)
    bot = mb.add_v(c + R @ V((0, 0, -rad[2])), glow)
    for i in range(seg):
        mb.add_f((top, grid[0][i], grid[0][(i + 1) % seg]), mat)
    for j in range(len(grid) - 1):
        for i in range(seg):
            a, b = grid[j][i], grid[j][(i + 1) % seg]
            cc, d = grid[j + 1][(i + 1) % seg], grid[j + 1][i]
            mb.add_f((a, d, cc, b), mat)
    for i in range(seg):
        mb.add_f((grid[-1][(i + 1) % seg], grid[-1][i], bot), mat)
    return mb


def torus(mb, center, R, r, rot, seg=64, sides=10, mat=0, glow=1.0, rfunc=None):
    c = V(center)
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for k in range(sides):
            b = 2 * math.pi * k / sides
            rr = r * (rfunc(a, b) if rfunc else 1.0)
            p = V(((R + rr * math.cos(b)) * math.cos(a), (R + rr * math.cos(b)) * math.sin(a), rr * math.sin(b)))
            ring.append(mb.add_v(c + rot @ p, glow))
        rings.append(ring)
    for i in range(seg):
        A, B = rings[i], rings[(i + 1) % seg]
        for k in range(sides):
            mb.add_f((A[k], B[k], B[(k + 1) % sides], A[(k + 1) % sides]), mat)
    return mb


def lathe(mb, profile, seg=32, center=(0, 0, 0), mat=0, rfunc=None, glow=0.0):
    """profile: lista (radio, z). Superficie de revolucion abierta."""
    c = V(center)
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            rr = r * (rfunc(a, z) if rfunc else 1.0)
            ring.append(mb.add_v(c + V((math.cos(a) * rr, math.sin(a) * rr, z)), glow))
        rings.append(ring)
    for j in range(len(rings) - 1):
        A, B = rings[j], rings[j + 1]
        for i in range(seg):
            mb.add_f((A[i], A[(i + 1) % seg], B[(i + 1) % seg], B[i]), mat)
    return mb


def rot_from(axis_z, axis_y_hint=(0, 1, 0)):
    z = V(axis_z).normalized()
    y = V(axis_y_hint)
    y = (y - z * y.dot(z))
    if y.length < 1e-4:
        y = z.orthogonal()
    y.normalize()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed()


def skin_mesh(name, verts, edges, radii, root=0, subsurf=2, mirror=False, displace=0.0, disp_scale=1.5):
    """Malla organica con modificador Skin (+Mirror opcional) + Subdivision.
    Devuelve datos de malla evaluados (y borra el objeto temporal)."""
    me = bpy.data.meshes.new(name + "_skel")
    me.from_pydata(verts, edges, [])
    ob = bpy.data.objects.new(name + "_skel", me)
    bpy.context.scene.collection.objects.link(ob)
    if mirror:
        mm = ob.modifiers.new("Mirror", 'MIRROR')
        mm.use_axis[0] = True
        mm.use_mirror_merge = True
        mm.merge_threshold = 0.01
    sk = ob.modifiers.new("Skin", 'SKIN')
    sk.use_smooth_shade = True
    sd = ob.data.skin_vertices[0].data
    for i, r in enumerate(radii):
        sd[i].radius = (r[0], r[1]) if isinstance(r, (tuple, list)) else (r, r)
        sd[i].use_root = (i == root)
    ss = ob.modifiers.new("Subsurf", 'SUBSURF')
    ss.levels = subsurf
    ss.render_levels = subsurf
    if displace > 0:
        tex = bpy.data.textures.new(name + "_tex", 'CLOUDS')
        tex.noise_scale = disp_scale
        dm = ob.modifiers.new("Displace", 'DISPLACE')
        dm.texture = tex
        dm.strength = displace
        dm.mid_level = 0.5
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    tmp = bpy.data.meshes.new_from_object(ev)
    bpy.data.objects.remove(ob)
    return tmp


# ---------------------------------------------------------------------
#  MATERIALES PROCEDURALES
# ---------------------------------------------------------------------
def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.location = (300, 0)
    nt.links.new(bs.outputs[0], out.inputs[0])
    return m, nt, bs


def inp(bs, *names):
    for n in names:
        if n in bs.inputs:
            return bs.inputs[n]
    raise KeyError(names)


def mat_armadura(name="M_Armadura", crack=1.0, base=(0.006, 0.005, 0.005), red=(0.05, 0.008, 0.004)):
    m, nt, bs = new_mat(name)
    L = nt.links
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.35
    nz.inputs["Detail"].default_value = 8
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = base + (1,)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = red + (1,)
    L.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], inp(bs, "Base Color"))
    inp(bs, "Roughness").default_value = 0.5
    inp(bs, "Metallic").default_value = 0.35
    # grietas de lava: voronoi distancia al borde
    vo = nt.nodes.new("ShaderNodeTexVoronoi")
    vo.feature = 'DISTANCE_TO_EDGE'
    vo.inputs["Scale"].default_value = 0.55
    L.new(tc.outputs["Object"], vo.inputs["Vector"])
    cr = nt.nodes.new("ShaderNodeMapRange")
    cr.inputs["From Min"].default_value = 0.0
    cr.inputs["From Max"].default_value = 0.022
    cr.inputs["To Min"].default_value = 1.0
    cr.inputs["To Max"].default_value = 0.0
    L.new(vo.outputs["Distance"], cr.inputs["Value"])
    nz2 = nt.nodes.new("ShaderNodeTexNoise")
    nz2.inputs["Scale"].default_value = 0.18
    L.new(tc.outputs["Object"], nz2.inputs["Vector"])
    mk = nt.nodes.new("ShaderNodeMapRange")
    mk.inputs["From Min"].default_value = 0.52
    mk.inputs["From Max"].default_value = 0.66
    L.new(nz2.outputs["Fac"], mk.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = 'MULTIPLY'
    L.new(cr.outputs["Result"], mul.inputs[0])
    L.new(mk.outputs["Result"], mul.inputs[1])
    # glow por vertice (bordes que brillan) sumado
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "glow"
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = 'ADD'
    add.use_clamp = True
    mul2 = nt.nodes.new("ShaderNodeMath")
    mul2.operation = 'MULTIPLY'
    mul2.inputs[1].default_value = crack
    L.new(mul.outputs[0], mul2.inputs[0])
    L.new(mul2.outputs[0], add.inputs[0])
    L.new(at.outputs["Fac"], add.inputs[1])
    ec = nt.nodes.new("ShaderNodeValToRGB")
    ec.color_ramp.elements[0].color = (0, 0, 0, 1)
    ec.color_ramp.elements[1].color = (1.0, 0.16, 0.01, 1)
    L.new(add.outputs[0], ec.inputs["Fac"])
    L.new(ec.outputs["Color"], inp(bs, "Emission Color", "Emission"))
    inp(bs, "Emission Strength").default_value = 3.0
    return m


def mat_simple(name, color, rough=0.6, metal=0.0, emit=None, estr=0.0, glow_emit=None, glow_str=4.0, grad_bone=False):
    m, nt, bs = new_mat(name)
    L = nt.links
    if grad_bone:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 1.2
        nz.inputs["Detail"].default_value = 6
        L.new(tc.outputs["Object"], nz.inputs["Vector"])
        at = nt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = "glow"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.inputs[6].default_value = (0.08, 0.05, 0.04, 1)
        mix.inputs[7].default_value = color + (1,)
        L.new(at.outputs["Fac"], mix.inputs[0])
        L.new(mix.outputs[2], inp(bs, "Base Color"))
    else:
        inp(bs, "Base Color").default_value = color + (1,)
    inp(bs, "Roughness").default_value = rough
    inp(bs, "Metallic").default_value = metal
    if emit:
        inp(bs, "Emission Color", "Emission").default_value = emit + (1,)
        inp(bs, "Emission Strength").default_value = estr
    if glow_emit:
        at = nt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = "glow"
        ec = nt.nodes.new("ShaderNodeValToRGB")
        ec.color_ramp.elements[0].color = (0, 0, 0, 1)
        ec.color_ramp.elements[0].position = 0.25
        ec.color_ramp.elements[1].color = glow_emit + (1,)
        L.new(at.outputs["Fac"], ec.inputs["Fac"])
        L.new(ec.outputs["Color"], inp(bs, "Emission Color", "Emission"))
        inp(bs, "Emission Strength").default_value = glow_str
    return m


def mat_fuego(name, col=(1.0, 0.42, 0.05), estr=3.5):
    m, nt, bs = new_mat(name)
    L = nt.links
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.5
    nz.inputs["Detail"].default_value = 4
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.9, 0.12, 0.02, 1)
    ramp.color_ramp.elements[1].color = (1.0, 0.85, 0.3, 1)
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[1].position = 0.75
    L.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], inp(bs, "Base Color"))
    L.new(ramp.outputs["Color"], inp(bs, "Emission Color", "Emission"))
    inp(bs, "Emission Strength").default_value = estr
    inp(bs, "Roughness").default_value = 0.4
    return m


def mat_roca(name="M_Roca"):
    m, nt, bs = new_mat(name)
    L = nt.links
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.12
    nz.inputs["Detail"].default_value = 10
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.015, 0.012, 0.012, 1)
    ramp.color_ramp.elements[1].color = (0.09, 0.04, 0.03, 1)
    L.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], inp(bs, "Base Color"))
    inp(bs, "Roughness").default_value = 0.9
    vo = nt.nodes.new("ShaderNodeTexVoronoi")
    vo.feature = 'DISTANCE_TO_EDGE'
    vo.inputs["Scale"].default_value = 0.25
    L.new(tc.outputs["Object"], vo.inputs["Vector"])
    cr = nt.nodes.new("ShaderNodeMapRange")
    cr.inputs["From Max"].default_value = 0.06
    cr.inputs["To Min"].default_value = 1.0
    cr.inputs["To Max"].default_value = 0.0
    L.new(vo.outputs["Distance"], cr.inputs["Value"])
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "glow"
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = 'ADD'
    add.use_clamp = True
    L.new(cr.outputs["Result"], add.inputs[0])
    L.new(at.outputs["Fac"], add.inputs[1])
    ec = nt.nodes.new("ShaderNodeValToRGB")
    ec.color_ramp.elements[0].color = (0, 0, 0, 1)
    ec.color_ramp.elements[1].color = (1.0, 0.35, 0.04, 1)
    L.new(add.outputs[0], ec.inputs["Fac"])
    L.new(ec.outputs["Color"], inp(bs, "Emission Color", "Emission"))
    inp(bs, "Emission Strength").default_value = 2.2
    return m


def build_materials():
    M = {}
    M["arm"] = mat_armadura()
    M["hueso"] = mat_simple("M_Hueso", (0.36, 0.29, 0.21), rough=0.7, grad_bone=True)
    M["tela"] = mat_simple("M_Tela", (0.02, 0.004, 0.004), rough=0.95, glow_emit=(1.0, 0.12, 0.01), glow_str=3.0)
    M["pluma"] = mat_simple("M_Pluma", (0.008, 0.007, 0.009), rough=0.5, metal=0.15, glow_emit=(1.0, 0.12, 0.01), glow_str=3.0)
    M["fuego"] = mat_fuego("M_Fuego")
    M["ojo"] = mat_simple("M_Ojo", (1.0, 0.75, 0.15), emit=(1.0, 0.62, 0.08), estr=5.0)
    M["oro"] = mat_simple("M_OroOscuro", (0.32, 0.17, 0.05), rough=0.35, metal=1.0, glow_emit=(1.0, 0.45, 0.05), glow_str=6.0)
    M["roca"] = mat_roca()
    M["nube"] = mat_simple("M_Nube", (0.03, 0.01, 0.008), rough=1.0, glow_emit=(1.0, 0.3, 0.02), glow_str=3.5)
    return M


# ---------------------------------------------------------------------
#  PIEZAS DEL ARCANGEL
#  Mira hacia -Y. Derecha del personaje = -X.
# ---------------------------------------------------------------------
FEET = 7.0  # altura de los pies (encima de la roca)


def part_cuerpo(M):
    """Torso + piernas con Skin + Mirror + Subdivision, gorjal y cinturon."""
    # mitad derecha del esqueleto (x>=0); el Mirror hace la otra mitad
    vs = [
        (0, 0.2, 37.5),   # 0 pelvis (raiz)
        (0, 0.0, 42.5),   # 1 cintura
        (0, -0.2, 47.5),  # 2 pecho bajo
        (0, 0.0, 52.0),   # 3 pecho alto
        (0, 0.4, 56.0),   # 4 base cuello
        (0, 0.3, 58.6),   # 5 cuello
        (4.5, 0.4, 54.2),  # 6 clavicula
        (8.0, 0.6, 54.6),  # 7 hombro
        (3.4, 0.2, 36.0),  # 8 cadera
        (4.2, -0.6, 29.0),  # 9 muslo
        (4.6, -1.2, 21.5),  # 10 rodilla
        (4.8, 0.2, 14.0),   # 11 espinilla
        (5.0, 0.6, FEET + 1.6),  # 12 tobillo
        (5.2, -3.6, FEET + 0.5),  # 13 punta pie
    ]
    es = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (4, 6), (6, 7), (0, 8), (8, 9), (9, 10), (10, 11), (11, 12), (12, 13)]
    rs = [(4.6, 3.4), (3.6, 2.8), (5.4, 3.6), (6.3, 3.9), (2.4, 2.2), (1.6, 1.6), (2.4, 2.0), (2.5, 2.3),
          (3.4, 3.3), (3.0, 3.0), (2.3, 2.4), (2.0, 2.1), (1.6, 1.7), (1.2, 0.8)]
    me = skin_mesh("Cuerpo", vs, es, rs, root=0, subsurf=2, mirror=True, displace=0.18, disp_scale=0.8)
    mb = MB()
    mb.add_mesh_data(me, mat_map=[0])
    bpy.data.meshes.remove(me)
    # gorjal (cuello alto de armadura) con picos
    lathe(mb, [(2.6, 55.2), (3.1, 56.6), (2.9, 58.4), (3.4, 59.4)], seg=28, center=(0, 0.35, 0), mat=0,
          rfunc=lambda a, z: 1.0 + (0.12 if z > 59 and (int(a / (2 * math.pi) * 14) % 2 == 0) else 0.0))
    for s in (1, -1):
        ellipsoid(mb, (4.6 * s, -2.6, 21.8), (1.7, 1.0, 1.9), seg=14, rings=8, mat=0)
        k0 = V((4.6 * s, -3.4, 22.6))
        loft(mb, smooth_path([k0, k0 + V((0.2 * s, -1.0, 1.4)), k0 + V((0.4 * s, -1.6, 3.2))], 7),
             lambda u: 0.55 * (1 - u) + 0.02, sides=6, mat=1, glow=lambda u: u)
    # cinturon con hebilla
    torus(mb, (0, 0.05, 41.6), 3.9, 0.55, Matrix.Diagonal((1, 0.78, 1)), seg=40, sides=8, mat=2, glow=0.0)
    ellipsoid(mb, (0, -3.15, 41.6), (1.1, 0.5, 1.3), seg=12, rings=8, mat=4, glow=1.0)
    # placas pectorales en capas (arcos de armadura)
    for i, z in enumerate((50.5, 48.6, 46.7, 44.8)):
        w = 5.4 - i * 0.55
        path = [V((-w, -2.4 + i * 0.25 + 0.2, z + 0.4)), V((0, -4.15 + i * 0.3, z - 0.3)), V((w, -2.4 + i * 0.25 + 0.2, z + 0.4))]
        loft(mb, smooth_path(path, 14), lambda u: 0.32, sides=6, flat=0.45, up=(0, 0, 1), mat=0, tip=False,
             glow=lambda u: 0.06)
    return mb.to_object("Cuerpo", [M["arm"], M["hueso"], M["oro"], M["tela"], M["ojo"]])


def part_tunica(M):
    """Tunica/faldon rasgado abierto al frente."""
    mb = MB()
    A0, A1 = math.radians(-150), math.radians(150)   # 0 = atras (+Y)
    na, nz = 90, 22
    rnd = random.Random(3)
    jag = [rnd.uniform(0, 1) for _ in range(na + 1)]
    zt, zb = 42.0, FEET + 0.8
    grid = []
    for j in range(nz + 1):
        v = j / nz
        row = []
        for i in range(na + 1):
            u = i / na
            a = lerp(A0, A1, u)
            z = lerp(zt, zb, v)
            # bordes rasgados abajo: tiras de distinto largo
            strip = jag[(i // 3) % len(jag)]
            cut = (0.18 + 0.55 * strip) * (abs(math.sin(i * 1.7)) * 0.6 + 0.4)
            zz = z + (cut * 16.0) * (v ** 3)
            r = lerp(4.4, 12.5, v ** 1.15) * (1 + 0.07 * math.sin(a * 11 + v * 3)) * (1 + 0.04 * math.sin(a * 23))
            # se abre al frente
            p = V((math.sin(a) * r, math.cos(a) * r * 0.82 + 0.6, zz))
            gl = max(0.0, (v - 0.82) / 0.18) ** 2
            row.append(mb.add_v(p, gl))
        grid.append(row)
    for j in range(nz):
        for i in range(na):
            mb.add_f((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]), 0)
    ob = mb.to_object("Tunica", [M["tela"]])
    so = ob.modifiers.new("Solidify", 'SOLIDIFY')
    so.thickness = 0.35
    apply_mods(ob)
    return ob


def hand(mb, wrist, palm, n_hint, s, curl=0.35, fist=False, mat_skin=0, mat_claw=1):
    d = (V(palm) - V(wrist)).normalized()
    n = V(n_hint) - d * V(n_hint).dot(d)
    n.normalize()
    sv = d.cross(n).normalized()
    P = V(palm)
    offs = [-1.05, -0.35, 0.35, 1.05]
    lens = [3.4, 4.1, 4.3, 3.6]
    for k, (o, Lg) in enumerate(zip(offs, lens)):
        base = P + d * 1.1 + sv * o * s
        pts = [base]
        dirv = (d + sv * o * s * 0.12).normalized()
        cur = base
        nseg = 3
        for j in range(nseg):
            c = curl * (j + 1) * (2.2 if fist else 1.0)
            dirv = (dirv * math.cos(c) - n * math.sin(c)).normalized()
            cur = cur + dirv * (Lg / nseg)
            pts.append(cur)
        path = smooth_path(pts, 10)
        loft(mb, path, lambda u: 0.48 - 0.16 * u, sides=7, mat=mat_skin, tip=False)
        # garra tipo hueso
        cdir = (dirv * 0.6 - n * 0.8).normalized() if not fist else (dirv - n * 0.3).normalized()
        cp = [cur, cur + dirv * 0.9, cur + dirv * 1.6 + cdir * 0.9]
        loft(mb, smooth_path(cp, 7), lambda u: 0.34 * (1 - u) ** 0.8, sides=6, mat=mat_claw,
             glow=lambda u: 1.0 - u * 0.6)
    # pulgar
    tb = P + d * 0.2 + sv * 1.3 * s
    tp = [tb, tb + sv * 1.2 * s + d * 0.8 - n * 0.4, tb + sv * 1.5 * s + d * 2.0 - n * (1.2 if fist else 0.6)]
    loft(mb, smooth_path(tp, 8), lambda u: 0.55 - 0.2 * u, sides=7, mat=mat_skin, tip=False)
    e = tp[-1]
    td = (tp[-1] - tp[-2]).normalized()
    loft(mb, smooth_path([e, e + td * 0.9, e + td * 1.5 - n * 0.7], 6), lambda u: 0.36 * (1 - u), sides=6, mat=mat_claw,
         glow=lambda u: 1.0 - u * 0.6)
    return d, n, sv


ARM = dict(sh=(8.6, 0.6, 54.6), el=(15.5, -1.6, 46.5), wr=(20.5, -6.4, 40.0), pa=(21.7, -8.1, 38.4))


def part_brazos(M):
    """Brazos con Skin + Mirror: se hace el izquierdo (+X) y el Mirror crea el derecho."""
    sh, el, wr, pa = (V(ARM[k]) for k in ("sh", "el", "wr", "pa"))
    mid1 = sh.lerp(el, 0.5) + V((0.3, 0.4, 0.0))
    mid2 = el.lerp(wr, 0.45) + V((0.3, 0.0, 0.2))
    vs = [tuple(sh), tuple(mid1), tuple(el), tuple(mid2), tuple(wr), tuple(pa)]
    es = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]
    rs = [(2.3, 2.3), (1.9, 1.9), (1.35, 1.35), (1.55, 1.45), (1.0, 0.9), (1.45, 0.65)]
    me = skin_mesh("Brazos", vs, es, rs, root=0, subsurf=2, mirror=True, displace=0.12, disp_scale=0.6)
    izq, der = MB(), MB()
    # separar por lado
    vmap_i, vmap_d = {}, {}
    for p in me.polygons:
        cx = sum(me.vertices[i].co.x for i in p.vertices) / len(p.vertices)
        tgt, vmap = (izq, vmap_i) if cx > 0 else (der, vmap_d)
        idx = []
        for i in p.vertices:
            if i not in vmap:
                vmap[i] = tgt.add_v(me.vertices[i].co.copy(), 0.0)
            idx.append(vmap[i])
        tgt.add_f(idx, 0)
    bpy.data.meshes.remove(me)
    out = {}
    for s, mb, nm in ((1, izq, "BrazoIzq"), (-1, der, "BrazoDer")):
        S = V((s, 1, 1))
        def m_(v):
            return V((v[0] * s, v[1], v[2]))
        # hombrera: domo + 3 picos curvos de hueso
        ellipsoid(mb, m_((9.3, 0.6, 56.0)), (3.4, 3.2, 2.4), seg=20, rings=10, mat=0,
                  rot=Matrix.Rotation(math.radians(-22 * s), 3, 'Y'))
        for k, (dy, ln) in enumerate(((-1.6, 4.5), (0.4, 6.2), (2.2, 4.8))):
            b = m_((10.0, 0.6 + dy, 57.6))
            pts = [b, b + m_((1.2, dy * 0.15, 2.0)), b + m_((3.0, dy * 0.3 + 0.8, ln * 0.75)), b + m_((5.0, dy * 0.4 + 2.2, ln))]
            loft(mb, smooth_path(pts, 10), lambda u: 0.75 * (1 - u) ** 0.9 + 0.02, sides=7, mat=1,
                 glow=lambda u: u)
        # brazal (antebrazo) con placa
        loft(mb, smooth_path([m_(V(ARM["el"]).lerp(V(ARM["wr"]), 0.25)), m_(V(ARM["el"]).lerp(V(ARM["wr"]), 0.85))], 8),
             lambda u: 1.75 - 0.5 * u, sides=10, mat=2, tip=False, rfunc=lambda u, a: 1.0 + 0.12 * max(0, math.cos(a)),
             glow=lambda u: 0.15)
        # mano: derecha abierta (bola de fuego), izquierda en puno (espada)
        if s < 0:
            hand(mb, m_(V(ARM["wr"])), m_(V(ARM["pa"])), (0, -0.2, 1), s, curl=0.38, fist=False)
        else:
            hand(mb, m_(V(ARM["wr"])), m_(V(ARM["pa"])), (-0.7, 0.2, 0.3), s, curl=0.55, fist=True)
        out[nm] = mb.to_object(nm, [M["arm"], M["hueso"], M["oro"]])
    return out


def part_cabeza(M):
    mb = MB()
    C = V((0, 0.25, 61.6))

    def helm(p):
        # mascara: frente aplanada, menton en punta, nuca alargada
        x, y, z = p
        if y < 0:
            y *= 0.82 + 0.18 * min(1, abs(x) / 2.0)
        if z < 0:
            x *= 1 - 0.38 * (-z / 3.6)
            if y < 0:
                y -= 0.35 * (-z / 3.6)
        if y > 0:
            y *= 1.0 + 0.25 * max(0, z / 3.6)
        return V((x, y, z))
    ellipsoid(mb, C, (2.45, 2.9, 3.6), seg=32, rings=18, mat=0, deform=helm)
    # cresta central tipo aleta (va de la frente a la nuca)
    pts = [C + V((0, -2.2, 2.6)), C + V((0, 0, 4.4)), C + V((0, 3.0, 4.0)), C + V((0, 5.5, 2.0))]
    loft(mb, smooth_path(pts, 16), lambda u: 0.9 * math.sin(math.pi * min(1, u * 1.1)) + 0.05, sides=6, flat=0.25,
         up=(1, 0, 0), mat=2, tip=False, glow=lambda u: 0.25)
    # cuernos barridos hacia atras
    for s in (1, -1):
        b = C + V((1.9 * s, -0.6, 2.0))
        pts = [b, b + V((1.0 * s, 0.8, 2.6)), b + V((2.8 * s, 2.5, 5.6)), b + V((4.8 * s, 5.0, 7.2)), b + V((6.0 * s, 8.0, 6.6))]
        loft(mb, smooth_path(pts, 18), lambda u: 1.3 * (1 - u) ** 0.85 + 0.03, sides=9, mat=1,
             rfunc=lambda u, a: 1 + 0.08 * math.sin(u * 40), glow=lambda u: u ** 1.5)
        # cuerno secundario pequeno
        b2 = C + V((2.2 * s, 0.6, 0.6))
        pts2 = [b2, b2 + V((1.3 * s, 1.6, 0.5)), b2 + V((1.6 * s, 4.0, -0.4))]
        loft(mb, smooth_path(pts2, 10), lambda u: 0.55 * (1 - u) + 0.02, sides=7, mat=1, glow=lambda u: u)
    # rendija de ojos (hendidura oscura donde van los ojos)
    for s in (1, -1):
        p0 = C + V((0.35 * s, -2.4, 0.55))
        p1 = C + V((1.65 * s, -2.05, 0.95))
        loft(mb, smooth_path([p0, p1], 6), lambda u: 0.33 * math.sin(math.pi * (0.1 + 0.8 * u)) + 0.08,
             sides=6, flat=0.45, up=(0, 0, 1), mat=3, tip=False)
    return mb.to_object("Cabeza", [M["arm"], M["hueso"], M["oro"], M["tela"]])


def part_ojos(M):
    mb = MB()
    C = V((0, 0.25, 61.6))
    for s in (1, -1):
        p0 = C + V((0.4 * s, -2.62, 0.55))
        p1 = C + V((1.6 * s, -2.28, 0.98))
        loft(mb, smooth_path([p0, p1], 8), lambda u: 0.2 * math.sin(math.pi * (0.08 + 0.84 * u)) + 0.04,
             sides=6, flat=0.55, up=(0, 0, 1), mat=0, tip=False, glow=lambda u: 1.0)
    return mb.to_object("Ojos", [M["ojo"]])


def part_halo(M):
    mb = MB()
    C = V((0, 2.6, 66.8))
    R = Matrix.Rotation(math.radians(90 - 18), 3, 'X')
    torus(mb, C, 4.6, 0.32, R, seg=72, sides=8, mat=0, glow=1.0,
          rfunc=lambda a, b: 1 + 0.25 * math.sin(a * 9))
    # lenguas de fuego hacia afuera
    for i in range(18):
        a = 2 * math.pi * i / 18
        rad = V((math.cos(a), math.sin(a), 0))
        tang = V((-math.sin(a), math.cos(a), 0))
        b = C + R @ (rad * 4.7)
        ln = 1.4 + 1.1 * (0.5 + 0.5 * math.sin(i * 2.3))
        pts = [b, b + R @ (rad * ln * 0.5 + tang * 0.35), b + R @ (rad * ln + tang * 0.9)]
        loft(mb, smooth_path(pts, 8), lambda u: 0.32 * (1 - u), sides=6, mat=0, glow=lambda u: 1.0)
    return mb.to_object("Halo", [M["fuego"]])


def rueda_rings():
    """Rueda de la espalda: anillos concentricos ('ruedas dentro de ruedas').
    Devuelve dict nombre->(MB) para que cada anillo pueda girar en Roblox."""
    C = V((0, 7.5, 56.0))
    out = {}
    # anillo exterior (marco con dientes y gemas)
    mb = MB()
    R0 = Matrix.Rotation(math.radians(90), 3, 'X')
    torus(mb, C, 15.5, 0.85, R0, seg=96, sides=8, mat=0, glow=0.0, rfunc=lambda a, b: 1 + 0.15 * (math.sin(a * 24) > 0.6))
    torus(mb, C, 14.0, 0.38, R0, seg=96, sides=6, mat=1, glow=1.0)
    for i in range(24):
        a = 2 * math.pi * i / 24
        rad = V((math.cos(a), math.sin(a), 0))
        b = C + R0 @ (rad * 16.2)
        ln = 2.2 if i % 2 == 0 else 1.3
        loft(mb, smooth_path([b, b + R0 @ (rad * ln)], 5), lambda u: 0.55 * (1 - u) + 0.02, sides=6, mat=0,
             glow=lambda u: u)
        if i % 3 == 0:
            ellipsoid(mb, C + R0 @ (rad * 14.8) + V((0, -0.6, 0)), (0.85, 0.85, 0.85), seg=12, rings=8, mat=2, glow=1.0)
    out["RuedaExterior"] = (mb, C)
    # anillo medio (inclinado, girara en otro eje)
    mb = MB()
    R1 = Matrix.Rotation(math.radians(90), 3, 'X') @ Matrix.Rotation(math.radians(0), 3, 'Y')
    torus(mb, C, 11.0, 0.6, R1, seg=80, sides=8, mat=0, glow=0.0)
    for i in range(12):
        a = 2 * math.pi * i / 12
        rad = V((math.cos(a), math.sin(a), 0))
        ellipsoid(mb, C + R1 @ (rad * 11.0) + V((0, -0.4, 0)), (0.75, 0.75, 0.75), seg=12, rings=8, mat=2, glow=1.0)
        # dientes hacia afuera
        b = C + R1 @ (rad.copy() * 11.4)
        tng = V((-math.sin(a), math.cos(a), 0))
        b2 = C + R1 @ ((rad * 11.4) + tng * 1.2)
        loft(mb, smooth_path([b2, b2 + R1 @ (rad * 1.4)], 4), lambda u: 0.35 * (1 - u) + 0.02, sides=5, mat=0,
             glow=lambda u: u)
    out["RuedaMedia"] = (mb, C)
    # anillo interior
    mb = MB()
    torus(mb, C, 6.3, 0.45, R1, seg=64, sides=8, mat=0, glow=0.0)
    torus(mb, C, 5.6, 0.2, R1, seg=64, sides=6, mat=1, glow=1.0)
    for i in range(8):
        a = 2 * math.pi * i / 8
        rad = V((math.cos(a), math.sin(a), 0))
        b = C + R1 @ (rad * 6.3)
        loft(mb, smooth_path([b, b - R1 @ (rad * 1.8)], 4), lambda u: 0.35 * (1 - u) + 0.02, sides=5, mat=0,
             glow=lambda u: u)
    out["RuedaInterior"] = (mb, C)
    return out


def part_rueda(M):
    obs = {}
    for nm, (mb, C) in rueda_rings().items():
        obs[nm] = mb.to_object(nm, [M["oro"], M["fuego"], M["ojo"]])
    return obs


def wing_mb(rnd):
    """Ala izquierda (+X). Plumas lofteadas en filas, puntas de brasa, algunas rotas."""
    mb = MB()
    P = [V((3.2, 3.6, 53.5)), V((13.0, 9.5, 63.5)), V((27.0, 12.5, 71.0)), V((42.0, 14.5, 68.0))]
    arm = smooth_path(P, 40)
    loft(mb, arm, lambda u: lerp(1.9, 0.35, u), sides=10, mat=1, tip=True, cap_start=True, glow=lambda u: 0.0)
    # longitud acumulada para parametrizar
    acc = [0.0]
    for i in range(1, len(arm)):
        acc.append(acc[-1] + (arm[i] - arm[i - 1]).length)
    Ltot = acc[-1]

    def at(t):
        d = t * Ltot
        for i in range(1, len(arm)):
            if acc[i] >= d:
                f = (d - acc[i - 1]) / max(1e-6, acc[i] - acc[i - 1])
                return arm[i - 1].lerp(arm[i], f), (arm[i] - arm[i - 1]).normalized()
        return arm[-1], (arm[-1] - arm[-2]).normalized()

    def feather(base, direction, length, width, layer_off, broken=False):
        dirv = direction.normalized()
        # plano de la pluma ~ plano del ala (normal hacia Y)
        up = V((0, 1, 0))
        side = dirv.cross(up).normalized()
        curve = side * (length * 0.06)
        tipl = length * (rnd.uniform(0.55, 0.75) if broken else 1.0)
        pts = [base + V((0, layer_off, 0)),
               base + dirv * tipl * 0.35 + curve * 0.5 + V((0, layer_off + 0.25, 0)),
               base + dirv * tipl * 0.7 + curve + V((0, layer_off + 0.55, 0)),
               base + dirv * tipl + curve * 1.4 + V((0, layer_off + 0.9, 0))]
        path = smooth_path(pts, 9)
        notch = rnd.random() < 0.35

        def w(u):
            ww = width * (min(1.0, (u + 0.08) * 3.0) ** 0.5) * max(0.0, 1 - u ** 3) ** 0.5
            if notch and 0.55 < u < 0.7:
                ww *= 0.45
            return ww + 0.03
        loft(mb, path, w, sides=6, flat=0.12, up=(0, 1, 0), mat=0, tip=True, cap_start=True,
             glow=lambda u: max(0.0, (u - 0.8) / 0.2) ** 2 * 0.8)

    # primarias (mano): abanico hacia afuera/abajo
    n_pr = 13
    for i in range(n_pr):
        t = lerp(0.62, 1.0, i / (n_pr - 1))
        b, tan = at(t)
        f = i / (n_pr - 1)
        dirv = V((lerp(0.25, 1.0, f ** 1.3), lerp(0.18, 0.05, f), lerp(-1.0, -0.35, f)))
        ln = lerp(19.0, 15.0, abs(f - 0.35) * 1.4) + rnd.uniform(-1.2, 1.2)
        feather(b, dirv, ln, 2.7, layer_off=0.3, broken=rnd.random() < 0.18)
    # secundarias: hacia abajo
    n_sec = 16
    for i in range(n_sec):
        t = lerp(0.12, 0.62, i / (n_sec - 1))
        b, tan = at(t)
        f = i / (n_sec - 1)
        dirv = V((lerp(-0.12, 0.2, f), 0.22, -1.0))
        ln = lerp(11.0, 16.5, f ** 0.8) + rnd.uniform(-1.0, 1.0)
        feather(b, dirv, ln, 2.5, layer_off=0.1, broken=rnd.random() < 0.2)
    # coberteras (2 filas cortas, delante para tapar la base)
    for row, (ln0, ln1, off, n) in enumerate(((6.5, 8.5, -0.45, 16), (3.6, 5.0, -0.9, 18))):
        for i in range(n):
            t = lerp(0.08, 0.97, i / (n - 1))
            b, tan = at(t)
            f = i / (n - 1)
            dirv = V((lerp(0.0, 0.7, f ** 1.5), 0.2, -1.0))
            feather(b, dirv, lerp(ln0, ln1, math.sin(math.pi * f)) + rnd.uniform(-0.6, 0.6), 2.1 - row * 0.3,
                    layer_off=off, broken=False)
    # espolon de hueso en la "muneca" del ala
    b, tan = at(0.6)
    loft(mb, smooth_path([b, b + V((0.8, 0.2, 2.2)), b + V((0.4, 1.2, 4.0))], 8), lambda u: 0.7 * (1 - u) + 0.02,
         sides=7, mat=2, glow=lambda u: u)
    b, tan = at(0.999)
    loft(mb, smooth_path([b, b + V((2.0, 0.4, 0.6)), b + V((3.6, 1.2, -0.3))], 8), lambda u: 0.45 * (1 - u) + 0.02,
         sides=7, mat=2, glow=lambda u: u)
    return mb


def part_alas(M):
    rnd = random.Random(11)
    izq = wing_mb(rnd)
    # MIRROR en X para el ala derecha (simetria)
    der = izq.transformed(Matrix.Diagonal((-1, 1, 1, 1)), flip=True)
    mats = [M["pluma"], M["arm"], M["hueso"]]
    return {"AlaIzq": izq.to_object("AlaIzq", mats), "AlaDer": der.to_object("AlaDer", mats)}


def left_fist():
    d = (V(ARM["pa"]) - V(ARM["wr"])).normalized()
    return V(ARM["pa"]) + d * 1.6


def part_espada(M):
    mb = MB()
    H = left_fist() + V((0.2, -0.6, -0.2))
    b = V((0.12, -0.42, -0.9)).normalized()
    side = b.cross(V((1, 0, 0))).normalized()
    up = b.cross(side).normalized()
    # hoja flamigera (filo ondulado)
    L = 30.0
    blade = [H + b * (2.2 + L * i / 40) for i in range(41)]
    loft(mb, blade, lambda u: (1.7 * (1 - u ** 1.6) + 0.08) * (1 + 0.16 * math.sin(u * 30)), sides=6, flat=0.16,
         up=up, mat=0, tip=True, glow=lambda u: 1.0)
    # guarda en forma de alas
    for s in (1, -1):
        g = [H + b * 2.0, H + b * 1.6 + side * s * 1.8, H + b * 2.6 + side * s * 3.6, H + b * 4.6 + side * s * 4.4]
        loft(mb, smooth_path(g, 10), lambda u: 0.55 * (1 - u) + 0.05, sides=7, flat=0.6, up=up, mat=1,
             glow=lambda u: u * 0.8)
    ellipsoid(mb, H + b * 2.0, (1.0, 1.0, 0.7), seg=14, rings=8, mat=1, rot=rot_from(b, up))
    # mango y pomo
    loft(mb, [H + b * 1.9, H - b * 3.6], [0.42, 0.42], sides=8, mat=2, tip=False)
    ellipsoid(mb, H - b * 4.1, (0.7, 0.7, 0.8), seg=12, rings=8, mat=3, rot=rot_from(b, up), glow=1.0)
    return mb.to_object("Espada", [M["fuego"], M["oro"], M["arm"], M["ojo"]])


def part_manoderecha(M):
    """Orbe de fuego en la palma derecha (origen de proyectiles)."""
    mb = MB()
    s = -1
    wr = V((ARM["wr"][0] * s, ARM["wr"][1], ARM["wr"][2]))
    pa = V((ARM["pa"][0] * s, ARM["pa"][1], ARM["pa"][2]))
    d = (pa - wr).normalized()
    n = V((0, -0.2, 1)) - d * V((0, -0.2, 1)).dot(d)
    n.normalize()
    C = pa + d * 1.8 + n * 2.6
    rnd = random.Random(5)

    def fb(p):
        k = 1 + 0.18 * noise.noise(p * 1.3 + V((3, 1, 2)))
        return p * k
    ellipsoid(mb, C, (1.9, 1.9, 1.9), seg=24, rings=14, mat=0, deform=fb, glow=1.0)
    # llamas que salen del orbe
    for i in range(26):
        z = rnd.uniform(-0.6, 1.0)
        a = rnd.uniform(0, 2 * math.pi)
        dv = V((math.cos(a) * math.sqrt(1 - z * z), math.sin(a) * math.sqrt(1 - z * z), z)).normalized()
        b0 = C + dv * 1.6
        ln = rnd.uniform(0.8, 1.8)
        pts = [b0, b0 + dv * ln * 0.6 + V((0, 0, 0.3)), b0 + dv * ln + V((0, 0, ln * 0.7))]
        loft(mb, smooth_path(pts, 7), lambda u: 0.5 * (1 - u), sides=6, mat=0, glow=lambda u: 1.0)
    ob = mb.to_object("ManoDerecha", [M["fuego"]])
    return ob, C


def part_base(M):
    """Roca de lava (piso del jefe) + nubes de fuego."""
    mb = MB()
    nr, na = 22, 72
    Rmax = 24.0
    grid = []
    for j in range(nr + 1):
        r = Rmax * (j / nr)
        row = []
        for i in range(na if j > 0 else 1):
            a = 2 * math.pi * i / na
            x, y = math.cos(a) * r, math.sin(a) * r
            nn = noise.noise(V((x * 0.09, y * 0.09, 0.3)))
            edge = j / nr
            h = FEET - 0.3 + 1.6 * nn - 7.5 * max(0, edge - 0.75) ** 1.3 * 4
            gl = max(0.0, -nn - 0.15) * 2.5 if edge > 0.25 else 0.0
            row.append(mb.add_v((x, y, h), min(1.0, gl)))
        grid.append(row)
    for i in range(na):
        mb.add_f((grid[0][0], grid[1][i], grid[1][(i + 1) % na]), 0)
    for j in range(1, nr):
        for i in range(na):
            mb.add_f((grid[j][i], grid[j + 1][i], grid[j + 1][(i + 1) % na], grid[j][(i + 1) % na]), 0)
    # rocas puntiagudas alrededor
    rnd = random.Random(21)
    for k in range(14):
        a = 2 * math.pi * k / 14 + rnd.uniform(-0.15, 0.15)
        r = rnd.uniform(14, 20)
        b = V((math.cos(a) * r, math.sin(a) * r, FEET - 3))
        h = rnd.uniform(4, 9)
        lean = V((math.cos(a) * 0.4, math.sin(a) * 0.4, 1)).normalized()
        loft(mb, smooth_path([b, b + lean * h * 0.5, b + lean * h], 6), lambda u: 2.2 * (1 - u) + 0.05, sides=7, mat=0,
             rfunc=lambda u, an: 1 + 0.2 * math.sin(an * 3 + k), glow=lambda u: 0.0)
    roca = mb.to_object("BaseRoca", [M["roca"]])
    # nubes de fuego: bultos deformados con ruido
    nb = MB()
    for k in range(30):
        a = 2 * math.pi * k / 30 + rnd.uniform(-0.1, 0.1)
        r = rnd.uniform(13, 24)
        c = V((math.cos(a) * r, math.sin(a) * r, FEET - 1.5 + rnd.uniform(0, 4)))
        rad = rnd.uniform(3.5, 6.5)
        seed = V((k * 1.7, k * 0.3, 0))

        def bump(p, seed=seed):
            q = p.normalized()
            k2 = 1 + 0.28 * noise.noise(q * 2.2 + seed) + 0.1 * noise.noise(q * 5 + seed)
            return p * k2
        base_n = len(nb.v)
        ellipsoid(nb, c, (rad, rad, rad * 0.8), seg=18, rings=10, mat=0, deform=bump)
        for vi in range(base_n, len(nb.v)):
            z = (nb.v[vi].z - (c.z - rad)) / (2 * rad)
            nb.g[vi] = min(1.0, max(0.0, 1.15 - z * 1.5) ** 1.3)
    nubes = nb.to_object("NubesFuego", [M["nube"]])
    return roca, nubes


# ---------------------------------------------------------------------
#  EFECTOS DE PODERES (cada uno centrado en el origen, tamano ~1-10)
# ---------------------------------------------------------------------
def fx_objects(M):
    obs = []
    rnd = random.Random(31)
    # 1) BolaFuego: esfera con picos de llama hacia atras (+Z = atras del movimiento? usamos -Z = adelante)
    mb = MB()

    def fbn(p):
        return p * (1 + 0.15 * noise.noise(p * 1.8))
    ellipsoid(mb, (0, 0, 0), (2, 2, 2), seg=24, rings=14, mat=0, deform=fbn, glow=1.0)
    for i in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.4, 1.5)
        b = V((math.cos(a) * rr, math.sin(a) * rr, 1.2))
        pts = [b, b + V((math.cos(a) * 0.6, math.sin(a) * 0.6, 2.0)), b + V((math.cos(a) * 0.4, math.sin(a) * 0.4, rnd.uniform(4, 6.5)))]
        loft(mb, smooth_path(pts, 7), lambda u: 0.75 * (1 - u), sides=6, mat=0, glow=lambda u: 1)
    obs.append(mb.to_object("FX_BolaFuego", [M["fuego"]]))
    # 2) MediaLuna: tajo creciente
    mb = MB()
    pts = [V((math.cos(a) * 6, 0, math.sin(a) * 6)) for a in [math.radians(x) for x in range(-70, 71, 7)]]
    loft(mb, pts, lambda u: 1.2 * math.sin(math.pi * u) + 0.05, sides=6, flat=0.15, up=(0, 1, 0), mat=0, tip=True,
         glow=lambda u: 1)
    obs.append(mb.to_object("FX_MediaLuna", [M["fuego"]]))
    # 3) Onda: anillo de fuego con lenguas hacia arriba (radio 5)
    mb = MB()
    torus(mb, (0, 0, 0), 5.0, 0.45, Matrix.Identity(3), seg=64, sides=8, mat=0, glow=1.0)
    for i in range(32):
        a = 2 * math.pi * i / 32
        b = V((math.cos(a) * 5, math.sin(a) * 5, 0))
        h = rnd.uniform(1.0, 2.6)
        pts = [b, b + V((math.cos(a) * 0.3, math.sin(a) * 0.3, h * 0.5)), b + V((math.cos(a) * 0.8, math.sin(a) * 0.8, h))]
        loft(mb, smooth_path(pts, 6), lambda u: 0.42 * (1 - u), sides=5, mat=0, glow=lambda u: 1)
    obs.append(mb.to_object("FX_Onda", [M["fuego"]]))
    # 4) Pilar: columna de fuego retorcida (alto 10, radio ~1.5)
    mb = MB()
    for k in range(5):
        a0 = 2 * math.pi * k / 5
        pts = [V((math.cos(a0 + z * 0.45) * 0.9 * (1 - z / 14), math.sin(a0 + z * 0.45) * 0.9 * (1 - z / 14), z - 5)) for z in range(0, 11)]
        loft(mb, smooth_path(pts, 20), lambda u: 0.95 * (1 - u) + 0.05, sides=7, mat=0, glow=lambda u: 1)
    lathe(mb, [(1.6, -5), (1.2, -3), (0.9, 0), (0.5, 3), (0.05, 5)], seg=20, mat=0, glow=1.0)
    obs.append(mb.to_object("FX_Pilar", [M["fuego"]]))
    # 5) Meteoro: roca con grietas de lava y estela
    mb = MB()

    def rk(p):
        return p * (1 + 0.3 * noise.noise(p * 0.9 + V((5, 5, 5))))
    ellipsoid(mb, (0, 0, 0), (2, 2, 2), seg=20, rings=12, mat=0, deform=rk, glow=0.0)
    for i in range(10):
        a = rnd.uniform(0, 2 * math.pi)
        b = V((math.cos(a) * 1.0, math.sin(a) * 1.0, 1.4))
        pts = [b, b + V((0, 0, rnd.uniform(3, 6)))]
        loft(mb, smooth_path(pts, 6), lambda u: 0.9 * (1 - u), sides=6, mat=1, glow=lambda u: 1)
    obs.append(mb.to_object("FX_Meteoro", [M["roca"], M["fuego"]]))
    # 6) Geiser: chorro de lava
    mb = MB()
    lathe(mb, [(2.2, -5), (1.6, -4), (1.1, -1), (1.3, 2), (2.2, 4), (1.0, 5)], seg=24, mat=0, glow=1.0,
          rfunc=lambda a, z: 1 + 0.15 * math.sin(a * 6 + z))
    obs.append(mb.to_object("FX_Geiser", [M["fuego"]]))
    for o in obs:
        o.location = (0, 0, 0)
    return obs


# ---------------------------------------------------------------------
#  ACCESORIOS PARA JUGADORES (escala de personaje R15: ~5 studs alto)
# ---------------------------------------------------------------------
def player_objects(M):
    obs = []
    # Hombreras (par) centradas en el torso superior, ancho ~3
    mb = MB()
    for s in (1, -1):
        ellipsoid(mb, (s * 1.25, 0, 0.15), (0.75, 0.65, 0.45), seg=16, rings=8, mat=0,
                  rot=Matrix.Rotation(math.radians(-25 * s), 3, 'Y'))
        for k, dy in enumerate((-0.25, 0.25)):
            b = V((s * 1.45, dy, 0.4))
            loft(mb, smooth_path([b, b + V((s * 0.35, dy * 0.2, 0.5)), b + V((s * 0.8, dy * 0.4 + 0.15, 0.9))], 6),
                 lambda u: 0.16 * (1 - u) + 0.01, sides=6, mat=1, glow=lambda u: u)
    obs.append(mb.to_object("JUG_Hombreras", [M["arm"], M["hueso"]]))
    # Capa rasgada (cuelga desde los hombros), ancho 2.4, largo 3.6
    mb = MB()
    nw, nh = 14, 12
    grid = []
    for j in range(nh + 1):
        row = []
        v = j / nh
        for i in range(nw + 1):
            u = i / nw
            x = lerp(-1.1, 1.1, u) * (1 + 0.35 * v)
            cut = 0.5 * abs(math.sin(i * 2.1)) * (v ** 3)
            z = -v * 3.6 + cut
            y = 0.55 + 0.25 * v + 0.08 * math.sin(u * 12)
            row.append(mb.add_v((x, y, z), max(0.0, (v - 0.8) / 0.2)))
        grid.append(row)
    for j in range(nh):
        for i in range(nw):
            mb.add_f((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]), 0)
    ob = mb.to_object("JUG_Capa", [M["tela"]])
    so = ob.modifiers.new("Solidify", 'SOLIDIFY')
    so.thickness = 0.06
    apply_mods(ob)
    obs.append(ob)
    # Halo pequeno de brasas
    mb = MB()
    torus(mb, (0, 0, 0), 0.75, 0.07, Matrix.Identity(3), seg=40, sides=6, mat=0, glow=1.0,
          rfunc=lambda a, b: 1 + 0.3 * math.sin(a * 8))
    obs.append(mb.to_object("JUG_Halo", [M["fuego"]]))
    for o in obs:
        o.location = (0, 0, 0)
    return obs


# ---------------------------------------------------------------------
#  UTILIDADES DE OBJETO
# ---------------------------------------------------------------------
def select_only(ob):
    for o in bpy.context.scene.objects:
        if o is not None:
            o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def apply_mods(ob):
    """Aplica todos los modificadores (sin operadores)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    me.name = ob.name
    if old.users == 0:
        bpy.data.meshes.remove(old)


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def limit_tris(ob, limit=19000):
    t = tri_count(ob)
    if t > limit:
        ratio = (limit * 0.97) / t
        dm = ob.modifiers.new("Decimate", 'DECIMATE')
        dm.ratio = ratio
        apply_mods(ob)
        log("  Decimate %s: %d -> %d tris" % (ob.name, t, tri_count(ob)))
    return tri_count(ob)


def set_origin(ob, p):
    p = V(p)
    ob.data.transform(Matrix.Translation(-p))
    ob.location = p


def bbox_center(ob):
    vs = [v.co + ob.location for v in ob.data.vertices]
    mn = V((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = V((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return (mn + mx) / 2, mn, mx


# ---------------------------------------------------------------------
#  ESCENA DE RENDER
# ---------------------------------------------------------------------
def setup_render(engine_pref="EEVEE"):
    sc = bpy.context.scene
    ok = False
    if engine_pref == "EEVEE":
        for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                sc.render.engine = e
                ok = True
                break
            except Exception:
                pass
    if not ok:
        sc.render.engine = 'CYCLES'
        sc.cycles.samples = 48
        try:
            sc.cycles.use_denoising = True
        except Exception:
            pass
    try:
        sc.eevee.taa_render_samples = 48
    except Exception:
        pass
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 960
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = 'Standard'
        sc.view_settings.look = 'None'
    except Exception:
        pass
    w = bpy.data.worlds.new("Atardecer")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.05, 0.008, 0.004, 1)
    bg.inputs[1].default_value = 1.0
    # luces: contra-luz naranja + relleno rojo + clave tenue
    def light(name, typ, loc, rot, energy, color, size=None):
        ld = bpy.data.lights.new(name, typ)
        ld.energy = energy
        ld.color = color
        if size and hasattr(ld, "size"):
            ld.size = size
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
    light("Sol_contra", 'SUN', (0, 60, 90), (math.radians(-35), 0, math.radians(180)), 4.0, (1.0, 0.45, 0.2))
    light("Clave", 'AREA', (-45, -60, 70), (math.radians(55), 0, math.radians(-35)), 14000, (1.0, 0.7, 0.6), size=30)
    light("Relleno", 'AREA', (50, -40, 20), (math.radians(75), 0, math.radians(50)), 7000, (1.0, 0.2, 0.1), size=30)
    light("Lava", 'POINT', (0, -14, 9), (0, 0, 0), 25000, (1.0, 0.3, 0.04))
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = 32
    cam_d.clip_end = 1000
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def aim(cam, loc, target):
    cam.location = V(loc)
    d = V(target) - V(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def render(path, cam, loc, target, hide=()):
    aim(cam, loc, target)
    hidden = []
    for o in bpy.context.scene.objects:
        if any(o.name.startswith(h) for h in hide):
            o.hide_render = True
            hidden.append(o)
    bpy.context.scene.render.filepath = path
    t = time.time()
    bpy.ops.render.render(write_still=True)
    for o in hidden:
        o.hide_render = False
    log("  render", os.path.basename(path), "%.1fs" % (time.time() - t))


# ---------------------------------------------------------------------
#  HORNEADO
# ---------------------------------------------------------------------
def uv_unwrap(ob):
    select_only(ob)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    try:
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    except TypeError:
        bpy.ops.uv.smart_project()
    bpy.ops.object.mode_set(mode='OBJECT')


def bake_object(ob, size, texdir):
    import numpy as np
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 4
    try:
        sc.render.bake.margin = 6
    except Exception:
        pass
    uv_unwrap(ob)
    select_only(ob)
    imgs = {}
    for kind in ("color", "emit"):
        img = bpy.data.images.new("%s_%s" % (ob.name, kind), size, size, alpha=False)
        imgs[kind] = img
        for mt in ob.data.materials:
            nt = mt.node_tree
            nd = nt.nodes.get("BAKE_NODE")
            if nd is None:
                nd = nt.nodes.new("ShaderNodeTexImage")
                nd.name = "BAKE_NODE"
            nd.image = img
            for n in nt.nodes:
                n.select = False
            nd.select = True
            nt.nodes.active = nd
        t = time.time()
        if kind == "color":
            bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True, margin=6)
        else:
            bpy.ops.object.bake(type='EMIT', use_clear=True, margin=6)
        log("  bake %s %s %dpx %.1fs" % (ob.name, kind, size, time.time() - t))
    # color final = albedo + brillo (para que en Roblox se vean las grietas encendidas)
    n = size * size * 4
    a = np.empty(n, dtype=np.float32)
    e = np.empty(n, dtype=np.float32)
    imgs["color"].pixels.foreach_get(a)
    imgs["emit"].pixels.foreach_get(e)
    c = np.clip(a + e * 0.95, 0, 1)
    c[3::4] = 1.0
    imgs["color"].pixels.foreach_set(c)
    paths = {}
    for kind, img in imgs.items():
        p = os.path.join(texdir, "%s_%s.png" % (ob.name, kind))
        img.filepath_raw = p
        img.file_format = 'PNG'
        img.save()
        paths[kind] = p
    # material final simple con texturas horneadas
    m, nt, bs = new_mat("MB_" + ob.name)
    tcol = nt.nodes.new("ShaderNodeTexImage")
    tcol.image = imgs["color"]
    tem = nt.nodes.new("ShaderNodeTexImage")
    tem.image = imgs["emit"]
    nt.links.new(tcol.outputs["Color"], inp(bs, "Base Color"))
    nt.links.new(tem.outputs["Color"], inp(bs, "Emission Color", "Emission"))
    inp(bs, "Emission Strength").default_value = 2.0
    inp(bs, "Roughness").default_value = 0.6
    ob.data.materials.clear()
    ob.data.materials.append(m)
    ob.data.polygons.foreach_set("material_index", [0] * len(ob.data.polygons))
    return paths



# =====================================================================
#  KIT DE ESCENARIO: ciudad medieval en ruinas
#  Cada pieza: base en z=0, centrada en XY, frente hacia -Y.
# =====================================================================
def mat_piedra(name="M_Piedra", base=(0.05, 0.045, 0.042), mortar=(0.012, 0.01, 0.01), scale=0.45):
    m, nt, bs = new_mat(name)
    L = nt.links
    tc = nt.nodes.new("ShaderNodeTexCoord")
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = scale
    br.inputs["Mortar Size"].default_value = 0.025
    br.inputs["Color1"].default_value = base + (1,)
    br.inputs["Color2"].default_value = tuple(c * 0.6 for c in base) + (1,)
    br.inputs["Mortar"].default_value = mortar + (1,)
    # coordenadas de pared: (x+y, z) para que el ladrillo quede horizontal en cualquier muro
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs[0])
    addxy = nt.nodes.new("ShaderNodeMath")
    addxy.operation = 'ADD'
    L.new(sep.outputs[0], addxy.inputs[0])
    L.new(sep.outputs[1], addxy.inputs[1])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    L.new(addxy.outputs[0], comb.inputs[0])
    L.new(sep.outputs[2], comb.inputs[1])
    L.new(comb.outputs[0], br.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.08
    nz.inputs["Detail"].default_value = 6
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    hollin = nt.nodes.new("ShaderNodeMix")
    hollin.data_type = 'RGBA'
    hollin.blend_type = 'MULTIPLY'
    L.new(nz.outputs["Fac"], hollin.inputs[0])
    L.new(br.outputs["Color"], hollin.inputs[6])
    hollin.inputs[7].default_value = (0.25, 0.2, 0.2, 1)
    L.new(hollin.outputs[2], inp(bs, "Base Color"))
    inp(bs, "Roughness").default_value = 0.92
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "glow"
    ec = nt.nodes.new("ShaderNodeValToRGB")
    ec.color_ramp.elements[0].color = (0, 0, 0, 1)
    ec.color_ramp.elements[1].color = (1.0, 0.3, 0.04, 1)
    L.new(at.outputs["Fac"], ec.inputs["Fac"])
    L.new(ec.outputs["Color"], inp(bs, "Emission Color", "Emission"))
    inp(bs, "Emission Strength").default_value = 3.0
    return m


def kit_materials():
    K = {}
    K["piedra"] = mat_piedra()
    K["teja"] = mat_piedra("M_Teja", base=(0.06, 0.018, 0.012), mortar=(0.01, 0.004, 0.003), scale=0.9)
    K["ventana"] = mat_simple("M_Ventana", (1.0, 0.45, 0.08), emit=(1.0, 0.4, 0.06), estr=4.0)
    K["madera"] = mat_simple("M_Madera", (0.03, 0.018, 0.012), rough=0.9, glow_emit=(1.0, 0.25, 0.02), glow_str=4.0)
    K["roca"] = mat_roca("M_RocaKit")
    return K


def panel(mb, o, u, length, height, cols, rows, mat=0, holes=(), jag=0.0, seed=0, glowtop=0.0, win_mat=None, inset=0.5, normal=None):
    """Pared en el plano (u, Z). holes = celdas (c, r) vacias (ventanas)."""
    o, u = V(o), V(u).normalized()
    rnd = random.Random(seed)
    grid = []
    tops = [rnd.uniform(0, 1) for _ in range(cols + 1)]
    for r in range(rows + 1):
        row = []
        for c in range(cols + 1):
            z = height * r / rows
            if r == rows and jag > 0:
                z -= jag * tops[c] ** 1.5
            g = glowtop if r == rows else 0.0
            row.append(mb.add_v(o + u * (length * c / cols) + V((0, 0, z)), g))
        grid.append(row)
    hs = set(holes)
    for r in range(rows):
        for c in range(cols):
            if (c, r) in hs:
                continue
            mb.add_f((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]), mat)
    if win_mat is not None and normal is not None:
        n = V(normal).normalized()
        for (c, r) in hs:
            p = [o + u * (length * cc / cols) + V((0, 0, height * rr / rows)) - n * inset
                 for (cc, rr) in ((c, r), (c + 1, r), (c + 1, r + 1), (c, r + 1))]
            ids = [mb.add_v(q, 1.0) for q in p]
            mb.add_f(ids, win_mat)


def box(mb, c, s, mat=0, glow=0.0):
    c, s = V(c), V(s) / 2
    P = [c + V((sx * s.x, sy * s.y, sz * s.z)) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    ids = [mb.add_v(p, glow) for p in P]
    for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
        mb.add_f([ids[i] for i in f], mat)


def solidify(ob, t):
    so = ob.modifiers.new("Solidify", 'SOLIDIFY')
    so.thickness = t
    so.offset = 0.0
    apply_mods(ob)


def kit_casa(K, name, W, D, H, roofH, seed, broken_roof=0.25, jag=2.5):
    rnd = random.Random(seed)
    mb = MB()
    cols_w, cols_d, rows = max(3, int(W / 2.5)), max(3, int(D / 2.5)), max(4, int(H / 2.5))
    def wins(cols):
        hs = []
        for r in range(1, rows - 1, 3):
            for c in range(1, cols - 1, 2):
                if rnd.random() < 0.7:
                    hs.append((c, r))
        return hs
    x0, y0 = -W / 2, -D / 2
    # puerta al frente
    front_h = wins(cols_w) + [(cols_w // 2, 0)]
    panel(mb, (x0, y0, 0), (1, 0, 0), W, H, cols_w, rows, 0, front_h, jag, seed + 1, 0.6, 2, 0.6, (0, -1, 0))
    panel(mb, (W / 2, -y0, 0), (-1, 0, 0), W, H, cols_w, rows, 0, wins(cols_w), jag, seed + 2, 0.6, 2, 0.6, (0, 1, 0))
    panel(mb, (W / 2, y0, 0), (0, 1, 0), D, H, cols_d, rows, 0, wins(cols_d), jag * 0.4, seed + 3, 0.0, 2, 0.6, (1, 0, 0))
    panel(mb, (x0, -y0, 0), (0, -1, 0), D, H, cols_d, rows, 0, wins(cols_d), jag * 0.4, seed + 4, 0.0, 2, 0.6, (-1, 0, 0))
    # tejado a dos aguas (con huecos de derrumbe)
    ov = 1.2
    nx, ny = max(4, int(W / 2)), 4
    for side in (-1, 1):
        verts = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                x = -W / 2 - ov + (W + 2 * ov) * i / nx
                t = j / ny
                y = side * (D / 2 + ov) * (1 - t)
                z = H - 0.6 + roofH * t + rnd.uniform(-0.15, 0.15)
                row.append(mb.add_v((x, y, z), 0.0))
            verts.append(row)
        for j in range(ny):
            for i in range(nx):
                if rnd.random() < broken_roof and j < ny - 1:
                    continue
                f = (verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i])
                mb.add_f(f if side > 0 else tuple(reversed(f)), 1)
    # vigas quemadas asomando
    for k in range(3):
        x = rnd.uniform(-W / 3, W / 3)
        b = V((x, rnd.uniform(-D / 3, D / 3), H - 0.5))
        loft(mb, [b, b + V((rnd.uniform(-1, 1), rnd.uniform(-2, 2), roofH * 0.9))], [0.35, 0.3], sides=5, mat=3,
             tip=False, glow=lambda u: u)
    # chimenea
    box(mb, (W / 3, D / 5, H + roofH * 0.7), (1.6, 1.6, roofH * 1.4 + 2), 0)
    ob = mb.to_object(name, [K["piedra"], K["teja"], K["ventana"], K["madera"]])
    solidify(ob, 0.7)
    return ob


def kit_torre(K, name, R, H, seed):
    rnd = random.Random(seed)
    mb = MB()
    seg, rows = 20, max(6, int(H / 3))
    grid = []
    for r in range(rows + 1):
        row = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            z = H * r / rows
            rr = R * (1 + 0.04 * math.sin(a * 3)) * (1 - 0.06 * r / rows)
            row.append(mb.add_v((math.cos(a) * rr, math.sin(a) * rr, z), 0.0))
        grid.append(row)
    holes = {(i, r) for r in range(2, rows - 1, 3) for i in range(0, seg, 5) if rnd.random() < 0.8}
    for r in range(rows):
        for i in range(seg):
            if (i, r) in holes:
                continue
            mb.add_f((grid[r][i], grid[r][(i + 1) % seg], grid[r + 1][(i + 1) % seg], grid[r + 1][i]), 0)
    for (i, r) in holes:
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        rr = R * 0.86
        z0, z1 = H * r / rows, H * (r + 1) / rows
        ids = [mb.add_v(p, 1.0) for p in ((math.cos(a0) * rr, math.sin(a0) * rr, z0), (math.cos(a1) * rr, math.sin(a1) * rr, z0),
                                          (math.cos(a1) * rr, math.sin(a1) * rr, z1), (math.cos(a0) * rr, math.sin(a0) * rr, z1))]
        mb.add_f(ids, 2)
    # almenas
    for i in range(0, seg, 2):
        a = 2 * math.pi * (i + 0.5) / seg
        rr = R * 0.94 * 0.94
        box(mb, (math.cos(a) * rr, math.sin(a) * rr, H + 1.2), (2.0, 2.0, 2.4), 0, 0.0)
    # tejado conico roto
    lathe(mb, [(R * 1.12, H + 0.5), (R * 0.6, H + R * 1.3), (R * 0.15, H + R * 2.3)], seg=20, mat=1,
          rfunc=lambda a, z: 1 + 0.05 * math.sin(a * 7))
    ob = mb.to_object(name, [K["piedra"], K["teja"], K["ventana"]])
    solidify(ob, 0.8)
    return ob


def kit_muro(K, name, L, H, T, seed):
    rnd = random.Random(seed)
    mb = MB()
    cols, rows = max(4, int(L / 2.5)), max(6, int(H / 2.5))
    holes = [(rnd.randrange(1, cols - 1), rnd.randrange(2, rows - 2))]
    panel(mb, (-L / 2, -T / 2, 0), (1, 0, 0), L, H, cols, rows, 0, holes, 0.0, seed, 0.0, 2, 0.4, (0, -1, 0))
    panel(mb, (L / 2, T / 2, 0), (-1, 0, 0), L, H, cols, rows, 0, (), 0.0, seed + 1, 0.0)
    # tapa superior y almenas
    box(mb, (0, 0, H - 0.3), (L, T, 0.6), 0)
    n = max(3, int(L / 3.4))
    for i in range(n):
        x = -L / 2 + (i + 0.5) * L / n
        if rnd.random() < 0.85:
            box(mb, (x, -T / 2 + 0.8, H + 1.4), (L / n * 0.55, 1.6, 2.8), 0)
            box(mb, (x, T / 2 - 0.8, H + 1.4), (L / n * 0.55, 1.6, 2.8), 0)
    # contrafuertes
    for x in (-L / 2 + 1.2, L / 2 - 1.2):
        lathe(mb, [(1.6, 0), (1.3, H * 0.6), (0.4, H * 0.75)], seg=8, center=(x, -T / 2 - 0.8, 0), mat=0)
    ob = mb.to_object(name, [K["piedra"], K["teja"], K["ventana"]])
    return ob


def kit_torre_puerta(K, name, S, H, seed):
    mb = MB()
    cols, rows = 5, max(8, int(H / 3))
    rnd = random.Random(seed)
    for k, (o, u, n) in enumerate((((-S / 2, -S / 2, 0), (1, 0, 0), (0, -1, 0)), ((S / 2, -S / 2, 0), (0, 1, 0), (1, 0, 0)),
                                   ((S / 2, S / 2, 0), (-1, 0, 0), (0, 1, 0)), ((-S / 2, S / 2, 0), (0, -1, 0), (-1, 0, 0)))):
        hs = [(2, r) for r in range(3, rows - 1, 4)]
        panel(mb, o, u, S, H, cols, rows, 0, hs, 0.0, seed + k, 0.0, 2, 0.6, n)
    box(mb, (0, 0, H + 0.4), (S + 2.4, S + 2.4, 0.8), 0)
    for i in range(4):
        for side in range(4):
            t = -S / 2 + (i + 0.5) * S / 4
            p = [(t, -S / 2 - 0.6), (S / 2 + 0.6, t), (-t, S / 2 + 0.6), (-S / 2 - 0.6, -t)][side]
            if (i + side) % 2 == 0:
                box(mb, (p[0], p[1], H + 2.2), (1.8, 1.8, 2.8), 0)
    # brasero en la cima
    lathe(mb, [(1.2, H + 0.8), (1.8, H + 2.0), (2.0, H + 2.4)], seg=14, mat=1)
    ellipsoid(mb, (0, 0, H + 2.6), (1.4, 1.4, 0.8), seg=12, rings=6, mat=2, glow=1.0)
    ob = mb.to_object(name, [K["piedra"], K["teja"], K["ventana"]])
    solidify(ob, 0.8)
    return ob


def kit_roca(K, name, seed):
    rnd = random.Random(seed)
    mb = MB()
    for k in range(6):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0, 3.5)
        b = V((math.cos(a) * r, math.sin(a) * r, -1))
        h = rnd.uniform(5, 14)
        lean = V((rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35), 1)).normalized()
        sd = rnd.uniform(0, 10)
        loft(mb, smooth_path([b, b + lean * h * 0.5, b + lean * h], 8), lambda u: 2.6 * (1 - u) ** 0.9 + 0.08, sides=7,
             mat=0, rfunc=lambda u, an, sd=sd: 1 + 0.25 * math.sin(an * 3 + sd) + 0.1 * math.sin(u * 20 + sd),
             glow=lambda u: max(0.0, 0.5 - u) * 1.6)
    return mb.to_object(name, [K["roca"]])


def kit_arbol(K, name, seed):
    rnd = random.Random(seed)
    mb = MB()

    def rama(b, d, ln, r, depth):
        e = b + d * ln
        mid = b.lerp(e, 0.5) + V((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0))
        loft(mb, smooth_path([b, mid, e], 6), lambda u: r * (1 - 0.7 * u) + 0.03, sides=6, mat=0, tip=depth == 0,
             glow=lambda u: 0.0)
        if depth > 0:
            for _ in range(2 + (depth > 1)):
                nd = (d + V((rnd.uniform(-0.9, 0.9), rnd.uniform(-0.9, 0.9), rnd.uniform(-0.1, 0.5)))).normalized()
                rama(e, nd, ln * rnd.uniform(0.55, 0.75), r * 0.55, depth - 1)
    rama(V((0, 0, -0.5)), V((0.1, 0.05, 1)).normalized(), 7, 0.9, 3)
    return mb.to_object(name, [K["madera"]])


def build_kit():
    K = kit_materials()
    obs = []
    obs.append(kit_casa(K, "Casa_A", 14, 12, 16, 7, 101))
    obs.append(kit_casa(K, "Casa_B", 12, 10, 26, 8, 202, broken_roof=0.12, jag=1.5))
    obs.append(kit_casa(K, "Casa_C", 18, 14, 10, 5, 303, broken_roof=0.6, jag=4.0))
    obs.append(kit_torre(K, "Torre", 6, 34, 404))
    obs.append(kit_muro(K, "MuroSegmento", 20, 40, 6, 505))
    obs.append(kit_torre_puerta(K, "TorrePuerta", 10, 50, 606))
    obs.append(kit_roca(K, "RocaLava", 707))
    obs.append(kit_arbol(K, "ArbolSeco", 808))
    return obs


def main_kit():
    log("MODO kit escenario")
    reset_scene()
    obs = build_kit()
    xs = -60
    for o in obs:
        c, mn, mx = bbox_center(o)
        set_origin(o, (c.x, c.y, mn.z))
        set_origin(o, (c.x, c.y, mn.z))
        limit_tris(o)
        log("  %-14s %6d tris  %.1f x %.1f x %.1f" % (o.name, tri_count(o), mx.x - mn.x, mx.y - mn.y, mx.z - mn.z))
    # vista previa: acomodar en fila
    for o in obs:
        o.location = (xs, 0, 0)
        c, mn, mx = bbox_center(o)
        xs += (mx.x - mn.x) + 6
    cam = setup_render("EEVEE")
    render(os.path.join(OUT, "render_kit.png"), cam, (20, -150, 50), (20, 0, 18))
    if MODE == "kit":
        texdir = os.path.join(OUT, "texturas_kit")
        os.makedirs(texdir, exist_ok=True)
        for o in obs:
            bake_object(o, 1024 if o.name not in ("RocaLava", "ArbolSeco") else 512, texdir)
        setup_render("EEVEE")
        render(os.path.join(OUT, "render_kit_horneado.png"), bpy.context.scene.camera, (20, -150, 50), (20, 0, 18))
        for o in obs:
            o.location = (0, 0, 0)
        for o in bpy.context.scene.objects:
            o.select_set(False)
        for o in obs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(OUT, "Escenario_Kit.fbx"), use_selection=True, object_types={'MESH'},
            global_scale=1.0, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
            bake_space_transform=True, mesh_smooth_type='FACE', add_leaf_bones=False, bake_anim=False,
            path_mode='COPY', embed_textures=True, axis_forward='-Z', axis_up='Y')
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Escenario_Kit.blend"))
        log("  FBX + blend del kit guardados")
    log("LISTO")

# ---------------------------------------------------------------------
#  MAIN
# ---------------------------------------------------------------------
def build_all():
    M = build_materials()
    parts = {}
    log("Cuerpo...")
    parts["Cuerpo"] = part_cuerpo(M)
    log("Tunica...")
    parts["Tunica"] = part_tunica(M)
    log("Brazos...")
    parts.update(part_brazos(M))
    log("Cabeza / Ojos / Halo...")
    parts["Cabeza"] = part_cabeza(M)
    parts["Ojos"] = part_ojos(M)
    parts["Halo"] = part_halo(M)
    log("Rueda...")
    parts.update(part_rueda(M))
    log("Alas...")
    parts.update(part_alas(M))
    log("Espada / Mano...")
    parts["Espada"] = part_espada(M)
    mano, orb_c = part_manoderecha(M)
    parts["ManoDerecha"] = mano
    log("Base...")
    roca, nubes = part_base(M)
    parts["BaseRoca"] = roca
    parts["NubesFuego"] = nubes
    # Origenes utiles
    origins = {
        "Cuerpo": (0, 0, 46), "Tunica": (0, 0, 42), "BrazoIzq": ARM["sh"],
        "BrazoDer": (-ARM["sh"][0], ARM["sh"][1], ARM["sh"][2]),
        "Cabeza": (0, 0.25, 59), "Ojos": (0, -2.4, 62.4), "Halo": (0, 2.6, 66.8),
        "RuedaExterior": (0, 7.5, 56), "RuedaMedia": (0, 7.5, 56), "RuedaInterior": (0, 7.5, 56),
        "AlaIzq": (3.2, 3.6, 53.5), "AlaDer": (-3.2, 3.6, 53.5), "Espada": tuple(left_fist()),
        "ManoDerecha": tuple(orb_c), "BaseRoca": (0, 0, FEET - 1), "NubesFuego": (0, 0, FEET),
    }
    info = {}
    for nm, ob in parts.items():
        set_origin(ob, origins[nm])
        tc = limit_tris(ob)
        c, mn, mx = bbox_center(ob)
        info[nm] = dict(tris=tc, center=list(c), min=list(mn), max=list(mx), origin=list(origins[nm]))
        log("  %-14s %6d tris  alto %.1f" % (nm, tc, mx.z - mn.z))
    return M, parts, info


def main():
    log("MODO:", MODE, "Blender", bpy.app.version_string)
    reset_scene()
    M, parts, info = build_all()
    total_min = min(v["min"][2] for v in info.values())
    total_max = max(v["max"][2] for v in info.values())
    log("ALTO TOTAL: %.1f studs (%.1f a %.1f)" % (total_max - total_min, total_min, total_max))
    fx = fx_objects(M)
    jug = player_objects(M)
    for o in fx + jug:
        o.hide_render = True
        limit_tris(o)
        log("  %-14s %6d tris" % (o.name, tri_count(o)))
    cam = setup_render("EEVEE")
    tgt = (0, 0, 40)
    tag = "preview" if MODE == "preview" else "final"
    render(os.path.join(OUT, "render_%s_frente.png" % tag), cam, (0, -125, 44), tgt)
    render(os.path.join(OUT, "render_%s_34.png" % tag), cam, (70, -100, 60), tgt)
    if MODE == "preview":
        render(os.path.join(OUT, "render_preview_cara.png"), cam, (6, -26, 63), (0, 0, 60))
    if MODE == "full":
        texdir = os.path.join(OUT, "texturas")
        os.makedirs(texdir, exist_ok=True)
        sizes = {"Ojos": 256, "ManoDerecha": 256, "Halo": 512, "Espada": 512, "RuedaInterior": 512,
                 "RuedaMedia": 512, "RuedaExterior": 1024, "NubesFuego": 512}
        for nm, ob in parts.items():
            bake_object(ob, sizes.get(nm, 1024), texdir)
        for o in fx + jug:
            o.hide_render = False
            bake_object(o, 256 if o.name.startswith("FX") else 512, texdir)
            o.hide_render = True
        setup_render("EEVEE")
        cam = bpy.context.scene.camera
        render(os.path.join(OUT, "render_horneado_frente.png"), cam, (0, -125, 44), tgt)
        render(os.path.join(OUT, "render_horneado_34.png"), cam, (70, -100, 60), tgt)
        # EXPORTAR
        def export(path, objs):
            for o in bpy.context.scene.objects:
                o.select_set(False)
            for o in objs:
                o.hide_set(False)
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.export_scene.fbx(
                filepath=path, use_selection=True, object_types={'MESH'},
                global_scale=1.0, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
                bake_space_transform=True, use_mesh_modifiers=True, mesh_smooth_type='FACE',
                add_leaf_bones=False, bake_anim=False, path_mode='COPY', embed_textures=True,
                axis_forward='-Z', axis_up='Y')
            log("  FBX:", path)
        export(os.path.join(OUT, "Arcangel_SenorLlamas.fbx"), list(parts.values()))
        export(os.path.join(OUT, "Poderes_FX.fbx"), fx)
        export(os.path.join(OUT, "Jugador_Accesorios.fbx"), jug)
        info["_fx"] = {o.name: tri_count(o) for o in fx}
        info["_jug"] = {o.name: tri_count(o) for o in jug}
        with open(os.path.join(OUT, "piezas_info.json"), "w") as f:
            json.dump(info, f, indent=1)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Arcangel_SenorLlamas.blend"))
        log("  .blend guardado")
    log("LISTO")


try:
    if MODE.startswith("kit"):
        main_kit()
    else:
        main()
except Exception:
    log("ERROR:\n" + traceback.format_exc())
finally:
    _logf.close()
