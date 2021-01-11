------------------------------MOptions--------------------------------
--[[
    Ideally, this would allow buttons or sliders to be used.  It would be its own element(how?)
    The options would tell whether to use a button or a slider, whether it is momentary, and what its function is
    If there's no function per option, it will call the global function with the option's value.
    Options can also have colors.
    Options are indexed, so paging can reassign them to physical buttons properly.
    Should be able to set a page increment value that is independent of page size.
    Options are assigned to buttons vertically by columns.

]]
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
local Font = require("public.font")
local Color = require("public.color")
local Sprite = require("public.sprite")
local Math = require("public.math")
local GFX = require("public.gfx")
local Table = require("public.table")
local T = Table.T
local Element = require("gui.element")

local MOptions = {}
MOptions.__index = MOptions

function MOptions:createControls()
    --MSG(Table.stringify(self))
    local xpos, ypos
    local index = 1
    for i = 1, self.cols do
        xpos = self.x + ((i - 1) * self.w)
        for j = 1, self.rows do
            ypos = self.y + ((j - 1) * self.h)
            local switch = GUI.createElement({
                --parent = self,
                w = self.w,h = self.h, x = xpos, y = ypos,
                color = 'red',
                loop = true,
                frames = 2,
                caption = '',
                min = 0, max = 1,
                value = 0,
                name = self.name..'button'..index,
                type = self.type or "MButton",
                image =  self.image,
                index = index,
                option = nil,
                --call the self function with the updated selection
                func = function(self) end,
                params = {"a", "b", "c"}
            })
            self.controls[index] = switch
            MSG('adding switch:'..index)
            index = index + 1
            self.layer:addElements(switch)
        end
    end
end
--convert this to momentary, so it doesn't retain state
function MOptions:createPager()
    self.pager = GUI.createElement({
        --parent = self,
        name = self.name..'pager',
        type = "MButton",
        color = 'blue',
        image = self.pagerImage,
        spinner = true,
        momentary = true,
        horizontal = true,
        w = self.pagerw, h = self.pagerH,
        x = self.pagerX or self.rows * (self.w - 1) ,
        y = self.pagerY or self.cols * self.h,
        loop = true,
        inc = 1,min = -1, max = 1,
        frames = 1,
        caption = '',
        font = 2,
        value = 1,
        image =  "",
        func = function(self)  end
    })
    self.layer:addElements(pager)
    MSG('adding pager')
end

local defaults = {
    name = 'MOPTIONS',
    type = 'MButton',
    layer = {},
    image = '',
    rows = 4, cols = 4,
    h = 36, w = 96, x = 0, y = 0,
    usePager = true, pager = {},
    pagerH = 36,pagerW = 96, pagerX = nil, pagerY = nil,
    pagerImage = '',
    multi = false,
    color = 'black',
    options = {},
    controls = {},
    pageCount = 1, pageNum = 1,
    func = function(self) self:func() end
}

function MOptions.new(props)
    local self = setmetatable({}, MOptions)
    for prop,val in pairs(defaults) do
        self[prop] = val
    end
    for prop,val in pairs(props) do
        self[prop] = val
    end
    self:createControls()
    if self.usePager then
        self:createPager()
    end
    self:setPage(1)
    return self
end

function MOptions:setMomentary(val)
    for buttonNum = 1, self.rows * self.cols do
        local sw = self.controls[buttonNum]
        sw.momentary = val
    end

end

function MOptions:getOption(idx,name)
    if not self.options[idx] then
        self.options[idx] = {
            momentary = not self.multi,
            state = 0,
            type = 'MButton',
            name = name or '???'
        }
    end
    return self.options[idx]
end


function MOptions:setOption(idx,name,func,momentary,color,elementType,image)
    local option = self:getOption(idx,name)
    option.name = name
    option.func = func or nil
    option.momentary = momentary or 0
    option.color = color or nil
    option.type = elementType or 'MButton'
    option.image = image or nil
    return option
