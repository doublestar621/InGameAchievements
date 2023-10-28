--automatically generates all-zones cheevos for modded characters.

local lbc = require "necro.client.leaderboard.LeaderboardContext"
local components = require "necro.game.data.Components"
local utils = require "system.utils.Utilities"
local ecs = require "system.game.Entities"

local ach = require "InGameAchievements.api"
local filters = require "InGameAchievements.filters"
local iconStorage = require "InGameAchievements.iconstorage"

components.register { 
    allZonesAchievement = {
        components.field.table("data", {}),
        components.field.bool("exclude", false),
        components.field.string("excludeIfNameIs", ""), --fix suzetta not getting a cheevo
    },
}

local allZonesAch = {}

-- event.ecsSchemaReloaded.add("registerAchievements", {order = "regenerateLobby", sequence = 1}, function(ev) --register achievements!
--     for i, entity in ecs.prototypesWithComponents{"playableCharacter"} do
--         local data = entity.InGameAchievements_allZonesAchievement and entity.InGameAchievements_allZonesAchievement.data or {}
        
--         if not (entity.InGameAchievements_allZonesAchievement and entity.InGameAchievements_allZonesAchievement.exclude) then
--             local fName = entity.friendlyName and entity.friendlyName.name or entity.name --fallback.
--             if data.icon then
--                 data.cachedIcon = filters.imageToArray(data.icon)
--             else
--                 data.cachedIcon = filters.bitmapToArray(filters.getGenericAchievementImage(entity))
--             end
--             data.friendlyName = data.friendlyName or fName..": Hardcore!"
--             data.desc = data.desc or "Complete All Zones Mode with solo "..fName.."!"
--             data.descShort = data.descShort or fName.." All Zones Clear!"
--             data.version = data.version or -999999996
--             data.id = "InGameAchievements_AUTOGENALLZONES_"..entity.name
--             data.sortOrder = ach.sortOrder.ALL_ZONES
--             allZonesAch[entity.name] = ach.register(data,true)
--         end
--     end
--     ach.collect()
-- end)

--todo migrate to contentLoad
event.contentLoad.add("registerAchievements", {order = "customEntities", sequence = 1}, function(ev) --register achievements!
    for i, entity in ecs.prototypesWithComponents{"playableCharacter"} do
        local data = entity.InGameAchievements_allZonesAchievement and utils.fastCopy(entity.InGameAchievements_allZonesAchievement.data) or {}
        
        if not (entity.InGameAchievements_allZonesAchievement and (entity.InGameAchievements_allZonesAchievement.exclude or (entity.InGameAchievements_allZonesAchievement.excludeIfNameIs == entity.name))) then
            local fName = entity.friendlyName and entity.friendlyName.name or entity.name --fallback.
			-- dbg(fName, entity.name)
            if data.icon then
                data.cachedIcon = filters.imageToArray(data.icon)
            else
                data.cachedIcon = filters.bitmapToArray(filters.getGenericAchievementImage(entity))
            end
            data.friendlyName = data.friendlyName or fName..": Hardcore!"
            data.desc = data.desc or ("Complete All Zones Mode with solo "..fName.."!")
            data.descShort = data.descShort or fName.." All Zones Clear!"
            data.version = data.version or -999999994.998
            data.id = "InGameAchievements_AUTOGENALLZONES_"..entity.name
            data.sortOrder = ach.sortOrder.ALL_ZONES
			if entity.name == "Reaper" then
				data.hidden = true
				data.canUnlock = false
			end
            allZonesAch[entity.name] = ach.register(data,true)
            -- dbg(entity.name)
        end
    end
    -- ach.collect() --okay turns out this may not have been needed?
end)

event.entitySchemaLoadEntity.add("excludeBaseGameCharsAndSomeOthers", {order = "finalize", sequence = -1}, function(ev)
    --todo remove this, as its no longer used lol
    local skip = false
    local skipChars = {"Cadence", "Melody", "Aria", "Dorian", "Eli", "Monk", "Dove", "Coda", "Bolt", "Bard", "Nocturna", "Mary", "Tempo", "Diamond", "SampleMod_SampleChar", "Sync_Suzu", "Sync_Klarinetta", "Sync_Chaunter", "Ducklings_Duckling"}
    for i, v in ipairs(skipChars) do
        if ev.entity.name == v then
            skip = v
            break
        end
    end
    if skip then
        ev.entity.InGameAchievements_allZonesAchievement = { excludeIfNameIs = skip }
    end
end)

--unlock all zones cheevos!
event.runComplete.add("unlockAllZonesCheevos", {order = "leaderboardSubmission", sequence = 1}, function (ev)
    -- dbg(ev)
    if ev.summary.victory then --win!
        
        -- dbg(lbc.getModeContext())
        
        local context = lbc.getFinalRunContext()
        if (context.maximumPlayers <= 1) and (context.completion.victory) and (context.gameMode == "AllZones") then --valid all-zones run.
            if not (context.customRules[1]["gameplay.modifiers.dancepad"] or context.customRules[1]["gameplay.modifiers.phasing"] or (context.customRules[1]["gameplay.modifiers.rhythm"] == "NO_BEAT")) then --dont allow certain rules to be used.
                if allZonesAch[context.characters[1]] then
                    allZonesAch[context.characters[1]].unlock()
                end
            end
        end
    end
end)