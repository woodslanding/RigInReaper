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

local function createPager(parent)
    --M.Msg('pager image = '..parent.pagerImage)
    local pager = GUI.createElement({
        name = parent.name..'_pager',
        type = "MButton",
        color = 'gray',
        image = parent.pagerImage,
        spinner = true,
        momentary = true,
        horizontal = true,
        w = parent.pagerw or parent.w,
        h = parent.pagerH or parent.h,
        x = parent.pagerX or ((parent.cols - 1) * parent.w) + parent.x ,
        y = parent.pagerY or (parent.rows * parent.h) + parent.y,
        loop = true,
        inc = 1,min = -1, max = 1,
        frames = 1,
        caption = '',
        font = 2,
        value = 1,
        func = function(self) parent:incPage(self.value)  end
    })
    parent.layer:addElements(pager)
    --M.Msg('adding pager')
    return pager
end
local function createControls(parent)
    --M.Msg(Table.stringify(parent))
    local controls = {}
    local xpos, ypos
    local index = 1
    for i = 1, parent.cols do
        xpos = parent.x + ((i - 1) * parent.w)
        for j = 1, parent.rows do
            ypos = parent.y + ((j - 1) * parent.h)
            local switch = GUI.createElement({
                w = parent.w,h = parent.h, x = xpos, y = ypos,
                color = 'gray',
                loop = true,
                frames = 2,
                caption = '',
                min = 0, max = 1,
                value = 0,
                font = 3,
                name = parent.name..'_control_'..index,
                type = parent.type or "MButton",
                image =  parent.image,
                index = index,
                option = {},
                --call the self function with the updated selection
                func = function(self) parent:select(self.option.index) end,
                params = {"a", "b", "c"}
            })
            controls[index] = switch
            --M.Msg('adding switch:'..index)
            index = index + 1
            parent.layer:addElements(switch)
        end
    end
    return controls
end
MButtonPanel = {}
MButtonPanel.__index = MButtonPanel

local defaults = {
    name = 'ButtonPanel_'..math.random(),
    --type = 'MButton',
    layer = nil,
    window = nil,
    image = nil,
    rows = 4, cols = 4,
    h = 36, w = 96, x = 0, y = 0, z = 40,
    usePager = true,
    pager = nil,
    pagerImage = nil,
    multi = false,
    color = 'gray',
    options = {},
    controls = {},
    selection = {},
    pageCount = 1,
    pageNum = 1,
}

function MButtonPanel.new(props)
    local self = setmetatable({}, MButtonPanel)
    for prop,val in pairs(defaults) do
        self[prop] = val  --add defaults
    end
    for prop,val in pairs(props) do
        self[prop] = val  --add props from method call
    end
    self.layer = GUI.createLayer({name = self.name..'_layer', z = self.z})
    self.controls = createControls(self)
    if self.usePager then
        self.pager = createPager(self)
    end

    self.window:addLayers(self.layer)
    --M.Msg(Table.stringify(self))
    --self:setPage(1)  --don't set without options!!
    return self
end

function MButtonPanel:func()
    M.Msg("Calling default func on button panel")
end


function MButtonPanel:setMulti(multi)
    M.Msg('setting multi ')
    self.multi = multi
    self:clearSelection()
end

function MButtonPanel:setMomentary(momentary, optionIDX)
    if optionIDX then self.options[optionIDX].momentary = momentary
    else self.momentary = momentary
    end
    self:setPage(1)
end

function MButtonPanel:setOption(idx,parameters)
    --M.Msg('Adding option for '..self.name..' at index '..idx)
    if not self.options[idx] then
        local params = parameters or {}
        --M.Msg('adding option'..params.name)
        self.options[idx] = {
            index = idx,
            state = params.state or 0,
            color = params.color or self.color or 'gray',
            momentary = params.momentary or self.momentary,
            type = params.type or 'MButton',
            name = params.name or '???',
            func = params.func or self.func
        }
    end
    return self.options[idx]
end

function MButtonPanel:getOption(idx)
    if self.options[idx] then return self.options[idx] else return nil end
end

--[[function MButtonPanel:getSelectedOption()
    if type(self:getSelection()) ~= 'table' then
        return self:getOption(self:getSelection())
    else M.Msg("can't get selected option in multi mode")
    end
end--]]


function MButtonPanel:clearSelection()
    M.Msg(self.name..': resetting switches')
    for i,option in ipairs(self.options) do option.state = 0 end
    if self.multi then self.selection = {} else self.selection = nil end
    for i = 1, self.rows * self.cols do
        self.controls[i]:val(0)
    end
end
--defaults to getting the names, but can get any option field
function MButtonPanel:getSelectionData(field)
    if not self.selection then return nil end
    if not self.multi then
        if not field then return self.selection.name else return self.selection[field] end
    end
    --M.Msg('selection = '..TStr(self.selection))
    local data = {}
    for i,option in pairs(self.selection) do
        if not field then data[i] = option.name
        else data[i] = option[field] end
        M.Msg('getting selection data '..data[i])
    end
    return data
