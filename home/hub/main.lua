-- ============================================
-- MAIN.LUA - Точка входа HUB
-- ============================================

local term = require("term")
local event = require("event")
local os = require("os")
local filesystem = require("filesystem")

-- ============================================
-- ПРОВЕРКА НАЛИЧИЯ МОДУЛЕЙ
-- ============================================

local function checkModules()
    local modules = {"registry", "setup", "logger"}
    for _, mod in ipairs(modules) do
        local path = "/home/hub/" .. mod .. ".lua"
        if not filesystem.exists(path) then
            print("❌ Ошибка: файл " .. path .. " не найден!")
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

local config = require("config")
local registry = require("registry")
local setup = require("setup")
local logger = require("logger")

-- ============================================
-- ГЛАВНЫЙ ЭКРАН
-- ============================================

function drawMainScreen()
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║              " .. config.hubName .. " v" .. config.version .. "                      ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    
    local eohs = registry.getAll()
    print("📋 ЗАРЕГИСТРИРОВАННЫЕ EOH:")
    print("")
    
    if #eohs == 0 then
        print("  ⚠️ Нет зарегистрированных EOH. Нажмите S для настройки.")
    else
        for i, eoh in ipairs(eohs) do
            print("  " .. i .. ". " .. eoh.name)
        end
    end
    
    print("")
    print("════════════════════════════════════════════════════════════════")
    print("  [1-9] Настроить EOH    [S] Setup    [R] Обновить список")
    print("  [U] Обновить скрипт    [Q] Выход")
    print("════════════════════════════════════════════════════════════════")
    print("")
    print("Выберите опцию: ")
end

-- ============================================
-- НАСТРОЙКА EOH
-- ============================================

function configureEOH(index)
    local eoh = registry.getEOH(index)
    if not eoh then
        print("❌ EOH #" .. index .. " не найден")
        os.sleep(1)
        return
    end
    
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║           НАСТРОЙКА: " .. eoh.name .. "                        ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    
    local settings = eoh.settings
    print("📌 ПАРАМЕТРЫ:")
    print("  1. Режим: " .. (settings.mode == "power" and "⚡ POWER" or "🔧 PRODUCTION"))
    print("  2. Тир планеты: " .. settings.tier)
    print("  3. Astral Arrays: " .. (settings.useAA and "✅ ДА" or "❌ НЕТ"))
    print("  4. Оверклоки: " .. settings.overclocks)
    print("  5. Автоперезапуск: " .. (settings.autoRestart and "✅ ДА" or "❌ НЕТ"))
    print("  6. Погрешность: " .. (settings.tolerance * 100) .. "%")
    print("")
    print("  [1-6] Выбрать    [A/D] Изменить    [S] Сохранить    [B] Назад")
    print("")
    print("Выберите действие: ")
    
    -- Обработка ввода
    local field = 1
    while true do
        local _, _, key = event.pull("key_down")
        local char = string.char(key)
        
        if char >= "1" and char <= "6" then
            field = tonumber(char)
            print("✅ Выбрано поле " .. field)
        elseif char == "a" or char == "A" then
            if field == 1 then
                settings.mode = (settings.mode == "production") and "power" or "production"
            elseif field == 2 then
                settings.tier = math.min(9, settings.tier + 1)
            elseif field == 3 then
                settings.useAA = not settings.useAA
            elseif field == 4 then
                settings.overclocks = math.min(3, settings.overclocks + 1)
            elseif field == 5 then
                settings.autoRestart = not settings.autoRestart
            elseif field == 6 then
                settings.tolerance = math.min(0.05, settings.tolerance + 0.001)
            end
            print("✅ Изменено!")
        elseif char == "d" or char == "D" then
            if field == 1 then
                settings.mode = (settings.mode == "production") and "power" or "production"
            elseif field == 2 then
                settings.tier = math.max(1, settings.tier - 1)
            elseif field == 3 then
                settings.useAA = not settings.useAA
            elseif field == 4 then
                settings.overclocks = math.max(0, settings.overclocks - 1)
            elseif field == 5 then
                settings.autoRestart = not settings.autoRestart
            elseif field == 6 then
                settings.tolerance = math.max(0.001, settings.tolerance - 0.001)
            end
            print("✅ Изменено!")
        elseif char == "s" or char == "S" then
            registry.updateEOH(index, settings)
            print("✅ Настройки сохранены!")
            os.sleep(1)
            break
        elseif char == "b" or char == "B" then
            break
        end
    end
end

-- ============================================
-- ГЛАВНАЯ ФУНКЦИЯ
-- ============================================

function main()
    logger.init()
    registry.load()
    
    while true do
        drawMainScreen()
        local _, _, key = event.pull("key_down")
        local char = string.char(key)
        
        if char >= "1" and char <= "9" then
            configureEOH(tonumber(char))
        elseif char == "s" or char == "S" then
            setup.runSetup()
        elseif char == "r" or char == "R" then
            registry.load()
            print("✅ Registry перечитан")
            os.sleep(1)
        elseif char == "u" or char == "U" then
            print("🔄 Запуск обновления...")
            os.sleep(1)
            os.execute("lua /U.lua")
        elseif char == "q" or char == "Q" then
            logger.info("MAIN", "Выход из программы")
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
    print("  2. Файл /home/hub/logger.lua существует")
    print("  3. Файл /home/hub/registry.lua существует")
    print("  4. Файл /home/hub/setup.lua существует")
    print("")
    print("Программа остановлена через 10 секунд...")
    os.sleep(10)
end