Starlight.SetIncluded()
Starlight.IncludeIfNeeded("extensions/file.lua")

FInc = FInc or {} --Fast Inclusion

-- todo: stop using these
_CL = 1
_SH = 2
_SV = 3

FInc.CLIENT = 1
FInc.SHARED = 2
FInc.SERVER = 3

FInc.CLIENT_ADD = 100

local incCnt, addCnt = 0, 0
function FInc.GetCounters()
	return incCnt, addCnt
end

local inc = include
local function include(...)
	incCnt = incCnt + 1
	return inc(...)
end

local includes = {
	[FInc.CLIENT] = function(name, should)
		-- always add to CSLua,
		-- don't include clientside if should = false or 1
		-- 1 because extensions shouldnt be autoincluded

		if SERVER then
			AddCSLuaFile(name)
		else
			if should == false or should == 1 then return end
			return include(name)
		end
	end,

	[FInc.SHARED] = function(name, cl, sv)
		--cl = false : file doesn't get AddCSLua'd + not included clientside
		--cl = 1     : file gets only AddCSLua'd but not included
		--sv = false : file is not loaded but can be AddCSLua'd

		if cl ~= false then AddCSLuaFile(name) end

		if (sv ~= false and SERVER) or
			(cl ~= false and cl ~= 1 and CLIENT) then
			return include(name)
		end
	end,


	[FInc.SERVER] = function(name, should)
		if not SERVER or should == false then return end
		return include(name)
	end,

	[FInc.CLIENT_ADD] = function(name, should)
		if should == false then return end
		AddCSLuaFile(name)
	end
}

local needToInclude = {
	[1] = {[CLIENT] = true, [FInc.CLIENT] = true, [FInc.SHARED] = true, [FInc.SERVER] = false, [FInc.CLIENT_ADD] = true},
	[2] = {[SERVER] = true, [FInc.CLIENT] = true, [FInc.SHARED] = true, [FInc.SERVER] = true, [FInc.CLIENT_ADD] = true}
	--even though server's _CL should be false it's actually true because the server needs to AddCSLua
}

local function Realm()
	return CLIENT and 1 or 2
end

local function NeedToInclude(realm)
	local out = needToInclude[Realm()][realm]
	if out == nil then
		errorNHf("Unresolved realm: %s -> %s", CLIENT and "Client" or "Server", realm)
	end

	return out
end

FInc.IncludeRealms = includes

local BlankFunc = function() end

--callback:
--when _SV or _CL, return false to prevent including and addcslua'ing (when _CL)

--when _SH,
-- 1st return: 	if false, doesn't get AddCSLua'd and included clientside
-- 				if 1    , gets AddCSLua'd but not included clientside
-- 2nd return: if false, doesn't include serverside

-- if both returns are `false`, regardless of realm it'll just not do anything at all


-- mfw searching a folder takes 200ms
-- vfs was a mistake
FInc.CachedSearches = FInc.CachedSearches or {}
local cached_searches = FInc.CachedSearches
local including = 0

function FInc.Including()
	return including > 0, including
end

function FInc.IncludeFile(name, realm, decider, callback)
	if not NeedToInclude(realm) then return end
	decider = decider or BlankFunc
	callback = callback or BlankFunc

	if includes[realm] then
		local cl, sv = decider (name, realm)
		-- if we're dealing with _SV and the 2nd arg isn't nil,
		-- shift it to the 1st arg since the includers only take 1 arg for _CL/_SV
		if realm == _SV and sv ~= nil then
			cl = sv
		end

		includes[realm] (name, cl, sv)
		callback(name)
	else
		ErrorNoHalt("Could not include file " .. name .. "; fucked up realm?\n")
	end
end

local stack = {}
local unique = 0

