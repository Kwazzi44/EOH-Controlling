-- ============================================================
-- EOH CONTROLLER HUB
-- Универсальный HUD для всех зарегистрированных EOH.
--
-- ВАЖНО:
--   • Реальные параметры EOH пока не записываются в контроллер.
--   • Экран конфигурации изменяет сохранённый профиль registry.dat.
--   • Для физического переназначения транспозеров используется Setup.
-- ============================================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;" .. package.path

local component = require("component")
local event = require("event")
local shell = require("shell")
local theme = require("theme")
local registry = require("registry")
local core = require("eoh_core")
local recipes = require("recipes")
local logger = require("logger")

local gpu = component.isAvailable("gpu") and component.gpu
if not gpu then
    print("GPU not found")
    return
end

theme.setGPU(gpu)
logger.init()
logger.load()
registry.load()

local W, H = gpu.getResolution()
local C = theme.C

local function charKey()
    local ev = table.pack(event.pull("key_down"))
    return ev[3] or 0 -- ASCII character code
end

local function waitKey()
    event.pull("key_down")
end

local function drawFrame(title)
    theme.fill(1, 1, W, H, " ", C.text, C.bg)
    theme.text(1, 1, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)
    theme.text(2, 2, "==[ EOH CONTROLLER ]", C.title, C.bg)
    theme.text(1, 3, "|", C.border, C.bg)
    theme.text(W, 3, "|", C.border, C.bg)
    theme.text(3, 3, title or "Universal HUB", C.dim, C.bg)
    theme.text(1, 4, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)

    for y = 5, H - 3 do
        theme.text(1, y, "|", C.border, C.bg)
        theme.text(W, y, "|", C.border, C.bg)
    end

    theme.text(1, H - 2, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)
    theme.text(1, H - 1, "|", C.border, C.bg)
    theme.text(W, H - 1, "|", C.border, C.bg)
    theme.text(1, H, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)
end

local function footer(text)
    theme.text(3, H - 1, text, C.key, C.bg)
end

local function modeLabel(entry)
    if entry.mode == "production_aa" then
        return "PRODUCTION + AA"
    elseif entry.mode == "power" then
        return "POWER / DEEP DARK"
    end
    return "PRODUCTION"
end

local function tierLabel(entry)
    local tier = tonumber(entry.tier) or 1
    local recipe = recipes.get(tier)
    return recipe and recipe.display or ("T" .. tier)
end

local function getDisplaySettings(entry)
    entry.overclocks = math.max(0, math.min(3, tonumber(entry.overclocks) or 0))
    if entry.mode == "power" then
        entry.overclocks = 0
    end
    if entry.mode == "production_aa" then
        entry.useAA = true
    else
        entry.useAA = false
    end
    if entry.autoRestart == nil then entry.autoRestart = true end
    if entry.fluidTolerance == nil then entry.fluidTolerance = 0.001 end
end

local function saveEntry(entry)
    getDisplaySettings(entry)
    local recipe = core.recipeFor(entry)
    if recipe then
        entry.recipe_display = recipe.display
        entry.calculation = core.calculatePlan(entry, recipe)
    end
    return registry.save()
end

local function sourceSummary(channel)
    if not channel then return "-" end
    return string.format(
        "T%s | side %d | tank %d | %.0f L/s",
        tostring(channel.transposer or "?"):sub(1, 8),
        tonumber(channel.sourceSide) or -1,
        tonumber(channel.sourceTank) or -1,
        tonumber(channel.rate) or 0
    )
end

