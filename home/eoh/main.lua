-- Совместимость со старой командой.
package.path="/home/eoh/?.lua;/home/hub/?.lua;"..package.path
local shell=require("shell")
shell.execute("/home/hub/main.lua")
