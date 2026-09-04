-- ============================================
-- LOGGER.LUA - Система логирования для HUB
-- ============================================

local filesystem = require("filesystem")
local os = require("os")

local LOG = {
    buffer = {},
    path = "/home/hub/logs/hub.log",
    maxSize = 1024 * 1024,
    maxFiles = 5,
}

function LOG.init()
    if not filesystem.exists("/home/hub/logs/") then
        filesystem.makeDirectory("/home/hub/logs/")
    end
end

function LOG.write(level, module, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] [%s] [%s] %s", timestamp, level, module, message)
    table.insert(LOG.buffer, entry)
    LOG.flush()
end

function LOG.info(module, message)
    LOG.write("INFO", module, message)
end

function LOG.warn(module, message)
    LOG.write("WARN", module, message)
end

function LOG.error(module, message)
    LOG.write("ERROR", module, message)
end

function LOG.debug(module, message)
    LOG.write("DEBUG", module, message)
end

function LOG.flush()
    if #LOG.buffer == 0 then
        return
    end
    local file = io.open(LOG.path, "a")
    if file then
        file:write(table.concat(LOG.buffer, "\n") .. "\n")
        file:close()
        LOG.buffer = {}
    end
    if filesystem.exists(LOG.path) then
        local size = filesystem.size(LOG.path)
        if size > LOG.maxSize then
            LOG.rotate()
        end
    end
end

function LOG.rotate()
    for i = LOG.maxFiles - 1, 1, -1 do
        local old = LOG.path .. "." .. i
        local new = LOG.path .. "." .. (i + 1)
        if filesystem.exists(old) then
            filesystem.rename(old, new)
        end
    end
    if filesystem.exists(LOG.path) then
        filesystem.rename(LOG.path, LOG.path .. ".1")
    end
end

function LOG.getRecentLines(n)
    n = n or 50
    local lines = {}
    if filesystem.exists(LOG.path) then
        local file = io.open(LOG.path, "r")
        if file then
            local allLines = {}
            for line in file:lines() do
                table.insert(allLines, line)
            end
            file:close()
            local start = math.max(1, #allLines - n + 1)
            for i = start, #allLines do
                table.insert(lines, allLines[i])
            end
        end
    end
    return lines
end

return LOG