-- Load the library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Religius-Star/Main/refs/heads/main/ui%20libary/arod.luau"))()

local Cfg = Library:CreateConfig("arod_ui_demo")

-- ============================================================
-- WINDOW 1 – WITH ICONS
-- ============================================================
local WindowWithIcon = Library:CreateWindow("arod UI", "shield")

WindowWithIcon:Section("─── With Icons ───")

WindowWithIcon:Button("Execute Script", function()
    print("Script executed!")
end, "play")

local toggleIcon = WindowWithIcon:Toggle("Auto Farm", false,
    Cfg:Bind("w1_autoFarm", false, function(v)
        print("Auto Farm:", v)
    end), "zap")
Cfg:Link("w1_autoFarm", toggleIcon)

local ws1 = WindowWithIcon:Slider("WalkSpeed", 16, 100, 16,
    Cfg:Bind("w1_walkSpeed", 16, function(v)
        local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = v end
    end))
Cfg:Link("w1_walkSpeed", ws1)

local gamemode1 = WindowWithIcon:Dropdown("Gamemode", {"Solo","Duo","Squad"},
    Cfg:Bind("w1_gamemode", "Solo", function(choice)
        print("Gamemode:", choice)
    end), "users")
Cfg:Link("w1_gamemode", gamemode1)

local multiDropIcon = WindowWithIcon:Dropdown(
    "Select Fruits (max 2)",
    {"Apple","Banana","Cherry","Date"},
    Cfg:Bind("w1_fruits", {}, function(list)
        print("Fruits:", table.concat(list, ", "))
    end),
    "shopping-bag", true, 2
)
Cfg:Link("w1_fruits", multiDropIcon)

local name1 = WindowWithIcon:TextBox("Player Name", "Guest", "Enter name...",
    function(v) print("Name:", v) end, "user")
Cfg:Register("w1_name", name1, "Guest")

local keybind1 = WindowWithIcon:Keybind("Activate", Enum.KeyCode.RightControl,
    Cfg:Bind("w1_keybind", Enum.KeyCode.RightControl, function(key)
        print("Key:", key and key.Name or "none")
    end), "keyboard")
Cfg:Link("w1_keybind", keybind1)

WindowWithIcon:Button("Get Multi Selection", function()
    print("Current fruits:", table.concat(multiDropIcon:Get(), ", "))
end, "eye")

WindowWithIcon:Button("Clear Multi", function()
    multiDropIcon:Clear()
end, "x")

local folderIcon = WindowWithIcon:CreateFolder("Advanced", "folder")
folderIcon:Button("Folder Button", function() print("Folder btn") end, "play")

local fTog1 = folderIcon:Toggle("Folder Toggle", false,
    Cfg:Bind("w1_folder_toggle", false, function(v)
        print("Folder toggle:", v)
    end), "zap")
Cfg:Link("w1_folder_toggle", fTog1)

local fSld1 = folderIcon:Slider("Folder Slider", 0, 10, 5,
    Cfg:Bind("w1_folder_slider", 5, function(v)
        print("Folder slider:", v)
    end))
Cfg:Link("w1_folder_slider", fSld1)

local fDrop1 = folderIcon:Dropdown("Folder Dropdown", {"A","B","C"},
    Cfg:Bind("w1_folder_drop", "A", function(v)
        print("Folder drop:", v)
    end), "list")
Cfg:Link("w1_folder_drop", fDrop1)

-- ============================================================
-- WINDOW 1 – FOLDER SECTION
-- ============================================================
WindowWithIcon:Section("─── Folders ───")

local folder1 = WindowWithIcon:CreateFolder("Main Folder", "folder")
folder1:Button("Button", function() print("main folder btn") end, "play")

local fol1Tog = folder1:Toggle("Toggle", false,
    Cfg:Bind("w1_fol1_toggle", false, function(v)
        print("main folder toggle:", v)
    end), "zap")
Cfg:Link("w1_fol1_toggle", fol1Tog)

local fol1Sld = folder1:Slider("Slider", 0, 100, 50,
    Cfg:Bind("w1_fol1_slider", 50, function(v)
        print("main folder slider:", v)
    end))
