------------------------------MSPINNER--------------------------------
-- has a single image and a range of values or a table of values
-- vals = {1,3,4,6} or min = 1, max = 5, inc = 1
--
----------------------------------------------------------------------
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
local Font = require("public.font")
local Color = require("public.color")
local Sprite = require("public.sprite")
local Math = require("public.math")
local GFX = require("public.gfx")

local Element = require("gui.element")
--[[
    for a momentary switch set momentary = true.  On and off values are min and max
    for a multi-position switch set momentary false.  A spinner increments and decrements
    depending on which side is clicked.  Top/bottom vs left/right is set with 'horizontal'
    only vertical frames are supported by my version of 'vSprite'
]]
local MButton = Element:new()
MButton.__index = MButton
MButton.defaultProps = {
    name = "mbutton_"..math.random(), type = "MButton",
    displayOnly = false,
    momentary = false, loop = true,
    wrap = true, spinner = false, vertical = true,
    x = 16, y = 32, w = 64, h = 48,
    labelX = 0, labelY = 0,
    caption = "", font = 2, textColor = "white",
    captions = {},
    value = 0, --stores tableIndex if using vals{} not actual table val
    vals = nil, --use this OR min,max,inc
    min = 0,  max = 10, inc = 1,
    image = nil,
    func = function(self) end,
    params = {},
    frame = 0,
    frames = 1,
    vertFrames = true
}

function MButton:new(props)
    local button = self:addDefaultProps(props)
    return setmetatable(button, self)
end

function MButton:init()
    --M.Msg('Calling init for button '..self.name)
    self.sprite = Sprite:new({})
    if self.image then
        self.sprite:setImage(self.image,self.vertFrames)
        self.sprite.frame = { w = self.w, h = self.h }
    end
    --if not self.vSprite.image then error("The specified image was not found") end
    self:val(self.value)
end
--this keeps the component from responding to the mouse
function MButton:containsPoint (x, y)
    if self.displayOnly then return false
    else return  ( x >= (self.x or 0) and x < ((self.x or 0) + (self.w or 0)) and
                   y >= (self.y or 0) and y < ((self.y or 0) + (self.h or 0)) )
    end
end

function MButton:draw()
    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0
    if self.color then
        Color.set(self.color)
        local round = self.round or 0
        GFX.roundRect(self.x, self.y, self.w-1, self.h-1, round, true, true)
    end
    if self.image then self.sprite:draw(x, y, w, h,self.frame, self.frames, self.vertFrames) end

    Color.set(self.textColor)
    Font.set(self.font)
    if self.caption then
        local str = self:formatOutput(self.caption)
        str = str:gsub([[\n]],"\n")
        local strWidth, strHeight = gfx.measurestr(str)
        local playX = w-strWidth
        local playY = h - strHeight
        gfx.x = x + (playX / 2) + (self.labelX * playX)
        gfx.y = y + (playY / 2) + (self.labelY * playY)
        gfx.drawstr(str)
    end
end

function MButton:setFrame(frame)
    if self.frames == 1 then self.frame = 0
    elseif frame <= self.frames and frame >= 0 then
        self.frame = frame
    end
    self:redraw()
end


