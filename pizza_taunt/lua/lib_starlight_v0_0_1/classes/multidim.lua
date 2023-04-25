if Starlight then Starlight.SetIncluded() end

--rip your RAM
local select, rawget, rawset
	= select, rawget, rawset

muldim = muldim or Class:callable()
if Starlight then Starlight.MulDim = muldim end
local weak = muldim:callable()
weak.__mode = "kv"

function muldim:Initialize(mode)
	if mode then
		if not mode == "k" or mode == "v" or mode == "kv" then
			errorf("muldim takes mode as `k` or `v` or `kv`, not %s (`%s`)", mode, type(mode))
		end
		return weak()
	end
end

function muldim:Get(...)
	local curvar = self

	for k=1, select("#", ...) do
		local v = select(k, ...)

		local nxt = rawget(curvar, v)
		if nxt == nil then return end
		curvar = nxt
	end

	return curvar
end

function muldim:GetOrSet(...)
	local curvar = self

	for k=1, select("#", ...) do
		local v = select(k, ...)

		if rawget(curvar, v) == nil then
			local new = muldim:new()
			rawset(curvar, v, new)
			curvar = new
		else
			curvar = rawget(curvar, v)
		end
	end

	return curvar
end

function muldim:Set(val, ...)
	local curvar = self
	local cachednext

	for k=1, select("#", ...) do
		local v = (cachednext ~= nil and cachednext) or select(k, ...)
		local nextkey = select(k + 1, ...)
		cachednext = nextkey

		local nextval = rawget(curvar, v)
		if nextval == nil then

			if nextkey ~= nil then --if next key in ... exists
				nextval = muldim:new()
				rawset(curvar, v, nextval) --recursively create new dim objects
			else
				rawset(curvar, v, val) --or just set the value
				return val, curvar
			end

		else

			if nextkey == nil then
				rawset(curvar, v, val)
				nextval = val
			end

		end

		curvar = nextval
	end

	return val, curvar
end

-- insert value at #tbl + 1, like table.insert
function muldim:Insert(val, ...)
	local curvar = self
	local cachednext

	for k=1, select("#", ...) do
		local v = (cachednext ~= nil and cachednext) or select(k, ...)
		local nextkey = select(k + 1, ...)
		cachednext = nextkey

		local nextval = rawget(curvar, v)

		if nextval == nil then

			if nextkey ~= nil then
				nextval = muldim:new()
				rawset(curvar, v, nextval)
			else
				nextval = muldim:new()
				rawset(curvar, v, nextval)
				rawset(rawget(curvar, v), 1, val)
				return val, curvar
			end

		else

			if nextkey == nil then
				local into = rawget(curvar, v)
				rawset(into, #into + 1, val)
			end

		end

		curvar = nextval
	end

	return val, curvar
end

function muldim:RemoveSeq(key, ...)
	local tbl = self:Get(...)
	if not tbl then return end

	table.remove(tbl, key)
end

function muldim:RemoveSeqValue(val, ...)
	local tbl = self:Get(...)
	if not tbl then return end

	for i = #tbl, 1, -1 do
		if tbl[i] == val then
			table.remove(tbl, i)
			break
		end
	end
end

function muldim:Remove(key, ...)
	local tbl = self:Get(...)
	if not tbl then return end

	local was = tbl[key]
	tbl[key] = nil

	return was
end

function muldim:RemoveValue(val, ...)
	local tbl = self:Get(...)
	if not tbl then return end

	for k,v in pairs(tbl) do
		if v == val then
			tbl[k] = nil
			break
		end
	end
end