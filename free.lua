local menu = require "necro.menu.Menu"
local utils = require "system.utils.Utilities"
local txtf = require "necro.config.i18n.TextFormat"
local settings = require "necro.config.Settings"

local ach = require "InGameAchievements.api"

local free = ach.register({
    id = "InGameAchievements_freeAchievement",
    version = 1,
    friendlyName = "Achievement",
    desc = "This is an achievement.",
    icon = "mods/InGameAchievements/achievement_stanley_parable_reference.png",
    sortOrder = ach.sortOrder.MEME,
})

event.menu.add("freeachievement", {key = "settings", sequence = 1}, function (ev)
	if ev.menu and ev.menu.entries and ev.arg.prefix and (ev.arg.prefix == "misc.other") and ev.arg.layer and (ev.arg.layer == 3) then
		ev.menu = utils.deepCopy(ev.menu)
		table.insert(ev.menu.entries, #ev.menu.entries-2, {
			label = function()
                local unlocked = free.isUnlocked()
                return "Free Achievement "..txtf.checkbox(unlocked, 2)
            end,
            id = "freeAchievement",
			action = function ()
                local unlocked = free.isUnlocked()
                if unlocked then
                    free.revoke()
                else
                    free.unlock(false, false, true)
                end
			end,
		})
	end
end)