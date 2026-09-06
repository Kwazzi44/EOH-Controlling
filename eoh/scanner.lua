-- EOH SCANNER
-- Detects hardware conservatively. Nothing is guessed when the result is ambiguous.
local component = require("component")
local sides = require("sides")
local M = {}
local SIDE_NAMES = {"down", "up", "north", "south", "west", "east"}
local SIDE_BY_NAME = {}
for _, name in ipairs(SIDE_NAMES) do SIDE_BY_NAME[name] = sides[name] end
local function sideName(value)
    for _, name in ipairs(SIDE_NAMES) do if sides[name] == value then return name end end
    return tostring(value)
end
local function clean(text) return string.lower(tostring(text or ""):gsub("§.", "")) end
local function hasMethod(address, method)
    local ok, methods = pcall(component.methods, address)
    return ok and type(methods) == "table" and methods[method] ~= nil
end
local function sensorMarksController(proxy)
    if not proxy or type(proxy.getSensorInformation) ~= "function" then return false end
    local ok, info = pcall(proxy.getSensorInformation)
    if not ok or type(info) ~= "table" then return false end
    for _, line in ipairs(info) do
        local text = clean(line)
        if text:find("progress:",1,true) or text:find("problems",1,true) or text:find("efficiency:",1,true) or text:find("прогресс:",1,true) or text:find("проблемы",1,true) or text:find("эффективность:",1,true) then return true end
    end
    return false
end
local function machineName(proxy, fallback)
    if proxy and type(proxy.getMachineName) == "function" then
        local ok, value = pcall(proxy.getMachineName)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return fallback or "gt_machine"
