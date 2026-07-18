local library = {flags = {}, windows = {}, open = true}

--Services
local runService = game:GetService"RunService"
local tweenService = game:GetService"TweenService"
local textService = game:GetService"TextService"
local inputService = game:GetService"UserInputService"
local ui = Enum.UserInputType.MouseButton1

--Locals
local dragging, dragInput, dragStart, startPos, dragObject

--Functions
local function round(num, bracket)
	bracket = bracket or 1
	local a = math.floor(num/bracket + (math.sign(num) * 0.5)) * bracket
	if a < 0 then
		a = a + bracket
	end
	return a
end

local function keyCheck(x,x1)
	for _,v in next, x1 do
		if v == x then
			return true
		end
	end
end

local function update(input)
	local delta = input.Position - dragStart
	local yPos = (startPos.Y.Offset + delta.Y) < -36 and -36 or startPos.Y.Offset + delta.Y
	dragObject:TweenPosition(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, yPos), "Out", "Quint", 0.1, true)
end

--Chroma
local chromaColor
local rainbowTime = 5
task.spawn(function()
	while task.wait() do
		chromaColor = Color3.fromHSV(tick() % rainbowTime / rainbowTime, 1, 1)
	end
end)

-- Accent color
local ACCENT = Color3.fromRGB(255, 65, 65)
local ACCENT_DIM = Color3.fromRGB(180, 40, 40)
local BG_DARK = Color3.fromRGB(12, 12, 14)
local BG_MID = Color3.fromRGB(18, 18, 22)
local BG_LIGHT = Color3.fromRGB(28, 28, 34)
local BG_HOVER = Color3.fromRGB(38, 38, 46)
local TEXT_MAIN = Color3.fromRGB(240, 240, 245)
local TEXT_DIM = Color3.fromRGB(130, 130, 145)
local BORDER = Color3.fromRGB(45, 45, 55)
local BORDER_FOCUS = Color3.fromRGB(80, 80, 100)

function library:Create(class, properties)
	properties = typeof(properties) == "table" and properties or {}
	local inst = Instance.new(class)
	for property, value in next, properties do
		inst[property] = value
	end
	return inst
end

local function createOptionHolder(holderTitle, parent, parentTable, subHolder)
	local size = subHolder and 28 or 34
	parentTable.main = library:Create("ImageButton", {
		LayoutOrder = subHolder and parentTable.position or 0,
		Position = UDim2.new(0, 20 + (216 * (parentTable.position or 0)), 0, 20),
		Size = UDim2.new(0, 210, 0, size),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BG_DARK,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.04,
		ClipsDescendants = true,
		Parent = parent
	})

	-- Subtle border overlay
	library:Create("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BORDER,
		ImageTransparency = 0.4,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		ZIndex = 10,
		Parent = parentTable.main
	})

	local roundBg
	if not subHolder then
		roundBg = library:Create("ImageLabel", {
			Size = UDim2.new(1, 0, 0, size),
			BackgroundTransparency = 1,
			Image = "rbxassetid://3570695787",
			ImageColor3 = parentTable.open and BG_LIGHT or BG_MID,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(100, 100, 100, 100),
			SliceScale = 0.04,
			Parent = parentTable.main
		})

		-- Accent left bar
		library:Create("Frame", {
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			Parent = roundBg
		})
	end

	local title = library:Create("TextLabel", {
		Size = UDim2.new(1, -10, 0, size),
		Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = subHolder and 0 or 1,
		BackgroundColor3 = BG_MID,
		BorderSizePixel = 0,
		Text = holderTitle,
		TextSize = subHolder and 13 or 14,
		Font = Enum.Font.GothamBold,
		TextColor3 = TEXT_MAIN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parentTable.main
	})

	local closeHolder = library:Create("Frame", {
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(-1, 0, 1, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Parent = title
	})

	local close = library:Create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -size - 8, 1, -size - 8),
		Rotation = parentTable.open and 90 or 0,
		BackgroundTransparency = 1,
		Image = "rbxassetid://4918373417",
		ImageColor3 = parentTable.open and TEXT_DIM or Color3.fromRGB(60, 60, 70),
		ScaleType = Enum.ScaleType.Fit,
		Parent = closeHolder
	})

	parentTable.content = library:Create("Frame", {
		Position = UDim2.new(0, 0, 0, size),
		Size = UDim2.new(1, 0, 1, -size),
		BackgroundTransparency = 1,
		Parent = parentTable.main
	})

	local layout = library:Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parentTable.content
	})

	layout.Changed:Connect(function()
		parentTable.content.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
		parentTable.main.Size = #parentTable.options > 0 and parentTable.open
			and UDim2.new(0, 210, 0, layout.AbsoluteContentSize.Y + size)
			or UDim2.new(0, 210, 0, size)
	end)

	if not subHolder then
		library:Create("UIPadding", {
			Parent = parentTable.content
		})

		title.InputBegan:Connect(function(input)
			if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
				dragObject = parentTable.main
				dragging = true
				dragStart = input.Position
				startPos = dragObject.Position
			end
		end)
		title.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				dragInput = input
			end
		end)
		title.InputEnded:Connect(function(input)
			if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	local function doToggle()
		parentTable.open = not parentTable.open
		local targetRot = parentTable.open and 90 or 0
		local targetColor = parentTable.open and TEXT_DIM or Color3.fromRGB(60, 60, 70)
		tweenService:Create(close, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = targetRot, ImageColor3 = targetColor}):Play()
		if subHolder then
			tweenService:Create(title, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = parentTable.open and BG_LIGHT or BG_MID}):Play()
		else
			tweenService:Create(roundBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = parentTable.open and BG_LIGHT or BG_MID}):Play()
		end
		parentTable.main:TweenSize(
			#parentTable.options > 0 and parentTable.open
				and UDim2.new(0, 210, 0, layout.AbsoluteContentSize.Y + size)
				or UDim2.new(0, 210, 0, size),
			"Out", "Back", 0.3, true
		)
	end

	closeHolder.InputBegan:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			doToggle()
		end
	end)

	function parentTable:SetTitle(newTitle)
		title.Text = tostring(newTitle)
	end

	return parentTable
