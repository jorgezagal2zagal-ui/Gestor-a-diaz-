--!strict
-- =====================================================================
--  EL SEÑOR DE LAS LLAMAS  -  Cerebro del jefe (Roblox / Luau)
-- =====================================================================
--  * Detecta cuando un jugador ENTRA a la ciudad.
--  * Despierta, te mira y encadena PODERES BRUTALES por FASES.
--  * Tiene vida y barra de jefe: puedes derrotarlo.
--  * Al morir, explota en una erupción final.
--
--  DÓNDE VA:  pega este Script en  ServerScriptService.
--
--  NECESITAS EN EL WORKSPACE (ver README):
--   * Model "SenorLlamas" con PrimaryPart (p.ej. "HumanoidRootPart").
--       - (opcional) Parts "Ojos" y "ManoDerecha" para que salgan de ahí.
--   * Part "ZonaCiudad" (Anchored, CanCollide=false, Transparency=1).
--   * ModuleScript "Poderes" en ReplicatedStorage.
-- =====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Poderes = require(ReplicatedStorage:WaitForChild("Poderes"))
local Sonidos = require(ReplicatedStorage:WaitForChild("Sonidos"))

-- ---------- CONFIGURACIÓN --------------------------------------------
local CONFIG = {
	NOMBRE_DEMONIO = "SenorLlamas",
	NOMBRE_ZONA    = "ZonaCiudad",

	VIDA_MAX       = 5000,     -- vida del jefe
	GIRO_SUAVE     = 5,        -- qué tan rápido voltea a verte

	-- Rango de golpes cuerpo a cuerpo (zarpazo cuando te le acercas)
	RANGO_MELEE    = 24,       -- distancia (studs) para que use garras
	DANO_MELEE     = 38,       -- daño del zarpazo
	ESPERA_MELEE   = 1.0,      -- segundos entre zarpazos

	COOLDOWN_GOLPE = 0.4,      -- seg mínimos entre golpes de la MISMA arma al jefe

	-- Tiempo entre ataques según la fase (menos = más agresivo)
	ESPERA_FASE1   = 3.5,      -- 100%–66% de vida
	ESPERA_FASE2   = 2.2,      -- 66%–33% de vida
	ESPERA_FASE3   = 1.3,      -- 33%–0%  de vida (modo furia)
}
-- --------------------------------------------------------------------

local demonio = Workspace:WaitForChild(CONFIG.NOMBRE_DEMONIO)
local zona = Workspace:WaitForChild(CONFIG.NOMBRE_ZONA) :: BasePart
local raiz: BasePart = (demonio :: Model).PrimaryPart
	or (demonio:FindFirstChild("HumanoidRootPart") :: BasePart)
assert(raiz, "El Model '" .. CONFIG.NOMBRE_DEMONIO .. "' necesita un PrimaryPart.")

Poderes.configurar(demonio, raiz)

-- ---------- VIDA DEL JEFE + BARRA ------------------------------------
local vida = Instance.new("NumberValue")
vida.Name = "VidaJefe"
vida.Value = CONFIG.VIDA_MAX
vida.Parent = demonio

