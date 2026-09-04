-- ============================================
-- EOH_CORE.LUA - Основная логика работы с EOH
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;" .. package.path

local component = require("component")
local computer = require("computer")
local sides = require("sides")
local os = require("os")
local thread = require("thread")
local config = dofile("/home/eoh/config.lua")
local recipes = require("recipes")
-- Keep EOH's logger isolated from the HUB logger.  Both programs use the
-- same generic module name, and package.path is shared by OpenComputers.
local logger = dofile("/home/eoh/logger.lua")

local CORE_BUILD = "20260904-1494"

config.components = config.components or {}
config.transposer = config.transposer or {}
config.transposer.sourceSide = config.transposer.sourceSide or "north"
config.transposer.targetSide = config.transposer.targetSide or "south"
config.transposer.transferRate = config.transposer.transferRate or 1000
config.components.transposers = config.components.transposers or {}
config.components.transposerPlasmaList = config.components.transposerPlasmaList or {}
local runtimeState = {}
local runtimeCache = {}
local cycleRunners = {}
local threadContexts = setmetatable({}, {__mode = "k"})

local function currentComponents()
    local current = thread.current()
    return (current and threadContexts[current]) or config.components
end

local function setRuntimeState(address, stage, message)
    if not address then return end
    runtimeState[address] = {stage = stage, message = message}
    runtimeCache[address] = nil
end

function setComponents(components)
    components = components or {}
    config.components.eohController = components.eoh or components.eohController
    config.components.transposerHydrogen = components.transposerH2
        or components.transposerHydrogen
    config.components.transposerHelium = components.transposerHe
        or components.transposerHelium
    config.components.transposerPlasma = components.transposerPlasma
        or (components.transposerPlasmaList and components.transposerPlasmaList[1])
    config.components.transposerPlasmaList = components.transposerPlasmaList
        or {}
    if #config.components.transposerPlasmaList == 0
        and config.components.transposerPlasma then
        table.insert(config.components.transposerPlasmaList,
            config.components.transposerPlasma)
    end
    config.components.transposers = components.transposers or {}
end

-- ============================================
-- ПОИСК КОМПОНЕНТОВ
-- ============================================

local function sensorMarksController(proxy)
    if type(proxy.getSensorInformation) ~= "function" then
        return false
    end

    local ok, information = pcall(function()
        return proxy.getSensorInformation()
    end)
    if not ok or type(information) ~= "table" then
        return false
    end
    for _, line in ipairs(information) do
        local text = string.lower(tostring(line):gsub("§.", ""))
        if text:find("progress:", 1, true)
            or text:find("problems", 1, true)
            or text:find("efficiency:", 1, true)
            or text:find("прогресс:", 1, true)
            or text:find("проблемы", 1, true)
            or text:find("эффективность:", 1, true) then
            return true
        end
    end
    return false
end

local function hasControllerSensor(address)
    local ok, information = pcall(component.invoke, address,
        "getSensorInformation")
    return ok and type(information) == "table"
end

local function inspectTransposer(address)
    local proxy = component.proxy(address)
    if not proxy then
        return {
            address = address,
            sourceSide = sides.north,
            targetSide = sides.south,
            capacity = 0,
            level = 0,
        }
    end
    local sourceSideName = config.transposer.sourceSide or "north"
    local targetSideName = config.transposer.targetSide or "south"
    local targetSide = sides[targetSideName] or sides.south
    local best
    for side = 0, 5 do
        local capacity
        local okCapacity, capacityValue = pcall(component.invoke, address,
            "getTankCapacity", side, 1)
        if okCapacity and type(capacityValue) == "number"
            and capacityValue > 0 then
            capacity = capacityValue
        end
        if capacity then
            local level = 0
            local okLevel, levelValue = pcall(component.invoke, address,
                "getTankLevel", side, 1)
            if okLevel and type(levelValue) == "number" then
                level = levelValue
            end
            local fluid
            local okFluid, info = pcall(component.invoke, address,
                "getFluidInTank", side, 1)
            if okFluid and type(info) == "table" then
                local contents = info[1] or info
                if type(contents) == "table" then
                    fluid = contents.name or contents.label
                    level = tonumber(contents.amount) or level
                end
            end
            -- A fluid-bearing source is more useful than an empty side with
            -- a marginally larger tank.  The latter is commonly the EOH
            -- input side and must remain the transfer target.
            if not best
                or (fluid and level > 0 and not best.fluid)
                or (not best.fluid and capacity > best.capacity) then
                best = {
                    address = address,
                    sourceSide = side,
                    targetSide = targetSide,
                    capacity = capacity,
                    level = level,
                    fluid = fluid,
                }
            end
        end
    end
    if best then
        local ok, rate = pcall(component.invoke, address,
            "getFluidTransferRate", best.sourceSide)
        if ok and type(rate) == "number" then
            best.transferRate = rate
        end
    end
    return best or {
        address = address,
        sourceSide = sides[sourceSideName] or sides.north,
        targetSide = targetSide,
        capacity = 0,
        level = 0,
    }
