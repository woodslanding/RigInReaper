-- Meo-Ada Mespotine - convert a preset-file of a vst or jsfx to an rpl-file - 23th of October 2020
--
-- licensed under MIT-license

-- insert Ultraschall-API-functions into this script
    dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")


-- Step1: ask for presetfile and targetfilename
    retval, filename = reaper.GetUserFileNameForRead(reaper.GetResourcePath().."/presets/.", "Select Presetfile", "*.ini")
    if retval==false then return end
    retval, filename2 = reaper.JS_Dialog_BrowseForSaveFile("Where to store the rpl-file?", reaper.GetResourcePath(), "", "")
    if retval==false then return end


-- Step 2: Let's get the pluginname; only vst64 and js supported currently
    path, file=ultraschall.GetPath(filename)
    file=string.gsub(file, ".ini", "")

    -- which plugintype? vst- or js-? Read it from the filename of the presetfile.
    if file:match("vst")~=nil then FX="VST: " inifile="reaper-vstplugins64.ini" file=string.gsub(file, "vst%-", "")
    elseif file:match("js")~=nil then FX="" inifile="reaper-jsfx.ini" file=string.gsub(file, "js%-", "") file=string.gsub(file, "%_", "/", 1)
    else
      reaper.MB("Sorry, plugintype not supported...\n\nPlease tell the developer the filename "..path, "Error", 0)
    end

    IniFile=ultraschall.ReadFullFile(reaper.GetResourcePath().."/"..inifile).."\n"
    IniEntry=IniFile:match(file..".-\n") -- let's find the right line in the ini-file
    Name=IniEntry:match("\"(.-)\"")                         -- if VST
    if Name==nil then Name=IniEntry:match(",.-,(.*)\n") end -- if JSFX


-- Step 3: Let's create the rpl-filelist
    -- first, we need to get the number of existing presets
    retval, PresetCount = ultraschall.GetIniFileValue("General", "NbPresets", "", filename)
    PresetCount=tonumber(PresetCount)

    -- String will be the string, that holds the entire rpl-datastructur
    String="<REAPER_PRESET_LIBRARY `"..FX..Name.."`\n" -- start the rpl-datastructure

    for i=0, PresetCount-1 do
      -- Get the name of the preset
      retval, Name=ultraschall.GetIniFileValue("Preset"..i, "Name", "", filename)
      -- Get the data of the preset. It's a hex-string, but rpl-files need this as a base64-string.
      -- So we need to convert it.
      retval, Data=ultraschall.GetIniFileValue("Preset"..i, "Data", "", filename) -- read Hex-string
      Data=string.gsub(Data, "\n", "") -- remove all newlines that are stored in the data
      Data=ultraschall.ConvertHex2Ascii(Data) -- convert it into a normal binary string
      Data=ultraschall.Base64_Encoder(Data:sub(1,-2)) -- convert the binary string into its Base64-equivalent

      -- Now we add the entries into the rpl-datastructure
      -- New preset-block with the Presetname
      String=String.."  <PRESET `"..Name.."`\n"

      -- Data. It must be split into lines of 128-bytes
      while Data:len()>0 do
        String=String.."    "..Data:sub(1,128).."\n"
        Data=Data:sub(129,-1)
      end

      -- End of this Presetblock
      String=String.."  >\n"
    end

    -- Let's finish up the entire RPL-structure
    String=String..">\n"

    -- make newlines to carriage return newlines, like Windows does(not needed, only in here for maximum compatibility)
    String=string.gsub(String, "\n", "\r\n")


-- Step 4: Write it into the file
    ultraschall.WriteValueToFile(filename2, String)