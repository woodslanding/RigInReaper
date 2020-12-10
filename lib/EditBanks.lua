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
require 'MSlider'
require "moonUtils"
require 'createMoonBank'
require 'MButtonPanel'
require 'MText'

BRIGHTNESS = 60

local GUI = require("gui.core")
local M = require("public.message")
local Table = require("public.table")
local Math = require("public.math")
local T = Table.T

Keyboard = {}
Plug = {}
Bank = {}
Banks = {}
Presets = {}
Preset = nil
PresetPanel = {}
BankPanel = {}
VSTPanel = {}

MappingControls = {}

BankColor = {}
BankSettings = {}
ColorByBanks = {}
BankParamLayer = GUI.createLayer({name = "bankParamLayer", z = 9})
BankWindow = GUI.createWindow({ name = "EDIT BANKS", w = 1300, h = 800, x = 0, y = 0,})

Mode = nil
MODES = {BANK = 'Bank Mode', PRESET = 'Preset Mode'}

CurrentTrack = 1  --We will get this from the main window


-------------------------------------------------------------------------------------------------------
--------------------------------------------------------CONTROLS---------------------------------------
Options = {
    menu = {
        {
            {name = 'Save Preset', func = function(self) end   },  --from x-raym
            {name = 'Save As',func = function(self)
                Keyboard:visible(true)
                Keyboard.func = function()
                    M.Msg('Saving preset as '..Keyboard.text)
                    --local track, fxnum, Preset_Name = Get_LastTouch_FX()
                    --M.Msg('effect = '..self.text)
                    --Save_VST_Preset(track,fxnum,self.text)
                    Keyboard:visible(false)
                end
            end

        },
            {name = 'Delete Preset',func = function(self) end   },
            {name = 'Rename Preset',func = function(self) end   },
        },
        {
            {name = 'Preset Mode', func = function(self)
                M.Msg('setting preset Mode')
                Mode = MODES.PRESET
                PresetPanel:setMulti(false)    BankPanel:setMulti(true)
                SetBankInfo('gray')
                --PresetPanel:setColor('gray',true)
                BankParamLayer:hide()
                --set mappings to global
                PresetPanel:setPage(1)       BankPanel:setPage(1)
            end  },
            {name = 'Bank Mode', func = function(self)
                M.Msg('setting Bank Mode')
                Mode = MODES.BANK
                BankParamLayer:show()
                PresetPanel:setMulti(true)     BankPanel:setMulti(false)
                --set mappings to BANK
                PresetPanel:setPage(1)       BankPanel:setPage(1)
            end  },
          },
        {
            {name = 'New Bank',   func = function(self)
                Keyboard:setTitle('New Bank Name:')
                Keyboard:visible(true)
                Keyboard.func = function()
                    M.Msg('Creating New Bank '..Keyboard.text)
                    Plug:addBank(Keyboard.text)
                    Keyboard:visible(false)
                    SavePlug()
                    LoadPlug()
                end
            end  },
            --{name = 'Rename Bank',func = function(self) end  },
            --{name = 'Save Banks', func = function(self) end  }, --do this automatically unless there is a performance hit somehow
            {name = 'Delete Bank',func = function(self) end  },
        },
        {
            {name = 'New VST',func = function(self)
                    Keyboard:visible(true)
                    Keyboard.func = function()
                        M.Msg('Creating New Vst File '..Keyboard.text)
                        local vstName = GetFXName(CurrentTrack,INSTRUMENT_SLOT)
                        M.Msg('Vst Dll = '..vstName)
                        Plug = Plugin.new(vstName,Keyboard.text,{})
                        Keyboard:visible(false)
                        Plug:save()
                        RefreshBanks()
                    end
            end
            },
            {name = 'ShowVST',func = function(self) OpenVST(CurrentTrack) end    },
            --todo: move and resize
            -- reaper.TrackFX_GetFloatingWindow( track, index )
            -- retval, ZOrder, flags = reaper.JS_Window_SetPosition( windowHWND, left, top, width, height, ZOrder, flags )
            {name = 'Close', func = function(self) CloseWindow(BankWindow.name) end },
        },

    },
    panels = {
        {name = 'presets',rows = 8, cols = 5, icon = 'ComboRev',func = function(self)
            if Mode == MODES.BANK then
                local presetNums = PresetPanel:getSelectionData('index')
                TStr(presetNums,'preset nums')
                Plug:setPresetsForBank(Bank.name,presetNums)
                SavePlug()
            elseif Mode == MODES.PRESET then
                --select a single preset, and add it to multiple banks
                --first set the bank buttons to the selected preset
                Preset = self.name
                BankPanel:clearSelection()
                --go through all the bankpanel's options
                --for each one, get the bank name, and query the plug to determine if the preset is in it
                for i,option in ipairs(BankPanel.options) do
                    TStr(option,'add option')
                    BankPanel:select(i,true)
                    --[[if Plug:bankContainsPreset(option.name,Preset) then
                        local button = BankPanel:getButtonForOption(i)
                        BankPanel:select(button.index,true)
                    end--]]
                end
                BankPanel:setPage(1)
            end
        end },
        {name = 'banks',rows = 8, cols = 4, icon = 'ComboRev',func = function(self)
            if Mode == MODES.BANK then
                Bank = Plug:getBank(self.name)
                PresetPanel:clearSelection()
                SetBankInfo()
                --PresetPanel:setPage(1)
                --PresetPanel:setColor(color,true)  --don't do this manually.  set the option and then set the page!
                --M.Msg('PRESETS = \n'..Table.stringify(Bank.presets))
                --might be able to streamline this, now options are indexed....
                for i, option in ipairs(PresetPanel.options) do
                    option.color = Bank:getColor()
                    for _, name in ipairs(Bank.presets) do
                        if name == option.name then
                            M.Msg('adding preset '..name..' for option: '..i)
                            PresetPanel:select(i,true)
                        end--]]
                    end
                end--]]--
                PresetPanel:setPage(1)
            elseif Mode == MODES.PRESET then
                local bankNums = BankPanel:getSelectionData()
                local preset = PresetPanel:getSelectionData()
                --M.Msg('in presetmode:  ',preset)
                --TStr(bankNums,'bank numbers')
                if bankNums and preset then Plug:addPresetToBanks(preset,bankNums) SavePlug() end
            end
        end },
        {name = 'VSTs',rows = 8, cols = 2, icon = 'ComboRev',func = function()
             --self is a button, not a panel.
            Plug = Plugin.load(VSTPanel:getSelection().name)
            LoadPlug()
        end },
    },
    --these will display a parameter name, and have an icon to show what they are mapped from
    controlMappings = {        --(clicking assigns last touched param, if vst window is open)
        { name = 'ENC',cols = 8,icon = 'EncMap'},
        { name = 'SWA',cols = 8,icon = 'Sw1Map'},
        { name = 'SWB',cols = 8,icon = 'Sw2Map'},
        { name = 'DRB',cols = 9,icon = 'DrawbarMap'},
        { name = 'TGA',cols = 4,icon = 'UpToggleMap' },
        { name = 'TGB',cols = 4,icon = 'DnToggleMap' },
        { name = 'FSW',cols = 4,icon = 'FootswMap'},
    },
    controls = {
        { name = 'MW', icon = 'MWMap'},
        { name = 'BC', icon = 'BCMap'},
        { name = 'AT', icon = 'ATMap'},
        { name = 'EXP', icon = 'ExpMap'},
        { name = 'PED2', icon = 'Ped2Map'},
        { name = 'SUS', icon = 'SusMap'},
    },
    sliders = {
        {name = 'sat',title = 'Saturation',min = 0,max = 100,func = function(self) Bank.sat = Int(self) SavePlug() SetBankInfo() end },
        {name = 'hue',title = 'Hue',min = 0, max = 360,func = function(self) Bank.hue = Int(self) SavePlug() SetBankInfo() end },
        {name = 'trim',title = 'Trim',min = 0, max = 100,func = function(self) Bank.trim = Int(self) SavePlug() end },
        {name = 'expcrv',title = 'Exp Curve',min = 0, max = 10, func = function(self) Bank.expcrv =Int(self) SavePlug() end },
        {name = 'ped2crv',title = 'Ped2 Curve',min = 0, max = 10, func = function(self) Bank.ped2crv =Int(self) SavePlug() end },
    },
    rangeSliders = {
        {name = 'lokey',title = 'Low', func = function(self) Bank.lokey = Int(self) self:setCaption(GetNoteName(self:val())) SavePlug() end },
        {name = 'hikey',title = 'High', func = function(self) Bank.hikey = Int(self) self:setCaption(GetNoteName(self:val())) SavePlug() end },
    },
    bankSettings = {
        {name = 'isfx',title = 'Is Effect',func = function(self) Bank.isfx = self:val() SavePlug() end },
        {name = 'extin',title = 'Ext Audio',func = function(self) Bank.extin = self:val() SavePlug() end },
        {name = 'midiin',title = 'MIDI In',func = function(self) Bank.midiin = self:val() SavePlug() end },
        {name = 'nsolo',title = 'NS Solo',func = function(self) Bank.nsolo = self:val() SavePlug() end },
        {name = 'fakesus',title = 'Fake Sustain',func = function(self) Bank.fakesus = self:val() SavePlug() end }, --poss. global value?
    },
}