local function configScreen(entry)
    getDisplaySettings(entry)

    local selected = 1
    local fields = {
        "mode",
        "tier",
        "overclocks",
        "autoRestart",
        "fluidTolerance"
    }

    while true do
        drawFrame("Configuration: " .. (entry.name or "EOH"))

        theme.text(3, 5, "REGISTERED EOH", C.title, C.bg)
        theme.text(3, 6, "Address: " .. tostring(entry.adapter_addr or "-"), C.dim, C.bg)

        theme.text(3, 8, "1  Work profile", selected == 1 and C.sel_fg or C.text, selected == 1 and C.sel_bg or C.bg)
        theme.text(27, 8, modeLabel(entry), selected == 1 and C.sel_fg or C.text, selected == 1 and C.sel_bg or C.bg)

        theme.text(3, 9, "2  Planet tier", selected == 2 and C.sel_fg or C.text, selected == 2 and C.sel_bg or C.bg)
        theme.text(27, 9, entry.mode == "power" and "T9 Deep Dark (fixed)" or tierLabel(entry), selected == 2 and C.sel_fg or C.text, selected == 2 and C.sel_bg or C.bg)

        theme.text(3, 10, "3  Overclocks", selected == 3 and C.sel_fg or C.text, selected == 3 and C.sel_bg or C.bg)
        theme.text(27, 10, tostring(entry.overclocks), selected == 3 and C.sel_fg or C.text, selected == 3 and C.sel_bg or C.bg)

        theme.text(3, 11, "4  Auto restart", selected == 4 and C.sel_fg or C.text, selected == 4 and C.sel_bg or C.bg)
        theme.text(27, 11, entry.autoRestart and "ON" or "OFF", selected == 4 and C.sel_fg or C.text, selected == 4 and C.sel_bg or C.bg)

        theme.text(3, 12, "5  Fluid tolerance", selected == 5 and C.sel_fg or C.text, selected == 5 and C.sel_bg or C.bg)
        theme.text(27, 12, string.format("%.3f%%", (entry.fluidTolerance or 0.001) * 100), selected == 5 and C.sel_fg or C.text, selected == 5 and C.sel_bg or C.bg)

        theme.text(3, 14, "INPUT CHANNELS", C.title, C.bg)
        if entry.channels and #entry.channels > 0 then
            local row = 15
            for _, ch in ipairs(entry.channels) do
                if row <= H - 8 then
                    theme.text(3, row, string.format("%-14s %s", tostring(ch.fluid), sourceSummary(ch)), C.text, C.bg)
                    row = row + 1
                end
            end
        else
            theme.text(3, 15, "No channels configured.", C.err, C.bg)
        end

        theme.text(3, math.min(H - 7, 20), "NOTE", C.warn, C.bg)
        theme.text(3, math.min(H - 6, 21), "Профиль сохраняется в registry.dat.", C.dim, C.bg)
        theme.text(3, math.min(H - 5, 22), "Для смены физических транспозеров используйте Setup.", C.dim, C.bg)

        footer("[1-5] Select   [A/D] Change   [S] Save   [R] Rebind   [B] Back")

        local ch = charKey()

        if ch == 98 or ch == 66 then -- b/B
            return false
        elseif ch == 115 or ch == 83 then -- s/S
            local ok = saveEntry(entry)
            logger.info("HUB", ok and "EOH configuration saved" or "Failed to save EOH configuration")
            return ok
        elseif ch == 114 or ch == 82 then -- r/R
            shell.execute("/home/hub/setup.lua")
            registry.load()
            local fresh = registry.get(entry.id)
            if fresh then
                entry = fresh
                getDisplaySettings(entry)
            end
        elseif ch >= 49 and ch <= 53 then
            selected = ch - 48
        elseif ch == 97 or ch == 65 or ch == 100 or ch == 68 then -- a/d
            local dir = (ch == 97 or ch == 65) and -1 or 1
            local field = fields[selected]

            if field == "mode" then
                local modes = {"production", "production_aa", "power"}
                local idx = 1
                for i, mode in ipairs(modes) do
                    if mode == entry.mode then idx = i break end
                end
                idx = ((idx - 1 + dir) % #modes) + 1
                entry.mode = modes[idx]
                if entry.mode == "power" then
                    entry.tier = 9
                    entry.overclocks = 0
                elseif entry.mode == "production_aa" then
                    entry.tier = math.max(1, math.min(8, tonumber(entry.tier) or 1))
                else
                    entry.tier = math.max(1, math.min(8, tonumber(entry.tier) or 1))
                end
                getDisplaySettings(entry)
            elseif field == "tier" then
                if entry.mode ~= "power" then
                    local tier = tonumber(entry.tier) or 1
                    tier = tier + dir
                    if tier < 1 then tier = 8 end
                    if tier > 8 then tier = 1 end
                    entry.tier = tier
                end
            elseif field == "overclocks" then
                if entry.mode ~= "power" then
                    entry.overclocks = math.max(0, math.min(3, entry.overclocks + dir))
                end
            elseif field == "autoRestart" then
                entry.autoRestart = not entry.autoRestart
            elseif field == "fluidTolerance" then
                local value = tonumber(entry.fluidTolerance) or 0.001
                value = value + (dir * 0.0001)
                value = math.max(0, math.min(0.01, value))
                entry.fluidTolerance = value
            end
        end
    end
end

local function listView()
    while true do
        drawFrame("Universal EOH HUD")

        theme.text(3, 5, "REGISTERED EOH", C.title, C.bg)

        local all = registry.getAll()
        local arr = {}
        for _, e in pairs(all) do table.insert(arr, e) end
        table.sort(arr, function(a, b) return (a.name or a.id) < (b.name or b.id) end)

        if #arr == 0 then
            theme.text(3, 7, "No EOH registered.", C.warn, C.bg)
            theme.text(3, 9, "Press S to open Setup.", C.dim, C.bg)
        else
            for i, e in ipairs(arr) do
                if i > H - 10 then break end
                local eoh = {address = e.adapter_addr, name = e.name}
                local status = core.readStatus(eoh) or {}
                local line = string.format(
                    "%02d  %-18s %-18s %-18s %5.1f%%",
                    i,
                    (e.name or "EOH"):sub(1, 18),
                    tierLabel(e):sub(1, 18),
                    modeLabel(e):sub(1, 18),
                    status.percent or 0
                )
                theme.text(3, 6 + i, line, status.active and C.ok or C.text, C.bg)
            end
        end

        footer("[1-9] Configure   [S] Setup   [R] Refresh   [U] Update   [Q] Quit")

        local ch = charKey()

        if ch == 1 or ch == 81 or ch == 113 then
            return
        elseif ch >= 49 and ch <= 57 then
            local index = ch - 48
            if arr[index] then
                configScreen(arr[index])
                registry.load()
            end
        elseif ch == 83 or ch == 115 then
            shell.execute("/home/hub/setup.lua")
            registry.load()
        elseif ch == 82 or ch == 114 then
            registry.load()
        elseif ch == 85 or ch == 117 then
            shell.execute("/home/U.lua")
            registry.load()
        end
    end
end

listView()
