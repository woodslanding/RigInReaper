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

local function fakeOptions(panel)
    for i = 1,250 do
        panel.options[i] = {  name = 'option'..i..'-'..math.random(111,999), val = 0 }
    end
end

function CreateParams()
    local rows, cols, w, h = 4, 8, 96 , 32
    local params = MButtonPanel.new(ifl.."Combo.png",controlLayer,rows,cols,
                                192,240,w,h,       --button
                                192,200,96,32) --spinner
    fakeOptions(params)
    params.multi = true
    params.pager.image = ifl.."Combo.png"
    params:setPage(1)
    params:setColor(RandomColor(40))
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
    presets:setColor(RandomColor())
    return presets
end



------------------------------------
---------------- MAIN --------------
------------------------------------
CreateParams()
CreatePresets()
local window = GUI.createWindow({
    name = "RIG",
    w = 960, h = 980, x = -12, y = 0
  })
  window:addLayers(sliderLayer,titleLayer,bkgdLayer,controlLayer,backdropLayer)
  window:open()
  GUI.Main()

  Fullscreen("RIG")