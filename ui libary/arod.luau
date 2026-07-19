--!nocheck

-- Fallbacks for non-executor environments
local gethui   = gethui   or function() return game:GetService("CoreGui") end

local TweenService: TweenService = game:GetService("TweenService")
local UIS: UserInputService      = game:GetService("UserInputService")
local Players: Players           = game:GetService("Players")
local RunService: RunService     = game:GetService("RunService")
local HttpService: HttpService   = game:GetService("HttpService")
local player: Player             = Players.LocalPlayer

-- ANTI-DUPE
local existingGui = player:WaitForChild("PlayerGui"):FindFirstChild("455HubGui")
	or gethui():FindFirstChild("455HubGui")
if existingGui then existingGui:Destroy() end
if _G["4557Running"] then
	_G["4557Running"] = false
	if _G["4557Connection"] then
		(_G["4557Connection"] :: RBXScriptConnection):Disconnect()
		_G["4557Connection"] = nil
	end
end
_G["4557Running"] = true

local Lib   = {}
Lib.__index = Lib

-- ─── ICON SYSTEM ──────────────────────────────────────────────────────────────
local Icons: {[string]: string} = {}
local ICON_URL = "https://raw.githubusercontent.com/Religius-Star/Main/refs/heads/main/config/icon.json"

local function _loadIcons()
	local ok, result = pcall(function()
		local raw = HttpService:GetAsync(ICON_URL)
		local fn = loadstring(raw)
		if fn then
			local data = fn()
			if data and data.assets then
				return data.assets
			end
		end
		return nil
	end)
	if ok and result then
		Icons = result
	else
		warn("[455Hub] Icon load failed, icons disabled:", result)
	end
end
_loadIcons()

local function _icon(name: string?): string?
	if not name or name == "" then return nil end
	local key = name:find("^lucide%-") and name or ("lucide-" .. name)
	return Icons[key]
end

-- ─── THEME ────────────────────────────────────────────────────────────────────
local T = {
	BG         = Color3.fromRGB(10,  10,  14),
	SURFACE    = Color3.fromRGB(18,  18,  24),
	SURFACE2   = Color3.fromRGB(26,  26,  34),
	BORDER     = Color3.fromRGB(42,  42,  56),
	ACCENT     = Color3.fromRGB(220, 20,  60),
	ACCENT_DIM = Color3.fromRGB(100, 10,  28),
	TEXT       = Color3.fromRGB(240, 240, 245),
	TEXT_DIM   = Color3.fromRGB(120, 120, 135),
	TITLE_H    = 36,
	WIN_W      = 200,
	WIN_MAR    = 12,
	WIN_Y      = 8,
}

