Starlight.SetIncluded()

Starlight.TypeCheckers = Starlight.TypeCheckers or {}

function IsPlayer(ent)
	if type(ent) ~= "Player" or not IsValid(ent) then return false end
	return true
end

Starlight.TypeCheckers[isangle] 		= "Angle"
Starlight.TypeCheckers[ismatrix] 		= "VMatrix"
Starlight.TypeCheckers[ispanel] 		= "Panel"
Starlight.TypeCheckers[isentity] 		= "Entity"
Starlight.TypeCheckers[IsPlayer] 		= "Player"
Starlight.TypeCheckers[isvector] 		= "Vector"

Starlight.TypeCheckers[isnumber] 		= "number"
Starlight.TypeCheckers[isstring] 		= "string"
Starlight.TypeCheckers[istable] 		= "table"
Starlight.TypeCheckers[isfunction] 	= "function"
Starlight.TypeCheckers[isbool] 		= "boolean"

function CheckArg(num, arg, check, expected_type)
	if check == true or check == false then
		if check then return end

		local err = (expected_type and
			("expected '%s', got '%s' (%s) instead"):format(expected_type, type(arg), arg)
			or ("failed check function on '%s' (%s)"):format(type(arg), arg)
		)

		errorf("bad argument #%d (%s)", num, err)
	elseif isfunction(check) then
		if not check(arg) then
			expected_type = expected_type or Starlight.TypeCheckers[check]

			local err = (expected_type and
				("expected '%s', got '%s' (%s) instead"):format(expected_type, type(arg), arg)
				or ("failed check function on '%s' (%s)"):format(type(arg), arg)
			)
			errorf("bad argument #%d (%s)", num, err)
		end
	elseif isstring(check) then
		if type(arg) ~= check then
			local err = ("expected '%s', got '%s' (%s) instead")
				:format(expected_type or check, type(arg), arg)

			errorf("bad argument #%d (%s)", num, err)
		end
	end
end

function RegisterTypeCheck(fn, name)
	CheckArg(1, fn, isfunction) -- heh
	CheckArg(2, name, isstring)

	Starlight.TypeCheckers[fn] = name
end

function ComplainArg(num, wanted, got)
	errorf("bad argument #%d (expected '%s', got '%s' instead)", num, wanted, got)
end

function util.gary()
	error("gary")
end

local errorers = {}

-- nohalt run: will throw an ErrorNoHalt
function GenerateErrorer(err)
	if errorers[err] then
		return errorers[err]
	end

	local fmt = tostring(err) .. " error: %s\n%s\n"

	errorers[err] = function(err)
		return ErrorNoHalt(fmt:format(err, debug.traceback("", 2)))
	end

	return errorers[err]
end

function gpcall(name, fn, ...)
	return xpcall(fn, GenerateErrorer(name), ...)
end