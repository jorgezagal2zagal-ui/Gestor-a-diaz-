-- =====================================================================
--  ARMADO DEL ARCÁNGEL "SenorLlamas"  (pegar en la Barra de Comandos)
--  Requiere haber importado con Importar 3D:
--    Arcangel_SenorLlamas.fbx, Poderes_FX.fbx, Jugador_Accesorios.fbx
-- =====================================================================
local WS = workspace
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")

local imp = WS:FindFirstChild("Arcangel_SenorLlamas")
assert(imp, "No encuentro el modelo importado 'Arcangel_SenorLlamas' en Workspace")

-- 1) borrar el bloque temporal (y cualquier SenorLlamas viejo)
for _, v in WS:GetChildren() do
	if v.Name == "SenorLlamas" and v ~= imp then v:Destroy() end
end

-- 2) prueba: ¿las piezas ancladas siguen a la raíz por WeldConstraint?
local ta = Instance.new("Part") ta.Anchored = true ta.Position = Vector3.new(0, 900, 0) ta.Parent = WS
local tb = Instance.new("Part") tb.Anchored = true tb.Position = Vector3.new(0, 905, 0) tb.Parent = WS
local tw = Instance.new("WeldConstraint") tw.Part0 = ta tw.Part1 = tb tw.Parent = ta
ta.CFrame = CFrame.new(10, 900, 0) * CFrame.Angles(0, math.rad(90), 0)
local ANCLADAS_SIGUEN = (tb.Position - Vector3.new(10, 905, 0)).Magnitude < 0.05
ta:Destroy() tb:Destroy()
print("[Armado] piezas ancladas siguen con WeldConstraint:", ANCLADAS_SIGUEN)

-- 3) dirección del frente (de la cabeza hacia los ojos) en la orientación importada
local cabeza, ojos = imp:FindFirstChild("Cabeza"), imp:FindFirstChild("Ojos")
assert(cabeza and ojos, "Faltan Cabeza u Ojos en el modelo importado")
local f = ojos.Position - cabeza.Position
local FRENTE = Vector3.new(f.X, 0, f.Z).Unit
local GIRO_FRENTE = math.atan2(FRENTE.X, -FRENTE.Z) -- para orientar otras mallas de Blender
print("[Armado] frente importado:", FRENTE)

-- 4) medidas
local cf0, size0 = imp:GetBoundingBox()
local minY = cf0.Position.Y - size0.Y / 2
local alto = size0.Y
print(("[Armado] alto del modelo: %.1f studs"):format(alto))
local cuerpo = imp:FindFirstChild("Cuerpo")
local centroXZ = Vector3.new(cuerpo.Position.X, 0, cuerpo.Position.Z)

-- 5) HumanoidRootPart en el centro del torso (46 studs sobre la base en Blender)
local alturaTorso = 46 - 0.9
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = Vector3.new(6, 6, 6)
hrp.Transparency = 1
hrp.CanCollide = false
hrp.CanQuery = false
hrp.CanTouch = false
hrp.Anchored = true
local pos = Vector3.new(centroXZ.X, minY + alturaTorso, centroXZ.Z)
hrp.CFrame = CFrame.lookAt(pos, pos + FRENTE)
hrp.Parent = imp
imp.Name = "SenorLlamas"
imp.PrimaryPart = hrp

-- 6) colocarlo en el centro de la plaza, mirando a la puerta (+X), base en el piso (y=0)
local destino = Vector3.new(0, alturaTorso - 0.4, 0)
imp:PivotTo(CFrame.lookAt(destino, destino + Vector3.xAxis))
hrp:SetAttribute("SueloY", 0)
hrp:SetAttribute("AlturaBarra", (alto - alturaTorso) + 6)

-- 7) soldar todo a la raíz (las ruedas giran con su propio script)
local RUEDAS = { RuedaExterior = true, RuedaMedia = true, RuedaInterior = true }
local SIN_COLISION = { AlaIzq = true, AlaDer = true, Halo = true, Ojos = true, ManoDerecha = true,
	Espada = true, NubesFuego = true, RuedaExterior = true, RuedaMedia = true, RuedaInterior = true }
