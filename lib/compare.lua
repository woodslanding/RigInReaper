dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local hsluv = require "hsluv"

DBG = true
INPUT_DEVICE_NAME = 'HD Audio Mic input 1'
FX_PREFIX = 'MT-'
--midi vol settings
MIDIVOL_NAME = "JS: Volume Adjustment"
MIDIVOL_SLOT = 3
INSTRUMENT_SLOT = 2

--ch strip settings
MIDICHSTRIP_NAME = "JS: midiChStrip" 
MIDICHSTRIP_SLOT = 1
LO_NOTE_PARAM = 5
HI_NOTE_PARAM = 6
NS_SOLO_PARAM = 9
NS_MUTE_LOW_PARAM = 10
NS_MUTE_HI_PARAM = 11

AUDIO_INPUT_PARAM = 26
AUDIO_INPUT_NONE = 0
AUDIO_INPUT_EXT = 1
AUDIO_INPUT_MIXER = 2
AUDIO_INPUT_BOTH = 3

--I/O track numbers   todo: set controls to different channels on behringer
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
NOTESOURCE_PARAM = 16
NS_COUNT = 4
NS_KEYB,NS_DUAL,NS_ROLI,NS_NONE = 0,1,2,3
USE_DRAWBARS_PARAM = 27
--Audio outputs
AUDIO_OUTPUT_PARAM = 25
OUT_PARAM_A,OUT_PARAM_B,OUT_PARAM_C,OUT_PARAM_D = 0,1,2,3
--track numbers
OUT_OFFSET = 3 --difference between param#s and track# for outputs

REAPER_STEREO = 1024
REAPER_MONO = 0

EXPRESSION_PARAM = 13

NS_OFF = 0
NS_ON = 1
NS_MUTED = 2

REAPER_SEND = 0
REAPER_RCV = -1

previousNotesourceSetting = 0

function msg(string)
    return reaper.ShowConsoleMsg(string..'\n')
end

function dbg(string,data,string2,data2)
    if DBG then
        if data == nil then data = 'nil' 
        end
        if string2 == nil then 
            return msg(string..' '..tostring(data)) 
        elseif data2 == nil then 
            data2 = 'nil'
        end
        return msg(string..' '..tostring(data)..',  '..string2..' '..tostring(data2))   
    end
end

function getRGB(hue,sat,level)
    color = {}
    color[1] = hue
    color[2] = sat
    color[3] = level
    rgb = hsluv.hpluv_to_rgb(color)
    dbg('getRGB: r:',rgb[1],'g:',rgb[2])
    dbg('b:',rgb[3])
    return rgb
end

function boolToInt(val)
    if val == true then return 1
    elseif val == false then return 0
    else return val
    end
end

function intToBool(val)
    if val == true then return true
    elseif val == false then return false
    elseif val >= 1 then return true
    elseif val <= 0 then return false
    end
end

function getMoonParam(tracknum,param)
    track = getTrackByTCPNum(tracknum)
    local val,_,_ = reaper.TrackFX_GetParam( track, MIDICHSTRIP_SLOT, param) 
    return val
end

function setMoonParam(tracknum,param,val)
    track = getTrackByTCPNum(tracknum)
    dbg('setting param',param,'to',val)
    _ = reaper.TrackFX_SetParam(track,MIDICHSTRIP_SLOT,param,val) 
end

function setVolParam(tracknum,param,val)
    track = getTrackByTCPNum(tracknum)
    _ = reaper.TrackFX_SetParam(track,MIDIVOL_SLOT,param,val) 
end

function string.starts(s, start)
    return s:sub(1, string.len(start)) == start
 end

function pad_zeros(str, places)
    if string.len(str) < places then
        return string.rep('0', places - string.len(str))..str
    else
        return str
    end
end

function incrementValue(value,min,max,loop)
    dbg('incrementValue:  val=',value,'max=',max)
    if value < min or value > max then 
        msg('incrementValue: value must be between min and max')
    elseif value < max then
        return value + 1
    elseif loop then 
        return min
    else return max
    end
end

