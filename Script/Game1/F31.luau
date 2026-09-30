local response = game:HttpGet("https://raw.githubusercontent.com/MainTreeUhh/ab/main/cf")
local ab = loadstring(response)()
local Window = ab:CreateWindow("Strongman Simulator")
local Folder = Window:AddFolder("Main")

-- Fire only real remotes, safely
local function fireAllRemotes(id)
	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("RemoteEvent") then
			task.spawn(function()
				pcall(function()
					obj:FireServer(id)
				end)
			end)
		elseif obj:IsA("RemoteFunction") then
			task.spawn(function()
				pcall(function()
					obj:InvokeServer(id)
				end)
			end)
		end
	end
end

Folder:AddButton({
	text = "Instant UGC 1",
	callback = function()
		fireAllRemotes("117932065714358")
	end
})

Folder:AddButton({
	text = "Instant UGC 2",
	callback = function()
		fireAllRemotes("133366739624397")
	end
})
ab:Init()
