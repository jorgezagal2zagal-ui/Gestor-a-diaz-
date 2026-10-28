-- =====================================================================
--  VUELO DEL ARCÁNGEL (Script en ServerScriptService)
--  Despierto: despega de su roca, flota con bamboleo y cada tanto se
--  lanza en picada a otro punto de la plaza. Baja un momento para los
--  golpes al suelo. Dormido o muerto: regresa y aterriza en su roca.
--  Solo mueve la POSICIÓN de la raíz; el giro lo sigue haciendo DemonLordAI.
-- =====================================================================
local RunService = game:GetService("RunService")
local demonio = workspace:WaitForChild("SenorLlamas")
local raiz: BasePart = demonio.PrimaryPart or demonio:WaitForChild("HumanoidRootPart")

local CONFIG = {
	ALTURA = 16,          -- altura de vuelo sobre su posición en tierra (studs)
	BAMBOLEO = 2.2,       -- sube y baja mientras flota
	RADIO = 30,           -- qué tanto se aleja del centro de la plaza
	CADA_MIN = 7,         -- segundos entre picadas
	CADA_MAX = 12,
	DURACION_PICADA = 2.4,
	ALTURA_GOLPE = 4,     -- baja a esta altura para golpes cuerpo a cuerpo / al suelo
}

local CENTRO = Vector3.new(raiz.Position.X, 0, raiz.Position.Z)
local Y_TIERRA = raiz.Position.Y
local h = 0
local xz = CENTRO
local desde, hacia, tPicada, durPicada = CENTRO, CENTRO, 0, 0
local siguiente = os.clock() + CONFIG.CADA_MIN
local bajarHasta = 0
local t = 0

local GOLPES = { melee = 1.1, nova = 1.3, pilares = 1.2, lava = 1.2 }
demonio:GetAttributeChangedSignal("AtaqueN"):Connect(function()
	local dur = GOLPES[demonio:GetAttribute("Ataque") or ""]
	if dur then bajarHasta = os.clock() + dur end
end)

local function irA(p: Vector3, dur: number)
	desde, hacia, tPicada, durPicada = xz, p, 0, dur
end

RunService.Heartbeat:Connect(function(dt)
	t += dt
	local muerto = demonio:GetAttribute("Muerto") == true
	local despierto = demonio:GetAttribute("Despierto") == true and not muerto

	-- altura objetivo
	local hObj = 0
	if despierto then
		hObj = (os.clock() < bajarHasta) and CONFIG.ALTURA_GOLPE or CONFIG.ALTURA
	end
	local vel = muerto and 0.6 or ((os.clock() < bajarHasta) and 4 or 1.2)
	h += (hObj - h) * math.clamp(dt * vel, 0, 1)

	-- picadas por la plaza
	if despierto then
		if os.clock() >= siguiente then
			local ang = math.random() * math.pi * 2
			local r = math.random() * CONFIG.RADIO
			irA(CENTRO + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r), CONFIG.DURACION_PICADA)
			siguiente = os.clock() + CONFIG.CADA_MIN + math.random() * (CONFIG.CADA_MAX - CONFIG.CADA_MIN)
		end
	elseif (hacia - CENTRO).Magnitude > 0.5 or (xz - CENTRO).Magnitude > 0.5 then
		if hacia ~= CENTRO then irA(CENTRO, 3) end
	end
	if durPicada > 0 then
		tPicada = math.min(tPicada + dt, durPicada)
		local f = tPicada / durPicada
		f = f * f * (3 - 2 * f)
		xz = desde:Lerp(hacia, f)
	end

	local bam = math.sin(t * 1.6) * CONFIG.BAMBOLEO * math.clamp(h / CONFIG.ALTURA, 0, 1)
	local pos = Vector3.new(xz.X, Y_TIERRA + h + bam, xz.Z)
	raiz.CFrame = CFrame.new(pos) * raiz.CFrame.Rotation

	local volando = h > 3
	if demonio:GetAttribute("Volando") ~= volando then
		demonio:SetAttribute("Volando", volando)
	end
end)
