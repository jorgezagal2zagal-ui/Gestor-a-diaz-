-- =====================================================================
--  CONTROL DE PODERES DEL JUGADOR (LocalScript en StarterPlayerScripts)
--  Teclas Q / E / R / F o los botones de la pantalla (sirven en celular).
--  Apunta a donde está el mouse (en celular: al centro de la pantalla).
-- =====================================================================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local jugador = Players.LocalPlayer
local evento = RS:WaitForChild("PoderJugador") :: RemoteEvent

local LISTA = {
	{ id = "orbe", tecla = Enum.KeyCode.Q, letra = "Q", nombre = "Orbe", cd = 1.2, color = Color3.fromRGB(255, 214, 120) },
	{ id = "escudo", tecla = Enum.KeyCode.E, letra = "E", nombre = "Escudo", cd = 12, color = Color3.fromRGB(255, 160, 70) },
	{ id = "tajo", tecla = Enum.KeyCode.R, letra = "R", nombre = "Tajo", cd = 5, color = Color3.fromRGB(255, 120, 50) },
	{ id = "estrella", tecla = Enum.KeyCode.F, letra = "F", nombre = "Estrella", cd = 25, color = Color3.fromRGB(255, 240, 180) },
}

-- ---------- interfaz ---------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PoderesUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = jugador:WaitForChild("PlayerGui")

local barra = Instance.new("Frame")
barra.AnchorPoint = Vector2.new(1, 1)
barra.Position = UDim2.new(1, -20, 1, -20)
barra.Size = UDim2.fromOffset(4 * 78, 90)
barra.BackgroundTransparency = 1
barra.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = barra

local listoEn: { [string]: number } = {}
local cubiertas: { [string]: Frame } = {}
local textos: { [string]: TextLabel } = {}

local function boton(p)
	local b = Instance.new("TextButton")
	b.Name = p.id
	b.Size = UDim2.fromOffset(70, 70)
	b.BackgroundColor3 = Color3.fromRGB(25, 10, 8)
	b.BackgroundTransparency = 0.15
	b.AutoButtonColor = true
	b.Text = ""
	b.Parent = barra
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local borde = Instance.new("UIStroke")
	borde.Color = p.color
	borde.Thickness = 2.5
	borde.Parent = b
	local nombre = Instance.new("TextLabel")
	nombre.BackgroundTransparency = 1
	nombre.Size = UDim2.new(1, 0, 0.45, 0)
	nombre.Position = UDim2.fromScale(0, 0.18)
	nombre.Text = p.nombre
	nombre.Font = Enum.Font.GothamBold
	nombre.TextScaled = true
	nombre.TextColor3 = p.color
	nombre.Parent = b
	local letra = Instance.new("TextLabel")
	letra.BackgroundTransparency = 1
	letra.Size = UDim2.new(1, 0, 0.28, 0)
	letra.Position = UDim2.fromScale(0, 0.62)
	letra.Text = p.letra
	letra.Font = Enum.Font.GothamBlack
	letra.TextScaled = true
	letra.TextColor3 = Color3.new(1, 1, 1)
	letra.Parent = b
	local cubierta = Instance.new("Frame")
	cubierta.BackgroundColor3 = Color3.new(0, 0, 0)
	cubierta.BackgroundTransparency = 0.35
	cubierta.AnchorPoint = Vector2.new(0, 1)
	cubierta.Position = UDim2.fromScale(0, 1)
	cubierta.Size = UDim2.fromScale(1, 0)
	cubierta.ZIndex = 3
	cubierta.Parent = b
	Instance.new("UICorner", cubierta).CornerRadius = UDim.new(1, 0)
	local tiempo = Instance.new("TextLabel")
	tiempo.BackgroundTransparency = 1
	tiempo.Size = UDim2.fromScale(1, 1)
	tiempo.ZIndex = 4
	tiempo.Text = ""
	tiempo.Font = Enum.Font.GothamBlack
	tiempo.TextScaled = true
	tiempo.TextColor3 = Color3.new(1, 1, 1)
	tiempo.Parent = b
	cubiertas[p.id] = cubierta
	textos[p.id] = tiempo
	return b
end

-- ---------- apuntar ------------------------------------------------------
local function apuntar(): Vector3
	local cam = workspace.CurrentCamera
	local pos
	if UIS.MouseEnabled then
		pos = UIS:GetMouseLocation()
	else
		pos = cam.ViewportSize / 2
	end
	local rayo = cam:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { jugador.Character }
	local r = workspace:Raycast(rayo.Origin, rayo.Direction * 600, params)
	return r and r.Position or (rayo.Origin + rayo.Direction * 300)
end

-- ---------- usar un poder ---------------------------------------------
local function usar(p)
	local ahora = os.clock()
	if (listoEn[p.id] or 0) > ahora then return end
	local pj = jugador.Character
	local hum = pj and pj:FindFirstChildOfClass("Humanoid")
	local hrp = pj and pj:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (hum and hrp and hum.Health > 0) then return end
	listoEn[p.id] = ahora + p.cd
	local destino = apuntar()
	if p.id == "tajo" then
		-- el dash lo hace el cliente (el personaje es tuyo); el daño lo hace el servidor
		local dir = Vector3.new(destino.X - hrp.Position.X, 0, destino.Z - hrp.Position.Z)
		if dir.Magnitude < 1 then dir = hrp.CFrame.LookVector end
		dir = dir.Unit
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir)
		hrp.AssemblyLinearVelocity = dir * 120 + Vector3.new(0, 12, 0)
	end
	evento:FireServer(p.id, destino)
end

for i, p in LISTA do
	local b = boton(p)
	b.LayoutOrder = i
	b.Activated:Connect(function() usar(p) end)
end

UIS.InputBegan:Connect(function(input, procesado)
	if procesado then return end
	for _, p in LISTA do
		if input.KeyCode == p.tecla then usar(p) end
	end
end)

-- ---------- enfriamientos en pantalla -----------------------------------
game:GetService("RunService").RenderStepped:Connect(function()
	local ahora = os.clock()
	for _, p in LISTA do
		local falta = (listoEn[p.id] or 0) - ahora
		if falta > 0 then
			cubiertas[p.id].Size = UDim2.fromScale(1, falta / p.cd)
			textos[p.id].Text = falta >= 1 and tostring(math.ceil(falta)) or ""
		else
			cubiertas[p.id].Size = UDim2.fromScale(1, 0)
			textos[p.id].Text = ""
		end
	end
end)
