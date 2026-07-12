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

local function isSupported(fn: any): boolean
	return type(fn) == "function"
end

local function copyToClipboard(text: string): boolean
	if isSupported(setclipboard) then
		local ok = pcall(setclipboard, text)
		if ok then return true end
	end

	if isSupported(toclipboard) then
		local ok = pcall(toclipboard, text)
		if ok then return true end
	end

	if isSupported(Clipboard) and isSupported(Clipboard.set) then
		local ok = pcall(Clipboard.set, text)
		if ok then return true end
	end

	return false
end

local function fetch(url: string): FetchResult
	local ok, res = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "GET",
		Headers = HEADERS,
	})

	if ok and res then
		return { success = true, statusCode = res.StatusCode, body = res.Body }
	end

	if isSupported(syn and syn.request or nil) then
		local ok2, res2 = pcall(syn.request, { Url = url, Method = "GET", Headers = HEADERS })
		if ok2 and res2 then
			return { success = true, statusCode = res2.StatusCode, body = res2.Body }
		end
	end

	if isSupported(http and http.request or nil) then
		local ok3, res3 = pcall(http.request, { Url = url, Method = "GET", Headers = HEADERS })
		if ok3 and res3 then
			return { success = true, statusCode = res3.StatusCode, body = res3.Body }
		end
	end

	if isSupported(request) then
		local ok4, res4 = pcall(request, { Url = url, Method = "GET", Headers = HEADERS })
		if ok4 and res4 then
			return { success = true, statusCode = res4.StatusCode, body = res4.Body }
		end
	end

	return { success = false, statusCode = nil, body = nil }
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

pcall(function()
	local resolvedLink: string = resolveInviteLink()
	copyToClipboard(resolvedLink)
end)
