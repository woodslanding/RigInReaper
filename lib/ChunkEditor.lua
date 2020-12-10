-- For binary:
-- DOS & Windows:   \r\n, 0D0A (hex), 13,10 (decimal) -- CR (возврат каретки) - LF (перевод строки)
-- Unix & Mac OS X:   \n, 0A (hex), 10 (decimal) -- LF (перевод строки)
-- По сути - "\n" канает на все, кроме древних маков
--==============================================================================
--[[Короче, в чанке идет тупо "\n", а не "\r\n". Этого достаточно, если делать чисто для чанка.
Никаких проблем быть не должно, просто расписать все красиво.
Позицию можно нормально найти только измеряя строку постепенно, остальные варианты не канают!
Поэтому, так и делать. На байты для клав. ввода можно не раскладывать - делать через sub, хотя...
Тоже самое происходит для текст. файла, если читать файл в "r", как текст, а не "rb"(бинарный)!
Это упрощает ситуацию, для бинарников все равно нужен был бы другой подход, можно забить.
ЭТО РЕАЛЬНО ВАЖНО, ЧТОБЫ НЕ ПОРОТЬСЯ ПОТОМ!!! --]]
--==============================================================================
--[[Короче говоря - самым простым и надежным решением будет такое:
1)Цепляем чанк, либо читаем файл в "r" mode, для файла построчно годится, сразу в таблицу.
2)Строится таблица строк, но без завершающих "\n", это все сходу упрощает!
3)Редактирование теперь становится простым и понятным, по крайней мере, без заумных расчетов.
4)Клеим таблицу с разделителем "\n", и в конец ставим "\n", все!
5)По итогу - все просто, логично и четко, даже для бинарников возможно сделать небольшой мод, но это не сейчас. --]]
--==============================================================================
--[[
 ЭТО ЧЕРНОВОЙ ВАРИАНТ!!!
 В данном варианте используются ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ(для упрощения).
 В конечном ванианте ОБЯЗАТЕЛЬНО пересмотреть все и упаковать как положено!!!
 --]]
--==============================================================================
------------------------------
-- TEST FILE -----------------
--FilePath = "C:\\Users\\EUGEN\\Desktop\\str_lines_test.txt" -- file for tests only!!!
------------------------------
------------------------------
--==============================================================================
local min, max = math.min, math.max
local ceil, floor = math.ceil, math.floor
------------------------------
function minmax(x, minv, maxv)
  return min(max(x, minv),maxv)
end
------------------------------
function round(x)
  if x < 0 then return ceil(x - 0.5) else return floor(x + 0.5) end
end
------------------------------
function round_to(x, step)
  if x < 0 then return ceil(x/step - 0.5)*step else return floor(x/step + 0.5)*step end