for _, p in imp:GetChildren() do
	if p:IsA("BasePart") and p ~= hrp then
		p.CanTouch = true
		p.CanCollide = not SIN_COLISION[p.Name]
		p.CastShadow = not (p.Name == "Ojos" or p.Name == "Halo" or p.Name == "ManoDerecha")
		if RUEDAS[p.Name] then
			p.Anchored = true
		else
			p.Anchored = ANCLADAS_SIGUEN
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Name = "Soldadura_" .. p.Name
			w.Part0 = hrp
			w.Part1 = p
			w.Parent = hrp
		end
	end
end
pcall(function() imp.BaseRoca.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition end)

-- 7b) ajuste de texturas para la luz de Roblox (más fuerte que la de Blender):
--     armadura oscura con grietas encendidas, fuego brillante, ruedas suaves
local OSCURAS = { Cuerpo = true, Tunica = true, BrazoIzq = true, BrazoDer = true, Cabeza = true,
	AlaIzq = true, AlaDer = true, BaseRoca = true }
local FUERTES = { Ojos = true, ManoDerecha = true, Halo = true, Espada = true }
for _, p in imp:GetChildren() do
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		pcall(function()
			if OSCURAS[p.Name] then
				sa.Color = Color3.fromRGB(70, 62, 62)
				sa.EmissiveStrength = 5
				sa.EmissiveTint = Color3.fromRGB(255, 140, 60)
			elseif FUERTES[p.Name] then
				sa.EmissiveStrength = 3
			elseif RUEDAS[p.Name] then
				sa.EmissiveStrength = 0.25
			else
				sa.EmissiveStrength = 0.8
			end
		end)
	end
end

-- 8) fuego y luces
local FUEGO = "rbxasset://textures/particles/fire_main.dds"
local CHISPA = "rbxasset://textures/particles/sparkles_main.dds"
local HUMO = "rbxasset://textures/particles/smoke_main.dds"
local AMARILLO = Color3.fromRGB(255, 214, 90)
local NARANJA = Color3.fromRGB(255, 120, 20)
local ROJO = Color3.fromRGB(200, 30, 10)
local function fuego(padre, tam, rate, vel, tex, vida)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fuego"
	e.Texture = tex or FUEGO
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, AMARILLO),
		ColorSequenceKeypoint.new(0.45, NARANJA),
		ColorSequenceKeypoint.new(1, ROJO),
	})
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, tam), NumberSequenceKeypoint.new(1, tam * 0.15) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(vida or 0.5, (vida or 0.5) * 1.8)
	e.Rate = rate
	e.Speed = NumberRange.new(vel * 0.5, vel)
	e.SpreadAngle = Vector2.new(30, 30)
	e.Acceleration = Vector3.new(0, vel * 1.5, 0)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = padre
	return e
end
local function luz(padre, color, brillo, rango)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brillo
	l.Range = rango
	l.Shadows = false
	l.Parent = padre
	return l
end
local o = imp.Ojos
luz(o, AMARILLO, 6, 22)
fuego(o, 0.6, 30, 3, CHISPA, 0.4)
local mano = imp.ManoDerecha
luz(mano, NARANJA, 8, 30)
fuego(mano, 3, 60, 6)
fuego(mano, 1, 20, 10, CHISPA, 0.6)
luz(imp.Halo, NARANJA, 5, 28)
fuego(imp.Halo, 1.6, 40, 4)
luz(imp.Espada, NARANJA, 6, 26)
fuego(imp.Espada, 1.4, 70, 3)
luz(imp.RuedaExterior, Color3.fromRGB(255, 150, 60), 2, 40)
fuego(imp.RuedaMedia, 0.8, 25, 2, CHISPA, 1)
local nubes = imp.NubesFuego
fuego(nubes, 9, 45, 8, nil, 1.1)
local humo = fuego(nubes, 14, 10, 6, HUMO, 3)
humo.Color = ColorSequence.new(Color3.fromRGB(60, 25, 20), Color3.fromRGB(15, 10, 10))
humo.LightEmission = 0
humo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
luz(imp.BaseRoca, NARANJA, 6, 45)
luz(imp.Cuerpo, Color3.fromRGB(255, 80, 30), 2, 30)

