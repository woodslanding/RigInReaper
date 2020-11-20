--[[11 x 48 = 528 --channels

1080-36 = 1044  --titleLayer bar
-528            --channels
= 516           --for buttons

44 x 6 = 264   --six preset button rows

516 - 264 = 252  --left

44 x 5 = 220  -- five control button rows
]]

--[[

32 px left for spacing
CHANNEL BUTTONS:
Select
Notesource
Enable
Exp
Ped2
Breath
Hold
NoSus
Octave+
Octave-
Channel+
Channel-
Oct Display
Meter Display
Mini Displays
	enc,sw1,sw2,drawbars,fsw
    mute fx,solo, hands]]
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

loadfile(libPath .. "scythe.lua")()
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

local controlLayer = GUI.createLayer({name = "ctlLayer", z = 2})
local titleLayer = GUI.createLayer({name = "titleLayer", z = 4})
local sliderLayer = GUI.createLayer({name = "sliderLayer", z = 6})
local fxbkgdLayer = GUI.createLayer({name = "fxbkgdLayer", z = 16})
local bkgdLayer = GUI.createLayer({name = "bkgdLayer", z = 18})
local backdropLayer = GUI.createLayer({name = "backdropLayer", z = 20})

local ChannelCount = 10
Channels = {}
Controls = {}
Current = 1

local ifl = IMAGE_FOLDER  --from MoonUtilities
local leftPad = 4
local scaling = .8
local chanW = 96
local faderW = 52
local paramsY = 240
local comboH = 36
local fxOffset = 390
local btnH = 36
local meterH = 12
local volOffset = fxOffset + (btnH * 4) + meterH
local chanH = (btnH * 6)
local leftW = 52
local rightW = 44

--Control Access Constants
INS = {EMPTY = 1,SOLO = 2,MUTEFX = 3,HANDS = 4, SHARP = 6, NATURAL = 7, FLAT = 8, ENCODERS = 9, SW1 = 10, SW2 = 11, DRAWBARS = 12}
MTR = {PAN = 1, L_METER = 2, R_METER = 3}
IND = {SOLO = 1, MUTEFX = 2, EMPTY = 3, HANDS = 4, ENCODERS = 6, SW1 = 7, SW2 = 8, DRAWBARS = 9}
MIX = {NOSUS = 1, HOLD = 2, BREATH = 3, PED2 = 4, EXP = 5, ENABLE = 6, SELECT = 7, SOURCE = 8}

local function fakeOptions(panel)
    for i = 1,250 do
        panel.options[i] = {  name = 'option'..i..'-'..math.random(111,999), val = 0 }
    end
end

local testNames = {'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings',
                    'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings',
                    'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings',
                    'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings'}

function Scale(val)
    return math.ceil(val * scaling)
end

function SetBackdrop()
    local bkdp = GUI.createElement({
        type = "Frame",
        name = 'backdrop',
        x = 0, y = 0, h = 1080, w = 1920,
        bg = 'black',
        color = 'black'
    })
    backdropLayer:addElements(bkdp)
end
---------------------------------------------------------------------------------------------------------
--------------------------------------------PRESET LAYER ------------------------------------------------
--TODO: need a means to store and recall the selection values for each channel
function CreatePresets()
    local rows, cols = 5,8
    local presets = MButtonPanel.new(ifl.."Combo.png",sliderLayer,rows,cols,
                                leftPad,0,chanW,comboH,       --button
                                true, (chanW * cols) + leftPad,0,44,72) --spinner
    fakeOptions(presets)
    presets.pager.image = ifl.."Spinner.png"
    presets:setPage(1)
    return presets
end
PresetPanel = CreatePresets()
function PresetPanel:onSelect() 
    Chan().presetName:val(self.selection[1]) 
end
----------------------------------------------------------------------------------------------------------
----------------------------------------------PARAMS LAYER------------------------------------------------
FxLevel = GUI.createElement({
    frames = 72,horizontal = false,
    --horizFrames = true,
    --vertText = true,
    name = "IfxLevel",
    min = 0,
    max = 99,
    value = 0,
    type = "MSlider",
    x = leftPad,y = paramsY - comboH, w = faderW,h = comboH * 5,
    labelX = 0,labelY = 0,
    image = ifl.."FxLevel.png",
    func = function(self, a, b, c) end,
})
sliderLayer:addElements(FxLevel)

