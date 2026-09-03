-- ============================================================
-- EOH CONTROLLER - SETUP WIZARD
-- ============================================================
-- Регистрация конкретного EOH и конкретных каналов подачи.
--
-- Wizard:
--   1) Сканирует все EOH и транспозеры.
--   2) Позволяет выбрать КОНКРЕТНЫЙ EOH.
--   3) Позволяет выбрать профиль работы.
--   4) Для каждой нужной жидкости позволяет выбрать
--      конкретный транспозер -> сторону -> tank.
--   5) Считывает transfer rate и сохраняет предварительный план.
--
-- Никаких операций transferFluid() здесь нет.
-- Setup только читает конфигурацию оборудования.
-- ============================================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;" .. package.path

local component = require("component")
local event = require("event")
local computer = require("computer")
local theme = require("theme")
local config = require("config")
local registry = require("registry")
local core = require("eoh_core")
local recipes = require("recipes")
local logger = require("logger")

local gpu = component.isAvailable("gpu") and component.gpu
if not gpu then
    print("GPU not found")
    return
end

theme.setGPU(gpu)
registry.load()
logger.init()
logger.load()

local W, H = gpu.getResolution()
local C = theme.C

local function clean(value)
    return tostring(value or ""):gsub("§.", "")
end

local function lower(value)
    return clean(value):lower()
end

local function invoke(address, method, ...)
    return pcall(component.invoke, address, method, ...)
end

local function fluidName(data)
    if type(data) ~= "table" then return nil end
    return data.name or data.fluidName or data.id
end

local function fluidAmount(data)
    if type(data) ~= "table" then return 0 end
    return tonumber(data.amount or data.level or 0) or 0
end

local function frame(title)
    theme.fill(1, 1, W, H, " ", C.text, C.bg)
    theme.text(1, 1, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)
    theme.text(2, 2, "==[ EOH SETUP ]", C.title, C.bg)
    theme.text(3, 3, clean(title or "Setup Wizard"), C.dim, C.bg)
    theme.text(1, 4, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)

    for y = 5, H - 3 do
        theme.text(1, y, "|", C.border, C.bg)
        theme.text(W, y, "|", C.border, C.bg)
    end

    theme.text(1, H - 2, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)
    theme.text(1, H, "+" .. string.rep("-", math.max(0, W - 2)) .. "+", C.border, C.bg)
end

local function waitKey()
    event.pull("key_down")
end

local function keyNumber()
    local ev = {event.pull("key_down")}
    return ev[3], ev[4]
end

local function askYesNo(prompt)
    frame("Confirmation")
    theme.text(3, 7, prompt, C.text, C.bg)
    theme.text(3, 9, "[Y] Да    [N] Нет", C.key, C.bg)

    while true do
        local code = keyNumber()
        if code == 21 then return true end      -- y
        if code == 49 then return true end      -- Y in some layouts
        if code == 35 then return false end     -- n
        if code == 14 then return false end     -- backspace as cancel
    end
end