function decrementValue(value,min,max,loop)
    if value < min or value > max then 
        msg('decrementValue: value must be between min and max')
    elseif value > min then
        return value - 1
    elseif loop then 
        return max
    else return min
    end
end
-------------------------------------------------------------------------------------------------
-------------------------------------TRACK METHODS-----------------------------------------------

function getSelectedTrackNumber()
    local tr = getSelectedTrack(0,0) 
    return getNumberOfTrack(tr)
end

function getTrackCount()
    return reaper.CountTracks(0)
end

function getTrackByTCPNum(tracknum)
    --dbg('getTrackByTCPNum: tracknum = ',tracknum)
    return reaper.GetTrack(0, tracknum - 1)
end

function getNumberOfTrack(mediatrack)
    --(returns zero if not found, -1 for master track) (read-only, returns the int directly)
    local num = reaper.GetMediaTrackInfo_Value( mediatrack,'IP_TRACKNUMBER')
    if num == 0 then msg('getSelectedTrackNumber: Track Not Found') 
    else return num
    end
end

function getSelectedTrack()
    local track = reaper.GetSelectedTrack(0,0)
    return track
end

function removeFX(tracknum)
    trk = getTrackByTCPNum(tracknum)
    count = reaper.TrackFX_GetCount(trk)
    if count > 0 then
        for idx = reaper.TrackFX_GetCount(trk)-1, 0, -1 do
            reaper.TrackFX_Delete(trk, idx)
        end
    end
end

function trackName(tracknum,name) 
    local track = getTrackByTCPNum(tracknum) 
    reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', name, true)
end

function isMoonTrack(tracknum)
    --dbg('isMoonTrack:  checking track ',tracknum)
    local track = reaper.GetTrack(0, tracknum - 1)
    --getTrackByTCPNum(tracknum) 
    local fxSlot = MIDICHSTRIP_SLOT
    local _,fxname = reaper.TrackFX_GetFXName(track, fxSlot, '')
    --dbg('effect name in slot 1: ',fxname)
    return fxname == MIDICHSTRIP_NAME
end

function getMoonTracks()
    local mtracks = {}
    local count = 0
    for i = 1,getTrackCount() do
        if isMoonTrack(i) then
            table.insert(mtracks,i)
            count = count + 1
        end
    end
    return mtracks
end
--################################################################################################################--
--------------------------------------------SEND AND REcEIVE--------------------------------------------------------

function getSendDest(tracknum,index)
    --dbg('getSendDest:  checking send',index,'on track',tracknum)
    track = getTrackByTCPNum(tracknum)
    desttr =  reaper.BR_GetMediaTrackSendInfo_Track( track, REAPER_SEND, index-1, 1)
    dest = getNumberOfTrack(desttr)
    --dbg('getSendDest: dest track = ',dest)
    return dest
end

function getSendCount(tracknum)
    return reaper.GetTrackNumSends( getTrackByTCPNum(tracknum), REAPER_SEND )
end

function getReceiveCount(tracknum)
    return reaper.GetTrackNumSends( getTrackByTCPNum(tracknum), REAPER_RCV )
end

function getReceive(tracknum,index)        
    local tr = getTrackByTCPNum(tracknum)
    local srcTrack = reaper.BR_GetMediaTrackSendInfo_Track( tr, REAPER_RCV, index-1, 0)
    return getNumberOfTrack( srcTrack )
end

function removeReceive(tracknum,idx)
    --dbg('removing receive '..idx..' from fx track '..tracknum)
    reaper.RemoveTrackSend( getTrackByTCPNum(tracknum), REAPER_RCV, idx-1 )
end

function removeSend(tracknum,idx)
    reaper.RemoveTrackSend( getTrackByTCPNum(tracknum), REAPER_SEND, idx-1 )
end

function addReceive(desttrack,srctrack)
    dbg('addReceive: adding receive to track ',fxtrack,'from track ',srctrack)
    mediatrack = getTrackByTCPNum(srctrack)
    mediaFxTrack = getTrackByTCPNum(desttrack)
    if mediatrack and mediaFxTrack then
        reaper.CreateTrackSend( mediatrack, mediaFxTrack )
    end
