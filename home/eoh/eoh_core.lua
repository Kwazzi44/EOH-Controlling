-- ============================================================
-- EOH CONTROLLER - CORE
-- ============================================================
-- Универсальный read-only/контрольный слой для одного EOH.
-- Реальная передача включается только через config.allow_fluid_transfer.
-- ============================================================

local component = require("component")
local config = require("config")
local recipes = require("recipes")
local logger = require("logger")

local core = {}

local function invoke(address, method, ...)
    return pcall(component.invoke, address, method, ...)
end

local function clean(s) return tostring(s or ""):gsub("§.", "") end
local function lower(s) return clean(s):lower() end

local function fluidName(data)
    if type(data) ~= "table" then return nil end
    return data.name or data.fluidName or data.id
end

local function amountOf(data)
    if type(data) ~= "table" then return 0 end
    return tonumber(data.amount or data.level or 0) or 0
end

local function detectEOH(addr)
    local ok, name = invoke(addr,"getName")
    if ok and lower(name):find("eye_of_harmony",1,true) then return true end
    ok, name = invoke(addr,"getName")
    return ok and lower(name):find("eye of harmony",1,true) ~= nil
end

local function inspectTransposer(addr)
    local result = { address=addr, eohSide=nil, sourceSide=nil, rate=0, tanks={} }
    local bestSourceSide=nil
    local bestSourceCount=0
    for side=0,5 do
        local okName,name = invoke(addr,"getInventoryName",side)
        local okCount,count = invoke(addr,"getTankCount",side)
        name = clean(okName and name or "")
        count = tonumber(okCount and count or 0) or 0
        local n = lower(name)
        if n == "gt.blockmachines" and count > 0 then
            result.eohSide=side
        end
        if count > bestSourceCount and n ~= "gt.blockmachines" then
            bestSourceSide=side
            bestSourceCount=count
        end
    end
    result.sourceSide=bestSourceSide
    if result.sourceSide ~= nil then
        local okCount,count = invoke(addr,"getTankCount",result.sourceSide)
        count = tonumber(okCount and count or 0) or 0
        for tank=1,count do
            local ok,data = invoke(addr,"getFluidInTank",result.sourceSide,tank)
            local fname = ok and fluidName(data) or nil
            result.tanks[tank] = {name=fname, amount=amountOf(data), side=result.sourceSide, tank=tank}
        end
    end
    local okRate,rate = invoke(addr,"getFluidTransferRate")
    result.rate = tonumber(okRate and rate or 0) or 0
    return result
end

function core.scanAll()
    local eohs={}
    for addr,_ in component.list("gt_machine") do
        if detectEOH(addr) then
            local ok,name=invoke(addr,"getName")
            table.insert(eohs,{address=addr,name=clean(ok and name or "Eye of Harmony")})
        end
    end
    table.sort(eohs,function(a,b) return a.address < b.address end)
    local transposers={}
    for addr,_ in component.list("transposer") do
        local t=inspectTransposer(addr)
        if t.eohSide ~= nil and t.sourceSide ~= nil then table.insert(transposers,t) end
    end
    table.sort(transposers,function(a,b) return a.address < b.address end)
    return eohs,transposers
end

function core.scan()
    local eohs,transposers=core.scanAll()
    if #eohs==0 then return nil,{},"EOH controller not found" end
    return eohs[1],transposers
end

function core.readStatus(eoh)
    if not eoh then return nil end
    local a={}
    local ok,v=invoke(eoh.address,"isMachineActive"); a.active=ok and v or false
    ok,v=invoke(eoh.address,"hasWork"); a.hasWork=ok and v or false
    ok,v=invoke(eoh.address,"isWorkAllowed"); a.workAllowed=ok and v or false
    ok,v=invoke(eoh.address,"getWorkProgress"); a.progress=tonumber(ok and v or 0) or 0
    ok,v=invoke(eoh.address,"getWorkMaxProgress"); a.maxProgress=tonumber(ok and v or 0) or 0
    a.percent=a.maxProgress>0 and math.max(0,math.min(100,a.progress*100/a.maxProgress)) or 0
    return a
end

local function sensorLines(eoh)
    local ok,data=invoke(eoh.address,"getSensorInformation")
    return ok and type(data)=="table" and data or {}
end

