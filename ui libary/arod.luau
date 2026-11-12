--!nocheck
local gethui   = gethui   or function() return game:GetService("CoreGui") end
local TweenService: TweenService = game:GetService("TweenService")
local UIS: UserInputService      = game:GetService("UserInputService")
local Players: Players           = game:GetService("Players")
local RunService: RunService     = game:GetService("RunService")
local player: Player             = Players.LocalPlayer

local existingGui = player:WaitForChild("PlayerGui"):FindFirstChild("455HubGui") or gethui():FindFirstChild("455HubGui")
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

local Icons: {[string]: string} = {}
local ICON_URL = "https://raw.githubusercontent.com/Religius-Star/Main/refs/heads/main/config/icon.json"

local function _loadIcons()
	local ok, result = pcall(function()
		local raw = game:HttpGet(ICON_URL)
		local iconData = loadstring(raw)()
		if iconData and iconData.assets then
			return iconData.assets
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

local function tw(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end
local function twFast(obj, props) tw(obj, 0.12, props) end
local function twMed(obj, props)  tw(obj, 0.22, props) end
local function twSlow(obj, props) tw(obj, 0.35, props) end

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

-- ============================================================
-- CONFIG LIST  (state for the list dropdown with rename / delete / refresh)
-- ============================================================
-- #region listmodel
-- Plain Lua on purpose (no type annotations) so it can be tested outside Roblox.
-- Holds what the list knows: items, selection, which row is being renamed or
-- armed for delete, and the status line. The GUI only draws it and calls these.
local function _newListModel(handlers)
	handlers = handlers or {}
	local m = {
		items = {}, selected = nil,
		mode = "idle", target = nil, armToken = 0,   -- idle | rename | armed
		status = nil, statusToken = 0,
		onChange = nil,
	}

	local function changed() if m.onChange then m.onChange() end end
	local function idle() m.mode = "idle"; m.target = nil end

	local function indexOf(name)
		for i, v in ipairs(m.items) do
			if v == name then return i end
		end
	end

	local function sortItems()
		table.sort(m.items, function(a, b)
			local la, lb = a:lower(), b:lower()
			if la == lb then return a < b end
			return la < lb
		end)
	end

	-- runs a handler safely; always returns success, result
	local function run(fn, fallback, ...)
		if not fn then return false, fallback end
		local called, success, result = pcall(fn, ...)
		if not called then return false, tostring(success) end
		return success, result
	end

	function m.setStatus(text, kind)
		m.status = { text = text, kind = kind }
		m.statusToken = m.statusToken + 1
		changed()
	end

	-- with a token: only clears if no newer status has replaced it
	function m.clearStatus(token)
		if token ~= nil and token ~= m.statusToken then return end
		m.status = nil
		changed()
	end

	function m.setItems(list)
		m.items = {}
		for _, v in ipairs(list or {}) do m.items[#m.items + 1] = v end
		sortItems()
		if m.selected and not indexOf(m.selected) then m.selected = nil end
		idle()
		changed()
	end

	function m.get() return m.selected end

	function m.select(name)
		if not indexOf(name) then return false end
		m.selected = name
		idle()
		if handlers.onSelect then pcall(handlers.onSelect, name) end
		changed()
		return true
	end

	-- like select, but silent (no onSelect)
	function m.set(name)
		if not indexOf(name) then return false end
		m.selected = name
		changed()
		return true
	end

	function m.beginRename(name)
		if not indexOf(name) then return false end
		m.mode = "rename"; m.target = name
		changed()
		return true
	end

	function m.cancel() idle(); changed() end

	function m.commitRename(newName)
		local old = m.target
		if m.mode ~= "rename" or not old then return false end
		if newName == old then idle(); changed(); return true end
		local ok, result = run(handlers.onRename, "Rename isn't available", old, newName)
		if not ok then
			m.setStatus(result or "Couldn't rename", "error")
			return false
		end
		local finalName = type(result) == "string" and result or newName
		local i = indexOf(old)
		if i then m.items[i] = finalName end
		sortItems()
		if m.selected == old then m.selected = finalName end
		idle()
		m.setStatus("Renamed to " .. finalName, "ok")
		return true
	end

	-- first press arms the row, a second press on the same row deletes it
	function m.pressDelete(name)
		if not indexOf(name) then return false end
		if m.mode == "armed" and m.target == name then
			local ok, result = run(handlers.onDelete, "Delete isn't available", name)
			idle()
			if not ok then
				m.setStatus(result or "Couldn't delete", "error")
				return false
			end
			table.remove(m.items, indexOf(name))
			if m.selected == name then m.selected = nil end
			m.setStatus("Deleted " .. name, "ok")
			return true
		end
		m.mode = "armed"; m.target = name
		m.armToken = m.armToken + 1
		changed()
		return true
	end

	-- the GUI calls this a few seconds after arming; stale tokens are ignored
	function m.disarm(token)
		if m.mode ~= "armed" or token ~= m.armToken then return end
		idle()
		changed()
	end

	function m.refresh()
		local called, list = pcall(handlers.onRefresh or function() return m.items end)
		if called and type(list) == "table" then
			m.setItems(list)
			m.setStatus("Refreshed", "ok")
		else
			m.setStatus("Couldn't refresh", "error")
		end
	end

	return m
end
-- #endregion listmodel

-- #region listview
-- Draws a list model (_newListModel) as a dropdown: a header, rows and a status line.
-- Plain Lua on purpose (no type annotations) so a fake GUI can drive it in tests.
-- Window lists and folder lists differ only in size, so sizes come in as a table.
local _LIST_DIMS = {
	window = { head = 44, row = 28, ico = 14, headText = 10, selText = 13, rowText = 12, radius = 6, btn = 20 },
	folder = { head = 40, row = 26, ico = 12, headText = 10, selText = 12, rowText = 11, radius = 5, btn = 18 },
}

local _LIST_RED = Color3.fromRGB(255, 80, 80)   -- same red the multi-select uses for "max reached"

-- parent: where the list goes, nextOrder: gives the next LayoutOrder, handlers: see _newListModel
-- (plus handlers.emptyText), onResize: called after the list opens or closes
local function _buildConfigList(parent, nextOrder, dims, headerText, iconName, items, handlers, onResize)
	handlers = handlers or {}
	local model = _newListModel(handlers)
	local open = false
	local lastShape = nil
	local emptyH = dims.row + 12

	-- header -----------------------------------------------------------------
	local head = Instance.new("TextButton")
	head.Name             = "Head"
	head.Size             = UDim2.new(1, 0, 0, dims.head)
	head.BackgroundColor3 = T.SURFACE
	head.Text             = ""
	head.LayoutOrder      = nextOrder()
	head.Parent           = parent
	_corner(head, dims.radius); _stroke(head)

	local textLeft = 8
	local iconId = _icon(iconName)
	if iconId then
		local ico = _makeIcon(head, iconId, dims.ico, T.ACCENT)
		ico.Name     = "Icon"
		ico.Position = UDim2.new(0, 6, 0.5, -dims.ico / 2)
		ico.ZIndex   = head.ZIndex + 1
		textLeft = 6 + dims.ico + 6
	end
	local rightSpace = 6 + 12 + 4 + dims.btn + 4   -- room for the arrow and the refresh button

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name                   = "Title"
	titleLbl.Size                   = UDim2.new(1, -(textLeft + rightSpace), 0, 12)
	titleLbl.Position               = UDim2.new(0, textLeft, 0, 4)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text                   = headerText or "Config list"
	titleLbl.TextColor3             = T.TEXT_DIM
	titleLbl.Font                   = Enum.Font.Gotham
	titleLbl.TextScaled             = true
	titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
	titleLbl.ZIndex                 = head.ZIndex + 1
	titleLbl.Parent                 = head
	Instance.new("UITextSizeConstraint", titleLbl).MaxTextSize = dims.headText

	local valueLbl = Instance.new("TextLabel")
	valueLbl.Name                   = "Value"
	valueLbl.Size                   = UDim2.new(1, -(textLeft + rightSpace), 0, 16)
	valueLbl.Position               = UDim2.new(0, textLeft, 0, dims.head - 22)
	valueLbl.BackgroundTransparency = 1
	valueLbl.Text                   = ""
	valueLbl.TextColor3             = T.TEXT
	valueLbl.Font                   = Enum.Font.GothamBold
	valueLbl.TextScaled             = true
	valueLbl.TextXAlignment         = Enum.TextXAlignment.Left
	valueLbl.ZIndex                 = head.ZIndex + 1
	valueLbl.Parent                 = head
	Instance.new("UITextSizeConstraint", valueLbl).MaxTextSize = dims.selText

	-- arrow: a chevron icon when icons loaded, a text glyph otherwise
	local chevDown, chevUp = _icon("chevron-down"), _icon("chevron-up")
	local arrow
	if chevDown then
		arrow = Instance.new("ImageLabel")
		arrow.Size                   = UDim2.new(0, 12, 0, 12)
		arrow.AnchorPoint            = Vector2.new(1, 0.5)
		arrow.Position               = UDim2.new(1, -6, 0.5, 0)
		arrow.BackgroundTransparency = 1
		arrow.Image                  = chevDown
		arrow.ImageColor3            = T.ACCENT
		arrow.ScaleType              = Enum.ScaleType.Fit
	else
		arrow = Instance.new("TextLabel")
		arrow.Size                   = UDim2.new(0, 14, 1, 0)
		arrow.AnchorPoint            = Vector2.new(1, 0.5)
		arrow.Position               = UDim2.new(1, -5, 0.5, 0)
		arrow.BackgroundTransparency = 1
		arrow.Text                   = "▾"
		arrow.TextColor3             = T.ACCENT
		arrow.Font                   = Enum.Font.GothamBold
		arrow.TextScaled             = true
		Instance.new("UITextSizeConstraint", arrow).MaxTextSize = 14
	end
	arrow.Name   = "Arrow"
	arrow.ZIndex = head.ZIndex + 1
	arrow.Parent = head
	local function setArrow(isOpen)
		if chevDown then
			arrow.Image = isOpen and (chevUp or chevDown) or chevDown
		else
			arrow.Text = isOpen and "▴" or "▾"
		end
	end

	head.MouseEnter:Connect(function() twFast(head, { BackgroundColor3 = T.SURFACE2 }) end)
	head.MouseLeave:Connect(function() twFast(head, { BackgroundColor3 = T.SURFACE }) end)

	-- the list ---------------------------------------------------------------
	local list = Instance.new("Frame")
	list.Name             = "List"
	list.Size             = UDim2.new(1, 0, 0, 0)
	list.BackgroundColor3 = T.SURFACE2
	list.ClipsDescendants = true
	list.LayoutOrder      = nextOrder()
	list.Parent           = parent
	_corner(list, 5); _stroke(list)
	Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder
	local listPad = Instance.new("UIPadding", list)
	listPad.PaddingTop    = UDim.new(0, 2)
	listPad.PaddingBottom = UDim.new(0, 2)

	local function listHeight()
		if #model.items == 0 then return emptyH + 4 end
		return #model.items * dims.row + 4
	end

	local function setOpen(v)
		open = v
		setArrow(v)
		twMed(list, { Size = UDim2.new(1, 0, 0, v and listHeight() or 0) })
		if onResize then task.delay(0.24, onResize) end
	end

	local function buildEmpty()
		local box = Instance.new("Frame")
		box.Name                   = "Empty"
		box.Size                   = UDim2.new(1, 0, 0, emptyH)
		box.BackgroundTransparency = 1
		box.BorderSizePixel        = 0
		box.Parent                 = list
		local l = Instance.new("TextLabel")
		l.Size                   = UDim2.new(1, -20, 1, -8)
		l.Position               = UDim2.new(0, 10, 0, 4)
		l.BackgroundTransparency = 1
		l.Text                   = handlers.emptyText or "No configs yet"
		l.Font                   = Enum.Font.Gotham
		l.TextSize               = dims.rowText - 2
		l.TextWrapped            = true
		l.TextColor3             = T.TEXT_DIM
		l.TextXAlignment         = Enum.TextXAlignment.Left
		l.ZIndex                 = box.ZIndex + 2
		l.Parent                 = box
	end

	local function nameLabel(row, text, rightSpace, bold)
		local l = Instance.new("TextLabel")
		l.Name                   = "Label"
		l.Size                   = UDim2.new(1, -(14 + rightSpace), 1, -4)
		l.Position               = UDim2.new(0, 10, 0, 2)
		l.BackgroundTransparency = 1
		l.Text                   = text
		l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextScaled             = true
		l.TextColor3             = T.TEXT
		l.TextXAlignment         = Enum.TextXAlignment.Left
		l.ZIndex                 = row.ZIndex + 2
		l.Parent                 = row
		Instance.new("UITextSizeConstraint", l).MaxTextSize = dims.rowText
		return l
	end

	-- a small button on the right side of a row: an icon if it loaded, a text glyph if not
	local function iconButton(row, name, rightOffset, iconName, fallback, color, onClick)
		local b = Instance.new("TextButton")
		b.Name                   = name
		b.Size                   = UDim2.new(0, dims.btn, 0, dims.btn)
		b.AnchorPoint            = Vector2.new(1, 0.5)
		b.Position               = UDim2.new(1, -rightOffset, 0.5, 0)
		b.BackgroundTransparency = 1
		b.Text                   = ""
		b.ZIndex                 = row.ZIndex + 3
		b.Parent                 = row
		local id = _icon(iconName)
		local glyph, prop
		if id then
			glyph = _makeIcon(b, id, dims.btn - 8, color)
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position    = UDim2.new(0.5, 0, 0.5, 0)
			prop = "ImageColor3"
		else
			glyph = Instance.new("TextLabel")
			glyph.Size                   = UDim2.new(1, 0, 1, 0)
			glyph.BackgroundTransparency = 1
			glyph.Text                   = fallback
			glyph.TextColor3             = color
			glyph.Font                   = Enum.Font.GothamBold
			glyph.TextScaled             = true
			glyph.Parent                 = b
			Instance.new("UITextSizeConstraint", glyph).MaxTextSize = 11
			prop = "TextColor3"
		end
		glyph.ZIndex = b.ZIndex + 1
		b.MouseEnter:Connect(function() twFast(glyph, { [prop] = T.ACCENT }) end)
		b.MouseLeave:Connect(function() twFast(glyph, { [prop] = color }) end)
		b.MouseButton1Click:Connect(function() onClick(glyph) end)
		return b, glyph
	end

	-- refresh button in the header (left of the arrow); its icon spins once when pressed
	iconButton(head, "Refresh", 6 + 12 + 4, "refresh-cw", "↻", T.TEXT_DIM, function(glyph)
		glyph.Rotation = 0
		twSlow(glyph, { Rotation = 360 })
		model.refresh()
	end)

	local function buildRow(index, name)
		local selected = model.selected == name
		local armed    = model.mode == "armed" and model.target == name
		local renaming = model.mode == "rename" and model.target == name

		local row = Instance.new("Frame")
		row.Name             = "Row"
		row.Size             = UDim2.new(1, 0, 0, dims.row)
		row.BackgroundColor3 = selected and T.SURFACE or T.SURFACE2
		row.BorderSizePixel  = 0
		row.LayoutOrder      = index
		row.Parent           = list

		if selected then
			local mark = Instance.new("Frame")
			mark.Name             = "Mark"
			mark.Size             = UDim2.new(0, 2, 1, -8)
			mark.Position         = UDim2.new(0, 0, 0, 4)
			mark.BackgroundColor3 = T.ACCENT
			mark.BorderSizePixel  = 0
			mark.ZIndex           = row.ZIndex + 2
			mark.Parent           = row
			_corner(mark, 1)
		end

		if renaming then
			-- the row turns into a text box: Enter or the check saves, the cross or Escape cancels
			local box = Instance.new("TextBox")
			box.Name              = "Editor"
			box.Size              = UDim2.new(1, -(12 + dims.btn * 2 + 10), 1, -8)
			box.Position          = UDim2.new(0, 8, 0, 4)
			box.BackgroundColor3  = T.BG
			box.Text              = name
			box.PlaceholderText   = "New name"
			box.TextColor3        = T.TEXT
			box.PlaceholderColor3 = T.TEXT_DIM
			box.Font              = Enum.Font.GothamBold
			box.TextSize          = dims.rowText
			box.TextXAlignment    = Enum.TextXAlignment.Left
			box.ClearTextOnFocus  = false
			box.ZIndex            = row.ZIndex + 2
			box.Parent            = row
			_corner(box, 4); _stroke(box, T.ACCENT)
			Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 6)
			-- losing focus any other way (a tap on the check button, say) must not close the editor
			box.FocusLost:Connect(function(enter, input)
				if enter then
					model.commitRename(box.Text)
				elseif input and input.KeyCode == Enum.KeyCode.Escape then
					model.cancel()
				end
			end)
			iconButton(row, "Cancel", 4, "x", "✕", T.TEXT_DIM, function() model.cancel() end)
			iconButton(row, "Save", 4 + dims.btn + 2, "check", "✓", T.ACCENT, function() model.commitRename(box.Text) end)
			task.defer(function() box:CaptureFocus() end)
			return
		end

		-- clicking the row picks it
		local pick = Instance.new("TextButton")
		pick.Name                   = "Pick"
		pick.Size                   = UDim2.new(1, 0, 1, 0)
		pick.BackgroundTransparency = 1
		pick.Text                   = ""
		pick.ZIndex                 = row.ZIndex + 1
		pick.Parent                 = row
		pick.MouseEnter:Connect(function() if not selected then twFast(row, { BackgroundColor3 = T.BORDER }) end end)
		pick.MouseLeave:Connect(function() if not selected then twFast(row, { BackgroundColor3 = T.SURFACE2 }) end end)
		pick.MouseButton1Click:Connect(function()
			model.select(name)
			setOpen(false)
		end)

		if armed then
			-- the X turned into a "Delete?" pill: one more press deletes, or it wears off
			nameLabel(row, name, 62, selected)
			local sure = Instance.new("TextButton")
			sure.Name             = "Confirm"
			sure.Size             = UDim2.new(0, 56, 0, dims.btn - 2)
			sure.AnchorPoint      = Vector2.new(1, 0.5)
			sure.Position         = UDim2.new(1, -4, 0.5, 0)
			sure.BackgroundColor3 = T.ACCENT
			sure.AutoButtonColor  = false
			sure.Text             = "Delete?"
			sure.TextColor3       = T.TEXT
			sure.Font             = Enum.Font.GothamBold
			sure.TextSize         = dims.rowText - 2
			sure.ZIndex           = row.ZIndex + 3
			sure.Parent           = row
			_corner(sure, 4)
			sure.MouseButton1Click:Connect(function() model.pressDelete(name) end)
		else
			nameLabel(row, name, dims.btn * 2 + 10, selected)
			iconButton(row, "Delete", 4, "x", "✕", T.TEXT_DIM, function()
				model.pressDelete(name)
				local token = model.armToken
				task.delay(3, function() model.disarm(token) end)   -- the confirm wears off
			end)
			iconButton(row, "Rename", 4 + dims.btn + 2, "pencil", "Aa", T.TEXT_DIM, function()
				model.beginRename(name)
			end)
		end
	end

	-- drawing ----------------------------------------------------------------
	local function renderHeader()
		local st = model.status
		if st then
			valueLbl.Text       = st.text
			valueLbl.TextColor3 = st.kind == "error" and _LIST_RED or T.ACCENT
		elseif model.selected then
			valueLbl.Text       = model.selected
			valueLbl.TextColor3 = T.TEXT
		else
			valueLbl.Text       = #model.items == 0 and "No configs yet" or "Select a config"
			valueLbl.TextColor3 = T.TEXT_DIM
		end
	end

	local function renderRows()
		-- only redraw when the rows would look different, so a status message does not rebuild an open editor
		local shape = table.concat(model.items, "\n") .. "|" .. tostring(model.selected)
			.. "|" .. model.mode .. "|" .. tostring(model.target)
		if shape == lastShape then return end
		lastShape = shape
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		if #model.items == 0 then
			buildEmpty()
		else
			for i, name in ipairs(model.items) do buildRow(i, name) end
		end
		if open then twMed(list, { Size = UDim2.new(1, 0, 0, listHeight()) }) end
	end

	local lastStatus = 0
	model.onChange = function()
		if model.status and model.statusToken ~= lastStatus then
			lastStatus = model.statusToken
			local token = model.statusToken
			task.delay(2.5, function() model.clearStatus(token) end)   -- messages fade after a moment
		end
		renderHeader()
		renderRows()
	end

	head.MouseButton1Click:Connect(function() setOpen(not open) end)
	model.setItems(items or {})

	-- what the caller gets back
	local L = { Model = model }
	function L:Get() return model.get() end
	function L:Set(name) return model.set(name) end   -- select without calling onSelect
	function L:SetItems(newItems) model.setItems(newItems) end
	function L:Refresh() model.refresh() end
	function L:Status(text, kind) model.setStatus(text, kind) end   -- kind: "ok" or "error"
	function L:Close() if open then setOpen(false) end end
	return L
end
-- #endregion listview

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

	local titleBar: Frame = Instance.new("Frame")
	titleBar.Size             = UDim2.new(1, 0, 0, T.TITLE_H)
	titleBar.BackgroundColor3 = T.BG
	titleBar.BorderSizePixel  = 0
	titleBar.ZIndex           = 11
	titleBar.Active           = true
	titleBar.Parent           = frame
	_accentLine(titleBar)

	local iconId = _icon(titleIcon)
	local titleTextX = 10
	if iconId then
		local ico = _makeIcon(titleBar, iconId, 16, T.ACCENT)
		ico.Position  = UDim2.new(0, 8, 0.5, -8)
		ico.ZIndex    = 12
		titleTextX    = 30
	end

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

	local colBtn: TextButton = Instance.new("TextButton")
	colBtn.Size               = UDim2.new(0, 24, 0, 24)
	colBtn.AnchorPoint        = Vector2.new(1, 0.5)
	colBtn.Position           = UDim2.new(1, -34, 0.5, 0)
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
			local delta = i.Position - dragStart
			local newX = startPos.X.Offset + delta.X
			local newY = startPos.Y.Offset + delta.Y
			frame.Position = UDim2.new(0, newX, 0, newY)
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
		local L = {}
		function L:Set(v: string) lbl.Text = v or "" end
		return L
	end

	function Win:Section(text: string)
		local sec: Frame = Instance.new("Frame")
		sec.Size                   = UDim2.new(1, 0, 0, 24)
		sec.BackgroundColor3       = T.SURFACE2
		sec.BackgroundTransparency = 0
		sec.LayoutOrder            = nxt()
		sec.Parent                 = scroll
		_corner(sec, 5)

		local accentBar: Frame = Instance.new("Frame")
		accentBar.Size             = UDim2.new(0, 3, 0.7, 0)
		accentBar.Position         = UDim2.new(0, 0, 0.15, 0)
		accentBar.BackgroundColor3 = T.ACCENT
		accentBar.BorderSizePixel  = 0
		accentBar.Parent           = sec
		_corner(accentBar, 2)

		local sLbl: TextLabel = Instance.new("TextLabel")
		sLbl.Size                  = UDim2.new(1, -16, 1, 0)
		sLbl.Position              = UDim2.new(0, 10, 0, 0)
		sLbl.BackgroundTransparency = 1
		sLbl.Text                  = string.upper(text or "")
		sLbl.TextColor3            = T.ACCENT
		sLbl.Font                  = Enum.Font.GothamBlack
		sLbl.TextScaled            = true
		sLbl.TextXAlignment        = Enum.TextXAlignment.Left
		sLbl.Parent                = sec
		local sc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", sLbl)
		sc2.MinTextSize = 7
		sc2.MaxTextSize = 10

		updateCanvas()
	end

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

	-- Dropdown signature (backward compat):
	-- single: Win:Dropdown(header, options, callback, icon?)
	-- multi:  Win:Dropdown(header, options, callback, icon?, true, maxPick?)
	-- multi arg4 can also be skipped: Win:Dropdown(header, options, callback, nil, true, 3)
	function Win:Dropdown(headerText: string, options: {string}, callback: any, icon: any, multi: boolean?, maxPick: number?)
		-- backward compat: if icon is boolean, treat as multi flag (no icon provided)
		local _icon2 = icon
		local _multi = multi
		local _max   = maxPick
		if type(icon) == "boolean" then
			_multi = icon
			_max   = multi :: any
			_icon2 = nil
		end
		_multi = _multi == true
		_max   = type(_max) == "number" and _max or (#options)

		local selected: string         = "Select..."
		local selectedSet: {[string]: boolean} = {}
		local selectedList: {string}   = {}
		local open = false

		local function buildLabel(): string
			if not _multi then
				return selected
			end
			if #selectedList == 0 then return "Select..." end
			if #selectedList <= 2 then return table.concat(selectedList, ", ") end
			return selectedList[1] .. ", +" .. (#selectedList - 1)
		end

		local dropBtn: TextButton = Instance.new("TextButton")
		dropBtn.Name             = "DropButton"
		dropBtn.Size             = UDim2.new(1, 0, 0, 44)
		dropBtn.BackgroundColor3 = T.SURFACE
		dropBtn.Text             = ""
		dropBtn.LayoutOrder      = nxt()
		dropBtn.Parent           = scroll
		_style(dropBtn)

		local textOffsetL = 10
		local iconId = _icon(_icon2)
		if iconId then
			local ico = _makeIcon(dropBtn, iconId, 14, T.ACCENT)
			ico.Position = UDim2.new(0, 8, 0.5, -7)
			ico.ZIndex   = dropBtn.ZIndex + 1
			textOffsetL  = 28
		end

		-- multi badge: shows "2/3" when multi mode
		local badgeLbl: TextLabel?
		if _multi then
			local badge: TextLabel = Instance.new("TextLabel")
			badge.Name               = "DropBadge"
			badge.Size               = UDim2.new(0, 28, 0, 14)
			badge.AnchorPoint        = Vector2.new(1, 0)
			badge.Position           = UDim2.new(1, -28, 0, 4)
			badge.BackgroundColor3   = T.ACCENT_DIM
			badge.Text               = "0/" .. _max
			badge.Font               = Enum.Font.GothamBold
			badge.TextScaled         = true
			badge.TextColor3         = T.ACCENT
			badge.TextXAlignment     = Enum.TextXAlignment.Center
			badge.ZIndex             = dropBtn.ZIndex + 2
			badge.Parent             = dropBtn
			_corner(badge, 4)
			local bsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", badge)
			bsc.MinTextSize = 6
			bsc.MaxTextSize = 9
			badgeLbl = badge
		end

		local headLbl: TextLabel = Instance.new("TextLabel")
		headLbl.Size               = UDim2.new(1, -(textOffsetL + (_multi and 34 or 24)), 0, 14)
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
		selLbl.Name               = "DropValue"
		selLbl.Size               = UDim2.new(1, -(textOffsetL + (_multi and 34 or 24)), 0, 18)
		selLbl.Position           = UDim2.new(0, textOffsetL, 0, 17)
		selLbl.BackgroundTransparency = 1
		selLbl.Text               = "Select..."
		selLbl.TextColor3         = T.TEXT
		selLbl.Font               = Enum.Font.GothamBold
		selLbl.TextScaled         = true
		selLbl.TextXAlignment     = Enum.TextXAlignment.Left
		selLbl.ZIndex             = dropBtn.ZIndex + 1
		selLbl.Parent             = dropBtn
		local sdsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", selLbl)
		sdsc.MaxTextSize = 13

		local _chevDownId = _icon("chevron-down")
		local _chevUpId   = _icon("chevron-up")
		local arrowImg: ImageLabel?
		local arrowLbl: TextLabel?

		if _chevDownId then
			local img: ImageLabel = Instance.new("ImageLabel")
			img.Size                  = UDim2.new(0, 14, 0, 14)
			img.AnchorPoint           = Vector2.new(1, 0.5)
			img.Position              = UDim2.new(1, -6, 0.5, 0)
			img.BackgroundTransparency = 1
			img.Image                 = _chevDownId
			img.ImageColor3           = T.ACCENT
			img.ScaleType             = Enum.ScaleType.Fit
			img.ZIndex                = dropBtn.ZIndex + 1
			img.Parent                = dropBtn
			arrowImg = img
		else
			local lbl: TextLabel = Instance.new("TextLabel")
			lbl.Size               = UDim2.new(0, 18, 1, 0)
			lbl.AnchorPoint        = Vector2.new(1, 0.5)
			lbl.Position           = UDim2.new(1, -6, 0.5, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text               = "▾"
			lbl.TextColor3         = T.ACCENT
			lbl.Font               = Enum.Font.GothamBold
			lbl.TextScaled         = true
			lbl.TextXAlignment     = Enum.TextXAlignment.Center
			lbl.ZIndex             = dropBtn.ZIndex + 1
			lbl.Parent             = dropBtn
			local adsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
			adsc.MaxTextSize = 16
			arrowLbl = lbl
		end

		local function setArrow(isOpen: boolean)
			if arrowImg then
				arrowImg.Image = isOpen and (_chevUpId or _chevDownId) or _chevDownId
			elseif arrowLbl then
				arrowLbl.Text = isOpen and "▴" or "▾"
			end
		end

		local dropFrame: Frame = Instance.new("Frame")
		dropFrame.Name             = "DropList"
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

		-- option rows
		local optFrames: {[string]: Frame} = {}

		for _, v in ipairs(options or {}) do
			local opt: TextButton = Instance.new("TextButton")
			opt.Name             = "DropOption"
			opt.Size             = UDim2.new(1, 0, 0, 28)
			opt.BackgroundColor3 = T.SURFACE2
			opt.Text             = ""
			opt.Parent           = dropFrame
			optFrames[v]         = opt

			local optLbl: TextLabel = Instance.new("TextLabel")
			optLbl.Size               = UDim2.new(1, _multi and -28 or -14, 1, -4)
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

			-- multi: pill checkbox on right
			local checkDot: Frame?
			if _multi then
				local dot: Frame = Instance.new("Frame")
				dot.Name             = "DropDot"
				dot.Size             = UDim2.new(0, 12, 0, 12)
				dot.AnchorPoint      = Vector2.new(1, 0.5)
				dot.Position         = UDim2.new(1, -8, 0.5, 0)
				dot.BackgroundColor3 = T.BORDER
				dot.ZIndex           = opt.ZIndex + 2
				dot.Parent           = opt
				_corner(dot, 3)
				checkDot = dot
			end

			local function refreshOpt()
				if not _multi then return end
				local on = selectedSet[v] == true
				twFast(opt, { BackgroundColor3 = on and T.SURFACE or T.SURFACE2 })
				if checkDot then
					twFast(checkDot, { BackgroundColor3 = on and T.ACCENT or T.BORDER })
				end
				optLbl.TextColor3 = on and T.TEXT or T.TEXT_DIM
			end

			opt.MouseEnter:Connect(function()
				if not (selectedSet[v] and _multi) then
					twFast(opt, { BackgroundColor3 = T.BORDER })
				end
			end)
			opt.MouseLeave:Connect(function()
				if _multi then refreshOpt()
				else twFast(opt, { BackgroundColor3 = T.SURFACE2 }) end
			end)

			opt.MouseButton1Click:Connect(function()
				if not _multi then
					-- single mode: original behavior
					selected    = v
					selLbl.Text = v
					open        = false
					setArrow(false)
					twMed(dropFrame, { Size = UDim2.new(1, 0, 0, 0) })
					task.wait(0.23)
					updateCanvas()
					if callback then pcall(callback, v) end
				else
					-- multi mode
					if selectedSet[v] then
						selectedSet[v] = nil
						for i, sv in ipairs(selectedList) do
							if sv == v then table.remove(selectedList, i); break end
						end
					else
						if #selectedList >= _max then
							-- max reached: flash badge red briefly
							if badgeLbl then
								twFast(badgeLbl, { TextColor3 = Color3.fromRGB(255, 80, 80) })
								task.delay(0.4, function()
									twFast(badgeLbl, { TextColor3 = T.ACCENT })
								end)
							end
							return
						end
						selectedSet[v] = true
						table.insert(selectedList, v)
					end
					refreshOpt()
					selLbl.Text = buildLabel()
					if badgeLbl then
						badgeLbl.Text = #selectedList .. "/" .. _max
					end
					if callback then pcall(callback, selectedList) end
				end
			end)
		end

		dropBtn.MouseEnter:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE2 }) end)
		dropBtn.MouseLeave:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE })  end)
		dropBtn.MouseButton1Click:Connect(function()
			open = not open
			setArrow(open)
			local h = open and (#options * 28 + 4) or 0
			twMed(dropFrame, { Size = UDim2.new(1, 0, 0, h) })
			task.delay(0.24, updateCanvas)
		end)

		updateCanvas()
		local D = {}
		-- Get: single returns string, multi returns {string}
		function D:Get() return _multi and selectedList or selected end
		-- Set: single pass string, multi pass {string}
		function D:Set(v: any)
			if not _multi then
				selected = v; selLbl.Text = v
			else
				selectedSet = {}; selectedList = {}
				for _, item in ipairs(v) do
					selectedSet[item] = true
					table.insert(selectedList, item)
				end
				selLbl.Text = buildLabel()
				if badgeLbl then badgeLbl.Text = #selectedList .. "/" .. _max end
				for item, frame in pairs(optFrames) do
					local on = selectedSet[item] == true
					frame.BackgroundColor3 = on and T.SURFACE or T.SURFACE2
					local dot = frame:FindFirstChildOfClass("Frame")
					if dot then dot.BackgroundColor3 = on and T.ACCENT or T.BORDER end
					local lbl = frame:FindFirstChildOfClass("TextLabel")
					if lbl then lbl.TextColor3 = on and T.TEXT or T.TEXT_DIM end
				end
			end
		end
		function D:Clear()
			if _multi then
				selectedSet = {}; selectedList = {}
				selLbl.Text = "Select..."
				if badgeLbl then badgeLbl.Text = "0/" .. _max end
				for _, frame in pairs(optFrames) do
					frame.BackgroundColor3 = T.SURFACE2
					local dot = frame:FindFirstChildOfClass("Frame")
					if dot then dot.BackgroundColor3 = T.BORDER end
					local lbl = frame:FindFirstChildOfClass("TextLabel")
					if lbl then lbl.TextColor3 = T.TEXT_DIM end
				end
			else
				selected = "Select..."; selLbl.Text = selected
			end
		end
		return D
	end

	-- Config list: a dropdown of saved configs. The pencil renames a row, the X deletes it (press twice),
	-- the arrows button in the header refreshes the list.
	-- handlers: onSelect(name), onRename(old, new) -> ok, nameOrError, onDelete(name) -> ok, error,
	--           onRefresh() -> {names}, emptyText
	function Win:ConfigList(headerText: string, items: {string}?, handlers: any, icon: string?)
		local L = _buildConfigList(scroll, nxt, _LIST_DIMS.window, headerText, icon, items, handlers, updateCanvas)
		updateCanvas()
		return L
	end

	function Win:TextBox(labelText: string, default: string, placeholder: string, callback: (string) -> (), icon: string?)
		local currentVal: string = default or ""

		local cont: Frame = Instance.new("Frame")
		cont.Size             = UDim2.new(1, 0, 0, 54)
		cont.BackgroundColor3 = T.SURFACE
		cont.LayoutOrder      = nxt()
		cont.Parent           = scroll
		_style(cont)

		local textOffsetL = 10
		local iconId = _icon(icon)
		if iconId then
			local ico = _makeIcon(cont, iconId, 14, T.ACCENT)
			ico.Position = UDim2.new(0, 8, 0, 7)
			ico.ZIndex   = cont.ZIndex + 1
			textOffsetL  = 28
		end

		local headerLbl: TextLabel = Instance.new("TextLabel")
		headerLbl.Size               = UDim2.new(1, -(textOffsetL + 8), 0, 16)
		headerLbl.Position           = UDim2.new(0, textOffsetL, 0, 5)
		headerLbl.BackgroundTransparency = 1
		headerLbl.Text               = labelText or "Input"
		headerLbl.Font               = Enum.Font.GothamBold
		headerLbl.TextScaled         = true
		headerLbl.TextColor3         = T.TEXT
		headerLbl.TextXAlignment     = Enum.TextXAlignment.Left
		headerLbl.ZIndex             = cont.ZIndex + 1
		headerLbl.Parent             = cont
		local htsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", headerLbl)
		htsc.MinTextSize = 8
		htsc.MaxTextSize = 12

		local inputBg: Frame = Instance.new("Frame")
		inputBg.Size             = UDim2.new(1, -16, 0, 22)
		inputBg.Position         = UDim2.new(0, 8, 0, 26)
		inputBg.BackgroundColor3 = T.BG
		inputBg.ZIndex           = cont.ZIndex + 1
		inputBg.Parent           = cont
		_corner(inputBg, 4)
		_stroke(inputBg, T.BORDER, 1)

		local clearBtn: TextButton = Instance.new("TextButton")
		clearBtn.Size               = UDim2.new(0, 18, 0, 18)
		clearBtn.AnchorPoint        = Vector2.new(1, 0.5)
		clearBtn.Position           = UDim2.new(1, -2, 0.5, 0)
		clearBtn.BackgroundTransparency = 1
		clearBtn.Text               = ""
		clearBtn.ZIndex             = cont.ZIndex + 3
		clearBtn.Parent             = inputBg
		local _cxId = _icon("x")
		local _cxImg: ImageLabel
		if _cxId then
			_cxImg = _makeIcon(clearBtn, _cxId, 10, T.TEXT_DIM)
			_cxImg.AnchorPoint = Vector2.new(0.5, 0.5)
			_cxImg.Position    = UDim2.new(0.5, 0, 0.5, 0)
			_cxImg.ZIndex      = clearBtn.ZIndex + 1
		else
			clearBtn.Text       = "✕"
			clearBtn.Font       = Enum.Font.GothamBold
			clearBtn.TextScaled = true
			clearBtn.TextColor3 = T.TEXT_DIM
			local csc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", clearBtn)
			csc.MinTextSize = 7
			csc.MaxTextSize = 10
		end

		local tb: TextBox = Instance.new("TextBox")
		tb.Size               = UDim2.new(1, -24, 1, -4)
		tb.Position           = UDim2.new(0, 6, 0, 2)
		tb.BackgroundTransparency = 1
		tb.Text               = currentVal
		tb.PlaceholderText    = placeholder or "Type here..."
		tb.PlaceholderColor3  = T.TEXT_DIM
		tb.Font               = Enum.Font.Gotham
		tb.TextScaled         = true
		tb.TextColor3         = T.TEXT
		tb.ClearTextOnFocus   = false
		tb.TextXAlignment     = Enum.TextXAlignment.Left
		tb.ZIndex             = cont.ZIndex + 2
		tb.Parent             = inputBg
		local tbsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", tb)
		tbsc.MinTextSize = 8
		tbsc.MaxTextSize = 11

		tb.Focused:Connect(function()
			twFast(inputBg, { BackgroundColor3 = T.SURFACE2 })
			local s = inputBg:FindFirstChildOfClass("UIStroke")
			if s then s.Color = T.ACCENT end
		end)
		tb.FocusLost:Connect(function()
			twFast(inputBg, { BackgroundColor3 = T.BG })
			local s = inputBg:FindFirstChildOfClass("UIStroke")
			if s then s.Color = T.BORDER end
			currentVal = tb.Text
			if callback then pcall(callback, currentVal) end
		end)

		clearBtn.MouseButton1Click:Connect(function()
			tb.Text    = ""
			currentVal = ""
			if callback then pcall(callback, "") end
		end)
		clearBtn.MouseEnter:Connect(function()
			if _cxImg then twFast(_cxImg, { ImageColor3 = T.ACCENT }) else clearBtn.TextColor3 = T.ACCENT end
		end)
		clearBtn.MouseLeave:Connect(function()
			if _cxImg then twFast(_cxImg, { ImageColor3 = T.TEXT_DIM }) else clearBtn.TextColor3 = T.TEXT_DIM end
		end)

		updateCanvas()
		local TB = {}
		function TB:Get(): string return currentVal end
		function TB:Set(v: string) currentVal = v; tb.Text = v end
		return TB
	end

	function Win:Keybind(labelText: string, default: Enum.KeyCode?, callback: (Enum.KeyCode?) -> (), icon: string?)
		local boundKey: Enum.KeyCode? = default
		local listening: boolean      = false
		local conn: RBXScriptConnection?

		local cont: Frame = Instance.new("Frame")
		cont.Size             = UDim2.new(1, 0, 0, 34)
		cont.BackgroundColor3 = T.SURFACE
		cont.LayoutOrder      = nxt()
		cont.Parent           = scroll
		_style(cont)

		local textOffsetL = 10
		local iconId = _icon(icon)
		if iconId then
			local ico = _makeIcon(cont, iconId, 14, T.TEXT_DIM)
			ico.Position = UDim2.new(0, 8, 0.5, -7)
			ico.ZIndex   = cont.ZIndex + 1
			textOffsetL  = 28
		end

		local lblFrame: Frame = Instance.new("Frame")
		lblFrame.Size                  = UDim2.new(1, -(textOffsetL + 78), 1, -6)
		lblFrame.Position              = UDim2.new(0, textOffsetL, 0, 3)
		lblFrame.BackgroundTransparency = 1
		lblFrame.ZIndex                = cont.ZIndex + 1
		lblFrame.Parent                = cont

		local lbl: TextLabel = Instance.new("TextLabel")
		lbl.Size                  = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                  = labelText or "Keybind"
		lbl.Font                  = Enum.Font.GothamBold
		lbl.TextScaled            = true
		lbl.TextColor3            = T.TEXT
		lbl.TextXAlignment        = Enum.TextXAlignment.Left
		lbl.ZIndex                = cont.ZIndex + 1
		lbl.Parent                = lblFrame
		local ksc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
		ksc.MinTextSize = 8
		ksc.MaxTextSize = 12

		local keyBtn: TextButton = Instance.new("TextButton")
		keyBtn.Size               = UDim2.new(0, 44, 0, 22)
		keyBtn.AnchorPoint        = Vector2.new(1, 0.5)
		keyBtn.Position           = UDim2.new(1, -30, 0.5, 0)
		keyBtn.BackgroundColor3   = T.SURFACE2
		keyBtn.Text               = boundKey and boundKey.Name or "NONE"
		keyBtn.Font               = Enum.Font.GothamBold
		keyBtn.TextScaled         = true
		keyBtn.TextColor3         = T.ACCENT
		keyBtn.ZIndex             = cont.ZIndex + 2
		keyBtn.Parent             = cont
		_corner(keyBtn, 4)
		_stroke(keyBtn, T.BORDER, 1)
		local kbsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", keyBtn)
		kbsc.MinTextSize = 7
		kbsc.MaxTextSize = 10

		local clrBtn: TextButton = Instance.new("TextButton")
		clrBtn.Size               = UDim2.new(0, 22, 0, 22)
		clrBtn.AnchorPoint        = Vector2.new(1, 0.5)
		clrBtn.Position           = UDim2.new(1, -4, 0.5, 0)
		clrBtn.BackgroundColor3   = T.SURFACE2
		clrBtn.Text               = ""
		clrBtn.ZIndex             = cont.ZIndex + 2
		clrBtn.Parent             = cont
		_corner(clrBtn, 4)
		_stroke(clrBtn, T.BORDER, 1)
		local _kxId = _icon("x")
		local _kxImg: ImageLabel
		if _kxId then
			_kxImg = _makeIcon(clrBtn, _kxId, 11, T.TEXT_DIM)
			_kxImg.AnchorPoint = Vector2.new(0.5, 0.5)
			_kxImg.Position    = UDim2.new(0.5, 0, 0.5, 0)
			_kxImg.ZIndex      = clrBtn.ZIndex + 1
		else
			clrBtn.Text       = "✕"
			clrBtn.Font       = Enum.Font.GothamBold
			clrBtn.TextScaled = true
			clrBtn.TextColor3 = T.TEXT_DIM
			local csc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", clrBtn)
			csc2.MinTextSize = 7
			csc2.MaxTextSize = 10
		end

		local function stopListening()
			listening       = false
			keyBtn.Text     = boundKey and boundKey.Name or "NONE"
			keyBtn.TextColor3 = T.ACCENT
			local s = keyBtn:FindFirstChildOfClass("UIStroke")
			if s then s.Color = T.BORDER end
			if conn then conn:Disconnect(); conn = nil end
		end

		keyBtn.MouseButton1Click:Connect(function()
			if listening then stopListening(); return end
			listening       = true
			keyBtn.Text     = "..."
			keyBtn.TextColor3 = T.TEXT_DIM
			local s = keyBtn:FindFirstChildOfClass("UIStroke")
			if s then s.Color = T.ACCENT end

			conn = UIS.InputBegan:Connect(function(input: InputObject, gpe: boolean)
				if gpe then return end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					boundKey = input.KeyCode
					if callback then pcall(callback, boundKey) end
					stopListening()
				end
			end)
		end)

		clrBtn.MouseButton1Click:Connect(function()
			boundKey = nil
			stopListening()
			if callback then pcall(callback, nil) end
		end)

		keyBtn.MouseEnter:Connect(function() twFast(keyBtn, { BackgroundColor3 = T.BORDER }) end)
		keyBtn.MouseLeave:Connect(function() twFast(keyBtn, { BackgroundColor3 = T.SURFACE2 }) end)
		clrBtn.MouseEnter:Connect(function()
			twFast(clrBtn, { BackgroundColor3 = T.ACCENT })
			if _kxImg then twFast(_kxImg, { ImageColor3 = T.TEXT }) else clrBtn.TextColor3 = T.TEXT end
		end)
		clrBtn.MouseLeave:Connect(function()
			twFast(clrBtn, { BackgroundColor3 = T.SURFACE2 })
			if _kxImg then twFast(_kxImg, { ImageColor3 = T.TEXT_DIM }) else clrBtn.TextColor3 = T.TEXT_DIM end
		end)

		updateCanvas()
		local K = {}
		function K:Get(): Enum.KeyCode? return boundKey end
		function K:Set(v: Enum.KeyCode?) boundKey = v; keyBtn.Text = v and v.Name or "NONE" end
		return K
	end

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

		-- "holder" is the clipped, animated shell around the folder body. It has NO
		-- layout of its own, so the accent bar can sit here without being treated as
		-- a list item. (The bar used to live inside the list layout: as soon as the
		-- folder opened it took a full-height row and pushed every button, slider,
		-- toggle, etc. out of view.)
		local holder: Frame = Instance.new("Frame")
		holder.Size                   = UDim2.new(1, 0, 0, 0)
		holder.BackgroundColor3       = T.BG
		holder.BackgroundTransparency = 0.4
		holder.ClipsDescendants       = true
		holder.LayoutOrder            = nxt()
		holder.Parent                 = scroll
		_corner(holder, 5)

		local fBar: Frame = Instance.new("Frame")
		fBar.Size             = UDim2.new(0, 2, 1, -8)
		fBar.Position         = UDim2.new(0, 0, 0, 4)
		fBar.BackgroundColor3 = T.ACCENT
		fBar.BorderSizePixel  = 0
		fBar.Visible          = false
		fBar.Parent           = holder
		_corner(fBar, 1)

		-- "content" holds the folder's elements and is the only thing with the list layout
		local content: Frame = Instance.new("Frame")
		content.Size                   = UDim2.new(1, 0, 1, 0)
		content.BackgroundTransparency = 1
		content.BorderSizePixel        = 0
		content.Parent                 = holder

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

		local folderOpen = false
		local folderTween: Tween? = nil
		local targetH = 0
		local dropClosers: {() -> ()} = {}  -- every Dropdown in this folder adds a "close me" function here

		-- height needed to show the whole list: content + top/bottom padding (3 + 3)
		local function openHeight(): number
			return cLayout.AbsoluteContentSize.Y + 6
		end

		local function setFolderHeight(h: number, animate: boolean)
			targetH = h
			if folderTween then folderTween:Cancel(); folderTween = nil end
			local goal = UDim2.new(1, 0, 0, h)
			if animate then
				folderTween = TweenService:Create(holder,
					TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{ Size = goal })
				folderTween:Play()
			else
				holder.Size = goal
			end
		end

		-- While open, the folder follows its content (a dropdown unfolding, elements
		-- added later, ...) so nothing is ever clipped. Width-only changes are ignored.
		cLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if folderOpen and openHeight() ~= targetH then
				setFolderHeight(openHeight(), false)
			end
		end)

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
			if folderOpen then
				setFolderHeight(openHeight(), true)
			else
				for _, collapse in ipairs(dropClosers) do collapse() end  -- reset open dropdowns
				setFolderHeight(0, true)
			end
			task.delay(0.25, updateCanvas)
		end)

		local Folder = {}
		local _fOrder = 0
		local function fnxt() _fOrder += 1; return _fOrder end

		local function _fStyle(obj: GuiObject) _corner(obj, 5); _stroke(obj) end

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

		function Folder:Label(text: string)
			local lbl: TextLabel = Instance.new("TextLabel")
			lbl.Size                  = UDim2.new(1, 0, 0, 20)
			lbl.BackgroundTransparency = 1
			lbl.Text                  = text or "Label"
			lbl.Font                  = Enum.Font.GothamMedium
			lbl.TextScaled            = true
			lbl.TextColor3            = T.TEXT_DIM
			lbl.TextXAlignment        = Enum.TextXAlignment.Center
			lbl.LayoutOrder           = fnxt()
			lbl.Parent                = content
			local sc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
			sc.MaxTextSize = 11
			updateCanvas()
			local L2 = {}
			function L2:Set(v: string) lbl.Text = v or "" end
			return L2
		end

		function Folder:Section(text: string)
			local sec: Frame = Instance.new("Frame")
			sec.Size                   = UDim2.new(1, 0, 0, 22)
			sec.BackgroundColor3       = T.SURFACE2
			sec.BackgroundTransparency = 0
			sec.LayoutOrder            = fnxt()
			sec.Parent                 = content
			_corner(sec, 5)

			local accentBar: Frame = Instance.new("Frame")
			accentBar.Size             = UDim2.new(0, 3, 0.7, 0)
			accentBar.Position         = UDim2.new(0, 0, 0.15, 0)
			accentBar.BackgroundColor3 = T.ACCENT
			accentBar.BorderSizePixel  = 0
			accentBar.Parent           = sec
			_corner(accentBar, 2)

			local sLbl: TextLabel = Instance.new("TextLabel")
			sLbl.Size                  = UDim2.new(1, -16, 1, 0)
			sLbl.Position              = UDim2.new(0, 10, 0, 0)
			sLbl.BackgroundTransparency = 1
			sLbl.Text                  = string.upper(text or "")
			sLbl.TextColor3            = T.ACCENT
			sLbl.Font                  = Enum.Font.GothamBlack
			sLbl.TextScaled            = true
			sLbl.TextXAlignment        = Enum.TextXAlignment.Left
			sLbl.Parent                = sec
			local sc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", sLbl)
			sc2.MinTextSize = 6
			sc2.MaxTextSize = 9
			updateCanvas()
		end

		function Folder:TextBox(labelText: string, default: string, placeholder: string, callback: (string) -> (), icon: string?)
			local currentVal: string = default or ""

			local cont2: Frame = Instance.new("Frame")
			cont2.Size             = UDim2.new(1, 0, 0, 50)
			cont2.BackgroundColor3 = T.SURFACE
			cont2.LayoutOrder      = fnxt()
			cont2.Parent           = content
			_fStyle(cont2)

			local tOffL = 8
			local iconId2 = _icon(icon)
			if iconId2 then
				local ico = _makeIcon(cont2, iconId2, 12, T.ACCENT)
				ico.Position = UDim2.new(0, 6, 0, 6)
				ico.ZIndex   = cont2.ZIndex + 1
				tOffL        = 22
			end

			local headerLbl2: TextLabel = Instance.new("TextLabel")
			headerLbl2.Size               = UDim2.new(1, -(tOffL + 8), 0, 14)
			headerLbl2.Position           = UDim2.new(0, tOffL, 0, 4)
			headerLbl2.BackgroundTransparency = 1
			headerLbl2.Text               = labelText or "Input"
			headerLbl2.Font               = Enum.Font.GothamBold
			headerLbl2.TextScaled         = true
			headerLbl2.TextColor3         = T.TEXT
			headerLbl2.TextXAlignment     = Enum.TextXAlignment.Left
			headerLbl2.ZIndex             = cont2.ZIndex + 1
			headerLbl2.Parent             = cont2
			local htsc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", headerLbl2)
			htsc2.MinTextSize = 7
			htsc2.MaxTextSize = 11

			local inputBg2: Frame = Instance.new("Frame")
			inputBg2.Size             = UDim2.new(1, -14, 0, 20)
			inputBg2.Position         = UDim2.new(0, 7, 0, 24)
			inputBg2.BackgroundColor3 = T.BG
			inputBg2.ZIndex           = cont2.ZIndex + 1
			inputBg2.Parent           = cont2
			_corner(inputBg2, 4)
			_stroke(inputBg2, T.BORDER, 1)

			local clearBtn2: TextButton = Instance.new("TextButton")
			clearBtn2.Size               = UDim2.new(0, 16, 0, 16)
			clearBtn2.AnchorPoint        = Vector2.new(1, 0.5)
			clearBtn2.Position           = UDim2.new(1, -2, 0.5, 0)
			clearBtn2.BackgroundTransparency = 1
			clearBtn2.Text               = ""
			clearBtn2.ZIndex             = cont2.ZIndex + 3
			clearBtn2.Parent             = inputBg2
			local _cxId2 = _icon("x")
			local _cxImg2: ImageLabel
			if _cxId2 then
				_cxImg2 = _makeIcon(clearBtn2, _cxId2, 9, T.TEXT_DIM)
				_cxImg2.AnchorPoint = Vector2.new(0.5, 0.5)
				_cxImg2.Position    = UDim2.new(0.5, 0, 0.5, 0)
				_cxImg2.ZIndex      = clearBtn2.ZIndex + 1
			else
				clearBtn2.Text       = "✕"
				clearBtn2.Font       = Enum.Font.GothamBold
				clearBtn2.TextScaled = true
				clearBtn2.TextColor3 = T.TEXT_DIM
			end

			local tb2: TextBox = Instance.new("TextBox")
			tb2.Size               = UDim2.new(1, -22, 1, -4)
			tb2.Position           = UDim2.new(0, 5, 0, 2)
			tb2.BackgroundTransparency = 1
			tb2.Text               = currentVal
			tb2.PlaceholderText    = placeholder or "Type here..."
			tb2.PlaceholderColor3  = T.TEXT_DIM
			tb2.Font               = Enum.Font.Gotham
			tb2.TextScaled         = true
			tb2.TextColor3         = T.TEXT
			tb2.ClearTextOnFocus   = false
			tb2.TextXAlignment     = Enum.TextXAlignment.Left
			tb2.ZIndex             = cont2.ZIndex + 2
			tb2.Parent             = inputBg2
			local tbsc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", tb2)
			tbsc2.MinTextSize = 7
			tbsc2.MaxTextSize = 10

			tb2.Focused:Connect(function()
				twFast(inputBg2, { BackgroundColor3 = T.SURFACE2 })
				local s = inputBg2:FindFirstChildOfClass("UIStroke")
				if s then s.Color = T.ACCENT end
			end)
			tb2.FocusLost:Connect(function()
				twFast(inputBg2, { BackgroundColor3 = T.BG })
				local s = inputBg2:FindFirstChildOfClass("UIStroke")
				if s then s.Color = T.BORDER end
				currentVal = tb2.Text
				if callback then pcall(callback, currentVal) end
			end)
			clearBtn2.MouseButton1Click:Connect(function()
				tb2.Text = ""; currentVal = ""
				if callback then pcall(callback, "") end
			end)
			clearBtn2.MouseEnter:Connect(function()
				if _cxImg2 then twFast(_cxImg2, { ImageColor3 = T.ACCENT }) else clearBtn2.TextColor3 = T.ACCENT end
			end)
			clearBtn2.MouseLeave:Connect(function()
				if _cxImg2 then twFast(_cxImg2, { ImageColor3 = T.TEXT_DIM }) else clearBtn2.TextColor3 = T.TEXT_DIM end
			end)

			updateCanvas()
			local TB2 = {}
			function TB2:Get(): string return currentVal end
			function TB2:Set(v: string) currentVal = v; tb2.Text = v end
			return TB2
		end

		function Folder:Keybind(labelText: string, default: Enum.KeyCode?, callback: (Enum.KeyCode?) -> (), icon: string?)
			local boundKey: Enum.KeyCode? = default
			local listening: boolean      = false
			local conn2: RBXScriptConnection?

			local cont2: Frame = Instance.new("Frame")
			cont2.Size             = UDim2.new(1, 0, 0, 32)
			cont2.BackgroundColor3 = T.SURFACE
			cont2.LayoutOrder      = fnxt()
			cont2.Parent           = content
			_fStyle(cont2)

			local tOffL = 8
			local iconId2 = _icon(icon)
			if iconId2 then
				local ico = _makeIcon(cont2, iconId2, 12, T.TEXT_DIM)
				ico.Position = UDim2.new(0, 6, 0.5, -6)
				ico.ZIndex   = cont2.ZIndex + 1
				tOffL        = 22
			end

			local lblF2: Frame = Instance.new("Frame")
			lblF2.Size                  = UDim2.new(1, -(tOffL + 74), 1, -6)
			lblF2.Position              = UDim2.new(0, tOffL, 0, 3)
			lblF2.BackgroundTransparency = 1
			lblF2.ZIndex                = cont2.ZIndex + 1
			lblF2.Parent                = cont2

			local lbl2: TextLabel = Instance.new("TextLabel")
			lbl2.Size                  = UDim2.new(1, 0, 1, 0)
			lbl2.BackgroundTransparency = 1
			lbl2.Text                  = labelText or "Keybind"
			lbl2.Font                  = Enum.Font.GothamBold
			lbl2.TextScaled            = true
			lbl2.TextColor3            = T.TEXT
			lbl2.TextXAlignment        = Enum.TextXAlignment.Left
			lbl2.ZIndex                = cont2.ZIndex + 1
			lbl2.Parent                = lblF2
			local ksc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl2)
			ksc2.MinTextSize = 7
			ksc2.MaxTextSize = 11

			local keyBtn2: TextButton = Instance.new("TextButton")
			keyBtn2.Size               = UDim2.new(0, 40, 0, 20)
			keyBtn2.AnchorPoint        = Vector2.new(1, 0.5)
			keyBtn2.Position           = UDim2.new(1, -28, 0.5, 0)
			keyBtn2.BackgroundColor3   = T.SURFACE2
			keyBtn2.Text               = boundKey and boundKey.Name or "NONE"
			keyBtn2.Font               = Enum.Font.GothamBold
			keyBtn2.TextScaled         = true
			keyBtn2.TextColor3         = T.ACCENT
			keyBtn2.ZIndex             = cont2.ZIndex + 2
			keyBtn2.Parent             = cont2
			_corner(keyBtn2, 4)
			_stroke(keyBtn2, T.BORDER, 1)
			local kbsc2: UITextSizeConstraint = Instance.new("UITextSizeConstraint", keyBtn2)
			kbsc2.MinTextSize = 6
			kbsc2.MaxTextSize = 9

			local clrBtn2: TextButton = Instance.new("TextButton")
			clrBtn2.Size               = UDim2.new(0, 20, 0, 20)
			clrBtn2.AnchorPoint        = Vector2.new(1, 0.5)
			clrBtn2.Position           = UDim2.new(1, -4, 0.5, 0)
			clrBtn2.BackgroundColor3   = T.SURFACE2
			clrBtn2.Text               = ""
			clrBtn2.ZIndex             = cont2.ZIndex + 2
			clrBtn2.Parent             = cont2
			_corner(clrBtn2, 4)
			_stroke(clrBtn2, T.BORDER, 1)
			local _kxId2 = _icon("x")
			local _kxImg2: ImageLabel
			if _kxId2 then
				_kxImg2 = _makeIcon(clrBtn2, _kxId2, 10, T.TEXT_DIM)
				_kxImg2.AnchorPoint = Vector2.new(0.5, 0.5)
				_kxImg2.Position    = UDim2.new(0.5, 0, 0.5, 0)
				_kxImg2.ZIndex      = clrBtn2.ZIndex + 1
			else
				clrBtn2.Text       = "✕"
				clrBtn2.Font       = Enum.Font.GothamBold
				clrBtn2.TextScaled = true
				clrBtn2.TextColor3 = T.TEXT_DIM
			end

			local function stopListening2()
				listening       = false
				keyBtn2.Text    = boundKey and boundKey.Name or "NONE"
				keyBtn2.TextColor3 = T.ACCENT
				local s = keyBtn2:FindFirstChildOfClass("UIStroke")
				if s then s.Color = T.BORDER end
				if conn2 then conn2:Disconnect(); conn2 = nil end
			end

			keyBtn2.MouseButton1Click:Connect(function()
				if listening then stopListening2(); return end
				listening = true
				keyBtn2.Text = "..."
				keyBtn2.TextColor3 = T.TEXT_DIM
				local s = keyBtn2:FindFirstChildOfClass("UIStroke")
				if s then s.Color = T.ACCENT end
				conn2 = UIS.InputBegan:Connect(function(input: InputObject, gpe: boolean)
					if gpe then return end
					if input.UserInputType == Enum.UserInputType.Keyboard then
						boundKey = input.KeyCode
						if callback then pcall(callback, boundKey) end
						stopListening2()
					end
				end)
			end)
			clrBtn2.MouseButton1Click:Connect(function()
				boundKey = nil; stopListening2()
				if callback then pcall(callback, nil) end
			end)
			keyBtn2.MouseEnter:Connect(function() twFast(keyBtn2, { BackgroundColor3 = T.BORDER }) end)
			keyBtn2.MouseLeave:Connect(function() twFast(keyBtn2, { BackgroundColor3 = T.SURFACE2 }) end)
			clrBtn2.MouseEnter:Connect(function()
				twFast(clrBtn2, { BackgroundColor3 = T.ACCENT })
				if _kxImg2 then twFast(_kxImg2, { ImageColor3 = T.TEXT }) else clrBtn2.TextColor3 = T.TEXT end
			end)
			clrBtn2.MouseLeave:Connect(function()
				twFast(clrBtn2, { BackgroundColor3 = T.SURFACE2 })
				if _kxImg2 then twFast(_kxImg2, { ImageColor3 = T.TEXT_DIM }) else clrBtn2.TextColor3 = T.TEXT_DIM end
			end)

			updateCanvas()
			local K2 = {}
			function K2:Get(): Enum.KeyCode? return boundKey end
			function K2:Set(v: Enum.KeyCode?) boundKey = v; keyBtn2.Text = v and v.Name or "NONE" end
			return K2
		end

		function Folder:Dropdown(headerText: string, options: {string}, callback: any, icon: any, multi: boolean?, maxPick: number?)
			local opts = options or {}
			-- backward compat: a boolean in the icon slot is the multi flag (no icon)
			local iconName = icon
			local isMulti  = multi
			local maxN     = maxPick
			if type(icon) == "boolean" then
				isMulti  = icon
				maxN     = multi :: any
				iconName = nil
			end
			isMulti = isMulti == true
			maxN    = type(maxN) == "number" and maxN or #opts

			local selected: string = "Select..."
			local selectedSet: {[string]: boolean} = {}
			local selectedList: {string} = {}
			local open = false

			local function buildLabel(): string
				if not isMulti then return selected end
				if #selectedList == 0 then return "Select..." end
				if #selectedList <= 2 then return table.concat(selectedList, ", ") end
				return selectedList[1] .. ", +" .. (#selectedList - 1)
			end

			local dropBtn: TextButton = Instance.new("TextButton")
			dropBtn.Name             = "DropButton"
			dropBtn.Size             = UDim2.new(1, 0, 0, 40)
			dropBtn.BackgroundColor3 = T.SURFACE
			dropBtn.Text             = ""
			dropBtn.LayoutOrder      = fnxt()
			dropBtn.Parent           = content
			_fStyle(dropBtn)

			local tOffL = 8
			local fdid  = _icon(iconName)
			if fdid then
				local ico = _makeIcon(dropBtn, fdid, 12, T.ACCENT)
				ico.Position = UDim2.new(0, 6, 0.5, -6)
				ico.ZIndex   = dropBtn.ZIndex + 1
				tOffL        = 22
			end

			-- multi badge: shows "2/3" (top right, left of the arrow)
			local badgeLbl: TextLabel?
			if isMulti then
				local badge: TextLabel = Instance.new("TextLabel")
				badge.Name               = "DropBadge"
				badge.Size               = UDim2.new(0, 26, 0, 12)
				badge.AnchorPoint        = Vector2.new(1, 0)
				badge.Position           = UDim2.new(1, -22, 0, 3)
				badge.BackgroundColor3   = T.ACCENT_DIM
				badge.Text               = "0/" .. maxN
				badge.Font               = Enum.Font.GothamBold
				badge.TextScaled         = true
				badge.TextColor3         = T.ACCENT
				badge.TextXAlignment     = Enum.TextXAlignment.Center
				badge.ZIndex             = dropBtn.ZIndex + 2
				badge.Parent             = dropBtn
				_corner(badge, 4)
				local fbsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", badge)
				fbsc.MinTextSize = 6
				fbsc.MaxTextSize = 9
				badgeLbl = badge
			end

			local headLbl: TextLabel = Instance.new("TextLabel")
			headLbl.Size               = UDim2.new(1, -(tOffL + (isMulti and 52 or 20)), 0, 12)
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
			selLbl.Name               = "DropValue"
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

			local _fChevDownId = _icon("chevron-down")
			local _fChevUpId   = _icon("chevron-up")
			local fArrowImg: ImageLabel?
			local arrowLbl: TextLabel?

			if _fChevDownId then
				local img: ImageLabel = Instance.new("ImageLabel")
				img.Size                  = UDim2.new(0, 12, 0, 12)
				img.AnchorPoint           = Vector2.new(1, 0.5)
				img.Position              = UDim2.new(1, -5, 0.5, 0)
				img.BackgroundTransparency = 1
				img.Image                 = _fChevDownId
				img.ImageColor3           = T.ACCENT
				img.ScaleType             = Enum.ScaleType.Fit
				img.ZIndex                = dropBtn.ZIndex + 1
				img.Parent                = dropBtn
				fArrowImg = img
			else
				local lbl: TextLabel = Instance.new("TextLabel")
				lbl.Size               = UDim2.new(0, 16, 1, 0)
				lbl.AnchorPoint        = Vector2.new(1, 0.5)
				lbl.Position           = UDim2.new(1, -4, 0.5, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text               = "▾"
				lbl.TextColor3         = T.ACCENT
				lbl.Font               = Enum.Font.GothamBold
				lbl.TextScaled         = true
				lbl.ZIndex             = dropBtn.ZIndex + 1
				lbl.Parent             = dropBtn
				local fadsc: UITextSizeConstraint = Instance.new("UITextSizeConstraint", lbl)
				fadsc.MaxTextSize = 14
				arrowLbl = lbl
			end

			local function setFArrow(isOpen: boolean)
				if fArrowImg then
					fArrowImg.Image = isOpen and (_fChevUpId or _fChevDownId) or _fChevDownId
				elseif arrowLbl then
					arrowLbl.Text = isOpen and "▴" or "▾"
				end
			end

			local dropFrame: Frame = Instance.new("Frame")
			dropFrame.Name             = "DropList"
			dropFrame.Size             = UDim2.new(1, 0, 0, 0)
			dropFrame.BackgroundColor3 = T.SURFACE2
			dropFrame.ClipsDescendants = true
			dropFrame.LayoutOrder      = fnxt()
			dropFrame.Parent           = content
			_corner(dropFrame, 5)
			_stroke(dropFrame)

			local dfL = Instance.new("UIListLayout", dropFrame); dfL.SortOrder = Enum.SortOrder.LayoutOrder
			local dfP = Instance.new("UIPadding", dropFrame); dfP.PaddingTop = UDim.new(0,2); dfP.PaddingBottom = UDim.new(0,2)

			local optFrames: {[string]: TextButton} = {}

			for _, v in ipairs(opts) do
				local opt: TextButton = Instance.new("TextButton")
				opt.Name             = "DropOption"
				opt.Size             = UDim2.new(1, 0, 0, 26)
				opt.BackgroundColor3 = T.SURFACE2
				opt.Text             = ""
				opt.Parent           = dropFrame
				optFrames[v]         = opt

				local optLbl: TextLabel = Instance.new("TextLabel")
				optLbl.Size               = UDim2.new(1, isMulti and -26 or -14, 1, -4)
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

				-- multi: check box on the right
				local checkDot: Frame?
				if isMulti then
					local dot: Frame = Instance.new("Frame")
					dot.Name             = "DropDot"
					dot.Size             = UDim2.new(0, 10, 0, 10)
					dot.AnchorPoint      = Vector2.new(1, 0.5)
					dot.Position         = UDim2.new(1, -8, 0.5, 0)
					dot.BackgroundColor3 = T.BORDER
					dot.ZIndex           = opt.ZIndex + 2
					dot.Parent           = opt
					_corner(dot, 3)
					checkDot = dot
				end

				local function refreshOpt()
					if not isMulti then return end
					local on = selectedSet[v] == true
					twFast(opt, { BackgroundColor3 = on and T.SURFACE or T.SURFACE2 })
					if checkDot then
						twFast(checkDot, { BackgroundColor3 = on and T.ACCENT or T.BORDER })
					end
					optLbl.TextColor3 = on and T.TEXT or T.TEXT_DIM
				end

				opt.MouseEnter:Connect(function()
					if not (selectedSet[v] and isMulti) then
						twFast(opt, { BackgroundColor3 = T.BORDER })
					end
				end)
				opt.MouseLeave:Connect(function()
					if isMulti then refreshOpt()
					else twFast(opt, { BackgroundColor3 = T.SURFACE2 }) end
				end)

				opt.MouseButton1Click:Connect(function()
					if not isMulti then
						selected = v; selLbl.Text = v; open = false; setFArrow(false)
						twMed(dropFrame, { Size = UDim2.new(1, 0, 0, 0) })
						task.wait(0.23); updateCanvas()
						if callback then pcall(callback, v) end
					else
						if selectedSet[v] then
							selectedSet[v] = nil
							for i, sv in ipairs(selectedList) do
								if sv == v then table.remove(selectedList, i); break end
							end
						else
							if #selectedList >= maxN then
								-- limit reached: flash the badge red for a moment
								if badgeLbl then
									twFast(badgeLbl, { TextColor3 = Color3.fromRGB(255, 80, 80) })
									task.delay(0.4, function()
										twFast(badgeLbl, { TextColor3 = T.ACCENT })
									end)
								end
								return
							end
							selectedSet[v] = true
							table.insert(selectedList, v)
						end
						refreshOpt()
						selLbl.Text = buildLabel()
						if badgeLbl then badgeLbl.Text = #selectedList .. "/" .. maxN end
						if callback then pcall(callback, selectedList) end
					end
				end)
			end

			dropBtn.MouseEnter:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE2 }) end)
			dropBtn.MouseLeave:Connect(function()   twFast(dropBtn, { BackgroundColor3 = T.SURFACE })  end)
			dropBtn.MouseButton1Click:Connect(function()
				open = not open; setFArrow(open)
				local h = open and (#opts * 26 + 4) or 0
				twMed(dropFrame, { Size = UDim2.new(1, 0, 0, h) })
				task.delay(0.24, updateCanvas)
			end)

			-- when the folder closes, put this dropdown back to its closed state too
			table.insert(dropClosers, function()
				if not open then return end
				open = false; setFArrow(false)
				twMed(dropFrame, { Size = UDim2.new(1, 0, 0, 0) })
			end)

			updateCanvas()
			local D = {}
			-- single: the picked string, multi: the list of picked strings
			function D:Get() return isMulti and selectedList or selected end

			-- bring every row in line with selectedSet
			local function paintRows()
				for item, frame in pairs(optFrames) do
					local on = selectedSet[item] == true
					frame.BackgroundColor3 = on and T.SURFACE or T.SURFACE2
					local dot = frame:FindFirstChildOfClass("Frame")
					if dot then dot.BackgroundColor3 = on and T.ACCENT or T.BORDER end
					local lbl = frame:FindFirstChildOfClass("TextLabel")
					if lbl then lbl.TextColor3 = on and T.TEXT or T.TEXT_DIM end
				end
			end

			-- single: pass a string, multi: pass a list of strings
			function D:Set(v: any)
				if not isMulti then
					selected = v; selLbl.Text = v
				else
					selectedSet = {}; selectedList = {}
					for _, item in ipairs(v) do
						selectedSet[item] = true
						table.insert(selectedList, item)
					end
					selLbl.Text = buildLabel()
					if badgeLbl then badgeLbl.Text = #selectedList .. "/" .. maxN end
					paintRows()
				end
			end

			function D:Clear()
				if isMulti then
					selectedSet = {}; selectedList = {}
					selLbl.Text = "Select..."
					if badgeLbl then badgeLbl.Text = "0/" .. maxN end
					paintRows()
				else
					selected = "Select..."; selLbl.Text = selected
				end
			end
			return D
		end

		-- same list as the window's, sized for a folder; it folds up when the folder closes
		function Folder:ConfigList(headerText: string, items: {string}?, handlers: any, icon: string?)
			local L = _buildConfigList(content, fnxt, _LIST_DIMS.folder, headerText, icon, items, handlers, updateCanvas)
			table.insert(dropClosers, function() L:Close() end)
			updateCanvas()
			return L
		end

		return Folder
	end

	updateCanvas()
	return Win
end

-- ============================================================
-- CONFIG STORE  (file layer behind the config list)
-- ============================================================
-- #region store
-- Plain Lua on purpose (no type annotations) so it can be tested outside Roblox.
-- `fs` holds the executor's file functions; any of them may be nil.

-- letters, numbers, space, _ and -, trimmed, at most 32 characters
local function _cleanConfigName(raw)
	local n = tostring(raw or "")
	n = n:gsub("%.json$", "")
	n = n:gsub("[^%w _%-]", "")
	n = n:gsub("^%s+", "")
	n = n:sub(1, 32)
	n = n:gsub("%s+$", "")
	return n
end

local function _newConfigStore(folder, fs)
	fs = fs or {}
	local store = {}
	local known = {}  -- configs saved this session; the list falls back to these without listfiles

	-- names of the saved configs, sorted A-Z (no .json)
	function store.list()
		local names = {}
		if not fs.listfiles then
			for name in pairs(known) do names[#names + 1] = name end
		elseif fs.isfolder and fs.isfolder(folder) then
			local ok, files = pcall(fs.listfiles, folder)
			if ok and type(files) == "table" then
				for _, p in ipairs(files) do
					local base = tostring(p):match("([^/\\]+)$")
					if base and base:lower():sub(-5) == ".json" then
						names[#names + 1] = base:sub(1, -6)
					end
				end
			end
		end
		table.sort(names, function(a, b)
			local la, lb = a:lower(), b:lower()
			if la == lb then return a < b end
			return la < lb
		end)
		return names
	end

	local function file(name) return folder .. "/" .. name .. ".json" end

	function store.exists(name)
		name = _cleanConfigName(name)
		if name == "" or not fs.isfile then return false end
		local ok, found = pcall(fs.isfile, file(name))
		return ok and found == true
	end

	-- saves text to <folder>/<name>.json. Returns true, cleanedName  or  false, reason
	function store.write(name, text)
		name = _cleanConfigName(name)
		if name == "" then return false, "Enter a name first" end
		if not (fs.writefile and fs.isfolder and fs.makefolder) then
			return false, "Your executor can't save files"
		end
		local ok, err = pcall(function()
			if not fs.isfolder(folder) then fs.makefolder(folder) end
			fs.writefile(file(name), text)
		end)
		if not ok then return false, "Couldn't save: " .. tostring(err) end
		known[name] = true
		return true, name
	end

	-- returns the saved text, or nil, reason
	function store.read(name)
		name = _cleanConfigName(name)
		if not store.exists(name) or not fs.readfile then return nil, "Config not found" end
		local ok, text = pcall(fs.readfile, file(name))
		if not ok then return nil, "Couldn't read: " .. tostring(text) end
		return text
	end

	function store.delete(name)
		name = _cleanConfigName(name)
		if not store.exists(name) then return false, "Config not found" end
		if not fs.delfile then return false, "Your executor can't delete files" end
		local ok, err = pcall(fs.delfile, file(name))
		if not ok then return false, "Couldn't delete: " .. tostring(err) end
		known[name] = nil
		return true
	end

	-- moves old -> new. Returns true, cleanedNewName  or  false, reason
	function store.rename(old, new)
		old, new = _cleanConfigName(old), _cleanConfigName(new)
		if new == "" then return false, "Enter a name first" end
		if not store.exists(old) then return false, "Config not found" end
		if old == new then return true, new end
		-- only the letter case changed: on Windows that is the same file
		local sameFile = old:lower() == new:lower()
		if not sameFile and store.exists(new) then return false, "Name already used" end
		if not fs.delfile then return false, "Your executor can't delete files" end
		local text, err = store.read(old)
		if not text then return false, err end
		if sameFile then
			local ok, derr = store.delete(old)
			if not ok then return false, derr end
			local wok, werr = store.write(new, text)
			if not wok then store.write(old, text); return false, werr end
		else
			local wok, werr = store.write(new, text)
			if not wok then return false, werr end
			local dok, derr = store.delete(old)
			if not dok then store.delete(new); return false, derr end
		end
		return true, new
	end

	return store
end
-- #endregion store

-- ============================================================
-- CONFIG SYSTEM  (Rayfield-style)
--
-- Usage:
--   local Cfg = Lib:CreateConfig("hi", "hi.json")
--   -- Option A: manual register then load
--   Cfg:Register("MyToggle",   toggleRef,   false)
--   Cfg:Register("MyDropdown", dropdownRef, "Option1")
--   Cfg:Register("MySlider",   sliderRef,   50)
--   Cfg:Register("MyKeybind",  keybindRef,  Enum.KeyCode.F)
--   Cfg:Load()   -- call after all Register() calls
--
--   -- Option B: Attach() — registers + wraps callback + auto-saves
--   local myToggle = Win:Toggle("Godmode", false,
--       Cfg:Attach("Godmode", nil, false, function(v) ... end))
--   Cfg:Attach("Godmode", myToggle, false)  -- call after to link ref
--   Cfg:Load()
--
--   -- Option C: one-liner Bind()
--   local myToggle = Win:Toggle("Godmode", false,
--       Cfg:Bind("Godmode", false, function(v) ... end))
--   -- then after: Cfg:Link("Godmode", myToggle)
--   Cfg:Load()
-- ============================================================
function Lib:CreateConfig(folderName: string, fileName: string)
	local CFG_FOLDER = folderName or "455Hub_Configs"
	-- the config that Save() / Load() use (nil once it has been deleted from the list)
	local currentName = _cleanConfigName(fileName or "config.json")
	if currentName == "" then currentName = "config" end
	local store = _newConfigStore(CFG_FOLDER, {
		isfolder = isfolder, makefolder = makefolder, isfile = isfile, readfile = readfile,
		writefile = writefile, listfiles = listfiles, delfile = delfile,
	})

	local _entries: {[string]: {ref: any, default: any}} = {}
	local HttpService = game:GetService("HttpService")

	local function _canUseFiles(): boolean
		return (writefile ~= nil) and (readfile ~= nil)
			and (isfile ~= nil) and (isfolder ~= nil) and (makefolder ~= nil)
	end

	local function _serialize(val: any): any
		local t = typeof(val)
		if t == "boolean" or t == "number" or t == "string" then
			return val
		elseif t == "EnumItem" then
			return { __type = "KeyCode", name = val.Name }
		elseif t == "table" then
			-- multi-dropdown returns {string}
			local out = {}
			for i, v in ipairs(val) do out[i] = v end
			return out
		end
		return nil
	end

	local function _deserialize(raw: any): any
		if type(raw) == "table" and raw.__type == "KeyCode" then
			local ok, kc = pcall(function()
				return (Enum.KeyCode :: any)[raw.name]
			end)
			return ok and kc or nil
		end
		return raw
	end

	-- current value of every registered element, ready for JSON
	local function _collect()
		local data = {}
		for key, entry in pairs(_entries) do
			local ref = entry.ref
			if ref and ref.Get then
				local ok, val = pcall(function() return ref:Get() end)
				if ok then
					local s = _serialize(val)
					if s ~= nil then data[key] = s end
				end
			end
		end
		return data
	end

	local function _encode()
		local ok, text = pcall(function() return HttpService:JSONEncode(_collect()) end)
		if not ok then return nil, "Couldn't turn the settings into a file" end
		return text
	end

	-- put saved values on the elements; anything missing falls back to its default
	local function _apply(data)
		for key, entry in pairs(_entries) do
			local ref = entry.ref
			if ref and ref.Set then
				local saved = data[key]
				if saved ~= nil then
					pcall(function() ref:Set(_deserialize(saved)) end)
				elseif entry.default ~= nil then
					pcall(function() ref:Set(entry.default) end)
				end
			end
		end
	end

	local Config = {}

	-- Register an element ref + default value under key
	function Config:Register(key: string, ref: any, default: any)
		_entries[key] = { ref = ref, default = default }
	end

	-- Link a ref to an already-registered key (use after Bind/callback creation)
	function Config:Link(key: string, ref: any)
		if _entries[key] then
			_entries[key].ref = ref
		else
			_entries[key] = { ref = ref, default = nil }
		end
	end

	-- Save all registered values to the current config (inside CFG_FOLDER)
	function Config:Save()
		if not _canUseFiles() or not currentName then return end
		local text, err = _encode()
		if text then
			local ok, werr = store.write(currentName, text)
			if ok then return end
			err = werr
		end
		warn("[455Hub Config] Save failed:", err)
	end

	-- Load saved values and apply to refs; falls back to defaults
	function Config:Load()
		if not _canUseFiles() or not currentName then
			for _, entry in pairs(_entries) do
				if entry.ref and entry.ref.Set and entry.default ~= nil then
					pcall(function() entry.ref:Set(entry.default) end)
				end
			end
			return
		end

		local data = {}
		local text = store.read(currentName)  -- nil when there is no file yet
		if text then
			local ok, decoded = pcall(function() return HttpService:JSONDecode(text) end)
			if ok and type(decoded) == "table" then
				data = decoded
			else
				warn("[455Hub Config] Load failed:", decoded)
			end
		end
		_apply(data)
	end

	-- Reset all to defaults and delete the saved file
	function Config:Reset()
		for _, entry in pairs(_entries) do
			if entry.ref and entry.ref.Set and entry.default ~= nil then
				pcall(function() entry.ref:Set(entry.default) end)
			end
		end
		if _canUseFiles() and currentName then
			store.delete(currentName)
		end
	end

	-- ---- config list: several named configs in the config folder ----

	-- name of the config Save() / Load() use right now (nil if none)
	function Config:Current() return currentName end

	function Config:SetCurrent(name)
		local n = _cleanConfigName(name)
		currentName = n ~= "" and n or nil
	end

	-- saved config names, A-Z
	function Config:List() return store.list() end

	-- same as List(); call it to pick up files added or removed outside the script
	function Config:Refresh() return store.list() end

	-- save the current values as <name>.json and make it the current config
	function Config:SaveAs(name)
		local text, err = _encode()
		if not text then return false, err end
		local ok, res = store.write(name, text)
		if not ok then return false, res end
		currentName = res
		return true, res
	end

	-- apply <name>.json to the elements and make it the current config
	function Config:LoadFrom(name)
		local text, err = store.read(name)
		if not text then return false, err end
		local ok, data = pcall(function() return HttpService:JSONDecode(text) end)
		if not ok or type(data) ~= "table" then return false, "Config file is damaged" end
		_apply(data)
		currentName = _cleanConfigName(name)
		return true, currentName
	end

	function Config:Rename(old, new)
		local ok, res = store.rename(old, new)
		if not ok then return false, res end
		if currentName and _cleanConfigName(old) == currentName then currentName = res end
		return true, res
	end

	-- deleting the current config stops Save() from writing until you pick another one
	function Config:Delete(name)
		local ok, err = store.delete(name)
		if not ok then return false, err end
		if _cleanConfigName(name) == currentName then currentName = nil end
		return true
	end

	--[[
		CreateManager: the config UI in one call. Adds a name box with "Create config", the config list
		(pencil renames, X deletes, arrows refresh) and "Load selected" / "Save to selected".
		`target` is a window or a folder. Clicking a row only selects it; Load applies it.
		opts (optional): { title = "Configs", icon = "folder", icons = false }. icons = false leaves the
		button and list icons out (for a window that has none). Returns the list.

			local Cfg = Library:CreateConfig("MyHub", "default")
			-- ...create your elements and Cfg:Register / Cfg:Link them...
			Cfg:CreateManager(Window)
	]]
	function Config:CreateManager(target: any, opts: any)
		opts = opts or {}
		local useIcons = opts.icons ~= false
		local function ic(name: string): string?
			return useIcons and name or nil
		end
		local list: any = nil
		local function say(text: string, kind: string)
			if list then list:Status(text, kind) end
		end

		local nameBox = target:TextBox("Config name", "", "Name your config", nil)

		target:Button("Create config", function()
			local ok, res = Config:SaveAs(nameBox:Get())
			if not ok then say(res or "Couldn't save", "error") return end
			nameBox:Set("")
			list:SetItems(Config:List())
			list:Set(res)
			say("Created " .. res, "ok")
		end, ic("plus"))

		list = target:ConfigList(opts.title or "Configs", Config:List(), {
			onSelect  = function() end,   -- picking a row does nothing until Load or Save is pressed
			onRename  = function(old, new) return Config:Rename(old, new) end,
			onDelete  = function(name) return Config:Delete(name) end,
			onRefresh = function() return Config:Refresh() end,
			emptyText = "No configs yet. Name one above and press Create.",
		}, ic(opts.icon or "folder"))
		if Config:Current() then list:Set(Config:Current()) end

		target:Button("Load selected", function()
			local name = list:Get()
			if not name then say("Pick a config first", "error") return end
			local ok, err = Config:LoadFrom(name)
			if ok then say("Loaded " .. name, "ok") else say(err or "Couldn't load", "error") end
		end, ic("download"))

		target:Button("Save to selected", function()
			local name = list:Get()
			if not name then say("Pick a config first", "error") return end
			local ok, err = Config:SaveAs(name)
			if ok then say("Saved " .. name, "ok") else say(err or "Couldn't save", "error") end
		end, ic("save"))

		return list
	end

	--[[
		AutoSave — register ref+default+callback, return wrapped callback
		that auto-saves after every change. Legacy helper.

		local myTgl = Win:Toggle("X", false, Cfg:AutoSave(nil,"X",false, function(v) end))
		Cfg:Link("X", myTgl)
		Cfg:Load()
	]]
	function Config:AutoSave(ref: any, key: string, default: any, callback: any)
		self:Register(key, ref, default)
		return function(val: any)
			if callback then pcall(callback, val) end
			task.defer(function() self:Save() end)
		end
	end

	--[[
		Bind — NEW Rayfield-style helper.
		Returns a callback wrapper that auto-saves; link the ref afterward.

		Example (Toggle):
			local myTgl = Win:Toggle("ESP", false,
			    Cfg:Bind("ESP", false, function(v) espEnabled = v end))
			Cfg:Link("ESP", myTgl)

		Example (Dropdown):
			local myDrop = Win:Dropdown("Team", {"Red","Blue"}, 
			    Cfg:Bind("Team", "Red", function(v) team = v end))
			Cfg:Link("Team", myDrop)

		Then call Cfg:Load() once after all Bind/Link calls.
	]]
	function Config:Bind(key: string, default: any, callback: any)
		-- pre-register with no ref yet; Link() fills it in after element is created
		if not _entries[key] then
			_entries[key] = { ref = nil, default = default }
		else
			_entries[key].default = default
		end
		return function(val: any)
			if callback then pcall(callback, val) end
			task.defer(function() self:Save() end)
		end
	end

	return Config
end

function Lib:Start()
	_loaded = true
	for _, fn in ipairs(_pendingShow) do fn() end
	_pendingShow = {}
	_reposition()
end

return Lib
