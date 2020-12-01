-----------------------------MTEXT

--[[
    this is a textfield that has a built-in onscreen keyboard
]]
MText = {}
MText.__index = MText

function MText.new(icon,x,y,h,w,color,)
    self.icon = icon
    self.color = color
    self.x = x self.y = y self.w = w self.h = h
end

local keyboardText = {  '1','2','3','4','5','6','7','8','9','0','backspace',
                        'Q','W','E','R','T','Y','U','I','O','P',"'",
                        'A','S','D','F','G','H','J','K','L','-','"',
                        'Z','X','C','V','B',' ','N','M','&','_','enter'
        }

local Keyboard = MButtonPanel.new(imageFolder.."Combo.png",textLayer,4,11,self.x,self.y,self.h,self.w)
    for idx,key in pairs(keyboardText) do
        Keyboard:setOption(idx,key,0,function(self) processKey(self:getSelection(1)))
    end
    Keyboard:setPage(1)
return presets

