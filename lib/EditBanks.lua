--------------------------------------------------------Edit Banks---------------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")({printErrors = true})

require 'Mbutton'
require "moonUtils"
require 'createMoonBank'
require 'MButtonPanel'

local GUI = require("gui.core")
local M = require("public.message")
local Table = require("public.table")
local T = Table.T

local btnH = 36
local meterH = 12
local chanH = (btnH * 6)
local comboH = 36

local leftPad = 4
local chanW = 96
local faderW = 52
local leftW = 52
local rightW = 44

local presetY = 16

local presetCols = 8
local rows = 16

local imageFolder = reaper.GetResourcePath().."\\scripts\\_RigInReaper\\Images\\"
local layer1 = GUI.createLayer({name = "layer1", z = 5})
local layer2 = GUI.createLayer({name = "layer2", z = 4})

local function fakeOptions(panel, string)
    for i = 1,250 do
        panel.options[i] = {  name = string..' '..i, val = 0 }
    end
end

local window = GUI.createWindow({
        name = "EDIT BANKS",
        w = 1300,
        h = 600,
        x = 100, y = 0,
    })
------------------------------------
-------- GUI Elements --------------
------------------------------------
--I suppose we should have the option of either assigning multiple banks to one preset
--or multiple presets to one bank....  we'll start out with just the former
M.Msg('rows = '..rows)
function CreatePresets()
    local presets = MButtonPanel.new(imageFolder.."Combo.png",layer1,rows,presetCols,
                                leftPad,presetY,chanW,comboH,       --button
                                true, (chanW * presetCols) + leftPad,presetY,44,72) --spinner
    fakeOptions(presets, 'preset')
    presets.pager.image = imageFolder.."Spinner.png"
    presets:setPage(1)
    return presets
end
PresetPanel = CreatePresets()
PresetPanel:setColor(RandomColor(40))
function PresetPanel:onSelect()
end

function CreateBanks()
    local cols = 4
    local banks = MButtonPanel.new(imageFolder.."Combo.png",layer2,rows,cols,
                                leftPad + (chanW * presetCols) + 48, presetY,chanW,comboH,       --button
                                true,4 + (chanW * presetCols) + leftPad, (comboH * (presetCols-2) + presetY),44,72) --spinner
    fakeOptions(banks,'bank')
    banks.pager.image = imageFolder.."Spinner.png"
    banks.multi = true
    banks:setPage(1)
    return banks
end
BankPanel = CreateBanks()
for _,switch in pairs(BankPanel.switches) do
    switch.color = RandomColor()
end
function BankPanel:onSelect()

end

window:addLayers(layer1,layer2)
window:open()

GUI.Main()

--[[
function Plugin.test(name)
    local plug = Plugin.new(name)
    plug.emptyPreset = 'not found'
    plug:setParam('A1','Reverb')
    plug:setParam('A2','Chorus')
    plug:addBank('favorites',120,.05)
    plug:addBank('pianos',10,.09)
    plug:addPresetToBank('pianos','Grandeur')
    plug:addPresetToBank('favorites','OB pad')
    plug:addPresetToBank('favorites','Grandeur')
    plug:addPresetToBank('pianos','Black')
    plug:addPresetToBank('pianos','Death Piano')
    plug:addPresetToBank('pianos','poor naming')
    local curBank = plug:getBank('favorites')
    curBank:setParam('A5','Wah')
    plug:getBank('pianos'):setParam('A1','Reverb')
    --plug:getPresetList()
    return plug
end

local plugName = 'test'
local plug = Plugin.test(plugName)
plug:save()
local plug2 = Plugin.load(plugName)
print(plug2)
--print(table.concat(plug:getPresetList(),', '))
plug2.name = 'test2'
plug2:save()--]]