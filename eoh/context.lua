-- EOH CONTEXT
-- Persistent per-EOH state boundary shared by HUB and engine.
local configLib=require("lib.config")
local loggerLib=require("lib.logger")
local recipes=require("recipes")
local M={}
local function copyTable(value)
    if type(value)~="table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copyTable(v) end; return result
end
local function defaultSettings() return copyTable(configLib.defaults or {}) end
local function normalizeComponents(components)
    local result=copyTable(components or {})
    result.eoh=result.eoh or result.eohController; result.eohController=result.eohController or result.eoh
    result.transposerHydrogen=result.transposerHydrogen or result.transposerH2; result.transposerH2=result.transposerH2 or result.transposerHydrogen
    result.transposerHelium=result.transposerHelium or result.transposerHe; result.transposerHe=result.transposerHe or result.transposerHelium
    if type(result.transposerPlasmaList)~="table" then if type(result.transposerPlasmaList)=="string" then result.transposerPlasmaList={result.transposerPlasmaList} else result.transposerPlasmaList={} end end
    if type(result.transposers)~="table" then result.transposers={} end
    return result
end
local function normalizeSettings(settings)
    local result=defaultSettings(); for key,value in pairs(settings or {}) do result[key]=copyTable(value) end; return result
end
function M.new(components,settings)
    local normalizedComponents=normalizeComponents(components); local normalizedSettings=normalizeSettings(settings)
    local ctx={config=copyTable(configLib),components=normalizedComponents,settings=normalizedSettings,recipes=recipes,runtime={stage="OFF",message=nil,updatedAt=0,version=0},runtimeCache={},createdAt=os.clock(),sourceComponents=components,sourceSettings=settings}
    ctx.config.components=ctx.components; ctx.logger=loggerLib.new("/home/eoh","eoh.log"); ctx.logger:init(); return ctx
end
function M.apply(ctx,components,settings)
    local changed=false
    if components~=nil and ctx.sourceComponents~=components then ctx.components=normalizeComponents(components); ctx.config.components=ctx.components; ctx.sourceComponents=components; changed=true end
    if settings~=nil and ctx.sourceSettings~=settings then ctx.settings=normalizeSettings(settings); ctx.sourceSettings=settings; changed=true end
    if changed then ctx.runtimeCache={} end
    return ctx
end
function M.mergeComponents(ctx,components) return M.apply(ctx,components,nil) end
function M.getAddress(ctx) return ctx.components.eoh or ctx.components.eohController end
function M.copy(value) return copyTable(value) end
return M
