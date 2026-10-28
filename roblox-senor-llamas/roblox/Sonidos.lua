--!strict
-- =====================================================================
--  SONIDOS DEL SEÑOR DE LAS LLAMAS  (ModuleScript / Luau)
-- =====================================================================
--  DÓNDE VA:  ReplicatedStorage > ModuleScript llamado "Sonidos"
--
--  CÓMO PONER LOS SONIDOS:
--   1. En Studio abre View > Toolbox > pestaña "Audio" y busca (ej. "roar",
--      "explosion", "fire whoosh", "epic boss music").
--   2. Clic derecho al audio > "Copy Asset ID".
--   3. Pega el número abajo, entre las comillas: "rbxassetid://123456".
--  Los que dejes vacíos ("") simplemente no suenan (no da error).
-- =====================================================================

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Sonidos = {}

-- ---------- PEGA AQUÍ TUS IDs ----------------------------------------
local IDS: { [string]: string } = {
	despertar = "",   -- rugido al despertar
	musica    = "",   -- música épica de jefe (se repite)
	zarpazo   = "",   -- tajo de garra
	nova      = "",   -- onda expansiva
	rayo      = "",   -- láser ocular
	bolas     = "",   -- bolas de fuego
	meteoro   = "",   -- meteoros cayendo
	pilares   = "",   -- pilares de fuego
	lava      = "",   -- erupción de lava
	colosal   = "",   -- meteoro colosal
	fase      = "",   -- rugido al cambiar de fase
	muerte    = "",   -- muerte del jefe
}

local VOLUMEN: { [string]: number } = {
	musica = 0.5,
}
-- --------------------------------------------------------------------

local musicaActual: Sound? = nil

-- Reproduce un sonido una vez, en la posición de 'donde' (o en el Workspace).
function Sonidos.reproducir(nombre: string, donde: Instance?)
	local id = IDS[nombre]
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = VOLUMEN[nombre] or 1
	s.RollOffMaxDistance = 400
	s.Parent = donde or Workspace
	s:Play()
	Debris:AddItem(s, 10)
end

-- Música de jefe en bucle (para todos los jugadores).
function Sonidos.iniciarMusica()
	local id = IDS.musica
	if musicaActual or not id or id == "" then return end
	local s = Instance.new("Sound")
	s.Name = "MusicaJefe"
	s.SoundId = id
	s.Volume = VOLUMEN.musica or 0.5
	s.Looped = true
	s.Parent = Workspace
	s:Play()
	musicaActual = s
end

function Sonidos.detenerMusica()
	if musicaActual then
		musicaActual:Destroy()
		musicaActual = nil
	end
end

return Sonidos
