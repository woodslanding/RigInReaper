local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local height = 400
local width = 600

local window = GUI.createWindow({
  name = "Default Parameters",
  w = width,
  h = height,
})

function SetLabels(labels)

end

function UpdateButtons(rowCount,colCount,height,width,names)   
    local layer = GUI.createLayer({name = "Buttons"})
    local button = nil
    local index,xpos = 0,0,0
    for col = 0,colCount - 1 do
        local ypos = 0
        for row = 0,rowCount - 1 do
            button = GUI.createElements( {
                name = "button_"..index,
                type = "Button",
                x = xpos,
                w = width/colCount,
                y= ypos,
                h = height/rowCount,
                caption = names[index] or '---'
            })
            layer:addElements(button)
            reaper.ShowConsoleMsg('adding button '..button.name..'\n')
            ypos = ypos + height/rowCount
            index = index + 1
        end
        xpos = xpos + width/colCount
    end
    return layer
end


local layer = UpdateButtons(8,4,height*.8, width,{"test1","test2","test3","test4"})
window:addLayers(layer)
window:open()

GUI.Main()
