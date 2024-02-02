local zStandard = require "system.utils.serial.ZStandard"
local serialization = require "system.utils.serial.Serialization"
local filters = require "InGameAchievements.filters"
local base64 = require "system.utils.serial.Base64"
local settings = require "necro.config.Settings"

local iconStorage = {}

iconData = settings.user.table {
	id = "iconData",
	visibility = settings.Visibility.HIDDEN, --doesnt need to be restricted b/c who cares if you cheat the icons lol
	serializer = function(data)
		return base64.encode(zStandard.compress(serialization.serialize(data)))
	end,
	deserializer = function(data)
		return serialization.deserialize(zStandard.decompress(base64.decode(data)))
	end,
	format = function()
		return "<do not select, framerate will die>"
	end,
}

function iconStorage.getImage(id)
	return filters.listToImage(iconData[id] or filters.imageToList("mods/InGameAchievements/error.png"))
end

function iconStorage.setImage(id, image)
	iconData[id] = filters.imageToList(image)
end

function iconStorage.setRaw(id, data)
	iconData[id] = data
end

function iconStorage.upgradeFromOldVer(icon)
	local new = {}

	for y = 0, #icon do
		for x = 0, #icon[y] do
			new[(x + 1) + (y * 32)] = icon[y][x]
		end
	end
	
	return new
end

-- function iconStorage.serializeFromArray(array)
-- 	return base64.encode(zStandard.compress(serialization.serialize(array)))
-- end

-- function iconStorage.serializeFromImage(image)
-- 	return iconStorage.serializeFromArray(filters.imageToArray(image))
-- end

-- function iconStorage.deserialize(data)
-- 	return serialization.deserialize(zStandard.decompress(base64.decode(data)))
-- end

-- function iconStorage.deserializeAndGet(data)
-- 	return filters.listToImage(iconStorage.deserialize(data))
-- end

--[[
local test = "mods/InGameAchievements/error.png"

test = iconStorage.serializeFromImage(test)

dbg(test)

test = iconStorage.deserialize(test)

dbg(test)


local testIcon = "mods/InGameAchievements/error.png"

local testArray = filters.imageToArray(testIcon)

local b64before = zStandard.compress(serialization.serialize(testArray))

local b64after = base64.encode(zStandard.compress(serialization.serialize(testArray)))

dbg(#b64before)

dbg(#b64after)

local testIcon = "mods/InGameAchievements/error.png"

local testArray = filters.imageToArray(testIcon)

local testList = {}

for y = 0, #testArray do
	for x = 0, #testArray[y] do
		testList[(x + 1) + ((y + 1) * 32)] = testArray[y][x]
	end
end

dbg(testList)

dbg(#base64.encode(zStandard.compress(serialization.serialize(testList))))
dbg(#base64.encode(zStandard.compress(serialization.serialize(testArray))))
]]

return iconStorage