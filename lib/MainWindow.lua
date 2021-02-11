------------------------------MAIN WINDOW--------------------------------
--[[
    startup process:
    do we want to load the default gpreset before setting up the gui, maybe??
    But that is not helpful with bank settings--where to store them in the meantime?
    Okay, we can't
]]
-------------------------------------------------------------------------
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

local channelCount = 16

local iCh = 1
local leftX = -12

local indZ = 4
local titleZ = 4
local ctlLayerZ = 8
local panelZ = 12
local faderZ = 12
local organZ = 14

local scaling = .8

local imageFolder = IMAGE_FOLDER  --from MoonUtilities
local presetFolder = GBANK_FOLDER
local indent = '    '
-- panel states
local PanelDisplay = 3
    local GLOBAL = 1
    local VST = 2
    local PRESET = 3
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
local function getColor(hue, sat)
    local saturation = sat or 60
    hue = hue or 0
    return GetRGB(hue, saturation)
end

local function getLayer(z)
    if layers[z] then return layers[z]
    else layers[z] = GUI.createLayer({name = 'layer'..z, z = z})
    end
    return layers[z]
end
-- channel data
local vsts = nil  --list of all VSTs with bank files
local plugs = {}  --list of loaded VSTs by channel
local gBankPage = 1  --current global bank page
local presets = {}  --table of tables of presets by channel
local presetPages = {} --table of preset pages
local bankLists = {}  -- list of banks for selected vst by channel
local selectedBanks = {} --list of selected banks by channel
local bankPages = {} --list of bank pages

---------------------------------------------------------------------------------------------
--[[
    what can't be recalled?
    Query sends for fx status....
    Bank Info:
        Hue, Sat, preset list,
        We can get range from MCS as well as MPE settings


    On Startup:
    1. Create the gui.  Values for bank and preset are missing.  no colors yet.
    2. Set default global bank.
    2. Load Default Global Preset.  This should:
        a. load vsts to each channel
        b. create bank tables for all channels
        c. select bank for each channel
        d. select preset for each channel or preset1 if not found
        e. set colors for all channels
        f. sync all gui elements
    3. Select inspector channel 1
    4. Set panels to show presets

    On startup:  we may need to order the settings so we can get dependencies loaded first???

]]

--set gui elements to the reaper value they address. if no name or chan, all will be synced
--obviously global elements will not have a channel.  The function can tell the difference
--DEPRECATE??  Seems like when we load a default global preset on startup, we don't need this...
local function sync(elmName, chan)
    if chan and elmName
    then
        CH().elmName:sync() --sync one element
    else
        if CH().elmName then --not a global element
            for i = 1,channelCount do
                if not elmName then --sync 'em all
                    for name,element in pairs(gui.ch[i]) do
                        if element.sync then element:sync() end
                    end
                else gui.ch[i].elmName:sync() --sync one element across all channels
                end
            end
        elseif gui.elmName then gui.elmName:sync()
        end --fail gracefully if no such element
    end
end

function ChanColor(chan, hue, sat)
    MSG('color for chan:',chan, hue, sat)
    if not hue then
        if chan then return getColor(selectedBanks[chan].hue, selectedBanks[chan].sat)
        else return 'gray' end
    end
    for _, elm in pairs(gui.ch[chan]) do
        --MSG(elm.name, "Setting color")
        if elm.bg then elm:setColor(getColor(hue, sat)) end
        --MSG('setting color for chan ', chan)
        SetChanColor(chan, hue, sat)
    end
end

--get or set.  perhaps recolor if not being used by organ... maybe also (re)caption the controls
local function organColor(hue,sat)
    local color
    if not hue then color = GetRGB(20,40,50)
    else color = GetRGB(hue,sat,BRIGHTNESS) end
    return color
end

function GetChFxOptions(chan)
    local options = {}
    for i, fxch in ipairs(GetChFxList(chan)) do
        --MSG('fx chan = ',fxch)
        options[i] = {name = gui.ch[fxch].preset:val(), color = ChanColor(fxch), chan = fxch,
                    func = function(self)
                        local option = gui.fxSelect:getOption(self.index)
                        SetFxByIdx( iCh, option.chan )
                        CH().send:setColor(option.color)
                        CH().sendLabel:val(option.name)
                        CH().fxSpin:setCaption(option.chan)
                        gui.fxLevel:setColor(option.color)
                        gui.fxLabel:val(option.name)
                    end
        }
    end
    return options
end

--called to load a new bank.
function LoadBank(bankname, chan)
    if not chan then chan = iCh end
    local bank
    if bankname then bank = plugs[chan]:getBank(bankname)
    else bank = plugs[chan].banks[1]  end --if no bank indicated, use the first one
    selectedBanks[chan] = bank
    SetChanFxStatus(chan, bank.isfx)                            --MSG('bank is fx',bank.isfx)
    presets[chan] = bank:presetsAsOptions()
    ChanColor(chan, bank.hue, bank.sat)                         --MSG('finished loading chan'..chan)
end

