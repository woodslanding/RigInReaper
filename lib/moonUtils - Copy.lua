dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

--Functions to:
--setNotesource, setEffectDestination,
--TODO: notesource soloing

DBG = true
--ch strip settings
MIDICHSTRIP_NAME = "JS: midiChStrip" 
MIDICHSTRIP_SLOT = 1 --fx numbered from 0???
NS_SOLO_PARAM = 8
NS_MUTE_LOW_PARAM = 9
NS_MUTE_HI_PARAM = 10
AUDIO_INPUT_PARAM = 24

NS_SELECT_PARAM = 14
NS_COUNT = 4
KEYB,DUAL,ROLI,NONE = 0,1,2,3
OUTPUT_A,OUTPUT_B,OUTPUT_C,OUTPUT_D = 3,4,5,6
KEYB_IN,ROLI_IN = 7,8

REAPER_SEND = 0
REAPER_RCV = -1


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
    local tr = getTrackByTCPNum(tracknum)
    return reaper.GetTrackNumSends( tr, REAPER_SEND )
end

function getReceive(tracknum,index)        
    local tr = getTrackByTCPNum(tracknum)
    local srcTrack = reaper.BR_GetMediaTrackSendInfo_Track( tr, REAPER_RCV, index-1, 0)
    --ultraschall.GetTrackAUXSendReceives(tracknumber, i) + 1
    return getNumberOfTrack( srcTrack )
end

function removeReceive(tracknum,idx)
    --dbg('removing receive '..idx..' from fx track '..tracknum)
    _ = ultraschall.DeleteTrackAUXSendReceives(tracknum, getRcvCount(), false)
end

function addReceive(destTrack,srctrack)
    --dbg('addReceive: adding receive to ',fxtrack)
    --dbg('addReceive: from track '..srctrack)
    mediatrack = getTrackByTCPNum(srctrack)
    mediaFxTrack = getTrackByTCPNum(desttrack)
    reaper.CreateTrackSend( mediatrack, mediaFxTrack )
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
        dest = getSendDest(tracknum,i)
        if dest == destTrack then
            return i
        end
    end
end

function setSendMuted(tracknum,dest,setmute)
    index = getSendIndex(tracknum,dest)
    toggle = (isSendMuted(tracknum,index) and not setmute) or 
             (not isSendMuted(tracknum,index) and setmute)
    if toggle then toggleSendMuted(tracknum,dest)
    end
end
    

function toggleSendMuted(tracknum,dest)
    --dbg('toggleSendMuted: tracknum = ',tracknum,'dest =',dest)
    track = getTrackByTCPNum(tracknum)
    index = getSendIndex(tracknum,dest)
    reaper.ToggleTrackSendUIMute( track, index -1 ) 
end




----------------------------------------EFFECT SWITCHING-------------------------------------
--track templates will be saved without any effect sends, since we don't know what effects we'll
--have when it's reloaded.  So on reloading, we need to add a send for every effect in the mixer

function isEffectTrack(tracknum)
    track = getTrackByTCPNum(tracknum)
    local isFX,_,_ = reaper.TrackFX_GetParam(track, MIDICHSTRIP_SLOT, AUDIO_INPUT_PARAM)    
    return isFX > 1  --0 no input, 1 exernal input
end

function getEffectTracks()
    local effectTracks = {}
    local trackcount = reaper.CountTracks(0)
    dbg('track count = ',trackcount)
    local effectCount = 0
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
        dbg('getEffectForTrack: sendcount = ',getSendCount(tracknum))
        dest = getSendDest(tracknum,i)
        dbg('getEffectForTrack: index',i,'destination is',dest)
        muted = isSendMuted(tracknum,i)
        dbg('getEffectForTrack: dest',dest,'mute status =',muted)
        _,name = reaper.GetTrackName(getTrackByTCPNum(dest),'')
        dbg('getEffectForTrack: track -',name,'index',i)
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
    for i,track in pairs(tracks) do
        dbg('getIndexForEffect: i = ',i,', track = ',track)
        if track == tracknum then
            dbg('getIndexForEffect: returning index = ',i)
            return i,count
        end
    end
end

