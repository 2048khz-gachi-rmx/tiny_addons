AutoRestart = AutoRestart or {}
local Tag = "ar_ChatAddText"


-- TODO: make it better
local function writeContents(...)
	return net.WriteTable({...})
end

local function readContents()
	return net.ReadTable()
end

if SERVER then
	util.AddNetworkString(Tag)
	local PLAYER = FindMetaTable("Player")

	function PLAYER:ARChatAddText(...)
		net.Start(Tag)
			net.WriteBool(true)
			writeContents(...)
		net.Send(self)
	end

	function AutoRestart.ChatAddText(...)
		if player.GetCount() == 0 then return end

		net.Start(Tag)
			net.WriteBool(true)
			writeContents(...)
		net.Broadcast()
	end

	function PLAYER:ARConsoleAddText(...)
		net.Start(Tag)
			net.WriteBool(false)
			writeContents(...)
		net.Send(self)
	end

	function AutoRestart.ConsoleAddText(...)
		if player.GetCount() == 0 then return end

		net.Start(Tag)
			net.WriteBool(false)
			writeContents(...)
		net.Broadcast()
	end
end

if CLIENT then

	net.Receive(Tag, function()
		local inChat = net.ReadBool()

		local data = readContents()
		if not istable(data) then
			return
		end

		if inChat then
			chat.AddText(unpack(data))
		else
			data[#data + 1] = "\n"
			MsgC(unpack(data))
		end
	end)

end