--!nonstrict
-- Shop-only presentation. Reuses the game's uploaded VehicleEffects textures for 2D UI particles.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Motion = require(script.Parent.UiMotion)
local Assets = {
 ember_wyvern = {Image="rbxassetid://86656789323399",Background="rbxassetid://113326107436007", Color=Color3.fromRGB(77,222,255), Deep=Color3.fromRGB(14,38,66), Period=5.8},
 singularity = {Image="rbxassetid://93660472264640",Background="rbxassetid://77761574959564", Color=Color3.fromRGB(255,207,67), Deep=Color3.fromRGB(43,32,24), Period=6.7},
}
-- Same textures already used by Shared.VehicleEffects; no external pack or scripts are imported.
local Tex = {Dot="rbxassetid://85679586220861",Glint="rbxassetid://132086922886913",Ring="rbxassetid://116102440578307",Flame="rbxassetid://130692121457990",SoftBand="rbxassetid://121066246235320",Nebula="rbxassetid://132097236933374",Streak="rbxassetid://124197020388243"}
local Shop = {}
local entries = {}
local clock = 0
local heartbeat
local owners = {}
local function shown(object)
 while object do
  if object:IsA("GuiObject") and not object.Visible then return false end
  if object:IsA("LayerCollector") and not object.Enabled then return false end
  object=object.Parent
 end
 return true
end
local function make(class,name,parent,props)
 local object=Instance.new(class)
 object.Name=name
 for key,value in props do object[key]=value end
 object.Parent=parent
 return object
end
local function image(name,parent,texture,z,color)
 return make("ImageLabel",name,parent,{BackgroundTransparency=1,Image=texture,ImageColor3=color or Color3.new(1,1,1),ImageTransparency=1,ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),ZIndex=z})
end
local function inScrollView(entry)
 local list=entry.Box:FindFirstAncestorWhichIsA("ScrollingFrame")
 if not list then return true end
 local p,s=entry.Box.AbsolutePosition,entry.Box.AbsoluteSize
 return p.Y+s.Y>list.AbsolutePosition.Y and p.Y<list.AbsolutePosition.Y+list.AbsoluteSize.Y
end
local function reset(entry)
 if entry.HoverTween then entry.HoverTween:Cancel() entry.HoverTween=nil end
 entry.HoverScale.Scale=1
 entry.Art.Position=UDim2.fromScale(.5,.56)
 entry.Art.Rotation=0
 entry.Scale.Scale=1
 entry.Backdrop.Position=UDim2.fromScale(.5,.5)
 entry.Backdrop.Rotation=0
 entry.Pattern.Position=UDim2.fromScale(-.1,-.1)
 entry.Rim.Transparency=.65
 entry.Fx.Visible=false
 entry.LastShine=nil
 local shine=entry.Box:FindFirstChild("MotionShine")
 if shine then shine.Visible=false end