end

function addSend(srctrack,desttrack)
    addReceive(desttrack,srctrack)
end

function isReceiveMuted(tracknum,index)
    track = getTrackByTCPNum(tracknum)
    _, mute = reaper.GetTrackReceiveUIMute( track, index - 1)
    return intToBool(mute)
end

function isSendMuted(tracknum,index)
    track = getTrackByTCPNum(tracknum)
    --dbg('isSendMuted:  index =',index)
    --indices are zero based here :^P
    _, mute = reaper.GetTrackSendUIMute( track , index - 1 )
    --dbg('isSendMuted: tracknum',tracknum,'mute status = ',not mute)
    return intToBool(mute)
end

function getSendIndex(tracknum,destTrack)
    dbg('getSendIndex:  track=',tracknum,'destTrack=',destTrack)
    for i = 1,getSendCount(tracknum) do
        local dest = getSendDest(tracknum,i)
        if dest == destTrack then
            return i
        end
    end
end

function muteSend(tracknum,dest,setmute)
    dbg('muteSend: tracknum = ',tracknum,'dest = ',dest)
    if tracknum == dest then return end  --thought we checked this elsewhere, but we'll do it again here!
    local index = getSendIndex(tracknum,dest)
    if index then 
        if setmute then reaper.SetTrackSendInfo_Value( getTrackByTCPNum(tracknum), REAPER_SEND, index-1,'B_MUTE', boolToInt(setmute)) 
        else return isSendMuted(tracknum,index)
    end
end

function setSendPreFader(tracknum,dest)
    local idx = getSendIndex(tracknum,dest) 
    local worked = reaper.SetTrackSendInfo_Value( getTrackByTCPNum(tracknum), REAPER_SEND, idx-1, 'I_SENDMODE',3 )
    --dbg('setSendPreFader: Success=',worked,'dest=',dest)   
end   

function setSendPhase(tracknum, dest, flipped)
    dbg('setSendPhase: track=',tracknum,'ph=',flipped)
    local idx = getSendIndex(tracknum,dest)
    local worked = reaper.SetTrackSendInfo_Value(getTrackByTCPNum(tracknum), REAPER_SEND,idx-1, 'B_PHASE', boolToInt(flipped))
end

function getSendPhase(tracknum,dest)
    local idx = getSendIndex(tracknum,dest)
    local flipped = reaper.GetTrackSendInfo_Value(getTrackByTCPNum(tracknum), REAPER_SEND,idx-1, 'B_PHASE')
    return flipped
end

function setOutputSend(tracknum,outputnum)
    dbg('setOutputSend: track=',tracknum,'outputnum=',outputnum)
    for i = OUT_A,OUT_D do
        if outputnum == i then
            muteSend(tracknum,i,false)
        else muteSend(tracknum,i,true)
        end
    end
end

function getOutputSend(tracknum)
    local send = getMoonParam(tracknum,AUDIO_OUTPUT_PARAM)
    return send + OUT_OFFSET
end

--for cueing: mute the send to current output buss
function setCue(tracknum,cue)
    local send = getOutputSend(tracknum)
    muteSend(tracknum,send,cue)
end
----------------------------------------------------------------------------------------------
--#############################################################################################
---------------------------------------EXPRESSION CONTROL-------------------------------------
--we should turn off expression, NOT by muting the midi rcv, but by BYPASSING THE MIDI VOL FX!!!
--this way, we don't have to worry about resetting the value to max.
function bypassExpression(tracknum,byp)
    local tr = getTrackByTCPNum(tracknum)
    reaper.TrackFX_SetOffline(tr, MIDIVOL_SLOT,byp)
    --reaper.TrackFX_SetEnabled( track, fx, enabled )  --what's the difference???
end

-----------------------------------------------------------------------------------------------
--------------------------------------OPEN FX WINDOWS------------------------------------------

function openVST(tracknum,open)
    tr = getTrackByTCPNum(tracknum)
    reaper.TrackFX_SetOpen(tr, INSTRUMENT_SLOT, open)
