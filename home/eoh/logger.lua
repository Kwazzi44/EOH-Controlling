-- logger.lua
-- Простая система логирования с ротацией файла.

local config = require("config")

local logger = {}
logger.levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
logger.currentLevel = logger.levels.INFO

local function now()
  local ok, oslib = pcall(require, "os")
  if ok and oslib and oslib.date then
    return oslib.date("%Y-%m-%d %H:%M:%S")
  end
  return tostring(os.time and os.time() or 0)
end

local function ensureDir(path)
  local ok, filesystem = pcall(require, "filesystem")
  if ok and filesystem and filesystem.exists and not filesystem.exists(path) then
    filesystem.makeDirectory(path)
  end
end

local function fileSize(path)
  local ok, filesystem = pcall(require, "filesystem")
  if ok and filesystem and filesystem.exists and filesystem.size then
    if filesystem.exists(path) then
      return filesystem.size(path)
    end
  end
  return 0
end

local function rotateIfNeeded()
  ensureDir(config.logDir)
  if fileSize(config.logFile) < config.maxLogSize then
    return
  end

  local timestamp = now():gsub("[: ]", "_")
  local rotated = config.logFile .. "." .. timestamp
  local filesystem = require("filesystem")
  if filesystem.exists(rotated) then
    filesystem.remove(rotated)
  end
  filesystem.rename(config.logFile, rotated)
end

local function append(line)
  ensureDir(config.logDir)
  rotateIfNeeded()

  local f = io.open(config.logFile, "a")
  if not f then return false end
  f:write(line, "\n")
  f:close()
  return true
end

function logger.log(level, module, message)
  local lvl = logger.levels[level] or logger.levels.INFO
  if lvl < logger.currentLevel then
    return
  end
  append(string.format("[%s] [%s] [%s] %s", now(), level, module or "core", tostring(message)))
end

function logger.debug(module, message) logger.log("DEBUG", module, message) end
function logger.info(module, message) logger.log("INFO", module, message) end
function logger.warn(module, message) logger.log("WARN", module, message) end
function logger.error(module, message) logger.log("ERROR", module, message) end

function logger.tail(lines)
  lines = lines or config.logHistoryLines
  local f = io.open(config.logFile, "r")
  if not f then return {} end
  local buf = {}
  for line in f:lines() do
    buf[#buf + 1] = line
  end
  f:close()

  local out = {}
  local start = math.max(1, #buf - lines + 1)
  for i = start, #buf do
    out[#out + 1] = buf[i]
  end
  return out
end

return logger
