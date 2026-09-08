local component = require("component")
local term = require("term")
local theme = require("theme")
local gui = {}
local gpu = component.isAvailable("gpu") and component.gpu or nil
local C = theme.C
local coreBuild = "unknown"

local stageLabel={OFF="[OFF ]",READY="[STBY]",LOADING="[LOAD]",STARTING="[WAIT]",WORK="[WORK]",NO_EU="[NO EU]",ERROR="[ERR ]"}
local stageColor={OFF=C.dim,READY=C.partial,LOADING=C.key,STARTING=C.warn,WORK=C.ok,NO_EU=C.ring_down,ERROR=C.ring_down}
local function progressPercent(runtime)
    local progress=tonumber(runtime and runtime.progress) or 0; local maximum=tonumber(runtime and (runtime.maximum or runtime.maxProgress)) or 0
    if maximum>0 then return math.max(0,math.min(100,math.floor(progress/maximum*100))) end; return nil
end
local function progressText(runtime) local p=progressPercent(runtime); return p and string.format("%3d%%",p) or "--" end
local function modeName(settings)
    if settings.mode=="power" then return "ENERGY" end
    return settings.useAA and "AA" or "NO AA"
end
local function componentShort(value)
    if type(value)=="table" then value=value.address end; if not value then return "-" end; value=tostring(value); return #value>18 and value:sub(1,18) or value