end

function openMidiChStrip(tracknum,open)
    tr = getTrackByTCPNum(tracknum)
    reaper.TrackFX_SetOpen(tr, MIDICHSTRIP_SLOT, open)
end

function openMidiVol(tracknum,open)
    tr = getTrackByTCPNum(tracknum)
    reaper.TrackFX_SetOpen(tr, MIDIVOL_SLOT, open)
end
--###########################################################################################--
----------------------------------------EFFECT SWITCHING-------------------------------------
--Need to look at this code again
--when we set the effect, we are looking for a number from 1-n of available effect tracks
--for an instrument track this will be the fxtrack count.  for an effect track it will be COUNT- 1!!
--because it will not include the effect itself.
--so when getting the list of available effects, we need to know who is asking!!
function isEffectTrack(tracknum)
    local isFX = getMoonParam(tracknum,AUDIO_INPUT_PARAM)    
    return isFX > 1  --0 no input, 1 exernal input
end

function getEffectsForTrack(tracknum)
    local effectTracks = {}
    local trackcount = getTrackCount()
    dbg('track count = ',trackcount)
    local effectCount = 0
    for i = 1,trackcount do
        if isMoonTrack(i) and isEffectTrack(i) and (i ~= tracknum) then         
            effectCount = effectCount + 1           
            dbg('getEffectsForTrack: adding effect track: ',i,'to table position ',effectCount)  
            effectTracks[effectCount] = i
        end
    end
    return effectTracks,effectCount
end

function getCurrentEffect(tracknum)
    for i = 1,getSendCount(tracknum) do
        dbg('getCurrentEffect: sendcount = ',getSendCount(tracknum))
        dest = getSendDest(tracknum,i)
        dbg('getCurrentEffect: index',i,'destination is',dest)
        muted = isSendMuted(tracknum,i)
        if isMoonTrack(dest) and not muted then 
            dbg('getCurrentEffect: dest =',dest)
            return dest
        end
    end
    --if the send has been muted, then the recently muted track will have been put out of phase
    for i = 1,getSendCount(tracknum) do
        dest = getSendDest(tracknum,i)
        phaseFlipped = getSendPhase(tracknum,dest)
        if isMoonTrack(dest) and phaseFlipped then
            return dest
        end
    end
    return getSendDest(tracknum,1) --nothing selected at all, return first fx
end
     
function getEffectForIndex(tracknum,index)
    dbg('getEffectForIndex: get for index: ',index)
    local tracks,count = getEffectsForTrack(tracknum)
    dbg('getEffectForIndex:  effect track = ',tracks[index])
    return tracks[index],count
end

function getIndexForEffect(tracknum)
    dbg('getIndexForEffect: track ',tracknum)
    local tracks,count = getEffectsForTrack(tracknum)
    for i,track in ipairs(tracks) do
        dbg('getIndexForEffect: i = ',i,', track = ',track)
        if track == getCurrentEffect(tracknum) then
            dbg('getIndexForEffect: returning index = ',i)
            return i,count
        end
    end
    if getEffectForIndex(1) ~= tracknum then return 1,count
    else return 2,count
    end
end

function isTrackEffectMuted(tracknum)
    for i,track in ipairs(getEffectsForTrack(tracknum)) do
        if getSendPhase(tracknum,track) then return true
        end
    end
    return false
end

function setEffect(tracknum,fxIdx)
    dbg('setEffect: tracknum =',tracknum,'fx idx=',fxIdx)
    local phMute = isTrackEffectMuted(tracknum)
    for i,track in ipairs(getEffectsForTrack(tracknum)) do
        local active = (i ~= fxIdx)
        dbg('setEffect: track=',track,'active=',active)
        muteSend(tracknum,track, active )
        --only mute the active effect, and only if it was muted before...
        setSendPhase(tracknum, track, phMute and active)
    end
end

function incrementEffect(tracknum)
    idx,count = getIndexForEffect(tracknum)
    dbg('incrementEffect: count=',count,'idx=',idx)
    inc = incrementValue(idx,1,count,true)
    dbg('incrementEffect: inc=',inc)
    setEffect(tracknum, inc)
