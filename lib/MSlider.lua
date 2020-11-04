------------------------------MSLIDER--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'moonUtils'
require 'MLabel'
--require 'VSprite'

loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local M = require("public.message")
local Image = require("public.image")
local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Table = require("public.table")
local Sprite = require("public.sprite")
local T = Table.T
local Element = require("gui.element")


local hasBeenDragging = false
local dragStartX, dragStartY
local origVal = 0

local MSlider = Element:new()
MSlider.__index = MSlider
MSlider.defaultProps = {
    name = "mslider", type = "MSLIDER", display = false,
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
    horizFrames = false
}

function MSlider:new(props)
    local MSlider = self:addDefaultProps(props)
    return setmetatable(MSlider, self)
end


function MSlider:init()
    self.sprite = Sprite:new({})
    if self.image then
        self.sprite:setImage(IMAGE_FOLDER.."/"..self.image)
        self.sprite.frame = { w = self.w, h = self.h }
    end
    --if not self.sprite.image then error("MSlider: The specified image was not found") end
end

function MSlider:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0
  --gfx.blit(self.buffer, 1, 0, self.state * self.w, 0, self.w, self.h, self.x, self.y, self.w, self.h)

    self.sprite:draw(x, y, w, h, self.frame, self.frames, self.horizFrames)
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
        --M.Msg('frame = '..self.frame)
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

  local vLabel = GUI.createElement ({
      type = "MLabel",
      vertical = false,
      caption = 'testing horiz label',
      name = 'testVLabel',
      w = 150, h = 30,
      x = 0, y = 40
  })

  local label = GUI.createElement ({
    type = "MLabel",
    vertical = true,
    caption = 'testing vertical label',
    name = 'testLabel',
    w = 150, h = 30,
    x = 300, y = 40
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
