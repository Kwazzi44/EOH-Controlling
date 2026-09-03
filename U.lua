-- ============================================================
-- EOH Controller — UPDATER
-- Короткая команда обновления: lua /home/U.lua
-- ============================================================

local REPO = "https://raw.githubusercontent.com/Kwazzi44/EOH-Controlling/main"

local component  = require("component")
local filesystem = require("filesystem")
local internet   = require("internet")

if not component.isAvailable("internet") then
    io.write("[ERROR] Internet Card not found!\n")
    os.exit(1)
end

local FILES = {
    { "/home/eoh/config.lua",   "/home/eoh/config.lua"   },
    { "/home/eoh/logger.lua",   "/home/eoh/logger.lua"   },
    { "/home/eoh/recipes.lua",  "/home/eoh/recipes.lua"  },
    { "/home/eoh/theme.lua",    "/home/eoh/theme.lua"    },
    { "/home/eoh/eoh_core.lua", "/home/eoh/eoh_core.lua" },
    { "/home/eoh/gui.lua",      "/home/eoh/gui.lua"      },
    { "/home/eoh/main.lua",     "/home/eoh/main.lua"     },
    { "/U.lua",                 "/home/U.lua"            },
    { "/autorun.lua",           "/autorun.lua"           },
}

local function mkdirs(dest)
    local dir = filesystem.path(dest)
    if dir and dir ~= "/" and not filesystem.exists(dir) then
        filesystem.makeDirectory(dir)
    end
end

local function download(url, dest)
    mkdirs(dest)

    local bust = "?v=" .. tostring(math.random(1000000, 9999999))

    local ok, err = pcall(function()
        local resp = internet.request(url .. bust)
        local f = assert(io.open(dest, "w"))

        for chunk in resp do
            f:write(chunk)
        end

        f:close()
    end)

    return ok, err
end

io.write("\n==========================================\n")
io.write("          EOH Controller — UPDATER       \n")
io.write("==========================================\n")
io.write("[NOTE] Configuration and logs are NOT removed.\n")
io.write("\n")

local ok_n, fail_n = 0, 0

io.write("Updating EOH Controller files...\n\n")

for _, entry in ipairs(FILES) do
    io.write(string.format("  [..] %-35s", entry[2]))

    local ok, err = download(REPO .. entry[1], entry[2])

    if ok then
        io.write("\r  [OK] " .. entry[2] .. "\n")
        ok_n = ok_n + 1
    else
        io.write("\r  [!!] " .. entry[2] .. "\n")
        io.write("       " .. tostring(err) .. "\n")
        fail_n = fail_n + 1
    end
end

io.write(string.format("\nDone: %d updated, %d failed\n", ok_n, fail_n))

if fail_n == 0 then
    io.write("\nUpdate complete! Rebooting in 3 seconds...\n")
    os.sleep(3)
    require("computer").shutdown(true)
end