-- 9) luz de atardecer rojo
for _, c in Lighting:GetChildren() do
	if c:IsA("Atmosphere") or c:IsA("BloomEffect") or c:IsA("ColorCorrectionEffect") or c:IsA("SunRaysEffect") then
		c:Destroy()
	end
end
pcall(function() Lighting.Technology = Enum.Technology.Future end)
Lighting.ClockTime = 17.85
Lighting.GeographicLatitude = 25
Lighting.Brightness = 1.6
Lighting.Ambient = Color3.fromRGB(35, 18, 16)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 40, 38)
Lighting.ColorShift_Top = Color3.fromRGB(255, 150, 110)
Lighting.ColorShift_Bottom = Color3.fromRGB(110, 20, 10)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true
local atm = Instance.new("Atmosphere")
atm.Density = 0.38
atm.Offset = 0.2
atm.Color = Color3.fromRGB(205, 95, 60)
atm.Decay = Color3.fromRGB(110, 28, 18)
atm.Glare = 0.45
atm.Haze = 1.8
atm.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 1
bloom.Size = 36
bloom.Threshold = 0.85
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Brightness = 0.02
cc.Contrast = 0.15
cc.Saturation = 0.12
cc.TintColor = Color3.fromRGB(255, 232, 220)
cc.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.1
rays.Spread = 0.6
rays.Parent = Lighting

-- 10) efectos de poderes -> ReplicatedStorage.FX_Poderes ; accesorios -> ServerStorage.EstiloJugador
local function guardar(nombreModelo, destinoPadre, nuevoNombre)
	local m = WS:FindFirstChild(nombreModelo)
	if not m then warn("[Armado] no encontré " .. nombreModelo) return end
	local viejo = destinoPadre:FindFirstChild(nuevoNombre)
	if viejo then viejo:Destroy() end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	m.Name = nuevoNombre
	m:SetAttribute("GiroFrente", GIRO_FRENTE)
	m.Parent = destinoPadre
end
guardar("Poderes_FX", RS, "FX_Poderes")
guardar("Jugador_Accesorios", SS, "EstiloJugador")
guardar("Escenario_Kit", SS, "EscenarioKit")
local kit = SS:FindFirstChild("EscenarioKit")
if kit then
	for _, p in kit:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = true
			p.CanQuery = true
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if sa then pcall(function() sa.EmissiveStrength = 2 end) end
		end
	end
end

-- 11) scripts: ruedas que giran, estilo de jugadores, poderes y AI actualizados
local function ponerScript(padre, clase, nombre, fuente)
	local viejo = padre:FindFirstChild(nombre)
	if viejo then viejo:Destroy() end
	local s = Instance.new(clase)
	s.Name = nombre
	s.Source = fuente
	s.Parent = padre
	return s
end
ponerScript(SSS, "Script", "RuedasGiro", [==[__RUEDAS__]==])
ponerScript(SSS, "Script", "EstiloJugador", [==[__ESTILO__]==])

local function actualizar(inst, largoOriginal, fuente)
	if not inst then warn("[Armado] no encontré script para actualizar") return end
	if #inst.Source ~= largoOriginal and inst.Source ~= fuente then
		warn(("[Armado] %s fue modificado por ti (largo %d); lo respaldo como %s_Respaldo antes de actualizar")
			:format(inst.Name, #inst.Source, inst.Name))
		local r = inst:Clone()
		r.Name = inst.Name .. "_Respaldo"
		r.Disabled = true
		pcall(function() r.Enabled = false end)
		r.Parent = SS
	end
	inst.Source = fuente
end
actualizar(RS:FindFirstChild("Poderes"), 16293, [==[__PODERES__]==])
actualizar(SSS:FindFirstChild("DemonLordAI"), 9088, [==[__AI__]==])
actualizar(SSS:FindFirstChild("CiudadArena"), 8136, [==[__CIUDAD__]==])

game:GetService("Selection"):Set({ imp })
print("[Armado] LISTO: SenorLlamas armado con", #imp:GetChildren(), "hijos. Ancladas:", ANCLADAS_SIGUEN)
