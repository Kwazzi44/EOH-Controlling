-- ============================================
-- SETTINGS.LUA - Управление настройками
-- ============================================

local filesystem = require("filesystem")
local serialization = require("serialization")
local config = require("config")

local SETTINGS = {
    file = "/home/eoh/settings.dat",
}

function SETTINGS.load()
    if filesystem.exists(SETTINGS.file) then
        local f = io.open(SETTINGS.file, "r")
        if f then
            local data = f:read("*all")
            f:close()
            local saved = serialization.unserialize(data)
            if saved then
                for k, v in pairs(saved) do
                    config.defaults[k] = v
                end
            end
        end
    end
end

function SETTINGS.save()
    local f = io.open(SETTINGS.file, "w")
    if f then
        f:write(serialization.serialize(config.defaults))
        f:close()
        return true
    end
    return false
end

function SETTINGS.get(key)
    return config.defaults[key]
end

function SETTINGS.set(key, value)
    config.defaults[key] = value
    SETTINGS.save()
end

return SETTINGS