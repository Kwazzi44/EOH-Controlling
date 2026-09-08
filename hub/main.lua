-- ============================================
-- MAIN.LUA - Точка входа HUB
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local term = require("term")
local event = require("event")
local keyboard = require("keyboard")
local computer = require("computer")
local os = require("os")
local filesystem = require("filesystem")

local function checkModules()
    local modules = {
        {name="config", path="/home/lib/config.lua"},
        {name="settings", path="/home/lib/settings.lua"},
        {name="registry", path="/home/hub/registry.lua"},
        {name="setup", path="/home/hub/setup.lua"},
        {name="logger", path="/home/lib/logger.lua"},
        {name="eoh_core", path="/home/eoh/eoh_core.lua"},
        {name="gui", path="/home/hub/gui.lua"},
    }
    for _, mod in ipairs(modules) do
        if not filesystem.exists(mod.path) then
            print("Ошибка: файл " .. mod.path .. " не найден!")
            os.sleep(3)
            return false
        end
    end
    return true
end

if not checkModules() then return end

local config = require("config")
local registry = require("registry")
local setup = require("setup")
local loggerLib = require("logger")
local logger = loggerLib.new("/home/hub", "hub.log")
logger:init()
local core = require("eoh_core")
local gui = require("gui")
gui.setBuild(core.build)
gui.init()

local function keyToChar(charCode)
    if type(charCode) == "number" and charCode >= 0 and charCode <= 255 then
        return string.char(charCode)
    end
    return ""
end

-- OpenComputers key_down: address, character, keyCode, player.
-- События читаем без фильтра, затем сами проверяем тип события.
local function pullKey(timeout)
    local eventName, address, charCode, keyCode, player = event.pull(timeout)
    if eventName == "key_down" then
        return true, charCode, keyCode, player
    end
    return false, nil, nil, nil
end

local function physicalKeyDown(code)
    if not code or type(keyboard.isKeyDown) ~= "function" then return false end
    local ok, down = pcall(keyboard.isKeyDown, code)
    return ok and down == true
end

local function keyMatches(keyCode, namedKey, fallback)
    return keyCode == namedKey or keyCode == fallback
end

local function isF1(keyCode)
    return keyMatches(keyCode, keyboard.keys.f1, 59)
end

local function isF3(keyCode)
    return keyMatches(keyCode, keyboard.keys.f3, 61)
end

local function isDelete(keyCode)
    return keyMatches(keyCode, keyboard.keys.delete, 211)
end

local function isBackKey(charCode, keyCode)
    return charCode == string.byte("b")
        or charCode == string.byte("B")
        or keyCode == keyboard.keys.b
        or keyCode == 48
        or keyCode == keyboard.keys.backspace
        or keyCode == 14
end

local function isRunKey(charCode, keyCode)
    return charCode == string.byte("r")
        or charCode == string.byte("R")
        or keyCode == keyboard.keys.r
        or keyCode == 19
end

local guiCache = {eohsHash=nil, runtimesHash=nil, selected=nil}

local function computeRuntimesHash(runtimes)
    local hash = ""
    for i, r in ipairs(runtimes or {}) do
        hash = hash .. i .. ":" .. tostring(r.stage) .. ":" .. tostring(r.progress) .. ":" .. tostring(r.maximum) .. ";"
    end
    return hash
end

local function computeEohsHash(eohs)
    local hash = ""
    for i, e in ipairs(eohs or {}) do
        hash = hash .. i .. ":" .. tostring(e.name) .. ":" .. tostring((e.components or {}).eohController or "") .. ";"
    end
    return hash
end

local lastDrawTime = 0
local drawInterval = 0.2

function drawMainScreen(selected)
    local now = computer.uptime()
    if now - lastDrawTime < drawInterval then return end
    local eohs = registry.getAll()
    local runtimes = {}
    for index, eoh in ipairs(eohs) do
        runtimes[index] = core.getRuntimeState(eoh.components)
    end
    local eohsHash = computeEohsHash(eohs)
    local runtimesHash = computeRuntimesHash(runtimes)
    if guiCache.eohsHash == eohsHash
        and guiCache.runtimesHash == runtimesHash
        and guiCache.selected == selected then
        return
    end
    guiCache.eohsHash = eohsHash
    guiCache.runtimesHash = runtimesHash
    guiCache.selected = selected
    lastDrawTime = now
    gui.draw(eohs, selected or 1, config.hubName .. " v" .. config.version, runtimes)
end

local detailCache = {signature=nil, notice=nil, index=nil}
local lastDetailUpdate = 0
local detailUpdateInterval = 0.5

local function runtimeSignature(runtime)
    runtime = runtime or {}
    local progress = tonumber(runtime.progress) or 0
    local maximum = tonumber(runtime.maximum) or 0
    local percent = 0
    if maximum > 0 then
        percent = math.floor(math.max(0, math.min(1, progress / maximum)) * 100)
    end
    return tostring(runtime.stage or "OFF") .. ":" .. tostring(percent)
end

