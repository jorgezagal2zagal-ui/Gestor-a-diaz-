-- =====================================================================
--  PODERES DEL JUGADOR (Script en ServerScriptService)
--  El cliente (ControlPoderes) manda:  PoderJugador:FireServer(nombre, apuntar)
--  El servidor revisa enfriamientos, hace el daño al jefe y los efectos.
--    Q  "orbe"     Orbe Sagrado: proyectil de luz           (1.2 s)
--    E  "escudo"   Escudo de Llamas: inmune 4 s              (12 s)
--    R  "tajo"     Tajo Ardiente: corte que avanza (el dash lo hace el cliente) (5 s)
--    F  "estrella" Estrella Caída: definitivo en área        (25 s)
--  Mallas: ReplicatedStorage > FX_Jugador (hechas en Blender).
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local evento = RS:FindFirstChild("PoderJugador") :: RemoteEvent
if not evento then
	evento = Instance.new("RemoteEvent")
	evento.Name = "PoderJugador"
	evento.Parent = RS
end
local FX = RS:WaitForChild("FX_Jugador", 10)

local PODERES = {
	orbe = { cd = 1.2, dano = 60 },
	escudo = { cd = 12, dur = 4 },
	tajo = { cd = 5, dano = 110 },
	estrella = { cd = 25, dano = 320, radio = 24 },
}
local DORADO = Color3.fromRGB(255, 205, 110)
local BLANCO = Color3.fromRGB(255, 245, 220)

local ultimo: { [Player]: { [string]: number } } = {}
Players.PlayerRemoving:Connect(function(p) ultimo[p] = nil end)

-- ---------- helpers ----------------------------------------------------
local function jefe(): (Model?, NumberValue?)
	local d = workspace:FindFirstChild("SenorLlamas")
	if not d then return nil, nil end
	return d :: Model, d:FindFirstChild("VidaJefe") :: NumberValue?
end

