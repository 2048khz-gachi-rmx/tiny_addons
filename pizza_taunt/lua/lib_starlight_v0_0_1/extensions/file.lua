Starlight.SetIncluded()
local gm = gmod.GetGamemode()
function file.Here(lv)
	lv = lv or 2
	local source = debug.getinfo(lv).source

	return source:match(".+/lua/(.+/).+%.lua") or
		source:match("gamemodes/" .. gm.FolderName .. "/(.+/).+%.lua")
end

function file.Me(lv)
	lv = lv or 2
	local source = debug.getinfo(lv).source

	return source:match(".+/lua/.+/(.+%.lua)") or
		source:match("gamemodes/" .. gm.FolderName .. "/.+/(.+%.lua)")
end

function file.PathToMe(lv)
	lv = lv or 2
	local source = debug.getinfo(lv).source

	return source:match(".+/lua/(.+/.+%.lua)") or
		source:match("gamemodes/(" .. gm.FolderName .. "/.+/.+%.lua)")
end

local sep = "/\\"
local setsep = "[" .. sep .. "]"
function file.GetFile(path)
	local fn = path:match("[^" .. sep .. "]+$")
	return fn, fn:match("%.(%w+)$")
end

-- adds an / at the end if there isn't one
function file.GetPath(path)
	local ret, fl = path:match("(.+" .. setsep .. ")(.+)")
	ret = ret or ""
	if fl and fl:match(setsep .. "$") then ret = ret .. fl end

	if #ret > 0 and ret:sub(-1) ~= "/" then ret = ret .. "/" end

	return ret
end

function file.GetPathTable(path)
	local ret = {}
	local len = 0
	for f in path:gmatch("[^" .. sep .. "]+") do
		len = len + 1
		ret[len] = f
	end
	return ret, len
end

function file.HasInPath(path, fld, ptrn)
	for f in path:gmatch("[^" .. sep .. "]+") do
		if ptrn then
			if f:match(fld) then
				return true
			end
		else
			if f == fld then
				return true
			end
		end
	end

	return false
end

function file.ForEveryFile(path, where, func, recurse)
	local wildcard = path:match("[^" .. sep .. "]+$") or "*"
	local path = file.GetPath(path)

	if isfunction(where) then
		recurse = func
		func = where
		where = "LUA"
	end

	local files, folders = file.Find(path .. wildcard, where)

	for k,v in ipairs(files) do
		local full_path = path .. v
		func(full_path)
	end

	if recurse ~= false then
		for k,v in ipairs(folders) do
			file.ForEveryFile(path .. v .. "/" .. wildcard, where, func, true)
		end
	end
end

function file.ForEveryFolder(path, func)

end

function file.ForEvery(path, func)

end