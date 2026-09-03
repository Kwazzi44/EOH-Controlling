-- ============================================================
-- EOH CONTROLLER - CORE / PHASE 3
-- ============================================================
-- Реальная интеграция с EOH через OpenComputers Adapter.
--
-- Phase 3:
--   * scan EOH + 2 transposer;
--   * читает прямые методы EOH;
--   * разбирает sensor information;
--   * читает H2 / He / Raw Stellar Plasma;
--   * читает источники через AE2 Fluid Interface;
--   * строит план подачи;
--   * умеет безопасно выполнить ОДИН ручной transfer в test-режиме;
--   * после transfer всегда проверяет результат;
--   * по умолчанию реальная перекачка выключена.
--
-- ВАЖНО:
-- В EOH рецептурные количества могут быть значительно больше
-- объёма одного input hatch. Поэтому Phase 3 НЕ пытается заранее
-- залить весь рецепт. Автоматический непрерывный режим будет
-- добавлен после проверки ручного теста.
-- ============================================================

local component = require("component")
local config = require("config")
local logger = require("logger")
local recipes = require("recipes")

local EOH = {}

EOH.state = {
    controller = nil,
    transposers = {},
    scanned = false,
    lastError = nil,
    lastScan = 0,
    lastTransfer = nil
}

local FLUIDS = {
    hydrogen = {
        tank = 1,
        names = {"hydrogen", "водород"},
        label = "Hydrogen"
    },
    helium = {
        tank = 2,
        names = {"helium", "гелий"},
        label = "Helium"
    },
    plasma = {
        tank = 3,
        names = {
            "rawstarmatter",
            "raw stellar plasma",
            "сырой звёздной плазм",
            "конденсированной сырой звёздной плазм"
        },
        label = "Raw Stellar Plasma"
    }
}

local function safeInvoke(address, method, ...)
    return pcall(component.invoke, address, method, ...)
end

local function cleanText(value)
    return tostring(value or ""):gsub("§.", "")
end

local function lower(value)
    return cleanText(value):lower()
end

local function contains(text, needle)
    return lower(text):find(lower(needle), 1, true) ~= nil
end

local function parseAmount(text)
    text = cleanText(text)

    local number, unit = text:match("([%d][%d%.,]*%d?)%s*([kKmMbBtT]?)")
    if not number then
        number = text:match("([%d][%d%.,]*%d?)")
    end
    if not number then return nil end

    -- В сенсоре EOH точка используется как десятичный разделитель.
    -- Запятые в формате 1,000,000 трактуем как разделители тысяч.
    number = number:gsub("(%d),(%d%d%d)", "%1%2")
    number = number:gsub("(%d),(%d%d%d)", "%1%2")

    local value = tonumber(number)
    if not value then return nil end

    unit = (unit or ""):lower()
    if unit == "k" then value = value * 1e3 end
    if unit == "m" then value = value * 1e6 end
    if unit == "b" then value = value * 1e9 end
    if unit == "t" then value = value * 1e12 end

    return value
end

local function parseFirstNumber(text)
    return parseAmount(text)
end

local function isEOH(address)
    local ok, name = safeInvoke(address, "getName")
    if ok and type(name) == "string" then
        local n = lower(name)
        if n:find("multimachine.em.eye_of_harmony", 1, true)
            or n:find("eye.of.harmony", 1, true)
            or n:find("eye_of_harmony", 1, true)
            or n:find("eye of harmony", 1, true) then
            return true
        end
    end

    local okSensor, sensor = safeInvoke(address, "getSensorInformation")
    if okSensor and type(sensor) == "table" then
        for _, line in ipairs(sensor) do
            local n = lower(line)
            if n:find("eye of harmony", 1, true)
                or n:find("eye_of_harmony", 1, true) then
                return true
            end
        end
    end

    return false
end

local function inspectTransposer(address)
    local fluidSide = nil
    local eohSide = nil

    for side = 0, 5 do
        local okName, name = safeInvoke(address, "getInventoryName", side)
        local okCount, count = safeInvoke(address, "getTankCount", side)

        name = okName and tostring(name or "") or ""
        count = okCount and tonumber(count or 0) or 0
        local n = lower(name)

        if n == "tile.fluid_interface" and count == 6 then
            fluidSide = side
        elseif n == "gt.blockmachines" and count == 1 then
            eohSide = side
        end
    end

    if fluidSide == nil or eohSide == nil then
        return nil
    end

    return {
        address = address,
        fluidSide = fluidSide,
        eohSide = eohSide,
        tanks = {
            hydrogen = config.transposer.hydrogen_tank,
            helium = config.transposer.helium_tank,
            plasma = config.transposer.plasma_tank
        }
    }
end

