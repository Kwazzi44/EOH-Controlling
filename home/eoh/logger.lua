local config = require("config")
local filesystem = require("filesystem")

local logger = {}
local buffer = {}
local ready = false

local function ensureDirectory()
    local dir = filesystem.path(config.log_file)
    if dir and not filesystem.exists(dir) then filesystem.makeDirectory(dir) end
end

local function rotate()
    if not filesystem.exists(config.log_file) then return end
    local size = filesystem.size(config.log_file) or 0
    if size < (config.log_max_bytes or 1048576) then return end
    local old = config.log_file .. ".1"
    pcall(filesystem.remove, old)
    pcall(filesystem.rename, config.log_file, old)
end

local function timestamp()
    local t = os.date("*t")
    return string.format("[%04d-%02d-%02d %02d:%02d:%02d]", t.year,t.month,t.day,t.hour,t.min,t.sec)
end

function logger.init()
    if ready then return end
    ready = true
    ensureDirectory()
end

function logger.log(level, module, message)
    logger.init()
    local line = string.format("%s [%s] [%s] %s", timestamp(), tostring(level), tostring(module), tostring(message))
    rotate()
    local f = io.open(config.log_file, "a")
    if f then f:write(line, "\n"); f:close() end
    table.insert(buffer, line)
    while #buffer > 400 do table.remove(buffer, 1) end
end

function logger.info(m, s) logger.log("INFO",m,s) end
function logger.warn(m, s) logger.log("WARN",m,s) end
function logger.error(m, s) logger.log("ERROR",m,s) end

function logger.load()
    logger.init()
    local f = io.open(config.log_file, "r")
    if not f then return end
    buffer = {}
    for line in f:lines() do
        table.insert(buffer,line)
        if #buffer > 400 then table.remove(buffer,1) end
    end
    f:close()
end

function logger.getLines(n)
    n = tonumber(n) or 18
    local out = {}
    local start = math.max(1,#buffer-n+1)
    for i=start,#buffer do table.insert(out,buffer[i]) end
    return out
end

return logger
