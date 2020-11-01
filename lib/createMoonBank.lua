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
]]--

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'moonUtils'
--move the following to utils eventually.  or maybe have a nativeUtils that doesn't use reaper functions

function CleanComma(s)  return s:sub(1, string.len(s) -2) end

--dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local Bank = {}
Bank.__index = Bank

function Bank.new(name,hue,sat)
    local self = setmetatable({}, Bank) 
    self.name = name
    self.hue = hue or 0
    self.sat = sat or 0
    self.params = {}
    self.presets = {}
    return self
end

function Bank:__tostring()
    local rtnStr = '    '..self.name..' = { '..'name = '..Esc(self.name)..', hue = '..self.hue..', sat = '..self.sat..',\n            ' 
    ..GetParamStr(self.params)..'\n'
    ..'            presets = {\"'..table.concat (self.presets,'\", \"')..'\" }\n'
    ..'        }'
    return rtnStr
end

function Bank:addPreset(name)
    table.insert(self.presets,name)
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
    local presets = {}
    for preset in pairs(self.presets) do
        table.insert(presets,tostring(self.presets[preset]))
    end
    table.sort(presets)
    return presets
end
---------------------------PLUGIN METHODS --------------------------
local   Plugin = {}
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
    for _,name in pairs(self.presets) do
        retStr = retStr..Esc(name)..', '
    end
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
    return TableSort(self.presets)
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

function Plugin:addPresetToBank(bankName,preset)
    if not self.banks[bankName] then print('non-existent bank: '..bankName) return end
    self.banks[bankName]:addPreset(preset)
    self:addPreset(preset)
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
    local f = assert(loadfile('c:\\lua\\'..filename..'.lua'))
    local data = f()
    local self = setmetatable(data,Plugin)   
    for bankName,table in pairs(self.banks) do
        self.banks[bankName] = Bank.init(table)
    end
    return self
end
function Plugin:save()
    local filename = 'c:\\lua\\'..self.name..'.lua'
    local file = io.open(filename,'w')
    file:write(tostring(self))
    file:close() 
end

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
plug2:save()

