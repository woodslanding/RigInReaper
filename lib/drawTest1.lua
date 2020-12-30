local CENTER_H = 1
local CENTER_V = 4

-------------------------------------------------------
function rotate_text(Ptext, Pdegrees, PdestX, PdestY,w,h, centerX,centerY)
-- -------------------------------------------------------
--local strW, strH, Ldim, degtorad

    degtorad = 1 / 360 * 2 * 3.14159
    save_gfxr = gfx.r; save_gfxg = gfx.g; save_gfxb = gfx.b

    gfx.r = 30/256; gfx.g = 30/256; gfx.b = 50/256  -- background colour, for the off-screen buffer
    strW, strH = gfx.measurestr(Ptext)  -- get the length of the string , in pixels
    playX, playY = (w - strH)/2, (h - strW)/2
    adjX = math.max(playX * centerX, 0)
    --reaper.ShowConsoleMsg('strW, strH = '..strW..', '..strH..'\n')
    adjY = math.max(playY * centerY, 0)
--    strW = math.max(strW, 19)
    Ldim = math.max(w, h)     -- get the larger, add 1 for safety

    gfx.dest=127;                   -- draw to off-screen buffer
    gfx.setimgdim(127, -1, -1)      -- clear the buffer
    gfx.setimgdim(127, Ldim, Ldim)  -- sets its size
    gfx.rect(0,0, Ldim, Ldim)       -- set the bg colour, for improved anti-aliasing

    gfx.a = 0.90
    gfx.r = save_gfxr; gfx.g = save_gfxg; gfx.b = save_gfxb -- set the text colour

    --gfx.x = strW/2
    --gfx.y = (w/2) + strH + strH/2;                 -- position in the middle of the buffer
    --gfx.x = 0
    --gfx.y = 0
    gfx.x = (h/2) - (strW/2)
    gfx.y = w --- (strH)/2
    gfx.printf("%s", Ptext)

    gfx.dest=-1;                           -- switch back to on-screen
    gfx.mode = 0 +1-1 + 2 +4               -- blend mode (1) deactivated, disable source alpha (2),
                                           -- disable filtering (4)

    gfx.blit(127, 1,      --0,
    Pdegrees * degtorad,  -- source, scale, rotation (in radians) [,
             0,      strW/2, Ldim, Ldim,  -- srcx, srcy, srcw, srch,
             PdestX, PdestY,  Ldim, Ldim,  -- destx, desty, destw, desth,
             0, 0)                         -- rotxoffs, rotyoffs])

end -- of function

function loop()
    x = 0
    y = 0
    w = 40
    h = 150
    gfx.x = 0
    gfx.rect(x,y,w,h)
    --gfx.drawstr("Hello World!", CENTER_H | CENTER_V, gfx.w, gfx.h)
    rotate_text('hello world',270,x,y,w,h, 1,0)
    if gfx.getchar() >= 0 then
      reaper.defer(loop)
    end
end

function run(x,y,w,h,text)
    --gfx.set(0);
    --gfx.rect(x,y,w,h)
    strW, strH = gfx.measurestr(text)

    -- draw a gradient for demonstration purposes
    gfx.gradrect(0,0,gfx.w,40,
        0,0,0,1,
        1/gfx.w, .2/gfx.w, 0, 0,0,
        0,1/40,0,0)
        gfx.dest=127;                   -- draw to off-screen buffer
        gfx.setimgdim(127, -1, -1)      -- clear the buffer
        gfx.setimgdim(127, w, h)  -- sets its size

    gfx.transformblit(127, -- source image
            0,0, w,h, -- output x/y/w/h
            2,2, -- 2x2 table below:
            {  -- gfx.transformblit takes a table of coordinates
                w,0, -- source coordinates of top left
                h,w, -- source coordinates of top right
                0,0, -- source coordinates of bottom left
                0,h,-- source coordinates of bottom right
            }
            )

    gfx.update();

    reaper.defer(run);

    end

     -- gfx.init("test",800,800);


  gfx.init("", 400, 300)
  gfx.setfont(1, "sans-serif", 24)
  gfx.r, gfx.g, gfx.b = 1, 1, 1
  --loop()
  reaper.defer(run(0,0,40,200,'TESTING TEXT'));