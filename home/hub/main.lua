-- ============================================
-- MAIN.LUA - Точка входа HUB
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local term = require("term")
local event = require("event")
local keyboard = require("keyboard")
local computer = require("computer")
local os = require("os")
local filesystem = require("filesystem")

-- ============================================
-- ПРОВЕРКА НАЛИЧИЯ МОДУЛЕЙ
-- ============================================

local function checkModules()
    local modules = {
        {name="registry", path="/home/hub/registry.lua"},
        {name="setup", path="/home/hub/setup.lua"},
        {name="logger", path="/home/lib/logger.lua"},
        {name="eoh_core", path="/home/eoh/eoh_core.lua"},
        {name="gui", path="/home/hub/gui.lua"},
    }
    for _, mod in ipairs(modules) do
        if not filesystem.exists(mod.path) then
            print("❌ Ошибка: файл " .. mod.path .. " не найден!")
            print("Убедитесь, что все файлы установлены.")
            os.sleep(3)
            return false
        end
    end
    return true
end

-- ============================================
-- ЗАГРУЗКА МОДУЛЕЙ
-- ============================================

if not checkModules() then
    return
end

local config = dofile("/home/hub/config.lua")
local registry = require("registry")
local setup = require("setup")
local loggerLib = require("lib.logger")
local logger = loggerLib.new("/home/hub", "hub.log")
logger:init()
local core = require("eoh_core")
local gui = require("gui")
gui.init()

local function keyToChar(key)
    if type(key) == "number" and key >= 0 and key <= 255 then
        return string.char(key)
    end
    return ""
end

local function isLetter(charCode, keyCode, letter, scanCode)
    return charCode == string.byte(letter)
        or charCode == string.byte(string.upper(letter))
        or keyCode == scanCode
end

local function isKey(keyCode, namedKey, fallback)
    return keyCode == namedKey or keyCode == fallback
end

local function isRunKey(charCode, keyCode)
    return charCode == string.byte("r") or charCode == string.byte("R")
        or keyCode == 19
end

-- ============================================
-- ГЛАВНЫЙ ЭКРАН
-- ============================================

function drawMainScreen(selected)
    local eohs = registry.getAll()
    local runtimes = {}
    for index, eoh in ipairs(eohs) do
        runtimes[index] = core.getRuntimeState(eoh.components)
    end
    gui.draw(eohs, selected or 1, config.hubName .. " v" .. config.version,
        runtimes)
end

-- ============================================
-- НАСТРОЙКА EOH
-- ============================================

local function showDetail(index)
        local eoh = registry.getEOH(index)
        if not eoh then return end
        local notice
        while true do
            gui.drawDetail(eoh, notice, core.getRuntimeState(eoh.components))
            notice = nil
            local _, _, charCode, keyCode = event.pull(0.5, "key_down")
            local char = keyToChar(charCode)
            if keyCode == keyboard.keys.enter or keyCode == keyboard.keys.numpadenter
                or keyCode == 28 then
                configureEOH(index)
            elseif isRunKey(charCode, keyCode) then
                local started, message = core.startConfiguredCycle(
                    eoh.components, eoh.settings or {})
                notice = started and "RUN: recipe cycle started"
                    or "RUN BLOCKED: " .. tostring(message)
            elseif isKey(keyCode, keyboard.keys.f1, 59) then
                setup.runSetup()
            elseif isLetter(charCode, keyCode, "b", 48)
                or keyCode == keyboard.keys.escape or keyCode == 1
                or keyCode == 14 then
                return
            end
            eoh = registry.getEOH(index) or eoh
        end
end

