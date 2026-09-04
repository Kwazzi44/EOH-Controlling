-- ============================================
-- SETUP.LUA - Настройка и регистрация EOH
-- ============================================

local term = require("term")
local event = require("event")
local registry = require("registry")
local logger = require("logger")
local filesystem = require("filesystem")

-- Проверяем наличие eoh_core
local eohCore = nil
if filesystem.exists("/home/eoh/eoh_core.lua") then
    eohCore = require("eoh_core")
end

function runSetup()
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║                   НАСТРОЙКА НОВОГО EOH                       ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    print("🔍 Поиск компонентов EOH...")
    
    local components = {eoh = nil, transposerH2 = nil, transposerHe = nil, transposerPlasma = nil}
    
    -- Если есть eoh_core, используем его
    if eohCore and eohCore.scanComponents then
        components = eohCore.scanComponents()
    else
        -- Простой поиск компонентов
        for address, name in component.list() do
            if name:find("EyeOfHarmony") and not components.eoh then
                components.eoh = address
                print("  ✅ Найден контроллер: " .. address)
            end
            if name:find("transposer") then
                if not components.transposerH2 then
                    components.transposerH2 = address
                    print("  ✅ Найден транспозер (H2): " .. address)
                elseif not components.transposerHe then
                    components.transposerHe = address
                    print("  ✅ Найден транспозер (He): " .. address)
                elseif not components.transposerPlasma then
                    components.transposerPlasma = address
                    print("  ✅ Найден транспозер (Plasma): " .. address)
                end
            end
        end
    end
    
    if not components.eoh then
        print("")
        print("❌ КОНТРОЛЛЕР EOH НЕ НАЙДЕН!")
        print("Убедитесь, что мультиблок собран и адаптер подключен.")
        print("")
        print("Нажмите любую клавишу для возврата...")
        event.pull("key_down")
        return
    end
    
    print("")
    print("✅ Найден контроллер EOH: " .. components.eoh)
    print("✅ Транспозер H2: " .. (components.transposerH2 or "не найден"))
    print("✅ Транспозер He: " .. (components.transposerHe or "не найден"))
    print("✅ Транспозер Plasma: " .. (components.transposerPlasma or "не найден"))
    print("")
    print("Введите имя для EOH (или оставьте пустым): ")
    
    local name = io.read()
    if name == "" then
        name = "EOH #" .. (#registry.getAll() + 1)
    end
    
    local id = registry.addEOH(name, components)
    print("")
    print("✅ EOH зарегистрирован с ID: " .. id)
    print("")
    print("Нажмите любую клавишу для возврата...")
    event.pull("key_down")
end

return { runSetup = runSetup }