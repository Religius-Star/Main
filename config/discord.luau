local HttpService = game:GetService("HttpService")

local INVITE_CODE: string = "mJm4etTYjk"
local SERVER_ID: string = "1525943679133552811"
local BASE_URL: string = "https://discord.gg/" .. INVITE_CODE

local HEADERS: { [string]: string } = {
	["Accept"] = "application/json",
	["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
}

type FetchResult = {
	success: boolean,
	statusCode: number?,
	body: string?,
}

local function fetch(url: string): FetchResult
	local ok, res = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "GET",
		Headers = HEADERS,
	})

	if not ok then
		return { success = false, statusCode = nil, body = nil }
	end

	return {
		success = true,
		statusCode = res.StatusCode,
		body = res.Body,
	}
end

local function resolveInviteLink(): string
	local inviteUrl = string.format(
		"https://discord.com/api/v10/invites/%s?with_counts=true&with_expiration=true",
		INVITE_CODE
	)

	local inviteResult = fetch(inviteUrl)
	if inviteResult.success and inviteResult.statusCode == 200 then
		return BASE_URL
	end

	local widgetUrl = string.format(
		"https://discord.com/api/v10/guilds/%s/widget.json",
		SERVER_ID
	)

	local widgetResult = fetch(widgetUrl)
	if widgetResult.success and widgetResult.statusCode == 200 and widgetResult.body then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, widgetResult.body)
		if ok and type(data) == "table" and type(data.instant_invite) == "string" then
			return data.instant_invite
		end
	end

	return BASE_URL
end

local ok, result = pcall(function()
	local resolvedLink: string = resolveInviteLink()
	setclipboard(resolvedLink)
	print("[Discord] Copied:", resolvedLink)
end)

if not ok then
	warn("[Discord] Error:", result)
end
