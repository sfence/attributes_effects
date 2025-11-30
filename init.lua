
attributes_effects = {
	translate = core.get_translator("attributes_effects"),
}

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

dofile(modpath.."/functions.lua")
dofile(modpath.."/api.lua")
dofile(modpath.."/step.lua")
dofile(modpath.."/tool.lua")