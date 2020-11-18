------------------------------MBUTTONPANEL--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")()

require 'Mbutton'
require "moonUtils"

local GUI = require("gui.core")
local Element = require("gui.element")
local M = require("public.message")
local Table = require("public.table")
local T = Table.T

local MButtonPanel = Element:new()
MButtonPanel.__index = MButtonPanel
MButtonPanel.defaultProps = {
    name = "buttonpanel", type = "MButtonPanel",
    rows = 3, cols = 3, x = 0, y = 0, w= 96, h = 40,
    multi = false,
    color = 'black',
    options = {},
    switches = {},
    pager = nil,
    pagerW = 48, pagerH = 80, pagerX = 288,pagerY = 120,
    pagerVert = true,
    pageNum = 1,
    image = nil,
}

function MButtonPanel:new(props)
    local panel = self:addDefaultProps(props)
    setmetatable(panel, self)
    panel:createComponents()
    return panel
end

function MButtonPanel:createComponents()
    local xpos, ypos
    local index = 1
    for i = 1, self.cols do
        xpos = self.x + ((i - 1) * self.w)
        for j = 1, self.rows do
            ypos = self.y + ((j - 1) * self.h)
            M.Msg('creating switch # '..index)
            self.switches[index] = GUI.createElement({
                name = self.name..'button'..index,
                type = "MButton",
                w = self.w,h = self.h, x = xpos, y = ypos,
                color = self.color,
                loop = true,
                frames = 2,
                caption = '',
                min = 0, max = index,
                value = 0,
                image =  self.image,
                func = function() end,
                params = {"a", "b", "c"}
            })
            index = index + 1
        end
    end
    self.pager = GUI.createElement({
        name = self.name..'pager',
        type = "MButton",
        spinner = true,
        horizontal = false,
        w = self.pagerW, h = self.pagerH,
        x = self.pagerX, y = self.pagerY,
        loop = true, min = 1,
        max = 1, --just a placeholder
        inc = 1,
        frames = 1,
        caption = '',
        font = 2,
        value = 1,
        image =  self.image,
        func = function() end
    })
end

function MButtonPanel:getElements()
    return self.pager,table.unpack(self.switches)
end

function MButtonPanel:init()
    M.Msg('calling init')
    --self:createComponents()
end

function MButtonPanel:getOption(idx)
    if not self.options[idx] then self.options[idx] = {} end
    return self.options[idx]
end
function MButtonPanel:setOption(idx,name,val)
    local option = self:getOption(idx)
    option.name = name
    option.val = val
end

function MButtonPanel:getOptionName(idx)  return self:getOption(idx).name or '---' end
function MButtonPanel:getOptionVal(idx) return  self:getOption(idx).val or 0 end
function MButtonPanel:setOptionVal(idx,val)   self:getOption(idx).val = val end
function MButtonPanel:setOptionName(idx,name) self:getOption(idx).name = name end
function MButtonPanel:zeroOptions() for _,option in pairs(self.options) do  option.val = 0 end end


function MButtonPanel:MultiSel(set)
    local sw = self.switches[set]
    local option,_ = self:getOptionForButton(set)
    if option.val then --some buttons on the last page may not have an option
        if option.val == 0 then
            option.val = 1
            sw.frame = 1
        else
            option.val = 0
            sw.frame = 0
        end
        sw:redraw()
    end
end

function MButtonPanel:select(set)
    if self.multi then self:MultiSel(set)
    else
        self:zeroOptions()
        for button = 1,self.rows * self.cols do
            local option, _ = self:getOptionForButton(button)
            local sw = self.switches[button]
            if sw.max == set then
                sw.frame = 1
                option.val = 1
                M.Msg('option '..option.name,' enabled', 'frame set to 1!')
            else sw.frame = 0
            end
            sw:redraw()
        end
    end
end

function MButtonPanel:setPage(page) --pages start at 1
    self.pageCount = math.ceil(#self.options/(self.rows * self.cols))
    M.Msg('pageCount = '..self.pageCount)
    self.pager.max = self.pageCount
    if page > self.pageCount then self.pageNum = self.pageCount else self.pageNum = page end
    for buttonNum = 1, self.rows * self.cols do
        local sw = self.switches[buttonNum]
        local option = self:getOptionForButton(buttonNum)
        sw.caption = option.name or '---'
        self.pager.caption = self.pageNum
        if option.val and option.val > 0 then
            --M.Msg('setting button '..buttonNum..' on')
            sw.frame = 1
        else sw.frame = 0 end
        sw:redraw()
    end
    M.Msg('PAGE SET')
end

function MButtonPanel:setColor(color)
    for buttonNum = 1, self.rows * self.cols do
        local sw = self.switches[buttonNum]
        sw.color = color
        sw:redraw()
    end
    self.pager.color = color
    self.pager:redraw()
end


function MButtonPanel:getOptionForButton(buttonNum)
    local num = (self.rows * self.cols * (self.pageNum - 1)) + buttonNum
    local option = self:getOption(num)
    return option, num
end

--return MButtonPanel
GUI.elementClasses.MButtonPanel = MButtonPanel

------------------------------------
-------- Window settings -----------
------------------------------------
----

local window = GUI.createWindow({
  name = "BUTTONPANEL TEST",
  w = 1000,
  h = 300,
  x = 100, y = 0,
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
local imageFolder = reaper.GetResourcePath().."\\scripts\\_RigInReaper\\Images\\"

--create 250 options
local cols,rows, w, h = 8, 5, 96, 32

local panel = GUI.createElement({
    type = 'MButtonPanel',
    name = 'testPanel',
    image = imageFolder.."Combo.png",
    rows = rows, cols = cols, w = w, h = h, x = 0, y = 0,         --matrix
    pagerW = 32, pagerH = 72, pagerX = w*cols, pagerY = h*rows,   --pager
})

for i = 1,250 do
    panel.options[i] = {
        name = i,
        val = 0
    }
end

local layer = GUI.createLayer({name = "Layer1", z = 1})
layer:addElements(panel)
M.Msg('pre-init???')
for i = 1,#panel.switches do
   layer:addElements(panel.switches[i])
   M.Msg('adding switch '..i)
end
--layer:addElements(table.unpack(panel.switches))
layer:addElements(panel.pager)
window:addLayers(layer)
window:open()
M.Msg('calling main')
GUI.Main()--]]

panel.pager.image = imageFolder.."EffectSpin.png"
--panel:setPage(1)
--panel:setColor(GetRGB(20,100,60))