-- ─── TWEEN PRESETS ────────────────────────────────────────────────────────────
local function tw(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end
local function twFast(obj, props) tw(obj, 0.12, props) end
local function twMed(obj, props)  tw(obj, 0.22, props) end
local function twSlow(obj, props) tw(obj, 0.35, props) end

-- ─── GUI ROOT ─────────────────────────────────────────────────────────────────
local _gui: ScreenGui = Instance.new("ScreenGui")
_gui.Name           = "455HubGui"
_gui.ResetOnSpawn   = false
_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
_gui.Parent         = gethui()

local WIN_W   = T.WIN_W
local WIN_MAR = T.WIN_MAR
local WIN_Y   = T.WIN_Y
local _windows: {any}          = {}
local _loaded: boolean         = false
local _pendingShow: {() -> ()} = {}

-- ─── STYLE HELPERS ────────────────────────────────────────────────────────────
local function _corner(obj: GuiObject, r: number?)
	local c = Instance.new("UICorner", obj)
	c.CornerRadius = UDim.new(0, r or 6)
end

local function _stroke(obj: GuiObject, color: Color3?, thickness: number?)
	local s: UIStroke = Instance.new("UIStroke", obj)
	s.Color           = color or T.BORDER
	s.Thickness       = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

local function _style(obj: GuiObject)
	_corner(obj)
	_stroke(obj)
end

local function _accentLine(parent: Frame)
	local line: Frame = Instance.new("Frame")
	line.Size             = UDim2.new(1, 0, 0, 2)
	line.Position         = UDim2.new(0, 0, 1, -2)
	line.BackgroundColor3 = T.ACCENT
	line.BorderSizePixel  = 0
	line.Parent           = parent
end

-- TextScaled label helper with size constraint
local function _makeLabel(parent: Instance, props: {[string]: any}): TextLabel
	local lbl: TextLabel = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextColor3             = T.TEXT
	lbl.TextXAlignment         = Enum.TextXAlignment.Left
	for k, v in pairs(props) do
		(lbl :: any)[k] = v
	end
	lbl.Parent = parent
	return lbl
end

-- Icon ImageLabel helper
local function _makeIcon(parent: Instance, iconId: string, size: number?, color: Color3?): ImageLabel
	local img: ImageLabel = Instance.new("ImageLabel")
	img.Size                  = UDim2.new(0, size or 16, 0, size or 16)
	img.BackgroundTransparency = 1
	img.Image                 = iconId
	img.ImageColor3           = color or T.TEXT_DIM
	img.ScaleType             = Enum.ScaleType.Fit
	img.Parent                = parent
	return img
end

local function _reposition()
	local vis: {Frame} = {}
	for _, w in ipairs(_windows) do
		if w.shown then table.insert(vis, w.frame) end
	end
	local n = #vis
	if n == 0 then return end
	local sw = workspace.CurrentCamera.ViewportSize.X
	local pos: {number} = {}
	if n == 1 then
		pos = { WIN_MAR }
	elseif n == 2 then
		pos = { WIN_MAR, sw - WIN_W - WIN_MAR }
	else
		local gap = math.max((sw - WIN_MAR * 2 - WIN_W * n) / (n - 1), WIN_MAR)
		for i = 1, n do pos[i] = WIN_MAR + (i - 1) * (WIN_W + gap) end
	end
	for i, frame in ipairs(vis) do
		local x = math.clamp(pos[i] or WIN_MAR, 0, sw - WIN_W)
		twSlow(frame, { Position = UDim2.new(0, x, 0, WIN_Y) })
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CREATE WINDOW
-- titleIcon: optional lucide icon name shown left of the title
-- ─────────────────────────────────────────────────────────────────────────────
function Lib:CreateWindow(title: string, titleIcon: string?)
	local winData: {[string]: any} = { shown = false }
	table.insert(_windows, winData)

	local frame: Frame = Instance.new("Frame")
	frame.Size             = UDim2.new(0, WIN_W, 0, 100)
	frame.Position         = UDim2.new(0, WIN_MAR, 0, WIN_Y)
	frame.BackgroundColor3 = T.BG
	frame.ClipsDescendants = true
	frame.Active           = true
	frame.Visible          = false
	frame.ZIndex           = 10
	frame.Parent           = _gui
	_corner(frame, 8)
	_stroke(frame)

	winData.frame = frame

	-- Title bar
	local titleBar: Frame = Instance.new("Frame")
	titleBar.Size             = UDim2.new(1, 0, 0, T.TITLE_H)
	titleBar.BackgroundColor3 = T.BG
	titleBar.BorderSizePixel  = 0
	titleBar.ZIndex           = 11
	titleBar.Active           = true
	titleBar.Parent           = frame
	_accentLine(titleBar)

	-- Optional title icon
	local iconId = _icon(titleIcon)
	local titleTextX = 10
	if iconId then
		local ico = _makeIcon(titleBar, iconId, 16, T.ACCENT)
		ico.Position  = UDim2.new(0, 8, 0.5, -8)
		ico.ZIndex    = 12
		titleTextX    = 30
	end

	-- Title text (TextScaled with constraint)
	local titleLbl: TextLabel = Instance.new("TextLabel")
	titleLbl.Size             = UDim2.new(1, -(titleTextX + 64), 1, -4)
	titleLbl.Position         = UDim2.new(0, titleTextX, 0, 2)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text             = string.upper(title or "Window")
	titleLbl.Font             = Enum.Font.LuckiestGuy
	titleLbl.TextScaled       = true
	titleLbl.TextColor3       = T.TEXT
	titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
	titleLbl.ZIndex           = 12
	titleLbl.Parent           = titleBar
	local tsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", titleLbl)
	tsc.MinTextSize = 8
	tsc.MaxTextSize = 15

	-- Close button (X)
	local closeBtn: TextButton = Instance.new("TextButton")
	closeBtn.Size               = UDim2.new(0, 24, 0, 24)
	closeBtn.AnchorPoint        = Vector2.new(1, 0.5)
	closeBtn.Position           = UDim2.new(1, -6, 0.5, 0)
	closeBtn.Text               = ""
	closeBtn.BackgroundColor3   = T.SURFACE2
	closeBtn.ZIndex             = 12
	closeBtn.Parent             = titleBar
	_corner(closeBtn, 5)

	local closeIconId = _icon("x")
	if closeIconId then
		local img = _makeIcon(closeBtn, closeIconId, 14, T.TEXT_DIM)
		img.Position = UDim2.new(0.5, -7, 0.5, -7)
		img.ZIndex   = closeBtn.ZIndex + 1
	else
		closeBtn.Text = "✕"
		closeBtn.TextScaled = true
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextColor3 = T.TEXT_DIM
	end

	closeBtn.MouseEnter:Connect(function()
		twFast(closeBtn, { BackgroundColor3 = T.ACCENT })
		if closeBtn:FindFirstChildOfClass("ImageLabel") then
			twFast(closeBtn:FindFirstChildOfClass("ImageLabel"), { ImageColor3 = T.TEXT })
		else
			closeBtn.TextColor3 = T.TEXT
		end
	end)
	closeBtn.MouseLeave:Connect(function()
		twFast(closeBtn, { BackgroundColor3 = T.SURFACE2 })
		if closeBtn:FindFirstChildOfClass("ImageLabel") then
			twFast(closeBtn:FindFirstChildOfClass("ImageLabel"), { ImageColor3 = T.TEXT_DIM })
		else
			closeBtn.TextColor3 = T.TEXT_DIM
		end
	end)
	closeBtn.MouseButton1Click:Connect(function()
		frame:Destroy()
		for i, w in ipairs(_windows) do
			if w == winData then
				table.remove(_windows, i)
				break
			end
		end
		_reposition()
	end)

	-- Collapse/Expand button (minus/plus)
	local colBtn: TextButton = Instance.new("TextButton")
	colBtn.Size               = UDim2.new(0, 24, 0, 24)
	colBtn.AnchorPoint        = Vector2.new(1, 0.5)
	colBtn.Position           = UDim2.new(1, -34, 0.5, 0)  -- left of close
	colBtn.Text               = ""
	colBtn.BackgroundColor3   = T.SURFACE2
	colBtn.ZIndex             = 12
	colBtn.Parent             = titleBar
	_corner(colBtn, 5)

	local colImage: ImageLabel = _makeIcon(colBtn, _icon("minus") or "", 14, T.TEXT_DIM)
	colImage.Position = UDim2.new(0.5, -7, 0.5, -7)
	colImage.ZIndex   = colBtn.ZIndex + 1

	colBtn.MouseEnter:Connect(function()
		twFast(colBtn, { BackgroundColor3 = T.ACCENT })
		twFast(colImage, { ImageColor3 = T.TEXT })
	end)
	colBtn.MouseLeave:Connect(function()
		twFast(colBtn, { BackgroundColor3 = T.SURFACE2 })
		twFast(colImage, { ImageColor3 = T.TEXT_DIM })
	end)

	-- Scroll area
	local scroll: ScrollingFrame = Instance.new("ScrollingFrame")
	scroll.Size                   = UDim2.new(1, 0, 1, -T.TITLE_H)
	scroll.Position               = UDim2.new(0, 0, 0, T.TITLE_H)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness     = 3
	scroll.ScrollBarImageColor3   = T.ACCENT
	scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
	scroll.Parent                 = frame

	local layout: UIListLayout = Instance.new("UIListLayout")
	layout.Padding   = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent    = scroll

	local pad: UIPadding = Instance.new("UIPadding")
	pad.PaddingTop    = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft   = UDim.new(0, 5)
	pad.PaddingRight  = UDim.new(0, 5)
	pad.Parent        = scroll

	local collapsed: boolean = false
	local function updateCanvas()
		task.defer(function()
			scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
			if not collapsed then
				frame.Size = UDim2.new(0, WIN_W, 0,
					math.clamp(layout.AbsoluteContentSize.Y + T.TITLE_H + 8, 70, 380))
			end
		end)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

	colBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		if collapsed then
			colImage.Image = _icon("plus") or ""
			twMed(frame, { Size = UDim2.new(0, WIN_W, 0, T.TITLE_H) })
		else
			colImage.Image = _icon("minus") or ""
			twMed(frame, {
				Size = UDim2.new(0, WIN_W, 0,
					math.clamp(layout.AbsoluteContentSize.Y + T.TITLE_H + 8, 70, 380))
			})
		end
	end)

	-- DRAG
	local dragging  = false
	local dragStart = Vector3.zero
	local startPos  = UDim2.new()

	titleBar.InputBegan:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch
		then
			dragging  = true
			dragStart = i.Position
			startPos  = frame.Position
		end
	end)
	titleBar.InputEnded:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(i: InputObject)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch
		then
			local sc    = workspace.CurrentCamera.ViewportSize
			local delta = i.Position - dragStart
			local newX  = math.clamp(startPos.X.Offset + delta.X, 0, math.max(0, sc.X - frame.AbsoluteSize.X))
			local newY  = math.clamp(startPos.Y.Offset + delta.Y, 0, math.max(0, sc.Y - frame.AbsoluteSize.Y))
			frame.Position = UDim2.new(0, newX, 0, newY)
		end
	end)

	-- ANTI OUT-OF-SCREEN
	RunService.RenderStepped:Connect(function()
		if not frame or not frame.Parent then return end
		local sc  = workspace.CurrentCamera.ViewportSize
		local pos = frame.Position
		local x   = math.clamp(pos.X.Offset, 0, math.max(0, sc.X - frame.AbsoluteSize.X))
		local y   = math.clamp(pos.Y.Offset, 0, math.max(0, sc.Y - frame.AbsoluteSize.Y))
		if x ~= pos.X.Offset or y ~= pos.Y.Offset then
			frame.Position = UDim2.new(0, x, 0, y)
		end
	end)

	if _loaded then
		winData.shown = true
		frame.Visible = true
		_reposition()
	else
		table.insert(_pendingShow, function()
			winData.shown = true
			frame.Visible = true
		end)
	end

	local Win    = {}
	local _order = 0
	local function nxt() _order += 1; return _order end

	function Win:SetTitle(text: string, icon: string?)
		titleLbl.Text = string.upper(text or "Window")
	end
	function Win:SetPosition(x: number, y: number)
		frame.Position = UDim2.new(0, x, 0, y)
	end

	-- ── LABEL ──────────────────────────────────────────────────────────────────
	function Win:Label(text: string)
		local lbl: TextLabel = Instance.new("TextLabel")
		lbl.Size                  = UDim2.new(1, 0, 0, 22)
		lbl.BackgroundTransparency = 1
		lbl.Text                  = text or "Label"
		lbl.Font                  = Enum.Font.GothamMedium
		lbl.TextScaled            = true
		lbl.TextColor3            = T.TEXT_DIM
		lbl.TextXAlignment        = Enum.TextXAlignment.Center
		lbl.LayoutOrder           = nxt()
		lbl.Parent                = scroll
		local sc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
		sc.MaxTextSize = 12
		updateCanvas()
		return lbl
	end

	-- ── SECTION ────────────────────────────────────────────────────────────────
	function Win:Section(text: string)
		local sec: Frame = Instance.new("Frame")
		sec.Size                  = UDim2.new(1, 0, 0, 20)
		sec.BackgroundTransparency = 1
		sec.LayoutOrder           = nxt()
		sec.Parent                = scroll

		local bar: Frame = Instance.new("Frame")
		bar.Size             = UDim2.new(0, 3, 0.6, 0)
		bar.Position         = UDim2.new(0, 0, 0.2, 0)
		bar.BackgroundColor3 = T.ACCENT
		bar.BorderSizePixel  = 0
		bar.Parent           = sec
		_corner(bar, 2)

		local line: Frame = Instance.new("Frame")
		line.Size             = UDim2.new(1, -8, 0, 1)
		line.Position         = UDim2.new(0, 8, 0.5, 0)
		line.BackgroundColor3 = T.BORDER
		line.BorderSizePixel  = 0
		line.Parent           = sec

		local sLbl: TextLabel = Instance.new("TextLabel")
		sLbl.Size                  = UDim2.new(0.76, 0, 1, 0)
		sLbl.Position              = UDim2.new(0, 10, 0, 0)
		sLbl.BackgroundColor3      = T.BG
		sLbl.Text                  = text or ""
		sLbl.TextColor3            = T.TEXT_DIM
		sLbl.Font                  = Enum.Font.GothamBold
		sLbl.TextScaled            = true
		sLbl.TextXAlignment        = Enum.TextXAlignment.Left
		sLbl.Parent                = sec
		local sc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", sLbl)
		sc2.MaxTextSize = 10

		updateCanvas()
	end

	-- ── BUTTON ─────────────────────────────────────────────────────────────────
	function Win:Button(text: string, callback: () -> (), icon: string?)
		local btn: TextButton = Instance.new("TextButton")
		btn.Size             = UDim2.new(1, 0, 0, 34)
		btn.BackgroundColor3 = T.SURFACE
		btn.Text             = ""
		btn.LayoutOrder      = nxt()
		btn.Parent           = scroll
		_style(btn)

		local textOffsetL = 10
		local iconId = _icon(icon)
		if iconId then
			local ico = _makeIcon(btn, iconId, 14, T.ACCENT)
			ico.Position  = UDim2.new(0, 8, 0.5, -7)
			ico.ZIndex    = btn.ZIndex + 1
			textOffsetL   = 28
		end

		local lblFrame: Frame = Instance.new("Frame")
		lblFrame.Size                  = UDim2.new(1, -(textOffsetL + 24), 1, -6)
		lblFrame.Position              = UDim2.new(0, textOffsetL, 0, 3)
		lblFrame.BackgroundTransparency = 1
		lblFrame.ZIndex                = btn.ZIndex + 1
		lblFrame.Parent                = btn

		local lbl: TextLabel = Instance.new("TextLabel")
		lbl.Size                  = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                  = text or "Button"
		lbl.Font                  = Enum.Font.GothamBold
		lbl.TextScaled            = true
		lbl.TextColor3            = T.TEXT
		lbl.TextXAlignment        = Enum.TextXAlignment.Left
		lbl.ZIndex                = btn.ZIndex + 1
		lbl.Parent                = lblFrame
		local bsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
		bsc.MinTextSize = 8
		bsc.MaxTextSize = 13

		local arr: TextLabel = Instance.new("TextLabel")
		arr.Size               = UDim2.new(0, 16, 1, 0)
		arr.AnchorPoint        = Vector2.new(1, 0.5)
		arr.Position           = UDim2.new(1, -6, 0.5, 0)
		arr.BackgroundTransparency = 1
		arr.Text               = "›"
		arr.Font               = Enum.Font.GothamBold
		arr.TextScaled         = true
		arr.TextColor3         = T.ACCENT
		arr.ZIndex             = btn.ZIndex + 1
		arr.Parent             = btn
		local asc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", arr)
		asc.MinTextSize = 8
		asc.MaxTextSize = 18

		btn.MouseEnter:Connect(function()     twFast(btn, { BackgroundColor3 = T.SURFACE2 }) end)
		btn.MouseLeave:Connect(function()     twFast(btn, { BackgroundColor3 = T.SURFACE })  end)
		btn.MouseButton1Down:Connect(function() twFast(btn, { BackgroundColor3 = T.ACCENT }) end)
		btn.MouseButton1Up:Connect(function()
			task.delay(0.12, function() twFast(btn, { BackgroundColor3 = T.SURFACE }) end)
		end)
		btn.MouseButton1Click:Connect(function()
			if callback then pcall(callback) end
		end)

		updateCanvas()
		return btn
	end

	-- ── TOGGLE ─────────────────────────────────────────────────────────────────
	function Win:Toggle(text: string, default: boolean, callback: (boolean) -> (), icon: string?)
		local state: boolean = default or false

		local row: TextButton = Instance.new("TextButton")
		row.Size             = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = T.SURFACE
		row.Text             = ""
		row.LayoutOrder      = nxt()
		row.Parent           = scroll
		_style(row)

		local textOffsetL = 10
		local iconId = _icon(icon)
		if iconId then
			local ico = _makeIcon(row, iconId, 14, T.TEXT_DIM)
			ico.Position = UDim2.new(0, 8, 0.5, -7)
			ico.ZIndex   = row.ZIndex + 1
			textOffsetL  = 28
		end

		local lblFrame: Frame = Instance.new("Frame")
		lblFrame.Size                  = UDim2.new(1, -(textOffsetL + 48), 1, -6)
		lblFrame.Position              = UDim2.new(0, textOffsetL, 0, 3)
		lblFrame.BackgroundTransparency = 1
		lblFrame.ZIndex                = row.ZIndex + 1
		lblFrame.Parent                = row

		local lbl: TextLabel = Instance.new("TextLabel")
		lbl.Size                  = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                  = text or "Toggle"
		lbl.Font                  = Enum.Font.GothamBold
		lbl.TextScaled            = true
		lbl.TextColor3            = T.TEXT
		lbl.TextXAlignment        = Enum.TextXAlignment.Left
		lbl.ZIndex                = row.ZIndex + 1
		lbl.Parent                = lblFrame
		local tsc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
		tsc2.MinTextSize = 8
		tsc2.MaxTextSize = 13

		local pill: Frame = Instance.new("Frame")
		pill.Size             = UDim2.new(0, 32, 0, 18)
		pill.AnchorPoint      = Vector2.new(1, 0.5)
		pill.Position         = UDim2.new(1, -8, 0.5, 0)
		pill.BackgroundColor3 = state and T.ACCENT or T.SURFACE2
		pill.ZIndex           = row.ZIndex + 1
		pill.Parent           = row
		_corner(pill, 9)

		local knob: Frame = Instance.new("Frame")
		knob.Size             = UDim2.new(0, 12, 0, 12)
		knob.AnchorPoint      = Vector2.new(0.5, 0.5)
		knob.Position         = state and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0)
		knob.BackgroundColor3 = T.TEXT
		knob.ZIndex           = row.ZIndex + 2
		knob.Parent           = pill
		_corner(knob, 6)

		local function applyState()
			twMed(pill,  { BackgroundColor3 = state and T.ACCENT or T.SURFACE2 })
			twMed(knob,  { Position = state and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0) })
		end

		row.MouseEnter:Connect(function()     twFast(row, { BackgroundColor3 = T.SURFACE2 }) end)
		row.MouseLeave:Connect(function()     twFast(row, { BackgroundColor3 = T.SURFACE })  end)
		row.MouseButton1Click:Connect(function()
			state = not state
			applyState()
			if callback then pcall(callback, state) end
		end)

		updateCanvas()
		local Tv = {}
		function Tv:Set(v: boolean) state = v; applyState() end
		function Tv:Get(): boolean  return state end
		return Tv
	end

	-- ── SLIDER ────────────────────────────────────────────────────────────────
	function Win:Slider(text: string, min: number, max: number, default: number, callback: (number) -> ())
		min = min or 0; max = max or 100
		local val = math.clamp(default or min, min, max)

		local cont: Frame = Instance.new("Frame")
		cont.Size             = UDim2.new(1, 0, 0, 60)
		cont.BackgroundColor3 = T.SURFACE
		cont.LayoutOrder      = nxt()
		cont.Parent           = scroll
		_style(cont)

		local lblFrame: Frame = Instance.new("Frame")
		lblFrame.Size                  = UDim2.new(0.6, -8, 0, 20)
		lblFrame.Position              = UDim2.new(0, 10, 0, 5)
		lblFrame.BackgroundTransparency = 1
		lblFrame.Parent                = cont

		local tLbl: TextLabel = Instance.new("TextLabel")
		tLbl.Size               = UDim2.new(1, 0, 1, 0)
		tLbl.BackgroundTransparency = 1
		tLbl.Text               = text or "Slider"
		tLbl.Font               = Enum.Font.GothamBold
		tLbl.TextScaled         = true
		tLbl.TextColor3         = T.TEXT
		tLbl.TextXAlignment     = Enum.TextXAlignment.Left
		tLbl.Parent             = lblFrame
		local slsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", tLbl)
		slsc.MinTextSize = 8
		slsc.MaxTextSize = 13

		local numBox: Frame = Instance.new("Frame")
		numBox.Size             = UDim2.new(0, 36, 0, 20)
		numBox.AnchorPoint      = Vector2.new(1, 0)
		numBox.Position         = UDim2.new(1, -8, 0, 5)
		numBox.BackgroundColor3 = T.SURFACE2
		numBox.BorderSizePixel  = 0
		numBox.Parent           = cont
		_corner(numBox, 4)

		local valTxt: TextBox = Instance.new("TextBox")
		valTxt.Size               = UDim2.new(1, -4, 1, -4)
		valTxt.Position           = UDim2.new(0, 2, 0, 2)
		valTxt.BackgroundTransparency = 1
		valTxt.Text               = tostring(val)
		valTxt.Font               = Enum.Font.GothamBold
		valTxt.TextScaled         = true
		valTxt.TextColor3         = T.ACCENT
		valTxt.ClearTextOnFocus   = false
		valTxt.TextXAlignment     = Enum.TextXAlignment.Center
		valTxt.TextYAlignment     = Enum.TextYAlignment.Center
		valTxt.Parent             = numBox
		local vtsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", valTxt)
		vtsc.MinTextSize = 7
		vtsc.MaxTextSize = 12

		local bar: Frame = Instance.new("Frame")
		bar.Size             = UDim2.new(1, -18, 0, 5)
		bar.Position         = UDim2.new(0, 9, 0, 42)
		bar.BackgroundColor3 = T.SURFACE2
		bar.Parent           = cont
		_corner(bar, 3)

		local ip = (val - min) / (max - min)
		local fill: Frame = Instance.new("Frame")
		fill.Size             = UDim2.new(ip, 0, 1, 0)
		fill.BackgroundColor3 = T.ACCENT
		fill.Parent           = bar
		_corner(fill, 3)

		local knob: Frame = Instance.new("Frame")
		knob.Size             = UDim2.new(0, 12, 0, 12)
		knob.AnchorPoint      = Vector2.new(0.5, 0.5)
		knob.Position         = UDim2.new(ip, 0, 0.5, 0)
		knob.BackgroundColor3 = T.TEXT
		knob.ZIndex           = bar.ZIndex + 1
		knob.Parent           = bar
		_corner(knob, 6)
		_stroke(knob, T.ACCENT, 2)

		local sliderDrag = false
		local function setPos(pos: number)
			pos           = math.clamp(pos, 0, 1)
			fill.Size     = UDim2.new(pos, 0, 1, 0)
			knob.Position = UDim2.new(pos, 0, 0.5, 0)
			val           = math.floor(min + pos * (max - min))
			valTxt.Text   = tostring(val)
			if callback then pcall(callback, val) end
		end

		bar.InputBegan:Connect(function(i: InputObject)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch
			then sliderDrag = true; setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X) end
		end)
		UIS.InputChanged:Connect(function(i: InputObject)
			if sliderDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch)
			then setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X) end
		end)
		UIS.InputEnded:Connect(function(i: InputObject)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch
			then sliderDrag = false end
		end)
		valTxt.FocusLost:Connect(function(enter: boolean)
			if enter then
				local v = tonumber(valTxt.Text)
				if v then
					val = math.clamp(v, min, max)
					local p = (val - min) / (max - min)
					fill.Size = UDim2.new(p, 0, 1, 0); knob.Position = UDim2.new(p, 0, 0.5, 0)
					valTxt.Text = tostring(val)
					if callback then pcall(callback, val) end
				else valTxt.Text = tostring(val) end
			end
		end)

		updateCanvas()
		local S = {}
		function S:Set(v: number)
			val = math.clamp(v, min, max)
			local p = (val - min) / (max - min)
			fill.Size = UDim2.new(p, 0, 1, 0); knob.Position = UDim2.new(p, 0, 0.5, 0)
			valTxt.Text = tostring(val)
		end
		function S:Get() return val end
		return S
	end

	-- ── DROPDOWN ──────────────────────────────────────────────────────────────
	function Win:Dropdown(headerText: string, options: {string}, callback: (string) -> (), icon: string?)
		local selected = "Select..."
		local open     = false

		local dropBtn: TextButton = Instance.new("TextButton")
		dropBtn.Size             = UDim2.new(1, 0, 0, 44)
		dropBtn.BackgroundColor3 = T.SURFACE
		dropBtn.Text             = ""
		dropBtn.LayoutOrder      = nxt()
		dropBtn.Parent           = scroll
		_style(dropBtn)

		local textOffsetL = 10
		local iconId = _icon(icon)
		if iconId then
			local ico = _makeIcon(dropBtn, iconId, 14, T.ACCENT)
			ico.Position = UDim2.new(0, 8, 0.5, -7)
			ico.ZIndex   = dropBtn.ZIndex + 1
			textOffsetL  = 28
		end

		local headLbl: TextLabel = Instance.new("TextLabel")
		headLbl.Size               = UDim2.new(1, -(textOffsetL + 24), 0, 14)
		headLbl.Position           = UDim2.new(0, textOffsetL, 0, 3)
		headLbl.BackgroundTransparency = 1
		headLbl.Text               = headerText or "Dropdown"
		headLbl.TextColor3         = T.TEXT_DIM
		headLbl.Font               = Enum.Font.Gotham
		headLbl.TextScaled         = true
		headLbl.TextXAlignment     = Enum.TextXAlignment.Left
		headLbl.ZIndex             = dropBtn.ZIndex + 1
		headLbl.Parent             = dropBtn
		local hdsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", headLbl)
		hdsc.MaxTextSize = 10

		local selLbl: TextLabel = Instance.new("TextLabel")
		selLbl.Size               = UDim2.new(1, -(textOffsetL + 24), 0, 18)
		selLbl.Position           = UDim2.new(0, textOffsetL, 0, 17)
		selLbl.BackgroundTransparency = 1
		selLbl.Text               = selected
		selLbl.TextColor3         = T.TEXT
		selLbl.Font               = Enum.Font.GothamBold
		selLbl.TextScaled         = true
		selLbl.TextXAlignment     = Enum.TextXAlignment.Left
		selLbl.ZIndex             = dropBtn.ZIndex + 1
		selLbl.Parent             = dropBtn
		local sdsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", selLbl)
		sdsc.MaxTextSize = 13

		local arrowLbl: TextLabel = Instance.new("TextLabel")
		arrowLbl.Size               = UDim2.new(0, 18, 1, 0)
		arrowLbl.AnchorPoint        = Vector2.new(1, 0.5)
		arrowLbl.Position           = UDim2.new(1, -6, 0.5, 0)
		arrowLbl.BackgroundTransparency = 1
		arrowLbl.Text               = "▾"
		arrowLbl.TextColor3         = T.ACCENT
		arrowLbl.Font               = Enum.Font.GothamBold
		arrowLbl.TextScaled         = true
		arrowLbl.TextXAlignment     = Enum.TextXAlignment.Center
		arrowLbl.ZIndex             = dropBtn.ZIndex + 1
		arrowLbl.Parent             = dropBtn
		local adsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", arrowLbl)
		adsc.MaxTextSize = 16

		local dropFrame: Frame = Instance.new("Frame")
		dropFrame.Size             = UDim2.new(1, 0, 0, 0)
		dropFrame.BackgroundColor3 = T.SURFACE2
		dropFrame.ClipsDescendants = true
		dropFrame.LayoutOrder      = nxt()
		dropFrame.Parent           = scroll
		_corner(dropFrame, 5)
		_stroke(dropFrame)

		local dLayout = Instance.new("UIListLayout", dropFrame)
		dLayout.SortOrder = Enum.SortOrder.LayoutOrder
		local dPad = Instance.new("UIPadding", dropFrame)
		dPad.PaddingTop    = UDim.new(0, 2)
		dPad.PaddingBottom = UDim.new(0, 2)

		for _, v in ipairs(options or {}) do
			local opt: TextButton = Instance.new("TextButton")
			opt.Size             = UDim2.new(1, 0, 0, 28)
			opt.BackgroundColor3 = T.SURFACE2
			opt.Text             = ""
			opt.Parent           = dropFrame

			local optLbl: TextLabel = Instance.new("TextLabel")
			optLbl.Size               = UDim2.new(1, -14, 1, -4)
			optLbl.Position           = UDim2.new(0, 8, 0, 2)
			optLbl.BackgroundTransparency = 1
			optLbl.Text               = v
			optLbl.Font               = Enum.Font.GothamBold
			optLbl.TextScaled         = true
			optLbl.TextColor3         = T.TEXT
			optLbl.TextXAlignment     = Enum.TextXAlignment.Left
			optLbl.ZIndex             = opt.ZIndex + 1
			optLbl.Parent             = opt
			local odsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", optLbl)
			odsc.MaxTextSize = 12

			opt.MouseEnter:Connect(function()   twFast(opt, { BackgroundColor3 = T.BORDER }) end)
			opt.MouseLeave:Connect(function()   twFast(opt, { BackgroundColor3 = T.SURFACE2 }) end)
			opt.MouseButton1Click:Connect(function()
				selected      = v
				selLbl.Text   = v
				open          = false
				arrowLbl.Text = "▾"
				twMed(dropFrame, { Size = UDim2.new(1, 0, 0, 0) })
				task.wait(0.23)
				updateCanvas()
				if callback then pcall(callback, v) end
			end)
		end

		dropBtn.MouseEnter:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE2 }) end)
		dropBtn.MouseLeave:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE })  end)
		dropBtn.MouseButton1Click:Connect(function()
			open          = not open
			arrowLbl.Text = open and "▴" or "▾"
			local h       = open and (#options * 28 + 4) or 0
			twMed(dropFrame, { Size = UDim2.new(1, 0, 0, h) })
			task.delay(0.24, updateCanvas)
		end)

		updateCanvas()
		local D = {}
		function D:Get() return selected end
		function D:Set(v: string) selected = v; selLbl.Text = v end
		return D
	end

	-- ── FOLDER ─────────────────────────────────────────────────────────────────
	function Win:CreateFolder(folderName: string, folderIcon: string?)
		local tabBtn: TextButton = Instance.new("TextButton")
		tabBtn.Size             = UDim2.new(1, 0, 0, 30)
		tabBtn.BackgroundColor3 = T.SURFACE2
		tabBtn.Text             = ""
		tabBtn.LayoutOrder      = nxt()
		tabBtn.Parent           = scroll
		_style(tabBtn)

		local fTextOffL = 10
		local ficId = _icon(folderIcon)
		if ficId then
			local ico = _makeIcon(tabBtn, ficId, 12, T.TEXT_DIM)
			ico.Position = UDim2.new(0, 8, 0.5, -6)
			ico.ZIndex   = tabBtn.ZIndex + 1
			fTextOffL    = 24
		end

		local tabLbl: TextLabel = Instance.new("TextLabel")
		tabLbl.Size               = UDim2.new(1, -(fTextOffL + 6), 1, -4)
		tabLbl.Position           = UDim2.new(0, fTextOffL, 0, 2)
		tabLbl.BackgroundTransparency = 1
		tabLbl.Text               = "▶  " .. (folderName or "Folder")
		tabLbl.Font               = Enum.Font.GothamBold
		tabLbl.TextScaled         = true
		tabLbl.TextColor3         = T.TEXT_DIM
		tabLbl.TextXAlignment     = Enum.TextXAlignment.Left
		tabLbl.ZIndex             = tabBtn.ZIndex + 1
		tabLbl.Parent             = tabBtn
		local ftsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", tabLbl)
		ftsc.MinTextSize = 7
		ftsc.MaxTextSize = 12

		local content: Frame = Instance.new("Frame")
		content.Size                   = UDim2.new(1, 0, 0, 0)
		content.BackgroundColor3       = T.BG
		content.BackgroundTransparency = 0.4
		content.ClipsDescendants       = true
		content.LayoutOrder            = nxt()
		content.Parent                 = scroll
		_corner(content, 5)

		local cLayout: UIListLayout = Instance.new("UIListLayout")
		cLayout.Padding   = UDim.new(0, 3)
		cLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cLayout.Parent    = content

		local cPad: UIPadding = Instance.new("UIPadding")
		cPad.PaddingLeft   = UDim.new(0, 4)
		cPad.PaddingRight  = UDim.new(0, 0)
		cPad.PaddingTop    = UDim.new(0, 3)
		cPad.PaddingBottom = UDim.new(0, 3)
		cPad.Parent        = content

		local fBar: Frame = Instance.new("Frame")
		fBar.Size             = UDim2.new(0, 2, 1, 0)
		fBar.BackgroundColor3 = T.ACCENT
		fBar.BorderSizePixel  = 0
		fBar.Visible          = false
		fBar.Parent           = content

		local folderOpen = false
		local function updateFolder()
			task.defer(function()
				if folderOpen then
					local h = cLayout.AbsoluteContentSize.Y + 6
					twMed(content, { Size = UDim2.new(1, 0, 0, h) })
				else
					for _, obj in ipairs(content:GetDescendants()) do
						if obj:IsA("Frame") and obj.ClipsDescendants and obj ~= content then
							(obj :: Frame).Size = UDim2.new(1, 0, 0, 0)
						end
					end
					twMed(content, { Size = UDim2.new(1, 0, 0, 0) })
				end
				task.wait(0.23)
				updateCanvas()
			end)
		end

		tabBtn.MouseEnter:Connect(function()
			if not folderOpen then twFast(tabBtn, { BackgroundColor3 = T.BORDER }) end
		end)
		tabBtn.MouseLeave:Connect(function()
			if not folderOpen then twFast(tabBtn, { BackgroundColor3 = T.SURFACE2 }) end
		end)
		tabBtn.MouseButton1Click:Connect(function()
			folderOpen    = not folderOpen
			tabLbl.Text   = (folderOpen and "▼  " or "▶  ") .. (folderName or "Folder")
			twFast(tabLbl, { TextColor3 = folderOpen and T.ACCENT or T.TEXT_DIM })
			twFast(tabBtn, { BackgroundColor3 = folderOpen and T.SURFACE or T.SURFACE2 })
			fBar.Visible  = folderOpen
			updateFolder()
		end)

		local Folder = {}
		local _fOrder = 0
		local function fnxt() _fOrder += 1; return _fOrder end

		local function _fStyle(obj: GuiObject) _corner(obj, 5); _stroke(obj) end

		-- Folder:Button
		function Folder:Button(text: string, callback: () -> (), icon: string?)
			local btn: TextButton = Instance.new("TextButton")
			btn.Size             = UDim2.new(1, 0, 0, 32)
			btn.BackgroundColor3 = T.SURFACE
			btn.Text             = ""
			btn.LayoutOrder      = fnxt()
			btn.Parent           = content
			_fStyle(btn)

			local tOffL = 8
			local bid = _icon(icon)
			if bid then
				local ico = _makeIcon(btn, bid, 12, T.ACCENT)
				ico.Position = UDim2.new(0, 6, 0.5, -6)
				ico.ZIndex   = btn.ZIndex + 1
				tOffL        = 22
			end

			local lblF: Frame = Instance.new("Frame")
			lblF.Size                  = UDim2.new(1, -(tOffL + 22), 1, -6)
			lblF.Position              = UDim2.new(0, tOffL, 0, 3)
			lblF.BackgroundTransparency = 1
			lblF.ZIndex                = btn.ZIndex + 1
			lblF.Parent                = btn

			local lbl: TextLabel = Instance.new("TextLabel")
			lbl.Size                  = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text                  = text or "Button"
			lbl.Font                  = Enum.Font.GothamBold
			lbl.TextScaled            = true
			lbl.TextColor3            = T.TEXT
			lbl.TextXAlignment        = Enum.TextXAlignment.Left
			lbl.ZIndex                = btn.ZIndex + 1
			lbl.Parent                = lblF
			local fbsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
			fbsc.MinTextSize = 7
			fbsc.MaxTextSize = 12

			local arr: TextLabel = Instance.new("TextLabel")
			arr.Size               = UDim2.new(0, 14, 1, 0)
			arr.AnchorPoint        = Vector2.new(1, 0.5)
			arr.Position           = UDim2.new(1, -4, 0.5, 0)
			arr.BackgroundTransparency = 1
			arr.Text               = "›"
			arr.Font               = Enum.Font.GothamBold
			arr.TextScaled         = true
			arr.TextColor3         = T.ACCENT
			arr.ZIndex             = btn.ZIndex + 1
			arr.Parent             = btn
			local fasc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", arr)
			fasc.MinTextSize = 7
			fasc.MaxTextSize = 16

			btn.MouseEnter:Connect(function()      twFast(btn, { BackgroundColor3 = T.SURFACE2 }) end)
			btn.MouseLeave:Connect(function()      twFast(btn, { BackgroundColor3 = T.SURFACE })  end)
			btn.MouseButton1Down:Connect(function() twFast(btn, { BackgroundColor3 = T.ACCENT }) end)
			btn.MouseButton1Up:Connect(function()
				task.delay(0.12, function() twFast(btn, { BackgroundColor3 = T.SURFACE }) end)
			end)
			btn.MouseButton1Click:Connect(function()
				if callback then pcall(callback) end
			end)
			updateCanvas(); return btn
		end

		-- Folder:Toggle
		function Folder:Toggle(text: string, default: boolean, callback: (boolean) -> (), icon: string?)
			local state = default or false
			local row: TextButton = Instance.new("TextButton")
			row.Size             = UDim2.new(1, 0, 0, 32)
			row.BackgroundColor3 = T.SURFACE
			row.Text             = ""
			row.LayoutOrder      = fnxt()
			row.Parent           = content
			_fStyle(row)

			local tOffL = 8
			local tid = _icon(icon)
			if tid then
				local ico = _makeIcon(row, tid, 12, T.TEXT_DIM)
				ico.Position = UDim2.new(0, 6, 0.5, -6)
				ico.ZIndex   = row.ZIndex + 1
				tOffL        = 22
			end

			local lblF: Frame = Instance.new("Frame")
			lblF.Size                  = UDim2.new(1, -(tOffL + 44), 1, -6)
			lblF.Position              = UDim2.new(0, tOffL, 0, 3)
			lblF.BackgroundTransparency = 1
			lblF.ZIndex                = row.ZIndex + 1
			lblF.Parent                = row

			local lbl: TextLabel = Instance.new("TextLabel")
			lbl.Size                  = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text                  = text or "Toggle"
			lbl.Font                  = Enum.Font.GothamBold
			lbl.TextScaled            = true
			lbl.TextColor3            = T.TEXT
			lbl.TextXAlignment        = Enum.TextXAlignment.Left
			lbl.ZIndex                = row.ZIndex + 1
			lbl.Parent                = lblF
			local ftsc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
			ftsc2.MinTextSize = 7
			ftsc2.MaxTextSize = 12

			local pill: Frame = Instance.new("Frame")
			pill.Size             = UDim2.new(0, 30, 0, 16)
			pill.AnchorPoint      = Vector2.new(1, 0.5)
			pill.Position         = UDim2.new(1, -8, 0.5, 0)
			pill.BackgroundColor3 = state and T.ACCENT or T.SURFACE2
			pill.ZIndex           = row.ZIndex + 1
			pill.Parent           = row
			_corner(pill, 8)

			local knob: Frame = Instance.new("Frame")
			knob.Size             = UDim2.new(0, 10, 0, 10)
			knob.AnchorPoint      = Vector2.new(0.5, 0.5)
			knob.Position         = state and UDim2.new(1, -8, 0.5, 0) or UDim2.new(0, 8, 0.5, 0)
			knob.BackgroundColor3 = T.TEXT
			knob.ZIndex           = row.ZIndex + 2
			knob.Parent           = pill
			_corner(knob, 5)

			local function applyState()
				twMed(pill, { BackgroundColor3 = state and T.ACCENT or T.SURFACE2 })
				twMed(knob, { Position = state and UDim2.new(1, -8, 0.5, 0) or UDim2.new(0, 8, 0.5, 0) })
			end

			row.MouseEnter:Connect(function()    twFast(row, { BackgroundColor3 = T.SURFACE2 }) end)
			row.MouseLeave:Connect(function()    twFast(row, { BackgroundColor3 = T.SURFACE })  end)
			row.MouseButton1Click:Connect(function()
				state = not state; applyState()
				if callback then pcall(callback, state) end
			end)
			updateCanvas()
			local Tv = {}
			function Tv:Set(v) state = v; applyState() end
			function Tv:Get()  return state end
			return Tv
		end

		-- Folder:Slider
		function Folder:Slider(text: string, min: number, max: number, default: number, callback: (number) -> ())
			min = min or 0; max = max or 100
			local val = math.clamp(default or min, min, max)

			local cont: Frame = Instance.new("Frame")
			cont.Size             = UDim2.new(1, 0, 0, 56)
			cont.BackgroundColor3 = T.SURFACE
			cont.LayoutOrder      = fnxt()
			cont.Parent           = content
			_fStyle(cont)

			local lblF: Frame = Instance.new("Frame")
			lblF.Size                  = UDim2.new(0.6, -8, 0, 18)
			lblF.Position              = UDim2.new(0, 8, 0, 5)
			lblF.BackgroundTransparency = 1
			lblF.Parent                = cont

			local tLbl: TextLabel = Instance.new("TextLabel")
			tLbl.Size                  = UDim2.new(1, 0, 1, 0)
			tLbl.BackgroundTransparency = 1
			tLbl.Text                  = text or "Slider"
			tLbl.Font                  = Enum.Font.GothamBold
			tLbl.TextScaled            = true
			tLbl.TextColor3            = T.TEXT
			tLbl.TextXAlignment        = Enum.TextXAlignment.Left
			tLbl.Parent                = lblF
			local slsc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", tLbl)
			slsc2.MinTextSize = 7
			slsc2.MaxTextSize = 12

			local numBox: Frame = Instance.new("Frame")
			numBox.Size             = UDim2.new(0, 34, 0, 18)
			numBox.AnchorPoint      = Vector2.new(1, 0)
			numBox.Position         = UDim2.new(1, -8, 0, 5)
			numBox.BackgroundColor3 = T.SURFACE2
			numBox.BorderSizePixel  = 0
			numBox.Parent           = cont
			_corner(numBox, 4)

			local valTxt: TextBox = Instance.new("TextBox")
			valTxt.Size               = UDim2.new(1, -4, 1, -4)
			valTxt.Position           = UDim2.new(0, 2, 0, 2)
			valTxt.BackgroundTransparency = 1
			valTxt.Text               = tostring(val)
			valTxt.Font               = Enum.Font.GothamBold
			valTxt.TextScaled         = true
			valTxt.TextColor3         = T.ACCENT
			valTxt.ClearTextOnFocus   = false
			valTxt.TextXAlignment     = Enum.TextXAlignment.Center
			valTxt.TextYAlignment     = Enum.TextYAlignment.Center
			valTxt.Parent             = numBox
			local fvtsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", valTxt)
			fvtsc.MinTextSize = 7
			fvtsc.MaxTextSize = 11

			local bar: Frame = Instance.new("Frame")
			bar.Size             = UDim2.new(1, -16, 0, 4)
			bar.Position         = UDim2.new(0, 8, 0, 40)
			bar.BackgroundColor3 = T.SURFACE2
			bar.Parent           = cont
			_corner(bar, 3)

			local ip = (val - min) / (max - min)
			local fill: Frame = Instance.new("Frame")
			fill.Size             = UDim2.new(ip, 0, 1, 0)
			fill.BackgroundColor3 = T.ACCENT
			fill.Parent           = bar
			_corner(fill, 3)

			local knob: Frame = Instance.new("Frame")
			knob.Size             = UDim2.new(0, 10, 0, 10)
			knob.AnchorPoint      = Vector2.new(0.5, 0.5)
			knob.Position         = UDim2.new(ip, 0, 0.5, 0)
			knob.BackgroundColor3 = T.TEXT
			knob.ZIndex           = bar.ZIndex + 1
			knob.Parent           = bar
			_corner(knob, 5)
			_stroke(knob, T.ACCENT, 2)

			local sliderDrag = false
			local function setPos(pos: number)
				pos = math.clamp(pos, 0, 1)
				fill.Size = UDim2.new(pos, 0, 1, 0); knob.Position = UDim2.new(pos, 0, 0.5, 0)
				val = math.floor(min + pos * (max - min)); valTxt.Text = tostring(val)
				if callback then pcall(callback, val) end
			end

			bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliderDrag = true; setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X) end end)
			UIS.InputChanged:Connect(function(i) if sliderDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X) end end)
			UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliderDrag = false end end)
			valTxt.FocusLost:Connect(function(enter) if enter then local v = tonumber(valTxt.Text); if v then val = math.clamp(v, min, max); local p = (val-min)/(max-min); fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p,0,0.5,0); valTxt.Text = tostring(val); if callback then pcall(callback, val) end else valTxt.Text = tostring(val) end end end)

			updateCanvas()
			local S = {}
			function S:Set(v) val = math.clamp(v, min, max); local p = (val-min)/(max-min); fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p,0,0.5,0); valTxt.Text = tostring(val) end
			function S:Get() return val end
			return S
		end

		-- Folder:Dropdown
		function Folder:Dropdown(headerText: string, options: {string}, callback: (string) -> (), icon: string?)
			local selected = "Select..."
			local open     = false

			local dropBtn: TextButton = Instance.new("TextButton")
			dropBtn.Size             = UDim2.new(1, 0, 0, 40)
			dropBtn.BackgroundColor3 = T.SURFACE
			dropBtn.Text             = ""
			dropBtn.LayoutOrder      = fnxt()
			dropBtn.Parent           = content
			_fStyle(dropBtn)

			local tOffL = 8
			local fdid  = _icon(icon)
			if fdid then
				local ico = _makeIcon(dropBtn, fdid, 12, T.ACCENT)
				ico.Position = UDim2.new(0, 6, 0.5, -6)
				ico.ZIndex   = dropBtn.ZIndex + 1
				tOffL        = 22
			end

			local headLbl: TextLabel = Instance.new("TextLabel")
			headLbl.Size               = UDim2.new(1, -(tOffL + 20), 0, 12)
			headLbl.Position           = UDim2.new(0, tOffL, 0, 3)
			headLbl.BackgroundTransparency = 1
			headLbl.Text               = headerText or "Dropdown"
			headLbl.TextColor3         = T.TEXT_DIM
			headLbl.Font               = Enum.Font.Gotham
			headLbl.TextScaled         = true
			headLbl.TextXAlignment     = Enum.TextXAlignment.Left
			headLbl.ZIndex             = dropBtn.ZIndex + 1
			headLbl.Parent             = dropBtn
			local fhdsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", headLbl)
			fhdsc.MaxTextSize = 10

			local selLbl: TextLabel = Instance.new("TextLabel")
			selLbl.Size               = UDim2.new(1, -(tOffL + 20), 0, 16)
			selLbl.Position           = UDim2.new(0, tOffL, 0, 15)
			selLbl.BackgroundTransparency = 1
			selLbl.Text               = selected
			selLbl.TextColor3         = T.TEXT
			selLbl.Font               = Enum.Font.GothamBold
			selLbl.TextScaled         = true
			selLbl.TextXAlignment     = Enum.TextXAlignment.Left
			selLbl.ZIndex             = dropBtn.ZIndex + 1
			selLbl.Parent             = dropBtn
			local fsdsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", selLbl)
			fsdsc.MaxTextSize = 12

			local arrowLbl: TextLabel = Instance.new("TextLabel")
			arrowLbl.Size               = UDim2.new(0, 16, 1, 0)
			arrowLbl.AnchorPoint        = Vector2.new(1, 0.5)
			arrowLbl.Position           = UDim2.new(1, -4, 0.5, 0)
			arrowLbl.BackgroundTransparency = 1
			arrowLbl.Text               = "▾"
			arrowLbl.TextColor3         = T.ACCENT
			arrowLbl.Font               = Enum.Font.GothamBold
			arrowLbl.TextScaled         = true
			arrowLbl.ZIndex             = dropBtn.ZIndex + 1
			arrowLbl.Parent             = dropBtn
			local fadsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", arrowLbl)
			fadsc.MaxTextSize = 14

			local dropFrame: Frame = Instance.new("Frame")
			dropFrame.Size             = UDim2.new(1, 0, 0, 0)
			dropFrame.BackgroundColor3 = T.SURFACE2
			dropFrame.ClipsDescendants = true
			dropFrame.LayoutOrder      = fnxt()
			dropFrame.Parent           = content
			_corner(dropFrame, 5)
			_stroke(dropFrame)

			local dfL = Instance.new("UIListLayout", dropFrame); dfL.SortOrder = Enum.SortOrder.LayoutOrder
			local dfP = Instance.new("UIPadding", dropFrame); dfP.PaddingTop = UDim.new(0,2); dfP.PaddingBottom = UDim.new(0,2)

			for _, v in ipairs(options or {}) do
				local opt: TextButton = Instance.new("TextButton")
				opt.Size             = UDim2.new(1, 0, 0, 26)
				opt.BackgroundColor3 = T.SURFACE2
				opt.Text             = ""
				opt.Parent           = dropFrame

				local optLbl: TextLabel = Instance.new("TextLabel")
				optLbl.Size               = UDim2.new(1, -14, 1, -4)
				optLbl.Position           = UDim2.new(0, 6, 0, 2)
				optLbl.BackgroundTransparency = 1
				optLbl.Text               = v
				optLbl.Font               = Enum.Font.GothamBold
				optLbl.TextScaled         = true
				optLbl.TextColor3         = T.TEXT
				optLbl.TextXAlignment     = Enum.TextXAlignment.Left
				optLbl.ZIndex             = opt.ZIndex + 1
				optLbl.Parent             = opt
				local fodsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", optLbl)
				fodsc.MaxTextSize = 11

				opt.MouseEnter:Connect(function()   twFast(opt, { BackgroundColor3 = T.BORDER }) end)
				opt.MouseLeave:Connect(function()   twFast(opt, { BackgroundColor3 = T.SURFACE2 }) end)
				opt.MouseButton1Click:Connect(function()
					selected = v; selLbl.Text = v; open = false; arrowLbl.Text = "▾"
					twMed(dropFrame, { Size = UDim2.new(1, 0, 0, 0) })
					task.wait(0.23); updateFolder(); updateCanvas()
					if callback then pcall(callback, v) end
				end)
			end

			dropBtn.MouseEnter:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE2 }) end)
			dropBtn.MouseLeave:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE })  end)
			dropBtn.MouseButton1Click:Connect(function()
				open = not open; arrowLbl.Text = open and "▴" or "▾"
				local h = open and (#options * 26 + 4) or 0
				twMed(dropFrame, { Size = UDim2.new(1, 0, 0, h) })
				task.delay(0.24, function() updateFolder(); updateCanvas() end)
			end)

			updateCanvas()
			local D = {}
			function D:Get() return selected end
			function D:Set(v) selected = v; selLbl.Text = v end
			return D
		end

		return Folder
	end

	updateCanvas()
	return Win
end

-- START
function Lib:Start()
	_loaded = true
	for _, fn in ipairs(_pendingShow) do fn() end
	_pendingShow = {}
	_reposition()
end

return Lib