function setCurrentTrack(track)  CurrentTrack = track end

function Int(ctl) return Math.round(ctl:val()) end

function Map(ctl)
    M.Msg('mapping control '..ctl.name)
    --if reaper.Get_LastTouch_FX then
        local _, _, paramNum = GetLastTouchedFX()
        if paramNum then
            local paramName = GetParamName(CurrentTrack,INSTRUMENT_SLOT,paramNum)
            TStr(ctl,'Mapping Control:')
            Bank:setParam(ctl.name,paramNum)
            SavePlug()
            ctl:setCaption(paramName)
        end
    --end
end

function RefreshBanks()
    local i = 1
    local plugName = GetFXName(CurrentTrack,INSTRUMENT_SLOT)
    for name,vst in pairs(GetBankFileTable()) do
        M.Msg('setting option '..name..' to '..vst)
        VSTPanel:setOption(i,{
            name = name,
            vst = vst
        })
        local vstFile = vst..'.dll'
        if vstFile == plugName then VSTPanel:select(i) end
        i = i + 1
    end

end
function LoadPlug()
    Banks = Plug:getBankList()
    BankPanel.options = {}
    BankPanel:setColor('gray',true)
    for i,bankName in ipairs(Banks) do
        --M.Msg('Adding option for bankpanel: '..bank)
        local bank = Plug:getBank(bankName)
        BankPanel:setOption(i,{name = bankName, bank = bank, color = GetRGB(bank.hue,bank.sat,BRIGHTNESS)})
    end
    BankPanel:setPage(1)
    LoadInstrument(CurrentTrack, Plug.vstName)
    --this should be some sort of option... normally use
    local sourcePresets = GetRplPresets(CurrentTrack)
    Presets = Plug:getPresetList()
    for i,preset in ipairs(sourcePresets) do
        --M.Msg('checking preset '..preset)
        if not TableContains(Presets,preset) then
            table.insert(Presets,preset)
        end
    end
    Presets = ArraySort(Presets)
    Plug.presets = Presets
    TStr(Plug,'plug')
    Plug:save()
    --TStr(Presets,'presets: ')
    PresetPanel.options = {}
    for i,preset in ipairs(Presets) do
        PresetPanel:setOption(i,{name = preset}) end
    PresetPanel:setPage(1)
