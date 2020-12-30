dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
local hsluv = require "hsluv"

DBG = false

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
            IN_BHR2 = 7,    --behringer#2 - Reaper Control Unit port
            IN_ROLI = 8,   --notes and roli controls, I suppose? roli port/ all channels
            IN_KEYB = 9,   --notes only, yamaha, CH1
            IN_PB = 10,    --Yamaha Port, CH1
            IN_MOD = 11,   --Yamaha Port, CH1
            IN_ENC = 12,   --behringer port CH1
            IN_PUSH = 13,  --behringer port CH2
            IN_BTN_UP = 14,--behringer port CH3
            IN_BTN_DN = 15,--behringer port CH4
            IN_SUS = 16,   --FC port
            IN_FSW = 17,   --FC port
            IN_EXP = 18,   --FC port
            IN_AT = 19,    --drawbar port
            IN_DRWB = 20,  --drawbar port
            IN_ORG_CTL = 21,--drawbar port
}
FIRST_INST_TRACK = 22

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
    HANDS = 4,
    LO_NOTE = 5,
    HI_NOTE = 6,
    NS_SOLO = 9,
    NS_MUTE_LO = 10,
    NS_MUTE_HI = 11,
    SUSTAIN = 12,
    HOLD = 13,
    EXPRESSION = 14,
    NOTESOURCE = 16,
    AUDIO_OUT = 25,
    AUDIO_IN = 26,
    USE_DRAWBARS = 27,
    HUE = 29,
    SAT = 30,
    NS_MUTED = 31
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

local previousNotesourceSetting = 0

NOTES = {'C','C#','D','Eb','E','F','F#','G','Ab','A','Bb','B'}

function GetNoteName(noteNum)
    noteNum = math.floor(noteNum)
    local octave = math.floor(noteNum/12) - 2
    local note = noteNum % 12
    return NOTES[note + 1]..octave
end
-----------------------------------------------------------------------------------------------------------
---------------------------------------------BASIC UTILITIES-----------------------------------------------
function GetTrackChunk(trackNum)
    dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

    local found, trackstatechunk = ultraschall.GetTrackStateChunk_Tracknumber(trackNum)
    print(trackstatechunk)
end

function Dbg(...)
    if DBG then
        --call M.Msg with args.... how?
    end
end

function IncrementValue(value,min,max,wrap,inc)
    inc = inc or 1
    --Dbg('value = '..value)
    if inc < 0 then return DecrementValue(value,min,max,wrap,0 - inc)
    else
        wrap = wrap or true
        if value == false then return true
        elseif value == true and wrap then return false
        elseif value == true then return true
        else
            --Dbg('incrementValue:  val=',value,'max=',max)
            if value < min or value > max then
                M.Msg('incrementValue: value must be between min and max')
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
            M.Msg('decrementValue: value must be between min and max')
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
    M.Msg("ERROR:  No file found containing: "..str)
end

function GetFileStartingWith(startsWith,path)
    if not path then path = BANK_FOLDER end
    for _,fileName in pairs(GetFileList(path)) do
        if StartsWith(fileName,startsWith) then return fileName
        end
    end
    M.Msg('No file found starting with: '..startsWith)
end

--parses bank folder and returns a table with displayName = vstName
function GetBankFileTable(path)
    if not path then path = BANK_FOLDER end
    local table = {}
    for i,name in pairs(GetFileList(path)) do
        --M.Msg('file = '..name)
        local parts = StringSplit(name,'.')
        --TStr(parts,'parts')
        table[parts[1]] = parts[2]
        --M.Msg('part 1 = '..parts[1]..',part 2 = '..parts[2])
    end
    --TStr(table,'bank folder')
    return table
end

function CreateFolder(path)
    if EndsWith(path,'/') or EndsWith(path,'\\') then path = CleanComma(path) end
    return reaper.RecursiveCreateDirectory(path,0) > 0
end

---------------------------------------------------------------------------------------------------
----------------------------------------------------WINDOW UTILITIES-------------------------------

function CloseWindow(window)
    local title = window.name
    M.Msg('window title = '..title)
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
    --M.Msg("layout: x = "..x)
    local xadj = math.floor((i - 1)/rows)
    local yadj = (i-1) % rows
    local xpos = x + (xadj * w)
    local ypos = y + (yadj * h)
    return xpos,ypos
end

--------------------------------------OPEN FX WINDOWS------------------------------------------
function OpenPlugin(tracknum,fxnum)
    local tr = GetTrack(tracknum)
    reaper.TrackFX_Show( GetTrack(tracknum), fxnum, 3 )  --fx zero-based again...
end

function OpenVST(tracknum)
    OpenPlugin(tracknum, INSTRUMENT_SLOT)
end

function OpenMidiChStrip(tracknum,open)
    OpenPlugin(tracknum, MCS.SLOT)
end

function OpenMidiVol(tracknum,open)
    OpenPlugin(tracknum, MIDIVOL.SLOT)
end

function GetLastTouchedFX()
    local _, _, tracknum, fxnum, paramnum, _, _ = ultraschall.GetLastTouchedFX()
    return tracknum, fxnum, paramnum
