PizzaTaunt.TauntSequences = PizzaTaunt.TauntSequences or {}

table.Merge(PizzaTaunt.TauntSequences, {
	["menu_zombie_01"] = {0.6},
	["taunt_cheer_base"] = {0.6},
	["taunt_laugh"] = {0.15},
	["taunt_muscle"] = {{0.1, 0.1}, {0.3, 0.35}, {0.43}, {0.75}},
})

function PizzaTaunt.GetPoseSequence(ent)
	do
		local seq, t = hook.Run("PizzaTaunt_PickTaunt", ent)
		if seq then
			return seq, t
		end
	end

	local t, seq = table.Random(PizzaTaunt.TauntSequences)

	if istable(t[1]) then
		t = t[math.random(#t)]
	end

	if isnumber(t[1]) and isnumber(t[2]) then
		t = Lerp(math.random(), t[1], t[2])
	elseif isnumber(t[1]) then
		t = t[1]
	end

	return seq, t
end