end

function scanComponents(excluded)
    logger.info("EOH", "Поиск компонентов...")
    excluded = excluded or {}
    local found = {
        eoh = nil,
        transposerH2 = nil,
        transposerHe = nil,
        transposerPlasma = nil,
        transposerPlasmaList = {},
        controllers = {},
        all = {},
        transposers = {},
    }
    config.components.eohController = nil
    config.components.transposerHydrogen = nil
    config.components.transposerHelium = nil
    config.components.transposerPlasma = nil
    config.components.transposerPlasmaList = {}
    config.components.transposers = {}
    local machineAddresses = {}
    for address, componentName in component.list("gt_machine") do
        if excluded[address] then goto next_machine end
        local okProxy, proxy = pcall(component.proxy, address)
        if not okProxy or not proxy then
            logger.warn("EOH", "Не удалось получить proxy: " .. address)
        else
            local name = componentName
            if proxy.getMachineName then
                local ok, value = pcall(proxy.getMachineName)
                if ok and type(value) == "string" and value ~= "" then
                    name = value
                end
            end
            table.insert(machineAddresses, address)
            table.insert(found.all, {address = address, name = name})
            logger.debug("EOH", "gt_machine: " .. name .. " [" .. address .. "]")
            if not config.components.eohController and sensorMarksController(proxy) then
                config.components.eohController = address
                found.eoh = address
                logger.info("EOH", "Найден контроллер EOH: " .. address)
            end
        end
        ::next_machine::
    end
    -- Keep every detected controller.  Setup uses this list to select the
    -- unregistered controller when several EOH multiblocks are connected.
    for _, address in ipairs(machineAddresses) do
        if hasControllerSensor(address) then
            table.insert(found.controllers, address)
            if not found.eoh then
                found.eoh = address
                config.components.eohController = address
            end
        end
    end
    for address in component.list("transposer") do
        if excluded[address] then goto next_transposer end
        local ok, details = pcall(inspectTransposer, address)
        if ok and details then
            table.insert(found.transposers, details)
            table.insert(found.all, {address = address, name = "transposer"})
            logger.info("EOH", "Найден транспозер: " .. address
                .. ", capacity=" .. tostring(details.capacity)
                .. ", fluid=" .. tostring(details.fluid or "unknown"))
        else
            logger.warn("EOH", "Не удалось опросить транспозер: " .. address)
        end
        ::next_transposer::
    end
    for _, transposer in ipairs(found.transposers) do
            local fluid = string.lower(transposer.fluid or "")
            if fluid:find("hydrogen", 1, true) then
                found.transposerH2 = transposer.address
            elseif fluid:find("helium", 1, true) then
                found.transposerHe = transposer.address
            elseif fluid:find("plasma", 1, true) then
                found.transposerPlasma = transposer.address
                table.insert(found.transposerPlasmaList, transposer.address)
            end
    end
    local used = {}
    local function mark(address)
        if address then used[address] = true end
        return address
    end
    mark(found.transposerH2)
    mark(found.transposerHe)
    mark(found.transposerPlasma)
    local function nextUnused()
        for _, item in ipairs(found.transposers) do
            if not used[item.address] then
                used[item.address] = true
                return item.address
            end
        end
        return found.transposers[1] and found.transposers[1].address
    end
    if not found.transposerH2 then found.transposerH2 = nextUnused() end
    if not found.transposerHe then found.transposerHe = nextUnused() end
    if #found.transposerPlasmaList == 0 and found.transposerPlasma then
        table.insert(found.transposerPlasmaList, found.transposerPlasma)
    end
    config.components.transposers = found.transposers
        config.components.transposerHydrogen = found.transposerH2
        config.components.transposerHelium = found.transposerHe
    config.components.transposerPlasma = found.transposerPlasma
    config.components.transposerPlasmaList = found.transposerPlasmaList
    if not found.eoh and #machineAddresses == 1 then
        found.eoh = machineAddresses[1]
        config.components.eohController = found.eoh
        logger.warn("EOH", "Использован единственный gt_machine как контроллер EOH")
    end
    if not config.components.eohController then
        logger.error("EOH", "Контроллер EOH не найден!")
    end
    return found