end
----------------------------------------------------------------------------------------------------------
------------------------------------------------------TABLE UTILITIES-------------------------------------
function TStr(table,str)
    if not str then local str = 'table unknown' end
    if not table then return M.Msg('-----------TStr, table is nil: '..str) end
    local val = nil
    if not str then str = table.name or 'TABLE' end
    if type(table) ~= 'table' then val = 'not a table' else val = Table.stringify(table) end
    return M.Msg('\nT:------['..str..']-----\n'..val..'\n---------------------------')
end

function ArraySort(t)
    local sorted = {}
    for i in ipairs(t) do table.insert(sorted,t[i]) end
    table.sort(sorted, function (a,b) return a:lower() < b:lower() end)
    return sorted
end

function TableSort(t)
    local sorted = {}
    for n in pairs(t) do table.insert(sorted, n) end
    table.sort(sorted, function (a,b) return a:lower() < b:lower() end)
    return sorted
end

function TableContains(table, element)
    for _, value in pairs(table) do
      if value == element then
        return true
      end
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
--returns the index of a table that has a .name field that matches name, or a string that matches name
function IForName(array, name)
    for i,element in ipairs(array) do
        if type(element) == 'table' and element.name and (element.name == name) then return i end
        if type(element) == 'string' and element == name then return i end
    end
    return nil
end

-------------------------------------------------------------------------------------------------------------
---------------------------------------------------STRING UTILITIES------------------------------------------

function StartsWith(sourceString, start)
    return sourceString:sub(1, string.len(start)) == start
 end

function EndsWith(sourceString, ending)
    local endString = sourceString:sub(string.len(sourceString) - string.len(ending) + 1, string.len(sourceString))
    --M.Msg('end string = '..endString..', ending = '..ending)
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
function GetMoonParam(tracknum,param)
    local track = GetTrack(tracknum)
    local val,_,_ = reaper.TrackFX_GetParam( track, MCS.SLOT, param)
    return val
end

function SetMoonParam(tracknum,param,val)
    local track = GetTrack(tracknum)
    Dbg('Setting moon param',param,'to',val)
    _ = reaper.TrackFX_SetParam(track,MCS.SLOT,param,val)
end

function SetVolParam(tracknum,param,val)
    local track = GetTrack(tracknum)
    _ = reaper.TrackFX_SetParam(track,MIDIVOL.SLOT,param,val)
end

-------------------------------------------------------------------------------------------------
-------------------------------------TRACK METHODS-----------------------------------------------

function GetTrack(tracknum)
    --Dbg('GetTrack: tracknum = ',tracknum)
    return reaper.GetTrack(0, tracknum - 1)
end

function GetSelectedTrackNumber()
    local tr = GetSelectedTrack(0,0)
    return GetNumberOfTrack(tr)
end

function GetSelectedTrack()
    local track = reaper.GetSelectedTrack(0,0)
    return track
end

function SetTrackSelected(tracknum)
    reaper.SetOnlyTrackSelected( GetTrack(tracknum) )
end

function GetTrackCount()
    return reaper.CountTracks(0)
end

function GetNumberOfTrack(mediatrack)
    --(returns zero if not found, -1 for master track) (read-only, returns the int directly)
    local num = reaper.GetMediaTrackInfo_Value( mediatrack,'IP_TRACKNUMBER')
    if num == 0 then M.Msg('GetSelectedTrackNumber: Track Not Found')
    else return num
    end
end

function GetFXName(tracknum,slot)
    local track = GetTrack(tracknum)
    --reaper.BR_TrackFX_GetFXModuleName(track, 0, "", 0)
    local done,name = reaper.BR_TrackFX_GetFXModuleName(track,slot,"",128)--NOT SHOWN IN API DOCS!
    if done then M.Msg('getting fx name: '..name)
    elseif track then M.Msg('fx name failed at track,slot: '..track,slot)
    end
    return GetFilename(name)  --strip off .dll
end

function ClearFX(tracknum)
    local trk = GetTrack(tracknum)
    local count = reaper.TrackFX_GetCount(trk)
    if count > 0 then
        for idx = reaper.TrackFX_GetCount(trk) - 1, 0, -1 do
            reaper.TrackFX_Delete(trk, idx)
        end
    end
end

function TrackName(tracknum,name)
    local track = GetTrack(tracknum)
    if name then reaper.GetSetMediaTrackInfo_String(track, "P_NAME",name,true)
    else _,name = reaper.GetTrackName(track,'')
        return name
    end
end

function IsMoonTrack(tracknum)
    --Dbg('IsMoonTrack:  checking track ',tracknum)
    local track = reaper.GetTrack(0, tracknum - 1)
    --GetTrack(tracknum)
    local fxSlot = MCS.SLOT
    local _,fxname = reaper.TrackFX_GetFXName(track, fxSlot, '')
    --Dbg('effect name in slot 1: ',fxname)
    return fxname == MCS.NAME
end

