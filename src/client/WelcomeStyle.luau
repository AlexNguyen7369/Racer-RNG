--!nonstrict
-- Reference composition; existing server credit and PanelBand ownership are preserved.
local Welcome = {}
function Welcome.Apply(panel, closePanel)
	local function make(c, n, p, props)
		local o = Instance.new(c)
		o.Name = n
		for k, v in props do
			o[k] = v
		end
		o.Parent = p
		return o
	end
	local dark = Color3.fromRGB(20, 23, 35)
	local function stroke(o, width, border)
		for _, c in o:GetChildren() do
			if c:IsA("UIStroke") then
				c:Destroy()
			end
		end
		return make("UIStroke", "WelcomeOutline", o, {
			Color = dark,
			Thickness = width,
			ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
		})
	end
	for _, c in panel:GetChildren() do
		if c:IsA("UIGradient") or c:IsA("UIStroke") or c:IsA("UICorner") then
			c:Destroy()
		end
	end
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	make("UICorner", "WelcomeCorner", panel, { CornerRadius = UDim.new(0, 24) })
	stroke(panel, 4, true)
	local function label(o, pos, size, color)
		for _, child in o:GetChildren() do
			if child:IsA("UITextSizeConstraint") then
				child:Destroy()
			end
		end
		o.Position = pos
		o.Size = size
		o.Font = Enum.Font.FredokaOne
		o.TextColor3 = color or Color3.new(1, 1, 1)
		o.TextWrapped = false
		o.TextScaled = true
		stroke(o, 3.5, false)
		make("UITextSizeConstraint", "WelcomeTextLimit", o, { MinTextSize = 14, MaxTextSize = 48 })
	end
	-- Low-contrast checks retain a white surface without competing with the reward.
	local pattern = make("Frame", "RacingChecks", panel, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(1, -32, 1, -32),
		ClipsDescendants = true,
		ZIndex = 1,
	})
	for row = 0, 7 do
		for col = 0, 13 do
			if (row + col) % 2 == 0 then
				local check = make("Frame", "Check", pattern, {
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromRGB(229, 236, 246),
					BackgroundTransparency = 0.6,
					Position = UDim2.fromScale(col / 14, row / 8),
					Size = UDim2.fromScale(1 / 14, 1 / 8),
					ZIndex = 1,
				})
				make("UICorner", "CheckCorner", check, { CornerRadius = UDim.new(0, 8) })
			end
		end
	end
	local title = panel.Title
	title.Text = "OFFLINE REWARD"
	label(title, UDim2.fromOffset(70, 10), UDim2.new(1, -140, 0, 54))
	title.Font = Enum.Font.Bangers
	title.ZIndex = 3
	panel.Earnings.ZIndex = 3
	panel.Away.ZIndex = 3
	local close = panel.Close
	close.ZIndex = 4
	close.Text = "X"
	close.Position = UDim2.new(1, -56, 0, 10)
	close.Size = UDim2.fromOffset(44, 44)
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 30
	close.TextStrokeTransparency = 0
	close.TextStrokeColor3 = dark
	close.BackgroundColor3 = Color3.fromRGB(255, 58, 112)
	stroke(close, 4, true)
	make("UICorner", "WelcomeCloseCorner", close, { CornerRadius = UDim.new(0, 12) })
	local subtitle =
		make("TextLabel", "Subtitle", panel, { BackgroundTransparency = 1, Text = "WHILE OFFLINE YOU GAINED:" })
	subtitle.ZIndex = 3
	label(subtitle, UDim2.fromScale(0.04, 0.17), UDim2.fromScale(0.92, 0.08))
	local art = make("ImageLabel", "SpeedIcon", panel, {
		ZIndex = 3,
		BackgroundTransparency = 1,
		Image = "rbxassetid://121915283083474",
		ImageRectOffset = Vector2.new(256, 0),
		ImageRectSize = Vector2.new(256, 256),
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromScale(0.38, 0.29),
	})
	label(panel.Earnings, UDim2.fromScale(0.04, 0.585), UDim2.fromScale(0.92, 0.13), Color3.fromRGB(255, 180, 0))
	label(panel.Away, UDim2.fromScale(0.04, 0.745), UDim2.fromScale(0.92, 0.055), Color3.fromRGB(72, 87, 109))
	panel.Away.WelcomeOutline.Thickness = 0
	panel.Away.WelcomeTextLimit.MaxTextSize = 17
	subtitle.WelcomeTextLimit.MaxTextSize = 20
	title.WelcomeTextLimit.MaxTextSize = 64
	local claim = make("TextButton", "Claim", panel, {
		Position = UDim2.fromScale(0.06, 0.835),
		Size = UDim2.fromScale(0.88, 0.13),
		BackgroundColor3 = Color3.fromRGB(120, 242, 35),
		Text = "Claim",
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
	})
	make("UICorner", "WelcomeClaimCorner", claim, { CornerRadius = UDim.new(0, 16) })
	stroke(claim, 4, true)
	local caption = make("TextLabel", "Caption", claim, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "Claim",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
	})
	claim.Text = ""
	stroke(caption, 3.5, false)
	make("UITextSizeConstraint", "Limit", caption, { MinTextSize = 12, MaxTextSize = 36 })
	claim.ZIndex = 3
	caption.ZIndex = 4
	local double = make("TextButton", "Double", panel, {
		Text = "",
		BackgroundColor3 = Color3.fromRGB(255, 204, 30),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		ZIndex = 3,
	})
	make("UICorner", "Corner", double, { CornerRadius = UDim.new(0, 16) })
	stroke(double, 4, true)
	local doubleTitle =
		make("TextLabel", "Caption", double, { BackgroundTransparency = 1, Text = "DOUBLE IT!", ZIndex = 4 })
	label(doubleTitle, UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.94, 0.51))
	doubleTitle.WelcomeTextLimit.MaxTextSize = 30
	local price = make("TextLabel", "Price", double, { BackgroundTransparency = 1, Text = "19 ROBUX", ZIndex = 4 })
	label(price, UDim2.fromScale(0.03, 0.56), UDim2.fromScale(0.94, 0.3), Color3.fromRGB(83, 255, 38))
	price.WelcomeTextLimit.MaxTextSize = 16
	-- Offline double (docs/OFFLINE_DOUBLE_SPEC.md): shown only while the server says the reward is claimable; the
	-- server decides the amount when Roblox confirms the purchase.
	local player = game:GetService("Players").LocalPlayer
	local product = require(game:GetService("ReplicatedStorage").Shared.MonetizationConfig).OfflineDouble
	local configured = product.ProductId > 0
	double:SetAttribute("PurchaseConfigured", configured)
	double.Active = configured
	double.AutoButtonColor = configured
	price.Text = configured and string.format("%d ROBUX", product.RobuxPrice) or "COMING SOON"
	local function showDouble()
		double.Visible = player:GetAttribute("OfflineDoubleOpen") == true
	end
	player:GetAttributeChangedSignal("OfflineDoubleOpen"):Connect(showDouble)
	showDouble()
	double.Activated:Connect(function()
		if configured and double.Visible then
			game:GetService("MarketplaceService"):PromptProductPurchase(player, product.ProductId)
		end
	end)
	claim.Activated:Connect(closePanel)
	-- In very short bands use a side-by-side icon and amount, keeping a full-height tap target.
	local function fit()
		local height = panel.AbsoluteSize.Y
		local short = height < 300
		subtitle.Visible = not short
		local titleHeight = short and 46 or math.clamp(height * 0.14, 46, 64)
		title.Size = UDim2.new(1, -140, 0, titleHeight)
		title.WelcomeTextLimit.MaxTextSize = short and 46 or 64
		subtitle.Position = UDim2.new(0.04, 0, 0, titleHeight + 22)
		subtitle.Size = UDim2.new(0.92, 0, 0, 26)
		-- Stack bottom-up from the offset-pinned button row so the Away line never reaches into Claim / Double.
		local claimOffset = short and 64 or 80
		claim.Position = UDim2.new(0.04, 0, 1, -claimOffset)
		claim.Size = UDim2.new(0.44, 0, 0, short and 50 or 60)
		double.Position = UDim2.new(0.52, 0, 1, -claimOffset)
		double.Size = claim.Size
		local awayHeight = short and 18 or 20
		local awayTop = height - claimOffset - 6 - awayHeight
		panel.Away.Position = UDim2.new(0.04, 0, 0, awayTop)
		panel.Away.Size = UDim2.new(0.92, 0, 0, awayHeight)
		local contentTop = short and titleHeight + 16 or titleHeight + 48
		local contentBottom = awayTop - 4
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		local artSize
		if short then
			-- Side-by-side icon and amount in the band between the title and the Away line.
			local band = math.max(0, contentBottom - contentTop)
			artSize = math.min(height * 0.30, band)
			art.Position = UDim2.new(0.23, 0, 0, contentTop + band / 2)
			panel.Earnings.Position = UDim2.new(0.36, 0, 0, contentTop)
			panel.Earnings.Size = UDim2.new(0.59, 0, 0, band)
		else
			local earningsHeight = math.clamp(height * 0.13, 30, 46)
			local earningsTop = contentBottom - earningsHeight
			panel.Earnings.Position = UDim2.new(0.04, 0, 0, earningsTop)
			panel.Earnings.Size = UDim2.new(0.92, 0, 0, earningsHeight)
			artSize = math.min(height * 0.32, math.max(0, earningsTop - contentTop - 16))
			art.Position = UDim2.new(0.5, 0, 0, (contentTop + earningsTop) / 2)
		end
		art.Size = UDim2.fromOffset(artSize, artSize)
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end
return Welcome
