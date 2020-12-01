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

BRIGHTNESS = 60

local GUI = require("gui.core")
local M = require("public.message")
local Table = require("public.table")
local T = Table.T


Plug = {}
Bank = {}
Banks = {}
Presets = {}
PresetPanel = {}
BankPanel = {}
VSTPanel = {}


MODE = {BANK = 'Bank Mode', PRESET = 'Preset Mode'}


-------------------------------------------------------------------------------------------------------
--------------------------------------------------------CONTROLS---------------------------------------
Options = {
    menu = {
        {
            {name = 'Save Preset', func = function(self) end   },  --from x-raym
            {name = 'Save As',func = function(self) end   },
            {name = 'Delete Preset',func = function(self) end   },
            {name = 'Rename Preset',func = function(self) end   },
        },
        {
            {name = 'Preset Mode', func = function(self)
                PresetPanel:setMulti(false)    BankPanel:setMulti(true)
                --set mappings to global
                PresetPanel:setPage(1)       BankPanel:setPage(1)
            end  },
            {name = 'Bank Mode', func = function(self)
                PresetPanel:setMulti(true)     BankPanel:setMulti(false)
                --set mappings to BANK
                PresetPanel:setPage(1)       BankPanel:setPage(1)
            end  },
          },
        {
            {name = 'New Bank',   func = function(self) end  },
            --{name = 'Rename Bank',func = function(self) end  },
            {name = 'Save Banks', func = function(self) end  }, --do this automatically unless there is a performance hit somehow
            {name = 'Delete Bank',func = function(self) end  },
        },
        {
            {name = 'SelVST',func = function(self) end },
            {name = 'ShowVST',func = function(self) end    }, --open the vst window floated at an appropriate size and position for control editing.
        },
    },
    panels = {
        {name = 'presets',rows = 8, cols = 4, icon = 'ComboRev',func = function(self)
            --M.Msg('self = \n'..Table.stringify(self))
            if MODE.BANK then
                --Bank.presets = {}
                --for i in ipairs(PresetPanel:getSelection()) do
                    --Bank:addPreset(PresetPanel.options[i].name)
                    --M.Msg('adding preset:'..options[i].name)
               -- end
               local presetNums = PresetPanel:getSelection()
               M.Msg('selection names = '..Table.stringify(presetNums))
                Plug:setPresetsForBank(Bank.name,presetNums)
                --Plug:save()
                M.Msg('SAVE Plug = \n',Plug)
            end


        end },
        {name = 'banks',rows = 8, cols = 4, icon = 'ComboRev',func = function(self)
            if MODE.BANK then
                Bank = Plug:getBank(self.name)
                PresetPanel:clearSelection()
                local color = GetRGB(Bank.hue,Bank.sat,BRIGHTNESS)
                PresetPanel:setColor(color,true)
                --M.Msg('PRESETS = \n'..Table.stringify(Bank.presets))
                for i, option in ipairs(PresetPanel.options) do
                    for _, name in ipairs(Bank.presets) do
                        if name == option.name then
                            M.Msg('adding preset '..name..' for option: '..i)
                            local button = PresetPanel:getButtonForOption(i)
                            PresetPanel:select(button.index,true)
                        end
                    end
                end--]]--
            end
        end },
        {name = 'VSTs',rows = 8, cols = 2, icon = 'ComboRev',func = function()
             --self is a button, not a panel.
            Plug = Plugin.load(VSTPanel:getSelection().name)
            Banks = Plug:getBankList()
            BankPanel.options = {}
            BankPanel:setColor('gray',true)
            for i,bankName in ipairs(Banks) do
                --M.Msg('Adding option for bankpanel: '..bank)
                local bank = Plug:getBank(bankName)
                BankPanel:setOption(i,{name = bankName, bank = bank, color = GetRGB(bank.hue,bank.sat,BRIGHTNESS)})
            end
            BankPanel:setPage(1)
            M.Msg(Plug)
            --Presets = Plug.presets
            Presets = Plug:getPresetList()
            PresetPanel.options = {}
            for i in ipairs(Presets) do PresetPanel:setOption(i,{name = Presets[i]}) end
            PresetPanel:setPage(1)
        end },
    },
    controlBanks = {        --(clicking assigns last touched param, if vst window is open)
        Encoders = {cols = 8,icon = 'EncoderSlider',func = function(self) end },
        Switches1 = {cols = 8,icon = 'Sw1State',func = function(self) end },
        Switches2 = {cols = 8,icon = 'Sw2State',func = function(self) end },
        Drawbars = {cols = 9,icon = 'DrawbarSlider',func = function(self) end },
        TogglesUp = {cols = 4,icon = 'ToggleStateUp',func = function(self) end },
        TogglesDn = {cols = 4,icon = 'ToggleStateDn',func = function(self) end },
        Footswitches = {cols = 4,icon = 'FootswitchState',func = function(self) end },
    },
    controls = {
        MW = {icon = 'MWState',func = function(self) end },
        BC = {icon = 'BCState',func = function(self) end },
        AT = {icon = 'ATState',func = function(self) end },
        EXP = {icon = 'ExpState',func = function(self) end },
        PED2 = {icon = 'Ped2State',func = function(self) end },
        SUS = {icon = 'SusState',func = function(self) end },
    },
    sliders = {
        Sat = {name = 'Saturation',func = function(self) end },
        Hue = {name = 'Hue',func = function(self) end },
        LoKey = {name = 'Low Key',func = function(self) end },
        HiKey = {name = 'High Key',func = function(self) end },
        Trim = {name = 'Trim',func = function(self) end },
    },
    bankSettings = {
        NsSolo = {name = 'NS Solo',func = function(self) end },
        ExpCurve = {name = 'Exp Curve',func = function(self) end },
        Ped2Curve = {name = 'Ped2 Curve',func = function(self) end },
        IsFX = {name = 'Is Effect',func = function(self) end },
        ExtIN = {name = 'Ext Audio',func = function(self) end },
        FakeSus = {name = 'Fake Sustain',func = function(self) end },
        MidiIN = {name = 'MIDI In',func = function(self) end },
        NsSolo = {name = 'NS Solo',func = function(self) end },
    },
    textFields = {
        PresetName = {name = 'Preset Name',func = function(self) end },
        BankName = {name = 'Bank Name',func = function(self) end },
        Notes = {name = 'Bank Notes',func = function(self) end },
    }
}

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

