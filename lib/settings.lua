-- ============================================
-- SETTINGS.LUA - Управление настройками
-- ============================================

local filesystem = require("filesystem")
local serialization = require("serialization")
local config = require("lib.config")

local SETTINGS = {
    file = "/home/eoh/settings.dat",
}

function SETTINGS.load()
    if filesystem.exists(SETTINGS.file) then
        local content = ""
        local result, reason = pcall(function()
            local f, openErr = io.open(SETTINGS.file, "r")
            if not f then
                return nil
            end
            content = f:read("*all")
            f:close()
            return true
        end)

        if not result or content == "" then
            print("⚠️  Config file missing or empty. Using defaults.")
            return
        end

        local saved, err = serialization.unserialize(content)
        if not saved then
            print("⚠️  Ошибка загрузки конфига: " .. tostring(err))
            print("   Будут использованы настройки по умолчанию.")
            return
        end

        for k, v in pairs(saved) do
            config.defaults[k] = v
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
