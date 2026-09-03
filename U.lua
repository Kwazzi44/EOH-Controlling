-- ============================================================
-- EOH Controller - Universal Updater
-- ============================================================
-- Полная синхронизация приложения по update_manifest.lua.
--
-- Алгоритм:
--   1. Скачать свежий manifest во временную область.
--   2. Скачать ВСЕ новые файлы во временную область.
--   3. Проверить, что Lua-файлы компилируются.
--   4. Удалить старые файлы из manifest/remove.
--   5. Установить подготовленные файлы.
--   6. Перезапустить OC.
--
-- Защищённые данные никогда не входят в операции удаления/установки.
-- ============================================================

local component = require("component")
local filesystem = require("filesystem")
local internet = require("internet")
local computer = require("computer")

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"
local MANIFEST_LOCAL = "/home/update_manifest.lua"
local TMP_ROOT = "/home/.eoh_update"
local TMP_MANIFEST = TMP_ROOT .. "/update_manifest.lua"

if not component.isAvailable("internet") then
    print("[ERROR] Internet Card not found")
    return
end

local function mkdirFor(path)
    local dir = filesystem.path(path)
    if dir and dir ~= "/" and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
    end
end

local function readAll(path)
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    local data = f:read("*a")
    f:close()
    return data
end

local function writeDownload(url, dest)
    mkdirFor(dest)

    local ok, err = pcall(function()
        local response = assert(internet.request(url .. "?v=" .. tostring(os.time()) .. tostring(math.random(1000, 9999))))
        local f = assert(io.open(dest, "w"))
        for chunk in response do
            f:write(chunk)
        end
        f:close()
    end)

    if not ok then
        pcall(filesystem.remove, dest)
        return false, err
    end

    local data = readAll(dest)
    if not data or #data == 0 then
        pcall(filesystem.remove, dest)
        return false, "downloaded file is empty"
    end

    return true
end

local function compileLua(path)
    local chunk, err = loadfile(path)
    if not chunk then
        return false, err
    end
    return true
end

