-- =====================================================================
--  RUEDAS DE LA ESPALDA: giran alrededor del arcángel (sigue su raíz)
--  Va en ServerScriptService (Script).
-- =====================================================================
local RunService = game:GetService("RunService")
local demonio = workspace:WaitForChild("SenorLlamas")
local raiz: BasePart = demonio.PrimaryPart or demonio:WaitForChild("HumanoidRootPart")

-- giro (rad/s) sobre el eje del frente + bamboleo (eje, amplitud rad, velocidad)
local CONFIG = {
	RuedaExterior = { giro = 0.3, bEje = Vector3.yAxis, bAmp = 0, bVel = 0 },
	RuedaMedia    = { giro = -0.55, bEje = Vector3.yAxis, bAmp = 0.25, bVel = 0.8 },
	RuedaInterior = { giro = 1.0, bEje = Vector3.xAxis, bAmp = 0.3, bVel = 1.1 },
}

local datos = {}
for nombre, c in CONFIG do
	local p = demonio:FindFirstChild(nombre)
	if p and p:IsA("BasePart") then
		local off = raiz.CFrame:ToObjectSpace(p.CFrame)
		datos[p] = { pos = off.Position, rot = off.Rotation, c = c }
		p.Anchored = true
	end
end

local t = 0
RunService.Heartbeat:Connect(function(dt)
	t += dt
	for p, d in datos do
		if p.Parent then
			local c = d.c
			local giro = CFrame.fromAxisAngle(Vector3.zAxis, c.giro * t)
			local bam = CFrame.fromAxisAngle(c.bEje, c.bAmp * math.sin(t * c.bVel))
			p.CFrame = raiz.CFrame * CFrame.new(d.pos) * bam * giro * d.rot
		end
	end
end)
