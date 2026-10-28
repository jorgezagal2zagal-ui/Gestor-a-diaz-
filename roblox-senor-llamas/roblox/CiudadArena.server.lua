--!strict
-- =====================================================================
--  CIUDAD ARENA EN LLAMAS  (Roblox / Luau)
-- =====================================================================
--  Construye TODO el escenario de combate directo en Roblox, sin Blender:
--   * suelo de piedra oscura,
--   * anillo de edificios medievales con una PLAZA central (ahí va el jefe),
--   * charcos de LAVA que queman al tocarlos,
--   * fogatas / llamaradas de ambiente,
--   * muralla exterior con una PUERTA de entrada,
--   * un SpawnLocation en la puerta (los jugadores entran por ahí),
--   * la Part "ZonaCiudad" que activa al demonio (la crea automáticamente).
--
--  DÓNDE VA:  pega este Script en  ServerScriptService.
--  Corre UNA vez al iniciar el juego y arma toda la arena.
--
--  Coloca tu Model "SenorLlamas" en el CENTRO (0, altura, 0).
-- =====================================================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- ---------- CONFIGURACIÓN --------------------------------------------
local CONFIG = {
	RADIO_PLAZA   = 60,    -- radio del claro central (donde pelean)
	RADIO_CIUDAD  = 170,   -- hasta dónde llegan los edificios
	ALTO_MURO     = 40,    -- altura de la muralla exterior
	ANCHO_PUERTA  = 40,    -- hueco de la puerta de entrada
	DANO_LAVA     = 12,    -- daño por segundo al pisar lava
}
-- --------------------------------------------------------------------

local NARANJA = Color3.fromRGB(255, 120, 20)
local ROJO    = Color3.fromRGB(190, 35, 12)
local PIEDRA  = Color3.fromRGB(28, 24, 22)
local TEJADO  = Color3.fromRGB(45, 18, 12)

-- Contenedor para no ensuciar el Workspace
local arena = Instance.new("Folder")
arena.Name = "CiudadArena"
arena.Parent = Workspace

local function parte(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = arena
	return p
end

local function emisorFuego(host: BasePart, tamano: number, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxassetid://243660364"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), ROJO)
	e.LightEmission = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tamano),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.5, 1.0)
	e.Rate = rate
	e.Speed = NumberRange.new(5, 12)
	e.Acceleration = Vector3.new(0, 18, 0)
	e.Parent = host
end

-- ---------- SUELO ----------------------------------------------------
parte({
	Name = "Suelo",
	Size = Vector3.new(CONFIG.RADIO_CIUDAD * 2 + 80, 2, CONFIG.RADIO_CIUDAD * 2 + 80),
	Position = Vector3.new(0, -1, 0),
	Material = Enum.Material.Slate,
	Color = PIEDRA,
})

-- ---------- EDIFICIOS (anillo con plaza central) ---------------------
local function edificio(x: number, z: number, mirarAlCentro: CFrame)
	local alto = math.random(14, 42)
	local ancho = math.random(10, 20)
	local fondo = math.random(10, 20)

	-- muros
	local m = parte({
		Name = "Edificio",
		Size = Vector3.new(ancho, alto, fondo),
		CFrame = CFrame.new(x, alto / 2, z),
		Material = Enum.Material.Brick,
		Color = PIEDRA,
	})
	-- tejado (prisma)
	parte({
		Name = "Tejado",
		Size = Vector3.new(ancho + 1, ancho * 0.6, fondo + 1),
		CFrame = CFrame.new(x, alto + ancho * 0.25, z),
		Material = Enum.Material.Slate,
		Color = TEJADO,
	})
	-- algunas ventanas con brillo de incendio adentro
	if math.random() < 0.6 then
		parte({
			Name = "Ventana",
			Size = Vector3.new(2.5, 3, 0.4),
			CFrame = m.CFrame * CFrame.new(0, math.random(-2, 6), -fondo / 2 - 0.1),
			Material = Enum.Material.Neon,
			Color = NARANJA,
		})
	end
end

local filas = 0
local radio = CONFIG.RADIO_PLAZA + 18
while radio < CONFIG.RADIO_CIUDAD do
	local circunf = 2 * math.pi * radio
	local cuantos = math.max(6, math.floor(circunf / 28))
	for i = 1, cuantos do
		local ang = (i / cuantos) * math.pi * 2 + filas * 0.3
		-- deja un hueco para la puerta (hacia +X)
		if math.abs(math.cos(ang)) > 0.86 and math.sin(ang) > -0.2 and math.sin(ang) < 0.2 and math.cos(ang) > 0 then
			continue
		end
		local x = math.cos(ang) * (radio + math.random(-6, 6))
		local z = math.sin(ang) * (radio + math.random(-6, 6))
		edificio(x, z, CFrame.lookAt(Vector3.new(x, 0, z), Vector3.zero))
	end
	radio += math.random(26, 34)
	filas += 1
