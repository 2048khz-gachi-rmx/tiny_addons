PizzaTaunt.Convars = PizzaTaunt.Convars or {}
local cv = PizzaTaunt.Convars

cv.ParryNPCs = CreateConVar("pizzataunt_parry_vsnpc", "1",
	FCVAR_ARCHIVE + FCVAR_REPLICATED, "Allow parrying NPC attacks?")

cv.ParryPlayers = CreateConVar("pizzataunt_parry_vsplayers", "1",
	FCVAR_ARCHIVE + FCVAR_REPLICATED, "Allow parrying player attacks?")

cv.BoostParry = CreateConVar("pizzataunt_parry_deflectmult", "1",
	FCVAR_ARCHIVE + FCVAR_REPLICATED, "Multiplier for deflected damage to the attacker\n" ..
	"(2 = deal x2 the damage to the attacker when parried)")

cv.ParryDiminish = CreateConVar("pizzataunt_parry_parrymult", "0",
	FCVAR_ARCHIVE + FCVAR_REPLICATED, "Multiplier for damage that goes unparried\n" ..
	"(0.25 = 25% of the damage still goes through the parry)")

cv.ParryTime = CreateConVar("pizzataunt_parry_parrytime", "100",
	FCVAR_ARCHIVE + FCVAR_REPLICATED, "Percentage of the taunt's length when the parry is active\n" ..
	"(50 = the first 50% of the taunt can parry damage; 100 = parry lasts the entire taunt)",
	0, 100)

cv.ParryExplosives = CreateConVar("pizzataunt_parry_explosives", "1",
	FCVAR_ARCHIVE + FCVAR_REPLICATED, "Allow parrying blast damage?")

PizzaTaunt.ParryableDamage = bit.bor(DMG_BULLET, DMG_SLASH, DMG_CLUB, DMG_BUCKSHOT, DMG_SNIPER,
	DMG_BLAST, DMG_BLAST_SURFACE) -- Special handling

function PizzaTaunt.CanParryDamage(dmg)
	local dtyp = dmg:GetDamageType()

	if bit.band(dtyp, PizzaTaunt.ParryableDamage) == 0 then
		return false
	end

	-- if bit.band(dtyp, bit.bor(DMG_BLAST, DMG_BLAST_SURFACE)) ~= 0 then
	if dmg:IsExplosionDamage() then
		-- it's blast damage, obey the blast convar
		return cv.ParryExplosives:GetBool()
	end

	return true
end

function PizzaTaunt.DoParryLogic(ent, dmg)
	if PizzaTaunt.PARRYING then return end

	local startTaunt = PizzaTaunt.IsTaunting(ent)
	if not startTaunt then return end

	if CurTime() > (startTaunt + cv.ParryTime:GetFloat() / 100 * PizzaTaunt.Length)  then return end

	local atk = dmg:GetAttacker()
	-- if atk == ent then return end

	local cvar = IsPlayer(atk) and cv.ParryPlayers
		or IsValid(atk) and atk:IsNPC() and cv.ParryNPCs
		or false -- default: parry non-npc and non-player damage

	if cvar and not cvar:GetBool() then return end
	if not PizzaTaunt.CanParryDamage(dmg) then return end

	local can = hook.Run("PizzaTaunt_CanParryDamage", ent, dmg, atk)
	if can == false then return end

	PizzaTaunt.PARRYING = true

	local _, handled, ret = gpcall("PizzaTaunt_ParryDamage", hook.Run, "PizzaTaunt_ParryDamage",
		ent, dmg, dmg:GetDamageType())

	PizzaTaunt.PARRYING = false

	if handled ~= nil then return ret end

	return true
end

PizzaTaunt.PARRYING = false

hook.Add("EntityTakeDamage", "TauntParry", function(ent, dmg)
	return PizzaTaunt.DoParryLogic(ent, dmg)
end)

