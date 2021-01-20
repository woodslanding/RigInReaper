--------------------------------------------------------Edit Banks---------------------------------------
--[[

    Should NS info be stored with bank?  FI, MPE mode, PB range, etc.?
    Or should we create a real NS editing panel?  Maybe a tab on the organ panel?

    PARAMS PANEL:   Shows all mappable controls, and allows them to be mapped to parameters.
    MENU:
    LISTS:  There are 4 lists reading Left to Right!

        CHANNEL LIST:   Populated with the VSTs of MoonChannels. When a channel is selected, it is queried for its VST,
                                    and if it is found in the bank folder it is shown in the
        VST LIST:       Shows all the VSTs for which bankFiles have been created.
                                    when one of these is selected, it displays its banks in the
        BANK LIST:      Shows all Banks for the chosen VST.
        PRESET LIST:    Shows all Presets for the chosen VST.

        There are Two modes for the BANK LIST:
            1.  Bank Mode:  presets are multi-select, so you select a bank and create a preset list.  Params are for selected BANK only.
                    The actual plugin preset cannot be changed from here, nor can it be saved
            2.  Preset Mode: banks are multi-select, so you can assign a preset to several banks.  Params are GLOBAL for ALL BANKS.
                    Presets can be changed here, for auditioning, and presets can be saved.

    PRESET TYPES:
        1. Stored as RPL, and found in Bank File.  ALL GOOD!
        2. Stored as RPL, and not found in Bank.  ADD TO BANK!
        3. Found in Bank, but no RPL.  MISSING RPL!!
        4. Fxps. mostly just for reaktor, which will not actually load up with any!!
                    so, we just need a 'get fxps' command and options to convert some or all to RPLs
    OPTIONS:
        There are Options for Viewing and Converting Presets:
            View MISSING Bank Presets
            View Unconverted FXPs
            View Bank Presets
            View Presets for Selected Bank only (Bank Mode Only)

            Convert Selected VST's to RPL's (option to overwrite?  Bank Mode only)
            Convert ALL VST's to RPL's  (option to overwrite?)
            Save  Preset (preset mode only)
            Save Current Preset As (preset mode only)

    FILE NAMING:
        1. DisplayName.VstName.lua
        2. We will concatenate this file name when saving, and use the first part when filling vst and channel tables
        3. When loading, we need to search for a file whose first part matches the name in the table, and load the second parts

    OTHER BANK SETTINGS
        1. AT --> CC and TOGGLE/ threshold
        2. MPE or NORMAL?
        3. MPE voice count
        4. AUDIO INPUT (NONE, EXT, MIXER, BOTH)
        5.


]]--

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
Plug = nil
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
local PRESET = {NORMAL = 1, NO_RPL_FOR_FXP = 2, FXP_ONLY = 3, MISSING_RPL = 4 }

local channel = 1  --We will get this from the main window
local channelCount = #GetMoonTracks()  --TODO: query moonutils to get this
--------------------------------------------------------------------------------------------------------------------
------------------------------------------------------ FUNCTIONS ---------------------------------------------------
--------------------------------------------------------------------------------------------------------------------

function setchannel(track)  channel = track end

function Int(ctl) return Math.round(ctl:val()) end

function Map(ctl)
    MSG('mapping control '..ctl.name)
    --if reaper.Get_LastTouch_FX then
        local _, _, paramNum = GetLastTouchedFX()
        if paramNum then
            local paramName = GetParamName(channel,INSTRUMENT_SLOT,paramNum)
            TStr(ctl,'Mapping Control:')
            Bank:setParam(ctl.name,paramNum)
            SavePlug()
            ctl:setCaption(paramName)
        end
    --end
end

function RefreshChannels()
    for i = 1,channelCount do
        Options.chanPanel:setOption(i, { name = GetPluginDisplayName(GetFXName(i)),
                                        color = 'gray',
                                        func = function(self) channel = self.index
                                            SetTrackSelected(channel)
                                            local name =  Options.chanPanel:getSelectionData()
                                            MSG('selecting value: ', name)
                                            VSTPanel:selectByName(name)
                                        end })
    end
    Options.chanPanel:setPage(1)
end