Cfg:Link("w1_fol1_slider", fol1Sld)

local fol1Drop = folder1:Dropdown("Dropdown", {"X","Y","Z"},
    Cfg:Bind("w1_fol1_drop", "X", function(v)
        print("main folder drop:", v)
    end), "list")
Cfg:Link("w1_fol1_drop", fol1Drop)

local folder2 = WindowWithIcon:CreateFolder("Second Folder", "star")
folder2:Button("Button", function() print("second folder btn") end, "play")

local fol2Tog = folder2:Toggle("Toggle", false,
    Cfg:Bind("w1_fol2_toggle", false, function(v)
        print("second folder toggle:", v)
    end), "eye")
Cfg:Link("w1_fol2_toggle", fol2Tog)

local fol2Sld = folder2:Slider("Range", 1, 50, 10,
    Cfg:Bind("w1_fol2_slider", 10, function(v)
        print("second folder slider:", v)
    end))
Cfg:Link("w1_fol2_slider", fol2Sld)

local fol2Drop = folder2:Dropdown("Target", {"Nearest","Lowest HP"},
    Cfg:Bind("w1_fol2_drop", "Nearest", function(v)
        print("second folder target:", v)
    end), "crosshair")
Cfg:Link("w1_fol2_drop", fol2Drop)

local folder3 = WindowWithIcon:CreateFolder("Picker", "folder")
local folder3Picker = folder3:Dropdown(
    "Pick (max 2)",
    {"A","B","C","D"},
    Cfg:Bind("w1_picker", {}, function(list)
        print("picker:", table.concat(list, ", "))
    end),
    "shopping-bag", true, 2
)
Cfg:Link("w1_picker", folder3Picker)

folder3:Button("Get Selection", function()
    print("picked:", table.concat(folder3Picker:Get(), ", "))
end, "eye")

folder3:Button("Clear Selection", function()
    folder3Picker:Clear()
end, "x")

-- ============================================================
-- WINDOW 2 – WITHOUT ICONS
-- ============================================================
local WindowNoIcon = Library:CreateWindow("arod UI Non icon")

WindowNoIcon:Section("─── Without Icons ───")

WindowNoIcon:Button("Execute Script", function()
    print("Script executed (no icon)!")
end)

local toggleNoIcon = WindowNoIcon:Toggle("Auto Farm", false,
    Cfg:Bind("w2_autoFarm", false, function(v)
        print("Auto Farm (no icon):", v)
    end))
Cfg:Link("w2_autoFarm", toggleNoIcon)

local ws2 = WindowNoIcon:Slider("WalkSpeed", 16, 100, 16,
    Cfg:Bind("w2_walkSpeed", 16, function(v)
        local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = v end
    end))
Cfg:Link("w2_walkSpeed", ws2)

local gamemode2 = WindowNoIcon:Dropdown("Gamemode", {"Solo","Duo","Squad"},
    Cfg:Bind("w2_gamemode", "Solo", function(choice)
        print("Gamemode (no icon):", choice)
    end))
Cfg:Link("w2_gamemode", gamemode2)

local multiDropNoIcon = WindowNoIcon:Dropdown(
    "Select Colors (max 3)",
    {"Red","Green","Blue","Yellow","Purple"},
    Cfg:Bind("w2_colors", {}, function(list)
        print("Colors:", table.concat(list, ", "))
    end),
    nil, true, 3
)
Cfg:Link("w2_colors", multiDropNoIcon)

local name2 = WindowNoIcon:TextBox("Player Name", "Guest", "Enter name...",
    function(v) print("Name (no icon):", v) end)
Cfg:Register("w2_name", name2, "Guest")

local keybind2 = WindowNoIcon:Keybind("Activate", Enum.KeyCode.F,
    Cfg:Bind("w2_keybind", Enum.KeyCode.F, function(key)
        print("Key (no icon):", key and key.Name or "none")
    end))
Cfg:Link("w2_keybind", keybind2)

