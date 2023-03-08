-- https://github.com/2048khz-gachi-rmx/beizwors/blob/live/addons/core_bw_modules/lua/bw_modules/server/join_broadcast_sv.lua

JoinAnnouncer = JoinAnnouncer or {}
local an = JoinAnnouncer

local enable = CreateConVar("joinbroadcast_enabled", "1", FCVAR_ARCHIVE,
	"Enable the join-leave broadcasting?")

local function enabled()
	an.Enabled = enable:GetBool()
	return an.Enabled
end

local unspamCvar = CreateConVar("joinbroadcast_antispam_ratelimit", "10", FCVAR_ARCHIVE,
	"Whenever someone cancels joining, this many seconds will have to pass before their next join will be announced again.\n" ..
	"This prevents spam from the same player repeatedly joining and leaving.")

local spewRightPwd = CreateConVar("joinbroadcast_spew_password", "0", FCVAR_ARCHIVE,
	"When enabled, if the server is password-protected and someone uses the wrong password, the correct one will be appended to the message too.")

local broadcastBadPwd = CreateConVar("joinbroadcast_broadcast_wrong_password", "1", FCVAR_ARCHIVE,
	"When enabled, if the server is password-protected and someone uses the wrong password, it'll be broadcasted.")

local broadcastPlaytime = CreateConVar("joinbroadcast_broadcast_playtime", "1", FCVAR_ARCHIVE,
	"Include information about how much time the player spent on the server before leaving.\n" ..
	"This (probably) won't track time properly for servers that change maps!")

local broadcastJointime = CreateConVar("joinbroadcast_broadcast_jointime", "1", FCVAR_ARCHIVE,
	"Include information about how much time the player spent on the loading screen.")

local broadcastReason = CreateConVar("joinbroadcast_broadcast_leave_reason", "1", FCVAR_ARCHIVE,
	"Include information about why the player left (kick? disconnect? etc.)")

util.AddNetworkString("NewPlayerBroadcast")

an.IPs = an.IPs or {}
an.JoinTimes = an.JoinTimes or {}
an.LeaveTimes = an.LeaveTimes or {}
an.SpawnTimes = an.SpawnTimes or {}
an.UIDToSID = an.UIDToSID or {}

local IPs = an.IPs
local joinTimes = an.JoinTimes
local leaveTimes = an.LeaveTimes
local spawnTimes = an.SpawnTimes
local u2s = an.UIDToSID

local Colors = {}

Colors.Sky = Color(50, 150, 250)
Colors.Yellowish = Color(250, 210, 120)
Colors.Red = Color(255, 70, 70)

local function getJoinTime(sid)
	if joinTimes[sid] then return SysTime() - joinTimes[sid], true end
	return 0, false
end

local function getLeaveTime(sid)
	if leaveTimes[sid] then return SysTime() - leaveTimes[sid], true end
	return 0, false
end

local function getPlayTime(sid)
	if spawnTimes[sid] then return SysTime() - spawnTimes[sid], true end
	return 0, false
end

local function table_RemapValues(t, to)
	for k,v in ipairs(t) do
		if to[v] ~= nil then
			t[k] = to[v]
		end
	end

	return t
end

function an.AnnounceConnect(name, sid64, ip, sub)
	local sid = util.SteamIDFrom64(sid64)

	if enabled() then
		net.Start("NewPlayerBroadcast")
			net.WriteUInt(0, 4)
			net.WriteString(name)
			net.WriteString(sid)
		net.Broadcast()

		local txt = name .. (" has started connecting to the server. (%s @ %s)")
			:format(sid64, ip)

		MsgC(
			Colors.Yellowish, "[Connect] ",
			Color(230, 230, 230), txt,
			"\n"
		)
	end

	joinTimes[sid64] = joinTimes[sid64] or SysTime() - (sub or 0)
	IPs[sid64] = ip

	hook.Run("AnnounceConnect", name, sid64, ip)
end

function an.OnJoin(name, sid64, ip)
	local time, was = getLeaveTime(sid64)
	local cd = unspamCvar:GetInt() - time

	if was and cd > 0 then
		timer.Create("announceconnect_" .. sid64, cd, 1, function()
			an.AnnounceConnect(name, sid64, ip, cd)
		end)
	else
		an.AnnounceConnect(name, sid64, ip)
	end
