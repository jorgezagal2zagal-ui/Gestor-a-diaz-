-- =====================================================================
--  INSTALADOR: animaciones + vuelo del arcángel y poderes (jefe y jugador)
--  Pegar/cargar en la Barra de Comandos con el lugar abierto (modo edición).
--  Requiere: SenorLlamas ya armado y Poderes_Extra.fbx importado.
-- =====================================================================
local WS = workspace
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local demonio = WS:FindFirstChild("SenorLlamas")
assert(demonio, "No encuentro SenorLlamas")
local hrp = demonio.PrimaryPart
assert(hrp, "SenorLlamas sin PrimaryPart")

local function soldadura(nombre)
	return hrp:FindFirstChild("Soldadura_" .. nombre)
end

-- 1) La roca y las nubes se quedan en el piso (el jefe va a volar)
local altar = WS:FindFirstChild("AltarJefe") or Instance.new("Folder")
altar.Name = "AltarJefe"
altar.Parent = WS
for _, n in { "BaseRoca", "NubesFuego" } do
	local p = demonio:FindFirstChild(n)
	if p then
		local w = soldadura(n)
		if w then w:Destroy() end
		p.Anchored = true
		p.Parent = altar
	end
end

-- 2) Soldaduras -> articulaciones Motor6D con pivote en cada coyuntura
--    (coordenadas de Blender: X lado, Y adelante(-)/atrás(+), Z alto)
local ala = demonio:FindFirstChild("AlaIzq")
local sx = (hrp.CFrame:PointToObjectSpace(ala.Position).X < 0) and -1 or 1
local ojos = demonio:FindFirstChild("Ojos")
local sz = (hrp.CFrame:PointToObjectSpace(ojos.Position).Z < 0) and 1 or -1
local function B(bx, by, bz)
	return hrp.CFrame * CFrame.new(sx * bx, bz - 46, sz * by)
end
local ARTIC = {
	{ "Cuerpo", "HumanoidRootPart", 0, 0.2, 40 },
	{ "Tunica", "Cuerpo", 0, 0.4, 42 },
	{ "Cabeza", "Cuerpo", 0, 0.3, 58.5 },
	{ "Ojos", "Cabeza", 0, 0.3, 58.5 },
	{ "Halo", "Cabeza", 0, 0.3, 58.5 },
	{ "BrazoIzq", "Cuerpo", 8.6, 0.6, 54.6 },
	{ "BrazoDer", "Cuerpo", -8.6, 0.6, 54.6 },
	{ "Espada", "BrazoIzq", 8.6, 0.6, 54.6 },
	{ "ManoDerecha", "BrazoDer", -8.6, 0.6, 54.6 },
	{ "AlaIzq", "Cuerpo", 3.2, 3.6, 53.5 },
	{ "AlaDer", "Cuerpo", -3.2, 3.6, 53.5 },
}
for _, a in ARTIC do
	local nombre, padreN, bx, by, bz = a[1], a[2], a[3], a[4], a[5]
	local parte = demonio:FindFirstChild(nombre)
	local padre = demonio:FindFirstChild(padreN)
	if parte and padre then
		for _, d in demonio:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == "Art_" .. nombre then d:Destroy() end
		end
		local w = soldadura(nombre)
		if w then w:Destroy() end
		parte.Anchored = false
		parte.Massless = true
		local piv = B(bx, by, bz)
		local m = Instance.new("Motor6D")
		m.Name = "Art_" .. nombre
		m.Part0 = padre
		m.Part1 = parte
		m.C0 = padre.CFrame:ToObjectSpace(piv)
		m.C1 = parte.CFrame:ToObjectSpace(piv)
		m.Parent = padre
	else
		warn("[Instalar] falta pieza " .. tostring(nombre) .. " o " .. tostring(padreN))
	end
end

-- 3) Mallas nuevas de Blender: FX_* del jefe y JUG_* del jugador
local extra = WS:FindFirstChild("Poderes_Extra")
local fxJefe = RS:FindFirstChild("FX_Poderes")
local fxJug = RS:FindFirstChild("FX_Jugador") or Instance.new("Model")
fxJug.Name = "FX_Jugador"
fxJug.Parent = RS
if extra then
	for _, p in extra:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			local destino = (p.Name:sub(1, 4) == "JUG_") and fxJug or fxJefe
			local viejo = destino and destino:FindFirstChild(p.Name)
			if viejo then viejo:Destroy() end
			p.Parent = destino or fxJug
		end
	end
	extra:Destroy()
else
	warn("[Instalar] no encontré Poderes_Extra (importa Poderes_Extra.fbx)")
end

-- 4) RemoteEvent de poderes del jugador
if not RS:FindFirstChild("PoderJugador") then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "PoderJugador"
	ev.Parent = RS
end

-- 5) Scripts
local function poner(padre, clase, nombre, fuente)
	local v = padre:FindFirstChild(nombre)
	if v then v:Destroy() end
	local s = Instance.new(clase)
	s.Name = nombre
	s.Source = fuente
	s.Parent = padre
end
poner(SSS, "Script", "VueloJefe", [==[__VUELO__]==])
poner(SSS, "Script", "PoderesJugador", [==[__PJ_SERVER__]==])
poner(SPS, "LocalScript", "AnimacionesJefe", [==[__ANIM__]==])
poner(SPS, "LocalScript", "ControlPoderes", [==[__PJ_CLIENT__]==])

local function actualizar(inst, largoAnterior, fuente)
	if not inst then warn("[Instalar] no encontré script para actualizar") return end
	if #inst.Source ~= largoAnterior and inst.Source ~= fuente then
		local r = inst:Clone()
		r.Name = inst.Name .. "_Respaldo"
		pcall(function() r.Enabled = false end)
		r.Parent = SS
		warn("[Instalar] " .. inst.Name .. " tenía cambios tuyos: respaldo en ServerStorage")
	end
	inst.Source = fuente
end
actualizar(RS:FindFirstChild("Poderes"), __LEN_PODERES__, [==[__PODERES__]==])
actualizar(SSS:FindFirstChild("DemonLordAI"), __LEN_AI__, [==[__AI__]==])

print("[Instalar] LISTO: articulaciones, vuelo, animaciones y poderes instalados")
