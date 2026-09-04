-- ============================================
-- SETTINGS.LUA - Управление настройками
-- ============================================

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local filesystem = require("filesystem")
local serialization = require("serialization")
local config = dofile("/home/eoh/config.lua")

config.defaults = config.defaults or {}

local SETTINGS = {
    file = "/home/eoh/settings.dat",
}

function SETTINGS.load()
    if filesystem.exists(SETTINGS.file) then
        local f, openErr = io.open(SETTINGS.file, "r")
        if f then
            local data = f:read("*all")
            f:close()
            local ok, saved = pcall(serialization.unserialize, data)
            if ok and saved then
                for k, v in pairs(saved) do
                    config.defaults[k] = v
                end
            else
                print("⚠️  Ошибка загрузки конфига: " .. tostring(saved or openErr))
                print("   Будут использованы настройки по умолчанию.")
            end
        else
            print("⚠️  Не удалось открыть файл конфига: " .. tostring(openErr))
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