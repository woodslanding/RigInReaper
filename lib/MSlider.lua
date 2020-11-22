------------------------------MSLIDER--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")()


local GUI = require("gui.core")
local M = require("public.message")
local Image = require("public.image")
local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Table = require("public.table")
local Sprite = require("public.sprite")
local GFX = require("public.gfx")
local T = Table.T
local Element = require("gui.element")


local hasBeenDragging = false
local dragStartX, dragStartY
local origVal = 0

local MSlider = Element:new()
MSlider.__index = MSlider
MSlider.defaultProps = {
    name = "mslider", type = "MSLIDER", displayOnly = false,
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

function MSlider:new(props)
    local MSlider = self:addDefaultProps(props)
    return setmetatable(MSlider, self)
end


function MSlider:init()
    self.sprite = Sprite:new({})
    if self.image then
        self.sprite:setImage(self.image)
        self.sprite.frame = { w = self.w, h = self.h }
    end
    self:val(self.value)
    --well, I could imagine implementing an invisible slider someday....
    --if not self.sprite.image then error("MSlider: The specified image was not found") end
end

--this keeps the component from responding to the mouse
function MSlider:containsPoint (x, y)
    if self.displayOnly then return false 
    else return  ( x >= (self.x or 0) and x < ((self.x or 0) + (self.w or 0)) and
                   y >= (self.y or 0) and y < ((self.y or 0) + (self.h or 0)) )
    end
end

function MSlider:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0

    if self.color then
        Color.set(self.color)
        local round = self.round or 0
        GFX.roundRect(self.x, self.y, self.w-1, self.h-1, round, true, true)
    end

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

function MSlider:onMouseDown(state)
    dragStartX = state.mouse.x
    dragStartY = state.mouse.y
    origVal = self.value
end
--A drag works normally, but you can touch the fader to immediately go to a specific value
--Todo:  fade to new value?
function MSlider:onMouseUp(state)
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
function MSlider:onDrag(state)
    hasBeenDragging = true
    local pixval = self:getRange()/self:throw()
    local delta
    if self.horizontal then delta = state.mouse.x - dragStartX else delta = dragStartY - state.mouse.y end
    local newVal = (delta * pixval) + origVal
    --M.Msg('newVal - '..newVal)
    self:val(newVal)  
    self:func(table.unpack(self.params))
end

function MSlider:setColor(color)  
    self.color = color
    self:redraw()
end

function MSlider:getRange() return self.max - self.min end

function MSlider:throw()
    local throw
    if self.horizontal then throw = self.w else throw = self.h end
    return throw
end

function MSlider:val(incoming)
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

GUI.elementClasses.MSlider = MSlider
--[[
local slider = GUI.createElement({
    frames = 11, frame = 5,
    vertText = true,
    name = "slider",
    min = -5,
    max = 5,
    value = 0,
    type = "MSlider",
    w = 180,h = 48,x = 0,y = 0,
    labelX = 0,labelY = 0,
    --image =  "meterL.png",
    image = "oct.png",
    func = function(self, a, b, c) Msg(self.name, self:val()) end,
    params = {"a", "b", "c"}
  })

  local vSlider = GUI.createElement({
    frames = 144, frame = 0,
    horizontal = false,
    caption = 'test',
    name = "vslider",
    min = 0,
    max = 99,
    value = 0,
    type = "MSlider",
    w = 64,h = 288,x = 200,y = 10,
    labelX = 0,labelY = 0,
    image =  "VolVert.png",
    func = function(self, a, b, c) self.caption = self.value end,
    params = {"a", "b", "c"}
  })
------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
  name = "MSLIDER TEST",
  w = 600,
  h = 400
})

------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})

layer:addElements(vSlider, label,vLabel)
window:addLayers(layer)
window:open()

GUI.Main()--]]
