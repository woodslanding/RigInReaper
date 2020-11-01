--commands to consider: create RPLs from vst presets

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'lib.moonUtils'

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

function GetPresetList(emptyName)
    local writeFile = true  --true:write, false, write to console
    --Check that fx window is focused----------------------------------------------------
    local focused,tracknum,_,fx_num = reaper.GetFocusedFX()
    --msg('tracknum = '..tracknum)
    if focused then
        Dbg('track num =',tracknum)
        local track = getTrack(tracknum)
        local _,fx_name = reaper.TrackFX_GetFXName(track, fx_num,"")
        --msg('fx name = '..fx_name)
    end
    local vstWindowTitle = reaper.JS_Localize(fx_name, "common") 
    local hwnd = reaper.JS_Window_Find(vstWindowTitle, false)   
    -- check if window found
    if not hwnd then
        reaper.MB("Please open FX in a floating plugin window!", "Window not found", 0)
        return nil
    end
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
        if name == '----  VST built-in programs  ----' then   --'----  User Presets (.rpl)  ----'
                list_start = i+1 
        end
    end
    -- check if user presets found
    if itemCount - list_start == 0 then  
        reaper.MB( "No User Presets Found: ","Not found", 0)
        return
    end 
    -- add user preset names --    
    local presets = {}
    local presetcount = 0
    local presetsByName = {} --for sorting later
    for i = list_start, list_end-1 do
        reaper.JS_WindowMessage_Send(presetWindow, "CB_SETCURSEL", i, 0,0,0)
        local presetname = reaper.JS_Window_GetTitle(presetWindow,"")      
        if presetname == emptyName then --don't add preset
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

function Main()

end


-- begin
if not reaper.APIExists("JS_Localize") then
  reaper.MB("js_ReaScriptAPI extension is required for this script.", "Missing API", 0)
else
  Main()
end

-- end
reaper.defer(function () end)