end

local function createLabel(option, parent)
	local main = library:Create("TextLabel", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = "  " .. option.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent.content
	})

	setmetatable(option, {__newindex = function(t, i, v)
		if i == "Text" then
			main.Text = "  " .. tostring(v)
		end
	end})
end

function createToggle(option, parent)
	local main = library:Create("TextLabel", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "  " .. option.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_MAIN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent.content
	})

	-- Pill toggle background
	local pillBg = library:Create("ImageLabel", {
		Position = UDim2.new(1, -8, 0.5, -7),
		Size = UDim2.new(0, 28, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = option.state and ACCENT or Color3.fromRGB(50, 50, 60),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.08,
		Parent = main
	})

	local pillKnob = library:Create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = option.state and UDim2.new(1, -7, 0.5, 0) or UDim2.new(0, 7, 0.5, 0),
		Size = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = Color3.fromRGB(230, 230, 240),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 1,
		Parent = pillBg
	})

	local function applyState(state)
		tweenService:Create(pillBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageColor3 = state and ACCENT or Color3.fromRGB(50, 50, 60)
		}):Play()
		tweenService:Create(pillKnob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = state and UDim2.new(1, -7, 0.5, 0) or UDim2.new(0, 7, 0.5, 0)
		}):Play()
	end

	main.InputBegan:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			option:SetState(not option.state)
		end
	end)

	function option:SetState(state)
		library.flags[self.flag] = state
		self.state = state
		applyState(state)
		self.callback(state)
	end

	if option.state then
		task.delay(1, function() option.callback(true) end)
	end

	setmetatable(option, {__newindex = function(t, i, v)
		if i == "Text" then
			main.Text = "  " .. tostring(v)
		end
	end})
end

function createButton(option, parent)
	local main = library:Create("Frame", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = parent.content
	})

	local btnBg = library:Create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -16, 1, -8),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BG_HOVER,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = main
	})

	-- Accent bottom line
	local accentLine = library:Create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0, 0, 0, 1),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		Parent = btnBg
	})

	local label = library:Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = option.text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextColor3 = TEXT_MAIN,
		Parent = btnBg
	})

	local inContact = false
	local clicking = false

	main.InputBegan:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			clicking = true
			tweenService:Create(btnBg, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = ACCENT_DIM}):Play()
			accentLine:TweenSize(UDim2.new(1, 0, 0, 1), "Out", "Quad", 0.25, true)
			option.callback()
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = true
			if not clicking then
				tweenService:Create(btnBg, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = Color3.fromRGB(50, 50, 62)}):Play()
				accentLine:TweenSize(UDim2.new(1, 0, 0, 1), "Out", "Quad", 0.3, true)
			end
		end
	end)

	main.InputEnded:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			clicking = false
			tweenService:Create(btnBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				ImageColor3 = inContact and Color3.fromRGB(50, 50, 62) or BG_HOVER
			}):Play()
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = false
			if not clicking then
				tweenService:Create(btnBg, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = BG_HOVER}):Play()
				accentLine:TweenSize(UDim2.new(0, 0, 0, 1), "Out", "Quad", 0.2, true)
			end
		end
	end)
end

