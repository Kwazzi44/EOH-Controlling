-- EOH CONTEXT
-- Immutable-ish per-controller configuration/state boundary.
local configLib = require("lib.config")
local loggerLib = require("lib.logger")
local recipes = require("recipes")

local M = {}

local function copyTable(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do
        result[k] = copyTable(v)
    end
    return result
end

local function defaultSettings()
    return copyTable(configLib.defaults or {})
end

function M.new(components, settings)
    local config = copyTable(configLib)
    config.components = copyTable(components or {})
    if type(config.components.transposerPlasmaList) ~= "table" then
        if type(config.components.transposerPlasmaList) == "string" then
            config.components.transposerPlasmaList = {config.components.transposerPlasmaList}
        else
            config.components.transposerPlasmaList = {}
        end
    end
    if type(config.components.transposers) ~= "table" then
        config.components.transposers = {}
    end
    config.transposer = config.transposer or {}
    config.transposer.sourceSide = config.transposer.sourceSide or "north"
    config.transposer.targetSide = config.transposer.targetSide or "south"
    config.transposer.transferRate = config.transposer.transferRate or 1000

    local normalizedSettings = defaultSettings()
    for key, value in pairs(settings or {}) do
        normalizedSettings[key] = value
    end
    if normalizedSettings.mode == "aa" then
        normalizedSettings.useAA = true
    elseif normalizedSettings.mode ~= "aa" then
        normalizedSettings.useAA = false
    end

    local ctx = {
        config = config,
        components = config.components,
        settings = normalizedSettings,
        recipes = recipes,
        runtime = {},
        runtimeCache = {},
        createdAt = os.clock(),
    }

    ctx.logger = loggerLib.new("/home/eoh", "eoh.log")
    ctx.logger:init()
    return ctx
end

function M.mergeComponents(ctx, components)
    ctx.components = copyTable(components or {})
    ctx.config.components = ctx.components
    if type(ctx.components.transposerPlasmaList) ~= "table" then
        ctx.components.transposerPlasmaList = {}
    end
    if type(ctx.components.transposers) ~= "table" then
        ctx.components.transposers = {}
    end
    ctx.runtimeCache = {}
end

function M.getAddress(ctx)
    return ctx.components.eoh or ctx.components.eohController
end

return M
