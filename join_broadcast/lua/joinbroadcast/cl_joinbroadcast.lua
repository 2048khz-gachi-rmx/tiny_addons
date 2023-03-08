-- https://github.com/2048khz-gachi-rmx/beizwors/blob/live/gamemodes/basewars/gamemode/client/cl_status.lua

local Colors = {}

Colors.Sky = Color(50, 150, 250)
Colors.Yellowish = Color(250, 210, 120)
Colors.Leave = Color(220, 70, 70)

hook.Add("ChatText", "___Nope", function(ind, name, txt, type)
	if type == "joinleave" then return true end
end)

function table_ReplaceValue(t, what, with)
	for k, v in ipairs(t) do
		if v == what then
			t[k] = with
			return k
		end
	end
end

local function formatTime(s)
	local time = string.FormattedTime(s)

	if time.h > 0 then
		return ("%02i:%02i:%02i"):format(time.h, time.m, time.s)
	else
		return ("%02i:%02i"):format(time.m, time.s)
	end
end

local function pickPhrase(spent, regular, none, toomuch)
	local out = spent == 0 and none
		or spent == 65535 and toomuch
		or regular

	return out, out ~= regular
end

net.Receive("NewPlayerBroadcast", function()
	local typ = net.ReadUInt(4)

	local startConnect = typ == 0
	local joinFull = typ == 1

	local left = typ >= 2
	local leftUnconnected = typ == 2
	local leftConnected = typ == 3

	local plyname = net.ReadString()
	local sid = net.ReadString()

	local dat = {
		Colors.Yellowish, "[Connect] ",
		Color(200, 200, 200), "Player ",
		Color(100, 220, 100), plyname, " ",
		Color(160, 160, 160), "[STEAMID]",
	}

	local append

	if left then
		dat[1] = Colors.Leave
		dat[2] = "[Disconnect] "
	elseif joinFull then
		dat[1] = Colors.Sky
	end

	if startConnect then
		surface.PlaySound("npc/scanner/scanner_nearmiss1.wav")

		append = {
			Color(200, 200, 200), "has started connecting to the server.",
		}
	elseif joinFull then
		surface.PlaySound("garrysmod/content_downloaded.wav")

		local spent = net.ReadUInt(16)

		local text1, irregular = pickPhrase(spent, "finished loading in ", "finished loading", "plays on a toaster")
		local text2 = not irregular and formatTime(spent) or ""

		append = {
			Color(200, 200, 200), text1,
			Color(220, 200, 35), text2,
			Color(200, 200, 200), ".",
		}
	elseif leftUnconnected then
		surface.PlaySound("npc/turret_floor/retract.wav")

		local spent = net.ReadUInt(16)
		local reason = net.ReadString()
		reason = #reason > 0 and reason

		if reason:match("^Disconnect by user") then
			reason = "disconnected"
		end

		local text1, irregular = pickPhrase(spent, "gave up on joining after ", "figured he had enough", "plays on a toaster")
		local text2 = not irregular and formatTime(spent) or ""

		append = {
			Color(200, 200, 200), text1,
			Color(220, 200, 35), text2,
			Color(200, 200, 200), ".",
		}

		if reason then
			table.Add(append, {
				Color(120, 120, 120), (" (%s)"):format(reason),
			})
		end

	elseif leftConnected then
		surface.PlaySound("npc/turret_floor/retract.wav")
		surface.PlaySound("npc/roller/mine/combine_mine_deploy1.wav")

		local spent = net.ReadUInt(16)
		local reason = net.ReadString()
		reason = #reason > 0 and reason

		local verb = "left"

		if reason:match("^Disconnect by user") then
			reason = "disconnected"
		elseif math.random() < 0.01 then
			verb = "got owned"
		end

		local text1 = verb .. pickPhrase(spent,  " after playing for ", ".", " after playing for ")
		local text2, irregular2 = pickPhrase(spent, formatTime(spent), "", "MORE THAN 18 HOURS!?")
		local text3 = ""

		if not irregular2 then
			text2 = formatTime(spent)
			text3 = "."
		end

		append = {
			Color(200, 200, 200), 	text1,
			Color(220, 200, 35), 	text2,
			Color(200, 200, 200), 	text3,
		}

		if reason then
			table.Add(append, {
				Color(120, 120, 120), (" (%s)"):format(reason),
			})
		end
	end

	table.Add(dat, append)

	local key = table_ReplaceValue(dat, "[STEAMID]", "")

	chat.AddText(unpack(dat))

	dat[key] = ("(%s) "):format(sid)

	MsgC(unpack(dat))
	MsgC("\n")
end)