local function isProtected(path, protected)
    for _, item in ipairs(protected or {}) do
        if path == item then
            return true
        end
        if item:sub(-1) == "/" and path:sub(1, #item) == item then
            return true
        end
    end
    return false
end

local function targetStagePath(localPath)
    return TMP_ROOT .. "/new" .. localPath
end

local function normalizeEntry(entry)
    if type(entry) == "string" then
        return entry, entry
    end
    if type(entry) == "table" then
        return entry.remote, entry.local
    end
    return nil, nil
end

-- Чистим только собственную временную область.
if filesystem.exists(TMP_ROOT) then
    filesystem.remove(TMP_ROOT)
end
filesystem.makeDirectory(TMP_ROOT)

print("==========================================")
print("       EOH Controller - UPDATE")
print("==========================================")
print("Full application synchronization")
print("")

-- ------------------------------------------------------------
-- 1. Получаем свежий manifest.
-- ------------------------------------------------------------

io.write("[MANIFEST] Downloading ... ")
local ok, err = writeDownload(REPO .. "/update_manifest.lua", TMP_MANIFEST)
if not ok then
    print("FAILED: " .. tostring(err))
    filesystem.remove(TMP_ROOT)
    return
end
print("OK")

local manifestChunk, manifestErr = loadfile(TMP_MANIFEST)
if not manifestChunk then
    print("[MANIFEST] Syntax error: " .. tostring(manifestErr))
    filesystem.remove(TMP_ROOT)
    return
end

local manifestOK, manifest = pcall(manifestChunk)
if not manifestOK or type(manifest) ~= "table" then
    print("[MANIFEST] Invalid manifest")
    filesystem.remove(TMP_ROOT)
    return
end

if type(manifest.files) ~= "table" then
    print("[MANIFEST] files list missing")
    filesystem.remove(TMP_ROOT)
    return
end

local protected = manifest.protected or {}
print("Version: " .. tostring(manifest.version or "unknown"))
print("Build:   " .. tostring(manifest.build or "unknown"))
print("")

-- ------------------------------------------------------------
-- 2. Скачиваем всё во временную область.
-- ------------------------------------------------------------

local entries = {}
local failed = 0

for _, rawEntry in ipairs(manifest.files) do
    local remote, localPath = normalizeEntry(rawEntry)

    if not remote or not localPath then
        print("[ERROR] Invalid manifest entry")
        failed = failed + 1
    elseif isProtected(localPath, protected) then
        print("[SKIP] Protected: " .. localPath)
    else
        local staged = targetStagePath(localPath)
        io.write("[DOWNLOAD] " .. localPath .. " ... ")
        local okDownload, downloadErr = writeDownload(REPO .. "/" .. remote, staged)

        if not okDownload then
            print("FAILED: " .. tostring(downloadErr))
            failed = failed + 1
        else
            -- Компиляция Lua до удаления старой версии.
            if localPath:sub(-4) == ".lua" then
                local okLua, luaErr = compileLua(staged)
                if not okLua then
                    print("FAILED SYNTAX: " .. tostring(luaErr))
                    filesystem.remove(staged)
                    failed = failed + 1
                else
                    print("OK")
                    table.insert(entries, { localPath = localPath, staged = staged })
                end
            else
                print("OK")
                table.insert(entries, { localPath = localPath, staged = staged })
            end
        end
    end
end

if failed > 0 then
    print("")
    print("Update cancelled. Old installation was NOT removed.")
    filesystem.remove(TMP_ROOT)
    return
end

-- ------------------------------------------------------------
-- 3. Удаляем старые файлы программы.
-- ------------------------------------------------------------

print("")
print("Deleting old application files...")

for _, rawEntry in ipairs(manifest.files) do
    local _, localPath = normalizeEntry(rawEntry)

    if localPath and not isProtected(localPath, protected) then
        if localPath ~= "/home/U.lua" and filesystem.exists(localPath) then
            filesystem.remove(localPath)
            print("[DELETE] " .. localPath)
        end
    end
end

for _, localPath in ipairs(manifest.remove or {}) do
    if not isProtected(localPath, protected) and filesystem.exists(localPath) then
        filesystem.remove(localPath)
        print("[REMOVE] " .. localPath)
    end
end

-- ------------------------------------------------------------
-- 4. Устанавливаем новые файлы.
-- ------------------------------------------------------------

print("")
print("Installing new application files...")

local installFailed = false

-- Сначала всё, кроме текущего U.lua.
for _, item in ipairs(entries) do
    if item.localPath ~= "/home/U.lua" then
        mkdirFor(item.localPath)
        if filesystem.exists(item.localPath) then
            filesystem.remove(item.localPath)
        end
        local renamed = filesystem.rename(item.staged, item.localPath)
        if not renamed then
            print("[INSTALL] FAILED: " .. item.localPath)
            installFailed = true
            break
        end
        print("[INSTALL] " .. item.localPath .. " ... OK")
    end
end

if installFailed then
    print("")
    print("Update failed during installation.")
    filesystem.remove(TMP_ROOT)
    return
end

-- U.lua заменяем последним: текущий скрипт уже загружен в память.
for _, item in ipairs(entries) do
    if item.localPath == "/home/U.lua" then
        if filesystem.exists("/home/U.lua") then
            filesystem.remove("/home/U.lua")
        end
        local renamed = filesystem.rename(item.staged, "/home/U.lua")
        if not renamed then
            print("[INSTALL] FAILED: /home/U.lua")
            filesystem.remove(TMP_ROOT)
            return
        end
        print("[INSTALL] /home/U.lua ... OK")
    end
end

filesystem.remove(TMP_ROOT)

print("")
print("==========================================")
print("UPDATE COMPLETE")
print("==========================================")
print("Protected data preserved.")
print("Restarting OC...")

os.sleep(2)
computer.shutdown(true)
