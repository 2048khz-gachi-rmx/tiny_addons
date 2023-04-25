Starlight.SetIncluded()

function eachNewline(s) --meant to be used as 'for s in eachNewline(tx) do...'
	local ps = 0
	local st, e
	local i = 0

	return function()
		st, e = s:find("[\r\n]", ps)
		i = i + 1

		if st then
			local ret = s:sub(ps, st - 1)
			ps = e + 1
			return ret, i
		elseif ps <= #s then
			local ret = s:sub(ps)
			ps = #s + 1
			return ret, i
		end
	end
end

function eachMatch(s, match)
	local ps = 0
	local st, e
	local i = 0

	return function()
		st, e = s:find(match, ps)
		i = i + 1

		if st then
			local ret = s:sub(ps, st - 1)
			ps = e + 1
			return ret, s:sub(st, e)
		elseif ps <= #s then
			local ret = s:sub(ps)
			ps = #s + 1
			return ret --, s:sub(st, e)
		end
	end
end

function amtNewlines(s)
	return select(2, s:gsub("[\r\n]", ""))
end

function printf(s, ...)
	print(s:format(...))
end

function errorf(s, ...)
	return error(s:format(...), 2)
end

function errorNHf(s, ...)
	return ErrorNoHaltWithStack(s:format(...))
end

ErrorNoHaltf = errorNHf
errorNHF = errorNHf

function assertf(cond, err, ...)
	if not cond then
		if not err then err = "assertion failed!" end
		errorf(err, ...)
	end
end

function assertNHf(cond, err, ...)
	if not cond then
		if not err then err = "assertion failed!" end
		errorNHf(err, ...)

		return false
	end

	return true
end