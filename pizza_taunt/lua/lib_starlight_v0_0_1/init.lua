AddCSLuaFile()

local libTbl = Starlight

-- very hacky, yea?
local is_dev = system.IsWindows() and file.Exists("is_dev", "DATA")
if SERVER then
	SetGlobalBool("is_dev_sv", is_dev)
end

function game.IsDev()
	if CLIENT then return GetGlobalBool("is_dev_sv", false) end
	return system.IsWindows() and is_dev
end

function game.GetServerID()
	return game.IsDev() and "dev" or "live - EU"
end

PLAYER = FindMetaTable("Player")
ENTITY = FindMetaTable("Entity")
PANEL = FindMetaTable("Panel")
WEAPON = FindMetaTable("Weapon")

local root = libTbl.RootFolder

local _CL = 1
local _SH = 2
local _SV = 3
local _NONE = 4

local loading = true

local includes = {
	[_CL] = function(name, noInclude)
		if SERVER then
			AddCSLuaFile(name)
		elseif not noInclude and not name:match("_ext") then
			include(name)
		end
	end,

	[_SH] = function(name, noInclude)
		AddCSLuaFile(name)
		if not noInclude and not name:match("_ext") then include(name) end
	end,


	[_SV] = function(name, noInclude)
		if noInclude or name:match("_ext") then return end
		include(name)
	end,

	[_NONE] = function() end,
}

-- Not a very good practice to set inclusion realms like that here but oh well...?
local realmExclusive = {
	["mysql_emitter.lua"] 			= _SV,
	["sql_arglist.lua"] 			= _SV,
	["rtpool.lua"] 					= _CL,
	["networkable_sv_ext.lua"] 		= _NONE,
	["binds_ext_sv.lua"] 			= _NONE,
	["networkable_cl_ext.lua"] 		= _CL,
	["chat.lua"] 					= _CL,
	["render.lua"] 					= _CL,
}

libTbl.Included = {} -- not auto-refresh friendly on purpose; allows reloading everything

function libTbl.SetIncluded(who)
	local src = who
	if not who then
		local path = debug.getinfo(2).source
		src = path
		who = path:match("/?([^/]+/[^/]+%.lua)$") -- matches highest folder + file
	end

	if not who then
		ErrorNoHaltf("Failed to resolve path `%s`.", src)
		return
	end

	libTbl.Included[who] = true
end

local including = {}

function libTbl.IncludeIfNeeded(who)
	local path = root .. who
	if including[who] then
		errorNHf("Recursive inclusion? Crisis averted (attempted to include %s)", who)
		return false
	end

	if libTbl.Included[who] then return false end

	including[who] = true

	libTbl.SetIncluded(who) -- set as included before including to avoid infinite loops
	include(path)

	including[who] = nil

	return true
end

local coreFileCount = 0

local function IncludeFolder(name, realm, nofold)
	local file, folder = file.Find( name, "LUA" )

	local pathname = name:match("(.+/).+")

	--[[
		Include all found lua files
	]]
	for k,v in pairs(file) do
		if not v:match(".+%.lua$") then continue end --if file doesn't end with .lua, ignore it
		local name = pathname .. v

		if realmExclusive[v] then
			includes[realmExclusive[v]] (name)
			continue
		end

		if loading then
			coreFileCount = coreFileCount + 1
		end

		local incCheck = name:match("([^/]+/[^/]+%.lua)$")

		-- don't re-include files set via libTbl.SetIncluded
		if libTbl.Included[incCheck] then
			includes[realm] (name, true)
			continue
		end

		if includes[realm] then
			includes[realm] (name)
		else
			ErrorNoHalt("Could not include file " .. name .. "; fucked up realm?\n")
			continue
		end

	end

	--[[
		Recursively add folders
	]]

	if not nofold then
		for k,v in pairs(folder) do
			IncludeFolder(pathname .. v .. "/*", realm)
		end
	end

end

--[==================================[
	Make a bunch of util functions
	for convenient inclusion
	(dependencies, game states, etc)
--]==================================]

local initCallbacks = {}