local fxBgColor = RandomColor()
local fxBg = GUI.createElement({
    type = "Frame",
    name = 'Ifxbg',
    x = leftPad, y = paramsY - comboH, w = faderW, h = comboH * 5,
    bg = fxBgColor,
    color = fxBgColor,
})
bkgdLayer:addElements(fxBg)

function CreateFxSel()
    local rows, cols = 4, 1
    local fxSel = MButtonPanel.new(ifl.."Combo.png",controlLayer,rows,cols,
                                faderW + leftPad, paramsY, chanW, comboH,     --button
                                true,faderW + leftPad, paramsY - comboH, chanW, comboH)
    fakeOptions(fxSel)
    fxSel.multi = false
    fxSel.pager.horizontal = true
    fxSel.pager.image = ifl.."HorizSpin.png"
    fxSel:setPage(1)
    fxSel:setColor(RandomColor(40))
    return fxSel
end 
--------------------------------------------------INSPECTOR----------------------------------
function IChan() return Channels[Current] end
Inspector = {}

Inspector.icons =  {'Empty', 'ISolo', 'IMuteFX', 'IHands',
                    'Empty','Sharp','Natural','Flat',
                    'IEncoders','ISwitches1','ISwitches2','IDrawbars',
                    }

Inspector.ind =    {IND.EMPTY,IND.SOLO,IND.MUTEFX,IND.HANDS,
                    IND.EMPTY,IND.SHARP,IND.NATURAL,IND.FLAT,
                    IND.ENCODERS,IND.SW1,IND.SW2,IND.DRAWBARS}
Inspector.switches = {}

function CreateInspectorSwitch(xpos,ypos,w,h,index)
    local dest = Inspector.ind[index]  --the channel indicator index for this switch
    M.Msg('create switch: ',xpos,ypos,w,h,index)
    local switch = GUI.createElement({
        w = w,h = h, x = xpos, y = ypos,
        type = "MButton",
        name = Inspector.icons[index],
        image = ifl..Inspector.icons[index]..'.png',
        loop = true,
        frames = 2,
        caption = '',
        min = 0, max = 1,
        value = 0,
        func = function(self) M.Msg('Calling func '..self.name,'ind: '..dest) IChan().indicators[dest]:val(self:val()) end
    })
    controlLayer:addElements(switch)
    Inspector.switches[index] = switch
end

function CreateInspector() 
    local x,y,w,h = faderW + leftPad + chanW + 8, paramsY, (chanW + faderW) / 2, comboH
    local rows,columns =  4,3
    local xpos, ypos
    local index = 1
    for i = 1, columns do
        xpos = x + ((i - 1) * w)
        for j = 1, rows do
            ypos = y + ((j - 1) * h)
            if Inspector.icons[index] ~= 'Empty' then CreateInspectorSwitch(xpos,ypos,w,h,index) end
            index = index + 1
        end
    end
    Inspector.switches[INS.FLAT].momentary = true
    Inspector.switches[INS.FLAT].func = function(self) IChan().semi:increment(-1,false)  end
    Inspector.switches[INS.SHARP].momentary = true  
    Inspector.switches[INS.SHARP].func = function(self) IChan().semi:increment(1,false)  end
    Inspector.switches[INS.NATURAL].momentary = true
    Inspector.switches[INS.NATURAL].func = function(self) IChan().semi:val(0)  
                                                          IChan().octave:val(0)
                                                          IChan().mixSpinners[2]:val(0)
                                                          IChan().mixSpinners[2].caption = '' end
    return
end
CreateInspector()
function setInspectorColor(color) 
    for i,switch in pairs(Inspector.switches) do
        switch.color = color
        switch:redraw()
    end
end

----------------------------------------------PARAMS----------------------------------------------
function CreateParams()
    local rows, cols, x, y, w, h = 4, 8
    local params = MButtonPanel.new(ifl.."Combo.png",controlLayer,rows,cols,
                                (chanW * 3) + leftPad, paramsY, chanW , comboH )     --no spinner
    fakeOptions(params)
    params.multi = true
    --params.pager.image = ifl.."Combo.png"
    params:setPage(1)
    return params
end

ParamPanel = CreateParams()
FxSelPanel = CreateFxSel()

-----------------------------------------------------------------------------------------------------------------------------------
                                          --    CREATE   --
                                          --    CHANNEL  --