local function createBind(option, parent)
	local binding
	local loop
	local text = string.match(option.key, "Mouse") and string.sub(option.key, 1, 5) .. string.sub(option.key, 12, 13) or option.key

	local main = library:Create("TextLabel", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "  " .. option.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_MAIN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent.content
	})

	local round = library:Create("ImageLabel", {
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, -textService:GetTextSize(text, 13, Enum.Font.GothamBold, Vector2.new(9e9, 9e9)).X - 16, 0, 18),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BG_HOVER,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = main
	})

	local bindinput = library:Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = TEXT_MAIN,
		Parent = round
	})

	local inContact
	main.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = true
			if not binding then
				tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = Color3.fromRGB(55, 55, 68)}):Play()
			end
		end
	end)

	main.InputEnded:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			binding = true
			bindinput.Text = "..."
			tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = ACCENT}):Play()
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = false
			if not binding then
				tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = BG_HOVER}):Play()
			end
		end
	end)

	inputService.InputBegan:Connect(function(input)
		if inputService:GetFocusedTextBox() then return end
		if (input.KeyCode.Name == option.key or input.UserInputType.Name == option.key) and not binding then
			if option.hold then
				loop = runService.Heartbeat:Connect(function()
					if binding then
						option.callback(true)
						loop:Disconnect()
						loop = nil
					else
						option.callback()
					end
				end)
			else
				option.callback()
			end
		elseif binding then
			local key
			pcall(function()
				if not keyCheck(input.KeyCode, blacklistedKeys) then
					key = input.KeyCode
				end
			end)
			pcall(function()
				if keyCheck(input.UserInputType, whitelistedMouseinputs) and not key then
					key = input.UserInputType
				end
			end)
			key = key or option.key
			option:SetKey(key)
		end
	end)

	inputService.InputEnded:Connect(function(input)
		if input.KeyCode.Name == option.key or input.UserInputType.Name == option.key or input.UserInputType.Name == "MouseMovement" then
			if loop then
				loop:Disconnect()
				loop = nil
				option.callback(true)
			end
		end
	end)

	function option:SetKey(key)
		binding = false
		if loop then
			loop:Disconnect()
			loop = nil
		end
		self.key = key or self.key
		self.key = self.key.Name or self.key
		library.flags[self.flag] = self.key
		if string.match(self.key, "Mouse") then
			bindinput.Text = string.sub(self.key, 1, 5) .. string.sub(self.key, 12, 13)
		else
			bindinput.Text = self.key
		end
		tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = inContact and Color3.fromRGB(55, 55, 68) or BG_HOVER}):Play()
		round.Size = UDim2.new(0, -textService:GetTextSize(bindinput.Text, 13, Enum.Font.GothamBold, Vector2.new(9e9, 9e9)).X - 16, 0, 18)
	end
end

local function createSlider(option, parent)
	local main = library:Create("Frame", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = parent.content
	})

	local title = library:Create("TextLabel", {
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -60, 0, 18),
		BackgroundTransparency = 1,
		Text = option.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_MAIN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = main
	})

	local valueRound = library:Create("ImageLabel", {
		Position = UDim2.new(1, -8, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 48, 0, 18),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BG_HOVER,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = main
	})

	local inputvalue = library:Create("TextBox", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = option.value,
		TextColor3 = TEXT_MAIN,
		TextSize = 12,
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		Parent = valueRound
	})

	local sliderTrack = library:Create("ImageLabel", {
		Position = UDim2.new(0, 8, 0, 34),
		Size = UDim2.new(1, -16, 0, 4),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BG_HOVER,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = main
	})

	local fill = library:Create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = ACCENT,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = sliderTrack
	})

	local circle = library:Create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new((option.value - option.min) / (option.max - option.min), 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = ACCENT,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 1,
		Parent = sliderTrack
	})

	if option.min >= 0 then
		fill.Size = UDim2.new((option.value - option.min) / (option.max - option.min), 0, 1, 0)
	else
		fill.Position = UDim2.new((0 - option.min) / (option.max - option.min), 0, 0, 0)
		fill.Size = UDim2.new(option.value / (option.max - option.min), 0, 1, 0)
	end

	local sliding = false
	local inContact = false

	main.InputBegan:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			tweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = ACCENT}):Play()
			tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(3.5, 0, 3.5, 0), ImageColor3 = ACCENT}):Play()
			sliding = true
			option:SetValue(option.min + ((input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X) * (option.max - option.min))
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = true
			if not sliding then
				tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(2.5, 0, 2.5, 0)}):Play()
			end
		end
	end)

	inputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and sliding then
			option:SetValue(option.min + ((input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X) * (option.max - option.min))
		end
	end)

	main.InputEnded:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
			if inContact then
				tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(2.5, 0, 2.5, 0)}):Play()
			else
				tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 0, 0)}):Play()
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = false
			inputvalue:ReleaseFocus()
			if not sliding then
				tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 0, 0)}):Play()
			end
		end
	end)

	inputvalue.FocusLost:Connect(function()
		tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 0, 0)}):Play()
		option:SetValue(tonumber(inputvalue.Text) or option.value)
	end)

	function option:SetValue(value)
		value = round(value, option.float)
		value = math.clamp(value, self.min, self.max)
		circle:TweenPosition(UDim2.new((value - self.min) / (self.max - self.min), 0, 0.5, 0), "Out", "Quad", 0.08, true)
		if self.min >= 0 then
			fill:TweenSize(UDim2.new((value - self.min) / (self.max - self.min), 0, 1, 0), "Out", "Quad", 0.08, true)
		else
			fill:TweenPosition(UDim2.new((0 - self.min) / (self.max - self.min), 0, 0, 0), "Out", "Quad", 0.08, true)
			fill:TweenSize(UDim2.new(value / (self.max - self.min), 0, 1, 0), "Out", "Quad", 0.08, true)
		end
		library.flags[self.flag] = value
		self.value = value
		inputvalue.Text = value
		self.callback(value)
	end
end

