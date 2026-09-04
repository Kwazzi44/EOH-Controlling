-- ============================================
-- EOH_CORE.LUA - Основная логика работы с EOH
-- ============================================

local component = require("component")
local sides = require("sides")
local os = require("os")
local config = require("config")
local recipes = require("recipes")
local logger = require("logger")

-- ============================================
-- ПОИСК КОМПОНЕНТОВ
-- ============================================

function scanComponents()
    logger.info("EOH", "Поиск компонентов...")
    local found = {}
    for address, name in component.list() do
        if name:find("EyeOfHarmony") and not config.components.eohController then
            config.components.eohController = address
            found.eoh = address
            logger.info("EOH", "Найден контроллер: " .. address)
        end
        if name:find("transposer") then
            if not config.components.transposerHydrogen then
                config.components.transposerHydrogen = address
                logger.info("EOH", "Найден транспозер (H2): " .. address)
            elseif not config.components.transposerHelium then
                config.components.transposerHelium = address
                logger.info("EOH", "Найден транспозер (He): " .. address)
            elseif not config.components.transposerPlasma then
                config.components.transposerPlasma = address
                logger.info("EOH", "Найден транспозер (Plasma): " .. address)
            end
        end
    end
    if not config.components.eohController then
        logger.error("EOH", "Контроллер EOH не найден!")
    end
    return found
end

-- ============================================
-- ПОЛУЧЕНИЕ СТАТУСА
-- ============================================

function getStatus()
    local status = {active = false, hydrogen = 0, helium = 0, plasma = 0, progress = 0, error = nil}
    if not config.components.eohController then
        status.error = "Controller not found"
        return status
    end
    local controller = component.proxy(config.components.eohController)
    if controller.isActive then status.active = controller.isActive() end
    if controller.getTankInfo then
        local tanks = controller.getTankInfo()
        if tanks then
            for _, tank in ipairs(tanks) do
                if tank.name then
                    if tank.name:find("Hydrogen") then status.hydrogen = tank.amount or 0
                    elseif tank.name:find("Helium") then status.helium = tank.amount or 0
                    elseif tank.name:find("Plasma") then status.plasma = tank.amount or 0 end
                end
            end
        end
    end
    if controller.getProgress then status.progress = controller.getProgress() or 0 end
    return status
end

-- ============================================
-- ПОДАЧА ЖИДКОСТИ
-- ============================================

function supplyFluid(transposerAddr, fluidName, amount)
    if not transposerAddr then
        logger.error("EOH", "Транспозер для " .. fluidName .. " не найден!")
        return false
    end
    if amount <= 0 then return true end
    local transposer = component.proxy(transposerAddr)
    local source = sides[config.transposer.sourceSide] or sides.north
    local target = sides[config.transposer.targetSide] or sides.south
    transposer.setSide(source, target)
    transposer.setTransferRate(config.transposer.transferRate)
    local transferred = transposer.transferFluid(amount)
    logger.info("EOH", "Передано " .. fluidName .. ": " .. transferred .. "L из " .. amount .. "L")
    return transferred == amount
}

-- ============================================
-- ЗАПУСК РЕЦЕПТА
-- ============================================

function startRecipe(tier, useAA, overclocks)
    logger.info("EOH", "Запуск рецепта: тир " .. tier .. ", AA: " .. tostring(useAA))
    local recipe = recipes.get(tier)
    if not recipe then
        logger.error("EOH", "Неизвестный тир: " .. tier)
        return false, "Неизвестный тир"
    end
    local status = getStatus()
    if status.active then
        logger.warn("EOH", "EOH уже работает")
        return false, "EOH already active"
    end
    local multiplier = 2 ^ (overclocks or 0)
    local required = {hydrogen = 0, helium = 0, plasma = 0}
    if useAA then
        required.plasma = recipe.plasma * multiplier
        if not config.components.transposerPlasma then
            logger.error("EOH", "Транспозер для плазмы не найден!")
            return false, "Plasma transposer not found"
        end
    else
        required.hydrogen = recipe.hydrogen * multiplier
        required.helium = recipe.helium * multiplier
        if not config.components.transposerHydrogen or not config.components.transposerHelium then
            logger.error("EOH", "Транспозеры для H2/He не найдены!")
            return false, "H2/He transposers not found"
        end
    end
    local success = true
    if useAA then
        if required.plasma > 0 then
            local current = status.plasma or 0
            if current < required.plasma then
                success = supplyFluid(config.components.transposerPlasma, "Plasma", required.plasma - current)
            end
        end
    else
        if required.hydrogen > 0 then
            local current = status.hydrogen or 0
            if current < required.hydrogen then
                success = supplyFluid(config.components.transposerHydrogen, "Hydrogen", required.hydrogen - current)
            end
        end
        if required.helium > 0 and success then
            local current = status.helium or 0
            if current < required.helium then
                success = supplyFluid(config.components.transposerHelium, "Helium", required.helium - current)
            end
        end
    end
    if not success then
        logger.error("EOH", "Ошибка подачи жидкости")
        return false, "Fluid supply failed"
    end
    local newStatus = getStatus()
    local tolerance = config.defaults.tolerance
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
        logger.warn("EOH", "Обнаружено переполнение!")
        return false, "Overflow detected"
    end
    logger.info("EOH", "Рецепт запущен")
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
            waitForCompletion()
            logger.info("EOH", "Цикл завершен")
        else
            logger.error("EOH", "Ошибка: " .. tostring(err))
            break
        end
        if not autoRestart then break end
    end
end

function runPowerMode()
    logger.info("EOH", "Power Mode: Deep Dark T9")
    while true do
        startRecipe(9, false, 0)
        waitForCompletion()
        logger.info("EOH", "Цикл генерации завершен")
        if not config.defaults.autoRestart then break end
    end
end

function waitForCompletion()
    logger.info("EOH", "Ожидание завершения...")
    while getStatus().active do
        os.sleep(1)
    end
    logger.info("EOH", "Рецепт завершен")
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
    scanComponents = scanComponents,
    getStatus = getStatus,
    startRecipe = startRecipe,
    runProductionMode = runProductionMode,
    runPowerMode = runPowerMode,
    waitForCompletion = waitForCompletion,
    formatNumber = formatNumber,
}