-- ============================================
-- INPUT.LUA - Centralized keyboard handling
-- ============================================
local event = require("event")
local keyboard = require("keyboard")
local M = {}
local function key(name,fallback)
    if keyboard.keys and keyboard.keys[name]~=nil then return keyboard.keys[name] end
    return fallback
end
M.keys={enter=key("enter",28),numpadenter=key("numpadenter",156),up=key("up",200),down=key("down",208),left=key("left",203),right=key("right",205),back=key("back",14),f1=key("f1",59),f3=key("f3",61),delete=key("delete",211),r=key("r",19),b=key("b",48),q=key("q",16)}
function M.wait(timeout)
    local eventName,address,charCode,keyCode,player=event.pull(timeout,"key_down")
    if eventName~="key_down" then return nil end
    return {address=address,char=charCode,code=keyCode,player=player}
end
function M.char(eventData)
    local value=eventData and eventData.char
    if type(value)~="number" or value<0 or value>255 then return "" end
    return string.char(value)
end
function M.is(eventData,name)
    if not eventData then return false end
    local code=eventData.code; local char=M.char(eventData)
    if name=="enter" then return code==M.keys.enter or code==M.keys.numpadenter or code==28 end
    if name=="back" then return code==M.keys.back or code==14 end
    if name=="f1" then return code==M.keys.f1 or code==59 end
    if name=="f3" then return code==M.keys.f3 or code==61 end
    if name=="delete" then return code==M.keys.delete or code==211 end
    if name=="r" then return code==M.keys.r or code==19 or char=="r" or char=="R" end
    if name=="b" then return code==M.keys.b or code==48 or char=="b" or char=="B" end
    if name=="q" then return code==M.keys.q or code==16 or char=="q" or char=="Q" end
    if name=="up" then return code==M.keys.up or code==200 end
    if name=="down" then return code==M.keys.down or code==208 end
    if name=="left" then return code==M.keys.left or code==203 end
    if name=="right" then return code==M.keys.right or code==205 end
    return false
end
return M