--called to load a new plugin on a channel
--defaults to iCh, and bank #1
function LoadPlug(vstname, chan)
    if not chan then chan = iCh end
    LoadInstrument(chan, vstname)  --have reaper load the vst
    plugs[chan] = Plugin.load(vstname) --load plugin and bank data
    bankLists[chan] = plugs[chan]:getBanks()
    for i, bank in pairs(bankLists[chan]) do
        bank.color = GetRGB(bank.hue, bank.sat, BRIGHTNESS)
    end
end

--called by the bank panel when a button is selected. name is the buttonName
function SelectBank()
    local option = gui.banks:getSelection()
    MST(option, 'found bank')
    --gui.banks:select(option.index)
    --local bank = option   --gui.banks:getSelectedOption() or gui.banks.options[1]
    --MST(bank,'selected bank option')
    if PanelDisplay == GLOBAL then
        gui.presets:setOptions(GetGPresets())
    elseif PanelDisplay == VST then
        --don't load dll.  load it when a bank is selected
        local plugname = gui.banks:getSelectionData()
        plugs[iCh] = Plugin.load(plugname)

        gui.presets:setOptions()
    elseif PanelDisplay == PRESET then
        LoadBank(option.name)
        gui.presets:setOptions(presets[iCh])
        gui.presets:select(1) --eventually, maybe a bank stores a default preset
    end
end
--called by the preset panel when a button is selected
function SelectPreset()
    local option = gui.presets:getSelection()
    MST(option, 'preset option selected')
    if PanelDisplay == PRESET then
        presets[iCh] = option
        SetFxPreset(iCh,option.name)
        PresetChanged(iCh)
    elseif PanelDisplay == GLOBAL then
        GlobalRecall(option.name, GetGBanks().name)
    elseif PanelDisplay == VST then
        LoadPlug(option.name)
    end
end

-----------------------------------------------------------------------------------------------------------------
-------------------------------------------SWITCH PANEL DISPLAYS ------------------------------------------------
function SetPanelsGLOBAL()
    PanelDisplay = GLOBAL
    gui.banks:setOptions(GetGBanks())
    gui.presets:setOptions(GetGPresets())
    gui.presets:select(gPreset, true)
    --gui.presets:pageToSelection()
end

function SetPanelsVST()
    PanelDisplay = VST
    gui.banks:setOptions(vsts)
    --gui.banks:selectByName(ch().vst:val(), true)
    --gui.banks:pageToSelection()
    gui.presets:setOptions(selectedBanks[iCh])
end

function SetPanelsPRESETS()
    PanelDisplay = PRESET
    gui.banks:setOptions(bankLists[iCh])
    gui.presets:setOptions(presets[iCh])
end

--------------------------------------------------------------------------------------------------
---------------------------------     GLOBAL LOAD/SAVE   -----------------------------------------
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
    --MST(gui.ch,'Channels')
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
    local folder = GBANK_FOLDER..'/'..gui.globalBank.name
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
--part of startup is loading the default global bank
function GlobalRecall(presetName, gBankname)
    if not vsts then vsts = GetBankFileTable() end
    local path = GBANK_FOLDER..gBankname..'/'..presetName..'.lua'
    MSG('loading file: '..path)
    local data = assert(loadfile(path))()
    --MST(data,'data')
    --first we need to load all plugins, then load banks and create needed fx sends.
    for i,channel in ipairs(data.channels) do
        LoadPlug(channel.vst, i)
        LoadBank(channel.bank,i)
    end
    for name,gval in pairs(data) do
        if name == 'channels' then
            for i,chan in ipairs(gval) do
                MSG('Channel: '..i)
                for name, val in pairs(chan) do
                    --check for obselete fields....
                    local elm = gui.ch[i][name]
                    if elm then elm:val(val) end--update control
                end
            end
        else
            gui[name]:val(gval)
            gui[name]:func()
        end
    end
    for i,channel in ipairs(gui.ch) do
        for name, val in pairs(channel) do
            --select is going to needlessly update a bunch of stuff each time...
            --spinners will increment unhelpfully...
            --vst and bank have already been loaded
            if (name == 'select') or (name == 'octaveSpin') or (name =='fxSpin') or (name =='vst') or (name =='bank') then
            else
                --MSG('calling func for: '..name)
                local elm = gui.ch[i][name]
                if elm and elm:func() then
                    MSG('updating:'..name)
                    elm:func(elm) --update reaper
                end
            end
        end
        VstChanged(i)
        BankChanged(i)
        PresetChanged(i)
    end
    --set all sends at once after loading everything
    --sync()
end



--------------------------------------------------------------------------------------------------
--{{{{{{{{{{{{{{{{{{{{{{{{{{{{{          LAYOUT CONSTANTS            }}}}}}}}}}}}}}}}}}}}}}}}}}}}}
--------------------------------------------------------------------------------------------------
local leftPad = 4
local pad = 6

local comboH = 36
local btnH = 36
local meterH = 12
local chanW = 96
local tBtnW = 44
local tempoIncW = 44
local tempoH = 44

local spinnerW = 44
local spinnerH = 72
local btnW = 96
local faderW = 52
local chBtnW = 44
local semiPad = 42
local totalW = 1536
local totalH = 1200
local panH = 12
local dbW = 20
local dbH = btnH * 3 - pad - pad