end

-- ============================================
-- ПОЛУЧЕНИЕ СТАТУСА
-- ============================================

local function readActive(address)
    if not address then return false end
    -- The GTNH controller exposes isMachineActive.  Probing several absent
    -- compatibility methods on every HUD refresh causes visible OC stalls.
    local ok, value = pcall(component.invoke, address, "isMachineActive")
    return ok and value == true
end

local function readControllerNumber(address, method)
    local ok, value = pcall(component.invoke, address, method)
    return ok and tonumber(value) or nil
end

local function readSensorProgress(address)
    local ok, information = pcall(component.invoke, address,
        "getSensorInformation")
    if not ok or type(information) ~= "table" then return nil, nil end
    -- EOH reports its live recipe progress in the first sensor line.
    local text = tostring(information[1] or ""):gsub("\194\167.", "")
        :gsub(",", "")
    local progress, maximum = text:match("(%d+).-(%d+)")
    return tonumber(progress), tonumber(maximum)
end

function getRuntimeState(components)
    components = components or {}
    local address = components.eoh or components.eohController
    if not address then
        return {stage = "OFF", message = "Controller not bound"}
    end
    local now = computer.uptime()
    local cached = runtimeCache[address]
    if cached and now - cached.at < 1 then
        return cached.value
    end
    local function remember(value)
        runtimeCache[address] = {at = now, value = value}
        return value
    end
    local okProxy, controller = pcall(component.proxy, address)
    if not okProxy or not controller then
        return remember({stage = "OFF", message = "Controller unavailable"})
    end
    if readActive(address) then
        local progress = readControllerNumber(address, "getWorkProgress") or 0
        local maximum = readControllerNumber(address, "getWorkMaxProgress") or 0
        if maximum <= 0 then
            local sensorProgress, sensorMaximum = readSensorProgress(address)
            if sensorProgress and sensorMaximum then
                progress = sensorProgress
                maximum = sensorMaximum
            end
        end
        return remember({stage = "WORK", progress = progress, maximum = maximum})
    end
    local state = runtimeState[address] or {stage = "READY"}
    local okAllowed, allowed = pcall(component.invoke, address, "isWorkAllowed")
    if okAllowed and allowed == false then
        return remember({stage = "OFF", message = "Work disabled"})
    end
    if state.stage == "STARTING" then
        local stored = readControllerNumber(address, "getEUStored") or 0
        local input = readControllerNumber(address, "getEUInputAverage") or 0
        if stored <= 0 and input <= 0 then
            return {stage = "NO_EU", message = "No available energy"}
        end
    end
    return remember(state)
end

local function readSensorInformation(address)
    local ok, information = pcall(component.invoke, address,
        "getSensorInformation")
    return ok and type(information) == "table" and information or nil
end

local function sensorAmount(information, englishName, russianStem)
    if not information then return nil end
    for _, line in ipairs(information) do
        local text = tostring(line):gsub("\167.", "")
        local lower = string.lower(text)
        if lower:find(englishName, 1, true)
            or (russianStem and text:find(russianStem, 1, true)) then
            local value = text:match("([%d%.,]+)%s*$")
            if value then
                value = value:gsub(",", "")
                return tonumber(value)
            end
        end
    end
    return nil
