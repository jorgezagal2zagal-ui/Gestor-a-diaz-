--!strict
-- =====================================================================
--  EL SEÑOR DE LAS LLAMAS  -  IA + Zona de la ciudad (Roblox / Luau)
-- =====================================================================
--  QUÉ HACE:
--   * Detecta cuando un jugador ENTRA a la ciudad (una Part de zona).
--   * El demonio se activa, mira al jugador más cercano y lo ATACA:
--       - lanza bolas de fuego,
--       - hace un golpe de área (AOE) cada cierto tiempo.
--   * Cuando no hay nadie en la ciudad, vuelve a dormir.
--
--  DÓNDE VA:
--   Pega este Script dentro de  ServerScriptService.
--
--  QUÉ NECESITAS EN EL WORKSPACE (ver README):
--   * Un Model llamado "SenorLlamas" con un PrimaryPart (ej. "HumanoidRootPart").
--   * Una Part llamada "ZonaCiudad" (Anchored, CanCollide=false, Transparency=1)
--     que cubra el área de la ciudad.
-- =====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

-- ---------- CONFIGURACIÓN (ajústala a tu gusto) ----------------------
local CONFIG = {
	NOMBRE_DEMONIO   = "SenorLlamas",
	NOMBRE_ZONA      = "ZonaCiudad",

	DANIO_BOLA       = 25,      -- daño por bola de fuego
	DANIO_AOE        = 40,      -- daño del golpe de área
	RADIO_AOE        = 28,      -- alcance del golpe de área (studs)

	COOLDOWN_BOLA    = 1.2,     -- segundos entre bolas de fuego
	COOLDOWN_AOE     = 7.0,     -- segundos entre golpes de área
	VEL_BOLA         = 90,      -- velocidad de la bola de fuego (studs/s)
	VIDA_BOLA        = 6,       -- segundos antes de que la bola se borre

	GIRO_SUAVE       = 6,       -- qué tan rápido gira a ver al jugador
}
-- --------------------------------------------------------------------

-- Referencias al mundo
local demonio = Workspace:WaitForChild(CONFIG.NOMBRE_DEMONIO)
local zona = Workspace:WaitForChild(CONFIG.NOMBRE_ZONA) :: BasePart

local raiz: BasePart = (demonio :: Model).PrimaryPart
	or (demonio:FindFirstChild("HumanoidRootPart") :: BasePart)
assert(raiz, "El Model '" .. CONFIG.NOMBRE_DEMONIO .. "' necesita un PrimaryPart.")

-- ---------- UTILIDADES -----------------------------------------------

-- ¿Está 'pos' dentro de la Part 'parte' (caja orientada)?
local function dentroDe(parte: BasePart, pos: Vector3): boolean
	local local_ = parte.CFrame:PointToObjectSpace(pos)
	local h = parte.Size / 2
	return math.abs(local_.X) <= h.X
		and math.abs(local_.Y) <= h.Y
		and math.abs(local_.Z) <= h.Z
end

-- Devuelve el jugador vivo más cercano que esté DENTRO de la ciudad, o nil.
local function objetivoEnCiudad(): (Player?, BasePart?)
	local mejor: Player? = nil
	local mejorParte: BasePart? = nil
	local mejorDist = math.huge
	for _, jugador in Players:GetPlayers() do
		local pj = jugador.Character
		local hum = pj and pj:FindFirstChildOfClass("Humanoid")
		local hrp = pj and pj:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and hrp and hum.Health > 0 and dentroDe(zona, hrp.Position) then
			local d = (hrp.Position - raiz.Position).Magnitude
			if d < mejorDist then
				mejorDist, mejor, mejorParte = d, jugador, hrp
			end
		end
	end
	return mejor, mejorParte
end

-- El demonio voltea (solo en el eje Y) a mirar un punto.
local function mirarHacia(objetivo: Vector3, dt: number)
	local plano = Vector3.new(objetivo.X, raiz.Position.Y, objetivo.Z)
	local deseado = CFrame.lookAt(raiz.Position, plano)
	local alfa = math.clamp(CONFIG.GIRO_SUAVE * dt, 0, 1)
	raiz.CFrame = raiz.CFrame:Lerp(deseado, alfa)
