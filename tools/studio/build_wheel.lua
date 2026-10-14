-- Builds the permanent plaza LuckyWheel. Re-run in Edit mode; only replaces this model.
-- Edit-mode require can retain a table from before Rojo's latest sync; read the current data source.
local Rewards = assert(loadstring(game.ReplicatedStorage.Shared.WheelRewards.Source))()
assert(Rewards[1].arc, "WheelRewards has not synced yet")
local old = workspace:FindFirstChild("LuckyWheel")
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "LuckyWheel"
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local angle = math.rad(300)
local pos = Vector3.new(math.sin(angle) * 36, -1.7, -math.cos(angle) * 36)
local frame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
model.WorldPivot = frame
local STONE = Color3.fromRGB(57, 61, 65)
local DARK = Color3.fromRGB(25, 29, 31)
local BONE = Color3.fromRGB(186, 178, 148)
local IRON = Color3.fromRGB(49, 53, 52)
local BRONZE = Color3.fromRGB(129, 104, 61)
local SOUL = Color3.fromRGB(95, 230, 150)

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = frame * cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
local function block(name, size, at, color, mat)
	return part(model, name, size, CFrame.new(at), color, mat)
end
local function rod(parent, name, a, b, width, color, mat)
	return part(parent, name, Vector3.new(width, width, (b-a).Magnitude),
		CFrame.lookAt((a+b)/2, b), color, mat)
end
local function skull(parent, at, scale)
	local cf = CFrame.new(at)
	part(parent, "Skull", Vector3.new(0.95, 0.82, 0.6)*scale, cf, BONE, Enum.Material.SmoothPlastic)
	part(parent, "Jaw", Vector3.new(0.6, 0.27, 0.52)*scale, cf*CFrame.new(0,-0.48*scale,0), BONE)
	for _, side in ipairs({-1,1}) do
		part(parent, "EyeSocket", Vector3.new(0.25,0.22,0.08)*scale, cf*CFrame.new(side*0.24*scale,0,-0.32*scale), DARK)
		part(parent, "SoulEye", Vector3.new(0.12,0.09,0.09)*scale, cf*CFrame.new(side*0.24*scale,0,-0.37*scale), SOUL, Enum.Material.Neon)
	end
	part(parent, "Nose", Vector3.new(0.11,0.17,0.07)*scale, cf*CFrame.new(0,-0.19*scale,-0.34*scale), DARK)
	for i=-1,1 do
		part(parent,"Tooth",Vector3.new(0.1,0.13,0.12)*scale,cf*CFrame.new(i*0.18*scale,-0.38*scale,-0.3*scale),BONE)
	end