local function showDetail(index)
    local eoh = registry.getEOH(index)
    if not eoh then return end

    local notice = nil
    local needsRedraw = true
    detailCache.signature = nil
    detailCache.notice = nil
    detailCache.index = nil

    -- Латчи не дают R/B/F3 срабатывать несколько раз за одно удержание.
    local keyLatch = {b=false, r=false, f3=false}

    while true do
        local now = computer.uptime()
        local runtime = core.getRuntimeState(eoh.components)
        local signature = runtimeSignature(runtime)
        local changed = detailCache.signature ~= signature
            or detailCache.index ~= index
            or detailCache.notice ~= notice

        if needsRedraw or changed then
            gui.drawDetail(eoh, notice, runtime)
            detailCache.signature = signature
            detailCache.notice = notice
            detailCache.index = index
            lastDetailUpdate = now
            needsRedraw = false
        end
        notice = nil

        local gotKey, charCode, keyCode = pullKey(0.05)
        local handled = false

        if gotKey then
            local char = keyToChar(charCode)

            if keyCode == keyboard.keys.enter
                or keyCode == keyboard.keys.numpadenter
                or keyCode == 28 then
                configureEOH(index)
                needsRedraw = true
                handled = true

            elseif isF1(keyCode) then
                setup.runSetup()
                needsRedraw = true
                handled = true

            elseif isF3(keyCode) then
                registry.load()
                eoh = registry.getEOH(index) or eoh
                needsRedraw = true
                handled = true
            end

            -- Для букв сначала пробуем реальное keyCode, затем polling ниже.
            if not handled and isRunKey(charCode, keyCode) then
                local started, message = core.startConfiguredCycle(eoh.components, eoh.settings or {})
                notice = started
                    and "RUN: recipe cycle started"
                    or "RUN BLOCKED: " .. tostring(message)
                needsRedraw = true
                keyLatch.r = true
                handled = true
            end

            if not handled and isBackKey(charCode, keyCode) then
                return
            end
        end

        -- Некоторые сборки OC/моды Minecraft передают буквенные клавиши
        -- нестабильно через key_down. Поэтому для B/R/F3 есть второй,
        -- физический путь через keyboard.isKeyDown().
        local bDown = physicalKeyDown(keyboard.keys.b or 48)
        local rDown = physicalKeyDown(keyboard.keys.r or 19)
        local f3Down = physicalKeyDown(keyboard.keys.f3 or 61)

        if bDown then
            if not keyLatch.b then
                keyLatch.b = true
                return
            end
        else
            keyLatch.b = false
        end

        if rDown then
            if not keyLatch.r then
                keyLatch.r = true
                local started, message = core.startConfiguredCycle(eoh.components, eoh.settings or {})
                notice = started
                    and "RUN: recipe cycle started"
                    or "RUN BLOCKED: " .. tostring(message)
                needsRedraw = true
            end
        else
            keyLatch.r = false
        end

        if f3Down then
            if not keyLatch.f3 then
                keyLatch.f3 = true
                registry.load()
                eoh = registry.getEOH(index) or eoh
                needsRedraw = true
            end
        else
            keyLatch.f3 = false
        end

        eoh = registry.getEOH(index) or eoh
    end
end

