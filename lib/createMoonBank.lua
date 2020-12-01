--[[
   we want to populate the combos with two things:
    1.  a list of banks for this particular VST
    2.  a list of presets for the selected bank.
    so the function would be:  loadPresets(vstName,bankname)
    this would search the file vstName and return 2 values:
        1. a list of all the bank names for this vstName
        2. a list of all the presets in the bank 'bankname'
    selecting a bank parses the moonBank file, and creates bank lists for it
    -----------------------
    If we have a 1-button solution to converting vst built-in programs to RPLs,
    (updating) we can deal exclusively with RPLs.

    for creating the .mbf file we need:
    1.  A means of viewing ALL presets for a vst (rpl list) and assigning each one
        to one or more banks.  This can be a fullscreen window with button arrays
        on the left for presets, and the right for banks.  The bank buttons are
        multi-select, and bank data is written whenever the preset is changed.
        they also need some indication of 'last selected', for bank editing.
        It should show a lot of (32?) banks, with option for paging
        It should be associated with a track so the selected preset can be auditioned.
    2.  Also needs: Buttons for creating, renaming, reordering, coloring, and deleting banks/tags.
    3.  Need a window for assigning params to widgets, both globally and per bank.  Global could be
        in a page of main window, but bank should probably be accessed from the bank edit page.

    We should be able to save the current preset from this page.  When a preset has been edited,
    we can open this page and
    1.  Just save the preset under its current name  or
    2.  Select a new name and bank(s) for the preset

    CONTROL LIST:
    1.  Select VST--this will load all banks for this VST
    2.  Bank Mode:  presets are multi-select, so you select a bank and create a preset list.  Params are for selected BANK.
    3.  Preset Mode: banks are multi-select, so you can assign a preset to several banks.  Params are GLOBAL
    3.  Switch to edit global params, vs bank params--[done above!]
    4.  Switch to show all presets, vs. just those in the chosen bank.  Bank mode only!
    5.  Maybe Someday--drag and drop for preset/bank position vs. alphabetized (toggle) d&d does seem possible... for now just alphabetize
    6.  Params should be at side of screen, to allow for VST window to be open.  Window should also not be full screen.
    7.  Half-learn, where you wiggle a vst control and then press a widget button to assign it.
    8.  Widgets: Encoder, sw1, sw2, drawbars, organ toggles, 4 footswitches,Pedal2, BC, MOD,
            maybe also Exp and Sustain (defeat normal assignment)
    9.  Use the Inspector channel when opening...
    10. Create New Bank.  Delete Bank.  Rename Bank.  Set Bank Hue and Sat.  Write All Banks.  Save Preset.
    11. Other banks settings?  NS Solo.  Key Range!?  Exp,Ped2 Curve, IS FX, Ext Audio IN, Fake Sus, Midi Input,
]]--

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

local M = require("public.message")
local Table = require("public.table")
local T = Table.T

require 'moonUtils'
--from moonUtils:
--[[function Esc(str) return ("%q"):format(str) end
function CleanComma(s)  return s:sub(1, string.len(s) -2) end
function TableSort(t)
    local sorted = {}
    for n in pairs(t) do table.insert(sorted, n) end

    table.sort(sorted)
    return sorted
end

function ArraySort(t)
    local sorted = {}
    for i in ipairs(t) do table.insert(sorted,t[i]) end
    table.sort(sorted)
    return sorted
end--]]

local Bank = {}
Bank.__index = Bank

local PATH = 'C:\\Users\\moon\\Documents\\_REAPER\\Scripts\\_RigInReaper\\Banks\\'  --for testing

function Bank.new(name,hue,sat,image)
    local self = setmetatable({}, Bank)
    self.name = name
    self.hue = hue or 0
    self.sat = sat or 0
    self.image = image or ''
    self.params = {}
    self.presets = {}
    return self
end

function Bank:__tostring()
    local rtnStr = '    '..self.name..' = { '..'name = '..Esc(self.name)..', hue = '..self.hue..', sat = '..self.sat..',\n            '
    ..GetParamStr(self.params)..'\n'
    ..GetPresetStr(self.presets)..'\n'
    ..'        }'
    return rtnStr
end

function Bank:addPreset(name)
        self.presets[name] = name
        M.Msg('Added preset '..name..', presets = '..Table.stringify(self.presets))
end

function Bank:setParam(control,name)
    self.params[control]=name
    --don't map encoder push mappings, they are just for soloing (receive only on this track)
    --E1...E8,   --encoder mappings
    --L1...L8,   --lower button mappings
    --U1...U8,   --upper button mappings
    --F1...F4,   --footswitch mappings
    --T1...T8,   --organ toggle mappings
    --D1...D9,   --drawbar mappings
end

function Bank:getParam(control)
    return self.params.name
end

function GetPresetStr(presets)
    M.Msg('PRESETS UNSORTED = \n'..Table.stringify(presets))
    local retStr = '            presets = {'
    local sorted = TableSort(Table.invert(presets))
    M.Msg('PRESETS SORTED = \n'..Table.stringify(sorted))
    for index,val in pairs(sorted) do
        retStr = retStr..Esc(val)..', '
    end
    return CleanComma(retStr)..'}'
