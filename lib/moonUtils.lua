dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
local hsluv = require "hsluv"

DBG_OFF = false

-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
loadfile(libPath .. "scythe.lua")({printErrors = true})

local M = require("public.message")
local Table = require("public.table")
local T = Table.T

local moonTracks = nil

--require 'Save_VST_Preset'

IMAGE_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/Images/"
BANK_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/Banks/"
PRESET_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/Presets/"

BRIGHTNESS = 50

SCREEN_WIDTH = 1920
SCREEN_HEIGHT = 1080
TASKBAR_H = 30

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

--I/O track numbers   todo: Set controls to different channels on behringer
TRACKS = {  OUT_MASTER = 1,  --sum of A,B,C,D ??
            OUT_MON = 2,
            OUT_A = 3,
            OUT_B = 4,
            OUT_C = 5,
            OUT_D = 6,
            IN_MIDI = 7,
            IN_BHR2 = 8,    --behringer#2 - Reaper Control Unit port
            IN_ROLI = 9,   --notes and roli controls, I suppose? roli port/ all channels
            IN_KEYB = 10,   --notes only, yamaha, CH1
            IN_PB = 11,    --Yamaha Port, CH1
            IN_MOD = 12,   --Yamaha Port, CH1
            IN_ENC = 13,   --behringer port CH1
            IN_PUSH = 14,  --behringer port CH2
            IN_BTN_UP = 15,--behringer port CH3
            IN_BTN_DN = 16,--behringer port CH4
            IN_SUS = 17,   --FC port
            IN_FSW = 18,   --FC port
            IN_EXP = 19,   --FC port
            IN_PED2 = 20,  --FC port
            IN_AT = 21,    --drawbar port
            IN_DRWB = 22,  --drawbar port
            IN_ORG_CTL = 23,--drawbar port
}
FIRST_INST_TRACK = 24

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

AUDIO_IN = {
    NONE = 0, EXT = 1, MIXER = 2, BOTH = 3
}

NS_COUNT = 4
NS = {KBD = 0, DUAL = 1, ROLI = 2, NONE = 3}

--Audio outputs
AUDIO_OUT = {A = 0, B = 1, C = 2, D = 3}
--track numbers
OUT_OFFSET = 3 --difference between param#s and track# for outputs

REAPER = {SEND = 0, RCV = -1, STEREO = 1024, MONO = 0 }

NOTES = {'C','C#','D','Eb','E','F','F#','G','Ab','A','Bb','B'}

------------------LOCAL GLOBALS-------------------------------------
local previousNotesourceSetting = 0
local currentFxList = nil
local moonTracks = nil

function GetNoteName(noteNum)
    noteNum = math.floor(noteNum)
    local octave = math.floor(noteNum/12) - 2
    local note = noteNum % 12
    return NOTES[note + 1]..octave