end

function getStatus()
    local components = currentComponents()
    local status = {
        active = false,
        hydrogen = 0,
        helium = 0,
        plasma = 0,
        progress = 0,
        maxProgress = 0,
        error = nil,
    }
    if not components.eohController and not components.eoh then
        status.error = "Controller not found"
        return status
    end
    local address = components.eoh or components.eohController
    local okProxy, controller = pcall(component.proxy, address)
    if not okProxy or not controller then
        status.error = "Controller unavailable"
        return status
    end
    status.active = readActive(address)
    local okTanks, tanks = pcall(component.invoke,
        address, "getTankInfo")
    if okTanks and tanks then
        for _, tank in ipairs(tanks) do
            if type(tank) == "table" then
                local contents = tank.contents or tank
                local name = contents.name or contents.label
                local amount = contents.amount or tank.amount or 0
                if name and string.lower(name):find("hydrogen", 1, true) then
                    status.hydrogen = amount
                elseif name and string.lower(name):find("helium", 1, true) then
                    status.helium = amount
                elseif name and string.lower(name):find("plasma", 1, true) then
                    status.plasma = amount
                end
            end
        end
    end
    for _, method in ipairs({"getProgress", "getWorkProgress"}) do
        local okProgress, progress = pcall(component.invoke,
            address, method)
        if okProgress and type(progress) == "number" then
            status.progress = progress
            break
        end
    end
    local okMaximum, maximum = pcall(component.invoke,
        address, "getWorkMaxProgress")
    if okMaximum and type(maximum) == "number" then
        status.maxProgress = maximum
    end

    -- GTNH exposes internal EOH fluids through sensor text, not getTankInfo.
    local sensors = readSensorInformation(address)
    status.helium = sensorAmount(sensors, "helium",
        "\208\181\208\187\208\184\208\185") or status.helium
    status.hydrogen = sensorAmount(sensors, "hydrogen",
        "\208\190\208\180\208\190\209\128\208\190\208\180") or status.hydrogen
    status.plasma = sensorAmount(sensors, "plasma",
        "\208\191\208\187\208\176\208\183\208\188") or status.plasma
    return status
end

-- ============================================
-- ПОДАЧА ЖИДКОСТИ
-- ============================================

local function supplyFluidFromList(transposerAddresses, fluidName, amount)
    local components = currentComponents()
    if amount <= 0 then return true, nil end
    if not transposerAddresses or #transposerAddresses == 0 then
        logger.error("EOH", "Транспозеры для " .. fluidName .. " не найдены!")
        return false, "transposer not found"
    end
    local remaining = amount
    local lastError = "no transfer attempted"
    for _, address in ipairs(transposerAddresses) do
        if remaining <= 0 then break end
        local details
        for _, item in ipairs(components.transposers or {}) do
            if item.address == address then details = item break end
        end
        -- Capacity is the tank size, not the amount available to transfer.
        -- Prefer the inspected level so a full-size but empty tank is not
        -- treated as a valid source.
        local available = details and details.level or remaining
        local transferredAmount = math.min(remaining,
            available > 0 and available or remaining)
        local ok, err = supplyFluid(address, fluidName, transferredAmount)
        if ok then
            remaining = remaining - transferredAmount
        else
            lastError = tostring(err)
            logger.warn("EOH", "Транспозер " .. tostring(address)
                .. " не передал " .. fluidName .. ": " .. tostring(err))
        end
    end
    return remaining <= 0, remaining <= 0 and nil or lastError
end

local function tankContents(info)
    if type(info) ~= "table" then return nil end
    if info.name or info.label or info.amount then return info end
    if type(info[1]) == "table" then return info[1] end
    if type(info.contents) == "table" then return info.contents end
    return nil
end

local function readTankLevel(address, proxy, side)
    local ok, value = pcall(component.invoke, address, "getTankLevel", side, 1)
    return ok and tonumber(value) or nil
end

