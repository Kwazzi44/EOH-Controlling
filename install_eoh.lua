-- ============================================
-- EOH CONTROLLER INSTALLER / UPDATER
-- ============================================
-- Low-disk-space installer for OpenComputers.
-- User data is protected in /home/eoh_data/.

local filesystem = require("filesystem")
local internet = require("internet")
local os = require("os")
local computer = require("computer")
local serialization = require("serialization")
local term = require("term")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"
local VERSION = "20260906-2302"
local PROTECTED = "/home/eoh_data"

local FILES = {
  "/eoh/eoh_core.lua", "/eoh/context.lua", "/eoh/scanner.lua",
  "/eoh/runtime.lua", "/eoh/transposers.lua", "/eoh/engine.lua",
  "/eoh/diagnose.lua", "/eoh/main.lua", "/eoh/recipes.lua",
  "/hub/main.lua", "/hub/gui.lua", "/hub/theme.lua", "/hub/database.lua",
  "/hub/registry.lua", "/hub/setup.lua", "/lib/config.lua",
  "/lib/settings.lua", "/lib/logger.lua", "/autorun.lua", "/U.lua",
  "/update_manifest.lua", "/install_eoh.lua"
}

local function ensureDir(path)
  if filesystem.exists(path) then return true end
  local ok, err = filesystem.makeDirectory(path)
  if not ok and not filesystem.exists(path) then return false, err end
  return true
end

local function readResponse(request)
  local chunks = {}
  while true do
    local ok, chunk = pcall(request.read)
    if not ok then return nil, "Ошибка чтения HTTP: " .. tostring(chunk) end
    if not chunk then break end
    chunks[#chunks + 1] = chunk
  end
  return table.concat(chunks)
end

local function fetch(url)
  local ok, request = pcall(internet.request, url)
  if not ok or not request then return nil, "Не удалось создать HTTP запрос" end
  local data, err = readResponse(request)
  if not data then return nil, err end
  if data == "" then return nil, "Получен пустой ответ" end
  return data
end

local function checkLua(data, name)
  local loader, err
  if loadstring then loader, err = loadstring(data, name)
  else loader, err = load(data, name) end
  if not loader then return false, err end
  return true
end

local function writeFile(path, data)
  local dir = filesystem.path(path)
  if dir then
    local ok, err = ensureDir(dir)
    if not ok then return false, "Не удалось создать " .. dir .. ": " .. tostring(err) end
  end
  local file, err = io.open(path, "w")
  if not file then return false, tostring(err) end
  local okWrite, writeErr = pcall(file.write, file, data)
  file:close()
  if not okWrite then return false, tostring(writeErr) end
  return true
end

local function readFile(path)
  local file, err = io.open(path, "r")
  if not file then return nil, err end
  local data = file:read("*all")
  file:close()
  return data
end

local function migrateLegacyData()
  local target = PROTECTED .. "/database.dat"
  local oldRegistry = "/home/hub/registry.dat"
  local oldSettings = "/home/eoh/settings.dat"
  if filesystem.exists(target) then return true end
  if not filesystem.exists(oldRegistry) and not filesystem.exists(oldSettings) then return true end

  local data = {schema=1, globalSettings={}, eohs={}}
  if filesystem.exists(oldRegistry) then
    local content, err = readFile(oldRegistry)
    if not content then return false, tostring(err) end
    local saved, reason = serialization.unserialize(content)
    if type(saved) ~= "table" then return false, "Старый registry.dat повреждён: " .. tostring(reason) end
    if saved.eohs then
      data.eohs = saved.eohs
      data.globalSettings = saved.globalSettings or {}
    else
      data.eohs = saved
    end
  end
  if filesystem.exists(oldSettings) then
    local content = readFile(oldSettings)
    if content then
      local saved = serialization.unserialize(content)
      if type(saved) == "table" then
        for k, v in pairs(saved) do data.globalSettings[k] = v end
      end
    end
  end
  local serialized = serialization.serialize(data)
  if not serialized then return false, "Не удалось сериализовать database.dat" end
  local ok, err = writeFile(target, serialized)
  if not ok then return false, err end
  return true
end

local function install()
  term.clear()
  print("============================================================")
  print("          EOH CONTROLLER INSTALLER " .. VERSION)
  print("============================================================")
  print("")
  print("Protected data: " .. PROTECTED .. "/")
  print("Пользовательская база не удаляется и не обновляется.")

  print("")
  print("[1/3] Проверка GitHub...")
  local probe, probeErr = fetch(REPO .. "/README.md")
  if not probe then error("Нет подключения к GitHub: " .. tostring(probeErr)) end
  print("  OK")

  print("")
  print("[2/3] Защита пользовательских данных...")
  local ok, err = ensureDir(PROTECTED)
  if not ok then error("Не удалось создать " .. PROTECTED .. ": " .. tostring(err)) end
  local migrated, migrationErr = migrateLegacyData()
  if not migrated then error("Миграция: " .. tostring(migrationErr)) end
  print("  OK")

  print("")
  print("[3/3] Скачивание и установка файлов...")
  print("  Файлы проверяются в RAM перед записью; временная копия на диске не создаётся.")

  for i, src in ipairs(FILES) do
    local dst = "/home" .. src
    io.write(string.format("  [%02d/%02d] %s ... ", i, #FILES, src))
    local data, downloadErr = fetch(REPO .. src)
    if not data then print("FAIL"); error(src .. ": " .. tostring(downloadErr)) end

    -- Do not search for '<html' or other substrings: valid Lua text may contain them.
    -- Syntax validation is the reliable check for Lua sources.
    if src:sub(-4) == ".lua" then
      local valid, syntaxErr = checkLua(data, src)
      if not valid then print("FAIL"); error("Синтаксическая ошибка в " .. src .. ": " .. tostring(syntaxErr)) end
    end

    local wrote, writeErr = writeFile(dst, data)
    if not wrote then print("FAIL"); error(dst .. ": " .. tostring(writeErr)) end
    print("OK")
  end

  print("")
  print("============================================================")
  print("EOH Controller " .. VERSION .. " установлен.")
  print("Protected data сохранена: " .. PROTECTED .. "/database.dat")
  print("============================================================")
  print("Перезагрузка через 5 секунд...")
  os.sleep(5)
  computer.shutdown(true)
end

local ok, err = xpcall(install, debug.traceback)
if not ok then
  print("")
  print("============================================================")
  print("              ОШИБКА УСТАНОВКИ")
  print("============================================================")
  print(tostring(err))
  print("")
  print("Protected data: " .. PROTECTED .. "/")
  print("Пользовательская база не удаляется установщиком.")
  print("")
  print("Нажмите любую клавишу для выхода...")
  pcall(function() io.read() end)
end
