-- ============================================================
-- EOH CONTROLLER - CORE
-- ============================================================
-- Здесь находится вся логика поиска EOH и двух транспозеров,
-- чтения состояния и безопасной подачи жидкостей.
--
-- ВАЖНО:
-- На первом этапе ядро НЕ запускает рецепт автоматически.
-- Функции transferFluid() работают только по явному вызову.
-- ============================================================

local component = require("component")
local config = require("config")
local logger = require("logger")

local EOH = {}
EOH.state = {
    controller = nil,
    transposers = {},
    scanned = false,
    lastError = nil
}

local FLUIDS = {
    hydrogen = {
        tank = 1,
        names = {"hydrogen", "водород"}
    },
    helium = {
        tank = 2,
        names = {"helium", "гелий"}
    },
    plasma = {
        tank = 3,
        names = {"rawstarmatter", "raw stellar plasma", "сырой звёздной плазм", "конденсированной сырой"}
    }
}

local function safeInvoke(address, method, ...)
    return pcall(component.invoke, address, method, ...)
end

local function lower(value)
    return tostring(value or ""):lower()
end

local function cleanText(value)
    return tostring(value or ""):gsub("§.", "")
end

local function findNumber(text)
    text = cleanText(text)

    -- Ищем число с разделителями тысяч и десятичной частью.
    local value = text:match("([%d][%d%.,%s]*)")
    if not value then return nil end

    value = value:gsub("%s+", ""):gsub(",", "")

    -- Если строка использует запятую как десятичный разделитель,
    -- это будет уточнено на уровне вызывающего кода. Для EOH нам
    -- в первую очередь нужны целые объёмы.
    local number = tonumber(value)
    return number
end

local function containsAny(text, names)
    local s = lower(cleanText(text))
    for _, name in ipairs(names) do
        if s:find(lower(name), 1, true) then
            return true
        end
    end
    return false
end

local function parseFluidLine(line, names)
    if not containsAny(line, names) then return nil end
    return findNumber(line)
end

local function getName(address)
    local methods = {"getName", "getMachineName", "getBlockName", "getCustomName"}

    for _, method in ipairs(methods) do
        local ok, value = safeInvoke(address, method)
        if ok and type(value) == "string" and value ~= "" then
            return cleanText(value)
        end
    end

    return "Unknown"
end

local function isEOH(address)
    local name = lower(getName(address))

    if name:find("eye.of.harmony", 1, true)
        or name:find("eye_of_harmony", 1, true)
        or name:find("eye of harmony", 1, true) then
        return true
    end

    -- Некоторые версии могут отдавать локализованное/внутреннее
    -- имя. В таком случае дополнительно смотрим сенсор.
    local ok, sensor = safeInvoke(address, "getSensorInformation")
    if ok and type(sensor) == "table" then
        for _, line in ipairs(sensor) do
            local clean = lower(cleanText(line))
            if clean:find("eye of harmony", 1, true)
                or clean:find("eye_of_harmony", 1, true) then
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

        name = okName and tostring(name) or ""
        count = okCount and tonumber(count) or 0

        local lname = lower(name)

        if lname == "tile.fluid_interface" and count == 6 then
            fluidSide = side
        end

        if lname == "gt.blockmachines" and count == 1 then
            eohSide = side
        end
    end

    if not fluidSide or not eohSide then
        return nil
    end

    -- Проверяем первые три танка, чтобы не принять случайный
    -- Fluid Interface за наше устройство.
    local expected = {"hydrogen", "helium", "rawstarmatter"}
    local tanksOk = true

    for tank = 1, 3 do
        local ok, fluid = safeInvoke(
            address,
            "getFluidInTank",
            fluidSide,
            tank
        )

        if ok and type(fluid) == "table" and fluid.name then
            local actual = lower(fluid.name)
            if not actual:find(lower(expected[tank]), 1, true) then
                tanksOk = false
            end
        end
    end

    if not tanksOk then
        logger.warn("CORE", "Transposer layout found but tank mapping differs: " .. address)
        -- Не отбрасываем устройство: на пустом интерфейсе данные
        -- о жидкости могут отсутствовать. Стороны уже подтверждены.
    end

    return {
        address = address,
        eohSide = eohSide,
        fluidSide = fluidSide,
        tanks = {
            hydrogen = 1,
            helium = 2,
            plasma = 3
        }
    }
end

