dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

DBG = true
INPUT_DEVICE_NAME = 'HD Audio Mic input 1'
--midi vol settings
MIDIVOL_NAME = "JS: Volume Adjustment"
MIDIVOL_SLOT = 3
VOL_PARAM = 4
MIDICH_PARAM = 0
EXP_CC = 3
--ch strip settings
MIDICHSTRIP_NAME = "JS: midiChStrip" 
MIDICHSTRIP_SLOT = 1
LO_NOTE_PARAM = 4
HI_NOTE_PARAM = 5
NS_SOLO_PARAM = 8
NS_MUTE_LOW_PARAM = 9
NS_MUTE_HI_PARAM = 10

AUDIO_INPUT_PARAM = 24
AUDIO_INPUT_NONE = 0
AUDIO_INPUT_EXT = 1
AUDIO_INPUT_MIXER = 2
AUDIO_INPUT_BOTH = 3

AUDIO_OUTPUT_PARAM = 23

USE_DRAWBARS_PARAM = 25

NOTESOURCE_PARAM = 14
NS_COUNT = 4
NS_KEYB,NS_DUAL,NS_ROLI,NS_NONE = 0,1,2,3
--ins and outs
OUT_MON,OUT_A,OUT_B,OUT_C,OUT_D = 2,3,4,5,6
IN_KEYB,IN_ROLI,IN_SUS,IN_ENC,IN_PUSH,IN_BTN_UP,IN_BTN_DN,IN_FSW,IN_EXP,IN_DRWB,IN_AUX = 7,8,9,10,11,12,13,14,15,16,17
OUT_PARAM_A,OUT_PARAM_B,OUT_PARAM_C,OUT_PARAM_D = 0,1,2,3

REAPER_STEREO = 1024
REAPER_MONO = 0

EXPRESSION_PARAM = 13

NS_OFF = 0
NS_ON = 1
NS_MUTED = 2

REAPER_SEND = 0
REAPER_RCV = -1

previousNotesourceSetting = 0

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
        return msg(string..' '..tostring(data)..' '..string2..' '..tostring(data2))   
    end
end

function incrementValue(value,min,max,loop)
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
        msg('incrementValue: value must be between min and max')
    elseif value > min then
        return value - 1
    elseif loop then 
        return max
    else return min
    end
end

function getSelectedTrackNumber()
    local tr = getSelectedTrack(0,0) 
    return getNumberOfTrack(tr)
end

function getTrackCount()
    return reaper.CountTracks(0)
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

function getTrack(tracknum)
    dbg('getting track num ',tracknum)
    local track = reaper.GetTrack(0,tracknum) or msg("invalid track number: "..tracknumber)
    return track
end

function getSelectedTrack()
    local track = reaper.GetSelectedTrack(0,0)
    return track
end

function getSendDest(tracknum,index)
    --dbg('getSendDest:  checking send',index,'on track',tracknum)
    track = getTrackByTCPNum(tracknum)
    desttr =  reaper.BR_GetMediaTrackSendInfo_Track( track, REAPER_SEND, index-1, 1)
    dest = getNumberOfTrack(desttr)
    --dbg('getSendDest: dest track = ',dest)
    return dest
end

function getRcvCount(tracknum)
    local tr = getTrackByTCPNum(tracknum)
    return reaper.GetTrackNumSends( tr, REAPER_RCV )
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
    --ultraschall.GetTrackAUXSendReceives(tracknumber, i) + 1
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
    --dbg('addReceive: adding receive to ',fxtrack)
    --dbg('addReceive: from track '..srctrack)
    mediatrack = getTrackByTCPNum(srctrack)
    mediaFxTrack = getTrackByTCPNum(desttrack)
    reaper.CreateTrackSend( mediatrack, mediaFxTrack )
end

function addSend(srctrack,desttrack)
    addReceive(desttrack,srctrack)
end

function isReceiveMuted(tracknum,index)
    track = getTrackByTCPNum(tracknum)
    _, mute = reaper.GetTrackReceiveUIMute( track, index - 1)
end

function isSendMuted(tracknum,index)
    track = getTrackByTCPNum(tracknum)
    --dbg('isSendMuted:  index =',index)
    --indices are zero based here :^P
    _, mute = reaper.GetTrackSendUIMute( track , index - 1 )
    --dbg('isSendMuted: tracknum',tracknum,'mute status = ',not mute)
    return mute
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

