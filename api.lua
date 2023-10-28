-- Press Shift+F1 to display debug output in-game
-- print("Hello world, this is In-Game Achievements!")

local utils = require "system.utils.Utilities"
local menu = require "necro.menu.Menu"
local sound = require "necro.audio.Sound"
local settings = require "necro.config.Settings"
local gfx = require "system.gfx.GFX"
local bitmap = require "system.game.Bitmap"
local color = require "system.utils.Color"
local statistics = require "necro.game.system.Statistics"
-- local lbc = require "necro.client.leaderboard.LeaderboardContext"
local ui = require "necro.render.UI"
local hud = require "necro.render.hud.HUD"
local hudLayout = require "necro.render.hud.HUDLayout"
local render = require "necro.render.Render"
local settingsStorage = require "necro.config.SettingsStorage"
local hsvf = require "necro.render.filter.HSVFilter"
local txtf = require "necro.config.i18n.TextFormat"
local sound = require "necro.audio.Sound"
local LocalCoop = require "necro.client.LocalCoop"
local enum = require "system.utils.Enum"
local player = require "necro.game.character.Player"
local grayscaleFilter = require "necro.render.filter.GrayscaleFilter"
local fileIO = require "system.game.FileIO"
local stringUtils = require "system.utils.StringUtilities"

local filters = require "InGameAchievements.filters"
-- local versionCheck = require "InGameAchievements.versioncheck"
local iconStorage = require "InGameAchievements.iconstorage"
local delayedSave = require "InGameAchievements.delayedsave"

local sortOrder = enum.sequence{
    ALL_ZONES = 1,
    ALL_ZONES_SPECIAL = 2,
    UNTAGGED = 3,
    MISC = 4,
    MEME = 5,
}

local achLayer = settings.Layer.LOCAL
achievementData = settings.user.table { --achievements stored here.
    id = "InGameAchievements_achievementData",
    key = "InGameAchievements_achievementData",
    name = "Achievement Data (DO NOT MODDIFY)",
    default = {},
    visibility = settings.Visibility.RESTRICTED, --hide from power settings?
}
canUnlockCheevos = settings.user.bool {
    id = "InGameAchievements_canUnlockCheevos",
    name = "Allow unlocking of achievements",
    default = true,
    visibility = settings.Visibility.HIDDEN,
}
sortMode = settings.user.number {
    id = "InGameAchievements_sortMode",
    name = "Sort",
    min = 1,
    max = 6,
    default = 1,
    visibility = settings.Visibility.HIDDEN,
}
aggressiveAutoSave = settings.user.bool {
    id = "InGameAchievements_aggressiveAutoSave",
    name = "Immediately save achievements",
    default = true,
    visibility = settings.Visibility.HIDDEN,
}
loadedOnly = settings.user.bool {
    id = "InGameAchievements_showLoadedOnly",
    name = "Loaded mods only",
    default = false,
    visibility = settings.Visibility.HIDDEN,
}



-- local function unlockedWrapper(k1, k2, default)
-- 	if (k1.unlocked or false) == (k2.unlocked or false) then
-- 		return type(default) == "function" and default() or default
-- 	else
-- 		return k1.unlocked
-- 	end
-- end

local function getNamespace(string)
	string = string:gsub("InGameAchievements_AUTOGENALLZONES_", "")
	local i = string.find(string, "_")
	if i then
		return string.sub(string, 1, i-1)
	else
		return nil
	end
end

