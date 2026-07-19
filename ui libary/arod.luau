--!nocheck

-- Fallbacks for non-executor environments
local cloneref = cloneref or function(x: any): any return x end
local gethui   = gethui   or function(): Instance return game:GetService("CoreGui") end

local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local UIS: UserInputService      = cloneref(game:GetService("UserInputService"))
local Players: Players           = cloneref(game:GetService("Players"))
local RunService: RunService     = cloneref(game:GetService("RunService"))
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

-- ─── THEME ────────────────────────────────────────────────────────────────────
local T = {
	BG         = Color3.fromRGB(10,  10,  14),   -- window body
	SURFACE    = Color3.fromRGB(18,  18,  24),   -- element background
	SURFACE2   = Color3.fromRGB(26,  26,  34),   -- element hover / numbox
	BORDER     = Color3.fromRGB(42,  42,  56),   -- strokes
	ACCENT     = Color3.fromRGB(220, 20,  60),   -- crimson active
	ACCENT_DIM = Color3.fromRGB(100, 10,  28),   -- accent off-state
	TEXT       = Color3.fromRGB(240, 240, 245),  -- primary text
	TEXT_DIM   = Color3.fromRGB(120, 120, 135),  -- muted text
	TITLE_H    = 40,                              -- title bar height px
	WIN_W      = 220,
	WIN_MAR    = 15,
	WIN_Y      = 10,
}

-- ─── TWEEN PRESETS ────────────────────────────────────────────────────────────
local function tw(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end
local function twFast(obj, props)  tw(obj, 0.12, props) end
local function twMed(obj, props)   tw(obj, 0.22, props) end
local function twSlow(obj, props)  tw(obj, 0.35, props) end

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

-- ─── HELPERS ──────────────────────────────────────────────────────────────────
local function _corner(obj: GuiObject, r: number?)
	local c = Instance.new("UICorner", obj)
	c.CornerRadius = UDim.new(0, r or 6)
end

local function _stroke(obj: GuiObject, color: Color3?, thickness: number?)
	local s: UIStroke = Instance.new("UIStroke", obj)
	s.Color     = color or T.BORDER
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

-- Standard surface element style
local function _style(obj: GuiObject)
	_corner(obj)
	_stroke(obj)
end

-- Drop-shadow behind a frame (uses a slightly larger, blurred dark frame)
local function _shadow(parent: Frame)
	local sh: Frame = Instance.new("Frame")
	sh.Name              = "_shadow"
	sh.Size              = UDim2.new(1, 10, 1, 10)
	sh.Position          = UDim2.new(0, -5, 0, 4)
	sh.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
	sh.BackgroundTransparency = 0.55
	sh.ZIndex            = parent.ZIndex - 1
	sh.BorderSizePixel   = 0
	_corner(sh, 8)
	sh.Parent = parent.Parent
	-- keep shadow in sync position-wise
	parent:GetPropertyChangedSignal("Position"):Connect(function()
		sh.Position = UDim2.new(0, parent.Position.X.Offset - 5, 0, parent.Position.Y.Offset + 4)
	end)
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		sh.Size = UDim2.new(0, parent.AbsoluteSize.X + 10, 0, parent.AbsoluteSize.Y + 10)
	end)
end

-- Accent underline below the title bar
local function _accentLine(parent: Frame)
	local line: Frame = Instance.new("Frame")
	line.Size             = UDim2.new(1, 0, 0, 2)
	line.Position         = UDim2.new(0, 0, 1, -2)
	line.BackgroundColor3 = T.ACCENT
	line.BorderSizePixel  = 0
	line.Parent           = parent
end