-- =================== IMPROVED DROPDOWN ===================
local function createList(option, parent, holder)
	local valueCount = 0
	local debounce = false   -- open/close debounce

	local ROW_HEIGHT = 32
	local MAX_VISIBLE = 5

	local main = library:Create("Frame", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		Parent = parent.content
	})

	-- Dropdown box background
	local dropBg = library:Create("ImageLabel", {
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 1, -10),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BG_HOVER,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = main
	})

	-- Subtle border
	local dropBorder = library:Create("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BORDER,
		ImageTransparency = 0.3,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		ZIndex = 5,
		Parent = dropBg
	})

	local titleLabel = library:Create("TextLabel", {
		Position = UDim2.new(0, 10, 0, 8),
		Size = UDim2.new(1, -32, 0, 14),
		BackgroundTransparency = 1,
		Text = option.text,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = main
	})

	local listvalue = library:Create("TextLabel", {
		Position = UDim2.new(0, 10, 0, 24),
		Size = UDim2.new(1, -32, 0, 22),
		BackgroundTransparency = 1,
		Text = option.value,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextColor3 = TEXT_MAIN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = main
	})

	-- Animated chevron arrow
	local chevron = library:Create("ImageLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 2),
		Size = UDim2.new(0, 12, 0, 12),
		Rotation = 90,
		BackgroundTransparency = 1,
		Image = "rbxassetid://4918373417",
		ImageColor3 = TEXT_DIM,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
		Parent = dropBg
	})

	-- Popup container (parented to base so it floats above everything)
	option.mainHolder = library:Create("ImageButton", {
		ZIndex = 10,
		Size = UDim2.new(0, 216, 0, 8),  -- starts collapsed
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageTransparency = 1,
		ImageColor3 = BG_DARK,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		ClipsDescendants = true,
		Visible = false,
		Parent = library.base
	})

	-- Popup border
	library:Create("ImageLabel", {
		ZIndex = 12,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BORDER,
		ImageTransparency = 0.1,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = option.mainHolder
	})

	-- Accent top bar on popup
	library:Create("Frame", {
		ZIndex = 11,
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		Parent = option.mainHolder
	})

	local content = library:Create("ScrollingFrame", {
		ZIndex = 10,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, 0, 1, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarImageColor3 = ACCENT,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = option.mainHolder
	})

	library:Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = content
	})

	local layout = library:Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 1),
		Parent = content
	})

	local function getPopupHeight()
		local rows = math.min(valueCount, MAX_VISIBLE)
		return rows * ROW_HEIGHT + 10 + 2  -- +padding+accentbar
	end

	layout.Changed:Connect(function()
		local targetH = getPopupHeight()
		option.mainHolder.Size = UDim2.new(0, 216, 0, targetH)
		content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)

	local inContact = false

	local function openDropdown()
		if debounce then return end
		debounce = true

		if library.activePopup then
			library.activePopup:Close()
		end

		local position = main.AbsolutePosition
		local targetH = getPopupHeight()

		option.mainHolder.Size = UDim2.new(0, 216, 0, 0)
		option.mainHolder.Position = UDim2.new(0, position.X - 3, 0, position.Y + 44)
		option.open = true
		option.mainHolder.Visible = true
		library.activePopup = option
		content.ScrollBarThickness = 4

		-- Animate background highlight on dropdown box
		tweenService:Create(dropBg, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageColor3 = Color3.fromRGB(48, 48, 60)
		}):Play()
		tweenService:Create(dropBorder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageColor3 = ACCENT, ImageTransparency = 0.5
		}):Play()

		-- Rotate chevron down
		tweenService:Create(chevron, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = 270, ImageColor3 = ACCENT
		}):Play()

		-- Popup slides down from collapsed height
		tweenService:Create(option.mainHolder, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = 0
		}):Play()
		option.mainHolder:TweenSize(UDim2.new(0, 216, 0, targetH), "Out", "Back", 0.28, true)

		-- Stagger-fade items in
		local items = {}
		for _, label in next, content:GetChildren() do
			if label:IsA("TextLabel") then
				table.insert(items, label)
			end
		end
		for i, label in ipairs(items) do
			label.TextTransparency = 1
			label.BackgroundTransparency = 1
			task.delay(0.04 * (i - 1), function()
				tweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0, TextTransparency = 0
				}):Play()
			end)
		end

		task.delay(0.3, function() debounce = false end)
	end

	dropBg.InputBegan:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			if option.open then
				option:Close()
			else
				openDropdown()
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = true
			if not option.open then
				tweenService:Create(dropBg, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageColor3 = Color3.fromRGB(44, 44, 56)
				}):Play()
				tweenService:Create(chevron, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageColor3 = TEXT_MAIN
				}):Play()
			end
		end
	end)

	dropBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = false
			if not option.open then
				tweenService:Create(dropBg, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageColor3 = BG_HOVER
				}):Play()
				tweenService:Create(chevron, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageColor3 = TEXT_DIM
				}):Play()
			end
		end
	end)

	function option:AddValue(value)
		valueCount = valueCount + 1
		local label = library:Create("TextLabel", {
			ZIndex = 10,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = BG_MID,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "   " .. value,
			TextSize = 13,
			TextTransparency = 1,
			Font = Enum.Font.Gotham,
			TextColor3 = TEXT_MAIN,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = content
		})

		-- Selected indicator bar
		local selBar = library:Create("Frame", {
			ZIndex = 11,
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Parent = label
		})

		local function setSelected(sel)
			tweenService:Create(selBar, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = sel and 0 or 1
			}):Play()
			tweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = sel and ACCENT or TEXT_MAIN,
				BackgroundColor3 = sel and Color3.fromRGB(38, 18, 18) or BG_MID
			}):Play()
		end

		-- Highlight current value
		if tostring(value) == tostring(self.value) then
			task.delay(0.01, function() setSelected(true) end)
		end

		local rowInContact = false
		local rowClicking = false

		label.InputBegan:Connect(function(input)
			if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
				rowClicking = true
				tweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = Color3.fromRGB(28, 12, 12)
				}):Play()
				self:SetValue(value)
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				rowInContact = true
				if not rowClicking then
					tweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = BG_LIGHT
					}):Play()
				end
			end
		end)

		label.InputEnded:Connect(function(input)
			if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
				rowClicking = false
				tweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = rowInContact and BG_LIGHT or BG_MID
				}):Play()
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				rowInContact = false
				if not rowClicking then
					tweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = BG_MID
					}):Play()
				end
			end
		end)
	end

	if not table.find(option.values, option.value) then
		option:AddValue(option.value)
	end

	for _, value in next, option.values do
		option:AddValue(tostring(value))
	end

	function option:RemoveValue(value)
		for _, label in next, content:GetChildren() do
			if label:IsA("TextLabel") and label.Text == "   " .. value then
				label:Destroy()
				valueCount = valueCount - 1
				break
			end
		end
		if self.value == value then
			self:SetValue("")
		end
	end

	function option:SetValue(value)
		library.flags[self.flag] = tostring(value)
		self.value = tostring(value)
		listvalue.Text = self.value
		-- Update selection highlight
		for _, label in next, content:GetChildren() do
			if label:IsA("TextLabel") then
				local sel = label.Text == "   " .. tostring(value)
				local bar = label:FindFirstChildWhichIsA("Frame")
				if bar then
					tweenService:Create(bar, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = sel and 0 or 1
					}):Play()
				end
				tweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = sel and ACCENT or TEXT_MAIN,
					BackgroundColor3 = sel and Color3.fromRGB(38, 18, 18) or BG_MID
				}):Play()
			end
		end
		self.callback(value)
		self:Close()
	end

	function option:Close()
		if debounce then return end
		debounce = true
		library.activePopup = nil
		self.open = false
		content.ScrollBarThickness = 0

		-- Rotate chevron back up
		tweenService:Create(chevron, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = 90, ImageColor3 = inContact and TEXT_MAIN or TEXT_DIM
		}):Play()

		-- Reset dropdown box color
		tweenService:Create(dropBg, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageColor3 = inContact and Color3.fromRGB(44, 44, 56) or BG_HOVER
		}):Play()
		tweenService:Create(dropBorder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageColor3 = BORDER, ImageTransparency = 0.3
		}):Play()

		-- Collapse popup height first, then hide
		option.mainHolder:TweenSize(UDim2.new(0, 216, 0, 0), "In", "Quad", 0.2, true)
		tweenService:Create(option.mainHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = 1
		}):Play()

		-- Fade items out quickly
		for _, label in next, content:GetChildren() do
			if label:IsA("TextLabel") then
				tweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1, TextTransparency = 1
				}):Play()
			end
		end

		task.delay(0.22, function()
			if not self.open then
				self.mainHolder.Visible = false
			end
			debounce = false
		end)
	end

	return option
