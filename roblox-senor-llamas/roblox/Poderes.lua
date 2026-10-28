--!strict
-- =====================================================================
--  PODERES DEL SEÑOR DE LAS LLAMAS  (ModuleScript / Luau)
-- =====================================================================
--  Poderes BRUTALES y llamativos con efectos (partículas, luz, rayos,
--  explosiones). Pensado para un jefe final.
--
--  DÓNDE VA:  ReplicatedStorage > ModuleScript llamado "Poderes"
--  LO USA:    DemonLordAI.server.lua lo carga con require().
--
--  Ataques incluidos:
--    1. Lluvia de meteoros        (meteoros caen del cielo)
--    2. Pilares de fuego          (columnas que erupcionan bajo el jugador)
--    3. Nova de fuego             (onda expansiva gigante)
--    4. Rayo ocular               (láser de los ojos que persigue)
--    5. Bolas infernales teledirigidas
--    6. Erupción de lava          (géiseres de lava)
--    7. METEORO COLOSAL           (ataque final devastador)
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Sonidos = require(game:GetService("ReplicatedStorage"):WaitForChild("Sonidos"))

local Poderes = {}

-- Referencias (las setea el AI al arrancar con Poderes.configurar)
local DEMONIO: Instance? = nil
local RAIZ: BasePart? = nil

-- Colores de fuego reutilizables
local NARANJA = Color3.fromRGB(255, 120, 20)
local AMARILLO = Color3.fromRGB(255, 220, 90)
local ROJO = Color3.fromRGB(200, 30, 10)

function Poderes.configurar(demonio: Instance, raiz: BasePart)
	DEMONIO = demonio
	RAIZ = raiz
end

-- Altura del piso bajo el jefe (atributo "SueloY" en la raíz; si no, la base de la raíz).
local function sueloY(): number
	local r = RAIZ :: BasePart
	local a = r:GetAttribute("SueloY")
	if typeof(a) == "number" then return a end
	return r.Position.Y - r.Size.Y / 2
end


-- ---------------------------------------------------------------------
--  VISUALES HECHOS EN BLENDER (ReplicatedStorage > FX_Poderes)
--  Si existen, se "visten" las Parts del poder con la malla y la Part
--  se vuelve invisible. Si no existen, todo funciona como antes.
--    modo "esfera"   : malla centrada, escala uniforme según Size.X
--    modo "vertical" : malla vertical, ancho=Size.X, alto=Size.Y
--    modo "anillo"   : malla horizontal, diámetro = max(Size.Y, Size.Z)
--    modo "plano"    : misma orientación que la Part, ancho X, alto Y
-- ---------------------------------------------------------------------
local FX_CARPETA = game:GetService("ReplicatedStorage"):FindFirstChild("FX_Poderes")
local function vestir(parte: BasePart, nombre: string, modo: string): BasePart?
	local plantilla = FX_CARPETA and FX_CARPETA:FindFirstChild(nombre)
	if not (plantilla and plantilla:IsA("BasePart")) then return nil end
	local base = (plantilla :: BasePart).Size
	local m = (plantilla :: BasePart):Clone()
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = false
	local girar = math.random() * math.pi * 2
	local function ajustar()
		local sz = parte.Size
		if modo == "esfera" then
			local k = sz.X / math.max(base.X, base.Z) * 1.6
			m.Size = base * k
			m.CFrame = CFrame.new(parte.Position) * CFrame.Angles(0, girar, 0)
		elseif modo == "vertical" then
			m.Size = Vector3.new(base.X * sz.X / base.X, sz.Y, base.Z * sz.X / base.X)
			m.CFrame = CFrame.new(parte.Position) * CFrame.Angles(0, girar, 0)
		elseif modo == "anillo" then
			local k = math.max(sz.Y, sz.Z) / base.X
			m.Size = base * math.max(k, 0.05)
			m.CFrame = CFrame.new(parte.Position + Vector3.new(0, m.Size.Y * 0.35, 0))
		else -- plano
			m.Size = Vector3.new(sz.X, sz.Y, base.Z * sz.X / base.X)
			m.CFrame = parte.CFrame
		end
	end
	ajustar()
	m.Parent = parte
	parte.Transparency = 1
	local con
	con = RunService.Heartbeat:Connect(function()
		if not parte.Parent then
			con:Disconnect()
			return
		end
		ajustar()
	end)
	return m
end