end--]]

--returns a table of options
function MButtonPanel:select(set,doNotRun)
    if set then
        local sw = self:getButtonForOption(set)
        --M.Msg('found button '..sw.name)
        local option = self.options[set]
        if option then   --some buttons may not have options...
            --in multi mode we generally just add or subtract from the selection.  If we want to do something, set 'run' to true
            if self.multi then   --in multimode we ignore everything in options except state
                if option.state == 0 then
                    option.state = 1
                    sw:val(option.state)
                    self.selection[set] = option
                    if not doNotRun then option:func() end
                else
                    option.state = 0
                    sw:val(option.state)
                    self.selection[set] = nil
                    if not doNotRun then option:func() end
                end

            elseif not self.multi then --in single-select mode, we can run the action here...
                self:clearSelection()
                for button = 1,self.rows * self.cols do
                    local sw = self.controls[button]
                    local option = sw.option
                    if option and set and sw.option.index == set then
                        if not self.momentary then sw.frame = 1 end
                        option.state = 1
                        self.selection = option
                        --M.Msg(self.name..': options: \n:'..Table.stringify(self.options))
                        option:func()
                    else sw.frame = 0
                    end
                    sw:redraw()
                end
            end
            return self.selection
        end
    else M.Msg(self.name..': set is nil') end
end
--for single select this is an integer.  for multi, you can select an index, or else get a table of indices
function MButtonPanel:getSelection(index)
    if index and type(self.selection) == 'table' then return self.selection[index]
    else return self.selection end
end


function MButtonPanel:incPage(val) self:setPage(self.pageNum + val) end

function MButtonPanel:setPage(page) --pages start at 1
    local btnCount = self.rows * self.cols
    self.pageCount = math.ceil(#self.options/(self.rows * self.cols))
    if page > self.pageCount then self.pageNum = self.pageCount
    elseif page < 1 then self.pageNum = 1
    else self.pageNum = page end
    for buttonNum = 1, btnCount do
        --M.Msg('Setting options for button: '..buttonNum)
        local sw = self.controls[buttonNum]
        local optionIdx = (btnCount * (self.pageNum - 1)) + buttonNum
        --don't use setOption,as that will automatically create an option...
        local option = self.options[optionIdx]
        --M.Msg('option = '..Table.stringify(option))
        if not option then sw.caption = '---'
        else
            sw.option = option
            sw.caption = option.name --shouldn't have an option without a name
            sw.type = option.type or self.type or 'MButton'
            sw.momentary = option.momentary or self.momentary
            --M.Msg('setting sw:'..sw.name..' to momentary = ',sw.momentary)
            sw.color = option.color or self.color
            sw.image = option.image or self.image
            if self.pager then self.pager:setCaption(self.pageNum) end
            if option.state and option.state > 0 and not option.momentary then
                --todo: support for sliders?
                sw.frame = option.state - 1
            else sw.frame = 0 end
            sw:redraw()
        end
    end
    --M.Msg('PAGE SET')
end

function MButtonPanel:setColor(color, resetAll)
    for buttonNum = 1, self.rows * self.cols do
        local sw = self.controls[buttonNum]
        if sw.option then
            if resetAll then sw.color = color  --if we are resetting, change all the colors
            elseif sw.option and sw.option.color  then  --otherwise, if we have an option and it has a color then leave it be
            else sw.color = color
            end
        end
        if self.pager then self.pager.color = color end
        sw:redraw()
    end
end
--breaks when option index is a string...
function MButtonPanel:getButtonForOption(idx)
    local count = self.rows * self.cols
    for i = 1,count  do
        local control = self.controls[i]
        if control.option.index == idx then
             return control end
    end
    --local btnCount = self.rows*self.cols
    --return self.controls[idx % (btnCount-1)]
end


--return MButtonPanel

------------------------------------
-------- Window settings -----------
------------------------------------
--[[--

local window = GUI.createWindow({
  name = "BUTTON controls TEST",
  w = 800,
  h = 300,
  x = 0, y = 0,
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
local imageFolder = reaper.GetResourcePath().."\\scripts\\_RigInReaper\\Images\\"
local layer = GUI.createLayer({name = "Layer1", z = 1})

local panel = MButtonPanel.new({
    layer = layer,
    rows = 5, cols = 8,
    name = 'PanelTest',
    image = imageFolder..'Combo.png',
    pagerImage = imageFolder..'HorizSpin.png',
    usePager = true,
    multi = false,
})

for i = 1,250 do
    local color = GetRGB(i,60,40)
    panel:setOption(i, {
        name = 'option '..i,
        color = color
    })
end
panel:setPage(1)



window:addLayers(layer)
window:open()


GUI.Main()--]]
