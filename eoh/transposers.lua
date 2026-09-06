-- EOH TRANSPOSERS
-- Fluid routing is explicit and never falls back to a random component.
local component = require("component")
local sides = require("sides")
local os = require("os")
local M = {}

local function sideValue(name, default) return sides[name] or default end
local function tankContents(info)
    if type(info) ~= "table" then return nil end
    if info.name or info.label or info.amount then return info end
    if type(info[1]) == "table" then return info[1] end
    if type(info.contents) == "table" then return info.contents end
    return nil
end

local function getBinding(ctx, address)
    local defaultSource = sideValue(ctx.config.transposer.sourceSide, sides.north)
    local defaultTarget = sideValue(ctx.config.transposer.targetSide, sides.south)
    for _, item in ipairs(ctx.components.transposers or {}) do
        if type(item) == "table" and item.address == address then
            return item.sourceSide or defaultSource, item.targetSide or defaultTarget
        end
    end
    return defaultSource, defaultTarget
end

local function readSource(ctx, address, sourceSide, wanted)
    local ok, info = pcall(component.invoke, address, "getFluidInTank", sourceSide, 1)
    if not ok then return false, 0, nil, "cannot read source tank: " .. tostring(info) end
    local contents = tankContents(info)
    local amount = tonumber(contents and contents.amount or 0) or 0
    local name = contents and (contents.name or contents.label) or nil
    if amount <= 0 then return true, 0, name, "source tank is empty" end
    if wanted and name then
        local lowerName, lowerWanted = string.lower(tostring(name)), string.lower(tostring(wanted))
        if not lowerName:find(lowerWanted, 1, true) then return false, amount, name, "source contains " .. tostring(name) .. ", expected " .. tostring(wanted) end
    end
    return true, amount, name, nil
end

local function targetFree(address, target)
    local okCap, cap = pcall(component.invoke, address, "getTankCapacity", target, 1)
    local okLevel, level = pcall(component.invoke, address, "getTankLevel", target, 1)
    if not okCap or not okLevel then return nil, "cannot read target tank" end
    return math.max(0, (tonumber(cap) or 0) - (tonumber(level) or 0)), nil
end

function M.supply(ctx, address, fluidName, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true, nil, 0 end
    if not address then return false, "transposer not configured", 0 end
    local okProxy, proxy = pcall(component.proxy, address)
    if not okProxy or not proxy then return false, "transposer unavailable", 0 end
    local source, target = getBinding(ctx, address)
    if source == target then return false, "sourceSide and targetSide are identical", 0 end
    local remaining, transferred, stalled = amount, 0, 0
    local lastError = "zero transfer"
    while remaining > 0 do
        local sourceOk, available, sourceName, sourceError = readSource(ctx, address, source, fluidName)
        if not sourceOk then return false, sourceError, transferred end
        if available <= 0 then return false, tostring(fluidName) .. " source tank is empty", transferred end
        local free, freeError = targetFree(address, target)
        if free == nil then return false, freeError, transferred end
        if free <= 0 then return false, "target tank is full", transferred end
        local requested = math.min(remaining, available, free)
        if requested <= 0 then return false, "nothing can be transferred", transferred end
        local ok, movedOk, movedOrError = pcall(component.invoke, address, "transferFluid", source, target, requested)
        if ok and movedOk == true then
            local moved = tonumber(movedOrError) or 0
            if moved > 0 then
                transferred = transferred + moved
                remaining = math.max(0, remaining - moved)
                local controller = ctx.components.eoh or ctx.components.eohController
                if controller then ctx.runtimeCache[controller] = nil end
                stalled, lastError = 0, ""
            else lastError = "transfer returned zero" end
        elseif ok then lastError = tostring(movedOrError or movedOk or "transfer rejected")
        else lastError = tostring(movedOk) end
        if remaining <= 0 then return true, nil, transferred end
        if transferred > amount then return false, "transferred more fluid than requested", transferred end
        if lastError ~= "" and stalled < 20 then stalled = stalled + 1; os.sleep(0.25)
        elseif lastError ~= "" then return false, lastError .. ", remaining " .. tostring(remaining), transferred
        else os.sleep(0.05) end
    end
    return true, nil, transferred
end

function M.supplyList(ctx, addresses, fluidName, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true, nil, 0 end
    if type(addresses) ~= "table" or #addresses == 0 then return false, "no transposer configured", 0 end
    local remaining, transferred, errors = amount, 0, {}
    for _, address in ipairs(addresses) do
        if remaining <= 0 then break end
        local ok, err, moved = M.supply(ctx, address, fluidName, remaining)
        moved = tonumber(moved) or 0
        transferred = transferred + moved
        remaining = math.max(0, amount - transferred)
        if not ok and err then errors[#errors + 1] = tostring(address) .. ": " .. tostring(err) end
    end
    if remaining <= 0 then return true, nil, transferred end
    return false, "unable to transfer " .. tostring(fluidName) .. "; remaining " .. tostring(remaining) .. (#errors > 0 and " [" .. table.concat(errors, " | ") .. "]" or ""), transferred
end
return M
