function run()
  gfx.set(0);
  gfx.rect(0,0,gfx.w,gfx.h)

  -- draw a gradient for demonstration purposes
  gfx.gradrect(0,0,gfx.w,40,
     0,0,0,1,
     1/gfx.w, .2/gfx.w, 0, 0,0,
     0,1/40,0,0)

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