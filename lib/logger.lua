-- ============================================
-- LOGGER.LUA - Общая система логирования
-- ============================================

local filesystem = require("filesystem")
local os = require("os")

local LOG = {}
LOG.__index = LOG

function LOG.new(basePath, logFileName)
    local self = setmetatable({}, LOG)
    self.buffer = {}
    self.basePath = basePath or "/home"
    self.logFileName = logFileName or "app.log"
    self.path = basePath .. "/logs/" .. logFileName
    self.maxSize = 1024 * 1024  -- 1MB
    self.maxFiles = 5
    return self
end

function LOG:init()
    local logsDir = self.basePath .. "/logs/"
    if not filesystem.exists(logsDir) then
        filesystem.makeDirectory(logsDir)
    end
end

function LOG:write(level, module, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] [%s] [%s] %s", timestamp, level, module, message)
    table.insert(self.buffer, entry)
    self:flush()
end

function LOG:info(module, message) 
    self:write("INFO", module, message) 
end

function LOG:warn(module, message) 
    self:write("WARN", module, message) 
end

function LOG:error(module, message) 
    self:write("ERROR", module, message) 
end

function LOG:debug(module, message) 
    self:write("DEBUG", module, message) 
end

function LOG:flush()
    if #self.buffer == 0 then 
        return 
    end
    local file, err = io.open(self.path, "a")
    if file then
        file:write(table.concat(self.buffer, "\n") .. "\n")
        file:close()
        self.buffer = {}
    else
        -- Fallback: вывод в консоль если файл не доступен
        print("[LOG ERROR] Cannot open log file: " .. tostring(err))
    end
    
    if filesystem.exists(self.path) then
        local size = filesystem.size(self.path)
        if size > self.maxSize then
            self:rotate()
        end
    end
end

function LOG:rotate()
    for i = self.maxFiles - 1, 1, -1 do
        local old = self.path .. "." .. i
        local new = self.path .. "." .. (i + 1)
        if filesystem.exists(old) then
            filesystem.rename(old, new)
        end
    end
    if filesystem.exists(self.path) then
        filesystem.rename(self.path, self.path .. ".1")
    end
end

function LOG:getRecentLines(n)
    n = n or 50
    local lines = {}
    if filesystem.exists(self.path) then
        local file, err = io.open(self.path, "r")
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
        else
            print("[LOG ERROR] Cannot read log file: " .. tostring(err))
        end
    end
    return lines
end

return LOG