function EOH.scan()
    EOH.state.controller = nil
    EOH.state.transposers = {}
    EOH.state.lastError = nil
    EOH.state.scanned = false

    for address, _ in component.list("gt_machine") do
        if isEOH(address) then
            local ok, name = safeInvoke(address, "getName")
            EOH.state.controller = {
                address = address,
                name = ok and cleanText(name) or "Eye of Harmony"
            }
            break
        end
    end

    if not EOH.state.controller then
        EOH.state.lastError = "EOH controller not found"
        EOH.state.scanned = true
        logger.error("CORE", EOH.state.lastError)
        return false, EOH.state.lastError
    end

    for address, _ in component.list("transposer") do
        local t = inspectTransposer(address)
        if t then
            table.insert(EOH.state.transposers, t)
        end
    end

    table.sort(EOH.state.transposers, function(a, b)
        return a.address < b.address
    end)

    if config.require_two_transposers and #EOH.state.transposers < 2 then
        EOH.state.lastError = "Required 2 EOH transposers; found " .. #EOH.state.transposers
        EOH.state.scanned = true
        logger.error("CORE", EOH.state.lastError)
        return false, EOH.state.lastError
    end

    EOH.state.scanned = true
    EOH.state.lastScan = os.clock and os.clock() or 0

    logger.info("CORE", string.format(
        "Scan OK: EOH=%s, transposers=%d",
        EOH.state.controller.name,
        #EOH.state.transposers
    ))

    return true
end

function EOH.getController()
    return EOH.state.controller
end

function EOH.getTransposers()
    return EOH.state.transposers
end

function EOH.getStatus()
    if not EOH.state.controller then
        return {
            active = false,
            hasWork = false,
            workAllowed = false,
            progress = 0,
            maxProgress = 0,
            percent = 0,
            error = EOH.state.lastError
        }
    end

    local address = EOH.state.controller.address
    local okActive, active = safeInvoke(address, "isMachineActive")
    local okWork, hasWork = safeInvoke(address, "hasWork")
    local okAllowed, allowed = safeInvoke(address, "isWorkAllowed")
    local okProgress, progress = safeInvoke(address, "getWorkProgress")
    local okMax, maxProgress = safeInvoke(address, "getWorkMaxProgress")

    progress = okProgress and tonumber(progress) or 0
    maxProgress = okMax and tonumber(maxProgress) or 0

    local percent = 0
    if maxProgress > 0 then
        percent = math.max(0, math.min(100, progress * 100 / maxProgress))
    end

    return {
        active = okActive and active == true,
        hasWork = okWork and hasWork == true,
        workAllowed = okAllowed and allowed == true,
        progress = progress,
        maxProgress = maxProgress,
        percent = percent,
        error = nil
    }
end

function EOH.getSensorInformation()
    if not EOH.state.controller then
        return nil, "EOH not scanned"
    end

    local ok, data = safeInvoke(
        EOH.state.controller.address,
        "getSensorInformation"
    )

    if not ok then
        return nil, tostring(data)
    end

    if type(data) ~= "table" then
        return nil, "Unexpected sensor data type: " .. type(data)
    end

    return data
end

function EOH.getRawSensorLines()
    return EOH.getSensorInformation()
end

function EOH.getSensorData()
    local sensor, err = EOH.getSensorInformation()
    if not sensor then return nil, err end

    local data = {
        lines = sensor,
        hydrogen = 0,
        helium = 0,
        plasma = 0,
        astralArrays = 0,
        successChance = nil,
        activeAstralArrays = 0,
        totalOverclocks = 0,
        recipeInput = nil,
        recipeOutput = nil
    }

    for index, rawLine in ipairs(sensor) do
        local line = cleanText(rawLine)
        local l = lower(line)
        local value = parseFirstNumber(line)

        if index == 14 or contains(l, "водород") or contains(l, "hydrogen") then
            if value then data.hydrogen = value end
        elseif index == 15 or contains(l, "гелий") or contains(l, "helium") then
            if value then data.helium = value end
        elseif index == 13 or contains(l, "сырая звёздная плазм")
            or contains(l, "raw stellar plasma") or contains(l, "rawstarmatter") then
            if value then data.plasma = value end
        end

        if contains(l, "астральных массивов") or contains(l, "astral arrays") then
            if contains(l, "действующие") or contains(l, "active") then
                data.activeAstralArrays = value or data.activeAstralArrays
            else
                data.astralArrays = value or data.astralArrays
            end
        end

        if contains(l, "шанс успеха рецепта") or contains(l, "recipe success") then
            data.successChance = value
        elseif contains(l, "вход рецепта") or contains(l, "recipe input") then
            data.recipeInput = cleanText(line)
        elseif contains(l, "выход рецепта") or contains(l, "recipe output") then
            data.recipeOutput = cleanText(line)
        elseif contains(l, "всего потеплений") or contains(l, "всего параллелей") or contains(l, "overclocks") then
            data.totalOverclocks = value or data.totalOverclocks
        end
    end

    return data
