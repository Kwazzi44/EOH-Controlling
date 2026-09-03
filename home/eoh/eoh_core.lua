-- ============================================================
-- EOH CONTROLLER - CORE / PHASE 2
-- ============================================================
-- Реальная интеграция с EOH через OpenComputers Adapter.
--
-- Phase 2 умеет:
--   * искать EOH и оба транспозера;
--   * читать прямые методы EOH;
--   * разбирать 27 строк Sensor Information;
--   * читать H2 / He / Raw Stellar Plasma;
--   * выбирать рецепт и режим входа;
--   * рассчитывать дефицит жидкостей;
--   * читать доступный запас в AE2 Fluid Interface;
--   * строить план подачи без фактического transfer.
--
-- Реальная перекачка намеренно заблокирована config.allow_fluid_transfer=false.
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
    lastScan = 0
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

local function parseFirstNumber(text)
    text = cleanText(text)

    -- Берём первое числовое значение после двоеточия, если оно есть.
    local tail = text:match(":%s*([%-%d][%d%.,%s]*)")
    local value = tail or text:match("([%-%d][%d%.,%s]*)")
    if not value then
        return nil
    end

    value = value:gsub("%s+", "")

    -- Сенсор EOH использует точку для дробей в наблюдаемом выводе.
    -- Убираем разделители тысяч вида 1,000, но сохраняем десятичную точку.
    value = value:gsub("(%d),(%d%d%d)", "%1%2")

    return tonumber(value)
end

local function parsePercent(text)
    local number = parseFirstNumber(text)
    if not number then return nil end
    return number
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

    -- Резерв: смотрим сенсор, не изменяя состояние машины.
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

    logger.info(
        "CORE",
        string.format(
            "Scan OK: EOH=%s, transposers=%d",
            EOH.state.controller.name,
            #EOH.state.transposers
        )
    )

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
    if not sensor then
        return nil, err
    end

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

        -- В наблюдаемом EOH-потоке поля жидкостей находятся на строках 13-16.
        -- Дополнительно проверяем текст, чтобы парсер не зависел только от индекса.
        if index == 14 or contains(l, "водород") or contains(l, "hydrogen") then
            if value then data.hydrogen = value end
        elseif index == 15 or contains(l, "гелий") or contains(l, "helium") then
            if value then data.helium = value end
        elseif index == 13 or contains(l, "сырая звёздная плазм")
            or contains(l, "raw stellar plasma") or contains(l, "rawstarmatter") then
            if value then data.plasma = value end
        end

        if contains(l, "астральных массивов") or contains(l, "astral arrays") then
            if not contains(l, "действующие") and not contains(l, "active") then
                data.astralArrays = value or data.astralArrays
            else
                data.activeAstralArrays = value or data.activeAstralArrays
            end
        end

        if contains(l, "шанс успеха рецепта") or contains(l, "recipe success") then
            data.successChance = parsePercent(line)
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
        return {
            hydrogen = 0,
            helium = 0,
            plasma = 0
        }, err
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

    local result = {
        amount = okLevel and tonumber(level) or 0,
        name = nil,
        label = nil,
        capacity = nil
    }

    if okFluid and type(fluid) == "table" then
        result.name = fluid.name
        result.label = fluid.label
        result.amount = tonumber(fluid.amount) or result.amount
    end

    local okCapacity, capacity = safeInvoke(
        transposer.address,
        "getTankCapacity",
        transposer.fluidSide,
        tank
    )

    if okCapacity then
        result.capacity = tonumber(capacity)
    end

    return result
end

function EOH.getSourceFluidState()
    local result = { transposers = {} }

    for _, transposer in ipairs(EOH.state.transposers) do
        table.insert(result.transposers, {
            address = transposer.address,
            hydrogen = readSourceTank(transposer, "hydrogen"),
            helium = readSourceTank(transposer, "helium"),
            plasma = readSourceTank(transposer, "plasma")
        })
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

    local result = {
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

    if overclocks > 0 then
        result.calculationNote = "OC scaling is not applied in Phase 2 until EOH parameter rules are verified."
    end

    return result
end

local function tolerantMissing(required, current)
    required = tonumber(required) or 0
    current = tonumber(current) or 0
    local tolerance = tonumber(config.fluid_tolerance) or 0

    if required <= 0 then
        return 0
    end

    local epsilon = required * tolerance
    return math.max(0, required - current - epsilon)
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

    local function sourceTotal(fluidKey)
        local total = 0
        for _, t in ipairs(sources.transposers) do
            total = total + (t[fluidKey].amount or 0)
        end
        return total
    end

    for _, fluidKey in ipairs({"hydrogen", "helium", "plasma"}) do
        local missing = result.missing[fluidKey]
        local available = sourceTotal(fluidKey)

        if missing > 0 then
            if available < missing then
                result.ready = false
                table.insert(
                    result.warnings,
                    FLUIDS[fluidKey].label .. ": source shortage"
                )
            end
        end
    end

    if overclocks > 0 then
        table.insert(result.warnings, result.recipe.calculationNote)
    end

    return result
end

function EOH.previewFluidTransfer(fluidKey, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return {
            fluid = fluidKey,
            requested = 0,
            planned = 0,
            remaining = 0,
            operations = {}
        }
    end

    local spec = FLUIDS[fluidKey]
    if not spec then
        return nil, "Unknown fluid: " .. tostring(fluidKey)
    end

    local sources = {}
    for _, transposer in ipairs(EOH.state.transposers) do
        local src = readSourceTank(transposer, fluidKey)
        table.insert(sources, {
            transposer = transposer,
            amount = src.amount
        })
    end

    table.sort(sources, function(a, b)
        return a.amount > b.amount
    end)

    local remaining = amount
    local operations = {}

    for _, item in ipairs(sources) do
        if remaining <= 0 then break end
        local portion = math.min(remaining, item.amount)
        if portion > 0 then
            table.insert(operations, {
                address = item.transposer.address,
                sourceSide = item.transposer.fluidSide,
                sinkSide = item.transposer.eohSide,
                sourceTank = spec.tank,
                amount = portion
            })
            remaining = remaining - portion
        end
    end

    return {
        fluid = fluidKey,
        requested = amount,
        planned = amount - remaining,
        remaining = remaining,
        operations = operations,
        executable = remaining <= 0
    }
end

function EOH.transferFluid(fluidKey, amount)
    if not config.allow_fluid_transfer then
        return false, 0, "Fluid transfer is disabled in Phase 2 (dry run)"
    end

    local plan, err = EOH.previewFluidTransfer(fluidKey, amount)
    if not plan then
        return false, 0, err
    end

    if not plan.executable then
        return false, plan.planned, "Insufficient source fluid"
    end

    local total = 0

    for _, op in ipairs(plan.operations) do
        local ok, transferred = safeInvoke(
            op.address,
            "transferFluid",
            op.sourceSide,
            op.sinkSide,
            op.amount,
            op.sourceTank
        )

        if not ok then
            logger.error("CORE", "transferFluid failed: " .. tostring(transferred))
            return false, total, tostring(transferred)
        end

        transferred = tonumber(transferred) or 0
        total = total + transferred
    end

    logger.info("CORE", string.format("Transferred %d L of %s", total, fluidKey))
    return total >= amount, total
end

function EOH.inspect()
    local status = EOH.getStatus()
    local sensor = EOH.getSensorData()
    local fluids = EOH.getFluids()
    local source = EOH.getSourceFluidState()

    return {
        controller = EOH.getController(),
        transposers = EOH.getTransposers(),
        status = status,
        sensor = sensor,
        fluids = fluids,
        sourceFluids = source
    }
end

return EOH
