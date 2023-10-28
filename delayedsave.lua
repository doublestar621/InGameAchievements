--save settings at times where the lag spike is less noticable
local settingsStorage = require "necro.config.SettingsStorage"
local settings = require "necro.config.Settings"
local gameState = require "necro.client.GameState"
local menu = require "necro.menu.Menu"
local currentLevel = require "necro.game.level.CurrentLevel"

local delayedSave = {}

local saveLayer = settings.Layer.LOCAL

savePending = false

function delayedSave.perform()
	--if we're in a state where lagspikes happening are fine-ish, save immedietely.
	if (not gameState.isPlaying()) or currentLevel.isSafe() then
		settingsStorage.saveToFile(saveLayer)
	else
		savePending = true
	end
end

local function doSave()
	if savePending then
		settingsStorage.saveToFile(saveLayer)
		savePending = false
	end
end

event.gameStateLevel.add("saveSettings", {order = "stopMusic", sequence = 1000}, doSave)
event.runComplete.add("saveSettings", {order = "replaySave", sequence = 1000}, doSave)
event.gameStatePause.add("saveSettings", {order = "richPresence", sequence = 1000}, doSave)
event.gameStateEnterLobby.add("saveSettings", {order = "init", sequence = -1000}, doSave)
event.gameStateLeaveLobby.add("saveSettings", {order = "reset", sequence = -1000}, doSave)
event.gameStateMainMenu.add("saveSettings", {order = "lobby", sequence = -1000}, doSave)

return delayedSave