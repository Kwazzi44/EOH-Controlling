-- ============================================
-- DATABASE.LUA - Protected user configuration
--
-- This file is code and may be updated.
-- The actual database is stored outside the update tree:
--   /home/eoh_data/database.dat
--
-- ONLY user-owned EOH configuration is stored here:
--   * EOH names
--   * hardware/component bindings
--   * tier / planet / AA / overclock
--   * user operational settings
-- No runtime cache, recipes, logs or program code belong here.
-- ============================================

local filesystem = require("filesystem")
local serialization = require("serialization")

local DB = {
    directory = "/home/eoh_data",
    file = "/home/eoh_data/database.dat",
    tempFile = "/home/eoh_data/database.dat.tmp",
}

local function ensureDirectory()
    if filesystem.exists(DB.directory) then return true end
    local ok = filesystem.makeDirectory(DB.directory)
    return ok or filesystem.exists(DB.directory)
end

local function emptyData()
    return {
        schema = 1,
        globalSettings = {},
        eohs = {},
    }
end

local function normalize(data)
    if type(data) ~= "table" then
        return emptyData()
    end

    if data.eohs == nil and #data > 0 then
        return {
            schema = 1,
            globalSettings = {},
            eohs = data,
        }
    end

    data.schema = tonumber(data.schema) or 1
    if type(data.globalSettings) ~= "table" then
        data.globalSettings = {}
    end
    if type(data.eohs) ~= "table" then
        data.eohs = {}
    end
    return data
end

function DB.exists()
    return filesystem.exists(DB.file)
end

function DB.load()
    if not DB.exists() then
        return emptyData()
    end

    local file, err = io.open(DB.file, "r")
    if not file then
        return nil, "Cannot open database: " .. tostring(err)
    end

    local content = file:read("*all")
    file:close()
    if not content or content == "" then
        return nil, "Database is empty"
    end

    local data, reason = serialization.unserialize(content)
    if type(data) ~= "table" then
        return nil, "Invalid database: " .. tostring(reason)
    end

    return normalize(data)
end

function DB.save(data)
    if not ensureDirectory() then
        return false, "Cannot create " .. DB.directory
    end

    data = normalize(data)
    local serialized = serialization.serialize(data)
    if not serialized then
        return false, "Cannot serialize database"
    end

    local file, err = io.open(DB.tempFile, "w")
    if not file then
        return false, "Cannot create database temp file: " .. tostring(err)
    end
    file:write(serialized)
    file:close()

    if filesystem.exists(DB.file) then
        filesystem.remove(DB.file)
    end
    if not filesystem.rename(DB.tempFile, DB.file) then
        return false, "Cannot replace database.dat"
    end

    return true
end

function DB.defaultData()
    return emptyData()
end

return DB
