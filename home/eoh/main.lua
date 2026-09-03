-- ============================================================
-- EOH CONTROLLER - MAIN / PHASE 2
-- ============================================================

package.path = "/home/eoh/?.lua;" .. package.path

local event = require("event")
local os = require("os")
local computer = require("computer")

local config = require("config")
local logger = require("logger")
local core = require("eoh_core")
local gui = require("gui")

logger.init()
logger.load()

local okGui, guiErr = gui.init()
if not okGui then
    io.write("EOH Controller: " .. tostring(guiErr) .. "\n")
    return
end

local VIEW = {
    DASHBOARD = 1,
    CALCULATION = 2,
    SENSOR = 3,
    LOGS = 4
}

local ui = {
    view = VIEW.DASHBOARD,
    dirty = true,
    fullRedraw = true,
    lastPoll = -1,
    calculation = nil,
    lastError = nil
}

local function scan()
    local ok, err = core.scan()
    ui.lastError = ok and nil or err
    ui.dirty = true
    ui.fullRedraw = true
end

local function dashboardData()
    return {
        controller = core.getController(),
        transposers = core.getTransposers(),
        status = core.getStatus(),
        fluids = core.getFluids(),
        sensor = core.getSensorData() or {
            astralArrays = 0,
            activeAstralArrays = 0,
            successChance = nil,
            totalOverclocks = 0
        }
    }
end

local function redraw()
    if ui.view == VIEW.DASHBOARD then
        gui.drawDashboard(dashboardData(), ui.fullRedraw)
    elseif ui.view == VIEW.CALCULATION then
        if not ui.calculation then
            ui.calculation = core.calculateFluidPlan(
                config.planet_tier,
                "production",
                config.use_astral_arrays,
                config.overclocks
            )
        end
        if ui.calculation then
            gui.drawCalculation(ui.calculation, ui.fullRedraw)
        end
    elseif ui.view == VIEW.SENSOR then
        local lines = core.getRawSensorLines() or {"Sensor unavailable"}
        gui.drawSensor(lines)
    elseif ui.view == VIEW.LOGS then
        gui.drawLogs(logger.getLines(18))
    end

    ui.dirty = false
    ui.fullRedraw = false
end

local function openCalculation()
    ui.view = VIEW.CALCULATION
    ui.calculation = core.calculateFluidPlan(
        config.planet_tier,
        "production",
        config.use_astral_arrays,
        config.overclocks
    )
    ui.dirty = true
    ui.fullRedraw = true
end

local function onKey(char)
    if not char then return end

    local c = string.char(char):lower()

    if c == "q" then
        return false
    end

    if c == "r" then
        scan()
        if ui.view == VIEW.CALCULATION then
            ui.calculation = core.calculateFluidPlan(
                config.planet_tier,
                "production",
                config.use_astral_arrays,
                config.overclocks
            )
        end
        return true
    end

    if c == "c" then
        openCalculation()
        return true
    end

    if c == "s" then
        ui.view = VIEW.SENSOR
        ui.dirty = true
        ui.fullRedraw = true
        return true
    end

    if c == "l" then
        ui.view = VIEW.LOGS
        ui.dirty = true
        ui.fullRedraw = true
        return true
    end

    if c == "b" then
        ui.view = VIEW.DASHBOARD
        ui.dirty = true
        ui.fullRedraw = true
        return true
    end

    return true
end

if config.auto_scan then
    scan()
else
    ui.dirty = true
end

logger.info("MAIN", "EOH Controller started (Phase 2 / dry run)")

while true do
    if ui.dirty then
        redraw()
    end

    -- Обновляем данные без полного перерисовывания экрана.
    if ui.view == VIEW.DASHBOARD then
        local now = computer.uptime()
        if ui.lastPoll < 0 or now - ui.lastPoll >= config.poll_interval then
            ui.lastPoll = now
            ui.dirty = true
            ui.fullRedraw = false
        end
    end

    local ev = table.pack(event.pull(config.gui_refresh))

    if ev[1] == "key_down" then
        local keepRunning = onKey(ev[3])
        if keepRunning == false then
            break
        end
    end
end

logger.info("MAIN", "EOH Controller stopped")
