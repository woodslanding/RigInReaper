--[[11 x 48 = 528 --channels

1080-36 = 1044  --titleLayer bar
-528            --channels
= 516           --for buttons

44 x 6 = 264   --six preset button rows

516 - 264 = 252  --left

44 x 5 = 220  -- five control button rows
]]
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
local Theme = require("gui.theme")


Theme.fonts[2] = {'Calibri', 28,"b"}

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

local mainLayer = GUI.createLayer({name = "mainLayer", z = 2})
local titleLayer = GUI.createLayer({name = "titleLayer", z = 1})
local bkgdLayer = GUI.createLayer({name = "bkgdLayer", z = 3})

local yOffset = 500
Channels = {}
Bkgds = {}
local scaling = .8
local testNames = {'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings',
                    'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings',
                    'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings',
                    'Ships Piano','Showdown','Large Sliver Globes', 'Lush Strings'}

function Scale(val)
    return Math.round(val * scaling)
end

function CreateChannel(chanNum,color)

    local chanW = Scale(120)
    local chanH = Scale(528)
    local xpos = (chanNum - 1) * chanW
    local leftW = Scale(64) local rightW = Scale(56)
    local btnH = Scale(48)

    local bkgd = GUI.createElement({
        type = "Frame",
        name = 'bkgd'..chanNum,
        x = xpos, y = yOffset, h = chanH, w = chanW,
        bg = color
    })
    Bkgds[chanNum] = bkgd
    bkgdLayer:addElements(bkgd)

    local label = GUI.createElement ({
        type = "MLabel",
        vertical = true,
        caption = testNames[chanNum],
        name = 'testLabel'..chanNum,
        w = Scale(150), h = Scale(30),
        x = xpos + 6, y = yOffset
    })
    titleLayer:addElements(label)

    local slider = GUI.createElement({
        frames = 144,horizontal = false,
        --horizFrames = true,
        --vertText = true,
        name = "slider"..chanNum,
        min = 0,
        max = 99,
        value = 0,
        type = "MSlider",
        w = leftW,h = Scale(288),x = xpos,y = yOffset,
        labelX = 0,labelY = 0,
        --image =  "meterL.png",
        image = "VolVert.png",
        func = function(self, a, b, c) Msg(self.name, self:val()) end,
        params = {"a", "b", "c"}
    })
    mainLayer:addElements(slider)


    local mixIcons = {'NoSus','Hold','Breath','Ped2','Exp','Enable'}
    local mixFuncs = {}
    local mixCtls = {}
    for slotNum,icon in pairs(mixIcons) do
        mixCtls[slotNum] = GUI.createElement({
            name = icon..chanNum,
            type = "MButton",
            w = rightW, h = btnH,
            x = xpos + leftW, y = (btnH * (slotNum - 1)) + yOffset,
            color = nil,
            frames = 2,
            vals = {0,1},
            value= 0,
            image = icon..'.png',
            func = mixFuncs[slotNum],
        })
        mainLayer:addElements(mixCtls[slotNum])
    end

    mixCtls[6].vals = {0,1,2,3}
    mixCtls[6].frames = 4
end

for i = 1,16 do
    CreateChannel(i,GetRGB(i * 130,100,50))
    --MSG('creating channel'..i)
end




------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
    name = "CHANNEL",
    w = 1920,
    h = 1000,
    x = -12,
    y = 0
  })

  ------------------------------------
  -------- GUI Elements --------------
  ------------------------------------



  window:addLayers(mainLayer,titleLayer,bkgdLayer)
  window:open()

  GUI.Main()