end

--deselect all buttons
function MOptions:clearSelection() for _,option in pairs(self.options) do  option.state = 0 end self.selection = nil end

--returns a table of functions or option indices
function MOptions:select(set)
    local sw = self.controls[set]
    local option = sw.option
    --in multi mode we just add or subtract from the selection.  Doing something with the selection is separate
    if self.multi and not option.momentary then   --can't do multi-select with momentary options
        if option then                            --some buttons may not have options...
            if option.state == 0 then
                option.state = 1
                sw.frame = 1
                table.insert(self.selection,set,set)
            else
                option.state = 0
                sw.frame = 0
                table.remove(self.selection,set)
            end
            sw:redraw()
        end
    else  --in single-select mode, we can run the action here...
        self:clearSelection()
        for button = 1,self.rows * self.cols do
            local sw = self.controls[button]
            local option = sw.option
            if sw.index == set then
                sw.frame = 1
                option.state = 1
                self.selection = set
            else sw.frame = 0
            end
            sw:redraw()
            option.func(set)
        end
    end
    return self.selection
end
--
function MOptions:getSelection(index)
    return self.selection
end

function MOptions:func()
    --do something with the selection table or just return it
    return self:getSelection()
end

function MOptions:incPage(page) self:setPage(self.pageNum + 1) end
function MOptions:decPage(page) self:setPage(self.pageNum - 1) end
--todo: support for partial paging....
function MOptions:setPage(page) --pages start at 1
    local btnCount = self.rows * self.cols
    self.pageCount = math.ceil(#self.options/(self.rows * self.cols))
    if page > self.pageCount then self.pageNum = self.pageCount else self.pageNum = page end
    for buttonNum = 1, btnCount do
        local sw = self.controls[buttonNum]
        --don't use getOption,as that will automatically create an option...
        local option = self.options[(btnCount * (page - 1)) + buttonNum]
        if not option then sw.caption = '---'
        else
            sw.caption = option.name --shouldn't have an option without a name
            sw.type = option.type or self.type or 'MButton'
            sw.momentary = option.momentary
            sw.color = option.color or self.color
            sw.image = option.image or self.image or nil
            if self.pager then self.pager:setCaption(self.pageNum) end
            if option.state and option.state > 0 then
                --support for sliders...
                sw.frame = option.state - 1
            else sw.frame = 0 end
            sw:redraw()
        end
    end
    MSG('PAGE SET')
end
--sets button color, unless the option already has one
function MOptions:setColor(color)
    for buttonNum = 1, self.rows * self.cols do
        local sw = self.controls[buttonNum]
        local color = sw.option.color
        if not color then sw:setColor(color) end
    end
    if self.pager then self.pager:setColor(color) end
end

function MOptions:getButtonForOption(idx)
    local btnCount = self.rows*self.cols
    return self.controls[idx % (btnCount-1)]
end

--GUI.elementClasses.MOptions = MOptions
--return MOptions

------------------------------------
-------- Window settings -----------
------------------------------------
--

local window = GUI.createWindow({
  name = "BUTTON controls TEST",
  w = 1000,
  h = 300,
  x = 100, y = 0,
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
local imageFolder = reaper.GetResourcePath().."\\scripts\\_RigInReaper\\Images\\"
local layer1 = GUI.createLayer({name = "Layer1", z = 1})

local function createTestOptions()
    for i = 1,250 do
        local option = {i,'option '..i)
        option.color = GetRGB(i,60,50)
    end

end

local panel = MOptions.new({
    layer = layer1,
    rows = 5, cols = 8,
    name = 'OptionTest',
    image = imageFolder..'Combo.png',
    pagerImage = imageFolder..'Spinner.png',
    multi = false,
    options = createTestOptions()
    })



window:addLayers(layer1)
window:open()


--panel:setPage(1)
GUI.Main()--]]
