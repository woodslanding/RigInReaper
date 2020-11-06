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


local leftPad = 4
local scaling = .8
local function randomColor()
    return GetRGB(math.random(360),100-(math.random(10) * math.random(10)),50)
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

Channels = {}
Bkgds = {}
-----------------------------------------------------------------------------------------------------------------------------------
                                          --    CREATE   --
                                          --    CHANNEL  --                                      
-----------------------------------------------------------------------------------------------------------------------------------
function CreateChannel(chanNum,color,fxColor)
    local fxOffset = 390
    local btnH = 36
    local meterH = 12
    local volOffset = fxOffset + (btnH * 4) + meterH
    local chanW = 96
    local chanH = (btnH * 6)
    local xpos = ((chanNum - 1) * chanW) + leftPad
    local leftW = 52
    local rightW = 44

    ------------------------------------------------------------------------------------------------------
    --------------------------------------------------------SEND------------------------------------------
    local sendBg = GUI.createElement({
        type = "Frame",
        name = 'fxbg'..chanNum,
        x = xpos, y = fxOffset, h = btnH * 4, w = chanW,
        bg = fxColor,
        color = 'black'
    })
    --Bkgds[chanNum] = sendBg
    bkgdLayer:addElements(sendBg)

    local fxLabel = GUI.createElement ({
        type = "MLabel",
        vertical = true,
        caption = testNames[chanNum],
        name = 'fxLabel'..chanNum,
        font = {'Calibri', 18,"b"},
        w = Scale(150), h = Scale(30),
        x = xpos + 8, y = fxOffset + 10
    })
    titleLayer:addElements(fxLabel)

    local send = GUI.createElement({
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
        image = "Send.png",
        func = function(self, a, b, c) end,
        params = {"a", "b", "c"}
    })
    sliderLayer:addElements(send)
    ------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------SPINNERS-------------------------------------------
    local mixSpinIcons = {'EffectSpin','OctaveSpin'}
    local spinFuncs = {}
    local mixSpinners = {}
    for slotNum,icon in pairs(mixSpinIcons) do
        mixSpinners[slotNum] = GUI.createElement({
            name = icon..chanNum,
            type = "MButton",
            spinner = true,
            w = 44, h = 72,
            x = xpos + leftW, y = (btnH * (slotNum - 1) * 2) + fxOffset,
            color = nil,
            frames = 1,
            min = -5,max = 5,
            value= 0,
            image = icon..'.png',
            func = spinFuncs[slotNum],
        })
        controlLayer:addElements(mixSpinners[slotNum])
    end

    mixSpinners[1].min = -7
    mixSpinners[1].max = 7
    ------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------METERS-------------------------------------------
    local meterIcons = {'Pan','MeterL','MeterR'}
    local meterFuncs = {}
    local meterCtls = {}
    for slotNum,icon in pairs(meterIcons) do
        meterCtls[slotNum] = GUI.createElement ({
            type = "MSlider",
            name = icon..chanNum,
            image = icon..'.png',
            frames = 25, frame = math.random(25),
            horizontal = true,
            min = 0, max = 1, value = 0,
            w = chanW, h = 6, x = xpos, y = volOffset - 12,
            func = meterFuncs[slotNum],
        })
    end
    meterCtls[1].h = 12
    --pan
    controlLayer:addElements(meterCtls[1])
    --meters
    meterCtls[3].y = volOffset - 6
    sliderLayer:addElements(meterCtls[2])
    sliderLayer:addElements(meterCtls[3])
    -------------------------------------------------------------------------------------------------------
    --------------------------------------------------------VOLUME-----------------------------------------
    local bkgd = GUI.createElement({
        type = "Frame",
        name = 'bkgd'..chanNum,
        x = xpos, y = volOffset - meterH, h = chanH + meterH + 4, w = chanW,
        bg = color,
        color = 'black'
    })
    bkgdLayer:addElements(bkgd)

    local label = GUI.createElement ({
        type = "MLabel",
        vertical = true,
        caption = testNames[chanNum],
        name = 'instLabel'..chanNum,
        w = Scale(150), h = Scale(30),
        x = xpos + 4, y = volOffset + 10
    })
    titleLayer:addElements(label)

    local slider = GUI.createElement({
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
        image = "Volume.png",
        func = function(self, a, b, c) end,
        params = {"a", "b", "c"}
    })
    sliderLayer:addElements(slider)
    ------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------BUTTONS-------------------------------------------
    local mixIcons = {'NoSus','Hold','Breath','Ped2','Exp','Enable','Select','Notesource'}
    local mixFuncs = {}
    local mixCtls = {}
    for slotNum,icon in pairs(mixIcons) do
        mixCtls[slotNum] = GUI.createElement({
            name = icon..chanNum,
            type = "MButton",
            w = rightW, h = btnH,
            x = xpos + leftW, y = (btnH * (slotNum - 1)) + volOffset,
            color = nil,
            frames = 2,
            vals = {0,1},
            value= 0,
            image = icon..'.png',
            func = mixFuncs[slotNum],
        })
        controlLayer:addElements(mixCtls[slotNum])
    end
    --enable
    mixCtls[6].vals = {0,1,2,3}
    mixCtls[6].frames = 4
    --notesource
    mixCtls[8].vals = {0,1,2}
    mixCtls[8].frames = 3
    mixCtls[8].x = xpos
    mixCtls[8].y = (btnH * 6) + volOffset
    mixCtls[8].w = leftW
end

SetBackdrop()
for i = 1,16 do
    CreateChannel(i,randomColor(),randomColor())
    --M.Msg('creating channel'..i)
end




------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
    name = "CHANNEL",
    w = 1920,
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