end
local function label(p, text, color, pixels)
	local gui = Instance.new("SurfaceGui",p)
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels or 60
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel",gui)
	t.Size = UDim2.fromScale(1,1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeColor3 = DARK
	t.TextStrokeTransparency = 0
	t.TextScaled = true
	t.TextWrapped = true
end

-- A low dais, buttressed pillars and an iron axle frame.
block("Dais",Vector3.new(17,0.45,6),Vector3.new(0,0.225,0.5),STONE).CanCollide=true
block("BaseTrim",Vector3.new(15.5,0.3,4.7),Vector3.new(0,0.6,0.4),DARK).CanCollide=true
for _, side in ipairs({-1,1}) do
	local x = side*6.6
	block("Foot",Vector3.new(2.8,0.8,3),Vector3.new(x,0.9,0.4),STONE).CanCollide=true
	block("Pillar",Vector3.new(1.3,10,1.5),Vector3.new(x,6,0.8),STONE).CanCollide=true
	for y=2,10,2 do
		block("PillarBand",Vector3.new(1.6,0.3,1.8),Vector3.new(x,y,0.8),BRONZE,Enum.Material.Metal)
	end
	block("Capital",Vector3.new(2.3,0.6,2.2),Vector3.new(x,11.2,0.8),DARK)
	skull(model,Vector3.new(x,11.95,0.5),1.3)
	rod(model,"Brace",Vector3.new(x,1.2,1.5),Vector3.new(side*4.9,7.3,1.5),0.4,IRON,Enum.Material.Metal)
	local flame = block("BrazierFlame",Vector3.one*0.15,Vector3.new(x,3.2,-1.2),SOUL,Enum.Material.Neon)
	flame.Transparency=1
	block("BrazierBowl",Vector3.new(1.4,0.4,1.1),Vector3.new(x,2.9,-1.2),BRONZE,Enum.Material.Metal)
	local fire=Instance.new("Fire",flame) fire.Color=SOUL fire.SecondaryColor=BONE fire.Size=2.4 fire.Heat=2
	local light=Instance.new("PointLight",flame) light.Color=SOUL light.Range=12 light.Brightness=0.8
end
block("TopBeam",Vector3.new(14,0.65,1.2),Vector3.new(0,12.7,0.7),IRON,Enum.Material.Metal)
skull(model,Vector3.new(0,13.1,-0.3),1.5)
local pointer=part(model,"Pointer",Vector3.new(0.65,1.1,0.5),CFrame.new(0,12.25,-1.05),BRONZE,Enum.Material.Metal)
local mesh=Instance.new("SpecialMesh",pointer) mesh.MeshType=Enum.MeshType.Wedge
pointer.CFrame=frame*CFrame.new(0,12.25,-1.05)*CFrame.Angles(0,0,math.pi)
local title=block("Sign",Vector3.new(9,0.9,0.3),Vector3.new(0,1.25,-1.8),DARK)
label(title,"LUCKY WHEEL",BONE)

local rotor=Instance.new("Model",model)
rotor.Name="Rotor"
local centre=Vector3.new(0,6.9,0)
rotor.WorldPivot=frame*CFrame.new(centre)
local radius=5.15
local function disc(name,r,thick,z,color)
	return part(rotor,name,Vector3.new(thick,r*2,r*2),CFrame.new(centre+Vector3.new(0,0,z))*CFrame.Angles(0,math.pi/2,0),color,Enum.Material.Metal,Enum.PartType.Cylinder)
end
disc("IronBacking",radius+0.15,0.65,0,IRON)

-- Triangulated coloured sectors, made from anchored wedges in the wheel's XY plane.
local function triangle(a,b,c,color)
	local ab,ac,bc=b-a,c-a,c-b
	if ac:Dot(ac)>ab:Dot(ab) and ac:Dot(ac)>bc:Dot(bc) then a,b=b,a
	elseif ab:Dot(ab)>bc:Dot(bc) then a,c=c,a end
	ab,ac,bc=b-a,c-a,c-b
	local right=ac:Cross(ab).Unit
	local back=bc.Unit
	local up=bc:Cross(right).Unit
	local height=math.abs(ab:Dot(up))
	for _, spec in ipairs({{(a+b)/2,right,up,back,math.abs(ab:Dot(back))},
		{(a+c)/2,-right,up,-back,math.abs(ac:Dot(back))}}) do
		local w=Instance.new("WedgePart")
		w.Name="SectorFace" w.Anchored=true w.CanCollide=false w.CanTouch=false
		w.Size=Vector3.new(0.12,height,math.max(0.01,spec[5]))
		w.CFrame=frame*CFrame.fromMatrix(spec[1],spec[2],spec[3],spec[4])
		w.Color=color w.Material=Enum.Material.Slate w.Parent=rotor
	end
end
for i,reward in ipairs(Rewards) do
	local theta=reward.centerAngle
	local steps=math.max(1,math.ceil(reward.arc/math.rad(6)))
	local a=centre+Vector3.new(0,0,-0.4)
	for k=0,steps-1 do
		local t0=reward.startAngle+k*reward.arc/steps
		local t1=t0+reward.arc/steps
		triangle(a,a+Vector3.new(math.sin(t0)*radius,math.cos(t0)*radius,0),
			a+Vector3.new(math.sin(t1)*radius,math.cos(t1)*radius,0),reward.color)
	end
	local boundary=reward.startAngle
	local previous=Rewards[(i-2)%#Rewards+1]
	local narrow=reward.weight<=1 or previous.weight<=1
	local spokeA=centre+Vector3.new(math.sin(boundary)*0.8,math.cos(boundary)*0.8,-0.57)
	local spokeB=centre+Vector3.new(math.sin(boundary)*radius,math.cos(boundary)*radius,-0.57)
	rod(rotor,"BoneSpoke",spokeA,spokeB,narrow and 0.065 or 0.16,BONE,Enum.Material.SmoothPlastic)
	for k=1,3 do
		local p=spokeA:Lerp(spokeB,k/4)
		part(rotor,"BoneJoint",Vector3.one*(narrow and 0.1 or 0.26),CFrame.new(p),BONE,Enum.Material.SmoothPlastic,Enum.PartType.Ball)
	end
	local textRadius=reward.weight<=1 and 4.3 or 3.65
	local textAt=centre+Vector3.new(math.sin(theta)*textRadius,math.cos(theta)*textRadius,-0.6)
	local textWidth=math.min(3,2*textRadius*math.sin(math.min(reward.arc,math.pi)/2)*0.8)
	local plaque=part(rotor,"Reward"..i,Vector3.new(textWidth,1.4,0.03),CFrame.new(textAt)*CFrame.Angles(0,0,-theta),DARK)
	plaque.Transparency=1
	label(plaque,reward.weight<=1 and "1\n%" or reward.face.."\n"..reward.weight.."%",BONE,90)
	local pegAt=centre+Vector3.new(math.sin(theta)*5.45,math.cos(theta)*5.45,-0.3)
	part(rotor,"Peg",Vector3.new(0.25,0.45,0.35),CFrame.new(pegAt)*CFrame.Angles(0,0,-theta),BRONZE,Enum.Material.Metal)
end
for k=0,55 do
	local t=(k+0.5)*2*math.pi/56
	local at=centre+Vector3.new(math.sin(t)*5.2,math.cos(t)*5.2,-0.48)
	part(rotor,"BoneRim",Vector3.new(0.61,0.22,0.23),CFrame.new(at)*CFrame.Angles(0,0,-t),k%4==0 and BRONZE or BONE,Enum.Material.SmoothPlastic)
end
disc("Hub",0.85,0.4,-0.7,BRONZE)
skull(rotor,centre+Vector3.new(0,0,-1),1.1)

local anchor=block("Interaction",Vector3.new(3,3,1),Vector3.new(0,2,-3),DARK)
anchor.Transparency=1 anchor.CanQuery=false
local prompt=Instance.new("ProximityPrompt",anchor)
prompt.Name="WheelPrompt" prompt.ActionText="Spin" prompt.ObjectText="Lucky Wheel"
prompt.HoldDuration=0 prompt.MaxActivationDistance=12 prompt.RequiresLineOfSight=false
model:SetAttribute("SpinFrom",0) model:SetAttribute("SpinTo",0)
model:SetAttribute("SpinAt",0) model:SetAttribute("SpinDuration",5)
model.Parent=workspace
return "LuckyWheel built: "..#model:GetDescendants().." instances at "..tostring(pos)
