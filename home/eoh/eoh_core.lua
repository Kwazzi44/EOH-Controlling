-- eoh_core.lua
-- Вся логика взаимодействия с Eye of Harmony.

local component = require("component")
local config = require("config")
local logger = require("logger")
local recipes = require("recipes")

local core = {}
core.state = {
  controller = nil,
  transposers = {},
  lastScan = 0,
  lastError = nil,
}

local function lower(value)
  return tostring(value or ""):lower()
end

local function safeCall(proxy, method, ...)
  if not proxy then return false, nil end
  local fn = proxy[method]
  if type(fn) ~= "function" then return false, nil end
  return pcall(fn, proxy, ...)
end

local function tryMethods(proxy, methods, ...)
  for _, method in ipairs(methods) do
    local ok, result = safeCall(proxy, method, ...)
    if ok and result ~= nil then
      return true, result, method
    end
  end
  return false, nil, nil
end

local function normalizeFluidEntry(fluid)
  if type(fluid) == "table" then
    return {
      name = fluid.name or fluid.label or fluid.id or fluid.localizedName or fluid[1],
      amount = tonumber(fluid.amount or fluid.size or fluid[2] or 0) or 0,
      capacity = tonumber(fluid.capacity or fluid.maxAmount or fluid[3] or 0) or 0,
    }
  end

  if type(fluid) == "string" then
    return { name = fluid, amount = 0, capacity = 0 }
  end

  return nil
end

local function matchFluidKey(name)
  local n = lower(name)
  if n:find("hydrogen", 1, true) then return "hydrogen" end
  if n:find("helium", 1, true) then return "helium" end
  if n:find("raw stellar plasma", 1, true) then return "plasma" end
  if n:find("plasma", 1, true) then return "plasma" end
  return nil
end

local function sideForResource(resource)
  if resource == "hydrogen" then return config.defaultSides.input end
  if resource == "helium" then return config.defaultSides.output end
  if resource == "plasma" then return config.defaultSides.plasmaInput end
  return config.defaultSides.buffer
end

