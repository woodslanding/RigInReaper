-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")()

local GUI = require("gui.core")
local M = require("public.message")
local Table = require("public.table")
local T = Table.T

require 'moonUtils'

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

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


--[[begin
if not reaper.APIExists("JS_Localize") then
  reaper.MB("js_ReaScriptAPI extension is required for this script.", "Missing API", 0)
else
  TStr(GetVstPresets(1),'PRESETS')
end

-- end
reaper.defer(function () end)--]]