function getSendIndex(tracknum,destTrack)
    for i = 1,getSendCount(tracknum) do
        local dest = getSendDest(tracknum,i)
        if dest == destTrack then
            return i
        end
    end
end

function setSendMuted(tracknum,dest,setmute)
    dbg('setSendMuted: tracknum = ',tracknum,'dest = ',dest)
    local index = getSendIndex(tracknum,dest)
    reaper.SetTrackSendInfo_Value( getTrackByTCPNum(tracknum), REAPER_SEND, index-1,'B_MUTE', setmute)
end

function setSendPreFader(tracknum,dest)
    local idx = getSendIndex(tracknum,dest) 
    local worked = reaper.SetTrackSendInfo_Value( getTrackByTCPNum(tracknum), REAPER_SEND, idx-1, 'I_SENDMODE',3 )
    --dbg('setSendPreFader: Success=',worked,'dest=',dest)
    
end   

function setOutputSend(tracknum,outputnum)
    dbg('setOutputSend: track=',tracknum,'outputnum=',outputnum)
    for i = OUT_A,OUT_D do
        if outputnum == i then
            setSendMuted(tracknum,i,0)
        else setSendMuted(tracknum,i,1)
        end
    end
end


--when switching from a track template with audio expression to one with midi expression, max
--the audio expression
----------------------------------------------------------------------------------------------
---------------------------------------EXPRESSION CONTROL-------------------------------------
function resetExpression(tracknum)
    if getMoonParam(tracknum,EXPRESSION_PARAM) ~= EXP_CC then
        setVolParam(tracknum,VOL_PARAM,127) --exp will be handled by the instrument, so turn up volume
    else setVolParam(tracknum,VOL_PARAM,0) --what's stored in the template is random, and new inst may be louder
    end
end
---------------------------------------------------------------------------------------------
----------------------------------------EFFECT SWITCHING-------------------------------------
function isEffectTrack(tracknum)
    local isFX = getMoonParam(tracknum,AUDIO_INPUT_PARAM)    
    return isFX > 1  --0 no input, 1 exernal input
end

function getEffectTracks()
    local effectTracks = {}
    local trackcount = getTrackCount()
    dbg('track count = ',trackcount)
    local effectCount = 1
    for i = 1,trackcount do
        if isMoonTrack(i) and isEffectTrack(i) then
            dbg('getEffectTracks: adding effect track: ',i)
            dbg('getEffectTracks: to table position ',effectCount)
            effectTracks[effectCount] = i
            effectCount = effectCount + 1
        end
    end
    return effectTracks,effectCount
end

function getEffectForTrack(tracknum)
    for i = 1,getSendCount(tracknum) do
        --dbg('getEffectForTrack: sendcount = ',getSendCount(tracknum))
        dest = getSendDest(tracknum,i)
        --dbg('getEffectForTrack: index',i,'destination is',dest)
        muted = isSendMuted(tracknum,i)
        --dbg('getEffectForTrack: dest',dest,'mute status =',muted)
        _,name = reaper.GetTrackName(getTrackByTCPNum(dest),'')
        --dbg('getEffectForTrack: track -',name,'index',i)
        --dbg('geEffectForTrack: dest =',dest)
        if isMoonTrack(dest) and not muted then 
            --dbg('getEffectForTrack: dest =',dest)
            return dest
        end
    end
end
     
function getEffectForIndex(index)
    dbg('getEffectForIndex: get for index: ',index)
    local tracks,count = getEffectTracks()
    dbg('getEffectForIndex:  effect track = ',tracks[index])
    return tracks[index],count
end

function getIndexForEffect(tracknum)
    dbg('getIndexForEffect: track ',tracknum)
    local tracks,count = getEffectTracks()
    for i,track in ipairs(tracks) do
        dbg('getIndexForEffect: i = ',i,', track = ',track)
        if track == tracknum then
            dbg('getIndexForEffect: returning index = ',i)
            return i,count
        end
    end
end