function GetMoonTracks()
    local mtracks = {}
    local count = 0
    for i = 1,GetTrackCount() do
        if IsMoonTrack(i) then
            table.insert(mtracks,i)
            count = count + 1
        end
    end
    return mtracks
end

function TrackEnable(track,enable)
    if enable == nil then
        return GetMoonParam(track,MCS.MIDI_ON)
    else
        SetMoonParam(track,MCS.MIDI_ON,enable)
    end
end

function ToggleTrackEnable(track)
    if TrackEnable(track) == 0 then TrackEnable(track,1)
    else TrackEnable(track,0)
    end
end
--################################################################################################################--
--------------------------------------------SEND AND REcEIVE--------------------------------------------------------

function GetSendDest(tracknum,index)
    --Dbg('GetSendDest:  checking send',index,'on track',tracknum)
    local track = GetTrack(tracknum)
    local desttr =  reaper.BR_GetMediaTrackSendInfo_Track( track, REAPER.SEND, index-1, 1)
    local dest = GetNumberOfTrack(desttr)
    --Dbg('GetSendDest: dest track = ',dest)
    return dest
end

function GetSendCount(tracknum)
    return reaper.GetTrackNumSends( GetTrack(tracknum), REAPER.SEND )
end

function GetReceiveCount(tracknum)
    return reaper.GetTrackNumSends( GetTrack(tracknum), REAPER.RCV )
end

function GetReceive(tracknum,index)
    local tr = GetTrack(tracknum)
    local srcTrack = reaper.BR_GetMediaTrackSendInfo_Track( tr, REAPER.RCV, index-1, 0)
    return GetNumberOfTrack( srcTrack )
end

function RemoveReceive(tracknum,idx)
    --Dbg('removing receive '..idx..' from fx track '..tracknum)
    reaper.RemoveTrackSend( GetTrack(tracknum), REAPER.RCV, idx-1 )
end

function RemoveSend(tracknum,idx)
    reaper.RemoveTrackSend( GetTrack(tracknum), REAPER.SEND, idx-1 )
end

function AddReceive(desttrack,srctrack)
    Dbg('addReceive: adding receive to track ',srctrack,'from track ',srctrack)
    local mediatrack = GetTrack(srctrack)
    local mediaFxTrack = GetTrack(desttrack)
    if mediatrack and mediaFxTrack then
        reaper.CreateTrackSend( mediatrack, mediaFxTrack )
    end
end

function AddSend(srctrack,desttrack)
    AddReceive(desttrack,srctrack)
end

function IsReceiveMuted(tracknum,index)
    local track = GetTrack(tracknum)
    local _, mute = reaper.GetTrackReceiveUIMute( track, index - 1)
    return IntToBool(mute)
end

function IsSendMuted(tracknum,index)
    local track = GetTrack(tracknum)
    Dbg('IsSendMuted:  index =',index)
    --indices are zero based here :^P
    local _, mute = reaper.GetTrackSendUIMute( track , index - 1 )
    Dbg('IsSendMuted: tracknum',tracknum,'mute status = ',mute)
    return IntToBool(mute)
end

function GetSendIndex(tracknum,destTrack)
    Dbg('GetSendIndex:  track=',tracknum,'destTrack=',destTrack)
    for i = 1,GetSendCount(tracknum) do
        local dest = GetSendDest(tracknum,i)
        if dest == destTrack then
            return i
        end
    end
end

--Get/Set method
function MuteSend(tracknum,dest,Setmute)
    Dbg('MuteSend: Set mute = ',Setmute,'dest = ',dest)
    if tracknum == dest then return end  --thought we checked thIs elsewhere, but we'll do it again here!
    local index = GetSendIndex(tracknum,dest)
    if index then
        Dbg('MuteSend: found index = ',index,'dest = ',dest)
        if Setmute then reaper.SetTrackSendInfo_Value( GetTrack(tracknum), REAPER.SEND, index-1,'B_MUTE', BoolToInt(Setmute))
        else return IsSendMuted(tracknum,index) end
    end
end

function SetSendPreFader(tracknum,dest)
    local idx = GetSendIndex(tracknum,dest)
    local worked = reaper.SetTrackSendInfo_Value( GetTrack(tracknum), REAPER.SEND, idx-1, 'I_SENDMODE',3 )
    --Dbg('SetSendPreFader: Success=',worked,'dest=',dest)
end

function SetSendPhase(tracknum, dest, flipped)
    --Dbg('SetSendPhase: track=',tracknum,'ph=',flipped)
    local idx = GetSendIndex(tracknum,dest)
    local worked = reaper.SetTrackSendInfo_Value(GetTrack(tracknum), REAPER.SEND,idx-1, 'B_PHASE', BoolToInt(flipped))
end

function GetSendPhase(tracknum,dest)
    local idx = GetSendIndex(tracknum,dest)
    local flipped = reaper.GetTrackSendInfo_Value(GetTrack(tracknum), REAPER.SEND,idx-1, 'B_PHASE')
    return flipped
end

function SetOutputSend(tracknum,outputnum)
    --Dbg('SetOutputSend: track=',tracknum,'outputnum=',outputnum)
    for i = TRACKS.OUT_A,TRACKS.OUT_D do
        if outputnum == i then
            MuteSend(tracknum,i,false)
        else MuteSend(tracknum,i,true)
        end
    end