end
local function render(entry,t)
 if not shown(entry.Owner) or not inScrollView(entry) then reset(entry) return end
 entry.Fx.Visible=true
 local wyvern=entry.Id=="ember_wyvern"
 local phase=t+(wyvern and 0 or 2.3)
 -- Background and stud pattern move independently of the foreground cutout and fixed labels.
 entry.Backdrop.Position=UDim2.fromScale(.5+math.sin(phase*.23)*.055,.5+math.cos(phase*.19)*.035)
 entry.Backdrop.Rotation=math.sin(phase*.16)*.7
 entry.Pattern.Position=UDim2.fromScale(-.12+(phase*.008)%(1.25/14),-.12+(phase*.006)%(1.25/10))
 entry.Rim.Transparency=.4+math.sin(phase*.9)*.18
 entry.Art.Position=UDim2.fromScale(.5,.56+math.sin(phase*1.8)*.008)
 entry.Art.Rotation=math.sin(phase*1.25)*.45
 entry.Scale.Scale=1+math.sin(phase*1.8)*.018
 for i,particle in entry.Particles do
  local age=(phase*(wyvern and .23 or .42)+i/#entry.Particles)%1
  local alpha=math.sin(age*math.pi)
  local x,y
  if wyvern then
   x=.12+((i*.173)% .76)+math.sin(phase+i)*.045
   y=.88-age*.76
  else
   local a=age*math.pi*2+i*.8
   x=.51+math.cos(a)*(.26+(i%4)*.055)
   y=.46+math.sin(a)*(.17+(i%3)*.06)
  end
  particle.Position=UDim2.fromScale(x,y)
  local size=(wyvern and (i%3==0 and 10 or 5) or (i%3==0 and 23 or 12))*(.45+.55*alpha)
  particle.Size=UDim2.fromOffset(size,size)
  particle.Rotation=phase*35+i*41
  particle.ImageTransparency=1-alpha*(wyvern and .72 or .88)
 end
 -- Wyvern uses small drifting embers; car retains nebula and orbital streaks.
 for i,layer in entry.Layers do
  local age=(phase*(wyvern and .55 or .20)+i*.173)%1
  local alpha=math.sin(age*math.pi)
  if wyvern then
   layer.ImageTransparency=1
  else
   if i<=2 then
    layer.ImageColor3=i==1 and Color3.fromRGB(126,87,220) or Color3.fromRGB(255,199,92)
    layer.Position=UDim2.fromScale(i==1 and .16 or .82,.30+math.sin(phase*.3+i)*.13)
    layer.Size=UDim2.fromScale(.62,.7)
    layer.Rotation=phase*(i==1 and 3 or -3)
    layer.ImageTransparency=.67+math.sin(phase*.4+i)*.07
   elseif i<=4 then
    layer.Position=UDim2.fromScale(.55,.38)
    layer.Size=UDim2.fromScale(.7+math.sin(phase*.4+i)*.12,.37)
    layer.Rotation=(i==3 and -22 or 24)+math.sin(phase*.3)*8
    layer.ImageTransparency=.73
   else
    local angle=age*math.pi*2+i*.8
    layer.Position=UDim2.fromScale(.51+math.cos(angle)*.43,.48+math.sin(angle)*.31)
    layer.Size=UDim2.fromOffset(8,28+alpha*25)
    layer.Rotation=angle*180/math.pi+90
    layer.ImageTransparency=1-alpha*.68
   end
  end
 end
 -- Local glint plus a full-card sweep using the same preset as the Money counter.
 local cycle=math.floor(phase/6)
 if entry.LastShine~=cycle then
  entry.LastShine=cycle
  Motion.Shine(entry.Box,.9)
  local sweep=entry.Box:FindFirstChild("MotionShine")
  if sweep then sweep.ZIndex=8 sweep.Visible=true end
 end
 local flashPhase=(phase%entry.Spec.Period)/entry.Spec.Period
 local flash=math.max(0,1-math.abs(flashPhase-.18)/.045)
 entry.Flash.ImageTransparency=1-flash*.78
 entry.Flash.Position=wyvern and UDim2.fromScale(.27,.43) or UDim2.fromScale(.67,.29)
 entry.Flash.Size=UDim2.fromOffset(28+flash*40,28+flash*40)
 entry.Ring.ImageTransparency=1-flash*.55
 entry.Ring.Position=entry.Flash.Position
 entry.Ring.Size=UDim2.fromOffset(38+flash*56,38+flash*56)
 entry.Fx:SetAttribute("Phase",flash>0 and "Flash" or "Particles")
end
local function updatePlayback()
 local active=false
 if not Motion.Reduced() then
  for _,entry in entries do
   if entry.Owner.Parent and shown(entry.Owner) then active=true break end
  end
 end
 if not active then
  if heartbeat then heartbeat:Disconnect() heartbeat=nil end
  for _,entry in entries do reset(entry) end
  return
 end
 if heartbeat then return end
 heartbeat=RunService.Heartbeat:Connect(function(dt)
  clock+=math.min(dt,.1)
  for _,entry in entries do
   local frozen=entry.Preview:GetAttribute("FxFreezeTime")
   render(entry,type(frozen)=="number" and frozen or clock)
  end
 end)
end
function Shop.Preview(box,spec,ownerBackdrop)
 local config=Assets[spec.Id]
 if not config then return end
 if box:FindFirstChild("Preview") then return end
 if not owners[ownerBackdrop] then
  owners[ownerBackdrop]=ownerBackdrop:GetPropertyChangedSignal("Visible"):Connect(updatePlayback)
 end
 box.ClipsDescendants=true
 local preview=make("CanvasGroup","Preview",box,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=1})
 make("UICorner","Corner",preview,{CornerRadius=UDim.new(0,14)})
 local background=image("MovingBackdrop",preview,config.Background,1)
 background.ImageTransparency=0
 background.ScaleType=Enum.ScaleType.Crop
 background.AnchorPoint=Vector2.new(.5,.5)
 background.Position=UDim2.fromScale(.5,.5)
 background.Size=UDim2.fromScale(1.22,1.22)
 local pattern=make("Frame","DriftingStudPattern",preview,{BackgroundTransparency=1,Size=UDim2.fromScale(1.25,1.25),Position=UDim2.fromScale(-.1,-.1),ZIndex=1})
 for y=0,9 do
  for x=0,13 do
   local stud=make("Frame","Stud",pattern,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromScale(x/14,y/10),Size=UDim2.fromScale(.027,.039),ZIndex=1})
   make("UICorner","Corner",stud,{CornerRadius=UDim.new(0,2)})
   make("UIStroke","Relief",stud,{Color=config.Color,Thickness=1,Transparency=.89,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  end
 end
 local art=image("Art",preview,config.Image,2)
 art.ImageTransparency=0
 art.Position=UDim2.fromScale(.5,.56)
 art.Size=spec.Id=="singularity" and UDim2.fromScale(.95,.90) or UDim2.fromScale(1.08,1.02)
 art.ScaleType=Enum.ScaleType.Fit
 local scale=make("UIScale","ArtMotionScale",art,{Scale=1})
 local fx=make("Frame","Particles",preview,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=3,Visible=false})
 local particles={}
 local moteCount=spec.Id=="ember_wyvern" and 24 or 28
 for i=1,moteCount do
  local particle=image("Mote"..i,fx,i%3==0 and Tex.Glint or Tex.Dot,3,config.Color)
  particle:SetAttribute("TextureSource","Shared.VehicleEffects")
  table.insert(particles,particle)
 end
 local layers={}
 local count=spec.Id=="ember_wyvern" and 0 or 12
 for i=1,count do
  local texture=spec.Id=="ember_wyvern" and (i<=10 and Tex.Flame or Tex.SoftBand) or (i<=2 and Tex.Nebula or (i<=4 and Tex.Ring or Tex.Streak))
  local layer=image("Atmosphere"..i,fx,texture,3,config.Color)
  if spec.Id=="ember_wyvern" and i<=10 then layer.ImageRectSize=Vector2.new(256,256) end
  table.insert(layers,layer)
 end
 local flash=image("Flash",fx,Tex.Glint,4)
 local ring=image("PulseRing",fx,Tex.Ring,3,config.Color)
 local rimFrame=make("Frame","PremiumRim",box,{BackgroundTransparency=1,Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),ZIndex=7})
 make("UICorner","Corner",rimFrame,{CornerRadius=UDim.new(0,11)})
 local rim=make("UIStroke","InnerLight",rimFrame,{Color=config.Color,Thickness=1,Transparency=.65,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local hoverScale=make("UIScale","GamepassHoverScale",box,{Scale=1})
 local entry={HoverScale=hoverScale,Backdrop=background,Pattern=pattern,Rim=rim,Owner=ownerBackdrop,Id=spec.Id,Box=box,Preview=preview,Art=art,Scale=scale,Fx=fx,Particles=particles,Layers=layers,Flash=flash,Ring=ring,Spec=config}
 table.insert(entries,entry)
 local function hover(inside)
  if entry.HoverTween then entry.HoverTween:Cancel() end
  local goal=inside and not Motion.Reduced() and shown(ownerBackdrop) and 1.035 or 1
  entry.HoverTween=Motion.Create(hoverScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=goal})
  entry.HoverTween:Play()
 end
 local entered=box.MouseEnter:Connect(function() hover(true) end)
 local exited=box.MouseLeave:Connect(function() hover(false) end)
 preview.Destroying:Connect(function()
  entered:Disconnect()
  exited:Disconnect()
  if entry.HoverTween then entry.HoverTween:Cancel() end
 end)
 preview:SetAttribute("ParticleBudget",#particles+#layers)
 preview.Destroying:Connect(function()
  local index=table.find(entries,entry)
  if index then table.remove(entries,index) end
  local used=false
  for _,item in entries do if item.Owner==ownerBackdrop then used=true break end end
  if not used and owners[ownerBackdrop] then owners[ownerBackdrop]:Disconnect() owners[ownerBackdrop]=nil end
  updatePlayback()
 end)
 updatePlayback()
end

function Shop.Decorate(box)
 if not Assets[box.Name] then return end
 local config=Assets[box.Name]
 local gradient=box:FindFirstChildOfClass("UIGradient")
 if gradient then gradient.Color=ColorSequence.new(config.Deep,Color3.fromRGB(8,13,24)) end
 local edge=box:FindFirstChildOfClass("UIStroke")
 if edge then edge.Color=config.Color edge.Thickness=3 end
 -- Scrims protect the labels without covering the central full-card illustration.
 local scrim=make("Frame","TextScrim",box,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(5,10,20),BorderSizePixel=0,ZIndex=3,Active=false})
 make("UICorner","Corner",scrim,{CornerRadius=UDim.new(0,14)})
 make("UIGradient","Fade",scrim,{Rotation=90,Transparency=NumberSequence.new({
  NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.24,.88),
  NumberSequenceKeypoint.new(.55,1),NumberSequenceKeypoint.new(.72,.85),NumberSequenceKeypoint.new(1,.08)})})
 for _,name in {"Name","Stats","Buy","Gift","GiftReason"} do
  local object=box:FindFirstChild(name)
  if object then
   object.ZIndex=5
   for _,child in object:GetDescendants() do if child:IsA("GuiObject") then child.ZIndex=6 end end
  end
 end
 local stats=box:FindFirstChild("Stats")
 if stats then
  stats.TextColor3=config.Color
  stats.Position=UDim2.fromScale(.04,.15)
  stats.Size=UDim2.fromScale(.92,.12)
  local limit=stats:FindFirstChildOfClass("UITextSizeConstraint")
  if limit then limit.MaxTextSize=26 end
 end
 local giftReason=box:FindFirstChild("GiftReason")
 if giftReason then giftReason.TextColor3=Color3.fromRGB(205,215,230) end