end

function SavePlug()
    M.Msg('Saving plug: '..Plug.name)
    if Plug then Plug:save() end --keep from crashing if we haven't chosen a plug yet
end

function SetBankInfo(color)
    BankColor = color or GetRGB(Bank.hue,Bank.sat,BRIGHTNESS)
    for i, element in pairs(ColorByBanks) do
        element:setColor(BankColor,true)
    end
    for i, ctl in pairs(BankSettings) do
        local field = ctl.name
        if Bank[field] then
            local bankVal = Bank[field]
            if bankVal then ctl:val(bankVal) end
        end
    end
    for i, ctl in pairs(MappingControls) do
        local field = ctl.name
        if Bank.params[field] then
            local bankVal = Bank.params[field]
            if bankVal then
                M.Msg('control '..ctl.name..' set to '..bankVal)
                ctl:setCaption(GetParamName(CurrentTrack,INSTRUMENT_SLOT,bankVal))
            end
        end
    end
end

---------------------------------------------------------------------------
-------- GUI Elements -----------------------------------------------------
---------------------------------------------------------------------------
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
local mappingLayer = GUI.createLayer({name = "mappingLayer", z = 10})
local  pad = 8
local w,h = 96,36
local layerZ = 40
local x,y = 0,0

--------------------------------------------------------------------------------------------------------------
----------------------------------------------LAYOUT CONTROL MAPPINGS-----------------------------------------
w,h = 96,36
y = 0--(h * 9) + pad
for i, b in ipairs(Options.controlMappings) do
    x = 0
    for j = 1,Options.controlMappings[i].cols  do
        --M.Msg('x = '..x,'y = '..y)
        local button = GUI.createElement({
            type = 'MButton',
            color = 'gray',
            font = 3,
            caption = b.name..j,
            image = imageFolder..b.icon..'.png',
            name = b.name..j,
            min = 0, max = 1,
            frames = 2,
            func = function(self) Map(self) end,
            x = x, y = y, w = w, h = h,
            momentary = true
        })
        Options.controlMappings[i][j] = button
        table.insert(ColorByBanks,button)
        table.insert(BankSettings,button)
        mappingLayer:addElements(button)
        M.Msg('adding button to layer: '..button.name)
        table.insert(MappingControls,button)
        x = x + w
    end
    y = y + h