function MButton:increment(incVal)
    if incVal == 0 then return end
    local usingRange = self.min ~= nil and self.max ~= nil
    --self:m('calling inc =,'..incVal..' using range = '..tostring(usingRange))
    if self.vals and (#self.vals ~= self.frames) then M.Msg('#vals must = frames')
    elseif not self.wrap then
        if (self.vals and self.value == self.vals[1] and incVal < 0)
            or (self.vals and self.value < self.vals[#self.vals] and incVal > 0)
            or (usingRange and self.value == self.min and incVal < 0)
            or (usingRange and self.value == self.max and incVal > 0)
        then return 0
        elseif (usingRange and incVal < 0) then self.value = self.value - 1 self:setFrame(self.frame - 1)
        else self.value = self.value + 1 self:setFrame(self.frame + 1)
        end
    --we are wrapping from here on out
    elseif self.vals then
        if self.value == self.vals[1] and incVal < 0 then
            self.value = #self.vals
            self:setFrame(self.frames - 1)
            self:m('setting frame to'..self.frames - 1)
        elseif self.value > self.vals[#self.vals] and incVal > 0 then
            self.value = 1
            self.frame = 0
        elseif incVal < 0 then
            self.value = self.value - 1     self:setFrame(self.frame - 1)
            self:m('setting frame to'..self.frame - 1)
        else self.value = self.value + 1    self:setFrame(self.frame + 1)
            self:m('setting frame to'..self.frame + 1)
        end
    elseif usingRange then
        if self.value == self.min and incVal < 0 then
            self.value = self.max           self:setFrame(self.frames - 1)
            self:m('setting frame to'..self.frames - 1)
        elseif self.value == self.max and incVal > 0 then
            self.value = self.min           self:setFrame(0)
            self:m('setting frame to'..0)
        else self.value = self.value + incVal
            if incVal > 0 then              self:setFrame(self.frame + 1)
                self:m('setting frame to'..self.frame + 1)
            else                            self:setFrame(self.frame - 1)
                self:m('setting frame to'..self.frame - 1)
            end
        end
    end
end

function MButton:onMouseUp(state)
    if self.momentary and not self.spinner then self.value = self.min or self.vals[1] or 0
        self.frame = 0
    elseif self.spinner then
        if self.momentary then self.frame = 0
        elseif self:spinUp() then self:increment(self.inc or 1)
        else self:increment(0 - self.inc or -1)
        end
    else self:increment(self.inc, true)
    end
    if self:containsPoint(state.mouse.x, state.mouse.y) then
        self:func(table.unpack(self.params))
    end
    self:redraw()
end

function MButton:onMouseDown(state)
    if self.momentary then
        if self.spinner then
            if self:spinUp(state) then self:val(1) else self:val(-1) end
            self.frame = self.frames - 1
        else
            self.value = self.max or 1
            self.frame = self.frames - 1
        end
    end
end

function MButton:spinUp(state)
    local midX = self.x + (self.w/2)
    local midY = self.y + (self.h/2)
    return (self.horizontal and state.mouse.x > midX ) or ( not self.horizontal and state.mouse.y < midY)
end
-- Not used
function MButton:onDrag()
end

function MButton:setColor(color)
    self.color = color
    self:redraw()
end

--[[
    When setting value externally, we will want to use the value in the table
    But internally we will be using the table index.  If it is a one-frame vSprite
    we will look to max and min to set the value, and frame won't matter.  If we
    have a value table, however, we'll want to deliver the appropriate value by
    referencing the FrameNumber.
]]

function MButton:val(set)
    --if set then M.Msg('setting val to '..set..' for '..self.name)end
    if not set and self.vals then return self.vals[self.value]
    elseif not set and self.min and self.max then return self.value
    elseif self.vals then
        for index,val in pairs(self.vals) do
            if val == set then
                self.value = index
                self:setFrame(index - 1)
                if self.captions and self.caption then
                     self.caption = self.captions[self.frame]
                end
                return true
            end
        end
        M.Msg("can't set value of control to: "..set)
    elseif self.min and self.max then
        if set >= self.min and set <= self.max then
            self.value = set
            local range = self.max - self.min + 1
            local pct =  (set-self.min)/range
            local frame = Math.round((self.frames) * pct)
            self:setFrame(frame)
        end
    end
end

function MButton:m(text)
    --M.Msg(self.name..': '..text)
end

function MButton:__tostring()
    return self.name..' = '..self:val()
end

function MButton:setCaption(text)
    self.caption = text
    self:redraw()
end

function MButton:SaveState(path)

end

function MButton:LoadState(path)
    local f = assert(loadfile('c:\\lua\\'..filename..'.lua'))
    local data = f()

    return self
end

--return MButton
GUI.elementClasses.MButton = MButton
------------Test---------------
--[[
local imageFolder = reaper.GetResourcePath().."/Scripts/Images/"

switches = {}
function createSwitch(i)
    local switch = GUI.createElement({
        momentary = false,
        w = 80,h = 40,
        x = i * 80,y = 0,
        color = 'blue',
        wrap = true,
        frames = 3,
        vals = {1,2,3},
        value = 1,
        name = "switch"..i,
        type = "MButton",
        labelX = 0, labelY = 0,
        image =  imageFolder.."Notesource.png",
        func = function(self) M.Msg('setting track'..i.. 'to '..self.value) TrackName(i,"track "..self.value) end,
        params = {"a", "b", "c"}
    })
    switches[i] = switch
    return switch
end

function MSpinnerTest()
    local spinner = GUI.createElement({
        type = "MButton", spinner = true,
        name = 'spinner',
        color = 'red',
        w = 40,h = 80,
        x = 0,y = 200,
        wrap = true,
        frames = 1,
        caption = '1',
        value = 1,
        min = 1, max = 3,
        image = imageFolder.."EffectSpin.png",
        func = function(self) switches[1]:val(self.value) self.caption = self:val() M.Msg('function called:'..self.value) end,
    })
    return spinner
end
------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
  name = "MButton Test",
  w = 600,
  h = 500
})
------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})
for i = 1,8 do
    layer:addElements(createSwitch(i))
end
layer:addElements(MSpinnerTest())
window:addLayers(layer)
window:open()

GUI.Main()
--]]