end
local function controllerEvidence(address, proxy, name)
    local lowerName, reasons, score = clean(name), {}, 0
    local strong = lowerName:find("eye of harmony",1,true) or lowerName:find("eyeofharmony",1,true) or lowerName:find("eoh",1,true)
    if strong then score = score + 100; reasons[#reasons+1] = "machine name" end
    if hasMethod(address,"setWorkAllowed") then score=score+3; reasons[#reasons+1]="setWorkAllowed" end
    if hasMethod(address,"getWorkProgress") then score=score+2; reasons[#reasons+1]="getWorkProgress" end
    if hasMethod(address,"getWorkMaxProgress") then score=score+2; reasons[#reasons+1]="getWorkMaxProgress" end
    if hasMethod(address,"getTankInfo") then score=score+1; reasons[#reasons+1]="getTankInfo" end
    local sensor = sensorMarksController(proxy)
    if sensor then score=score+3; reasons[#reasons+1]="sensor markers" end
    local structural = hasMethod(address,"setWorkAllowed") and hasMethod(address,"getWorkProgress") and hasMethod(address,"getWorkMaxProgress") and sensor
    return {address=address,name=name,score=score,strong=strong and true or false,structural=structural and true or false,candidate=strong and true or false,reasons=reasons}
end
local function tankContents(info)
    if type(info) ~= "table" then return nil end
    if info.name or info.label or info.amount then return info end
    if type(info[1]) == "table" then return info[1] end
    if type(info.contents) == "table" then return info.contents end
    return nil
end
local function inspectTransposer(address, sourceSideName, targetSideName)
    local configuredSource = SIDE_BY_NAME[sourceSideName] or sides.north
    local configuredTarget = SIDE_BY_NAME[targetSideName] or sides.south
    local result={address=address,sourceSide=configuredSource,targetSide=configuredTarget,capacity=0,level=0,fluid=nil,fluidId=nil,role=nil,sides={}}
    for side=0,5 do
        local entry={side=side,name=sideName(side),capacity=0,level=0,fluid=nil,fluidId=nil}
        local okCap,cap=pcall(component.invoke,address,"getTankCapacity",side,1)
        if okCap and tonumber(cap) and tonumber(cap)>0 then entry.capacity=tonumber(cap) end
        local okLevel,level=pcall(component.invoke,address,"getTankLevel",side,1)
        if okLevel and tonumber(level) then entry.level=tonumber(level) end
        local okFluid,info=pcall(component.invoke,address,"getFluidInTank",side,1)
        if okFluid then
            local contents=tankContents(info)
            if contents then entry.fluid=contents.name or contents.label; entry.fluidId=contents.name; entry.level=tonumber(contents.amount) or entry.level end
        end
        if entry.capacity>0 then table.insert(result.sides,entry) end
    end
    for _,entry in ipairs(result.sides) do
        if entry.side==configuredSource then result.capacity=entry.capacity; result.level=entry.level; result.fluid=entry.fluid; result.fluidId=entry.fluidId; break end
    end
    local fluidSides={}
    for _,entry in ipairs(result.sides) do if entry.fluid and entry.level>0 then fluidSides[#fluidSides+1]=entry end end
    if #fluidSides==1 then local entry=fluidSides[1]; result.sourceSide=entry.side; result.capacity=entry.capacity; result.level=entry.level; result.fluid=entry.fluid; result.fluidId=entry.fluidId end
    result.sourceSideName=sideName(result.sourceSide); result.targetSideName=sideName(result.targetSide)
    return result
end
local function roleForFluid(text)
    text=clean(text)
    if text:find("hydrogen",1,true) then return "hydrogen" end
    if text:find("helium",1,true) then return "helium" end
    if text:find("plasma",1,true) then return "plasma" end
    return nil
end
local function detectFluidRole(transposer)
    local roles={}
    local function add(role,entry) if role then roles[role]=roles[role] or {}; roles[role][#roles[role]+1]=entry end end
    for _,entry in ipairs(transposer.sides or {}) do if entry.fluid and entry.level>0 then add(roleForFluid(entry.fluid),entry) end end
    local detected={}
    for role,entries in pairs(roles) do if #entries==1 then detected[role]=entries[1] end end
    return detected
end
function M.scan(excluded, options)
    excluded=excluded or {}; options=options or {}
    local sourceSide,targetSide=options.sourceSide or "north",options.targetSide or "south"
    local found={eoh=nil,controllers={},controllerCandidates={},machines={},transposers={},transposerH2=nil,transposerHe=nil,transposerPlasma=nil,transposerPlasmaList={},all={},warnings={}}
    for address,componentName in component.list("gt_machine") do
        if not excluded[address] then
            local ok,proxy=pcall(component.proxy,address)
            if ok and proxy then
                local name=machineName(proxy,componentName); local evidence=controllerEvidence(address,proxy,name)
                local machine={address=address,name=name,isControllerCandidate=evidence.candidate,score=evidence.score,reasons=evidence.reasons}
                table.insert(found.machines,machine); table.insert(found.all,{address=address,name=name,type="gt_machine"})
                if evidence.candidate then table.insert(found.controllerCandidates,machine) end
            end
        end
    end
    if #found.controllerCandidates==1 then found.eoh=found.controllerCandidates[1].address; found.controllers={found.eoh}
    elseif #found.controllerCandidates>1 then found.warnings[#found.warnings+1]="Несколько кандидатов EOH: контроллер не выбран автоматически."
    else found.warnings[#found.warnings+1]="Контроллер EOH не распознан автоматически." end
    for address in component.list("transposer") do
        if not excluded[address] then
            local ok,details=pcall(inspectTransposer,address,sourceSide,targetSide)
            if ok and details then
                local roles=detectFluidRole(details); details.detectedRoles=roles
                local configuredRole=roleForFluid(details.fluid)
                if configuredRole and roles[configuredRole] then details.role=configuredRole; details.sourceSide=roles[configuredRole].side
                elseif roles.hydrogen and not roles.helium and not roles.plasma then details.role="hydrogen"; details.sourceSide=roles.hydrogen.side
                elseif roles.helium and not roles.hydrogen and not roles.plasma then details.role="helium"; details.sourceSide=roles.helium.side
                elseif roles.plasma and not roles.hydrogen and not roles.helium then details.role="plasma"; details.sourceSide=roles.plasma.side end
                table.insert(found.transposers,details); table.insert(found.all,{address=address,name="transposer",type="transposer"})
                if details.role=="plasma" then found.transposerPlasma=found.transposerPlasma or address; table.insert(found.transposerPlasmaList,address) end
            end
        end
    end
    local h2Candidates,heCandidates={},{}
    for _,item in ipairs(found.transposers) do
        if item.role=="hydrogen" then h2Candidates[#h2Candidates+1]=item.address elseif item.role=="helium" then heCandidates[#heCandidates+1]=item.address end
    end
    found.transposerH2=(#h2Candidates==1) and h2Candidates[1] or nil
    found.transposerHe=(#heCandidates==1) and heCandidates[1] or nil
    if #h2Candidates>1 then found.warnings[#found.warnings+1]="Найдено несколько Hydrogen transposer; выбор требуется вручную." end
    if #heCandidates>1 then found.warnings[#found.warnings+1]="Найдено несколько Helium transposer; выбор требуется вручную." end
    return found
end
M.inspectTransposer=inspectTransposer
M.controllerEvidence=controllerEvidence
return M
