--!nonstrict
-- Owner 2026-10-28: paid showcase section follows every rollable car. Never counts as a discovery.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local MarketplaceService=game:GetService("MarketplaceService")
local Catalog=require(ReplicatedStorage.Shared.CarCatalog)
local Presentation=require(script.Parent.ShopPresentation)
local Index={}
local function make(class,name,parent,props)
 local o=Instance.new(class) o.Name=name
 for k,v in props do o[k]=v end
 o.Parent=parent return o
end
local function text(name,parent,value,pos,size,max)
 local o=make("TextLabel",name,parent,{BackgroundTransparency=1,Text=value,Position=pos,Size=size,Font=Enum.Font.FredokaOne,TextScaled=true,TextColor3=Color3.new(1,1,1),ZIndex=5})
 make("UITextSizeConstraint","Max",o,{MinTextSize=14,MaxTextSize=max})
 make("UIStroke","Outline",o,{Color=Color3.fromRGB(18,22,43),Thickness=2.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 return o
end
local function commas(n)
 local s=tostring(math.floor(n))
 repeat local count s,count=s:gsub("^(%d+)(%d%d%d)","%1,%2") until count==0
 return s
end
function Index.Attach(refs)
 local gallery=refs.GridHost:WaitForChild("Gallery")
 if gallery:FindFirstChild("Gamepass") then return end
 local grid=gallery:FindFirstChildOfClass("UIGridLayout")
 if not grid then return end
 -- Keep existing tile refs and their grid layout intact; place the grid in a list above the paid footer.
 local cars=make("Frame","Cars",gallery,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,grid.AbsoluteContentSize.Y),LayoutOrder=1})
 for _,tile in gallery:GetChildren() do
  if tile:IsA("GuiObject") and tile~=cars then tile.Parent=cars end
 end
 grid.Parent=cars
 local function inheritedScale()
  local scale=1
  local ancestor=cars
  while ancestor and ancestor:IsA("GuiObject") do
   for _,child in ancestor:GetChildren() do if child:IsA("UIScale") then scale*=child.Scale end end
   ancestor=ancestor.Parent
  end
  return math.max(.01,scale)
 end
 local function fitCars()
  local scale=inheritedScale()
  cars.Size=UDim2.new(1,0,0,grid.AbsoluteContentSize.Y/scale)
  local footer=gallery:FindFirstChild("Gamepass")
  if footer then for _,box in footer.Row:GetChildren() do
   if box:IsA("Frame") then box.Buy.Size=UDim2.fromOffset(122,math.max(48,46/scale)) end
  end end
 end
 grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCars)
 make("UIListLayout","Sections",gallery,{Padding=UDim.new(0,20),SortOrder=Enum.SortOrder.LayoutOrder})
 local section=make("Frame","Gamepass",gallery,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,340),LayoutOrder=2})
 text("Title",section,"GAMEPASS",UDim2.fromOffset(4,0),UDim2.new(1,-8,0,40),32)
 local row=make("Frame","Row",section,{BackgroundTransparency=1,Position=UDim2.fromOffset(4,52),Size=UDim2.new(1,-16,0,280)})
 make("UIGridLayout","Layout",row,{CellSize=UDim2.new(.5,-8,1,0),CellPadding=UDim2.fromOffset(16,0),SortOrder=Enum.SortOrder.LayoutOrder})
 for order,spec in Catalog.Passes() do
  local box=make("Frame",spec.Id,row,{LayoutOrder=order,BackgroundColor3=Color3.fromRGB(10,16,28),BorderSizePixel=0,ClipsDescendants=true})
  make("UICorner","Corner",box,{CornerRadius=UDim.new(0,14)})
  make("UIStroke","Stroke",box,{Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  text("Name",box,spec.Name,UDim2.fromScale(.04,.03),UDim2.fromScale(.92,.13),32)
  text("Stats",box,"×"..commas(spec.SpeedMulti).." SPEED",UDim2.fromScale(.04,.15),UDim2.fromScale(.92,.12),26)
  local buy=make("TextButton","Buy",box,{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-12,1,-12),Size=UDim2.fromOffset(122,48),BackgroundColor3=Color3.fromRGB(114,235,58),Text="",AutoButtonColor=false,ZIndex=5})
  make("UICorner","Corner",buy,{CornerRadius=UDim.new(0,10)})
  make("UIStroke","Stroke",buy,{Thickness=3,Color=Color3.fromRGB(18,22,43),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  make("ImageLabel","Robux",buy,{BackgroundTransparency=1,Image="rbxasset://textures/ui/common/robux.png",ImageColor3=Color3.fromRGB(18,22,43),Position=UDim2.fromScale(.08,.2),Size=UDim2.fromScale(.22,.6),ScaleType=Enum.ScaleType.Fit,ZIndex=6})
  local price=text("Price",buy,commas(spec.RobuxPrice),UDim2.fromScale(.32,.12),UDim2.fromScale(.62,.76),28)
  local function refresh()
   local owned=Players.LocalPlayer:GetAttribute("Pass_"..spec.Id)==true
   buy:SetAttribute("Owned",owned)
   buy.Active=not owned and (spec.GamepassId or 0)>0
   buy.AutoButtonColor=buy.Active
  end
  refresh()
  Players.LocalPlayer:GetAttributeChangedSignal("Pass_"..spec.Id):Connect(refresh)
  buy.Activated:Connect(function()
   if buy.Active and (spec.GamepassId or 0)>0 then MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer,spec.GamepassId) end
  end)
  if (spec.GamepassId or 0)>0 then
   task.spawn(function()
    local ok,info=pcall(MarketplaceService.GetProductInfo,MarketplaceService,spec.GamepassId,Enum.InfoType.GamePass)
    if ok and type(info.PriceInRobux)=="number" then price.Text=commas(info.PriceInRobux) end
   end)
  end
  Presentation.Preview(box,spec,refs.Panel.Parent)
  Presentation.Decorate(box)
 end
 refs.GridHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCars)
 fitCars()
 gallery:SetAttribute("GamepassSection",true)
end
return Index
