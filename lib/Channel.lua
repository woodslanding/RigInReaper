--[[11 x 48 = 528 --channels

1080-36 = 1044  --title bar
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
local floor = 0

local slider = GUI.createElement({
    frames = 144,horizontal = false,
    --horizFrames = true,
    --vertText = true,
    name = "slider",
    min = 0,
    max = 99,
    value = 0,
    type = "MSlider",
    w = 64,h = 288,x = 0,y = 200,
    labelX = 0,labelY = 0,
    --image =  "meterL.png",
    image = "VolVert.png",
    func = function(self, a, b, c) Msg(self.name, self:val()) end,
    params = {"a", "b", "c"}
})

local label = GUI.createElement ({
    type = "MLabel",
    vertical = true,
    caption = 'Ships Piano',
    name = 'testLabel',
    w = 150, h = 30,
    x = 6, y = 250
})
local noSus = GUI.createElement({
    name = "nosus",
    type = "MButton",
    w = 56,h = 48,
    x = 64,y = 200,
    color = nil,
    wrap = true,
    frames = 2,
    vals = {0,1},
    value = 0,
    image =  "NoSus.png",
    func = function(self)  end,
    params = {"a", "b", "c"}
})
local hold = GUI.createElement({
    name = "hold",
    type = "MButton",
    w = 56,h = 48,
    x = 64,y = 248,
    color = nil,
    wrap = true,
    frames = 2,
    vals = {0,1},
    value = 0,
    image =  "Hold.png",
    func = function(self)  end,
    params = {"a", "b", "c"}
})
local bc = GUI.createElement({
    name = "breath",
    type = "MButton",
    w = 56,h = 48,
    x = 64,y = 296,
    color = nil,
    wrap = true,
    frames = 2,
    vals = {0,1},
    value = 0,
    image =  "Breath.png",
    func = function(self)  end,
    params = {"a", "b", "c"}
})
local ped2 = GUI.createElement({
    name = "ped2",
    type = "MButton",
    w = 56,h = 48,
    x = 64,y = 344,
    color = nil,
    wrap = true,
    frames = 2,
    vals = {0,1},
    value = 0,
    image =  "Ped2.png",
    func = function(self)  end,
    params = {"a", "b", "c"}
})
local exp = GUI.createElement({
    name = "exp",
    type = "MButton",
    w = 56,h = 48,
    x = 64,y = 392,
    color = nil,
    wrap = true,
    frames = 2,
    vals = {0,1},
    value = 0,
    image =  "Exp.png",
    func = function(self)  end,
    params = {"a", "b", "c"}
})


------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
    name = "CHANNEL",
    w = 120,
    h = 528
  })
  
  ------------------------------------
  -------- GUI Elements --------------
  ------------------------------------
  
  local layer = GUI.createLayer({name = "Layer1", z = 2})
  local layer2 = GUI.createLayer({name = "Layer2", z = 1})
  
  layer:addElements(slider,noSus,bc,hold,ped2,exp)
  layer2:addElements(label)
  window:addLayers(layer)
  window:addLayers(layer2)
  window:open()
  
  GUI.Main()