end
-----------------------------------------------------------------------------------------------------------
---------------------------------------------BASIC UTILITIES-----------------------------------------------
function MSG(...)
    if DBG_OFF then return end
    local out = {}
    for _, v in ipairs({...}) do
      out[#out+1] = tostring(v)
    end
    reaper.ShowConsoleMsg(table.concat(out, " ").."\n")
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
    --MSG('value = '..value)
    if inc < 0 then return DecrementValue(value,min,max,wrap,0 - inc)
    else
        wrap = wrap or true
        if value == false then return true
        elseif value == true and wrap then return false
        elseif value == true then return true
        else
            --MSG('incrementValue:  val=',value,'max=',max)
            if value < min or value > max then
                ERR('incrementValue: value must be between min and max')
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
        if value < min or value > max then
            MSG('decrementValue: value must be between min and max')
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
    return rgb
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

--parses bank folder and returns a table with displayName = vstName
function GetBankFileTable(path)
    if not path then path = BANK_FOLDER end
    local table = {}
    for i,filename in pairs(GetFileList(path)) do
        --MSG('file = '..name)
        local parts = StringSplit(filename,'.')
        --TStr(parts,'parts')
        table[i] = { name = parts[1], vst = parts[2] }
        --MSG('part 1 = '..parts[1]..',part 2 = '..parts[2])
    end
    --TStr(table,'bank folder')
    return table
end

function GetPluginDisplayName(plugName, path)
    for name, vst in pairs(GetBankFileTable(path)) do
        if vst == plugName then return name end
    end
    return plugName --if no bank file, just use the dll filename2
end

-- Creates simple options from the files or the subfolders for a particular path
function OptionsFromPath(path, useFoldersNotFiles)
    local options = {}
    if useFoldersNotFiles then options = GetSubFolderList(path) else options = GetFileList(path) end
    --TStr(options, 'options')
    for i,filename in ipairs(options) do
        options[i] = { index = i, name = filename }
        --MSG('added item: '..filename)
    end
    return options
end

function CreateFolder(path)
    if EndsWith(path,'/') or EndsWith(path,'\\') then path = CleanComma(path) end
    return reaper.RecursiveCreateDirectory(path,0) > 0
end

---------------------------------------------------------------------------------------------------
----------------------------------------------------WINDOW UTILITIES-------------------------------

function CloseWindow(window)
    local title = window.name
    --MSG('window title = '..title)
    local hWnd = reaper.JS_Window_Find(title, true) -- find window by title bar text
    if hWnd ~=nil then reaper.JS_WindowMessage_Post(hWnd, "WM_CLOSE", 0,0,0,0) end
end

function Fullscreen(window, off)
    local title = window.name
    local win = reaper.JS_Window_Find(title, true)
    if not off then
        local style = reaper.JS_Window_GetLong(win, 'STYLE')
        if style then
            style = style & (0xFFFFFFFF - 0x00C40000) --removes window frame
            reaper.JS_Window_SetLong(win, "STYLE", style)
        end
        reaper.JS_Window_SetPosition(win, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT - 200)
    else window:reopen({})
    end
end

function ResizeWindow(window, x, y, w, h)
    local title = window.name
    local win = reaper.JS_Window_Find(title, true)
    reaper.JS_Window_SetPosition(win, x, y, w, h)
    window:update()
end

function GetLayoutXandY(i,x,y,w,h,rows)
    --MSG("layout: x = "..x)
    local xadj = math.floor((i - 1)/rows)
    local yadj = (i-1) % rows
    local xpos = x + (xadj * w)
    local ypos = y + (yadj * h)
    return xpos,ypos
end

--------------------------------------OPEN FX WINDOWS------------------------------------------
function OpenPlugin(chanNum,fxnum, useReaperIDX)
    reaper.TrackFX_Show( GetTrack(chanNum, useReaperIDX), fxnum, 3 )  --fx zero-based again...
end

function OpenVST(chanNum)
    OpenPlugin(chanNum, INSTRUMENT_SLOT)
end

function OpenMidiChStrip(chanNum,open)
    OpenPlugin(chanNum, MCS.SLOT)
end

function OpenMidiVol(chanNum,open)
    OpenPlugin(chanNum, MIDIVOL.SLOT)
end

function GetFocusedFX(useReaperIDX)
    local chanNum
    local found,tracknum,_,fxnum = reaper.GetFocusedFX() --ignore item number
    if found == 1 then found = true end
    if not useReaperIDX then chanNum = ChanOfTrack(tracknum) end
    return found, chanNum, fxnum
end

function GetLastTouchedFX(useReaperIDX)
    local chanNum
    local found, _, tracknum, fxnum, paramnum, _, _ = ultraschall.GetLastTouchedFX()
    if not useReaperIDX then chanNum = ChanOfTrack(tracknum) end
    return found, chanNum, fxnum, paramnum
end
----------------------------------------------------------------------------------------------------------
------------------------------------------------------TABLE UTILITIES-------------------------------------
function TStr(table,str)
    if not str then local str = 'table unknown' end
    if not table then return MSG('-----------TStr, table is nil: '..str) end
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
--returns the index of a table array that has a .name field that matches name, or a string that matches name
function IForName(array, name)
    for i,element in ipairs(array) do
        if type(element) == 'table' and element.name and (element.name == name) then return i end
        if type(element) == 'string' and element == name then return i end
    end
    return nil
end



function ArraySortByField(array, field)
    if not field then field = 'name' end
    local names = {}
    for i, element in ipairs(array) do
        TStr(element, 'element table')
        --if type(element) == 'table' then names[element.name] = element
        if type(element) == 'table' then names[element[field]] = element or ''
        elseif type(element) == 'string' then names[element] = element or ''
        end
    end
    --TStr(names,'names')
    local sorted =  TableSort(names)
    TStr(sorted,'sorted')
    for i, element in ipairs(sorted) do
        sorted[i] = names[element]
        --TStr(names[element])
    end
    return sorted

end

-------------------------------------------------------------------------------------------------------------
---------------------------------------------------STRING UTILITIES------------------------------------------

function StartsWith(sourceString, start)
    return sourceString:sub(1, string.len(start)) == start
 end

function EndsWith(sourceString, ending)
    local endString = sourceString:sub(string.len(sourceString) - string.len(ending) + 1, string.len(sourceString))
    --MSG('end string = '..endString..', ending = '..ending)
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
    return splitByPlainSeparator(str,sep,1000)
end

function Pad_zeros(str, places)
    if string.len(str) < places then
        return string.rep('0', places - string.len(str))..str
    else
        return str
    end
end

function Esc(str) return ("%q"):format(str) end

function CleanComma(s)  return s:sub(1, string.len(s) -2) end

---------------------------------------------------------------------
---------------------------------MOON PARAMS-------------------------
function PANIC()
    for i,chanNum in ipairs(GetMoonChans()) do
        SetMoonParam(chanNum, MCS.PANIC)
    end
end

function GetMoonParam(chanNum, param, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    MSG('getting Moon param,',param,', track: ',tracknum)
    local val,_,_ = reaper.TrackFX_GetParam( track, MCS.SLOT, param)
    MSG('param val = ',val)
    return val
end

function SetMoonParam(chanNum, param, val, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    --MSG('Setting moon param',param,'to',val)
    local _ = reaper.TrackFX_SetParam(track,MCS.SLOT,param,val)
end

function SetVolPlugParam(chanNum,param, val, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    local _ = reaper.TrackFX_SetParam(track,MIDIVOL.SLOT,param,val)
end

-------------------------------------------------------------------------------------------------
-------------------------------------TRACK METHODS-----------------------------------------------

function GetTrack(chanNum, useReaperIDX)
    local tracknum = IndexOfChan(chanNum, useReaperIDX)
    return reaper.GetTrack(0, tracknum - 1)
end

function GetSelectedTrackNumber()
    local tr = GetSelectedTrack(0,0)
    return GetNumberOfTrack(tr)
end

function GetChanNumForSelected()
    local track = reaper.GetSelectedTrack(0,0)
    if IsMoonTrack(track) then
        return reaper.GetMediaTrackInfo_Value( mediatrack,'IP_TRACKNUMBER')
    end
end

function GetSelectedTrack()
    local track = reaper.GetSelectedTrack(0,0)
    return track
end

function SetTrackSelected(chanNum, useReaperIDX)
    reaper.SetOnlyTrackSelected( GetTrack(chanNum, useReaperIDX))
end

function GetTrackCount()
    return reaper.CountTracks(0)
end

function GetNumberOfTrack(mediatrack)
    --(returns zero if not found, -1 for master track) (read-only, returns the int directly)
    local num = reaper.GetMediaTrackInfo_Value( mediatrack,'IP_TRACKNUMBER')
    if num == 0 then ERR('GetSelectedTrackNumber: Track Not Found')
    else return num
    end
end

function GetFXName(chanNum,slot, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    if not slot then slot = INSTRUMENT_SLOT end
    --MSG('GETFXNAME, tracknum = '..tracknum)
    local done,name = reaper.BR_TrackFX_GetFXModuleName(track,slot,"",128)--NOT SHOWN IN API DOCS!
    if done then --MSG('getting fx name: '..name)
    elseif track then ERR('MU.GetFXName--fx name failed at track,slot: ',tracknum,slot)
    end
    return GetFilename(name)  --strip off .dll
end

function ClearFX(chanNum, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    local count = reaper.TrackFX_GetCount(track)
    if count > 0 then
        for idx = reaper.TrackFX_GetCount(track) - 1, 0, -1 do
            reaper.TrackFX_Delete(track, idx)
        end
    end
end

function ChanName(chanNum,name, useReaperIDX)
    --preset name, presumably...
    local tracknum = IndexOfChan(chanNum, useReaperIDX)
    local track = GetTrack(tracknum)
    if not name then
        _, name = reaper.GetTrackName(track,'')
        return name
    else reaper.GetSetMediaTrackInfo_String(track, "P_NAME",name,true)
    end
end

--seems redundant to just return index, but it will clarify the code
function IndexOfChan(index, useReaperIDX)
    MSG('checking index of chan',index)
    if not useReaperIDX then
        local tracknum = index + FIRST_INST_TRACK - 1
        return  tracknum    --GetMoonChans()[index]
    else return index
    end
end

function ChanOfTrack(tracknum)
    local chanNum = tracknum - FIRST_INST_TRACK + 1
    if chanNum > 0 then return chanNum else MSG('No Channel for Track: '..tracknum) return nil end
end

--really just part of a check of conformity of the wkp
function IsMoonTrack(chanNum, useReaperIDX)
    --MSG('IsMoonTrack:  checking track:', chanNum)
    local track = GetTrack(chanNum, useReaperIDX)
    --GetTrack(tracknum)
    local fxSlot = MCS.SLOT
    local found,fxname = reaper.TrackFX_GetFXName(track, fxSlot, '')
    if found and fxnam == MCS.NAME then return true else return false end
end
-- For now we will assume we're not adding or removing moon tracks during use.
function GetMoonChans()
    if not moonTracks then  --create the moontracks table
        moonTracks = {}
        for i = 1, GetTrackCount() do
            if IsMoonTrack(i, true) then
                table.insert(moonTracks, ChanOfTrack(i))
                MSG('track is moon track: ', i, 'chan = ',ChanOfTrack(i))
            end
        end
    end
    return moonTracks
end

function EnableChan(chanNum,set, useReaperIDX)
    if set == nil then
        return GetMoonParam(chanNum, MCS.MIDI_ON, useReaperIDX)
    else
        SetMoonParam(chanNum, MCS.MIDI_ON, set, useReaperIDX)
    end
end

function ToggleTrackEnable(chanNum, useReaperIDX)
    if EnableChan(chanNum, useReaperIDX) == 0 then EnableChan(chanNum, 1, useReaperIDX)
    else EnableChan(tracknum, 0, useReaperIDX)
    end
end
--################################################################################################################--
--------------------------------------------SEND AND REcEIVE--------------------------------------------------------

function GetSendDest(chanNum,index, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    local desttr =  reaper.BR_GetMediaTrackSendInfo_Track( track, REAPER.SEND, index-1, 1)
    local destChan =  ChanOfTrack(GetNumberOfTrack(desttr))
    --MSG('GetSendDest: dest track = ',dest)
    return destChan
end

function GetSendCount(chanNum, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    return reaper.GetTrackNumSends( GetTrack(tracknum), REAPER.SEND )
end

function GetReceiveCount(chanNum, useReaperIDX)
    return reaper.GetTrackNumSends( GetTrack(chanNum, useReaperIDX), REAPER.RCV )
end

function GetReceive(chanNum,index, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    local srcTrack = reaper.BR_GetMediaTrackSendInfo_Track( track, REAPER.RCV, index-1, 0)
    return ChanOfTrack(GetNumberOfTrack( srcTrack ))
end

function RemoveReceive(chanNum,idx, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    --MSG('removing receive '..idx..' from fx track '..tracknum)
    reaper.RemoveTrackSend( track, REAPER.RCV, idx-1 )
end

function RemoveSend(chanNum,idx, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    reaper.RemoveTrackSend( track, REAPER.SEND, idx-1 )
end

function AddReceive(desttrack,srctrack, useReaperIDX)
    MSG('addReceive: adding receive to track ',srctrack,'from track ',srctrack)
    local mediatrack = GetTrack(srctrack, useReaperIDX)
    local mediaFxTrack = GetTrack(desttrack, useReaperIDX)
    if mediatrack and mediaFxTrack then
        reaper.CreateTrackSend( mediatrack, mediaFxTrack )
    else ERR('AddReceive, no track found: ', desttrack, srctrack)
    end
end

function AddSend(srctrack,desttrack)
    AddReceive(desttrack,srctrack)
end

function IsReceiveMuted(chanNum,index, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    local _, mute = reaper.GetTrackReceiveUIMute( track, index - 1)
    return IntToBool(mute)
end

function IsSendMuted(chanNum,index, useReaperIDX)
    local track = GetTrack(chanNum, useReaperIDX)
    MSG('IsSendMuted:  index =',index)
    --indices are zero based here :^P
    local _, mute = reaper.GetTrackSendUIMute( track , index - 1 )
    MSG('IsSendMuted: tracknum',chanNum, 'mute status = ', mute)
    return IntToBool(mute)
end

function GetSendIndex(chanNum,destChan, useReaperIDX)
    MSG('GetSendIndex:  chan =',chanNum,'dest chan =',destChan)
    for i = 1,GetSendCount(chanNum, useReaperIDX) do
        local dest = GetSendDest(chanNum,i, useReaperIDX)
        if dest == destChan then
            return i
        end
    end
end

--Get/Set method
function MuteSend(chanNum, destChan, Setmute, useReaperIDX)
    local source = IndexOfChan(chanNum, useReaperIDX)
    local dest = IndexOfChan(destChan, useReaperIDX)
    MSG('MuteSend: Set mute = ',Setmute,'dest = ',dest)
    if source == dest then return end  --thought we checked thIs elsewhere, but we'll do it again here!
    local index = GetSendIndex(source, dest, useReaperIDX)
    if index then
        MSG('MuteSend: found index = ',index,'dest = ',dest)
        if Setmute then reaper.SetTrackSendInfo_Value( GetTrack(source), REAPER.SEND, index-1,'B_MUTE', BoolToInt(Setmute))
        else return IsSendMuted(chanNum,index, useReaperIDX) end
    end
end

function SetSendPreFader(chanNum,destChan, useReaperIDX)
    local idx = GetSendIndex(chanNum,destChan, useReaperIDX)
    local worked = reaper.SetTrackSendInfo_Value( GetTrack(chanNum, useReaperIDX), REAPER.SEND, idx-1, 'I_SENDMODE',3 )
    --MSG('SetSendPreFader: Success=',worked,'dest=',dest)
end

function SetSendPhase(chanNum, destChan, flipped, useReaperIDX)
    --MSG('SetSendPhase: track=',tracknum,'ph=',flipped)
    local idx = GetSendIndex(chanNum,destChan, useReaperIDX)
    local worked = reaper.SetTrackSendInfo_Value( GetTrack(chanNum, useReaperIDX), REAPER.SEND,idx-1, 'B_PHASE', BoolToInt(flipped))
end

function GetSendPhase(chanNum, dest, useReaperIDX)
    local idx = GetSendIndex(chanNum, dest, useReaperIDX)
    local flipped = reaper.GetTrackSendInfo_Value(GetTrack(tracknum, useReaperIDX), REAPER.SEND,idx-1, 'B_PHASE')
    return flipped
end

function SetOutputSend(chanNum,outputnum, useReaperIDX)
    for i = TRACKS.OUT_A,TRACKS.OUT_D do
        if outputnum == i then
            MuteSend(chanNum, outputnum, false, useReaperIDX)
        else MuteSend(chanNum, outputnum, true, useReaperIDX)
        end
    end
end

function GetOutputSend(chanNum, useReaperIDX)
    local send = GetMoonParam(chanNum ,MCS.AUDIO_OUT, useReaperIDX )
    return send + OUT_OFFSET
end

--for cueing: mute the send to current output buss
function Cue(chanNum,SetCue)
    if SetCue then
        local send = GetOutputSend(chanNum)
        MSG('cue-muting send: ',send,', SetCue = ', SetCue)
        MuteSend(chanNum,send,SetCue)
    elseif IsSendMuted(chanNum,GetOutputSend(chanNum)) then return 1
    else return 0
    end
end
----------------------------------------------------------------------------------------------
--#############################################################################################
---------------------------------------EXPRESSION CONTROL-------------------------------------
--we should turn off expression, NOT by muting the midi rcv, but by BYPASSING THE MIDI VOL FX!!!
--thIs way, we don't have to worry about reSetting the value to max.
function ExpOn(chanNum, on, useReaperIDX)
    --reaper.TrackFX_SetOffline(trk, MIDIVOL.SLOT,not on)
    reaper.TrackFX_SetEnabled(  GetTrack(chanNum, useReaperIDX), MIDIVOL.SLOT, on )  --what's the difference???
end

function IsExpOn(chanNum, useReaperIDX)
    return reaper.TrackFX_GetEnabled(  GetTrack(chanNum, useReaperIDX), MIDIVOL.SLOT )
end

-----------------------------------------------------------------------------------------------
--#############################################################################################
---------------------------------------TRANSPORT CONTROLS -------------------------------------
function SetTempo(tempo)
    reaper.SetCurrentBPM( 0, tempo, 1 )
end

function GetTempo()
    return  reaper.Master_GetTempo()
end

-----------------------------------------------------------------------------------------------
--###########################################################################################--
----------------------------------------EFFECT SWITCHING-------------------------------------
--Need to look at thIs code again
--when we Set the effect, we are looking for a number from 1-n of available effect tracks
--for an instrument track thIs will be the fxtrack count.  for an effect track it will be COUNT- 1!!
--because it will not include the effect itself.
--so when Getting the lIst of available effects, we need to know who Is asking!!
function IsEffectCh(chanNum)
    --local IsFX = GetMoonParam(chanNum,MCS.AUDIO_IN)
    --return IsFX > 1  --0 no input, 1 exernal input
    --TODO:  need a bank to query for this.  No need to put it in MCS
    return true
end

--an array of all the channels with mixer inputs, i.e. effects
local function getFxList()
    if not currentFxList then
        currentFxList = {}
        for i, moonChanNum in ipairs(GetMoonChans()) do
            if IsEffectCh(moonChanNum) then table.insert(currentFxList, moonChanNum) end
        end
    else return currentFxList
    end
    return currentFxList
end

function SetEffect(chanNum,fxIdx)
    local tracknum = IndexOfChan(chanNum)
    MSG('SetEffect: tracknum =',tracknum,'fx idx=',fxIdx)
    local phMute = IsTrackEffectMuted(tracknum)
    for i,track in ipairs(GetEffectsForCh(tracknum)) do
        local active = (i ~= fxIdx)
        --MSG('SetEffect: track=',track,'active=',active)
        MuteSend(tracknum,track, active )
        --only mute the active effect, and only if it was muted before...
        SetSendPhase(tracknum, track, phMute and active)
    end
end
--need to include the channel, so it won't send to itself
function GetEffectsForCh(chanNum)
    local chFX = {}
    for i, moonChanNum in ipairs(getFxList()) do
        if moonChanNum ~= chanNum then
            table.insert(chFX, moonChanNum)
        end
    end
    return chFX
end

function GetFxChanName(chanNum)
    return GetFxPresetName(GetFxChan(chanNum))
end

function SetFxChanByName(name, chanNum)
    local idx
    local fx = GetEffectsForCh(chanNum)
    if #fx > 0 then
        for i, fxChan in ipairs(fx) do
            MSG('checking fx slot: '..i)
            if GetFxPresetName(fxChan) == name then idx = i end
        end
        if not idx then idx = 1 end
        SetEffect(chanNum, idx)
    else SetEffect(chanNum,1)
    end
end

function IncrementEffect(ChanNum,dec)
    local tracknum = IndexOfChan(chanNum)
    local idx,count = GetIndexForEffect(tracknum)
    MSG('IncrementEffect: count=',count,'idx=',idx)
    local inc = IncrementValue(idx,1,count,true)
    local dec = DecrementValue(idx,1,count,true)
    MSG('IncrementEffect: inc=',inc)
    if dec  then SetEffect(tracknum, dec)
            else SetEffect(tracknum, inc)
    end
end

function SetTrackEffectMuted(chanNum,mute)
    local tracknum = IndexOfChan(chanNum)
    --keep track of the last muted fx by reversing its phase
    local dest = GetFxChan(tracknum)
    MSG('SetTrackEffectMuted: tracknum=',tracknum,'dest=',dest)
    --muted =  IsSendMuted(tracknum,dest) --TODO: do we need thIs check?
    SetSendPhase(tracknum,dest,mute)
    MuteSend(tracknum,dest,mute)
end

--###########################################################################################--
-------------------------------------FX LEVEL CONTROL-----------------------------------------
--all done by send levels, either to effects or to outputs.
--sends are all pre-fader
function SetWetDryLevels(chanNum,fader, useReaperIDX)
    --MSG('SetWetDryLevels: track#=',tracknum,'fader val =',fader)
    local wetlevel = math.min(fader * 2, 1)
    local drylevel = math.min(2 - (fader * 2), 1)
    local sendIdx = GetSendIndex(chanNum,GetFxChan(chanNum), useReaperIDX)
    reaper.SetTrackSendUIVol( GetTrack(chanNum, useReaperIDX), MIDIVOL.SLOT, sendIdx-1, wetlevel*wetlevel, 0)
    Volume(chanNum,drylevel)
end

--need to reverse the math above...
function GetEffectLevel( chanNum, useReaperIDX)
    --TODO: SetWetDryLevelFader
    --wet =
end

function Volume(chanNum, fader, useReaperIDX)
    if not fader then
        local _,vol,pan = reaper.GetTrackSendUIVolPan(GetTrack(chanNum, useReaperIDX), TRACKS.OUT_MON) --should be the same as the others
        MSG('track,vol,pan = ',chanNum, vol, pan)
        return vol/vol, pan
    else
        for output = TRACKS.OUT_MON,TRACKS.OUT_D do
            --MSG('SetWetDryLevels: Setting level',fader)
            local sendIdx = GetSendIndex(tracknum,output)
            --MSG('SetWetDryLevels: Setting level for index',sendIdx,'vol=',dryVol)
            reaper.SetTrackSendUIVol(GetTrack(chanNum, useReaperIDX), sendIdx-1, fader*fader, 0)
        end
    end
end


function Pan(chanNum, fader, useReaperIDX)
    if not fader then
        local _, pan = Volume(chanNum, fader, useReaperIDX)
        return pan
    else
        for output = TRACKS.OUT_MON,TRACKS.OUT_D do
            local sendIdx = GetSendIndex(chanNum, output, useReaperIDX)
            reaper.SetTrackSendUIPan(GetTrack(chanNum, useReaperIDX), sendIdx - 1, fader, 0)
        end
    end
end

--[[
function GetMeter(tracknum,chan)
    --peak = Track_GetPeakInfo(track, channel);
    --amp_dB = 8.6562;
    --peak_in_dB = amp_dB*log(peak);
    local track = GetTrack(tracknum)
    local level = reaper.Track_GetPeakInfo( track, chan )
    --MSG('level =',level,'chan = ',chan)
    return level
end--]]
--------------------------------------------------------------------------------------------
---------------------------------KEYB_TYPE SWITCHING---------------------------------------

function Notesource(chanNum,nsindex, useReaperIDX) --Get or Set
    local tracknum = useReaperIDX or IndexOfChan(chanNum)
    if nsindex then
        --Set midiChStrip value for input type
        SetMoonParam(tracknum,MCS.KEYB_TYPE,nsindex)
        SetOutputByNotesource(tracknum,nsindex)
        MuteSendsByNotesource(tracknum,nsindex)
    else return GetMoonParam(tracknum,MCS.KEYB_TYPE, useReaperIDX)
    end
end

function SetOutputByNotesource( chanNum, nsindex, useReaperIDX)
    MSG('SetOutputByNotesource: nsindex=',nsindex)
    --If an inst has output D, it should NOT change with ns!
    local output = GetMoonParam(chanNum, MCS.AUDIO_OUT, useReaperIDX)
    MSG('SetOutputByNotesource: output=',output)
    if output ~= AUDIO_OUT.D then
        MSG('SetOutputByNotesource: Setting by notesource',nsindex)
        if nsindex == NS.KBD then
            SetOutputSend(chanNum, TRACKS.OUT_A, useReaperIDX)
            SetMoonParam(chanNum,MCS.AUDIO_OUT,AUDIO_OUT.A, useReaperIDX)
        elseif nsindex == NS.ROLI then
            SetOutputSend(chanNum,TRACKS.OUT_B, useReaperIDX)
            SetMoonParam(chanNum,MCS.AUDIO_OUT,AUDIO_OUT.B, useReaperIDX)
        elseif nsindex == NS.DUAL then
            SetOutputSend(chanNum,TRACKS.OUT_A, useReaperIDX)
            SetMoonParam(chanNum,MCS.AUDIO_OUT,AUDIO_OUT.A, useReaperIDX)
        elseif nsindex == NS.NONE then
            SetOutputSend(chanNum,TRACKS.OUT_C, useReaperIDX)
            SetMoonParam(chanNum,MCS.AUDIO_OUT,AUDIO_OUT.C, useReaperIDX)
        end
    else SetOutputSend(chanNum,TRACKS.OUT_D)
        MSG('SetOutputByNotesource: Setting by output D:', output)
    end
end

function MuteSendsByNotesource(tracknum,nsIndex, useReaperIDX)
    local tracknum = useReaperIDX or IndexOfChan(chanNum)
    if nsIndex == NS.KBD then
        MuteSend(TRACKS.IN_KEYB,tracknum,false)
        MuteSend(TRACKS.IN_ROLI,tracknum,true)
    elseif nsIndex == NS.ROLI then
        MuteSend(TRACKS.IN_KEYB,tracknum,true)
        MuteSend(TRACKS.IN_ROLI,tracknum,false)
    elseif nsIndex == NS.DUAL then
        MuteSend(TRACKS.IN_KEYB,tracknum,false)
        MuteSend(TRACKS.IN_ROLI,tracknum,true)
    elseif nsIndex == NS.NONE then
        MuteSend(TRACKS.IN_KEYB,tracknum,true)
        MuteSend(TRACKS.IN_ROLI,tracknum,true)
    end
end

function IncrementNotesource(tracknum, useReaperIDX)
    local tracknum = useReaperIDX or IndexOfChan(chanNum)
    local nsIndex = Notesource(tracknum)
    --increment it
    nsIndex = IncrementValue(nsIndex,0,NS_COUNT-1)
    Notesource(tracknum,nsIndex)
end

function DecrementNotesource(tracknum, useReaperIDX)
    local tracknum = IndexOfChan(chanNum, useReaperIDX)
    local nsIndex = Notesource(tracknum)
    --decrement it
    nsIndex = DecrementValue(nsIndex,0,NS_COUNT-1)
    Notesource(tracknum,nsIndex)
end
-------------------------------------------------------------------------------------
---------------------------------------NOTE SOURCE SOLOING----------------------------
--none of these need to deal with reaper indexes....
function TrackLimits(chanNum, lo, hi)
    if not lo or hi then
        return GetMoonParam(chanNum,MCS.LO_NOTE), GetMoonParam(chanNum, MCS.HI_NOTE) end
    if lo then SetMoonParam(chanNum,MCS.LO_NOTE,lo) end
    if hi then SetMoonParam(chanNum,MCS.HI_NOTE,hi) end
end

function NotesoloLimits(chanNum, lo, hi)
    if not lo or hi then
        return GetMoonParam(chanNum,MCS.NS_MUTE_LO), GetMoonParam(chanNum, MCS.NS_MUTE_HI) end
    if lo then SetMoonParam(chanNum,MCS.NS_MUTE_LO,lo) end
    if hi then SetMoonParam(chanNum,MCS.NS_MUTE_HI,hi) end
end

function GetNotesoloChans(nsNum)
    local nsTracks = {}
    for i, chanNum in ipairs(GetMoonChans()) do
        local chanNS = GetMoonParam( chanNum, MCS.KEYB_TYPE)
        if chanNS == nsNum then
            table.insert(nsTracks, chanNum)
        end
    end
    return nsTracks
end

function GetNsSoloMuteRange(nsNum)
    local low = 127
    local high = 0
    for i,chanNum in ipairs(GetNotesoloChans(nsNum)) do
        MSG('GetNsSoloMuteRange: checking track', chanNum)
        if GetMoonParam(chanNum, MCS.NS_SOLO) == 1 then --look for nsoloed insts
            MSG('GetNsSoloMuteRange: track', chanNum)
            high = math.max(high, GetMoonParam(chanNum,MCS.HI_NOTE))
            low = math.min(low, GetMoonParam( chanNum,MCS.LO_NOTE))
            MSG('GetNsSoloMuteRange: low = ',low,'high=',high)
        end
    end
    return low,high
end

function NsSolo(chanNum, solo)
    if solo then
        SetMoonParam(chanNum,MCS.NS_SOLO,solo)
        MSG('SetNsSolo: Setting nss to',solo,'track', chanNum)
        local nsNum = GetMoonParam(chanNum, MCS.KEYB_TYPE)
        local low, high = GetNsSoloMuteRange(nsNum)
        MSG('SetNsSolo: low =',low,'high=',high)
        for i, chanNum in ipairs(GetNotesoloChans(nsNum)) do
            if GetMoonParam(chanNum, MCS.NS_SOLO) ~= 1 then
                MSG('SetNsSolo: found non-soloed track',tracknum)
                if high > low then
                    SetMoonParam(chanNum, MCS.NS_MUTED,1)
                    SetMoonParam(chanNum, MCS.NS_MUTE_HI, high)
                    SetMoonParam(chanNum, MCS.NS_MUTE_LO, low)
                else --no note solo
                    SetMoonParam(chanNum, MCS.NS_SOLO,0)
                end
            end
        end
    else return GetMoonParam(chanNum, MCS.NS_SOLO)
    end
end

--###########################################################################################--
--------------------------------------- ADDING FX SENDS--------------------------------------
--After loading a new instrument (fxchain) we need to add a send for every effect in the mixer
--if the new inst Is an effect, we need to add every (other!) moon track in the mixer as a (muted) receive.
--###########################################################################################--
---------------------------------------AUDIO INPUT CONTROL------------------------------------
--when we load a template we will read the Setting of the audio input and configure the chan inputs
--may be unnecessary, if the template was saved with these Settings!
--it does insure that the track Setting matches what Is in midiChStrip
--  Set track to audio input

function SetAudioInput(tracknum,stereo, dev_name, useReaperIDX)
    local dev_id
    for i = 1,  reaper.GetNumAudioInputs() do
        local nameout =  reaper.GetInputChannelName( i-1 )
        --MSG('SetAudioInput:  Device name =',nameout)
        if nameout:lower():match(dev_name:lower()) then dev_id = i-1 end
    end
    if not dev_id then ERR("SetAudioInput: Device Not Found: ", dev_name) return end
    reaper.SetMediaTrackInfo_Value( GetTrack(chanNum, useReaperIDX), 'I_RECINPUT',stereo + dev_id)
end

function RemoveAudioInput(tracknum, useReaperIDX)
    reaper.SetMediaTrackInfo_Value( GetTrack(tracknum, useReaperIDX), 'I_RECINPUT', -1)
end

function ClearRouting(chanNum, useReaperIDX)
    SetTrackSelected( IndexOfChan(chanNum, useReaperIDX) )
    local commandID = reaper.NamedCommandLookup("_S&M_SENDS6") --remove sends
    reaper.Main_OnCommand(commandID, 0)
    local commandID = reaper.NamedCommandLookup("_S&M_SENDS5") --remove receives
    reaper.Main_OnCommand(commandID, 0)
end

--when loading a new fxchain...
function ConfigureTrack(chan)
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
        MuteSend(chan,TRACKS.IN_DRWB)
    end
    --add sends for all effects tracks
    for i,effect in pairs(GetEffectsForCh(chan)) do
        MSG('ConfigureTrack: adding send to new track',effect)
        AddSend(chan,effect)
        MuteSend(chan,effect,true)
        SetSendPreFader(chan,effect)
    end
    --Is thIs an effect track???
    local input = GetMoonParam(chan,MCS.AUDIO_IN)
    if input == AUDIO_IN.MIXER or input == AUDIO_IN.BOTH then
        --add thIs track as muted send to every moon channel
        for i,chanNum in ipairs(GetMoonChans()) do
            if chanNum ~= chan then
                AddSend(chanNum,chan)
                MuteSend(chanNum,chan,true)
                SetSendPreFader(chanNum,chan)
                MSG('ConfigureTrack, adding send: ',track)
            end
        end
        --for sure effects will go out output C.  A or B will Get Set if NS changes
        SetMoonParam(chan, MCS.AUDIO_OUT, AUDIO_OUT.C)
    end
    if input == AUDIO_IN.EXT or input == AUDIO_IN.BOTH then
        MSG('ConfigureTrack: Setting audio input',input)
        SetAudioInput(chan,REAPER.STEREO,INPUT_DEVICE_NAME)
    end
    if input == AUDIO_IN.NONE or input == AUDIO_IN.MIXER then
        MSG('ConfigureTrack: removing audio input',input)
        RemoveAudioInput(chan)
    end
    --Inst will have a preferred NS
    local ns = GetMoonParam(chan,MCS.KEYB_TYPE)
    MSG('ConfigureTrack: ns=',ns)
    MuteSendsByNotesource(chan,ns)
    SetOutputByNotesource(chan,ns)
    --Set effect to idx1, Volume off
    --if idx1 Is ourselves, thIs will fail. kludgey...but
    local fx = GetEffectForIndex(1)
    if fx == chan then fx = GetEffectForIndex(2) end
    MuteSend(chan,fx,false)
    SetWetDryLevels(chan,0)
end



--------------------------------------------------------------------------------------------------------------
------#######################################################################################################
------------------------------------------------ FX LOADING ---------------------------------------------

function LoadInstrument(chanNum,vstname)
    --defer???
    reaper.PreventUIRefresh(1)
    local oldName = GetFXName(chanNum, INSTRUMENT_SLOT)
    MSG('new fx name = '..vstname, 'old name = '..oldName)
    if vstname ~= oldName then
        local track = GetTrack(chanNum)
        reaper.TrackFX_Delete( track, INSTRUMENT_SLOT )
        reaper.TrackFX_AddByName(track, vstname, false, -1)
        reaper.TrackFX_CopyToTrack( track, reaper.TrackFX_GetCount(track) - 1, track, 1, true )
        --MSG('adding vst:'..vstname)
    end
    reaper.PreventUIRefresh(-1)
end

function SaveInstrument(chanNum, useReaperIDX)
    ClearRouting(chanNum, useReaperIDX)
    local name = GetInstName( chanNum, useReaperIDX)
    MSG('saveInstrument: name=',name)
end

function GetInstName()
    --todo
end

---------------------------------------------------------------------------------------------------------------
--#############################################################################################################
-------------------------------------------------PRESETS-----------------------------------------------

function incFxPreset(chanNum, fx, useReaperIDX)
    if not fx then fx = INSTRUMENT_SLOT end
    local presetmove = 1
    reaper.TrackFX_NavigatePresets( GetTrack(chanNum, useReaperIDX), fx, presetmove )
end
function decFxPreset(tracknum, fx)
    local track = GetTrack(tracknum)
    local presetmove = -1
    reaper.TrackFX_NavigatePresets( GetTrack(chanNum, useReaperIDX), fx, presetmove )
end
function SelectPreset(chanNum, presetname, useReaperIDX) --Test:  if RPL and built-in have same name, RPL is chosen??
    local trackNum = IndexOfChan(chanNum)
    reaper.TrackFX_SetPreset( GetTrack(trackNum, useReaperIDX), INSTRUMENT_SLOT, presetname )
end

function GetParamName(tracknum,fxnum, paramnum, useReaperIDX)
    local _, name = reaper.TrackFX_GetParamName( GetTrack(chanNum, useReaperIDX), fxnum, paramnum - 1, "" )--wtf? here the fx are zero based!  so are params.
    --MSG('param name is'..name)
    return name
end

local fxpText = '----  VST built-in programs  ----'
local rplText = '----  User Presets (.rpl)  ----'
local defaultText = 'Reset to factory default'

local function GetPresetList(chanNum, ignoreName, fxnum, useReaperIDX )
    if not fxnum then fxnum = INSTRUMENT_SLOT end
    if not ignoreName then ignoreName = '' end
    if not chanNum then chanNum = 1 end
    --if not factoryPresets then factoryPresets = false end
    local writeFile = true
    OpenPlugin(chanNum,fxnum, useReaperIDX)
    local fxName
    if GetFocusedFX() then
        --MSG('chan num ='..chanNum, 'fx num '..fxnum)
        fxName = GetFXName(chanNum, useReaperIDX)
        --MSG('fx name = '..fxName)
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
        if line == defaultText then MSG(i,': ignoring default line')--do nothing
        elseif line ~= fxpText and line ~= rplText and not onToFXPs then  table.insert(rpls, line) --MSG(i,': adding to rpls')
        elseif line == fxpText then onToFXPs = true --MSG(i,': on to fxps')
        elseif line ~= ignoreName and line ~= rplText then table.insert(fxps, line)
        end
    end
    -- restore preset index
    reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", cur_index, 0,0,0)
    rpls =  RemoveDuplicates(ArraySort(rpls))
    fxps = RemoveDuplicates(ArraySort(fxps))
    ShowFX(chanNum, true)
    --reaper.TrackFX_Show(track, INSTRUMENT_SLOT, 2) --close the fx float
    return rpls, fxps
end

function ShowFX(chanNum, hide, slot)
    if not slot then slot = INSTRUMENT_SLOT end
    if not hide then hide = 3 else hide = 2 end
    return reaper.TrackFX_Show(GetTrack(IndexOfChan(chanNum)), slot, hide)
end

function GetFXPs(tracknum, ignore, fxNum)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    if not ignore then ignore = '' end
    local _, fxps = GetPresetList(tracknum, ignore, fxNum)
    return fxps
end

function GetRPLs(chanNum)
    return GetPresetList(chanNum)
end

function GetFxPresetName(chanNum, fxNum, useReaperIDX)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local found, presetname = reaper.TrackFX_GetPreset(GetTrack(chanNum, useReaperIDX), fxNum, "")
    if found then return presetname else return 'No Preset' end
end

--This will overwrite rpls with vsts....
function WritePreset(chanNum, fxNum, presetName, useReaperIDX)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    if not presetName then presetName = GetFxPresetName(chanNum, fxNum) end
    local vstName = GetFXName(chanNum, fxNum)
    local trackNum = IndexOfChan(chanNum, useReaperIDX)
    --get track data
    local found, chunk = ultraschall.GetTrackStateChunk_Tracknumber(trackNum)
    if not found then ERR('Track chunk not found: ',trackNum, fxNum) end
    local data1 = ultraschall.GetFXStateChunk(chunk)
    local data2 = ultraschall.GetFXFromFXStateChunk(data1, fxNum + 1)  --ultraschall fx are 1-based
    local data3 = ultraschall.GetFXSettingsString_FXLines(data2)
    local data4 = ultraschall.Base64_Decoder(data3)
    local data = ultraschall.ConvertAscii2Hex(data4)
    --MSG('data',data)
    --local data = getPresetHex(chanNum, fxNum)
    --prepare for writing file
    local presetFile = reaper.GetResourcePath()..'/presets/vst-'..vstName..'.ini'
    --MSG('path = ', presetFile)
    local presetCount, key, section
    if reaper.file_exists(presetFile) then
        ultraschall.GetIniFileValue()
         _, presetCount =  reaper.BR_Win32_GetPrivateProfileString("General", "NbPresets", "", presetFile)
        section = 'Preset'..math.tointeger(presetCount)
    else section, presetCount = 'Preset0', 0
    end
    presetCount = math.tointeger(presetCount + 1)
    --Update/write number of presets
    --MSG("GOT HERE")
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
        MSG('written: '..i)
    end
    ultraschall.SetIniFileValue(section,'Name', presetName, presetFile)
    ultraschall.SetIniFileValue(section,'Len', presetLength//2, presetFile)
    reaper.TrackFX_SetPreset(GetTrack(trackNum, useReaperIDX), fxNum, presetName)
end

local function loadFXPsForConversion(chanNum, fxNum, overwrite, ignore)
    --MSG('loading fx for ch',chanNum,'fx',fxNum)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local rpls,fxps = GetPresetList(chanNum, ignore, fxNum)
    --TStr(rpls, 'rpls')
    local convert = {}
    for i, name in ipairs(fxps) do
        --MSG('checking fxp',name)
        if name ~= ignore then
            local presetExists = ArrayContains(rpls, name)
            --if presetExists then MSG('preset exists: ',name) end
            if overwrite or (not overwrite and not presetExists) then
                table.insert(convert, {name = name, chan = chanNum, fx = fxNum})
            end
        end
    end
    --TStr(convert,'convert')
    return convert
end

local function convertNextPreset(presetList, waitTime, presetNumber)
    local preset = presetList[presetNumber]
    local deferID = "PresetConversion"
    MSG('Saving Preset: ', preset.name)
    for i, preset in ipairs(presetList) do
    WritePreset(preset.chan, preset.fx, preset.name) end
    --[[if presetNumber < #presetList then
        --MSG('preset number', presetNumber)
        ultraschall.Defer(convertNextPreset(presetList, waitTime, presetNumber + 1), deferID, 2, waitTime)
    else ultraschall.StopDeferCycle(deferID)
    end--]]
end

function ConvertPresets(chanNum, fxNum, overwrite, ignorePresetsNamed, waitTime)
    local presetList = loadFXPsForConversion(chanNum, fxNum, overwrite, ignorePresetsNamed)
    convertNextPreset(presetList, waitTime, 1)
end

function Get_Strings_Until(stringTable, index, test)
    --MSG('checking string: '..stringTable[index]..'index: '..index)
    if StartsWith(stringTable[index], test) then return index
    elseif index == #stringTable then return -1
    else return Get_Strings_Until(stringTable, index + 1, test)
    end
end

local function getFXLines(chanNum, fxNum, useReaperIDX)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local track = GetTrack(chanNum, useReaperIDX)
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

function SaveMoonPreset(chanNum, fxNum)
    local lines, first, last  = getFXLines(chanNum, fxNum)
    local presetName = GetFxPresetName(chanNum, fxNum)
    local vstName = GetFXName(chanNum, fxNum)
    local filename = BANK_FOLDER..vstName..'/'..presetName..'.MPF'
    --MSG('file = '..filename)
    CreateFolder(BANK_FOLDER..vstName)
    local file = io.open(filename,'w+')
    --MSG('writing to file: '..filename)
    --local chunkTable = {}
    for i = first,last do
        file:write(lines[i],'\n')
    end
    file:close()
end

function LoadMoonPreset(chanNum, fxNum, presetName)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local fxLines = {}
    local track = GetTrack(chanNum)
    local fileName = BANK_FOLDER..GetFXName(chanNum, fxNum)..'/'..presetName..'.MPF'
    for line in io.lines(fileName) do
        fxLines[#fxLines + 1] = line
    end
    local trackChunkLines, first, last = getFXLines(chanNum, fxNum)
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
    --MSG('writing to ch '..str)
    reaper.SetTrackStateChunk(track, str, false)
end

---------------------------------------------------------------------------------------------------------------
--#############################################################################################################
-------------------------------------------------TESTING METHODS-----------------------------------------------

function Test()
    MSG('testing')
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
    TStr(ArraySortByField(table, 'color'),'sorted')
    --]]

    --ends = 'test'
    --notend = 'west'
    --string = 'thisisatest'
    --MSG('string end test: '..tostring(EndsWith(string,ends)))
    --MSG('string end fail: '..tostring(EndsWith(string,notend)))

    --GetTrackChunk(1)
    --SavePreset(1,2,'TEST')
    --MSG('test: Setting wet level',20)
    --SetWetDryLevels(20,.3)
    --ConfigureTrack(GetSelectedTrackNumber())

    --ClearRouting(GetSelectedTrackNumber())
    --loadInstrument(22,'MT-Guitar Rig')
    --loadInstrument(GetSelectedTrackNumber(),'Kontakt')
    --loadInstrument(GetSelectedTrackNumber(),'PrIsm')
    --loadInstrument(GetSelectedTrackNumber(),'Guitar Rig')

    --SetWetDryLevels(GetSelectedTrackNumber(),.1)
    --SetWetDryLevels(GetSelectedTrackNumber(),.3)
    --SetWetDryLevels(GetSelectedTrackNumber(),.5)
    --SetWetDryLevels(GetSelectedTrackNumber(),.7)
    --SetWetDryLevels(GetSelectedTrackNumber(),.9)

    --cue(21,0)
    --IncrementEffect(21)
    --SetTrackEffectMuted(21,true)
    --SetTrackEffectMuted(21,false)
    --GetRGB()
    --GetMeter(22,1)

end

function GetFxChan(chanNum)
    for i = 1,GetSendCount(chanNum) do
        MSG('GetFxChan: sendcount = ',GetSendCount(chanNum))
        local dest = GetSendDest(chanNum,i)
        MSG('GetFxChan: index',i,'destination Is',dest)
        local muted = IsSendMuted(chanNum,i)
        if IsMoonTrack(dest) and not muted then
            MSG('GetFxChan: dest =',dest)
            return ChanOfTrack(dest)
        end
    end
    --if the send has been muted, then the recently muted track will have been put out of phase
    for i = 1,GetSendCount(chanNum) do
        local dest = GetSendDest(chanNum,i)
        local phaseFlipped = GetSendPhase(chanNum,dest)
        if IsMoonTrack(dest) and phaseFlipped then
            return ChanOfTrack(dest)
        end
    end
    return GetSendDest(chanNum,1) --nothing selected at all, return first fx
end

function GetEffectForIndex(chanNum,index)
    --MSG('GetEffectForIndex: Get for index: ',index)
    local tracks,count = GetEffectsForCh(chanNum)
    MSG('GetEffectForIndex:  effect track = ',tracks[index])
    return tracks[index],count
end

function GetIndexForEffect(chanNum)
    local tracks,count = GetEffectsForCh(chanNum)
    for i, chan in ipairs(tracks) do
        MSG('GetIndexForEffect: i = ',i,', track = ',track)
        if chan == GetFxChan(chanNum) then
            MSG('GetIndexForEffect: returning index = ',i)
            return i,count
        end
    end
    if GetEffectForIndex(1) ~= chanNum then return 1,count
    else return 2,count
    end
end

function IsTrackEffectMuted(chanNum)
    for i,chan in ipairs(GetEffectsForCh(chanNum)) do
        if GetSendPhase(chanNum,chan) then return true
        end
    end
    return false
end



--Test()
--reaper.Track_GetPeakInfo( track, chan ) --use for meters