-- Fill the two edge triangles between adjacent deck cross sections, including slopes.
-- Reuse wedges during simulation; these are free join geometry, not extra members.
local Joins={}
function Joins.Update(folder, sections, collisionGroup)
 local pool=folder:GetChildren(); local used=0
 local function wedge(size,cf,source)
  used+=1
  local p=pool[used]
  if not p then p=Instance.new("WedgePart"); p.Name="DeckJoin"; p.Parent=folder end
  p.Size=size; p.CFrame=cf; p.Anchored=true; p.CanCollide=true; p.CanTouch=false
  p.CollisionGroup=collisionGroup or "Default"; p.Material=source.Material; p.Color=source.Color
  for _,key in ipairs({"OwnerUserId","ObjectId","BuildKind"}) do p:SetAttribute(key,source:GetAttribute(key)) end
 end
 local function triangle(a,b,c,source)
  local ab,ac,bc=b-a,c-a,c-b
  if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
  elseif ac:Dot(ac)>ab:Dot(ab) and ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
  ab,ac,bc=b-a,c-a,c-b
  if bc.Magnitude<.01 or ac:Cross(ab).Magnitude<.01 then return end
  local right=ac:Cross(ab).Unit; local back=bc.Unit; local up=bc:Cross(right).Unit
  local height=math.abs(ab:Dot(up)); local thickness=.65
  -- Offset below the roadway so the fill's upper surface follows the joint.
  local offset=Vector3.new(0,-thickness/2,0)
  wedge(Vector3.new(thickness,height,math.max(.01,math.abs(ab:Dot(back)))),CFrame.fromMatrix((a+b)/2+offset,right,up,back),source)
  wedge(Vector3.new(thickness,height,math.max(.01,math.abs(ac:Dot(back)))),CFrame.fromMatrix((a+c)/2+offset,-right,up,-back),source)
 end
 for _,ends in pairs(sections) do
  for i=1,#ends-1 do for j=i+1,#ends do
   local a,b=ends[i],ends[j]
   local sideA=a.Part.CFrame.RightVector*a.Part.Size.X/2
   local sideB=b.Part.CFrame.RightVector*b.Part.Size.X/2
   if sideA:Dot(sideB)<0 then sideB=-sideB end
   local center=(a.Point+b.Point)/2
   triangle(center,a.Point+sideA,b.Point+sideB,a.Part)
   triangle(center,a.Point-sideA,b.Point-sideB,a.Part)
  end end
 end
 for i=used+1,#pool do pool[i]:Destroy() end
end
return Joins