function incrementEffect(tracknum,decInstead)
    --local tr = getTrack(tracknum)
    dbg('incrementEffect: getting effects for: ',tracknum)
    local origFxTrack = getEffectForTrack(tracknum)
    local fxindex,fxCount = getIndexForEffect(origFxTrack)  --what was the previous index?
    dbg('incrementEffect: initial index = ',fxindex)
    if decInstead then 
        fxindex = decrementValue(fxindex,1,fxCount,true)
    else fxindex = incrementValue(fxindex,1,fxCount,true)
    end
    dbg('incrementEffect: fx index = ',fxindex)
    local fxTrack,_ = getEffectForIndex(fxindex) 
    dbg('incrementEffect: orig fx track = ',origFxTrack) 
    dbg('incrementEffect: fx track = ',fxTrack)
    setSendMuted(tracknum,origFxTrack,1)
    setSendMuted(tracknum,fxTrack,0)
end
----------------------------------------------------------------------------------------------
-------------------------------------FX LEVEL CONTROL-----------------------------------------
--all done by send levels, either to effects or to outputs.
function setWetDryLevels(tracknum,fader)
    wetlevel = math.min(fader * 2, 1)
    drylevel = math.min(2 - (fader * 2), 1)
    wetVol = reaper.SLIDER2DB(wetlevel)
    dryVol = reaper.SLIDER2DB(drylevel)
    sendIdx = getSendIndex(tracknum,getEffectForTrack(tracknum))
    reaper.SetTrackSendUIVol(getTrackByTCPNum(tracknum), sendIdx-1, wetVol, 0)
    for output = OUT_MON,OUT_D do
        sendIdx = getSendIndex(tracknum,output)
        reaper.SetTrackSendUIVol(getTrackByTCPNum(tracknum), sendIdx-1, dryVol, 0)
    end
end
--------------------------------------------------------------------------------------------
---------------------------------CONTROL SOURCE SWITCHING-----------------------------------
function muteEncoders(tracknum, val) setSendMuted(tracknum,IN_ENC,val) end
function mutePush(tracknum,val) setSendMuted(tracknum,IN_PUSH,val) end
function muteLowerButtons(tracknum, val) setSendMuted(tracknum,IN_BTN_DN,val) end
function muteUpperButtons(tracknum, val) setSendMuted(tracknum,IN_BTN_UP,val) end
function muteFootswitches(tracknum,val) setSendMuted(tracknum,IN_FSW,val) end
function muteDrawbars(tracknum,val) setSendMuted(tracknum,IN_DRWB) end
function muteExpression(tracknum,val) setSendMuted(tracknum,IN_EXP) end
--------------------------------------------------------------------------------------------
---------------------------------NOTESOURCE SWITCHING---------------------------------------

function getNotesourceSetting(tracknum)    
    local nsIndex = getMoonParam(tracknum,NOTESOURCE_PARAM)
    dbg('getNotesourceSetting:  track: ',tracknum,'ns Index = ',nsIndex)
    return nsIndex
end 

function setOutputByNotesource(tracknumber,nsindex)
    --If an inst has output D, it should NOT change with ns!
    if getMoonParam(tracknumber,AUDIO_OUTPUT_PARAM) ~= OUT_PARAM_D then
        if nsIndex == NS_KEYB then 
            setOutputSend(tracknumber,OUT_A)
        elseif nsIndex == NS_ROLI then  
            setOutputSend(tracknumber,OUT_B)
        elseif nsIndex == NS_DUAL then
            setOutputSend(tracknumber,OUT_A)
        elseif nsIndex == NS_NONE then 
            setOutputSend(tracknumber,OUT_C)
        end 
    end
end

function muteSendsByNotesource(tracknumber,nsindex)
    if nsIndex == NS_KEYB then 
        setSendMuted(IN_KEYB,tracknumber,0)
        setSendMuted(IN_ROLI,tracknumber,1)
    elseif nsIndex == NS_ROLI then  
        setSendMuted(IN_KEYB,tracknumber,1)
        setSendMuted(IN_ROLI,tracknumber,0)
    elseif nsIndex == NS_DUAL then
        setSendMuted(IN_KEYB,tracknumber,0)
        setSendMuted(IN_ROLI,tracknumber,1)
    elseif nsIndex == NS_NONE then 
        setSendMuted(IN_KEYB,tracknumber,1)
        setSendMuted(IN_ROLI,tracknumber,1)
    end 
end

function setNotesource(tracknumber,nsindex) 
    --set midiChStrip value for input type
    setMoonParam(tracknumber,NOTESOURCE_PARAM,nsindex)   
    setOutputByNotesource(tracknumber,nsindex)
    muteSendsByNotesource(tracknumber,nsindex)
end