-- ---------------------------------------------------------------------
--  HELPERS DE EFECTOS
-- ---------------------------------------------------------------------

-- Emisor de partículas de fuego listo para usar.
local function emisorFuego(tamano: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxassetid://243660364"  -- textura de humo/fuego estándar de Roblox
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, AMARILLO),
		ColorSequenceKeypoint.new(0.5, NARANJA),
		ColorSequenceKeypoint.new(1, ROJO),
	})
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tamano),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Rate = rate
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 20, 0)
	return e
end

local function luzFuego(brillo: number, rango: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = NARANJA
	l.Brightness = brillo
	l.Range = rango
	return l
end

-- Daña a todos los jugadores dentro de un radio.
local function danarEnRadio(centro: Vector3, radio: number, dano: number, empuje: number?)
	for _, jugador in Players:GetPlayers() do
		local pj = jugador.Character
		local hum = pj and pj:FindFirstChildOfClass("Humanoid")
		local hrp = pj and pj:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and hrp and hum.Health > 0 then
			local dir = hrp.Position - centro
			if dir.Magnitude <= radio then
				hum:TakeDamage(dano)
				if empuje and empuje > 0 then
					local fuerza = (dir.Magnitude > 0.1 and dir.Unit or Vector3.yAxis)
					hrp.AssemblyLinearVelocity = fuerza * empuje + Vector3.new(0, empuje * 0.6, 0)
				end
			end
		end
	end
end

-- Lista de personajes-objetivo vivos.
local function objetivosVivos(): { BasePart }
	local lista = {}
	for _, jugador in Players:GetPlayers() do
		local pj = jugador.Character
		local hum = pj and pj:FindFirstChildOfClass("Humanoid")
		local hrp = pj and pj:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and hrp and hum.Health > 0 then
			table.insert(lista, hrp)
		end
	end
	return lista
end

-- Marca en el suelo que avisa dónde va a caer un ataque (telegrafía).
local function marcaDeAdvertencia(pos: Vector3, radio: number, duracion: number)
	local marca = Instance.new("Part")
	marca.Anchored = true
	marca.CanCollide = false
	marca.CanQuery = false
	marca.Shape = Enum.PartType.Cylinder
	marca.Size = Vector3.new(0.4, radio * 2, radio * 2)
	marca.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	marca.Material = Enum.Material.Neon
	marca.Color = ROJO
	marca.Transparency = 0.5
	marca.Parent = Workspace
	TweenService:Create(marca, TweenInfo.new(duracion), { Transparency = 0.15 }):Play()
	Debris:AddItem(marca, duracion + 0.1)
end

-- ---------------------------------------------------------------------
--  1. LLUVIA DE METEOROS
-- ---------------------------------------------------------------------
local function caerMeteoro(xz: Vector3, dano: number, radio: number)
	local inicio = xz + Vector3.new(math.random(-20, 20), 180, math.random(-20, 20))
	local meteoro = Instance.new("Part")
	meteoro.Shape = Enum.PartType.Ball
	meteoro.Size = Vector3.new(8, 8, 8)
	meteoro.Position = inicio
	meteoro.Material = Enum.Material.CrackedLava
	meteoro.Color = ROJO
	meteoro.Anchored = true
	meteoro.CanCollide = false
	emisorFuego(9, 60).Parent = meteoro
	luzFuego(8, 30).Parent = meteoro
	meteoro.Parent = Workspace
	local vMeteoro = vestir(meteoro, "FX_Meteoro", "esfera")

	marcaDeAdvertencia(Vector3.new(xz.X, xz.Y + 0.2, xz.Z), radio, 0.8)

	task.spawn(function()
		local destino = Vector3.new(xz.X, xz.Y + 4, xz.Z)
		local t = 0
		local duracion = 0.8
		while t < duracion do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			meteoro.Position = inicio:Lerp(destino, math.min(t / duracion, 1))
		end
		-- IMPACTO
		local exp = Instance.new("Explosion")
		exp.Position = destino
		exp.BlastRadius = radio
		exp.BlastPressure = 0           -- daño manual, sin volar todo sin control
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = Workspace
		danarEnRadio(destino, radio, dano, 40)
		meteoro.Transparency = 1
		if vMeteoro then vMeteoro.Transparency = 1 end
		Debris:AddItem(meteoro, 0.2)
	end)
end

function Poderes.lluviaDeMeteoros(cantidad: number?, dano: number?, radio: number?)
	Sonidos.reproducir("meteoro", RAIZ)
	local n = cantidad or 8
	local d = dano or 30
	local r = radio or 14
	local objetivos = objetivosVivos()
	if #objetivos == 0 then return end
	task.spawn(function()
		for i = 1, n do
			local obj = objetivos[math.random(1, #objetivos)]
			caerMeteoro(obj.Position, d, r)
			task.wait(0.25)
		end
	end)
end

-- ---------------------------------------------------------------------
--  2. PILARES DE FUEGO
-- ---------------------------------------------------------------------
function Poderes.pilaresDeFuego(dano: number?, radio: number?)
	Sonidos.reproducir("pilares", RAIZ)
	local d = dano or 35
	local r = radio or 10
	for _, obj in objetivosVivos() do
		local pos = obj.Position
		marcaDeAdvertencia(Vector3.new(pos.X, pos.Y - 2.5, pos.Z), r, 0.6)
		task.delay(0.6, function()
			local pilar = Instance.new("Part")
			pilar.Anchored = true
			pilar.CanCollide = false
			pilar.Size = Vector3.new(r * 1.6, 60, r * 1.6)
			pilar.Position = Vector3.new(pos.X, pos.Y + 28, pos.Z)
			pilar.Material = Enum.Material.Neon
			pilar.Color = NARANJA
			pilar.Transparency = 0.25
			emisorFuego(r, 120).Parent = pilar
			luzFuego(10, 40).Parent = pilar
			pilar.Parent = Workspace
			local vPilar = vestir(pilar, "FX_Pilar", "vertical")
			danarEnRadio(pos, r, d, 55)
			TweenService:Create(vPilar or pilar, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			Debris:AddItem(pilar, 0.6)
		end)
	end
end

-- ---------------------------------------------------------------------
--  3. NOVA DE FUEGO (onda expansiva gigante)
-- ---------------------------------------------------------------------
function Poderes.novaDeFuego(radioMax: number?, dano: number?)
	Sonidos.reproducir("nova", RAIZ)
	if not RAIZ then return end
	local raiz = RAIZ :: BasePart
	local rMax = radioMax or 50
	local d = dano or 45
	local onda = Instance.new("Part")
	onda.Anchored = true
	onda.CanCollide = false
	onda.CanQuery = false
	onda.Shape = Enum.PartType.Cylinder
	local centroPiso = Vector3.new(raiz.Position.X, sueloY() + 1, raiz.Position.Z)
	onda.CFrame = CFrame.new(centroPiso) * CFrame.Angles(0, 0, math.rad(90))
	onda.Size = Vector3.new(2, 2, 2)
	onda.Material = Enum.Material.Neon
	onda.Color = AMARILLO
	onda.Transparency = 0.1
	luzFuego(12, rMax).Parent = onda
	onda.Parent = Workspace
	local vOnda = vestir(onda, "FX_Onda", "anillo")

	task.spawn(function()
		local pasos = 24
		for i = 1, pasos do
			local f = i / pasos
			onda.Size = Vector3.new(3, rMax * 2 * f, rMax * 2 * f)
			if vOnda then vOnda.Transparency = 0.9 * f * f else onda.Transparency = 0.1 + 0.9 * f end
			task.wait(0.02)
		end
		onda:Destroy()
	end)
	danarEnRadio(centroPiso, rMax, d, 70)
end

-- ---------------------------------------------------------------------
--  4. RAYO OCULAR (láser que persigue)
-- ---------------------------------------------------------------------
function Poderes.rayoOcular(objetivo: BasePart, duracion: number?, danoPorSeg: number?)
	Sonidos.reproducir("rayo", RAIZ)
	if not RAIZ then return end
	local raiz = RAIZ :: BasePart
	local dur = duracion or 2.5
	local dps = danoPorSeg or 30

	-- Origen del rayo (ojos): una Part "Ojos" si existe, si no la parte alta de la raíz.
	local ojos = (DEMONIO and DEMONIO:FindFirstChild("Ojos")) :: BasePart?
	local a0 = Instance.new("Attachment")
	a0.Parent = ojos or raiz
	if not ojos then a0.Position = Vector3.new(0, raiz.Size.Y / 2, -raiz.Size.Z / 2) end

	local a1 = Instance.new("Attachment")
	a1.Parent = objetivo

	local haz = Instance.new("Beam")
	haz.Attachment0 = a0
	haz.Attachment1 = a1
	haz.Width0 = 2.5
	haz.Width1 = 1.2
	haz.Color = ColorSequence.new(AMARILLO, ROJO)
	haz.LightEmission = 1
	haz.FaceCamera = true
	haz.Texture = "rbxassetid://446111271"
	haz.TextureSpeed = 4
	haz.Parent = a0

	task.spawn(function()
		local t = 0
		while t < dur and objetivo.Parent do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			local hum = objetivo.Parent and objetivo.Parent:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum:TakeDamage(dps * dt)
			end
		end
		haz:Destroy(); a0:Destroy(); a1:Destroy()
	end)
end

-- ---------------------------------------------------------------------
--  5. BOLAS INFERNALES TELEDIRIGIDAS
-- ---------------------------------------------------------------------
function Poderes.bolasInfernales(cantidad: number?, dano: number?, velocidad: number?)
	Sonidos.reproducir("bolas", RAIZ)
	if not RAIZ then return end
	local raiz = RAIZ :: BasePart
	local n = cantidad or 5
	local d = dano or 22
	local vel = velocidad or 55
	local objetivos = objetivosVivos()
	if #objetivos == 0 then return end

	task.spawn(function()
		for i = 1, n do
			local objetivo = objetivos[math.random(1, #objetivos)]
			local bola = Instance.new("Part")
			bola.Shape = Enum.PartType.Ball
			bola.Size = Vector3.new(3, 3, 3)
			local mano = DEMONIO and DEMONIO:FindFirstChild("ManoDerecha")
			bola.Position = (mano and mano:IsA("BasePart")) and (mano :: BasePart).Position
				or (raiz.Position + raiz.CFrame.UpVector * 6)
			bola.Material = Enum.Material.Neon
			bola.Color = NARANJA
			bola.CanCollide = false
			bola.Anchored = true
			emisorFuego(4, 40).Parent = bola
			luzFuego(6, 16).Parent = bola
			bola.Parent = Workspace
			local vBola = vestir(bola, "FX_BolaFuego", "esfera")

			-- Persigue al objetivo por unos segundos.
			task.spawn(function()
				local t = 0
				local golpeo = false
				while t < 4 and bola.Parent and not golpeo do
					local dt = RunService.Heartbeat:Wait()
					t += dt
					if objetivo.Parent then
						local dir = (objetivo.Position - bola.Position)
						if dir.Magnitude < 4 then
							local hum = objetivo.Parent:FindFirstChildOfClass("Humanoid")
							if hum then hum:TakeDamage(d) end
							danarEnRadio(bola.Position, 6, d * 0.5, 20)
							golpeo = true
						else
							bola.Position += dir.Unit * vel * dt
						end
					end
				end
				bola.Transparency = 1
				if vBola then vBola.Transparency = 1 end
				Debris:AddItem(bola, 0.1)
			end)
			task.wait(0.3)
		end
	end)
end

-- ---------------------------------------------------------------------
--  6. ERUPCIÓN DE LAVA (géiseres por todo el mapa)
-- ---------------------------------------------------------------------
function Poderes.erupcionDeLava(cantidad: number?, dano: number?)
	Sonidos.reproducir("lava", RAIZ)
	if not RAIZ then return end
	local raiz = RAIZ :: BasePart
	local n = cantidad or 14
	local d = dano or 28
	task.spawn(function()
		for i = 1, n do
			local ang = math.random() * math.pi * 2
			local dist = math.random(10, 70)
			local centro = Vector3.new(raiz.Position.X + math.cos(ang) * dist, sueloY(), raiz.Position.Z + math.sin(ang) * dist)
			marcaDeAdvertencia(centro, 8, 0.4)
			task.delay(0.4, function()
				local geiser = Instance.new("Part")
				geiser.Anchored = true
				geiser.CanCollide = false
				geiser.Size = Vector3.new(10, 40, 10)
				geiser.Position = centro + Vector3.new(0, 20, 0)
				geiser.Material = Enum.Material.CrackedLava
				geiser.Color = Color3.fromRGB(255, 80, 10)
				emisorFuego(8, 90).Parent = geiser
				luzFuego(9, 30).Parent = geiser
				geiser.Parent = Workspace
				local vGeiser = vestir(geiser, "FX_Geiser", "vertical")
				danarEnRadio(centro, 9, d, 50)
				TweenService:Create(vGeiser or geiser, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				Debris:AddItem(geiser, 0.6)
			end)
			task.wait(0.12)
		end
	end)
end

-- ---------------------------------------------------------------------
--  MELEE: ZARPAZO (golpe cuerpo a cuerpo en arco)
-- ---------------------------------------------------------------------
--  Daña a los jugadores que estén EN FRENTE del demonio y dentro del
--  rango. Es el "rango de golpes" para cuando te le acercas.
function Poderes.zarpazo(dano: number?, rango: number?, anguloGrados: number?)
	Sonidos.reproducir("zarpazo", RAIZ)
	if not RAIZ then return end
	local raiz = RAIZ :: BasePart
	local d = dano or 35
	local rango_ = rango or 22
	local cosLimite = math.cos(math.rad((anguloGrados or 120) / 2))

	-- VFX: tajo de garra al frente
	local tajo = Instance.new("Part")
	tajo.Anchored = true
	tajo.CanCollide = false
	tajo.CanQuery = false
	tajo.Size = Vector3.new(rango_ * 1.6, rango_ * 1.2, 1)
	local baseZ = CFrame.new(raiz.Position.X, sueloY() + rango_ * 0.6, raiz.Position.Z) * raiz.CFrame.Rotation
	tajo.CFrame = baseZ * CFrame.new(0, 0, -rango_ * 0.5)
	tajo.Material = Enum.Material.Neon
	tajo.Color = Color3.fromRGB(255, 90, 30)
	tajo.Transparency = 0.3
	emisorFuego(5, 50).Parent = tajo
	tajo.Parent = Workspace
	local vTajo = vestir(tajo, "FX_MediaLuna", "plano")
	TweenService:Create(vTajo or tajo, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	Debris:AddItem(tajo, 0.35)

	-- Daño solo a quien esté dentro del arco frontal
	local frente = raiz.CFrame.LookVector
	for _, obj in objetivosVivos() do
		local dir = obj.Position - raiz.Position
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude <= rango_ then
			local haciaObj = (dir.Magnitude > 0.1) and dir.Unit or frente
			if frente:Dot(haciaObj) >= cosLimite then
				local hum = obj.Parent and obj.Parent:FindFirstChildOfClass("Humanoid")
				if hum then hum:TakeDamage(d) end
				obj.AssemblyLinearVelocity = haciaObj * 60 + Vector3.new(0, 30, 0)
			end
		end
	end
end

-- ---------------------------------------------------------------------
--  7. METEORO COLOSAL (ataque final — brutal)
-- ---------------------------------------------------------------------
function Poderes.meteoroColosal(dano: number?, radio: number?)
	Sonidos.reproducir("colosal", RAIZ)
	local objetivos = objetivosVivos()
	if #objetivos == 0 then return end
	local d = dano or 90
	local r = radio or 45
	-- cae en el promedio de los jugadores (los acorrala)
	local suma = Vector3.zero
	for _, o in objetivos do suma += o.Position end
	local centro = suma / #objetivos

	marcaDeAdvertencia(centro, r, 2.0)
	local inicio = centro + Vector3.new(0, 350, 0)
	local meteoro = Instance.new("Part")
	meteoro.Shape = Enum.PartType.Ball
	meteoro.Size = Vector3.new(40, 40, 40)
	meteoro.Position = inicio
	meteoro.Material = Enum.Material.CrackedLava
	meteoro.Color = ROJO
	meteoro.Anchored = true
	meteoro.CanCollide = false
	emisorFuego(40, 200).Parent = meteoro
	luzFuego(20, 120).Parent = meteoro
	meteoro.Parent = Workspace
	local vColosal = vestir(meteoro, "FX_Meteoro", "esfera")

	task.spawn(function()
		local destino = Vector3.new(centro.X, centro.Y + 20, centro.Z)
		local t = 0
		local dur = 2.0
		while t < dur do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			meteoro.Position = inicio:Lerp(destino, math.min(t / dur, 1))
		end
		local exp = Instance.new("Explosion")
		exp.Position = destino
		exp.BlastRadius = r
		exp.BlastPressure = 200000
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = Workspace
		danarEnRadio(destino, r, d, 120)
		meteoro.Transparency = 1
		if vColosal then vColosal.Transparency = 1 end
		Debris:AddItem(meteoro, 0.3)
	end)
end

return Poderes
