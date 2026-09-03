-- ============================================================
-- EOH CONTROLLER - GUI / PHASE 2
-- ============================================================
-- GUI построен по той же идее, что Planet Monitor:
-- статическая рамка рисуется один раз, динамические строки
-- перерисовываются без полного очистителя экрана.
-- ============================================================

local component = require("component")
local theme = require("theme")

local gui = {}
local gpu = nil
local W, H = 80, 25

local function C()
    return theme.C
end

local function drawText(x, y, text, fg, bg)
    theme.gset(x, y, theme.pad(text, W - x), fg, bg)
end

local function fmtVolume(value)
    value = tonumber(value) or 0
    local abs = math.abs(value)

    if abs >= 1e12 then return string.format("%.3f T L", value / 1e12) end
    if abs >= 1e9 then return string.format("%.3f B L", value / 1e9) end
    if abs >= 1e6 then return string.format("%.3f M L", value / 1e6) end
    if abs >= 1e3 then return string.format("%.3f k L", value / 1e3) end
    return string.format("%.0f L", value)
end

local function fmtNumber(value)
    local n = tonumber(value) or 0
    return string.format("%.0f", n)
end

local function statusText(status)
    if status.active then return "ACTIVE" end
    if status.error then return "ERROR" end
    return "STOPPED"
end

function gui.init()
    if not component.isAvailable("gpu") then
        return false, "GPU not found"
    end

    gpu = component.gpu
    W, H = gpu.getResolution()
    theme.init(gpu)
    gui.clear()
    return true
end

function gui.clear()
    theme.clear()
end

function gui.drawFrame(title, subtitle)
    theme.drawHeader(title, subtitle)

    for y = 5, H - 3 do
        theme.gset(1, y, "|", C().border, C().bg)
        theme.gset(W, y, "|", C().border, C().bg)
    end
end

