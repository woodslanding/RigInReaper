dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local found, trackChunk = ultraschall.GetTrackStateChunk_Tracknumber(1)
local chainChunk = ultraschall.GetFXStateChunk(trackChunk)
local fxLines = ultraschall.GetFXFromFXStateChunk(chainChunk, 2)
local fx_statestring_base64, fx_statestring = ultraschall.GetFXSettingsString_FXLines(fxLines)
--reaper.ShowConsoleMsg(fxLines)
print(fxLines)
ToClip(fx_statestring..'\n')