-- ============================================
-- SETTINGS.LUA - Legacy/global settings facade
-- ============================================
-- User settings are stored in the protected EOH database. This module itself
-- is updateable and contains no user-owned state.

local config = require("lib.config")
local registry = require("registry")

local SETTINGS = {}

function SETTINGS.load()
    registry.load()
    local saved = registry.getGlobalSettings() or {}
    for k, v in pairs(saved) do
        config.defaults[k] = v
    end
end

function SETTINGS.save()
    return registry.updateGlobalSettings(config.defaults)
end

function SETTINGS.get(key)
    return config.defaults[key]
end

function SETTINGS.set(key, value)
    config.defaults[key] = value
    return SETTINGS.save()
end

return SETTINGS
