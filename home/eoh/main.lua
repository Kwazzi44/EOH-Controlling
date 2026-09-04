-- ============================================
-- MAIN.LUA - Точка входа EOH Controller
-- ============================================

local term = require("term")
local gui = require("gui")
local logger = require("logger")
local settings = require("settings")
local core = require("eoh_core")

local function main()
    logger.init()
    settings.load()
    logger.info("MAIN", "Запуск EOH Controller v1.0")
    
    -- Автоматический поиск компонентов
    core.scanComponents()
    
    -- Запуск GUI (если есть файл gui.lua)
    if gui.run then
        gui.run()
    else
        -- Простой режим без GUI
        print("EOH Controller запущен")
        print("Нажмите:")
        print("  1 - Production Mode")
        print("  2 - Power Mode")
        print("  Q - Выход")
        
        while true do
            local input = io.read()
            if input == "1" then
                core.runProductionMode(
                    settings.get("tier"),
                    settings.get("useAA"),
                    settings.get("overclocks"),
                    settings.get("autoRestart")
                )
            elseif input == "2" then
                core.runPowerMode()
            elseif input == "q" or input == "Q" then
                break
            end
        end
    end
end

local ok, err = pcall(main)
if not ok then
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║                    КРИТИЧЕСКАЯ ОШИБКА                        ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    print("❌ " .. tostring(err))
    print("")
    print("📖 Проверьте файлы в /home/eoh/ и подключение компонентов.")
    print("")
    print("Программа остановлена.")
    os.sleep(10)
end