end
local function drawLine(x,y,width) theme.gset(x,y,string.rep("-",math.max(1,width)),C.border,C.bg) end
local function drawProgressBar(x,y,width,runtime)
    local percent=progressPercent(runtime)
    if not percent then theme.gset(x,y,"[--------------------] --",C.dim,C.bg); return end
    local inner=math.max(1,width-2); local filled=math.floor(inner*percent/100)
    local bar="["..string.rep("#",filled)..string.rep("-",inner-filled).."]"
    theme.gset(x,y,bar,C.ok,C.bg); theme.gset(x+#bar+1,y,string.format("%3d%%",percent),C.text,C.bg)
end
function gui.setBuild(build) coreBuild=tostring(build or "unknown") end
function gui.init() if not gpu then return false end; gpu.setDepth(gpu.maxDepth()); theme.init(gpu); return true end

function gui.drawConfirmDelete(eoh)
    if not gpu then term.clear(); print("DELETE EOH: "..tostring(eoh and eoh.name or "?")); print("ENTER = confirm   B/BACKSPACE = cancel"); return end
    local width,height=theme.getRes(); theme.gfill(1,1,width,height," ",C.text,C.bg); theme.drawHeader("DELETE EOH","CONFIRM")
    local name=tostring(eoh and eoh.name or "Unknown"); theme.gset(4,8,"Delete registered EOH?",C.warn,C.bg); theme.gset(4,10,name:sub(1,width-8),C.title,C.bg)
    theme.gset(4,12,"This removes only its database record.",C.text,C.bg); theme.gset(4,13,"Hardware and world components are NOT touched.",C.dim,C.bg); theme.drawFooter({{"Enter","Delete"},{"B","Cancel"}})
end

function gui.drawDetail(eoh,notice,runtime)
    if not gpu then term.clear(); print("EOH: "..tostring(eoh.name)); print("Status: "..tostring(runtime and runtime.stage or "OFF")); print("Progress: "..progressText(runtime)); print("B = Back, R = Run"); return end
    local width,height=theme.getRes(); local components=eoh.components or {}; local settings=eoh.settings or {}; local controller=components.eoh or components.eohController
    runtime=runtime or {stage=controller and "READY" or "OFF"}; local stage=runtime.stage or "OFF"; local stageText=stageLabel[stage] or "[????]"
    theme.gfill(1,1,width,height," ",C.text,C.bg); theme.drawHeader(tostring(eoh.name).." STATUS",stageText)
    local split=math.floor(width*0.54); if split<38 then split=38 end; if split>width-25 then split=width-25 end
    for y=5,height-2 do theme.gset(split,y,"|",C.border,C.bg) end
    theme.gset(2,5,"#  COMPONENT",C.dim,C.bg); theme.gset(split+2,5,"TELEMETRY",C.dim,C.bg); drawLine(2,6,split-3); drawLine(split+2,6,width-split-3)

    local rows={{"01","EOH Controller",controller}}
    if settings.useAA then rows[#rows+1]={"02","Plasma Transposer",components.transposerPlasma}
    else rows[#rows+1]={"02","H2 Transposer",components.transposerH2}; rows[#rows+1]={"03","He Transposer",components.transposerHe} end
    for i,row in ipairs(rows) do
        local y=6+i; local exists=row[3]~=nil
        theme.gset(2,y,row[1],C.dim,C.bg); theme.gset(6,y,row[2],exists and C.text or C.ring_down,C.bg)
        theme.gset(math.max(24,split-13),y,exists and "[BOUND]" or "[MISSING]",exists and C.ok or C.ring_down,C.bg)
        if exists and y+1<height-2 then theme.gset(6,y+1,componentShort(row[3]),C.dim,C.bg) end
    end

    local tx=split+2; local ty=7; theme.gset(tx,ty,"STATE: ",C.dim,C.bg); theme.gset(tx+7,ty,stageText,stageColor[stage] or C.unknown,C.bg); ty=ty+2
    theme.gset(tx,ty,"Progress:  "..progressText(runtime),C.text,C.bg); ty=ty+1; drawProgressBar(tx,ty,math.min(30,width-tx-4),runtime); ty=ty+2
    if runtime.message then theme.gset(tx,ty,tostring(runtime.message):sub(1,width-tx-1),C.dim,C.bg); ty=ty+2 end
    theme.gset(tx,ty,"Telemetry",C.title,C.bg); ty=ty+1
    theme.gset(tx,ty,"H2: "..tostring(runtime.hydrogen or 0),C.text,C.bg); ty=ty+1
    theme.gset(tx,ty,"He: "..tostring(runtime.helium or 0),C.text,C.bg); ty=ty+1
    theme.gset(tx,ty,"Plasma: "..tostring(runtime.plasma or 0),C.text,C.bg); ty=ty+2
    theme.gset(tx,ty,"Configuration",C.title,C.bg); ty=ty+1
    theme.gset(tx,ty,"Tier:       T"..tostring(settings.tier or 3),C.text,C.bg); ty=ty+1
    theme.gset(tx,ty,"Planet:     "..tostring(settings.planet or "-"),C.text,C.bg); ty=ty+1
    theme.gset(tx,ty,"AA:         "..(settings.useAA and "ON" or "OFF"),C.text,C.bg); ty=ty+1
    theme.gset(tx,ty,"Overclock:  "..tostring(settings.overclocks or 0),C.text,C.bg); ty=ty+1
    theme.gset(tx,ty,"Auto:       "..(settings.autoRestart~=false and "ON" or "OFF"),C.text,C.bg); ty=ty+1
    if notice then theme.gset(tx,math.min(ty,height-4),tostring(notice):sub(1,width-tx-1),C.warn,C.bg) end
    theme.gset(2,height-3,"CORE BUILD: "..coreBuild,C.dim,C.bg); theme.drawFooter({{"B","Back"},{"Enter","Settings"},{"R","Run"},{"F1","Setup"},{"F3","Refresh"}})
end

function gui.draw(eohs,selected,title,runtimes)
    if not gpu then term.clear(); print(title or "EOH CONTROLLER HUB"); for i,eoh in ipairs(eohs or {}) do print((i==selected and "> " or "  ")..i..". "..tostring(eoh.name)) end; return end
    local width,height=theme.getRes(); local total=#(eohs or {}); selected=selected or 1
    theme.gfill(1,1,width,height," ",C.text,C.bg); theme.drawHeader("GTNH EOH MONITOR",string.format("ONLINE - %d EOH",total))
    theme.gset(2,5,"#  EOH NAME",C.dim,C.bg); theme.gset(30,5,"STATUS",C.dim,C.bg); theme.gset(43,5,"ACTIVITY",C.dim,C.bg); theme.gset(62,5,"TIER",C.dim,C.bg); theme.gset(69,5,"OC",C.dim,C.bg); theme.gset(74,5,"AA",C.dim,C.bg); drawLine(2,6,width-3)
    local listHeight=math.max(1,height-10)
    for row=0,listHeight-1 do
        local index=row+1; local y=7+row
        if index<=total then
            local eoh=eohs[index]; local runtime=(runtimes or {})[index] or {stage="OFF"}; local stage=runtime.stage or "OFF"; local selectedRow=index==selected; local bg=selectedRow and C.sel_bg or C.bg
            theme.gfill(2,y,width-3,1," ",C.text,bg); theme.gset(3,y,string.format("%02d",index),C.dim,bg); theme.gset(7,y,tostring(eoh.name or "Unnamed"):sub(1,20),selectedRow and C.sel_fg or C.text,bg)
            theme.gset(30,y,stageLabel[stage] or "[????]",stageColor[stage] or C.unknown,bg)
            local activity=progressText(runtime); if stage=="WORK" then activity="working "..activity elseif stage=="READY" then activity="idle" elseif stage=="OFF" then activity="offline" else activity=string.lower(stage) end
            theme.gset(43,y,activity:sub(1,17),C.text,bg); theme.gset(62,y,"T"..tostring((eoh.settings or {}).tier or 3),C.text,bg); theme.gset(69,y,tostring((eoh.settings or {}).overclocks or 0),C.text,bg); theme.gset(74,y,(eoh.settings or {}).useAA and "ON" or "OFF",C.text,bg)
        end
    end
    theme.gset(2,height-3,string.format("EOH: %d   CORE: %s",total,coreBuild),C.dim,C.bg); theme.drawFooter({{"Enter","Details"},{"F1","Setup"},{"Del","Delete"},{"F3","Refresh"},{"Q","Quit"}})
end
function gui.clear()
    if gpu then local width,height=theme.getRes(); theme.gfill(1,1,width,height," ",C.text,C.bg) else term.clear() end
end
return gui
