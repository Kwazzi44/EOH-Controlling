-- ============================================
-- REGISTRY.LUA - Регистрация EOH
-- ============================================

local filesystem = require("filesystem")
local serialization = require("serialization")
local loggerLib = require("logger")
local logger = loggerLib.new("/home/hub", "hub.log")
logger:init()

local REGISTRY = {
    file = "/home/hub/registry.dat",
    eohs = {},
}

function REGISTRY.load()
    REGISTRY.eohs = {}
    if filesystem.exists(REGISTRY.file) then
        local content = ""
        local result, reason = pcall(function()
            local f = io.open(REGISTRY.file, "r")
            if not f then
                return nil
            end
            content = f:read("*all")
            f:close()
            return true
        end)

        if not result or content == "" then
            logger:warn("REGISTRY", "Registry file missing or empty. Starting fresh.")
            return REGISTRY.eohs
        end

        local loaded, loadError = serialization.unserialize(content)
        if type(loaded) ~= "table" then
            logger:warn("REGISTRY", "Registry file was not read: "
                .. tostring(loadError or "invalid data"))
            return REGISTRY.eohs
        end
        REGISTRY.eohs = loaded

        -- Repair old files that have sparse/missing IDs before callers use
        -- numeric selection indexes.
        for i, eoh in ipairs(REGISTRY.eohs) do
            eoh.id = i
            eoh.settings = eoh.settings or {}
        end
        logger:info("REGISTRY", "Загружено " .. #REGISTRY.eohs .. " EOH")
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
    if not saved then
        logger:error("REGISTRY", "Не удалось сохранить новый EOH")
    end
    logger:info("REGISTRY", "Добавлен EOH #" .. id .. " (" .. REGISTRY.eohs[id].name .. ")")
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
    if not saved then
        logger:error("REGISTRY", "Не удалось сохранить настройки EOH #" .. index)
    end
    logger:info("REGISTRY", "Обновлен EOH #" .. index)
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