end

function GetOutputSend(tracknum)
    local send = GetMoonParam(tracknum,MCS.AUDIO_OUT)
    --Dbg('output send, track = ',tracknum,'send =',send)
    return send + OUT_OFFSET
end

--for cueing: mute the send to current output buss
function Cue(tracknum,SetCue)
    if SetCue then
        local send = GetOutputSend(tracknum)
        Dbg('cue-muting send: ',send,', SetCue = ', SetCue)
        MuteSend(tracknum,send,SetCue)
    elseif IsSendMuted(tracknum,GetOutputSend(tracknum)) then return 1
    else return 0
    end
end
----------------------------------------------------------------------------------------------
--#############################################################################################
---------------------------------------EXPRESSION CONTROL-------------------------------------
--we should turn off expression, NOT by muting the midi rcv, but by BYPASSING THE MIDI VOL FX!!!
--thIs way, we don't have to worry about reSetting the value to max.
function BypassExpression(tracknum,byp)
    local tr = GetTrack(tracknum)
    reaper.TrackFX_SetOffline(tr, MIDIVOL.SLOT,byp)
    --reaper.TrackFX_SetEnabled( track, fx, enabled )  --what's the difference???
end

-----------------------------------------------------------------------------------------------
--#############################################################################################
---------------------------------------TRANSPORT CONTROLS -------------------------------------
function setTempo(tempo)
    reaper.SetCurrentBPM( 0, tempo, 1 )
end

-----------------------------------------------------------------------------------------------
--###########################################################################################--
----------------------------------------EFFECT SWITCHING-------------------------------------
--Need to look at thIs code again
--when we Set the effect, we are looking for a number from 1-n of available effect tracks
--for an instrument track thIs will be the fxtrack count.  for an effect track it will be COUNT- 1!!
--because it will not include the effect itself.
--so when Getting the lIst of available effects, we need to know who Is asking!!
function IsEffectTrack(tracknum)
    local IsFX = GetMoonParam(tracknum,MCS.AUDIO_IN)
    return IsFX > 1  --0 no input, 1 exernal input
end
--a lIst of all the instruments with mixer inputs, i.e. effects
function GetEffectsForTrack(tracknum)
    local effectTracks = {}
    local trackcount = GetTrackCount()
    Dbg('track count = ',trackcount)
    local effectCount = 0
    for i = 1,trackcount do
        if IsMoonTrack(i) and IsEffectTrack(i) and (i ~= tracknum) then
            effectCount = effectCount + 1
            Dbg('GetEffectsForTrack: adding effect track: ',i,'to table position ',effectCount)
            effectTracks[effectCount] = i
        end
    end
    return effectTracks,effectCount
end

function GetCurrentEffect(tracknum)
    for i = 1,GetSendCount(tracknum) do
        Dbg('GetCurrentEffect: sendcount = ',GetSendCount(tracknum))
        local dest = GetSendDest(tracknum,i)
        Dbg('GetCurrentEffect: index',i,'destination Is',dest)
        local muted = IsSendMuted(tracknum,i)
        if IsMoonTrack(dest) and not muted then
            Dbg('GetCurrentEffect: dest =',dest)
            return dest
        end
    end
    --if the send has been muted, then the recently muted track will have been put out of phase
    for i = 1,GetSendCount(tracknum) do
        local dest = GetSendDest(tracknum,i)
        local phaseFlipped = GetSendPhase(tracknum,dest)
        if IsMoonTrack(dest) and phaseFlipped then
            return dest
        end
    end
    return GetSendDest(tracknum,1) --nothing selected at all, return first fx
end

function GetEffectForIndex(tracknum,index)
    --Dbg('GetEffectForIndex: Get for index: ',index)
    local tracks,count = GetEffectsForTrack(tracknum)
    Dbg('GetEffectForIndex:  effect track = ',tracks[index])
    return tracks[index],count
end

function GetIndexForEffect(tracknum)
    --Dbg('GetIndexForEffect: track ',tracknum)
    local tracks,count = GetEffectsForTrack(tracknum)
    for i,track in ipairs(tracks) do
        Dbg('GetIndexForEffect: i = ',i,', track = ',track)
        if track == GetCurrentEffect(tracknum) then
            Dbg('GetIndexForEffect: returning index = ',i)
            return i,count
        end
    end
    if GetEffectForIndex(1) ~= tracknum then return 1,count
    else return 2,count
    end
end

function IsTrackEffectMuted(tracknum)
    for i,track in ipairs(GetEffectsForTrack(tracknum)) do
        if GetSendPhase(tracknum,track) then return true
        end
    end
    return false
end

function SetEffect(tracknum,fxIdx)
    Dbg('SetEffect: tracknum =',tracknum,'fx idx=',fxIdx)
    local phMute = IsTrackEffectMuted(tracknum)
    for i,track in ipairs(GetEffectsForTrack(tracknum)) do
        local active = (i ~= fxIdx)
        Dbg('SetEffect: track=',track,'active=',active)
        MuteSend(tracknum,track, active )
        --only mute the active effect, and only if it was muted before...
        SetSendPhase(tracknum, track, phMute and active)
    end
