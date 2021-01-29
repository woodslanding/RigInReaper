--commands to consider: create RPLs from vst presets

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'moonUtils'

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

local vstText = '----  VST built-in programs  ----'
local userText = '----  User Presets (.rpl)  ----'

--[[function Msg(...) --reaper.ShowConsoleMsg(arg)
    local out = {}
    for _, v in ipairs({...}) do
        out[#out+1] = tostring(v)
    end
    reaper.ShowConsoleMsg(table.concat(out, ", ").."\n")
end--]]

function GetPresetList(tracknum, factory, ignoreName, fxnum )
    if not fxnum then fxnum = INSTRUMENT_SLOT end
    if not ignoreName then ignoreName = '' end
    if not tracknum then tracknum = 1 end
    if not factory then factory = false end
    local writeFile = true  --true:write, false, write to console
    --Check that fx window is focused----------------------------------------------------
    OpenPlugin(tracknum,fxnum)
    local focused
    focused,tracknum,_,fxnum = reaper.GetFocusedFX()
    local fx_name
    if focused then
        --Msg('track num ='..tracknum, 'fx num '..fxnum)
        local track = GetTrack(tracknum)
        _,fx_name = reaper.TrackFX_GetFXName(track, fxnum,"")
        --Msg('fx name = '..fx_name)
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
        --[[if factory then startText = vstText; endText = nil else startText = 0; endText = vstText end
        if name == startText then  list_start = i + 1  end
        if name == endText then list_end = i + 1 end--]]
    end
    -- check if user presets found
    --Msg('item count = '..itemCount)
    if  itemCount - list_start == 0 then
        reaper.MB( "No Presets Found: ","Not found", 0)
        return
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
            --msg('added preset '..presetname)
        end
    end
    -- restore preset index
    reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", cur_index, 0,0,0)
    -- str = str..'\n' .. tostring(i-list_start) ..' '..reaper.JS_Window_GetTitle(presetWindow,"")

    --Sort presetWindow, if needed --------------------------------------------------------
    presets = {} --clear presets by num
    local presetTemp = {}
    for n in pairs(presetsByName) do
        table.insert(presetTemp, n)
    end
    table.sort(presetTemp) -- sort
    for i,n in ipairs(presetTemp) do --transfer to array
        table.insert(presets,n)
    end
    return presets
end

function GetVstPresets(tracknum, ignore)
    return GetPresetList(tracknum,true, ignore)
end

function GetRplPresets(tracknum)
    return GetPresetList(tracknum)
end


--begin
if not reaper.APIExists("JS_Localize") then
  reaper.MB("js_ReaScriptAPI extension is required for this script.", "Missing API", 0)
else
  MST(GetVstPresets(1),'PRESETS')
end

-- end
reaper.defer(function () end)--]]