--
PizzaTaunt.Bind = Starlight.Bind("pizzataunt")
local bnd = PizzaTaunt.Bind

bnd:SetCanPredict(true)
	:SetDefaultKey(KEY_T)
	:CreateConcommand("pizza_taunt")
	:SetSynced(true)

bnd:SetExclusive(true) -- TODO: setting

bnd:On("Activate", "FUNKY", function(self, ply)
	PizzaTaunt.Taunt(ply)
end)

local sfx = "pizzer.mp3"

function PizzaTaunt.PlaySound(ent, pitch, suppress)
	CheckArg(1, ent, IsEntity)

	if SERVER and not game.SinglePlayer() then
		-- Ugh
		net.Start("PizzaTaunt_Sound")
			net.WriteEntity(ent)
			net.WriteUInt(pitch, 16)

		if suppress and IsPlayer(ent) then
			net.SendOmit(ent)
		else
			net.Broadcast()
		end
	else
		ent:EmitSound(sfx, 80, pitch, 1, CHAN_AUTO)
	end
end

local ENTITY = FindMetaTable("Entity")

PizzaTaunt.TauntingEnts = PizzaTaunt.TauntingEnts or {}
PizzaTaunt.TauntData = PizzaTaunt.TauntData or {}

function ENTITY:GetTauntData()
	return PizzaTaunt.TauntData[self]
end

function PizzaTaunt.Taunt(ent)
	if ent:GetNW2Float("PTTauntTime", 0) ~= 0 then return end

	local ok = hook.Run("PizzaTaunt_CanTaunt", ent)
	if ok == false then return end

	PizzaTaunt.TauntData[ent] = {}

	PizzaTaunt.TauntingEnts[ent] = PizzaTaunt.TauntingEnts[ent] or UnPredictedCurTime()
	ent:SetNW2Float("PTTauntTime", UnPredictedCurTime())
	hook.Run("PizzaTaunt_StartTaunt", ent, IsFirstTimePredicted())
end

function PizzaTaunt.EndTaunt(ent)
	if ent:GetNW2Float("PTTauntTime", 0) == 0 then return end

	PizzaTaunt.TauntData[ent] = nil
	PizzaTaunt.TauntingEnts[ent] = nil
	ent:SetNW2Float("PTTauntTime", 0)
	hook.Run("PizzaTaunt_StopTaunt", ent)
end

function PizzaTaunt.IsTaunting(ent, unpred)
	local t = PizzaTaunt.TauntingEnts[ent]
	if not t then return false end

	if not unpred then return t end

	return SERVER and t or (UnPredictedCurTime() - t < PizzaTaunt.Length)
end

function PizzaTaunt.GetTauntingEnts()
	return PizzaTaunt.TauntingEnts
end

hook.Add("PizzaTaunt_StartTaunt", "DING", function(ent, pred)
	if not pred then return end
	PizzaTaunt.PlaySound(ent, math.random(100, 110), true)
end)

function PizzaTaunt.ThinkTaunt(ent)
	local sneed = math.random()

	math.randomseed(ent:EntIndex() + PizzaTaunt.TauntingEnts[ent])
	local rand = math.random()
	gpcall("ThinkTaunt", hook.Run, "PizzaTaunt_ThinkTaunt", ent, rand)
	math.randomseed(sneed)
end

function PizzaTaunt.DoPredLogic(ent)
	local aaa = ent:GetNW2Float("PTTauntTime", 0)
	if aaa == 0 then return end

	if CurTime() - aaa > PizzaTaunt.Length then
		PizzaTaunt.EndTaunt(ent)
	end
end

hook.Add("StartCommand", "ILovePrediction", function(ply)
	PizzaTaunt.DoPredLogic(ply)

	for ent, t in pairs(PizzaTaunt.TauntingEnts) do
		PizzaTaunt.DoPredLogic(ent)
	end
end)

hook.Add("PizzaTaunt_ThinkTaunt", "ThePizzaShaker", function(ent, seed)
	local dat = ent:GetTauntData()
	local seqDat = dat.SequenceData

	if not seqDat then
		local seq, cyc = PizzaTaunt.GetPoseSequence(ent)
		dat.SequenceData = {ent:LookupSequence(seq), cyc}
		seqDat = dat.SequenceData
	end

	ent:SetCycle(seqDat[2])
	ent:SetPlaybackRate(0)
end)

hook.Add("CalcMainActivity", "waa", function(ply, vel)
	if not PizzaTaunt.IsTaunting(ply, true) then return end

	local dat = ply:GetTauntData()
	if not dat then return end

	local seqDat = dat and dat.SequenceData
	if not seqDat then
		PizzaTaunt.ThinkTaunt(ply)
		seqDat = dat.SequenceData
		if not seqDat then return end
	end

	ply:SetCycle(seqDat[2])
	ply:SetPlaybackRate(0)

	return ACT_RESET, seqDat[1]
end)

hook.Add("StartCommand", "PizzaTaunt_STOPMOVING", function(ply, cmd)
	local aaa = ply:GetNW2Float("PTTauntTime", 0)
	if aaa == 0 then return end

	cmd:SetButtons(0)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetUpMove(0)
end)

hook.Add("PizzaTaunt_CanTaunt", "NoDeadTaunts", function(ent)
	if IsPlayer(ent) and not ent:Alive() then return false end
end)