end
--used by both Banks and Plugs
function GetParamStr(params)
    local paramT= {}
    local paramStr = 'params = {'
    for control,param in pairs(params) do
        table.insert(paramT,control..' = '..Esc(param))
    end
    paramStr = paramStr..table.concat(paramT,',')..'},'
    return paramStr
end

function Bank:getPresets()

    return ArraySort(self.presets)
    --[[for preset in pairs(self.presets) do
        table.insert(presets,tostring(self.presets[preset]))
    end
    ArraySort(presets)
    return presets--]]
end

---------------------------PLUGIN METHODS --------------------------
Plugin = {}
Plugin.__index = Plugin

function Plugin:__tostring()
    local bankT = {}
    local plugStr = 'return {\n    '..'name = '..Esc(self.name)..', emptyPreset = '..Esc(self.emptyPreset)..','
    local preStr =  '\n    presets = {'..self:getPresetString()..'}, \n'
    local bankPre = '\n    banks = {\n    '
    for bankName in pairs(self.banks) do
        table.insert(bankT,tostring(self.banks[bankName]))
    end
    return plugStr..preStr..'    '..GetParamStr(self.params)..bankPre..table.concat(bankT,',\n    ')..'\n    }\n'..'}'
end

function Plugin:getPresetString()
    local retStr = ''
    M.Msg('GETTING MASTER PRESET LIST: presets unsorted'..Table.stringify(self.presets))
    local sorted = TableSort(Table.invert(self.presets))
    for i,val in ipairs(sorted) do
        retStr = retStr..Esc(val)..', '
    end
    M.Msg('MASTER:Presets sorted = '..retStr)
    return CleanComma(retStr)
end

function Plugin.new(vstName)
    local self = setmetatable({}, Plugin)
    self.presets = {}
    self.name = vstName
    self.params = {}
    self.banks = {}
    self.emptyPreset = ''
    return self
end

function Plugin:getPresetList()
    local sorted = ArraySort(self.presets)
    M.Msg('PLUGIN GETTING PRESETS = \n'..Table.stringify(sorted))
    return sorted
end

function Plugin:addBank(bankName,hue,sat)
    --just quietly overwrite any existing bank?  for now...
    self.banks[bankName] = Bank.new(bankName,hue,sat)
end

function Plugin:addPreset(preset)
    if not self.presets[preset] then
        self.presets[preset] = preset
    end
end

function Plugin:setPresetsForBank(bankName,presetList)
    self.banks[bankName].presets = {}
    for i,name in ipairs(presetList) do
        self.banks[bankName]:addPreset(name)
    end
end

function Plugin:setBankPreset(bankName,presetName)
    if not self.banks[bankName] then print('non-existent bank: '..bankName) return end
    M.Msg('setting bank preset '..presetName..', remove = ',remove)
    self:addPreset(presetName)
    self.banks[bankName]:addPreset(presetName)
end
function Plugin:getBankList()
    return TableSort(self.banks)
end
function Plugin:getBank(bank)
    return self.banks[bank]
end

function Plugin:setParam(control,name)
    self.params[control]=name
end

function Plugin:getParam(control)
    return self.params[control]
end

function Bank.init(data)
    local self = setmetatable(data,Bank)
    return self
end

function Plugin.load(filename)
    M.Msg('loading file: '..PATH..filename)
    local f = assert(loadfile(PATH..filename..'.lua'))
    local data = f()
    local self = setmetatable(data,Plugin)
    --M.Msg('initializing banks')
    for bankName,table in pairs(self.banks) do
        self.banks[bankName] = Bank.init(table)
        M.Msg('init bank'..Table.stringify(self.banks[bankName]))
    end
    return self
end
function Plugin:save()
    local filename = PATH..self.name..'.lua'
    local file = io.open(filename,'w')
    file:write(tostring(self))
    file:close()
end

--[[function Plugin.test(name)
    local plug = Plugin.new(name)
    plug.emptyPreset = 'not found'
    plug:setParam('A1','Reverb')
    plug:setParam('A2','Chorus')
    plug:addBank('favorites',120,50)
    plug:addBank('pianos',10,.90)
    plug:setBankPreset('pianos','Grandeur')
    plug:setBankPreset('favorites','OB pad')
    plug:setBankPreset('favorites','Grandeur')
    plug:setBankPreset('pianos','Black')
    plug:setBankPreset('pianos','Death Piano')
    plug:setBankPreset('pianos','poor naming')
    local curBank = plug:getBank('favorites')
    curBank:setParam('A5','Wah')
    plug:getBank('pianos'):setParam('A1','Reverb')
    --plug:getPresetList()
    return plug
end
--[[
local plugName = 'Test'
local plug = Plugin.test(plugName)
plug:save()
local plug2 = Plugin.load(plugName)
print(plug2)
print(table.concat(plug:getPresetList(),', '))
plug2.name = 'test2'
plug2:save()--]]

