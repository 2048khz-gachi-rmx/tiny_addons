AddCSLuaFile()

BlankFunc = function() end
BLANKFUNC = BlankFunc

Class = {}
Class.__isobject = true

local Class = Class
local rawget = rawget
local ipairs = ipairs
local type = type
local setmetatable = setmetatable

Class.__index = Class
Class.Meta = {__index = Class}

--[[
	Inheritance table:
		Don't add methods to Object/Class this unless you know what you're doing.

		Class:extend():
			The new derived class,

			The .Meta key is the metatable for the class you get, so if you wanna change metamethods for _the class itself_ instead of its' instances,
			then do it in its' .Meta
--]]

local metamethods = {

	--metamethods (except __index) aren't inherited

	"__newindex",
	"__mode",
	"__concat",
	"__call",
	"__tostring"

	-- cba with math metamethods
}

local recursiveExtend = function(new, old, ...)
	-- we want OnExtend's to go from oldest to newest, so
	-- we'll store the chain and iterate in reverse order
	local chain, i = {new}, 1
	local prev = old --provided `old` is merely the parent from which it got extended

	while old do
		i = i + 1
		chain[i] = old
		old = old.__parent
	end

	for i2=i, 1, -1 do --iterate in reverse order, from oldest to newest
		local obj = chain[i2]
		local onExt = rawget(obj, "OnExtend")
		if onExt then
			onExt(prev, new, ...)
		end
	end
end

function Class:CopyMetamethods(old)
	for k,v in ipairs(metamethods) do
		self[v] = rawget(old, v)
	end
end

function Class:AliasMethod(method, ...)
	if type(method) ~= "function" then errorf("arg #1 is not a function (got %q)", type(method)) return end

	for k,v in ipairs({...}) do
		self[v] = method
	end
end

function Class:extend(...)
	local old = self

	local new = {}
	new.Meta = {}
	new.Meta.__index = old 				-- this time, __index points to the the parent
										-- which points to that parent's meta, which points to that parent's parent, so on
	Class.CopyMetamethods(new, old)

	-- setmetatable(new.Meta, old)
	setmetatable(new, new.Meta)

	new.__index = new
	new.__parent = old
	new.__super = old
	new.__instance = new
	new.__isobject = true

	local curobj

	new.__init = function(newobj, ...)
		local is_def = false

		curobj = newobj

		if newobj.__instance == new then
			is_def = true
		end

		if self.__init and rawget(new, "AutoInitialize") ~= false then 	--recursively call the parents' __init's
			local ret = self.__init(curobj, ...)		--if any of the initializes return a new object,
			curobj = ret or curobj						--that object will be used forward going up the chain
		end

	  --[[------------------------------]]
	  --	  calling :Initialize()
	  --[[------------------------------]]

		local func = rawget(new, "Initialize")	--after the oldest __init was called it'll start calling :Initialize()
												--this way we call :Initialize() starting from the oldest one and going up to the most recent one

		if func then
			local ret = func(curobj, ...)		--returning an object from any of the Initializes will use
			curobj = ret or curobj 				--that returned object on every initialize up the chain
		end

		if is_def then
			local temp = curobj 	--return curobj to original state
			curobj = nil

			return temp
		end

		return curobj
	end

	recursiveExtend(new, old, ...)

	return new
end

function Class:callable(...)
	local new = self:extend(...)
	new.Meta.__call = new.new
	return new
end
Class.Callable = Class.callable

--[[
	For override:
		Class:(I/i)nitialize:
			Called when a new instance of the object is constructed with a pre-created object.
]]

function Class:new(...)
	local func = rawget(self, "__init")
	if not func then
		errorf("Can't create an object from an instance!")
		return
	end

	local obj = setmetatable({}, self)

	if func then
		local new = func(obj, ...)
		if new then return new end
	end

	return obj

end

Class.extend = Class.extend
Class.Extend = Class.extend

Class.Meta.new = Class.new

Object = Class


function ChainAccessor(t, key, func, no_override)

	if not no_override or not t["Get" .. func] then
		t["Get" .. func] = function(self)
			return self[key]
		end
	end

	if not no_override or not t["Set" .. func] then
		t["Set" .. func] = function(self, val)
			self[key] = val
			return self
		end
	end

end