-- this script create by _vezt of the onwer (sorry for skidding) 
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Religius-Star/Main/refs/heads/main/ui%20libary/arod.luau"))()

local Kawai
do
    local success, err = pcall(function()
        local source = game:HttpGet("https://raw.githubusercontent.com/Mainery-foxxie/Main/refs/heads/main/UI%20Libary/Kawai%20Lib/Source.lua", true)
        local func = loadstring(source)
        if not func then error("Kawai Lib failed to compile") end
        Kawai = func()
    end)
    if not success then
        Kawai = nil
        warn("Kawai not loaded, using fallback notifications.")
    end
end

local CUSTOM_ICON = "88708020645655"
local PINK = Color3.fromRGB(255, 105, 180)
local PURPLE = Color3.fromRGB(128, 0, 128)

local function Notify(title, desc, nType, duration, buttons, iconKey)
    nType = nType or "info"
    duration = duration or 3
    pcall(function()
        if Kawai and Kawai.Notify then
            Kawai.Notify({
                Title = title,
                Desc = desc,
                Type = nType,
                Duration = duration,
                Icon = iconKey or CUSTOM_ICON,
                Buttons = buttons,
                Color = { PINK, PURPLE },
            })
        else
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title,
                Text = desc,
                Duration = duration,
            })
        end
    end)
end

local player = game:GetService("Players").LocalPlayer
local playerName = player.DisplayName or player.Name
local DISCORD_LINK = "https://discord.gg/mJm4etTYjk"

