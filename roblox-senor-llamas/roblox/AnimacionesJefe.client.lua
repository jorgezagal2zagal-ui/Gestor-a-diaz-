-- =====================================================================
--  ANIMACIONES DEL ARCÁNGEL (LocalScript en StarterPlayerScripts)
--  Mueve las articulaciones Motor6D "Art_<pieza>" del modelo SenorLlamas
--  según los atributos que pone el servidor:
--    Despierto (bool)  Volando (bool)  Muerto (bool)
--    Ataque (string) + AtaqueN (contador: cambia en cada ataque)
--  Corre en el cliente para que se vea suave (sin lag de red).
-- =====================================================================
local RunService = game:GetService("RunService")
local demonio = workspace:WaitForChild("SenorLlamas")

local NOMBRES = { "Cuerpo", "Tunica", "Cabeza", "BrazoIzq", "BrazoDer", "AlaIzq", "AlaDer" }
local M: { [string]: Motor6D } = {}
local t0 = os.clock()
while os.clock() - t0 < 15 do
	for _, n in NOMBRES do
		if not M[n] then
			for _, d in demonio:GetDescendants() do
				if d:IsA("Motor6D") and d.Name == "Art_" .. n then
					M[n] = d
				end
			end
		end
	end
	local faltan = 0
	for _, n in NOMBRES do if not M[n] then faltan += 1 end end
	if faltan == 0 then break end
	task.wait(0.5)
end

-- Ejes (marco de la raíz): X = derecha, Y = arriba, Z = atrás.
--  Brazo izq: subir de lado = -Z ; brazo der: subir de lado = +Z ; adelante = +X
--  Cabeza: mirar arriba = +X ; Cuerpo: inclinarse adelante = -X
--  Ala izq: bajar = +Z ; ala der: bajar = -Z ; plegar hacia atrás = +Y (izq) / -Y (der)
local function P(t: { [string]: { number } }): { [string]: Vector3 }
	local r = {}
	for k, v in t do r[k] = Vector3.new(v[1], v[2], v[3]) end
	return r
end
local CERO = Vector3.zero

local POSE_DORMIDO = P({
	Cuerpo = { -0.12, 0, 0 }, Cabeza = { -0.45, 0, 0 },
	BrazoIzq = { 0.1, 0, 0.25 }, BrazoDer = { 0.1, 0, -0.25 },
	AlaIzq = { 0, 0.45, 0.45 }, AlaDer = { 0, -0.45, -0.45 },
})
local POSE_DESPIERTO = P({})
local POSE_VUELO = P({ Cuerpo = { -0.1, 0, 0 }, BrazoIzq = { -0.15, 0, -0.1 }, BrazoDer = { -0.15, 0, 0.1 }, Tunica = { 0.15, 0, 0 } })
local POSE_MUERTO = P({
	Cuerpo = { 0.35, 0, 0.12 }, Cabeza = { -0.7, 0.2, 0 },
	BrazoIzq = { -0.2, 0, 0.55 }, BrazoDer = { -0.2, 0, -0.55 },
	AlaIzq = { 0, 0.3, 0.8 }, AlaDer = { 0, -0.3, -0.8 }, Tunica = { 0.2, 0, 0 },
})

