--!strict
-- =====================================================================
--  ESPADA INFERNAL  -  Arma del jugador para pelear al jefe (Luau)
-- =====================================================================
--  Crea una espada y se la da a CADA jugador al entrar. La espada tiene
--  el atributo "DanoArma", así que al golpear al "SenorLlamas" le baja la
--  vida (el jefe ya tiene cooldown por arma para que sea justo).
--
--  DÓNDE VA:  pega este Script en  ServerScriptService.
--
--  Cómo pelear: equipa la espada (tecla 1) y golpea al demonio acercándote.
-- =====================================================================

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

-- ---------- CONFIGURACIÓN --------------------------------------------
local DANO_ESPADA = 60      -- daño por golpe al jefe
-- --------------------------------------------------------------------

local function crearEspada(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Espada Infernal"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local hoja = Instance.new("Part")
	hoja.Name = "Handle"
	hoja.Size = Vector3.new(0.6, 6, 0.3)
	hoja.Material = Enum.Material.Neon
	hoja.Color = Color3.fromRGB(255, 110, 20)
	hoja.CanCollide = false
	hoja:SetAttribute("DanoArma", DANO_ESPADA)   -- <- esto le hace daño al jefe

	-- resplandor de la hoja
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 120, 30)
	luz.Brightness = 3
	luz.Range = 10
	luz.Parent = hoja

	-- fuego en la hoja
	local fuego = Instance.new("ParticleEmitter")
	fuego.Texture = "rbxassetid://243660364"
	fuego.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(200, 30, 10))
	fuego.LightEmission = 1
	fuego.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	fuego.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	fuego.Lifetime = NumberRange.new(0.3, 0.6)
	fuego.Rate = 40
	fuego.Speed = NumberRange.new(2, 5)
	fuego.Parent = hoja

	hoja.Parent = tool

	-- empuñadura
	local mango = Instance.new("Part")
	mango.Name = "Mango"
	mango.Size = Vector3.new(0.5, 1.6, 0.5)
	mango.Material = Enum.Material.Metal
	mango.Color = Color3.fromRGB(40, 30, 25)
	mango.CanCollide = false
	local soldar = Instance.new("WeldConstraint")
	soldar.Part0 = hoja
	soldar.Part1 = mango
	mango.CFrame = hoja.CFrame * CFrame.new(0, -3.5, 0)
	mango.Parent = tool
	soldar.Parent = tool

	return tool
end

-- La espada base vive en StarterPack: todos la reciben al aparecer.
crearEspada().Parent = StarterPack

-- Y a quien ya esté jugando, se la damos de una.
for _, jugador in Players:GetPlayers() do
	local mochila = jugador:FindFirstChildOfClass("Backpack")
	if mochila then
		crearEspada().Parent = mochila
	end
end

print("[EspadaInfernal] Espada entregada. ¡A pelear contra el Señor de las Llamas! ⚔️🔥")