end

function EOH.getFluids()
    local data, err = EOH.getSensorData()
    if not data then
        return {hydrogen = 0, helium = 0, plasma = 0}, err
    end

    return {
        hydrogen = data.hydrogen,
        helium = data.helium,
        plasma = data.plasma
    }
end

local function readSourceTank(transposer, fluidKey)
    local tank = transposer.tanks[fluidKey]

    local okFluid, fluid = safeInvoke(
        transposer.address,
        "getFluidInTank",
        transposer.fluidSide,
        tank
    )

    local okLevel, level = safeInvoke(
        transposer.address,
        "getTankLevel",
        transposer.fluidSide,
        tank
    )

    local okCapacity, capacity = safeInvoke(
        transposer.address,
        "getTankCapacity",
        transposer.fluidSide,
        tank
    )

    local result = {
        amount = okLevel and tonumber(level) or 0,
        name = nil,
        label = nil,
        capacity = okCapacity and tonumber(capacity) or nil
    }

    if okFluid and type(fluid) == "table" then
        result.name = fluid.name
        result.label = fluid.label
        result.amount = tonumber(fluid.amount) or result.amount
    end

    return result
end

function EOH.getSourceFluidState()
    local result = {transposers = {}}

    for _, transposer in ipairs(EOH.state.transposers) do
        local item = {
            address = transposer.address,
            hydrogen = readSourceTank(transposer, "hydrogen"),
            helium = readSourceTank(transposer, "helium"),
            plasma = readSourceTank(transposer, "plasma"),
            transferRate = 0
        }

        local okRate, rate = safeInvoke(
            transposer.address,
            "getFluidTransferRate"
        )

        if okRate then
            item.transferRate = tonumber(rate) or 0
        end

        table.insert(result.transposers, item)
    end

    return result
end

function EOH.getRecipe(tier)
    return recipes.get(tonumber(tier))
end

function EOH.getRecipeNeeds(tier, mode, useAA, overclocks)
    tier = tonumber(tier) or config.planet_tier
    mode = mode or "production"
    useAA = useAA == true
    overclocks = tonumber(overclocks) or 0

    local recipe
    if mode == "power" then
        recipe = recipes.get(9)
        useAA = false
        overclocks = 0
    else
        recipe = recipes.get(tier)
    end

    if not recipe then
        return nil, "Unknown tier: " .. tostring(tier)
    end

    return {
        mode = mode,
        tier = tonumber(mode == "power" and 9 or tier),
        planet = recipe.planet,
        display = recipe.display,
        starMatter = recipe.starMatter,
        duration = recipe.duration,
        useAA = useAA,
        overclocks = overclocks,
        source = recipe,
        inputMode = useAA and "plasma" or "hydrogen_helium",
        hydrogen = useAA and 0 or recipe.hydrogen,
        helium = useAA and 0 or recipe.helium,
        plasma = useAA and recipe.plasma or 0,
        overclockApplied = false
    }
end

local function tolerantMissing(required, current)
    required = tonumber(required) or 0
    current = tonumber(current) or 0
    local tolerance = tonumber(config.fluid_tolerance) or 0

    if required <= 0 then return 0 end

    local epsilon = required * tolerance
    return math.max(0, required - current - epsilon)
end

local function sourceTotal(sources, fluidKey)
    local total = 0
    for _, t in ipairs(sources.transposers) do
        total = total + (t[fluidKey].amount or 0)
    end
    return total
end

function EOH.calculateFluidPlan(tier, mode, useAA, overclocks)
    local needs, err = EOH.getRecipeNeeds(tier, mode, useAA, overclocks)
    if not needs then return nil, err end

    local current = EOH.getFluids()
    local sources = EOH.getSourceFluidState()

    local result = {
        recipe = needs,
        current = current,
        required = {
            hydrogen = needs.hydrogen,
            helium = needs.helium,
            plasma = needs.plasma
        },
        missing = {
            hydrogen = tolerantMissing(needs.hydrogen, current.hydrogen),
            helium = tolerantMissing(needs.helium, current.helium),
            plasma = tolerantMissing(needs.plasma, current.plasma)
        },
        source = sources,
        ready = true,
        warnings = {}
    }

    for _, fluidKey in ipairs({"hydrogen", "helium", "plasma"}) do
        local missing = result.missing[fluidKey]
        local available = sourceTotal(sources, fluidKey)

        if missing > 0 and available < math.min(missing, config.fluid_control.max_transfer_per_call) then
            result.ready = false
            table.insert(result.warnings,
                FLUIDS[fluidKey].label .. " source buffer is low ("
                .. math.floor(available) .. " L)")
        end
    end

    return result
