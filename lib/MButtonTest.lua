--
local imageFolder = reaper.GetResourcePath().."/Scripts/Images/"

-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'MButton'
require 'moonUtils'

loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local M = require("public.message")

local Element = require("gui.element")

local switches = {}
local function createSwitch(i)
    local switch = GUI.createElement({
        stateless = false,
        w = 80,h = 40,
        x = i * 80,y = 0,
        color = 'blue',
        wrap = true,
        frames = 3,
        vals = {1,2,3},
        value = 1,
        name = "switch"..i,
        type = "MButton",
        labelX = 0, labelY = 0,
        image =  imageFolder.."Notesource.png",
        func = function(self) M.Msg('setting track'..i.. 'to '..self.value) TrackName(i,"track "..self.value) end,
        params = {"a", "b", "c"}
    })
    switches[i] = switch
    return switch
end

function MSpinnerTest()
    local spinner = GUI.createElement({
        type = "MButton", spinner = true,
        name = 'spinner',
        color = 'red',
        w = 40,h = 80,
        x = 0,y = 200,
        wrap = true,
        frames = 1,
        caption = '1',
        value = 1,
        min = 1, max = 3,
        image = imageFolder.."EffectSpin.png",
        func = function(self) switches[1]:val(self.value) self.caption = self:val() M.Msg('function called:'..self.value) end,
    })
    return spinner
end
------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
  name = "MButton Test",
  w = 600,
  h = 500
})
------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})
for i = 1,8 do
    layer:addElements(createSwitch(i))
end
layer:addElements(MSpinnerTest())
window:addLayers(layer)
window:open()

GUI.Main()
--]]