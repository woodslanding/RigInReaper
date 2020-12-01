dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
local hsluv = require "hsluv"

DBG = false

--local M = require("public.message")
--local Table = require("public.table")
--local T = Table.T

IMAGE_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/Images/"
BANK_FOLDER = reaper.GetResourcePath().."/Scripts/_RigInReaper/Banks/"

SCREEN_WIDTH = 1920
SCREEN_HEIGHT = 1080
CHANNEL_WIDTH = 120
BUTTON_WIDTH = 60
BUTTON_HEIGHT = 48

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
TRACKS = {  OUT_MASTER = 1,
            OUT_MON = 2,
            OUT_A = 3,
            OUT_B = 4,
            OUT_C = 5,
            OUT_D = 6,
            IN_KEYB = 7,
            IN_ROLI = 8,
            IN_SUS = 9,
            IN_PB = 10,
            IN_MOD = 11,
            IN_AT = 12,
            IN_ENC = 13,
            IN_PUSH = 14,
            IN_BTN_UP = 15,
            IN_BTN_DN = 16,
            IN_FSW = 17,
            IN_EXP = 18,
            IN_DRWB = 19,
            IN_ORG_CTL = 20,
            IN_BHR2 = 21
}
FIRST_INST_TRACK = 22

INPUT_DEVICE_NAME = 'HD Audio Mic input 1'
--midi vol Settings
MIDIVOL = {}
    MIDIVOL.NAME = "JS: Volume Adjustment"
    MIDIVOL.SLOT = 3

INSTRUMENT_SLOT = 2

--MIDI ch strip Settings
MCS = {
    NAME = "JS: midiChStrip",
    SLOT = 1,
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
AUDIO_OUT = {A = 0,B = 1,C = 2,D = 3}
--track numbers
OUT_OFFSET = 3 --difference between param#s and track# for outputs

REAPER = {SEND = 0, RCV = -1, STEREO = 1024, MONO = 0 }

local previousNotesourceSetting = 0

function Esc(str) return ("%q"):format(str) end

function CleanComma(s)  return s:sub(1, string.len(s) -2) end

function GetFilename(file)
    local file_name = file:match("[^/]*.lua$")
    return file_name:sub(0, #file_name - 4)
end

function Fullscreen(windowTitle)
    local win = reaper.JS_Window_Find(windowTitle, true)
    local style = reaper.JS_Window_GetLong(win, 'STYLE')
    if style then
        style = style & (0xFFFFFFFF - 0x00C40000) --removes window frame
        reaper.JS_Window_SetLong(win, "STYLE", style)
    end
    reaper.JS_Window_SetPosition(win, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
end

function ArraySort(t)
    local sorted = {}
    for i in ipairs(t) do table.insert(sorted,t[i]) end
    table.sort(sorted)
    return sorted
end

function TableSort(t)
    local sorted = {}
    for n in pairs(t) do table.insert(sorted, n) end
    table.sort(sorted)
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


function Msg(string)
    return reaper.ShowConsoleMsg(string..'\n')
end

function Dbg(...)
    if DBG then
        local out = {}
        for _, v in ipairs({...}) do
        out[#out+1] = tostring(v)
        end
        reaper.ShowConsoleMsg(table.concat(out, ", ").."\n")
    end
end

function GetRGB(hue,sat,level)
    local color = { hue, sat, level }
    local rgb = hsluv.hpluv_to_rgb(color)
    --Dbg('GetRGB: r:',rgb[1],'g:',rgb[2])
    --Dbg('b:',rgb[3])
    return rgb
end

function RandomColor(brightness)
    return GetRGB(math.random(360),100-(math.random(10) * math.random(10)),brightness or 50)
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

function string.starts(s, start)
    return s:sub(1, string.len(start)) == start
 end

function Pad_zeros(str, places)
    if string.len(str) < places then
        return string.rep('0', places - string.len(str))..str
    else
        return str
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
                Msg('incrementValue: value must be between min and max')
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
            Msg('decrementValue: value must be between min and max')
        elseif value > min then
            return value - inc
        elseif wrap then
            return max
        else return min
        end
    end
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
    if num == 0 then Msg('GetSelectedTrackNumber: Track Not Found')
    else return num
    end
end

function GetFXName(tracknum,slot)
    local mediatrack = GetTrack(tracknum)
    local _,name = reaper.BR_TrackFX_GetFXModuleName(mediatrack,slot)
    return name
end

function ClearFX(tracknum)
    local trk = GetTrack(tracknum)
    local count = reaper.TrackFX_GetCount(trk)
    if count > 0 then
        for idx = reaper.TrackFX_GetCount(trk)-1, 0, -1 do
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
--------------------------------------OPEN FX WINDOWS------------------------------------------

function OpenVST(tracknum,open)
    local tr = GetTrack(tracknum)
    reaper.TrackFX_SetOpen(tr, INSTRUMENT_SLOT, open)
end

function OpenMidiChStrip(tracknum,open)
    local tr = GetTrack(tracknum)
    reaper.TrackFX_SetOpen(tr, MCS.SLOT, open)
end

function OpenMidiVol(tracknum,open)
    local tr = GetTrack(tracknum)
    reaper.TrackFX_SetOpen(tr, MIDIVOL.SLOT, open)
end
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
function SelectRPL(tracknum,presetname)  end
function SelectPresetByName(tracknum,presetname) end --for VSTs that support names
function SavePreset(tracknum,presetname) end
function OpenVSTBank(tracknum,bankname) end --for VSTs that support loading banks
function SetRPLBank(tracknum,bankname) end --filter the lIst of presets for those that start with the bank name
--alternatively, make it easy to take a bank of vst presets and convert to RPL
--thIs means removing presets with the same name from the RPL INI and replacing.
--Not sure how reaper handles thIs.

    ------#######################################################################################################
    ------------------------------------------------ FXCHAIN LOADING ---------------------------------------------

function LoadInstrument(tracknum,vstname)
    --all needs to be reworked for mbf format
    reaper.PreventUIRefresh(1)
    local path = BANK_FOLDER..vstname..'.lua'
    Dbg('loadInstrument: path=',path)
    ClearFX(tracknum)
    local trk = GetTrack(tracknum)
    reaper.TrackFX_AddByName(trk, path, false, -1)
    ConfigureTrack(tracknum)
    Dbg('tracknum=',tracknum,'chain=',vstname)
    --should actually be bank name
    TrackName(tracknum,vstname)
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
--#############################################################################################################
-------------------------------------------------TESTING METHODS-----------------------------------------------

function Test()
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