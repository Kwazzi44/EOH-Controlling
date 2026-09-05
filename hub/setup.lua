-- ============================================
-- SETUP.LUA - Настройка и регистрация EOH
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local term = require("term")
local event = require("event")
local component = require("component")
local registry = require("registry")
local loggerLib = require("lib.logger")
local logger = loggerLib.new("/home/hub", "hub.log")
logger:init()
local filesystem = require("filesystem")

-- Проверяем наличие eoh_core
local eohCore = nil
if filesystem.exists("/home/eoh/eoh_core.lua") then
    eohCore = require("eoh_core")
end

function runSetup(targetIndex)
    term.clear()
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║                   НАСТРОЙКА НОВОГО EOH                       ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print("")
    print("🔍 Поиск компонентов EOH...")
    
    local components = {eoh = nil, transposerH2 = nil, transposerHe = nil, transposerPlasma = nil}
    local excluded = {}
    for _, registered in ipairs(registry.getAll()) do
        local function claim(value)
            if type(value) == "string" then excluded[value] = true
            elseif type(value) == "table" then
                if value.address then excluded[value.address] = true end
                for _, item in pairs(value) do claim(item) end
            end
        end
        claim(registered.components or {})
        claim(registered.controllers or {})
    end
    
    -- Если есть eoh_core, используем его
    if eohCore and eohCore.scanComponents then
        components = eohCore.scanComponents(excluded)
    else
        for address, name in component.list("gt_machine") do
            components.all = components.all or {}
            table.insert(components.all, {address = address, name = name})
        end
    end
    
    -- Setup is for registering a new EOH. Existing bindings are excluded.
    local claimed = {}
    for index, eoh in ipairs(registry.getAll()) do
        if index ~= targetIndex then
            local bound = eoh.components or {}
            for _, value in pairs(bound) do
                if type(value) == "string" then
                    claimed[value] = true
                elseif type(value) == "table" then
                    for _, item in ipairs(value) do
                        if type(item) == "string" then
                            claimed[item] = true
                        elseif type(item) == "table" and item.address then
                            claimed[item.address] = true
                        end
                    end
                end
            end
        end
    end
    local function available(address)
        return address and not claimed[address]
    end
    local visibleControllers = {}
    for _, address in ipairs(components.controllers or {}) do
        if available(address) then
            table.insert(visibleControllers, address)
        end
    end
    components.controllers = visibleControllers
    components.eoh = visibleControllers[1]
    if not available(components.transposerH2) then components.transposerH2 = nil end
    if not available(components.transposerHe) then components.transposerHe = nil end
    if not available(components.transposerPlasma) then
        components.transposerPlasma = nil
    end
    local visibleTransposers = {}
    for _, transposer in ipairs(components.transposers or {}) do
        if available(transposer.address) then
            table.insert(visibleTransposers, transposer)
        end
    end
    components.transposers = visibleTransposers
    if not components.transposerH2 or not components.transposerHe then
        for _, transposer in ipairs(visibleTransposers) do
            local fluid = string.lower(transposer.fluid or "")
            if not components.transposerH2
                and fluid:find("hydrogen", 1, true) then
                components.transposerH2 = transposer.address
            elseif not components.transposerHe
                and fluid:find("helium", 1, true) then
                components.transposerHe = transposer.address
            end
        end
    end
    if #visibleTransposers == 1 then
        local address = visibleTransposers[1].address
        components.transposerH2 = components.transposerH2 or address
        components.transposerHe = components.transposerHe or address
    end
    local visiblePlasma = {}
    for _, address in ipairs(components.transposerPlasmaList or {}) do
        if available(address) then table.insert(visiblePlasma, address) end
    end
    components.transposerPlasmaList = visiblePlasma
    local visibleAll = {}
    for _, item in ipairs(components.all or {}) do
        if available(item.address) then table.insert(visibleAll, item) end
    end
    components.all = visibleAll

    if not components.eoh then
        print("")
        print("❌ КОНТРОЛЛЕР EOH НЕ НАЙДЕН!")
        if components.all then
            print("Доступные компоненты:")
            for _, item in ipairs(components.all) do
                print("  " .. item.name .. " [" .. item.address .. "]")
            end
        end
        print("Список компонентов записан в /home/eoh/logs/eoh.log.")
        print("Убедитесь, что мультиблок собран и адаптер подключен.")
        print("")
        print("Нажмите любую клавишу для возврата...")
        event.pull("key_down")
        return
    end
    
    print("")
    print("✅ Найден контроллер EOH: " .. components.eoh)
    print("✅ Транспозеры: " .. tostring(#(components.transposers or {})))
    for i, transposer in ipairs(components.transposers or {}) do
        print("  " .. i .. ". " .. transposer.address
            .. " | " .. tostring(transposer.fluid or "fluid не определён")
            .. " | " .. tostring(transposer.capacity) .. "L")
    end
    print("✅ Плазменные транспозеры для AA: "
        .. tostring(#(components.transposerPlasmaList or {})))
    local id
    if targetIndex and registry.getEOH(targetIndex) then
        local settings = registry.getEOH(targetIndex).settings or {}
        if settings.mode ~= "aa" then
            components.transposerPlasma = nil
            components.transposerPlasmaList = {}
        end
        local saved = registry.updateComponents(targetIndex, components)
        id = targetIndex
        print("")
        if saved then
            print("✅ Компоненты привязаны к EOH #" .. id)
        else
            print("❌ Не удалось сохранить привязку EOH #" .. id)
        end
    else
        print("")
        print("Введите имя для нового EOH (или оставьте пустым): ")
        local name = io.read()
        if name == "" then
            name = "EOH #" .. (#registry.getAll() + 1)
        end
        local saved
        id, saved = registry.addEOH(name, components)
        print("")
        if saved then
            print("✅ EOH зарегистрирован с ID: " .. id)
        else
            print("❌ EOH создан в памяти, но не сохранён")
        end
    end
    local eoh = registry.getEOH(id)
    local settings = eoh and eoh.settings or {}
    if eohCore and eohCore.startConfiguredCycle
        and settings.autoRestart ~= false then
        local started, message = eohCore.startConfiguredCycle(
            eoh.components, settings)
        print(started and "AUTO: recipe cycle started"
            or "AUTO: " .. tostring(message))
    end
    print("")
    print("Нажмите любую клавишу для возврата...")
    event.pull("key_down")
end

return { runSetup = runSetup }
