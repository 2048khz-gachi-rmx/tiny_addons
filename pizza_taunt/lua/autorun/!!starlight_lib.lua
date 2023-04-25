Starlight = Starlight or {}
Starlight.Name 		= "starlight"
Starlight.Version 	= "0.0.1"

Starlight.DependenciesFolder 	= "sl_deps"
Starlight.ExtensionsFolder 		= "sl_exts"

Starlight.MainColor = Color(50, 150, 255)

local libTbl = Starlight

function libTbl.NumToSemver(n)
	local frac = ("%.8f"):format(n):match("%.(%d?%d-)0*$") -- eels

	return ("%d.%d.%s"):format(
		bit.rshift(math.floor(n), 16),    -- top 16 bits of uint32 representation
		bit.band(math.floor(n), 0xFFFF),  -- bottom 16 bits of uint32 representation
		frac)
end

function libTbl.SemverToNum(ver)
	if type(ver) == "number" then return ver end

	local maj, min, rev = ver:match("(%d+).(%d+).(%d+)")
	if not maj or not min or not rev then errorf("`%s` is not a semver", ver) return end

	maj, min = tonumber(maj), tonumber(min)
	if maj > 65535 or min > 65535 or #rev > 6 then errorf("`%s`: your semvers are too strong for me traveller", ver) return end

	return bit.lshift(maj, 16)
		+ min
		+ tonumber("0." .. rev) -- ashuduiayf
end

-- if `to` isn't provided, it's assumed to be lib version
-- -1 = `what` is older than `to`
-- 0 = `what` == `to`
-- 1 = `what` is newer than `to`

function libTbl.CompareVersion(what, to)
	local n1, n2 = libTbl.SemverToNum(what), libTbl.SemverToNum(to or libTbl.Version)

	if n1 > n2 then return 1 end
	if n1 < n2 then return -1 end

	return 0
end

libTbl.VersionNum 	= libTbl.SemverToNum(libTbl.Version)

assert( libTbl.NumToSemver(libTbl.SemverToNum(libTbl.Version)) == libTbl.Version )
assert( libTbl.VersionNum > libTbl.SemverToNum("0.0.0") )
assert( libTbl.VersionNum < libTbl.SemverToNum("999.0.0") )

local root = "lib_starlight_v"
local _, folders = file.Find(root .. "*", "LUA")
local curMax = libTbl.Version

for _, v in pairs(folders) do
	local ver = v:match("_v([%d_]+)$"):gsub("_", ".")

	if libTbl.SemverToNum(curMax) < libTbl.SemverToNum(ver) then
		curMax = ver
	end
end

root = root .. curMax:gsub("%.", "_")
root = root .. "/"

libTbl.RootFolder = root

include(root .. "init.lua")