end

function setTrackEffectMuted(tracknum,mute)
    --keep track of the last muted fx by reversing its phase
    dest = getCurrentEffect(tracknum)
    dbg('setTrackEffectMuted: tracknum=',tracknum,'dest=',dest) 
    --muted =  isSendMuted(tracknum,dest) --TODO: do we need this check?
    setSendPhase(tracknum,dest,mute)
    muteSend(tracknum,dest,mute)
end

--###########################################################################################--
-------------------------------------FX LEVEL CONTROL-----------------------------------------
--all done by send levels, either to effects or to outputs.
function setWetDryLevels(tracknum,fader)
    --dbg('setWetDryLevels: track#=',tracknum,'fader val =',fader)
    local wetlevel = math.min(fader * 2, 1)
    local drylevel = math.min(2 - (fader * 2), 1)
    local sendIdx = getSendIndex(tracknum,getCurrentEffect(tracknum))
    reaper.SetTrackSendUIVol(getTrackByTCPNum(tracknum), sendIdx-1, wetlevel*wetlevel, 0)
    volume(tracknum,drylevel)
end

--TODO: setWetDryLevelFader

function volume(tracknum,fader)
    if fader then
        for output = TRACKS.OUT_MON,OUT_D do
            --dbg('setWetDryLevels: setting level for output',output)
            sendIdx = getSendIndex(tracknum,output)   
            --dbg('setWetDryLevels: setting level for index',sendIdx,'vol=',dryVol) 
            reaper.SetTrackSendUIVol(getTrackByTCPNum(tracknum), sendIdx-1, drylevel*drylevel, 0)     
        end
    else 
        local _,vol,pan = reaper.GetTrackSendUIVolPan(getTrackByTCPNum(tracknum),TRACKS.OUT_MON) --should be the same as the others
        return vol  
    end
end

--###########################################################################################--
---------------------------------CONTROL SOURCE SWITCHING-----------------------------------
function muteEncoders(tracknum, val) muteSend(tracknum,TRACKS.IN_ENC,val) 
function mutePush(tracknum,val) muteSend(tracknum,TRACKS.IN_PUSH,val) end
function muteLowerButtons(tracknum, val) muteSend(tracknum,TRACKS.IN_BTN_DN,val) end
function muteUpperButtons(tracknum, val) muteSend(tracknum,TRACKS.IN_BTN_UP,val) end
function muteFootswitches(tracknum,val) muteSend(tracknum,TRACKS.IN_FSW,val) end
function muteDrawbars(tracknum,val) muteSend(tracknum,TRACKS.IN_DRWB,val) end
function muteAftertouch(tracknum,val) muteSend(tracknum,TRACKS.IN_AT,val) end
function muteMod(tracknum,val) muteSend(tracknum,TRACKS.IN_MOD,val) end
function mutePitchbend(tracknum,val) muteSend(tracknum,TRACKS.IN_PB,val) end
function muteOrganCtls(tracknum,val) muteSend(tracknum,TRACKS.IN_ORG_CTL,val) end
function muteExpression(tracknum,val) muteSend(tracknum,TRACKS.IN_EXP,val) end
--------------------------------------------------------------------------------------------
---------------------------------NOTESOURCE SWITCHING---------------------------------------

function notesource(tracknumber,nsindex) --get or set
    if nsindex then
        --set midiChStrip value for input type
        setMoonParam(tracknumber,NOTESOURCE_PARAM,nsindex)   
        setOutputByNotesource(tracknumber,nsindex)
        muteSendsByNotesource(tracknumber,nsindex)
    else return getMoonParam(tracknumber,NOTESOURCE_PARAM)
    end
end

