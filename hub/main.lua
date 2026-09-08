-- ============================================
-- MAIN.LUA - Точка входа HUB
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local term = require("term")
local computer = require("computer")
local filesystem = require("filesystem")
local os = require("os")
local input = require("input")

local function checkModules()
    local modules = {
        {name="config", path="/home/lib/config.lua"},
        {name="settings", path="/home/lib/settings.lua"},
        {name="registry", path="/home/hub/registry.lua"},
        {name="setup", path="/home/hub/setup.lua"},
        {name="input", path="/home/hub/input.lua"},
        {name="logger", path="/home/lib/logger.lua"},
        {name="eoh_core", path="/home/eoh/eoh_core.lua"},
        {name="gui", path="/home/hub/gui.lua"},
    }
    for _, mod in ipairs(modules) do
        if not filesystem.exists(mod.path) then
            print("Ошибка: файл " .. mod.path .. " не найден!")
            os.sleep(3)
            return false
        end
    end
    return true
end

if not checkModules() then return end

local config = require("config")
local registry = require("registry")
local setup = require("setup")
local loggerLib = require("logger")
local logger = loggerLib.new("/home/hub", "hub.log")
logger:init()
local core = require("eoh_core")
local gui = require("gui")
gui.setBuild(core.build)
gui.init()

local MAIN_REFRESH_INTERVAL = 10
local DETAIL_REFRESH_INTERVAL = 0.5

local function runtimeSignature(runtime)
    runtime = runtime or {}
    return table.concat({
        tostring(runtime.stage or "OFF"),
        tostring(runtime.progress or 0),
        tostring(runtime.maximum or 0),
        tostring(runtime.active),
        tostring(runtime.hasWork),
        tostring(runtime.workAllowed),
        tostring(runtime.message or ""),
        tostring(runtime.hydrogen or 0),
        tostring(runtime.helium or 0),
        tostring(runtime.plasma or 0),
    }, ":")
end

local function snapshotMain()
    local eohs = registry.getAll()
    local runtimes = {}
    for index, eoh in ipairs(eohs) do
        runtimes[index] = core.refreshRuntime(eoh.components, eoh.settings, true)
    end
    return eohs, runtimes
end

local function drawMainScreen(selected, force)
    local eohs, runtimes = snapshotMain()
    if force then gui.draw(eohs, selected, config.hubName .. " v" .. config.version, runtimes) end
    return eohs, runtimes
end

local configureEOH

local function showDetail(index)
    local eoh = registry.getEOH(index)
    if not eoh then return end

    local notice = nil
    local lastSignature = nil
    local nextRefresh = 0

    while true do
        eoh = registry.getEOH(index) or eoh
        local now = computer.uptime()
        local runtime
        if now >= nextRefresh then
            runtime = core.refreshRuntime(eoh.components, eoh.settings, true)
            nextRefresh = now + DETAIL_REFRESH_INTERVAL
        else
            runtime = core.getRuntimeState(eoh.components, eoh.settings)
        end

        local signature = runtimeSignature(runtime) .. ":" .. tostring(notice or "")
        if signature ~= lastSignature then
            gui.drawDetail(eoh, notice, runtime)
            lastSignature = signature
        end
        notice = nil

        local key = input.wait(DETAIL_REFRESH_INTERVAL)
        if not key then
            core.tickConfiguredCycles()
        else
            if input.is(key, "enter") then
                configureEOH(index)
                lastSignature = nil

            elseif input.is(key, "f1") then
                setup.runSetup()
                lastSignature = nil

            elseif input.is(key, "f3") then
                registry.load()
                eoh = registry.getEOH(index) or eoh
                core.refreshRuntime(eoh.components, eoh.settings, true)
                lastSignature = nil

            elseif input.is(key, "r") then
                local started, message = core.startConfiguredCycle(eoh.components, eoh.settings or {})
                notice = started
                    and "RUN: recipe cycle started"
                    or "RUN BLOCKED: " .. tostring(message)
                lastSignature = nil

            elseif input.is(key, "back") then
                return
            end
        end
    end
end

