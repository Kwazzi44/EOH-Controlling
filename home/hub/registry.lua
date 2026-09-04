-- ============================================
-- REGISTRY.LUA - Регистрация EOH
-- ============================================

local filesystem = require("filesystem")
local serialization = require("serialization")
local logger = require("logger")

local REGISTRY = {
    file = "/home/hub/registry.dat",
    eohs = {},
}

function REGISTRY.load()
    if filesystem.exists(REGISTRY.file) then
        local f = io.open(REGISTRY.file, "r")
        if f then
            local data = f:read("*all")
            f:close()
            REGISTRY.eohs = serialization.unserialize(data) or {}
            if logger.info then
                logger.info("REGISTRY", "Загружено " .. #REGISTRY.eohs .. " EOH")
            end
        end
    end
    return REGISTRY.eohs
end

function REGISTRY.save()
    local f = io.open(REGISTRY.file, "w")
    if f then
        f:write(serialization.serialize(REGISTRY.eohs))
        f:close()
        return true
    end
    return false
end

function REGISTRY.addEOH(name, components, settings)
    local id = #REGISTRY.eohs + 1
    REGISTRY.eohs[id] = {
        id = id,
        name = name or "EOH #" .. id,
        components = components or {},
        settings = settings or {
            mode = "production",
            tier = 3,
            useAA = false,
            overclocks = 0,
            autoRestart = true,
            tolerance = 0.001,
        }
    }
    REGISTRY.save()
    if logger.info then
        logger.info("REGISTRY", "Добавлен EOH #" .. id .. " (" .. name .. ")")
    end
    return id
end

function REGISTRY.getEOH(index)
    return REGISTRY.eohs[index]
end

function REGISTRY.updateEOH(index, settings)
    if REGISTRY.eohs[index] then
        for k, v in pairs(settings) do
            REGISTRY.eohs[index].settings[k] = v
        end
        REGISTRY.save()
        if logger.info then
            logger.info("REGISTRY", "Обновлен EOH #" .. index)
        end
        return true
    end
    return false
end

function REGISTRY.getAll()
    return REGISTRY.eohs
end

return REGISTRY