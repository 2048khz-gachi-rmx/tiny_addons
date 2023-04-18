AutoRestart = AutoRestart or {}

AutoRestart.Convars = {
	Time = CreateConVar("autorestart_time", 60 * 12, FCVAR_ARCHIVE,
		"Automatically restart the server after this many minutes of uptime.\n" ..
		"Values of more than 1440 minutes (24 hours) are not recommended.",
		0),

	TimeCountdown = CreateConVar("autorestart_countdown", 10, FCVAR_ARCHIVE,
		"After the time runs out, the map change will occur in this many seconds.",
		1),

	Warns = CreateConVar("autorestart_warnings", "60 / 30 / 15 / 5 / 2 / 0", FCVAR_ARCHIVE,
		"Warn about automatic restarts X minutes before it happens.\n" ..
		"Can be delimited to produce multiple warnings\n" ..
		"(ie \"5,2,1\" will warn 5 minutes before restart, 2 minutes and 1 minute)\n" ..
		"Any non-number and non-dot character will be treated as a delimiter."),

	HardRestart = CreateConVar("autorestart_hardreset", 0, FCVAR_ARCHIVE,
		"Instead of simply changing the map, quits the server outright (by using `_restart`).\n" ..
		"Not recommended, since a map change resets CurTime() (the source of jank on long-running servers),\n" ..
		"so only set this if you know what you're doing.")
}

AutoRestart.WarningTimes = {}
AutoRestart.RestartTime = math.huge -- in seconds

