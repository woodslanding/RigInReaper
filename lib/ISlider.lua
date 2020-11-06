------------------------------ISLIDER--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")()

--Set your image path here...
IMAGE_FOLDER = reaper.GetResourcePath().."/Scripts/Images"

local GUI = require("gui.core")
local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Sprite = require("public.sprite")
local Element = require("gui.element")


local hasBeenDragging = false
local dragStartX, dragStartY
local origVal = 0

local ISlider = Element:new()
ISlider.__index = ISlider
ISlider.defaultProps = {
    name = "islider", type = "ISLIDER", display = false,
    frames = 20, horizontal = false,
    x = 16, y = 32, w = 24, h = 24,
    labelX = 0, labelY = 0,
    caption = "", font = 3, textColor = "text",
    func = function () end,
    params = {},
    min = 0,
    max = 1,
    sens = 1,
    value = 0,
    frame = 5,
    vertFrames = true
}

function ISlider:new(props)
    local ISlider = self:addDefaultProps(props)
    return setmetatable(ISlider, self)
end


function ISlider:init()
    self.sprite = Sprite:new({})
    if self.image then
        self.sprite:setImage(IMAGE_FOLDER.."/"..self.image)
        self.sprite.frame = { w = self.w, h = self.h }
    end
    --well, I could imagine implementing an invisible slider someday....
    --if not self.sprite.image then error("ISlider: The specified image was not found") end
end

function ISlider:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0

    self.sprite:draw(x, y, w, h, self.frame, self.frames, self.vertFrames)
      -- Draw the caption
    Color.set(self.textColor)
    Font.set(self.font)

    local str = self:formatOutput(self.caption)
    str = str:gsub([[\n]],"\n")

    local strWidth, strHeight = gfx.measurestr(str)
    local playX = w-strWidth
    local playY = h - strHeight

    gfx.x = x + (playX / 2) + (self.labelX * playX)
    gfx.y = y + (playY / 2) + (self.labelY * playY)
end

function ISlider:onMouseDown(state)
    dragStartX = state.mouse.x
    dragStartY = state.mouse.y
    origVal = self.value
end
--A drag works normally, but you can touch the fader to immediately go to a specific value
--Todo:  fade to new value?
function ISlider:onMouseUp(state)
    if  not hasBeenDragging  then
        --move slider to mouse position
        local pct
        if self.horizontal then
            pct = (state.mouse.x - self.x)/self:throw()
        else  pct = 1 - ((state.mouse.y - self.y)/self:throw()) --y measured from top!
        end
        self:val(self.min + (pct * self:getRange()))
        self:func(table.unpack(self.params))
    end
    hasBeenDragging = false
end

-- Will continue being called even if you drag outside the element
function ISlider:onDrag(state)
    hasBeenDragging = true
    local pixval = self:getRange()/self:throw()
    local delta
    if self.horizontal then delta = state.mouse.x - dragStartX else delta = dragStartY - state.mouse.y end
    local newVal = (delta * pixval) + origVal
    self:val(newVal)
    self:func(table.unpack(self.params))
end

function ISlider:getRange() return self.max - self.min end

function ISlider:throw()
    local throw
    if self.horizontal then throw = self.w else throw = self.h end
    return throw
end

function ISlider:val(incoming)
    if incoming then
        self.value = incoming
        local pct = ((self.value - self.min)/self:getRange())
        local frame = Math.round((self.frames-1) * pct)
        if frame < 0 then frame = 0 elseif frame > self.frames - 1 then frame = self.frames - 1 end
        self.frame = frame
        self:redraw()
    else return self.value
    end
end

GUI.elementClasses.ISlider = ISlider

----------------------------------------------------------------
--  Comment out test code below if using as component... otherwise--Problems!!
----------------------------------------------------------------
--
local slider = GUI.createElement ({
    type = "ISlider",
    name = 'vol',
    image = 'MeterL.png',
    caption = 'caption',
    frames = 25, frame = 13,
    horizontal = true,
    min = 0, max = 1, value = 0,
    w = 96, h = 20, x = 10, y = 10,
    func = function(self, a, b, c) self.caption = self.value end,
})

local vSlider = GUI.createElement({
    frames = 72,horizontal = false,
    --horizFrames = true,
    --vertText = true,
    name = "send",
    min = 0,
    max = 99,
    value = 0,
    type = "ISlider",
    w = 44,h = 144,x = 150,y = 10,
    labelX = 0,labelY = 0,
    image = "Send.png",
    func = function(self, a, b, c) self.caption = self.value end,
    params = {"a", "b", "c"}
})
------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
  name = "ISLIDER TEST",
  w = 600,
  h = 400
})

------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})

layer:addElements(vSlider, slider)
window:addLayers(layer)
window:open()

GUI.Main()--]]