local function pick(t) return t[math.random(1, #t)] end
local function fmt(s, name) return s:gsub("{name}", name) end

local femboyWelcomeMsgs = {
    "Hii {name}! I'm Shota, your femboy guide!\nWelcome to Vezt Auto-Player! 🎵",
    "Ohayou {name}! I'm Shota, and I'm here to make your day cuter!\nLet's ace those charts! 💖",
    "Hey {name}! Shota-chan reporting for duty!\nReady to auto-play? 🎀",
    "Hii {name}! I'm Shota, and I love skirts and thigh highs!\nLet's get those perfect scores! ✨",
}

local userInputService = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")

local function getDevice()
    if guiService:IsTenFootInterface() then
        return "Console"
    elseif userInputService.TouchEnabled and not userInputService.KeyboardEnabled then
        return "Mobile"
    else
        return "PC"
    end
end

local noteGame = require(
    game:GetService("Players").LocalPlayer.PlayerScripts
        :WaitForChild("Start")
        :WaitForChild("Menu")
        :WaitForChild("Freeplay")
        :WaitForChild("NoteGame")
)
local modCharts = game:GetService("ReplicatedStorage").Modules.ModCharts

local function getGameState()
    return getupvalue(noteGame.Init, 6)
end

local function getSettings()
    return getupvalue(noteGame.Init, 29)
end

local function getNoteGame(inner)
    return (not inner and noteGame) or getupvalue(noteGame.Init, 2)
end

local function getNotes()
    return getupvalue(getNoteGame(true)._GetEarlistNoteOfAll, 2)
end

local function getSongData()
    return getupvalue(noteGame.Init, 26)
end

local function getKeyModes()
    return getupvalue(getNoteGame(true)._CreateNote, 1)
end

local function getJudgements()
    return getupvalue(getNoteGame(true)._OnKeyReleased, 5)
end

local config = {
    Enabled = false,
    HitChance = 100,
    HitOffset = 0,
    NoMissExploit = false,
    NoAccuracyExploit = false,
    NoComboBreak = false,
}

local function shouldIgnore(noteType)
    local song = getSongData()
    if not song or not song.Category or not song.Song then
        return false
    end
    local ok, result = pcall(function()
        local chart = require(modCharts[song.Category][song.Song])
        if type(chart) == "table" and rawget(chart, "_CustomNoteConfig") then
            local custom = chart._CustomNoteConfig
            return (custom.IsDangerous and custom.IsDangerous[noteType]) or false
        end
        return false
    end)
    if not ok then
        error("[ShouldIgnore] " .. tostring(result), 0)
    end
    return result
end

local runService = game:GetService("RunService")
local virtualInput = game:GetService("VirtualInputManager")
local heartbeatConnection = nil
local processedNotes = {}
local heldKeys = {}

local function getHitDistance()
    local judgements = getJudgements()
    if judgements and judgements.Sick then
        return judgements.Sick.Distance
    end
    return 0.05833333333333333
end

local function shouldHit()
    return math.random(1, 100) <= config.HitChance
end

local function autoPlay()
    local ok, result = pcall(function()
        local gameState = getGameState()
        if not gameState or not gameState.ArrowGui then
            return
        end
        local settings = getSettings()
        if not settings then
            return
        end
        local notes = getNotes()
        if not notes then
            return
        end
        local keyModes = getKeyModes()
        if not keyModes then
            return
        end

        local maxArrows = gameState.MaxArrows or 4
        local keyMode = keyModes[maxArrows]
        if not keyMode then
            return
        end
        local controls = (maxArrows < 5 and settings) or settings.ExtraKeySettings[tostring(maxArrows)]
        if not controls then
            error("[autoPlay] controls nil for maxArrows=" .. tostring(maxArrows), 0)
        end
        local downScroll = settings.DownScroll
        local targetPosition = downScroll and 1 or 0
        local hitDistance = getHitDistance()

        for _, direction in pairs(keyMode.Codes) do
            local directionNotes = notes[direction]
            local keycode = controls[direction .. "Key"]
            if not keycode then
                error("[autoPlay > keycode] nil for direction=" .. tostring(direction), 0)
            end

            if directionNotes and #directionNotes > 0 then
                local selected = nil
                for _, candidate in ipairs(directionNotes) do
                    local candidateId = candidate[1] and (candidate[1].Name or candidate[1].ZIndex)
                    if candidateId and not processedNotes[candidateId] then
                        selected = candidate
                        break
                    end
                end

                if selected and selected[1] then
                    local note = selected[1]
                    local longNote = selected[2]
                    local noteType = nil
                    local attributeOK, attributeError = pcall(function()
                        noteType = note:GetAttribute("NoteType")
                    end)
                    if not attributeOK then
                        error("[autoPlay > GetAttribute] " .. tostring(attributeError), 0)
                    end

                    local ignore = noteType and shouldIgnore(noteType)
                    if ignore then
                        return
                    end
                    local noteId = note.Name or note.ZIndex
                    if not processedNotes[noteId] then
                        local notePosition = nil
                        local positionOK, positionError = pcall(function()
                            notePosition = note.Position.Y.Scale
                        end)
                        if not positionOK then
                            error("[autoPlay > notePos] " .. tostring(positionError), 0)
                        end
                        local distance = math.abs(notePosition - targetPosition)
                        local threshold = hitDistance + config.HitOffset

                        if distance <= threshold and shouldHit() then
                            processedNotes[noteId] = true
                            if longNote and longNote.Visible then
                                if heldKeys[direction] then
                                    virtualInput:SendKeyEvent(false, keycode, false, game)
                                    heldKeys[direction] = nil
                                end
                                virtualInput:SendKeyEvent(true, keycode, false, game)
                                heldKeys[direction] = {
                                    keycode = keycode,
                                    longNote = longNote,
                                    noteId = noteId,
                                }

                                local holdDirection, holdKeycode = direction, keycode
                                local holdNoteId, holdObject = noteId, longNote
                                task.spawn(function()
                                    local holdOK, holdError = pcall(function()
                                        while holdObject.Visible and holdObject.Parent do
                                            task.wait()
                                        end
                                        if
                                            heldKeys[holdDirection]
                                            and heldKeys[holdDirection].noteId == holdNoteId
                                        then
                                            virtualInput:SendKeyEvent(false, holdKeycode, false, game)
                                            heldKeys[holdDirection] = nil
                                        end
                                        task.delay(0.1, function()
                                            processedNotes[holdNoteId] = nil
                                        end)
                                    end)
                                    if not holdOK then
                                        error(
                                            "[autoPlay > spawnHold dir="
                                                .. tostring(holdDirection)
                                                .. "] "
                                                .. tostring(holdError),
                                            0
                                        )
                                    end
                                end)
                            else
                                local tapOK, tapError = pcall(function()
                                    if heldKeys[direction] then
                                        virtualInput:SendKeyEvent(false, keycode, false, game)
                                        task.wait()
                                        virtualInput:SendKeyEvent(true, keycode, false, game)
                                        task.wait()
                                        virtualInput:SendKeyEvent(false, keycode, false, game)
                                        virtualInput:SendKeyEvent(true, keycode, false, game)
                                    else
                                        virtualInput:SendKeyEvent(true, keycode, false, game)
                                        virtualInput:SendKeyEvent(false, keycode, false, game)
                                    end
                                end)
                                if not tapOK then
                                    error(
                                        "[autoPlay > tapNote dir="
                                            .. tostring(direction)
                                            .. "] "
                                            .. tostring(tapError),
                                        0
                                    )
                                end
                                task.delay(0.5, function()
                                    processedNotes[noteId] = nil
                                end)
                            end
                        end
                    end
                end
            end
        end

        for direction, held in pairs(heldKeys) do
            local cleanupOK, cleanupError = pcall(function()
                if not held or not held.longNote or not held.longNote.Visible or not held.longNote.Parent then
                    virtualInput:SendKeyEvent(false, held.keycode, false, game)
                    heldKeys[direction] = nil
                end
            end)
            if not cleanupOK then
                error(
                    "[autoPlay > holdCleanup dir=" .. tostring(direction) .. "] " .. tostring(cleanupError),
                    0
                )
            end
        end
    end)
    if not ok then
        error("[autoPlay > uncaught] " .. tostring(result), 0)
    end
end

local function setAutoPlayer(enabled)
    config.Enabled = enabled
    if enabled then
        if not heartbeatConnection then
            heartbeatConnection = runService.Heartbeat:Connect(autoPlay)
        end
    else
        for _, held in pairs(heldKeys) do
            virtualInput:SendKeyEvent(false, held.keycode, false, game)
        end
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        table.clear(processedNotes)
        table.clear(heldKeys)
    end
end

local oldNamecall = nil
local lastCombo = 0

local function namecallHandler(self, ...)
    local args = { ... }
    local method = getnamecallmethod():lower()
    if not checkcaller() and self.Name == "RoundEvent" and method == "fireserver" then
        if args[1] == 9 then
            if config.NoMissExploit == true then
                args[2].Misses = 0
            end
            if config.NoAccuracyExploit == true then
                args[2].Accuracy = 100
            end
            if config.NoComboBreak == true then
                local combo = args[2].Combo
                if combo == 0 and lastCombo > 0 then
                    args[2].Combo = lastCombo + 1
                    args[2].Score = args[2].Score + 350
                end
                lastCombo = args[2].Combo
            else
                lastCombo = args[2].Combo
            end
        end
        return oldNamecall(self, unpack(args))
    end
    return oldNamecall(self, ...)
end

oldNamecall = hookmetamethod(game, "__namecall", namecallHandler)

local MainWindow = Lib:CreateWindow("it's kawai | Alwi hub", "music")

MainWindow:Section("Controls")
MainWindow:Toggle("Enable Auto-Player", false, function(value)
    setAutoPlayer(value)
    Notify("Auto-Player", value and "Enabled" or "Disabled", value and "success" or "info", 2)
end)

MainWindow:Slider("Accuracy", 0, 100, 100, function(value)
    config.HitChance = value
end)

MainWindow:Section("Exploits")
MainWindow:Toggle("No Miss Exploit", false, function(value)
    config.NoMissExploit = value
    Notify("No Miss Exploit", value and "Enabled" or "Disabled", value and "success" or "info", 2)
end)
MainWindow:Toggle("High Accuracy Exploit", false, function(value)
    config.NoAccuracyExploit = value
    Notify("High Accuracy Exploit", value and "Enabled" or "Disabled", value and "success" or "info", 2)
end)
MainWindow:Toggle("No Combo Break [BETA]", false, function(value)
    config.NoComboBreak = value
    Notify("No Combo Break", value and "Enabled" or "Disabled", value and "success" or "info", 2)
end)

Lib:Start()

task.wait(0.5)
Notify("Shota-chan 💖", fmt(pick(femboyWelcomeMsgs), playerName), "info", 6)

task.wait(1)
Notify(
    "Shota-chan 💖",
    "Thanks for using this script!\nJoin our Discord for more fun and updates!",
    "info",
    60,
    {
        {
            Title = "Yes",
            Callback = function()
                pcall(setclipboard, DISCORD_LINK)
                Notify("Shota-chan", "Link copied! See you there! 💖", "success", 3)
            end
        },
        {
            Title = "No",
            Callback = function()
                pcall(setclipboard, DISCORD_LINK)
                player:Kick("Bad Boy/girl why not join :3")
                task.wait(2)
                game:Shutdown()
            end
        }
    }
)
