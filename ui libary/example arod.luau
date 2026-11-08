-- Load the library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Religius-Star/Main/refs/heads/main/ui%20libary/arod.luau"))()

-- ============================================================
-- WINDOW 1 – WITH ICONS
-- ============================================================
local WindowWithIcon = Library:CreateWindow("arod UI", "shield")

WindowWithIcon:Section("─── With Icons ───")

-- Button with icon
WindowWithIcon:Button("Execute Script", function()
    print("Script executed!")
end, "play")

-- Toggle with icon
local toggleIcon = WindowWithIcon:Toggle("Auto Farm", false, function(v)
    print("Auto Farm:", v)
end, "zap")

-- Slider (does NOT support icons – icon would be ignored)
WindowWithIcon:Slider("WalkSpeed", 16, 100, 16, function(v)
    local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = v end
end)

-- Single Dropdown with icon
WindowWithIcon:Dropdown(
    "Gamemode",
    {"Solo", "Duo", "Squad"},
    function(choice) print("Gamemode:", choice) end,
    "users"
)

-- Multi Dropdown with icon (max 2)
local multiDropIcon = WindowWithIcon:Dropdown(
    "Select Fruits (max 2)",
    {"Apple", "Banana", "Cherry", "Date"},
    function(list) print("Fruits:", table.concat(list, ", ")) end,
    "shopping-bag",  -- icon
    true,            -- multi
    2                -- maxPick
)

-- TextBox with icon (ONLY on main window, NOT in folder)
WindowWithIcon:TextBox("Player Name", "Guest", "Enter name...", function(v)
    print("Name:", v)
end, "user")

-- Keybind with icon (ONLY on main window)
WindowWithIcon:Keybind("Activate", Enum.KeyCode.RightControl, function(key)
    print("Key:", key and key.Name or "none")
end, "keyboard")

-- Extra buttons to interact with multi dropdown
WindowWithIcon:Button("Get Multi Selection", function()
    local current = multiDropIcon:Get()
    print("Current fruits:", table.concat(current, ", "))
end, "eye")

WindowWithIcon:Button("Clear Multi", function()
    multiDropIcon:Clear()
end, "x")

-- Folder with icon (only Button, Toggle, Slider, Dropdown allowed inside)
local folderIcon = WindowWithIcon:CreateFolder("Advanced", "folder")
folderIcon:Button("Folder Button", function() print("Folder btn") end, "play")
folderIcon:Toggle("Folder Toggle", false, function(v) print("Folder toggle:", v) end, "zap")
folderIcon:Slider("Folder Slider", 0, 10, 5, function(v) print("Folder slider:", v) end)
folderIcon:Dropdown("Folder Dropdown", {"A","B","C"}, function(v) print("Folder drop:", v) end, "list")


-- ============================================================
-- WINDOW 1 – FOLDER SECTION (NEW)
-- ============================================================
WindowWithIcon:Section("─── Folders ───")

-- Folder 1
local folder1 = WindowWithIcon:CreateFolder("Main Folder", "folder")
folder1:Button("Button", function() print("main folder btn") end, "play")
folder1:Toggle("Toggle", false, function(v) print("main folder toggle:", v) end, "zap")
folder1:Slider("Slider", 0, 100, 50, function(v) print("main folder slider:", v) end)
folder1:Dropdown("Dropdown", {"X","Y","Z"}, function(v) print("main folder drop:", v) end, "list")

-- Folder 2
local folder2 = WindowWithIcon:CreateFolder("Second Folder", "star")
folder2:Button("Button", function() print("second folder btn") end, "play")
folder2:Toggle("Toggle", false, function(v) print("second folder toggle:", v) end, "eye")
folder2:Slider("Range", 1, 50, 10, function(v) print("second folder slider:", v) end)
folder2:Dropdown("Target", {"Nearest", "Lowest HP"}, function(v) print("second folder target:", v) end, "crosshair")

-- Folder 3 – with a multi-dropdown handle inside
local folder3 = WindowWithIcon:CreateFolder("Picker", "folder")
local folder3Picker = folder3:Dropdown(
    "Pick (max 2)",
    {"A","B","C","D"},
    function(list) print("picker:", table.concat(list, ", ")) end,
    "shopping-bag", true, 2
)
folder3:Button("Get Selection", function()
    print("picked:", table.concat(folder3Picker:Get(), ", "))
end, "eye")
folder3:Button("Clear Selection", function()
    folder3Picker:Clear()
end, "x")


