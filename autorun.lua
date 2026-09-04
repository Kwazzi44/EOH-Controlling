-- ============================================
-- AUTORUN.LUA - Автозапуск EOH Controller
-- ============================================

local shell = require("shell")
local term = require("term")

term.clear()
print("Запуск EOH Controller...")
shell.execute("lua /home/hub/main.lua")