function core.readSensor(eoh)
    local lines=sensorLines(eoh)
    local out={lines=lines, aa=0, activeAA=0, success=nil, overclocks=0}
    for _,line in ipairs(lines) do
        local s=clean(line)
        local l=lower(s)
        local n=tonumber(s:match("(%d+)%s*$"))
        if l:find("astral",1,true) and l:find("массив",1,true) then out.aa=n or out.aa end
        if l:find("действующие",1,true) and l:find("астраль",1,true) then out.activeAA=n or out.activeAA end
        if l:find("овер",1,true) or l:find("потеп",1,true) then out.overclocks=n or out.overclocks end
        if l:find("шанс",1,true) and l:find("успех",1,true) then out.success=s:match("([%d%.,]+)%s*%%") or nil end
    end
    return out
end

function core.readEOHFluids(eoh)
    local data={hydrogen=0,helium=0,plasma=0}
    local lines=sensorLines(eoh)
    for _,line in ipairs(lines) do
        local s=clean(line); local l=lower(s)
        local num=s:match("([%d][%d%.,]*)")
        if num then
            num=num:gsub(",","")
            local value=tonumber(num) or 0
            if l:find("водород",1,true) or l:find("hydrogen",1,true) then data.hydrogen=value end
            if l:find("гелий",1,true) or l:find("helium",1,true) then data.helium=value end
            if l:find("плазм",1,true) or l:find("plasma",1,true) then data.plasma=value end
        end
    end
    return data
end

function core.recipeFor(entry)
    if entry.mode == "power" then return recipes.get(9) end
    return recipes.get(entry.tier)
end

function core.requiredFluids(entry, recipe)
    if not recipe then return {} end
    if entry.mode == "production_aa" then
        return { plasma = recipe.plasma }
    end
    return { hydrogen = recipe.hydrogen, helium = recipe.helium }
end

local function sumRate(list)
    local r=0
    for _,c in ipairs(list) do r=r+math.max(0,tonumber(c.rate) or 0) end
    return r
end

local function distribute(amount, channels)
    local plan={}
    if #channels==0 then return plan end
    local totalRate=sumRate(channels)
    if totalRate<=0 then
        plan[1]={channel=channels[1], amount=amount}
        return plan
    end
    local allocated=0
    for i,ch in ipairs(channels) do
        local share
        if i==#channels then share=amount-allocated else share=math.floor(amount*(ch.rate/totalRate)) end
        allocated=allocated+share
        table.insert(plan,{channel=ch,amount=share})
    end
    return plan
end

function core.calculatePlan(entry, recipe)
    local required=core.requiredFluids(entry,recipe)
    local channels=entry.channels or {}
    local out={mode=entry.mode,tier=entry.tier,recipe=recipe and recipe.display,fluids={}}
    local totalTime=0
    for fluid,amount in pairs(required) do
        local matching={}
        for _,ch in ipairs(channels) do if ch.fluid==fluid then table.insert(matching,ch) end end
        local allocations=distribute(amount,matching)
        local slow=0
        for _,a in ipairs(allocations) do
            local sec=(a.channel.rate or 0)>0 and a.amount/a.channel.rate or math.huge
            if sec>slow then slow=sec end
        end
        if slow>totalTime and slow<math.huge then totalTime=slow end
        out.fluids[fluid]={required=amount,channels=allocations,available=sumRate(matching)>0}
    end
    out.estimated_seconds=totalTime
    out.total_required={}
    for f,v in pairs(required) do out.total_required[f]=v end
    return out
end

function core.findSourceAmount(channel)
    local ok,data=invoke(channel.transposer,"getFluidInTank",channel.sourceSide,channel.sourceTank)
    if not ok then return nil,0 end
    return fluidName(data), amountOf(data)
end

function core.transfer(entry, fluid, amount)
    if not config.allow_fluid_transfer then return false,0,"live transfer disabled" end
    local remaining=math.max(0,math.floor(amount))
    local moved=0
    local attempts=0
    for _,ch in ipairs(entry.channels or {}) do
        if ch.fluid==fluid and remaining>0 then
            local ok,n=invoke(ch.transposer,"transferFluid",ch.sourceSide,ch.eohSide,remaining,ch.sourceTank)
            attempts=attempts+1
            local got=ok and (tonumber(n) or 0) or 0
            moved=moved+got
            remaining=math.max(0,remaining-got)
            if attempts >= (config.max_transfer_attempts or 10000) then break end
        end
    end
    return moved>0,moved,remaining==0 and nil or "not enough transferred"
end

return core
