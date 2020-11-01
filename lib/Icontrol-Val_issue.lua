------------------------------ICONROL--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

--local MU = require 'moonUtils'

loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local M = require("public.message")
local Sprite = require("public.sprite")
local Image = require("public.image")
local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Table = require("public.table")
local T = Table.T

local buttonImages = Image.loadFolder(reaper.GetResourcePath().."/Scripts/MOON/Images" )

local Element = require("gui.element")

MODES = { BUTTON = 0, SWITCH = 1, SPINNER = 2, SLIDER = 3, METER = 4, DISPLAY = 5 }

local hasBeenDragging = false



local IControl = Element:new()
IControl.__index = IControl
IControl.defaultProps = {
    name = "icontrol", type = "ICONTROL",
    mode = MODES.SWITCH, loop= false, frames = 2, horizontal = true,
    x = 16, y = 32, w = 24, h = 24,
    labelX = 0, labelY = 0,
    caption = "IControl", font = 3, textColor = "text",
    func = function () end,
    params = {},
    state = 0,
    min = 0,
    max = 1,
    sens = 1
}

function IControl:new(props)
    local IControl = self:addDefaultProps(props)
    return setmetatable(IControl, self)
end

function IControl:init()
    self.sprite = Sprite:new({})
    self.sprite:setImage(self.image)
    self.sprite.frame = { w = self.w, h = self.h }
    if not self.sprite.image then error("IControl: The specified image was not found") end
end

function IControl:draw()
    
    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0
  --gfx.blit(self.buffer, 1, 0, self.state * self.w, 0, self.w, self.h, self.x, self.y, self.w, self.h)
 
    self.sprite:draw(x, y, w, h, self.state, self.frames)
      -- Draw the caption
    local state = self.state
    Color.set(self.textColor)
    Font.set(self.font)

    local str = self:formatOutput(self.caption)
    str = str:gsub([[\n]],"\n")

    local strWidth, strHeight = gfx.measurestr(str)
    local playX = w-strWidth
    local playY = h - strHeight
    
    gfx.x = x + (playX / 2) + (self.labelX * playX)
    gfx.y = y + (playY / 2) + (self.labelY * playY)
    
    gfx.drawstr(str)
end

function IControl:ongoingUpdate(state)
  if self.state > 0 and not self:containsPoint(state.mouse.x, state.mouse.y) then
    self.state = 0
    self:redraw()
  end
end

function IControl:onMouseDown(state)
    DragStartX = state.mouse.x
    DragStartY = state.mouse.y
    local mouseVal = self.horizontal and state.mouse.x or state.mouse.y
    DragStartState = self:getState(mouseVal/self:longSide())
    if self.mode == MODES.BUTTON then 
      self.state = 1
      self:val(self.max)
    end
    self:redraw()
end

function IControl:increment(goingUp,wrapping)
    local inc = nil
    if goingUp then inc = 1 else inc = -1 end
    if goingUp == nil then goingUp = true end
    if wrapping == nil then wrapping = true end
    local limit = self.frames - 1
    if (self.state == limit and goingUp and wrapping)
       or (self.state == 0 and not goingUp and not wrapping) then self.state = 0
    elseif (self.state == 0 and not goingUp and wrapping) 
        or (self.state == limit and goingUp and not wrapping) then self.state = limit
    else self.state = self.state + inc end
    --M.Msg('state = ',self.state)
    return true
end

function IControl:onMouseUp(state)
    local midX = self.x + (self.w/2)
    local midY = self.y + (self.h/2)
    if self.mode == MODES.SWITCH then self:increment(true,true)
    elseif self.mode == MODES.SPINNER and self.horizontal and state.mouse.x < midX then self:increment(false,self.loop)
    elseif self.mode == MODES.SPINNER and self.horizontal and state.mouse.x > midX then self:increment(true,self.loop)
    elseif self.mode == MODES.SPINNER and not self.horizontal and state.mouse.y < midY then self:increment(false,self.loop)
    elseif self.mode == MODES.SPINNER and not self.horizontal and state.mouse.y > midY then self:increment(true,self.loop)
    elseif self.mode == MODES.SLIDER and not hasBeenDragging  then
        --move slider to mouse position    
        local pos = self.horizontal and state.mouse.x or state.mouse.y
        local rel = self.horizontal and pos - self.x or pos - self.y
        local pct = rel / self:longSide()
        self.state = self:getState(pct)
    elseif self.mode == MODES.BUTTON then self.state = 0 self.val(self.min) end
    if self:containsPoint(state.mouse.x, state.mouse.y) then
        self:func(table.unpack(self.params))
    end
    self:redraw()
    hasBeenDragging = false
end

-- Will continue being called even if you drag outside the element
function IControl:onDrag(state,last)
    if self.mode == MODES.SLIDER then
        hasBeenDragging = true
        local pixels = self.horizontal and  state.mouse.x - DragStartX  or state.mouse.y - DragStartY
        local pct = (pixels/self:longSide()) --getting funky values
        M.Msg('mouse state',state.mouse.x,'drag start',DragStartX)
        M.Msg('state:',self.state,'pct: ',pct)
        self.state = Math.clamp( self:getState(pct) - DragStartState, 0, self.frames-1)      
        --local adj = ((self.max - self.min) * self.sens) / self:longSide()
        --self.state = math.floor ( Math.clamp(self.state + (pixels * adj), self.min, self.max) - self.min )
        self:redraw()
        
        
    end
end

function IControl:valAsPercent()


end

function IControl:getState(pctVal)
    local pctAdj = (self.frames-1)/self.frames
    local pxMouse = pctAdj * pctVal * self.h * (self.frames)
    return(Math.round(pxMouse/self.h))
end

function IControl:val(incoming)
  --todo
end

function IControl:longSide()
    local longSide
    if self.horizontal then longSide = self.w else longSide = self.h end
    return longSide
end

GUI.elementClasses.IControl = IControl

local switch = GUI.createElement({
    mode = MODES.SPINNER,
    loop = false,
    frames = 3,
    name = "switch",
    type = "IControl",
    w = 64,h = 48,x = 0,y = 0,
    labelX = 0,labelY = 0,
    image =  buttonImages.path.."/".."comboButton3Pos.png",
    func = function(self, a, b, c) Msg(self.name, self:val()) end,
    params = {"a", "b", "c"}
  })

local slider = GUI.createElement({
    mode = MODES.SLIDER,
    loop = false,
    frames = 11,
    name = "slider",
    min = -5,
    max == 5,
    type = "IControl",
    w = 180,h = 48,x = 0,y = 0,
    labelX = 0,labelY = 0,
    image =  buttonImages.path.."/".."oct.png",
    func = function(self, a, b, c) Msg(self.name, self:val()) end,
    params = {"a", "b", "c"}
  })
------------------------------------
-------- Window settings -----------
------------------------------------


local window = GUI.createWindow({
  name = "Working with Images",
  w = 500,
  h = 500,
  anchor = "mouse"
})
--[[
local function goingUpdateRotation(self)
  mainImage.sprite.rotate.angle = self:val()
  mainImage:redraw()
end
local function goingUpdateScale(self)
  mainImage.sprite.scale = self:val()
  mainImage:redraw()
end--]]


------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})

layer:addElements(slider)
window:addLayers(layer)
window:open()

GUI.Main()
