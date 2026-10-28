-- =====================================================================
--  ESTILO DE LOS JUGADORES: hombreras, capa rasgada y halo de brasas
--  (mallas hechas en Blender, en ServerStorage > EstiloJugador)
--  + brasas en las manos y luz tenue. Va en ServerScriptService.
-- =====================================================================
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local carpeta = ServerStorage:WaitForChild("EstiloJugador")
local GIRO = (carpeta:GetAttribute("GiroFrente") or 0) :: number

local function pegar(pj: Model, nombre: string, parteNombres: { string }, offset: (BasePart) -> CFrame)
	local plantilla = carpeta:FindFirstChild(nombre)
	local parte: BasePart? = nil
	for _, n in parteNombres do
		local p = pj:FindFirstChild(n)
		if p and p:IsA("BasePart") then parte = p break end
	end
	if not (plantilla and plantilla:IsA("BasePart") and parte) then return end
	local m = (plantilla :: BasePart):Clone()
	m.Name = "Estilo_" .. nombre
	m.Anchored = false
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Massless = true
	m:PivotTo((parte :: BasePart).CFrame * offset(parte :: BasePart) * CFrame.Angles(0, GIRO, 0))
	local w = Instance.new("WeldConstraint")
	w.Part0 = parte
	w.Part1 = m
	w.Parent = m
	m.Parent = pj
end

local function brasas(padre: Instance)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Brasas"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(220, 50, 10))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.25, 0)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Rate = 12
	e.Speed = NumberRange.new(1, 3)
	e.Acceleration = Vector3.new(0, 4, 0)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Parent = padre
end

local function vestir(pj: Model)
	local hum = pj:WaitForChild("Humanoid", 10)
	if not hum then return end
	for _, v in pj:GetChildren() do
		if v.Name:sub(1, 7) == "Estilo_" then v:Destroy() end
	end
	pegar(pj, "JUG_Hombreras", { "UpperTorso", "Torso" }, function(p)
		return CFrame.new(0, p.Size.Y / 2 - 0.15, 0.5)
	end)
	pegar(pj, "JUG_Capa", { "UpperTorso", "Torso" }, function(p)
		return CFrame.new(0, p.Size.Y / 2 - 0.05, 0)
	end)
	pegar(pj, "JUG_Halo", { "Head" }, function(p)
		return CFrame.new(0, p.Size.Y / 2 + 0.75, 0.45)
	end)
	for _, n in { "RightHand", "LeftHand", "Right Arm", "Left Arm" } do
		local m = pj:FindFirstChild(n)
		if m then brasas(m) end
	end
	local torso = pj:FindFirstChild("UpperTorso") or pj:FindFirstChild("Torso")
	if torso then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 120, 40)
		l.Brightness = 0.8
		l.Range = 8
		l.Parent = torso
	end
end

local function alAparecer(jugador: Player)
	jugador.CharacterAppearanceLoaded:Connect(vestir)
	if jugador.Character and jugador:HasAppearanceLoaded() then
		vestir(jugador.Character)
	end
end
Players.PlayerAdded:Connect(alAparecer)
for _, p in Players:GetPlayers() do alAparecer(p) end