end

function an.AnnounceAbortJoin(name, sid64, reason)
	local passed = getJoinTime(sid64)
	joinTimes[sid64] = nil
	leaveTimes[sid64] = SysTime()

	if enabled() then
		local dat = {
			Colors.Red, "[Disconnect] ",
			Color(200, 200, 200), "TX1",
			Color(100, 220, 100), "NAME",
			Color(160, 160, 160), "DETAILS",
			Color(200, 200, 200), "TX2",
			Color(160, 160, 160), "WHY",
			"\n"
		}

		local remap = {
			TX1 = "Player ",
			NAME = name .. " ",
			DETAILS = ("(%s @ %s) "):format(sid64, IPs[sid64] or "??? untracked IP?"),
			TX2 = ("has given up on connecting after %ds. "):format(passed),
			WHY = ("(%s)"):format( reason:gsub("^%(", ""):gsub("%)$", "") )
		}


		table_RemapValues(dat, remap, true)

		MsgC(unpack(dat))

		local timeSpent = broadcastJointime:GetBool() and math.min(65535, math.floor(passed))
			or 0

		net.Start("NewPlayerBroadcast")
			net.WriteUInt(2, 4)
			net.WriteString(name)
			net.WriteString(sid64)
			net.WriteUInt(timeSpent, 16)
			net.WriteString(broadcastReason:GetBool() and reason or "")
		net.Broadcast()
	end

	hook.Run("AnnounceLeave", name, sid64, reason, passed, true)
	hook.Run("AnnounceAbortJoin", name, sid64, reason, passed, true)
end

function an.AnnounceLeaveGame(name, sid64, reason)
	local passed = getPlayTime(sid64)
	spawnTimes[sid64] = nil

	if enabled() then
		local dat = {
			Colors.Red, "[Disconnect] ",
			Color(200, 200, 200), "TX1",
			Color(100, 220, 100), "NAME",
			Color(160, 160, 160), "DETAILS",
			Color(200, 200, 200), "TX2",
			Color(160, 160, 160), "WHY",
			"\n"
		}

		local remap = {
			TX1 		= "Player ",
			NAME 		= name .. " ",
			DETAILS 	= ("(%s @ %s) "):format(sid64, IPs[sid64] or "??? untracked IP?"),
			TX2 		= "has left the server. ",
			WHY 		= ("(%s)"):format( reason:gsub("^%(", ""):gsub("%)$", "") )
		}

		table_RemapValues(dat, remap, true)

		MsgC(unpack(dat))

		local timePlayed = broadcastPlaytime:GetBool() and math.min(65535, math.floor(passed))
			or 0

		net.Start("NewPlayerBroadcast")
			net.WriteUInt(3, 4)
			net.WriteString(name)
			net.WriteString(sid64)
			net.WriteUInt(timePlayed, 16) -- u reckon 18hrs spent on the server is ok?
			net.WriteString(broadcastReason:GetBool() and reason or "")
		net.Broadcast()
	end

	hook.Run("AnnounceLeave", name, sid64, reason, passed, false)
	hook.Run("AnnounceLeaveGame", name, sid64, reason, passed)
end

function an.OnLeave(name, sid64, reason)
	local _, played = getPlayTime(sid64)
	if played then
		-- leaving after actually spawning and playing
		an.AnnounceLeaveGame(name, sid64, reason)
		return
	end

	-- unspawned leave; ratelimit
	timer.Remove("announceconnect_" .. sid64) -- don't announce their ratelimited connect

	local time, was = getLeaveTime(sid64)
	local cd = unspamCvar:GetInt() - time

	if was and cd > 0 then
		-- on cooldown from announcing; bail
		return
	else
		an.AnnounceAbortJoin(name, sid64, reason)
	end
end

