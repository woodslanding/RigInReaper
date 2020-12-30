--[[
    All channels and Data
    Tempo
]]



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


local ChannelData = {}
ChannelData.__index = ChannelData

function ChannelData:__tostring()

    --[[local bankT = {}
    local plugStr = 'return {\n    vstName = '..Esc(self.vstName)..', name = '..Esc(self.name)..', emptyPreset = '..Esc(self.emptyPreset)..','
    local preStr =  '\n    presets = {'..self:getPresetString()..'}, \n'
    local bankPre = '\n    banks = {\n    '
    for bankName in pairs(self.banks) do
        table.insert(bankT,tostring(self.banks[bankName]))
    end
    return plugStr..preStr..'    '..GetParamStr(self.params)..bankPre..table.concat(bankT,',\n    ')..'\n    }\n'..'}'--]]
end



function ChannelData.new(properties)
    local self = setmetatable({}, ChannelData)
    local defaults = {
        vstName = '', bankName = '', preset = '', presetPage = 1,
        volume = .85, pan = 0, fxLevel = .35, fxNum = nil,
        hands = false, hold = false, octave = 0, semi = 0,
        notesource = 1, enable = true, nsSolo = false,
        expOn = false, ped2On = false, bcOn = false, noSus = false,
        encOn = false, sw1On = false, sw2On = false, drbOn = false,
        cueOn = false,
        mappedVals = {}
    }

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