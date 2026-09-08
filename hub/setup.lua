-- ============================================
-- SETUP.LUA - Guided EOH configuration
-- ============================================
package.path = "/home/?.lua;/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local component = require("component")
local computer = require("computer")
local term = require("term")
local input = require("input")
local registry = require("registry")
local scanner = require("scanner")
local recipes = require("recipes")
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
    if gpu then theme.gfill(1, 1, W, H, " ", C.text, C.bg) else term.clear() end
end

local function text(x, y, value, color, bg)
    value = tostring(value or "")
    if gpu then theme.gset(x, y, value:sub(1, math.max(0, W - x + 1)), color or C.text, bg or C.bg)
    else print(value) end
end

local function header(title, step)
    if not gpu then clear(); print("=== " .. title .. " ==="); return end
    theme.gfill(1, 1, W, H, " ", C.text, C.bg)
    theme.drawHeader(title, string.format("STEP %d/8", step or 1))
end

local function footer()
    if gpu then
        theme.drawFooter({{"Up/Down", "Select"}, {"Enter", "Select"}, {"Backspace", "Back"}})
    else
        print("[Up/Down] select  [Enter] select  [Backspace] back")
    end
end

local function waitContinue(message)
    text(3, H - 4, message or "ENTER = continue", C.warn)
    while true do
        local key = input.wait(nil)
        if input.is(key, "enter") then return true end
        if input.is(key, "back") then return false end
    end
end

