------------------------------------------------------
--[[gfx.transformblit(127, -- source image
0,h, h,w, -- output x/y/w/h
2,2, -- 2x2 table below:
{  -- gfx.transformblit takes a table of coordinates
    w,0, -- source coordinates of top left
    h,w, -- source coordinates of top right
    0,0, -- source coordinates of bottom left
    0,h,-- source coordinates of bottom right
}
)--]]
-------------------------------------------------------
 --if center is true, then offsets are +- % of available space.  If not, offsets are pixels from lower left
function rotate_text(text, x, y, w, h, center, offsX, offsY )
    gfx.x = 0
    gfx.y = 0
    save_gfxr = gfx.r; save_gfxg = gfx.g; save_gfxb = gfx.b  --text color

    gfx.r = 30/256; gfx.g = 30/256; gfx.b = 70/256  -- background colour, for the off-screen buffer
    strW, strH = gfx.measurestr(text)  -- in pixels
    playX, playY = (h - strW)/2, (w - strH)/2
    if center then
      xpos = playX + (playX * offsX)
      ypos = playY + (playY * offsY)
    else
      xpos = offsY
      ypos = offsX
    end

    gfx.dest=127;                   -- draw to off-screen buffer
    gfx.setimgdim(127, -1, -1)      -- clear the buffer
    gfx.setimgdim(127, h + 1, w)  -- sets its size.  For some reason it's a pixel small in one direction
    gfx.rect(0,0, h, w)           -- set the bg colour, for improved anti-aliasing

    gfx.a = 1
    gfx.r = save_gfxr; gfx.g = save_gfxg; gfx.b = save_gfxb -- set the text colour

    gfx.x = xpos
    gfx.y = ypos

    gfx.printf("%s", text)

    gfx.dest=-1;                           -- switch back to on-screen
    gfx.mode = 0 +1-1 + 2 +4               -- blend mode (1) deactivated, disable source alpha (2),
    gfx.transformblit(127,  x,y, w, h, 2,2,  { h,0,  h,w,  0,0,  0,w, } )

end

function loop()
    x = 100
    y = 50
    w = 80
    h = 150
    adjX, adjY = 0,4
    gfx.x = 0
    gfx.y = 0
    gfx.rect(x,y,w,h)  --white reference rectangle
    rotate_text('hello world',x,y,w,h, false, adjX,adjY)
    if gfx.getchar() >= 0 then
      reaper.defer(loop)
    end
end

gfx.init("", 400, 300)
gfx.setfont(1, "sans-serif", 24)
gfx.r, gfx.g, gfx.b = 1, 1, 1
loop()