end
-- =================== END DROPDOWN ===================

local function createBox(option, parent)
	local main = library:Create("Frame", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = parent.content
	})

	local outline = library:Create("ImageLabel", {
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 1, -10),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BORDER_FOCUS,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = main
	})

	local inner = library:Create("ImageLabel", {
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BG_MID,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.01,
		Parent = outline
	})

	local title = library:Create("TextLabel", {
		Position = UDim2.new(0, 10, 0, 6),
		Size = UDim2.new(1, -20, 0, 14),
		BackgroundTransparency = 1,
		Text = option.text,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = main
	})

	local inputvalue = library:Create("TextBox", {
		Position = UDim2.new(0, 10, 0, 22),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		Text = option.value,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_MAIN,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		PlaceholderText = "...",
		PlaceholderColor3 = TEXT_DIM,
		Parent = main
	})

	local inContact = false
	local focused = false

	main.InputBegan:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			if not focused then inputvalue:CaptureFocus() end
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = true
			if not focused then
				tweenService:Create(outline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = BORDER_FOCUS}):Play()
			end
		end
	end)

	main.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = false
			if not focused then
				tweenService:Create(outline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = BORDER}):Play()
			end
		end
	end)

	inputvalue.Focused:Connect(function()
		focused = true
		tweenService:Create(outline, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = ACCENT}):Play()
		tweenService:Create(title, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextColor3 = ACCENT}):Play()
	end)

	inputvalue.FocusLost:Connect(function(enter)
		focused = false
		tweenService:Create(outline, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = inContact and BORDER_FOCUS or BORDER}):Play()
		tweenService:Create(title, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextColor3 = TEXT_DIM}):Play()
		option:SetValue(inputvalue.Text, enter)
	end)

	function option:SetValue(value, enter)
		library.flags[self.flag] = tostring(value)
		self.value = tostring(value)
		inputvalue.Text = self.value
		self.callback(value, enter)
	end
end

