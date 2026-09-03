-- ============================================================
-- EOH CONTROLLER - U
-- Быстрое обновление: lua /home/U.lua
-- ============================================================
-- ВАЖНО:
-- settings.lua, registry.dat и logs НИКОГДА не скачиваются
-- и не перезаписываются этим updater.
-- ============================================================

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"
local component = require("component")
local filesystem = require("filesystem")
local internet = require("internet")

if not component.isAvailable("internet") then print("[ERROR] Internet Card not found"); return end

local FILES = {
    {"/home/eoh/config.lua", "/home/eoh/config.lua"},
    {"/home/eoh/logger.lua", "/home/eoh/logger.lua"},
    {"/home/eoh/recipes.lua", "/home/eoh/recipes.lua"},
    {"/home/eoh/theme.lua", "/home/eoh/theme.lua"},
    {"/home/eoh/eoh_core.lua", "/home/eoh/eoh_core.lua"},
    {"/home/eoh/main.lua", "/home/eoh/main.lua"},
    {"/home/hub/config.lua", "/home/hub/config.lua"},
    {"/home/hub/registry.lua", "/home/hub/registry.lua"},
    {"/home/hub/main.lua", "/home/hub/main.lua"},
    {"/home/hub/setup.lua", "/home/hub/setup.lua"},
    {"/U.lua", "/home/U.lua"},
    {"/autorun.lua", "/autorun.lua"}
}

local function parent(path)
    local d=filesystem.path(path)
    if d and d~="/" and not filesystem.exists(d) then filesystem.makeDirectory(d) end
end

local function download(url,dest)
    parent(dest)
    local ok,err=pcall(function()
        local resp=internet.request(url.."?v="..tostring(math.random(1000000,9999999)))
        local f=assert(io.open(dest,"w"))
        for chunk in resp do f:write(chunk) end
        f:close()
    end)
    return ok,err
end

print("==========================================")
print("          EOH Controller - UPDATE")
print("==========================================")
print("Saved settings/registry/logs are preserved.")
print("")

local okc,fail=0,0
for _,e in ipairs(FILES) do
    io.write("[UPDATE] "..e[2].." ... ")
    local ok,err=download(REPO..e[1],e[2])
    if ok then print("OK"); okc=okc+1 else print("FAILED: "..tostring(err)); fail=fail+1 end
end

print(string.format("Done: %d OK, %d FAILED",okc,fail))
if fail==0 then
    os.sleep(1)
    require("computer").shutdown(true)
end
