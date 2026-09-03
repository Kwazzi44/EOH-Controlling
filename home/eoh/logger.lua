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
    return os.date("[%Y-%m-%d %H:%M:%S]")
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
    while #memory > 200 do
        table.remove(memory, 1)
    end
end

function logger.init()
    if initialized then return end
    initialized = true
    ensureDirectory()
end

function logger.log(level, module, message)
    level = tostring(level or "INFO")
    module = tostring(module or "CORE")
    message = tostring(message or "")

    local line = string.format(
        "%s [%s] [%s] %s",
        timestamp(),
        level,
        module,
        message
    )

    writeLine(line)
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
        if #memory > 200 then
            table.remove(memory, 1)
        end
    end

    file:close()
end

return logger