end

-- ---------- LAVA (charcos que queman) --------------------------------
local lavas: { BasePart } = {}
for _ = 1, 30 do
	local ang = math.random() * math.pi * 2
	local dist = math.random(CONFIG.RADIO_PLAZA - 15, CONFIG.RADIO_CIUDAD - 10)
	local x, z = math.cos(ang) * dist, math.sin(ang) * dist
	local lava = parte({
		Name = "Lava",
		Size = Vector3.new(math.random(10, 28), 1, math.random(10, 28)),
		Position = Vector3.new(x, 0.1, z),
		Material = Enum.Material.CrackedLava,
		Color = Color3.fromRGB(255, 70, 10),
		CanCollide = false,
	})
	table.insert(lavas, lava)
end

-- Daño por pisar lava (con pequeño enfriamiento por jugador)
local ultimoDano: { [Humanoid]: number } = {}
for _, lava in lavas do
	lava.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local ahora = os.clock()
			if (ultimoDano[hum] == nil) or (ahora - ultimoDano[hum] >= 0.5) then
				ultimoDano[hum] = ahora
				hum:TakeDamage(CONFIG.DANO_LAVA * 0.5)
			end
		end
	end)
end

-- ---------- FOGATAS / LLAMARADAS DE AMBIENTE -------------------------
for _ = 1, 45 do
	local ang = math.random() * math.pi * 2
	local dist = math.random(CONFIG.RADIO_PLAZA, CONFIG.RADIO_CIUDAD)
	local x, z = math.cos(ang) * dist, math.sin(ang) * dist
	local foco = parte({
		Name = "Fogata",
		Size = Vector3.new(2, 2, 2),
		Position = Vector3.new(x, 1, z),
		Transparency = 1,
		CanCollide = false,
	})
	emisorFuego(foco, math.random(3, 7), math.random(25, 55))
	local luz = Instance.new("PointLight")
	luz.Color = NARANJA
	luz.Brightness = 4
	luz.Range = 22
	luz.Parent = foco
end

-- ---------- MURALLA EXTERIOR CON PUERTA ------------------------------
local Rmuro = CONFIG.RADIO_CIUDAD + 20
local segmentos = 64
for i = 1, segmentos do
	local ang = (i / segmentos) * math.pi * 2
	-- hueco de la puerta hacia +X
	local x, z = math.cos(ang) * Rmuro, math.sin(ang) * Rmuro
	if math.abs(z) < CONFIG.ANCHO_PUERTA / 2 and x > 0 then
		continue
	end
	parte({
		Name = "Muro",
		Size = Vector3.new(2 * math.pi * Rmuro / segmentos + 2, CONFIG.ALTO_MURO, 6),
		CFrame = CFrame.lookAt(Vector3.new(x, CONFIG.ALTO_MURO / 2, z), Vector3.zero),
		Material = Enum.Material.Slate,
		Color = PIEDRA,
	})
end
-- Torres a los lados de la puerta
for _, signo in { -1, 1 } do
	parte({
		Name = "TorrePuerta",
		Size = Vector3.new(10, CONFIG.ALTO_MURO + 14, 10),
		CFrame = CFrame.new(Rmuro, (CONFIG.ALTO_MURO + 14) / 2, signo * (CONFIG.ANCHO_PUERTA / 2 + 6)),
		Material = Enum.Material.Slate,
		Color = PIEDRA,
	})
end

-- ---------- SPAWN DE JUGADORES (en la puerta) ------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "EntradaCiudad"
spawn.Size = Vector3.new(16, 1, 16)
spawn.Position = Vector3.new(Rmuro + 18, 1, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.Material = Enum.Material.Cobblestone
spawn.Color = Color3.fromRGB(60, 50, 45)
spawn.Parent = arena

-- ---------- ZONA QUE ACTIVA AL DEMONIO -------------------------------
-- (la misma Part que busca DemonLordAI; se crea aquí automáticamente)
local zona = Instance.new("Part")
zona.Name = "ZonaCiudad"
zona.Anchored = true
zona.CanCollide = false
zona.CanQuery = false
zona.Transparency = 1
zona.Size = Vector3.new(CONFIG.RADIO_CIUDAD * 2, 80, CONFIG.RADIO_CIUDAD * 2)
zona.Position = Vector3.new(0, 40, 0)
zona.Parent = Workspace   -- en Workspace para que el AI la encuentre con WaitForChild

print(("[CiudadArena] Arena construida. Puerta en X=%d. Coloca 'SenorLlamas' en el centro.")
	:format(math.floor(spawn.Position.X)))
