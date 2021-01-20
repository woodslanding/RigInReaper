------------------------------MSLIDER--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'moonUtils'
require 'MLabel'
require 'MSlider'
require 'MButton'
require 'MButtonPanel'
require 'createMoonBank'
require 'MText'

loadfile(libPath .. "scythe.lua")({printErrors = true})
local GUI = require("gui.core")
local M = require("public.message")
local Sprite = require("public.sprite")
local Image = require("public.image")
local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Table = require("public.table")
local T = Table.T
local Element = require("gui.element")

local layers = {}

local channelCount = 3

local iCh = 1
local leftX = -12

local indZ = 4
local titleZ = 4
local ctlLayerZ = 8
local panelZ = 12
local faderZ = 12

local scaling = .8

local imageFolder = IMAGE_FOLDER  --from MoonUtilities
local presetFolder = PRESET_FOLDER
local indent = '    '
-- panel states
local PanelDisplay = 1
    local GLOBAL = 1
    local VST = 2
    local PRESET = 3
local PanelDisplay
-----------------------------------------------------------------------------------------------------
------------------------------------------- PANEL FUNCTIONS -----------------------------------------
-----------------------------------------------------------------------------------------------------
--[[
    When we start the script, we need to have a viable wkp open.  This means all 16 channels with compliant
    fx chains, and all the midi and audio tracks to support them.

    Then when we start up, we needn't load up a default global preset: it is loaded already, and we just need
    to get the ui to reflect it.

    We should probably start up on the preset page for ch 1, but that is easy to change.

    Every control in the ui needs a method to query reaper for its associated value, and get accordingly.
    On startup we will run through all the ui elements and call this method.  Can use a lot of code from loading
    and saving global presets.

    Then we need to fill all the preset and bank tables for the channels.  Also fill the VST table.

    Commands:
    The panels will get functions updated as part of options loaded as their function changes.
    So there is no need for if-> then statements to check what the preset and bank tables are displaying.


    open in global mode
    1.GLOBAL MODE:      Right panel shows global banks,
                        Left panel shows global presets for current bank:  setMode(GLOBAL)

    2.VST MODE:     Left panel shows banks for selected vst, Right panels shows master VST list
    3.CHANNEL MODE: Left panel shows presets for current channel, Right panel shows banks for current VST

]]
-- channel data
local vsts = nil  --list of all mapped VSTs
local plugs = nil  --list of selected VSTs by channel
local gBanks = nil  --list of all global banks
local gBank = nil  --current global bank name
local gBankPage = 1  --current global bank page
local gPresets = nil
local gPreset = nil
local presets = {}  --table of tables of presets by channel
local presetPages = {} --table of preset pages
local banks = {}  -- list of banks for selected vst by channel
local bankPages = {} --list of bank pages

---------------------------------------------------------------------------------------------
--[[
    what can't be recalled?
    Bank name
    Drawbars -- we'll just be enabling that midi send, so that workings
    Footswitches -- if we put the hardwired ones on a different channel, we can mute by channel and check that way
    Cue--we can query mute states of outputs maybe
    MuteFX-- todo: check
    We can get tempo, but not any metric mods that led to it.  That's okay... we can load from preset...
    Can get track color... can we tease out Hue and Sat??  Maybe don't need to.

]]

local function sync()
    --query all ui elements for the reaper value they address
    for i = 1,channelCount do
        for name,element in pairs(gui.ch[i]) do
            MSG('updating control: ', element.name)
            --MSG('element.sync = ', element.sync)
            if element.sync then element:sync() end

        end
    end
    --vsts = GetBankFileTable()
    --plugs =

end

local function setPanelsGLOBAL()
    if not gBanks then gBanks = OptionsFromPath(PRESET_FOLDER) end
    gui.banks:setOptions(gBanks)
    if not gBank then gBank = gBanks:getOption(1) end
    if not gPresets then
        local folder = PRESET_FOLDER..gBank..'/'
        gPresets = OptionsFromPath(folder)
    end
    gui.presets:setOptions(gPresets)
    if not gPreset then gPreset = gui.presets:getOption(1)
                        gui.presets:setPage(1)
    else gui.presets:select(gPreset.index)
        gui.presets:pageToSelection()
    end
end

local function setPanelsVST()
    if not vsts then vsts = GetBankFileTable() end
    gui.banks:setOptions(vsts)
    gui.banks:selectByName(ch().vst:val())
    gui.presets:setOptions()

end
--we must always have valid plugs in all channels right from startup
--also valid banks.  we can fill in presets from there
local function setPanelsPRESETS()
    local ch = ch()
    if not presets[ch] then presets[ch] = plugs[ch].getBank(banks[ch]):getPresets() end
    gui.presets:setOptions()
end
--not needed?
local function getPlugList()
    if not plugs then
        for i = 1,channelCount do
            plugs[i] = gui.ch.vst:val()
        end
        TStr(plugs, 'plugins by chan')
    end
    return plugs
end

