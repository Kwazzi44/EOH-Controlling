-- ============================================
-- U.LUA - Обновление EOH Controller
-- ============================================

local filesystem = require("filesystem")
local internet = require("internet")
local os = require("os")
local term = require("term")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"

function downloadFile(url, path)
    local req = internet.request(url)
    if not req then
        return false, "Не удалось создать запрос"
    end
    
    local data = ""
    while true do
        local chunk = req.read()
        if not chunk then break end
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

function update()
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║              ОБНОВЛЕНИЕ EOH CONTROLLER                       ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    
    print("📥 Загрузка нового установщика...")
    local success, err = downloadFile(REPO .. "/install_eoh.lua", "/temp_install.lua")
    
    if not success then
        print("❌ Ошибка: " .. tostring(err))
        print("Нажмите любую клавишу для выхода...")
        os.sleep(5)
        return
    end
    
    print("✅ Новый установщик загружен")
    print("")
    print("🚀 Запуск установки...")
    os.sleep(2)
    
    os.execute("lua /temp_install.lua")
end

local ok, err = pcall(update)
if not ok then
    term.clear()
    print("❌ Ошибка обновления: " .. tostring(err))
    os.sleep(5)
end