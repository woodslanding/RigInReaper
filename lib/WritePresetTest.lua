

--[[  PRESET FILE FORMAT:
    Filename presets/vst-VST_DLL_NAME
        [General]
        NbPresets=N

        [PresetN]
        Data =
        Data_1 =
        Name =
        Len =
    ]]


dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local function get_CtrlSum(HEX)
    local Sum = 0
    for i=1, #HEX, 2 do  Sum = Sum + tonumber( HEX:sub(i,i+1), 16) end
    return string.sub( string.format("%X", Sum), -2, -1 )
end


function WritePreset(trackNum, fxNum, presetName, vstName)
    --get track data
    local found, data = ultraschall.GetTrackStateChunk_Tracknumber(trackNum)
    if not found then MSG('Track chunk not found: ',trackNum, fxNum) end
    data = ultraschall.GetFXStateChunk(data)
    data = ultraschall.GetFXFromFXStateChunk(data, fxNum + 1)  --ultraschall fx are 1-based
    data = ultraschall.GetFXSettingsString_FXLines(data)
    data = ultraschall.Base64_Decoder(data)
    data = ultraschall.ConvertAscii2Hex(data)
    --MSG('data',data)
    --local data = getPresetHex(chanNum, fxNum)
    --prepare for writing file
    local presetFile = reaper.GetResourcePath()..'/presets/vst-'..vstName..'.ini'
    MSG('path = ', presetFile)
    local presetCount, key, section
    if reaper.file_exists(presetFile) then
        ultraschall.GetIniFileValue()
         _, presetCount =  reaper.BR_Win32_GetPrivateProfileString("General", "NbPresets", "", presetFile)
        section = 'Preset'..math.tointeger(presetCount)
    else section, presetCount = 'Preset0', 1
    end
    --Update/write number of presets
    presetCount = math.tointeger(presetCount + 1)
    ultraschall.SetIniFileValue('General', 'NbPresets', presetCount, presetFile)
    local presetLength = #data
    local stringPos = 1
    for i = 1, math.ceil(presetLength/32768) do
        if i == 1 then key = 'Data' else key = 'Data_'..(i - 1) end
        local chunk = data:sub(stringPos, stringPos + 32767)
        local sum = get_CtrlSum(chunk)
        ultraschall.SetIniFileValue(section, key, chunk..sum, presetFile)
        stringPos = stringPos + 32768
    end
    ultraschall.SetIniFileValue(section,'Name', presetName, presetFile)
    ultraschall.SetIniFileValue(section,'Len', presetLength//2, presetFile)
end
