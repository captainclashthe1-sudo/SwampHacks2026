local DataStoreService=game:GetService("DataStoreService")
local store
local storeError
-- New economy baseline: start every player with a clean profile.
local storeOk,storeResult=pcall(function() return DataStoreService:GetDataStore("BridgeBuildersProgress_v3") end)
if storeOk then store=storeResult else storeError=tostring(storeResult) end
local SaveService={}
local VERSION=3

local function key(player)
 return "Player_"..player.UserId
end

function SaveService.Load(player)
 if not store then return nil,false end
 local ok,result=pcall(function() return store:GetAsync(key(player)) end)
 if not ok then
  warn("Bridge Builders save load failed for "..player.UserId..": "..tostring(result))
  return nil,false
 end
 if result==nil then return nil,true end
 if type(result)~="table" or result.Version~=VERSION then
  warn("Bridge Builders found an unsupported save for "..player.UserId)
  return nil,false
 end
 return result,true
end

function SaveService.Write(player,profile)
 if not store then return false,storeError or "DataStore is unavailable." end
 local ok,result=pcall(function()
  return store:UpdateAsync(key(player),function(previous)
   local revision=type(previous)=="table" and tonumber(previous.Revision) or 0
   profile.Version=VERSION
   profile.Revision=(revision or 0)+1
   profile.SavedAt=os.time()
   return profile
  end)
 end)
 if not ok then
  warn("Bridge Builders save write failed for "..player.UserId..": "..tostring(result))
  return false,tostring(result)
 end
 return true
end

return SaveService