function setOutputByNotesource(tracknumber,nsindex)
    dbg('setOutputByNotesource: nsindex=',nsindex)
    --If an inst has output D, it should NOT change with ns!
    local output = getMoonParam(tracknumber,AUDIO_OUTPUT_PARAM)
    dbg('setOutputByNotesource: output=',output)
    if output ~= OUT_PARAM_D then
        dbg('setOutputByNotesource: setting by notesource',nsindex)
        if nsindex == NS_KEYB then 
            setOutputSend(tracknumber,TRACKS.OUT_A)
            setMoonParam(tracknumber,AUDIO_OUTPUT_PARAM,OUT_PARAM_A)
        elseif nsindex == NS_ROLI then  
            setOutputSend(tracknumber,TRACKS.OUT_B)
            setMoonParam(tracknumber,AUDIO_OUTPUT_PARAM,OUT_PARAM_B)
        elseif nsindex == NS_DUAL then
            setOutputSend(tracknumber,TRACKS.OUT_A)
            setMoonParam(tracknumber,AUDIO_OUTPUT_PARAM,OUT_PARAM_A)
        elseif nsindex == NS_NONE then 
            setOutputSend(tracknumber,TRACKS.OUT_C)
            setMoonParam(tracknumber,AUDIO_OUTPUT_PARAM,OUT_PARAM_C)
        end 
    else setOutputSend(tracknumber,TRACKS.OUT_D)
        dbg('setOutputByNotesource: setting by output D,',output)
    end
end

function muteSendsByNotesource(tracknumber,nsindex)
    if nsIndex == TRACKS.NS_KEYB then 
        muteSend(TRACKS.IN_KEYB,tracknumber,false)
        muteSend(TRACKS.IN_ROLI,tracknumber,true)
    elseif nsIndex == TRACKS.NS_ROLI then  
        muteSend(TRACKS.IN_KEYB,tracknumber,true)
        muteSend(TRACKS.IN_ROLI,tracknumber,false)
    elseif nsIndex == NS_DUAL then
        muteSend(TRACKS.IN_KEYB,tracknumber,false)
        muteSend(IN_ROLI,tracknumber,true)
    elseif nsIndex == NS_NONE then 
        muteSend(TRACKS.IN_KEYB,tracknumber,true)
        muteSend(TRACKS.IN_ROLI,tracknumber,true)
    end 
end

function incrementNotesource(tracknumber)
    local nsIndex = notesource(tracknumber)
    --increment it
    nsIndex = incrementValue(nsIndex,0,NS_COUNT-1,true)
    setNotesource(tracknumber,nsIndex)
end

function decrementNotesource(tracknumber)
    local nsIndex = notesource(tracknumber)
    --decrement it
    nsIndex = decrementValue(nsIndex,0,NS_COUNT-1,true)
    setNotesource(tracknumber,nsIndex)
end   
-------------------------------------------------------------------------------------
---------------------------------------NOTESOURCE SOLOING----------------------------
function trackLimits(tracknumber)
    return getMoonParam(tracknumber,LO_NOTE_PARAM), getMoonParam(tracknumber,HI_NOTE_PARAM)
end

function notesoloLimits(tracknumber, lo, hi)
    setMoonParam(tracknumber,NS_MUTE_LOW_PARAM,lo)
    setMoonParam(tracknumber,NS_MUTE_HI_PARAM,hi)
end

function getTracksWithNS(nsNum)
    local nsTracks = {}
    for i,tracknum in ipairs(getMoonTracks()) do
        local trackns = getMoonParam(tracknum,NOTESOURCE_PARAM)
        if trackns == nsNum then
            table.insert(nsTracks,tracknum)
        end
    end
    return nsTracks   
end

function getNsSoloMuteRange(nsNum)
    local low = 127
    local high = 0
    for i,tracknum in ipairs(getTracksWithNS(nsNum)) do
        dbg('getNsSoloMuteRange: checking track',tracknum)
        if getMoonParam(tracknum,NS_SOLO_PARAM) == 1 then --look for nsoloed insts
            dbg('getNsSoloMuteRange: track',tracknum)
            high = math.max(high,getMoonParam(tracknum,HI_NOTE_PARAM))
            low = math.min(low,getMoonParam(tracknum,LO_NOTE_PARAM))
            dbg('getNsSoloMuteRange: low = ',low,'high=',high)
        end
    end
    return low,high