end

function IncrementEffect(tracknum,dec)
    local idx,count = GetIndexForEffect(tracknum)
    Dbg('IncrementEffect: count=',count,'idx=',idx)
    local inc = IncrementValue(idx,1,count,true)
    local dec = DecrementValue(idx,1,count,true)
    Dbg('IncrementEffect: inc=',inc)
    if dec  then SetEffect(tracknum, dec)
            else SetEffect(tracknum, inc)
    end
end

function SetTrackEffectMuted(tracknum,mute)
    --keep track of the last muted fx by reversing its phase
    local dest = GetCurrentEffect(tracknum)
    Dbg('SetTrackEffectMuted: tracknum=',tracknum,'dest=',dest)
    --muted =  IsSendMuted(tracknum,dest) --TODO: do we need thIs check?
    SetSendPhase(tracknum,dest,mute)
    MuteSend(tracknum,dest,mute)
end

--###########################################################################################--
-------------------------------------FX LEVEL CONTROL-----------------------------------------
--all done by send levels, either to effects or to outputs.
function SetWetDryLevels(tracknum,fader)
    --Dbg('SetWetDryLevels: track#=',tracknum,'fader val =',fader)
    local wetlevel = math.min(fader * 2, 1)
    local drylevel = math.min(2 - (fader * 2), 1)
    local sendIdx = GetSendIndex(tracknum,GetCurrentEffect(tracknum))
    reaper.SetTrackSendUIVol(GetTrack(tracknum), sendIdx-1, wetlevel*wetlevel, 0)
    Volume(tracknum,drylevel)
end


function GetEffectLevel(tracknum)
    --TODO: SetWetDryLevelFader
    --wet =
end

function Volume(tracknum,fader)
    if fader then
        for output = TRACKS.OUT_MON,TRACKS.OUT_D do
            --Dbg('SetWetDryLevels: Setting level',fader)
            local sendIdx = GetSendIndex(tracknum,output)
            --Dbg('SetWetDryLevels: Setting level for index',sendIdx,'vol=',dryVol)
            reaper.SetTrackSendUIVol(GetTrack(tracknum), sendIdx-1, fader*fader, 0)
        end
    else
        local _,vol,pan = reaper.GetTrackSendUIVolPan(GetTrack(tracknum),TRACKS.OUT_MON) --should be the same as the others
        return vol
    end
end
--[[
function GetMeter(tracknum,chan)
    --peak = Track_GetPeakInfo(track, channel);
    --amp_dB = 8.6562;
    --peak_in_dB = amp_dB*log(peak);
    local track = GetTrack(tracknum)
    local level = reaper.Track_GetPeakInfo( track, chan )
    --Dbg('level =',level,'chan = ',chan)
    return level
end--]]
--------------------------------------------------------------------------------------------
---------------------------------NOTESOURCE SWITCHING---------------------------------------

function Notesource(tracknumber,nsindex) --Get or Set
    if nsindex then
        --Set midiChStrip value for input type
        SetMoonParam(tracknumber,MCS.NOTESOURCE,nsindex)
        SetOutputByNotesource(tracknumber,nsindex)
        MuteSendsByNotesource(tracknumber,nsindex)
    else return GetMoonParam(tracknumber,MCS.NOTESOURCE)
    end
end

function SetOutputByNotesource(tracknumber,nsindex)
    Dbg('SetOutputByNotesource: nsindex=',nsindex)
    --If an inst has output D, it should NOT change with ns!
    local output = GetMoonParam(tracknumber,MCS.AUDIO_OUT)
    Dbg('SetOutputByNotesource: output=',output)
    if output ~= AUDIO_OUT.D then
        Dbg('SetOutputByNotesource: Setting by notesource',nsindex)
        if nsindex == NS.KBD then
            SetOutputSend(tracknumber,TRACKS.OUT_A)
            SetMoonParam(tracknumber,MCS.AUDIO_OUT,AUDIO_OUT.A)
        elseif nsindex == NS.ROLI then
            SetOutputSend(tracknumber,TRACKS.OUT_B)
            SetMoonParam(tracknumber,MCS.AUDIO_OUT,AUDIO_OUT.B)
        elseif nsindex == NS.DUAL then
            SetOutputSend(tracknumber,TRACKS.OUT_A)
            SetMoonParam(tracknumber,MCS.AUDIO_OUT,AUDIO_OUT.A)
        elseif nsindex == NS.NONE then
            SetOutputSend(tracknumber,TRACKS.OUT_C)
            SetMoonParam(tracknumber,MCS.AUDIO_OUT,AUDIO_OUT.C)
        end
    else SetOutputSend(tracknumber,TRACKS.OUT_D)
        Dbg('SetOutputByNotesource: Setting by output D,',output)
    end
end

