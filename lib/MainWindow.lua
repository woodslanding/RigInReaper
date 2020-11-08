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

local controlLayer = GUI.createLayer({name = "ctlLayer", z = 1})
local titleLayer = GUI.createLayer({name = "titleLayer", z = 2})
local sliderLayer = GUI.createLayer({name = "sliderLayer", z = 3})
local bkgdLayer = GUI.createLayer({name = "bkgdLayer", z = 4})
local backdropLayer = GUI.createLayer({name = "backdropLayer", z = 5})

local ChannelCount = 2
local Channels = {}

local ifl = IMAGE_FOLDER  --from MoonUtilities
local leftPad = 4
local scaling = .8
local function randomColor()
    return GetRGB(math.random(360),100-(math.random(10) * math.random(10)),50)
end


local function fakeOptions(panel)
    for i = 1,250 do
        panel.options[i] = {
            name = i..'-'..math.random(1111111,9999999),
            val = 0
        }
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

--
function CreateParams()
    local rows, cols, w, h = 4, 8, 96 , 32
    local params = MButtonPanel.new(ifl.."Combo.png",controlLayer,rows,cols,
                                192,240,w,h,       --button
                                192,200,96,32) --spinner
    fakeOptions(params)
    params.multi = true
    params.pager.image = ifl.."Combo.png"
    params:setPage(1)
    params:setColor(randomColor())
    return params
end
--TODO: need a means to store and recall the selection values for each channel
function CreatePresets()
    local rows, cols = 5,8
    local w, h = 96, 36
    local presets = MButtonPanel.new(ifl.."Combo.png",sliderLayer,rows,cols,
                                leftPad,0,w,h,       --button
                                (w * cols) + 8,0,44,72) --spinner
    fakeOptions(presets)
    presets.pager.image = ifl.."EffectSpin.png"
    presets:setPage(1)
    presets:setColor(randomColor())
    return presets
end

PresetPanel = CreatePresets()
ParamPanel = CreateParams()--]]

Channels = {}
-----------------------------------------------------------------------------------------------------------------------------------
                                          --    CREATE   --
                                          --    CHANNEL  --