end

function Shop.Apply(panel,list,row,root)
 for _,child in panel:GetChildren() do
  if child:IsA("UIGradient") then child:Destroy() end
 end
 panel.BackgroundColor3=Color3.new(1,1,1)
 panel.BackgroundTransparency=0
 local round=panel:FindFirstChildOfClass("UICorner")
 if round then round.CornerRadius=UDim.new(0,24) end
 local pattern=make("Frame","RacingChecks",panel,{BackgroundTransparency=1,Position=UDim2.fromOffset(16,16),Size=UDim2.new(1,-32,1,-32),ZIndex=0,ClipsDescendants=true})
 for y=0,9 do
  for x=0,13 do
   if (x+y)%2==0 then
    local check=make("Frame","Check",pattern,{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(229,236,246),BackgroundTransparency=.6,Position=UDim2.fromScale(x/14,y/10),Size=UDim2.fromScale(1/14,1/10),ZIndex=0})
    make("UICorner","Corner",check,{CornerRadius=UDim.new(0,8)})
   end
  end
 end
 local header=panel:FindFirstChild("Header")
 if header then
  header.BackgroundTransparency=1
  for _,child in header:GetChildren() do if child:IsA("UIGradient") then child:Destroy() end end
 end
 for _,box in row:GetChildren() do
  if box:IsA("Frame") then Shop.Decorate(box) end
 end
 local function fit()
  row.Size=UDim2.new(1,0,0,panel.AbsoluteSize.Y<300 and 240 or 290)
 end
 panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
 fit()
 updatePlayback()
end
Players.LocalPlayer:GetAttributeChangedSignal("ReduceEffects"):Connect(updatePlayback)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(updatePlayback)
return Shop