hook.Add("ScalePlayerDamage", "TauntParry", function(ply, hg, dmg)
	return PizzaTaunt.DoParryLogic(ply, dmg)
end)

-- Anti-sfx-spam table; only play the parry sound once per X seconds
PizzaTaunt.ParryCD = PizzaTaunt.ParryCD or {}
PizzaTaunt.ParrySFXInterval = 0.05
local sfx = "pizzaparry.mp3"

function PizzaTaunt.PlayParryEffects(ent)
	-- assert(SERVER, "PlayParrySound shouldn't be used clientside!")
	if (PizzaTaunt.ParryCD[ent] and CurTime() < PizzaTaunt.ParryCD[ent]) then
		return
	end

	ent:EmitSound(sfx, 90, math.random(100, 110), 1, CHAN_AUTO)
	PizzaTaunt.ParryCD[ent] = CurTime() + PizzaTaunt.ParrySFXInterval

	util.ScreenShake(ent:GetPos(), 5, 12, 1, 512)

	local ef = EffectData()
	ef:SetOrigin(ent:GetPos() + ent:OBBCenter())
	ef:SetScale(200)
	ef:SetNormal(vector_up)
	ef:SetEntity(ent)
	util.Effect("ThumperDust", ef)
	util.Effect("cball_explode", ef)
end


local function FUCK(atk, tr, dmg)
	dmg:ScaleDamage(0) -- I LUOVE GMOD
end

hook.Add("PizzaTaunt_ParryDamage", "ParryDirect", function(ent, dmg, typ)
	if bit.band(typ, bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER, DMG_SLASH, DMG_CLUB)) == 0 then
		return -- Not a damage type which is handled by this hook
	end

	local atk = dmg:GetAttacker()
	if IsValid(atk) and PizzaTaunt.IsTaunting(atk) then
		-- Cheeky bastard is taunting himself; deflecting damage now
		--   would make for an infinite loop of parrying
		-- Just forfeit the damage instead
		return true, true
	end

	local origAmt = dmg:GetDamage()

	if IsValid(atk) then
		dmg:SetAttacker(ent)
		dmg:SetDamage(origAmt * cv.BoostParry:GetFloat())

		atk:TakeDamageInfo(dmg)

		if dmg:IsBulletDamage() then
			local t = {
				Attacker = ent,
				Damage = 0,
				Force = 0,
				Dir = ((atk:GetPos() + atk:OBBCenter()) - ent:EyePos()):GetNormalized(),
				Src = ent:EyePos(),
				IgnoreEntity = ent,
				TracerName = "AR2Tracer",
				Callback = FUCK,
			}
			ent:FireBullets(t)
		end
	end

	PizzaTaunt.PlayParryEffects(ent)

	dmg:SetAttacker(atk)
	dmg:SetDamage(origAmt * cv.ParryDiminish:GetFloat())

	local ret = cv.ParryDiminish:GetFloat() == 0 or nil
	return true, ret
end)

hook.Add("PizzaTaunt_ParryDamage", "ParryExplosives", function(ent, dmg, typ)
	if not dmg:IsExplosionDamage() then
		return -- Not a damage type which is handled by this hook
	end

	-- Same as bullet damage but doesn't deflect damage to the attacker
	PizzaTaunt.PlayParryEffects(ent)
	dmg:SetDamage(dmg:GetDamage() * cv.ParryDiminish:GetFloat())

	local ret = cv.ParryDiminish:GetFloat() == 0 or nil
	return true, ret
end)

-- ew
local exists = false
hook.Add("EntityRemoved", "PizzaTaunt_GC", function(ent)
	if exists then return end
	exists = true

	timer.Create("PizzaTaunt_GC", 15, 1, function()
		exists = false
		for k,v in pairs(PizzaTaunt.ParryCD) do
			if not IsValid(k) then PizzaTaunt.ParryCD[k] = nil end
		end
	end)
end)