function incrementNotesource(tracknumber)
    local nsIndex = getNotesourceSetting(tracknumber)
    --increment it
    nsIndex = incrementValue(nsIndex,0,NS_COUNT-1,true)
    setNotesource(tracknumber,nsIndex)
end

function decrementNotesource(tracknumber)
    local nsIndex = getNotesourceSetting(tracknumber)
    --decrement it
    nsIndex = decrementValue(nsIndex,0,NS_COUNT-1,true)
    setNotesource(tracknumber,nsIndex)
end   
-------------------------------------------------------------------------------------
---------------------------------------NOTESOURCE SOLOING----------------------------
function getTrackLimits(tracknumber)
    return getMoonParam(tracknumber,LO_NOTE_PARAM), getMoonParam(tracknumber,HI_NOTE_PARAM)
end

function setNotesoloLimits(tracknumber, lo, hi)
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

function setNsSolo(tracknumber,solo)
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

----------------------------------------------------------------------------------------------
--------------------------------------- ADDING FX SENDS--------------------------------------
--track templates will be saved without any effect sends, since we don't know what effects we'll
--have when it's reloaded.  So on reloading, we need to add a send for every effect in the mixer
--if this changed the # of effects, we need to add every moon track in the mixer as a (muted) receive.
--yay, this won't affect current routings!
--!!! Sends need to be set up pre-fader!!
----------------------------------------------------------------------------------------------
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
  
--when loading a new template...
function configureTrack(newtrack) 
    --clear any fx sends or returns
    clearRouting(newtrack)
    --add all outputs to the track:
    for out = OUT_MON,OUT_D do
        addSend(newtrack,out)
    end
    --add inputs and mute
    for inp = IN_KEYB,IN_AUX do
        addReceive(newtrack,inp)
        setSendMuted(inp,newtrack,1)
    end
    --enable sustain      
    setSendMuted(IN_SUS,newtrack,0)
    --enable drawbars
    if getMoonParam(newtrack,USE_DRAWBARS_PARAM) == 1 then
        setSendMuted(newtrack,IN_DRWB,0)
    end
    --add sends for all effects tracks
    for i,effect in pairs(getEffectTracks()) do     
        dbg('configureTrack: adding send to new track',effect)
        if effect ~= newtrack then
            addSend(newtrack,effect)
            setSendMuted(newtrack,effect,1)
            setSendPreFader(newtrack,effect)
        end
    end
    --is this an effect track???
    local input = getMoonParam(newtrack,AUDIO_INPUT_PARAM)
    if input == AUDIO_INPUT_MIXER or input == AUDIO_INPUT_BOTH then
        --add this track as muted send to every moon channel
        for i,track in ipairs(getMoonTracks()) do
            if track ~= newtrack then
                addSend(track,newtrack)
                setSendMuted(track,newtrack,1)
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
    muteSendsByNotesource(newtrack,ns) 
    setOutputByNotesource(newtrack,ns)  
    --set effect to idx1, volume off   
    setSendMuted(newtrack,getEffectForIndex(1),0)
    setWetDryLevels(newtrack,0)
end

    ---------------------------------------------------------------------------------------------------------------
    ------------------------------------------------ TEMPLATE LOADING ---------------------------------------------
function loadInstrument(tracknum,instname)
    local path =  reaper.GetResourcePath()..'\\TrackTemplates\\'..instname..'.RTrackTemplate'
    reaper.Main_openProject(path)   
    reaper.SetTrackSelected(getTrackByTCPNum(tracknum), true)
    reaper.ReorderSelectedTracks(tracknum-1,0)
    reaper.DeleteTrack(getTrackByTCPNum(tracknum))   
    configureTrack(tracknum)

    INST_PREFIX = 'MT-'
end

function saveInstrument(tracknum)
    clearRouting(tracknum)
    local name = reaper.getTrackName(getTrackByTCPNum(tracknum))
    dbg('saveInstrument: name=',name)
    name = INST_PREFIX..name
end




---------------------------------------------------------------------------------------------------------------
-------------------------------------------------TESTING METHODS-----------------------------------------------

function test()
    --dbg('test: setting wet level',20)
    --setWetDryLevels(20,.3)
    --configureTrack(getSelectedTrackNumber())
    --clearRouting(getSelectedTrackNumber())
    --loadInstrument(22,'MT-Guitar Rig')

end

test()



    



    

