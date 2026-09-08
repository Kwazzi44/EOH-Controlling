-- EOH SETUP
-- Guided GUI for selecting an EOH controller, operating parameters and hardware.
-- User configuration is persisted through registry/database; code remains updateable.

package.path = "/home/?.lua;/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local component = require("component")
local event = require("event")
local keyboard = require("keyboard")
local computer = require("computer")
local filesystem = require("filesystem")
local registry = require("registry")
local scanner = require("scanner")
local theme = require("theme")

local gpu = component.isAvailable("gpu") and component.gpu or nil
local C = theme.C
local W, H = 80, 25

local function initScreen()
    if not gpu then return end
    gpu.setDepth(gpu.maxDepth())
    theme.init(gpu)
    W, H = theme.getRes()
end

local function clear()
    if gpu then
        theme.gfill(1, 1, W, H, " ", C.text, C.bg)
    else
        term.clear()
    end
end

local function text(x, y, value, color, bg)
    value = tostring(value or "")
    if gpu then
        theme.gset(x, y, value:sub(1, math.max(0, W - x + 1)), color or C.text, bg or C.bg)
    else
        print(value)
    end
end

local function header(title, step)
    if not gpu then
        clear()
        print("=== " .. title .. " ===")
        return
    end
    theme.gfill(1, 1, W, H, " ", C.text, C.bg)
    theme.drawHeader(title, string.format("STEP %d/8", step or 1))
    theme.gset(1, 4, "+" .. string.rep("=", W - 2) .. "+", C.border, C.bg)
end

local function footer(backLabel, nextLabel)
    if gpu then
        theme.drawFooter({
            {"Up/Down", "Select"},
            {"Enter", nextLabel or "Next"},
            {"Backspace", backLabel or "Back"},
            {"Esc", "Cancel"},
        })
    else
        print("[Up/Down] select  [Enter] next  [Backspace] back  [Esc] cancel")
    end
end

local function waitKey()
    while true do
        local _, _, charCode, keyCode = event.pull("key_down")
        return charCode, keyCode
    end
end

