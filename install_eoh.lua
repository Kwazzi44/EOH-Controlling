-- ============================================
-- EOH CONTROLLER INSTALLER / UPDATER
-- ============================================
-- All program files are replaced on update.
-- The ONLY protected EOH data is /home/eoh_data/.
-- It contains user configuration and hardware bindings only.
-- Do not put recipes, code, runtime cache or logs into that directory.

local filesystem = require("filesystem")
local internet = require("internet")
local os = require("os")
local computer = require("computer")
local serialization = require("serialization")
local term = require("term")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"
local VERSION = "20260906-2300"
local UPDATE_ROOT = "/tmp/eoh_update"

local MANAGED_PATHS = {
    "/home/eoh",
    "/home/hub",
    "/home/lib",
    "/home/autorun.lua",
    "/home/U.lua",
    "/home/update_manifest.lua",
    "/home/install_eoh.lua",
}

local FILES = {
    {src = "/eoh/eoh_core.lua", dst = "/home/eoh/eoh_core.lua"},
    {src = "/eoh/context.lua", dst = "/home/eoh/context.lua"},
    {src = "/eoh/scanner.lua", dst = "/home/eoh/scanner.lua"},
    {src = "/eoh/runtime.lua", dst = "/home/eoh/runtime.lua"},
    {src = "/eoh/transposers.lua", dst = "/home/eoh/transposers.lua"},
    {src = "/eoh/engine.lua", dst = "/home/eoh/engine.lua"},
    {src = "/eoh/diagnose.lua", dst = "/home/eoh/diagnose.lua"},
    {src = "/eoh/main.lua", dst = "/home/eoh/main.lua"},
    {src = "/eoh/recipes.lua", dst = "/home/eoh/recipes.lua"},
    {src = "/hub/main.lua", dst = "/home/hub/main.lua"},
    {src = "/hub/gui.lua", dst = "/home/hub/gui.lua"},
    {src = "/hub/theme.lua", dst = "/home/hub/theme.lua"},
    {src = "/hub/database.lua", dst = "/home/hub/database.lua"},
    {src = "/hub/registry.lua", dst = "/home/hub/registry.lua"},
    {src = "/hub/setup.lua", dst = "/home/hub/setup.lua"},
    {src = "/lib/config.lua", dst = "/home/lib/config.lua"},
    {src = "/lib/settings.lua", dst = "/home/lib/settings.lua"},
    {src = "/lib/logger.lua", dst = "/home/lib/logger.lua"},
    {src = "/autorun.lua", dst = "/home/autorun.lua"},
    {src = "/U.lua", dst = "/home/U.lua"},
    {src = "/update_manifest.lua", dst = "/home/update_manifest.lua"},
    {src = "/install_eoh.lua", dst = "/home/install_eoh.lua"},
}

local function ensureDirectory(path)
    if filesystem.exists(path) then return true end
    local ok, reason = filesystem.makeDirectory(path)
    if not ok and not filesystem.exists(path) then
        return false, reason
    end
    return true
end

