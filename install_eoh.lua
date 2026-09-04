
local filesystem = require("filesystem")
local internet = require("internet")
local os = require("os")
local term = require("term")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"

-- ============================================
-- КОНФИГУРАЦИЯ ФАЙЛОВ
-- ============================================

local FILES = {
    "/home/eoh/config.lua",
    "/home/eoh/eoh_core.lua",
    "/home/eoh/logger.lua",
    "/home/eoh/main.lua",
    "/home/eoh/recipes.lua",
    "/home/eoh/settings.lua",
    "/home/eoh/theme.lua",
    "/home/hub/calculator.lua",
    "/home/hub/config.lua",
    "/home/hub/main.lua",
    "/home/hub/registry.lua",
    "/home/hub/setup.lua",
    "/autorun.lua",
    "/U.lua",
    "/update_manifest.lua",
    "/README.md",
}

local SETTINGS_FILES = {
    "/home/hub/registry.dat",
    "/home/eoh/settings.dat",
    "/home/backup/",
}

local FOLDERS_TO_CLEAN = {
    "/home/eoh/",
    "/home/hub/",
}

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
-- СОХРАНЕНИЕ НАСТРОЕК
-- ============================================

function backupSettings()
    print("📦 Сохранение настроек...")
    
    local backupDir = "/home/backup/"
    if not filesystem.exists(backupDir) then
        filesystem.makeDirectory(backupDir)
    end
    
    local saved = 0
    for _, file in ipairs(SETTINGS_FILES) do
        if filesystem.exists(file) then
            local name = filesystem.name(file)
            local backup = backupDir .. name
            filesystem.copy(file, backup)
            print("  ✅ Сохранено: " .. name)
            saved = saved + 1
        end
    end
    
    print("  ✅ Сохранено настроек: " .. saved)
    return saved
end

-- ============================================
-- ВОССТАНОВЛЕНИЕ НАСТРОЕК
-- ============================================

function restoreSettings()
    print("📦 Восстановление настроек...")
    
    local backupDir = "/home/backup/"
    if not filesystem.exists(backupDir) then
        print("  ⚠️ Папка с бэкапами не найдена")
        return 0
    end
    
    local restored = 0
    for _, file in ipairs(SETTINGS_FILES) do
        local name = filesystem.name(file)
        local backup = backupDir .. name
        if filesystem.exists(backup) then
            filesystem.copy(backup, file)
            print("  ✅ Восстановлено: " .. name)
            restored = restored + 1
        end
    end
    
    print("  ✅ Восстановлено настроек: " .. restored)
    return restored
end

-- ============================================
-- ОЧИСТКА СТАРЫХ ФАЙЛОВ
-- ============================================

function cleanOldFiles()
    print("🗑️  Удаление старых файлов...")
    
    local deleted = 0
    for _, file in ipairs(FILES) do
        if filesystem.exists(file) then
            filesystem.remove(file)
            print("  ✅ Удален: " .. filesystem.name(file))
            deleted = deleted + 1
        end
    end
    
    for _, folder in ipairs(FOLDERS_TO_CLEAN) do
        if filesystem.exists(folder) then
            local list = filesystem.list(folder)
            for _, item in ipairs(list) do
                local path = folder .. item
                local isSetting = false
                for _, setting in ipairs(SETTINGS_FILES) do
                    if path == setting then
                        isSetting = true
                        break
                    end
                end
                if not isSetting then
                    filesystem.remove(path)
                    print("  ✅ Удалено: " .. path)
                end
            end
        end
    end
    
    print("  ✅ Удалено файлов: " .. deleted)
    return deleted
end

-- ============================================
-- УСТАНОВКА НОВЫХ ФАЙЛОВ
-- ============================================

function installNewFiles()
    print("📦 Установка новых файлов...")
    
    local dirs = {
        "/home/eoh/",
        "/home/eoh/logs/",
        "/home/hub/",
        "/home/hub/logs/",
    }
    for _, dir in ipairs(dirs) do
        if not filesystem.exists(dir) then
            filesystem.makeDirectory(dir)
            print("  📁 Создана: " .. dir)
        end
    end
    
    local installed = 0
    local failed = 0
    
    for _, file in ipairs(FILES) do
        local url = REPO .. file
        local name = filesystem.name(file)
        print("  📥 Загрузка: " .. name)
        
        local success, err = downloadFile(url, file)
        if success then
            print("  ✅ Установлен: " .. name)
            installed = installed + 1
        else
            print("  ❌ Ошибка: " .. name .. " - " .. tostring(err))
            failed = failed + 1
        end
    end
    
    print("  ✅ Установлено: " .. installed)
    print("  ❌ Ошибок: " .. failed)
    
    return installed, failed
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
    
    print("🔍 Проверка подключения...")
    local test = internet.request("https://raw.githubusercontent.com")
    if not test then
        print("❌ Нет подключения к интернету!")
        print("")
        print("Нажмите любую клавишу для выхода...")
        os.sleep(5)
        return
    end
    print("✅ Подключение есть")
    print("")
    
    backupSettings()
    print("")
    
    cleanOldFiles()
    print("")
    
    local installed, failed = installNewFiles()
    print("")
    
    restoreSettings()
    print("")
    
    print("════════════════════════════════════════════════════════════════")
    print("📊 ИТОГИ УСТАНОВКИ:")
    print("  ✅ Установлено: " .. installed)
    print("  ❌ Ошибок: " .. failed)
    print("  ✅ Настройки сохранены")
    print("════════════════════════════════════════════════════════════════")
    print("")
    
    if failed > 0 then
        print("⚠️  Некоторые файлы не установились.")
        print("Проверьте подключение и повторите попытку.")
        print("")
        print("Нажмите любую клавишу для выхода...")
        os.sleep(5)
        return
    end
    
    if filesystem.exists("/temp_install.lua") then
        filesystem.remove("/temp_install.lua")
    end
    
    print("✅ Установка завершена успешно!")
    print("🔄 Перезагрузка через 5 секунд...")
    os.sleep(5)
    os.reboot()
end

-- ============================================
-- ЗАПУСК
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