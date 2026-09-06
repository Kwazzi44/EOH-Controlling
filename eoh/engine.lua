-- EOH ENGINE
-- Coordinates one EOH cycle. Hardware bindings come exclusively from context.
local component = require("component")
local computer = require("computer")
local os = require("os")
local runtime = require("runtime")
local transposers = require("transposers")

local M = {}
local START_TIMEOUT = 45
local COMPLETE_TIMEOUT = 86400

local function address(ctx) return ctx.components.eoh or ctx.components.eohController end

local function requiredAmounts(recipe, useAA)
    if useAA then return {hydrogen = 0, helium = 0, plasma = recipe.plasma} end
    return {hydrogen = recipe.hydrogen, helium = recipe.helium, plasma = 0}
end

local function hasEnough(actual, required, tolerance)
    if required <= 0 then return true end
    return actual >= required * math.max(0, 1 - tolerance)
end

local function checkConfigured(ctx, useAA)
    if not address(ctx) then return false, "EOH controller not configured" end
    if useAA then
        local list = ctx.components.transposerPlasmaList or {}
        if #list == 0 and not ctx.components.transposerPlasma then return false, "Plasma transposer not configured" end
    else
        if not (ctx.components.transposerHydrogen or ctx.components.transposerH2) then return false, "Hydrogen transposer not configured" end
        if not (ctx.components.transposerHelium or ctx.components.transposerHe) then return false, "Helium transposer not configured" end
    end
    return true
end

local function supplyReagents(ctx, recipe, useAA)
    local status = runtime.getStatus(ctx)
    local tolerance = tonumber(ctx.settings.tolerance or ctx.config.defaults.tolerance) or 0.001
    local required = requiredAmounts(recipe, useAA)
    if useAA then
        local need = math.max(0, required.plasma - status.plasma)
        if need > 0 then
            local list = ctx.components.transposerPlasmaList
            if type(list) ~= "table" or #list == 0 then list = {ctx.components.transposerPlasma} end
            local ok, err = transposers.supplyList(ctx, list, "Plasma", need)
            if not ok then return false, err end
        end
    else
        local needH2 = math.max(0, required.hydrogen - status.hydrogen)
        if needH2 > 0 then
            local addressH2 = ctx.components.transposerHydrogen or ctx.components.transposerH2
            local ok, err = transposers.supply(ctx, addressH2, "Hydrogen", needH2)
            if not ok then return false, err end
        end
        local afterH2 = runtime.getStatus(ctx)
        local needHe = math.max(0, required.helium - afterH2.helium)
        if needHe > 0 then
            local addressHe = ctx.components.transposerHelium or ctx.components.transposerHe
            local ok, err = transposers.supply(ctx, addressHe, "Helium", needHe)
            if not ok then return false, err end
        end
    end
    local final = runtime.getStatus(ctx)
    if not hasEnough(final.hydrogen, required.hydrogen, tolerance) then return false, "Hydrogen amount is below recipe requirement" end
    if not hasEnough(final.helium, required.helium, tolerance) then return false, "Helium amount is below recipe requirement" end
    if not hasEnough(final.plasma, required.plasma, tolerance) then return false, "Plasma amount is below recipe requirement" end
    return true
end

function M.startRecipe(ctx, tier, useAA, overclocks)
    local controller = address(ctx)
    if not controller then return false, "EOH controller not configured" end
    local recipe = ctx.recipes.get(tier)
    if not recipe then return false, "unknown tier: " .. tostring(tier) end
    local configured, configError = checkConfigured(ctx, useAA)
    if not configured then return false, configError end
    local status = runtime.getStatus(ctx)
    if status.error then return false, status.error end
    if status.active or status.hasWork == true then return false, "EOH already has work" end
    runtime.set(ctx, "LOADING", "Loading reagents")
    local ok, err = supplyReagents(ctx, recipe, useAA)
    if not ok then runtime.set(ctx, "ERROR", tostring(err)); return false, "Fluid supply failed: " .. tostring(err) end
    local requestedOC = tonumber(overclocks) or 0
    if requestedOC > 0 then
        local okOC = pcall(component.invoke, controller, "setOverclock", requestedOC)
        if not okOC then ctx.logger:debug("ENGINE", "Controller has no setOverclock API; OC setting is informational") end
    end
    local okStart, result, reason = pcall(component.invoke, controller, "setWorkAllowed", true)
    if not okStart then runtime.set(ctx, "ERROR", tostring(result)); return false, "EOH start method failed: " .. tostring(result) end
    if result == false then runtime.set(ctx, "ERROR", tostring(reason or "Controller rejected start")); return false, "Controller rejected start" end
    runtime.set(ctx, "STARTING", "Waiting for EOH to start")
    return true, nil
end

function M.waitForCompletion(ctx, timeout)
    local startedAt, started, inactive = computer.uptime(), false, 0
    local limit = tonumber(timeout) or COMPLETE_TIMEOUT
    while computer.uptime() - startedAt < limit do
        local status = runtime.getStatus(ctx)
        if status.error then return false, status.error end
        if status.active or status.hasWork == true or status.progress > 0 then
            started = true; inactive = 0; runtime.set(ctx, "WORK", "EOH is running")
        elseif not started then
            if computer.uptime() - startedAt >= START_TIMEOUT then runtime.set(ctx, "ERROR", "EOH did not start within timeout"); return false, "EOH did not start within " .. tostring(START_TIMEOUT) .. " seconds" end
            os.sleep(0.25)
        else
            inactive = inactive + 1
            if inactive >= 4 then runtime.set(ctx, "READY", "Recipe completed"); return true, nil end
            os.sleep(0.5)
        end
    end
    runtime.set(ctx, "ERROR", "Timeout waiting for EOH completion")
    return false, "timeout waiting for EOH completion"
end

function M.runProduction(ctx, tier, useAA, overclocks, autoRestart)
    while true do
        local ok, err = M.startRecipe(ctx, tier, useAA, overclocks)
        if not ok then runtime.set(ctx, "ERROR", err); return false, err end
        ok, err = M.waitForCompletion(ctx)
        if not ok then runtime.set(ctx, "ERROR", err); return false, err end
        if not autoRestart then return true, nil end
        os.sleep(1)
    end
end

function M.runPower(ctx, autoRestart) return M.runProduction(ctx, 9, false, 0, autoRestart) end
return M