local function _reposition()
	local vis: {Frame} = {}
	for _, w in ipairs(_windows) do
		if w.shown then
			table.insert(vis, w.frame)
		end
	end
	local n: number = #vis
	if n == 0 then return end
	local sw: number = workspace.CurrentCamera.ViewportSize.X
	local pos: {number} = {}
	if n == 1 then
		pos = { WIN_MAR }
	elseif n == 2 then
		pos = { WIN_MAR, sw - WIN_W - WIN_MAR }
	else
		local gap = math.max((sw - WIN_MAR * 2 - WIN_W * n) / (n - 1), WIN_MAR)
		for i = 1, n do
			pos[i] = WIN_MAR + (i - 1) * (WIN_W + gap)
		end
	end
	for i, frame in ipairs(vis) do
		local x = math.clamp(pos[i] or WIN_MAR, 0, sw - WIN_W)
		twSlow(frame, { Position = UDim2.new(0, x, 0, WIN_Y) })
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CREATE WINDOW
-- ─────────────────────────────────────────────────────────────────────────────
function Lib:CreateWindow(title: string)

	local winData: {[string]: any} = { shown = false }
	table.insert(_windows, winData)

	-- Outer frame (the window card)
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
	_shadow(frame)

	winData.frame = frame

	-- Title bar
	local titleBar: TextLabel = Instance.new("TextLabel")
	titleBar.Size             = UDim2.new(1, 0, 0, T.TITLE_H)
	titleBar.Text             = string.upper(title or "Window")
	titleBar.Font             = Enum.Font.LuckiestGuy
	titleBar.TextSize         = 15
	titleBar.TextColor3       = T.TEXT
	titleBar.BackgroundColor3 = T.BG
	titleBar.Active           = true
	titleBar.ZIndex           = 11
	titleBar.Parent           = frame
	_accentLine(titleBar)

	-- Collapse button (─ / ▾ icon via text)
	local colBtn: TextButton = Instance.new("TextButton")
	colBtn.Size               = UDim2.new(0, 28, 0, 28)
	colBtn.Position           = UDim2.new(1, -33, 0.5, -14)
	colBtn.Text               = "─"
	colBtn.BackgroundColor3   = T.SURFACE2
	colBtn.Font               = Enum.Font.GothamBold
	colBtn.TextSize           = 13
	colBtn.TextColor3         = T.TEXT_DIM
	colBtn.ZIndex             = 12
	colBtn.Parent             = titleBar
	_corner(colBtn, 5)

	-- Hover effect on colBtn
	colBtn.MouseEnter:Connect(function()
		twFast(colBtn, { BackgroundColor3 = T.ACCENT, TextColor3 = T.TEXT })
	end)
	colBtn.MouseLeave:Connect(function()
		twFast(colBtn, { BackgroundColor3 = T.SURFACE2, TextColor3 = T.TEXT_DIM })
	end)

	-- Scroll area
	local scroll: ScrollingFrame = Instance.new("ScrollingFrame")
	scroll.Size                = UDim2.new(1, 0, 1, -T.TITLE_H)
	scroll.Position            = UDim2.new(0, 0, 0, T.TITLE_H)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness  = 3
	scroll.ScrollBarImageColor3 = T.ACCENT
	scroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
	scroll.Parent              = frame

	local layout: UIListLayout = Instance.new("UIListLayout")
	layout.Padding   = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent    = scroll

	local pad: UIPadding = Instance.new("UIPadding")
	pad.PaddingTop    = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft   = UDim.new(0, 6)
	pad.PaddingRight  = UDim.new(0, 6)
	pad.Parent        = scroll

	local collapsed: boolean = false
	local function updateCanvas()
		task.defer(function()
			scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
			if not collapsed then
				frame.Size = UDim2.new(0, WIN_W, 0,
					math.clamp(layout.AbsoluteContentSize.Y + T.TITLE_H + 12, 80, 420))
			end
		end)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

	colBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		if collapsed then
			colBtn.Text = "▾"
			twMed(frame, { Size = UDim2.new(0, WIN_W, 0, T.TITLE_H) })
		else
			colBtn.Text = "─"
			twMed(frame, {
				Size = UDim2.new(0, WIN_W, 0,
					math.clamp(layout.AbsoluteContentSize.Y + T.TITLE_H + 12, 80, 420))
			})
		end
	end)

	-- DRAG
	local dragging: boolean  = false
	local dragStart: Vector3 = Vector3.zero
	local startPos: UDim2   = UDim2.new()

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
			local sc: Vector2  = workspace.CurrentCamera.ViewportSize
			local delta: Vector3 = i.Position - dragStart
			local newX = math.clamp(startPos.X.Offset + delta.X, 0, math.max(0, sc.X - frame.AbsoluteSize.X))
			local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, math.max(0, sc.Y - frame.AbsoluteSize.Y))
			frame.Position = UDim2.new(0, newX, 0, newY)
		end
	end)

	-- ANTI OUT-OF-SCREEN
	RunService.RenderStepped:Connect(function()
		if not frame or not frame.Parent then return end
		local sc: Vector2 = workspace.CurrentCamera.ViewportSize
		local pos = frame.Position
		local x = math.clamp(pos.X.Offset, 0, math.max(0, sc.X - frame.AbsoluteSize.X))
		local y = math.clamp(pos.Y.Offset, 0, math.max(0, sc.Y - frame.AbsoluteSize.Y))
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
	local _order: number = 0
	local function nxt(): number _order += 1; return _order end

	function Win:SetTitle(text: string)
		titleBar.Text = string.upper(text or "Window")
	end
	function Win:SetPosition(x: number, y: number)
		frame.Position = UDim2.new(0, x, 0, y)
	end

	-- ── LABEL ──────────────────────────────────────────────────────────────────
	function Win:Label(text: string)
		local lbl: TextLabel = Instance.new("TextLabel")
		lbl.Size                  = UDim2.new(1, 0, 0, 28)
		lbl.Text                  = text or "Label"
		lbl.BackgroundTransparency = 1
		lbl.TextColor3            = T.TEXT_DIM
		lbl.Font                  = Enum.Font.GothamMedium
		lbl.TextSize              = 13
		lbl.TextXAlignment        = Enum.TextXAlignment.Center
		lbl.LayoutOrder           = nxt()
		lbl.Parent                = scroll
		updateCanvas()
		return lbl
	end

	-- ── SECTION DIVIDER ────────────────────────────────────────────────────────
	function Win:Section(text: string)
		local sec: Frame = Instance.new("Frame")
		sec.Size                  = UDim2.new(1, 0, 0, 22)
		sec.BackgroundTransparency = 1
		sec.LayoutOrder           = nxt()
		sec.Parent                = scroll

		-- Left accent bar
		local bar: Frame = Instance.new("Frame")
		bar.Size             = UDim2.new(0, 3, 0.7, 0)
		bar.Position         = UDim2.new(0, 0, 0.15, 0)
		bar.BackgroundColor3 = T.ACCENT
		bar.BorderSizePixel  = 0
		bar.Parent           = sec
		_corner(bar, 2)

		-- Divider line
		local line: Frame = Instance.new("Frame")
		line.Size             = UDim2.new(1, -10, 0, 1)
		line.Position         = UDim2.new(0, 8, 0.5, 0)
		line.BackgroundColor3 = T.BORDER
		line.BorderSizePixel  = 0
		line.Parent           = sec

		local sLbl: TextLabel = Instance.new("TextLabel")
		sLbl.Size                  = UDim2.new(0.75, 0, 1, 0)
		sLbl.Position              = UDim2.new(0, 12, 0, 0)
		sLbl.BackgroundColor3      = T.BG
		sLbl.Text                  = text or ""
		sLbl.TextColor3            = T.TEXT_DIM
		sLbl.Font                  = Enum.Font.GothamBold
		sLbl.TextSize              = 11
		sLbl.TextXAlignment        = Enum.TextXAlignment.Left
		sLbl.Parent                = sec

		updateCanvas()
	end

	-- ── BUTTON ─────────────────────────────────────────────────────────────────
	function Win:Button(text: string, callback: () -> ())
		local btn: TextButton = Instance.new("TextButton")
		btn.Size             = UDim2.new(1, 0, 0, 38)
		btn.Text             = text or "Button"
		btn.BackgroundColor3 = T.SURFACE
		btn.TextColor3       = T.TEXT
		btn.Font             = Enum.Font.GothamBold
		btn.TextSize         = 14
		btn.LayoutOrder      = nxt()
		btn.TextXAlignment   = Enum.TextXAlignment.Left
		btn.Parent           = scroll
		_style(btn)

		local bp: UIPadding = Instance.new("UIPadding")
		bp.PaddingLeft  = UDim.new(0, 12)
		bp.PaddingRight = UDim.new(0, 36)
		bp.Parent       = btn

		-- Arrow chevron
		local arr: TextLabel = Instance.new("TextLabel")
		arr.Size               = UDim2.new(0, 20, 1, 0)
		arr.AnchorPoint        = Vector2.new(1, 0.5)
		arr.Position           = UDim2.new(1, -6, 0.5, 0)
		arr.BackgroundTransparency = 1
		arr.Text               = "›"
		arr.Font               = Enum.Font.GothamBold
		arr.TextSize           = 20
		arr.TextColor3         = T.ACCENT
		arr.TextXAlignment     = Enum.TextXAlignment.Center
		arr.ZIndex             = btn.ZIndex + 1
		arr.Parent             = btn

		-- Hover
		btn.MouseEnter:Connect(function()
			twFast(btn, { BackgroundColor3 = T.SURFACE2 })
		end)
		btn.MouseLeave:Connect(function()
			twFast(btn, { BackgroundColor3 = T.SURFACE })
		end)
		-- Press flash
		btn.MouseButton1Down:Connect(function()
			twFast(btn, { BackgroundColor3 = T.ACCENT })
			twFast(btn, { TextColor3 = T.TEXT })
		end)
		btn.MouseButton1Up:Connect(function()
			twMed(btn, { BackgroundColor3 = T.SURFACE2 })
			task.delay(0.15, function()
				twFast(btn, { BackgroundColor3 = T.SURFACE })
			end)
		end)
		btn.MouseButton1Click:Connect(function()
			if callback then pcall(callback) end
		end)

		updateCanvas()
		return btn
	end

	-- ── TOGGLE (pill style) ────────────────────────────────────────────────────
	function Win:Toggle(text: string, default: boolean, callback: (boolean) -> ())
		local state: boolean = default or false

		local row: TextButton = Instance.new("TextButton")
		row.Size             = UDim2.new(1, 0, 0, 38)
		row.BackgroundColor3 = T.SURFACE
		row.Text             = ""
		row.LayoutOrder      = nxt()
		row.Parent           = scroll
		_style(row)

		local lbl: TextLabel = Instance.new("TextLabel")
		lbl.Size               = UDim2.new(1, -58, 1, 0)
		lbl.Position           = UDim2.new(0, 12, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text               = text or "Toggle"
		lbl.Font               = Enum.Font.GothamBold
		lbl.TextSize           = 14
		lbl.TextColor3         = T.TEXT
		lbl.TextXAlignment     = Enum.TextXAlignment.Left
		lbl.Parent             = row

		-- Pill track
		local pill: Frame = Instance.new("Frame")
		pill.Size             = UDim2.new(0, 36, 0, 20)
		pill.AnchorPoint      = Vector2.new(1, 0.5)
		pill.Position         = UDim2.new(1, -10, 0.5, 0)
		pill.BackgroundColor3 = state and T.ACCENT or T.SURFACE2
		pill.Parent           = row
		_corner(pill, 10)

		-- Pill knob
		local knob: Frame = Instance.new("Frame")
		knob.Size         = UDim2.new(0, 14, 0, 14)
		knob.AnchorPoint  = Vector2.new(0.5, 0.5)
		knob.Position     = state and UDim2.new(1, -10, 0.5, 0) or UDim2.new(0, 10, 0.5, 0)
		knob.BackgroundColor3 = T.TEXT
		knob.Parent       = pill
		_corner(knob, 7)

		local function applyState()
			twMed(pill,  { BackgroundColor3 = state and T.ACCENT or T.SURFACE2 })
			twMed(knob,  { Position = state and UDim2.new(1, -10, 0.5, 0) or UDim2.new(0, 10, 0.5, 0) })
		end

		row.MouseEnter:Connect(function()
			twFast(row, { BackgroundColor3 = T.SURFACE2 })
		end)
		row.MouseLeave:Connect(function()
			twFast(row, { BackgroundColor3 = T.SURFACE })
		end)
		row.MouseButton1Click:Connect(function()
			state = not state
			applyState()
			if callback then pcall(callback, state) end
		end)

		updateCanvas()
		local T2 = {}
		function T2:Set(v: boolean)
			state = v
			applyState()
		end
		function T2:Get(): boolean return state end
		return T2
	end

	-- ── SLIDER ────────────────────────────────────────────────────────────────
	function Win:Slider(text: string, min: number, max: number, default: number, callback: (number) -> ())
		min = min or 0; max = max or 100
		local val: number = math.clamp(default or min, min, max)

		local cont: Frame = Instance.new("Frame")
		cont.Size             = UDim2.new(1, 0, 0, 66)
		cont.BackgroundColor3 = T.SURFACE
		cont.LayoutOrder      = nxt()
		cont.Parent           = scroll
		_style(cont)

		local tLbl: TextLabel = Instance.new("TextLabel")
		tLbl.Size               = UDim2.new(0.62, 0, 0, 20)
		tLbl.Position           = UDim2.new(0, 12, 0, 6)
		tLbl.Text               = text or "Slider"
		tLbl.Font               = Enum.Font.GothamBold
		tLbl.TextSize           = 14
		tLbl.TextXAlignment     = Enum.TextXAlignment.Left
		tLbl.TextColor3         = T.TEXT
		tLbl.BackgroundTransparency = 1
		tLbl.Parent             = cont

		-- Value box
		local numBox: Frame = Instance.new("Frame")
		numBox.Size             = UDim2.new(0, 40, 0, 22)
		numBox.AnchorPoint      = Vector2.new(1, 0)
		numBox.Position         = UDim2.new(1, -10, 0, 6)
		numBox.BackgroundColor3 = T.SURFACE2
		numBox.BorderSizePixel  = 0
		numBox.Parent           = cont
		_corner(numBox, 4)

		local valTxt: TextBox = Instance.new("TextBox")
		valTxt.Size               = UDim2.new(1, 0, 1, 0)
		valTxt.BackgroundTransparency = 1
		valTxt.Text               = tostring(val)
		valTxt.Font               = Enum.Font.GothamBold
		valTxt.TextSize           = 13
		valTxt.TextColor3         = T.ACCENT
		valTxt.ClearTextOnFocus   = false
		valTxt.TextXAlignment     = Enum.TextXAlignment.Center
		valTxt.TextYAlignment     = Enum.TextYAlignment.Center
		valTxt.Parent             = numBox

		-- Track
		local bar: Frame = Instance.new("Frame")
		bar.Size             = UDim2.new(1, -20, 0, 6)
		bar.Position         = UDim2.new(0, 10, 0, 48)
		bar.BackgroundColor3 = T.SURFACE2
		bar.Parent           = cont
		_corner(bar, 3)

		local ip: number = (val - min) / (max - min)

		local fill: Frame = Instance.new("Frame")
		fill.Size             = UDim2.new(ip, 0, 1, 0)
		fill.BackgroundColor3 = T.ACCENT
		fill.Parent           = bar
		_corner(fill, 3)

		local knob: Frame = Instance.new("Frame")
		knob.Size             = UDim2.new(0, 14, 0, 14)
		knob.AnchorPoint      = Vector2.new(0.5, 0.5)
		knob.Position         = UDim2.new(ip, 0, 0.5, 0)
		knob.BackgroundColor3 = T.TEXT
		knob.ZIndex           = bar.ZIndex + 1
		knob.Parent           = bar
		_corner(knob, 7)
		_stroke(knob, T.ACCENT, 2)

		local sliderDrag: boolean = false
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
			then
				sliderDrag = true
				setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
			end
		end)
		UIS.InputChanged:Connect(function(i: InputObject)
			if sliderDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch)
			then
				setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
			end
		end)
		UIS.InputEnded:Connect(function(i: InputObject)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch
			then
				sliderDrag = false
			end
		end)
		valTxt.FocusLost:Connect(function(enter: boolean)
			if enter then
				local v = tonumber(valTxt.Text)
				if v then
					val = math.clamp(v, min, max)
					local p = (val - min) / (max - min)
					fill.Size     = UDim2.new(p, 0, 1, 0)
					knob.Position = UDim2.new(p, 0, 0.5, 0)
					valTxt.Text   = tostring(val)
					if callback then pcall(callback, val) end
				else
					valTxt.Text = tostring(val)
				end
			end
		end)

		updateCanvas()
		local S = {}
		function S:Set(v: number)
			val = math.clamp(v, min, max)
			local p = (val - min) / (max - min)
			fill.Size     = UDim2.new(p, 0, 1, 0)
			knob.Position = UDim2.new(p, 0, 0.5, 0)
			valTxt.Text   = tostring(val)
		end
		function S:Get(): number return val end
		return S
	end

	-- ── DROPDOWN ──────────────────────────────────────────────────────────────
	function Win:Dropdown(headerText: string, options: {string}, callback: (string) -> ())
		local selected: string = "Select..."
		local open: boolean    = false

		local dropBtn: TextButton = Instance.new("TextButton")
		dropBtn.Size             = UDim2.new(1, 0, 0, 48)
		dropBtn.BackgroundColor3 = T.SURFACE
		dropBtn.Text             = ""
		dropBtn.LayoutOrder      = nxt()
		dropBtn.Parent           = scroll
		_style(dropBtn)

		local headLbl: TextLabel = Instance.new("TextLabel")
		headLbl.Size               = UDim2.new(1, -30, 0, 16)
		headLbl.Position           = UDim2.new(0, 12, 0, 4)
		headLbl.BackgroundTransparency = 1
		headLbl.Text               = headerText or "Dropdown"
		headLbl.TextColor3         = T.TEXT_DIM
		headLbl.Font               = Enum.Font.Gotham
		headLbl.TextSize           = 11
		headLbl.TextXAlignment     = Enum.TextXAlignment.Left
		headLbl.Parent             = dropBtn

		local selLbl: TextLabel = Instance.new("TextLabel")
		selLbl.Size               = UDim2.new(1, -36, 0, 20)
		selLbl.Position           = UDim2.new(0, 12, 0, 20)
		selLbl.BackgroundTransparency = 1
		selLbl.Text               = selected
		selLbl.TextColor3         = T.TEXT
		selLbl.Font               = Enum.Font.GothamBold
		selLbl.TextSize           = 14
		selLbl.TextXAlignment     = Enum.TextXAlignment.Left
		selLbl.Parent             = dropBtn

		-- Animated arrow
		local arrowLbl: TextLabel = Instance.new("TextLabel")
		arrowLbl.Size               = UDim2.new(0, 22, 1, 0)
		arrowLbl.Position           = UDim2.new(1, -26, 0, 0)
		arrowLbl.BackgroundTransparency = 1
		arrowLbl.Text               = "▾"
		arrowLbl.TextColor3         = T.ACCENT
		arrowLbl.Font               = Enum.Font.GothamBold
		arrowLbl.TextSize           = 18
		arrowLbl.TextXAlignment     = Enum.TextXAlignment.Center
		arrowLbl.Parent             = dropBtn

		local dropFrame: Frame = Instance.new("Frame")
		dropFrame.Size             = UDim2.new(1, 0, 0, 0)
		dropFrame.BackgroundColor3 = T.SURFACE2
		dropFrame.ClipsDescendants = true
		dropFrame.LayoutOrder      = nxt()
		dropFrame.Active           = false
		dropFrame.Parent           = scroll
		_corner(dropFrame, 6)
		_stroke(dropFrame)

		local dLayout = Instance.new("UIListLayout", dropFrame)
		dLayout.SortOrder = Enum.SortOrder.LayoutOrder

		local dPad = Instance.new("UIPadding", dropFrame)
		dPad.PaddingTop    = UDim.new(0, 3)
		dPad.PaddingBottom = UDim.new(0, 3)

		for _, v in ipairs(options or {}) do
			local opt: TextButton = Instance.new("TextButton")
			opt.Size             = UDim2.new(1, 0, 0, 30)
			opt.Active           = true
			opt.Text             = v
			opt.BackgroundColor3 = T.SURFACE2
			opt.TextColor3       = T.TEXT
			opt.Font             = Enum.Font.GothamBold
			opt.TextSize         = 13
			opt.TextXAlignment   = Enum.TextXAlignment.Left
			opt.Parent           = dropFrame

			local op: UIPadding = Instance.new("UIPadding")
			op.PaddingLeft = UDim.new(0, 12)
			op.Parent = opt

			opt.MouseEnter:Connect(function()
				twFast(opt, { BackgroundColor3 = T.BORDER })
			end)
			opt.MouseLeave:Connect(function()
				twFast(opt, { BackgroundColor3 = T.SURFACE2 })
			end)
			opt.MouseButton1Click:Connect(function()
				selected    = v
				selLbl.Text = v
				open        = false
				arrowLbl.Text = "▾"
				twMed(dropFrame, { Size = UDim2.new(1, 0, 0, 0) })
				task.wait(0.23)
				updateCanvas()
				if callback then pcall(callback, v) end
			end)
		end

		dropBtn.MouseEnter:Connect(function()
			twFast(dropBtn, { BackgroundColor3 = T.SURFACE2 })
		end)
		dropBtn.MouseLeave:Connect(function()
			twFast(dropBtn, { BackgroundColor3 = T.SURFACE })
		end)
		dropBtn.MouseButton1Click:Connect(function()
			open = not open
			arrowLbl.Text = open and "▴" or "▾"
			local h: number = open and (#options * 30 + 6) or 0
			twMed(dropFrame, { Size = UDim2.new(1, 0, 0, h) })
			task.delay(0.24, updateCanvas)
		end)

		updateCanvas()
		local D = {}
		function D:Get(): string return selected end
		function D:Set(v: string) selected = v; selLbl.Text = v end
		return D
	end

	-- ── FOLDER (collapsible group) ────────────────────────────────────────────
	function Win:CreateFolder(folderName: string)
		local tabBtn: TextButton = Instance.new("TextButton")
		tabBtn.Size             = UDim2.new(1, 0, 0, 32)
		tabBtn.BackgroundColor3 = T.SURFACE2
		tabBtn.TextColor3       = T.TEXT_DIM
		tabBtn.Font             = Enum.Font.GothamBold
		tabBtn.TextSize         = 13
		tabBtn.Text             = "▶  " .. (folderName or "Folder")
		tabBtn.TextXAlignment   = Enum.TextXAlignment.Left
		tabBtn.LayoutOrder      = nxt()
		tabBtn.Parent           = scroll
		_style(tabBtn)

		local tp: UIPadding = Instance.new("UIPadding")
		tp.PaddingLeft = UDim.new(0, 12)
		tp.Parent      = tabBtn

		-- Folder content container
		local content: Frame = Instance.new("Frame")
		content.Size                  = UDim2.new(1, 0, 0, 0)
		content.BackgroundColor3      = T.BG
		content.BackgroundTransparency = 0.4
		content.ClipsDescendants      = true
		content.LayoutOrder           = nxt()
		content.Parent                = scroll
		_corner(content, 5)

		local cLayout: UIListLayout = Instance.new("UIListLayout")
		cLayout.Padding   = UDim.new(0, 4)
		cLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cLayout.Parent    = content

		local cPad: UIPadding = Instance.new("UIPadding")
		cPad.PaddingLeft   = UDim.new(0, 6)
		cPad.PaddingRight  = UDim.new(0, 0)
		cPad.PaddingTop    = UDim.new(0, 4)
		cPad.PaddingBottom = UDim.new(0, 4)
		cPad.Parent        = content

		-- Left accent bar on folder body
		local fBar: Frame = Instance.new("Frame")
		fBar.Size             = UDim2.new(0, 2, 1, 0)
		fBar.BackgroundColor3 = T.ACCENT
		fBar.BorderSizePixel  = 0
		fBar.Visible          = false
		fBar.Parent           = content

		local folderOpen: boolean = false
		local function updateFolder()
			task.defer(function()
				if folderOpen then
					local h = cLayout.AbsoluteContentSize.Y + 8
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

		-- Hover on folder header
		tabBtn.MouseEnter:Connect(function()
			if not folderOpen then
				twFast(tabBtn, { BackgroundColor3 = T.BORDER })
			end
		end)
		tabBtn.MouseLeave:Connect(function()
			if not folderOpen then
				twFast(tabBtn, { BackgroundColor3 = T.SURFACE2 })
			end
		end)
		tabBtn.MouseButton1Click:Connect(function()
			folderOpen = not folderOpen
			tabBtn.Text = (folderOpen and "▼  " or "▶  ") .. (folderName or "Folder")
			twFast(tabBtn, { TextColor3 = folderOpen and T.ACCENT or T.TEXT_DIM })
			twFast(tabBtn, { BackgroundColor3 = folderOpen and T.SURFACE or T.SURFACE2 })
			fBar.Visible = folderOpen
			updateFolder()
		end)

		local Folder    = {}
		local _fOrder: number = 0
		local function fnxt(): number _fOrder += 1; return _fOrder end

		-- Shared mini style for folder items (slightly smaller)
		local function _fStyle(obj: GuiObject)
			_corner(obj, 5)
			_stroke(obj)
		end

		function Folder:Button(text: string, callback: () -> ())
			local btn: TextButton = Instance.new("TextButton")
			btn.Size             = UDim2.new(1, 0, 0, 34)
			btn.Text             = text or "Button"
			btn.BackgroundColor3 = T.SURFACE
			btn.TextColor3       = T.TEXT
			btn.Font             = Enum.Font.GothamBold
			btn.TextSize         = 13
			btn.LayoutOrder      = fnxt()
			btn.TextXAlignment   = Enum.TextXAlignment.Left
			btn.Parent           = content
			_fStyle(btn)

			local bp: UIPadding = Instance.new("UIPadding")
			bp.PaddingLeft  = UDim.new(0, 10)
			bp.PaddingRight = UDim.new(0, 28)
			bp.Parent       = btn

			local arr: TextLabel = Instance.new("TextLabel")
			arr.Size               = UDim2.new(0, 18, 1, 0)
			arr.AnchorPoint        = Vector2.new(1, 0.5)
			arr.Position           = UDim2.new(1, -4, 0.5, 0)
			arr.BackgroundTransparency = 1
			arr.Text               = "›"
			arr.Font               = Enum.Font.GothamBold
			arr.TextSize           = 18
			arr.TextColor3         = T.ACCENT
			arr.ZIndex             = btn.ZIndex + 1
			arr.Parent             = btn

			btn.MouseEnter:Connect(function()
				twFast(btn, { BackgroundColor3 = T.SURFACE2 })
			end)
			btn.MouseLeave:Connect(function()
				twFast(btn, { BackgroundColor3 = T.SURFACE })
			end)
			btn.MouseButton1Down:Connect(function()
				twFast(btn, { BackgroundColor3 = T.ACCENT })
			end)
			btn.MouseButton1Up:Connect(function()
				task.delay(0.12, function()
					twFast(btn, { BackgroundColor3 = T.SURFACE })
				end)
			end)
			btn.MouseButton1Click:Connect(function()
				if callback then pcall(callback) end
			end)

			updateCanvas()
			return btn
		end

		function Folder:Toggle(text: string, default: boolean, callback: (boolean) -> ())
			local state: boolean = default or false
			local row: TextButton = Instance.new("TextButton")
			row.Size             = UDim2.new(1, 0, 0, 34)
			row.BackgroundColor3 = T.SURFACE
			row.Text             = ""
			row.LayoutOrder      = fnxt()
			row.Parent           = content
			_fStyle(row)

			local lbl: TextLabel = Instance.new("TextLabel")
			lbl.Size               = UDim2.new(1, -56, 1, 0)
			lbl.Position           = UDim2.new(0, 10, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text               = text or "Toggle"
			lbl.Font               = Enum.Font.GothamBold
			lbl.TextSize           = 13
			lbl.TextColor3         = T.TEXT
			lbl.TextXAlignment     = Enum.TextXAlignment.Left
			lbl.Parent             = row

			local pill: Frame = Instance.new("Frame")
			pill.Size             = UDim2.new(0, 34, 0, 18)
			pill.AnchorPoint      = Vector2.new(1, 0.5)
			pill.Position         = UDim2.new(1, -10, 0.5, 0)
			pill.BackgroundColor3 = state and T.ACCENT or T.SURFACE2
			pill.Parent           = row
			_corner(pill, 9)

			local knob: Frame = Instance.new("Frame")
			knob.Size         = UDim2.new(0, 12, 0, 12)
			knob.AnchorPoint  = Vector2.new(0.5, 0.5)
			knob.Position     = state and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0)
			knob.BackgroundColor3 = T.TEXT
			knob.Parent       = pill
			_corner(knob, 6)

			local function applyState()
				twMed(pill,  { BackgroundColor3 = state and T.ACCENT or T.SURFACE2 })
				twMed(knob,  { Position = state and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0) })
			end

			row.MouseEnter:Connect(function()
				twFast(row, { BackgroundColor3 = T.SURFACE2 })
			end)
			row.MouseLeave:Connect(function()
				twFast(row, { BackgroundColor3 = T.SURFACE })
			end)
			row.MouseButton1Click:Connect(function()
				state = not state
				applyState()
				if callback then pcall(callback, state) end
			end)

			updateCanvas()
			local Tv = {}
			function Tv:Set(v: boolean) state = v; applyState() end
			function Tv:Get(): boolean return state end
			return Tv
		end

		function Folder:Slider(text: string, min: number, max: number, default: number, callback: (number) -> ())
			min = min or 0; max = max or 100
			local val: number = math.clamp(default or min, min, max)

			local cont: Frame = Instance.new("Frame")
			cont.Size             = UDim2.new(1, 0, 0, 62)
			cont.BackgroundColor3 = T.SURFACE
			cont.LayoutOrder      = fnxt()
			cont.Parent           = content
			_fStyle(cont)

			local tLbl: TextLabel = Instance.new("TextLabel")
			tLbl.Size               = UDim2.new(0.62, 0, 0, 18)
			tLbl.Position           = UDim2.new(0, 10, 0, 6)
			tLbl.Text               = text or "Slider"
			tLbl.Font               = Enum.Font.GothamBold
			tLbl.TextSize           = 13
			tLbl.TextXAlignment     = Enum.TextXAlignment.Left
			tLbl.TextColor3         = T.TEXT
			tLbl.BackgroundTransparency = 1
			tLbl.Parent             = cont

			local numBox: Frame = Instance.new("Frame")
			numBox.Size             = UDim2.new(0, 38, 0, 20)
			numBox.AnchorPoint      = Vector2.new(1, 0)
			numBox.Position         = UDim2.new(1, -8, 0, 6)
			numBox.BackgroundColor3 = T.SURFACE2
			numBox.BorderSizePixel  = 0
			numBox.Parent           = cont
			_corner(numBox, 4)

			local valTxt: TextBox = Instance.new("TextBox")
			valTxt.Size               = UDim2.new(1, 0, 1, 0)
			valTxt.BackgroundTransparency = 1
			valTxt.Text               = tostring(val)
			valTxt.Font               = Enum.Font.GothamBold
			valTxt.TextSize           = 12
			valTxt.TextColor3         = T.ACCENT
			valTxt.ClearTextOnFocus   = false
			valTxt.TextXAlignment     = Enum.TextXAlignment.Center
			valTxt.TextYAlignment     = Enum.TextYAlignment.Center
			valTxt.Parent             = numBox

			local bar: Frame = Instance.new("Frame")
			bar.Size             = UDim2.new(1, -18, 0, 5)
			bar.Position         = UDim2.new(0, 9, 0, 46)
			bar.BackgroundColor3 = T.SURFACE2
			bar.Parent           = cont
			_corner(bar, 3)

			local ip: number = (val - min) / (max - min)
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

			local sliderDrag: boolean = false
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
				then
					sliderDrag = true
					setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
				end
			end)
			UIS.InputChanged:Connect(function(i: InputObject)
				if sliderDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
					or i.UserInputType == Enum.UserInputType.Touch)
				then
					setPos((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
				end
			end)
			UIS.InputEnded:Connect(function(i: InputObject)
				if i.UserInputType == Enum.UserInputType.MouseButton1
					or i.UserInputType == Enum.UserInputType.Touch
				then
					sliderDrag = false
				end
			end)
			valTxt.FocusLost:Connect(function(enter: boolean)
				if enter then
					local v = tonumber(valTxt.Text)
					if v then
						val = math.clamp(v, min, max)
						local p = (val - min) / (max - min)
						fill.Size     = UDim2.new(p, 0, 1, 0)
						knob.Position = UDim2.new(p, 0, 0.5, 0)
						valTxt.Text   = tostring(val)
						if callback then pcall(callback, val) end
					else
						valTxt.Text = tostring(val)
					end
				end
			end)

			updateCanvas()
			local S = {}
			function S:Set(v: number)
				val = math.clamp(v, min, max)
				local p = (val - min) / (max - min)
				fill.Size     = UDim2.new(p, 0, 1, 0)
				knob.Position = UDim2.new(p, 0, 0.5, 0)
				valTxt.Text   = tostring(val)
			end
			function S:Get(): number return val end
			return S
		end

		function Folder:Dropdown(headerText: string, options: {string}, callback: (string) -> ())
			local selected: string = "Select..."
			local open: boolean    = false

			local dropBtn: TextButton = Instance.new("TextButton")
			dropBtn.Size             = UDim2.new(1, 0, 0, 44)
			dropBtn.BackgroundColor3 = T.SURFACE
			dropBtn.Text             = ""
			dropBtn.LayoutOrder      = fnxt()
			dropBtn.Parent           = content
			_fStyle(dropBtn)

			local headLbl: TextLabel = Instance.new("TextLabel")
			headLbl.Size               = UDim2.new(1, -30, 0, 14)
			headLbl.Position           = UDim2.new(0, 10, 0, 4)
			headLbl.BackgroundTransparency = 1
			headLbl.Text               = headerText or "Dropdown"
			headLbl.TextColor3         = T.TEXT_DIM
			headLbl.Font               = Enum.Font.Gotham
			headLbl.TextSize           = 11
			headLbl.TextXAlignment     = Enum.TextXAlignment.Left
			headLbl.Parent             = dropBtn

			local selLbl: TextLabel = Instance.new("TextLabel")
			selLbl.Size               = UDim2.new(1, -30, 0, 18)
			selLbl.Position           = UDim2.new(0, 10, 0, 18)
			selLbl.BackgroundTransparency = 1
			selLbl.Text               = selected
			selLbl.TextColor3         = T.TEXT
			selLbl.Font               = Enum.Font.GothamBold
			selLbl.TextSize           = 13
			selLbl.TextXAlignment     = Enum.TextXAlignment.Left
			selLbl.Parent             = dropBtn

			local arrowLbl: TextLabel = Instance.new("TextLabel")
			arrowLbl.Size               = UDim2.new(0, 20, 1, 0)
			arrowLbl.Position           = UDim2.new(1, -22, 0, 0)
			arrowLbl.BackgroundTransparency = 1
			arrowLbl.Text               = "▾"
			arrowLbl.TextColor3         = T.ACCENT
			arrowLbl.Font               = Enum.Font.GothamBold
			arrowLbl.TextSize           = 16
			arrowLbl.TextXAlignment     = Enum.TextXAlignment.Center
			arrowLbl.Parent             = dropBtn

			local dropFrame: Frame = Instance.new("Frame")
			dropFrame.Size             = UDim2.new(1, 0, 0, 0)
			dropFrame.BackgroundColor3 = T.SURFACE2
			dropFrame.ClipsDescendants = true
			dropFrame.LayoutOrder      = fnxt()
			dropFrame.Parent           = content
			_corner(dropFrame, 5)
			_stroke(dropFrame)

			local dfLayout = Instance.new("UIListLayout", dropFrame)
			dfLayout.SortOrder = Enum.SortOrder.LayoutOrder
			local dfPad = Instance.new("UIPadding", dropFrame)
			dfPad.PaddingTop    = UDim.new(0, 2)
			dfPad.PaddingBottom = UDim.new(0, 2)

			for _, v in ipairs(options or {}) do
				local opt: TextButton = Instance.new("TextButton")
				opt.Size             = UDim2.new(1, 0, 0, 28)
				opt.Text             = v
				opt.BackgroundColor3 = T.SURFACE2
				opt.TextColor3       = T.TEXT
				opt.Font             = Enum.Font.GothamBold
				opt.TextSize         = 12
				opt.TextXAlignment   = Enum.TextXAlignment.Left
				opt.Parent           = dropFrame
				local op2: UIPadding = Instance.new("UIPadding")
				op2.PaddingLeft = UDim.new(0, 10)
				op2.Parent = opt

				opt.MouseEnter:Connect(function()
					twFast(opt, { BackgroundColor3 = T.BORDER })
				end)
				opt.MouseLeave:Connect(function()
					twFast(opt, { BackgroundColor3 = T.SURFACE2 })
				end)
				opt.MouseButton1Click:Connect(function()
					selected    = v
					selLbl.Text = v
					open        = false
					arrowLbl.Text = "▾"
					twMed(dropFrame, { Size = UDim2.new(1, 0, 0, 0) })
					task.wait(0.23)
					updateFolder()
					updateCanvas()
					if callback then pcall(callback, v) end
				end)
			end

			dropBtn.MouseEnter:Connect(function()
				twFast(dropBtn, { BackgroundColor3 = T.SURFACE2 })
			end)
			dropBtn.MouseLeave:Connect(function()
				twFast(dropBtn, { BackgroundColor3 = T.SURFACE })
			end)
			dropBtn.MouseButton1Click:Connect(function()
				open = not open
				arrowLbl.Text = open and "▴" or "▾"
				local h: number = open and (#options * 28 + 4) or 0
				twMed(dropFrame, { Size = UDim2.new(1, 0, 0, h) })
				task.delay(0.24, function()
					updateFolder()
					updateCanvas()
				end)
			end)

			updateCanvas()
			local D = {}
			function D:Get(): string return selected end
			function D:Set(v: string) selected = v; selLbl.Text = v end
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
