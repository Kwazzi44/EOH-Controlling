-- ============================================
-- REGISTRY.LUA - EOH configuration facade
-- ============================================
-- Registry code is updateable. The actual user database is protected by the
-- installer and lives in /home/eoh_data/database.dat.

local loggerLib = require("lib.logger")
local database = require("database")
local logger = loggerLib.new("/home/hub", "hub.log")
logger:init()

local REGISTRY = {
    eohs = {},
    globalSettings = {},
}

local DEFAULT_SETTINGS = {
    mode = "production",
    tier = 3,
    planet = nil,
    useAA = false,
    overclocks = 0,
    autoRestart = true,
    tolerance = 0.001,
}

local function normalizeSettings(settings)
    local result = {}
    for key, value in pairs(DEFAULT_SETTINGS) do
        result[key] = value
    end
    for key, value in pairs(settings or {}) do
        result[key] = value
    end

    result.tier = math.max(1, math.min(9, tonumber(result.tier) or 3))
    result.overclocks = math.max(0, math.min(3, tonumber(result.overclocks) or 0))
    result.autoRestart = result.autoRestart ~= false
    result.tolerance = math.max(0.001, math.min(0.05, tonumber(result.tolerance) or 0.001))

    if result.mode == "aa" then
        result.useAA = true
    elseif result.mode ~= "aa" then
        result.useAA = false
    end
    return result
end

local function normalizeComponents(components)
    components = components or {}
    components.eoh = components.eoh or components.eohController
    components.eohController = components.eohController or components.eoh
    components.transposerHydrogen = components.transposerHydrogen
        or components.transposerH2
    components.transposerH2 = components.transposerH2
        or components.transposerHydrogen
    components.transposerHelium = components.transposerHelium
        or components.transposerHe
    components.transposerHe = components.transposerHe
        or components.transposerHelium

    if type(components.transposerPlasmaList) ~= "table" then
        if type(components.transposerPlasmaList) == "string" then
            components.transposerPlasmaList = {components.transposerPlasmaList}
        else
            components.transposerPlasmaList = {}
        end
    end
    if type(components.transposers) ~= "table" then
        components.transposers = {}
    end
    return components
end

local function normalizeEOH(eoh, index)
    eoh = eoh or {}
    eoh.id = index
    eoh.name = eoh.name or ("EOH #" .. tostring(index))
    eoh.components = normalizeComponents(eoh.components)
    eoh.settings = normalizeSettings(eoh.settings)
    return eoh
end

local function save()
    local data = database.defaultData()
    data.globalSettings = REGISTRY.globalSettings or {}
    data.eohs = REGISTRY.eohs
    local ok, err = database.save(data)
    if not ok then
        logger:error("REGISTRY", tostring(err))
    end
    return ok
end

function REGISTRY.load()
    REGISTRY.eohs = {}
    REGISTRY.globalSettings = {}

    local data, err = database.load()
    if not data then
        if database.exists() then
            logger:error("REGISTRY", tostring(err))
        end
        return REGISTRY.eohs
    end

    REGISTRY.globalSettings = data.globalSettings or {}
    for index, eoh in ipairs(data.eohs or {}) do
        REGISTRY.eohs[index] = normalizeEOH(eoh, index)
    end

    logger:info("REGISTRY", "Loaded " .. tostring(#REGISTRY.eohs) .. " EOH")
    return REGISTRY.eohs
end

function REGISTRY.save()
    return save()
end

function REGISTRY.addEOH(name, components, settings)
    local id = #REGISTRY.eohs + 1
    REGISTRY.eohs[id] = normalizeEOH({
        id = id,
        name = name,
        components = components,
        settings = settings,
    }, id)

    local saved = save()
    if saved then
        logger:info("REGISTRY", "Added EOH #" .. tostring(id)
            .. " (" .. tostring(REGISTRY.eohs[id].name) .. ")")
    end
    return id, saved
end

function REGISTRY.getEOH(index)
    return REGISTRY.eohs[index]
end

function REGISTRY.updateEOH(index, settings)
    local eoh = REGISTRY.eohs[index]
    if not eoh then return false end

    eoh.settings = normalizeSettings(settings or eoh.settings)
    local saved = save()
    if saved then
        logger:info("REGISTRY", "Updated settings for EOH #" .. tostring(index))
    end
    return saved
end

function REGISTRY.updateComponents(index, components)
    local eoh = REGISTRY.eohs[index]
    if not eoh then return false end

    eoh.components = normalizeComponents(components)
    local saved = save()
    if saved then
        logger:info("REGISTRY", "Updated hardware binding for EOH #" .. tostring(index))
    end
    return saved
end

function REGISTRY.removeEOH(index)
    if not REGISTRY.eohs[index] then return false end

    table.remove(REGISTRY.eohs, index)
    for i, eoh in ipairs(REGISTRY.eohs) do
        eoh.id = i
    end
    return save()
end

function REGISTRY.getAll()
    return REGISTRY.eohs
end

function REGISTRY.getGlobalSettings()
    return REGISTRY.globalSettings
end

function REGISTRY.updateGlobalSettings(settings)
    REGISTRY.globalSettings = settings or {}
    return save()
end

return REGISTRY