local function numeroDano(pos: Vector3, cantidad: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 50)
	bb.AlwaysOnTop = true
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "-" .. math.floor(cantidad)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = DORADO
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	TweenService:Create(a, TweenInfo.new(1), { WorldPosition = pos + Vector3.new(0, 8, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(a, 1.1)
end

local function danarJefe(cantidad: number, pos: Vector3)
	local d, vida = jefe()
	if not (d and vida) or vida.Value <= 0 then return end
	vida.Value = math.max(0, vida.Value - cantidad)
	numeroDano(pos, cantidad)
end

-- ¿qué parte del jefe está cerca de este punto?
local function tocaJefe(pos: Vector3, radio: number): BasePart?
	local d = jefe()
	if not d then return nil end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { d }
	local partes = workspace:GetPartBoundsInRadius(pos, radio, params)
	for _, p in partes do
		if p.Name ~= "HumanoidRootPart" then return p end
	end
	return nil
end

local function malla(nombre: string): BasePart?
	local p = FX and FX:FindFirstChild(nombre)
	if p and p:IsA("BasePart") then
		local c = (p :: BasePart):Clone()
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		return c
	end
	return nil
end

local function luz(padre: Instance, brillo: number, rango: number)
	local l = Instance.new("PointLight")
	l.Color = DORADO
	l.Brightness = brillo
	l.Range = rango
	l.Parent = padre
end

local function chispas(padre: Instance, tam: number, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(BLANCO, DORADO)
	e.LightEmission = 1
	e.Size = NumberSequence.new(tam, 0)
	e.Lifetime = NumberRange.new(0.3, 0.7)
	e.Rate = rate
	e.Speed = NumberRange.new(2, 8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = padre
	return e
end

local function estallido(pos: Vector3, tam: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = DORADO
	p.Size = Vector3.one * 1
	p.Position = pos
	p.Parent = workspace
	luz(p, 8, tam * 3)
	TweenService:Create(p, TweenInfo.new(0.35), { Size = Vector3.one * tam, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.4)
end

-- ---------- poderes ----------------------------------------------------
local function orbe(pj: Model, apuntar: Vector3)
	local hrp = pj:FindFirstChild("HumanoidRootPart") :: BasePart
	local mano = (pj:FindFirstChild("RightHand") or pj:FindFirstChild("Right Arm") or hrp) :: BasePart
	local origen = mano.Position
	local dir = (apuntar - origen)
	if dir.Magnitude < 1 then dir = hrp.CFrame.LookVector end
	dir = dir.Unit
	local cf = CFrame.lookAt(origen, origen + dir)
	local m = malla("JUG_Orbe") or Instance.new("Part")
	m.Name = "OrbeSagrado"
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m:PivotTo(cf)
	luz(m, 5, 16)
	chispas(m, 0.5, 40)
	m.Parent = workspace
	task.spawn(function()
		local pos, vel, t = origen, 150, 0
		while t < 2.2 and m.Parent do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			pos += dir * vel * dt
			m:PivotTo(CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, t * 8))
			local p = tocaJefe(pos, 3.5)
			if p then
				danarJefe(PODERES.orbe.dano, pos)
				estallido(pos, 10)
				break
			end
		end
		m:Destroy()
	end)
end

local function escudo(pj: Model)
	local hrp = pj:FindFirstChild("HumanoidRootPart") :: BasePart
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = pj
	local m = malla("JUG_Escudo")
	if m then
		m.Anchored = false
		m.Massless = true
		m:PivotTo(hrp.CFrame)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = m
		w.Parent = m
		luz(m, 3, 14)
		chispas(m, 0.4, 25)
		m.Parent = pj
		Debris:AddItem(m, PODERES.escudo.dur)
	end
	Debris:AddItem(ff, PODERES.escudo.dur)
end

local function tajo(pj: Model, apuntar: Vector3)
	local hrp = pj:FindFirstChild("HumanoidRootPart") :: BasePart
	local dir = Vector3.new(apuntar.X - hrp.Position.X, 0, apuntar.Z - hrp.Position.Z)
	if dir.Magnitude < 1 then dir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1) end
	dir = dir.Unit
	local m = malla("JUG_Tajo")
	local pos = hrp.Position + dir * 4
	if m then
		m.Size = m.Size * 1.6
		m:PivotTo(CFrame.lookAt(pos, pos + dir))
		luz(m, 6, 20)
		m.Parent = workspace
	end
	task.spawn(function()
		local t, golpeo = 0, false
		while t < 0.45 do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			pos += dir * 130 * dt
			if m then
				m:PivotTo(CFrame.lookAt(pos, pos + dir))
				m.Transparency = math.clamp((t - 0.25) / 0.2, 0, 1)
			end
			if not golpeo then
				-- el tajo es alto: revisa abajo, en medio y arriba
				for _, alto in { 0, 10, 20, 32 } do
					if tocaJefe(pos + Vector3.new(0, alto, 0), 7) then
						danarJefe(PODERES.tajo.dano, pos + Vector3.new(0, alto, 0))
						estallido(pos + Vector3.new(0, alto, 0), 14)
						golpeo = true
						break
					end
				end
			end
		end
		if m then m:Destroy() end
	end)
end

local function estrella(pj: Model, apuntar: Vector3)
	local hrp = pj:FindFirstChild("HumanoidRootPart") :: BasePart
	local plano = Vector3.new(apuntar.X, 0, apuntar.Z)
	local desde = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	if (plano - desde).Magnitude > 160 then
		plano = desde + (plano - desde).Unit * 160
	end
	local r = PODERES.estrella.radio
	-- marca dorada en el suelo
	local marca = Instance.new("Part")
	marca.Anchored = true
	marca.CanCollide = false
	marca.CanQuery = false
	marca.Shape = Enum.PartType.Cylinder
	marca.Size = Vector3.new(0.4, r * 2, r * 2)
	marca.CFrame = CFrame.new(plano + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marca.Material = Enum.Material.Neon
	marca.Color = DORADO
	marca.Transparency = 0.6
	marca.Parent = workspace
	Debris:AddItem(marca, 1.5)
	task.delay(0.8, function()
		local m = malla("JUG_Estrella") or Instance.new("Part")
		m.Anchored = true
		m.CanCollide = false
		m.Size = m.Size * 2.2
		luz(m, 10, 60)
		chispas(m, 1.5, 80)
		m.Parent = workspace
		local inicio, fin = plano + Vector3.new(0, 200, 0), plano + Vector3.new(0, 4, 0)
		local t, dur = 0, 0.55
		while t < dur do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			m:PivotTo(CFrame.new(inicio:Lerp(fin, math.min(t / dur, 1))))
		end
		m:Destroy()
		estallido(fin, r * 2.2)
		local exp = Instance.new("Explosion")
		exp.Position = fin
		exp.BlastRadius = r
		exp.BlastPressure = 0
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = workspace
		-- el jefe es enorme: revisa varias alturas
		for _, alto in { 0, 15, 30 } do
			if tocaJefe(fin + Vector3.new(0, alto, 0), r) then
				danarJefe(PODERES.estrella.dano, fin + Vector3.new(0, alto + 10, 0))
				break
			end
		end
	end)
end

-- ---------- entrada desde el cliente ------------------------------------
evento.OnServerEvent:Connect(function(jugador: Player, nombre: any, apuntar: any)
	if typeof(nombre) ~= "string" or not PODERES[nombre] then return end
	if typeof(apuntar) ~= "Vector3" then apuntar = Vector3.zero end
	local pj = jugador.Character
	local hum = pj and pj:FindFirstChildOfClass("Humanoid")
	if not (pj and hum and hum.Health > 0 and pj:FindFirstChild("HumanoidRootPart")) then return end
	ultimo[jugador] = ultimo[jugador] or {}
	local ahora = os.clock()
	if (ultimo[jugador][nombre] or 0) + PODERES[nombre].cd - 0.15 > ahora then return end
	ultimo[jugador][nombre] = ahora
	if nombre == "orbe" then
		orbe(pj, apuntar)
	elseif nombre == "escudo" then
		escudo(pj)
	elseif nombre == "tajo" then
		tajo(pj, apuntar)
	elseif nombre == "estrella" then
		estrella(pj, apuntar)
	end
end)