function RefreshBanks()
    local i = 1
    local plugName = GetFXName(channel,INSTRUMENT_SLOT)
    --[[for name,vst in pairs(GetBankFileTable()) do
        MSG('setting option '..name..' to '..vst)
        VSTPanel:setOption(i,{
            name = name,
            vst = vst
        })
        local vstFile = vst..'.dll'
        if vstFile == plugName then VSTPanel:select(i) end
        i = i + 1
    end--]]

    VSTPanel:setPage(1)
end
function LoadPlug()
    Banks = Plug:getBankList()
    BankPanel.options = {}
    BankPanel:setColor('gray',true)
    for i,bankName in ipairs(Banks) do
        --MSG('Adding option for bankpanel: '..bank)
        local bank = Plug:getBank(bankName)
        BankPanel:setOption(i,{name = bankName, bank = bank, color = GetRGB(bank.hue,bank.sat,BRIGHTNESS)})
    end
    BankPanel:setPage(1)
    LoadInstrument(channel, Plug.vstName)

    --Automatically add RPLs to bank?  yes?
    local bankpres = Plug:getPresetList()
    local rpls = GetRPLs(channel)
    local fxps = GetFXPs(channel)
    Presets = {}  --new format!!
    --fill presets from bankfile, and note any that do not have RPLs
    for i, preset in ipairs(bankpres) do
        if not TableContains(rpls, preset) then
            table.insert(Presets, { name = preset, status = PRESET.MISSING_RPL, textColor = 'red' } )
            --possible option: remove missing presets
        else table.insert(Presets, { name = preset, status = PRESET.NORMAL, textColor = 'text' } )
        end
    end
    --1. Add any RPLs to bankfile, regardless
    for i, preset in ipairs(rpls) do
        if not TableContains(bankpres, preset) then
            table.insert(Presets, { name = preset, status = PRESET.NEW, textColor = 'cyan' } )
            --possible option: ask before adding new RPLs
        end
    end

    for i, preset in ipairs(fxps) do
        local presetTable
        --if there is an rpl for the fxp, it will already have been added to the bank, yes??
        if not TableContains(rpls, preset) then
            table.insert(Presets, { name = preset, status = PRESET.FXP_ONLY, textColor = 'yellow' } )
        end
    end
    Presets = ArraySortByField(Presets, 'textColor')
    TStr(Presets,'ALL PRESETS')
    --Presets = ArraySort(Presets)
    --Plug.presets = Presets
    --TStr(Plug,'plug')
    --Plug:save()
    --TStr(Presets,'presets: ')
    PresetPanel:setOptions(Presets)
    PresetPanel:setPage(1)
    RefreshChannels()
end

function SavePlug()
    MSG('Saving plug: '..Plug.name)
    if Plug then Plug:save() end --keep from crashing if we haven't chosen a plug yet
end

function SetBankInfo(color)
    if Bank == nil then return end
    BankColor = color or GetRGB(Bank.hue or 0,Bank.sat or 0,BRIGHTNESS)
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
        if not Bank.params then Bank.params = {} end
        if Bank.params[field] then
            local bankVal = Bank.params[field]
            if bankVal then
                MSG('control '..ctl.name..' set to '..bankVal)
                ctl:setCaption(GetParamName(channel,INSTRUMENT_SLOT,bankVal))
            end
        end
    end
    Options.modePanel:select(2)
    Options.modePanel:setPage(1)
end


