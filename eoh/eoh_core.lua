-- EOH CORE FACADE
-- Public API used by HUB and legacy /home/eoh/main.lua.
package.path = "/home/?.lua;/home/eoh/?.lua;/home/hub/?.lua;/home/lib/?.lua;" .. package.path

local context = require("context")
local scanner = require("scanner")
local runtime = require("runtime")
local engine = require("engine")
local thread = require("thread")
local computer = require("computer")
local component = require("component")

local M = {build = "20260906-2300"}
local defaultContext = nil
local runners = {}

local function ctxFor(components, settings)
    if components then return context.new(components, settings) end
    if not defaultContext then defaultContext = context.new({}, {}) end
    return defaultContext
end

function M.setComponents(components)
    defaultContext = context.new(components or {}, {})
    return true
end

function M.scanComponents(excluded)
    local cfg = defaultContext and defaultContext.config or context.new({}, {}).config
    local found = scanner.scan(excluded, {sourceSide = cfg.transposer.sourceSide, targetSide = cfg.transposer.targetSide})
    defaultContext = context.new(found, {})
    return found
end

function M.getStatus(components, settings) return runtime.getStatus(ctxFor(components, settings)) end
function M.getRuntimeState(components, settings) return runtime.getRuntimeState(ctxFor(components, settings)) end
function M.startRecipe(tier, useAA, overclocks, components, settings) return engine.startRecipe(ctxFor(components, settings), tier, useAA, overclocks) end
function M.runProductionMode(tier, useAA, overclocks, autoRestart, components, settings) return engine.runProduction(ctxFor(components, settings), tier, useAA, overclocks, autoRestart) end
function M.runPowerMode(autoRestart, components, settings) return engine.runPower(ctxFor(components, settings), autoRestart) end
function M.waitForCompletion(components, timeout) return engine.waitForCompletion(ctxFor(components), timeout) end

function M.formatNumber(num)
    num = tonumber(num) or 0
    if num >= 1e9 then return string.format("%.1fB", num / 1e9) end
    if num >= 1e6 then return string.format("%.1fM", num / 1e6) end
    if num >= 1e3 then return string.format("%.1fK", num / 1e3) end
    return tostring(num)
end

local function runnerFor(components)
    local address = components and (components.eoh or components.eohController)
    return address, address and runners[address] or nil
end

function M.startConfiguredCycle(components, settings)
    components, settings = components or {}, settings or {}
    local address = components.eoh or components.eohController
    if not address then return false, "Controller not configured" end
    local existing = runners[address]
    if existing and existing.running then return false, "Recipe cycle already running" end
    runners[address] = nil
    local ctx = context.new(components, settings)
    local runner = {ctx=ctx,running=true,thread=nil,startedAt=computer.uptime(),error=nil}
    local function worker()
        local ok, result, message = xpcall(function()
            if ctx.settings.mode == "power" then return engine.runPower(ctx, ctx.settings.autoRestart ~= false) end
            return engine.runProduction(ctx, ctx.settings.tier or 3, ctx.settings.mode == "aa", ctx.settings.overclocks or 0, ctx.settings.autoRestart ~= false)
        end, debug.traceback)
        runner.running = false
        if not ok then
            runner.error = result
            runtime.set(ctx, "ERROR", tostring(result))
            ctx.logger:error("CORE", "Recipe worker crashed: " .. tostring(result))
        elseif result == false then
            runner.error = message or "Recipe cycle failed"
            runtime.set(ctx, "ERROR", tostring(runner.error))
            ctx.logger:error("CORE", "Recipe cycle failed: " .. tostring(runner.error))
        end
    end
    local ok, handle = pcall(thread.create, worker)
    if not ok or not handle then runner.running=false; return false, "Unable to create EOH worker: " .. tostring(handle) end
    runner.thread = handle
    runner.stop = function()
        runner.running=false
        pcall(handle.kill, handle)
        pcall(component.invoke, address, "setWorkAllowed", false)
        runtime.set(ctx, "OFF", "Cycle stopped")
    end
    runner.status = function() return runner.running and "running" or "stopped" end
    runners[address] = runner
    pcall(handle.detach, handle)
    return true, "Recipe cycle started"
end

function M.tick()
    for address, runner in pairs(runners) do if not runner.running then runners[address] = nil end end
end

function M.stopCycle(components)
    local address, runner = runnerFor(components)
    if not runner then return false end
    runner.stop(); runners[address] = nil
    return true
end
function M.isCycleRunning(components)
    local _, runner = runnerFor(components)
    return runner ~= nil and runner.running == true
end
function M.getCycleError(components)
    local _, runner = runnerFor(components)
    return runner and runner.error or nil
end
return M
