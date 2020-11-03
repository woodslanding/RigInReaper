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
--[[
    for a momentary switch set stateless = true.  On and off values are min and max
    for a multi-position switch set stateless false.  A spinner increments and decrements
    depending on which side is clicked.  Top/bottom vs left/right is set with 'horizontal'
    only vertical frames are supported by my version of 'sprite'
]]
local MButton = Element:new()
MButton.__index = MButton
MButton.defaultProps = {
    name = "mbutton", type = "MBUTTON",
    stateless = false,
    wrap= true, spinner = false, horizontal = true,
    x = 16, y = 32, w = 64, h = 48,
    labelX = 0, labelY = 0,
    caption = "", font = 2, textColor = "white",
    captions = {},
    color = 'black', round = 0,
    func = function () end,
    params = {},
    value = 0,
    vals = nil,
    min = 0,
    max = 10,
    inc = 1,
    interval = 1,
    image = nil,
    frame = 0,
    frames = 1
}

function MButton:new(props)
    MButton = self:addDefaultProps(props)
    return setmetatable(MButton, self)
end

function MButton:init()
    self.sprite = Sprite:new({})
    if self.image then
        self.sprite:setImage(IMAGE_FOLDER.."/"..self.image)
        self.sprite.frame = { w = self.w, h = self.h }
    end
    if not self.sprite.image then error("Mspinner: The specified image was not found") end
end

function MButton:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0
    Color.set(self.color)
    GFX.roundRect(self.x, self.y, self.w-1, self.h-1, self.round, true, true)
    if self.image then self.sprite:draw(x, y, w+1, h+1,self.frame, self.frames) end

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

function MButton:increment(incVal,wrapping)
    --[[
        if only one frame,  then just increment or decrement the value by interval
        if multiple frames, then select next frame/next value in table
        if 1 frame and table of vals send error
        if multiple frames and min and max, send error
    ]]
    if (self.frames == 1 and type(self.vals) == 'table') then M.Msg('vals table ignored with static frame')
    elseif (self.frames > 1 and type(self.vals) ~= 'table') then M.Msg('min and max ignored with multiple frames')
    end
    if self.min and self.max and self.inc and type(self.vals) ~= 'table' then
        --only one frame, so...
        self.frame = 0
        --M.Msg('value = '..self.value,'min = '..self.min,'inc = '..incVal)
        self.value = IncrementValue(self.value,self.min,self.max,wrapping,incVal)

    else
        local limit = self.frames - 1
        if (self.frame == limit and incVal and wrapping)
        or (self.frame == 0 and not incVal and not wrapping) then self.frame = 0
        elseif (self.frame == 0 and not incVal and wrapping)
            or (self.frame == limit and incVal and not wrapping) then self.frame = limit
        else self.frame = self.frame + incVal end
        self.value = self.vals[self.frame + 1]  --frames numbered from zero
        if self.caption and self.captions then self.caption = self.captions[self.frame + 1] end
    end
    return true
end

function MButton:onMouseUp(state)
    local midX = self.x + (self.w/2)
    local midY = self.y + (self.h/2)
    local change = self.inc or 1
    if self.stateless then
        self.value = self.min
        self.frame = 0
    elseif not self.spinner then self:increment(change,true) --must wrap!
    elseif self.horizontal and state.mouse.x < midX then self:increment(0 - change,self.wrap)
    elseif self.horizontal and state.mouse.x > midX then self:increment(change,self.wrap)
    elseif not self.horizontal and state.mouse.y > midY then self:increment(0 - change,self.wrap)
    elseif not self.horizontal and state.mouse.y < midY then self:increment(change,self.wrap)
    end
    if self:containsPoint(state.mouse.x, state.mouse.y) then
        self:func(table.unpack(self.params))
    end
    self:redraw()
end


function MButton:onMouseDown(state)
    if self.stateless then
        self.value = self.max
        self.frame = 1
    end
end

-- Not used
function MButton:onDrag()
end

--[[
    When setting value externally, we will want to use the value in the table
    But internally we will be using the table index.  If it is a one-frame sprite
    we will look to max and min to set the value, and frame won't matter.  If we
    have a value table, however, we'll want to deliver the appropriate value by
    referencing the FrameNumber.
]]

function MButton:val(set)
    if self.vals then
        if type(self.vals) == 'table' then
            for frame,val in pairs(self.vals) do
                if val == set then
                    self.frame = frame - 1
                    if self.captions and self.caption then self.caption = self.captions[frame] end
                    return true
                end
            end
            M.Msg("can't set value of control to: "..set)
        end
    elseif self.min and self.max then
        if set >= self.min and set <= self.max then
            self.value = set
            if self.frames == 2 and set == self.max then self.frame = 1
            elseif self.frames == 2 and set == self.min then self.frame = 0
            end
        end
    end
end

GUI.elementClasses.MButton = MButton
------------Test---------------
--[[
function CreateSwitch(i,width)
    local switch = GUI.createElement({
        w = width,h = 40,
        x = (i-1) * width,
        color = GetRGB(i*40,90,50),
        wrap = true,
        frames = 4,
        vals = {1,2,4,8},
        value = 1,
        name = "switch"..i,
        type = "MButton",
        labelX = 0, labelY = 0,
        inc = 1,
        image =  "nsSel.png",
        func = function(self) M.Msg('setting track '..i..' to '..self.value) TrackName(i,"track "..self.value) end,
        params = {"a", "b", "c"}
    })
    return switch
end
function MSpinnerTest()
    local spinner = GUI.createElement({
        type = "MButton", spinner = true,
        color = GetRGB(140,100,50),
        w = BUTTON_HEIGHT * 2, h = BUTTON_HEIGHT,
        x = 0,y = 200,
        wrap = true,
        frames = 1,
        caption = '0',
        value = 0,
        min = 0, max = 11,
        image = "fxSel.png",
        func = function(self) M.Msg('page = '..self.value) self.caption = self.value end,
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
for i = 1,4 do
    layer:addElements(CreateSwitch(i,80))
end
layer:addElements(MSpinnerTest())
window:addLayers(layer)
window:open()
--M.Msg(GetRGB(120,.8,.5))
--switch:val(1)

GUI.Main()
--]]