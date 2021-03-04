dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
local hsluv = require "hsluv"

DBG_OFF = false

--[[
SCYTHE EDITS AND BUGS
    color line 228:     local rgb = Table.map(colorTable, function(v) return math.floor(v * 255) end)
    window, line 148:   local w, h = self.currentW, self.currentH + self.titleHeight
    layer, line 111:    gfx.setimgdim(self.buffer, self.window.currentW, self.window.currentH + self.window.titleHeight)
    sprite... edit for vert or horiz frames
]]

-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
loadfile(libPath .. "scythe.lua")({printErrors = true})

local M = require("public.message")
local Table = require("public.table")
local Color = require("public.color")
local Math = require("public.math")
local T = Table.T

local moonTracks = nil
local gBanks = nil  --list of all global banks
local gBank = nil
local gPresets = nil --



IMAGE_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/Images/"
BANK_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/Banks/"
GBANK_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/GBanks/"

BRIGHTNESS = 60

REAPER_TEMPO = 120
BEAT = 4  --default to 4/4
QUAVER = 1
HEMIOLA = 1

SCREEN_WIDTH = 1920
SCREEN_HEIGHT = 1280

HUES = {
    CRIMSON = 0,
    RED = 14,
    RUST = 20,
    PUMPKIN = 32,
    YELLOW = 44,
    LEMON = 56,
    GRASS = 80,
    GREEN = 120,
    TEAL = 135,
    AQUA = 175,
    SKY = 216,
    BLUE = 250,
    INDIGO = 260,
    VIOLET = 268,
    PURPLE = 274,
    LAVENDER = 280,
    FUSCHIA = 294
}

--number of moon channels
CH_COUNT = 16
--I/O track numbers   todo: Set controls to different channels on behringer
TRACKS = {
        --AUDIO OUTS
        OUT_MIX = 1 + CH_COUNT,  --8 ch with direct hardware outs.  Also sends to Master?
            OUT_MON = 2 + CH_COUNT,  --post fader send to MASTER
            OUT_A = 3 + CH_COUNT,    --out to MIX 1,2
            OUT_B = 4 + CH_COUNT,    --out to MIX 3,4
            OUT_C = 5 + CH_COUNT,    --out to MIX 5,6
            OUT_D = 6 + CH_COUNT,    --out to MIX 7,8
        --MIDI INPUTS
        IN_MIDI = 7 + CH_COUNT,  --All midi comes in here, and then is sent on to other virtual devices? Maybe all but Roli?
            IN_BHR2 = 8 + CH_COUNT,    --behringer#2 - Reaper Control Unit port
            IN_ROLI = 9 + CH_COUNT,   --notes and roli controls, I suppose? roli port/ all channels
            IN_KEYB = 10 + CH_COUNT,   --notes only, yamaha, CH1
            IN_PB = 11 + CH_COUNT,    --Yamaha Port, CH1
            IN_MOD = 12 + CH_COUNT,   --Yamaha Port, CH1
            IN_ENC = 13 + CH_COUNT,   --behringer port CH1
            IN_PUSH = 14 + CH_COUNT,  --behringer port CH2
            IN_SW1 = 15 + CH_COUNT,--behringer port CH3
            IN_SW2 = 16 + CH_COUNT,--behringer port CH4
            IN_SUS = 17 + CH_COUNT,   --FC port
            IN_FSW = 18 + CH_COUNT,   --FC port
            IN_EXP = 19 + CH_COUNT,   --FC port
            IN_PED2 = 20 + CH_COUNT,  --FC port
            IN_AT = 21 + CH_COUNT,    --drawbar port
            IN_BC = 22 + CH_COUNT,    --drawbar port
            IN_DRWB = 23 + CH_COUNT,  --drawbar port
            IN_ORG_CTL = 24 + CH_COUNT,--drawbar port
        --AUDIO INPUTS
        IN_AUDIO_MIC1 = 25 + CH_COUNT,
        IN_AUDIO_MIC2 = 26 + CH_COUNT,
        IN_AUDIO_INST = 28 + CH_COUNT,
        IN_AUDIO_LINE = 29 + CH_COUNT,
        IN_AUDIO_MON = 30 + CH_COUNT
}

INPUT_DEVICE_NAME = 'HD Audio Mic input 1'
--midi vol Settings
MIDIVOL = {}
    MIDIVOL.NAME = "JS: Volume Adjustment"
    MIDIVOL.SLOT = 2

INSTRUMENT_SLOT = 1

--MIDI ch strip Settings
MCS = {
    NAME = "JS: midiChStrip",
    SLOT = 0,
    MIDI_ON = 0,
    OCTAVE = 1,
    SEMI = 2,
    SEMI_CC = 3,
    HANDS = 4,
    LO_NOTE = 5,
    HI_NOTE = 6,
    FOLD_LO = 7,
    FOLD_HI = 8,
    NS_SOLO = 9,
    NS_MUTE_LO = 10,
    NS_MUTE_HI = 11,
    SUSTAIN = 12,
    HOLD = 13,
    EXP_CC = 14,
    EXPR_CURVE = 15,
    KEYB_TYPE = 16,
    MPE_VST = 17,
    MPE_BASE_CH = 18,
    MPE_POLY = 19,
    AT_TO_CC = 20,
    AT_TOGGLE = 21,
    PB_NORM = 22,
    PB_MPE = 23,
    PB_VST = 24,
    PB_NOTES = 25,
    AUDIO_IN = 26,
    AUDIO_OUT = 27,
    PANIC = 28,
}

--TODO: deprecate storing these in MCS???
AUDIO_IN = {
    NONE = 0, EXT = 1, MIXER = 2, BOTH = 3
}

NS_COUNT = 4
NS = {KBD = 0, ROLI = 1, NONE = 2, DUAL = 3}

--MCS Audio output setting
OUT_OFFSET = 3 --difference between param#s and track# for outputs
AUDIO_OUT = {A = 0, B = 1, C = 2, D = 3}
--track numbers

REAPER = {SEND = 0, RCV = -1, STEREO = 1024, MONO = 0 }

NOTES = {'C','C#','D','Eb','E','F','F#','G','Ab','A','Bb','B'}
MONTHS = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'}

------------------LOCAL GLOBALS-------------------------------------
local previousNotesourceSetting = 0
local currentFxList = nil
local moonTracks = nil
local fxChannels = {}

function GetNoteName(noteNum)
    noteNum = math.floor(noteNum)
    local octave = math.floor(noteNum/12) - 2
    local note = noteNum % 12
    return NOTES[note + 1]..octave
end
-----------------------------------------------------------------------------------------------------------
---------------------------------------------BASIC UTILITIES-----------------------------------------------
--OS time format:  3/2/2021 9:51:53 AM
--military time for now
function Time()
    local items = StringSplit(os.date())
    local tParts = StringSplit(items[2], ':')
    if tParts[1] == 12 then tParts[1] = 0 end
    if items[3] == 'PM' then tParts[1] = tParts[1] + 12 end
    return Int(tParts[1])..':'..tParts[2]
end

function Date()
    local items = StringSplit(os.date())
    local dParts = StringSplit(items[1],'/')
    local monthnum = dParts[1] + 0 --monthnum isn't recognized as a number when used as an index!
    local month = MONTHS[monthnum]
    return MONTHS[monthnum]..' '..dParts[2]
end

function Seconds()
    local items = StringSplit(os.date())
    local tParts = StringSplit(items[2], ':')
    return tParts[3]
end

function Int(num) return Math.round(num + 0) end

