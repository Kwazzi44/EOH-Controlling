-- ============================================================
-- EOH Controller - INSTALLER
-- ============================================================
local REPO="https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"
local component=require("component")
local filesystem=require("filesystem")
local internet=require("internet")
if not component.isAvailable("internet") then print("[ERROR] Internet Card not found"); return end

local FILES={
{"/home/eoh/config.lua","/home/eoh/config.lua"},
{"/home/eoh/logger.lua","/home/eoh/logger.lua"},
{"/home/eoh/recipes.lua","/home/eoh/recipes.lua"},
{"/home/eoh/theme.lua","/home/eoh/theme.lua"},
{"/home/eoh/eoh_core.lua","/home/eoh/eoh_core.lua"},
{"/home/eoh/main.lua","/home/eoh/main.lua"},
{"/home/hub/hub_config.lua","/home/hub/hub_config.lua"},
{"/home/hub/registry.lua","/home/hub/registry.lua"},
{"/home/hub/main.lua","/home/hub/main.lua"},
{"/home/hub/setup.lua","/home/hub/setup.lua"},
{"/U.lua","/home/U.lua"},
{"/autorun.lua","/autorun.lua"}
}
local function parent(path) local d=filesystem.path(path); if d and d~="/" and not filesystem.exists(d) then filesystem.makeDirectory(d) end end
local function download(url,dest) parent(dest); local ok,err=pcall(function() local r=internet.request(url.."?v="..tostring(os.time())); local f=assert(io.open(dest,"w")); for chunk in r do f:write(chunk) end; f:close() end); return ok,err end
print("=========================================="); print("       EOH Controller - INSTALLER"); print("==========================================")
local okc,fail=0,0
for _,e in ipairs(FILES) do io.write("[INSTALL] "..e[2].." ... "); local ok,err=download(REPO..e[1],e[2]); if ok then print("OK");okc=okc+1 else print("FAILED: "..tostring(err));fail=fail+1 end end
-- settings.lua создаём только один раз
if not filesystem.exists("/home/eoh/settings.lua") then
    local f=io.open("/home/eoh/settings.lua","w")
    if f then f:write([[local settings = { auto_refresh = true, last_view = "dashboard", log_lines = 18 }\nreturn settings\n]]);f:close() end
end
print(string.format("Done: %d OK, %d FAILED",okc,fail))
if fail==0 then os.sleep(2); require("computer").shutdown(true) end
