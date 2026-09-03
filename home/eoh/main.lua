-- ============================================================
-- EOH CONTROLLER - MAIN
-- ============================================================

local component = require("component")
local event = require("event")
local os = require("os")

local logger = require("logger")
local theme = require("theme")
local core = require("eoh_core")
local config = require("config")

logger.init()
logger.load()

local gpu = component.isAvailable("gpu") and component.gpu or nil
if gpu then
    theme.init(gpu)
end

local function fmtNumber(value)
    local n = tonumber(value) or 0
    local s = tostring(math.floor(n))
    local sign = ""
    if s:sub(1, 1) == "-" then
        sign = "-"
        s = s:sub(2)
    end

    while true do
        local replaced, count = s:gsub("^(%d+)(%d%d%d)", "%1 %2")
        s = replaced
        if count == 0 then break end
    end

    return sign .. s
end

local function draw()
    if not gpu then return end

    theme.clear()

    local ok, err = core.scan()
    local status = core.getStatus()
    local fluids, fluidErr = core.getFluids()
    local controller = core.getController()
    local transposers = core.getTransposers()

    theme.drawHeader(
        "EOH Controller",
        ok and (status.active and "ACTIVE" or "STOPPED") or "SCAN ERROR"
    )

    local C = theme.C

    theme.gset(3, 5, "EOH", C.title, C.bg)
    theme.gset(3, 6, "Controller:", C.dim, C.bg)
    theme.gset(18, 6, controller and controller.name or "NOT FOUND", C.text, C.bg)

    theme.gset(3, 7, "Progress:", C.dim, C.bg)
    theme.gset(
        18,
        7,
        string.format(
            "%d / %d  (%.1f%%)",
            status.progress,
            status.maxProgress,
            status.percent
        ),
        C.text,
        C.bg
    )

    theme.gset(3, 8, "Work allowed:", C.dim, C.bg)
    theme.gset(18, 8, tostring(status.workAllowed), C.text, C.bg)

    theme.gset(3, 10, "LIQUIDS IN EOH", C.title, C.bg)
    theme.gset(3, 11, "Hydrogen:", C.dim, C.bg)
    theme.gset(22, 11, fmtNumber(fluids.hydrogen) .. " L", C.text, C.bg)

    theme.gset(3, 12, "Helium:", C.dim, C.bg)
    theme.gset(22, 12, fmtNumber(fluids.helium) .. " L", C.text, C.bg)

    theme.gset(3, 13, "Raw Stellar Plasma:", C.dim, C.bg)
    theme.gset(22, 13, fmtNumber(fluids.plasma) .. " L", C.text, C.bg)

    theme.gset(3, 15, "TRANSPOSERS", C.title, C.bg)
    theme.gset(3, 16, "Found:", C.dim, C.bg)
    theme.gset(18, 16, tostring(#transposers), C.text, C.bg)

    for i, transposer in ipairs(transposers) do
        theme.gset(
            3,
            16 + i,
            string.format(
                "#%d  source side %d -> EOH side %d",
                i,
                transposer.fluidSide,
                transposer.eohSide
            ),
            C.text,
            C.bg
        )
    end

    if not ok then
        theme.gset(3, 20, "ERROR: " .. tostring(err), C.error, C.bg)
    elseif fluidErr then
        theme.gset(3, 20, "Sensor warning: " .. tostring(fluidErr), C.warn, C.bg)
    end

    theme.drawFooter({
        {"R", "Rescan"},
        {"S", "Sensor"},
        {"Q", "Quit"}
    })
end

local function showSensor()
    if not gpu then return end

    local lines, err = core.getRawSensorLines()
    theme.clear()
    theme.drawHeader("EOH Sensor", "READ ONLY")

    local C = theme.C
    if not lines then
        theme.gset(3, 5, "ERROR: " .. tostring(err), C.error, C.bg)
    else
        local y = 5
        for _, line in ipairs(lines) do
            if y >= select(2, theme.getRes()) - 3 then break end
            theme.gset(3, y, theme.pad(line:gsub("§.", ""), select(1, theme.getRes()) - 5), C.text, C.bg)
            y = y + 1
        end
    end

    theme.drawFooter({{"B", "Back"}})
end

while true do
    draw()

    local _, _, char, code = event.pull(config.gui_refresh)

    if char == string.byte("q") or char == string.byte("Q") then
        break
    elseif char == string.byte("r") or char == string.byte("R") then
        core.scan()
    elseif char == string.byte("s") or char == string.byte("S") then
        showSensor()
        while true do
            local _, _, c = event.pull()
            if c == string.byte("b") or c == string.byte("B") then
                break
            elseif c == string.byte("q") or c == string.byte("Q") then
                os.exit()
            end
        end
    end
end

if gpu then
    gpu.setBackground(theme.C.bg)
    gpu.setForeground(theme.C.text)
    gpu.fill(1, 1, select(1, theme.getRes()), select(2, theme.getRes()), " ")
end
