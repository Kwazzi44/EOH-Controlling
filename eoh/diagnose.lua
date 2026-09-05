-- EOH DIAGNOSTIC TOOL
-- Safe: reads component state only; never transfers fluid or starts a machine.

local component = require("component")
local filesystem = require("filesystem")
local serialization = require("serialization")
local sides = require("sides")
local term = require("term")

local outputPaths = {
    "/home/eoh/logs/diagnostic.log",
    "/diagnostic.log",
}
local lines = {}

local function line(text)
    text = tostring(text)
    lines[#lines + 1] = text
    print(text)
end

local function call(address, proxy, method, ...)
    local ok, value = pcall(component.invoke, address, method, ...)
    if ok then
        return true, value
    end
    if proxy and type(proxy[method]) == "function" then
        return pcall(proxy[method], ...)
    end
    return false, value
end

local function valueText(value)
    if type(value) == "table" then
        return serialization.serialize(value)
    end
    return tostring(value)
end

local function dumpMethods(proxy)
    local names = {}
    for name, value in pairs(proxy or {}) do
        if type(value) == "function" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return #names > 0 and table.concat(names, ", ") or "<none>"
end

local function componentMethods(address, proxy)
    local ok, methods = pcall(component.methods, address)
    if ok and type(methods) == "table" then
        local names = {}
        for name in pairs(methods) do names[#names + 1] = name end
        table.sort(names)
        return #names > 0 and table.concat(names, ", ") or "<none>"
    end
    return dumpMethods(proxy) .. " (component.methods error: " .. tostring(methods) .. ")"
end

local function dumpSensor(address, proxy)
    local ok, info = call(address, proxy, "getSensorInformation")
    if not ok then
        line("  sensor: unavailable (" .. tostring(info) .. ")")
        return
    end
    if type(info) ~= "table" then
        line("  sensor: " .. valueText(info))
        return
    end
    for index, text in ipairs(info) do
        line("  sensor[" .. index .. "]: " .. tostring(text))
    end
end

local function dumpTank(address, proxy, side)
    local prefix = "  side " .. tostring(side)
    local okCount, count = call(address, proxy, "getTankCount", side)
    count = okCount and tonumber(count) or 1
    line(prefix .. " tankCount=" .. tostring(count))
    for tank = 1, math.max(count, 1) do
        local okCapacity, capacity = call(address, proxy, "getTankCapacity", side, tank)
        local okLevel, level = call(address, proxy, "getTankLevel", side, tank)
        local okInfo, info = call(address, proxy, "getFluidInTank", side, tank)
        line(prefix .. " tank " .. tostring(tank)
            .. " capacity=" .. (okCapacity and valueText(capacity) or "ERR:" .. tostring(capacity))
            .. " level=" .. (okLevel and valueText(level) or "ERR:" .. tostring(level)))
        if okInfo then
            line(prefix .. " tank " .. tostring(tank) .. " fluid=" .. valueText(info))
        else
            line(prefix .. " tank " .. tostring(tank) .. " fluid=ERR:" .. tostring(info))
        end
    end
    if count ~= 0 then
        local okZero, zeroInfo = call(address, proxy, "getFluidInTank", side, 0)
        if okZero then
            line(prefix .. " tank 0 fluid=" .. valueText(zeroInfo))
        end
    end
end

local function dumpComponent(address, name)
    line("")
    line("COMPONENT " .. tostring(name) .. " [" .. tostring(address) .. "]")
    local okProxy, proxy = pcall(component.proxy, address)
    if not okProxy or not proxy then
        line("  proxy: ERROR " .. tostring(proxy))
        return
    end
    line("  proxy type: " .. type(proxy))
    line("  methods: " .. componentMethods(address, proxy))
    if name == "gt_machine" then
        dumpSensor(address, proxy)
        for _, method in ipairs({"isActive", "isMachineActive", "isWorking", "hasWork",
            "getProgress", "getWorkProgress", "getWorkMaxProgress", "getWorkAllowed"}) do
            local ok, result = call(address, proxy, method)
            if ok then line("  " .. method .. "=" .. valueText(result)) end
        end
    elseif name == "transposer" then
        for side = 0, 5 do
            dumpTank(address, proxy, side)
        end
        for _, method in ipairs({"getTransferRate", "getFluidTransferRate"}) do
            local ok, result = call(address, proxy, method, 0)
            if ok then line("  " .. method .. "(0)=" .. valueText(result)) end
        end
    end
end

term.clear()
line("=== EOH FULL DIAGNOSTIC ===")
line("timestamp unavailable (OpenComputers runtime)")
line("diagnostic version: 2")
line("component.isAvailable(gpu)=" .. tostring(component.isAvailable("gpu")))
line("component.isAvailable(gt_machine)=" .. tostring(component.isAvailable("gt_machine")))
line("component.isAvailable(transposer)=" .. tostring(component.isAvailable("transposer")))

line("")
line("GT_MACHINE COMPONENTS")
local machineCount = 0
for address, name in component.list("gt_machine") do
    machineCount = machineCount + 1
    dumpComponent(address, name)
end
line("gt_machine count=" .. machineCount)

line("")
line("TRANSPOSER COMPONENTS")
local transposerCount = 0
for address, name in component.list("transposer") do
    transposerCount = transposerCount + 1
    dumpComponent(address, name)
end
line("transposer count=" .. transposerCount)

line("")
line("SIDES")
for name, value in pairs(sides) do
    if type(value) == "number" then
        line("  " .. tostring(name) .. "=" .. tostring(value))
    end
end

line("")
line("REGISTRY FILE")
local registryPath = "/home/hub/registry.dat"
line("path=" .. registryPath .. " exists=" .. tostring(filesystem.exists(registryPath)))
if filesystem.exists(registryPath) then
    local file = io.open(registryPath, "r")
    if file then
        local data = file:read("*all")
        file:close()
        line("size=" .. tostring(#data))
        line("contents=" .. data)
    else
        line("read=ERROR")
    end
end

for _, outputPath in ipairs(outputPaths) do
    local directory = filesystem.path(outputPath)
    if directory and not filesystem.exists(directory) then
        filesystem.makeDirectory(directory)
    end
    local output = io.open(outputPath, "w")
    if output then
        output:write(table.concat(lines, "\n"))
        output:write("\n")
        output:close()
        line("REPORT SAVED: " .. outputPath)
    else
        line("REPORT SAVE ERROR: " .. outputPath)
    end
end

line("")
line("=== END DIAGNOSTIC ===")
line("Send the complete contents of /diagnostic.log")
