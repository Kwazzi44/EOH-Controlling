local serialization = require("serialization")
local filesystem = require("filesystem")
local config = require("config")

local registry = {}
local data = { eohs = {}, version = 1 }

local function persist()
    local path=config.registry_file
    local dir=filesystem.path(path)
    if dir and not filesystem.exists(dir) then filesystem.makeDirectory(dir) end
    local tmp=path..".tmp"
    local f=io.open(tmp,"w")
    if not f then return false end
    f:write(serialization.serialize(data))
    f:close()
    if filesystem.exists(path) then filesystem.remove(path) end
    return filesystem.rename(tmp,path)
end

function registry.load()
    local f=io.open(config.registry_file,"r")
    if not f then return true end
    local raw=f:read("*a"); f:close()
    local ok,obj=pcall(serialization.unserialize,raw)
    if ok and type(obj)=="table" then data=obj; data.eohs=data.eohs or {} end
    return true
end
function registry.save() return persist() end
function registry.getAll() return data.eohs end
function registry.get(id) return data.eohs[id] end
function registry.add(entry) data.eohs[entry.id]=entry; return persist() end
function registry.remove(id) data.eohs[id]=nil; return persist() end
function registry.count() local n=0 for _ in pairs(data.eohs) do n=n+1 end return n end

return registry
