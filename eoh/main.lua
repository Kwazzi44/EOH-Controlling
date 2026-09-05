-- ============================================
-- MAIN.LUA - Точка входа EOH Controller
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local term = require("term")
local os = require("os")
local loggerLib = require("lib.logger")
local logger = loggerLib.new("/home/eoh", "eoh.log")
logger:init()
local settings = require("lib.settings")
local core = require("eoh_core")

local function main()
    settings.load()
    logger:info("MAIN", "Запуск EOH Controller v1.0")
    
    -- Автоматический поиск компонентов
    core.scanComponents()
    
        -- Текстовый режим используется без отдельного GUI-модуля.
        print("EOH Controller запущен")
        print("Нажмите:")
        print("  1 - Production Mode")
        print("  2 - Production Mode + Astral Arrays")
        print("  3 - Deep Dark Energy Mode")
        print("  Q - Выход")
        
        while true do
            local input = io.read()
            if input == "1" then
                core.runProductionMode(
                    settings.get("tier"),
                    false,
                    settings.get("overclocks"),
                    settings.get("autoRestart")
                )
            elseif input == "2" then
                core.runProductionMode(
                    settings.get("tier"),
                    true,
                    settings.get("overclocks"),
                    settings.get("autoRestart")
                )
            elseif input == "3" then
                core.runPowerMode()
            elseif input == "q" or input == "Q" then
                break
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