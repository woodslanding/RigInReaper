------------------------------ICONROL--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'moonUtils'
require 'Icontrol'

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

local ImageFolder = reaper.GetResourcePath().."/Scripts/MOON/Images"

local Element = require("gui.element")
local Multi = false
local Rows, Cols = 5,8
local Ht, Wd = 40, 120
local hue, sat, level = 40, 99, 40

local Titles = {}


local Switches = {}
local Spinner

function CreateSwitch(i, xpos, ypos, wd, ht, title, hue, sat, level)

    local switch = GUI.createElement({
        mode = MODES.SWITCH,
        w = wd,h = ht, x = xpos, y = ypos,
        color = GetRGB(hue,sat,level),
        loop = true,
        frames = 2,
        caption = title,
        vals = {0,i},
        name = 'button'..i,
        type = "IControl",
        --labelX = 0, labelY = 0,
        image =  ImageFolder.."/".."comboButton2pos.png",
        func = function(self) M.Msg('setting val to '..i) end,
        params = {"a", "b", "c"}
    })
    function switch:onMouseUp()
        if Multi then MultiSel(switch.vals[2])
        else Select(switch.vals[2]) end
    end
    Switches[i] = switch
    return switch
end

function CreatePager()
    Spinner = GUI.createElement({
        mode = MODES.SPINNER,
        horizontal = true,
        w = 80, h = 40,
        x = Wd * Cols, y = Ht * (Rows - 1),
        loop = true, min = 1, max = 2, inc = 1,
        frames = 1,
        caption = '',
        font = 1,
        type = "IControl",
        image =  ImageFolder.."/".."fxSel.png",
        func = function(self) SetPage(self:val()) end
    })
    return Spinner
end

function MultiSel(set)
    local sw = Switches[set]
    M.Msg(' val = '..sw:val())
    if sw.frame == 0 then sw:setFrame(1)
    else sw:setFrame(0) end
    sw:redraw()
end

function Select(set)
    for idx = 1,Rows * Cols do
        local sw = Switches[idx]
        if sw.vals[2] == set then sw:val(set)
        else sw:val(0) end
        sw:redraw()
    end
end

function SetPage(pageNum) --pages start at 1
    Spinner.max = math.ceil(#Titles/Rows * Cols)
    for idx = 1, Rows * Cols do
        local sw = Switches[idx]
        sw.caption = Titles[(Rows * Cols * (pageNum - 1)) + idx] or '---'
        Spinner.caption = ' '..pageNum..' '
        sw:redraw()
    end
end

------------------------------------
-------- Window settings -----------
------------------------------------


local window = GUI.createWindow({
  name = "This Part Works!",
  w = 1200,
  h = 300,
  x = 0, y = 0,
  anchor = nil, corner = nil
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
for i = 0,250 do
    table.insert(Titles,' '..i..' ')
end
local xpos, ypos
local index = 1
local layer = GUI.createLayer({name = "Layer1", z = 1})
for i = 1, Cols do
    xpos = (i - 1) * Wd
    for j = 1, Rows do
        ypos = (j - 1) * Ht
        hue = 15
        sat = 95
        level = 50
        layer:addElements(CreateSwitch(index, xpos, ypos, Wd, Ht, "test"..index, hue, sat, level))
        index = index + 1
    end
end
layer:addElements(CreatePager())
SetPage(0)
window:addLayers(layer)
window:open()

GUI.Main()
