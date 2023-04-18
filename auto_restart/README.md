# Automatic server restarts

## Convars:
`autorestart_time`  **(default: 720)**  
Automatically restart the server after this many minutes of uptime.  
Values of more than 1440 minutes (24 hours) are not recommended.  

`autorestart_countdown`  **(default: 10)**  
After the time runs out, the map change will occur in this many seconds.

`autorestart_warnings`  **(default: "60 / 30 / 15 / 5 / 2 / 0")**  
Warn about automatic restarts X minutes before it happens.  
Can be delimited to produce multiple warnings (ie "5,2,1" will warn 5 minutes before restart, 2 minutes and 1 minute)  
Any non-number and non-dot character will be treated as a delimiter.

`autorestart_hardreset`  **(default: 0)**  
Instead of simply changing the map, quits the server outright (by using `_restart`).  
Not recommended, since a map change resets CurTime() (the source of jank on long-running servers),  
so only set this if you know what you're doing.

## Hooks:
`GM:AutoRestart_GetWarningFormat(number minutesTillRestart)`  
Called when generating a warning to send to chat and console.  
You can return your own format table to override the default.  
The format table is basically just colors and strings, similar to chat.AddText input.  

`GM:AutoRestart_GetChangeFormat(number minutesTillRestart)`  
Called when generating an announcement of an imminent map change.  
You can return your own format table to override the default.  

`GM:AutoRestart_AnnounceWarning(table announceFormat)`  
Called when a warning announcement is about to be made.  

`GM:AutoRestart_AnnounceChange(table announceFormat)`  
Called when an imminent map change announcement is about to be made.  

`GM:AutoRestart_PickMap()`  
Called when deciding what map to change to. Won't be called if we'll be hard-restarting instead.  

`GM:AutoRestart_RestartImminent()`  
Called when the restart countdown begins (usually a few secconds before the restart).  
Good place to, for example, send restart messages to other services,  
give everybody wacky weapons for a final deathmatch, or refund everyone.  

`GM:AutoRestart_RestartNow()`  
Called when the restart is about to occur (immediately after the hook).  
Good place to, for example, save the world to disk, to restore it after the restart.  