end
y = h * 4 + pad
for i,b in ipairs(Options.controls) do
    local xpos,ypos = GetLayoutXandY(i,(5 * w), y, w, h, 2)
    local button = GUI.createElement({
        type = 'MButton',
        color = 'gray',
        font = 3,
        caption = b.name,
        image = imageFolder..b.icon..'.png',
        name = b.name,
        min = 0, max = 1,
        frames = 2,
        func = function(self) Map(self) end,
        x = xpos, y = ypos, w = w, h = h,
        momentary = true,
    })
    Options.controls[i] = button
    table.insert(ColorByBanks,button)
    table.insert(BankSettings,button)
    M.Msg('adding button to layer: '..button.x..','..button.y)
    mappingLayer:addElements(button)
    table.insert(MappingControls,button)
end
--------------------------------------------------------------------------------------------------------------
----------------------------------------------LAYOUT BANK SETTINGS -------------------------------------------
for i,s in ipairs(Options.sliders) do
    local xpos = (9 * w) + (pad * 2)
    local ypos = (i - 1) * h -- ((i + 9) * h) + pad
    local slider = GUI.createElement({
        type = 'MSlider',
        color = 'gray',
        font = 2,
        caption = s.title,
        horizontal = true,
        name = s.name,
        image = imageFolder.."SimpleFader.png",
        x = xpos, y = ypos, w = w *2, h = h,
        min = s.min, max = s.max, sens = 1,
        frames = 49,vertFrames = true,
        func = s.func,
        waitToSet = true
    })
    Options.sliders[i] = slider
    M.Msg('slider '..i..' = '..slider.name)
    table.insert(ColorByBanks,slider)
    table.insert(BankSettings,slider)
    BankParamLayer:addElements(slider)
end