-- ============================================================
-- WINDOW 2 – WITHOUT ICONS
-- ============================================================
local WindowNoIcon = Library:CreateWindow("arod UI Non icon")   -- no window icon

WindowNoIcon:Section("─── Without Icons ───")

-- Button NO icon
WindowNoIcon:Button("Execute Script", function()
    print("Script executed (no icon)!")
end)

-- Toggle NO icon
local toggleNoIcon = WindowNoIcon:Toggle("Auto Farm", false, function(v)
    print("Auto Farm (no icon):", v)
end)

-- Slider (no icon anyway)
WindowNoIcon:Slider("WalkSpeed", 16, 100, 16, function(v)
    local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = v end
end)

-- Single Dropdown NO icon
WindowNoIcon:Dropdown(
    "Gamemode",
    {"Solo", "Duo", "Squad"},
    function(choice) print("Gamemode (no icon):", choice) end
)

-- Multi Dropdown NO icon (max 3)
local multiDropNoIcon = WindowNoIcon:Dropdown(
    "Select Colors (max 3)",
    {"Red", "Green", "Blue", "Yellow", "Purple"},
    function(list) print("Colors:", table.concat(list, ", ")) end,
    nil,   -- no icon
    true,  -- multi
    3      -- maxPick
)

-- TextBox NO icon
WindowNoIcon:TextBox("Player Name", "Guest", "Enter name...", function(v)
    print("Name (no icon):", v)
end)

-- Keybind NO icon
WindowNoIcon:Keybind("Activate", Enum.KeyCode.F, function(key)
    print("Key (no icon):", key and key.Name or "none")
end)

-- Extra buttons for multi dropdown
WindowNoIcon:Button("Get Multi (no icon)", function()
    local current = multiDropNoIcon:Get()
    print("Current colors:", table.concat(current, ", "))
end)

WindowNoIcon:Button("Set to Red & Blue (no icon)", function()
    multiDropNoIcon:Set({"Red", "Blue"})
end)

-- Folder WITHOUT icon
local folderNoIcon = WindowNoIcon:CreateFolder("Advanced")   -- no folder icon
folderNoIcon:Button("Folder Button", function() print("Folder btn (no icon)") end)
folderNoIcon:Toggle("Folder Toggle", false, function(v) print("Folder toggle (no icon):", v) end)
folderNoIcon:Slider("Folder Slider", 0, 10, 5, function(v) print("Folder slider (no icon):", v) end)
folderNoIcon:Dropdown("Folder Dropdown", {"A","B","C"}, function(v) print("Folder drop (no icon):", v) end)


-- ============================================================
-- WINDOW 2 – FOLDER SECTION (NEW)
-- ============================================================
WindowNoIcon:Section("─── Folders ───")

-- Folder 1 (no icons)
local nfolder1 = WindowNoIcon:CreateFolder("Main Folder")
nfolder1:Button("Button", function() print("main folder btn (no icon)") end)
nfolder1:Toggle("Toggle", false, function(v) print("main folder toggle (no icon):", v) end)
nfolder1:Slider("Slider", 0, 100, 50, function(v) print("main folder slider (no icon):", v) end)
nfolder1:Dropdown("Dropdown", {"X","Y","Z"}, function(v) print("main folder drop (no icon):", v) end)

-- Folder 2 (no icons)
local nfolder2 = WindowNoIcon:CreateFolder("Second Folder")
nfolder2:Button("Button", function() print("second folder btn (no icon)") end)
nfolder2:Toggle("Toggle", false, function(v) print("second folder toggle (no icon):", v) end)
nfolder2:Slider("Range", 1, 50, 10, function(v) print("second folder slider (no icon):", v) end)
nfolder2:Dropdown("Target", {"Nearest", "Lowest HP"}, function(v) print("second folder target (no icon):", v) end)

-- Folder 3 (no icons) – multi-dropdown with handle
local nfolder3 = WindowNoIcon:CreateFolder("Picker")
local nfolder3Picker = nfolder3:Dropdown(
    "Pick (max 3)",
    {"A","B","C","D","E"},
    function(list) print("nfolder3 picker:", table.concat(list, ", ")) end,
    nil, true, 3
)
nfolder3:Button("Get Selection", function()
    print("picked:", table.concat(nfolder3Picker:Get(), ", "))
end)
nfolder3:Button("Clear Selection", function()
    nfolder3Picker:Clear()
end)


-- ============================================================
-- START BOTH WINDOWS
-- ============================================================
Library:Start()
