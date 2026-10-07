local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Window = Rayfield:CreateWindow({
	name = "Alwi HUb Skid version",
	subtitle = "Auto-Reconnect System",
})

local AutoplayEnabled = true
local HoldLongNotes = true
local LegitMode = false
local KeyMonitor = false

local Connections = {}
local HeldKeys = {}
local LongHoldKeys = {}
local MatchHooked = false
local HookedFolder = nil
local LastNoteAt = 0

local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

game:GetService("StarterGui")

local SideNames = { "Left", "Right" }
local LaneKeyNames = {
	[9] = { "Left", "Down", "Up", "Right", "Space", "Left2", "Down2", "Up2", "Right2" },
	[8] = { "Left", "Down", "Up", "Right", "Left2", "Down2", "Up2", "Right2" },
	[7] = { "Left", "Up", "Right", "Space", "Left2", "Down", "Right2" },
	[6] = { "Left", "Up", "Right", "Left2", "Down", "Right2" },
	[5] = { "Left", "Down", "Space", "Up", "Right" },
	[4] = { "Left", "Down", "Up", "Right" },
}

local FallbackBinds = {
	[5] = { "D", "F", "Space", "J", "K" },
	[6] = { "S", "D", "F", "J", "K", "L" },
	[7] = { "S", "D", "F", "Space", "J", "K", "L" },
	[8] = { "A", "S", "D", "F", "J", "K", "L", "Semicolon" },
	[9] = { "A", "S", "D", "F", "Space", "J", "K", "L", "Semicolon" },
}

local function ResolveKey(colIndex, maxArrows, laneName, keyOptions)
	if keyOptions then
		local key = keyOptions[laneName .. "Key"]
		if typeof(key) == "EnumItem" then
			return key
		end
	end
	local fallback = FallbackBinds[maxArrows] and FallbackBinds[maxArrows][colIndex]
	if fallback then
		local ok, keyCode = pcall(Enum.KeyCode.FromName, Enum.KeyCode, fallback)
		if ok then
			return keyCode
		end
	end
	return nil
end

local function GetSortedChildren(parent)
	if not parent then
		return {}
	end
	local children = parent:GetChildren()
	table.sort(children, function(a, b)
		return a.AbsolutePosition.X < b.AbsolutePosition.X
	end)
	return children
end

local function FindMatchTable()
	for _, v in ipairs(getgc(true)) do
		if type(v) == "table" and rawget(v, "MatchFolder") ~= nil and rawget(v, "ArrowGui") ~= nil then
			return v
		end
	end
	return nil
end

local function ReleaseAllKeys()
	for key, _ in pairs(HeldKeys) do
		pcall(function()
			VirtualInputManager:SendKeyEvent(false, key, false, nil)
		end)
	end
	table.clear(HeldKeys)
	table.clear(LongHoldKeys)
end

