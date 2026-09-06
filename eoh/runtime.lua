-- EOH RUNTIME
-- Read-only machine state with short caching to keep the HUB responsive.
local component = require("component")
local computer = require("computer")

local M = {}

local function readValue(address, method, ...)
    local ok, value = pcall(component.invoke, address, method, ...)
    if ok then return value end
    return nil
end

local function readNumber(address, method)
    return tonumber(readValue(address, method))
end

local function readBoolean(address, methods)
    for _, method in ipairs(methods) do
        local value = readValue(address, method)
        if type(value) == "boolean" then
            return value
        end
    end
    return nil
end

local function sensorInformation(address)
    local info = readValue(address, "getSensorInformation")
    return type(info) == "table" and info or nil
end

local function parseNumber(text)
    if type(text) ~= "string" then return nil end
    local value = text:match("([%d%.,]+)%s*$")
    if not value then return nil end
    value = value:gsub(",", "")
    return tonumber(value)
end

local function sensorAmount(info, english, russian)
    if not info then return nil end
    for _, line in ipairs(info) do
        local text = tostring(line):gsub("§.", "")
        local lower = string.lower(text)
        if lower:find(english, 1, true)
            or (russian and russian ~= "" and text:find(russian, 1, true)) then
            local value = parseNumber(text)
            if value then return value end
        end
    end
    return nil
end

local function readActive(address)
    local value = readBoolean(address, {"isMachineActive", "isActive", "isWorking"})
    return value == true
end

local function readHasWork(address)
    local value = readBoolean(address, {"hasWork", "isWorking"})
    return value
end

local function readWorkAllowed(address)
    return readBoolean(address, {"isWorkAllowed", "getWorkAllowed", "workAllowed"})
end

local function readTanks(address)
    local tanks = readValue(address, "getTankInfo")
    return type(tanks) == "table" and tanks or nil
end

function M.getStatus(ctx)
    local address = ctx.components.eoh or ctx.components.eohController
    local status = {
        active = false,
        hasWork = nil,
        workAllowed = nil,
        hydrogen = 0,
        helium = 0,
        plasma = 0,
        progress = 0,
        maxProgress = 0,
        error = nil,
    }

    if not address then
        status.error = "Controller not configured"
        return status
    end

    local okProxy, proxy = pcall(component.proxy, address)
    if not okProxy or not proxy then
        status.error = "Controller unavailable"
        return status
    end

    status.active = readActive(address)
    status.hasWork = readHasWork(address)
    status.workAllowed = readWorkAllowed(address)
    status.progress = readNumber(address, "getWorkProgress") or 0
    status.maxProgress = readNumber(address, "getWorkMaxProgress") or 0

    local tanks = readTanks(address)
    if tanks then
        for _, tank in ipairs(tanks) do
            if type(tank) == "table" then
                local contents = tank.contents or tank
                local name = string.lower(tostring(contents.name or contents.label or ""))
                local amount = tonumber(contents.amount or tank.amount or 0) or 0
                if name:find("hydrogen", 1, true) then
                    status.hydrogen = math.max(status.hydrogen, amount)
                elseif name:find("helium", 1, true) then
                    status.helium = math.max(status.helium, amount)
                elseif name:find("plasma", 1, true) then
                    status.plasma = math.max(status.plasma, amount)
                end
            end
        end
    end

    local info = sensorInformation(address)
    local hydrogen = sensorAmount(info, "hydrogen", "водород")
    local helium = sensorAmount(info, "helium", "гелий")
    local plasma = sensorAmount(info, "plasma", "плазм")
    if hydrogen then status.hydrogen = math.max(status.hydrogen, hydrogen) end
    if helium then status.helium = math.max(status.helium, helium) end
    if plasma then status.plasma = math.max(status.plasma, plasma) end
    return status
end

function M.getRuntimeState(ctx)
    local address = ctx.components.eoh or ctx.components.eohController
    if not address then return {stage = "OFF", message = "Controller not configured"} end
    local now = computer.uptime()
    local cached = ctx.runtimeCache[address]
    if cached and now - cached.at < 0.5 then return cached.value end
    local status = M.getStatus(ctx)
    local value
    if status.error then
        value = {stage = "OFF", message = status.error}
    elseif status.active or status.hasWork == true then
        value = {stage = "WORK", progress = status.progress, maximum = status.maxProgress}
    elseif status.workAllowed == false then
        value = {stage = "OFF", message = "Work disabled"}
    else
        value = ctx.runtime[address] or {stage = "READY", message = "Ready"}
    end
    ctx.runtimeCache[address] = {at = now, value = value}
    return value
end

function M.set(ctx, stage, message)
    local address = ctx.components.eoh or ctx.components.eohController
    if address then
        ctx.runtime[address] = {stage = stage, message = message}
        ctx.runtimeCache[address] = nil
    end
end

function M.isActive(address)
    return readActive(address)
end

return M
