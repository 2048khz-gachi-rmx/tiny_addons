PizzaTaunt.VisEnts = PizzaTaunt.VisEnts or {}
local boneCache = {}

hook.Add("NotifyShouldTransmit", "PizzaTaunt", function(ent, enter)
	if enter then
		PizzaTaunt.VisEnts[#PizzaTaunt.VisEnts + 1] = ent
		PizzaTaunt.InstallNW(ent)
	else
		table.RemoveByValue(PizzaTaunt.VisEnts, ent)
		PizzaTaunt.EndTaunt(ent)

		hook.Run("PizzaTaunt_ClearEnt", ent)
	end
end)

local mat = Material("bing.png")

local hkName = "PreDrawOpaqueRenderables"
_curHk = hkName

local priorityBones = {
	"ValveBiped.Bip01_Spine2",
	"ValveBiped.Bip01_Spine1",
	"ValveBiped.Bip01_Spine",
}


function PizzaTaunt.GetOrigin(ent)
	if IsPlayer(ent) then
		if boneCache[ent] then
			return ent:GetBonePosition(boneCache[ent])
		end

		if boneCache[ent] ~= false then
			for k,v in ipairs(priorityBones) do
				if ent:GetBonePosition(ent:LookupBone(v)) then
					boneCache[ent] = ent:LookupBone(v)
					return ent:GetBonePosition(boneCache[ent])
				end
			end

			boneCache[ent] = false
		end
	end

	local pos = ent:GetPos()
	pos:Add(ent:OBBCenter()) -- buwomp

	return pos
end

local hwite = Color(255, 255, 255) -- mr wite

local ease = {
	[0] = function(x) return x end,
	[1] = math.ease.OutElastic,
	[-1] = math.ease.OutCirc,
}

hook.Add(hkName, "TauntDraw", function()
	if _curHk ~= hkName then
		hook.Remove(hkName, "TauntDraw")
		return
	end

	local ct = CurTime()
	local removeTime = 0.1
	local appearTime = PizzaTaunt.Length - 0.1

	for ent, time in pairs(PizzaTaunt.GetTauntingEnts()) do
		if ent == LocalPlayer() and not ent:ShouldDrawLocalPlayer() then continue end

		local passed = math.max(0, ct - time)
		local fr, dir = math.TriWaveEx(passed,
			appearTime, PizzaTaunt.Length - removeTime - appearTime, removeTime,
			0, 1, true)

		fr = ease[dir] (fr)

		local origin = PizzaTaunt.GetOrigin(ent)
		local sz = fr * 64

		hwite.a = math.min(255, fr * 255)

		render.SetMaterial(mat)
		render.DrawSprite(origin, sz, sz, hwite)

		PizzaTaunt.ThinkTaunt(ent)
	end
end)


function PizzaTaunt.NWChanged(ent, name, old, new)
	if new > 0 then
		if PizzaTaunt.TauntingEnts[ent] then return end -- anti inf-loop
		PizzaTaunt.Taunt(ent)
	else
		if not PizzaTaunt.TauntingEnts[ent] then return end
		PizzaTaunt.EndTaunt(ent)
	end
end

function PizzaTaunt.InstallNW(ent)
	ent:SetNW2VarProxy("PTTauntTime", PizzaTaunt.NWChanged)

	if ent:GetNW2Float("PTTauntTime", 0) ~= 0 then
		PizzaTaunt.Taunt(ent)
	end
end

for k,v in ipairs(ents.GetAll()) do
	if IsValid(v) then
		PizzaTaunt.InstallNW(v)
	end
end

net.Receive("PizzaTaunt_Sound", function()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end

	local pitch = net.ReadUInt(16)

	PizzaTaunt.PlaySound(ent, pitch)
end)

local keyz = {}

for k,v in pairs(_G) do
	if isstring(k) and (k:match("^KEY_") or k:match("^MOUSE_")) then
		keyz[#keyz + 1] = k
	end
end

local rebindCmd = "pizzataunt_setkey"
concommand.Add(rebindCmd, function(ply, cmd, args, argStr)
	local str = argStr:upper():Trim()
	if not str:match("^KEY_") and not str:match("^MOUSE_") then
		return
	end

	local keyEnum = _G[str]
	if not isnumber(keyEnum) then
		return
	end

	PizzaTaunt.Bind:SetKey(keyEnum)
	Starlight.Binds.WriteData()
end, function(_, args)
	local str = args:upper():Trim()
	local matches = {}

	for k,v in pairs(keyz) do
		if v:find("KEY_" .. str, 1, true) or v:find("MOUSE_" .. str, 1, true) or v:find(str, 1, true) then
			matches[#matches + 1] = rebindCmd .. " " .. v
		end
	end

	table.sort(matches, function(a, b)
		local b1, b2 = a:match("KEY_" .. str) or a:match("MOUSE_" .. str),
					   b:match("KEY_" .. str) or b:match("MOUSE_" .. str)

		if b1 and not b2 then return true end
		if b2 and not b1 then return false end
		if #a ~= #b then return #a < #b end

		return a < b
	end)
	return matches
end)