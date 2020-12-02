-----------------------------MTEXT

--[[
    this is a textfield that has a built-in onscreen keyboard
]]
KeyboardText = {        '1','2','3','4','5','6','7','8','9','0','backspace',
                        'q','w','e','r','t','y','u','i','o','p','&',
                        'a','s','d','f','g','h','j','k','l','-','#',
                        'z','x','c','v','b',' ','n','m','.','_','enter',

                        '1','2','3','4','5','6','7','8','9','0','backspace',
                        'Q','W','E','R','T','Y','U','I','O','P','\"',
                        'A','S','D','F','G','H','J','K','L','+','\'',
                        'Z','X','C','V','B',' ','N','M','(',')','enter'
}
--[[
MText = {}
MText.__index = MText

function MText.new(params)
    local self = setmetatable({}, MText)
    self.x = params.x or 100 self.y = params.y or 100, self.w = 40, self.h = 36
    self.text = params.text or ''
    self.func = function(self) end
    self.createKeyboard(self.text)
end

function MText:visible(visibility)
    if visibility then self.layer:show() else self.layer:hide() end
end

function MText:processKey(key)
    if key == 'enter' then self.func() self.layer:hide() end  --send it off.  how???
    elseif key == 'backspace' then self.text = self.text:sub(1, string.len(s) -2) --trim the last character
    else self.text = self.text..key  self.textfield:setCaption(self.text)
    end
end

function MText:createTextfield()  {
    local textfield = GUI.createElement({
        name = 'text_'..math.random(),
        type = 'MButton',
        image = imageFolder..'Combo.png',
        x = self.x,
        y = self.y,
        frames = 2,
        momentary = true,
        caption = self.text,
    })
    self.textfield = textfield
    return textfield
}

function MText:createKeyboard()
    local keyboard = MButtonPanel.new({
        image = imageFolder.."Combo.png",
        z = 2,
        rows = 4,
        cols = 11,
        w = self.w, self.h = 36, x = self.x + self.w,y = self.y + self.h,
        lowerCase = self.useLowerCase,
        usePager = true,
        pagerImage = imageFolder.."Spinner",
        pagerX = self.x, pagerY = self.h *2,
        pagerW = self.w, pagerH = self.h * 2,
        momentary = true,
        multi = false,
        window = self.window
    })
    for idx,key in pairs(self.getKeyset()) do
        keyboard:setOption(idx,{
            name = key,
            func = function(self) self:processKey(self.keyboard:getSelectionData()) end,
            momentary = true
        })
    end
    keyboard:setPage(1)
    keyboard.layer:addElements(self:createTextfield())
    return keyboard
end