local function DisconnectAll()
	for _, conn in ipairs(Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(Connections)
end

UserInputService.InputBegan:Connect(function(input, _)
	if KeyMonitor and input.UserInputType == Enum.UserInputType.Keyboard then
		print(input.KeyCode.Name)
	end
end)

local function HookMatch()
	local match = FindMatchTable()
	if not match then
		return nil
	end

	local sideName = SideNames[match.PlayerType]
	local sideFolder = sideName and match.ArrowGui:FindFirstChild(sideName)
	if not sideFolder or not sideFolder:FindFirstChild("Notes") then
		return nil
	end

	local Options = getrenv()._G.PlayerData.Options
	local receptors = GetSortedChildren(sideFolder:FindFirstChild("MainArrowContainer"))
	local noteColumns = GetSortedChildren(sideFolder:FindFirstChild("Notes"))
	local longColumns = GetSortedChildren(sideFolder:FindFirstChild("LongNotes"))
	local MaxArrows = match.MaxArrows
	local laneNames = LaneKeyNames[MaxArrows]
	if not laneNames then
		return nil
	end
	local keyOptions = MaxArrows < 5 and Options or Options.ExtraKeySettings[tostring(MaxArrows)]
	local hitThreshold = 15 * MaxArrows

	DisconnectAll()

	for colIndex, column in ipairs(noteColumns) do
		local key = ResolveKey(colIndex, MaxArrows, laneNames[colIndex], keyOptions)
		local receptor = receptors[colIndex]
		if key and receptor then

			local function WatchNote(note)
				if not AutoplayEnabled then
					return
				end
				LastNoteAt = os.clock()
				local connection
				connection = RunService.RenderStepped:Connect(function()
					if not note or not note.Parent or not AutoplayEnabled or match.MatchFolder.Parent == nil then
						connection:Disconnect()
						return
					end

					if (receptor.AbsolutePosition - note.AbsolutePosition).Magnitude <= hitThreshold then
						connection:Disconnect()

						if LegitMode then
							if math.random(1, 100) <= 0 then
								return
							end
							task.wait(math.random(30, 60) / 1000)
						end

						if HeldKeys[key] then
							VirtualInputManager:SendKeyEvent(false, key, false, nil)
							HeldKeys[key] = nil
							RunService.RenderStepped:Wait()
						end

						VirtualInputManager:SendKeyEvent(true, key, false, nil)
						HeldKeys[key] = true
						task.delay(0.02, function()
							if not AutoplayEnabled or not HeldKeys[key] then
								return
							end

							local isLong = false
							if HoldLongNotes and longColumns[colIndex] then
								isLong = #longColumns[colIndex]:GetChildren() > 0
							end

							if not isLong then
								VirtualInputManager:SendKeyEvent(false, key, false, nil)
								HeldKeys[key] = nil
								return
							end

							LongHoldKeys[key] = true
						end)
					end
				end)
			end

			for _, child in ipairs(column:GetChildren()) do
				WatchNote(child)
			end

			table.insert(Connections, column.ChildAdded:Connect(WatchNote))
		end
	end

	for i, longColumn in ipairs(longColumns) do
		local key = ResolveKey(i, MaxArrows, laneNames[i], keyOptions)
		if key then
			table.insert(Connections, longColumn.ChildRemoved:Connect(function()
				if not AutoplayEnabled then
					return
				end
				if HoldLongNotes and HeldKeys[key] and LongHoldKeys[key] then
					RunService.RenderStepped:Wait()
					VirtualInputManager:SendKeyEvent(false, key, false, nil)
					HeldKeys[key] = nil
					LongHoldKeys[key] = nil
				end
			end))
		end
	end

	return match
end

local ChangelogTab = Window:CreateTab({ name = "Changelogs" })

ChangelogTab:CreateText({
	name = "V2.1.8.5",
	text = "- Switched Key Monitor to Roblox Native Notifications.\n- Improved script resilience.",
})
ChangelogTab:CreateText({
	name = "V2.1.8.4",
	text = "- Added Key Monitoring toggle.\n- Fixed UI element titles to English.\n- Keybind functionality improved.",
})

local AutoplayerTab = Window:CreateTab({ name = "Autoplayer" })

local AutoplayToggle = AutoplayerTab:CreateToggle({
	name = "Enable Autoplayer",
	value = true,
	callback = function(value)
		AutoplayEnabled = value
		MatchHooked = false
		HookedFolder = nil
		if not value then
			DisconnectAll()
			ReleaseAllKeys()
		end
	end,
})

AutoplayerTab:CreateKeybind({
	name = "Toggle Autoplayer Keybind",
	value = "End",
	callback = function()
		AutoplayEnabled = not AutoplayEnabled
		AutoplayToggle:Set(AutoplayEnabled)
	end,
})

AutoplayerTab:CreateToggle({
	name = "Key Monitor (Native)",
	value = false,
	callback = function(value)
		KeyMonitor = value
	end,
})

AutoplayerTab:CreateDivider({ text = "Bot Customization" })

AutoplayerTab:CreateToggle({
	name = "Legit Mode",
	value = false,
	callback = function(value)
		LegitMode = value
	end,
})

AutoplayerTab:CreateInput({
	name = "Miss Chance (%)",
	value = "0",
	placeholder = "Type 0-100",
	callback = function(text)
		local num = tonumber(text)
		if num then
			math.clamp(num, 0, 100)
		end
	end,
})

AutoplayerTab:CreateToggle({
	name = "Hold Long Notes",
	value = true,
	callback = function(value)
		HoldLongNotes = value
	end,
})

local StatusText = AutoplayerTab:CreateText({
	name = "Status",
	text = "Waiting.",
})

task.spawn(function()
	while true do
		task.wait(1)
		pcall(function()
			local state = "Idle."
			if AutoplayEnabled then
				if HookedFolder and HookedFolder.Parent ~= nil then
					if os.clock() - LastNoteAt < 5 then
						state = "Playing."
					else
						state = "Armed, no notes."
					end
				else
					state = "Waiting for match."
				end
			end
			StatusText:Set(state)
		end)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)

		if AutoplayEnabled then
			if MatchHooked and HookedFolder and HookedFolder.Parent == nil then
				MatchHooked = false
				HookedFolder = nil
				DisconnectAll()
				ReleaseAllKeys()
			end
			local match = FindMatchTable()
			if match and match.MatchFolder then
				if MatchHooked and HookedFolder ~= match.MatchFolder then
					MatchHooked = false
					HookedFolder = nil
					DisconnectAll()
					ReleaseAllKeys()
				end
				if not MatchHooked then
					MatchHooked = true
					if pcall(HookMatch) then
						HookedFolder = match.MatchFolder
						task.spawn(function()
							pcall(function()
								match.MatchFolder.Destroying:Wait()
							end)
							MatchHooked = false
							HookedFolder = nil
							DisconnectAll()
							ReleaseAllKeys()
						end)
					else
						MatchHooked = false
					end
				end
			elseif not match then
				MatchHooked = false
				HookedFolder = nil
			end
		end
	end
end)
