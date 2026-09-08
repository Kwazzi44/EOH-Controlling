-- ============================================
-- DATABASE.LUA - Protected user configuration
--
-- Code is updateable. User data lives outside the update tree:
--   /home/eoh_data/database.dat
-- ============================================

local filesystem = require("filesystem")
local serialization = require("serialization")

local DB = {
    directory = "/home/eoh_data",
    file = "/home/eoh_data/database.dat",
    tempFile = "/home/eoh_data/database.dat.tmp",
    backupFile = "/home/eoh_data/database.dat.bak",
}

local function ensureDirectory()
    if filesystem.exists(DB.directory) then return true end
    local ok = filesystem.makeDirectory(DB.directory)
    return ok or filesystem.exists(DB.directory)
end

local function emptyData()
    return {schema=1, globalSettings={}, eohs={}}
end

local function normalize(data)
    if type(data) ~= "table" then return emptyData() end
    if data.eohs == nil and #data > 0 then
        return {schema=1, globalSettings={}, eohs=data}
    end
    data.schema = tonumber(data.schema) or 1
    if type(data.globalSettings) ~= "table" then data.globalSettings = {} end
    if type(data.eohs) ~= "table" then data.eohs = {} end
    return data
end

local function readSerialized(path)
    local file, err = io.open(path, "r")
    if not file then return nil, tostring(err) end
    local content = file:read("*all")
    file:close()
    if not content or content == "" then return nil, "Database is empty" end
    local data, reason = serialization.unserialize(content)
    if type(data) ~= "table" then return nil, "Invalid database: " .. tostring(reason) end
    return normalize(data)
end

function DB.exists()
    return filesystem.exists(DB.file)
end

function DB.load()
    if filesystem.exists(DB.file) then
        local data, err = readSerialized(DB.file)
        if data then return data end

        -- The main file exists but is unreadable. Try the last known-good backup.
        if filesystem.exists(DB.backupFile) then
            local backup, backupErr = readSerialized(DB.backupFile)
            if backup then return backup, "Recovered database from backup: " .. tostring(err) end
            return nil, tostring(err) .. "; backup also invalid: " .. tostring(backupErr)
        end
        return nil, err
    end

    if filesystem.exists(DB.backupFile) then
        local backup, err = readSerialized(DB.backupFile)
        if backup then return backup, "Recovered database from backup" end
        return nil, err
    end

    return emptyData()
end

function DB.save(data)
    if not ensureDirectory() then return false, "Cannot create " .. DB.directory end

    data = normalize(data)
    local serialized = serialization.serialize(data)
    if not serialized then return false, "Cannot serialize database" end

    local file, err = io.open(DB.tempFile, "w")
    if not file then return false, "Cannot create database temp file: " .. tostring(err) end
    local wrote, writeErr = pcall(file.write, file, serialized)
    file:close()
    if not wrote then
        pcall(filesystem.remove, DB.tempFile)
        return false, "Cannot write database temp file: " .. tostring(writeErr)
    end

    -- Keep the previous database until the new file is fully installed.
    if filesystem.exists(DB.backupFile) then pcall(filesystem.remove, DB.backupFile) end
    if filesystem.exists(DB.file) then
        if not filesystem.rename(DB.file, DB.backupFile) then
            pcall(filesystem.remove, DB.tempFile)
            return false, "Cannot create database backup"
        end
    end

    if filesystem.rename(DB.tempFile, DB.file) then
        return true
    end

    -- Installation failed: restore the previous database whenever possible.
    if filesystem.exists(DB.file) then pcall(filesystem.remove, DB.file) end
    if filesystem.exists(DB.backupFile) then
        pcall(filesystem.rename, DB.backupFile, DB.file)
    end
    pcall(filesystem.remove, DB.tempFile)
    return false, "Cannot install new database.dat; previous database restored when possible"
end

function DB.defaultData()
    return emptyData()
end

return DB