function libTbl.OnInitEntity(cb, ...)
	if EntityInitted then
		cb(...)
	else
		initCallbacks[#initCallbacks + 1] = {cb, ...}
	end
end

hook.Add("InitPostEntity", "InittedGlobal", function()
	EntityInitted = true

	for _, v in ipairs(initCallbacks) do
		v[1](unpack(v, 2))
	end

	initCallbacks = {}
end)

libTbl.LoadedDeps = libTbl.LoadedDeps or {}
libTbl.DepsCallbacks = libTbl.DepsCallbacks or {}

libTbl.Ready = libTbl.Ready or {}
libTbl.ReadyCallbacks = libTbl.ReadyCallbacks or {}


function libTbl.OnLoaded(file, cb, ...)
	if libTbl.LoadedDeps[file] then
		cb(...)
	else
		local t = libTbl.DepsCallbacks[file] or {}
		libTbl.DepsCallbacks[file] = t
		t[#t + 1] = {cb, ...}
	end
end

function libTbl.ListenReady(id, cb, ...)
	if libTbl.Ready[id] then
		cb(...)
	else
		local t = libTbl.ReadyCallbacks[id] or {}
		libTbl.ReadyCallbacks[id] = t
		t[#t + 1] = {cb, ...}
	end
end

function libTbl.MarkReady(id)
	if libTbl.ReadyCallbacks[id] then
		for k,v in ipairs(libTbl.ReadyCallbacks[id]) do
			v[1](unpack(v, 2))
		end

		libTbl.ReadyCallbacks[id] = nil
	end

	libTbl.LoadedDeps[id] = true
end

--[==================================[
	Include core files:
		1. Base `Class` object
		2. Library extensions
		3. Classes
		4. Libraries
			4.1. Third-party libraries
--]==================================]

include(root .. "classes.lua") -- base class goes first

local t1 = SysTime()

-- then we include everything

IncludeFolder(root .. "extensions/*", _SH) -- then extensions
IncludeFolder(root .. "classes/*", _SH)

IncludeFolder(root .. "libraries/*.lua", _SH)
IncludeFolder(root .. "libraries/client/*", _CL)
IncludeFolder(root .. "libraries/server/*", _SV)

IncludeFolder(root .. "thirdparty/*.lua", _SH)
IncludeFolder(root .. "thirdparty/client/*", _CL)
IncludeFolder(root .. "thirdparty/server/*", _SV)

loading = false

-- that is NOT supposed to happen
if not FInc then
	error("Starlight: FInc is missing...?")
end

local t2 = SysTime()


--[==================================[
		Include dependencies
--]==================================]

local function onLoad(s)
	if not s then
		s = debug.getinfo(2).short_src -- try to resolve path...?
	end

	--printf("Loaded %s %s %.2fs. after start...", s, Realm(true, true), SysTime() - s1)
	local fn = file.GetFile(s)

	if libTbl.DepsCallbacks[fn] then
		for k,v in ipairs(libTbl.DepsCallbacks[fn]) do
			v[1](unpack(v, 2))
		end

		libTbl.DepsCallbacks[fn] = nil
	end

	libTbl.LoadedDeps[fn] = true
end

libTbl.MarkLoaded = onLoad

local inc = FInc.RealmResolver():SetDefault(true)

local function shouldInc(fn)
	if fn:match("/cl_") or fn:match("/sh_") or fn:match("/sv_") then return false, false end
	return inc(fn)
end


local deps_t1 = SysTime()

hook.Run("Starlight", libTbl)

local extFiles = FInc.GetCounters()
local depFiles = 0

do
	local path = libTbl.ExtensionsFolder:gsub("/$", "")
		FInc.Recursive(path .. "/sh_*.lua", _SH, nil)
		FInc.Recursive(path .. "/*.lua", _SH, shouldInc)
		FInc.Recursive(path .. "/cl_*.lua", _CL, nil)
		FInc.Recursive(path .. "/sv_*.lua", _SV, nil)
		FInc.Recursive(path .. "/client/*", _CL, nil)
		FInc.Recursive(path .. "/server/*", _SV, nil)

	depFiles = extFiles
	extFiles = FInc.GetCounters() - extFiles

	path = libTbl.DependenciesFolder:gsub("/$", "")
		FInc.Recursive(path .. "/sh_*.lua", _SH, nil, onLoad)
		FInc.Recursive(path .. "/*.lua", _SH, shouldInc, onLoad)
		FInc.Recursive(path .. "/cl_*.lua", _CL, nil, onLoad)
		FInc.Recursive(path .. "/sv_*.lua", _SV, nil, onLoad)
		FInc.Recursive(path .. "/client/*", _CL, nil, onLoad)
		FInc.Recursive(path .. "/server/*", _SV, nil, onLoad)

	depFiles = FInc.GetCounters() - depFiles
end


local deps_t2 = SysTime()


--[==================================[
	Spew out a fancy text of info
		  because its COOL
--]==================================]

local l1 	= 	"Starlight"
local l2 	= 	"Core (%d files) ran in %.2fs."
local l3 	= 	"Dependencies (~%d files) ran in %.2fs."

l2 = l2:format(coreFileCount + extFiles, t2 - t1)
l3 = l3:format(depFiles, deps_t2 - deps_t1)

local longest_line = math.ceil(math.max(#l1, #l2, #l3) / 2) * 2 + 2

local function calcWidth(tx)
	local amt1 = math.floor( (longest_line - #tx) / 2 )
	local amt2 = math.ceil( (longest_line - #tx) / 2 )
	local spaces1 = (" "):rep(amt1)
	local spaces2 = (" "):rep(amt2)

	return spaces2 .. tx .. spaces1
end

local top = "□" .. ("―"):rep(longest_line) .. "□"
local bottom = "□" .. ("―"):rep(longest_line) .. "□"

local gray = Color(180, 180, 180)

MsgC("\n",
	Starlight.MainColor, top, "\n",
	Starlight.MainColor, "|", Starlight.MainColor, calcWidth(l1):gsub("%s%s(%S+)", "* %1"), Starlight.MainColor, "|\n",
	Starlight.MainColor, "|", gray, calcWidth(l2), Starlight.MainColor, "|\n",
	Starlight.MainColor, "|", gray, calcWidth(l3), Starlight.MainColor, "|\n",
	Starlight.MainColor, bottom, "\n\n")