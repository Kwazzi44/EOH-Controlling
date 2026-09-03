-- ============================================================
-- EOH Controller - INSTALLER
-- ============================================================

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"

local component = require("component")
local filesystem = require("filesystem")
local internet = require("internet")

if not component.isAvailable("internet") then
    io.write("[ERROR] Internet Card not found!\n")
    return
end

local FILES = {
    { "/home/eoh/config.lua", "/home/eoh/config.lua" },
    { "/home/eoh/logger.lua", "/home/eoh/logger.lua" },
    { "/home/eoh/recipes.lua", "/home/eoh/recipes.lua" },
    { "/home/eoh/theme.lua", "/home/eoh/theme.lua" },
    { "/home/eoh/eoh_core.lua", "/home/eoh/eoh_core.lua" },
    { "/home/eoh/gui.lua", "/home/eoh/gui.lua" },
    { "/home/eoh/main.lua", "/home/eoh/main.lua" },
    { "/U.lua", "/home/U.lua" },
    { "/autorun.lua", "/autorun.lua" }
}

local function makeParent(path)
    local dir = filesystem.path(path)
    if dir and dir ~= "/" and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
    end
end

local function download(url, dest)
    makeParent(dest)

    local ok, err = pcall(function()
        local response = internet.request(url .. "?v=" .. tostring(os.time()))
        local file = assert(io.open(dest, "w"))
        for chunk in response do
            file:write(chunk)
        end
        file:close()
    end)

    return ok, err
end

io.write("\n==========================================\n")
io.write("       EOH Controller - INSTALLER        \n")
io.write("==========================================\n\n")

local okCount, failCount = 0, 0

for _, entry in ipairs(FILES) do
    io.write("[..] " .. entry[2] .. "\n")
    local ok, err = download(REPO .. entry[1], entry[2])

    if ok then
        io.write("[OK] " .. entry[2] .. "\n")
        okCount = okCount + 1
    else
        io.write("[!!] " .. entry[2] .. " -> " .. tostring(err) .. "\n")
        failCount = failCount + 1
    end
end

io.write(string.format("\nDone: %d OK, %d FAILED\n", okCount, failCount))

if failCount == 0 then
    io.write("Installation complete. Rebooting...\n")
    os.sleep(2)
    require("computer").shutdown(true)
end