end

function nsSolo(tracknumber,solo)
    setMoonParam(tracknumber,NS_SOLO_PARAM,solo)
    dbg('setNsSolo: setting nss to',solo,'track',tracknumber)
    local nsNum = getMoonParam(tracknumber,NOTESOURCE_PARAM)
    local low,high = getNsSoloMuteRange(nsNum) 
    dbg('setNsSolo: low =',low,'high=',high)         
    for i,tracknum in ipairs(getTracksWithNS(nsNum)) do
        if getMoonParam(tracknum,NS_SOLO_PARAM) ~= NS_ON then
            dbg('setNsSolo: found non-soloed track',tracknum)
            if high > low then
                setMoonParam(tracknum,NS_SOLO_PARAM,NS_MUTED)
                setMoonParam(tracknum,NS_MUTE_HI_PARAM, high)
                setMoonParam(tracknum,NS_MUTE_LOW_PARAM,low)
            else --no note solo
                setMoonParam(tracknum,NS_SOLO_PARAM,0)
            end
        end
    end
end

--###########################################################################################--
--------------------------------------- ADDING FX SENDS--------------------------------------
--After loading a new instrument (fxchain) we need to add a send for every effect in the mixer
--if the new inst is an effect, we need to add every (other!) moon track in the mixer as a (muted) receive.
--###########################################################################################--
---------------------------------------AUDIO INPUT CONTROL------------------------------------
--when we load a template we will read the setting of the audio input and configure the chan inputs
--may be unnecessary, if the template was saved with these settings!
--it does insure that the track setting matches what is in midiChStrip
--  set track to audio input

function setAudioInput(tracknum,stereo, dev_name)
    for i = 1,  reaper.GetNumAudioInputs() do
        nameout =  reaper.GetInputChannelName( i-1 )
        --dbg('setAudioInput:  Device name =',nameout)
        if nameout:lower():match(dev_name:lower()) then dev_id = i-1 end
    end
    if not dev_id then return end
    tr = getTrackByTCPNum(tracknum)
    reaper.SetMediaTrackInfo_Value( tr, 'I_RECINPUT',is_stereo + dev_id)
end
  
function removeAudioInput(tracknum)
    reaper.SetMediaTrackInfo_Value(getTrackByTCPNum(tracknum), 'I_RECINPUT',-1)
end

function clearRouting(track)
    commandID = reaper.NamedCommandLookup("_S&M_SENDS6") --remove sends
    reaper.Main_OnCommand(commandID, 0)
    commandID = reaper.NamedCommandLookup("_S&M_SENDS5") --remove receives
    reaper.Main_OnCommand(commandID, 0)
end
  