function core.scanComponents()
  local found = {
    controller = nil,
    transposers = {},
  }

  for address, ctype in component.list() do
    local ctypeLower = lower(ctype)
    if not found.controller then
      for _, pattern in ipairs(config.componentPatterns.eohController) do
        if ctypeLower:find(pattern, 1, true) then
          found.controller = component.proxy(address)
          break
        end
      end
    end

    for _, pattern in ipairs(config.componentPatterns.transposer) do
      if ctypeLower:find(pattern, 1, true) then
        found.transposers[#found.transposers + 1] = component.proxy(address)
        break
      end
    end
  end

  if not found.controller then
    return false, "Не найден контроллер Eye of Harmony. Проверьте, что мультиблок собран и OC видит компонент."
  end

  if #found.transposers == 0 then
    return false, "Не найден ни один transposer. Для подачи жидкостей нужен хотя бы один транспозер."
  end

  core.state.controller = found.controller
  core.state.transposers = found.transposers
  core.state.lastScan = os.time()
  core.state.lastError = nil

  logger.info("eoh_core", string.format("Найдено компонентов: controller=1, transposers=%d", #found.transposers))
  return true, found
end

function core.ensureScanned()
  if core.state.controller and #core.state.transposers > 0 then
    return true
  end
  return core.scanComponents()
end

function core.getSelectedRecipe(settings)
  settings = settings or config.defaults
  if settings.mode == "power" then
    return recipes.powerMode
  end
  return recipes.get(settings.tier) or recipes.get(config.defaults.tier)
end

function core.computeRequirement(recipe, settings)
  settings = settings or config.defaults
  local scaled = recipes.scale(recipe, settings.overclocks or 0)
  local requirement = {
    hydrogen = 0,
    helium = 0,
    plasma = 0,
    duration = scaled.duration,
    matter = scaled.matter,
    planet = scaled.planet,
    tier = scaled.tier,
    overclocks = scaled.overclocks,
    useAA = settings.useAA and true or false,
  }

  if settings.useAA then
    requirement.plasma = scaled.plasma > 0 and scaled.plasma or math.max(scaled.hydrogen, scaled.helium)
  else
    requirement.hydrogen = scaled.hydrogen
    requirement.helium = scaled.helium
  end

  return requirement
end

function core.readMachineStatus()
  local controller = core.state.controller
  if not controller then
    return { active = false, progress = 0, text = "Контроллер не найден" }
  end

  local activeOk, active = tryMethods(controller, { "isActive", "isRunning", "active", "getWorking", "working" })
  local progressOk, progress = tryMethods(controller, { "getProgress", "progress", "getRecipeProgress", "recipeProgress" })
  local recipeOk, recipeName = tryMethods(controller, { "getRecipeName", "recipeName", "getCurrentRecipe" })
  local textOk, text = tryMethods(controller, { "getStatus", "status", "getTextStatus" })

  if type(recipeName) == "table" then
    recipeName = recipeName.name or recipeName.label or recipeName[1]
  end

  progress = tonumber(progress) or 0
  if progress > 1 then
    -- Если метод возвращает 0..100, оставляем как есть. Если 0..1, нормализуем.
    if progress <= 1 then
      progress = progress * 100
    end
  end

  return {
    active = activeOk and (active == true or active == 1),
    progress = progress,
    recipe = recipeOk and recipeName or nil,
    text = textOk and text or nil,
  }
end

function core.readFluidLevels()
  local totals = {
    hydrogen = 0,
    helium = 0,
    plasma = 0,
    raw = {},
  }

  for _, t in ipairs(core.state.transposers) do
    for side = 0, 5 do
      local count = 0
      local okCount, c = safeCall(t, "getTankCount", side)
      if okCount and c then count = tonumber(c) or 0 end

      for tank = 1, math.max(1, count) do
        local okFluid, fluid = safeCall(t, "getFluidInTank", side, tank)
        if okFluid and fluid then
          local entry = normalizeFluidEntry(fluid)
          if entry and entry.name then
            local key = matchFluidKey(entry.name)
            if key then
              totals[key] = totals[key] + (entry.amount or 0)
            end
            totals.raw[#totals.raw + 1] = {
              side = side,
              tank = tank,
              name = entry.name,
              amount = entry.amount or 0,
              capacity = entry.capacity or 0,
            }
          end
        end
      end
    end
  end

  return totals
end

local function transferBetween(transposer, fromSide, toSide, amount)
  if amount <= 0 then return 0 end
  local transferred = 0

  -- Пытаемся стандартный вариант transferFluid(fromSide, toSide, amount, fromTank, toTank)
  local ok, result = pcall(function()
    return transposer.transferFluid(fromSide, toSide, amount, 1, 1)
  end)
  if ok and type(result) == "number" then
    transferred = result
  elseif ok and result == true then
    transferred = amount
  end

  return transferred
end

function core.ensureFluids(requirement, settings)
  settings = settings or config.defaults
  local levels = core.readFluidLevels()
  local tolerance = tonumber(settings.tolerance or config.defaultTolerance) or config.defaultTolerance
  local transposer = core.state.transposers[1]
  if not transposer then
    return false, "Transposer не найден"
  end

  local resources = { "hydrogen", "helium", "plasma" }
  for _, resource in ipairs(resources) do
    local required = tonumber(requirement[resource] or 0) or 0
    if required > 0 then
      local current = tonumber(levels[resource] or 0) or 0
      local limit = required * (1 + tolerance)

      if current > limit then
        return false, string.format("Переполнение %s: текущий %d > допустимого %d", resource, current, math.floor(limit))
      end

      local missing = required - current
      if missing > 0 then
        local fromSide = sideForResource(resource)
        local toSide = config.defaultSides.buffer
        -- В простейшей схеме считаем, что буфер и вход EOH находятся на заданных сторонах.
        local moved = transferBetween(transposer, fromSide, toSide, missing)
        logger.info("eoh_core", string.format("Долив %s: требовалось %d, перенесено %d", resource, missing, moved))
      end
    end
  end

  -- Повторная проверка после долива.
  local after = core.readFluidLevels()
  for _, resource in ipairs(resources) do
    local required = tonumber(requirement[resource] or 0) or 0
    local current = tonumber(after[resource] or 0) or 0
    local limit = required * (1 + tolerance)

    if current > limit then
      return false, string.format("После долива обнаружено переполнение %s: %d > %d", resource, current, math.floor(limit))
    end
    if required > 0 and current + math.floor(required * tolerance) < required then
      logger.warn("eoh_core", string.format("%s не удалось долить точно: current=%d required=%d", resource, current, required))
    end
  end

  return true, after
end

function core.startRecipe(requirement)
  local controller = core.state.controller
  if not controller then
    return false, "Контроллер не найден"
  end

  local candidates = {
    { "startRecipe", requirement },
    { "start", requirement },
    { "activate", requirement },
    { "run", requirement },
    { "enable", requirement },
  }

  for _, entry in ipairs(candidates) do
    local method = entry[1]
    local args = entry[2]
    local ok, result = safeCall(controller, method, args)
    if ok then
      logger.info("eoh_core", "Запуск рецепта через метод " .. method)
      return true, result or true
    end
  end

  return false, "Не найден подходящий метод запуска на контроллере EOH"
end

function core.stopRecipe()
  local controller = core.state.controller
  if not controller then return false end
  local ok = tryMethods(controller, { "stop", "disable", "halt", "shutdown" })
  return ok and true or false
end

function core.getSnapshot(settings)
  local status = core.readMachineStatus()
  local fluids = core.readFluidLevels()
  local recipe = core.getSelectedRecipe(settings)
  local requirement = core.computeRequirement(recipe, settings)

  return {
    status = status,
    fluids = fluids,
    recipe = recipe,
    requirement = requirement,
    scanned = core.state.controller ~= nil,
    transposers = #core.state.transposers,
    lastScan = core.state.lastScan,
    lastError = core.state.lastError,
  }
end

function core.runOneCycle(settings)
  settings = settings or config.defaults

  local ok, scanResult = core.ensureScanned()
  if not ok then
    core.state.lastError = scanResult
    logger.error("eoh_core", scanResult)
    return false, scanResult
  end

  local recipe = core.getSelectedRecipe(settings)
  if not recipe then
    local msg = "Не выбран рецепт"
    core.state.lastError = msg
    return false, msg
  end

  if (recipe.hydrogen or 0) == 0 and (recipe.helium or 0) == 0 and (recipe.plasma or 0) == 0 then
    local msg = string.format("Рецепт T%d не заполнен. Проверьте recipes.lua", recipe.tier or 0)
    core.state.lastError = msg
    logger.warn("eoh_core", msg)
    return false, msg
  end

  local requirement = core.computeRequirement(recipe, settings)
  logger.info("eoh_core", string.format("Подготовка рецепта: %s / T%d / AA=%s / OC=%d", requirement.planet, requirement.tier, tostring(requirement.useAA), requirement.overclocks))

  local filled, fillResult = core.ensureFluids(requirement, settings)
  if not filled then
    core.state.lastError = fillResult
    logger.error("eoh_core", fillResult)
    return false, fillResult
  end

  local started, startResult = core.startRecipe(requirement)
  if not started then
    core.state.lastError = startResult
    logger.error("eoh_core", startResult)
    return false, startResult
  end

  -- Наблюдение за выполнением рецепта.
  local status = core.readMachineStatus()
  return true, {
    requirement = requirement,
    status = status,
    fluids = fillResult,
  }
end

function core.waitForCompletion(timeoutSeconds)
  timeoutSeconds = timeoutSeconds or 0
  local start = os.clock()
  while true do
    local status = core.readMachineStatus()
    if not status.active then
      return true, status
    end
    if timeoutSeconds > 0 and (os.clock() - start) > timeoutSeconds then
      return false, "Таймаут ожидания завершения рецепта"
    end
    os.sleep(1)
  end
end

return core
