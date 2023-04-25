if not Starlight.Emitter then include('emitter.lua') end

local cmdPrefix = "sl_"

Starlight.Binds = Starlight.Binds or {}
local Binds = Starlight.Binds

Binds.Data = Binds.Data or {}
Binds.Objects = Binds.Objects or {} -- [id] = bindObject
Binds.Keys = Binds.Keys or muldim:new()	-- [KEY_*][bind_ID] = bindObject
Binds.Concommands = Binds.Concommands or {}

function Binds.GetByName(name)
	return Binds.Objects[name]
end

local fileName = Starlight.Name .. "_binds.txt"

local comment = [[
Don't touch this unless you're confident you won't mess it up.

You may want to use this page: https://wiki.facepunch.com/gmod/Enums/KEY
]]

local function writeData()
	if SERVER then errorf("tried to write bind data serverside...?") return end

	local t = {}

	for line, num in eachNewline(comment) do
		if select(2, line:gsub("%w", "")) > 0 then
			line = "## " .. line
		end

		t[num] = line
	end

	t[#t + 1] = "\n\n"

	local dat = util.TableToJSON(Binds.Data, true)
	t[#t + 1] = dat

	file.Write(fileName, table.concat(t, "\n"))
end

local function readData()
	if SERVER then errorf("tried to read bind data serverside...?") return end

	local dat = file.Read(fileName, "DATA")

	if not dat then
		writeData()
		return
	end

	local json = {}

	for line, num in eachNewline(dat) do
		if line:match("^##") then continue end
		json[#json + 1] = line
	end

	local bindData = util.JSONToTable(table.concat(json))

	for k,v in pairs(bindData or {}) do
		Binds.Data[k] = Binds.BindData(unpack(v))
	end
end

Binds.WriteData = writeData
Binds.ReadData = readData

BINDS_TOGGLE = "TOGGLE"
BINDS_HOLD = "HOLD"

Binds.BindData = Binds.BindData or Object:callable()
local bindData = Binds.BindData

bindData[1] = KEY_NONE
bindData[2] = BINDS_TOGGLE

local key_whitelist = {
	Key = 1,
	Method = 2
}

bindData.__index = function(self, k)
	if isnumber(k) then return bindData[k] end

	k = key_whitelist[k] or -1
	return self[k] or bindData[k]
end

bindData.__newindex = function(self, k, v)
	if not isnumber(k) then
		if not key_whitelist[k] then errorf("%s is not a whitelisted non-number index.", k) return end
		rawset(self, key_whitelist[k], v)
		return
	end

	rawset(self, k, v)
end

function bindData:Initialize(k, m)
	self[1] = k
	self[2] = m
end

if CLIENT then
	readData()
end

local function cleanID(t, id)
	for i=#t, 1, -1 do
		if t[i].ID == id then
			table.remove(t, i)
		end
	end
end

Starlight.Bind = Starlight.Bind or Starlight.Emitter:callable()
local Bind = Starlight.Bind

function Bind:Initialize(id)
	assert(id, "Binds require an ID")

	self.ID = tostring(id)

	self.__States = {} -- [ply] = bool
	self.__BtnStates = {}

	self:SetValid(true)

	-- if an existing object for this ID already exists, just give that
	if Binds.Objects[id] then return Binds.Objects[id] end
	Binds.Objects[id] = self

	-- if we have data for that bindID (preferred key/method), set those automatically
	if Binds.Data[id] then
		local dat = Binds.Data[id]
		self :SetKey(dat.Key)
			:SetMethod(dat.Method)
		return
	end

	-- otherwise, create new data
	Binds.Data[id] = bindData:new()
	self:SetMethod(BINDS_HOLD)
end

function Bind:Remove()
	Binds.Data[self.ID] = nil
	if Binds.Objects[self.ID] == self then
		Binds.Objects[self.ID] = nil
	end

	local t = Binds.Keys[self.Key]
	if not t then return end


	for i=#t, 1, -1 do
		if t[i] == self then
			table.remove(t, i)
		end
	end

	self:SetValid(false)

	if SERVER then
		for k,v in ipairs(player.GetConstAll()) do
			Binds.Remap(v)
		end
	end
end

ChainAccessor(Bind, "_Valid", "Valid")
Bind:AliasMethod(Bind.GetValid, "IsValid")

function Bind:GetData()
	return Binds.Data[self.ID]
end

function Bind.IsValidKey(key, arg2)
	if istable(key) then key = arg2 end
	if not arg2 then return false end

	local name = input.GetKeyName(key)
	if not name then return false end

	if #name == 1 then return true end 				-- 1-letter binds are fine
	if name:match("^MWHEEL") then return false end 	-- mousewheel cant be a bind

	local mkey = tonumber(name:match("MOUSE(%d+)"))
	if mkey and mkey > 2 then return true end -- lmb/rmb cant be binds

	local fkey = tonumber(name:match("F(%d+)"))
	if fkey and fkey <= 4 then return false end -- F1-F4 cant be binds

	if key >= 64 and key <= 71 then
		return false -- control keys: enter, space, caps/scroll locks, etc.
	end

	if key >= 104 and key <= 106 then
		return false -- caps/scroll/num toggles
	end

	return true
end

-- exclusive means that bind and ONLY that bind will proc for this key
-- there can't be multiple exclusive binds on a key

-- there theoretically can be multiple binds and an exclusive bind,
-- but they just won't run

function Bind:GetExclusive()
	return self.Exclusive
end

function Bind:SetExclusive(b) --, prevent_default)	-- gmod sucks, cant prevent default lol
	if b == nil then b = true end

	if b and self.Key then
		for k,v in ipairs(Binds.Keys[self.Key]) do
			if v.Exclusive then
				return self, "There can't be multiple exclusive keys! (The other is " .. v.ID .. ")"
			end
		end
	end

	self.Exclusive = b
	return self
	--self.ExclusivePreventDefault = prevent_default
end


ChainAccessor(Bind, "Exclusive", "Exclusive", true)
ChainAccessor(Bind, "Key", "Key")
ChainAccessor(Bind, "ID", "ID")

function Bind:SetKey(k)
	assert(isnumber(k), "not a key")
	assertf(k < 65536 and k >= 0, "invalid key (%s isn't within [0-65535] range)", k)

	local prev = self.Key
	if prev == k then return self end --bruh

	self.Key = k

	if Binds.Keys[prev] then
		cleanID(Binds.Keys[prev], self.ID)
	end

	if k and Binds.Keys[k] then
		cleanID(Binds.Keys[k], self.ID)

		if self.Exclusive then
			for k,v in ipairs(Binds.Keys[self.Key]) do
				if v.Exclusive then
					return false, "There can't be multiple exclusive keys! (The other is " .. v.ID .. ")"
				end
			end
		end

	end

	Binds.Keys:Insert(self, k)

	self:GetData().Key = k

	self:Emit("KeyChanged", prev, k)
	hook.Run("BindKeyChanged", self, k)
	return self
end

function Bind:SetMethod(m)
	local prev = self.Method
	self.Method = m

	self:GetData().Method = m

	self:Emit("MethodChanged", prev, m)
	return self
end

function Bind:SetDefaultMethod(m)
	if not self.Method then
		self:SetMethod(m)
	end

	return self
end

function Bind:CreateConcommand(name)
	name = name or self.ID
	Binds.Concommands[name] = self
	return self
end

Bind:AliasMethod(Bind.CreateConcommand, "CreateConcommands")

function Bind:SetDefaultKey(k)
	if not self.Key then
		return self:SetKey(k)
	end

	return self
end

if CLIENT then

	-- only works on holdable binds
	function Bind:SetHeld(b)
		if self:GetSynced() then
			errorNHf("Can't force hold a synced bind -- that's not how it works.")
			return
		end

		local me = CachedLocalPlayer()
		local ac = self:GetActive(me)
		self.__KeepHeld = b

		if b then
			if ac then return end
			-- if we weren't active before, activate now
			self:_Fire(true, me)
		else
			-- if we were active before only because of the Held state,
			-- we disable ourselves ( otherwise we leave it to the user )
			if self:GetButtonState() == false and self:GetActive(me) then
				self:_Fire(false, me)
			end
		end
	end

end

function Bind:GetHeld()
	return not not self.__KeepHeld
end

ChainAccessor(Bind, "_CanPredict", "CanPredict")
ChainAccessor(Bind, "_Synced", "Synced")

function Bind:SetSynced(b)
	self._Synced = b
	if CLIENT and b and self:GetKey() then
		self:NWKey()
	end

	return self
end

-- the "custom" button state; can be influenced by addons (eg Bind:SetHeld(true))
function Bind:GetActive(ply)
	CheckArg(1, ply, CLIENT or IsPlayer)
	ply = ply or CachedLocalPlayer()

	if not self:GetCanPredict() or SERVER then
		return self.__States[ply] or false
	end

	-- handle predicted activations... NW2 i guess?
	return ply:GetNW2Bool("_bindSt:" .. self.ID, false)
end

function Bind:SetActive(ply, b)
	CheckArg(1, ply, CLIENT or IsPlayer)
	ply = ply or CachedLocalPlayer()

	self.__States[ply] = b

	if self:GetCanPredict() then
		ply:SetNW2Bool("_bindSt:" .. self.ID, b)
	end
end

-- the REAL button state, the player's input representing this bind currently
function Bind:GetButtonState(ply)
	CheckArg(1, ply, CLIENT or IsPlayer)
	ply = ply or CachedLocalPlayer()

	if not self:GetCanPredict() or SERVER then
		return self.__BtnStates[ply] or false
	end

	return ply:GetNW2Bool("_bindBtn:" .. self.ID, false)
end

function Bind:SetButtonState(ply, b)
	CheckArg(1, ply, CLIENT or IsPlayer)
	ply = ply or CachedLocalPlayer()

	self.__BtnStates[ply] = b

	if self:GetCanPredict() then
		ply:SetNW2Bool("_bindBtn:" .. self.ID, b)
	end
end

function Bind:Deactivate(ply)
	local newState = not self:GetActive(ply)
	if newState ~= false then return end

	self:SetActive(ply, newState)
	self:Emit("Deactivate", ply)
end

function Bind:Activate(ply)
	local newState = not self:GetActive(ply)
	if newState ~= true then return end

	self:SetActive(ply, newState)
	self:Emit("Activate", ply)
end

function Bind:_Fire(down, ply)
	local inPred = not IsFirstTimePredicted()

	if self.Method == BINDS_HOLD then
		if not self:GetCanPredict() and down == self:GetActive(ply) and not inPred then return end 	-- you can't re-activate a holdable bind
		if not self:GetCanPredict() and not down and self:GetHeld() and not inPred then return end 	-- if the bind is forced to be held, don't deactivate it

		if down then
			self:Activate(ply)
		else
			self:Deactivate(ply)
		end
	elseif self.Method == BINDS_TOGGLE and down then
		-- unsure if this works
		local newState = self:GetActive(ply)

		if newState then
			self:Activate(ply)
		else
			self:Deactivate(ply)
		end
	end

end

local function getBinds(ply, btn)
	if CLIENT then return Binds.Keys[btn] end

	return ply._keysToBinds and ply._keysToBinds[btn]
end

-- cl only hook
hook.Add("PlayerBindPress", Starlight.Name .. "_BindsDown", function(ply, _, _, btn)
	local binds = getBinds(ply, btn)
	if not binds then return end

	for k,v in ipairs(binds) do
		if v.Exclusive then return true end
	end
end)

hook.Add("PlayerButtonDown", Starlight.Name .. "_BindsDown", function(ply, btn)
	local binds = getBinds(ply, btn)
	if not binds then return end

	local first = IsFirstTimePredicted()

	for _, bind in ipairs(binds) do
		if not bind.Exclusive then continue end
		if bind:Emit("ShouldActivate") == false then continue end
		if not first and not bind:GetCanPredict() then continue end

		bind:SetButtonState(ply, true)
		bind:Emit("ButtonChanged", true)

		bind:_Fire(true, ply)
		return -- exclusive bind
	end


	for _, bind in ipairs(binds) do
		if bind:Emit("ShouldActivate") == false then continue end
		if not first and not bind:GetCanPredict() then continue end

		bind:SetButtonState(ply, true)
		bind:Emit("ButtonChanged", true)

		bind:_Fire(true, ply)
	end
end)

hook.Add("PlayerButtonUp", Starlight.Name .. "_BindsUp", function(ply, btn)
	local binds = getBinds(ply, btn)
	if not binds then return end

	local first = IsFirstTimePredicted()

	for _, bind in ipairs(binds) do
		if not bind.Exclusive then continue end
		if bind:Emit("ShouldDeactivate") == false then continue end

		if not first and not bind:GetCanPredict() then continue end

		bind:SetButtonState(ply, false)
		bind:Emit("ButtonChanged", false)

		bind:_Fire(false, ply)
		return -- exclusive bind
	end


	for _, bind in ipairs(binds) do
		if bind:Emit("ShouldDeactivate") == false then continue end
		if not first and not bind:GetCanPredict() then continue end

		bind:SetButtonState(ply, false)
		bind:Emit("ButtonChanged", false)

		bind:_Fire(false, ply)
	end
end)

--[[
	Concommands
]]

local function autoCompleter(method)
	return function(cmd, args)
		args = args:Trim()

		local ret = {}

		for k,v in pairs(Binds.Concommands) do
			if v.Method ~= method then continue end
			if args ~= "" then
			 	local lw = v.ID:lower()
			 	local exact = lw:sub(1, #args) == args
			 	local fuzzy = lw:find(args, 1, true) and #lw < #args * 3
			 	if not exact and not fuzzy then continue end
			end
			print(k)
			ret[#ret + 1] = cmd .. " " .. k
		end

		return ret
	end
end


concommand.Add(cmdPrefix .. "bindToggle", function(ply, _, _, str)
	if not Binds.Concommands[str] then
		print("unknown bind: " .. (str or ""))
		return
	end

	local bnd = Binds.Concommands[str]

	if bnd.Method ~= BINDS_TOGGLE then
		printf("bind `%s` is not toggleable", str)
		return
	end

	bnd:_Fire(true, ply)
end, autoCompleter(BINDS_TOGGLE))

local function checkBindHoldable(str)
	if not Binds.Concommands[str] then
		print("unknown bind: " .. (str or ""))
		return
	end

	local bnd = Binds.Concommands[str]

	if bnd.Method ~= BINDS_HOLD then
		printf("bind `%s` is not holdable", str)
		return
	end

	return bnd
end

local function onHold(ply, _, _, str)
	str = str:gsub("%s*%d+$", "")

	local bnd = checkBindHoldable(str)
	if not bnd then return end

	bnd:_Fire(true, ply)
end

local function onUnhold(ply, _, _, str)
	str = str:gsub("%s*%d+$", "")

	local bnd = checkBindHoldable(str)
	if not bnd then return end

	bnd:_Fire(false, ply)
end


concommand.Add("+" .. cmdPrefix .. "bind", onHold, autoCompleter(BINDS_HOLD))
concommand.Add("-" .. cmdPrefix .. "bind", onUnhold, autoCompleter(BINDS_HOLD))

if SERVER then include("binds_ext_sv.lua") end

if CLIENT then
	-- network binds to the server so we can predict nicely
	local toNw = {}

	hook.Add("BindKeyChanged", "Network", function(bind, old, new)
		if not bind:GetSynced() then return end
		bind:NWKey()
	end)

	function Binds.Network()
		if table.IsEmpty(toNw) then return end

		-- Only network up to 255 binds at a time
		local curNwQueue = {}

		for id, key in pairs(toNw) do
			curNwQueue[#curNwQueue + 1] = id
			if #curNwQueue >= 255 then break end
		end

		net.Start("sl_Binds")
			net.WriteUInt(#curNwQueue, 8)

			for _, id in ipairs(curNwQueue) do
				local key = toNw[id]
				toNw[id] = nil

				net.WriteString(id)
				net.WriteUInt(key, 16)
			end
		net.SendToServer()

		table.Empty(toNw)
	end

	function Bind:NWKey()
		toNw[self.ID] = self:GetKey()
		timer.Simple(0, Binds.Network)
	end
end