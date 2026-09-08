-- ============================================
-- REGISTRY.LUA - EOH configuration facade
-- ============================================
local loggerLib=require("lib.logger"); local database=require("database"); local logger=loggerLib.new("/home/hub","hub.log"); logger:init()
local REGISTRY={eohs={},globalSettings={}}
local DEFAULT_SETTINGS={mode="production",tier=3,planet=nil,useAA=false,overclocks=0,autoRestart=true,tolerance=0.001}
local function copyTable(value) if type(value)~="table" then return value end local result={};for key,item in pairs(value) do result[key]=copyTable(item) end;return result end
local function normalizeSettings(settings)
    local result=copyTable(DEFAULT_SETTINGS);for key,value in pairs(settings or {}) do result[key]=copyTable(value) end
    result.tier=math.max(1,math.min(9,tonumber(result.tier) or 3));result.overclocks=math.max(0,math.min(3,tonumber(result.overclocks) or 0));result.autoRestart=result.autoRestart~=false;result.tolerance=math.max(0.001,math.min(0.05,tonumber(result.tolerance) or 0.001))
    if result.mode=="aa" then result.mode="production";result.useAA=true else result.mode=result.mode=="power" and "power" or "production";result.useAA=result.useAA==true end
    return result
end
local function normalizeComponents(components)
    local result=copyTable(components or {});result.eoh=result.eoh or result.eohController;result.eohController=result.eohController or result.eoh;result.transposerHydrogen=result.transposerHydrogen or result.transposerH2;result.transposerH2=result.transposerH2 or result.transposerHydrogen;result.transposerHelium=result.transposerHelium or result.transposerHe;result.transposerHe=result.transposerHe or result.transposerHelium
    if type(result.transposerPlasmaList)~="table" then if type(result.transposerPlasmaList)=="string" then result.transposerPlasmaList={result.transposerPlasmaList} else result.transposerPlasmaList={} end end;if type(result.transposers)~="table" then result.transposers={} end;return result
end
local function normalizeEOH(eoh,index) local result=copyTable(eoh or {});result.id=index;result.name=result.name or ("EOH #"..tostring(index));result.components=normalizeComponents(result.components);result.settings=normalizeSettings(result.settings);return result end
local function dataFrom(eohs,globalSettings) local data=database.defaultData();data.globalSettings=copyTable(globalSettings or {});data.eohs=copyTable(eohs or {});return data end
local function commitState(eohs,globalSettings,logMessage) local ok,err=database.save(dataFrom(eohs,globalSettings));if not ok then logger:error("REGISTRY",tostring(err));return false,err end;REGISTRY.eohs=eohs;REGISTRY.globalSettings=globalSettings;if logMessage then logger:info("REGISTRY",logMessage) end;return true end
function REGISTRY.load()
    REGISTRY.eohs={};REGISTRY.globalSettings={};local data,err=database.load();if not data then if database.exists() then logger:error("REGISTRY",tostring(err)) end;return REGISTRY.eohs,err end
    REGISTRY.globalSettings=copyTable(data.globalSettings or {});for index,eoh in ipairs(data.eohs or {}) do REGISTRY.eohs[index]=normalizeEOH(eoh,index) end;logger:info("REGISTRY","Loaded "..tostring(#REGISTRY.eohs).." EOH");return REGISTRY.eohs,err
end
function REGISTRY.save() local ok,err=database.save(dataFrom(REGISTRY.eohs,REGISTRY.globalSettings));if not ok then logger:error("REGISTRY",tostring(err)) end;return ok,err end
function REGISTRY.addEOH(name,components,settings) local proposed=copyTable(REGISTRY.eohs);local id=#proposed+1;proposed[id]=normalizeEOH({name=name,components=components,settings=settings},id);local ok,err=commitState(proposed,copyTable(REGISTRY.globalSettings),"Added EOH #"..tostring(id).." ("..tostring(proposed[id].name)..")");return id,ok,err end
function REGISTRY.getEOH(index) return REGISTRY.eohs[index] end
function REGISTRY.getAll() return REGISTRY.eohs end
function REGISTRY.getGlobalSettings() return REGISTRY.globalSettings end
function REGISTRY.updateEOH(index,settings) local proposed=copyTable(REGISTRY.eohs);if not proposed[index] then return false,"EOH not found" end;proposed[index].settings=normalizeSettings(settings or proposed[index].settings);return commitState(proposed,copyTable(REGISTRY.globalSettings),"Updated settings for EOH #"..tostring(index)) end
function REGISTRY.updateComponents(index,components) local proposed=copyTable(REGISTRY.eohs);if not proposed[index] then return false,"EOH not found" end;proposed[index].components=normalizeComponents(components);return commitState(proposed,copyTable(REGISTRY.globalSettings),"Updated hardware binding for EOH #"..tostring(index)) end
function REGISTRY.removeEOH(index) local proposed=copyTable(REGISTRY.eohs);if not proposed[index] then return false,"EOH not found" end;table.remove(proposed,index);for i,eoh in ipairs(proposed) do eoh.id=i end;return commitState(proposed,copyTable(REGISTRY.globalSettings),"Removed EOH #"..tostring(index)) end
function REGISTRY.updateGlobalSettings(settings) return commitState(copyTable(REGISTRY.eohs),copyTable(settings or {}),"Updated global settings") end
local function addressOf(value) if type(value)=="string" then return value elseif type(value)=="table" then return value.address end return nil end
function REGISTRY.isHardwareBound(address,exceptIndex)
    if not address or address=="" then return false end
    for index,eoh in ipairs(REGISTRY.eohs) do if index~=exceptIndex then local c=eoh.components or {}
        local direct={c.eoh,c.eohController,c.transposerHydrogen,c.transposerH2,c.transposerHelium,c.transposerHe,c.transposerPlasma}
        for _,value in ipairs(direct) do if addressOf(value)==address then return true,index,eoh.name end end
        for _,item in ipairs(c.transposers or {}) do if addressOf(item)==address then return true,index,eoh.name end end
        for _,item in ipairs(c.transposerPlasmaList or {}) do if addressOf(item)==address then return true,index,eoh.name end end
    end end
    return false
end
return REGISTRY