function EOH.scan()
    EOH.state.controller = nil
    EOH.state.transposers = {}
    EOH.state.lastError = nil

    -- --------------------------------------------------------
    -- EOH Controller
    -- --------------------------------------------------------
    for address, _ in component.list("gt_machine") do
        if isEOH(address) then
            EOH.state.controller = {
                address = address,
                name = getName(address)
            }
            break
        end
    end

    if not EOH.state.controller then
        EOH.state.lastError = "EOH controller not found"
        EOH.state.scanned = true
        logger.error("CORE", "EOH controller not found")
        return false, EOH.state.lastError
    end

    logger.info(
        "CORE",
        "EOH found: " .. EOH.state.controller.name
            .. " @ " .. EOH.state.controller.address
    )

    -- --------------------------------------------------------
    -- Two Transposers
    -- --------------------------------------------------------
    for address, _ in component.list("transposer") do
        local data = inspectTransposer(address)
        if data then
            table.insert(EOH.state.transposers, data)
        end
    end

    table.sort(EOH.state.transposers, function(a, b)
        return a.address < b.address
    end)

    if #EOH.state.transposers < 2 and config.require_two_transposers then
        EOH.state.lastError = "Required transposers not found"
        EOH.state.scanned = true
        logger.error(
            "CORE",
            "Expected 2 transposers, found " .. tostring(#EOH.state.transposers)
        )
        return false, EOH.state.lastError
    end

    EOH.state.scanned = true

    logger.info(
        "CORE",
        "Transposers found: " .. tostring(#EOH.state.transposers)
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

    local _, active = safeInvoke(address, "isMachineActive")
    local okWork, hasWork = safeInvoke(address, "hasWork")
    local okAllowed, allowed = safeInvoke(address, "isWorkAllowed")
    local okProgress, progress = safeInvoke(address, "getWorkProgress")
    local okMax, maxProgress = safeInvoke(address, "getWorkMaxProgress")

    progress = okProgress and tonumber(progress) or 0
    maxProgress = okMax and tonumber(maxProgress) or 0

    local percent = 0
    if maxProgress > 0 then
        percent = (progress / maxProgress) * 100
    end

    return {
        active = active == true,
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

function EOH.getFluids()
    local sensor, err = EOH.getSensorInformation()

    local result = {
        hydrogen = 0,
        helium = 0,
        plasma = 0
    }

    if not sensor then
        return result, err
    end

    for _, rawLine in ipairs(sensor) do
        local line = cleanText(rawLine)

        local value
        value = parseFluidLine(line, FLUIDS.hydrogen.names)
        if value then result.hydrogen = value end

        value = parseFluidLine(line, FLUIDS.helium.names)
        if value then result.helium = value end

        value = parseFluidLine(line, FLUIDS.plasma.names)
        if value then result.plasma = value end
    end

    return result
end

function EOH.getRawSensorLines()
    return EOH.getSensorInformation()
end

function EOH.getRecipe(tier)
    local recipes = require("recipes")
    return recipes.get(tonumber(tier) or 1)
end

function EOH.getRecipeNeeds(tier, mode, useAA, overclocks)
    local recipe = EOH.getRecipe(tier)
    if not recipe then return nil, "Unknown tier" end

    mode = mode or "production"
    useAA = useAA == true
    overclocks = tonumber(overclocks) or 0

    local result = {
        hydrogen = recipe.hydrogen,
        helium = recipe.helium,
        plasma = recipe.plasma,
        duration = recipe.duration,
        planet = recipe.planet,
        starMatter = recipe.starMatter,
        tier = tonumber(tier),
        useAA = useAA,
        overclocks = overclocks
    }

    -- На этом этапе AA/overclock пока НЕ преобразуют численные
    -- требования рецепта: реальные правила масштабирования должны
    -- быть подтверждены по getParameters()/сенсору EOH.
    -- Поэтому база остаётся точным источником исходных значений.

    if mode == "power" then
        result.tier = 9
        result.planet = "Deep Dark"
        result.useAA = false
        result.overclocks = 0
    end

    return result
end

local function fluidLevel(transposer, fluidKey)
    local tank = transposer.tanks[fluidKey]
    local ok, level = safeInvoke(
        transposer.address,
        "getTankLevel",
        transposer.fluidSide,
        tank
    )

    if not ok then return 0 end
    return tonumber(level) or 0
end

local function chooseTransposer(fluidKey)
    local best = nil
    local bestLevel = -1

    for _, transposer in ipairs(EOH.state.transposers) do
        local level = fluidLevel(transposer, fluidKey)
        if level > bestLevel then
            best = transposer
            bestLevel = level
        end
    end

    return best
end

function EOH.getSourceFluidState()
    local result = {
        transposers = {}
    }

    for _, transposer in ipairs(EOH.state.transposers) do
        local item = {
            address = transposer.address,
            hydrogen = fluidLevel(transposer, "hydrogen"),
            helium = fluidLevel(transposer, "helium"),
            plasma = fluidLevel(transposer, "plasma")
        }
        table.insert(result.transposers, item)
    end

    return result
end

function EOH.transferFluid(fluidKey, amount)
    if not EOH.state.scanned then
        return false, 0, "Scan has not been performed"
    end

    local spec = FLUIDS[fluidKey]
    if not spec then
        return false, 0, "Unknown fluid: " .. tostring(fluidKey)
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return true, 0
    end

    local totalTransferred = 0
    local remaining = amount

    -- Используем оба транспозера последовательно, выбирая сначала
    -- тот, где больше доступного данного флюида.
    local ordered = {}
    for _, t in ipairs(EOH.state.transposers) do
        table.insert(ordered, t)
    end

    table.sort(ordered, function(a, b)
        return fluidLevel(a, fluidKey) > fluidLevel(b, fluidKey)
    end)

    for _, transposer in ipairs(ordered) do
        if remaining <= 0 then break end

        local available = fluidLevel(transposer, fluidKey)
        if available > 0 then
            local request = math.min(remaining, available)

            local ok, transferred = safeInvoke(
                transposer.address,
                "transferFluid",
                transposer.fluidSide,
                transposer.eohSide,
                request,
                spec.tank
            )

            if not ok then
                logger.error(
                    "CORE",
                    "transferFluid failed on " .. transposer.address
                        .. ": " .. tostring(transferred)
                )
            else
                transferred = tonumber(transferred) or 0
                totalTransferred = totalTransferred + transferred
                remaining = remaining - transferred

                logger.info(
                    "CORE",
                    string.format(
                        "Transferred %d L of %s via %s",
                        transferred,
                        fluidKey,
                        transposer.address
                    )
                )
            end
        end
    end

    if totalTransferred < amount then
        return false, totalTransferred, "Not enough source fluid"
    end

    return true, totalTransferred
end

function EOH.inspect()
    local status = EOH.getStatus()
    local fluids = EOH.getFluids()
    local sources = EOH.getSourceFluidState()

    return {
        controller = EOH.getController(),
        transposers = EOH.getTransposers(),
        status = status,
        fluids = fluids,
        sourceFluids = sources
    }
end

return EOH
