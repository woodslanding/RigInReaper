dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

function GetTrack(tracknum)
    return reaper.GetTrack(0, tracknum - 1)
end

function GetFXName(chanNum,slot)
    local tracknum = TrackOfChan(chanNum)
    local track = GetTrack(tracknum)
    if not slot then slot = INSTRUMENT_SLOT end
    --MSG('GETFXNAME, tracknum = '..tracknum)
    local done,name = reaper.BR_TrackFX_GetFXModuleName(track,slot,"",128)--NOT SHOWN IN API DOCS!
    if done then --MSG('getting fx name: '..name)
    elseif track then ERR('MU.GetFXName--fx name failed at track,slot: ',tracknum,slot)
    end
    return GetFilename(name)  --strip off .dll
end

function MSG(...)
    if DBG_OFF then return end
    local out = {}
    for _, v in ipairs({...}) do
      out[#out+1] = tostring(v)
    end
    reaper.ShowConsoleMsg(table.concat(out, " ").."\n")
end

function StartsWith(sourceString, start)
    return sourceString:sub(1, string.len(start)) == start
 end

function WritePreset(trackNum, fxNum)
    --get track data
    local found, data = ultraschall.GetTrackStateChunk_Tracknumber(trackNum)
    local vstName = GetFXName(chanNum, fxNum)
    --MSG('data:'..data)
    local fxState = ultraschall.GetFXStateChunk(data)
    data = ultraschall.GetFXFromFXStateChunk(data, fxNum + 1)  --ultraschall fx are 1-based
    data = ultraschall.GetFXSettingsString_FXLines(data)
    local decoded = ultraschall.Base64_Decoder(data)
    local hex = ultraschall.ConvertAscii2Hex(decoded)
    --prepare for writing file
    ToClip(hex)

    local presetFile = reaper.GetResourcePath()..'/presets/vst-'..vstName..'.ini'
    MSG('path = ', presetFile)
    local presetCount, key, section
    if reaper.file_exists(presetFile) then
        ultraschall.GetIniFileValue()
         _, presetCount =  reaper.BR_Win32_GetPrivateProfileString("General", "NbPresets", "", presetFile)
        section = 'Preset'..math.tointeger(presetCount)
    else section, presetCount = 'Preset0', 0
    end
    presetCount = math.tointeger(presetCount + 1)
    --Update/write number of presets
    ultraschall.SetIniFileValue('General', 'NbPresets', presetCount, presetFile)
    local presetLength = #data
    local stringPos = 1
    ---from Eugen's method... maybe there's a better way?
    for i = 1, math.ceil(presetLength/32768) do
        if i == 1 then key = 'Data' else key = 'Data_'..(i - 1) end
        local chunk = data:sub(stringPos, stringPos + 32767)
        local sum = 0
        for i = 1, #chunk, 2 do  sum = sum + tonumber( chunk:sub(i,i + 1), 16) end
        sum = string.sub( string.format("%X", sum), -2, -1 )
        ultraschall.SetIniFileValue(section, key, chunk..sum, presetFile)
        stringPos = stringPos + 32768
    end
    ultraschall.SetIniFileValue(section,'Name', presetName, presetFile)
    -- don't understand //2, it's from Eugen, but the code didn't work until I added it
    ultraschall.SetIniFileValue(section,'Len', presetLength//2, presetFile)
    reaper.TrackFX_SetPreset(GetTrack(trackNum), fxNum, presetName)--]]
end

function Get_Strings_Until(stringTable, index, test)
    --MSG('checking string: '..stringTable[index]..'index: '..index)
    if StartsWith(stringTable[index], test) then return index
    elseif index == #stringTable then return -1
    else return Get_Strings_Until(stringTable, index + 1, test)
    end
end
--My almost regex free, homemade parsing....
local function getFXLines(chanNum, fxNum)
    if not fxNum then fxNum = INSTRUMENT_SLOT end
    local track = GetTrack(TrackOfChan(chanNum))
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
        FX_Type = lines[fxIDX]:sub(2,4)  --not supported yet
        fxIDX = fxIDX + 1
    end
    local lastIDX = Get_Strings_Until(lines, fxIDX, ">") - 1
    return lines, fxIDX, lastIDX, chainIDX, FX_Type
end

function SaveMoonPreset(chanNum, fxNum)
    local lines, first, last  = getFXLines(chanNum, fxNum)
    local presetName = GetFxPresetName(chanNum, fxNum)
    local vstName = GetFXName(chanNum, fxNum)
    local filename = BANK_FOLDER..vstName..'/'..presetName..'.MPF'
    MSG('file = '..filename)
    CreateFolder(BANK_FOLDER..vstName)
    local file = io.open(filename,'w+')
    MSG('writing to file: '..filename)
    --local chunkTable = {}
    for i = first,last do
        file:write(lines[i],'\n')
    end
    file:close()
end

function LoadMoonPreset(chanNum, fxNum, presetName)
    local fxLines = {}
    local fileName = BANK_FOLDER..GetFXName(chanNum, fxNum)..'/'..presetName..'.MPF'
    for line in io.lines(fileName) do
        fxLines[#fxLines + 1] = line
    end
    local lines, first, last = getFXLines(chanNum, fxNum)
    for i = first, last do
        lines[i] = fxLines[i - first + 1]
    end
    local str = table.concat(lines,'\n')
    reaper.SetTrackStateChunk(GetTrack(TrackOfChan(chanNum)), str, false)
end

WritePreset(23,1)