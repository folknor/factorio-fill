-- Version 1 by folk
-- To the extent possible under law, the authors have waived all copyright and related or neighboring rights to lib-events.lua.
-- http://creativecommons.org/publicdomain/zero/1.0/
-- In laymans terms: "do whatever you want with this file and its content"
-- Credits: folk, zx64
--[[

USAGE INSTRUCTIONS
In your control.lua scope somewhere, put something to the effect of
local events = require("lib-events")

Then register event handlers with:
events.register("your-event-name", function(event) print(serpent.block(event)) end)

And fire/trigger events with:
events.trigger("your-event-name", player.index, false, "arbitrary/foo", 123, tech.name, {foo=false}, ...)

Other mods can then listen for "your-event-name" before or after you, irrespective of mod load order or dependencies.

Events that are triggered, but have zero listeners, will not actually be triggered. Of course, noone will notice.
]]

local MAJOR, MINOR, register = "lib-events", 1, true
local eventIds
if remote.interfaces[MAJOR] then
	local existingIds = remote.call(MAJOR, "getEventIds")
	if type(existingIds) ~= "nil" then eventIds = existingIds
	else error("Previous version of lib-events did not pass on the registered event IDs.") end
	local version = remote.call(MAJOR, "version")
	if type(version) == "number" and version <= MINOR then register = false
	else
		remote.remove_interface(MAJOR)
		print("More recent version of lib-events has been detected.") -- stdout just in case someone notices
	end
end
if register then
	if type(eventIds) ~= "table" then eventIds = {} end
	local function getId(name)
		if not eventIds[name] then eventIds[name] = script.generate_event_name() end
		return eventIds[name]
	end
	local function trigger(name, ...)
		if not eventIds[name] then return end
		script.raise_event(eventIds[name], {...})
	end
	remote.add_interface(MAJOR, {
		getId=getId,
		trigger=trigger,
		version=function() return MINOR end,
		getEventIds=function() return eventIds end,
	})
end
local m = {
	trigger = function(...) remote.call(MAJOR, "trigger", ...) end,
	register = function(name, funcref)
		script.on_event((remote.call(MAJOR, "getId", name)), funcref)
	end,
}
return m
