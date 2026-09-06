-- ============================================
-- AUTORUN.LUA - Автозапуск EOH Controller
-- ============================================

local shell = require("shell")
local term = require("term")

package.path = "/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

term.clear()
print("Запуск EOH Controller...")
local ok, reason = shell.execute("lua /home/hub/main.lua")
if not ok then
  io.stderr:write("Не удалось запустить HUB: " .. tostring(reason) .. "\n")
end