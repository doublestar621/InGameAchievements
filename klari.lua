local lbc = require "necro.client.leaderboard.LeaderboardContext"
local ach = require "InGameAchievements.api"
local SettingsStorage = require "necro.config.SettingsStorage"
local Settings = require "necro.config.Settings"
local achDrod = ach.register({
    id = "InGameAchievements_klariDeadly",
    version = 2,
    friendlyName = "Deadly Crypt of Death",
    desc = "Complete solo Klarinetta All Zones with Zweihänder controls set to 'DROD, 90° rotations'\n(Shift-F9, search for 'zweihaender.control'. Set it after you start the run!) (No-beat mode is allowed)",
    descShort = "Klarineta All Zones with 'DROD, 90° rotations' controls clear!",
    icon = "mods/InGameAchievements/klari_drod.png",
    sortOrder = ach.sortOrder.ALL_ZONES_SPECIAL,
})
-- local achOrth = ach.register({
--     id = "InGameAchievements_klariOrthagonal",
--     version = 0,
--     friendlyName = "Orthagonetta",
--     desc = "Clear solo Klarinetta All Zones Mode with Zweihänder controls set to 'Orthro rotate + move'\n(Shift-F9, search for 'zweihaender.control')",
--     descShort = "Klarineta All Zones, 'Orthro rotate + move' controls",
--     icon = "mods/InGameAchievements/klari_orthag.png",
-- })
event.runComplete.add("unlockKlariCheevos", {order = "leaderboardSubmission", sequence = 1}, function (ev)
    -- dbg(ev)
    if ev.summary.victory then --win!
        
        local context = lbc.getFinalRunContext()
        if (context.maximumPlayers <= 1) and context.completion.victory and (context.gameMode == "AllZones") and (context.characters[1] == "Sync_Klarinetta") then
                -- dbg(context.customRules[1]["mod.Sync.zweihaender.zweihaender.control"])
                -- dbg(SettingsStorage.get("mod.Sync.zweihaender.zweihaender.control"))
            if (SettingsStorage.get("mod.Sync.zweihaender.zweihaender.control") == 4) then
                achDrod.unlock()
            end
            -- if (context.customRules[1]["mod.Sync.zweihaender.zweihaender.control"] == "SAUSAGE") then
            --     achOrth.unlock()
            -- end
        end
    end
end)