function MuteSendsByNotesource(tracknumber,nsIndex)
    if nsIndex == NS.KBD then
        MuteSend(TRACKS.IN_KEYB,tracknumber,false)
        MuteSend(TRACKS.IN_ROLI,tracknumber,true)
    elseif nsIndex == NS.ROLI then
        MuteSend(TRACKS.IN_KEYB,tracknumber,true)
        MuteSend(TRACKS.IN_ROLI,tracknumber,false)
    elseif nsIndex == NS.DUAL then
        MuteSend(TRACKS.IN_KEYB,tracknumber,false)
        MuteSend(TRACKS.IN_ROLI,tracknumber,true)
    elseif nsIndex == NS.NONE then
        MuteSend(TRACKS.IN_KEYB,tracknumber,true)
        MuteSend(TRACKS.IN_ROLI,tracknumber,true)
    end
end

function IncrementNotesource(tracknumber)
    local nsIndex = Notesource(tracknumber)
    --increment it
    nsIndex = IncrementValue(nsIndex,0,NS_COUNT-1)
    Notesource(tracknumber,nsIndex)
end

function DecrementNotesource(tracknumber)
    local nsIndex = Notesource(tracknumber)
    --decrement it
    nsIndex = DecrementValue(nsIndex,0,NS_COUNT-1)
    Notesource(tracknumber,nsIndex)
end
-------------------------------------------------------------------------------------
---------------------------------------NOTESOURCE SOLOING----------------------------
function TrackLimits(tracknumber, lo,hi)
    if not lo or hi then
        return GetMoonParam(tracknumber,MCS.LO_NOTE), GetMoonParam(tracknumber,MCS.HI_NOTE) end
    if lo then SetMoonParam(tracknumber,MCS.LO_NOTE,lo) end
    if hi then SetMoonParam(tracknumber,MCS.HI_NOTE,hi) end
end

function NotesoloLimits(tracknumber, lo, hi)
    if not lo or hi then
        return GetMoonParam(tracknumber,MCS.NS_MUTE_LO), GetMoonParam(tracknumber,MCS.NS_MUTE_HI) end
    if lo then SetMoonParam(tracknumber,MCS.NS_MUTE_LO,lo) end
    if hi then SetMoonParam(tracknumber,MCS.NS_MUTE_HI,hi) end
end

function GetTracksWithNS(nsNum)
    local nsTracks = {}
    for i,tracknum in ipairs(GetMoonTracks()) do
        local trackns = GetMoonParam(tracknum,MCS.NOTESOURCE)
        if trackns == nsNum then
            table.insert(nsTracks,tracknum)
        end
    end
    return nsTracks
end

function GetNsSoloMuteRange(nsNum)
    local low = 127
    local high = 0
    for i,tracknum in ipairs(GetTracksWithNS(nsNum)) do
        Dbg('GetNsSoloMuteRange: checking track',tracknum)
        if GetMoonParam(tracknum,MCS.NS_SOLO) == 1 then --look for nsoloed insts
            Dbg('GetNsSoloMuteRange: track',tracknum)
            high = math.max(high,GetMoonParam(tracknum,MCS.HI_NOTE))
            low = math.min(low,GetMoonParam(tracknum,MCS.LO_NOTE))
            Dbg('GetNsSoloMuteRange: low = ',low,'high=',high)
        end
    end
    return low,high
end

function NsSolo(tracknumber,solo)
    if solo then
        SetMoonParam(tracknumber,MCS.NS_SOLO,solo)
        Dbg('SetNsSolo: Setting nss to',solo,'track',tracknumber)
        local nsNum = GetMoonParam(tracknumber,MCS.NOTESOURCE)
        local low,high = GetNsSoloMuteRange(nsNum)
        Dbg('SetNsSolo: low =',low,'high=',high)
        for i,tracknum in ipairs(GetTracksWithNS(nsNum)) do
            if GetMoonParam(tracknum,MCS.NS_SOLO) ~= 1 then
                Dbg('SetNsSolo: found non-soloed track',tracknum)
                if high > low then
                    SetMoonParam(tracknum,MCS.NS_MUTED,1)
                    SetMoonParam(tracknum,MCS.NS_MUTE_HI, high)
                    SetMoonParam(tracknum,MCS.NS_MUTE_LO,low)
                else --no note solo
                    SetMoonParam(tracknum,MCS.NS_SOLO,0)
                end
            end
        end
    else return GetMoonParam(tracknumber,MCS.NS_SOLO)
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

function SetAudioInput(tracknum,stereo, dev_name)
    local dev_id
    for i = 1,  reaper.GetNumAudioInputs() do
        local nameout =  reaper.GetInputChannelName( i-1 )
        --Dbg('SetAudioInput:  Device name =',nameout)
        if nameout:lower():match(dev_name:lower()) then dev_id = i-1 end
    end
    if not dev_id then return end
    local tr = GetTrack(tracknum)
    reaper.SetMediaTrackInfo_Value( tr, 'I_RECINPUT',stereo + dev_id)
end

function RemoveAudioInput(tracknum)
    reaper.SetMediaTrackInfo_Value(GetTrack(tracknum), 'I_RECINPUT',-1)
end