local sortModeNames = {"By Type", "By Type, Unlocked First", "Alphabetical", "Alphabetical, Unlocked First", "By Mod", "By Mod, Unlocked First"}
local sortModeDescriptions = {
	"Sort achievements by their type.",
	"Sort achievements by whether or not you've unlocked them, then by their type.",
	"Sort achievements by their name.",
	"Sort achievements by whether or not you've unlocked them, then by their name.",
	"Sort achievements by which mod they're from.",
	"Sort achievements by whether or not you've unlocked them, then by which mod they're from.",
}
local sortFunctions = {
    function(k1, k2)--default (sortOrder)
        local s1, s2 = (k1.sortOrder or 0), (k2.sortOrder or 0)
        if s1 == s2 then
            return (k1.friendlyName or k1.id) < (k2.friendlyName or k2.id)
        else
            return (k1.sortOrder or 0) < (k2.sortOrder or 0)
        end
    end,
    function(k1, k2)--default unlocked first
        if (k1.unlocked or false) == (k2.unlocked or false) then
            local s1, s2 = (k1.sortOrder or 0), (k2.sortOrder or 0)
            if s1 == s2 then
                return (k1.friendlyName or k1.id) < (k2.friendlyName or k2.id)
            else
                return (k1.sortOrder or 0) < (k2.sortOrder or 0)
            end
        else
            return k1.unlocked
        end
    end,
    function(k1, k2)--by name
        return (k1.friendlyName or k1.id) < (k2.friendlyName or k2.id)
    end,
    function(k1, k2)--by name unlocked first
        if (k1.unlocked or false) == (k2.unlocked or false) then
            return (k1.friendlyName or k1.id) < (k2.friendlyName or k2.id)
        else
            return k1.unlocked
        end
    end,
	
	--by mod
	function(k1, k2)
		local ns1, ns2 = getNamespace(k1.id), getNamespace(k2.id)
		if ns1 == ns2 then
			--use sort order
			local s1, s2 = (k1.sortOrder or 0), (k2.sortOrder or 0)
			if s1 == s2 then
				return (k1.friendlyName or k1.id) < (k2.friendlyName or k2.id)
			else
				return (k1.sortOrder or 0) < (k2.sortOrder or 0)
			end
		else
			return ns1 < ns2
		end
	end,
	
	--by mod, unlocked first
	function(k1, k2)
		-- return unlockedWrapper(k1, k2, function()
		-- 	local ns1, ns2 = getNamespace(k1.id), getNamespace(k2.id)
		-- 	if ns1 == ns2 then
		-- 		--use sort order
		-- 		local s1, s2 = (k1.sortOrder or 0), (k2.sortOrder or 0)
		-- 		if s1 == s2 then
		-- 			return (k1.friendlyName or k1.id) < (k2.friendlyName or k2.id)
		-- 		else
		-- 			return (k1.sortOrder or 0) < (k2.sortOrder or 0)
		-- 		end
		-- 	else
		-- 		return ns1 < ns2
		-- 	end
		-- end)
		if (k1.unlocked or false) == (k2.unlocked or false) then
			local ns1, ns2 = getNamespace(k1.id), getNamespace(k2.id)
			if ns1 == ns2 then
				--use sort order
				local s1, s2 = (k1.sortOrder or 0), (k2.sortOrder or 0)
				if s1 == s2 then
					return (k1.friendlyName or k1.id) < (k2.friendlyName or k2.id)
				else
					return (k1.sortOrder or 0) < (k2.sortOrder or 0)
				end
			else
				return ns1 < ns2
			end
		else
			return k1.unlocked
		end
	end,
}
-- alwaysPopup = settings.user.bool {
--     id = "InGameAchievements_alwaysPopup",
--     name = "Always show pop-up",
--     default = false,
--     visibility = settings.Visibility.RESTRICTED, --hide from power settings?
-- }

