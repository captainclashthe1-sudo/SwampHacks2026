-- A cable mount follows an actual deck cross section, including yaw and slope.
local Mounts={}
function Mounts.Find(beams,nodeId,point)
 local best,bestScore
 for _,beam in pairs(beams) do
  local role=beam:GetAttribute("MemberRole")
  if role=="Deck" or role=="ArchRamp" then
   local linked=beam:GetAttribute("StartNodeId")==nodeId or beam:GetAttribute("EndNodeId")==nodeId
   local localPoint=point and beam.CFrame:PointToObjectSpace(point)
   local onSpan=localPoint and math.abs(localPoint.Z)<=beam.Size.Z/2+.15 and math.abs(localPoint.X)<=beam.Size.X/2 and math.abs(localPoint.Y-beam.Size.Y/2)<=1.5
   if linked or onSpan then
    local score=linked and 0 or 1+math.abs(localPoint.Y-beam.Size.Y/2)
    if not best or score<bestScore or (score==bestScore and (beam:GetAttribute("ObjectId") or "")<(best:GetAttribute("ObjectId") or "")) then best=beam;bestScore=score end
   end
  end
 end
 return best
end
function Mounts.Position(deck,point,side,width)
 if not deck then return point+Vector3.new(0,0,side*(width/2-.12)) end
 local right=deck.CFrame.RightVector
 if right.Z<0 or (math.abs(right.Z)<.001 and right.X<0) then right=-right end
 local localPoint=deck.CFrame:PointToObjectSpace(point)
 local center=deck.CFrame:PointToWorldSpace(Vector3.new(0,deck.Size.Y/2-.08,math.clamp(localPoint.Z,-deck.Size.Z/2,deck.Size.Z/2)))
 return center+right*side*(deck.Size.X/2-.12)
end
return Mounts
