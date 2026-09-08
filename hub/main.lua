-- ============================================
-- MAIN.LUA - HUB entry point
-- ============================================
package.path="/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;"..package.path

local term=require("term")
local computer=require("computer")
local filesystem=require("filesystem")
local os=require("os")
local input=require("input")

local function checkModules()
    local modules={
        {"config","/home/lib/config.lua"},{"settings","/home/lib/settings.lua"},{"registry","/home/hub/registry.lua"},
        {"setup","/home/hub/setup.lua"},{"input","/home/hub/input.lua"},{"logger","/home/lib/logger.lua"},
        {"eoh_core","/home/eoh/eoh_core.lua"},{"gui","/home/hub/gui.lua"},
    }
    for _,mod in ipairs(modules) do
        if not filesystem.exists(mod[2]) then print("Ошибка: файл "..mod[2].." не найден!"); os.sleep(3); return false end
    end
    return true
end
if not checkModules() then return end

local config=require("config")
local registry=require("registry")
local setup=require("setup")
local loggerLib=require("logger")
local logger=loggerLib.new("/home/hub","hub.log"); logger:init()
local core=require("eoh_core")
local gui=require("gui"); gui.setBuild(core.build); gui.init()

local MAIN_REFRESH_INTERVAL=10
local DETAIL_REFRESH_INTERVAL=0.5

local function runtimeSignature(runtime)
    runtime=runtime or {}
    return table.concat({tostring(runtime.stage or "OFF"),tostring(runtime.progress or 0),tostring(runtime.maximum or 0),tostring(runtime.active),tostring(runtime.hasWork),tostring(runtime.workAllowed),tostring(runtime.message or ""),tostring(runtime.hydrogen or 0),tostring(runtime.helium or 0),tostring(runtime.plasma or 0)},":")
end

local function snapshotMain()
    local eohs=registry.getAll(); local runtimes={}
    for index,eoh in ipairs(eohs) do runtimes[index]=core.refreshRuntime(eoh.components,eoh.settings,true) end
    return eohs,runtimes
end

local function showDetail(index)
    local eoh=registry.getEOH(index); if not eoh then return end
    local notice=nil; local lastSignature=nil; local nextRefresh=0
    while true do
        eoh=registry.getEOH(index) or eoh
        local now=computer.uptime(); local runtime
        if now>=nextRefresh then runtime=core.refreshRuntime(eoh.components,eoh.settings,true); nextRefresh=now+DETAIL_REFRESH_INTERVAL
        else runtime=core.getRuntimeState(eoh.components,eoh.settings) end
        local signature=runtimeSignature(runtime)..":"..tostring(notice or "")
        if signature~=lastSignature then gui.drawDetail(eoh,notice,runtime); lastSignature=signature end
        notice=nil

        local key=input.wait(DETAIL_REFRESH_INTERVAL)
        if not key then core.tickConfiguredCycles()
        elseif input.is(key,"enter") then
            setup.runSetup(index); lastSignature=nil; nextRefresh=0
        elseif input.is(key,"f1") then
            setup.runSetup(); lastSignature=nil; nextRefresh=0
        elseif input.is(key,"f3") then
            registry.load(); eoh=registry.getEOH(index) or eoh; lastSignature=nil; nextRefresh=0
        elseif input.is(key,"r") then
            local started,message=core.startConfiguredCycle(eoh.components,eoh.settings or {})
            notice=started and "RUN: recipe cycle started" or "RUN BLOCKED: "..tostring(message); lastSignature=nil
        elseif input.is(key,"back") then return end
    end
end

local function confirmDelete(index)
    local eoh=registry.getEOH(index); if not eoh then return false end
    gui.drawConfirmDelete(eoh)
    while true do
        local key=input.wait(nil)
        if input.is(key,"enter") then return true end
        if input.is(key,"back") then return false end
    end
end

local function deleteSelected(index)
    local eoh=registry.getEOH(index); if not eoh or not confirmDelete(index) then return false end
    core.stopCycle(eoh.components)
    local name=eoh.name
    local ok,err=registry.removeEOH(index)
    if not ok then logger:error("MAIN","Failed to delete EOH #"..tostring(index)..": "..tostring(err)); return false end
    core.dropContext(eoh.components)
    logger:info("MAIN","Deleted EOH #"..tostring(index).." ("..tostring(name)..")")
    return true
end

function main()
    registry.load()
    local selected=1; local nextMainRefresh=0
    for _,eoh in ipairs(registry.getAll()) do
        local settings=eoh.settings or {}
        if settings.autoRestart~=false then core.startConfiguredCycle(eoh.components,settings) end
    end

    while true do
        core.tickConfiguredCycles()
        local now=computer.uptime()
        if now>=nextMainRefresh then
            local eohs,runtimes=snapshotMain(); selected=math.max(1,math.min(selected,math.max(1,#eohs)))
            gui.draw(eohs,selected,config.hubName.." v"..config.version,runtimes); nextMainRefresh=now+MAIN_REFRESH_INTERVAL
        end

        local key=input.wait(0.5)
        if key then
            local eohs=registry.getAll()
            if input.is(key,"up") then
                selected=math.max(1,selected-1); local current,runtimes=snapshotMain(); gui.draw(current,selected,config.hubName.." v"..config.version,runtimes)
            elseif input.is(key,"down") then
                selected=math.min(math.max(1,#eohs),selected+1); local current,runtimes=snapshotMain(); gui.draw(current,selected,config.hubName.." v"..config.version,runtimes)
            elseif input.is(key,"enter") then
                if eohs[selected] then showDetail(selected) end; nextMainRefresh=0
            elseif input.is(key,"f1") then
                setup.runSetup(); registry.load(); nextMainRefresh=0
            elseif input.is(key,"delete") then
                if eohs[selected] and deleteSelected(selected) then selected=math.max(1,math.min(selected,#registry.getAll())) end; nextMainRefresh=0
            elseif input.is(key,"f3") then
                registry.load(); nextMainRefresh=0
            elseif input.is(key,"q") then
                logger:info("MAIN","Выход из программы"); break
            end
        end
    end
end

local ok,err=xpcall(main,debug.traceback)
if not ok then
    term.clear(); print("============================================"); print("КРИТИЧЕСКАЯ ОШИБКА"); print("============================================"); print(""); print(tostring(err)); print(""); print("Проверьте установку файлов /home/hub/ и /home/eoh/"); print("Программа остановлена через 10 секунд..."); os.sleep(10)
end