function MSG(...)
    if DBG_OFF then return end
    local out = {}
    for _, v in ipairs({...}) do
        local str
        if v == nil then str = 'NIL' else str = tostring(v) end
        out[#out+1] = str
    end
    reaper.ShowConsoleMsg(Seconds()..':'..table.concat(out, " ").."\n")
end

function ERR(...)
    local out = {}
    for _, v in ipairs({...}) do
      out[#out+1] = tostring(v)
    end
    reaper.ShowConsoleMsg('ERROR::::'..table.concat(out, " ").."\n")
end


function IncrementValue(value,min,max,wrap,inc)
    inc = inc or 1
    ----MSG('value = '..value)
    if inc < 0 then return DecrementValue(value,min,max,wrap,0 - inc)
    else
        wrap = wrap or true
        if value == false then return true
        elseif value == true and wrap then return false
        elseif value == true then return true
        else
            ----MSG('incrementValue:  val=',value,'max=',max)

            if value < min then value = min
            elseif value > max then value = max
            elseif value < max then
                return value + inc
            elseif wrap then
                return min
            else return max
            end
        end
    end
end

function DecrementValue(value,min,max,wrap,inc)
    inc = inc or 1
    wrap = wrap or true
    if value == true then return false
    elseif value == false and wrap then return true
    elseif value == false then return false
    else
        if value < min then value = min
        elseif value > max then value = max
        elseif value > min then
            return value - inc
        elseif wrap then
            return max
        else return min
        end
    end
end

function GetRGB(hue,sat,level)
    if not level then level = BRIGHTNESS end
    local color = { hue, sat, level }
    local rgb = hsluv.hpluv_to_rgb(color)
    --MST(rgb, 'color table')
    return rgb
end

function GetReaperColor(hue,sat,level)
    return Color.toNative(GetRGB(hue, sat, level))
end

function SetChanColor(chan, hue, sat, level)
    reaper.SetTrackColor(GetTrack(chan), GetReaperColor(hue, sat))
end

function RandomColor(brightness)
    return GetRGB(math.random(360),100-(math.random(10) * math.random(10)),brightness or BRIGHTNESS)
end

function BoolToInt(val)
    if val == true then return 1
    elseif val == false then return 0
    else return val
    end
end

function IntToBool(val)
    if val == true then return true
    elseif val == false then return false
    elseif val >= 1 then return true
    elseif val <= 0 then return false
    end
end

local function getCurrentProject()
    local _,proj = reaper.EnumProjects(-1)
    return proj
end

local function getCurrentProjectFilename()
    local projectName = ultraschall.GetProjectFilename(getCurrentProject())
end

---------------------------------------------------------------------------------------------------------
-------------------------------------------FILE UTILITIES-----------------------------------------------
function GetFileList(path)
    local names = {}
    local filecount,files = ultraschall.GetAllFilenamesInPath(path)
    for i, file in pairs(files) do
        names[i] = GetFilename(file)
    end
    return names
end

function GetSubFolderList(path)
    local names = {}
    local count, files = ultraschall.GetAllDirectoriesInPath(path)
    for i, file in pairs(files) do
        _, names[i] = ultraschall.GetPath(file)
    end
    return names
end

--returns just the name portion, no path or extension
function GetFilename(file)
    local path, filename = ultraschall.GetPath(file)
    return filename:sub(0, #filename - 4)
end

function GetFileContaining(str,path)
    if not path then path = BANK_FOLDER end
    local filecount,files = ultraschall.GetAllFilenamesInPath(path)
    for _,fileName in pairs(files) do
        if string.find(fileName,str) then return fileName end
    end
    ERR("ERROR:  No file found containing: "..str)
end

function GetFileStartingWith(startsWith,path)
    if not path then path = BANK_FOLDER end
    for _,fileName in pairs(GetFileList(path)) do
        if StartsWith(fileName,startsWith) then return fileName
        end
    end
    ERR('No file found starting with: '..startsWith)
end

--parses bank folder names and returns a table
--in the format files[i] = { name =, vst =}
function GetBankFileTable()
    local files = {}
    for i,filename in pairs(GetFileList(BANK_FOLDER)) do
        local parts = StringSplit(filename,'.')
        table[parts[1]] = parts[2]
        files[i] = { name = parts[1], vst = parts[2]}
    end
    local sorted = ArraySortByField(files)
    --MST(sorted,'bank file table')
    return sorted
end

function GetGBanks()
    if not gBanks then gBanks = OptionsFromPath(GBANK_FOLDER, true) end
    return gBanks
end

function GetGPresets(bankname)
    return OptionsFromPath(GBANK_FOLDER..bankname..'/')
end

function GetPluginDisplayName(plugName, path)
    for i, plug in pairs(GetBankFileTable(path)) do
        if plug.vst == plugName then return plug.name end
    end
    return plugName --if no bank file, just use the dll filename2
end

function GetPlugFromDisplayName(name, path)
    for i, plug in ipairs(GetBankFileTable(path)) do
        MSG('plugname = ',plug.name, ', plugvst = ', plug.vst)
        if plug.name == name then return plug.vst end
    end
    return name
end

function GetPlugName(chan, slot)
    local track = GetTrack(chan)
    if not slot then slot = INSTRUMENT_SLOT end
    ----MSG('GetPlugName, tracknum = '..tracknum)
    local done,name = reaper.BR_TrackFX_GetFXModuleName(track,slot,"",128)--NOT SHOWN IN API DOCS!
    if done then ----MSG('getting fx name: '..name)
    elseif track then ERR('MU.GetPlugName--fx name failed at track,slot: ',chan,slot)
    end
    return GetFilename(name)  --strip off .dll
end

-- Creates simple options from the files or the subfolders for a particular path
function OptionsFromPath(path, useFoldersNotFiles)
    local options = {}
    if useFoldersNotFiles then options = GetSubFolderList(path) else options = GetFileList(path) end
    --MST(options, 'options')
    for i,filename in ipairs(options) do
        options[i] = { index = i, name = filename }
        ----MSG('added item: '..filename)
    end
    return options
end

function CreateFolder(path)
    if EndsWith(path,'/') or EndsWith(path,'\\') then path = CleanComma(path) end
    return reaper.RecursiveCreateDirectory(path,0) > 0
end

---------------------------------------------------------------------------------------------------
----------------------------------------WINDOW UTILITIES-------------------------------------------

function CloseWindow(window)
    local title = window.name
    ----MSG('window title = '..title)
    local hWnd = reaper.JS_Window_Find(title, true) -- find window by title bar text
    if hWnd ~=nil then reaper.JS_WindowMessage_Post(hWnd, "WM_CLOSE", 0,0,0,0) end
end

local originalStyle = nil
function Fullscreen(window, off)
    MSG('Calling fullscreen:',off)
    --window:init()
    local title = window.name
    local style
    local win = reaper.JS_Window_Find(title, true)
    if not originalStyle then
        style = reaper.JS_Window_GetLong(win, 'STYLE')
        originalStyle = style
    else style = originalStyle
    end
    if not off then

        reaper.JS_Window_Show( win, "RESTORE" )
        reaper.JS_Window_SetStyle( win, "MAXIMIZE" )
    else
        reaper.JS_Window_Show( win, "RESTORE" )
        reaper.JS_Window_SetLong( win, "STYLE", style )
    end
    --window:redraw()
end


function ResizeWindow(window, x, y, w, h, on)
    if on then Fullscreen(window, true)
        local title = window.name
        local win = reaper.JS_Window_Find(title, true)
        reaper.JS_Window_SetPosition(win, x, y, w, h)
    else Fullscreen(window, false) end
end

function GetLayoutXandY(i,x,y,w,h,rows)
    ----MSG("layout: x = "..x)
    local xadj = math.floor((i - 1)/rows)
    local yadj = (i-1) % rows
    local xpos = x + (xadj * w)
    local ypos = y + (yadj * h)
    return xpos,ypos
end

--------------------------------------OPEN FX WINDOWS------------------------------------------
function OpenPlugin(chan,fxnum)
    if not fxnum then fxnum = INSTRUMENT_SLOT end
    reaper.TrackFX_Show( GetTrack(chan), fxnum, 3 )  --fx zero-based again...
end

function OpenMidiChStrip(chan,open)
    OpenPlugin(chan, MCS.SLOT)
end

function OpenMidiVol(chan,open)
    OpenPlugin(chan, MIDIVOL.SLOT)
end

function GetFocusedFX()
    local found,chan,_,fxnum = reaper.GetFocusedFX() --ignore item number
    if found == 1 then found = true end
    return found, chan, fxnum
end

function GetLastTouchedFX()
    local found, _, chan, fxnum, paramnum, _, _ = ultraschall.GetLastTouchedFX()
    return found, chan, fxnum, paramnum
end
----------------------------------------------------------------------------------------------------------
------------------------------------------------------TABLE UTILITIES-------------------------------------
--either table or string can come first
function MST(arg1,arg2)
    local str, table
    if not arg2 then                   str = 'table'    table = arg1
    elseif type(arg1) == 'string' then str = arg1       table = arg2
    elseif type(arg2) == 'string' then str = arg2       table = arg1
    end
    if not str then local str = 'table unknown' end
    if not table then return MSG('-----------MST, table is nil: '..str) end
    local val = nil
    if not str then str = table.name or 'TABLE' end
    if type(table) ~= 'table' then val = 'not a table' else val = Table.stringify(table) end
    return MSG('\nT:------['..str..']-----\n'..val..'\n---------------------------')
end

function ArraySort(array)
    local sorted = {}
    for i in ipairs(array) do table.insert(sorted,array[i]) end
    table.sort(sorted, function (a,b) return a:lower() < b:lower() end)
    return sorted
end

function TableSort(t)
    local sorted = {}
    for n in pairs(t) do table.insert(sorted, n) end
    table.sort(sorted, function (a,b) return a:lower() < b:lower() end)
    return sorted
end

function ArrayContains(array, element)
    for _, value in ipairs(array) do
        if value == element then return true end
    end
    return false
end

function TableContains(table, element)
    for _, value in pairs(table) do
      if value == element then return true end
    end
    return false
end

function RemoveDuplicates(table)
    local hash = {}
    local res = {}
    for _,val in ipairs(table) do
        if (not hash[val]) then
            res[#res+1] = val -- you could print here instead of saving to result table if you wanted
            hash[val] = true
        end
    end
    return res
  end
--returns the index of a table array that has a .name field that matches name, or a string that matches name, or just a matching value
function IForName(array, item)
    for i,element in ipairs(array) do
        if element == item then return i
        elseif type(element) == 'string' and element == item then return i
        elseif type(element) == 'table' and element.name and (element.name == item) then return i
        end
    end
    return nil
end
-- return the index of a table in an array of tables that has a field with the requisite value
function IForField(array, field, value)
    for i, element in ipairs(array) do
        if type(element) == 'table' and element[field] and element[field] == value then return i end
    end
end
--doesn't work--can only be one item for each value in 'field'!
function ArraySortByField(array, field)
    if not field then field = 'name' end
    local names = {}
    for i, element in ipairs(array) do
        if type(element) == 'table' then names[element[field]] = element or ''
        elseif type(element) == 'string' then names[element] = element or ''
        end
    end
    local sorted =  TableSort(names)
    for i, element in ipairs(sorted) do
        sorted[i] = names[element]
    end
    return sorted
end

-------------------------------------------------------------------------------------------------------------
---------------------------------------------------STRING UTILITIES------------------------------------------

function StartsWith(sourceString, start)
    return sourceString:sub(1, string.len(start)) == start
 end

function EndsWith(sourceString, ending)
    local endString = sourceString:sub(string.len(sourceString) - string.len(ending) + 1, string.len(sourceString))  --MSG('end string = '..endString..', ending = '..ending)
    return endString == ending
end

 local function splitByPlainSeparator(str, sep, max)
    local z = #sep; sep = '^.-'..sep:gsub('[$%%()*+%-.?%[%]^]', '%%%0')
    local t,n,p, q,r = {},1,1, str:find(sep)
    while q and n~=max do
        t[n],n,p = str:sub(q,r-z),n+1,r+1
        q,r = str:find(sep,p)
    end
    t[n] = str:sub(p)
    return t
end

function StringSplit(str,sep)
    if not sep then sep = ' ' end
    return splitByPlainSeparator(str,sep,1000)
end

function Pad_zeros(str, places)
    if string.len(str) < places then
        return string.rep('0', places - string.len(str))..str
    else
        return str
    end
end

function Esc(val)
    if type(val) == 'string' then return ("%q"):format(val) else return val end
end
--just strips a number of characters off the end of the string.  default is 1
function CleanComma(s, num)
    local trim = 2
    if num then trim = num + 1 end
      return s:sub(1, string.len(s) - trim) end

---------------------------------------------------------------------
---------------------------------MOON PARAMS-------------------------
function PANIC()
    for i = 1, CH_COUNT do
        SetMoonParam(i, MCS.PANIC)
    end
end

function GetMoonParam(chan, param)
    local track = GetTrack(chan)   ---MSG('getting Moon param,',param,', track: ',chan)
    local val,_,_ = reaper.TrackFX_GetParam( track, MCS.SLOT, param)
    return val
end

function SetMoonParam(chan, param, val)
    local track = GetTrack(chan)  --MSG('Setting moon param',param,'to',val)
    local _ = reaper.TrackFX_SetParam(track,MCS.SLOT,param,val)
end

function SetVolPlugParam(chan,param, val)
    local track = GetTrack(chan)
    local _ = reaper.TrackFX_SetParam(track,MIDIVOL.SLOT,param,val)
end

-------------------------------------------------------------------------------------------------
-------------------------------------TRACK METHODS-----------------------------------------------

function GetTrack(chan)     --MSG("GetTrack: TRACK =", chan)
    return reaper.GetTrack(0, chan - 1)
end

function GetSelectedTrackNumber()
    local tr = GetSelectedTrack(0,0)
    return ChanOfTrack(tr)
end

function GetSelectedTrack()
    local track = reaper.GetSelectedTrack(0,0)
    return track
end

function SetTrackSelected(chan)
    reaper.SetOnlyTrackSelected( GetTrack(chan))
end

function GetTrackCount()
    return reaper.CountTracks(0)
end

function ChanOfTrack(mediatrack)
    --(returns zero if not found, -1 for master track) (read-only, returns the int directly)
    local num = reaper.GetMediaTrackInfo_Value( mediatrack,'IP_TRACKNUMBER')
    if num == 0 then ERR('GetSelectedTrackNumber: Track Not Found')
    else return num
    end
end

function GetChanPresetName(chan, slot) --MSG('Getting fx preset for chan: ', chan)
    if not slot then slot = INSTRUMENT_SLOT end
    local found, presetname = reaper.TrackFX_GetPreset(GetTrack(chan), slot, "") --MSG('preset found for chan', chan, ' named ', presetname)
    if found then return presetname else return 'No Preset' end
end

function ChanName(chan,name)
    --preset name, presumably...
    local track = GetTrack(chan)
    if not name then
        _, name = reaper.GetTrackName(track,'')
        return name
    else reaper.GetSetMediaTrackInfo_String(track, "P_NAME",name,true)
    end
end

function EnableChan(chan,set)
    if set == nil then
        return GetMoonParam(chan, MCS.MIDI_ON)
    else
        SetMoonParam(chan, MCS.MIDI_ON, set)
    end
end

function ToggleTrackEnable(chan)
    if EnableChan(chan) == 0 then EnableChan(chan, 1)
    else EnableChan(tracknum, 0)
    end
end
--################################################################################################################--
--------------------------------------------SEND AND RECEIVE--------------------------------------------------------
function InitOutputRouting()
    for chan = 1, CH_COUNT do
        for out = TRACKS.OUT_MON, TRACKS.OUT_D do
            AddSend(chan, out)
        end
    end
end

function GetSendDest(chan,index)
    local track = GetTrack(chan)
    local dest = reaper.BR_GetMediaTrackSendInfo_Track( track, REAPER.SEND, index-1, 1)
    local destCh = ChanOfTrack(dest)
    return destCh
end

function GetSendCount(chan)
    local track = GetTrack(chan)
    local count = reaper.GetTrackNumSends( track, REAPER.SEND ) --MSG('GetSendCount:chan',chan,'count',count)
    return count
end

function GetReceiveCount(chan)
    return reaper.GetTrackNumSends( GetTrack(chan), REAPER.RCV )
end

function GetReceive(chan, index)
    local track = GetTrack(chan)
    local srcTrack = reaper.BR_GetMediaTrackSendInfo_Track( track, REAPER.RCV, index-1, 0)
    return ChanOfTrack( srcTrack )
end

function RemoveReceive(chan, idx)
    local track = GetTrack(chan)  --MSG('removing receive '..idx..' from fx track '..tracknum)
    reaper.RemoveTrackSend( track, REAPER.RCV, idx-1 )
end

function GetNumberOfTrack(track)
    return reaper.GetMediaTrackInfo_Value( track, 'IP_TRACKNUMBER' )
end

function RemoveAllSends(chan,destCh)
    local src_track = GetTrack(chan)
    local dest_track = GetTrack(destCh)
    local send_count = reaper.GetTrackNumSends(src_track, REAPER.SEND)
    for i = send_count - 1, 0, -1 do -- loop from end
        local dest_track2 = reaper.BR_GetMediaTrackSendInfo_Track(src_track, REAPER.SEND, i, 1)
        if dest_track == dest_track2 then reaper.RemoveTrackSend(src_track, 0, i) end
    end
end

function AddSend(chan,destCh)
    RemoveAllSends(chan, destCh)
    local mediatrack = GetTrack(chan)
    local mediaFxTrack = GetTrack(destCh)
    if mediatrack and mediaFxTrack then
        reaper.CreateTrackSend( mediatrack, mediaFxTrack )
    else ERR('AddReceive, no track found: ', destCh, chan)
    end
end


function IsReceiveMuted(chan, index)
    local track = GetTrack(chan)
    local _, mute = reaper.GetTrackReceiveUIMute( track, index - 1)
    return IntToBool(mute)
end

function GetSendIndex(chan, destChan)
    for i = 1, GetSendCount(chan) do
        local dest = GetSendDest(chan, i)  --MSG('GetSendIndex: dest = ', dest, 'SourceChan = ',chan, 'index = ',i)
        if dest == destChan then
            return i
        end
    end
    --quietly fail
    MSG('no index for chan:',chan, ',dest:',destChan)
    return nil
end

function IsSendMuted(chan, destCh)
    local track = GetTrack(chan)
    local index = GetSendIndex(chan, destCh) --MSG('IsSendMuted: tracknum',chan, index)
    --indices are zero based here :^P
    if index then local _, mute = reaper.GetTrackSendUIMute( track , index - 1 )
            return IntToBool(mute)
    end
end

function MidiIN(chan, inputNum, enable)
    if not enable then --get status
        return IsSendMuted(inputNum, chan)
    else --set mute input
        local mute = not enable
        MuteSend(inputNum, chan, mute)
    end
end

--SET MUTE.  Silently fails if send does not exist
-- mute is boolean
function MuteSend(chan, destChan, Setmute)
    if Setmute == nil then Setmute = true end
    local index = GetSendIndex(chan, destChan)
    if index then
        reaper.SetTrackSendInfo_Value( GetTrack(chan), REAPER.SEND, index-1,'B_MUTE', BoolToInt(Setmute))
    end
end

function SetSendPreFader(chan, destChan)
    local index = GetSendIndex(chan, destChan)
    if index then
        local worked = reaper.SetTrackSendInfo_Value( GetTrack(chan), REAPER.SEND, index-1, 'I_SENDMODE',3 ) --MSG('SetSendPreFader: Success=',worked,'dest=',dest)
    end
end

function FlipPhase(chan, destChan, flipped) --MSG('SetSendPhase: track=',chan,'ph=',flipped)
    local idx = GetSendIndex(chan,destChan)
    local worked = reaper.SetTrackSendInfo_Value( GetTrack(chan), REAPER.SEND,idx-1, 'B_PHASE', BoolToInt(flipped))
end

function IsPhaseFlipped(chan, destCh)
    local idx = GetSendIndex(chan, destCh)
    if not idx then return false end
    local flipped = reaper.GetTrackSendInfo_Value(GetTrack(chan), REAPER.SEND,idx-1, 'B_PHASE')
    return flipped > 0
end

function SetOutputSend(chan,outputnum)
    --choice for out D will have to be stored in global preset
    for i = TRACKS.OUT_A,TRACKS.OUT_D do
        if outputnum == i then
            MuteSend(chan, outputnum, false)
        else MuteSend(chan, outputnum, true)
        end
    end
end
--query reaper for selected output
function GetOutputSend(chan)
    for i = TRACKS.OUT_A,TRACKS.OUT_D do
        if not IsSendMuted(chan,i) or
            (IsSendMuted(chan, i) and IsPhaseFlipped(chan, i) )
            then return i end
    end
    ERR("Get output send: Bad Output Mute State")
end

--for cueing: mute the send to current output buss and flip its phase
function Cue(chan,SetCue)
    local send = GetOutputSend(chan)  --MSG('Checking output send', send)
    if SetCue then                    --MSG('cue-muting send: ',send,', SetCue = ', SetCue)
        MuteSend(chan, send, SetCue)
        FlipPhase(chan, send, SetCue)
    else return IsSendMuted(chan,send)
    end
end
----------------------------------------------------------------------------------------------
--#############################################################################################
---------------------------------------EXPRESSION CONTROL-------------------------------------
--we should turn off expression, NOT by muting the midi rcv, but by BYPASSING THE MIDI VOL FX!!!
--thIs way, we don't have to worry about reSetting the value to max.
function ExpOn(chan, on)
    --reaper.TrackFX_SetOffline(trk, MIDIVOL.SLOT,not on)
    reaper.TrackFX_SetEnabled(  GetTrack(chan), MIDIVOL.SLOT, on )  --what's the difference???
end

function IsExpOn(chan)
    return reaper.TrackFX_GetEnabled(  GetTrack(chan), MIDIVOL.SLOT )
end

-----------------------------------------------------------------------------------------------
--#############################################################################################
---------------------------------------TRANSPORT CONTROLS -------------------------------------

function SetTempo(tempo)          --MSG('calling tempo:', tempo)
    reaper.SetCurrentBPM( 0, tempo, 0 )
    --Home()  --think this is an okay idea...

end

--might someday want to be able to locate to the nearest beat.
--Still don't know if beat fx work with transport stopped
function Home()
    reaper.Main_OnCommand( 40042, 0 )
end

function SetLoop( msrCount )
    --start point is zero.
    --end point is # measures at LOCAL tempo.  Needs to be converted to reaper tempo
    local reaperEnd =  reaper.TimeMap2_beatsToTime( getCurrentProject(), 0, msrCount )
    ---local localEnd = reaperEnd * (REAPER_TEMPO/LOCAL_TEMPO)  --or the reverse :\
    local loopstart, loopend = reaper.GetSet_LoopTimeRange( true, true, 0, reaperEnd, true )
end

function GetTempo()
    return  reaper.Master_GetTempo()
end

function Stop()
    reaper.Main_OnCommand(1016, 0)
end

function InitTempo()
    local bpm = GetTempo()
    MSG("BPM", bpm)
    LOCAL_TEMPO = bpm
    REAPER_TEMPO = bpm
    HEMIOLA = 1
    QUAVER = 1
    reaper.GetSetRepeat(1)
    SetLoop(16) --default to two measures for now
    reaper.Main_OnCommand( 1007, 0 )  --PLAY!
end
--get/set. reaper's tempo is a combination of these.
--LOCAL_TEMPO is the persisted displayTempo
--quaver is a multiplier of two
--hemiola is for triplet or dotted rhythms
function Tempo(displayTempo, quaver, hemiola ) --MSG("calling tempo: display = ", displayTempo, ', quaver = ',quaver,', modifier = ', hemiola)
    if not displayTempo and not hemiola and not quaver then return LOCAL_TEMPO end
    if quaver then QUAVER = quaver end
    if hemiola then HEMIOLA = hemiola end
    if displayTempo then LOCAL_TEMPO = Math.round(displayTempo) end --MSG('meter mod = ', HEMIOLA, ', beat mod = ', QUAVER)
    --round to one decimal place
    REAPER_TEMPO = Math.round(LOCAL_TEMPO * HEMIOLA * QUAVER * 10) / 10 -- MSG("Setting reaper tempo to: ", REAPER_TEMPO) MSG("local tempo = ", LOCAL_TEMPO)
    SetTempo(REAPER_TEMPO)
end
--reaper's denominator is always set to 4, and we can double or halve tempo from app...
function SetBeat(numerator)
    BEATS = numerator
    reaper.SetTempoTimeSigMarker(getCurrentProject(), 0, 0, -1,-1, GetTempo(),BEATS,4, true )
end
--------------------------------------------------------------------------------------------------------------
------#######################################################################################################
------------------------------------------------ FX LOADING ---------------------------------------------
function LoadInstrument(chan,vstname)
    --defer???
    --we will have to select a bank before re-adding the sends
    reaper.PreventUIRefresh(1)
    local oldName = GetPluginDisplayName(GetPlugName(chan, INSTRUMENT_SLOT))
    --MSG('new fx name = '..vstname, 'old name = '..oldName)
    if vstname ~= oldName then
        local track = GetTrack(chan)
        reaper.TrackFX_Delete( track, INSTRUMENT_SLOT )
        reaper.TrackFX_AddByName(track, vstname, false, -1)
        reaper.TrackFX_CopyToTrack( track, reaper.TrackFX_GetCount(track) - 1, track, 1, true )   --MSG('adding vst:'..vstname)
    end
    reaper.PreventUIRefresh(-1)
end


-----------------------------------------------------------------------------------------------
--###########################################################################################--
----------------------------------------EFFECT SWITCHING-------------------------------------
--ROUTING:  inst -> prefader sends (to fxchans) ^ dryLevel(track fader) -> postfader sends(to outputs)

function ClearChanSends()
    for send = 1, CH_COUNT do
        for rcv = 1, CH_COUNT do
            RemoveAllSends(send, rcv)
        end
    end
end

function ResetSends()
    ClearChanSends()
    for send = 1, CH_COUNT do
        for i, rcv in ipairs(GetChFxList(send)) do
            AddSend(send, rcv)
            SetSendPreFader(send, rcv)
            MuteSend(send, rcv, true)
            FlipPhase(send, rcv, true)
        end
    end
end

--remove the old send, and rebuild, in case there are non-conforming settings
--called on any bank change, as isFX is a bank setting
function SetChanFxStatus(chan, isfx)
    for dest = 1, CH_COUNT do
        if dest ~= chan then       --MSG('calling SetChanFxStatus:', chan, dest)
            local muted IsSendMuted(chan, dest)
            local unselected = IsPhaseFlipped(chan, dest)
            RemoveAllSends(dest, chan)
            if isfx then           --MSG('addReceive: adding receive to track ',dest,'from track ',chan)
                AddSend(dest, chan)
                SetSendPreFader(dest,chan)
                MuteSend(dest,chan, muted) --restore the mute setting
                FlipPhase(dest, chan, unselected)
            end
        end
    end
end

--###########################################################################################--
-------------------------------------FX LEVEL CONTROL-----------------------------------------
--THE VALUES OF VOLUME AND PAN ARE NOT THOSE SHOWING IN THE WKP.  THEY REPRESENT SEND LEVELS AND PANS!!!
--TODO!!!!!!!!   VALUES SHOULD BE STORED AS DB IN PRESETS AND IN THE INTERFACE.


--make the output sends post fader, and use the fader for the volume adjustment
--so we can store both the main volume, and the fx adjustment volume in the project.
local function setVolume(chan, level, useDB)
    if not useDB then -- do nothing
    else level = ultraschall.DB2MKVOL(level) end
    reaper.SetMediaTrackInfo_Value(GetTrack(chan), 'D_VOL', level)
end

local function getVolume(chan, useDB)
    local _, vol, pan = reaper.GetTrackUIVolPan(GetTrack(chan))
    if not useDB then return vol else return ultraschall.MKVOL2DB end
end
--fx sends are pre-fader, outputs are post fader
function SetFxLevel(chan, fxChan, fader)    --MSG('SetFxLevel: chan ', chan,'fader val =',fader)
    --MSG('fx channel = ', fxChan)
    local wetlevel = math.min(fader * 2, 1)
    local drylevel = math.min(2 - (fader * 2), 1)
    SetSendLevel(chan, fxChan, wetlevel)
    setVolume(chan,drylevel)
end

--need to reverse the math above...
function GetFxLevel(chan, fxchan)
    --get the fx send level as param. if it is less than 1, then return half its value
    local fxSendLevel = GetSendLevel(chan, fxchan)
    if fxSendLevel < 1 then return fxSendLevel / 2 end
    --get the track volume, which is the fx adjustment for full wet, as param. return half its value + .5
    local dryLevel = getVolume(chan)
    return ( (1- dryLevel) / 2 ) + .5
end

function SetSendLevel(chan, destCh, level, useDB)
    local sendIdx = GetSendIndex(chan, destCh)
    if sendIdx then
        if not useDB then --do nothing
        else level = ultraschall.DB2MKVOL(level) end
        reaper.SetTrackSendUIVol(GetTrack(chan), sendIdx-1, level, 0)
    else --MSG('MU--SET SEND LEVEL: chan',chan,'destChan',destCh,'level',level)
    end
end

function GetSendLevel(chan, destCh, returnDB)
    MSG('getting send level, ch',chan, 'to ', destCh)
    local sendIdx = GetSendIndex(chan, destCh)
    local _,vol,pan = reaper.GetTrackSendUIVolPan(GetTrack(chan), sendIdx - 1)   --MSG('getting send vol = ',vol, 'chan',chan,'dest chan',destCh)
    if not returnDB then return vol else return ultraschall.MKVOL2DB(vol) end
end
--trim is in db +-
--take or return volume as a paramVal 1..0
function Output(chan, volume, trim)
    if not trim then trim = 0 end
    if not volume then            MSG('Getting output', chan, 'of', math.exp((OutputDB(chan) - trim) / 20))
         return math.exp((OutputDB(chan) - trim) / 20)
    else                           MSG('Setting output', chan, 'to', volume)
        OutputDB(chan, (20 * math.log(volume)) + trim)
    end
end
--lets try storing values as db, which is more readable and meaningful  Edit: maybe eventually.
function OutputDB(chan, db)
    if not db then    MSG('volpan, track = ',chan,'output =',TRACKS.OUT_MON)
        local sendIdx = GetSendIndex(chan,TRACKS.OUT_MON)
         --should be the same as the others
        local _,vol,pan = reaper.GetTrackSendUIVolPan(GetTrack(chan), sendIdx-1 )   MSG('track,vol,pan = ', chan, vol, pan)
        return ultraschall.MKVOL2DB(vol)
    else
        local fader = ultraschall.DB2MKVOL(db)
        for output = TRACKS.OUT_MON, TRACKS.OUT_D do  MSG('SetFxLevel: track',output,', Setting level',fader)
             --using reaper idx now
            local sendIdx = GetSendIndex(chan, output)  --MSG('SetFxLevel: Setting level for index',sendIdx,'vol=', fader)
            if sendIdx then reaper.SetTrackSendUIVol(GetTrack(chan), sendIdx-1, fader, 0) end
        end
    end
end

function MuteOutputs(chan, mute)
    for output = TRACKS.OUT_MON, TRACKS.OUT_D do
        MuteSend(chan, output, mute )
    end
end

--panning is done at the output send
function Pan(chan, fader)
    if not fader then
        local _, vol, pan = reaper.GetTrackSendUIVolPan(GetTrack(chan), TRACKS.OUT_MON)
        return pan
    else
        for output = TRACKS.OUT_MON,TRACKS.OUT_D do
            local sendIdx = GetSendIndex(chan, output)
            reaper.SetTrackSendUIPan(GetTrack(chan), sendIdx - 1, fader, 0)
        end
    end
end

function GetMeter(chan)
    --val_to_dB = function(val) return 20*math.log(val, 10) end
    --dB_to_val = function(dB_val) return 10^(dB_val/20) end
    --peak = Track_GetPeakInfo(track, channel);
    local amp_dB = 8.6562;
    --peak_in_dB = amp_dB*log(peak);
    local track = GetTrack(tracknum)
    local peakL, peakR = reaper.Track_GetPeakInfo(track, 0 ), reaper.Track_GetPeakInfo(track, 1 )
    local dbL, dbR =  amp_dB*log(peakL),amp_dB*log(peakR)
    return 10^(dbL/20), 10^(dbR/20)  --MSG('level =',level,'chan = ',chan)
    --return levelL,levelR
end--]]
--------------------------------------------------------------------------------------------
---------------------------------NOTESOURCE SWITCHING---------------------------------------
--hopefully we can use MCS to make banks work equally well with roli or keyboard control
--Get or Set
function Notesource(chan,nsindex)
    if nsindex then
        --Set midiChStrip value for input type
        SetMoonParam(chan,MCS.KEYB_TYPE,nsindex)
        SetOutputByNotesource(chan,nsindex)
        MuteSendsByNotesource(chan,nsindex)
    else return GetMoonParam(chan,MCS.KEYB_TYPE)
    end
end

function SetOutputByNotesource( chan, nsindex)  --MSG('SetOutputByNotesource: nsindex=',nsindex)
    --If an inst has output D, it should NOT change with ns!  That's a separate hard out.
    local output = GetOutputSend(chan)          --MSG('SetOutputByNotesource: output=',output)
    if output ~= AUDIO_OUT.D then               --MSG('SetOutputByNotesource: Setting by notesource',nsindex)
        if nsindex == NS.KBD then
            SetOutputSend(chan, TRACKS.OUT_A)
        elseif nsindex == NS.ROLI then
            SetOutputSend(chan,TRACKS.OUT_B)
        elseif nsindex == NS.DUAL then
            SetOutputSend(chan,TRACKS.OUT_A)
        elseif nsindex == NS.NONE then
            SetOutputSend(chan,TRACKS.OUT_C)
        end
    end
end
--we should just look to the controller type in mcs for now
function MuteSendsByNotesource(chan,nsIndex)
    if nsIndex == NS.KBD then
        MuteSend(TRACKS.IN_KEYB,chan,false)
        MuteSend(TRACKS.IN_ROLI,chan,true)
    elseif nsIndex == NS.ROLI then
        MuteSend(TRACKS.IN_KEYB,chan,true)
        MuteSend(TRACKS.IN_ROLI,chan,false)
    elseif nsIndex == NS.DUAL then
        MuteSend(TRACKS.IN_KEYB,chan,false)
        MuteSend(TRACKS.IN_ROLI,chan,true)
    elseif nsIndex == NS.NONE then
        MuteSend(TRACKS.IN_KEYB,chan,true)
        MuteSend(TRACKS.IN_ROLI,chan,true)
    end
end

function IncrementNotesource(chan)
    local nsIndex = Notesource(chan)
    --increment it
    nsIndex = IncrementValue(nsIndex,0,NS_COUNT-1)
    Notesource(tracknum,nsIndex)
end

function DecrementNotesource(chan)
    local nsIndex = Notesource(chan)
    --decrement it
    nsIndex = DecrementValue(nsIndex,0,NS_COUNT-1)
    Notesource(tracknum,nsIndex)
end
-------------------------------------------------------------------------------------
---------------------------------------NOTE SOURCE SOLOING----------------------------
function TrackLimits(chan, lo, hi)
    if not lo or hi then
        return GetMoonParam(chan,MCS.LO_NOTE), GetMoonParam(chan, MCS.HI_NOTE) end
    if lo then SetMoonParam(chan,MCS.LO_NOTE,lo) end
    if hi then SetMoonParam(chan,MCS.HI_NOTE,hi) end
end

function NotesoloLimits(chan, lo, hi)
    if not lo or hi then
        return GetMoonParam(chan,MCS.NS_MUTE_LO), GetMoonParam(chan, MCS.NS_MUTE_HI) end
    if lo then SetMoonParam(chan,MCS.NS_MUTE_LO,lo) end
    if hi then SetMoonParam(chan,MCS.NS_MUTE_HI,hi) end
end


--returns table { 1 = chanNum, 2 = chanNum, etc. }
--of enabled channels with given nsNum
function GetChansWithNS(nsNum)
    local nsTracks = {}
    for i = 1, CH_COUNT do
        local chanNS = GetMoonParam( i, MCS.KEYB_TYPE)
        if chanNS == nsNum and GetMoonParam(i, MCS.MIDI_ON) == 1 then
            table.insert(nsTracks, i)
        end
    end
    return nsTracks
end

function GetNsSoloMuteRange(nsNum)
    local low = 127
    local high = 0
    for i,chan in ipairs(GetChansWithNS(nsNum)) do
        --MSG('GetNsSoloMuteRange: checking track', chan)
        if GetMoonParam(chan, MCS.NS_SOLO) == 1 then   --MSG('GetNsSoloMuteRange: track', chan)
             --look for nsoloed insts
            high = math.max(high, GetMoonParam(chan,MCS.HI_NOTE))
            low = math.min(low, GetMoonParam( chan,MCS.LO_NOTE))  --MSG('GetNsSoloMuteRange: low = ',low,'high=',high)
        end
    end
    return low,high
end

function NsSolo(chan, solo)
    if solo then                             --MSG('NSSOLO: val = ',solo)
        SetMoonParam(chan,MCS.NS_SOLO,solo)  --MSG('SetNsSolo: Setting nss to',solo,'track', chan)
        local nsNum = GetMoonParam(chan, MCS.KEYB_TYPE)
        local low, high = GetNsSoloMuteRange(nsNum) --MSG('SetNsSolo: low =',low,'high=',high)
        for i, chan in ipairs(GetChansWithNS(nsNum)) do
            if GetMoonParam(chan, MCS.NS_SOLO) ~= 1 then  --MSG('SetNsSolo: found non-soloed track',tracknum)
                if high > low then
                    SetMoonParam(chan, MCS.NS_MUTE_HI, high)
                    SetMoonParam(chan, MCS.NS_MUTE_LO, low)
                else --no note solo
                    SetMoonParam(chan, MCS.NS_SOLO,0)
                end
            end
        end
    else return GetMoonParam(chan, MCS.NS_SOLO)
    end
end

--###########################################################################################--
---------------------------------------AUDIO INPUT CONTROL------------------------------------
--when we load a template we will read the Setting of the audio input and configure the chan inputs
--may be unnecessary, if the template was saved with these Settings!
--it does insure that the track Setting matches what Is in midiChStrip
--  Set track to audio input

function SetAudioInput(tracknum,stereo, dev_name)
    local dev_id
    for i = 1,  reaper.GetNumAudioInputs() do
        local nameout =  reaper.GetInputChannelName( i-1 )
        ----MSG('SetAudioInput:  Device name =',nameout)
        if nameout:lower():match(dev_name:lower()) then dev_id = i-1 end
    end
    if not dev_id then ERR("SetAudioInput: Device Not Found: ", dev_name) return end
    reaper.SetMediaTrackInfo_Value( GetTrack(chan), 'I_RECINPUT',stereo + dev_id)
end

function RemoveAudioInput(tracknum)
    reaper.SetMediaTrackInfo_Value( GetTrack(tracknum), 'I_RECINPUT', -1)
end

function ClearRouting(chan)
    SetTrackSelected(chan)
    local commandID = reaper.NamedCommandLookup("_S&M_SENDS6") --remove sends
    reaper.Main_OnCommand(commandID, 0)
    local commandID = reaper.NamedCommandLookup("_S&M_SENDS5") --remove receives
    reaper.Main_OnCommand(commandID, 0)
end
--Only used when creating a wkp from scratch.  Still probably useful, but needs work.
--[[function ConfigureTrack(chan)
    --clear any fx sends or returns
    ClearRouting(chan)
    --add all outputs to the track:
    for out = TRACKS.OUT_MON,TRACKS.OUT_D do
        AddSend(chan,out)
    end
    --add midi inputs
    for inp = TRACKS.IN_KEYB,TRACKS.IN_BHR2 do
        AddReceive(chan,inp)
        --MuteSend(inp,chan,true)
    end
    --enable sustain
    --MuteSend(TRACKS.IN_SUS,chan,false)
    --enable drawbars
    if GetMoonParam(chan,MCS.USE_DRAWBARS) == 1 then
        MuteSend(chan,TRACKS.IN_DRWB, true)
    end
    --add sends for all effects tracks
    for i,effect in pairs(GetChFxList(chan)) do
        --MSG('ConfigureTrack: adding send to new track',effect)
        AddSend(chan,effect)
        MuteSend(chan,effect, true)
        SetSendPreFader(chan,effect)
    end
    --Is thIs an effect track???
    local input = GetMoonParam(chan,MCS.AUDIO_IN)
    if input == AUDIO_IN.MIXER or input == AUDIO_IN.BOTH then
        --add this track as muted send to every moon channel
        for i = 1, CH_COUNT do
            if i ~= chan then
                AddSend(chan,i)
                MuteSend(chan,i)
                SetSendPreFader(chan, i)
                --MSG('ConfigureTrack, adding send: ',track)
            end
        end
        --for sure effects will go out output C.  A or B will Get Set if NS changes
        SetMoonParam(chan, MCS.AUDIO_OUT, AUDIO_OUT.C)
    end
    if input == AUDIO_IN.EXT or input == AUDIO_IN.BOTH then
        --MSG('ConfigureTrack: Setting audio input',input)
        SetAudioInput(chan,REAPER.STEREO,INPUT_DEVICE_NAME)
    end
    if input == AUDIO_IN.NONE or input == AUDIO_IN.MIXER then
        --MSG('ConfigureTrack: removing audio input',input)
        RemoveAudioInput(chan)
    end
    --Inst will have a preferred NS
    local ns = GetMoonParam(chan,MCS.KEYB_TYPE)
    --MSG('ConfigureTrack: ns=',ns)
    MuteSendsByNotesource(chan,ns)
    SetOutputByNotesource(chan,ns)
    --Set effect to idx1, Volume off
    --if idx1 Is ourselves, thIs will fail. kludgey...but
    local fx = GetFxForIndex(1)
    if fx == chan then fx = GetFxForIndex(2) end
    MuteSend(chan,fx,false)
    SetFxLevel(chan,0)
end--]]

---------------------------------------------------------------------------------------------------------------
--#############################################################################################################
-------------------------------------------------PRESETS-----------------------------------------------

function incFxPreset(chan, fx)
    if not fx then fx = INSTRUMENT_SLOT end
    local presetmove = 1
    reaper.TrackFX_NavigatePresets( GetTrack(chan), fx, presetmove )
end
function decFxPreset(tracknum, fx)
    local track = GetTrack(tracknum)
    local presetmove = -1
    reaper.TrackFX_NavigatePresets( GetTrack(chan), fx, presetmove )
end
--
function SetFxPreset(chan, presetname) --Test:  if RPL and built-in have same name, RPL is chosen??
    MSG("SETTING FX PRESET, CHAN", chan)
    local unchanged, previous = reaper.TrackFX_GetPreset(GetTrack(chan), INSTRUMENT_SLOT, '')
    MSG('previous, current', previous, presetname)
    if previous ~= presetname then
        reaper.TrackFX_SetPreset( GetTrack(chan), INSTRUMENT_SLOT, presetname )
    end
end

function GetParamName(chan,fxnum, paramnum)
    local _, name = reaper.TrackFX_GetParamName( GetTrack(chan), fxnum, paramnum - 1, "" )--wtf? here the fx are zero based!  so are params.
    ----MSG('param name is'..name)
    return name
end
-----------------------------------------------------------PRESET CONVERSION-----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
local fxpText = '----  VST built-in programs  ----'
local rplText = '----  User Presets (.rpl)  ----'
local defaultText = 'Reset to factory default'

local function GetPresetList(chan, ignoreName, fxnum )
    if not fxnum then fxnum = INSTRUMENT_SLOT end
    if not ignoreName then ignoreName = '' end
    if not chan then chan = 1 end
    --if not factoryPresets then factoryPresets = false end
    local writeFile = true
    OpenPlugin(chan,fxnum)
    local fxName
    if GetFocusedFX() then
        ----MSG('chan num ='..chan, 'fx num '..fxnum)
        fxName = GetPlugName(chan)
        ----MSG('fx name = '..fxName)
    end
    local vstWindowTitle = reaper.JS_Localize(fxName, "common")
    local hwnd = reaper.JS_Window_Find(vstWindowTitle, false)
    local container = reaper.JS_Window_FindChildByID(hwnd, 0)
    local presetWindow = reaper.JS_Window_FindChildByID(container, 1000)
    local itemCount = reaper.JS_WindowMessage_Send(presetWindow, "CB_GETCOUNT", 0,0,0,0)
    -- save current index
    local cur_index = reaper.JS_WindowMessage_Send(presetWindow, "CB_GETCURSEL", 0,0,0,0)
    -- get indexes for start/end of user preset names --
    local presetLines = {}
    for i = 0, itemCount - 1 do  -- 0 is default text
        reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", i, 0,0,0)
        local name = reaper.JS_Window_GetTitle(presetWindow,"")
        table.insert(presetLines,name)

    end
    local rpls = {}
    local fxps = {}
    local onToFXPs = false
    for i, line in ipairs(presetLines) do
        if line == defaultText then --MSG(i,': ignoring default line')--do nothing
        elseif line ~= fxpText and line ~= rplText and not onToFXPs then  table.insert(rpls, line) ----MSG(i,': adding to rpls')
        elseif line == fxpText then onToFXPs = true ----MSG(i,': on to fxps')
        elseif line ~= ignoreName and line ~= rplText then table.insert(fxps, line)
        end
    end
    -- restore preset index
    reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", cur_index, 0,0,0)
    rpls =  RemoveDuplicates(ArraySort(rpls))
    fxps = RemoveDuplicates(ArraySort(fxps))
    ShowFX(chan, true)
    --reaper.TrackFX_Show(track, INSTRUMENT_SLOT, 2) --close the fx float
    return rpls, fxps
end

function ShowFX(chan, hide, slot)
    if not slot then slot = INSTRUMENT_SLOT end
    if not hide then hide = 3 else hide = 2 end
    return reaper.TrackFX_Show(GetTrack(chan), slot, hide)
end

function GetFXPs(tracknum, ignore, fxNum)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    if not ignore then ignore = '' end
    local _, fxps = GetPresetList(tracknum, ignore, fxNum)
    return fxps
end

function GetRPLs(chan)
    return GetPresetList(chan)
end

--This will overwrite rpls with vsts....
function WritePreset(chan, fxNum, presetName)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    if not presetName then presetName = GetChanPresetName(chan, fxNum) end
    local vstName = GetPlugName(chan, fxNum)
    --get track data
    local found, chunk = ultraschall.GetTrackStateChunk_Tracknumber(chan)
    if not found then ERR('Track chunk not found: ',chan, fxNum) end
    local data1 = ultraschall.GetFXStateChunk(chunk)
    local data2 = ultraschall.GetFXFromFXStateChunk(data1, fxNum + 1)  --ultraschall fx are 1-based
    local data3 = ultraschall.GetFXSettingsString_FXLines(data2)
    local data4 = ultraschall.Base64_Decoder(data3)
    local data = ultraschall.ConvertAscii2Hex(data4)
    ----MSG('data',data)
    --local data = getPresetHex(chan, fxNum)
    --prepare for writing file
    local presetFile = reaper.GetResourcePath()..'/presets/vst-'..vstName..'.ini'
    ----MSG('path = ', presetFile)
    local presetCount, key, section
    if reaper.file_exists(presetFile) then
        ultraschall.GetIniFileValue()
         _, presetCount =  reaper.BR_Win32_GetPrivateProfileString("General", "NbPresets", "", presetFile)
        section = 'Preset'..math.tointeger(presetCount)
    else section, presetCount = 'Preset0', 0
    end
    presetCount = math.tointeger(presetCount + 1)
    --Update/write number of presets
    ----MSG("GOT HERE")
    ultraschall.SetIniFileValue('General', 'NbPresets', presetCount, presetFile)
    local presetLength = #data
    local stringPos = 1
    for i = 1, math.ceil(presetLength/32768) do
        if i == 1 then key = 'Data' else key = 'Data_'..(i - 1) end
        local chunk = data:sub(stringPos, stringPos + 32767)
        local sum = 0
        for i = 1, #chunk, 2 do  sum = sum + tonumber( chunk:sub(i,i + 1), 16) end
        sum = string.sub( string.format("%X", sum), -2, -1 )
        ultraschall.SetIniFileValue(section, key, chunk..sum, presetFile)
        stringPos = stringPos + 32768
        --MSG('written: '..i)
    end
    ultraschall.SetIniFileValue(section,'Name', presetName, presetFile)
    ultraschall.SetIniFileValue(section,'Len', presetLength//2, presetFile)
    reaper.TrackFX_SetPreset(GetTrack(chan), fxNum, presetName)
end

local function loadFXPsForConversion(chan, fxNum, overwrite, ignore)
    ----MSG('loading fx for ch',chan,'fx',fxNum)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local rpls,fxps = GetPresetList(chan, ignore, fxNum)
    --MST(rpls, 'rpls')
    local convert = {}
    for i, name in ipairs(fxps) do
        ----MSG('checking fxp',name)
        if name ~= ignore then
            local presetExists = ArrayContains(rpls, name)
            --if presetExists then --MSG('preset exists: ',name) end
            if overwrite or (not overwrite and not presetExists) then
                table.insert(convert, {name = name, chan = chan, fx = fxNum})
            end
        end
    end
    --MST(convert,'convert')
    return convert
end

local function convertNextPreset(presetList, waitTime, presetNumber)
    local preset = presetList[presetNumber]
    local deferID = "PresetConversion"
    --MSG('Saving Preset: ', preset.name)
    for i, preset in ipairs(presetList) do
    WritePreset(preset.chan, preset.fx, preset.name) end
    --[[if presetNumber < #presetList then
        ----MSG('preset number', presetNumber)
        ultraschall.Defer(convertNextPreset(presetList, waitTime, presetNumber + 1), deferID, 2, waitTime)
    else ultraschall.StopDeferCycle(deferID)
    end--]]
end

function ConvertPresets(chan, fxNum, overwrite, ignorePresetsNamed, waitTime)
    local presetList = loadFXPsForConversion(chan, fxNum, overwrite, ignorePresetsNamed)
    convertNextPreset(presetList, waitTime, 1)
end

function Get_Strings_Until(stringTable, index, test)
    ----MSG('checking string: '..stringTable[index]..'index: '..index)
    if StartsWith(stringTable[index], test) then return index
    elseif index == #stringTable then return -1
    else return Get_Strings_Until(stringTable, index + 1, test)
    end
end

local function getFXLines(chan, fxNum)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local track = GetTrack(chan)
    local ret, Track_Chunk =  reaper.GetTrackStateChunk(track,"",false)
    local lines = {}
    for s in Track_Chunk:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end
    local chainIDX = Get_Strings_Until(lines, 1, "<FXCHAIN")
    local fxIDX = chainIDX + 1
    local FX_Type
    for i = 0,fxNum do
        fxIDX = Get_Strings_Until(lines, fxIDX, "<")
        FX_Type = lines[fxIDX]:sub(2,4)
        fxIDX = fxIDX + 1
    end
    local lastIDX = Get_Strings_Until(lines, fxIDX, ">") - 1
    return lines, fxIDX, lastIDX, chainIDX
end

function SaveMoonPreset(chan, fxNum)
    local lines, first, last  = getFXLines(chan, fxNum)
    local presetName = GetChanPresetName(chan, fxNum)
    local vstName = GetPlugName(chan, fxNum)
    local filename = BANK_FOLDER..vstName..'/'..presetName..'.MPF'
    ----MSG('file = '..filename)
    CreateFolder(BANK_FOLDER..vstName)
    local file = io.open(filename,'w+')
    ----MSG('writing to file: '..filename)
    --local chunkTable = {}
    for i = first,last do
        file:write(lines[i],'\n')
    end
    file:close()
end

function LoadMoonPreset(chan, fxNum, presetName)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local fxLines = {}
    local track = GetTrack(chan)
    local fileName = BANK_FOLDER..GetPlugName(chan, fxNum)..'/'..presetName..'.MPF'
    for line in io.lines(fileName) do
        fxLines[#fxLines + 1] = line
    end
    local trackChunkLines, first, last = getFXLines(chan, fxNum)
    local lastPart = {}
    local fxPart= {}
    local firstPart = {}
    for i = 1, first do firstPart[i] = trackChunkLines[i]end
    for i = last, #trackChunkLines do lastPart[i] = trackChunkLines[i] end
    for i = first, last do fxLines[i] = trackChunkLines[i - first + 1] end
    local bits = {}
    table.insert(bits,table.concat(firstPart,'\n'))
    table.insert(bits,table.concat(fxPart,'\n'))
    table.insert(bits,table.concat(lastPart,'\n'))
    local str = table.concat(bits,'\n')
    ----MSG('writing to ch '..str)
    reaper.SetTrackStateChunk(track, str, false)
end

---------------------------------------------------------------------------------------------------------------
--#############################################################################################################
-------------------------------------------------TESTING METHODS-----------------------------------------------

--function Test()
    --SaveMoonPreset(1)
    --LoadMoonPreset(1,INSTRUMENT_SLOT,'Black Market 0')
    --GetPresetList(1,'<empty>')
    --ConvertPresets(1, INSTRUMENT_SLOT, false, '<empty>', 1 )
    --WritePreset(1)
    --[[
    local table = {
        { name = 'element', color = 'blue'},
        {name ='thing', color = 'white'},
        {name ='unit', color = 'red'},
        {name ='piece', color = 'green'},
        {name = 'bit', color = 'cyan' }
    }
    MST(ArraySortByField(table, 'color'),'sorted')
    --]]

    --ends = 'test'
    --notend = 'west'
    --string = 'thisisatest'
    ----MSG('string end test: '..tostring(EndsWith(string,ends)))
    ----MSG('string end fail: '..tostring(EndsWith(string,notend)))

    --GetTrackChunk(1)
    --SavePreset(1,2,'TEST')
    ----MSG('test: Setting wet level',20)
    --SetFxLevel(20,.3)

    --cue(21,0)
    --IncFxNum(21)
    --SetTrackFxMuted(21,true)
    --SetTrackFxMuted(21,false)
    --GetRGB()
    --GetMeter(22,1)

    --MSG('testing')
    --Output(1, 1, 0)
    --SetFxLevel(1,.75)
    ----MSG('fxlevel = ', GetFxLevel(1))


--end

--ClearChanSends()
--AddSend(2,5)
--AddSend(2,5)
--AddSend(2,5)
--AddSend(2,5)
--AddSend(2,5)
--AddSend(2,5)
--RemoveSend(2,5)

--ClearChanSends()
--InitOutputRouting()
--MSG(Date())
--Test()
--reaper.Track_GetPeakInfo( track, chan ) --use for meters