function ClearRouting(track)
    SetTrackSelected(track)
    local commandID = reaper.NamedCommandLookup("_S&M_SENDS6") --remove sends
    reaper.Main_OnCommand(commandID, 0)
    local commandID = reaper.NamedCommandLookup("_S&M_SENDS5") --remove receives
    reaper.Main_OnCommand(commandID, 0)
end

--when loading a new fxchain...
function ConfigureTrack(newtrack)
    --clear any fx sends or returns
    ClearRouting(newtrack)
    --add all outputs to the track:
    for out = TRACKS.OUT_MON,TRACKS.OUT_D do
        AddSend(newtrack,out)
    end
    --add midi inputs
    for inp = TRACKS.IN_KEYB,TRACKS.IN_BHR2 do
        AddReceive(newtrack,inp)
        --MuteSend(inp,newtrack,true)
    end
    --enable sustain
    --MuteSend(TRACKS.IN_SUS,newtrack,false)
    --enable drawbars
    if GetMoonParam(newtrack,MCS.USE_DRAWBARS) == 1 then
        MuteSend(newtrack,TRACKS.IN_DRWB,true)
    end
    --add sends for all effects tracks
    for i,effect in pairs(GetEffectsForTrack(newtrack)) do
        Dbg('ConfigureTrack: adding send to new track',effect)
        AddSend(newtrack,effect)
        MuteSend(newtrack,effect,true)
        SetSendPreFader(newtrack,effect)
    end
    --Is thIs an effect track???
    local input = GetMoonParam(newtrack,MCS.AUDIO_IN)
    if input == AUDIO_IN.MIXER or input == AUDIO_IN.BOTH then
        --add thIs track as muted send to every moon channel
        for i,track in ipairs(GetMoonTracks()) do
            if track ~= newtrack then
                AddSend(track,newtrack)
                MuteSend(track,newtrack,true)
                SetSendPreFader(track,newtrack)
                Dbg('ConfigureTrack, adding send: ',track)
            end
        end
        --for sure effects will go out output C.  A or B will Get Set if NS changes
        SetMoonParam(newtrack,MCS.AUDIO_OUT,AUDIO_OUT.C)
    end
    if input == AUDIO_IN.EXT or input == AUDIO_IN.BOTH then
        Dbg('ConfigureTrack: Setting audio input',input)
        SetAudioInput(newtrack,REAPER.STEREO,INPUT_DEVICE_NAME)
    end
    if input == AUDIO_IN.NONE or input == AUDIO_IN.MIXER then
        Dbg('ConfigureTrack: removing audio input',input)
        RemoveAudioInput(newtrack)
    end
    --Inst will have a preferred NS
    local ns = GetMoonParam(newtrack,MCS.NOTESOURCE)
    Dbg('ConfigureTrack: ns=',ns)
    MuteSendsByNotesource(newtrack,ns)
    SetOutputByNotesource(newtrack,ns)
    --Set effect to idx1, Volume off
    --if idx1 Is ourselves, thIs will fail. kludgey...but
    local fx = GetEffectForIndex(1)
    if fx == newtrack then fx = GetEffectForIndex(2) end
    MuteSend(newtrack,fx,false)
    SetWetDryLevels(newtrack,0)
end


---------------------------------------------------------------------------------------------------------------
--#############################################################################################################
-------------------------------------------------PRESET SELECTION-----------------------------------------------

function incFxPreset(tracknum, fx)
    local track = GetTrack(tracknum)
    local presetmove = 1
    reaper.TrackFX_NavigatePresets( track, fx, presetmove )
end
function decFxPreset(tracknum, fx)
    local track = GetTrack(tracknum)
    local presetmove = -1
    reaper.TrackFX_NavigatePresets( track, fx, presetmove )
end
function SelectPreset(tracknum,fxnum, presetname) --Test:  if RPL and built-in have same name, RPL is chosen??
    local track = GetTrack(tracknum)
    reaper.TrackFX_SetPreset( track, INSTRUMENT_SLOT, presetname )
end

function SavePreset(tracknum,presetname)
    if not presetname then presetname = 'test' end  --get current preset name...
    local found, trackstatechunk = ultraschall.GetTrackStateChunk_Tracknumber(tracknum)
    --M.Msg('TRACK_CHUNK\n'..trackstatechunk)
    local fxStateChunk = ultraschall.GetFXStateChunk(trackstatechunk)
    --M.Msg("FX_CHUNK\n"..fxStateChunk)
    local fx_lines, startoffset, endoffset = ultraschall.GetFXFromFXStateChunk(fxStateChunk, 2)
    local fx_statestring_base64, fx_statestring = ultraschall.GetFXSettingsString_FXLines(fx_lines)
    M.Msg('State String'..fx_lines)
    --ultraschall.SaveFXStateChunkAsRFXChainfile( string filename, string FXStateChunk)
end

function GetParamName(tracknum,fxnum, paramnum)
    --M.Msg('getting param name for ',tracknum,fxnum,paramnum)
    local track = GetTrack(tracknum)
    local _, name = reaper.TrackFX_GetParamName( track, fxnum, paramnum - 1, "" )--wtf? here the fx are zero based!  so are params.
    --M.Msg('param name is'..name)
    return name