-------------------------------------------------------------------------------------------------------
--------------------------------------------------------CONTROLS---------------------------------------
--[[OPTIONS:
There are Options for Viewing and Converting Presets:
    View RPL's
    View VST's
    View ALL   (VSTs are italicized!  Duplicate names in RED? or just don't show VSTs that are duplicates of RPLs?)
    View Presets for Selected Bank only (Bank Mode Only)

    Convert Selected VST's to RPL's (option to overwrite?  Bank Mode only)
    Convert ALL VST's to RPL's  (option to overwrite?)
    Save  Preset (preset mode only)
    Save Current Preset As (preset mode only)--]]
Options = {
    menu = {
        { --submenu 2
            {name = 'Save Preset', func = function(self) end
                    --check new ultrashall chunk handling


            },
            {name = 'Save As',func = function(self)
                    Keyboard:visible(true)
                    Keyboard.func = function()
                        MSG('Saving preset as '..Keyboard.text)
                        --local track, fxnum, Preset_Name = Get_LastTouch_FX()
                        --MSG('effect = '..self.text)
                        --Save_VST_Preset(track,fxnum,self.text)
                        Keyboard:visible(false)
                    end
                end
            }

        },
        {
            {name = 'Delete Preset',func = function(self) end   },
            {name = 'Rename Preset',func = function(self) end   },
        },
        {
            {name = 'New Bank',   func = function(self)
                Keyboard:setTitle('New Bank Name:')
                Keyboard:visible(true)
                Keyboard.func = function()
                    MSG('Creating New Bank '..Keyboard.text)
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
                                        local vstName = GetFXName(channel,INSTRUMENT_SLOT)
                                        Keyboard:setTitle('Set Display Name for '..vstName..':')
                                        Plug = Plugin.new(vstName,Keyboard.text,{})
                                        Plug:save()
                                        RefreshBanks()
                                    end
                            end
            },
            {name = 'ShowVST',func = function(self) OpenVST(channel) end },
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
                    --TStr(option,'add option')
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
                --TStr(Bank,'selected bank')
                PresetPanel:clearSelection()
                SetBankInfo()
                --might be able to streamline this, now options are indexed....
                for i, option in ipairs(PresetPanel.options) do
                    option.color = Bank:getColor()
                    for _, name in ipairs(Bank.presets) do
                        if name == option.name then
                            --MSG('adding preset '..name..' for option: '..i)
                            PresetPanel:select(i,true)
                        end
                    end
                end
                PresetPanel:setPage(1)
            elseif Mode == MODES.PRESET then
                local bankNums = BankPanel:getSelectionData()
                local preset = PresetPanel:getSelectionData()
                --MSG('in presetmode:  ',preset)
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
        {name = 'expcrv',title = 'Exp Curve',min = 0, max = 10, func = function(self) Bank.expcrv = Int(self) SavePlug() end },
        {name = 'ped2crv',title = 'Ped2 Curve',min = 0, max = 10, func = function(self) Bank.ped2crv = Int(self) SavePlug() end },
    },
    --[[OTHER ARCANE BANK SETTINGS
    buttons:
        AUDIO INPUT (NONE, EXT, MIXER, BOTH)
        MIDI IN: MPE or NORMAL?  --tag on to midiIn button
        PB->NOTES
    sliders:
        MPE voice count
        PB RANGE IN
        PB RANGE OUT
        AT --> CC
        AT TOGGLE /threshold
        Transpose->CC   --poss. control pitchshift vst?
    textfield:
        bank notes (probably display only--we don't want to type a bunch of stuff with the onscreen keyboard)
    ]]
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
    mode = {
        {name = 'Preset Mode', func = function(self)
            MSG('setting preset Mode')
            Mode = MODES.PRESET
            PresetPanel:setMulti(false)    BankPanel:setMulti(true)
            SetBankInfo('gray')
            --PresetPanel:setColor('gray',true)
            BankParamLayer:hide()
            --set mappings to global
            PresetPanel:setPage(1)       BankPanel:setPage(1)
        end  },
        {name = 'Bank Mode', func = function(self)
            MSG('setting Bank Mode')
            Mode = MODES.BANK
            BankParamLayer:show()
            PresetPanel:setMulti(true)     BankPanel:setMulti(false)
            --set mappings to BANK
            PresetPanel:setPage(1)       BankPanel:setPage(1)
        end  },
    },
    presetMenu =
    {
        {name = 'Show All', func = function(self) end
            --if Plug then
        },
        {name = 'Update FXPs', func = function(self)
        end
        },
        {name = 'Update RPLs', func = function(self)
            Keyboard:visible(true)
            Keyboard.func = function()
                if Plug then
                    Keyboard:setTitle('Ignore Presets Named:')
                    local presets = GetRPLs(channel, Keyboard.text)
                    Plug:addPresets(presets)
                    Plug:save()
                    RefreshBanks()
                end
            end
        end
        },
    },
    chanPanel = {}
}
--------------------------------------------------------------------------------------------------------------
------------------------------------------- GUI Elements -----------------------------------------------------
--------------------------------------------------------------------------------------------------------------
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
y = 0

for i, b in ipairs(Options.controlMappings) do
    x = 0
    for j = 1,Options.controlMappings[i].cols  do
        --MSG('x = '..x,'y = '..y)
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
        MSG('adding button to layer: '..button.name)
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
    MSG('adding button to layer: '..button.x..','..button.y)
    mappingLayer:addElements(button)
    table.insert(MappingControls,button)
end
--------------------------------------------------------------------------------------------------------------
----------------------------------------------LAYOUT BANK SETTINGS -------------------------------------------

for i,s in ipairs(Options.sliders) do
    local waitToSet
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
        waitToSet = s.waitToSet or false
    })
    Options.sliders[i] = slider
    MSG('slider '..i..' = '..slider.name)
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
    MSG('in create bank settings')
    local rows = 5
    local x = (11 * w) + (pad * 2)
    local y = 0
    local xpos, ypos = GetLayoutXandY(i,x,y,w,h,rows)
    MSG('layout = '..xpos..', '..ypos)
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
    TStr(menu, 'menu')
    --MSG(Table.stringify(menu))
    x = x + pad + ((#submenu) *  w)
    --do we need this?  check later...
    --layerZ = layerZ - 1
    for i,option in ipairs(submenu) do
        --MSG('calling set option: '..tostring(menu.name))
        local newOption = menu:setOption(i,option)
        newOption.func = option.func
    end
    --if i == 2 then menu:setMomentary(false) end
    MSG('setting menu ')
    menu:setPage(1)
    Options.menu[i].panel = menu
end--]]

-------------------------------------------------------------------------------
-------------------------LAYOUT MAIN PANELS-----------------------------
y = (h * 8) + (pad * 2)
x = 0
for i,options in ipairs(Options.panels) do
    --local x, y = 0, 40
    --MSG('name',name,'options',Table.stringify(options))
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
    --layerZ = layerZ - 1
    panel:setPage(1)
    Options.panels[i] = panel
    --MSG('PANEL = '..Table.stringify(Options.panels[i]))
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
-----------------------------------------------------------------------------------------------------
---------------------------------------------MODE BUTTONS--------------------------------------------
local modePanel = MButtonPanel.new({
    name = 'mode',
    image = imageFolder.."Combo.png",
    z = layerZ,
    color = 'blue',
    font = 2,
    rows = 1, cols = #Options.mode,
    x = (5 * w) + pad , y = (h * 16) + (pad*2), w = w, h = h,
    usePager = false,
    multi = false,
    window = BankWindow,
    options = {},
})
Options.modePanel = modePanel

for i,option in ipairs(Options.mode) do
    local newOption = modePanel:setOption(i,option)
end
Options.modePanel:select(2)
Options.modePanel:setPage(1)

------------------------------------------------------------------------------------------------------
------------------------------------------CHAN SELECT-------------------------------------------------
local panel = MButtonPanel.new({
    name = 'chanSelect',
    image = imageFolder.."Combo.png",
    z = layerZ,
    color = 'blue',
    font = 2,
    rows = 8, cols = 2,
    x = (w * 11) + (pad * 3) , y = (h * 8) + (pad * 2), w = w, h = h,
    usePager = false,
    multi = false,
    window = BankWindow,
    options = {},
})
Options.chanPanel = panel
RefreshChannels()

--[[function RefreshChannels()
    for i = 1, channelCount do
        Options.chanPanel:setOption(i, {name = GetPluginDisplayName(GetFXName(i)), func = function(self) channel = self.index end  } )
    end
    Options.chanPanel:setPage(1)
end--]]


------------------------------------------------------------------------------------------------------
-------------------------------------------WINDOW-----------------------------------------------------
Keyboard = MText.new({
    x = 100, y = 100, window = BankWindow
})
Keyboard:visible(false)

BankWindow:addLayers(BankParamLayer,mappingLayer)

--Fullscreen(BankWindow.name)
function OpenBankEditor()
    BankWindow:open()
    GUI.Main()
end

OpenBankEditor()