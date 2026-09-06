-- ============================================
-- THEME.LUA - HUB visual theme
-- ============================================

local theme = {}
local gpu

-- Keep the GPU reference in module-local state.
theme.C = {
    bg = 0x000000,
    text = 0xFFFFFF,
    dim = 0x777777,
    border = 0x555555,
    title = 0x55AAFF,
    key = 0xFFFF55,
    ok = 0x55FF55,
    warn = 0xFFAA00,
    partial = 0xAAAAAA,
    ring_down = 0xFF5555,
    unknown = 0xFF55FF,
    sel_bg = 0x202840,
    sel_fg = 0xFFFFFF,
}

local width, height = 80, 25

function theme.init(g)
    gpu = g
    if gpu then
        width, height = gpu.getResolution()
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
    theme.gfill(1, 1, w, 2, " ", theme.C.text, theme.C.bg)
    theme.gset(2, 1, theme.pad(title, math.max(1, w - 4)), theme.C.title, theme.C.bg)
    theme.gset(math.max(2, w - #tostring(status or "")), 1, tostring(status or ""), theme.C.key, theme.C.bg)
    theme.gset(1, 3, string.rep("-", w), theme.C.border, theme.C.bg)
end

function theme.drawFooter(items)
    local y = height
    local x = 2
    theme.gfill(1, y, width, 1, " ", theme.C.text, theme.C.bg)
    for _, item in ipairs(items or {}) do
        local key, label = tostring(item[1]), tostring(item[2])
        local text = "[" .. key .. "] " .. label .. "  "
        if x + #text < width then
            theme.gset(x, y, text, theme.C.key, theme.C.bg)
            x = x + #text
        end
    end
end

return theme
