local theme = {}
local gpu
local width, height = 80, 25

theme.C = {
    bg = 0x002B36, sel_bg = 0x073642, sel_fg = 0x268BD2,
    text = 0x839496, dim = 0x586E75, border = 0x1D6680,
    title = 0x268BD2, key = 0xB58900,
    ok = 0x859900, warn = 0xB58900, ring_down = 0xDC322F,
    unknown = 0x586E75, partial = 0x2AA198,
}

function theme.init(value)
    gpu = value
    if gpu then width, height = gpu.getResolution() end
end

function theme.getRes() return width, height end

function theme.gset(x, y, text, fg, bg)
    if not gpu then return end
    if fg then gpu.setForeground(fg) end
    if bg then gpu.setBackground(bg) end
    gpu.set(x, y, text)
end

function theme.gfill(x, y, w, h, char, fg, bg)
    if not gpu then return end
    if fg then gpu.setForeground(fg) end
    if bg then gpu.setBackground(bg) end
    gpu.fill(x, y, w, h, char)
end

function theme.pad(value, length)
    local text = tostring(value or "")
    local unicode = require("unicode")
    if unicode.len(text) > length then
        return unicode.sub(text, 1, math.max(1, length - 1)) .. "~"
    end
    return text .. string.rep(" ", math.max(0, length - unicode.len(text)))
end

function theme.drawHeader(title, subtitle)
    local C = theme.C
    theme.gset(1, 1, "+" .. string.rep("-", width - 2) .. "+", C.border, C.bg)
    theme.gset(1, 2, "|", C.border, C.bg)
    local tag = "==[ " .. tostring(title) .. " ]"
    theme.gset(2, 2, tag .. string.rep("=", math.max(0, width - 2 - #tag)), C.title, C.bg)
    theme.gset(width, 2, "|", C.border, C.bg)
    theme.gfill(2, 3, width - 2, 1, " ", C.dim, C.bg)
    if subtitle then theme.gset(3, 3, "STATUS: " .. tostring(subtitle), C.dim, C.bg) end
    theme.gset(1, 3, "|", C.border, C.bg)
    theme.gset(width, 3, "|", C.border, C.bg)
end

function theme.drawFooter(items)
    local C = theme.C
    theme.gset(1, height - 2, "+" .. string.rep("-", width - 2) .. "+", C.border, C.bg)
    theme.gfill(2, height - 1, width - 2, 1, " ", C.text, C.bg)
    local x = 3
    for _, item in ipairs(items or {}) do
        if x < width - 4 then
            theme.gset(x, height - 1, "[" .. item[1] .. "]", C.key, C.bg)
            x = x + #item[1] + 3
            theme.gset(x, height - 1, item[2], C.text, C.bg)
            x = x + #item[2] + 2
        end
    end
    theme.gset(1, height - 1, "|", C.border, C.bg)
    theme.gset(width, height - 1, "|", C.border, C.bg)
    theme.gset(1, height, "+" .. string.rep("-", width - 2) .. "+", C.border, C.bg)
end

return theme