end

-- ---------- ATAQUES ---------------------------------------------------

-- Punto desde donde salen las bolas (una "mano" si existe, si no la raíz).
local function puntoDeDisparo(): Vector3
	local mano = demonio:FindFirstChild("ManoDerecha") :: BasePart?
	if mano then
		return mano.Position
	end
	return raiz.Position + raiz.CFrame.UpVector * 6 + raiz.CFrame.LookVector * 3
end

local function lanzarBolaDeFuego(destino: BasePart)
	local origen = puntoDeDisparo()
	local bola = Instance.new("Part")
	bola.Shape = Enum.PartType.Ball
	bola.Size = Vector3.new(4, 4, 4)
	bola.Position = origen
	bola.Material = Enum.Material.Neon
	bola.Color = Color3.fromRGB(255, 120, 20)
	bola.CanCollide = false
	bola.Massless = true

	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 130, 30)
	luz.Brightness = 6
	luz.Range = 18
	luz.Parent = bola

	-- Dirección hacia el objetivo en el momento del disparo.
	local dir = (destino.Position - origen).Unit
	bola.AssemblyLinearVelocity = dir * CONFIG.VEL_BOLA
	bola.Parent = Workspace

	-- Daño al tocar a un personaje.
	local golpeado = false
	bola.Touched:Connect(function(hit)
		if golpeado then return end
		if hit:IsDescendantOf(demonio) then return end
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			golpeado = true
			hum:TakeDamage(CONFIG.DANIO_BOLA)
			bola:Destroy()
		end
	end)

	Debris:AddItem(bola, CONFIG.VIDA_BOLA)
end

local function golpeDeArea()
	-- Onda expansiva visual
	local onda = Instance.new("Part")
	onda.Anchored = true
	onda.CanCollide = false
	onda.Shape = Enum.PartType.Cylinder
	onda.Material = Enum.Material.Neon
	onda.Color = Color3.fromRGB(255, 90, 20)
	onda.Transparency = 0.2
	onda.CFrame = CFrame.new(raiz.Position - Vector3.new(0, raiz.Size.Y / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	onda.Size = Vector3.new(1, 4, 4)
	onda.Parent = Workspace

	-- Crece y se desvanece
	task.spawn(function()
		local pasos = 20
		for i = 1, pasos do
			local f = i / pasos
			onda.Size = Vector3.new(1, CONFIG.RADIO_AOE * 2 * f, CONFIG.RADIO_AOE * 2 * f)
			onda.Transparency = 0.2 + 0.8 * f
			task.wait(0.02)
		end
		onda:Destroy()
	end)

	-- Daño a todos los jugadores dentro del radio
	for _, jugador in Players:GetPlayers() do
		local pj = jugador.Character
		local hum = pj and pj:FindFirstChildOfClass("Humanoid")
		local hrp = pj and pj:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and hrp and hum.Health > 0 then
			if (hrp.Position - raiz.Position).Magnitude <= CONFIG.RADIO_AOE then
				hum:TakeDamage(CONFIG.DANIO_AOE)
			end
		end
	end
end

-- ---------- BUCLE PRINCIPAL ------------------------------------------
local tBola = 0
local tAoe = 0
local activo = false

RunService.Heartbeat:Connect(function(dt)
	local jugador, parte = objetivoEnCiudad()

	if jugador and parte then
		if not activo then
			activo = true
			print("[SeñorLlamas] ¡" .. jugador.Name .. " entró a la ciudad! El demonio despierta.")
		end

		mirarHacia(parte.Position, dt)

		tBola += dt
		if tBola >= CONFIG.COOLDOWN_BOLA then
			tBola = 0
			lanzarBolaDeFuego(parte)
		end

		tAoe += dt
		if tAoe >= CONFIG.COOLDOWN_AOE then
			tAoe = 0
			golpeDeArea()
		end
	else
		if activo then
			activo = false
			print("[SeñorLlamas] La ciudad quedó vacía. El demonio duerme.")
		end
	end
end)

print("[SeñorLlamas] IA cargada. Esperando intrusos en '" .. CONFIG.NOMBRE_ZONA .. "'...")
