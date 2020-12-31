
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

local PATH = 'C:\\Users\\moon\\Documents\\_REAPER\\Scripts\\_RigInReaper\\Banks\\'  --for testing

function Bank.new(name)
    local self = setmetatable({}, Bank)
    self.name = name
    return self
end

function Bank:__tostring()
    local propstr = ""
    local paramstr, presetstr
    for prop,val in pairs(self) do
        if prop == 'name' then propstr = 'name = '..Esc(val)..', '..propstr --put the name first
        elseif prop == 'params' then paramstr = GetParamStr(val)
        elseif prop == 'presets' then presetstr = GetPresetStr(val)
        else propstr = propstr..prop..' = '..val..', '
        end
    end
    local rtnStr = '    '..self.name..' = { '..propstr..'\n            '
    ..paramstr..'\n'
    ..presetstr..'\n'
    ..'        }'
    return rtnStr
end

function Bank:addPreset(name)
        self.presets[name] = name
        --M.Msg('Added preset '..name..', presets = '..Table.stringify(self.presets))
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
    --M.Msg('PRESETS UNSORTED = '..Table.stringify(presets))
    local retStr = '            presets = {'
    local sorted = TableSort(Table.invert(presets))
    --M.Msg('PRESETS SORTED = '..Table.stringify(sorted))
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
    local plugStr = 'return {\n    vstName = '..Esc(self.vstName)..', name = '..Esc(self.name)..', emptyPreset = '..Esc(self.emptyPreset)..','
    local preStr =  '\n    presets = {'..self:getPresetString()..'}, \n'
    local bankPre = '\n    banks = {\n    '
    for bankName in pairs(self.banks) do
        table.insert(bankT,tostring(self.banks[bankName]))
    end
    return plugStr..preStr..'    '..GetParamStr(self.params)..bankPre..table.concat(bankT,',\n    ')..'\n    }\n'..'}'
end

function Plugin:getPresetString()
    local retStr = ''
    --M.Msg('GETTING MASTER PRESET LIST: presets unsorted'..Table.stringify(self.presets))
    local sorted = TableSort(Table.invert(self.presets))
    for i,val in ipairs(sorted) do
        retStr = retStr..Esc(val)..', '
    end
    --M.Msg('MASTER:Presets sorted = '..retStr)
    return CleanComma(retStr)
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
    --M.Msg('PLUGIN GETTING PRESETS = \n'..Table.stringify(sorted))
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
    self.banks[bankName] = bank
    --TStr(bank,'bank created')
end

function Plugin:addPreset(preset)
    if not self.presets[preset] then
        self.presets[preset] = preset
    end
end

function Plugin:bankContainsPreset(bankName,presetName)
    local bank = self.banks[bankName]
    for i,name in pairs(bank.presets) do
        if name == presetName then return true end
    end
    return false
end


function Plugin:getBanksContaining(presetName)
    local list = self.getBankList()
    TStr(list,'Banks with '..presetName)
end

function Plugin:addPresetToBanks(presetName,banks)
    --M.Msg('adding preset '..presetName, 'to banks: '..TStr(banks))
    for i,option in pairs(banks) do
        self.banks[option.name]:addPreset(presetName)
    end
end

function Plugin:setPresetsForBank(bankName,presets)
    --M.Msg('bank name = '..bankName)
    self.banks[bankName].presets = {}
    --M.Msg('setting presets for bank:'..Table.stringify(presets))
    for i,option in pairs(presets) do
        self.banks[bankName]:addPreset(self.presets[i])
        --M.Msg('adding preset: '..self.presets[i])
    end
end

function Plugin:setBankPreset(bankName,presetName)
    if not self.banks[bankName] then print('non-existent bank: '..bankName) return end
    --M.Msg('setting bank preset '..presetName)
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

function Plugin.load(name)
    local filename = GetFileStartingWith(name)
    if not filename then return end
    M.Msg('loading file: ',PATH..filename)
    local f = assert(loadfile(PATH..filename..'.lua'))
    local data = f()
    local self = setmetatable(data,Plugin)
    --M.Msg('initializing banks')
    for bankName,table in pairs(self.banks) do
        self.banks[bankName] = Bank.init(table)
        --M.Msg('init bank'..Table.stringify(self.banks[bankName]))
    end
    return self
end
function Plugin:save()
    local filename = PATH..self.name..'.'..self.vstName..'.lua'
    local file = io.open(filename,'w')
    M.Msg('writing to file: '..filename)
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

