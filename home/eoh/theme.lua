-- ============================================================
-- EOH CONTROLLER - SOLARIZED DARK THEME
-- ============================================================

local theme = {}
local gpu
local W, H = 80, 25

-- Те же основные цвета, что используются в Planet Monitor.
theme.C = {
    bg = 0x002B36,
    header_bg = 0x073642,
    sel_bg = 0x073642,
    sel_fg = 0x268BD2,
    text = 0x839496,
    dim = 0x586E75,
    border = 0x1D6680,
    title = 0x268BD2,
    key = 0xB58900,
    ok = 0x859900,
    warn = 0xB58900,
    error = 0xDC322F,
    partial = 0x2AA198
}

function theme.init(customGpu)
    gpu = customGpu
    if gpu then
        W, H = gpu.getResolution()
    end
end

function theme.getRes()
    return W, H
end

function theme.gset(x, y, text, fg, bg)
    if not gpu then return end
    if fg then gpu.setForeground(fg) end
    if bg then gpu.setBackground(bg) end
    gpu.set(x, y, text)
end

function theme.gfill(x, y, w, h, ch, fg, bg)
    if not gpu then return end
    if fg then gpu.setForeground(fg) end
    if bg then gpu.setBackground(bg) end
    gpu.fill(x, y, w, h, ch)
end

function theme.clear()
    theme.gfill(1, 1, W, H, " ", theme.C.text, theme.C.bg)
end

function theme.pad(text, width)
    local unicode = require("unicode")
    text = tostring(text or "")
    if unicode.len(text) > width then
        return unicode.sub(text, 1, math.max(1, width - 1)) .. "~"
    end
    return text .. string.rep(" ", width - unicode.len(text))
end

function theme.drawHeader(title, subtitle)
    local C = theme.C
    theme.gset(1, 1, "+" .. string.rep("-", W - 2) .. "+", C.border, C.bg)
    theme.gset(1, 2, "|", C.border, C.bg)

    local tag = "==[ " .. tostring(title) .. " ]"
    local fill = string.rep("=", math.max(0, W - 2 - #tag))
    theme.gset(2, 2, tag .. fill, C.title, C.bg)
    theme.gset(W, 2, "|", C.border, C.bg)

    theme.gset(1, 3, "|", C.border, C.bg)
    theme.gfill(2, 3, W - 2, 1, " ", C.dim, C.bg)
    if subtitle then
        theme.gset(3, 3, "STATUS: " .. tostring(subtitle), C.dim, C.bg)
    end
    theme.gset(W, 3, "|", C.border, C.bg)
end

function theme.drawFooter(keys)
    local C = theme.C
    theme.gset(1, H - 2, "+" .. string.rep("-", W - 2) .. "+", C.border, C.bg)
    theme.gfill(2, H - 1, W - 2, 1, " ", C.text, C.bg)
    theme.gset(1, H - 1, "|", C.border, C.bg)

    local x = 3
    for _, key in ipairs(keys or {}) do
        if x >= W - 4 then break end
        theme.gset(x, H - 1, "[" .. key[1] .. "]", C.key, C.bg)
        x = x + #key[1] + 3
        theme.gset(x, H - 1, key[2], C.text, C.bg)
        x = x + #key[2] + 2
    end

    theme.gset(W, H - 1, "|", C.border, C.bg)
    theme.gset(1, H, "+" .. string.rep("-", W - 2) .. "+", C.border, C.bg)
end

return theme