function configureEOH(index)
    local eoh = registry.getEOH(index)
    if not eoh then
        print("❌ EOH #" .. index .. " не найден")
        os.sleep(1)
        return
    end
    
    local settings = eoh.settings or {}
    local defaults = {
        mode = "production",
        tier = 3,
        useAA = false,
        overclocks = 0,
        autoRestart = true,
        tolerance = 0.001,
    }
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = value end
    end
    if settings.mode ~= "aa" then settings.useAA = false end
    eoh.settings = settings
    core.setComponents(eoh.components)
    -- Ignore the opening key's repeat without waiting for a key_up event.
    -- key_up can be lost when the UI changes, which used to freeze this view.
    local inputEnabledAt = computer.uptime() + 0.75
    local field = 1
    local function drawSettings()
        term.clear()
        print("EOH SETTINGS: " .. tostring(eoh.name))
        print("")
        local modeName = settings.mode == "power" and "DEEP DARK"
            or settings.mode == "aa" and "PRODUCTION + AA" or "PRODUCTION"
        local values = {
            "Mode: " .. modeName,
            "Planet tier: " .. tostring(settings.tier),
            "Astral Arrays: " .. (settings.mode == "aa" and "ON" or "OFF"),
            "Overclocks: " .. tostring(settings.overclocks),
            "Auto restart: " .. (settings.autoRestart and "ON" or "OFF"),
            "Tolerance: " .. tostring(settings.tolerance * 100) .. "%",
        }
        for i, value in ipairs(values) do
            print((i == field and "> " or "  ") .. i .. ". " .. value)
        end
        print("")
        print("UP/DOWN Select  LEFT/RIGHT Change")
        print("ENTER Save  R Run  B/ESC Back")
    end
    local function change(delta)
        if field == 1 then
            local modes = {"production", "aa", "power"}
            local current = 1
            for i, mode in ipairs(modes) do
                if settings.mode == mode then current = i end
            end
            settings.mode = modes[((current - 1 + delta) % #modes) + 1]
            settings.useAA = settings.mode == "aa"
        elseif field == 2 then
            settings.tier = math.max(1, math.min(9, settings.tier + delta))
        elseif field == 3 then
            settings.useAA = not settings.useAA
            settings.mode = settings.useAA and "aa" or "production"
        elseif field == 4 then
            settings.overclocks = math.max(0, math.min(3, settings.overclocks + delta))
        elseif field == 5 then
            settings.autoRestart = not settings.autoRestart
        elseif field == 6 then
            settings.tolerance = math.max(0.001, math.min(0.05, settings.tolerance + delta * 0.001))
        end
    end
    drawSettings()
    while true do
        local _, _, charCode, keyCode = event.pull("key_down")
        local char = keyToChar(charCode)
        if keyCode == keyboard.keys.up then
            field = math.max(1, field - 1)
        elseif keyCode == keyboard.keys.down then
            field = math.min(6, field + 1)
        elseif keyCode == keyboard.keys.left then
            change(-1)
        elseif keyCode == keyboard.keys.right then
            change(1)
        elseif keyCode == keyboard.keys.enter or keyCode == keyboard.keys.numpadenter
            or keyCode == 28
            or char == "s" or char == "S" then
            if computer.uptime() >= inputEnabledAt then
                registry.updateEOH(index, settings)
                break
            end
        elseif char == "r" or char == "R" then
            registry.updateEOH(index, settings)
            core.startConfiguredCycle(eoh.components, settings)
            break
        elseif isLetter(charCode, keyCode, "b", 48)
            or keyCode == keyboard.keys.escape or keyCode == 1
            or keyCode == 14 then
            break
        elseif char == "s" or char == "S" then
            break
        end
        drawSettings()
    end
end

-- ============================================
-- ГЛАВНАЯ ФУНКЦИЯ
-- ============================================

function main()
    registry.load()
    -- AUTO must survive a computer/HUB restart.  Setup also calls this helper
    -- after rebinding hardware; the core rejects a duplicate runner.
    for _, eoh in ipairs(registry.getAll()) do
        local settings = eoh.settings or {}
        if settings.autoRestart ~= false then
            core.startConfiguredCycle(eoh.components, settings)
        end
    end
    local selected = 1
    while true do
        local eohs = registry.getAll()
        if selected > math.max(1, #eohs) then selected = math.max(1, #eohs) end
        drawMainScreen(selected)
        local _, _, charCode, keyCode = event.pull(0.5, "key_down")
        local char = keyToChar(charCode)
        if keyCode == keyboard.keys.up then
            selected = math.max(1, selected - 1)
        elseif keyCode == keyboard.keys.down then
            selected = math.min(math.max(1, #eohs), selected + 1)
        elseif keyCode == keyboard.keys.enter or keyCode == keyboard.keys.numpadenter
            or keyCode == 28 then
            if eohs[selected] then showDetail(selected) end
        elseif char >= "1" and char <= "9" then
            configureEOH(tonumber(char))
        elseif isKey(keyCode, keyboard.keys.f1, 59) then
            setup.runSetup()
        elseif isKey(keyCode, keyboard.keys.delete, 211) then
            if #registry.getAll() > 0 then
                registry.removeEOH(selected)
                selected = math.max(1, math.min(selected, #registry.getAll()))
            end
        elseif isKey(keyCode, keyboard.keys.f3, 61) then
            registry.load()
        elseif char == "q" or char == "Q" then
            logger:info("MAIN", "Выход из программы")
            break
        end
    end
end

-- ============================================
-- ЗАПУСК С ОБРАБОТКОЙ ОШИБОК
-- ============================================

local ok, err = pcall(main)
if not ok then
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║                    КРИТИЧЕСКАЯ ОШИБКА                        ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    print("❌ " .. tostring(err))
    print("")
    print("📖 Проверьте:")
    print("  1. Все файлы установлены в /home/hub/")
    print("  2. Файл /home/lib/logger.lua существует")
    print("  3. Файл /home/hub/registry.lua существует")
    print("  4. Файл /home/hub/setup.lua существует")
    print("  5. Файл /home/eoh/eoh_core.lua существует")
    print("")
    print("Программа остановлена через 10 секунд...")
    os.sleep(10)
end