function gui.drawDashboard(data, full)
    if full then
        gui.clear()
        gui.drawFrame("EOH Controller", statusText(data.status))
    else
        theme.gset(3, 3, theme.pad("STATUS: " .. statusText(data.status), W - 5), C().dim, C().bg)
    end

    local y = 6
    local controller = data.controller
    local status = data.status
    local fluids = data.fluids
    local sensor = data.sensor
    local transposers = data.transposers

    drawText(3, y, "EOH", C().title, C().bg); y = y + 1
    drawText(3, y, "Controller:", C().dim, C().bg)
    drawText(20, y, controller and controller.name or "NOT FOUND", C().text, C().bg); y = y + 1
    drawText(3, y, "Progress:", C().dim, C().bg)
    drawText(20, y, string.format("%s / %s (%.1f%%)", fmtNumber(status.progress), fmtNumber(status.maxProgress), status.percent), C().text, C().bg); y = y + 1
    drawText(3, y, "Work allowed:", C().dim, C().bg)
    drawText(20, y, tostring(status.workAllowed), status.workAllowed and C().ok or C().warn, C().bg); y = y + 2

    drawText(3, y, "LIQUIDS IN EOH", C().title, C().bg); y = y + 1
    drawText(3, y, "Hydrogen:", C().dim, C().bg)
    drawText(22, y, fmtVolume(fluids.hydrogen), C().text, C().bg); y = y + 1
    drawText(3, y, "Helium:", C().dim, C().bg)
    drawText(22, y, fmtVolume(fluids.helium), C().text, C().bg); y = y + 1
    drawText(3, y, "Raw Stellar Plasma:", C().dim, C().bg)
    drawText(22, y, fmtVolume(fluids.plasma), C().text, C().bg); y = y + 2

    drawText(3, y, "EOH SENSOR", C().title, C().bg); y = y + 1
    drawText(3, y, "AA:", C().dim, C().bg)
    drawText(20, y, tostring(sensor.astralArrays), C().text, C().bg)
    drawText(31, y, "Active:", C().dim, C().bg)
    drawText(40, y, tostring(sensor.activeAstralArrays), C().text, C().bg); y = y + 1
    drawText(3, y, "Success:", C().dim, C().bg)
    drawText(20, y, sensor.successChance and string.format("%.2f%%", sensor.successChance) or "n/a", C().text, C().bg); y = y + 1
    drawText(3, y, "Overclocks:", C().dim, C().bg)
    drawText(20, y, tostring(sensor.totalOverclocks), C().text, C().bg); y = y + 2

    drawText(3, y, "TRANSPOSERS", C().title, C().bg); y = y + 1
    drawText(3, y, "Found:", C().dim, C().bg)
    drawText(20, y, tostring(#transposers), #transposers >= 2 and C().ok or C().warn, C().bg); y = y + 1

    for i, t in ipairs(transposers) do
        if y <= H - 4 then
            drawText(3, y, string.format("#%d  source side %d -> EOH side %d", i, t.fluidSide, t.eohSide), C().text, C().bg)
            y = y + 1
        end
    end

    -- Очистка хвоста рабочей области без полного экрана.
    for row = y, H - 4 do
        theme.gfill(2, row, W - 2, 1, " ", C().text, C().bg)
    end

    theme.drawFooter({
        {"R", "Rescan"},
        {"C", "Calculate"},
        {"S", "Sensor"},
        {"Q", "Quit"}
    })
end

function gui.drawCalculation(plan, full)
    if full then
        gui.clear()
        gui.drawFrame("EOH Calculation", plan.recipe.display or "PLAN")
    end

    local y = 6
    local r = plan.recipe

    drawText(3, y, "RECIPE", C().title, C().bg); y = y + 1
    drawText(3, y, "Planet:", C().dim, C().bg)
    drawText(20, y, r.planet, C().text, C().bg); y = y + 1
    drawText(3, y, "Tier:", C().dim, C().bg)
    drawText(20, y, tostring(r.tier), C().text, C().bg); y = y + 1
    drawText(3, y, "Input mode:", C().dim, C().bg)
    drawText(20, y, r.inputMode, C().text, C().bg); y = y + 1
    drawText(3, y, "AA:", C().dim, C().bg)
    drawText(20, y, tostring(r.useAA), C().text, C().bg)
    drawText(31, y, "OC:", C().dim, C().bg)
    drawText(38, y, tostring(r.overclocks), C().text, C().bg); y = y + 2

    drawText(3, y, "FLUID PLAN", C().title, C().bg); y = y + 1

    local function row(label, key)
        drawText(3, y, label .. ":", C().dim, C().bg)
        drawText(22, y, fmtVolume(plan.required[key]), C().text, C().bg)
        drawText(38, y, "current", C().dim, C().bg)
        drawText(47, y, fmtVolume(plan.current[key]), C().text, C().bg)
        drawText(63, y, "missing", C().dim, C().bg)
        drawText(72, y, fmtVolume(plan.missing[key]), plan.missing[key] > 0 and C().warn or C().ok, C().bg)
        y = y + 1
    end

    row("Hydrogen", "hydrogen")
    row("Helium", "helium")
    row("Plasma", "plasma")
    y = y + 1

    drawText(3, y, "SOURCE CHECK", C().title, C().bg); y = y + 1
    drawText(3, y, plan.ready and "Source fluids: READY" or "Source fluids: NOT ENOUGH", plan.ready and C().ok or C().error, C().bg); y = y + 1

    for _, warning in ipairs(plan.warnings or {}) do
        if y <= H - 4 then
            drawText(3, y, "! " .. warning, C().warn, C().bg)
            y = y + 1
        end
    end

    if y <= H - 4 then
        drawText(3, y + 1, "DRY RUN: no fluid will be transferred in Phase 2.", C().partial, C().bg)
    end

    theme.drawFooter({{"B", "Back"}, {"R", "Refresh"}, {"Q", "Quit"}})
end

function gui.drawSensor(lines)
    gui.clear()
    gui.drawFrame("EOH Sensor", "READ ONLY")

    local row = 6
    for _, line in ipairs(lines or {}) do
        if row > H - 4 then break end
        drawText(3, row, tostring(line):gsub("§.", ""), C().text, C().bg)
        row = row + 1
    end

    theme.drawFooter({{"B", "Back"}, {"Q", "Quit"}})
end

function gui.drawLogs(lines)
    gui.clear()
    gui.drawFrame("EOH Logs", "LAST RECORDS")

    local row = 6
    for _, line in ipairs(lines or {}) do
        if row > H - 4 then break end
        drawText(2, row, line, C().text, C().bg)
        row = row + 1
    end

    theme.drawFooter({{"B", "Back"}, {"Q", "Quit"}})
end

return gui