-----------------------------------------------------------------------------------------------------------------------------------
function CreateChannel(chanNum,color,fxColor)
    local channel = {}
    channel.color = color
    channel.fxColor = fxColor

    local xpos = ((chanNum - 1) * chanW) + leftPad

    channel.bkgd = GUI.createElement({
        type = "Frame",
        name = 'bkgd'..chanNum,
        x = xpos, y = fxOffset, h = chanH +  meterH + (btnH * 5), w = chanW,
        bg = color,
        color = 'black',
    })
    bkgdLayer:addElements(channel.bkgd)
    ------------------------------------------------------------------------------------------------------
    --------------------------------------------------------SEND------------------------------------------
    channel.sendBg = GUI.createElement({
        type = "Frame",
        name = 'fxbg'..chanNum,
        x = xpos, y = fxOffset, h = (btnH * 4) + 2, w = 40,
        bg = fxColor,
        color = 'black',
    })
    fxbkgdLayer:addElements(channel.sendBg)

    channel.fxLabel = GUI.createElement ({
        type = "MLabel",
        vertical = true,
        caption = testNames[chanNum],
        name = 'fxLabel'..chanNum,
        font = {'Calibri', 18,"b"},
        w = Scale(150), h = Scale(30),
        x = xpos + 8, y = fxOffset,

    })
    titleLayer:addElements(channel.fxLabel)

    channel.send = GUI.createElement({
        frames = 72,horizontal = false,
        --horizFrames = true,
        --vertText = true,
        name = "Send"..chanNum,
        min = 0,
        max = 99,
        value = 0,
        type = "MSlider",
        w = leftW,h = btnH * 4,x = xpos,y = fxOffset,
        labelX = 0,labelY = 0,
        image = ifl.."Send.png",
        func = function(self, a, b, c) end,
        color = fxColor
    })
    sliderLayer:addElements(channel.send)

    channel.semi = GUI.createElement({
        name = 'semi'..chanNum,
        type = "MButton",
        displayOnly = true,
        wrap = false,
        w = 14, h = 66,
        x = xpos + 45, y = fxOffset,
        color = nil,
        frames = 15,
        min = -7, max = 7,
        value= 0,
        image = ifl..'Semi.png',

    })
    controlLayer:addElements(channel.semi)

    channel.octave = GUI.createElement({
        name = 'oct'..chanNum,
        type = "MButton",
        displayOnly = true,
        wrap = false,
        w = 14, h = 66,
        x = xpos + 45, y = fxOffset + 72,
        color = nil,
        frames = 11,
        min = -5, max = 5,
        value= 0,
        image = ifl..'Oct.png',

    })
    controlLayer:addElements(channel.octave)

    ------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------SPINNERS-------------------------------------------
    channel.mixSpinIcons = {'Spinner','Spinner'}
    channel.spinFuncs = {}
    channel.spinFuncs[2] = function(self)
                                channel.octave:val(self:val())
                                if self.value ~= 0 then self.caption = self.value else self.caption = '' end
                            end
    channel.mixSpinners = {}
    for slotNum,icon in pairs(channel.mixSpinIcons) do
        channel.mixSpinners[slotNum] = GUI.createElement({
            name = slotNum..icon..chanNum,
            type = "MButton",
            spinner = true, wrap = false,
            labelY = -.02,
            w = 44, h = 72,
            x = xpos + leftW, y = (btnH * (slotNum - 1) * 2) + fxOffset,
            color = nil,
            frames = 1,
            min = -5,max = 5,
            value= 0,
            image = ifl..icon..'.png',
            func = channel.spinFuncs[slotNum],
        })
        titleLayer:addElements(channel.mixSpinners[slotNum])
     end

    channel.mixSpinners[1].min = 1

    ------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------METERS-------------------------------------------

    channel.meterIcons = {'Pan','MeterL','MeterR'}
    channel.meterFuncs = {}
    channel.meterCtls = {}
    for slotNum,icon in pairs(channel.meterIcons) do
        channel.meterCtls[slotNum] = GUI.createElement ({
            type = "MSlider",
            --displayOnly = true,
            name = icon..chanNum,
            image = ifl..icon..'.png',
            frames = 25, --frame = math.random(25),
            horizontal = true,
            min = 0, max = 1, value = 0,
            w = chanW, h = 6, x = xpos, y = volOffset - 12,
            func = channel.meterFuncs[slotNum],
        })
    end
    channel.meterCtls[MTR.PAN].h = 12
    channel.meterCtls[MTR.PAN].displayOnly = false
    controlLayer:addElements(channel.meterCtls[MTR.PAN])

    channel.meterCtls[MTR.R_METER].y = volOffset - 6
    sliderLayer:addElements(channel.meterCtls[MTR.L_METER])
    sliderLayer:addElements(channel.meterCtls[MTR.R_METER])
    -------------------------------------------------------------------------------------------------------
    -------------------------------------------------------INDICATORS--------------------------------------
    local indH, indW, indX = 18, 18, 32

    channel.indicatorIcons = {'Solo','MuteFX','Empty','Hands','Empty','Encoders','Switches1','Switches2','Drawbars','Empty'}
    channel.indicators = {}
    for slotNum, icon in pairs(channel.indicatorIcons) do
        if icon ~= 'Empty' then
            channel.indicators[slotNum] = GUI.createElement({
                type = "MButton", name = slotNum..icon..chanNum,
                x = xpos + indX, y = (indH * (slotNum - 1)) + volOffset + 10, w = indW, h = indH,
                displayOnly = false, image = ifl..icon..'.png',
                min = 0, max = 1, value = 0, frames = 2,
            })
            controlLayer:addElements(channel.indicators[slotNum])
        end
    end

    -------------------------------------------------------------------------------------------------------
    --------------------------------------------------------VOLUME-----------------------------------------

    channel.presetName = GUI.createElement ({
        type = "MLabel",
        vertical = true,
        caption = testNames[chanNum],
        name = 'instLabel'..chanNum,
        w = Scale(150), h = Scale(30),
        x = xpos + 4, y = volOffset + 72,
    })
    titleLayer:addElements(channel.presetName)

    channel.volume = GUI.createElement({
        frames = 108,horizontal = false,
        --horizFrames = true,
        --vertText = true,
        name = "volume"..chanNum,
        min = 0,
        max = 99,
        value = 0,
        type = "MSlider",
        w = leftW,h = btnH * 6,x = xpos,y = volOffset,
        labelX = 0,labelY = 0,
        image = ifl.."Volume.png",
    })
    sliderLayer:addElements(channel.volume)
    ------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------BUTTONS-------------------------------------------

    channel.mixIcons = {'NoSus','Hold','Breath','Ped2','Exp','Enable','Select','NoteSource'}
    channel.mixFuncs = {} 
    --Channel select
    channel.mixFuncs[MIX.SELECT] = function(self) setDetailChannel(self.chan) end
    channel.mixCtls = {}
    for slotNum,icon in pairs(channel.mixIcons) do
        channel.mixCtls[slotNum] = GUI.createElement({
            name = icon..chanNum,
            type = "MButton",
            w = rightW, h = btnH,
            x = xpos + leftW, y = (btnH * (slotNum - 1)) + volOffset,
            color = nil,
            frames = 2,
            vals = {0,1},
            value= 0,
            image = ifl..icon..'.png',
            func = channel.mixFuncs[slotNum],
            chan = chanNum,
        })
        controlLayer:addElements(channel.mixCtls[slotNum])
    end
    --enable
    channel.mixCtls[MIX.ENABLE].vals = {0,1,2,3}
    channel.mixCtls[MIX.ENABLE].frames = 4
    --notesource
    channel.mixCtls[MIX.SOURCE].vals = {0,1,2}
    channel.mixCtls[MIX.SOURCE].frames = 3
    channel.mixCtls[MIX.SOURCE].x = xpos
    channel.mixCtls[MIX.SOURCE].y = (btnH * 6) + volOffset
    channel.mixCtls[MIX.SOURCE].w = leftW

    return channel
end

function setDetailChannel(chanNum)
    Current = chanNum
    M.Msg("IN SET DETAIL,SLOT: "..chanNum)
    local chan = Channels[chanNum]
    for i = 1,ChannelCount do
        Channels[i].mixCtls[7]:val(0)
        Channels[i].bkgd.h = chanH +  meterH + 4 + (btnH * 4)
        Channels[i].bkgd:redraw()
    end
    chan.mixCtls[MIX.SELECT]:val(1)
    chan.bkgd.h = chanH + meterH + (btnH * 8)
    chan.bkgd:redraw()
    PresetPanel:setColor(chan.color)
    ParamPanel:setColor(chan.color)
    setInspectorColor(chan.color)
end

SetBackdrop()
for i = 1,ChannelCount do
    Channels[i] = CreateChannel(i,RandomColor(50),RandomColor(60))
end

------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
    name = "CHANNEL",
    w = 1020,
    h = 980,
    x = -12,
    y = 0
  })

  ------------------------------------
  -------- GUI Elements --------------
  ------------------------------------

  window:addLayers(sliderLayer,titleLayer,bkgdLayer,fxbkgdLayer,controlLayer,backdropLayer)
  window:open()

  GUI.Main()