local presetCols = 8
local presetRows = 6
local paramCols = 8
local paramRows = 4
local bankCols = 3
local inspectorRows = 3
local inspBtnW = btnW * .75
local inspectorW = inspBtnW * inspectorRows
local chanBtnRows = 7

local indH, indW, indX = 17, 17, 32

--x positions
local presetX = faderW + leftPad


local semiX = leftPad + semiPad
local chanBtnX = leftPad + faderW
local inspectorX = chanBtnX + btnW + pad
local paramsX = inspectorX + inspectorW + pad
local bankX = presetX + leftPad + (presetCols * btnW) + spinnerW + pad
local transportX = bankX + (bankCols * btnW) + pad
local organX = paramsX + (paramCols * btnW) + pad
local masterVolX = totalW - faderW

local tempoW = (totalW - transportX) - (2 * tempoIncW)
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

local function setBackdrop()
    local bkdp = GUI.createElement({
        type = "Frame",
        name = 'backdrop',
        x = 0, y = 0, h = 1100, w = 1920,
        bg = GetRGB(159,30,50),
        color = 'black',
    })
    getLayer(99):addElements(bkdp)
    return bkdp
end

local function createMenu(props)
    local z = ctlLayerZ
    local items = {}
    for i,option in ipairs(props.options) do
        local image = option.image or "Combo.png"
        local x, y = GetLayoutXandY(i, props.x, props.y, btnW, btnH, props.rows or 1)
        local item = GUI.createElement({
            name = option.name,
            caption = option.name,
            type = 'MButton',
            wrap = true,
            color = GetRGB(0,0,20),
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
    local image = props.image or nil
    if image then image = imageFolder..image..'.png' end
    local fontSize = props.fontSize or 32
    local font = {'Calibri', fontSize,"b"}
    local title = GUI.createElement ({
        type = "MButton",
        name = props.name..'_'..ch,
        image = image or nil,
        momentary = props.momentary or true,
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
        captionX = props.captionX or 0,
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
        x = props.x, y = props.y, w = props.w or btnW, h = props.h or comboH, z = panelZ,
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
        MST(options,'options')
        panel:setPage(1)
    end
    return panel
end

local function createFader(props, ch)
    if not ch then ch = '' end
    local image
    if props.image then image = props.image else image = props.name end
    --MSG('create fader'..props.name)
    local z = props.z or faderZ
    local fader = GUI.createElement({
        frames = props.frames,
        caption = props.caption or '',
        captionX = props.captionX or 0,
        captionY = props.captionY or 0,
        horizontal = props.horizontal or false,
        name = props.name..'_'..ch,
        type = "MSlider",
        min = props.min or 0, max = props.max or 1, value = 0,
        x = props.x ,y = props.y, w = props.w or faderW, h = props.h,
        image = imageFolder..image..".png",
        func = props.func,
        ch = ch,
        color = props.color or nil,
        save = props.save,
        sync = props.sync or nil,
        bg = props.bg or nil
    })
    getLayer(z):addElements(fader)
    return fader
end

local function createButton(props, ch)
    if not ch then ch = '' end
    local fontSize = props.fontSize or 22
    local font = {'Calibri', fontSize,"b"}
    local caption = props.caption or ''
    local image = props.image or props.name
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
        image = imageFolder..image..".png",
        func = props.func,
        ch = ch,
        save = props.save,
        sync = props.sync or nil,
        bg = props.bg or nil
    })
    --MSG('Created Element: '..button.name)
    getLayer(z):addElements(button)
    return button
end

local function createSpinner(props, ch)
    if not ch then ch = '' end
    local z = props.z or ctlLayerZ
    local image
    if props.image then image = props.image else image = 'Spinner' end
    local spinner = GUI.createElement({
        name = props.name..'_'..ch,
        type = "MButton",
        momentary = true,
        spinner = true, wrap = false,
        captionY = -.02,
        w = props.w or spinnerW, h = props.h or spinnerH,
        x = props.x, y = props.y,
        frames = 1,
        min = -1,max = 1,inc = 1, --for now need all these for stateless spinner...
        image = imageFolder..image..'.png',
        func = props.func,
        ch = ch,
        save = false,
        bg = props.bg or nil
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
    fullscreen = { name = 'FullScreen', x = 0, y = 0, w = presetX - pad, h = btnH, func = function(self) Fullscreen(window, self:val() == 1) end },
    leftMenu = {  x = presetX, y = 0, color = 'blue', options = {
            { name = 'Quit', momentary = true, func = function(self) CloseWindow(window) end },
            { name = 'Console', momentary = true, func = function() ultraschall.BringReaScriptConsoleToFront() end },
            { name = 'Global', momentary = true, func = function() SetPanelsGLOBAL() end },
            { name = 'Presets', momentary = true, func = function() SetPanelsPRESETS() end},
            { name = 'VSTs', momentary = true, func = function() SetPanelsVST() end},
            { name = 'Scroll Left', momentary = true, func = function(self) leftPad = -300
                                            ResizeWindow(window, leftX, 0, 800, SCREEN_HEIGHT) window:redraw() end }
        },
    },
    globalBank = { name = 'gBank', save = true, multi = false,  fontSize = 18, x = bankX - (btnW * 4), y = 0, w = 4 * btnW, sync = function(self)  end},
    globalPreset = { name = 'gPreset', save = true, x = bankX - btnW, y = 0, w = 4 * btnW, color = 'gray', func = function(self) end},
    rightMenu = { x = totalW - btnW - faderW - pad, y = (tempoH * 3) + pad, rows = 3, options =  {
            { name = 'BankEditor',momentary = true, func = function(self) OpenBankEditor() end},
            { name = 'gSave', momentary = true, func = function(self) GlobalSave(gui.globalPreset.caption) end},
            { name = 'gSave As', momentary = true, func = function(self) GlobalSaveAs()  end },
        },
    },
    masterVol = {   name = 'masterVol', save = true, image = 'masterVol', color = 'green', x = masterVolX, y = presetY, h = btnH*6,  frames = 108,
                        func = function(self) MSG('volume = '..self:val()) end},
    masterLabel =  { name = 'masterLabel', caption = 'MASTER', fontSize = 36, textColor = 'gray', x = masterVolX + pad + 2, y = 116, w = 120, h = 24 },
    monitorVol = {  name = 'monitor',save = true, image = 'monitorVol', color = 'yellow', x = 0, y = presetY, h = btnH * 6, frames = 72, func = function(self) end },
    monitorLabel =  { name = 'monitorLabel', caption = 'MONITOR', fontSize = 36, textColor = 'gray', x = 6, y = 132, w = 100, h = 24 },
    ------------------------------------------------------------------------------------------------
    --{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ ROW 1 }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}--
    ------------------------------------------------------------------------------------------------

    presets =   {   name = 'presetPanel', x = presetX, y = presetY, rows = presetRows, cols = presetCols, chColor = true,
                func = function(self) SelectPreset() end},
    presetPager = {  x = bankX - spinnerW - pad, y = presetY, w = spinnerW, h = spinnerH, chColor = true},
    banks =     {   name = 'bankPanel', x = bankX, y = presetY, rows = presetRows, cols = bankCols, func = function(self) SelectBank() end },
    bankPager = {  x = bankX - spinnerW, y = paramsY - spinnerH - pad, w = spinnerW, h = spinnerH},
    -------------------------------------------TRANSPORT---------------------------
    -------------------------------------------------------------------------------
    tempoDec = { name = 'TempoDec', w = tBtnW, x = transportX, y = 0, h = tempoH, momentary = true,  func = function(self) UpdateTempo(LOCAL_TEMPO - 1) end },
    tempo    = { name = 'Tempo', w = tempoW, x = transportX + tBtnW, h = tempoH, y = 0, horizontal = true, min = 50, max = 197, frames = 147, func = function(self) Tempo(self:val()) end },
    tempoInc = { name = 'TempoInc', x = totalW - tBtnW, y = 0, w = tBtnW, h = tempoH, momentary = true, func = function(self) UpdateTempo(LOCAL_TEMPO + 1) end },
    hemiola = { name = 'hemiola',  w = tBtnW, h = btnH, x = transportX, y = tempoH + btnH, rows = 1, cols = 2, options = {
        { name = 'ResetMeter', func = function(self) Tempo(nil, nil, 1) end },
        { name = 'Quint', func = function(self) Tempo(nil, nil, .8) end },
        { name = 'Triplet', func = function(self) Tempo(nil, nil, .75) end },
        { name = 'Dot', func = function(self) Tempo(nil, nil, .66666666) end },
        { name = 'DoubleDot', func = function(self) Tempo(nil, nil, .625) end},
            }
    },
    quaver =  { name = 'quaver', x = transportX, y = tempoH, w = tBtnW , rows = 1, cols = 5, options =   {
                { name = 'Whole', image = 'Whole', func = function(self) Tempo(nil, .25) end }, --tempo multiplier affects reaper.  Store original tempo in the tempo slider
                { name = 'Half', image = 'Half', func = function(self) Tempo(nil, .5) end },
                { name = 'Quarter', image = 'Quarter', func = function(self) Tempo(nil, 1) end },
                { name = 'Eighth', image = 'Eighth', func = function(self) Tempo(nil, 2) end },
                { name = 'Sixteenth', image = 'Sixteenth', func = function(self) Tempo(nil, 4) end},
            }
    },
    ------------------------------------------------------------------------------------------------
    --{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ ROW 2 }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}--
    ------------------------------------------------------------------------------------------------
    fxLevel =  {   name = 'fxLevel', image = 'send', x = leftPad, y = paramsY ,frames = 72, h = 5 * btnH, func = function(self) SetFxLevel(iCh, self:val()) CH().send:val(self:val()) end},
    fxLabel =  {   name = 'fxLabel', x = leftPad + pad, y = paramsY + 55, fontSize = 24, h = 5 * btnH, },
    panFader =  {   name = 'Ipan', x = inspectorX, y = paramsY, frames = 97, min = -1, max = 1, horizontal = true, chColor = true, caption = 'pan', captionY = -.7,
                    w = 2 * inspBtnW, h = btnH, func =  function(self) CH().pan:val(self:val()) Pan(iCh, self:val()) end },
    trackTitle = {  name = 'trackTitle', x = paramsX, y = paramsY, w = btnW * 3, func = function(self) OpenPlugin(iCh) end },  --show vst
    paramTabs = { name = 'paramTabs',x = paramsX + (5 * btnW), y = paramsY, rows = 1, cols = 2, color = GetRGB(0,0,75), options = {
            { name = 'Params', func = function(self) gui.params.layer:show() gui.mappings.layer:hide()  end },
            { name = 'Mappings', func = function(self) gui.params.layer:hide() gui.mappings.layer:show() end },
        },
    },
    fxSelect =  {   name = 'fxSelect', x = chanBtnX, y = paramsY + btnH, rows = paramRows, cols = 1, func = function(self) end },
    fxSelectPager = {  x = faderW + leftPad, y = paramsY, w = btnW, h = btnH, image = "HorizSpin.png" , horizontal = true},
    inspector = {   x = inspectorX, y = paramsY + btnH, w = inspBtnW, h = btnH, chColor = true, options = {
            { name = 'Cue', func = function(self)    CH().Cue:val(self:val()) Cue(iCh, self:val()) end },
            { name = 'Solo', func = function(self)   CH().Solo:val(self:val())  end },
            { name = 'MuteFx', func = function(self) CH().MuteFx:val(self:val())  end },
            { name = 'NsSolo', func = function(self) CH().NsSolo:val(self:val())  end },
            { name = 'Hands', func = function(self)  CH().Hands:val(self:val()) SetMoonParam(iCh, MCS.HANDS, self:val()) end },
            { name = 'Sharp', momentary = true, func = function(self)   CH().semi:increment(1,false) SetMoonParam(iCh, MCS.SEMI, CH().semi:val()) end },
            { name = 'Natural', momentary = true, func = function(self) CH().semi:val(0); CH().oct:val(0); CH().octaveSpin:setCaption('') SetMoonParam(iCh, MCS.SEMI, 0) end },
            { name = 'Flat', momentary = true, func = function(self)    CH().semi:increment(-1,false) SetMoonParam(iCh, MCS.SEMI, CH().semi:val()) end },
            { name = 'Encoders', func = function(self)  CH().Encoders:val(self:val()) MidiIN(iCh, TRACKS.IN_ENC, self:val()) end },
            { name = 'Switches1', func = function(self) CH().Switches1:val(self:val()) MidiIN(iCh, TRACKS.IN_SW1) end },
            { name = 'Switches2', func = function(self) CH().Switches2:val(self:val()) MidiIN(iCh, TRACKS.IN_SW2) end },
            { name = 'Drawbars', func = function(self)  CH().Drawbars:val(self:val()) MidiIN(iCh, TRACKS.IN_DRWB) end },
        },
    },
    params =    {   name = 'params', x = paramsX, y = paramsY + btnH, rows = paramRows, cols = paramCols, chColor = true, func = function(self) end },
    mappings =  {  name = 'mappings', x = paramsX, y = paramsY + btnH, rows = paramRows, cols = paramCols, multi = true, options = {
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
    organTabs = { name = 'organTabs',x = organX, y = paramsY, rows = 1, cols = 2, color = GetRGB(0,0,75), options = {
            { name = 'Organ', color = organColor(), func = function(self) ShowOrganCtl(true)  end },
            { name = 'Mods', func = function(self) ShowOrganCtl(false) end },
        },
    },
    organControls = { name = 'organControls', x = organX, y = paramsY + btnH, h = dbH/2, w = btnW/2, rows = 2, cols = 4, multi = true, options =  {
            { name = 'ch vib',   sync = function(self) end, func = function(self) end },
            { name = 'leslie',    sync = function(self) end, func = function(self) end },
            { name = 'vib UP', sync = function(self) end, func = function(self) end },
            { name = 'vib DN', sync = function(self) end, func = function(self) end },
            { name = 'perc',    sync = function(self) end, func = function(self) end },
            { name = 'harm',  sync = function(self) end, func = function(self) end },
            { name = 'vol',   sync = function(self) end, func = function(self) end },
            { name = 'decay', sync = function(self) end, func = function(self) end },
        },
    },
    drawbars = { x = totalW - (9* dbW) - pad, y = paramsY + btnH, z = organZ, frames = 9, options =  {
            { name = 'drawbar1', sync = function(self) end, func = function(self) end },
            { name = 'drawbar2', sync = function(self) end, func = function(self) end },
            { name = 'drawbar3', sync = function(self) end, func = function(self) end },
            { name = 'drawbar4', sync = function(self) end, func = function(self) end },
            { name = 'drawbar5', sync = function(self) end, func = function(self) end },
            { name = 'drawbar6', sync = function(self) end, func = function(self) end },
            { name = 'drawbar7', sync = function(self) end, func = function(self) end },
            { name = 'drawbar8', sync = function(self) end, func = function(self) end },
            { name = 'drawbar9', sync = function(self) end, func = function(self) end },
        },
    },
    organDrive =  { name = 'drive', caption = 'drive', captionY = -.6, x = organX, y = paramsY + (btnH * 4) - pad, z = organZ, w = btnW*2, h = btnH + pad,
                horizontal = true, frames = 97, image = 'OrganFader',  sync = function(self)end, func = function(self) end },
    organReverb = { name = 'reverb', caption = 'reverb', captionY = -.6, x = totalW - (9* dbW) - pad, y = paramsY + (btnH * 4) - pad, z = organZ, w = dbW*9, h = btnH + pad,
                horizontal = true, frames = 97, image = 'OrganFader', sync = function(self)end, func = function(self) end },
    ------------------------------------------------------------------------------------------------
    --{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{ CHANNELS }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}--
    ------------------------------------------------------------------------------------------------

    --TODO: On startup, SetFxLevel requires all fx sends to be set up...


    -- this data is stored unless save = false
    send =     { name = 'Send', x = leftPad, y = fxSendY, h = 4 * btnH, frames = 72, func = function(self) SetFxLevel(self.ch, self:val()) gui.fxLevel:val(self:val()) end,
                sync = function(self) self:val(GetFxLevel(self.ch)) self:setColor(ChanColor(self.ch)) end},
    sendLabel =  { name = 'sendLabel', x = leftPad + 4, y = fxSendY + 12, w = 120, h = 20, fontSize = 18, sync = function(self) self:val(GetChFxName(self.ch)) end }, --fx selected by spinner, but stored here
    semi =     { name = 'Semi', bg = true, x = semiX, y = fxSendY, displayOnly = true, wrap = false, z = 4,
                                    w = 16, h = spinnerH, frames = 15, min = -7, max = 7, sync = function(self) self:val(GetMoonParam(self.ch, MCS.SEMI))  end }, -- stores semi data
    oct  =     { name = 'Oct', bg = true, x = semiX, y = octY, displayOnly = true, wrap = false, z = 4,
                                    w = 16, h = spinnerH, frames = 11, min = -5, max = 5,
                                    sync = function(self) self:val(GetMoonParam(self.ch, MCS.OCTAVE)) end }, --stores oct data
    fxSpin =   { name = 'fxSpin', bg = true, save = false, x = leftPad + faderW, y = fxSendY, sync = function(self) self.caption = GetFxChan(self.ch) end,
                                                                        func = function(self)
                                                                            local chan = CH(self.ch)
                                                                            IncFxNum(self.ch,self:val())
                                                                            self.caption = GetFxChan(self.ch)
                                                                            chan.send:setColor(ChanColor(GetFxChan(self.ch)))
                                                                            chan.sendLabel:val(GetChFxName(self.ch)) end },
    octaveSpin =  { name = 'octaveSpin', bg = true, save = false, x = leftPad + faderW, y = octY, chColor = true, func = function(self)
                                                                            local chan = CH(self.ch)
                                                                            chan.oct:increment(self:val())
                                                                            SetMoonParam(self.ch, MCS.OCTAVE, chan.oct:val())
                                                                            if chan.oct:val() ~= 0 then
                                                                                self.caption = math.floor(chan.oct:val())
                                                                            else self.caption = '' end end},
    pan =    { name = 'pan', x = leftPad, y = chanY - meterH, h = panH, w = chanW, horizontal = true, z = 4,
                                    displayOnly = true, frames = 25, min = -1, max = 1,  sync = function(self) self:val(Pan(self.ch)) end  },
    meterL = { name = 'meterL', bg = true, save = false, x = leftPad, y = chanY - meterH, h = panH/2, w = chanW, horizontal = true,
                                    displayOnly = true,frames = 25, chColor = true },
    meterR = { name = 'meterR', bg = true, save = false, x = leftPad, y = chanY - (meterH/2), h = panH/2, w = chanW, horizontal = true,
                                    displayOnly = true, frames = 25, chColor = true },

    preset =   { name = 'presetName', x = leftPad + 2, y = chanY + 106, fontSize = 26,  sync = function(self) end  },
    volume =    { name = 'volume', bg = true, x = leftPad, y = chanY, h = btnH * 6, w = faderW, frames = 108,  chColor = true, func = function(self) Output(self.ch,self:val()) end ,  sync = function(self) self:val(Output(self.ch)) end },

    lights =  { x = leftPad + indX, y = chanY + pad, w = indW, h = indH, displayOnly = true, z = indZ, options = {
            { name = 'Cue', sync = function(self) self:val(Cue(self.ch)) end },
            { name = 'Solo', sync = function(self) end },
            { name = 'MuteFx', sync = function(self) end },
            { name = 'NsSolo', sync = function(self) end },
            { name = 'Hands', sync = function(self) GetMoonParam(self.ch, MCS.HANDS) end },
            { name = 'Encoders',  sync = function(self) self:val(MidiIN(self.ch, TRACKS.IN_ENC)) end },
            { name = 'Switches1', sync = function(self) self:val(MidiIN(self.ch, TRACKS.IN_SW1)) end },
            { name = 'Switches2', sync = function(self) self:val(MidiIN(self.ch, TRACKS.IN_SW2)) end },
            { name = 'Drawbars',  sync = function(self) self:val(MidiIN(self.ch, TRACKS.IN_DRWB)) end },
        },
    },
    buttons = { x = chanBtnX, y = chanY, w = chBtnW, h = btnH, chColor = true, options =  {
            --need a method to query bank for sustain type
            { name = 'NoSus', bg = true, func = function(self) SetMoonParam(self.ch, MCS.SUSTAIN, self:val()) end, sync = function(self) self:val(GetMoonParam(self.ch, MCS.SUSTAIN) == 0) end },
            { name = 'Hold', bg = true, func = function(self) SetMoonParam(self.ch, MCS.HOLD, self:val()) end, sync = function(self) self:val(GetMoonParam(self.ch, MCS.HOLD)) end },
            { name = 'Breath', bg = true, func = function(self) MidiIN(self.ch, TRACKS.IN_BC, self:val()) end, sync = function(self) self:val(MidiIN(self.ch, TRACKS.IN_BC)) end },
            { name = 'Ped2', bg = true, func = function(self) MidiIN(self.ch, TRACKS.IN_PED2, self:val()) end, sync = function(self) self:val(MidiIN(self.ch, TRACKS.IN_PED2)) end },
            { name = 'Exp', bg = true, func = function(self) MidiIN(self.ch, TRACKS.IN_EXP, self:val()) end, sync = function(self) self:val(IsExpOn(self.ch)) end },
            { name = 'Enable',  bg = true, vals = {1,2,3,4}, frames = 4, func = function(self) end, sync = function(self) end },
        },
    },
    vst   =  { name = 'vst', caption = '', color = 'black', image = 'plain', captionX = .1,
            x = leftPad + (chanW / 2), y = nsY - pad, w = chanW/2, h = 12, fontSize = 11, textColor = 'green', displayOnly = true, sync = function(self) initPlug(self.ch) self:val(plugs[self.ch].name) end },
    bank  =  { name = 'Bank', color = 'black', caption = '', image = 'plain',
            x = leftPad, y = nsY - pad, w = chanW/2, h = 12, fontSize = 11, textColor = 'yellow', displayOnly = true, sync = function(self) self:val(bankLists[self.ch].name) end },
    nSource   =  { name = 'Notesource', x = leftPad, y = nsY, vals = {0,1,2}, frames = 3, w = faderW, h = btnH, func = function(self) end, sync = function(self) end },
    select    =  { name = 'Select', x = chanBtnX, y = nsY, h = btnH, w = chBtnW, func = function(self) ChChanged(self.ch) end, sync = function(self) end },
    ch = {},  --this is where all the channel components will go
}
-----------------------------------------------------------------------------------------------------------
---{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{  CREATE ELEMENTS  }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
-----------------------------------------------------------------------------------------------------------
--setBackdrop()
gui.fullscreen = createButton(gui.fullscreen)
gui.leftMenu = createMenu(gui.leftMenu)
gui.globalPreset = createTitle(gui.globalPreset)
gui.globalBank = createTitle(gui.globalBank)
gui.tempoDec = createButton(gui.tempoDec)
gui.tempo = createFader(gui.tempo)
gui.tempoInc = createButton(gui.tempoInc)
MSG('got here')

local function tempoOptions(options)
    local opts = {}
    for i,option in ipairs(options) do
        local newOption = { name = '', image = imageFolder..option.name..'.png', func = option.func }
        table.insert(opts, newOption)
    end
    return opts
end
gui.hemiola = createPanel(gui.hemiola, nil, tempoOptions(gui.hemiola.options))
gui.quaver = createPanel(gui.quaver, nil, tempoOptions(gui.quaver.options))

gui.rightMenu = createMenu(gui.rightMenu)

gui.monitorVol = createFader(gui.monitorVol)
gui.monitorLabel = createLabel(gui.monitorLabel)
gui.masterVol = createFader(gui.masterVol)
gui.masterLabel = createLabel(gui.masterLabel)
--PANELS-----------------------------------------------------
gui.presets = createPanel(gui.presets, gui.presetPager)
gui.banks = createPanel(gui.banks, gui.bankPager)

gui.fxLevel = createFader(gui.fxLevel)
gui.fxLabel = createLabel(gui.fxLabel)
gui.fxSelect = createPanel(gui.fxSelect, gui.fxSelectPager)
gui.panFader = createFader(gui.panFader)  --clicking on pan resets it to center
function gui.panFader:onMouseUp(state)
    if not self.hasBeenDragging then
        self:val(0)
        CH().pan:val(0)
    end
    self.hasBeenDragging = false
end

gui.trackTitle = createTitle(gui.trackTitle)
--INSPECTOR-----------------------------------------------------------
for i, btn in ipairs(gui.inspector.options) do
    btn.x, btn.y = GetLayoutXandY(i, gui.inspector.x, gui.inspector.y, gui.inspector.w, btnH, paramRows)
    btn.w, btn.h = gui.inspector.w, gui.inspector.h
    btn.chColor = gui.inspector.chColor
    if not btn.momentary then btn.name = 'I'..btn.name end
    --MSG('Creating inspector button: '..btn.name)
    gui[btn.name] = createButton(btn)
end
--PARAMS--------------------------------------------------------------
gui.paramTabs = createPanel(gui.paramTabs, nil, gui.paramTabs.options)
gui.params = createPanel(gui.params)  -- todo: show encoder soloing!
gui.mappings = createPanel(gui.mappings, nil, gui.mappings.options)
--ORGAN---------------------------------------------------------------

gui.organTabs = createPanel(gui.organTabs, nil, gui.organTabs.options)
for i, fader in ipairs(gui.drawbars.options) do
    fader.x, fader.y = GetLayoutXandY(i, gui.drawbars.x, gui.drawbars.y, dbW, dbH, 1)
    fader.w, fader.h = dbW, dbH
    fader.z = gui.drawbars.options.z
    fader.frames = gui.drawbars.frames
    if i == 1 or i == 2 then fader.image = 'DrawbarBrown'
    elseif i == 3 or i == 4 or i == 6 or i == 9 then fader.image = 'DrawbarWhite'
    else fader.image = 'DrawbarBlack' end
    fader.color = organColor()
    gui[fader.name] = createFader(fader)
    gui.drawbars[i] = fader
end
gui.organControls = createPanel(gui.organControls, nil, gui.organControls.options)
gui.organControls:setColor(organColor(), true)
gui.organDrive = createFader(gui.organDrive) gui.organDrive:setColor(organColor())
gui.organReverb = createFader(gui.organReverb) gui.organReverb:setColor(organColor())

function ShowOrganCtl(on)
    if on then getLayer(organZ):show() gui.organControls.layer:show()
    else getLayer(organZ):hide() gui.organControls.layer:hide()
    end
end

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

    gui.ch[i] = ch

end

------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------MIXER METHODS-------------------------------------------

function UpdateTempo(bpm)
    Tempo(bpm) --set reaper tempo, and global values
    gui.tempo:val(LOCAL_TEMPO)
end

function CH(chan)
    if not chan then return gui.ch[iCh]
    else return gui.ch[chan] end
end
--update the gui when a preset is changed
function PresetChanged(chNum)
    local name = presets[chNum].name
    CH().preset:val(name)
    gui.trackTitle:val(name)
    for i, chanNum in ipairs(GetFxReceives(chNum)) do
        --change their send name to the new preset name
        gui.ch[chanNum].sendLabel:val(name)
    end
end
--update the gui when a bank is changed
function BankChanged(chNum)
    local name = selectedBanks[chNum].name
    CH().bank:val(name)
    for i, rcvCh in ipairs(GetFxReceives(chNum)) do
        gui.ch[rcvCh].send:setColor(ChanColor(chNum))
    end
end
function VstChanged(chNum)
    local name = selectedBanks[chNum].vstName
    CH().vst:val(name)
end
--called by channel select button
function ChChanged(chNum)
    --MSG('got here')
    iCh = chNum
    local color = ChanColor(chNum)
    if PanelDisplay == PRESET then
        gui.presets:setColor(color, true)
        gui.presets:setOptions(presets[iCh])
        gui.banks:setOptions(bankLists[iCh])
        gui.banks:selectByName(selectedBanks[iCh].name, true) --select the button, but don't reload the bank...
        gui.banks:pageToSelection()
    end
    --get preset list
    gui.trackTitle.textColor = color
    gui.trackTitle:setCaption(CH().preset:val())
    gui.paramTabs:setColor(color, true)
    --fx
    gui.fxLabel:val( CH().sendLabel:val() )
    gui.fxLevel:val( CH().send:val())

    gui.fxSelect:setOptions(GetChFxOptions(iCh))
    MST(gui.fxSelect.options, 'OPTIONS')
    gui.fxSelect:select(GetFxChan(iCh),true)
    gui.fxSelect:pageToSelection()

    for i = 1,channelCount do
        CH(i).select:val(0)
        CH(i).select:setColor('black')
        CH(i).nSource:setColor('black')
        CH(i).bank:setColor('black')
        CH(i).vst:setColor('black')
    end
    CH().select:val(1)
    CH().select:setColor(color)
    CH().nSource:setColor(color)
    CH().bank:setColor(color)
    CH().vst:setColor(color)
    --get inspector
    for i,elm in ipairs(gui.lights.options) do
        local lightName = elm.name  -- the original options don't have an 'I'
        --MSG('light: '..lightName)
        local inspName = 'I'..lightName
        --set global gui inspector values to channel's light values
        if inspName ~= 'IEmpty' then  --except this one!
            --MST(gui[inspName],inspName)
            gui[inspName]:val(CH()[lightName]:val())
            gui[inspName]:setColor(color)
        end
    end
    gui.Sharp:setColor(color)
    gui.Flat:setColor(color)
    gui.Natural:setColor(color)
    gui.panFader:setColor(color)

    for name,ctl in pairs(gui) do
        --MSG('ctl = '..name)
        if ctl.chColor and ctl.color then ctl:setColor(CH().color) end
    end

    gui.panFader:val(CH().pan:val())--]]
end

for _,layer in pairs(layers) do window:addLayers(layer) end

--GlobalSave('test')
window:open()
Fullscreen(window)
ResetSends()
--initTables()
GlobalRecall('default','default')
--sync()
--ChChanged(1)
SetPanelsPRESETS()
GUI.Main()