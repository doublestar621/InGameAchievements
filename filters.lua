
local bitmap = require "system.game.Bitmap"
local color = require "system.utils.Color"
local commonFilter = require "necro.render.filter.CommonFilter"
local ecs = require "system.game.Entities"
local grayscaleFilter = require "necro.render.filter.GrayscaleFilter"

-- local baseImg = "mods/InGameAchievements/base.png"
local hardcoreImg = "mods/InGameAchievements/base_hardcore.png"
-- dbg(bitmap.load("mods/InGameAchievements/base.png"))

local bitmapToImage = commonFilter.register("InGameAchievements_bitmapToImage", { }, { bitmap = true }, function (args)
    return args.bitmap
end)

local arrayToImage = commonFilter.register("InGameAchievements_arrayToImage", { }, { array = true }, function (args)
    
    local ar = args.array
    
    local bm = bitmap.new(32, 32)
    -- dbg(ar)
    for y = 0, bm.getHeight() - 1 do
        for x = 0, bm.getWidth() - 1 do
            bm.setPixel(x, y, ar[y][x])
        end
    end
    -- dbg("done")
    return bm
end)

local listToImageFilter = commonFilter.register("InGameAchievements_listToImage", { }, { list = true }, function (args)
    
    local list = args.list
	
    local bm = bitmap.new(32, 32)
	
	for i = 1, #list do
		bm.setPixel(i - 1, 0, list[i]) --it wraps horizontally so this *should* work
	end
	
    return bm
end)

local function listToImage(list)
	return listToImageFilter{list = list}
end

local function imageToList(image)
	local bm = bitmap.load(image) or bitmap.load("mods/InGameAchievements/error.png") --more graceful error lol
    local array = {}
    for y = 0, bm.getHeight() - 1 do
        for x = 0, bm.getWidth() - 1 do
            array[#array + 1] = bm.getPixel(x, y)
        end
    end
    return array
end

local filterLocked = commonFilter.register("InGameAchievements_filterLocked", { image = true }, { }, function (args)
    for y = 0, args.image.getHeight() - 1 do
        for x = 0, args.image.getWidth() - 1 do
            local h, s, v, a = color.toHSV(args.image.getPixel(x,y))
            args.image.setPixel(x, y, color.hsv(h, 0, v*0.6, a))
        end
    end
    return args.image
end)

local function imageToArray(image)
    local bm = bitmap.load(image) or bitmap.load("mods/InGameAchievements/error.png") --more graceful error lol
    local array = {}
    for y = 0, bm.getHeight() - 1 do
        array[y] = {}
        for x = 0, bm.getWidth() - 1 do
            array[y][x] = bm.getPixel(x, y)
        end
    end
    return array
end

local function bitmapToArray(bm)
    local array = {}
    for y = 0, bm.getHeight() - 1 do
        array[y] = {}
        for x = 0, bm.getWidth() - 1 do
            array[y][x] = bm.getPixel(x, y)
        end
    end
    return array
end

local function doPrefix(path)
    return "/"..path
end

local function getGenericAchievementImage(entity)
    --sould return an image. 
    local bm = bitmap.load("mods/InGameAchievements/base_hardcore.png") --yes.ha.
    local spriteLowerData = entity.sprite
    local spriteLower = bitmap.load(doPrefix(spriteLowerData.texture)) --load entity's texture
    spriteLower = bitmap.crop(spriteLower, {0, 0, spriteLowerData.width, spriteLowerData.height})
    local spriteUpper = bitmap.new(1, 1)
    if entity.characterWithAttachment then
        local spriteUpperData = ecs.getEntityPrototype(entity.characterWithAttachment.attachmentType).sprite
        if spriteUpperData and spriteUpperData.texture then
            spriteUpper = bitmap.load(doPrefix(spriteUpperData.texture)) --load head's texture
            if spriteUpper then
                spriteUpper = bitmap.crop(spriteUpper, {0, 0, spriteUpperData.width, spriteUpperData.height})
            else
                spriteUpper = nil
            end
        end
    end
    local offsetX = (32 - spriteLower.getWidth()) / 2
    -- local offsetUpper --vertical
    for y = 0, bm.getHeight() - 1 do
        for x = 0, bm.getWidth() - 1 do
            if spriteLower then
                if x < spriteLower.getWidth()-1 and y < spriteLower.getHeight()-1 then
                    local p = spriteLower.getPixel(x,y)
                    if p and bm.getPixel(x+offsetX, y) and color.getA(p) > 0 then --may need special casing for transparent players in the future?
                        bm.setPixel(x+offsetX, y, p)--i think.
                    end
                end
            end
            if spriteUpper then
                if x < spriteUpper.getWidth()-1 and y < spriteUpper.getHeight()-1 then
                    local p = spriteUpper.getPixel(x,y)
                    if p and bm.getPixel(x+offsetX, y) and color.getA(p) > 0 then --may need special casing for transparent players in the future?
                        bm.setPixel(x+offsetX, y, p)--i think.
                    end
                end
            end
        end
    end
    return bm
end

return{
    bitmapToImage = bitmapToImage,
    arrayToImage = arrayToImage,
    imageToArray = imageToArray,
    bitmapToArray = bitmapToArray,
    getGenericAchievementImage = getGenericAchievementImage,
    filterLocked = filterLocked,
	
	listToImage = listToImage,
	imageToList = imageToList,
}