local function chooseFromList(title, items, formatter, emptyText)
    while true do
        frame(title)

        if #items == 0 then
            theme.text(3, 7, emptyText or "Nothing found.", C.warn, C.bg)
            theme.text(3, H - 4, "Press any key to return.", C.dim, C.bg)
            waitKey()
            return nil
        end

        local maxRows = math.max(1, H - 10)
        local page = 1
        local pages = math.ceil(#items / maxRows)

        while true do
            frame(title)
            local startIndex = (page - 1) * maxRows + 1
            local endIndex = math.min(#items, startIndex + maxRows - 1)

            for i = startIndex, endIndex do
                local row = 5 + (i - startIndex)
                theme.text(3, row, string.format("[%d] %s", i, formatter(items[i])), C.text, C.bg)
            end

            theme.text(3, H - 4, string.format("Page %d/%d | number = select | N = next page | B = back", page, pages), C.dim, C.bg)

            local ch, code = keyNumber()

            if code == 14 then
                return nil
            elseif ch == 78 or ch == 110 then -- N/n
                if page < pages then page = page + 1 else page = 1 end
            elseif ch >= 49 and ch <= 57 then
                local selected = ch - 48
                if selected >= 1 and selected <= #items then
                    return items[selected]
                end
            end
        end
    end
end

local function scanEOHs()
    local found = {}

    for address, _ in component.list("gt_machine") do
        local ok, name = invoke(address, "getName")
        name = ok and clean(name) or ""
        local lname = lower(name)

        if lname:find("multimachine.em.eye_of_harmony", 1, true)
            or lname:find("eye_of_harmony", 1, true)
            or lname:find("eye of harmony", 1, true) then

            table.insert(found, {
                address = address,
                name = name ~= "" and name or "Eye of Harmony"
            })
        end
    end

    table.sort(found, function(a, b) return a.address < b.address end)
    return found
end

local function scanTransposers()
    local found = {}

    for address, _ in component.list("transposer") do
        local okRate, rate = invoke(address, "getFluidTransferRate")
        rate = tonumber(okRate and rate or 0) or 0

        local t = {
            address = address,
            rate = rate,
            eohSide = nil,
            endpoints = {}
        }

        -- Собираем ВСЕ стороны с tank'ами.
        for side = 0, 5 do
            local okName, name = invoke(address, "getInventoryName", side)
            local okCount, count = invoke(address, "getTankCount", side)

            name = clean(okName and name or "")
            count = tonumber(okCount and count or 0) or 0

            if count > 0 then
                local isEOH = lower(name) == "gt.blockmachines"

                if isEOH then
                    t.eohSide = side
                else
                    for tank = 1, count do
                        local okFluid, data = invoke(address, "getFluidInTank", side, tank)
                        local fname = okFluid and fluidName(data) or nil
                        local amount = okFluid and fluidAmount(data) or 0

                        local okCap, capacity = invoke(address, "getTankCapacity", side, tank)
                        capacity = tonumber(okCap and capacity or 0) or 0

                        table.insert(t.endpoints, {
                            side = side,
                            tank = tank,
                            inventory = name ~= "" and name or "unknown",
                            fluid = fname,
                            amount = amount,
                            capacity = capacity
                        })
                    end
                end
            end
        end

        if t.eohSide ~= nil and #t.endpoints > 0 then
            table.insert(found, t)
        end
    end

    table.sort(found, function(a, b) return a.address < b.address end)
    return found
end

local function allEndpoints(transposers)
    local result = {}

    for ti, t in ipairs(transposers) do
        for _, e in ipairs(t.endpoints) do
            table.insert(result, {
                tindex = ti,
                transposer = t,
                side = e.side,
                tank = e.tank,
                inventory = e.inventory,
                fluid = e.fluid,
                amount = e.amount,
                capacity = e.capacity
            })
        end
    end

    table.sort(result, function(a, b)
        if a.tindex ~= b.tindex then return a.tindex < b.tindex end
        if a.side ~= b.side then return a.side < b.side end
        return a.tank < b.tank
    end)

    return result
end

local function fluidMatches(wanted, actual)
    if actual == nil or actual == "" then
        return true -- пустой резервуар разрешаем выбрать
    end
    return lower(actual) == lower(wanted)
end

local function formatRate(rate)
    return string.format("%.0f L/s", tonumber(rate) or 0)
end

local function selectEndpoint(all, wanted, used, usedTransposers)
    local available = {}

    for _, e in ipairs(all) do
        local key = e.transposer.address .. ":" .. tostring(e.side) .. ":" .. tostring(e.tank)
        if not used[key] and not usedTransposers[e.transposer.address] and fluidMatches(wanted, e.fluid) then
            table.insert(available, e)
        end
    end

    if #available == 0 then
        frame("Source selection")
        theme.text(3, 7, "Подходящий резервуар не найден для: " .. wanted, C.err, C.bg)
        theme.text(3, 9, "Проверьте, что резервуар подключён к transposer и", C.dim, C.bg)
        theme.text(3, 10, "в нём либо есть нужная жидкость, либо он пуст.", C.dim, C.bg)
        theme.text(3, H - 4, "Press any key.", C.dim, C.bg)
        waitKey()
        return nil
    end

    local selected = chooseFromList(
        "Select source for " .. wanted,
        available,
        function(e)
            local fluid = e.fluid or "EMPTY"
            local amount = string.format("%.0f L", e.amount or 0)
            return string.format(
                "T%d  side %d tank %d | %-18s | %s / %s | rate %s",
                e.tindex,
                e.side,
                e.tank,
                e.inventory,
                fluid,
                amount,
                formatRate(e.transposer.rate)
            )
        end,
        "No compatible source tanks found."
    )

    return selected
end

local function chooseMode()
    local items = {
        {id = "production", label = "Обычный фарм (H2 + He)"},
        {id = "production_aa", label = "Фарм с Astral Arrays (Plasma)"},
        {id = "power", label = "Энергия (Deep Dark T9)"}
    }

    while true do
        local selected = chooseFromList(
            "Select EOH work profile",
            items,
            function(item) return item.label end
        )
        if selected then return selected.id end
    end
end

local function chooseTier()
    local items = {}
    for tier = 1, 9 do
        local recipe = recipes.get(tier)
        if recipe then
            table.insert(items, {tier = tier, label = recipe.display})
        end
    end

    local selected = chooseFromList(
        "Select planet tier",
        items,
        function(item) return item.label end
    )

    return selected and selected.tier or nil
end

local function confirmExisting(entry)
    frame("EOH already registered")
    theme.text(3, 7, "This EOH is already registered:", C.warn, C.bg)
    theme.text(3, 9, entry.name or "Unknown", C.text, C.bg)
    theme.text(3, 10, "Setup will replace its saved hardware mapping.", C.dim, C.bg)
    theme.text(3, H - 4, "Y = continue    N = cancel", C.key, C.bg)

    while true do
        local ch = keyNumber()
        if ch == 89 or ch == 121 then return true end -- Y/y
        if ch == 78 or ch == 110 then return false end -- N/n
    end
end

local function buildChannel(selected)
    return {
        fluid = selected.wanted,
        transposer = selected.transposer.address,
        address = selected.transposer.address,
        sourceSide = selected.side,
        eohSide = selected.transposer.eohSide,
        sourceTank = selected.tank,
        rate = selected.transposer.rate,
        sourceInventory = selected.inventory,
        sourceFluid = selected.fluid,
        sourceCapacity = selected.capacity
    }
end

local function registerEOH(eoh, transposers)
    local existing = registry.get(eoh.address)
    if existing and not confirmExisting(existing) then
        return
    end

    local mode = chooseMode()
    local tier

    if mode == "power" then
        tier = 9
    else
        tier = chooseTier()
        if not tier then return end
    end

    local recipe = recipes.get(tier)
    if not recipe then
        frame("Setup error")
        theme.text(3, 7, "Recipe not found.", C.err, C.bg)
        waitKey()
        return
    end

    -- Проверяем, что выбранный профиль совместим с количеством каналов.
    local requiredFluids
    if mode == "production_aa" then
        requiredFluids = {"rawstarmatter"}
    else
        requiredFluids = {"hydrogen", "helium"}
    end

    if #transposers == 0 then
        frame("Setup error")
        theme.text(3, 7, "No configured transposers found.", C.err, C.bg)
        waitKey()
        return
    end

    local endpoints = allEndpoints(transposers)
    local used = {}
    local usedTransposers = {}
    local channels = {}

    for _, wanted in ipairs(requiredFluids) do
        local selected = selectEndpoint(endpoints, wanted, used, usedTransposers)
        if not selected then return end

        selected.wanted = wanted
        table.insert(channels, buildChannel(selected))

        local key = selected.transposer.address .. ":" .. tostring(selected.side) .. ":" .. tostring(selected.tank)
        used[key] = true
        usedTransposers[selected.transposer.address] = true
    end

    local entry = {
        id = eoh.address,
        name = recipe.display,
        adapter_addr = eoh.address,
        mode = mode,
        tier = tier,
        recipe_display = recipe.display,
        channels = channels,
        created_at = os.time()
    }

    -- Тяжёлая калькуляция делается только при регистрации.
    entry.calculation = core.calculatePlan(entry, recipe)

    local ok = registry.add(entry)

    frame("Registration complete")

    if ok then
        theme.text(3, 6, "[OK] EOH registered.", C.ok, C.bg)
    else
        theme.text(3, 6, "[ERROR] Failed to save registry.", C.err, C.bg)
    end

    theme.text(3, 8, "EOH: " .. (eoh.name or "Eye of Harmony"), C.text, C.bg)
    theme.text(3, 9, "Mode: " .. mode, C.text, C.bg)
    theme.text(3, 10, "Recipe: " .. recipe.display, C.text, C.bg)
    theme.text(3, 12, "Selected channels:", C.title, C.bg)

    local row = 13
    for _, ch in ipairs(channels) do
        if row <= H - 6 then
            theme.text(3, row, string.format(
                "%s -> T %s | source side %d tank %d | %.0f L/s",
                ch.fluid,
                ch.transposer:sub(1, 8),
                ch.sourceSide,
                ch.sourceTank,
                ch.rate
            ), C.text, C.bg)
            row = row + 1
        end
    end

    if entry.calculation then
        theme.text(3, row + 1, "Pre-calculated transfer plan:", C.title, C.bg)
        row = row + 2
        for fluid, plan in pairs(entry.calculation.fluids) do
            if row <= H - 5 then
                theme.text(3, row, string.format(
                    "%s: %s L | estimated channel time %.2fs",
                    fluid,
                    tostring(plan.required),
                    plan.channels[1] and (plan.channels[1].amount / math.max(1, plan.channels[1].channel.rate)) or 0
                ), C.dim, C.bg)
                row = row + 1
            end
        end
    end

    theme.text(3, H - 4, "Press any key.", C.dim, C.bg)
    waitKey()
end

local function run()
    frame("Scanning for EOH and transposers...")

    local eohs = scanEOHs()
    local transposers = scanTransposers()

    if #eohs == 0 then
        theme.text(3, 7, "EOH not found.", C.err, C.bg)
        theme.text(3, 9, "Make sure the Adapter sees the multiblock controller.", C.dim, C.bg)
        waitKey()
        return
    end

    if #transposers == 0 then
        theme.text(3, 7, "No suitable transposers found.", C.err, C.bg)
        theme.text(3, 9, "Each transposer must expose an EOH side and source tank side.", C.dim, C.bg)
        waitKey()
        return
    end

    -- Показываем статус регистрации прямо в списке EOH.
    local selected = chooseFromList(
        "Select EOH to configure",
        eohs,
        function(e)
            local marker = registry.get(e.address) and "REGISTERED" or "NEW"
            return string.format(
                "%-32s | %s | %s",
                e.name,
                marker,
                e.address:sub(1, 8)
            )
        end,
        "No EOH found."
    )

    if not selected then return end

    registerEOH(selected, transposers)
end

run()
