--

util.AddNetworkString("PizzaTaunt_Sound")

hook.Add("Think", "PIZZER", function()
	for ent, time in pairs(PizzaTaunt.GetTauntingEnts()) do
		PizzaTaunt.ThinkTaunt(ent)
	end
end)