local function loadPresets()
    if PanelDisplay == GLOBAL then
        local folder = PRESET_FOLDER..gBank..'/'
        MSG('folder = '..folder)
        gui.presets:setOptions(OptionsFromPath(folder))
        gui.presets:setPage(1)
    elseif PanelDisplay == VST then
    elseif PanelDisplay == PRESET then
    end
end

local function selectBank(bankName)
    if PanelDisplay == GLOBAL then
        gBank = bankName
    elseif PanelDisplay == VST then
    elseif PanelDisplay == PRESET then
    end
    loadPresets()
end
-- use cases: 1--get bank display when channel changes
--            2--change to bank display from global or vst display
function ShowPresets(vst, chan)
    PanelDisplay = PRESET
    local i
    if chan then i = chan else i = ch() end
    if not vst then vst = vsts[i] end  --we should fill this table before loading any banks, I think
    if not plugs[i] or plugs[i].vstName ~= vst then plugs[i] = Plugin.load(vst) end  --don't want to re-read every time we switch channels
    local banks = plugs[i]:getBankList()
    gui.banks:setColor('gray', true)
    for i,bankName in ipairs(banks) do
        local bank = plugs[i]:getBank(bankName)
        gui.banks:setOption(i, {index = i, name = bankName, bank = bank, color = GetRGB(bank.hue,bank.sat,BRIGHTNESS)})
    end
    if not gBank then gBank = GetFileList(PRESET_FOLDER)[1] end
    gui.banks:setPage(bankPages[i] or 1)
    Presets = Plug:getPresetList()
    for i,preset in ipairs(Presets) do Presets[i] = { name = preset } end
    gui.presets:setOptions(Presets)
    gui.presets:setPage(presetPages[i] or 1)
end

function ShowVsts()
    PanelDisplay = VST
    local i = 1
    local plugName = GetFXName(CurrentTrack,INSTRUMENT_SLOT)
    MSG('Plug Name = '..plugName)
    for name,vst in pairs(GetBankFileTable()) do
        MSG('setting option '..name..' to '..vst)
        gui.banks:setOption(i,{ name = name, vst = vst })
        local vstFile = vst..'.dll'
        if vstFile == plugName then gui.banks:select(i) end
        i = i + 1
    end
end

function ShowGlobalPanel()
    PanelDisplay = GLOBAL
    if not gBanks then gBanks = OptionsFromPath(PRESET_FOLDER, true) end
    gui.banks:setOptions(gBanks)
    if not gBank then gBank = gui.banks:getOption(1).name end
    selectBank(gBank)
end

function ProcessPreset(name)
    if PanelDisplay == PresetPanel then
        ch().presetName:val(name)
        SelectPreset(ch(), name)
    elseif PanelDisplay == GLOBAL then
        GlobalRecall(name)
    elseif PanelDisplay == VST then
    end
end


--------------------------------------------------------------------------------------------------
---------------------------------     GENERAL FUNCTIONS  -----------------------------------------
--------------------------------------------------------------------------------------------------

function GlobalSave(gPresetName)
    local saveData = 'return '..'{ \n'
    for name,elm in pairs(gui) do
        --MSG('saving element: '..name)
        if elm.save then
            --MSG('saving ctl: '..name)
            saveData = saveData..indent..name..' = '..Esc(elm:val())..',\n'
        end
    end
    saveData = saveData..indent..'channels = {\n'
    --TStr(gui.ch,'Channels')
    for num,chan in ipairs(gui.ch) do --color is not a table, but we can get it from the bank...
        saveData = saveData..indent..indent..'{ '
        for name, elm in pairs(chan) do
            if type(elm) == 'table' and elm.save ~= false then
                MSG('saving control: '..name)
                saveData = saveData..name..' = '..Esc(elm:val())..', '
            end
        end
        saveData = saveData..'},\n'
    end
    saveData = saveData..indent..'},'..'\n}'
    local folder = PRESET_FOLDER..'/'..gui.globalBank.name
    if not CreateFolder(folder) then MSG("Couldn't create folder: "..folder) end
    local file = io.open(folder..'/'..gPresetName..'.lua','w')
    MSG('writing to file: '..gPresetName)
    file:write(saveData)
    file:close()
end

function GlobalSaveAs()
    Keyboard:visible(true)
    Keyboard.func = function(self)
        MSG('Saving preset as '..Keyboard.text)
        GlobalSave(Keyboard.text)
        Keyboard:visible(false)
    end
end