WindowNoIcon:Button("Get Multi (no icon)", function()
    print("Current colors:", table.concat(multiDropNoIcon:Get(), ", "))
end)

WindowNoIcon:Button("Set to Red & Blue (no icon)", function()
    multiDropNoIcon:Set({"Red","Blue"})
end)

local folderNoIcon = WindowNoIcon:CreateFolder("Advanced")
folderNoIcon:Button("Folder Button", function() print("Folder btn (no icon)") end)

local nfTog = folderNoIcon:Toggle("Folder Toggle", false,
    Cfg:Bind("w2_folder_toggle", false, function(v)
        print("Folder toggle (no icon):", v)
    end))
Cfg:Link("w2_folder_toggle", nfTog)

local nfSld = folderNoIcon:Slider("Folder Slider", 0, 10, 5,
    Cfg:Bind("w2_folder_slider", 5, function(v)
        print("Folder slider (no icon):", v)
    end))
Cfg:Link("w2_folder_slider", nfSld)

local nfDrop = folderNoIcon:Dropdown("Folder Dropdown", {"A","B","C"},
    Cfg:Bind("w2_folder_drop", "A", function(v)
        print("Folder drop (no icon):", v)
    end))
Cfg:Link("w2_folder_drop", nfDrop)

-- ============================================================
-- WINDOW 2 – FOLDER SECTION
-- ============================================================
WindowNoIcon:Section("─── Folders ───")

local nfolder1 = WindowNoIcon:CreateFolder("Main Folder")
nfolder1:Button("Button", function() print("main folder btn (no icon)") end)

local nf1Tog = nfolder1:Toggle("Toggle", false,
    Cfg:Bind("w2_fol1_toggle", false, function(v)
        print("main folder toggle (no icon):", v)
    end))
Cfg:Link("w2_fol1_toggle", nf1Tog)

local nf1Sld = nfolder1:Slider("Slider", 0, 100, 50,
    Cfg:Bind("w2_fol1_slider", 50, function(v)
        print("main folder slider (no icon):", v)
    end))
Cfg:Link("w2_fol1_slider", nf1Sld)

local nf1Drop = nfolder1:Dropdown("Dropdown", {"X","Y","Z"},
    Cfg:Bind("w2_fol1_drop", "X", function(v)
        print("main folder drop (no icon):", v)
    end))
Cfg:Link("w2_fol1_drop", nf1Drop)

local nfolder2 = WindowNoIcon:CreateFolder("Second Folder")
nfolder2:Button("Button", function() print("second folder btn (no icon)") end)

local nf2Tog = nfolder2:Toggle("Toggle", false,
    Cfg:Bind("w2_fol2_toggle", false, function(v)
        print("second folder toggle (no icon):", v)
    end))
Cfg:Link("w2_fol2_toggle", nf2Tog)

local nf2Sld = nfolder2:Slider("Range", 1, 50, 10,
    Cfg:Bind("w2_fol2_slider", 10, function(v)
        print("second folder slider (no icon):", v)
    end))
Cfg:Link("w2_fol2_slider", nf2Sld)

local nf2Drop = nfolder2:Dropdown("Target", {"Nearest","Lowest HP"},
    Cfg:Bind("w2_fol2_drop", "Nearest", function(v)
        print("second folder target (no icon):", v)
    end))
Cfg:Link("w2_fol2_drop", nf2Drop)

local nfolder3 = WindowNoIcon:CreateFolder("Picker")
local nfolder3Picker = nfolder3:Dropdown(
    "Pick (max 3)",
    {"A","B","C","D","E"},
    Cfg:Bind("w2_picker", {}, function(list)
        print("nfolder3 picker:", table.concat(list, ", "))
    end),
    nil, true, 3
)
Cfg:Link("w2_picker", nfolder3Picker)

nfolder3:Button("Get Selection", function()
    print("picked:", table.concat(nfolder3Picker:Get(), ", "))
end)

nfolder3:Button("Clear Selection", function()
    nfolder3Picker:Clear()
end)

-- ============================================================
-- LOAD CONFIG, THEN START
-- ============================================================
Cfg:Load()
Library:Start()