local function selectedLoop(title, items, selected, renderItem, allowEmpty)
    selected = selected or 1
    if #items == 0 and not allowEmpty then return nil, "empty" end
    while true do
        clear()
        header(title, 1)
        if #items == 0 then
            text(4, 7, "Нет доступных вариантов.", C.warn)
            footer("", "Cancel")
        else
            for i, item in ipairs(items) do
                local y = 6 + i
                local active = i == selected
                if y < H - 3 then
                    if gpu then theme.gfill(3, y, W - 6, 1, " ", C.text, active and C.sel_bg or C.bg) end
                    text(5, y, (active and "> " or "  ") .. tostring(renderItem(item, i)),
                        active and C.sel_fg or C.text, active and C.sel_bg or C.bg)
                end
            end
            footer("Back", "Select")
        end
        local _, keyCode = waitKey()
        if keyCode == keyboard.keys.up then
            selected = math.max(1, selected - 1)
        elseif keyCode == keyboard.keys.down then
            selected = math.min(math.max(1, #items), selected + 1)
        elseif keyCode == keyboard.keys.enter or keyCode == keyboard.keys.numpadenter or keyCode == 28 then
            if #items > 0 then return items[selected], selected end
        elseif keyCode == keyboard.keys.backspace or keyCode == 14 then
            return nil, "back"
        elseif keyCode == keyboard.keys.escape or keyCode == 1 then
            return nil, "cancel"
        end
    end
end

local function waitContinue(message)
    if gpu then
        text(3, H - 4, message or "Нажмите Enter для продолжения.", C.warn)
    else
        print(message or "Нажмите Enter для продолжения.")
    end
    while true do
        local _, keyCode = waitKey()
        if keyCode == keyboard.keys.enter or keyCode == keyboard.keys.numpadenter or keyCode == 28 then return true end
        if keyCode == keyboard.keys.escape or keyCode == 1 or keyCode == keyboard.keys.backspace or keyCode == 14 then return false end
    end
end

local function componentAddress(value)
    if type(value) == "string" then return value end
    if type(value) == "table" then return value.address end
    return nil
end

local function buildExcluded(targetIndex)
    local excluded = {}
    for index, eoh in ipairs(registry.getAll()) do
        if index ~= targetIndex then
            local function claim(value)
                local address = componentAddress(value)
                if address then excluded[address] = true; return end
                if type(value) == "table" then
                    for _, item in pairs(value) do claim(item) end
                end
            end
            claim(eoh.components or {})
            claim(eoh.controllers or {})
        end
    end
    return excluded
end

local function scanHardware(targetIndex)
    local result = scanner.scan(buildExcluded(targetIndex), {})
    local candidates = result.controllerCandidates or {}
    table.sort(candidates, function(a, b) return (a.name or "") < (b.name or "") end)
    return result, candidates
end

local function controllerText(item)
    local name = tostring(item.name or "gt_machine")
    return name .. " [" .. tostring(item.address):sub(1, 18) .. "]"
end

local function transposerText(item)
    local role = item.role and string.upper(item.role) or "UNASSIGNED"
    local fluid = item.fluid and tostring(item.fluid) or "empty/unknown"
    local side = item.sourceSideName and tostring(item.sourceSideName) or "?"
    return role .. " | " .. fluid .. " | " .. side .. " | " .. tostring(item.address):sub(1, 18)
end

local function pickTransposer(title, transposers, used, wantedRole, current)
    local list = {}
    for _, item in ipairs(transposers or {}) do
        if not used[item.address] or item.address == current then
            local roleOk = true
            if wantedRole and item.role and item.role ~= wantedRole and item.address ~= current then
                roleOk = false
            end
            if roleOk then list[#list + 1] = item end
        end
    end
    if #list == 0 then return nil, "empty" end
    return selectedLoop(title, list, 1, transposerText, false)
end

local function configureNumber(title, values, current)
    local items = {}
    for _, value in ipairs(values) do items[#items + 1] = value end
    local chosen, reason = selectedLoop(title, items, 1, function(v) return tostring(v) end, false)
    if not chosen then return nil, reason end
    return tonumber(chosen) or chosen
end

local function configureChoice(title, values, current)
    local selected = 1
    for i, value in ipairs(values) do if value.value == current then selected = i end end
    local chosen, reason = selectedLoop(title, values, selected, function(v) return v.label end, false)
    if not chosen then return nil, reason end
    return chosen.value
end

local function summary(settings, controller, h2, he, plasma)
    clear()
    header("ПОДТВЕРЖДЕНИЕ EOH", 8)
    local rows = {
        "Controller: " .. tostring(controller and controller.name or "-"),
        "Address:    " .. tostring(controller and controller.address or "-"),
        "Tier:       T" .. tostring(settings.tier),
        "Planet:     " .. tostring(settings.planet),
        "AA:         " .. (settings.mode == "aa" and "ON" or "OFF"),
        "Overclock:  " .. tostring(settings.overclocks),
        "Hydrogen:   " .. tostring(h2 and h2.address or "-"),
        "Helium:     " .. tostring(he and he.address or "-"),
        "Plasma:     " .. tostring(plasma and plasma.address or "-"),
    }
    for i, row in ipairs(rows) do text(4, 5 + i, row, C.text) end
    text(4, H - 5, "ENTER = сохранить    BACKSPACE = назад    ESC = отмена", C.warn)
    while true do
        local _, keyCode = waitKey()
        if keyCode == keyboard.keys.enter or keyCode == keyboard.keys.numpadenter or keyCode == 28 then return true end
        if keyCode == keyboard.keys.backspace or keyCode == 14 then return false, "back" end
        if keyCode == keyboard.keys.escape or keyCode == 1 then return false, "cancel" end
    end
end

function runSetup(targetIndex)
    initScreen()

    local existing = targetIndex and registry.getEOH(targetIndex) or nil
    local settings = {}
    for k, v in pairs((existing and existing.settings) or {}) do settings[k] = v end
    settings.tier = tonumber(settings.tier) or 3
    settings.planet = settings.planet or "Overworld"
    settings.mode = settings.mode or "production"
    settings.overclocks = tonumber(settings.overclocks) or 0
    settings.autoRestart = settings.autoRestart ~= false

    local result, candidates = scanHardware(targetIndex)
    if #candidates == 0 then
        clear(); header("НАСТРОЙКА НОВОГО EOH", 1)
        text(4, 7, "КОНТРОЛЛЕР EOH НЕ НАЙДЕН", C.ring_down)
        text(4, 9, "Ожидалось имя: Multimachine:Eye_of_Harmony", C.warn)
        text(4, 10, "Проверьте адаптер и подключение к EOH.", C.text)
        waitContinue("ENTER = назад")
        return
    end

    local controller, reason = selectedLoop("ВЫБОР КОНТРОЛЛЕРА EOH", candidates, 1, function(item)
        return controllerText(item)
    end, false)
    if not controller then return end

    local tier = configureNumber("ВЫБОР TIER", {1,2,3,4,5,6,7,8,9}, settings.tier)
    if not tier then return end
    settings.tier = tier

    local planets = {
        {value="Overworld", label="Overworld"},
        {value="Nether", label="Nether"},
        {value="End", label="The End"},
        {value="Moon", label="Moon"},
        {value="Mars", label="Mars"},
        {value="Asteroids", label="Asteroids"},
        {value="Venus", label="Venus"},
        {value="Mercury", label="Mercury"},
    }
    local planet = configureChoice("ВЫБОР ПЛАНЕТЫ", planets, settings.planet)
    if not planet then return end
    settings.planet = planet

    local aa = configureChoice("ANTIMATTER (AA)", {
        {value="production", label="AA: OFF — обычное производство"},
        {value="aa", label="AA: ON — производство плазмы"},
    }, settings.mode)
    if not aa then return end
    settings.mode = aa
    settings.useAA = aa == "aa"

    local oc = configureNumber("OVERCLOCK", {0,1,2,3}, settings.overclocks)
    if not oc then return end
    settings.overclocks = oc

    result, candidates = scanHardware(targetIndex)
    local transposers = result.transposers or {}
    local used = {}
    local old = existing and existing.components or {}

    local h2, r1 = pickTransposer("ПРИВЯЗКА H₂", transposers, used, "hydrogen", old.transposerH2)
    if not h2 then
        if r1 == "back" then return end
        waitContinue("H₂ транспозер не выбран. Нужен источник водорода.")
        return
    end
    used[h2.address] = true

    local he, r2 = pickTransposer("ПРИВЯЗКА He", transposers, used, "helium", old.transposerHe)
    if not he then
        if r2 == "back" then return end
        waitContinue("He транспозер не выбран. Нужен источник гелия.")
        return
    end
    used[he.address] = true

    local plasma
    if settings.mode == "aa" then
        plasma = pickTransposer("ПРИВЯЗКА PLASMA", transposers, used, "plasma", old.transposerPlasma)
        if not plasma then
            waitContinue("Для AA нужен плазменный транспозер.")
            return
        end
        plasma = plasma
        used[plasma.address] = true
    end

    local components = {
        eoh = controller.address,
        eohController = controller.address,
        transposerH2 = h2.address,
        transposerHydrogen = h2.address,
        transposerHe = he.address,
        transposerHelium = he.address,
        transposerPlasma = plasma and plasma.address or nil,
        transposerPlasmaList = plasma and {plasma.address} or {},
        transposers = {},
    }
    for _, item in ipairs(transposers) do
        if used[item.address] then
            components.transposers[#components.transposers + 1] = {
                address = item.address,
                role = item.address == h2.address and "hydrogen"
                    or item.address == he.address and "helium"
                    or item.address == (plasma and plasma.address) and "plasma" or nil,
                sourceSide = item.sourceSide,
                sourceSideName = item.sourceSideName,
                targetSide = item.targetSide,
                targetSideName = item.targetSideName,
            }
        end
    end

    local ok, why = summary(settings, controller, h2, he, plasma)
    if not ok then
        if why == "back" then
            return runSetup(targetIndex)
        end
        return
    end

    local id, saved
    if existing then
        saved = registry.updateComponents(targetIndex, components)
        if saved then saved = registry.updateEOH(targetIndex, settings) end
        id = targetIndex
    else
        local name = "EOH " .. tostring(controller.name or "Controller")
        id, saved = registry.addEOH(name, components, settings)
    end

    clear(); header("ГОТОВО", 8)
    if saved then
        text(4, 8, "✓ EOH успешно сохранён.", C.ok)
        text(4, 10, "Контроллер: " .. tostring(controller.address), C.text)
        text(4, 11, "Tier T" .. tostring(settings.tier) .. " | " .. tostring(settings.planet)
            .. " | AA " .. (settings.mode == "aa" and "ON" or "OFF")
            .. " | OC " .. tostring(settings.overclocks), C.text)
        text(4, 13, "Оборудование привязано к этому EOH.", C.ok)
    else
        text(4, 8, "✗ Не удалось сохранить конфигурацию.", C.ring_down)
        text(4, 10, "Проверьте /home/eoh/logs и базу данных.", C.warn)
    end
    waitContinue("ENTER = вернуться в Main")
end

return { runSetup = runSetup }
