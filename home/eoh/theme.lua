local theme = {}
local component = require("component")
local gpu = component.isAvailable("gpu") and component.gpu

local C = {
    bg = 0x002B36,
    bg_alt = 0x073642,
    text = 0x839496,
    dim = 0x586E75,
    title = 0x2AA198,
    border = 0x268BD2,
    key = 0xB58900,
    ok = 0x859900,
    warn = 0xCB4B16,
    err = 0xDC322F,
    sel_fg = 0x002B36,
    sel_bg = 0x2AA198
}

theme.C = C
function theme.setGPU(g) gpu = g or gpu end
function theme.fill(x,y,w,h,ch,fg,bg)
    if not gpu then return end
    gpu.setBackground(bg or C.bg); gpu.setForeground(fg or C.text)
    gpu.fill(x,y,w,h,ch or " ")
end
function theme.text(x,y,s,fg,bg)
    if not gpu then return end
    gpu.setBackground(bg or C.bg); gpu.setForeground(fg or C.text)
    gpu.set(x,y,tostring(s))
end
function theme.clear() theme.fill(1,1,gpu.getResolution()," ",C.text,C.bg) end
function theme.line(y,char,fg)
    if not gpu then return end
    local w = select(1,gpu.getResolution())
    theme.text(1,y,string.rep(char or "-",w),fg or C.border,C.bg)
end
return theme
