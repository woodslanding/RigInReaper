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
local M = require("public.message")
local Table = require("public.table")
local T = Table.T

local function createButtons(parent,image,layer,rows, columns, x, y, w, h)
    local switches = {}
    local xpos, ypos
    local index = 1
    for i = 1, columns do
        xpos = x + ((i - 1) * w)
        for j = 1, rows do
            ypos = y + ((j - 1) * h)
            local switch = GUI.createElement({
                w = w,h = h, x = xpos, y = ypos,
                color = 'black',
                loop = true,
                frames = 2,
                caption = '',
                min = 0, max = index,
                value = 0,
                name = 'button'..index,
                type = "MButton",
                image =  image,
                func = function(self) parent:select(self.max) parent:onSelect() end,
                params = {"a", "b", "c"}
            })
            layer:addElements(switch)
            switches[index] = switch
            index = index + 1
        end
    end
    return switches
end

local function createPager(parent,layer,x,y,w,h)
    local pager
    pager = GUI.createElement({
        name = 'pager',
        spinner = true,
        horizontal = true,
        w = w, h = h,
        x = x, y = y,
        loop = true, min = 1,
        max = 1, --just a placeholder
        inc = 1,
        frames = 1,
        caption = '',
        font = 2,
        value = 1,
        type = "MButton",
        image =  "",
        func = function(self) parent:setPage(self.value)  end
    })
    layer:addElements(pager)
    return pager
end

MButtonPanel = {}
MButtonPanel.__index = MButtonPanel

function MButtonPanel.new(image,layer,rows,cols,x,y,w,h,usePager,pX,pY,pW,pH)
    local self = setmetatable({}, MButtonPanel)
    self.layer = layer
    self.h = h self.w = w self.x = x self.y = y
    self.multi = false
    self.rows = rows   self.cols = cols
    self.color = 'black'
    self.options = {}
    self.selection = {}
    self.pageCount = 4 self.pageNum = 1
    self.switches = createButtons(self,image,layer,self.rows,self.cols,self.x,self.y,self.w,self.h)
    if usePager then
        self.pager = createPager(self,layer,pX,pY,pW,pH)
    end
    return self
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
function MButtonPanel:zeroOptions() for _,option in pairs(self.options) do  option.val = 0 end self.selection = {} end

function MButtonPanel:MultiSel(set)
    local sw = self.switches[set]
    local option,_ = self:getOptionForButton(set)
    if option.val then --some buttons on the last page may not have an option
        if option.val == 0 then
            option.val = 1
            sw.frame = 1
            table.insert(self.selection,option.name)
        else
            option.val = 0
            sw.frame = 0
            table.remove(self.selection,option.name)
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
                table.insert(self.selection, option.name)
            else sw.frame = 0
            end
            sw:redraw()
        end
    end
end

function MButtonPanel:onSelect()
    --override for button actions
end

function MButtonPanel:setPage(page) --pages start at 1
    self.pageCount = math.ceil(#self.options/(self.rows * self.cols))
    M.Msg('pageCount = '..self.pageCount)
    if self.pager then self.pager.max = self.pageCount end
    if page > self.pageCount then self.pageNum = self.pageCount else self.pageNum = page end
    for buttonNum = 1, self.rows * self.cols do
        local sw = self.switches[buttonNum]
        local option = self:getOptionForButton(buttonNum)
        sw.caption = option.name or '---'
        if self.pager then self.pager.caption = self.pageNum end
        if option.val and option.val > 0 then
            --M.Msg('setting button '..buttonNum..' on')
            sw.frame = 1
        else sw.frame = 0 end
        sw:redraw()
    end
    --M.Msg('PAGE SET')
end

function MButtonPanel:setColor(color)
    for buttonNum = 1, self.rows * self.cols do
        local sw = self.switches[buttonNum]
        sw.color = color
        if self.pager then self.pager.color = color end
        sw:redraw()
    end
end


function MButtonPanel:getOptionForButton(buttonNum)
    local num = (self.rows * self.cols * (self.pageNum - 1)) + buttonNum
    local option = self:getOption(num)
    return option, num
end

--return MButtonPanel

------------------------------------
-------- Window settings -----------
------------------------------------
--[[

local window = GUI.createWindow({
  name = "BUTTON switches TEST",
  w = 1000,
  h = 300,
  x = 100, y = 0,
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
local imageFolder = reaper.GetResourcePath().."\\scripts\\_RigInReaper\\Images\\"
local layer = GUI.createLayer({name = "Layer1", z = 1})

--create 250 options
local cols, w = 8, 96
local panel = MButtonPanel.new(imageFolder.."Combo.png",layer,5,cols,
                            0,0,w,32,       --button
                            w*cols,0,36,72) --spinner
for i = 1,250 do
    panel.options[i] = {
        name = i,
        val = 0
    }
end
panel.pager.image = imageFolder.."EffectSpin.png"
panel:setColor(GetRGB(120,100,60))
panel:setPage(1)
window:addLayers(panel.layer)
window:open()

GUI.Main()--]]