local function createColorPickerWindow(option)
	option.mainHolder = library:Create("ImageButton", {
		ZIndex = 3,
		Size = UDim2.new(0, 240, 0, 180),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageTransparency = 1,
		ImageColor3 = BG_DARK,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = library.base
	})

	local hue, sat, val = Color3.toHSV(option.color)
	hue, sat, val = hue == 0 and 1 or hue, sat + 0.005, val - 0.005
	local editinghue
	local editingsatval
	local currentColor = option.color
	local previousColors = {[1] = option.color}
	local originalColor = option.color
	local rainbowEnabled
	local rainbowLoop

	function option:updateVisuals(Color)
		currentColor = Color
		self.visualize2.ImageColor3 = Color
		hue, sat, val = Color3.toHSV(Color)
		hue = hue == 0 and 1 or hue
		self.satval.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		self.hueSlider.Position = UDim2.new(1 - hue, 0, 0, 0)
		self.satvalSlider.Position = UDim2.new(sat, 0, 1 - val, 0)
	end

	option.hue = library:Create("ImageLabel", {
		ZIndex = 3,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -100, 0, 22),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = option.mainHolder
	})

	library:Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.157, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(0.323, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.488, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.817, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = option.hue
	})

	option.hueSlider = library:Create("Frame", {
		ZIndex = 3,
		Position = UDim2.new(1 - hue, 0, 0, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = BG_DARK,
		BorderColor3 = TEXT_MAIN,
		Parent = option.hue
	})

	option.hue.InputBegan:Connect(function(Input)
		if Input.UserInputType == ui or (input and input.UserInputType == Enum.UserInputType.Touch) then
			editinghue = true
			local X = (option.hue.AbsolutePosition.X + option.hue.AbsoluteSize.X) - option.hue.AbsolutePosition.X
			X = (Input.Position.X - option.hue.AbsolutePosition.X) / X
			X = X < 0 and 0 or X > 0.995 and 0.995 or X
			option:updateVisuals(Color3.fromHSV(1 - X, sat, val))
		end
	end)

	inputService.InputChanged:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseMovement and editinghue then
			local X = (option.hue.AbsolutePosition.X + option.hue.AbsoluteSize.X) - option.hue.AbsolutePosition.X
			X = (Input.Position.X - option.hue.AbsolutePosition.X) / X
			X = X <= 0 and 0 or X >= 0.995 and 0.995 or X
			option:updateVisuals(Color3.fromHSV(1 - X, sat, val))
		end
	end)

	option.hue.InputEnded:Connect(function(Input)
		if Input.UserInputType == ui or (input and input.UserInputType == Enum.UserInputType.Touch) then
			editinghue = false
		end
	end)

	option.satval = library:Create("ImageLabel", {
		ZIndex = 3,
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -100, 1, -42),
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		Image = "rbxassetid://4155801252",
		ImageTransparency = 1,
		ClipsDescendants = true,
		Parent = option.mainHolder
	})

	option.satvalSlider = library:Create("Frame", {
		ZIndex = 3,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(sat, 0, 1 - val, 0),
		Size = UDim2.new(0, 4, 0, 4),
		Rotation = 45,
		BackgroundTransparency = 1,
		BackgroundColor3 = TEXT_MAIN,
		Parent = option.satval
	})

	option.satval.InputBegan:Connect(function(Input)
		if Input.UserInputType == ui or (input and input.UserInputType == Enum.UserInputType.Touch) then
			editingsatval = true
			local X = (option.satval.AbsolutePosition.X + option.satval.AbsoluteSize.X) - option.satval.AbsolutePosition.X
			local Y = (option.satval.AbsolutePosition.Y + option.satval.AbsoluteSize.Y) - option.satval.AbsolutePosition.Y
			X = (Input.Position.X - option.satval.AbsolutePosition.X) / X
			Y = (Input.Position.Y - option.satval.AbsolutePosition.Y) / Y
			X = X <= 0.005 and 0.005 or X >= 1 and 1 or X
			Y = Y <= 0 and 0 or Y >= 0.995 and 0.995 or Y
			option:updateVisuals(Color3.fromHSV(hue, X, 1 - Y))
		end
	end)

	inputService.InputChanged:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseMovement and editingsatval then
			local X = (option.satval.AbsolutePosition.X + option.satval.AbsoluteSize.X) - option.satval.AbsolutePosition.X
			local Y = (option.satval.AbsolutePosition.Y + option.satval.AbsoluteSize.Y) - option.satval.AbsolutePosition.Y
			X = (Input.Position.X - option.satval.AbsolutePosition.X) / X
			Y = (Input.Position.Y - option.satval.AbsolutePosition.Y) / Y
			X = X <= 0.005 and 0.005 or X >= 1 and 1 or X
			Y = Y <= 0 and 0 or Y >= 0.995 and 0.995 or Y
			option:updateVisuals(Color3.fromHSV(hue, X, 1 - Y))
		end
	end)

	option.satval.InputEnded:Connect(function(Input)
		if Input.UserInputType == ui or (input and input.UserInputType == Enum.UserInputType.Touch) then
			editingsatval = false
		end
	end)

	option.visualize2 = library:Create("ImageLabel", {
		ZIndex = 3,
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0, -80, 0, 80),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = currentColor,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = option.mainHolder
	})

	local function makeButton(zeroPos, label)
		local btn = library:Create("ImageLabel", {
			ZIndex = 3,
			Position = UDim2.new(1, -8, 0, zeroPos),
			Size = UDim2.new(0, -80, 0, 18),
			BackgroundTransparency = 1,
			Image = "rbxassetid://3570695787",
			ImageTransparency = 1,
			ImageColor3 = BG_MID,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(100, 100, 100, 100),
			SliceScale = 0.02,
			Parent = option.mainHolder
		})
		library:Create("TextLabel", {
			ZIndex = 3,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = label,
			TextTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = TEXT_MAIN,
			Parent = btn
		})
		btn.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
				tweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = BG_HOVER}):Play()
			end
		end)
		btn.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
				tweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = BG_MID}):Play()
			end
		end)
		return btn
	end

	option.resetColor = makeButton(92, "Reset")
	option.resetText = option.resetColor:FindFirstChildWhichIsA("TextLabel")
	option.resetColor.InputBegan:Connect(function(Input)
		if Input.UserInputType == ui and not rainbowEnabled then
			previousColors = {originalColor}
			option:SetColor(originalColor)
		end
	end)

	option.undoColor = makeButton(112, "Undo")
	option.undoText = option.undoColor:FindFirstChildWhichIsA("TextLabel")
	option.undoColor.InputBegan:Connect(function(Input)
		if Input.UserInputType == ui and not rainbowEnabled then
			local Num = #previousColors == 1 and 0 or 1
			option:SetColor(previousColors[#previousColors - Num])
			if #previousColors ~= 1 then
				table.remove(previousColors, #previousColors)
			end
		end
	end)

	option.setColor = makeButton(132, "Set")
	option.setText = option.setColor:FindFirstChildWhichIsA("TextLabel")
	option.setColor.InputBegan:Connect(function(Input)
		if Input.UserInputType == ui and not rainbowEnabled then
			table.insert(previousColors, currentColor)
			option:SetColor(currentColor)
		end
	end)

	option.rainbow = makeButton(152, "Rainbow")
	option.rainbowText = option.rainbow:FindFirstChildWhichIsA("TextLabel")
	option.rainbow.InputBegan:Connect(function(Input)
		if Input.UserInputType == ui then
			rainbowEnabled = not rainbowEnabled
			if rainbowEnabled then
				rainbowLoop = runService.Heartbeat:Connect(function()
					option:SetColor(chromaColor)
					option.rainbowText.TextColor3 = chromaColor
				end)
			else
				rainbowLoop:Disconnect()
				option:SetColor(previousColors[#previousColors])
				option.rainbowText.TextColor3 = TEXT_MAIN
			end
		end
	end)

	return option
end

local function createColor(option, parent, holder)
	option.main = library:Create("TextLabel", {
		LayoutOrder = option.position,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "  " .. option.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_MAIN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent.content
	})

	local colorBoxOutline = library:Create("ImageLabel", {
		Position = UDim2.new(1, -8, 0.5, -8),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 18, 0, 18),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = BORDER_FOCUS,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = option.main
	})

	option.visualize = library:Create("ImageLabel", {
		Position = UDim2.new(0, 2, 0, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		Image = "rbxassetid://3570695787",
		ImageColor3 = option.color,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 100, 100),
		SliceScale = 0.02,
		Parent = colorBoxOutline
	})

	local inContact = false
	option.main.InputBegan:Connect(function(input)
		if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
			if not option.mainHolder then createColorPickerWindow(option) end
			if library.activePopup then library.activePopup:Close() end
			local position = option.main.AbsolutePosition
			option.mainHolder.Position = UDim2.new(0, position.X - 5, 0, position.Y - 10)
			option.open = true
			option.mainHolder.Visible = true
			library.activePopup = option
			tweenService:Create(option.mainHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0, Position = UDim2.new(0, position.X - 5, 0, position.Y - 4)}):Play()
			tweenService:Create(option.mainHolder, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.1), {Position = UDim2.new(0, position.X - 5, 0, position.Y + 1)}):Play()
			tweenService:Create(option.satval, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
			for _, object in next, option.mainHolder:GetDescendants() do
				if object:IsA("TextLabel") then
					tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
				elseif object:IsA("ImageLabel") then
					tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play()
				elseif object:IsA("Frame") then
					tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
				end
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = true
			if not option.open then
				tweenService:Create(colorBoxOutline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = TEXT_MAIN}):Play()
			end
		end
	end)

	option.main.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			inContact = false
			if not option.open then
				tweenService:Create(colorBoxOutline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageColor3 = BORDER_FOCUS}):Play()
			end
		end
	end)

	function option:SetColor(newColor)
		if self.mainHolder then self:updateVisuals(newColor) end
		self.visualize.ImageColor3 = newColor
		library.flags[self.flag] = newColor
		self.color = newColor
		self.callback(newColor)
	end

	function option:Close()
		library.activePopup = nil
		self.open = false
		local position = self.main.AbsolutePosition
		tweenService:Create(self.mainHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1, Position = UDim2.new(0, position.X - 5, 0, position.Y - 10)}):Play()
		tweenService:Create(self.satval, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
		for _, object in next, self.mainHolder:GetDescendants() do
			if object:IsA("TextLabel") then
				tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
			elseif object:IsA("ImageLabel") then
				tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
			elseif object:IsA("Frame") then
				tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
			end
		end
		task.delay(0.3, function()
			if not self.open then
				self.mainHolder.Visible = false
			end
		end)
	end
end

local function loadOptions(option, holder)
	for _, newOption in next, option.options do
		if newOption.type == "label" then
			createLabel(newOption, option)
		elseif newOption.type == "toggle" then
			createToggle(newOption, option)
		elseif newOption.type == "button" then
			createButton(newOption, option)
		elseif newOption.type == "list" then
			createList(newOption, option, holder)
		elseif newOption.type == "box" then
			createBox(newOption, option)
		elseif newOption.type == "bind" then
			createBind(newOption, option)
		elseif newOption.type == "slider" then
			createSlider(newOption, option)
		elseif newOption.type == "color" then
			createColor(newOption, option, holder)
		elseif newOption.type == "folder" then
			newOption:init()
		end
	end
end

local function getFnctions(parent)
	function parent:AddLabel(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.type = "label"
		option.position = #self.options
		table.insert(self.options, option)
		return option
	end

	function parent:AddToggle(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.state = typeof(option.state) == "boolean" and option.state or false
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "toggle"
		option.position = #self.options
		option.flag = option.flag or option.text
		library.flags[option.flag] = option.state
		table.insert(self.options, option)
		return option
	end

	function parent:AddButton(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "button"
		option.position = #self.options
		option.flag = option.flag or option.text
		table.insert(self.options, option)
		return option
	end

	function parent:AddBind(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.key = (option.key and option.key.Name) or option.key or "F"
		option.hold = typeof(option.hold) == "boolean" and option.hold or false
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "bind"
		option.position = #self.options
		option.flag = option.flag or option.text
		library.flags[option.flag] = option.key
		table.insert(self.options, option)
		return option
	end

	function parent:AddSlider(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.min = typeof(option.min) == "number" and option.min or 0
		option.max = typeof(option.max) == "number" and option.max or 0
		option.dual = typeof(option.dual) == "boolean" and option.dual or false
		option.value = math.clamp(typeof(option.value) == "number" and option.value or option.min, option.min, option.max)
		option.value2 = typeof(option.value2) == "number" and option.value2 or option.max
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.float = typeof(option.value) == "number" and option.float or 1
		option.type = "slider"
		option.position = #self.options
		option.flag = option.flag or option.text
		library.flags[option.flag] = option.value
		table.insert(self.options, option)
		return option
	end

	function parent:AddList(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.values = typeof(option.values) == "table" and option.values or {}
		option.value = tostring(option.value or option.values[1] or "")
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.open = false
		option.type = "list"
		option.position = #self.options
		option.flag = option.flag or option.text
		library.flags[option.flag] = option.value
		table.insert(self.options, option)
		return option
	end

	function parent:AddBox(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.value = tostring(option.value or "")
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.type = "box"
		option.position = #self.options
		option.flag = option.flag or option.text
		library.flags[option.flag] = option.value
		table.insert(self.options, option)
		return option
	end

	function parent:AddColor(option)
		option = typeof(option) == "table" and option or {}
		option.text = tostring(option.text)
		option.color = typeof(option.color) == "table"
			and Color3.new(tonumber(option.color[1]), tonumber(option.color[2]), tonumber(option.color[3]))
			or option.color or Color3.new(1, 1, 1)
		option.callback = typeof(option.callback) == "function" and option.callback or function() end
		option.open = false
		option.type = "color"
		option.position = #self.options
		option.flag = option.flag or option.text
		library.flags[option.flag] = option.color
		table.insert(self.options, option)
		return option
	end

	function parent:AddFolder(title)
		local option = {}
		option.title = tostring(title)
		option.options = {}
		option.open = false
		option.type = "folder"
		option.position = #self.options
		table.insert(self.options, option)
		getFnctions(option)
		function option:init()
			createOptionHolder(self.title, parent.content, self, true)
			loadOptions(self, parent)
		end
		return option
	end
end

function library:CreateWindow(title)
	local window = {title = tostring(title), options = {}, open = true, canInit = true, init = false, position = #self.windows}
	getFnctions(window)
	table.insert(library.windows, window)
	return window
end

function library:Init()
	self.base = self.base or self:Create("ScreenGui")
	local protectGui = syn and syn.protect_gui
		or (typeof(get_hidden_gui) == "function" and get_hidden_gui)
		or (typeof(gethui) == "function" and function(g) g.Parent = gethui() end)
	if protectGui then
		protectGui(self.base)
	else
		game:GetService("Players").LocalPlayer:Kick("Error: protect_gui not found")
		return
	end
	self.base.Parent = game:GetService"CoreGui"
	self.base.ResetOnSpawn = true
	self.base.Name = "ToraScript"

	for _, window in next, self.windows do
		if window.canInit and not window.init then
			window.init = true
			createOptionHolder(window.title, self.base, window)
			loadOptions(window)
		end
	end
	return self.base
end

function library:Close()
	if typeof(self.base) ~= "Instance" then return end
	self.open = not self.open
	if self.activePopup then
		self.activePopup:Close()
	end
	for _, window in next, self.windows do
		if window.main then
			window.main.Visible = self.open
		end
	end
end

inputService.InputBegan:Connect(function(input)
	if input.UserInputType == ui or input.UserInputType == Enum.UserInputType.Touch then
		if library.activePopup then
			local h = library.activePopup.mainHolder
			if h then
				if input.Position.X < h.AbsolutePosition.X or input.Position.Y < h.AbsolutePosition.Y
					or input.Position.X > h.AbsolutePosition.X + h.AbsoluteSize.X
					or input.Position.Y > h.AbsolutePosition.Y + h.AbsoluteSize.Y then
					library.activePopup:Close()
				end
			end
		end
	end
end)

inputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		update(input)
	end
end)

task.wait(1)
local VirtualUser = game:service"VirtualUser"
game:GetService("Players").LocalPlayer.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

return library
