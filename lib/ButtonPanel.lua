------------------------------ICONROL--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'moonUtils'
require 'Mbutton'

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
local Ht, Wd = 40, 100
local hue, sat, level = 40, 99, 40

local titles = {}


local switches = {}
local pager
local selection = {}

function GetName(idx)  return titles[idx] end
function SetNames(str) titles = str end

function CreateSwitch(i, xpos, ypos, wd, ht, title, hue, sat, level)

    local switch = GUI.createElement({
        w = wd,h = ht, x = xpos, y = ypos,
        color = GetRGB(hue,sat,level),
        loop = true,
        frames = 2,
        caption = '',
        min = 0, max = i, value = 0,
        name = 'button'..i,
        type = "MButton",
        --labelX = 0, labelY = 0,
        image =  "comboButton2pos.png",
        func = function(self) M.Msg('setting val to '..i,'caption = '..self.caption) end,
        params = {"a", "b", "c"}
    })
    function switch:onMouseUp()
        if Multi then MultiSel(switch.max)
        else Select(switch.max) end
    end
    switches[i] = switch
    return switch
end

function CreatePager()
    pager = GUI.createElement({
        spinner =true,
        horizontal = true,
        w = 80, h = 40,
        x = Wd * Cols, y = Ht * (Rows - 1),
        loop = true, min = 1, max = 2, inc = 1,
        frames = 1,
        caption = '',
        font = 1,
        value = 1,
        type = "MButton",
        image =  "fxSel.png",
        func = function(self) M.Msg('page = '..self.value) SetPage(self.value)  end
    })
    return pager
end

function MultiSel(set)
    local sw = switches[set]
    M.Msg(' val = '..sw:val())
    if sw.frame == 0 then sw.frame(1)
    else sw.frame(0) end
    sw:redraw()
end

function Select(set) 
    M.Msg('setting to '..set)
    for idx = 1,Rows * Cols do
        local sw = switches[idx]
        if sw.max == set then 
            sw:val(set)
            --selection = {set}
        else sw:val(sw.min) end
        sw:redraw()
    end
end

function SetPage(pageNum) --pages start at 1
    M.Msg('setting page to '..pageNum)
    pager.max = math.ceil(#titles/(Rows * Cols))
    M.Msg('set max to'..pager.max)
    for idx = 1, Rows * Cols do
        local sw = switches[idx]
        sw.caption = titles[(Rows * Cols * (pageNum - 1)) + idx] or '---'
        pager.caption = pageNum
        sw:redraw()
    end
end

------------------------------------
-------- Window settings -----------
------------------------------------


local window = GUI.createWindow({
  name = "BUTTON PANEL TEST",
  w = 1200,
  h = 300,
  x = 200, y = 100,
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
local str = {}
for i = 1,250 do
    table.insert(str,i)
end
SetNames(str)
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
        layer:addElements(CreateSwitch(index, xpos, ypos, Wd, Ht, GetName(i), hue, sat, level))
        index = index + 1
    end
end
layer:addElements(CreatePager())
SetPage(1)
window:addLayers(layer)
window:open()

GUI.Main()