--rendering code
local popupAnimData = {}
event.renderUI.add("showAchievement", {order="menuOverlay", sequence = 1}, function(ev)
    if popupAnimData[1] then
        local animData = popupAnimData[1]
        local b = render.getBuffer(render.Buffer.UI_MENU)
        -- dbg(b)
        -- b.drawImage("mods/InGameAchievements/achPopupBack.png", 10, 0, 3, 1, 150*2, 40*2, render.Corner.BOTTOM_RIGHT, render.Corner.BOTTOM_RIGHT)
        local yOff = 0
        if animData.time < 0.5 then
            yOff = (0.5 - animData.time) * (160)
        elseif animData.time > 5 then
            yOff = (animData.time - 5) * (160)
        end
        -- dbg(yOff)
        local dataUpper = ui.measureText({ --get width and height for Things:tm:
            text = animData.textUpper,
            font = ui.Font.SMALL,
        })
        local dataCenter = ui.measureText({ --get width and height for Things:tm:
            text = animData.textCenter,
            font = ui.Font.MEDIUM,
            size = 24,
            spacingX = 1,
        })
        local dataLower = ui.measureText({ --get width and height for Things:tm:
            text = animData.textBottom,
            font = ui.Font.SMALL,
        })
        local totalWidth = math.max(dataUpper.width*2 or 0, dataLower.width*2 or 0, dataCenter.width or 0) + (76) + 12
        local totalHeight = (dataUpper.height + dataCenter.height + dataLower.height) + 36 --spacing :P
        -- dbg(dataUpper, dataCenter, dataLower)
        -- dbg(dataLower.width, totalWidth - 76 - 12)
        
        --draw a box.
        b.draw({ --background
            texture = "ext/particles/TEMP_particle_black.png",
            rect = {gfx.getWidth() - totalWidth - 4, (gfx.getHeight() - totalHeight - 4) + yOff, totalWidth, totalHeight},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            z = 1,
        })
        b.draw({ --bottom right
            texture = "mods/InGameAchievements/achPopupTopLeft.png",
            rect = {gfx.getWidth() - 8, (gfx.getHeight() - 8) + yOff, 8, 8},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            angle = math.rad(180),
            z = 1,
        })
        b.draw({ --top right
            texture = "mods/InGameAchievements/achPopupTopLeft.png",
            rect = {gfx.getWidth() - 8, (gfx.getHeight() - 8 - totalHeight) + yOff, 8, 8},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            angle = math.rad(90),
            z = 1,
        })
        b.draw({ --bottom left
            texture = "mods/InGameAchievements/achPopupTopLeft.png",
            rect = {gfx.getWidth() - 8 - totalWidth, (gfx.getHeight() - 8) + yOff, 8, 8},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            angle = math.rad(-90),
            z = 1,
        })
        b.draw({ --top left
            texture = "mods/InGameAchievements/achPopupTopLeft.png",
            rect = {gfx.getWidth() - 8 - totalWidth, (gfx.getHeight() - 8 - totalHeight) + yOff, 8, 8},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            z = 1,
        })
        b.draw({ --left edge
            texture = "mods/InGameAchievements/achPopupBorderLeft.png",
            rect = {gfx.getWidth() - totalWidth - 8, (gfx.getHeight() - totalHeight) + yOff, 4, totalHeight - 8},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            z = 1,
        })
        b.draw({ --right edge
            texture = "mods/InGameAchievements/achPopupBorderLeft.png",
            rect = {gfx.getWidth() - 4, (gfx.getHeight() - totalHeight) + yOff, 4, totalHeight - 8},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            angle = math.rad(180),
            z = 1,
        })
        b.draw({ --top edge
            texture = "mods/InGameAchievements/achPopupBorderLeft.png",
            rect = {gfx.getWidth() - 6, (gfx.getHeight() - totalHeight - 8) + yOff, 4, totalWidth - 4},
            origin = {0, 0},
            -- origin = {gfx.getWidth(), -0.5},
            angle = math.rad(90),
            z = 1,
        })
        b.draw({ --bottom edge
            texture = "mods/InGameAchievements/achPopupBorderLeft.png",
            rect = {gfx.getWidth() -totalWidth , (gfx.getHeight()) + yOff, 4, totalWidth - 6},
            origin = {0, 0},
            -- origin = {gfx.getWidth(), -0.5},
            angle = math.rad(-90),
            z = 1,
        })
        
        --draw icon (hopefully?)
        b.draw({ --the icon
            texture = animData.icon, --todo?
            rect = {gfx.getWidth() - totalWidth, (gfx.getHeight() - totalHeight) + yOff, 64, 64},
            -- origin = {-0.5, -0.5},
            -- origin = {gfx.getWidth(), -0.5},
            z = 1,
        })
        --okay we need to actually make upper-casing work here
        local uppercase = ui.isUppercaseEnabled()
        local t = {
            uppercase and ui.upper(animData.textUpper) or animData.textUpper,
            uppercase and ui.upper(animData.textCenter) or animData.textCenter,
            uppercase and ui.upper(animData.textBottom) or animData.textBottom,
        }
        --draw smaller text
        b.drawText({
            text = t[1],
            font = ui.Font.SMALL.font,
            x = gfx.getWidth() - totalWidth + 76,
            y = (gfx.getHeight() - totalHeight) + yOff + (8),
            -- size = ui.Font.SMALL.size,
            z = 2,
        })
        --draw larget text
        b.drawText({
            text = t[2],
            font = ui.Font.MEDIUM.font,
            size = 24,
            spacingX = 1,
            x = gfx.getWidth() - totalWidth + 76,
            y = (gfx.getHeight() - totalHeight) + yOff + (22),
            -- size = ui.Font.SMALL.size,
            z = 2,
        })
        --draw description
        b.drawText({
            text = t[3],
            font = ui.Font.SMALL.font,
            x = gfx.getWidth() - totalWidth + 76,
            y = (gfx.getHeight() - totalHeight) + yOff + (48),
            -- size = ui.Font.SMALL.size,
            z = 2,
        })
        -- dbg(b)
        -- b.drawImage("mods/InGameAchievements/achPopupBack.png", 0, 0, 1, 1)
    end
end)