function GlobalRecall(presetName)
    --need to load all the button settings.
    --then load the vst if needed
    --then fill the presets of any changed
    local path = PRESET_FOLDER..gui.globalBank.name..'/'..presetName..'.lua'
    MSG('loading file: '..path)
    local data = assert(loadfile(path))()
    --TStr(data,'data')
    for name,gval in pairs(data) do
        if name == 'channels' then
            for i,chan in ipairs(gval) do
                MSG('Channel: '..i)
                for name, val in pairs(chan) do
                    --check for obselete fields....
                    local field = gui.ch[i][name]
                    if field then
                        MSG('setting field: '..name..', value = '..val)
                        gui.ch[i][name]:val(val) end
                end
            end
        else
            gui[name]:val(gval)
        end
    end
    for i,channel in ipairs(gui.ch) do
        local vst = channel.vst:val()
        plugs[i] = Plugin.load(vst)
        TStr(plugs[i],'plugin')
        MSG("loading vst: "..plugs[i].vstName)
        --LoadInstrument(i, vstName)
        MSG('getting bank: '..channel.bank:val())
        banks[i] = plugs[i]:getBank(channel.bank:val())
        presets[i] = banks[i]:getPresets()
        MSG('setting preset to: '..channel.preset:val())
        SelectPreset(i, channel.preset:val())
    end

end



--------------------------------------------------------------------------------------------------
--{{{{{{{{{{{{{{{{{{{{{{{{{{{{{          LAYOUT CONSTANTS            }}}}}}}}}}}}}}}}}}}}}}}}}}}}}
--------------------------------------------------------------------------------------------------
local leftPad = 4
local pad = 8

local comboH = 36
local btnH = 36
local meterH = 12
local chanW = 96

local spinnerW = 44
local spinnerH = 72
local btnW = 96
local faderW = 52
local chBtnW = 44
local semiPad = 42
local totalW = 1536
local totalH = 900
local panH = 12

local presetCols = 8
local presetRows = 5
local paramCols = 8
local paramRows = 4
local bankCols = 3
local inspectorRows = 3
local inspBtnW = btnW * .75
local inspectorW = inspBtnW * inspectorRows
local chanBtnRows = 7

local indH, indW, indX = 17, 17, 32

--x positions
local semiX = leftPad + semiPad
local chanBtnX = leftPad + faderW
local inspectorX = chanBtnX + btnW + pad
local paramsX = inspectorX + inspectorW + pad
local bankX = leftPad + (presetCols * btnW) + spinnerW + pad
local transportX = bankX + (bankCols * btnW) + pad
local organX = paramsX + (paramCols * btnW) + pad
local masterVolX = totalW - faderW
--y positions
local presetY = btnH + pad
local paramsY = presetY + (btnH * presetRows) + pad
local fxSendY = paramsY + btnH + (btnH * paramRows) + pad
local octY = fxSendY + spinnerH
local chanY = octY + spinnerH + meterH
local nsY = chanY + (chanBtnRows * btnH) - btnH + pad
------------------------------------------------------------------------------------------------------
--{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ GUI METHODS }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}--
------------------------------------------------------------------------------------------------------

local window = GUI.createWindow({
    name = "RIG", w = totalW, h = totalH, x = leftX, y = 0
})

Keyboard = MText.new({ x = 100, y = 100, window = window, z = 2 })
    Keyboard:visible(false)

local function getColor(hue, sat)
    local saturation = sat or 60
    return GetRGB(hue, saturation)
end

local function getLayer(z)
    if layers[z] then return layers[z]
    else layers[z] = GUI.createLayer({name = 'layer'..z, z = z})
    end
    return layers[z]
end

local function setBackdrop()
    local bkdp = GUI.createElement({
        type = "Frame",
        name = 'backdrop',
        x = 0, y = 0, h = 1080, w = 1920,
        bg = GetRGB(159,30,20),
        color = 'black',
    })
    getLayer(99):addElements(bkdp)
    return bkdp
end

local function createMenu(props)
    local z = ctlLayerZ
    local items = {}

    for i,option in ipairs(props.options) do
        --TStr(option,'MENU OPTION')
        local x, y = GetLayoutXandY(i, props.x, props.y, btnW, btnH, 1)
        local item = GUI.createElement({
            name = option.name,
            caption = option.name,
            type = 'MButton',
            wrap = true,
            momentary = option.momentary or false,
            w = btnW, h = btnH, x = x, y = y, z = z,
            frames = 2, min = 0, max = 1,
            image = imageFolder.."Combo.png",
            func = option.func,
        })
        getLayer(z):addElements(item)
        items[i] = item
    end
    return items
end

local function createTitle(props,ch)
    if not ch then ch = '' end
    local fontSize = props.fontSize or 32
    local font = {'Calibri', fontSize,"b"}
    local title = GUI.createElement ({
        type = "MButton",
        name = props.name..'_'..ch,
        momentary = props.momentary or true,
        multi = props.multi or false,
        caption = props.caption or props.name,
        textColor = props.textColor or 'black',
        color = props.color or nil,
        font = font,
        w = props.w, h = props.h or comboH,
        x = props.x, y = props.y,
        func = props.func,
        save = props.save,
        ch = ch,
        sync = props.sync or nil
    })
    --for title buttons, the data is the text
    function title:val(new)
        if new then self:setCaption(new)
        else return self.caption end
    end
    getLayer(titleZ):addElements(title)
    return title
end

