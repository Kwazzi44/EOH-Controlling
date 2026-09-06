-- ============================================
-- MAIN.LUA - Совместимый запуск EOH Controller
-- ============================================
-- HUB is the single application entry point. This file remains only as a
-- compatibility wrapper for old installations/scripts.

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local shell = require("shell")
local term = require("term")

term.clear()
print("EOH Controller: запускается HUB...")
local ok, reason = shell.execute("lua /home/hub/main.lua")
if not ok then
    io.stderr:write("Не удалось запустить HUB: " .. tostring(reason) .. "\n")
end