function supplyFluid(transposerAddr, fluidName, amount)
    local components = currentComponents()
    if not transposerAddr then
        logger.error("EOH", "Транспозер для " .. fluidName .. " не найден!")
        return false, "transposer not found"
    end
    if amount <= 0 then return true end
    local okProxy, transposer = pcall(component.proxy, transposerAddr)
    if not okProxy or not transposer then
        logger.error("EOH", "Транспозер недоступен: " .. tostring(transposerAddr))
        return false, "transposer unavailable"
    end
    local defaultSource = sides[config.transposer.sourceSide] or sides.north
    local defaultTarget = sides[config.transposer.targetSide] or sides.south
    for _, details in ipairs(components.transposers or {}) do
        if details.address == transposerAddr then
            defaultSource = details.sourceSide or defaultSource
            defaultTarget = details.targetSide or defaultTarget
            break
        end
    end
    local sources = {}
    local sourceSeen = {}
    local wanted = string.lower(fluidName)
    for side = 0, 5 do
        for _, tankIndex in ipairs({1, 0}) do
            local okInfo, info = pcall(component.invoke, transposerAddr,
                "getFluidInTank", side, tankIndex)
            local contents = okInfo and tankContents(info) or nil
            local name = type(contents) == "table"
                and (contents.name or contents.label) or nil
            local amountAvailable = type(contents) == "table"
                and tonumber(contents.amount or 0) or 0
            if name and amountAvailable > 0
                and string.lower(tostring(name)):find(wanted, 1, true)
                and not sourceSeen[side] then
                table.insert(sources, side)
                sourceSeen[side] = true
            end
        end
    end
    if #sources == 0 then
        -- Some GTNH transposer builds expose tank levels but omit fluid names
        -- from getFluidInTank.  This address has already been explicitly
        -- bound to the requested fluid, so use non-empty sides as sources
        -- while never treating the EOH input side as a source.
        for side = 0, 5 do
            local level = readTankLevel(transposerAddr, transposer, side)
            if side ~= defaultTarget and level and level > 0
                and not sourceSeen[side] then
                table.insert(sources, side)
                sourceSeen[side] = true
            end
        end
        if #sources > 0 then
            logger.warn("EOH", "Fluid name unavailable for " .. fluidName
                .. "; using non-empty bound transposer sides")
        else
            return false, fluidName .. " tank not detected on transposer"
        end
    end
    local targets = {defaultTarget}
    logger.info("EOH", "TRANSFER " .. fluidName .. " addr=" .. transposerAddr
        .. " sources=" .. table.concat(sources, ",")
        .. " target=" .. tostring(defaultTarget)
        .. " requested=" .. tostring(amount))
    local remaining = amount
    local failureReason = "transfer incomplete"
    local stalledAttempts = 0
    while remaining > 0 do
        local transferred = 0
        local lastError = "transfer returned zero"
        for _, source in ipairs(sources) do
            for _, target in ipairs(targets) do
                if source ~= target then
                    local transferAmount = remaining
                    local okCapacity, capacity = pcall(component.invoke,
                        transposerAddr, "getTankCapacity", target, 1)
                    local okLevel, level = pcall(component.invoke,
                        transposerAddr, "getTankLevel", target, 1)
                    if okCapacity and okLevel then
                        local free = (tonumber(capacity) or 0)
                            - (tonumber(level) or 0)
                        if free > 0 then
                            transferAmount = math.min(transferAmount, free)
                        end
                    end
                    local sourceBefore = readTankLevel(transposerAddr, transposer, source)
                    local targetBefore = readTankLevel(transposerAddr, transposer, target)
                    local okTransfer, value, transferError =
                        pcall(component.invoke, transposerAddr, "transferFluid",
                            source, target, transferAmount)
                    logger.info("EOH", "TRANSFER_RESULT " .. fluidName
                        .. " source=" .. tostring(source)
                        .. " target=" .. tostring(target)
                        .. " amount=" .. tostring(transferAmount)
                        .. " ok=" .. tostring(okTransfer)
                        .. " value=" .. tostring(value)
                        .. " extra=" .. tostring(transferError)
                        .. " before=" .. tostring(sourceBefore)
                        .. "/" .. tostring(targetBefore))
                    if okTransfer and value == true and tonumber(transferError)
                        and tonumber(transferError) > 0 then
                        transferred = tonumber(transferError)
                        break
                    end
                    if okTransfer and tonumber(value) and tonumber(value) > 0 then
                        transferred = tonumber(value)
                        break
                    end
                    if okTransfer and value == true then
                        local sourceAfter = readTankLevel(transposerAddr, transposer, source)
                        local targetAfter = readTankLevel(transposerAddr, transposer, target)
                        local sourceDelta = sourceBefore and sourceAfter
                            and sourceBefore - sourceAfter or 0
                        local targetDelta = targetBefore and targetAfter
                            and targetAfter - targetBefore or 0
                        transferred = math.max(sourceDelta, targetDelta, 0)
                        logger.info("EOH", "TRANSFER_LEVELS sourceAfter="
                            .. tostring(sourceAfter) .. " targetAfter="
                            .. tostring(targetAfter) .. " moved="
                            .. tostring(transferred))
                        if transferred > 0 then break end
                    end
                    if not okTransfer then
                        lastError = "API error on sides "
                            .. tostring(source) .. " -> " .. tostring(target)
                            .. ": " .. tostring(value)
                    elseif okTransfer and value == true and tonumber(transferError) == 0 then
                        lastError = "zero transfer on sides "
                            .. tostring(source) .. " -> " .. tostring(target)
                            .. " (source empty or target blocked)"
                    else
                        lastError = tostring(transferError or value or lastError)
                    end
                end
            end
            if transferred > 0 then break end
        end
        failureReason = lastError
        if transferred <= 0 then
            stalledAttempts = stalledAttempts + 1
            if stalledAttempts > 120 then
                logger.error("EOH", "Не удалось передать " .. fluidName
                    .. " (" .. lastError .. "), осталось "
                    .. tostring(remaining) .. "L")
                return false, lastError
            end
            logger.debug("EOH", "Transfer paused for " .. fluidName
                .. "; waiting for target space (attempt "
                .. tostring(stalledAttempts) .. ")")
            os.sleep(0.5)
        else
            stalledAttempts = 0
            remaining = remaining - transferred
            logger.info("EOH", "Передано " .. fluidName .. ": " .. transferred .. "L")
            if remaining > 0 then os.sleep(0.05) end
        end
    end
    if remaining <= 0 then
        return true
    end
    return false, failureReason .. ", remaining "
        .. tostring(remaining) .. "L"