local function createLabel(props, ch)
    if not ch then ch = '' end
    local fontSize = props.fontSize or 22
    local font = {'Calibri', fontSize,"b"}
    local label = GUI.createElement ({
        type = "MLabel",
        vertical = props.vertical or true,
        caption = props.caption or 'LABEL TEST '..ch,
        name = props.name..'_'..ch,
        font = font,
        textColor = props.textColor or 'text',
        w = props.w, h = props.h,
        x = props.x, y = props.y,
        ch = ch,
        save = props.save,
        sync = props.sync or nil
    })

    getLayer(titleZ):addElements(label)
    return label
end

local function createPanel(props, pager, options)
    --MSG('pager = ',pager)
    local usePager, px, py, pw, ph, pImage
    if pager then px = pager.x
        py = pager.y
        pw = pager.w or spinnerW
        ph = pager.h or spinnerH
        pImage = pager.image or 'Spinner.png'
        usePager = true
    end
    if pImage then pImage = imageFolder..pImage end
    local panel = MButtonPanel.new({
        name = props.name,
        horizontal = false,
        multi = props.multi or false,
        image = imageFolder.."Combo.png",
        rows = props.rows, cols = props.cols,
        x = props.x, y = props.y, w = btnW, h = comboH, z = panelZ,
        usePager = usePager or false,
        pagerImage = pImage,
        pagerX = px, pagerY = py, pagerW = pw, pagerH = ph,
        window = window, z = panelZ,
        func = props.func,
        options = {},
        save = props.save,
        sync = props.sync or nil
    })
    --MSG('pager'..panel.pager)
    if pager and panel.pager and pager.horizontal then
        panel.pager.horizontal = pager.horizontal
    end
    if options then
        panel:setOptions(options)
        --TStr(options,'options')
        panel:setPage(1)
    end
    return panel
end

local function createFader(props, ch)
    if not ch then ch = '' end
    local icon
    if props.icon then icon = props.icon else icon = props.name end
    --MSG('create fader'..props.name)
    local z = props.z or faderZ
    local fader = GUI.createElement({
        frames = props.frames,
        horizontal = props.horizontal or false,
        name = props.name..'_'..ch,
        type = "MSlider",
        min = props.min or 0, max = props.max or 1, value = 0,
        x = props.x ,y = props.y, w = props.w or faderW, h = props.h,
        image = imageFolder..icon..".png",
        func = props.func,
        ch = ch,
        save = props.save,
        sync = props.sync or nil
    })
    getLayer(z):addElements(fader)
    return fader
end

local function createButton(props, ch)
    if not ch then ch = '' end
    local fontSize = props.fontSize or 22
    local font = {'Calibri', fontSize,"b"}
    local caption = props.caption or ''
    local icon = props.icon or props.name
    local z = props.z or ctlLayerZ
    local button = GUI.createElement({
        name = props.name..'_'..ch,
        displayOnly = props.displayOnly or false,
        momentary = props.momentary or false,
        type = 'MButton', wrap = props.wrap or true,
        caption = caption,
        font = font,
        textColor = props.textColor or 'white',
        color = props.color or nil,
        frames = props.frames or 2,
        min = props.min or 0, max = props.max or 1,
        x = props.x ,y = props.y, w = props.w or faderW,h = props.h,
        image = imageFolder..icon..".png",
        func = props.func,
        ch = ch,
        save = props.save,
        sync = props.sync or nil
    })
    --MSG('Created Element: '..button.name)
    getLayer(z):addElements(button)
    return button
end

local function createSpinner(props, ch)
    if not ch then ch = '' end
    local z = props.z or ctlLayerZ
    local icon
    if props.icon then icon = props.icon else icon = 'Spinner' end
    local spinner = GUI.createElement({
        name = props.name..'_'..ch,
        type = "MButton",
        momentary = true,
        spinner = true, wrap = false,
        labelY = -.02,
        w = props.w or spinnerW, h = props.h or spinnerH,
        x = props.x, y = props.y,
        frames = 1,
        min = -1,max = 1,inc = 1, --for now need all these for stateless spinner...
        image = imageFolder..icon..'.png',
        func = props.func,
        ch = ch,
        save = false
    })
    getLayer(z):addElements(spinner)
    return spinner
end

--------------------------------------------------------------------------------------------------------------------
--****************************************************************************************************************--
--------------------------------------------------------------------------------------------------------------------
--------{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ GUI PROPERTIES }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}-------
--------------------------------------------------------------------------------------------------------------------

