-- ============================================
-- THEME.LUA - GTNH Planet Monitor inspired theme
-- ============================================

local theme = {}
local gpu

theme.C = {
    bg = 0x002B36,
    text = 0x839496,
    dim = 0x586E75,
    border = 0x1D6680,
    title = 0x268BD2,
    key = 0xB58900,
    ok = 0x859900,
    warn = 0xB58900,
    partial = 0x2AA198,
    ring_down = 0xDC322F,
    unknown = 0x586E75,
    sel_bg = 0x073642,
    sel_fg = 0x268BD2,
}

local width, height = 80, 25

function theme.init(g)
    gpu = g
    if gpu then
        width, height = gpu.getResolution()
        gpu.setBackground(theme.C.bg)
        gpu.setForeground(theme.C.text)
    end
end

function theme.getRes()
    return width, height
end

function theme.gfill(x, y, w, h, char, fg, bg)
    if not gpu then return end
    if not w or w <= 0 or not h or h <= 0 then return end
    gpu.setForeground(fg or theme.C.text)
    gpu.setBackground(bg or theme.C.bg)
    gpu.fill(x, y, w, h, char or " ")
end

function theme.gset(x, y, text, fg, bg)
    if not gpu then return end
    gpu.setForeground(fg or theme.C.text)
    gpu.setBackground(bg or theme.C.bg)
    gpu.set(x, y, tostring(text or ""))
end

function theme.pad(value, size)
    value = tostring(value or "")
    if #value > size then return value:sub(1, size) end
    return value .. string.rep(" ", size - #value)
end

function theme.drawHeader(title, status)
    local w = width
    theme.gfill(1, 1, w, 3, " ", theme.C.text, theme.C.bg)
    theme.gset(2, 1, "==[ " .. tostring(title or "") .. " ]==", theme.C.title, theme.C.bg)
    local s = tostring(status or "")
    if #s > 0 and #s < w - 4 then
        theme.gset(w - #s - 1, 1, s, theme.C.key, theme.C.bg)
    end
    theme.gset(2, 2, "STATUS: ", theme.C.dim, theme.C.bg)
    theme.gset(10, 2, s, theme.C.text, theme.C.bg)
    theme.gset(1, 3, string.rep("-", w), theme.C.border, theme.C.bg)
end

function theme.drawFooter(items)
    local y = height
    local x = 2
    theme.gfill(1, y, width, 1, " ", theme.C.text, theme.C.bg)
    for _, item in ipairs(items or {}) do
        local key, label = tostring(item[1]), tostring(item[2])
        local keyText = "[" .. key .. "]"
        local text = keyText .. " " .. label .. "  "
        if x + #text < width then
            theme.gset(x, y, keyText, theme.C.key, theme.C.bg)
            theme.gset(x + #keyText + 1, y, label .. "  ", theme.C.text, theme.C.bg)
            x = x + #text
        end
    end
end

return theme
