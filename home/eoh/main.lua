-- ============================================================
-- EOH CONTROLLER - MAIN / PHASE 3
-- ============================================================

package.path = "/home/eoh/?.lua;" .. package.path

local event = require("event")
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

local VIEW = { DASHBOARD = 1, CALCULATION = 2, SENSOR = 3, LOGS = 4, FILL = 5 }

local ui = {
    view = VIEW.DASHBOARD,
    dirty = true,
    fullRedraw = true,
    lastPoll = -1,
    calculation = nil,
    fillResult = nil,
    fillTitle = nil
}

local function scan()
    core.scan()
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

local function calculate()
    ui.calculation = core.calculateFluidPlan(
        config.planet_tier,
        "production",
        config.use_astral_arrays,
        config.overclocks
    )
end

local function redraw()
    if ui.view == VIEW.DASHBOARD then
        gui.drawDashboard(dashboardData(), ui.fullRedraw)
    elseif ui.view == VIEW.CALCULATION then
        if not ui.calculation then calculate() end
        if ui.calculation then
            gui.drawCalculation(ui.calculation, ui.fullRedraw)
        end
    elseif ui.view == VIEW.SENSOR then
        local lines = core.getRawSensorLines() or {"Sensor unavailable"}
        gui.drawSensor(lines)
    elseif ui.view == VIEW.LOGS then
        gui.drawLogs(logger.getLines(18))
    elseif ui.view == VIEW.FILL then
        gui.drawFillTest(ui.fillResult, ui.fillTitle)
    end

    ui.dirty = false
    ui.fullRedraw = false
end

local function openCalculation()
    calculate()
    ui.view = VIEW.CALCULATION
    ui.dirty = true
    ui.fullRedraw = true
end

local function runFillTest()
    -- PHASE 3: ручной тест только после явного включения
    -- config.allow_fluid_transfer=true.
    -- По умолчанию тест не выполнит transfer.
    local fluid = "hydrogen"
    local result, detail = core.fillTest(fluid, config.fill_test_amount)

    if result then
        ui.fillResult = detail
    else
        ui.fillResult = {
            ok = false,
            error = detail
        }
    end

    ui.fillTitle = "Hydrogen / one buffer test"
    ui.view = VIEW.FILL
    ui.dirty = true
    ui.fullRedraw = true
end

local function onKey(char)
    if not char then return true end
    local c = string.char(char):lower()

    if c == "q" then return false end

    if c == "r" then
        scan()
        if ui.view == VIEW.CALCULATION then calculate() end
        return true
    end

    if c == "c" then openCalculation(); return true end
    if c == "s" then ui.view = VIEW.SENSOR; ui.dirty = true; ui.fullRedraw = true; return true end
    if c == "l" then ui.view = VIEW.LOGS; ui.dirty = true; ui.fullRedraw = true; return true end
    if c == "f" then runFillTest(); return true end

    if c == "b" then
        ui.view = VIEW.DASHBOARD
        ui.dirty = true
        ui.fullRedraw = true
        return true
    end

    return true
end

if config.auto_scan then scan() end
logger.info("MAIN", "EOH Controller started (Phase 3 / safe fluid test)")

while true do
    if ui.dirty then redraw() end

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
        if onKey(ev[3]) == false then break end
    end
end

logger.info("MAIN", "EOH Controller stopped")
