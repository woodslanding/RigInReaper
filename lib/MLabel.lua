--------------------------MLABEL----------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local Buffer = require("public.buffer")
local Font = require("public.font")
local Color = require("public.color")
local Text = require("public.text")
local Element = require("gui.element")

local font = {'Calibri', 28,"b"}
local lenX,lenY, origW

local MLabel = Element:new()
MLabel.__index = MLabel
MLabel.defaultProps = {
    name = "label",
    type = "MLabel",
    shadow = true,
    x = 0,
    y = 0,
    w = 100,
    h = 40,
    textW = 0,
    textH = 0,
    caption = "MLabel",
    font = font,
    color =   "text",
    bg =      "cyan",
    justify = 0  -- 0 for left, 1 for right
}

function MLabel:new(props)
  local label = self:addDefaultProps(props)

  return setmetatable(label, self)
end

function MLabel:containsPoint (x, y)
    return false
end

function MLabel:init()

    -- We can't do font measurements without an open window
    if gfx.w == 0 then return end

    self.buffers = self.buffers or Buffer.get(2)

    Font.set(self.font)

    local output = self:formatOutput(self.caption)
    --self.origW = self.w
    self.textW, self.textH = gfx.measurestr(output)

    local w, h = self.textW + 4, self.textH + 4
    lenX,lenY = w,h
    if self.vertical then 
        self.lenX = math.max(w,h)
        self.lenY = lenX
    end

    -- Because we might be doing this mid-Draw,
    -- make sure we put this back the way we found it
    local dest = gfx.dest
    
    gfx.dest = self.buffers[1]
    gfx.setimgdim(self.buffers[1], -1, -1)
    gfx.setimgdim(self.buffers[1], w, h)

    -- Text + shadow
    gfx.dest = self.buffers[2]
    gfx.setimgdim(self.buffers[2], -1, -1)
    gfx.setimgdim(self.buffers[2], self.lenX, self.lenY)

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

    --subtract text width to left-justify
    local just = self.textW * (1 - self.justify)
    if self.vertical then gfx.x, gfx.y = self.x - 2, self.y + self.w - just
    else gfx.x, gfx.y = self.x - 2, self.y -2 end

    gfx.a = 1

    -- Text
    if self.vertical then
            gfx.blit(self.buffers[2], 1, math.rad(-90)
            )
    else gfx.blit(self.buffers[2], 1, 0)
        gfx.a = 1
    end
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
