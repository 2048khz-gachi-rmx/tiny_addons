
if SERVER then
	include("joinbroadcast/sv_joinbroadcast.lua")
	AddCSLuaFile("joinbroadcast/cl_joinbroadcast.lua")
else
	include("joinbroadcast/cl_joinbroadcast.lua")
end

AddCSLuaFile("joinbroadcast/sh_joinbroadcast.lua")
include("joinbroadcast/sh_joinbroadcast.lua")