--when loading a new fxchain...
function configureTrack(newtrack) 
    --clear any fx sends or returns
    clearRouting(newtrack)
    --add all outputs to the track:
    for out = TRACKS.OUT_MON,TRACKS.OUT_D do
        addSend(newtrack,out)
    end
    --add inputs and mute
    for inp = TRACKS.IN_KEYB,TRACKS.IN_AUX do
        addReceive(newtrack,inp)
        muteSend(inp,newtrack,true)
    end
    --enable sustain      
    muteSend(TRACKS.IN_SUS,newtrack,false)
    --enable drawbars
    if getMoonParam(newtrack,USE_DRAWBARS_PARAM) == 1 then
        muteSend(newtrack,TRACKS.IN_DRWB,true)
    end
    --add sends for all effects tracks
    for i,effect in pairs(getEffectsForTrack(newtrack)) do     
        dbg('configureTrack: adding send to new track',effect)
        addSend(newtrack,effect)
        muteSend(newtrack,effect,true)
        setSendPreFader(newtrack,effect)
    end
    --is this an effect track???
    local input = getMoonParam(newtrack,AUDIO_INPUT_PARAM)
    if input == AUDIO_INPUT_MIXER or input == AUDIO_INPUT_BOTH then
        --add this track as muted send to every moon channel
        for i,track in ipairs(getMoonTracks()) do
            if track ~= newtrack then
                addSend(track,newtrack)
                muteSend(track,newtrack,true)
                setSendPreFader(track,newtrack)
                dbg('configureTrack, adding send: ',track)
            end
        end
        --for sure effects will go out output C.  A or B will get set if NS changes
        setMoonParam(newtrack,AUDIO_OUTPUT_PARAM,OUT_PARAM_C)
    end
    if input == AUDIO_INPUT_EXT or input == AUDIO_INPUT_BOTH then   
        dbg('configureTrack: setting audio input',input)
        setAudioInput(newtrack,REAPER_STEREO,INPUT_DEVICE_NAME)
    end
    if input == AUDIO_INPUT_NONE or input == AUDIO_INPUT_MIXER then
        dbg('configureTrack: removing audio input',input)
        removeAudioInput(newtrack)
    end  
    --Inst will have a preferred NS
    local ns = getMoonParam(newtrack,NOTESOURCE_PARAM)
    dbg('configureTrack: ns=',ns)
    muteSendsByNotesource(newtrack,ns) 
    setOutputByNotesource(newtrack,ns)  
    --set effect to idx1, volume off 
    --if idx1 is ourselves, this will fail. kludgey...but
    local fx = getEffectForIndex(1)
    if fx == newtrack then fx = getEffectForIndex(2) end 
    muteSend(newtrack,fx,false)
    setWetDryLevels(newtrack,0)
end

    ------#######################################################################################################
    ------------------------------------------------ FXCHAIN LOADING ---------------------------------------------    

function loadInstrument(tracknum,chainname)  
    --need to give these chains the exact same name as in the reabank file, minus the fx prefix.
    --then we can use '//*' data in that file to e.g. set the param numbers for all the BH controls
    --also to set the track color
    --and eventually we can just read the '//!' data to generate the patch list
    reaper.PreventUIRefresh(1)
    local path = FX_PREFIX..chainname..'.RfxChain' 
        --reaper.GetResourcePath('')..'/FXChains/'..chainname..'.RfxChain'
    dbg('loadInstrument: path=',path)
    removeFX(tracknum)
    trk = getTrackByTCPNum(tracknum)
    reaper.TrackFX_AddByName(trk, path, false, -1)
    configureTrack(tracknum)
    dbg('tracknum=',tracknum,'chain=',chainname)
    trackName(tracknum,chainname)
    reaper.PreventUIRefresh(-1)
end

function getInstName(tracknum)
    return reaper.getTrackName(getTrackByTCPNum(tracknum))
end

function saveInstrument(tracknum)
    clearRouting(tracknum)
    local name = getInstName(tracknum)
    dbg('saveInstrument: name=',name)
    name = INST_PREFIX..name
    --just a stub.  We may not be able to do this at all....
end


---------------------------------------------------------------------------------------------------------------
--#############################################################################################################
-------------------------------------------------TESTING METHODS-----------------------------------------------

function test()
    --dbg('test: setting wet level',20)
    --setWetDryLevels(20,.3)
    --configureTrack(getSelectedTrackNumber())

    --clearRouting(getSelectedTrackNumber())
    --loadInstrument(22,'MT-Guitar Rig')
    --loadInstrument(getSelectedTrackNumber(),'Kontakt')
    --loadInstrument(getSelectedTrackNumber(),'Prism')
    --loadInstrument(getSelectedTrackNumber(),'Guitar Rig')

    --setWetDryLevels(getSelectedTrackNumber(),.1)   
    --setWetDryLevels(getSelectedTrackNumber(),.3)    
    --setWetDryLevels(getSelectedTrackNumber(),.5)   
    --setWetDryLevels(getSelectedTrackNumber(),.7)  
    --setWetDryLevels(getSelectedTrackNumber(),.9)

    --setCue(21,0)
    --incrementEffect(21)
    --setTrackEffectMuted(21,true)
    --setTrackEffectMuted(21,false)
    --getRGB()
    

end

test()

--reaper.Track_GetPeakInfo( track, 0 ) --use for meters



    



    