function AutoRestart.ParseWarnTimes(str)
	if #str == 0 then
		table.Empty(AutoRestart.WarningTimes)
	end

	local new = {}
	for numStr in str:gmatch("([%d%.]+)[^%d%.]*") do
		new[#new + 1] = tonumber(numStr)
	end

	AutoRestart.WarningTimes = new

	-- force ascending order
	table.sort(new, function(a, b) return a > b end)
end

local logCol = Color(90, 160, 90)
local errCol = Color(230, 150, 150)
local warnCol = Color(255, 210, 65)
local texCol = Color(210, 210, 210)

function AutoRestart.Log(...)
	MsgC(logCol, "[AutoRestart] ", ...)
end

function AutoRestart.LogN(...)
	local t = {...}
	t[#t + 1] = "\n"

	return AutoRestart.Log(unpack(t))
end

function AutoRestart.ParseRestartTime(str)
	local strNum = str:match("[%.%d]+") -- try to extract a number regardless of formatting errors

	local num = tonumber(strNum or "")
	if not num then -- couldn't get ANY number
		AutoRestart.LogN(
			errCol, "Invalid restart time set: \"",
				texCol, str,
			errCol, "\" can't be interpreted as a number!"
		)

		return
	end

	if strNum ~= str then -- provided string isn't the same as extracted number
		AutoRestart.LogN(
			warnCol, "Invalid restart time format: \"",
				texCol, str,
			warnCol, "\" interpreted as \"",
				texCol, tostring(num) .. " minutes\"",
			warnCol, "."
		)
	else
		AutoRestart.LogN(texCol, "Set restart time to ",
			warnCol, ("%s minutes."):format(num))
	end

	AutoRestart.RestartTime = num * 60
end


cvars.AddChangeCallback(AutoRestart.Convars.Warns:GetName(), function(name, old, new)
	AutoRestart.ParseWarnTimes(new)
end)

cvars.AddChangeCallback(AutoRestart.Convars.Time:GetName(), function(name, old, new)
	AutoRestart.ParseRestartTime(new)
end)

AutoRestart.ParseWarnTimes(AutoRestart.Convars.Warns:GetString())
AutoRestart.ParseRestartTime(AutoRestart.Convars.Time:GetString())

local ct = CurTime()

function AutoRestart.GetNextRestart()
	return math.max(0, AutoRestart.RestartTime - ct)
end

function AutoRestart.GetWarningFormat(left)
	local fmt = hook.Run("AutoRestart_GetWarningFormat", left)
	if fmt then return fmt end

	fmt = {
		Color(255, 70, 255), "[SERVER] ",
	}

	local GRAMMER = "minute" .. (left == 1 and "" or "s")

	if left < 1 then
		left = math.Round(left * 60)
		GRAMMER = "second" .. (left == 1 and "" or "s")
	end

	if left > 5 then
		table.Add(fmt, {
			texCol, ("Automatic server restart in %d %s!"):format(left, GRAMMER)
		})
	elseif left > 0 then
		-- restart soon:tm:
		table.Add(fmt, {
			texCol, "Automatic server restart in ",
			warnCol, ("%s %s"):format(left, GRAMMER),
			texCol, "!"
		})
	else
		-- restart right now
		table.Add(fmt, {
			texCol, "Automatic server restart",
			Color(230, 100, 100), " IMMINENT!",
		})
	end

	return fmt
end

function AutoRestart.GetChangeFormat(toMap)
	local fmt = hook.Run("AutoRestart_GetChangeFormat", left)
	if fmt then return fmt end

	if toMap then
		fmt = {
			Color(255, 70, 255), "[SERVER] ",
			texCol, "Changing map to ",
			logCol, toMap,
			texCol, (" in %d seconds!"):format(AutoRestart.GetCountdownTime())
		}
	else
		fmt = {
			Color(255, 70, 255), "[SERVER] ",
			warnCol, ("Shutting down in %d seconds!"):format(AutoRestart.GetCountdownTime())
		}
	end

	return fmt
end

function AutoRestart.GetCountdownTime()
	return math.Clamp(AutoRestart.Convars.TimeCountdown:GetInt() or 0, 1, 30)
end

function AutoRestart.AnnounceWarning(left)
	local fmt = AutoRestart.GetWarningFormat(left)
	hook.Run("AutoRestart_AnnounceWarning", fmt)

	AutoRestart.ChatAddText(unpack(fmt))
	AutoRestart.LogN(unpack(fmt))
end

function AutoRestart.AnnounceChange(toMap)
	local fmt = AutoRestart.GetChangeFormat(toMap)
	hook.Run("AutoRestart_AnnounceChange", fmt)

	AutoRestart.ChatAddText(unpack(fmt))
	AutoRestart.LogN(unpack(fmt))
end

function AutoRestart.Poll()
	ct = CurTime()

	local left_seconds = AutoRestart.GetNextRestart()
	local left_minutes = left_seconds / 60

	-- Pop warn times off the stack, but only actually warn using the last popped one
	local next_warn = AutoRestart.WarningTimes[1]
	local toWarn

	while next_warn and left_minutes < next_warn do
		toWarn = next_warn

		table.remove(AutoRestart.WarningTimes, 1)
		next_warn = AutoRestart.WarningTimes[1]
	end

	if toWarn then
		AutoRestart.AnnounceWarning(toWarn)
	end

	if left_seconds <= 0 then
		AutoRestart.BeginRestart()
	end
end

function AutoRestart.BeginRestart()
	if AutoRestart.RestartImminent then return end -- already in the process

	AutoRestart.RestartImminent = true

	local map
	local goes_hard = AutoRestart.Convars.HardRestart:GetBool()

	if not goes_hard then
		map = hook.Run("AutoRestart_PickMap") or game.GetMap()
	end

	AutoRestart.AnnounceChange(map)

	-- Good place to refund crap 'n all that
	hook.Run("AutoRestart_RestartImminent")

	-- NOW is when we have to do anti-hibernation hooey
	-- Also, FWIW, SysTime() isnt affected by host_timescale
	local beganWhen = SysTime()
	local toWait = AutoRestart.GetCountdownTime()

	timer.Create("ar_AutoRestartCountdown",
		0, 0,
		function()
			if SysTime() - beganWhen < toWait then return end

			AutoRestart.RestartImminent = false

			-- Opportunity to kick players with a custom reason or kill the server your own way
			hook.Run("AutoRestart_RestartNow")

			if goes_hard then
				RunConsoleCommand("_restart")
			else
				RunConsoleCommand("changelevel", map)
			end
		end)
end

timer.Create("AutoRestart_Poll", 1, 0, function()
	AutoRestart.Poll()
end)