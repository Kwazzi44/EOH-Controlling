-- ============================================
-- U.LUA - Обновление EOH Controller
-- ============================================

local filesystem = require("filesystem")
local internet = require("internet")
local os = require("os")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"
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

function update()
    print("🔄 Обновление EOH Controller...")
    print("")
    
    -- Создаем бэкап
    if filesystem.exists("/home/eoh/") then
        if not filesystem.exists("/home/eoh/backup/") then
            filesystem.makeDirectory("/home/eoh/backup/")
        end
        print("📦 Создание бэкапа...")
    end
    
    -- Обновляем файлы
    print("📦 Загрузка обновлений...")
    for _, file in ipairs(FILES) do
        local url = REPO .. file
        local backup = "/home/eoh/backup/" .. filesystem.name(file) .. ".bak"
        
        if filesystem.exists(file) then
            filesystem.copy(file, backup)
        end
        
        local success, data = pcall(function()
            return internet.request(url)
        end)
        if success and data then
            local f = io.open(file, "w")
            if f then
                f:write(data.readAll())
                f:close()
                print("  ✅ Обновлен: " .. file)
            end
        else
            print("  ❌ Ошибка: " .. file)
        end
    end
    
    print("")
    print("✅ Обновление завершено!")
    print("🔄 Перезагрузка через 3 секунды...")
    os.sleep(3)
    os.reboot()
end

update()