local joinWait = {}
hook.Add("CheckPassword", "BroadcastJoin", function( sid64, ip, pw1, pw2, name )
	local sid = util.SteamIDFrom64( sid64 )
	if pw1 and pw2 and #pw1 > 0 and pw1 ~= pw2 then

		if broadcastBadPwd:GetBool() and enabled() then
			local id_tx = "%s (%s) failed password."
			local dat = {
				Colors.Red, "[Disconnect] ",
				Color(200, 200, 200), id_tx:format(name, sid, pw1, pw2), " (",
			}

			local text = "tried: "

			if spewRightPwd:GetBool() then
				table.Add(dat, {
					Color(70, 210, 70), pw1,
				})

				text = " vs. "
			end

			table.Add(dat, {
				Color(200, 200, 200), text,
				Color(160, 70, 70), #pw2 > 0 and pw2 or "-",
				Color(200, 200, 200), ")."
			})

			an.BroadcastChatText(unpack(dat))

			dat[#dat + 1] = "\n"
			MsgC(unpack(dat))
		end

		return
	end

	joinWait[sid64] = true

	timer.Simple(0, function()
		if not joinWait[sid64] then return end
		joinWait[sid64] = nil
		an.OnJoin(name, sid64, ip)
	end)
end)

-- custom hook initially intended for ULX... but who's gonna provide it for *you*?
hook.Add("PlayerRefusedJoin", "StopBroadcast", function(sid64)
	joinWait[sid64] = nil
end)

gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "TrackLeave", function( data )
	local name = data.name
	local reason = data.reason and data.reason:gsub("[\r\n]*$", "")
	local sid64 = u2s[data.userid] or util.SteamIDTo64(data.networkid)

	an.OnLeave(name, sid64, reason)
end)

hook.Add("JB_PlayerFullyLoaded", "BroadcastJoin", function(ply)
	u2s[ply:UserID()] = ply:SteamID64() -- botz

	local passed = getJoinTime(ply:SteamID64())
	joinTimes[ply:SteamID64()] = nil
	spawnTimes[ply:SteamID64()] = SysTime()

	if enabled() then
		-- this will be MsgC'd, not sent to clients
		local dat = {
			Colors.Sky, "[Connect] ",
			Color(200, 200, 200), "Player ",
			Color(100, 220, 100), ply:Nick(), " ",
			Color(160, 160, 160), ("(%s @ %s) "):format(ply:SteamID64(), ply:IPAddress()),
			Color(200, 200, 200), "finished connecting after ",
			Color(220, 200, 35), ("%d"):format(passed),
			Color(200, 200, 200), "s.",
			"\n"
		}


		local timeSpent = broadcastJointime:GetBool() and math.min(65535, math.floor(passed))
			or 0

		net.Start("NewPlayerBroadcast")
			net.WriteUInt(1, 4)
			net.WriteString(ply:Nick())
			net.WriteString(ply:SteamID())
			net.WriteUInt(timeSpent, 16)
		net.Broadcast()

		MsgC(unpack(dat))
	end

	hook.Run("AnnounceJoin", ply:Nick(), ply:SteamID64(), ply, passed)
end)

--[[
-- example of how you could announce join/leaves to discord

hook.Add("AnnounceJoin", "Discord", function(name, sid, ply, passed)
	if not discord.Enabled then return end
	if not discord.DB then return end

	local tx = "Player %s has joined the server [%s] after %s."
	tx = tx:format(name, game.GetServerID(), string.TimeParse(passed))

	discord.QueueEmbed("joinleave", "Join/Leave",
		Embed()
			:SetText(tx)
			:SetColor(70, 200, 70)
		)
end)

hook.Add("AnnounceConnect", "Discord", function(name, sid, ip)
	if not discord.Enabled then return end
	if not discord.DB then return end

	local tx = "Player %s has started connecting to the server. [%s]"
	tx = tx:format(name, game.GetServerID())

	discord.QueueEmbed("joinleave", "Join/Leave",
		Embed()
			:SetText(tx)
			:SetColor(230, 200, 70)
		)
end)

hook.Add("AnnounceLeave", "Discord", function(name, sid, reason, passed, injoin)
	if not discord.Enabled then return end
	if not discord.DB then return end

	local tx = "Player %s has %s [%s]. (session: %s)."
	tx = tx:format(
		name,
		injoin and "given up on connecting" or "left the server",
		game.GetServerID(),
		passed > 0 and string.TimeParse(passed) or "?"
	)

	discord.QueueEmbed("joinleave", "Join/Leave",
		Embed()
			:SetText(tx)
			:SetColor(200, 70, 70)
		)
end)

]]