-- ============================================
-- REGISTRY.LUA - Регистрация EOH
-- ============================================

local filesystem = require("filesystem")
local serialization = require("serialization")
local logger = dofile("/home/hub/logger.lua")

local REGISTRY = {
    file = "/home/hub/registry.dat",
    eohs = {},
}

function REGISTRY.load()
    REGISTRY.eohs = {}
    if filesystem.exists(REGISTRY.file) then
        local f = io.open(REGISTRY.file, "r")
        if f then
            local data = f:read("*all")
            f:close()
            local loaded, loadError = serialization.unserialize(data)
            if type(loaded) == "table" then
                REGISTRY.eohs = loaded
            elseif logger.warn then
                logger.warn("REGISTRY", "Registry file was not read: "
                    .. tostring(loadError or "invalid data"))
            end
            -- Repair old files that have sparse/missing IDs before callers use
            -- numeric selection indexes.
            for i, eoh in ipairs(REGISTRY.eohs) do
                eoh.id = i
                eoh.settings = eoh.settings or {}
            end
            if logger.info then
                logger.info("REGISTRY", "Загружено " .. #REGISTRY.eohs .. " EOH")
            end
        end
    end
    return REGISTRY.eohs
end

function REGISTRY.save()
    local directory = filesystem.path(REGISTRY.file)
    if directory and not filesystem.exists(directory) then
        filesystem.makeDirectory(directory)
    end
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
    local saved = REGISTRY.save()
    if not saved and logger.error then
        logger.error("REGISTRY", "Не удалось сохранить новый EOH")
    end
    if logger.info then
        logger.info("REGISTRY", "Добавлен EOH #" .. id .. " (" .. REGISTRY.eohs[id].name .. ")")
    end
    return id, saved
end

function REGISTRY.getEOH(index)
    return REGISTRY.eohs[index]
end

function REGISTRY.updateEOH(index, settings)
    if not REGISTRY.eohs[index] then return false end
    REGISTRY.eohs[index].settings = REGISTRY.eohs[index].settings or {}
    for k, v in pairs(settings or {}) do
        REGISTRY.eohs[index].settings[k] = v
    end
    local saved = REGISTRY.save()
    if not saved and logger.error then
        logger.error("REGISTRY", "Не удалось сохранить настройки EOH #" .. index)
    end
    if logger.info then
        logger.info("REGISTRY", "Обновлен EOH #" .. index)
    end
    return saved
end

function REGISTRY.updateComponents(index, components)
    if not REGISTRY.eohs[index] then return false end
    REGISTRY.eohs[index].components = components or {}
    local saved = REGISTRY.save()
    return saved
end

function REGISTRY.removeEOH(index)
    if not REGISTRY.eohs[index] then return false end
    table.remove(REGISTRY.eohs, index)
    for i, eoh in ipairs(REGISTRY.eohs) do eoh.id = i end
    local saved = REGISTRY.save()
    return saved
end

function REGISTRY.getAll()
    return REGISTRY.eohs
end

return REGISTRY
