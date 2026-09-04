-- ============================================
-- U.LUA - Загрузчик обновлений
-- Загружает свежий install_eoh.lua и запускает его
-- ============================================

local internet = require("internet")
local os = require("os")
local term = require("term")
local filesystem = require("filesystem")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"

function update()
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║              ЗАГРУЗКА ОБНОВЛЕНИЙ                             ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    print("📥 Загрузка нового установщика...")
    
    -- Скачиваем новый install_eoh.lua
    local url = REPO .. "/install_eoh.lua"
    local req = internet.request(url)
    
    if not req then
        print("❌ Ошибка: не удалось подключиться к репозиторию")
        print("Проверьте подключение к интернету.")
        print("")
        print("Нажмите любую клавишу для выхода...")
        os.sleep(5)
        return
    end
    
    -- Читаем данные
    local data = ""
    while true do
        local chunk = req.read()
        if not chunk then break end
        data = data .. chunk
    end
    
    if data == "" then
        print("❌ Ошибка: получен пустой файл")
        os.sleep(5)
        return
    end
    
    -- Сохраняем новый установщик как временный файл
    local tempFile = "/temp_install.lua"
    local f = io.open(tempFile, "w")
    if not f then
        print("❌ Ошибка: не удалось создать временный файл")
        os.sleep(5)
        return
    end
    f:write(data)
    f:close()
    
    print("✅ Новый установщик загружен")
    print("")
    print("🚀 Запуск установки...")
    print("")
    os.sleep(2)
    
    -- Запускаем новый установщик через dofile (безопаснее os.execute)
    local ok, err = pcall(dofile, tempFile)
    if not ok then
        print("❌ Ошибка при запуске установщика: " .. tostring(err))
        print("Попробуйте перезагрузить компьютер и запустить вручную:")
        print("  lua " .. tempFile)
        os.sleep(5)
    end
end

-- ============================================
-- ЗАПУСК
-- ============================================

local ok, err = pcall(update)
if not ok then
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║                    ОШИБКА ОБНОВЛЕНИЯ                         ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    print("❌ " .. tostring(err))
    print("")
    print("📖 Проверьте подключение к интернету")
    print("")
    print("Нажмите любую клавишу для выхода...")
    os.sleep(10)
end