configureEOH = function(index)
    local eoh = registry.getEOH(index)
    if not eoh then
        print("EOH #" .. tostring(index) .. " не найден")
        os.sleep(1)
        return
    end

    local settings = {}
    for key, value in pairs(eoh.settings or {}) do settings[key] = value end
    local defaults = {
        mode="production", tier=3, planet=nil, useAA=false,
        overclocks=0, autoRestart=true, tolerance=0.001
    }
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = value end
    end

    local field = 1

    local function drawSettings()
        gui.clear()
        print("EOH SETTINGS: " .. tostring(eoh.name))
        print("")
        local modeName = settings.mode == "power" and "DEEP DARK"
            or settings.mode == "aa" and "PRODUCTION + AA"
            or "PRODUCTION"
        local values = {
            "Mode: " .. modeName,
            "Planet tier: T" .. tostring(settings.tier),
            "Planet: " .. tostring(settings.planet or "-"),
            "Astral Arrays: " .. (settings.useAA and "ON" or "OFF"),
            "Overclocks: " .. tostring(settings.overclocks),
            "Auto restart: " .. (settings.autoRestart and "ON" or "OFF"),
            "Tolerance: " .. tostring(settings.tolerance * 100) .. "%"
        }
        for i, value in ipairs(values) do
            print((i == field and "> " or "  ") .. i .. ". " .. value)
        end
        print("")
        print("UP/DOWN Select  LEFT/RIGHT Change")
        print("ENTER Save  R Run  B Backspace")
    end

    local function change(delta)
        if field == 1 then
            local modes = {"production", "power"}
            local current = settings.mode == "power" and 2 or 1
            settings.mode = modes[((current - 1 + delta) % #modes) + 1]
        elseif field == 2 then
            settings.tier = math.max(1, math.min(9, settings.tier + delta))
        elseif field == 3 then
            local recipes = eoh and eoh.settings and eoh.settings.planet
            local planets = {"Overworld", "Mars", "Ceres", "Io", "Titan", "Proteus", "Pluto", "Vega B", "Deep Dark"}
            local current = 1
            for i, planet in ipairs(planets) do if settings.planet == planet then current = i end end
            settings.planet = planets[((current - 1 + delta) % #planets) + 1]
            settings.tier = current
        elseif field == 4 then
            settings.useAA = not settings.useAA
        elseif field == 5 then
            settings.overclocks = math.max(0, math.min(3, settings.overclocks + delta))
        elseif field == 6 then
            settings.autoRestart = not settings.autoRestart
        elseif field == 7 then
            settings.tolerance = math.max(0.001, math.min(0.05, settings.tolerance + delta * 0.001))
        end
    end

    drawSettings()
    while true do
        local key = input.wait(nil)
        if input.is(key, "up") then
            field = math.max(1, field - 1)
        elseif input.is(key, "down") then
            field = math.min(7, field + 1)
        elseif input.is(key, "left") then
            change(-1)
        elseif input.is(key, "right") then
            change(1)
        elseif input.is(key, "enter") then
            local ok, err = registry.updateEOH(index, settings)
            if not ok then
                print("Не удалось сохранить: " .. tostring(err))
                os.sleep(2)
            else
                break
            end
        elseif input.is(key, "r") then
            local ok, err = registry.updateEOH(index, settings)
            if not ok then
                print("Не удалось сохранить: " .. tostring(err))
                os.sleep(2)
            else
                core.startConfiguredCycle(eoh.components, settings)
                break
            end
        elseif input.is(key, "back") then
            break
        end
        drawSettings()
    end
end

local function confirmDelete(index)
    local eoh = registry.getEOH(index)
    if not eoh then return false end
    gui.drawConfirmDelete(eoh)
    while true do
        local key = input.wait(nil)
        if input.is(key, "enter") then return true end
        if input.is(key, "back") then return false end
    end
end

local function deleteSelected(index)
    local eoh = registry.getEOH(index)
    if not eoh or not confirmDelete(index) then return false end

    -- Stop the worker before removing its persistent record.
    core.stopCycle(eoh.components)

    local name = eoh.name
    local ok, err = registry.removeEOH(index)
    if not ok then
        logger:error("MAIN", "Failed to delete EOH #" .. tostring(index) .. ": " .. tostring(err))
        return false
    end

    core.dropContext(eoh.components)
    logger:info("MAIN", "Deleted EOH #" .. tostring(index) .. " (" .. tostring(name) .. ")")
    return true
end

function main()
    registry.load()
    local selected = 1
    local nextMainRefresh = 0

    -- Start configured AUTO cycles once after loading the database.
    for _, eoh in ipairs(registry.getAll()) do
        local settings = eoh.settings or {}
        if settings.autoRestart ~= false then
            core.startConfiguredCycle(eoh.components, settings)
        end
    end

    while true do
        core.tickConfiguredCycles()
        local now = computer.uptime()
        if now >= nextMainRefresh then
            local eohs, runtimes = snapshotMain()
            selected = math.max(1, math.min(selected, math.max(1, #eohs)))
            gui.draw(eohs, selected, config.hubName .. " v" .. config.version, runtimes)
            nextMainRefresh = now + MAIN_REFRESH_INTERVAL
        end

        local key = input.wait(0.5)
        if key then
            local eohs = registry.getAll()

            if input.is(key, "up") then
                selected = math.max(1, selected - 1)
                local current, runtimes = snapshotMain()
                gui.draw(current, selected, config.hubName .. " v" .. config.version, runtimes)

            elseif input.is(key, "down") then
                selected = math.min(math.max(1, #eohs), selected + 1)
                local current, runtimes = snapshotMain()
                gui.draw(current, selected, config.hubName .. " v" .. config.version, runtimes)

            elseif input.is(key, "enter") then
                if eohs[selected] then showDetail(selected) end
                nextMainRefresh = 0

            elseif input.is(key, "f1") then
                setup.runSetup()
                registry.load()
                nextMainRefresh = 0

            elseif input.is(key, "delete") then
                if eohs[selected] and deleteSelected(selected) then
                    selected = math.max(1, math.min(selected, #registry.getAll()))
                end
                nextMainRefresh = 0

            elseif input.is(key, "f3") then
                registry.load()
                nextMainRefresh = 0

            elseif input.is(key, "q") then
                logger:info("MAIN", "Выход из программы")
                break
            end
        end
    end
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    term.clear()
    print("============================================")
    print("КРИТИЧЕСКАЯ ОШИБКА")
    print("============================================")
    print("")
    print(tostring(err))
    print("")
    print("Проверьте установку файлов /home/hub/ и /home/eoh/")
    print("Программа остановлена через 10 секунд...")
    os.sleep(10)
end