end

function EOH.getTransferRate()
    local rates = {}
    for _, t in ipairs(EOH.state.transposers) do
        local ok, value = safeInvoke(t.address, "getFluidTransferRate")
        rates[#rates + 1] = ok and tonumber(value) or 0
    end
    return rates
end

local function freeSpaceEOH(fluidKey)
    -- В GTNH EOH input hatch proxy у нас даёт только один tank на side 3.
    -- Пока нет отдельного API свободного места конкретно H2/He/Plasma,
    -- используем консервативный лимит из config.fluid_control.
    return config.fluid_control.max_transfer_per_call
end

local function chooseTransposer(fluidKey, requested)
    local best = nil
    local bestAmount = -1

    for _, t in ipairs(EOH.state.transposers) do
        local source = readSourceTank(t, fluidKey)
        if source.amount > bestAmount then
            best = t
            bestAmount = source.amount
        end
    end

    if not best or bestAmount <= 0 then
        return nil, 0
    end

    return best, bestAmount
end

function EOH.transferFluid(fluidKey, amount, forceLive)
    if not EOH.state.scanned then
        return false, "EOH is not scanned"
    end

    if not FLUIDS[fluidKey] then
        return false, "Unknown fluid: " .. tostring(fluidKey)
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return false, "Transfer amount must be positive"
    end

    local live = forceLive == true or config.allow_fluid_transfer == true
    if not live then
        return false, "Fluid transfer is disabled (DRY RUN)"
    end

    amount = math.min(amount, config.fluid_control.max_transfer_per_call)

    local transposer, sourceAvailable = chooseTransposer(fluidKey, amount)
    if not transposer then
        return false, FLUIDS[fluidKey].label .. " source is empty"
    end

    amount = math.min(amount, math.floor(sourceAvailable))
    if amount <= 0 then
        return false, "No source fluid available"
    end

    local startFluids = EOH.getFluids()
    local before = tonumber(startFluids[fluidKey]) or 0

    logger.warn("FLUID", string.format(
        "LIVE TEST: transfer %s %.0f L via %s",
        FLUIDS[fluidKey].label,
        amount,
        transposer.address
    ))

    -- component.invoke() возвращает результаты самого метода трансопозера.
    -- Поэтому здесь отдельно сохраняем result и moved.
    local callOK, transferOK, moved = pcall(
        component.invoke,
        transposer.address,
        "transferFluid",
        transposer.fluidSide,
        transposer.eohSide,
        amount,
        transposer.tanks[fluidKey]
    )

    if not callOK then
        logger.error("FLUID", "transferFluid call error: " .. tostring(transferOK))
        return false, {
            ok = false,
            requested = amount,
            moved = 0,
            before = before,
            after = before,
            observedDelta = 0,
            error = tostring(transferOK),
            transposer = transposer
        }
    end

    if transferOK ~= true then
        logger.error("FLUID", "transferFluid returned failure: " .. tostring(moved))
        return false, {
            ok = false,
            requested = amount,
            moved = tonumber(moved) or 0,
            before = before,
            after = before,
            observedDelta = 0,
            error = "transposer rejected transfer",
            transposer = transposer
        }
    end

    moved = tonumber(moved) or 0

    -- Даём машине один короткий тик, чтобы состояние хранилища успело
    -- обновиться перед повторным чтением.
    if config.fluid_control.verification_delay and config.fluid_control.verification_delay > 0 then
        os.sleep(config.fluid_control.verification_delay)
    end

    local afterFluids = EOH.getFluids()
    local after = tonumber(afterFluids[fluidKey]) or before
    local observedDelta = after - before

    local result = {
        ok = moved > 0,
        requested = amount,
        moved = moved,
        observedDelta = observedDelta,
        before = before,
        after = after,
        transposer = transposer,
        error = moved > 0 and nil or "transporter moved zero liters"
    }

    EOH.state.lastTransfer = result

    if not result.ok then
        logger.error("FLUID", "Transfer returned zero moved amount")
        return false, result
    end

    logger.info("FLUID", string.format(
        "Transfer complete: requested=%.0f moved=%.0f observedDelta=%.0f",
        amount, moved, observedDelta
    ))

    return true, result
end

function EOH.fillTest(fluidKey, amount)
    amount = tonumber(amount) or config.fill_test_amount

    if amount > config.fill_test_amount then
        amount = config.fill_test_amount
    end

    if not config.allow_fluid_transfer then
        return false, "DRY RUN: set allow_fluid_transfer=true in config.lua to enable live test"
    end

    return EOH.transferFluid(fluidKey, amount, true)
end

return EOH
