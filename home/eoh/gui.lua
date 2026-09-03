-- ============================================================
-- EOH CONTROLLER - GUI / PHASE 3
-- ============================================================

local component = require("component")
local theme = require("theme")
local config = require("config")

local gui = {}
local gpu
local W, H = 80, 25

local function C() return theme.C end

local function drawText(x, y, text, fg, bg)
    theme.gset(x, y, theme.pad(text, math.max(0, W - x)), fg, bg)
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

local function statusText(status)
    if status.active then return "ACTIVE" end
    if status.error then return "ERROR" end
    return "STOPPED"
end

function gui.init()
    if not component.isAvailable("gpu") then return false, "GPU not found" end
    gpu = component.gpu
    W, H = gpu.getResolution()
    theme.init(gpu)
    gui.clear()
    return true
end

function gui.clear() theme.clear() end

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
    end

    local y = 6
    local status = data.status
    local fluids = data.fluids
    local sensor = data.sensor
    local transposers = data.transposers

    drawText(3, y, "EOH", C().title, C().bg); y = y + 1
    drawText(3, y, "Controller:", C().dim, C().bg)
    drawText(20, y, data.controller and data.controller.name or "NOT FOUND", C().text, C().bg); y = y + 1
    drawText(3, y, "Progress:", C().dim, C().bg)
    drawText(20, y, string.format("%d / %d (%.1f%%)", status.progress, status.maxProgress, status.percent), C().text, C().bg); y = y + 1
    drawText(3, y, "Work allowed:", C().dim, C().bg)
    drawText(20, y, tostring(status.workAllowed), status.workAllowed and C().ok or C().warn, C().bg); y = y + 2

    drawText(3, y, "LIQUIDS IN EOH", C().title, C().bg); y = y + 1
    drawText(3, y, "Hydrogen:", C().dim, C().bg); drawText(22, y, fmtVolume(fluids.hydrogen), C().text, C().bg); y = y + 1
    drawText(3, y, "Helium:", C().dim, C().bg); drawText(22, y, fmtVolume(fluids.helium), C().text, C().bg); y = y + 1
    drawText(3, y, "Raw Stellar Plasma:", C().dim, C().bg); drawText(22, y, fmtVolume(fluids.plasma), C().text, C().bg); y = y + 2

    drawText(3, y, "EOH SENSOR", C().title, C().bg); y = y + 1
    drawText(3, y, "AA:", C().dim, C().bg); drawText(20, y, tostring(sensor.astralArrays), C().text, C().bg)
    drawText(31, y, "Active:", C().dim, C().bg); drawText(40, y, tostring(sensor.activeAstralArrays), C().text, C().bg); y = y + 1
    drawText(3, y, "Success:", C().dim, C().bg); drawText(20, y, sensor.successChance and string.format("%.2f%%", sensor.successChance) or "n/a", C().text, C().bg); y = y + 1
    drawText(3, y, "Overclocks:", C().dim, C().bg); drawText(20, y, tostring(sensor.totalOverclocks), C().text, C().bg); y = y + 2

    drawText(3, y, "TRANSPOSERS", C().title, C().bg); y = y + 1
    drawText(3, y, "Found:", C().dim, C().bg); drawText(20, y, tostring(#transposers), #transposers >= 2 and C().ok or C().warn, C().bg); y = y + 1
    for i, t in ipairs(transposers) do
        drawText(3, y, string.format("#%d  source side %d -> EOH side %d", i, t.fluidSide, t.eohSide), C().text, C().bg)
        y = y + 1
    end

    drawText(3, y + 1, config.allow_fluid_transfer and "LIVE MODE ENABLED" or "DRY RUN: fluid transfer disabled", config.allow_fluid_transfer and C().warn or C().partial, C().bg)

    for row = y + 2, H - 4 do
        theme.gfill(2, row, W - 2, 1, " ", C().text, C().bg)
    end

    theme.drawFooter({{"R", "Rescan"}, {"C", "Calculate"}, {"F", "Fill test"}, {"S", "Sensor"}, {"L", "Logs"}, {"Q", "Quit"}})
end

function gui.drawCalculation(plan, full)
    if full then
        gui.clear()
        gui.drawFrame("EOH Calculation", plan.recipe.display or "PLAN")
    end

    local y = 6
    local r = plan.recipe

    drawText(3, y, "RECIPE", C().title, C().bg); y = y + 1
    drawText(3, y, "Planet:", C().dim, C().bg); drawText(20, y, r.planet, C().text, C().bg); y = y + 1
    drawText(3, y, "Tier:", C().dim, C().bg); drawText(20, y, tostring(r.tier), C().text, C().bg); y = y + 1
    drawText(3, y, "Input mode:", C().dim, C().bg); drawText(20, y, r.inputMode, C().text, C().bg); y = y + 1
    drawText(3, y, "AA:", C().dim, C().bg); drawText(20, y, tostring(r.useAA), C().text, C().bg)
    drawText(31, y, "OC:", C().dim, C().bg); drawText(38, y, tostring(r.overclocks), C().text, C().bg); y = y + 2

    drawText(3, y, "CURRENT / RECIPE TOTAL", C().title, C().bg); y = y + 1
    drawText(3, y, "Hydrogen:", C().dim, C().bg); drawText(22, y, fmtVolume(plan.current.hydrogen), C().text, C().bg); drawText(38, y, "/ " .. fmtVolume(plan.required.hydrogen), C().dim, C().bg); y = y + 1
    drawText(3, y, "Helium:", C().dim, C().bg); drawText(22, y, fmtVolume(plan.current.helium), C().text, C().bg); drawText(38, y, "/ " .. fmtVolume(plan.required.helium), C().dim, C().bg); y = y + 1
    drawText(3, y, "Plasma:", C().dim, C().bg); drawText(22, y, fmtVolume(plan.current.plasma), C().text, C().bg); drawText(38, y, "/ " .. fmtVolume(plan.required.plasma), C().dim, C().bg); y = y + 2

    drawText(3, y, "NEXT SAFE FILL STEP", C().title, C().bg); y = y + 1
    for _, key in ipairs({"hydrogen", "helium", "plasma"}) do
        local missing = plan.missing[key]
        if missing > 0 then
            drawText(3, y, key .. ":", C().dim, C().bg)
            drawText(22, y, fmtVolume(math.min(missing, config.fluid_control.max_transfer_per_call)), C().warn, C().bg)
        else
            drawText(3, y, key .. ":", C().dim, C().bg)
            drawText(22, y, "no fill", C().ok, C().bg)
        end
        y = y + 1
    end

    drawText(3, y, "SOURCE", C().title, C().bg); y = y + 1
    local sourceRows = {"hydrogen", "helium", "plasma"}
    for _, key in ipairs(sourceRows) do
        local total = 0
        for _, t in ipairs(plan.source.transposers) do total = total + (t[key].amount or 0) end
        drawText(3, y, key .. ":", C().dim, C().bg)
        drawText(22, y, fmtVolume(total), total > 0 and C().ok or C().error, C().bg)
        y = y + 1
    end

    drawText(3, y + 1, "No automatic continuous filling in Phase 3 yet.", C().partial, C().bg)
    theme.drawFooter({{"B", "Back"}, {"R", "Refresh"}, {"Q", "Quit"}})
end

function gui.drawFillTest(result, title)
    gui.clear()
    gui.drawFrame("Fluid Test", title or "RESULT")

    local y = 6
    if not result then
        drawText(3, y, "No result", C().error, C().bg)
    elseif not result.ok then
        drawText(3, y, "TRANSFER FAILED", C().error, C().bg); y = y + 2
        drawText(3, y, tostring(result.error or result), C().warn, C().bg)
    else
        drawText(3, y, "TRANSFER OK", C().ok, C().bg); y = y + 2
        drawText(3, y, "Requested:", C().dim, C().bg); drawText(22, y, tostring(result.requested) .. " L", C().text, C().bg); y = y + 1
        drawText(3, y, "Reported moved:", C().dim, C().bg); drawText(22, y, tostring(result.moved) .. " L", C().text, C().bg); y = y + 1
        drawText(3, y, "EOH before:", C().dim, C().bg); drawText(22, y, tostring(result.before) .. " L", C().text, C().bg); y = y + 1
        drawText(3, y, "EOH after:", C().dim, C().bg); drawText(22, y, tostring(result.after) .. " L", C().text, C().bg); y = y + 1
        drawText(3, y, "Observed delta:", C().dim, C().bg); drawText(22, y, tostring(result.observedDelta) .. " L", C().text, C().bg); y = y + 1
    end

    drawText(3, y + 2, "Press B to return.", C().partial, C().bg)
    theme.drawFooter({{"B", "Back"}, {"Q", "Quit"}})
end

function gui.drawSensor(lines)
    gui.clear(); gui.drawFrame("EOH Sensor", "READ ONLY")
    local row = 6
    for _, line in ipairs(lines or {}) do
        if row > H - 4 then break end
        drawText(3, row, tostring(line):gsub("§.", ""), C().text, C().bg); row = row + 1
    end
    theme.drawFooter({{"B", "Back"}, {"Q", "Quit"}})
end

function gui.drawLogs(lines)
    gui.clear(); gui.drawFrame("EOH Logs", "LAST RECORDS")
    local row = 6
    for _, line in ipairs(lines or {}) do
        if row > H - 4 then break end
        drawText(2, row, line, C().text, C().bg); row = row + 1
    end
    theme.drawFooter({{"B", "Back"}, {"Q", "Quit"}})
end

return gui
