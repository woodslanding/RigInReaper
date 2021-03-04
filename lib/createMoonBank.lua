
   --[[
we want to populate the combos with two things:
   1.  a list of banks for this particular VST
   2.  a list of presets for the selected bank.
   so the function would be:  loadPresets(vstName,bankname)
   this would search the file vstName and return 2 values:
       1. a list of all the bank names for this vstName
       2. a list of all the presets in the bank 'bankname'
   selecting a vst parses the moonBank file, and creates bank lists for it
   -----------------------
   If we have a 1-button solution to converting vst built-in programs to RPLs,
   (updating) we can deal exclusively with RPLs.

    for creating the .mbf file we need:
    1.  A means of viewing ALL presets for a vst (rpl list) and assigning each one
        to one or more banks.  This can be a fullscreen window with button arrays
        on the left for presets, and the right for banks.  The bank buttons are
        multi-select, and bank data is written whenever the preset is changed.
        It should show a lot of (32?) banks, with option for paging
        It should be associated with a track so the selected preset can be auditioned.
    2.  Also needs: Buttons for creating, renaming, reordering, coloring, and deleting banks/tags.



   --]]

-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")()
local M = require("public.message")
local Table = require("public.table")
local T = Table.T

require 'moonUtils'

local Bank = {}
Bank.__index = Bank
local ALL = 'all'

local PATH = BANK_FOLDER

function Bank.new(name)
    local self = setmetatable({}, Bank)
    self.name = name
    return self
end

function Bank:__tostring()
    local propstr = ""
    local tab = '    '
    local paramstr, presetstr
    for prop,val in pairs(self) do
        if prop == 'name' then propstr = 'name = '..Esc(val)..', '..propstr --put the name first
        elseif prop == 'params' then paramstr = GetParamStr(val)
        elseif prop == 'presets' then presetstr = GetPresetStr(val)
        else propstr = propstr..prop..' = '..val..', '
        end
    end
    local rtnStr = tab..'{ '..propstr..'\n'..tab..tab..tab
    ..paramstr..'\n'
    ..presetstr..'\n'
    ..tab..tab..'}'
    return rtnStr
end

function Bank:addPreset(name)
        self.presets[name] = name
        --MSG('Added preset '..name..', presets = '..Table.stringify(self.presets))
end

function Bank:setParam(control,name)
    self.params[control] = name
end

function Bank:getParam(control)
    return self.params.name
end

function GetPresetStr(presets)
    --MSG('PRESETS UNSORTED = '..Table.stringify(presets))
    local retStr = '            presets = {'
    local sorted = TableSort(Table.invert(presets))
    --MSG('PRESETS SORTED = '..Table.stringify(sorted))
    if #sorted == 0 then return retStr..'}' end
    for index,val in pairs(sorted) do
        retStr = retStr..Esc(val)..', '
    end
    return CleanComma(retStr)..'}'
end
--used by both Banks and Plugs.  TODO: alphabetize
function GetParamStr(params)
    local paramT= {}
    local paramStr = 'params = {'
    for control,param in pairs(params) do
        table.insert(paramT,control..' = '..Esc(param))
    end
    paramStr = paramStr..table.concat(paramT,',')..'},'
    return paramStr
end

function Bank:getColor()
    return GetRGB(self.hue,self.sat, BRIGHTNESS)
end

function Bank:getPresets()
    return ArraySort(self.presets)
end

function Bank:presetsAsOptions()
    local options = {}
    --if #self:getPresets() == 0 then return options end
    for i, preset in ipairs(self:getPresets()) do
        options[i] = { name = preset, color = GetRGB(self.hue, self.sat, BRIGHTNESS) }
    end
    return options
end

---------------------------PLUGIN METHODS --------------------------
Plugin = {}
Plugin.__index = Plugin

function Plugin:__tostring()
    local bankT = {}
    local plugStr = 'return {\n    vstName = '..Esc(self.vstName)..', name = '..Esc(self.name)..', emptyPreset = '..Esc(self.emptyPreset)..','
    local preStr =  '\n    presets = {'..self:getPresetString()..'}, \n'
    local bankPre = '\n    banks = {\n    '
    --self:getSortedBanks()
    for i,bank in ipairs(self:getBanks()) do  --alphabetize banks when writing
        --MSG('Writing bank:'..bankName)
        table.insert(bankT,tostring(bank))
    end
    return plugStr..preStr..'    '..GetParamStr(self.params)..bankPre..table.concat(bankT,',\n    ')..'\n    }\n'..'}'
end

function Plugin:getPresetString()
    local retStr = ''
    --MSG('GETTING MASTER PRESET LIST: presets unsorted'..Table.stringify(self.presets))
    local sorted = TableSort(Table.invert(self.presets))
    --MST(sorted, 'SORTED INVERTED TABLE OF PRESETS')
    for i,val in ipairs(sorted) do
        retStr = retStr..Esc(val)..', '
    end
    --MSG('MASTER:Presets sorted = '..retStr)
    return CleanComma(retStr)
end
--returns a table of banks
function Plugin:getBanks() --sorts them also
    local banks = { }
    for i,name in ipairs(self:getBankList()) do
        table.insert(banks, self:getBank(name))
    end
    self.banks = banks
    return banks
end

function Plugin:getBankList()
    local nameTable = {}
    for i, bank in ipairs(self.banks) do
        table.insert(nameTable,bank.name)
    end
    --MST(nameTable,'nameTable')
    local sorted = TableSort(Table.invert(nameTable))
    return sorted
