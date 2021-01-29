local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")

------------------------------------
-------- Window settings -----------
------------------------------------
SCREEN_WIDTH = 1920
SCREEN_HEIGHT = 1280


function Fullscreen(window, off)
    local title = window.name
    local win = reaper.JS_Window_Find(title, true)
    if not off then
        local style = reaper.JS_Window_GetLong(win, 'STYLE')
        if style then
            style = style & (0xFFFFFFFF - 0x00C40000) --removes window frame
            reaper.JS_Window_SetLong(win, "STYLE", style)
        end
        reaper.JS_Window_SetPosition(win, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    else --need to figure out this code...
    end
end

local window = GUI.createWindow({
  name = "MButton Test",
  w = 1920,
  h = 1280
})
------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})

layer:addElements(GUI.createElement( {
    name = "close",
    type = "Button",
    caption = 'close',
    x = 10,
    w = 96,
    y= 10,
    h = 36,
    func = function() window:close() end
}))
layer:addElements(GUI.createElement( {
    name = "test",
    type = "Button",
    caption = 'large',
    x = 200,
    w = 300,
    y= 10,
    h = 1000,
    func = function()  end
}))
window:addLayers(layer)
window:open()
Fullscreen(window)
GUI.Main()