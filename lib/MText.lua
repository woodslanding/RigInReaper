-----------------------------MTEXT---------------------------------
--[[
    this is a textfield that has a built-in onscreen keyboard

                        --[['1','2','3','4','5','6','7','8','9','0','backspace',
                        'q','w','e','r','t','y','u','i','o','p','&',
                        'a','s','d','f','g','h','j','k','l','-','#',
                        'z','x','c','v','b',' ','n','m','.','_','enter',

                        '1','2','3','4','5','6','7','8','9','0','backspace',
                        'Q','W','E','R','T','Y','U','I','O','P','\"',
                        'A','S','D','F','G','H','J','K','L','+','\'',
                        'Z','X','C','V','B',' ','N','M','(',')','enter']]
--]]
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")()

require 'Mbutton'
require "moonUtils"
require 'MButtonPanel'

local GUI = require("gui.core")
local M = require("public.message")
local Table = require("public.table")
local T = Table.T

local font = {'Calibri', 36,"b"}

ImageFolder = IMAGE_FOLDER

KeyboardText = {
    '*','[',']','ABC',
    '1','q','a','z',
    '2','w','s','x',
    '3','e','d','c',
    '4','r','f','v',
    '5','t','g','b',
    '6','y','h',' ',
    '7','u','j','n',
    '8','i','k','m',
    '9','o','l','.',
    '0','p','-','_',
    '<<','&','#','-->',

    '!','$','%','abc',
    '1','Q','A','Z',
    '2','W','S','X',
    '3','E','D','C',
    '4','R','F','V',
    '5','T','G','B',
    '6','Y','H',' ',
    '7','U','J','N',
    '8','I','K','M',
    '9','O','L',')',
    '0','P','+','(',
    '<<','\"','\'','-->'
}

Color = GetRGB(170,20,50)

MText = {}
MText.__index = MText

function MText:createTextfield()
    local textfield = GUI.createElement({
        name = "text_"..math.random(),
        type = "MButton",
        --image = ImageFolder.."Combo.png",
        x = self.x + (self.w * 6),
        y = self.y,
        w = self.w * 6,
        h = self.h,
        font = font,
        frames = 2,
        image = nil,
        textColor = 'text',
        momentary = true,
        caption = self.text,
        color = Color,
    })
    self.textfield = textfield
    return textfield
end
function MText:createTitle()
    local title = GUI.createElement({
        name = "title_"..math.random(),
        type = "MButton",
        --image = ImageFolder.."Combo.png",
        x = self.x,
        y = self.y,
        w = self.w * 6,
        h = self.h,
        font = font,
        image = nil,
        frames = 2,
        momentary = true,
        caption = self.text,
        color = 'black',
        textColor = Color
    })
    self.title = title
    return title
end

function MText:createKeyboard(parent)
    local keyboard = MButtonPanel.new({
        image = ImageFolder.."Combo.png",
        z = 2,
        rows = 4,
        cols = 12,
        w = self.w,
        h = self.h,
        x = self.x,
        y = self.y + self.h,
        lowerCase = self.useLowerCase,
        font = font,
        usePager = false,
        momentary = true,
        multi = false,
        window = self.window,
        color = self.color,
    })
    for idx,key in pairs(KeyboardText) do
        keyboard:setOption(idx,{
            name = key,
            func = function(self) parent:processKey(self.name) end,
            momentary = true
        })
    end
    keyboard:setPage(1)
    keyboard.layer:addElements(self:createTextfield())
    keyboard.layer:addElements(self:createTitle())
    return keyboard
end

function MText.new(props)
    local self = setmetatable({}, MText)
    --defaults
    self.x = 100
    self.w = 84
    self.h = 48
    self.text = ""
    self.y = 100
    self.color = Color
    self.func = props.func or function(self) end
    for prop,val in pairs(props) do
        self[prop] = val  --add props from method call
    end
    self.keyboard = self:createKeyboard(self)
    return self
end

function MText:setTitle(text)
    self.title.caption = text
end

function MText:visible(visibility)
    if visibility then self.keyboard.layer:show() else self.keyboard.layer:hide() end
end

function MText:func()
end

function MText:processKey(key)
    if key == "-->" then
        self.func()
        self:setTitle('')
        self.text = ''
        self.textfield:setCaption('')
        self.keyboard.layer:hide()
    elseif key == "abc" then self.keyboard:setPage(1)
    elseif key == "ABC" then self.keyboard:setPage(2)
    elseif key == "<<" then self.text = self.text:sub(1, string.len(self.text) -1) self.textfield:setCaption(self.text)--trim the last character
    else self.text = self.text..key MSG('setting caption:'..self.text) self.textfield:setCaption(self.text)
    end
end