end

-- ============================================
-- ЗАПУСК РЕЦЕПТА
-- ============================================

function startRecipe(tier, useAA, overclocks)
    local components = currentComponents()
    logger.info("EOH", "Запуск рецепта: тир " .. tier .. ", AA: " .. tostring(useAA))
    local recipe = recipes.get(tier)
    if not recipe then
        logger.error("EOH", "Неизвестный тир: " .. tier)
        return false, "Неизвестный тир"
    end
    if not components.eohController and not components.eoh then
        return false, "EOH controller not found"
    end
    local status = getStatus()
    if status.active then
        logger.warn("EOH", "EOH уже работает")
        return false, "EOH already active"
    end
    local required = {hydrogen = 0, helium = 0, plasma = 0}
    if useAA then
        required.plasma = recipe.plasma
        if not components.transposerPlasma
            and #(components.transposerPlasmaList or {}) == 0 then
            logger.error("EOH", "Транспозер для плазмы не найден!")
            return false, "Plasma transposer not found"
        end
    else
        required.hydrogen = recipe.hydrogen
        required.helium = recipe.helium
        if not components.transposerHydrogen and not components.transposerH2
            or not components.transposerHelium and not components.transposerHe then
            logger.error("EOH", "Транспозеры для H2/He не найдены!")
            return false, "H2/He transposers not found"
        end
    end
    local tolerance = tonumber(config.defaults.tolerance) or 0.001
    local function exceedsRequirement(current, requiredAmount)
        return requiredAmount > 0
            and (tonumber(current) or 0) > requiredAmount * (1 + tolerance)
    end
    if exceedsRequirement(status.hydrogen, required.hydrogen)
        or exceedsRequirement(status.helium, required.helium)
        or exceedsRequirement(status.plasma, required.plasma) then
        logger.warn("EOH", "EOH already contains excess fluid; "
            .. "skipping refill and starting with stored input")
    end
    local controllerAddress = components.eoh or components.eohController
    setRuntimeState(controllerAddress, "LOADING", "Loading reagents")
    local success, supplyError = true, nil
    if useAA then
        if required.plasma > 0 then
            local current = status.plasma or 0
            if current < required.plasma then
                success, supplyError = supplyFluidFromList(
                    components.transposerPlasmaList,
                    "Plasma",
                    required.plasma - current
                )
            end
        end
    else
        local jobs = {}
        local results = {}
        local function queueSupply(name, address, amount)
            if amount <= 0 then return end
            jobs[#jobs + 1] = thread.create(function()
                local owner = thread.current()
                threadContexts[owner] = components
                local ok, err = supplyFluid(address, name, amount)
                results[#results + 1] = {name = name, ok = ok, error = err}
                threadContexts[owner] = nil
            end)
        end
        queueSupply("Hydrogen", components.transposerHydrogen or components.transposerH2,
            required.hydrogen - (status.hydrogen or 0))
        queueSupply("Helium", components.transposerHelium or components.transposerHe,
            required.helium - (status.helium or 0))
        if #jobs > 0 then
            local joined, joinError = thread.waitForAll(jobs)
            if not joined then
                success = false
                supplyError = joinError
            else
                for _, result in ipairs(results) do
                    if not result.ok then
                        success = false
                        supplyError = result.name .. ": "
                            .. tostring(result.error)
                        break
                    end
                end
            end
        end
    end
    if not success then
        setRuntimeState(controllerAddress, "ERROR",
            "Reagent transfer failed: " .. tostring(supplyError))
        logger.error("EOH", "Ошибка подачи жидкости")
        if supplyError == nil or supplyError == ""
            or tostring(supplyError) == "0" then
            supplyError = "transfer returned zero; source tank or target side is unavailable"
        elseif type(supplyError) ~= "string" then
            if tonumber(supplyError) == 0 then
                supplyError = "transfer returned zero; source tank or target side is unavailable"
            else
                supplyError = tostring(supplyError)
            end
        end
        return false, "CORE " .. CORE_BUILD .. " | Fluid supply failed: " .. supplyError
    end
    local newStatus = getStatus()
    local overflow = false
    if useAA then
        if required.plasma > 0 then
            overflow = (newStatus.plasma / required.plasma - 1) > tolerance
        end
    else
        if required.hydrogen > 0 then
            overflow = (newStatus.hydrogen / required.hydrogen - 1) > tolerance
        end
        if not overflow and required.helium > 0 then
            overflow = (newStatus.helium / required.helium - 1) > tolerance
        end
    end
    if overflow then
        logger.warn("EOH", "EOH contains excess fluid after supply; "
            .. "starting with stored input")
    end
    local okController, controller = pcall(component.proxy,
        controllerAddress)
    if not okController or not controller then
        setRuntimeState(controllerAddress, "ERROR",
            "Controller unavailable")
        return false, "EOH controller unavailable"
    end
    local started = false
    local okStart, result = pcall(component.invoke,
        controllerAddress, "setWorkAllowed", true)
    started = okStart and result ~= false
    if not started then
        setRuntimeState(controllerAddress, "ERROR",
            "Controller did not accept start")
        logger.error("EOH", "У контроллера нет метода запуска")
        return false, "EOH start method not found"
    end
    logger.info("EOH", "Рецепт запущен")
    setRuntimeState(controllerAddress, "STARTING",
        "Waiting for EOH to start")
    return true
end

-- ============================================
-- РЕЖИМЫ РАБОТЫ
-- ============================================

function runProductionMode(tier, useAA, overclocks, autoRestart)
    logger.info("EOH", "Production Mode: тир " .. tier)
    while true do
        local success, err = startRecipe(tier, useAA, overclocks)
        if success then
            local completed, completionError = waitForCompletion()
            if not completed then
                logger.error("EOH", "Completion wait failed: "
                    .. tostring(completionError))
                break
            end
            logger.info("EOH", "Цикл завершен")
        else
            logger.error("EOH", "Ошибка: " .. tostring(err))
            break
        end
        if not autoRestart then break end
    end
end

function runPowerMode(autoRestart)
    logger.info("EOH", "Power Mode: Deep Dark T9")
    if autoRestart == nil then
        autoRestart = config.defaults.autoRestart
    end
    while true do
        local success, err = startRecipe(9, false, 0)
        if not success then
            logger.error("EOH", "Ошибка: " .. tostring(err))
            break
        end
        local completed, completionError = waitForCompletion()
        if not completed then
            logger.error("EOH", "Completion wait failed: "
                .. tostring(completionError))
            break
        end
        logger.info("EOH", "Цикл генерации завершен")
        if not autoRestart then break end
    end
end

-- Starts one managed recipe cycle for a controller.  The runner stays alive
-- while AUTO is enabled: after a completed recipe it refills missing reagents
-- and enables the next one.  Keeping the runners here also prevents Setup and
-- the HUD from creating two concurrent loops for the same EOH.
function startConfiguredCycle(components, settings)
    components = components or {}
    settings = settings or {}
    local address = components.eoh or components.eohController
    if not address then return false, "Controller not bound" end

    local existing = cycleRunners[address]
    if existing then
        local ok, status = pcall(existing.status, existing)
        if ok and status == "running" then
            return false, "Recipe cycle already running"
        end
        cycleRunners[address] = nil
    end

    local runner = thread.create(function()
        threadContexts[thread.current()] = components
        local ok, err = pcall(function()
            -- When Setup is run during an active recipe, first wait for that
            -- recipe to finish, then take over its automatic restart.
            if readActive(address) then
                setRuntimeState(address, "WORK", "Monitoring active recipe")
                local completed, completionError = waitForCompletion()
                if not completed then error(tostring(completionError)) end
            end
            if settings.mode == "power" then
                runPowerMode(settings.autoRestart ~= false)
            else
                runProductionMode(settings.tier or 3, settings.mode == "aa",
                    settings.overclocks or 0, settings.autoRestart ~= false)
            end
        end)
        if not ok then
            setRuntimeState(address, "ERROR", tostring(err))
            logger.error("EOH", "Recipe cycle failed: " .. tostring(err))
        end
        threadContexts[thread.current()] = nil
        cycleRunners[address] = nil
    end)
    cycleRunners[address] = runner
    return true, "Recipe cycle started"
end

function waitForCompletion()
    local components = currentComponents()
    logger.info("EOH", "Ожидание завершения...")
    local started = false
    for _ = 1, 10 do
        local status = getStatus()
        if status.error then return false, status.error end
        if status.active then
            started = true
            break
        end
        os.sleep(0.5)
    end
    if not started then
        return false, "EOH did not become active after enabling work"
    end
    while true do
        local status = getStatus()
        if status.error then return false, status.error end
        if not status.active then break end
        os.sleep(1)
    end
    logger.info("EOH", "Recipe completed")
    setRuntimeState(components.eoh or components.eohController, "READY", "Ready")
    return true
end

-- ============================================
-- ФОРМАТИРОВАНИЕ
-- ============================================

function formatNumber(num)
    if num >= 1e9 then return string.format("%.1fB", num / 1e9)
    elseif num >= 1e6 then return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then return string.format("%.1fK", num / 1e3)
    else return tostring(num) end
end

return {
    build = CORE_BUILD,
    setComponents = setComponents,
    scanComponents = scanComponents,
    getStatus = getStatus,
    getRuntimeState = getRuntimeState,
    startRecipe = startRecipe,
    runProductionMode = runProductionMode,
    runPowerMode = runPowerMode,
    startConfiguredCycle = startConfiguredCycle,
    waitForCompletion = waitForCompletion,
    formatNumber = formatNumber,
}