local window = GUI.createWindow({
        name = "EDIT BANKS",
        w = 1200,
        h = 800,
        x = 100, y = 0,
    })
------------------------------------
-------- GUI Elements --------------
------------------------------------
local  menuPad = 8
local x,y,w,h = 0,0,96,36
local layerZ = 40

for i,submenu in ipairs(Options.menu) do
    local menu = MButtonPanel.new({
        name = 'menu_'..i,
        image = imageFolder.."Combo.png",
        momentary = true,
        z = layerZ,
        rows = 1, cols = #submenu,
        x = x, y = y, w = w, h = h,
        usePager = false,
        multi = false,
        window = window,
        options = {},
    })
    --M.Msg(Table.stringify(menu))
    x = x + menuPad + ((#submenu) *  w)
    --do we need this?  check later...
    layerZ = layerZ - 1
    for i,option in ipairs(submenu) do
        --M.Msg('calling set option: '..tostring(menu.name))
        local newOption = menu:setOption(i,option)
        newOption.func = option.func
    end
    if i == 2 then menu:setMomentary(false) end
    menu:setPage(1)
    Options.menu[i].panel = menu
end--]]


y = 40
x = 0
for i,options in ipairs(Options.panels) do
    --M.Msg('name',name,'options',Table.stringify(options))
    local panel = MButtonPanel.new( {
        name = options.name,
        image = imageFolder..'ComboRev.png',
        rows = options.rows,
        cols = options.cols,
        func = options.func,
        y = y, x = x,w = w,h = h, z = layerZ,
        usePager = true,
        pagerImage = imageFolder..'HorizSpin.png',
        multi = false, --to start with...
        window = window,
        options = {},
        func = options.func
    })
    x = x + (w * options.cols) + menuPad
    layerZ = layerZ - 1
    panel:setPage(1)
    Options.panels[i].panel = panel
    --M.Msg('PANEL = '..Table.stringify(Options.panels[i]))
end--]]
PresetPanel = Options.panels[1].panel
BankPanel = Options.panels[2].panel
VSTPanel = Options.panels[3].panel
PresetPanel:setMulti(true)

local filecount,files = ultraschall.GetAllFilenamesInPath(BANK_FOLDER)
for i = 1, filecount do
    M.Msg('file = '..files[i])
    VSTPanel:setOption(i,{
        name = GetFilename(files[i])
    })
end
Options.panels[3].panel:setPage(1)

window:open()

GUI.Main()


--[[function Plugin.test(name)
    local plug = Plugin.new(name)
    plug.emptyPreset = 'not found'
    plug:setParam('A1','Reverb')
    plug:setParam('A2','Chorus')
    plug:addBank('favorites',120,.05)
    plug:addBank('pianos',10,.09)
    plug:setBankPreset('pianos','Grandeur')
    plug:setBankPreset('favorites','OB pad')
    plug:setBankPreset('favorites','Gentleman')
    plug:setBankPreset('pianos','Black')
    plug:setBankPreset('pianos','Death Piano')
    plug:setBankPreset('pianos','poor naming')
    local curBank = plug:getBank('favorites')
    curBank:setParam('A5','Wah')
    plug:getBank('pianos'):setParam('A1','Reverb')
    --plug:getPresetList()
    return plug
end

local plugName =''
local plug = Plugin.test(plugName)
M.Msg(tostring(plug))
plug:save()
local plug2 = Plugin.load(plugName)
--print(plug2)
M.Msg(tostring(plug2))
plug2.name = 'test2'
plug2:save()--]]