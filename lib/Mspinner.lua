------------------------------ICONROL--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'moonUtils'

loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local M = require("public.message")
local Sprite = require("public.sprite")
local Image = require("public.image")
local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Table = require("public.table")
local GFX = require("public.gfx")
local T = Table.T

local Element = require("gui.element")

MODES = { BUTTON = 0, SWITCH = 1, SPINNER = 2, DISPLAY = 3 }

local IControl = Element:new()
IControl.__index = IControl
IControl.defaultProps = {
    name = "icontrol", type = "ICONTROL",
    mode = MODES.SWITCH, loop= true, horizontal = true,
    x = 16, y = 32, w = 64, h = 48,
    labelX = 0, labelY = 0,
    caption = "", font = 2, textColor = "white",
    color = 'black', round = 0,
    func = function () end,
    params = {},
    vals = {0,1},
    inc = 1,
    image = nil,
    frames = 2,
    frame = 0
}

function IControl:new(props)
    local IControl = self:addDefaultProps(props)
    return setmetatable(IControl, self)
end

function IControl:init()
    self.sprite = Sprite:new({})
    self.sprite:setImage(self.image)
    self.sprite.frame = { w = self.w, h = self.h }
    self:setFrame(0)
    if not self.sprite.image then error("IControl: The specified image was not found") end
end

function IControl:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0
    Color.set(self.color)
    GFX.roundRect(self.x, self.y, self.w-1, self.h-1, self.round, true, true)
    self.sprite:draw(x, y, w+1, h+1, self.frame, self.frames)

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
  if self.frame > 0 and not self:containsPoint(state.mouse.x, state.mouse.y) then
    self.frame = 0
    self:redraw()
  end
end

function IControl:incFrame(goingUp,wrapping)
    
    local inc = nil
    if goingUp then inc = 1 else inc = -1 end
    if goingUp == nil then goingUp = true end
    if wrapping == nil then wrapping = true end
    local limit = self.frames - 1
    if (self.frame == limit and goingUp and wrapping)
       or (self.frame == 0 and not goingUp and not wrapping) then
        self:setFrame(0)
    elseif (self.frame == 0 and not goingUp and wrapping)
        or (self.frame == limit and goingUp and not wrapping) then
            self:setFrame(limit)
    else self:setFrame(self.frame + inc) end
    return true
end

function IControl:onMouseUp(state)
    local midX = self.x + (self.w/2)
    local midY = self.y + (self.h/2)
    if self.mode == MODES.SWITCH then self:incFrame(true,true)
    elseif self.mode == MODES.DISPLAY then return
    elseif self.mode == MODES.BUTTON then self:setFrame(0)
    elseif self.mode == MODES.SPINNER and self.horizontal and state.mouse.x < midX then self:incFrame(false,self.loop)
    elseif self.mode == MODES.SPINNER and self.horizontal and state.mouse.x > midX then self:incFrame(true,self.loop)
    elseif self.mode == MODES.SPINNER and not self.horizontal and state.mouse.y > midY then self:incFrame(false,self.loop)
    elseif self.mode == MODES.SPINNER and not self.horizontal and state.mouse.y < midY then self:incFrame(true,self.loop)
    end
    if self:containsPoint(state.mouse.x, state.mouse.y) then
        self:func(table.unpack(self.params))
    end
    self:redraw()
end


function IControl:onMouseDown(state)
    if self.mode == MODES.BUTTON then
        self:setFrame(1)
        self:redraw()
    end
end

-- Not used
function IControl:onDrag()
end


function IControl:setFrame(frameNum)
    self.frame = frameNum
    local val = type(self.vals) == 'table' and self.vals[self.frame + 1] or self.frame  --frames numbered from 0
    self:val(val)
end

function IControl:val(set)
    if not set then return self.vals[self.frame] or self.frame end
    if type(self.vals) == 'table' then
        for frame,val in pairs(self.vals) do
            --M.Msg('checking frame',frame,'for val',set,'got',val)
            if val == set then
                self.frame = frame - 1
                if self.captions then self.caption = self.captions[frame] end
                --M.Msg('set frame'..self.frame)--,'val = '..self.vals[self.frame],'caption = '..self.caption)
                return true
            end
        end
        M.Msg("can't set value of control to: "..set)
    --can just set by frame, if there are no values
    elseif set > 0 and set < self.frames - 1 then self.frame = set end
end

GUI.elementClasses.IControl = IControl

local ImageFolder = reaper.GetResourcePath().."/Scripts/MOON/Images"
function CreateSwitch(i)
    local switch = GUI.createElement({
        mode = MODES.SPINNER,
        w = 144,h = 40,
        x = (i-1) * 144,
        color = GetRGB(i*40,90,50),
        loop = true,
        frames = 3,
        captions = {'one','two','three'},
        vals = {0,1,2},
        name = "switch"..i,
        type = "IControl",
        labelX = 0, labelY = 0,
        image =  ImageFolder.."/".."comboButton3Pos.png",
        func = function(self) M.Msg('setting track '..i) TrackName(i,"track "..self.caption) end,
        params = {"a", "b", "c"}
    })
    return switch
end
------------------------------------
-------- Window settings -----------
------------------------------------
--[[
local window = GUI.createWindow({
  name = "IControl Test",
  w = 600,
  h = 500,
  anchor = "mouse"
})
------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})
for i = 1,4 do
    layer:addElements(CreateSwitch(i))
end
window:addLayers(layer)
window:open()
--M.Msg(GetRGB(120,.8,.5))
--switch:val(1)

GUI.Main()
--]]