
function Rotate_text(Ptext, Pdegrees, PdestX, PdestY)

    DegToRad = 1 / 360 * 2 * 3.14159
    local save_gfxr = gfx.r
    local save_gfxg = gfx.g
    local save_gfxb = gfx.b

    gfx.r = 30/256; gfx.g = 30/256; gfx.b = 50/256  -- background colour, for the off-screen buffer
    LW, LH = gfx.measurestr(Ptext)  -- let the length of the string , in pixels
    --    LW = math.max(LW, 19)
    Ldim = math.max(LW, LH) +1      -- get the larger, add 1 for safety

    gfx.dest=127;                   -- draw to off-screen buffer
    gfx.setimgdim(127, -1, -1)      -- clear the buffer
    gfx.setimgdim(127, Ldim, Ldim)  -- sets its size
    gfx.rect(0,0, Ldim, Ldim)       -- set the bg colour, for improved anti-aliasing

    gfx.a = 0.90
    gfx.r = save_gfxr
    gfx.g = save_gfxg
    gfx.b = save_gfxb -- set the text colour

    gfx.x =0 
    gfx.y = LW/2                -- position in the middle of the buffer 
    gfx.printf("%s", Ptext)

    gfx.dest=-1                          -- switch back to on-screen
    gfx.mode = 0 +1-1 + 2 +4               -- blend mode (1) deactivated, disable source alpha (2), 
                                           -- disable filtering (4)

    gfx.blit(127, 1, Pdegrees * DegToRad,  -- source, scale, rotation (in radians) [, 
             0,      LW/2 -1, Ldim, Ldim,  -- srcx, srcy, srcw, srch, 
             PdestX, PdestY,  Ldim, Ldim,  -- destx, desty, destw, desth,
             0, 0)                         -- rotxoffs, rotyoffs])

end -- of function

--Justin's Solution:

function run() 
  gfx.set(0);
  gfx.rect(0,0,gfx.w,gfx.h)
  
  -- draw a gradient for demonstration purposes
  gfx.gradrect(0,0,gfx.w,40, 
     0,0,0,1, 
     1/gfx.w, .2/gfx.w, 0, 0,0,
     0,1/40,0,0)
     
  gfx.drawstr("TEST STRING")

  gfx.transformblit(-1, -- source image
         0,40, 40, 800, -- output x/y/w/h
         2,2, -- 2x2 table below:
         {  -- gfx.transformblit takes a table of coordinates
           800,0,  -- source coordinates of top left
           800,40, -- source coordinates of top right
           0,0, -- source coordinates of bottom left
           0,40 -- source coordinates of bottom right             
         }
         )

  gfx.update();

  reaper.defer(run);

end

gfx.init("test",800,800);
reaper.defer(run);