end

function Plugin.new(vstName, name, properties)
    local self = setmetatable({}, Plugin)
    --essential properties
    self.name = name
    self.vstName = vstName
    local defaults = {presets = {}, params = {}, banks = {}, emptyPreset = ''}
    for prop,val in pairs(defaults) do
        self[prop] = val  --add defaults
    end
    if properties then
        for prop,val in pairs(properties) do
            self[prop] = val  --add props from method call
        end
    end
    return self
end

function Plugin:getPresetList()
    local sorted = ArraySort(self.presets)
    --MSG('PLUGIN GETTING PRESETS = \n'..Table.stringify(sorted))
    return sorted
end

function Plugin:addBank(bankName,properties)
    --just quietly overwrite any existing bank?  for now...
    local bank = Bank.new(bankName)
    local defaults = {hue = 0, sat = 0, lokey = 1, hikey = 127,
                    params = {}, presets = {}
                }
    for prop,val in pairs(defaults) do
        bank[prop] = val  --add defaults
    end
    if properties then  --don't crash if we don't need to include any
        for prop,val in pairs(properties) do
            bank[prop] = val  --add props from method call
        end
    end
    table.insert(self.banks,bank)
    --MST(bank,'bank created')
end

function Plugin:containsPreset(presetName)
    for i,name in ipairs(self.presets) do
        if name == presetName then return true end
    end
    return false
end

function Plugin:addPresets(arrayOrString)
    if type(arrayOrString) == 'string' then arrayOrString = { arrayOrString } end
    for i,preset in ipairs(arrayOrString) do
        if not self:containsPreset() then table.insert(self.presets, preset) end
    end
end

function Plugin:bankContainsPreset(bankName,presetName)
    local bank = self:getBank(bankName)
    for i,name in ipairs(bank.presets) do
        if name == presetName then return true end
    end
    return false
end

function Plugin:getIndicesOfBanksContaining(presetName)
    local indices = {}
    for i,bank in ipairs(self.banks) do
        if self:bankContainsPreset(bank.name, presetName) then
            table.insert(indices, i)
        end
    end
    return indices
end

function Plugin:addPresetToBanks(presetName,banks)
    --MSG('adding preset '..presetName, 'to banks: '..MST(banks))
    for i, bank in pairs(banks) do
        self:getBank(bank.name):addPreset(presetName)
    end
end

function Plugin:setPresetsForBank(bankName,presets)
    --MSG('bank name = '..bankName)
    self:getBank(bankName).presets = {}
    --MSG('setting presets for bank:'..Table.stringify(presets))
    for i,option in pairs(presets) do
        self:getBank(bankName):addPreset(self.presets[i])
        --MSG('adding preset: '..self.presets[i])
    end
end

function Plugin:setBankPreset(bankName,presetName)
    if not self:getBank(bankName) then print('non-existent bank: '..bankName) return end
    --MSG('setting bank preset '..presetName)
    self:addPresets(presetName)
    self:getBank(bankName):addPreset(presetName)
end

function Plugin:getBank(bankName)
    MSG('bankname = ',bankName)
    for i, bank in ipairs(self.banks) do
        --MSG('Checking '..self.name..' for bank '..bank.name)
        if bank.name == bankName then return bank end
    end
    MSG('createMoonBank, bank not found: ',bankName)
    return nil
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

function Plugin.load(name)
    local filename = GetFileStartingWith(name)
    if not filename then return end
    --MSG('loading file: ',PATH..filename)
    local f = assert(loadfile(PATH..filename..'.lua'))
    local data = f()
    local self = setmetatable(data,Plugin)
    --MSG('initializing banks')
    for i,bank in ipairs(self.banks) do
        self.banks[i] = Bank.init(bank)
        --MSG('init bank'..Table.stringify(self.banks[i]))
    end
    return self
end
function Plugin:save()
    local filename = PATH..self.name..'.'..self.vstName..'.lua'
    local file = io.open(filename,'w')
    MSG('writing to file: '..filename)
    file:write(tostring(self))
    file:close()
end

--[[function Plugin.test(vstName,name)
    local plug = Plugin.new(vstName,name,{emptyPreset = 'not found'})
    plug:setParam('A1','Reverb')
    plug:setParam('A2','Chorus')
    plug:addBank('favorites',{hue = 120,sat  = 80,lokey = 30, hikey = 102})
    plug:addBank('pianos',{hue = 10,sat  = 60})
    plug:addBank('basses',{hue = 300,sat  = 80, hikey = 60, trim = 80})
    plug:setBankPreset('pianos','Grandeur')
    plug:setBankPreset('favorites','OB pad')
    plug:setBankPreset('favorites','Grandeur')
    plug:setBankPreset('pianos','Black')
    plug:setBankPreset('pianos','Death Piano')
    plug:setBankPreset('pianos','poor naming')
    plug:setBankPreset('basses','Really Rad Bass!')
    MSG('got here')
    local curBank = plug:getBank('favorites')
    curBank:setParam('A5','Wah')
    plug:getBank('pianos'):setParam('A1','Reverb')
    --plug:getPresetList()
    return plug
end

local plugName = 'Test'
local plug = Plugin.test('testVst (16 outs)',plugName)
plug:save()
local plug2 = Plugin.load(plugName)
print(plug2)
print(table.concat(plug:getPresetList(),', '))
plug2.name = 'Test2'
plug2:save()--]]