local function readResponse(request)
    local chunks = {}
    while true do
        local ok, chunk = pcall(request.read)
        if not ok then
            return nil, "Ошибка чтения HTTP ответа: " .. tostring(chunk)
        end
        if not chunk then break end
        chunks[#chunks + 1] = chunk
    end
    return table.concat(chunks)
end

local function fetch(url)
    local okRequest, request = pcall(internet.request, url)
    if not okRequest or not request then
        return nil, "Не удалось создать HTTP запрос"
    end
    local data, err = readResponse(request)
    if not data then return nil, err end
    if data == "" then return nil, "Получен пустой ответ" end
    return data
end

local function writeFile(path, data)
    local directory = filesystem.path(path)
    if directory then
        local ok, reason = ensureDirectory(directory)
        if not ok then return false, "Не удалось создать " .. directory .. ": " .. tostring(reason) end
    end
    local file, err = io.open(path, "w")
    if not file then return false, tostring(err) end
    file:write(data)
    file:close()
    return true
end

local function readFile(path)
    local file, err = io.open(path, "r")
    if not file then return nil, err end
    local data = file:read("*all")
    file:close()
    return data
end

local function syntaxCheck(path)
    local loader, reason = loadfile(path)
    if not loader then return false, reason end
    return true
end

local function copyFile(source, target)
    local data, err = readFile(source)
    if not data then return false, err end
    return writeFile(target, data)
end

local function migrateLegacyData()
    local dataPath = "/home/eoh_data/database.dat"
    local legacyRegistry = "/home/hub/registry.dat"
    local legacySettings = "/home/eoh/settings.dat"

    if filesystem.exists(dataPath) then return true end
    if not filesystem.exists(legacyRegistry) and not filesystem.exists(legacySettings) then return true end

    print("[MIGRATE] Сохраняем существующие пользовательские настройки...")
    local data = {schema = 1, globalSettings = {}, eohs = {}}

    if filesystem.exists(legacyRegistry) then
        local content, err = readFile(legacyRegistry)
        if not content then return false, "registry.dat: " .. tostring(err) end
        local saved, reason = serialization.unserialize(content)
        if type(saved) == "table" then
            if saved.eohs then
                data.eohs = saved.eohs
                data.globalSettings = saved.globalSettings or {}
            else
                data.eohs = saved
            end
        else
            return false, "Не удалось прочитать старый registry.dat: " .. tostring(reason)
        end
    end

    if filesystem.exists(legacySettings) then
        local content = readFile(legacySettings)
        if content then
            local saved = serialization.unserialize(content)
            if type(saved) == "table" then
                for key, value in pairs(saved) do data.globalSettings[key] = value end
            end
        end
    end

    local serialized = serialization.serialize(data)
    if not serialized then return false, "Не удалось сериализовать protected database" end
    local ok, err = writeFile(dataPath, serialized)
    if not ok then return false, tostring(err) end
    print("[MIGRATE] Protected database создан: " .. dataPath)
    return true
end

local function cleanupManagedPaths()
    print("[CLEANUP] Удаляем старые файлы EOH...")
    for _, path in ipairs(MANAGED_PATHS) do
        if filesystem.exists(path) then
            local ok, reason = filesystem.remove(path)
            if not ok and filesystem.exists(path) then
                return false, "Не удалось удалить " .. path .. ": " .. tostring(reason)
            end
        end
    end
    return true
end

local function downloadAll()
    if filesystem.exists(UPDATE_ROOT) then filesystem.remove(UPDATE_ROOT) end
    local ok, reason = ensureDirectory(UPDATE_ROOT)
    if not ok then error("Не удалось создать " .. UPDATE_ROOT .. ": " .. tostring(reason)) end

    print("[DOWNLOAD] Загружаем новую версию...")
    local installed = 0
    for _, item in ipairs(FILES) do
        io.write("  " .. item.src .. " ... ")
        local data, err = fetch(REPO .. item.src)
        if not data then print("FAIL"); error(item.src .. ": " .. tostring(err)) end
        if item.src:sub(-4) == ".lua"
            and (data:find("<html", 1, true) or data:find("404: Not Found", 1, true)) then
            print("FAIL")
            error(item.src .. ": GitHub вернул не Lua-файл")
        end
        local staged = UPDATE_ROOT .. item.dst:sub(6)
        local wrote, writeErr = writeFile(staged, data)
        if not wrote then print("FAIL"); error(item.src .. ": " .. tostring(writeErr)) end
        print("OK")
        installed = installed + 1
    end
    return installed
end

local function verifyStaged()
    print("[VERIFY] Проверяем новую систему...")
    for _, item in ipairs(FILES) do
        local staged = UPDATE_ROOT .. item.dst:sub(6)
        if item.dst:sub(-4) == ".lua" then
            local ok, reason = syntaxCheck(staged)
            if not ok then error("Синтаксическая ошибка в " .. item.src .. ": " .. tostring(reason)) end
        end
    end
    print("[VERIFY] OK")
end

local function installStaged()
    print("[INSTALL] Заменяем EOH-файлы...")
    for _, item in ipairs(FILES) do
        local staged = UPDATE_ROOT .. item.dst:sub(6)
        local ok, err = copyFile(staged, item.dst)
        if not ok then error("Не удалось установить " .. item.dst .. ": " .. tostring(err)) end
    end
end

local function install()
    term.clear()
    print("============================================================")
    print("          EOH CONTROLLER INSTALLER " .. VERSION)
    print("============================================================")
    print("")
    print("Protected data: /home/eoh_data/")
    print("Только пользовательские настройки и подключения.")

    print("")
    print("[1/6] Проверка подключения...")
    local probe, probeError = fetch(REPO .. "/README.md")
    if not probe then error("Нет подключения к GitHub: " .. tostring(probeError)) end
    print("  OK")

    print("")
    print("[2/6] Защита пользовательских данных...")
    local migrated, migrateError = migrateLegacyData()
    if not migrated then error(migrateError) end
    ensureDirectory("/home/eoh_data")
    print("  OK: /home/eoh_data не будет удалён или обновлён")

    print("")
    print("[3/6] Подготовка новой версии...")
    local installed = downloadAll()
    print("  OK: " .. tostring(installed) .. " файлов")

    print("")
    print("[4/6] Проверка новой версии...")
    verifyStaged()

    print("")
    print("[5/6] Очистка старой версии...")
    local cleaned, cleanError = cleanupManagedPaths()
    if not cleaned then error(cleanError) end
    print("  OK")

    print("")
    print("[6/6] Установка новой версии...")
    installStaged()
    filesystem.remove(UPDATE_ROOT)
    print("  OK")

    print("")
    print("============================================================")
    print("EOH Controller " .. VERSION .. " установлен.")
    print("Пользовательские настройки и подключения сохранены.")
    print("============================================================")
    print("")
    print("Перезагрузка через 5 секунд...")
    os.sleep(5)
    computer.shutdown(true)
end

local ok, err = xpcall(install, debug.traceback)
if not ok then
    if filesystem.exists(UPDATE_ROOT) then filesystem.remove(UPDATE_ROOT) end
    term.clear()
    print("============================================================")
    print("                    ОШИБКА УСТАНОВКИ")
    print("============================================================")
    print("")
    print(tostring(err))
    print("")
    print("Protected data: /home/eoh_data/")
    print("Пользовательская database не удаляется установщиком.")
    print("")
    print("Нажмите любую клавишу для выхода...")
    os.sleep(10)
end