for i,s in ipairs(Options.rangeSliders) do
    local wid, ht = 42, 252
    local xpos, ypos = GetLayoutXandY(i, (12 * w) + (pad * 2),0, wid, ht, 1)
    local slider = GUI.createElement({
        type = 'MSlider',
        color = 'gray',
        font = 4,
        textColor = 'black',
        caption = s.title,
        horizontal = false,
        name = s.name,
        image = imageFolder.."NoteFader.png",
        x = xpos, y = ypos, w = wid, h = ht,
        min = 0, max = 127, sens = 1,
        frames = 128,vertFrames = true,
        func = s.func,
        labelY = .4,
        waitToSet = true
    })
    --put them in with the other sliders...
    Options.sliders[i+5] = slider
    table.insert(ColorByBanks,slider)
    table.insert(BankSettings,slider)
    BankParamLayer:addElements(slider)
end

for i,b in ipairs(Options.bankSettings) do
    M.Msg('in create bank settings')
    local rows = 5
    local x = (11 * w) + (pad * 2)
    local y = 0
    local xpos, ypos = GetLayoutXandY(i,x,y,w,h,rows)
    M.Msg('layout = '..xpos..', '..ypos)
    local button = GUI.createElement({
        type = "MButton",
        color = 'gray',
        font = 2,
        caption = b.title,
        name = b.name,
        image = imageFolder.."Combo.png",
        x = xpos, y = ypos, w = w, h = h,
        min = 0, max = 1, frames = 2,
        func = b.func,
    })
    table.insert(ColorByBanks,button)
    table.insert(BankSettings,button)
    BankParamLayer:addElements(button)
end

-----------------------------------------------------------------------------------------------
-----------------------------------------------MENU--------------------------------------------
y = (h * 7) + pad
x = 0
for i,submenu in ipairs(Options.menu) do
    local menu = MButtonPanel.new({
        name = 'menu_'..i,
        image = imageFolder.."Combo.png",
        momentary = true,
        z = layerZ,
        color = 'blue',
        font = 2,
        rows = 1, cols = #submenu,
        x = x, y = y, w = w, h = h,
        usePager = false,
        multi = false,
        window = BankWindow,
        options = {},
    })
    --M.Msg(Table.stringify(menu))
    x = x + pad + ((#submenu) *  w)
    --do we need this?  check later...
    layerZ = layerZ - 1
    for i,option in ipairs(submenu) do
        --M.Msg('calling set option: '..tostring(menu.name))
        local newOption = menu:setOption(i,option)
        newOption.func = option.func
    end
    if i == 2 then menu:setMomentary(false) end
    M.Msg('setting menu ')
    menu:setPage(1)
    Options.menu[i].panel = menu
end--]]

-------------------------------------------------------------------------------
-------------------------LAYOUT MAIN PANELS-----------------------------
y = (h * 8) + (pad * 2)
x = 0
for i,options in ipairs(Options.panels) do
    --local x, y = 0, 40
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
        window = BankWindow,
        options = {},
        func = options.func
    })
    x = x + (w * options.cols) + pad
    layerZ = layerZ - 1
    panel:setPage(1)
    Options.panels[i] = panel
    --M.Msg('PANEL = '..Table.stringify(Options.panels[i]))
end--]]
PresetPanel = Options.panels[1]
table.insert(ColorByBanks,PresetPanel)
BankPanel = Options.panels[2]
VSTPanel = Options.panels[3]
--we should startup in preset mode...
Options.menu[2].panel:select(2)

--set the vst options.  if one of the options matches the last touched vst, then select it

--local vstNum
RefreshBanks()
VSTPanel:setPage(1)


------------------------------------------------------------------------------------------------------
-------------------------------------------WINDOW-----------------------------------------------------
Keyboard = MText.new({
    x = 100, y = 100, window = BankWindow
})
Keyboard:visible(false)

BankWindow:addLayers(BankParamLayer,mappingLayer)
BankWindow:open()
--Fullscreen(BankWindow.name)

GUI.Main()