local function crearBarraDeVida()
	local bb = Instance.new("BillboardGui")
	bb.Name = "BarraJefe"
	bb.Size = UDim2.new(14, 0, 1.4, 0)
	bb.StudsOffsetWorldSpace = Vector3.new(0, raiz.Size.Y / 2 + 8, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = raiz
	bb.Parent = raiz

	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Color3.fromRGB(20, 5, 5)
	fondo.BorderSizePixel = 0
	fondo.Parent = bb

	local relleno = Instance.new("Frame")
	relleno.Name = "Relleno"
	relleno.Size = UDim2.fromScale(1, 1)
	relleno.BackgroundColor3 = Color3.fromRGB(255, 70, 20)
	relleno.BorderSizePixel = 0
	relleno.Parent = fondo

	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.fromScale(1, 1)
	titulo.BackgroundTransparency = 1
	titulo.Text = "☠  EL SEÑOR DE LAS LLAMAS  ☠"
	titulo.Font = Enum.Font.GothamBold
	titulo.TextColor3 = Color3.new(1, 1, 1)
	titulo.TextScaled = true
	titulo.Parent = fondo

	vida.Changed:Connect(function(v)
		relleno.Size = UDim2.fromScale(math.clamp(v / CONFIG.VIDA_MAX, 0, 1), 1)
	end)
end
crearBarraDeVida()

-- Daño al jefe: cualquier parte que toque al demonio y tenga el atributo
-- "DanoArma" (lo pones en espadas/proyectiles del jugador) le resta vida.
-- Con cooldown por arma para que no se drene de un solo toque continuo.
local ultimoGolpe: { [Instance]: number } = {}
local function recibirGolpe(hit: BasePart)
	local dano = hit:GetAttribute("DanoArma")
	if typeof(dano) ~= "number" or vida.Value <= 0 then return end
	local ahora = os.clock()
	if ultimoGolpe[hit] and (ahora - ultimoGolpe[hit] < CONFIG.COOLDOWN_GOLPE) then return end
	ultimoGolpe[hit] = ahora
	vida.Value = math.max(0, vida.Value - dano)
end

for _, parte in demonio:GetDescendants() do
	if parte:IsA("BasePart") then
		parte.Touched:Connect(recibirGolpe)
	end
end

-- ---------- ZONA / OBJETIVO ------------------------------------------
local function dentroDe(parte: BasePart, pos: Vector3): boolean
	local l = parte.CFrame:PointToObjectSpace(pos)
	local h = parte.Size / 2
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end

local function objetivoEnCiudad(): BasePart?
	local mejor: BasePart? = nil
	local mejorDist = math.huge
	for _, jugador in Players:GetPlayers() do
		local pj = jugador.Character
		local hum = pj and pj:FindFirstChildOfClass("Humanoid")
		local hrp = pj and pj:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and hrp and hum.Health > 0 and dentroDe(zona, hrp.Position) then
			local d = (hrp.Position - raiz.Position).Magnitude
			if d < mejorDist then mejorDist, mejor = d, hrp end
		end
	end
	return mejor
end

local function mirarHacia(pos: Vector3, dt: number)
	local plano = Vector3.new(pos.X, raiz.Position.Y, pos.Z)
	local deseado = CFrame.lookAt(raiz.Position, plano)
	raiz.CFrame = raiz.CFrame:Lerp(deseado, math.clamp(CONFIG.GIRO_SUAVE * dt, 0, 1))
end

-- ---------- ELECCIÓN DE PODERES POR FASE -----------------------------
local function faseActual(): (number, number)
	local f = vida.Value / CONFIG.VIDA_MAX
	if f > 0.66 then return 1, CONFIG.ESPERA_FASE1 end
	if f > 0.33 then return 2, CONFIG.ESPERA_FASE2 end
	return 3, CONFIG.ESPERA_FASE3
end

local function lanzarPoder(fase: number, objetivo: BasePart)
	-- Cada fase abre ataques nuevos y más brutales.
	local opciones
	if fase == 1 then
		opciones = { "bolas", "rayo", "nova" }
	elseif fase == 2 then
		opciones = { "bolas", "rayo", "nova", "meteoros", "pilares" }
	else
		opciones = { "meteoros", "pilares", "lava", "nova", "rayo", "colosal" }
	end
	local elegido = opciones[math.random(1, #opciones)]

	if elegido == "bolas" then
		Poderes.bolasInfernales(5 + fase, 22)
	elseif elegido == "rayo" then
		Poderes.rayoOcular(objetivo, 2.5, 25 + fase * 5)
	elseif elegido == "nova" then
		Poderes.novaDeFuego(45 + fase * 8, 40 + fase * 5)
	elseif elegido == "meteoros" then
		Poderes.lluviaDeMeteoros(6 + fase * 2, 28, 14)
	elseif elegido == "pilares" then
		Poderes.pilaresDeFuego(35, 10)
	elseif elegido == "lava" then
		Poderes.erupcionDeLava(16, 28)
	elseif elegido == "colosal" then
		Poderes.meteoroColosal(90, 45)
	end
	return elegido
end

-- ---------- MUERTE DEL JEFE ------------------------------------------
local muerto = false
local function morir()
	muerto = true
	Sonidos.detenerMusica()
	Sonidos.reproducir("muerte", raiz)
	print("[SeñorLlamas] ¡El Señor de las Llamas ha sido derrotado!")
	-- Explosión final espectacular
	Poderes.novaDeFuego(90, 0)
	Poderes.erupcionDeLava(24, 0)
	local exp = Instance.new("Explosion")
	exp.Position = raiz.Position
	exp.BlastRadius = 60
	exp.BlastPressure = 0
	exp.Parent = Workspace
	task.wait(0.4)
	-- Se desvanece
	for _, p in demonio:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			game:GetService("TweenService"):Create(
				p, TweenInfo.new(1.5), { Transparency = 1 }
			):Play()
		end
	end
end

-- ---------- BUCLE PRINCIPAL ------------------------------------------
local activo = false
local ultimaFase = 1
task.spawn(function()
	while not muerto do
		local objetivo = objetivoEnCiudad()
		if objetivo and vida.Value > 0 then
			if not activo then
				activo = true
				print("[SeñorLlamas] ¡Un intruso entró! El demonio despierta. 🔥")
				Sonidos.reproducir("despertar", raiz)
				Sonidos.iniciarMusica()
			end
			-- Si el jugador está cerca -> ZARPAZO (rango de golpes).
			-- Si está lejos -> poder a distancia según la fase.
			local espera
			local dist = (objetivo.Position - raiz.Position).Magnitude
			if dist <= CONFIG.RANGO_MELEE then
				Poderes.zarpazo(CONFIG.DANO_MELEE, CONFIG.RANGO_MELEE, 120)
				espera = CONFIG.ESPERA_MELEE
			else
				local fase, e = faseActual()
				if fase ~= ultimaFase then
					ultimaFase = fase
					Sonidos.reproducir("fase", raiz)
				end
				lanzarPoder(fase, objetivo)
				espera = e
			end
			-- durante la espera, lo mantenemos mirando al objetivo
			local t = 0
			while t < espera and not muerto do
				local dt = RunService.Heartbeat:Wait()
				t += dt
				local o = objetivoEnCiudad()
				if o then mirarHacia(o.Position, dt) end
			end
		else
			if activo then
				activo = false
				print("[SeñorLlamas] La ciudad quedó vacía. El demonio duerme.")
				Sonidos.detenerMusica()
			end
			task.wait(0.4)
		end

		if vida.Value <= 0 and not muerto then
			morir()
		end
	end
end)

print("[SeñorLlamas] Jefe cargado. Vida: " .. CONFIG.VIDA_MAX .. ". Esperando intrusos...")
