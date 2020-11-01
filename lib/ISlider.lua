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


local IControl = Element:new()
IControl.__index = IControl
IControl.defaultProps = {
    name = "icontrol", type = "ICONTROL",
    horizontal = true,
    x = 16, y = 32, w = 240, h = 48,
    labelX = 0, labelY = 0,
    caption = "IControl", font = 2, textColor = "text",
    bg = "background",
    func = function () end,
    params = {},
    min = 0,
    max = 1,
    inc = .01,
    sens = 1,
    image = nil,
    frames = 48,
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
    if not self.sprite.image then error("IControl: The specified image was not found") end
end

function IControl:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.mode = 0
  --gfx.blit(self.buffer, 1, 0, self.frame * self.w, 0, self.w, self.h, self.x, self.y, self.w, self.h)
    self.sprite:draw(x, y, w, h, self.frame, self.frames)
      -- Draw the caption
    --local state = self.frame
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

    --M.Msg('state = ',self.frame)
    return true
end

function IControl:onMouseUp(state)
    local midX = self.x + (self.w/2)
    local midY = self.y + (self.h/2)
    if self.mode == MODES.SWITCH then self:incFrame(true,true)
    elseif self.mode == MODES.BUTTON then self:setFrame(0)
    elseif self.mode == MODES.SPINNER and self.horizontal and state.mouse.x < midX then self:incFrame(false,self.loop)
    elseif self.mode == MODES.SPINNER and self.horizontal and state.mouse.x > midX then self:incFrame(true,self.loop)
    elseif self.mode == MODES.SPINNER and not self.horizontal and state.mouse.y < midY then self:incFrame(false,self.loop)
    elseif self.mode == MODES.SPINNER and not self.horizontal and state.mouse.y > midY then self:incFrame(true,self.loop)
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

-- Will continue being called even if you drag outside the element
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
            if val == set then
                self.frame = frame - 1
                if self.captions then self.caption = self.captions[frame] end
                self.retval = set
                --M.Msg('set frame'..self.frame,'val = '..self.retval,'caption = '..self.caption)
                return true
            end
        end
        M.Msg("can't set value of control to: "..set)
    --can just set by frame, if there are no values
    elseif set > 0 and set < self.frames - 1 then self.frame = set end
end

GUI.elementClasses.IControl = IControl

local switch = GUI.createElement({
    mode = MODES.SPINNER,
    loop = false,
    frames = 3,
    captions = {'off','on','selected'},
    vals = {0,1,2},
    name = "switch",
    type = "IControl",
    w = 120,h = 120,x = 0,y = 0,
    labelX = 0,labelY = 0,
    image =  buttonImages.path.."/".."comboButton3Pos.png",
    func = function(self, a, b, c) Msg(self.name, self.retval) end,
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
------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})

layer:addElements(switch)
window:addLayers(layer)
window:open()

GUI.Main()