-- Ataques: lista de cuadros {tiempo, pose}. Se suman a la pose base.
local ATAQUES: { [string]: { any } } = {
	despertar = { -- rugido
		{ 0, P({}) },
		{ 0.5, P({ Cabeza = { 0.5, 0, 0 }, Cuerpo = { 0.15, 0, 0 }, BrazoIzq = { 0.2, 0, -0.7 }, BrazoDer = { 0.2, 0, 0.7 }, AlaIzq = { 0, -0.2, -0.6 }, AlaDer = { 0, 0.2, 0.6 } }) },
		{ 1.4, P({ Cabeza = { 0.55, 0.1, 0 }, Cuerpo = { 0.18, 0, 0 }, BrazoIzq = { 0.2, 0, -0.8 }, BrazoDer = { 0.2, 0, 0.8 }, AlaIzq = { 0, -0.2, -0.7 }, AlaDer = { 0, 0.2, 0.7 } }) },
		{ 2.0, P({}) },
	},
	bolas = { -- lanza con la mano derecha
		{ 0, P({}) },
		{ 0.35, P({ BrazoDer = { 0.5, -0.4, 0.9 }, Cuerpo = { 0, -0.2, 0 }, Cabeza = { 0, -0.15, 0 } }) },
		{ 0.6, P({ BrazoDer = { 1.3, 0.3, 0.3 }, Cuerpo = { -0.12, 0.15, 0 } }) },
		{ 1.2, P({}) },
	},
	rayo = { -- ojos: se inclina y abre alas
		{ 0, P({}) },
		{ 0.3, P({ Cabeza = { -0.2, 0, 0 }, Cuerpo = { -0.15, 0, 0 }, BrazoIzq = { 0.1, 0, -0.45 }, BrazoDer = { 0.1, 0, 0.45 }, AlaIzq = { 0, -0.15, -0.45 }, AlaDer = { 0, 0.15, 0.45 } }) },
		{ 2.4, P({ Cabeza = { -0.15, 0, 0 }, Cuerpo = { -0.15, 0, 0 }, BrazoIzq = { 0.1, 0, -0.45 }, BrazoDer = { 0.1, 0, 0.45 }, AlaIzq = { 0, -0.15, -0.5 }, AlaDer = { 0, 0.15, 0.5 } }) },
		{ 2.8, P({}) },
	},
	nova = { -- brazos arriba y golpe al suelo
		{ 0, P({}) },
		{ 0.45, P({ BrazoIzq = { 0.4, 0, -1.4 }, BrazoDer = { 0.4, 0, 1.4 }, Cabeza = { 0.4, 0, 0 }, Cuerpo = { 0.15, 0, 0 }, AlaIzq = { 0, 0, -0.7 }, AlaDer = { 0, 0, 0.7 } }) },
		{ 0.65, P({ BrazoIzq = { 1.1, 0, -0.2 }, BrazoDer = { 1.1, 0, 0.2 }, Cabeza = { -0.25, 0, 0 }, Cuerpo = { -0.35, 0, 0 }, AlaIzq = { 0, 0, 0.3 }, AlaDer = { 0, 0, -0.3 } }) },
		{ 1.4, P({}) },
	},
	meteoros = { -- invoca: brazos al cielo
		{ 0, P({}) },
		{ 0.5, P({ BrazoIzq = { 0.6, 0, -1.5 }, BrazoDer = { 0.6, 0, 1.5 }, Cabeza = { 0.55, 0, 0 }, Cuerpo = { 0.15, 0, 0 }, AlaIzq = { 0, -0.2, -0.6 }, AlaDer = { 0, 0.2, 0.6 } }) },
		{ 1.8, P({ BrazoIzq = { 0.6, 0, -1.55 }, BrazoDer = { 0.6, 0, 1.55 }, Cabeza = { 0.6, 0, 0 }, Cuerpo = { 0.15, 0, 0 }, AlaIzq = { 0, -0.2, -0.65 }, AlaDer = { 0, 0.2, 0.65 } }) },
		{ 2.3, P({}) },
	},
	pilares = { -- clava la espada
		{ 0, P({}) },
		{ 0.4, P({ BrazoIzq = { 1.7, 0, -0.3 }, Cuerpo = { 0.1, 0.2, 0 }, Cabeza = { 0.2, 0, 0 } }) },
		{ 0.6, P({ BrazoIzq = { 0.2, 0, 0.1 }, Cuerpo = { -0.3, -0.1, 0 }, Cabeza = { -0.3, 0, 0 } }) },
		{ 1.3, P({}) },
	},
	melee = { -- tajo con la espada
		{ 0, P({}) },
		{ 0.3, P({ BrazoIzq = { 0.7, 0.9, -0.7 }, Cuerpo = { 0, 0.35, 0 } }) },
		{ 0.5, P({ BrazoIzq = { 1.0, -1.2, -0.4 }, Cuerpo = { -0.1, -0.35, 0 } }) },
		{ 1.0, P({}) },
	},
	plumas = { -- abre las alas de golpe
		{ 0, P({}) },
		{ 0.35, P({ AlaIzq = { 0, 0.5, 0.4 }, AlaDer = { 0, -0.5, -0.4 }, Cuerpo = { -0.1, 0, 0 } }) },
		{ 0.6, P({ AlaIzq = { 0, -0.5, -0.8 }, AlaDer = { 0, 0.5, 0.8 }, Cuerpo = { 0.15, 0, 0 }, Cabeza = { 0.3, 0, 0 }, BrazoIzq = { 0, 0, -0.5 }, BrazoDer = { 0, 0, 0.5 } }) },
		{ 1.6, P({ AlaIzq = { 0, -0.4, -0.7 }, AlaDer = { 0, 0.4, 0.7 } }) },
		{ 2.0, P({}) },
	},
	juicio = { -- levanta la espada al cielo y la baja
		{ 0, P({}) },
		{ 0.5, P({ BrazoIzq = { 2.6, 0, -0.2 }, Cabeza = { 0.6, 0, 0 }, Cuerpo = { 0.2, 0, 0 }, AlaIzq = { 0, -0.2, -0.7 }, AlaDer = { 0, 0.2, 0.7 } }) },
		{ 1.6, P({ BrazoIzq = { 2.7, 0, -0.2 }, Cabeza = { 0.6, 0, 0 }, Cuerpo = { 0.2, 0, 0 }, AlaIzq = { 0, -0.2, -0.75 }, AlaDer = { 0, 0.2, 0.75 } }) },
		{ 1.9, P({ BrazoIzq = { 0.6, 0, 0 }, Cuerpo = { -0.25, 0, 0 }, Cabeza = { -0.2, 0, 0 } }) },
		{ 2.6, P({}) },
	},
}
ATAQUES.colosal = ATAQUES.meteoros
ATAQUES.lava = ATAQUES.pilares

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function evaluar(anim, t: number): { [string]: Vector3 }
	local keys = anim
	if t >= keys[#keys][1] then return keys[#keys][2] end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a[1] and t <= b[1] then
			local f = suave((t - a[1]) / (b[1] - a[1]))
			local r = {}
			for _, n in NOMBRES do
				local va = a[2][n] or CERO
				local vb = b[2][n] or CERO
				r[n] = va:Lerp(vb, f)
			end
			return r
		end
	end
	return keys[1][2]
end

local actual: { [string]: Vector3 } = {}
for _, n in NOMBRES do actual[n] = POSE_DORMIDO[n] or CERO end
local animActiva, animInicio = nil, 0

local function lanzar(nombre: string)
	local a = ATAQUES[nombre]
	if a then
		animActiva = a
		animInicio = os.clock()
	end
end
demonio:GetAttributeChangedSignal("AtaqueN"):Connect(function()
	lanzar(demonio:GetAttribute("Ataque") or "")
end)
local estabaDespierto = demonio:GetAttribute("Despierto") == true
demonio:GetAttributeChangedSignal("Despierto"):Connect(function()
	local d = demonio:GetAttribute("Despierto") == true
	if d and not estabaDespierto then lanzar("despertar") end
	estabaDespierto = d
end)

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local muerto = demonio:GetAttribute("Muerto") == true
	local despierto = demonio:GetAttribute("Despierto") == true
	local volando = demonio:GetAttribute("Volando") == true
	local base = muerto and POSE_MUERTO or (volando and POSE_VUELO) or (despierto and POSE_DESPIERTO) or POSE_DORMIDO
	local extra = nil
	if animActiva and not muerto then
		local ta = os.clock() - animInicio
		if ta > animActiva[#animActiva][1] then
			animActiva = nil
		else
			extra = evaluar(animActiva, ta)
		end
	end
	-- movimiento constante (respirar / aletear)
	local vivo = muerto and 0 or 1
	local aleteo = volando and 0.45 or (despierto and 0.16 or 0.05)
	local velAla = volando and 4.2 or 1.6
	local ala = math.sin(t * velAla) * aleteo * vivo
	local resp = math.sin(t * 1.3)
	local idle = {
		Cuerpo = Vector3.new(0.025 * resp, 0, 0) * vivo,
		Cabeza = Vector3.new(0.04 * math.sin(t * 1.3 + 1), 0.12 * math.sin(t * 0.45), 0) * vivo,
		BrazoIzq = Vector3.new(0.04 * math.sin(t * 1.1), 0, -0.05 * resp) * vivo,
		BrazoDer = Vector3.new(0.04 * math.sin(t * 1.1 + 0.5), 0, 0.05 * resp) * vivo,
		AlaIzq = Vector3.new(0, 0, ala),
		AlaDer = Vector3.new(0, 0, -ala),
		Tunica = Vector3.new(0.04 * math.sin(t * 0.9) + (volando and 0.05 * math.sin(t * 3) or 0), 0.03 * math.sin(t * 0.7), 0) * vivo,
	}
	local k = math.clamp(dt * 6, 0, 1)
	for _, n in NOMBRES do
		local objetivo = (base[n] or CERO)
		actual[n] = actual[n]:Lerp(objetivo, muerto and math.clamp(dt * 1.5, 0, 1) or k)
		local v = actual[n] + (idle[n] or CERO) + (extra and extra[n] or CERO)
		local m = M[n]
		if m then
			m.Transform = CFrame.Angles(v.X, v.Y, v.Z)
		end
	end
end)