local function selectedLoop(title, items, selected, renderItem, step)
    if #items == 0 then return nil, "empty" end
    selected = selected or 1
    while true do
        clear(); header(title, step)
        for i, item in ipairs(items) do
            local y = 6 + i
            if y < H - 3 then
                local active = i == selected
                if gpu then theme.gfill(3, y, W - 6, 1, " ", C.text, active and C.sel_bg or C.bg) end
                text(5, y, (active and "> " or "  ") .. tostring(renderItem(item, i)),
                    active and C.sel_fg or C.text, active and C.sel_bg or C.bg)
            end
        end
        footer()
        local key = input.wait(nil)
        if input.is(key, "up") then
            selected = math.max(1, selected - 1)
        elseif input.is(key, "down") then
            selected = math.min(#items, selected + 1)
        elseif input.is(key, "enter") then
            return items[selected], selected
        elseif input.is(key, "back") then
            return nil, "back"
        end
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
            local c = eoh.components or {}
            local fields = {
                c.eoh, c.eohController,
                c.transposerH2, c.transposerHydrogen,
                c.transposerHe, c.transposerHelium,
                c.transposerPlasma,
            }
            for _, value in ipairs(fields) do
                local address = componentAddress(value)
                if address then excluded[address] = true end
            end
            for _, value in ipairs(c.transposerPlasmaList or {}) do
                local address = componentAddress(value)
                if address then excluded[address] = true end
            end
            for _, value in ipairs(c.transposers or {}) do
                local address = componentAddress(value)
                if address then excluded[address] = true end
            end
        end
    end
    return excluded
end

local function scanHardware(targetIndex)
    return scanner.scan(buildExcluded(targetIndex), {})
end

local function controllerText(item)
    return tostring(item.name or "gt_machine") .. " [" .. tostring(item.address):sub(1, 18) .. "]"
end

local function transposerText(item)
    local role = item.role and string.upper(item.role) or "UNASSIGNED"
    local fluid = item.fluid and tostring(item.fluid) or "empty/unknown"
    local side = item.sourceSideName and tostring(item.sourceSideName) or "?"
    return role .. " | " .. fluid .. " | " .. side .. " | " .. tostring(item.address):sub(1, 18)
end

local function chooseNumber(title, values, current, step)
    local selected = 1
    for i, value in ipairs(values) do if tonumber(value) == tonumber(current) then selected = i end end
    local chosen, reason = selectedLoop(title, values, selected, tostring, step)
    if not chosen then return nil, reason end
    return tonumber(chosen)
end

local function chooseTransposer(title, transposers, used, role, current, step)
    local list = {}
    for _, item in ipairs(transposers or {}) do
        local free = not used[item.address] or item.address == current
        local roleOk = not item.role or item.role == role or item.address == current
        if free and roleOk then list[#list + 1] = item end
    end
    if #list == 0 then return nil, "empty" end
    return selectedLoop(title, list, 1, transposerText, step)
end

local function showPlanet(tier, step)
    local recipe = recipes.get(tier)
    clear(); header("ПЛАНЕТА", step)
    text(5, 8, "Tier T" .. tostring(tier), C.title)
    text(5, 10, "Planet: " .. tostring(recipe and recipe.planet or "-"), C.ok)
    text(5, 12, "Star Matter: " .. tostring(recipe and recipe.starMatter or "-"), C.text)
    text(5, 14, "Эта планета определяется выбранным Tier.", C.dim)
    return waitContinue("ENTER = продолжить")
end

local function summary(settings, controller, h2, he, plasma)
    clear(); header("ПОДТВЕРЖДЕНИЕ EOH", 7)
    local rows = {
        "Controller: " .. tostring(controller and controller.name or "-"),
        "Address:    " .. tostring(controller and controller.address or "-"),
        "Tier:       T" .. tostring(settings.tier),
        "Planet:     " .. tostring(settings.planet),
        "AA:         " .. (settings.useAA and "ON" or "OFF"),
        "Overclock:  " .. tostring(settings.overclocks),
        "Hydrogen:   " .. tostring(h2 and h2.address or "-"),
        "Helium:     " .. tostring(he and he.address or "-"),
        "Plasma:     " .. tostring(plasma and plasma.address or "-"),
    }
    for i, row in ipairs(rows) do text(4, 5 + i, row, C.text) end
    return waitContinue("ENTER = сохранить   BACKSPACE = назад")
end

function runSetup(targetIndex)
    initScreen()
    local existing = targetIndex and registry.getEOH(targetIndex) or nil
    local old = existing and existing.components or {}
    local settings = {}
    for key, value in pairs((existing and existing.settings) or {}) do settings[key] = value end
    settings.tier = tonumber(settings.tier) or 3
    settings.overclocks = tonumber(settings.overclocks) or 0
    settings.useAA = settings.useAA == true
    settings.mode = settings.mode == "power" and "power" or "production"

    local result = scanHardware(targetIndex)
    local candidates = result.controllerCandidates or {}
    table.sort(candidates, function(a, b) return tostring(a.name) < tostring(b.name) end)
    if #candidates == 0 then
        clear(); header("EOH SETUP", 1)
        text(4, 8, "КОНТРОЛЛЕР EOH НЕ НАЙДЕН", C.ring_down)
        text(4, 10, "Ожидается Multimachine:Eye_of_Harmony", C.warn)
        waitContinue("ENTER = назад")
        return
    end

    local controller, reason = selectedLoop("ВЫБОР КОНТРОЛЛЕРА EOH", candidates, 1, controllerText, 1)
    if not controller then return end

    local tier
    tier, reason = chooseNumber("ВЫБОР TIER", {1,2,3,4,5,6,7,8,9}, settings.tier, 2)
    if not tier then return end
    settings.tier = tier

    settings.planet = (recipes.get(tier) or {}).planet
    if not showPlanet(tier, 3) then return end

    local aaItems = {
        {value=false, label="AA: OFF — Hydrogen + Helium"},
        {value=true, label="AA: ON — Plasma"},
    }
    local aaSelected = settings.useAA and 2 or 1
    local aaChoice
    aaChoice, reason = selectedLoop("ASTRAL ARRAYS", aaItems, aaSelected, function(v) return v.label end, 4)
    if not aaChoice then return end
    settings.useAA = aaChoice.value

    local oc
    oc, reason = chooseNumber("OVERCLOCK", {0,1,2,3}, settings.overclocks, 5)
    if not oc then return end
    settings.overclocks = oc

    result = scanHardware(targetIndex)
    local transposers = result.transposers or {}
    local used = {}
    local h2, he, plasma

    if settings.useAA then
        plasma, reason = chooseTransposer("ПРИВЯЗКА PLASMA", transposers, used, "plasma", old.transposerPlasma, 6)
        if not plasma then
            waitContinue("Для AA нужен плазменный транспозер.")
            return
        end
        used[plasma.address] = true
    else
        h2, reason = chooseTransposer("ПРИВЯЗКА H₂", transposers, used, "hydrogen", old.transposerH2, 6)
        if not h2 then
            waitContinue("Нужен H₂ транспозер.")
            return
        end
        used[h2.address] = true

        he, reason = chooseTransposer("ПРИВЯЗКА He", transposers, used, "helium", old.transposerHe, 7)
        if not he then
            waitContinue("Нужен He транспозер.")
            return
        end
        used[he.address] = true
    end

    local components = {
        eoh=controller.address,
        eohController=controller.address,
        transposerH2=h2 and h2.address or nil,
        transposerHydrogen=h2 and h2.address or nil,
        transposerHe=he and he.address or nil,
        transposerHelium=he and he.address or nil,
        transposerPlasma=plasma and plasma.address or nil,
        transposerPlasmaList=plasma and {plasma.address} or {},
        transposers={},
    }
    for _, item in ipairs(transposers) do
        if used[item.address] then
            components.transposers[#components.transposers+1] = {
                address=item.address,
                role=item.address == (h2 and h2.address) and "hydrogen"
                    or item.address == (he and he.address) and "helium"
                    or item.address == (plasma and plasma.address) and "plasma" or nil,
                sourceSide=item.sourceSide,
                sourceSideName=item.sourceSideName,
                targetSide=item.targetSide,
                targetSideName=item.targetSideName,
            }
        end
    end

    settings.mode = "production"
    if not summary(settings, controller, h2, he, plasma) then return end

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
        text(4, 10, "Tier T" .. tostring(settings.tier) .. " | " .. tostring(settings.planet), C.text)
        text(4, 11, "AA " .. (settings.useAA and "ON" or "OFF") .. " | OC " .. tostring(settings.overclocks), C.text)
        text(4, 13, "Оборудование привязано к этому EOH.", C.ok)
    else
        text(4, 8, "✗ Не удалось сохранить конфигурацию.", C.ring_down)
    end
    waitContinue("ENTER = вернуться в Main")
end

return {runSetup=runSetup}
