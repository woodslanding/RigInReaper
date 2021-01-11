------------------------------ICONROL--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'Mbutton'
loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local M = require("public.message")
local Font = require("public.font")
local Color = require("public.color")
local Table = require("public.table")
local T = Table.T

local Multi = 0
local Rows, Cols = 5,8
local Ht, Wd = 40, 100
local hue, sat, level = 40, 99, 40

local switches = {}
local pager
local pageCount
local pageNum

local options = {}
function GetOption(idx)
    if not options[idx] then options[idx] = {} end
    return options[idx]
end
function SetOption(idx,name,val)
    local option = GetOption(idx)
    option.name = name
    option.val = val
end

function GetOptionName(idx)  return GetOption(idx).name or '---' end
function GetOptionVal(idx) return  GetOption(idx).val or 0 end
function SetOptionVal(idx,val)   GetOption(idx).val = val end
function SetOptionName(idx,name) GetOption(idx).name = name end
function ZeroAllOptions() for k,option in pairs(options) do  option.val = 0 end end

function CreateSwitch(i, xpos, ypos, wd, ht, title, hue, sat, level)

    local switch = GUI.createElement({
        w = wd,h = ht, x = xpos+wd, y = ypos + ht,
        color = GetRGB(hue,sat,level),
        loop = true,
        frames = 2,
        caption = '',
        min = 0, max = i, value = 0,
        name = 'button'..i,
        type = "MButton",
        --labelX = 0, labelY = 0,
        image =  "comboButton2pos.png",
        func = function(self) MSG('setting val to '..i,'caption = '..self.caption) end,
        params = {"a", "b", "c"}
    })
    function switch:onMouseUp()
        if Multi > 0 then MultiSel(switch.max)
        else Select(switch.max) end
    end
    switches[i] = switch
    return switch
end

function CreatePager(pages)
    pager = GUI.createElement({
        name = 'pager',
        spinner = true,
        horizontal = true,
        w = 80, h = 40,
        x = 0, y = Ht * (Rows - 1),
        loop = true, min = 1, max = pages, inc = 1,
        frames = 1,
        caption = '',
        font = 1,
        value = 1,
        type = "MButton",
        image =  "fxSel.png",
        func = function(self) MSG('page = '..self.value) SetPage(self.value)  end
    })
    return pager
end

function CreateSelButton()
    -- MSG('creating sel button')
    local selType = GUI.createElement({
        name = 'selectionType',
        w = 80, h = 40,
        x = 0, y = 80, vals = {0,1},
        frames = 2,
        value = 0,
        type = "MButton",
        image = "hands.png",
        func = function(self) Multi = self.value end
    })
    return selType
end

function MultiSel(set)
    local sw = switches[set]
    local option,idx = GetOptionForButton(set)
    if option.val then --some buttons on the last page may not have an option
        if option.val == 0 then
            option.val = 1
            sw.frame = 1
            MSG('option '..option.name,'on')
        else
            option.val = 0
            sw.frame = 0
            MSG('option '..option.name,'off')
        end
        sw:redraw()
    end
end

function Select(set)
    ZeroAllOptions()
    for button = 1,Rows * Cols do
        local option, idx = GetOptionForButton(button)
        local sw = switches[button]
        if sw.max == set then
            sw.frame = 1
            option.val = 1
            MSG('option '..option.name,' enabled')
        else sw.frame = 0
        end
        sw:redraw()
    end
end

function SetPage(page) --pages start at 1
    pageCount = math.ceil(#options/(Rows * Cols))
    pager.max = pageCount
    if page > pageCount then pageNum = pageCount else pageNum = page end
    for buttonNum = 1, Rows * Cols do
        local sw = switches[buttonNum]
        local option = GetOptionForButton(buttonNum)
        sw.caption = option.name or '---'
        pager.caption = pageNum
        if option.val and option.val > 0 then
            MSG('setting button '..buttonNum..' on')
            sw.frame = 1
        else sw.frame = 0 end
        sw:redraw()
    end
end

function GetPage()
    return pageNum

end

function GetOptionForButton(buttonNum)
    local num = (Rows * Cols * (pageNum - 1)) + buttonNum
    local option = GetOption(num)
    return option, num
end

function CreatButtonPanel(rows, columns)
    local xpos, ypos
    local index = 1
    for i = 1, columns do
        xpos = (i - 1) * Wd
        for j = 1, rows do
            ypos = (j - 1) * Ht
            hue = 15
            sat = 95
            level = 50
            layer:addElements(CreateSwitch(index, xpos, ypos, Wd, Ht, GetOptionName(i), hue, sat, level))
            index = index + 1
        end
    end
end

------------------------------------
-------- Window settings -----------
------------------------------------


local window = GUI.createWindow({
  name = "BUTTON PANEL TEST",
  w = 1000,
  h = 300,
  x = 100, y = 0,
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
--create 250 options
for i = 1,250 do
    options[i] = {
        name = i,
        val = 0
    }
end

local layer = GUI.createLayer({name = "Layer1", z = 1})


layer:addElements(CreateSelButton(),CreatePager(pageCount))
window:addLayers(layer)
SetPage(1)
window:open()

GUI.Main()