function incrementEffect(tracknum,decInstead)
    --get track num of current send. Will be the last in the list.
    --local tr = getTrack(tracknum)
    dbg('incrementEffect: getting effects for: ',tracknum)
    local origFxTrack = getEffectForTrack(tracknum)
    local fxindex,fxCount = getIndexForEffect(origFxTrack)  --what was the previous index?
    dbg('incrementEffect: initial index = ',fxindex)
    if decInstead then 
        fxindex = decrementValue(fxindex,0,fxCount-1,true)
    else fxindex = incrementValue(fxindex,0,fxCount-1,true)
    end
    dbg('incrementEffect: fx index = ',fxindex)
    local fxTrack,_ = getEffectForIndex(fxindex) 
    dbg('incrementEffect: orig fx track = ',origFxTrack) 
    dbg('incrementEffect: fx track = ',fxTrack)
    toggleSendMuted(tracknum,origFxTrack)
    toggleSendMuted(tracknum,fxTrack)
end
---------------------------------NOTESOURCE SWITCHING---------------------------------------

function addMidiReceive(tracknumber,srcChan)--TODO: check normal addReceive works here
    local midi = 0
    --set to midi input (1024) TODO:  Check, This may cause it to receive midi volume!!
    return ultraschall.AddTrackAUXSendReceives(srcChan,tracknumber,
                                        0,0,0,0,0,0,1,1,-1,midi,-1,false)
          or print2("problem setting midi receive from track "
                    ..tostring(srcChan).." to track "..tostring(tracknumber))
end

function getNotesourceSetting(tcpnumber)    
    local track = getTrackByTCPNum(tcpnumber)
    local nsIndex,_,_ = reaper.TrackFX_GetParam( track, MIDICHSTRIP_SLOT, NS_SELECT_PARAM ) 
    dbg('getNotesourceSetting:  track: ',tcpnumber,'ns Index = ',nsIndex)
    return nsIndex
end 

function updateTrackNotesourceSetting(tracknumber,nsIndex) 
    --set midiChStrip value for input type
    local tr = getTrackByTCPNum(tracknumber)
    reaper.TrackFX_SetParam(tr,MIDICHSTRIP_SLOT,NS_SELECT_PARAM,nsIndex)   
    if nsIndex == KEYB then 
        setSendMuted(ROLI_IN,tracknumber,true)
        setSendMuted(KEYB_IN,tracknumber,false)
        setSendMuted(tracknumber,OUTPUT_A,false)
        setSendMuted(tracknumber,OUTPUT_B,true)
        setSendMuted(tracknumber,OUTPUT_C,true)
        setSendMuted(tracknumber,OUTPUT_D,true)
    elseif nsIndex == ROLI then  
        setSendMuted(ROLI_IN,tracknumber,false)
        setSendMuted(KEYB_IN,tracknumber,true)
        setSendMuted(tracknumber,OUTPUT_A,true)
        setSendMuted(tracknumber,OUTPUT_B,false)
        setSendMuted(tracknumber,OUTPUT_C,true)
        setSendMuted(tracknumber,OUTPUT_D,true)
    elseif nsIndex == DUAL then
        setSendMuted(ROLI_IN,tracknumber,false)
        setSendMuted(KEYB_IN,tracknumber,false) 
        setSendMuted(tracknumber,OUTPUT_A,false)
        setSendMuted(tracknumber,OUTPUT_B,true)
        setSendMuted(tracknumber,OUTPUT_C,true)
        setSendMuted(tracknumber,OUTPUT_D,true) 
    elseif nsIndex == NONE then 
        setSendMuted(ROLI_IN,tracknumber,true)
        setSendMuted(KEYB_IN,tracknumber,true)
        setSendMuted(tracknumber,OUTPUT_A,true)
        setSendMuted(tracknumber,OUTPUT_B,true)
        setSendMuted(tracknumber,OUTPUT_C,false)
        setSendMuted(tracknumber,OUTPUT_D,true)
    end 
end

function incrementNotesource(tracknumber)
    local nsIndex = getNotesourceSetting(tracknumber)
    --increment it
    nsIndex = incrementValue(nsIndex,0,NS_COUNT-1,true)
    updateTrackNotesourceSetting(tracknumber,nsIndex)
end

function decrementNotesource(tracknumber)
    local nsIndex = getNotesourceSetting(tracknumber)
    --decrement it
    nsIndex = decrementValue(nsIndex,0,NS_COUNT-1,true)
    updateTrackNotesourceSetting(tracknumber,nsIndex)
end   

    

