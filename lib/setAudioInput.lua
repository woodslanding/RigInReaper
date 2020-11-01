package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
require 'lib.moonUtils'
dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

--for now just use the selected track, and just increment
setSendPreFader(20,21)