end
--------------------------------------------------------------------------------------------------------------
------#######################################################################################################
------------------------------------------------ FX LOADING ---------------------------------------------

function LoadInstrument(tracknum,vstname)
    local track = GetTrack(tracknum)
    reaper.PreventUIRefresh(1)
    M.Msg('tracknum = '..tracknum)
    local oldName = GetFXName(tracknum, INSTRUMENT_SLOT)
    M.Msg('new fx name = '..vstname, 'old name = '..oldName)
    if vstname ~= oldName then
        reaper.TrackFX_Delete( track, INSTRUMENT_SLOT )
        reaper.TrackFX_AddByName(track, vstname, false, -1)
        reaper.TrackFX_CopyToTrack( track, reaper.TrackFX_GetCount(track) - 1, track, 1, true )
        M.Msg('adding vst:'..vstname)
    end
    reaper.PreventUIRefresh(-1)
end

function SaveInstrument(tracknum)
    ClearRouting(tracknum)
    local name = GetInstName(tracknum)
    Dbg('saveInstrument: name=',name)

end

function GetInstName()
    --todo
end

---------------------------------------------------------------------------------------------------------------
-------------------------------------------------GET PRESETS---------------------------------------------------

local vstText = '----  VST built-in programs  ----'
local userText = '----  User Presets (.rpl)  ----'

local function GetPresetList(tracknum, factory, ignoreName, fxnum )
    if not fxnum then fxnum = INSTRUMENT_SLOT end
    if not ignoreName then ignoreName = '' end
    if not tracknum then tracknum = 1 end
    if not factory then factory = false end
    local writeFile = true  --true:write, false, write to console
    --Check that fx window is focused----------------------------------------------------
    OpenPlugin(tracknum,fxnum)
    local focused
    focused,tracknum,_,fxnum = reaper.GetFocusedFX()
    local track = GetTrack(tracknum)
    local fx_name
    if focused then
        --M.Msg('track num ='..tracknum, 'fx num '..fxnum)

        _,fx_name = reaper.TrackFX_GetFXName(track, fxnum,"")
        --M.Msg('fx name = '..fx_name)
    end
    local vstWindowTitle = reaper.JS_Localize(fx_name, "common")
    local hwnd = reaper.JS_Window_Find(vstWindowTitle, false)
    local container = reaper.JS_Window_FindChildByID(hwnd, 0)
    local presetWindow = reaper.JS_Window_FindChildByID(container, 1000)
    local itemCount = reaper.JS_WindowMessage_Send(presetWindow, "CB_GETCOUNT", 0,0,0,0)
    -- save current index
    local cur_index = reaper.JS_WindowMessage_Send(presetWindow, "CB_GETCURSEL", 0,0,0,0)
    -- get indexes for start/end of user preset names --
    local list_start = -1
    local list_end = itemCount
    for i = 0, itemCount-1 do
        reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", i, 0,0,0)
        local name = reaper.JS_Window_GetTitle(presetWindow,"")
        if not factory then
            if name == userText then list_start = i + 1
            elseif name == vstText then list_end = i
            end
        elseif name ==vstText then list_start = i + 1
        end
    end
    -- add user preset names --
    local presets = {}
    local presetcount = 0
    local presetsByName = {} --for sorting later
    for i = list_start, list_end-1 do
        reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", i, 0,0,0)
        local presetname = reaper.JS_Window_GetTitle(presetWindow,"")
        if presetname == ignoreName then --don't add preset
        else
            local num = i-list_start
            presets[num] = presetname
            presetsByName[presetname] = num
            presetcount = presetcount + 1
            --reaper.ShowConsoleMsg('added preset '..presetname)
        end
    end
    -- restore preset index
    reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", cur_index, 0,0,0)
    --TStr(presets,'presets unsorted')
    for i,name in ipairs(presets) do reaper.ShowConsoleMsg('PRESET: '..name..'\n') end
    presets =  ArraySort(presets)
    --TStr(presets,'sorted presets')
    presets = RemoveDuplicates(presets)
    --TStr(presets,'duplicates removed')
    reaper.TrackFX_Show(track, INSTRUMENT_SLOT, 2) --close the fx float
    return presets
end

function GetVstPresets(tracknum)
    return GetPresetList(tracknum,true,'<empty>')
end

function GetRplPresets(tracknum)
    return GetPresetList(tracknum)
end


---------------------------------------------------------------------------------------------------------------
--#############################################################################################################
-------------------------------------------------TESTING METHODS-----------------------------------------------

function Test()
    M.Msg('testing')
    ends = 'test'
    notend = 'west'
    string = 'thisisatest'
    M.Msg('string end test: '..tostring(EndsWith(string,ends)))
    M.Msg('string end fail: '..tostring(EndsWith(string,notend)))
    --GetTrackChunk(1)
    --SavePreset(1,2,'TEST')
    --Dbg('test: Setting wet level',20)
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

--Test()
--reaper.Track_GetPeakInfo( track, chan ) --use for meters