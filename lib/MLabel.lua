--------------------------MLABEL----------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

DEGREES_TO_RADIANS = 0.017453
local lenX,lenY

loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local Buffer = require("public.buffer")
local Font = require("public.font")
local Color = require("public.color")
local Text = require("public.text")

local Element = require("gui.element")

local MLabel = Element:new()
MLabel.__index = MLabel
MLabel.defaultProps = {
    name = "label",
    type = "MLabel",
    shadow = true,
    x = 0,
    y = 0,
    -- Placeholders; we'll get these at runtime
    w = 0,
    h = 0,

    caption = "MLabel",
    font =    1,
    color =   "text",
    bg =      "cyan",
}


function MLabel:new(props)
  local label = self:addDefaultProps(props)

  return setmetatable(label, self)
end


function MLabel:init()

    -- We can't do font measurements without an open window
    if gfx.w == 0 then return end

    self.buffers = self.buffers or Buffer.get(2)

    Font.set(self.font)

    local output = self:formatOutput(self.caption)
    self.w, self.h = gfx.measurestr(output)

    local w, h = self.w + 4, self.h + 4
    lenX,lenY = w,h
    if self.vertical then 
        lenX = math.max(w,h)
        lenY = lenX
    end

    -- Because we might be doing this mid-Draw,
    -- make sure we put this back the way we found it
    local dest = gfx.dest
    
    gfx.dest = self.buffers[1]
    gfx.setimgdim(self.buffers[1], -1, -1)
    gfx.setimgdim(self.buffers[1], w, h)

    --Color.set(self.bg)
    --gfx.rect(0, 0, self.w, self.h)

    -- Text + shadow
    gfx.dest = self.buffers[2]
    gfx.setimgdim(self.buffers[2], -1, -1)
    gfx.setimgdim(self.buffers[2], lenX, lenY)

    -- Text needs a background or the antialiasing will look like shit
    --Color.set(self.bg)
    --gfx.rect(0, 0, lenX, lenY)

    gfx.x, gfx.y = 2, 2

    Color.set(self.color)

    if self.shadow then
        Text.drawWithShadow(output, self.color, "black")
    else
        gfx.drawstr(output)
    end

    gfx.dest = dest
end


function MLabel:onDelete()
  Buffer.release(self.buffers)
end


function MLabel:draw()

    -- Font stuff doesn't work until we definitely have a gfx window
    if self.w == 0 then self:init() end

    gfx.x, gfx.y = self.x - 2, self.y - 2

    -- Background
    --gfx.blit(self.buffers[1], 1, 0)

    gfx.a = 1

    -- Text
    if self.vertical then
            gfx.blit(self.buffers[2], 1, math.rad(-90)
                --,0,      (lenX/2)-1, lenX, lenX  -- srcx, srcy, srcw, srch,
                --,self.x, self.y, lenX, lenX  -- destx, desty, destw, desth,
                --,0, 0
            )
    else gfx.blit(self.buffers[2], 1, 0)
    end
    --gfx.update()
    gfx.a = 1


    --[[temp_buf_num = 3
gfx.dest = temp_buf_num 
gfx.setimgdim(3, -1, -1)  -- reset buf
gfx.setimgdim(3, w, h)  -- define buffer size

-- draw something here

-- then use blit with source = temp_buf_num
-- dont forget to go back to default buffer (buffer you wanna blit to): gfx.dest = -1
]]

end

function MLabel:val(newval)

    if newval then
        self.caption = newval
        self:init()
        self:redraw()
    else
        return self.caption
    end

end

GUI.elementClasses.MLabel = MLabel
--[[
  local vLabel = GUI.createElement ({
      type = "MLabel",
      vertical = false,
      caption = 'testing horiz label',
      name = 'testVLabel',
      w = 150, h = 30,
      x = 0, y = 40
  })

  local label = GUI.createElement ({
    type = "MLabel",
    vertical = true,
    caption = 'testing vertical label',
    name = 'testLabel',
    w = 150, h = 30,
    x = 200, y = 40
})
------------------------------------
-------- Window settings -----------
------------------------------------


local window = GUI.createWindow({
name = "MLABEL TEST",
w = 500,
h = 400
})

------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})

layer:addElements(label,vLabel)
window:addLayers(layer)
window:open()

GUI.Main()--]]
