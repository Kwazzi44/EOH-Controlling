local component = require("component")
local term = require("term")
local theme = dofile("/home/hub/theme.lua")
local gui = {}
local gpu = component.isAvailable("gpu") and component.gpu or nil
local C = theme.C

local stageLabel = {
    OFF = "[ OFF ]", READY = "[READY]", LOADING = "[LOAD ]",
    STARTING = "[WAIT ]", WORK = "[WORK ]", NO_EU = "[NO EU]",
    ERROR = "[ ERR ]",
}
local stageColor = {
    OFF = C.dim, READY = C.partial, LOADING = C.key,
    STARTING = C.warn, WORK = C.ok, NO_EU = C.ring_down,
    ERROR = C.ring_down,
}

local function progressText(runtime)
    local progress = tonumber(runtime and runtime.progress) or 0
    local maximum = tonumber(runtime and runtime.maximum) or 0
    if maximum > 0 then
        return string.format("%3d%%", math.max(0, math.min(100,
            math.floor(progress / maximum * 100))))
    end
    return "--"
end

local function modeName(settings)
    if settings.mode == "power" then return "ENERGY" end
    if settings.mode == "aa" then return "AA" end
    return "NO AA"
end

function gui.init()
    if not gpu then return false end
    gpu.setDepth(gpu.maxDepth())
    theme.init(gpu)
    return true
end

function gui.drawDetail(eoh, notice, runtime)
    if not gpu then
        term.clear()
        print("EOH: " .. tostring(eoh.name))
        print("Controller: " .. tostring((eoh.components or {}).eoh or "missing"))
        return
    end
    local width, height = theme.getRes()
    local components = eoh.components or {}
    local settings = eoh.settings or {}
    local controller = components.eoh or components.eohController
    runtime = runtime or {stage = controller and "READY" or "OFF"}
    local stage = runtime.stage or "OFF"
    theme.gfill(1, 1, width, height, " ", C.text, C.bg)
    theme.drawHeader(tostring(eoh.name) .. " STATUS", stageLabel[stage] or "[????]")
    theme.gset(1, 4, "| #  COMPONENT                    ROLE          STATE", C.dim, C.bg)
    theme.gset(1, 5, "+" .. string.rep("=", width - 2) .. "+", C.border, C.bg)
    local useAA = settings.mode == "aa"
    local rows = {
        {"EOH", controller, "CONTROLLER"},
        {"H2", components.transposerH2, "HYDROGEN"},
        {"He", components.transposerHe, "HELIUM"},
    }
    if useAA then
        table.insert(rows, {"AA", components.transposerPlasma, "PLASMA"})
    end
    for i, row in ipairs(rows) do
        local y = 5 + i
        local active = row[2] and "BOUND" or "MISSING"
        theme.gset(1, y, "|", C.border, C.bg)
        theme.gset(width, y, "|", C.border, C.bg)
        theme.gset(3, y, string.format("%-3s %-28s %-13s %s", row[1],
            tostring(row[2] or "-"):sub(1, 28), row[3], active),
            row[2] and C.ok or C.ring_down, C.bg)
    end
    theme.gset(3, 12, "MODE: " .. modeName(settings), C.title, C.bg)
    theme.gset(3, 13, "TIER: T" .. tostring(settings.tier or 3)
        .. "   OC: " .. tostring(settings.overclocks or 0)
        .. "   AUTO: " .. (settings.autoRestart ~= false and "ON" or "OFF"), C.text, C.bg)
    theme.gset(3, 14, "STAGE: " .. stage .. "   PROGRESS: "
        .. progressText(runtime), stageColor[stage] or C.unknown, C.bg)
    theme.gset(3, 15, runtime.message or "", C.dim, C.bg)
    theme.gset(3, 16, "CORE BUILD: 20260904-1493", C.dim, C.bg)
    if notice then
        theme.gset(3, 18, tostring(notice):sub(1, width - 5), C.warn, C.bg)
    end
    theme.drawFooter({{"B", "Back"}, {"Enter", "Settings"}, {"R", "Run"}, {"F1", "Setup"}})
end

function gui.draw(eohs, selected, title, runtimes)
    if not gpu then
        term.clear()
        print(title or "EOH CONTROLLER HUB")
        for i, eoh in ipairs(eohs or {}) do
            print((i == selected and "> " or "  ") .. i .. ". " .. tostring(eoh.name))
        end

        return
    end

    local width, height = theme.getRes()
    local total = #(eohs or {})
    theme.gfill(1, 1, width, height, " ", C.text, C.bg)
    theme.drawHeader("GTNH EOH MONITOR", string.format("LIVE - %d CONTROLLERS | B1494", total))
    theme.gset(1, 4, "|" .. theme.pad("#", 4) .. theme.pad("EOH NAME", 16)
        .. theme.pad("STAGE", 11) .. theme.pad("PROGRESS", 10)
        .. theme.pad("MODE", 11) .. theme.pad("TIER", 5)
        .. theme.pad("OC", 5) .. "AUTO", C.dim, C.bg)
    theme.gset(1, 5, "+" .. string.rep("=", width - 2) .. "+", C.border, C.bg)

    local listHeight = height - 11
    for row = 0, listHeight - 1 do
        local index = row + 1
        local y = 6 + row
        theme.gset(1, y, "|", C.border, C.bg)
        theme.gset(width, y, "|", C.border, C.bg)
        if index <= total then
            local eoh = eohs[index]
            local selectedRow = index == (selected or 1)
            local bg = selectedRow and C.sel_bg or C.bg
            local runtime = (runtimes or {})[index] or {stage = "OFF"}
            local stage = runtime.stage or "OFF"
            theme.gfill(2, y, width - 2, 1, " ", C.text, bg)
            theme.gset(3, y, string.format("%02d", index), C.dim, bg)
            theme.gset(6, y, theme.pad(eoh.name or "Unnamed", 16),
                selectedRow and C.sel_fg or C.text, bg)
            theme.gset(22, y, theme.pad(stageLabel[stage] or "[????]", 11),
                stageColor[stage] or C.unknown, bg)
            theme.gset(33, y, theme.pad(progressText(runtime), 10), C.text, bg)
            theme.gset(43, y, theme.pad(modeName(eoh.settings or {}), 11), C.text, bg)
            theme.gset(54, y, theme.pad("T" .. tostring((eoh.settings or {}).tier or 3), 5), C.text, bg)
            theme.gset(59, y, theme.pad(tostring((eoh.settings or {}).overclocks or 0), 5), C.text, bg)
            theme.gset(64, y, ((eoh.settings or {}).autoRestart ~= false and "ON" or "OFF"),
                (eoh.settings or {}).autoRestart ~= false and C.ok or C.dim, bg)
        end
    end

    theme.drawFooter({
        {"Enter", "Details"}, {"F1", "Setup"}, {"Del", "Delete"},
        {"F3", "Refresh"}, {"Q", "Quit"},
    })
end

function gui.clear()
    if gpu then
        local width, height = theme.getRes()
        theme.gfill(1, 1, width, height, " ", C.text, C.bg)
    else
        term.clear()
    end
end

return gui