gui = {
    leftMenu = {  x = leftPad, y = 0, options = {
            { name = 'Presets', momentary = true, func = function() end },
            { name = 'Banks', momentary = true, func = function() end},
            { name = 'VSTs', momentary = true, func = function() end},
            { name = 'Scroll Left', momentary = true, func = function(self) leftPad = -300
                                            ResizeWindow(window, leftX, 0, 1000, SCREEN_HEIGHT) window:redraw() end },
            { name = 'Quit', momentary = true, func = function(self) CloseWindow(window) end },
            { name = 'FullScreen', momentary = false, func = function(self) Fullscreen(window, self:val() == 0) end },
        },
    },
    globalBank = { name = 'globalBank', save = true, multi = false,  fontSize = 18, x = bankX - (btnW * 4), y = 0, w = 4 * btnW, func = function(self) end}, -- show global banks in preset panel, and vsts in bank panel
    globalPreset = { name = 'globalPreset', save = true, x = bankX - btnW, y = 0, w = 4 * btnW, color = 'gray', func = function(self) end}, --show global presets in preset panel
    rightMenu = { x = transportX, y = 0, options =  {
            { name = 'Edit Banks',momentary = true, func = function(self) OpenBankEditor() end},
            { name = 'GlobalSave Preset', momentary = true, func = function(self) GlobalSave(gui.globalPreset.caption) end},
            { name = 'GlobalSave As', momentary = true, func = function(self) GlobalSaveAs()  end }
        }
    },
    masterVol = {   name = 'masterVol', save = true, icon = 'fxLevel', color = 'blue', x = masterVolX, y = 0, h = paramsY,  frames = 72,
                        func = function(self) MSG('volume = '..self:val()) end},
    masterLabel =  { name = 'masterLabel', caption = 'MASTER', x = masterVolX + pad, y = 0, w = 120, h = 24 },
    ------------------------------------------------------------------------------------------------
    --{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ ROW 1 }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}--
    ------------------------------------------------------------------------------------------------
    presets =   {   name = 'presetPanel', x = leftPad, y = presetY, rows = presetRows, cols = presetCols, chColor = true,
                func = function() local name = gui.presets:getSelectionData() MSG('name = '..name) ProcessPreset(name) end},
    presetPager = {  x = bankX - spinnerW - pad, y = presetY, w = spinnerW, h = spinnerH, chColor = true},
    banks =     {   name = 'bankPanel', x = bankX, y = presetY, rows = presetRows, cols = bankCols, func = function(self) end },
    bankPager = {  x = bankX - spinnerW, y = paramsY - spinnerH - pad, w = spinnerW, h = spinnerH},
    transport = {   name = 'transport', x = transportX, y = presetY, func = function(self) end},
    ------------------------------------------------------------------------------------------------
    --{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ ROW 2 }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}--
    ------------------------------------------------------------------------------------------------
    fxLevel =  {   name = 'fxLevel', x = leftPad, y = paramsY ,frames = 72, max = 99, h = 5 * btnH, func = function(self) end},
    fxLabel =  {   name = 'fxLabel', x = leftPad + pad, y = paramsY + 55, fontSize = 24, h = 5 * btnH},
    panFader =  {   name = 'Ipan', x = inspectorX, y = paramsY, frames = 97, min = -1, max = 1, horizontal = true, chColor = true,
                    w = 2 * inspBtnW, h = btnH, func =  function(self) ch().pan:val(self:val()) end },
    trackTitle = {  name = 'trackTitle', x = paramsX, y = paramsY, w = btnW * 3, func = function(self) end },  --show vst
    paramTabs = { name = 'paramTabs',x = paramsX + (5 * btnW), y = paramsY, rows = 1, cols = 2, color = GetRGB(0,0,75), options = {
            { name = 'Params', func = function(self) gui.params.layer:show() gui.mappings.layer:hide()  end },
            { name = 'Mappings', func = function(self) gui.params.layer:hide() gui.mappings.layer:show() end },
        },
    },
    fxSelect =  {   name = 'fxSelect', x = chanBtnX, y = paramsY + btnH, rows = paramRows, cols = 1, func = function(self) end },
    fxSelectPager = { x = faderW + leftPad, y = paramsY, w = btnW, h = btnH, image = "HorizSpin.png" , horizontal = true},
    inspector = {   x = inspectorX, y = paramsY + btnH, w = inspBtnW, h = btnH, chColor = true, options = {
            { name = 'Cue', func = function(self)    ch().Cue:val(self:val()) end },
            { name = 'Solo', func = function(self)   ch().Solo:val(self:val())  end },
            { name = 'MuteFx', func = function(self) ch().MuteFx:val(self:val())  end },
            { name = 'NsSolo', func = function(self) ch().NsSolo:val(self:val())  end },
            { name = 'Hands', func = function(self)  ch().Hands:val(self:val()) end },
            { name = 'Sharp', momentary = true, func = function(self)   ch().semi:increment(1,false) end },
            { name = 'Natural', momentary = true, func = function(self) ch().semi:val(0); ch().oct:val(0); ch().octaveSpin:setCaption('') end },
            { name = 'Flat', momentary = true, func = function(self)    ch().semi:increment(-1,false) end },
            { name = 'Encoders', func = function(self)  ch().Encoders:val(self:val()) end },
            { name = 'Switches1', func = function(self) ch().Switches1:val(self:val()) end },
            { name = 'Switches2', func = function(self) ch().Switches2:val(self:val())  end },
            { name = 'Drawbars', func = function(self)  ch().Drawbars:val(self:val())  end },
        },
    },
    params =    {   name = 'params', x = paramsX, y = paramsY + btnH, rows = paramRows, cols = paramCols, chColor = true, func = function(self) end },
    mappings =  {  name = 'mappings', x = paramsX, y = paramsY + btnH, rows = paramRows, cols = paramCols, options = {
         --this is basically just a cheat sheet, right? Eventually they might be active, and display/edit values...
            {name = 'Select Track', color = getColor(HUES.VIOLET), func = function(self) end},
            {name = 'Enable Track', color = getColor(HUES.VIOLET),func = function(self) end},
            {name = 'Cue Track', color = getColor(HUES.VIOLET), func = function(self) end},
            {name = 'Show VST', color = getColor(HUES.VIOLET), func = function(self) end},
            {name = 'Volume', color = getColor(HUES.AQUA), func = function(self) end},
            {name = 'Expression', color = getColor(HUES.AQUA), func = function(self) end},
            {name = 'Ped2', color = getColor(HUES.AQUA), func = function(self) end},
            {name = 'BC', color = getColor(HUES.AQUA), func = function(self) end},

            {name = 'Notesource', color = getColor(HUES.FUSCHIA), func = function(self) end},
            {name = 'Encoders', color = getColor(HUES.LEMON), func = function(self) end},
            {name = 'Switches1', color = getColor(HUES.PUMPKIN), func = function(self) end},
            {name = 'Switches2', color = getColor(HUES.YELLOW), func = function(self) end},
            {name = 'Pan', color = getColor(HUES.BLUE), func = function(self) end},
            {name = 'Center', color = getColor(HUES.BLUE), func = function(self) end},
            {name = 'NS Solo', color = getColor(HUES.YELLOW), func = function(self) end},
            {name = 'Ignore Sus', color = getColor(HUES.PUMPKIN), func = function(self) end},

            {name = 'Octave', color = getColor(HUES.TEAL), func = function(self) end},
            {name = 'Reset', color = getColor(HUES.TEAL), func = function(self) end},
            {name = 'Semi +', color = getColor(HUES.AQUA), func = function(self) end},
            {name = 'Semi -', color = getColor(HUES.AQUA), func = function(self) end},
            {name = 'Inst Scroll', color = getColor(HUES.GREEN), func = function(self) end},
            {name = 'Inst Select', color = getColor(HUES.GREEN), func = function(self) end},
            {name = 'Hands', color = getColor(HUES.PURPLE), func = function(self) end},
            {name = 'Hold', color = getColor(HUES.VIOLET), func = function(self) end},

            {name = 'Preset Scroll', color = getColor(HUES.GRASS), func = function(self) end},
            {name = 'Preset Select', color = getColor(HUES.GRASS), func = function(self) end},
            {name = 'Bank +', color = getColor(HUES.GRASS), func = function(self) end},
            {name = 'Bank -', color = getColor(HUES.GRASS), func = function(self) end},
            {name = 'FX Volume', color = getColor(HUES.RUST), func = function(self) end},
            {name = 'FX Mute', color = getColor(HUES.RUST), func = function(self) end},
            {name = 'FX Chan +', color = getColor(HUES.RUST), func = function(self) end},
            {name = 'FX Chan -', color = getColor(HUES.RUST), func = function(self) end},
        },
    },
    organPanel = {  name = 'organ',x = organX, y = paramsY, func = function(self) end },
    monitorVol = {  name = 'monitor',save = true, icon = 'fxLevel', color = 'yellow', x = masterVolX, y = paramsY, h = paramsY, frames = 72, func = function(self) end },
    monitorLabel =  { name = 'monitorLabel', caption = 'MONITOR', x = masterVolX + pad, y = paramsY, w = 120, h = 24 },
    ------------------------------------------------------------------------------------------------
    --{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ CHANNELS }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}--
    ------------------------------------------------------------------------------------------------

    --TODO: volume scaling check... How to retrieve BANK on startup?  Maybe just do a 'set' on bank by the bank text....
    --In most cases, display and proj should agree about values, but if not, then the project wins.

    -- this data is stored unless save = false
    send =     { name = 'Send', x = leftPad, y = fxSendY, h = 4 * btnH, frames = 72, func = function(self) end, sync = function() end},
    sendLabel =  { name = 'sendLabel', x = leftPad + pad, y = fxSendY, w = 120, h = 20, sync = function(self) SetFxChanByName(self:val(), self.ch) end }, --fx selected by spinner, but stored here
    semi =     { name = 'Semi', x = semiX, y = fxSendY, displayOnly = true, wrap = false, z = 4,
                                    w = 16, h = spinnerH, frames = 15, min = -7, max = 7, sync = function(self) self:val(GetMoonParam(self.ch, MCS.SEMI))  end }, -- stores semi data
    oct  =     { name = 'Oct', x = semiX, y = octY, displayOnly = true, wrap = false, z = 4,
                                    w = 16, h = spinnerH, frames = 11, min = -5, max = 5,
                                    sync = function(self) self:val(GetMoonParam(self.ch, MCS.OCTAVE)) end }, --stores oct data
    fxSpin =   { name = 'fxSpin', save = false, x = leftPad + faderW, y = fxSendY, func = function(self) end },
    octaveSpin =  { name = 'octaveSpin', save = false, x = leftPad + faderW, y = octY, chColor = true, func = function(self)
                                                                            local chan = ch(self.ch)
                                                                            chan.oct:increment(self:val())
                                                                            SetMoonParam(self.ch, MCS.OCTAVE, chan.oct:val())
                                                                            if chan.oct:val() ~= 0 then
                                                                                self.caption = math.floor(chan.oct:val())
                                                                            else self.caption = '' end end},
    pan =    { name = 'pan', x = leftPad, y = chanY - meterH, h = panH, w = chanW, horizontal = true, z = 4,
                                    displayOnly = true, frames = 25, min = -1, max = 1,  sync = function(self) self:val(Pan(self.ch)) end  },
    meterL = { name = 'meterL', save = false, x = leftPad, y = chanY - meterH, h = panH/2, w = chanW, horizontal = true,
                                    displayOnly = true,frames = 25, chColor = true },
    meterR = { name = 'meterR', save = false, x = leftPad, y = chanY - (meterH/2), h = panH/2, w = chanW, horizontal = true,
                                    displayOnly = true, frames = 25, chColor = true },

    preset =   { name = 'presetName', x = leftPad + 2, y = chanY + 88, fontSize = 28,  sync = function(self) self:val(GetFxPresetName(self.ch)) end  },
    volume =    { name = 'volume', x = leftPad, y = chanY, h = btnH * 6, w = faderW, frames = 108,  chColor = true, func = function(self) end ,  sync = function(self) self:val(Volume(self.ch)) end },

    lights =  { x = leftPad + indX, y = chanY + pad, w = indW, h = indH, displayOnly = true, z = indZ, options = {
            { name = 'Cue', sync = function(self) end },
            { name = 'Solo', sync = function(self) end },
            { name = 'MuteFx', sync = function(self) end },
            { name = 'NsSolo', sync = function(self) end },
            { name = 'Hands', sync = function(self) GetMoonParam(self.ch, MCS.HANDS) end },
            { name = 'Encoders', sync = function(self) end },
            { name = 'Switches1', sync = function(self) end },
            { name = 'Switches2', sync = function(self) end },
            { name = 'Drawbars', sync = function(self) end },
        },
    },
    --can these be updated from reaper??
    buttons = { x = chanBtnX, y = chanY, w = chBtnW, h = btnH, chColor = true, options =  {
            { name = 'NoSus', func = function(self) end, sync = function(self) end },
            { name = 'Hold', func = function(self) end, sync = function(self) GetMoonParam(self.ch, MCS.HOLD) end },
            { name = 'Breath', func = function(self) end, sync = function(self) end },
            { name = 'Ped2', func = function(self) end, sync = function(self) end },
            { name = 'Exp', func = function(self) end, sync = function(self) IsExpOn(self.ch) end },
            { name = 'Enable',  vals = {1,2,3,4}, frames = 4, func = function(self) end, sync = function(self) end },
        },
    },
    vst   =  { name = 'vst', caption = '', color = 'black', icon = 'Empty',
            x = leftPad, y = nsY - pad, w = chanW/2, h = pad, fontSize = 11, textColor = 'orange', displayOnly = true, sync = function(self) self:val(GetFXName(self.ch)) end },
    bank  =  { name = 'Bank', color = 'black', caption = '', icon = 'Empty',
            x = leftPad + (chanW / 2), y = nsY - pad, w = chanW/2, h = pad, fontSize = 11, textColor = 'gray', displayOnly = true, sync = function(self) end },
    nSource   =  { name = 'Notesource', x = leftPad, y = nsY, vals = {0,1,2}, frames = 3, w = faderW, h = btnH, func = function(self) end, sync = function(self) end },
    select    =  { name = 'Select', x = chanBtnX, y = nsY, h = btnH, w = chBtnW, func = function(self) chChanged(self.ch) end, sync = function(self) end },
    ch = {},  --this is where all the channel components will go
}
-----------------------------------------------------------------------------------------------------------
---{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{  CREATE ELEMENTS  }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
-----------------------------------------------------------------------------------------------------------
setBackdrop()
gui.leftMenu = createMenu(gui.leftMenu)
gui.globalPreset = createTitle(gui.globalPreset)
gui.globalBank = createTitle(gui.globalBank)
gui.rightMenu = createMenu(gui.rightMenu)
gui.masterVol = createFader(gui.masterVol)
gui.masterLabel = createLabel(gui.masterLabel)
--these hold chan presets/banks.  the global presets are stored in ch 0
--global presets should be stored in banks the same way as channel presets.
--so we need a moonBank for globals
gui.presets = createPanel(gui.presets, gui.presetPager)
gui.banks = createPanel(gui.banks, gui.bankPager)

gui.fxLevel = createFader(gui.fxLevel)
gui.fxLabel = createLabel(gui.fxLabel)
gui.fxSelect = createPanel(gui.fxSelect, gui.fxSelectPager)
gui.panFader = createFader(gui.panFader)  --clicking on pan resets it to center
function gui.panFader:onMouseUp(state)
    if not self.hasBeenDragging then
        self:val(0)
        ch().pan:val(0)
    end
    self.hasBeenDragging = false
end

gui.trackTitle = createTitle(gui.trackTitle)

for i, btn in ipairs(gui.inspector.options) do
    btn.x, btn.y = GetLayoutXandY(i, gui.inspector.x, gui.inspector.y, gui.inspector.w, btnH, paramRows)
    btn.w, btn.h = gui.inspector.w, gui.inspector.h
    btn.chColor = gui.inspector.chColor
    if not btn.momentary then btn.name = 'I'..btn.name end
    --MSG('Creating inspector button: '..btn.name)
    gui[btn.name] = createButton(btn)
end

gui.paramTabs = createPanel(gui.paramTabs, nil, gui.paramTabs.options)
gui.params = createPanel(gui.params)  -- todo: show encoder soloing!
gui.mappings = createPanel(gui.mappings, nil, gui.mappings.options)

gui.monitorVol = createFader(gui.monitorVol)
gui.monitorLabel = createLabel(gui.monitorLabel)

------------------------------------------    CREATE   CHANNEL -------------------------------------
for i = 1,channelCount do
    ----MSG('Chan '..i)
    local ch = {}
    ch.sendLabel =  createLabel(gui.sendLabel,i)
    ch.send =       createFader(gui.send, i)
    ch.semi =       createButton(gui.semi,i)
    ch.oct =        createButton(gui.oct,i)
    ch.fxSpin =     createSpinner(gui.fxSpin,i)
    ch.octaveSpin = createSpinner(gui.octaveSpin,i)
    ch.meterL =     createFader(gui.meterL, i)
    ch.meterR =     createFader(gui.meterR, i)
    ch.pan =        createFader(gui.pan, i)

    for num,option in ipairs(gui.lights.options) do
        option.x, option.y = GetLayoutXandY(num, gui.lights.x, gui.lights.y, indW, indH, 10)
        option.h, option.w = gui.lights.h, gui.lights.w
        option.displayOnly = gui.lights.displayOnly
        option.z = gui.lights.z
        ch[option.name] = createButton(option,i)
    end

    ch.preset = createLabel(gui.preset, i)
    ch.volume = createFader(gui.volume, i)

    for num, option in ipairs(gui.buttons.options) do
        option.x, option.y = GetLayoutXandY(num, gui.buttons.x, gui.buttons.y, chBtnW, btnH, 10)
        option.h, option.w = gui.buttons.h, gui.buttons.w
        option.chColor = true
        ch[option.name] = createButton(option,i)
    end
    ch.vst = createTitle(gui.vst,i)
    ch.bank = createTitle(gui.bank,i)
    ch.nSource = createButton(gui.nSource, i)
    ch.select = createButton(gui.select, i)
    --move them into place en masse at the end!
    for _, elm in pairs(ch) do
        elm.x = elm.x + (chanW * (i - 1))
    end
    ch.color = 'gray'
    gui.ch[i] = ch
    --MSG('got here')

end

------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------MIXER METHODS-------------------------------------------
function ch(chan)
    if not chan then return gui.ch[iCh]
    else return gui.ch[chan] end
end

function chChanged(chNum)
    iCh = chNum
    --get preset list
    --TStr(ch().presetName, 'channel label')
    gui.trackTitle:setCaption(ch().preset:val())
    for i = 1,channelCount do
        ch(i).select:val(0)
        ch(i).select:setColor('black')
        ch(i).nSource:setColor('black')
    end
    ch().select:val(1)
    --get inspector
    for i,elm in ipairs(gui.lights.options) do
        local lightName = elm.name  -- the original options don't have an 'I'
        --MSG('light: '..lightName)
        local inspName = 'I'..lightName
        --set global gui inspector values to channel's light values
        if inspName ~= 'IEmpty' then  --except this one!
            --TStr(gui[inspName],inspName)
            gui[inspName]:val(ch()[lightName]:val())
        end
    end

    for name,ctl in pairs(gui) do
        --MSG('ctl = '..name)
        if ctl.chColor and ctl.color then ctl:setColor(ch().color) end
    end

    gui.panFader:val(ch().pan:val())--]]
end

for _,layer in pairs(layers) do window:addLayers(layer) end

--GlobalSave('test')
window:open()
--MSG('got here')
Fullscreen(window)
sync()
chChanged(1)
GUI.Main()--]]