event.tick.add("achievementAnimate", {order = "renderTimestep", sequence = 1}, function(ev)
    if popupAnimData[1] then
        if not popupAnimData[1].playedSound then
            sound.playUI("shrineActivate")
            popupAnimData[1].playedSound = true
        end
        popupAnimData[1].time = popupAnimData[1].time + ev.deltaTime
        if popupAnimData[1].time > 5.5 then
            --remove
            table.remove(popupAnimData, 1)
        end
    end
end)

local newAchData = {}
local cheevosCollected = false --for late-registered cheevos!

local function showPopup(icon, topText, midText, bottomText)
    table.insert(popupAnimData, {
        textUpper = topText,
        textCenter = midText,
        textBottom = bottomText,
        icon = icon,
        time = 0,
    })
end

local function collectCheevos()
    -- for i, v in utils.sortedPairs(achievementData) do
    --     v.hidden = true
    -- end
	-- dbg(newAchData)
    for i, v in utils.sortedPairs(newAchData) do
        local write = false
		-- dbg(i, v.id)
        if achievementData and achievementData[i] then
            if achievementData[i].version < v.version then
                write = true
            end
        else
            write = true
        end
        if write or v.isDebug then
            local unlocked = achievementData[i] and achievementData[i].unlocked or false --preserve unlocks!
            if not achievementData then --just in case :P
                achievementData = {}
            end
            achievementData[i] = v
            achievementData[i].unlocked = unlocked
			
			--handle icon
			iconStorage.setImage(v.id, v.icon)
        end
    end
	-- local iconsToUpgrade = {}
    for i, v in utils.sortedPairs(achievementData) do
        if not v.sortOrder then
            if string.find(v.id, "InGameAchievements_AUTOGENALLZONES_") then
                v.sortOrder = sortOrder.ALL_ZONES
            else
                v.sortOrder = sortOrder.UNTAGGED
            end
        end
		--upgrade achievement icons (also applies to all-zones ones because i couldnt figure out how to make it properly switch to the new system hhhh)
		if v.cachedIcon then
			-- iconsToUpgrade[#iconsToUpgrade + 1] = {v.id, iconStorage.upgradeFromOldVer(v.cachedIcon)}
			iconStorage.setRaw(v.id, iconStorage.upgradeFromOldVer(v.cachedIcon))
			v.cachedIcon = nil
			-- dbg(v.id)
		end
		--useless field
		v.icon = nil
    end
	-- for i, con in ipairs(iconsToUpgrade) do
	-- 	iconStorage.setRaw(con[1], con[2])
	-- end
	--testing out compression for putting more stuff into one table
	-- do
	-- 	dbg(iconsToUpgrade)
	-- 	local sampleSetting = {}
	-- 	for i, v in ipairs(iconsToUpgrade) do
	-- 		sampleSetting[v[1]] = v[2]
	-- 	end
	-- 	dbg(#iconStorage.serializeFromArray(sampleSetting)) --83456
		
	-- 	local sampleString = ""
	-- 	for i, v in ipairs(iconsToUpgrade) do
	-- 		sampleString = sampleString..iconStorage.serializeFromArray(v[2])
	-- 	end
	-- 	dbg(#sampleString) --100492
	-- end
    cheevosCollected = true
end

local function registerAchievement(data, skipCollect)
	-- dbg(data.id)
    local unlocked = newAchData[data.id] and newAchData[data.id].unlocked or false
    newAchData[data.id] = data
    newAchData[data.id].unlocked = unlocked
    -- if not newAchData[data.id].cachedIcon and newAchData[data.id].icon then
    --     newAchData[data.id].cachedIcon = filters.imageToArray(newAchData[data.id].icon)
    -- end
    if cheevosCollected and not skipCollect then
        collectCheevos()
    end
    
    
    local function pop()
        showPopup(iconStorage.getImage(data.id), "Achievement Unlocked!", achievementData[data.id].friendlyName, achievementData[data.id].descShort or achievementData[data.id].desc)
    end
    
    --forceAnim: forces the popup to display
    --forceUnlock: bypasses the canUnlockCheevos option
    --playerCheck: pass an entity or playerID. it will be checked to 
    local function unlock(playerCheck, requireSingleplayer, forceUnlock)
        --okay i need to reorganise some stuff
        local unlock = false
        if (canUnlockCheevos or forceUnlock) and not (requireSingleplayer and not player.isAlone()) and not (achievementData[data.id].canUnlock == false) then
            if type(playerCheck) == "number" then --we've been handed a playerID (i hope).
                if LocalCoop.isLocal(playerCheck) then
                    unlock = true
                end
            elseif playerCheck and playerCheck.controllable then --the player entity itself.
                if LocalCoop.isLocal(playerCheck.controllable.playerID) then
                    unlock = true
                end
            else --no entityCheck
                unlock = true
            end
        end
        if ((achievementData[data.id] and not achievementData[data.id].unlocked) and unlock) then
            pop()
        end
        if unlock and not achievementData[data.id].unlocked then
            achievementData[data.id].unlocked = true
			if aggressiveAutoSave then
            	settingsStorage.saveToFile(achLayer)
			else
				delayedSave.perform()
			end
        end
    end
    
    local function revoke()
		if achievementData[data.id].unlocked then
			achievementData[data.id].unlocked = false
			if aggressiveAutoSave then
            	settingsStorage.saveToFile(achLayer)
			else
				delayedSave.perform()
			end
		end
    end
    
    local function isUnlocked()
        return achievementData[data.id] and achievementData[data.id].unlocked
    end
    
    --depreciated, kinda.
    local function unlockForced()
        unlock(false, false, true)
    end
    
    return {
        unlock = unlock,
        unlockForced = unlockForced, --semi-depreciated?
        revoke = revoke,
        isUnlocked = isUnlocked,
        pop = pop,
    }
end
-- process cheevos
event.contentLoad.add("collectAchievements", {order = "progression", sequence = 1}, function (ev)
	--make sure user isn't trying to downgrade to older version
	-- versionCheck.checkAndUpgrade()
    -- add new cheevos. this will need to be tweaked to include conversion stuff for images!
    collectCheevos()
end)

--menu stuff 1
event.menu.add("achievementsInPauseMenu", {key = "pause", sequence = 1}, function (ev)
    if ev.menu and ev.menu.entries then
        ev.menu = utils.deepCopy(ev.menu)
        table.insert(ev.menu.entries, 2, {
            label = "Achievements",
            -- enableIf = function ()
            --     return player.getPlayerEntity()
            -- end,
            action = function ()
                -- collectCheevos()
                menu.open("inGameAchievements")
            end,
        })
    end
end)

event.menu.add("one", "oneAchievementMenu", function (ev)
    -- dbg(ev)
    local entries = {}
    
    local ach = achievementData[ev.arg]
    
    local achIcon = iconStorage.getImage(ev.arg)
    if not ach.unlocked then
        -- achIcon = filters.filterLocked({image = achIcon})
		achIcon = grayscaleFilter.getPath(achIcon)
    end
    -- entries[#entries + 1] = {
    --     label = "",
    --     id = "empty",
    --     selectable = false,
    --     -- font = ui.Font.SMALL,
    -- }
    
    entries[#entries + 1] = {
        id = "icon",
        -- x = x,
        -- y = y,
        y = 40,
        height = 74,
        color = ach.unlocked and color.WHITE or color.gray(0.6),
        icon = {
            -- color = color.WHITE,
            image = achIcon, --temp!
            width = 64,
            height = 64,
        },
        selectable = false,
    }
    -- entries[#entries + 1] = {
    --     label = ach.friendlyName,
    --     id = "name",
    --     selectable = false,
    -- }
    --buffer
    -- entries[#entries + 1] = {
    --     label = "",
    --     id = "empty2",
    --     selectable = false,
    --     -- font = ui.Font.SMALL,
    -- }
    
    entries[#entries + 1] = {
        label = ach.desc,
        id = "desc",
        selectable = false,
    }
    if not ach.unlocked then
        entries[#entries + 1] = {
            label = "(Locked)",
            id = "locked",
            selectable = false,
        }
    end
    entries[#entries + 1] = {
        id = "_back",
        label = "Back",
        action = menu.close,
        sound = "UIBack",
    }
    
    ev.menu = {
        label = ach.friendlyName,
        entries = entries,
    }
end)

                --sound.playUI("shrineActivate")
event.menu.add("service", "achService", function (ev)
    local entries = {}
    
    local ach = achievementData[ev.arg]
    
    entries[#entries + 1] = {
        id = "_back",
        label = ev.arg,
    }
	
	entries[#entries + 1] = {height = 0}
    
    entries[#entries + 1] = {
        id = "lock",
        label = "Lock achievement",
        action = function()
            ach.unlocked = false
            menu.close()
            menu.close()
            menu.open("inGameAchievements")
        end,
    }
    
    entries[#entries + 1] = {
        id = "del",
        label = "Delete achievement",
        action = function()
            achievementData[ev.arg] = nil
			iconStorage.setImage(ev.arg)
            menu.close()
            menu.close()
            menu.open("inGameAchievements")
        end,
    }
	
	entries[#entries + 1] = {height = 0}
    
    entries[#entries + 1] = {
        id = "_back",
        label = "Back",
        action = menu.close,
        sound = "UIBack",
    }
    
    ev.menu = {
        label = ev.arg,
        entries = entries,
    }
end)

local function isAchievementModOfOriginLoaded(id)
	if not id:find("_") then return true end
	local namespace
	if stringUtils.startsWith(id, "InGameAchievements_AUTOGENALLZONES_") then
		namespace = id:sub(36, id:find("_", 36) - 1)
	else
		namespace = id:sub(1, id:find("_") - 1)
	end
	return fileIO.exists("mods/"..namespace.."/mod.json") --fileIO.exists doesn't return true when checking if a directory exists for some reason
end

event.menu.add("achievementsMenu", "inGameAchievements", function (ev)
    -- dbg(ev)
    
    local entries = {}
    -- dbg(gfx.getHeight(), gfx.getWidth())
    local width = gfx.getWidth() - 100
    local entriesX = math.max(math.floor(width / 72), 1)
    -- dbg(entriesX)
    -- local entriesY = math.floor(gfx.getHeight() / 32)
    -- dbg(achievementData)
    --header!
    
    -- entries[#entries + 1] = {
    --     label = function ()
    --         if menu.getSelectedEntry() and menu.getSelectedEntry().achievementData then
    --             return menu.getSelectedEntry().achievementData.name
    --         else
    --             return ""
    --         end
    --     end,
    --     id = "_header1",
    --     y = 0,
    --     z = 100,
    --     selectable = false,
    --     -- sticky = true,
    -- }
    -- entries[#entries + 1] = {
    --     label = function ()
    --         if menu.getSelectedEntry() and menu.getSelectedEntry().achievementData then
    --             return menu.getSelectedEntry().achievementData.desc
    --         else
    --             return ""
    --         end
    --     end,
    --     id = "_header2",
    --     y = 30,
    --     z = 100,
    --     selectable = false,
    --     font = ui.Font.SMALL,
    --     -- sticky = true,
    -- }
    
    -- local i = 0
    local achievementCount = 0
    local data = {}
	-- dbg(achievementData)
    for k, v in utils.sortedPairs(achievementData) do
		-- dbg(v.id)
		if not (v.hidden and not v.unlocked) and (not loadedOnly or isAchievementModOfOriginLoaded(v.id)) then
			achievementCount = achievementCount + 1
			table.insert(data, v)
		else
			-- dbg(v.hidden, v.unlocked, v.id)
		end
    end
    table.sort(data, sortFunctions[sortMode])
    -- for k, v in utils.sortedPairs(achievementData) do
    local vericalSize = 180
    
    for i = 1, #data, 1 do
        local v = data[i]
        -- i = i + 1
        local index = i
        local function menuOffset(diff) --from reclassify
            return function ()
                local i = i
                if index + diff <= achievementCount and index + diff > 0 then
                    menu.selectByID(index + diff)
                elseif diff > 1 then
                    menu.selectByID("_allowAch")
                elseif diff < 1 then
                    menu.selectByID("_back")
                end
                sound.playUI(diff > 0 and "UISelectDown" or "UISelectUp")
            end
        end
        
        local x, y = 72 * ((i-1) % entriesX) - ((entriesX-1) * 36), math.floor((i-1) / entriesX) * 72-- + 75
        -- dbg(x, y)
        local iconID = "achievementIcon"..v.id
        
        entries[#entries + 1] = {
            id = i,
            -- label = "a",
            achievementData = {
                name = v.friendlyName,
                desc = v.desc,
            },
            icon = {
                -- color = -2130706433,
                height = 36,
                image = "gfx/necro/gui/mod/empty.png",
                selectedImage = "gfx/necro/gui/mod/cursor.png",
                width = 36,
                -- visible = (menu.getSelectedID() == id) and true or false,
            },
            x = x,
            y = y,
            -- selectable = true,
            upAction = menuOffset(-entriesX),
            downAction = menuOffset(entriesX),
            rightAction = menuOffset(1),
            leftAction = menuOffset(-1),
            rightSound = "",
            leftSound = "",
            hideArrows = true,
            action = function () --todo open single cheevo menu!
                menu.open("oneAchievementMenu", v.id)
            end,
            specialAction = function () --open debug menu.
                menu.open("achService", v.id)
            end,
			boundingBox = {
				x - 36, y - 36, 72, 72
			},
        }
        -- y = y + 20
        -- dbg(v.cachedIcon)
        -- local achIcon = filters.arrayToImage({array = v.cachedIcon}) --iconStorage.getImage(id)
        local achIcon = iconStorage.getImage(v.id)
		-- dbg(v.id, v.serializedIcon)
        if not v.unlocked then
            --todo
            -- achIcon = hsvf.getPath(achIcon, 0, -1, -0.3)
            -- achIcon = filters.filterLocked({image = achIcon})
			achIcon = grayscaleFilter.getPath(achIcon)
        end
        entries[#entries + 1] = {
            id = iconID,
            x = x,
            y = y,
            color = v.unlocked and color.WHITE or color.gray(0.6),
            icon = {
                -- color = color.WHITE,
                image = achIcon,
                width = 32,
                height = 32,
            },
            selectable = false,
            -- fontSize = vericalSize,
        }
        -- y = y + (geo.h*2) + 30
        
        --[[icon = {
            image = sprite.texture,
            imageRect = {sprite.textureShiftX, sprite.textureShiftY, sprite.width, sprite.height},
            width = sprite.width,
            height = sprite.height,
            color = color.hsv(0, 0, (menu.getSelectedID() == i) and 1 or 0.4),
        }]]
        
    end
    
    local footerY = math.floor((achievementCount-1) / entriesX) * 72 + 70-- + 75
    --todo add sticky footer!
    --code mostly stolen from reclassify lol
    local bottomY = gfx.getHeight() - 100
    local needStickyFooter = ((entries[#entries] or {}).y or 0) > bottomY - 100
    local footerOffset = needStickyFooter and 0 or 40
    
    --non-sticky footer
    if not needStickyFooter then
        -- entries[#entries + 1] = {height = 0}

        entries[#entries + 1] = {
            label = function ()
                if menu.getSelectedEntry() and menu.getSelectedEntry().achievementData then
                    return menu.getSelectedEntry().achievementData.name
                else
                    return ""
                end
            end,
            selectable = false,
            y = footerY - 20,
        }
        entries[#entries + 1] = {
            label = function ()
				local entry = menu.getSelectedEntry()
				if entry then
					if entry.achievementData then
						return entry.achievementData.desc
					else
						return entry.footerDescription and type(entry.footerDescription) == "function" and entry.footerDescription() or entry.footerDescription or ""
					end
				end
            end,
            selectable = false,
            y = footerY + 10,
            font = ui.Font.SMALL,
        }
    end
    
    entries[#entries + 1] = {
        -- label = function ()
        --     return (menu.getSelectedEntry() or {}).name
        -- end,
        id = "_allowAch",
        label = function()
            return "Enable unlocking achievements "..txtf.checkbox(canUnlockCheevos, 2)
        end,
        -- selectable = false,
        -- sticky = true,
        -- x = 5,
        y = footerY + footerOffset,
        action = function()
            canUnlockCheevos = not canUnlockCheevos
        end,
        -- height = vericalSize,
		footerDescription = "Allows achievements to be unlocked.",
    }
    entries[#entries + 1] = {
        -- label = function ()
        --     return (menu.getSelectedEntry() or {}).name
        -- end,
        id = "_sortmode",
        label = function()
            return "Sort mode: "..sortModeNames[sortMode]
        end,
        -- selectable = false,
        -- sticky = true,
        -- x = 5,
        y = footerY + 40 + footerOffset,
        action = function()
            sortMode = sortMode + 1
            if sortMode > 6 then
                sortMode = 1
            end
            menu.update()
        end,
        rightAction = function()
            sortMode = sortMode + 1
            if sortMode > 6 then
                sortMode = 1
            end
            menu.update()
        end,
        leftAction = function()
            sortMode = sortMode - 1
            if sortMode < 1 then
                sortMode = 6
            end
            menu.update()
        end,
        -- height = vericalSize,
		
		footerDescription = function()
			return sortModeDescriptions[sortMode]
		end,
    }
    entries[#entries + 1] = {
        -- label = function ()
        --     return (menu.getSelectedEntry() or {}).name
        -- end,
        id = "_loadedOnly",
        label = function()
            return "Loaded mods only "..txtf.checkbox(loadedOnly, 2)
        end,
        y = footerY + 80 + footerOffset,
        action = function()
            loadedOnly = not loadedOnly
			menu.update()
        end,
		footerDescription = "Only show achievements from mods that are currently loaded.",
    }
    entries[#entries + 1] = {
        -- label = function ()
        --     return (menu.getSelectedEntry() or {}).name
        -- end,
        id = "_agressiveUnlock",
        label = function()
            return "Immediately save achievements "..txtf.checkbox(aggressiveAutoSave, 2)
        end,
        y = footerY + 120 + footerOffset,
        action = function()
            aggressiveAutoSave = not aggressiveAutoSave
        end,
		specialAction = function()
			settingsStorage.saveToFile(achLayer)
		end,
		footerDescription = "If on, achievements are saved the moment you unlock them.\nIf off, achievements only save when changing levels, ending a run or pausing/exiting the game.\nIf you're getting big lagspikes when unlocking achievements, turn this off.\n\n",
    }
    entries[#entries + 1] = {
        -- label = function ()
        --     return (menu.getSelectedEntry() or {}).name
        -- end,
        id = "_back",
        label = "Back",
        -- selectable = false,
        -- sticky = true,
        -- x = 5,
        y = footerY + 160 + footerOffset,
        action = menu.close,
        sound = "UIBack",
        -- height = vericalSize,
        
    }
    if needStickyFooter then
        -- entries[#entries + 1] = {
        --     y = footerY + 120 + footerOffset,
        -- }
        entries[#entries + 1] = {
            label = function ()
                if menu.getSelectedEntry() and menu.getSelectedEntry().achievementData then
                    return menu.getSelectedEntry().achievementData.name
                else
                    return ""
                end
            end,
            selectable = false,
            sticky = true,
            y = bottomY - 30,
        }
        entries[#entries + 1] = {
            label = function ()
				local entry = menu.getSelectedEntry()
				if entry then
					if entry.achievementData then
						return entry.achievementData.desc
					else
						return entry.footerDescription and type(entry.footerDescription) == "function" and entry.footerDescription() or entry.footerDescription or ""
					end
				end
            end,
            selectable = false,
            sticky = true,
            y = bottomY,
            font = ui.Font.SMALL,
        }
    end
    ev.menu = {
        label = "Achievements",
        entries = entries,
        -- directionalConfirmation = false,
        -- update = true,
        -- headerSize = 10,
        footerSize = needStickyFooter and 75 or nil,
        -- headerSize = 75,
    }
end)

-- local function handleIconUpgrade()
-- 	--itterate over all achievements, add icon, remove cachedIcon
-- end

return {
    register = registerAchievement,
    collect = collectCheevos,
    showPopup = showPopup,
    sortOrder = sortOrder,
	-- handleIconUpgrade = handleIconUpgrade,
}