-----------------------------------------------------------------------------------------------------------------------------------
function CreateChannel(chanNum,color,fxColor)
    local channel = {}
    local fxOffset = 390
    local btnH = 36
    local meterH = 12
    local volOffset = fxOffset + (btnH * 4) + meterH
    local chanW = 96
    local chanH = (btnH * 6)
    local xpos = ((chanNum - 1) * chanW) + leftPad
    local leftW = 52
    local rightW = 44

    channel.color = color
    channel.fxColor = fxColor
    ------------------------------------------------------------------------------------------------------
    --------------------------------------------------------SEND------------------------------------------
    channel.sendBg = GUI.createElement({
        type = "Frame",
        name = 'fxbg'..chanNum,
        x = xpos, y = fxOffset, h = btnH * 4, w = chanW,
        bg = fxColor,
        color = 'black',
        
    })
    bkgdLayer:addElements(channel.sendBg)

    channel.fxLabel = GUI.createElement ({
        type = "MLabel",
        vertical = true,
        caption = testNames[chanNum],
        name = 'fxLabel'..chanNum,
        font = {'Calibri', 18,"b"},
        w = Scale(150), h = Scale(30),
        x = xpos + 8, y = fxOffset + 10,
        
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
        
    })
    sliderLayer:addElements(channel.send)

    channel.octave = GUI.createElement({
            name = 'oct'..chanNum,
            type = "MButton",
            displayOnly = true,
            w = 16, h = 66,
            x = xpos +38, y = fxOffset + 72,
            color = nil,
            frames = 11,
            min = -5, max = 5,
            value= 0,
            image = ifl..'oct'..'.png',
            
        })
    titleLayer:addElements(channel.octave)
    ------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------SPINNERS-------------------------------------------
    channel.mixSpinIcons = {'EffectSpin','OctaveSpin'}
    channel.spinFuncs = {}
    channel.spinFuncs[2] = function(self) channel.octave:val(self:val()) end
    channel.mixSpinners = {}
    for slotNum,icon in pairs(channel.mixSpinIcons) do
        channel.mixSpinners[slotNum] = GUI.createElement({
            name = icon..chanNum,
            type = "MButton",
            spinner = true, loop = false,
            w = 44, h = 72,
            x = xpos + leftW, y = (btnH * (slotNum - 1) * 2) + fxOffset,
            color = nil,
            frames = 1,
            min = -5,max = 5,
            value= 0,
            image = ifl..icon..'.png',
            func = channel.spinFuncs[slotNum],
            
        })
        controlLayer:addElements(channel.mixSpinners[slotNum])
     end

    channel.mixSpinners[1].min = -7
    channel.mixSpinners[1].max = 7

    ------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------METERS-------------------------------------------
    channel.meterIcons = {'Pan','MeterL','MeterR'}
    channel.meterFuncs = {}
    channel.meterCtls = {}
    for slotNum,icon in pairs(channel.meterIcons) do
        channel.meterCtls[slotNum] = GUI.createElement ({
            type = "MSlider",
            displayOnly = true,
            name = icon..chanNum,
            image = ifl..icon..'.png',
            frames = 25, frame = math.random(25),
            horizontal = true,
            min = 0, max = 1, value = 0,
            w = chanW, h = 6, x = xpos, y = volOffset - 12,
            func = channel.meterFuncs[slotNum],
            
        })
    end
    channel.meterCtls[1].h = 12
    channel.meterCtls[1].displayOnly = false
    --pan
    controlLayer:addElements(channel.meterCtls[1])
    --meters
    channel.meterCtls[3].y = volOffset - 6
    sliderLayer:addElements(channel.meterCtls[2])
    sliderLayer:addElements(channel.meterCtls[3])
    -------------------------------------------------------------------------------------------------------
    --------------------------------------------------------VOLUME-----------------------------------------
    channel.bkgd = GUI.createElement({
        type = "Frame",
        name = 'bkgd'..chanNum,
        x = xpos, y = volOffset - meterH, h = chanH + meterH + 4, w = chanW,
        bg = color,
        color = 'black',
        
    })
    bkgdLayer:addElements(channel.bkgd)

    channel.label = GUI.createElement ({
        type = "MLabel",
        vertical = true,
        caption = testNames[chanNum],
        name = 'instLabel'..chanNum,
        w = Scale(150), h = Scale(30),
        x = xpos + 4, y = volOffset + 10,
        
    })
    titleLayer:addElements(channel.label)

    channel.slider = GUI.createElement({
        frames = 108,horizontal = false,
        --horizFrames = true,
        --vertText = true,
        name = "slider"..chanNum,
        min = 0,
        max = 99,
        value = 0,
        type = "MSlider",
        w = leftW,h = btnH * 6,x = xpos,y = volOffset,
        labelX = 0,labelY = 0,
        image = ifl.."Volume.png",
        
    })
    sliderLayer:addElements(channel.slider)
    ------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------BUTTONS-------------------------------------------
    channel.mixIcons = {'NoSus','Hold','Breath','Ped2','Exp','Enable','Select','Notesource'}
    channel.mixFuncs = {}
    channel.mixFuncs[7] = function(self)
        M.Msg('setting value of select to ch'..chanNum)
        for i = 1,ChannelCount do
            Channels[i].mixCtls[7]:val(0)
        end
        self:val(1)
        PresetPanel:setColor(channel.color)
    end
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
            
        })
        controlLayer:addElements(channel.mixCtls[slotNum])
    end
    --enable
    channel.mixCtls[6].vals = {0,1,2,3}
    channel.mixCtls[6].frames = 4
    --notesource
    channel.mixCtls[8].vals = {0,1,2}
    channel.mixCtls[8].frames = 3
    channel.mixCtls[8].x = xpos
    channel.mixCtls[8].y = (btnH * 6) + volOffset
    channel.mixCtls[8].w = leftW

    return channel
end

SetBackdrop()
for i = 1,ChannelCount do
    Channels[i] = CreateChannel(i,randomColor(),randomColor())
    --M.Msg('creating channel'..i)
end




------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
    name = "CHANNEL",
    w = 960,
    h = 980,
    x = -12,
    y = 0
  })

  ------------------------------------
  -------- GUI Elements --------------
  ------------------------------------

  window:addLayers(sliderLayer,titleLayer,bkgdLayer,controlLayer,backdropLayer)
  window:open()

  GUI.Main()