function configureEOH(index)
    local eoh = registry.getEOH(index)
    if not eoh then
        print("EOH #" .. index .. " не найден")
        os.sleep(1)
        return
    end

    local settings = eoh.settings or {}
    local defaults = {
        mode="production", tier=3, useAA=false,
        overclocks=0, autoRestart=true, tolerance=0.001
    }
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = value end
    end
    if settings.mode ~= "aa" then settings.useAA = false end
    eoh.settings = settings
    core.setComponents(eoh.components)

    local inputEnabledAt = computer.uptime() + 0.75
    local field = 1

    local function drawSettings()
        term.clear()
        print("EOH SETTINGS: " .. tostring(eoh.name))
        print("")
        local modeName = settings.mode == "power" and "DEEP DARK"
            or settings.mode == "aa" and "PRODUCTION + AA"
            or "PRODUCTION"
        local values = {
            "Mode: " .. modeName,
            "Planet tier: " .. tostring(settings.tier),
            "Astral Arrays: " .. (settings.mode == "aa" and "ON" or "OFF"),
            "Overclocks: " .. tostring(settings.overclocks),
            "Auto restart: " .. (settings.autoRestart and "ON" or "OFF"),
            "Tolerance: " .. tostring(settings.tolerance * 100) .. "%"
        }
        for i, value in ipairs(values) do
            print((i == field and "> " or "  ") .. i .. ". " .. value)
        end
        print("")
        print("UP/DOWN Select  LEFT/RIGHT Change")
        print("ENTER Save  R Run  B Backspace")
    end

    local function change(delta)
        if field == 1 then
            local modes = {"production", "aa", "power"}
            local current = 1
            for i, mode in ipairs(modes) do
                if settings.mode == mode then current = i end
            end
            settings.mode = modes[((current - 1 + delta) % #modes) + 1]
            settings.useAA = settings.mode == "aa"
        elseif field == 2 then
            settings.tier = math.max(1, math.min(9, settings.tier + delta))
        elseif field == 3 then
            settings.useAA = not settings.useAA
            settings.mode = settings.useAA and "aa" or "production"
        elseif field == 4 then
            settings.overclocks = math.max(0, math.min(3, settings.overclocks + delta))
        elseif field == 5 then
            settings.autoRestart = not settings.autoRestart
        elseif field == 6 then
            settings.tolerance = math.max(0.001, math.min(0.05, settings.tolerance + delta * 0.001))
        end
    end

    drawSettings()
    while true do
        local gotKey, charCode, keyCode = pullKey(nil)
        if gotKey then
            local char = keyToChar(charCode)
            if keyCode == keyboard.keys.up then
                field = math.max(1, field - 1)
            elseif keyCode == keyboard.keys.down then
                field = math.min(6, field + 1)
            elseif keyCode == keyboard.keys.left then
                change(-1)
            elseif keyCode == keyboard.keys.right then
                change(1)
            elseif keyCode == keyboard.keys.enter
                or keyCode == keyboard.keys.numpadenter
                or keyCode == 28
                or char == "s"
                or char == "S" then
                if computer.uptime() >= inputEnabledAt then
                    registry.updateEOH(index, settings)
                    break
                end
            elseif char == "r" or char == "R" or keyCode == keyboard.keys.r or keyCode == 19 then
                registry.updateEOH(index, settings)
                core.startConfiguredCycle(eoh.components, settings)
                break
            elseif isBackKey(charCode, keyCode) then
                break
            end
            drawSettings()
        end
    end
end

local function confirmDelete(index)
    local eoh = registry.getEOH(index)
    if not eoh then return false end
    gui.drawConfirmDelete(eoh)
    while true do
        local gotKey, charCode, keyCode = pullKey(nil)
        if gotKey then
            local char = keyToChar(charCode)
            if keyCode == keyboard.keys.enter
                or keyCode == keyboard.keys.numpadenter
                or keyCode == 28 then
                return true
            elseif isBackKey(charCode, keyCode)
                or char == "q"
                or char == "Q" then
                return false
            end
        end
    end
end

local function deleteSelected(index)
    local eoh = registry.getEOH(index)
    if not eoh then return false end
    if not confirmDelete(index) then return false end
    local name = eoh.name
    local ok = registry.removeEOH(index)
    if ok then
        logger:info("MAIN", "Deleted EOH #" .. tostring(index) .. " (" .. tostring(name) .. ")")
    end
    return ok
end

local dataDirty = true
local lastDataUpdate = 0
local dataUpdateInterval = 0.5

function main()
    dataDirty = true
    registry.load()

    for _, eoh in ipairs(registry.getAll()) do
        local settings = eoh.settings or {}
        if settings.autoRestart ~= false then
            core.startConfiguredCycle(eoh.components, settings)
        end
    end

    local selected = 1

    while true do
        core.tickConfiguredCycles()
        local now = computer.uptime()
        if not dataDirty and now - lastDataUpdate >= dataUpdateInterval then
            dataDirty = true
        end
        if dataDirty then
            drawMainScreen(selected)
            dataDirty = false
            lastDataUpdate = now
        end

        local gotKey, charCode, keyCode = pullKey(0.1)
        if gotKey then
            local char = keyToChar(charCode)

            if keyCode == keyboard.keys.up then
                selected = math.max(1, selected - 1)
                dataDirty = true

            elseif keyCode == keyboard.keys.down then
                selected = math.min(math.max(1, #registry.getAll()), selected + 1)
                dataDirty = true

            elseif keyCode == keyboard.keys.enter
                or keyCode == keyboard.keys.numpadenter
                or keyCode == 28 then
                if registry.getAll()[selected] then
                    showDetail(selected)
                end
                dataDirty = true

            elseif char and char >= "1" and char <= "9" then
                configureEOH(tonumber(char))
                dataDirty = true

            elseif isF1(keyCode) then
                setup.runSetup()
                dataDirty = true
                guiCache.eohsHash = nil
                guiCache.runtimesHash = nil

            elseif isDelete(keyCode) then
                if #registry.getAll() > 0 then
                    if deleteSelected(selected) then
                        selected = math.max(1, math.min(selected, #registry.getAll()))
                        guiCache.eohsHash = nil
                        guiCache.runtimesHash = nil
                    end
                    dataDirty = true
                end

            elseif isF3(keyCode) then
                dataDirty = true
                registry.load()

            elseif char and (char == "q" or char == "Q") then
                logger:info("MAIN", "Выход из программы")
                break
            end
        end
    end
end

local ok, err = pcall(main)
if not ok then
    term.clear()
    print("============================================")
    print("КРИТИЧЕСКАЯ ОШИБКА")
    print("============================================")
    print("")
    print(tostring(err))
    print("")
    print("Проверьте установку файлов /home/hub/ и /home/eoh/")
    print("Программа остановлена через 10 секунд...")
    os.sleep(10)
end