end
--==============================================================================
function pointIN(px, py, x,y,w,h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end
------------------------------
function mouseIN(x,y,w,h)
  return pointIN(gfx.mouse_x, gfx.mouse_y, x, y, w, h)
end
------------------------------
function mouseDown(x,y,w,h)
  return mouse_down and mouseIN(x,y,w,h)
end
------------------------------
function mouseUp(x,y,w,h)
  return mouse_up and mouseIN(x,y,w,h)
end
------------------------------
function mouseClick(x,y,w,h)
  return mouseUp(x,y,w,h) and pointIN(mouse_down_x, mouse_down_y, x,y,w,h)
end
--===========================================================================
function Button(x,y,w,h, lbl)
  gfx.set(1); gfx.rect(x,y,w,h)
  gfx.set(0.3); gfx.rect(x,y,w,h,0)
  gfx.x, gfx.y = x, y
  gfx.setfont(1,"Courier New",16)
  gfx.drawstr(lbl, 5, x+w, y+h)
  ------------
  return mouseDown(x,y,w,h) -- ret btn down
end
--==============================================================================
-- Get track chunk(allow > 4MB)
function GetTrackChunk(track)
  if not track then return end
  -- Try standart function -----
  local ret, track_chunk = reaper.GetTrackStateChunk(track, "", false) -- isundo = false
  if ret and track_chunk and #track_chunk < 4194303 then return track_chunk end
  -- If chunk_size >= max_size, use wdl fast string --
  local fast_str = reaper.SNM_CreateFastString("")
  if reaper.SNM_GetSetObjectState(track, fast_str, false, false) then
    track_chunk = reaper.SNM_GetFastString(fast_str)
  end
  reaper.SNM_DeleteFastString(fast_str)
  return track_chunk
end
-- Set track chunk(allow > 4MB)
function SetTrackChunk(track, track_chunk)
  if not (track and track_chunk) then return end
  if #track_chunk < 4194303 then return reaper.SetTrackStateChunk(track, track_chunk, false) end  -- isundo = false
  -- If chunk_size >= max_size, use wdl fast string --
  local fast_str, ret
  fast_str = reaper.SNM_CreateFastString("")
  if reaper.SNM_SetFastString(fast_str, track_chunk) then
    ret = reaper.SNM_GetSetObjectState(track, fast_str, true, false)
  end
  reaper.SNM_DeleteFastString(fast_str)
  return ret
end
--==============================================================================
function GetLinesFromString2(str) -- without "\n"
  if not str then return end
  local lines = {}
  for line in str:gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  -- Get last line or full string(if "\n" not found)
  if #lines == 0 then lines[#lines + 1] = str
    else lines[#lines + 1] = str:match(".*\n(.-)$")
  end
  -------------
  return lines
end
--==============================================================================
-- GetSet Chunk from/to buf. buf is a table of text lines.
-- Буфер в main-коде сейчас глобален(для тестов), не забыть поправить потом.
function GetChunkToBuf()
  local track = reaper.GetSelectedTrack(0, 0)
  local track_chunk = GetTrackChunk(track)
  return GetLinesFromString2(track_chunk)
end
----------
function SetChunkFromBuf(buf)
  local track = reaper.GetSelectedTrack(0, 0)
  local track_chunk = table.concat(buf,"\n")
  SetTrackChunk(track, track_chunk)
  reaper.UpdateArrange()
end

--=======================================================================================================
--=======================================================================================================
-- Желательно объединить функции по группам, чтобы сто раз не писать - CancelSelection, DelSelection --
-- Проверка значения char - здесь не нужна - вынести в общ. функцию, внутри частных оставить только действия --
-- Left ----------------------
function Left()
  if not(c_line == 1 and c_char == 0) then
    if c_char == 0 then c_line = max(1, c_line - 1); c_char = #buf[c_line] else c_char = c_char - 1 end
  end
end
-- Right ---------------------
function Right()
  if not(c_line == #buf and c_char == #buf[c_line]) then
    if c_char == #buf[c_line] then c_line = min(#buf, c_line + 1); c_char = 0 else c_char = c_char + 1 end
  end
end
-- Up ------------------------
function Up()
  c_line = max(1, c_line - 1); c_char = min(c_char, #buf[c_line])
end
-- Down ----------------------
function Down()
  c_line = min(#buf, c_line + 1); c_char = min(c_char, #buf[c_line])
end
------------------------------
function Backspace()
  if c_char > 0 then -- delete char(if c_char > 0)
    buf[c_line] = buf[c_line]:sub(1, c_char-1) .. buf[c_line]:sub(c_char+1, -1)
    c_char = max(0, c_char - 1)
  elseif c_char == 0 and c_line > 1 then -- del line sep, go to prev line(c_char == 0)
    c_char = #buf[c_line - 1]
    buf[c_line - 1] = buf[c_line - 1] .. buf[c_line] -- concat with prev line
    table.remove(buf, c_line)
    c_line = c_line - 1
  end
end
------------------------------
function Enter()
  table.insert(buf, c_line + 1, buf[c_line]:sub(c_char+1, -1))
  buf[c_line] = buf[c_line]:sub(1, c_char)
  c_line = c_line + 1
  c_char = 0
end
------------------------------
function InsertChar()
  buf[c_line] = buf[c_line]:sub(1, c_char) .. string.char(char) .. buf[c_line]:sub(c_char+1, -1)
  c_char = c_char + 1
end

--==================================================================================================
function GetKBInput1()
  if not Ctrl then
    if char == 1818584692 then CancelSelection(); Left()
    elseif char == 1919379572 then CancelSelection(); Right()
    elseif char == 30064      then CancelSelection(); Up()
    elseif char == 1685026670 then CancelSelection(); Down()
    end
  end
end
--------------------
function GetKBInput2()
  if not Ctrl then
    if char == 8 then
      if Sel then DelSelection() else Backspace() end
    end
    if char == 13 then DelSelection(); Enter()
    elseif char > 31 and char < 127 then DelSelection(); InsertChar()
    end
    -----------
    blink = 0
  end
end
--------------------
function GetKBInput3()
  if char == 6579564 then return DelSelection() end -- Del
  if Ctrl and char == 3 then return CopySeltoTmpBuf(s_line, s_char, e_line, e_char) end -- Ctrl + C
  if Ctrl and char == 22 then return PasteSelFromTmpBuf() end -- Ctrl + V
end
--==================================================================================================
-- Find and return position in text(c_line, c_char) by point coordinates(p_x, p_y)
function FindPosByCoords(p_x, p_y, x,y,w,h)
  local c_line, c_char, c_str
  c_line = s_pos + floor( (p_y - y) / gfx.texth )
  c_line = minmax(c_line, 1, #buf)
  c_str = buf[c_line]
  ----------------
  if x >= p_x then -- str_start x >= point x
    c_char = 0
  elseif x + gfx.measurestr(c_str) < p_x then -- str_end x < point x
    c_char = #c_str
  else
    for i = 1, #c_str do
      local sw = gfx.measurestr(c_str:sub(1, i))
      if x + sw >= p_x then c_char = i - 1; break end
    end
  end
  ----------------
  return c_line, c_char
end

-- Find and return point coordinates(p_x, p_y) by position in text(c_line, c_char)
function FindCoordsByPos(c_line, c_char, x,y,w,h)
  local c_str, p_x, p_y
  c_str = buf[c_line]
  local sw = gfx.measurestr(c_str:sub(1, c_char))
  local p_x, p_y = x + sw, y + gfx.texth*(c_line-s_pos)
  return p_x, p_y
end

-- Define Selection in text(start line/char, end line/char)
function DefineSelection(c_line, c_char, c_line2, c_char2)
  local s_line, e_line, s_char, e_char
  --------
  if c_line == c_line2 and c_char ~= c_char2 then
    s_line, s_char = c_line,  min(c_char, c_char2)
    e_line, e_char = c_line2, max(c_char, c_char2)
  elseif c_line < c_line2 then
    s_line, s_char = c_line, c_char
    e_line, e_char = c_line2, c_char2
  elseif c_line > c_line2 then
    s_line, s_char = c_line2, c_char2
    e_line, e_char = c_line, c_char
  end
  --------
  return s_line, s_char, e_line, e_char
end

-- Cancel Selection ----------------------------------------
function CancelSelection()
  s_line, s_char, e_line, e_char = nil, nil, nil, nil
  Sel = nil
end

--==================================================================================================
-- DRAW Text ---------------------------
function DrawText(x,y,w,h)
  -- Draw visible text from buf --------
  gfx.set(0) -- text color
  gfx.x, gfx.y = x, y -- set start coords
  for i = s_pos, #buf do
    gfx.drawstr(buf[i], 0, x + w, gfx.y + gfx.texth) -- clipped to x + w, gfx.y + gfx.texth
    gfx.x, gfx.y = x, gfx.y + gfx.texth -- next line coords
    if gfx.y > y + h - gfx.texth then break end
  end
end

-- DRAW Cursor -------------------------
function DrawCursor(c_line, c_char, x,y,w,h)
  if c_line and c_char then
    if blink < 15 then
      local p_x, p_y = FindCoordsByPos(c_line, c_char, x,y,w,h)
      if p_x >= x and p_x <= x + w and p_y >= y and p_y <= y + h - gfx.texth then
        gfx.rect(p_x, p_y, 2, gfx.texth) -- draw cursor
      end
    end
    if blink < 30 then blink = blink + 1 else blink = 0 end
  end
end

-- Draw Selection(line) ----------------
function DrawSel_Line(s_draw, e_draw, sel_line, sel_s_char, sel_e_char, x,y,w,h)
  if sel_line >= s_draw and sel_line <= e_draw then
    local x1, y1 = FindCoordsByPos(sel_line, sel_s_char, x,y,w,h)
    local x2, y2 = FindCoordsByPos(sel_line, sel_e_char, x,y,w,h)
    local ww = min(x2, x + w - 1) - x1 + 1
    gfx.rect(x1, y1, ww, gfx.texth, 1)
  end
end
-- Draw Selection(Full) ----------------
function DrawSelection(s_line, s_char, e_line, e_char, x,y,w,h)
  if not(s_line and s_char and e_line and e_char) then return end
  gfx.set(0, 0, 0.3, 0.2) -- selection color
  ------------------
  -- Выделение не должно вылазить за коорд. окна, исправить!!!
  -- И считать за пределами окна тоже лишняя трата ресурсов!!!
  local s_draw = minmax(s_line, s_pos, s_pos + max_vis_lines)
  local e_draw = minmax(e_line, s_pos, s_pos + max_vis_lines - 1)
  ------------------
  if s_line == e_line then  -- selection on one line
    DrawSel_Line(s_draw, e_draw, s_line, s_char, e_char, x,y,w,h)
  end
  ------------------
  if s_line ~= e_line then  -- selection on separate lines
    DrawSel_Line(s_draw, e_draw, s_line, s_char, #buf[s_line], x,y,w,h) -- first sel line
    --------
    for line = s_line + 1, e_line - 1 do
      DrawSel_Line(s_draw, e_draw, line, 0, #buf[line], x,y,w,h) -- between first/last lines
    end
    --------
    DrawSel_Line(s_draw, e_draw, e_line, 0, e_char, x,y,w,h) -- last sel line
  end
end
--==================================================================================================
--------------------------------
function DelSelection()
  -- используются глобальные переменные, править!!!
  if not(s_line and s_char and e_line and e_char) then return end
  ------------------
  if s_line == e_line then  -- selection on one line
    buf[s_line] = buf[s_line]:sub(1, s_char) .. buf[s_line]:sub(e_char+1, -1)
  else                      -- selection on separate lines
    buf[s_line] = buf[s_line]:sub(1, s_char) .. buf[e_line]:sub(e_char+1, -1) -- copy to first line
    for i = s_line + 1, e_line do -- remove other lines
      table.remove(buf, s_line + 1) -- table.remove shift elements left!
    end
  end
  ------------------
  c_line, c_char = s_line, s_char -- move cursor to sel start
  CancelSelection() -- cancel after delete!
end

--------------------------------
function CopySeltoTmpBuf(s_line, s_char, e_line, e_char)
  if not(s_line and s_char and e_line and e_char) then return end
  ------------------
  tmp_buf = {}
  ------------------
  if s_line == e_line then  -- selection on one line
    tmp_buf[1] = buf[s_line]:sub(s_char+1, e_char)
  else                      -- selection on separate lines
    tmp_buf[1] = buf[s_line]:sub(s_char+1, -1) -- first copied line
    for i = s_line + 1, e_line - 1 do
      tmp_buf[#tmp_buf + 1] = buf[i]
    end
    tmp_buf[#tmp_buf + 1] = buf[e_line]:sub(1, e_char) -- last copied line
  end
  ------------------
  return tmp_buf
end

--------------------------------------------------
function PasteSelFromTmpBuf()
  DelSelection() -- del sel
  ----------------------------
  if #tmp_buf == 1 then     -- if tmp_buf contains 1 line
    buf[c_line] = buf[c_line]:sub(1, c_char) .. tmp_buf[1] .. buf[c_line]:sub(c_char + 1, -1)
  elseif #tmp_buf > 1 then  -- if tmp_buf contains > 1 lines
    local ss = buf[c_line]:sub(1, c_char)
    local ee = buf[c_line]:sub(c_char + 1, -1)
    buf[c_line] = ss .. tmp_buf[1]
    table.insert(buf, c_line + 1, tmp_buf[#tmp_buf] .. ee)
    --------------
    for i = 2, #tmp_buf - 1 do
      table.insert(buf, c_line + i - 1, tmp_buf[i])
    end
  end
  -- Define new sel pos ------
  local c_line2, c_char2
  c_line2 = c_line + #tmp_buf - 1;
  if #tmp_buf == 1 then c_char2 = c_char + #tmp_buf[1]
  else c_char2 = #tmp_buf[#tmp_buf]
  end
  s_line, s_char, e_line, e_char = DefineSelection(c_line, c_char, c_line2, c_char2)
  Sel = s_line and s_char and e_line and e_char -- Selection state

end

--==================================================================================================
function Draw()
  if not buf then return end
  -------------------
  local font = "Courier New"  -- I USE MONOSPACE FONT!!!
  gfx.setfont(1, font, 16)
  local x, y = gfx.texth, gfx.texth -- wnd x, y coords
  local w, h = gfx.w - gfx.texth*2, gfx.h - gfx.texth*2 -- wnd w, h
  gfx.rect(x,y,w,h,0) -- active rect(for tests only)

  -- Scroll position(mouse_wheel) ------
  max_vis_lines = floor(h/gfx.texth) -- visible lines maximum
  if gfx.mouse_wheel ~= 0 then
    local scroll = floor(gfx.mouse_wheel/20)
    s_pos = minmax(s_pos - scroll, 1, max(1, #buf - max_vis_lines) )
    gfx.mouse_wheel = 0
  end

  --- Find clicked line and char -(-- need valid wnd coords!)----
  if mouseDown(x - gfx.texth, y, w, h) then
    local p_x, p_y = gfx.mouse_x, gfx.mouse_y
    c_line, c_char = FindPosByCoords(p_x, p_y, x,y,w,h)
    ----------------
    blink = 0
  end
  --- Find mouse_pos line and char -(-- need valid wnd coords!)--
  if gfx.mouse_cap&1 == 1 and pointIN(mouse_down_x,mouse_down_y, x - gfx.texth, y, w, h) then
    local p_x, p_y = gfx.mouse_x, gfx.mouse_y
    c_line2, c_char2 = FindPosByCoords(p_x, p_y, x,y,w,h)
    s_line, s_char, e_line, e_char = DefineSelection(c_line, c_char, c_line2, c_char2)
    Sel = s_line and s_char and e_line and e_char -- Selection state
    -----------
    if c_line2 >= s_pos + max_vis_lines then s_pos = minmax(s_pos + 1, 1, max(1, #buf - max_vis_lines) )
    elseif c_line2 < s_pos then s_pos = minmax(s_pos - 1, 1, max(1, #buf - max_vis_lines) )
    end
  end

  -- Draw text -------------------------
  DrawText(x,y,w,h)

  -- Draw cursor -----------------------
  DrawCursor(c_line, c_char, x,y,w,h)

  -- Draw selection --------------------
  DrawSelection(s_line, s_char, e_line, e_char, x,y,w,h)

  -- Get KB input ----------------------
  if char ~= 0 and c_line and c_char then
    GetKBInput1()
    GetKBInput2()
    GetKBInput3()
  end

  -- TEST line chars table !!! ---------
  --if buf and c_line then AAAchars = { string.byte(buf[c_line], 1, -1) } end
end

--==================================================================================================
function main()
  local x, y, w, h = gfx.w - 200 -  gfx.texth, 0, 100, gfx.texth -- btn x, y, w, h
  if Button(x,y,w,h, "Get Chunk") then buf = GetChunkToBuf() end
  ------------------
  local x  = x + w -- btn x, y, w, h
  if Button(x,y,w,h, "Set Chunk") then SetChunkFromBuf(buf) end
  ------------------
  if Ctrl and char == 19 then SetChunkFromBuf(buf) end -- Ctrl + S

  ------------------
  Draw()
  ------------------
end

--------------------------------------------------------------------------------
--   INIT   --------------------------------------------------------------------
--------------------------------------------------------------------------------
function Init()
  -- Init window ------
  gfx.clear = 0xF0F0F0
  gui = {w = 860, h = 500 , dock = 0, x = 100, y = 300}
  gfx.init("TEST", gui.w, gui.h, gui.dock, gui.x, gui.y)
  last_mouse_cap = 0
  s_pos = 1
  upd = 0
  blink = 0
end

----------------------------------------
--   Mainloop   ------------------------
----------------------------------------
function mainloop()
  -----------
  mouse_down = gfx.mouse_cap&1==1 and last_mouse_cap&1==0
  mouse_rdown = gfx.mouse_cap&2==2 and last_mouse_cap&2==0
  mouse_up = gfx.mouse_cap&1==0 and last_mouse_cap&1==1
  -----------
  if mouse_down then mouse_down_x = gfx.mouse_x; mouse_down_y = gfx.mouse_y end
  -----------
  last_mouse_cap = gfx.mouse_cap
  -------------------------
  Ctrl = gfx.mouse_cap&4 == 4

  -- DRAW,MAIN functions --
  main()
  -----------
  char = gfx.getchar()
  --if char==32 then reaper.Main_OnCommand(40044, 0) end -- play
  if char~=-1 then reaper.defer(mainloop) end          -- defer
  -----------
  gfx.update()
  -----------
end

----------------------------------------
Init()
mainloop()
