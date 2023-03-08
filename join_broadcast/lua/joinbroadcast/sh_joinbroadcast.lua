--https://github.com/2048khz-gachi-rmx/beizwors/blob/live/addons/core_just_lib_it_up/lua/lib_it_up/extensions/player.lua#L151-L292

JoinAnnouncer = JoinAnnouncer or {}
local an = JoinAnnouncer

if SERVER then
	an.FullyLoaded = an.FullyLoaded or {}
	local FullyLoaded = an.FullyLoaded

	util.AddNetworkString("FullLoad")

	-- wait for either the client's net message or source's Move hook

	local function runFullLoadHook(ply)
		if FullyLoaded[ply] then return end
		FullyLoaded[ply] = true

		hook.Run("JB_PlayerFullyLoaded", ply)
	end

	net.Receive("FullLoad", function(_, ply)
		runFullLoadHook(ply)
	end)

	hook.Add("PlayerInitialSpawn", "PlayerFullyLoaded", function(ply)
		local hookId = ("fullload_mv_%p"):format(ply)

		local function remove()
			hook.Remove("SetupMove", hookId)
		end

		hook.Add("SetupMove", hookId, function(mvPly, mv, cmd)
			if not ply:IsValid() then
				remove()
				return
			end

			if mvPly ~= ply then return end
			if cmd:IsForced() then return end

			runFullLoadHook(ply)
			remove()
		end)
	end)

else -- client
	an.FullLoadSent = an.FullLoadSent or false

	hook.Add("CalcView", "JB_FullyLoaded", function()
		if an.FullLoadSent then
			hook.Remove("CalcView", "JB_FullyLoaded")
			return
		end

		net.Start("FullLoad")
		net.SendToServer()

		an.FullLoadSent = true

		hook.Remove("CalcView", "JB_FullyLoaded")
		-- hook.Run("PlayerFullyLoaded", LocalPlayer())
	end)
end


JoinAnnouncer = JoinAnnouncer or {}
local an = JoinAnnouncer

local netName = "NewPlayerBroadcast_ChatText"

if SERVER then
	util.AddNetworkString(netName)

	function an.BroadcastChatText(...)
		net.Start(netName)
			net.WriteTable({...}) -- boohoo
		net.Broadcast()
	end
else
	net.Receive(netName, function()
		local data = net.ReadTable()
		if not istable(data) then return end

		chat.AddText(unpack(data))
	end)
end