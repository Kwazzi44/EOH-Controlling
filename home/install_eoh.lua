-- ============================================
-- INSTALL_EOH.LUA - Установка EOH Controller
-- ============================================

local filesystem = require("filesystem")
local internet = require("internet")
local os = require("os")
local term = require("term")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"

-- ============================================
-- ФУНКЦИЯ СКАЧИВАНИЯ ФАЙЛА
-- ============================================

function downloadFile(url, path)
    local req = internet.request(url)
    if not req then
        return false, "Не удалось создать запрос"
    end
    
    local data = ""
    while true do
        local chunk = req.read()
        if not chunk then
            break
        end
        data = data .. chunk
    end
    
    if data == "" then
        return false, "Получен пустой файл"
    end
    
    local file = io.open(path, "w")
    if not file then
        return false, "Не удалось создать файл: " .. path
    end
    file:write(data)
    file:close()
    
    return true, "OK"
end

-- ============================================
-- ГЛАВНАЯ ФУНКЦИЯ
-- ============================================

function install()
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║              УСТАНОВКА EOH CONTROLLER                       ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    
    -- Проверка интернета
    print("🔍 Проверка подключения...")
    local test = internet.request("https://raw.githubusercontent.com")
    if not test then
        print("❌ Нет подключения к интернету!")
        print("Нажмите любую клавишу для выхода...")
        os.sleep(5)
        return
    end
    print("✅ Подключение есть")
    print("")
    
    -- Создаем папки
    print("📁 Создание папок...")
    local dirs = {
        "/home/eoh/",
        "/home/eoh/logs/",
        "/home/hub/",
        "/home/hub/logs/",
    }
    for _, dir in ipairs(dirs) do
        if not filesystem.exists(dir) then
            filesystem.makeDirectory(dir)
            print("  ✅ Создана: " .. dir)
        end
    end
    print("")
    
    -- Список файлов для скачивания
    local files = {
        "/home/eoh/config.lua",
        "/home/eoh/eoh_config.lua",
        "/home/eoh/eoh_core.lua",
        "/home/eoh/diagnose.lua",
        "/home/eoh/logger.lua",
        "/home/eoh/main.lua",
        "/home/eoh/recipes.lua",
        "/home/eoh/settings.lua",
        "/home/eoh/theme.lua",
        "/home/hub/calculator.lua",
        "/home/hub/config.lua",
        "/home/hub/theme.lua",
        "/home/hub/main.lua",
        "/home/hub/gui.lua",
        "/home/hub/logger.lua",
        "/home/hub/registry.lua",
        "/home/hub/setup.lua",
        "/autorun.lua",
        "/U.lua",
        "/update_manifest.lua",
        "/README.md",
    }
    
    -- Скачиваем файлы
    print("📦 Загрузка файлов...")
    local installed = 0
    local failed = 0
    
    for _, file in ipairs(files) do
        local url = REPO .. file
        local name = filesystem.name(file)
        print("  📥 " .. name)
        
        local success, err = downloadFile(url, file)
        if success then
            print("  ✅ " .. name)
            installed = installed + 1
        else
            print("  ❌ " .. name .. " - " .. tostring(err))
            failed = failed + 1
        end
    end
    
    print("")
    print("════════════════════════════════════════════════════════════════")
    print("📊 ИТОГИ:")
    print("  ✅ Установлено: " .. installed)
    print("  ❌ Ошибок: " .. failed)
    print("════════════════════════════════════════════════════════════════")
    print("")
    
    if failed > 0 then
        print("⚠️  Некоторые файлы не установились.")
        print("Проверьте подключение и повторите попытку.")
        print("Нажмите любую клавишу для выхода...")
        os.sleep(5)
        return
    end
    
    print("✅ Установка завершена!")
    print("Запустите: lua /home/hub/main.lua")
    print("")
    print("Перезагрузка через 5 секунд...")
    os.sleep(5)
    os.reboot()
end

-- ============================================
-- ЗАПУСК С ОБРАБОТКОЙ ОШИБОК
-- ============================================

local ok, err = pcall(install)
if not ok then
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║                    ОШИБКА УСТАНОВКИ                         ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    print("❌ " .. tostring(err))
    print("")
    print("📖 Возможные причины:")
    print("  1. Нет подключения к интернету")
    print("  2. Недостаточно места на диске")
    print("  3. Проблемы с правами доступа")
    print("")
    print("Нажмите любую клавишу для выхода...")
    os.sleep(10)
end