function FInc.AbortRecurse(n)
	for i=1, n or 1 do
		stack[#stack] = nil
	end
end

function FInc.Recursive(name, realm, decider, callback)
	if not NeedToInclude(realm) then return end

	decider = decider or BlankFunc
	callback = callback or BlankFunc

	local curUq = unique
	local key = #stack + 1
	unique = unique + 1
	stack[key] = curUq

	including = including + 1

	local cache = (cached_searches[name] and CurTime() - cached_searches[name][1] < 0.2) and cached_searches[name]

	local files, folders

	if cache then
		files, folders = unpack(cache, 2)
	else
		files, folders = file.Find(name, "LUA", "nameasc")
		cached_searches[name] = {CurTime(), files, folders}
	end

	local path = name:match("(.+/).+$") or ""
	local wildcard = name:match(".+/(.+)$")

	for k,v in pairs(files) do
		if stack[key] ~= curUq then
			stack[#stack] = nil
			print("aborted recurse", name)
			return
		end

		if not v:match(".+%.lua$") then continue end --if file doesn't end with .lua, ignore it
		local inc_name = path .. v
		if inc_name:match("extensions/includes%.lua") then continue end --don't include yourself

		if includes[realm] then
			local cl, sv = decider (inc_name, realm, files)
			-- if we're dealing with _SV and the 2nd arg isn't nil,
			-- shift it to the 1st arg since the includers only take 1 arg for _CL/_SV
			if realm == _SV and sv ~= nil then
				cl = sv
			end

			includes[realm] (inc_name, cl, sv)
			callback(inc_name)
		else
			ErrorNoHalt("Could not include file " .. inc_name .. "; fucked up realm?\n")
			continue
		end

	end

	--if not nofold then
	if stack[key] == curUq then
		for k,v in pairs(folders) do

			-- path/ .. found_folder  .. /  .. wildcard_used
			-- muhaddon/newfolder/*.lua

			FInc.Recursive(path .. v .. "/" .. wildcard, realm, decider, callback)
		end
	else
		print("aborted folder reecurse", name)
	end
	--end

	including = including - 1
	stack[#stack] = nil
end

setmetatable(FInc, {__call = FInc.Recursive})

function FInc.NonRecursive(name, realm, decider, cb) --mhm
	name = (name:match("%.lua$") and name) or name .. ".lua"

	return FInc.Recursive(name, realm, decider, cb)
end

local svcol = Color( 70, 195, 255 )
local clcol = Color( 255, 200, 60 )

local incsvcol = Color( 137, 222, 255 )
local incclcol = Color( 255, 222, 102 )

local realmcol = SERVER and svcol or clcol

local function logInclusion(path, cl, sv, why, default)
	local reason = (why == -1 and "default-less extension-less") or
					(why == 0 and "extension") or
					(why == 1 and "default") or
					(why == 2 and "extension using default (addcslua'd: " .. tostring(not not default) .. ")") or
					(why == 3 and "resolved as '" .. tostring(not not default) .. "'")

									-- we can't differentiate between a cl-only extension and
									-- a shared extension which will be included manually

	local as_what = (cl == 1 and not sv and {color_white, "Shared/Client [unincluded, CS]"}) or
					(not cl and sv and {incsvcol, "Server [included, not CS]"}) or
					(cl and not sv and {incclcol, "Client [CL included]"}) or
					(cl and sv and {color_white, "Any [_CL/_SH/_SV]"}) or
					(not cl and not sv and {svcol, "None [unincluded, not CS]"})

	MsgC(realmcol, "Resolved ", path, " as ", as_what[1], as_what[2], realmcol, " (", reason, ")\n", color_white)
end

local function Resolve(res, path)
	local default = res.__DefaultRealm
	local verb = res.__Verbose

	local pt = file.GetPathTable(path)
	local fn = file.GetFile(path):gsub("%.lua", "")

	if not res.__Force then
		if fn:match("^_") then return false, false end -- _stuff.lua don't get included

		for k,v in ipairs(pt) do
			if v:match("^_") then
				return false, false
			end
		end
	end

	local is_sv = table.HasValue(pt, "server") or table.HasValue(pt, "sv") or false
	local is_cl = not is_sv and (table.HasValue(pt, "client") or table.HasValue(pt, "cl")) or false
	local is_sh = table.HasValue(pt, "shared") or table.HasValue(pt, "sh") or false

	-- failed matching by path; attempt matching by filename
	if not is_sv and not is_cl and not is_sh then
		is_sv = fn:match("^sv_.+") or fn:match(".+_sv$") or fn:match("_sv_") or false
		is_cl = fn:match("^cl_.+") or fn:match(".+_cl$") or fn:match("_cl_") or false
		is_sh = fn:match("^sh_.+") or fn:match(".+_sh$") or fn:match("_sh_") or false
	end

	-- extensions get included manually; do not include them
	-- folders can only have the full _extension name, not _ext

	local is_ext = (fn:match("_ext$") or fn:match("_extension$") or
			fn:match("^ext_.+") or fn:match("^extension_.+") or
			fn:match("_ext_") or path:match("_?extension_?")) and not res.__Extensions

	-- if we didn't pass cl/sv/sh path check...
	if not is_sv and not is_cl and not is_sh then
		-- and we weren't given a default realm...
		if default == nil then
			-- and it's not an extension, blame the user

			if not is_ext then
				ErrorNoHalt("Failed to resolve realm for file: " .. path .. ".\n")
			end
			-- if its an extension which didn't pass a realm check AND there's no default,
			-- it won't be addcslua'd
			if verb then
				logInclusion( path, false, false, is_ext and 0 or -1 )
			end
			return false, false
		else
			local out_cl, out_sv = default, default
			if isfunction(default) then
				out_cl, out_sv = default(path)

				if out_sv == nil then
					out_sv = out_cl
				end
			end

			if is_ext then
				if verb then
					logInclusion( path, out_cl and 1, false, 2, out_cl )
				end

				return out_cl and 1, false
			end

			if verb then
				logInclusion( path, out_cl, out_sv, 1, out_cl )
			end
			return out_cl, out_sv
		end
	end

	if is_ext then
		-- returning 1 for `cl` AddCSLua's it

		if verb then
			logInclusion( path, (is_cl or is_sh) and 1, false, 0 )
		end

		return (is_cl or is_sh) and 1, false
	end

	if verb then
		logInclusion( path, is_cl or is_sh, is_sv or is_sh, 3,
			(is_sh and "shared") or (is_cl and "client") or (is_sv and "server") )
	end

	return is_cl or is_sh, is_sv or is_sh
end

local Resolver = Object:extend()
Resolver.__call = Resolve

function Resolver:SetDefaultRealm(r)
	self.__DefaultRealm = r
	return self
end

Resolver:AliasMethod(Resolver.SetDefaultRealm, "DefaultRealm", "Default", "SetDefault", "Realm", "SetRealm")

function Resolver:SetVerbose(b)
	self.__Verbose = (b == nil and true) or b
	return self
end

Resolver:AliasMethod(Resolver.SetVerbose, "Verbose")

function Resolver:SetExtensions(b)
	self.__Extensions = (b == nil and true) or b
	return self
end

Resolver:AliasMethod(Resolver.SetExtensions, "Extensions", "AllowExtensions", "Extension")

function Resolver:SetForce(b)
	self.__Force = (b == nil and true) or b
	return self
end

Resolver:AliasMethod(Resolver.SetForce, "Forced")

local default_resolver = Resolver:new()

function FInc.RealmResolver(path)
	if isstring(path) then
		-- I mean, you _CAN_ use this function this way, but then you can't customize it
		return default_resolver(path)
	end

	return Resolver:new()
end

function FInc.FromHere(name, realm, decider, cb)
	if not NeedToInclude(realm) then return end

	local gm = engine.ActiveGamemode()

	--[[
		Gamemode lua files have a slightly different structure

		Whereas addons have
			[addonname]/lua/ ( [addon_folder_name]/... )
			[addonname]/lua/ ( [addon_lua_files] )
									^ what you need

		gamemodes have
			[gamemodename]/gamemode/*

		we can try matching gamemode first
	]]

	local where = debug.getinfo(2).source

	local search = "gamemodes/(%s/.+)" --we'll need to capture [gamemodename/gamemode/*]
	search = search:format(gm)

	local gm_where = where:match(search)

	if not gm_where then
		where = where:match(".+/[lua]*/(.+)") 	--addonname/lua/(addon_folder/...)
	else										--or addonname/lua/(addon_file.lua)
		if gm_where:match("/entities/") then
			where = gm_where:match("/entities/(entities/.+)")
		else
			where = gm_where
		end
	end

	if not where or where:sub(-4) ~= ".lua" then
		local err = "FInc.FromHere called from invalid path! %s\n"
		err = err:format(where)

		ErrorNoHalt(err)
		return
	end

	local path = where:match("(.+/).+%.lua$")	--get the path without the caller file

	if not path or #path < 1 then
		local err = "FInc.FromHere couldn't get source file! %s ; matched to %s\n"
		err = err:format(where, path)

		ErrorNoHalt(err)
		return
	end

	FInc.Recursive(path .. name, realm, decider, cb)
end


FInc._States = FInc._States or {
	-- good for checking eg `FInc.OnStates(print, CLIENT or "ServerOnlyState")
	[true] = true
}

FInc._StateCallbacks = FInc._StateCallbacks or {}

function FInc.OnStates(cb, ...)
	local states = {...}

	local ready = true

	for k,v in ipairs(states) do
		if not FInc._States[v] then ready = false break end
	end

	if ready then
		-- if all the states are set, just call the thing
		cb()
	else
		local key = #FInc._StateCallbacks + 1

		FInc._StateCallbacks[key] = function()
			for k,v in ipairs(states) do
				if not FInc._States[v] then return end
			end

			table.remove(FInc._StateCallbacks, key)
			cb()
		end

	end
end

function FInc.AddState(state)
	FInc._States[state] = true
	for k,v in ipairs(FInc._StateCallbacks) do
		v(state)
	end
end

FInc.SetState = FInc.AddState

function svinclude(...)
	if SERVER then include(...) end
end

function clinclude(...)
	if SERVER then
		AddCSLuaFile(...)
	else
		include(...)
	end
end