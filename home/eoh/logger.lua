-- ============================================================
-- EOH CONTROLLER - LOGGER
-- ============================================================

local config = require("config")
local filesystem = require("filesystem")

local logger = {}
local memory = {}
local initialized = false

local function ensureDirectory()
    local dir = filesystem.path(config.log_file)
    if dir and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
    end
end

local function timestamp()
    local t = os.date("*t")
    return string.format(
        "[%04d-%02d-%02d %02d:%02d:%02d]",
        t.year, t.month, t.day, t.hour, t.min, t.sec
    )
end

local function rotateIfNeeded()
    local path = config.log_file
    if not filesystem.exists(path) then return end

    local size = filesystem.size(path) or 0
    if size < (config.log_max_bytes or 1024 * 1024) then
        return
    end

    local backup = path .. ".1"
    pcall(filesystem.remove, backup)
    pcall(filesystem.rename, path, backup)
end

local function writeLine(line)
    ensureDirectory()
    rotateIfNeeded()

    local file = io.open(config.log_file, "a")
    if file then
        file:write(line, "\n")
        file:close()
    end

    table.insert(memory, line)
    while #memory > 300 do
        table.remove(memory, 1)
    end
end

function logger.init()
    if initialized then return end
    initialized = true
    ensureDirectory()
end

function logger.log(level, module, message)
    writeLine(string.format(
        "%s [%s] [%s] %s",
        timestamp(),
        tostring(level or "INFO"),
        tostring(module or "CORE"),
        tostring(message or "")
    ))
end

function logger.info(module, message)
    logger.log("INFO", module, message)
end

function logger.warn(module, message)
    logger.log("WARN", module, message)
end

function logger.error(module, message)
    logger.log("ERROR", module, message)
end

function logger.getLines(maxLines)
    local n = tonumber(maxLines) or 20
    local result = {}
    local start = math.max(1, #memory - n + 1)

    for i = start, #memory do
        table.insert(result, memory[i])
    end

    return result
end

function logger.load()
    ensureDirectory()

    local file = io.open(config.log_file, "r")
    if not file then return end

    memory = {}
    for line in file:lines() do
        table.insert(memory, line)
        if #memory > 300 then
            table.remove(memory, 1)
        end
    end

    file:close()
end

return logger
