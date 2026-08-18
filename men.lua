--[[
    SCOOPHUB | AUTO BUY PET V1.9
    ScoopHub custom key loader

    Flow:
    1. User enters a ScoopHub key.
    2. Loader validates it with ScoopHub's Cloudflare API.
    3. Valid keys are saved locally and launch the main ScoopHub script.
    4. Invalid, expired, revoked, or HWID-mismatched keys are rejected.
]]

repeat task.wait() until game:IsLoaded()

local HubName = "ScoopHub"
local ProductName = "AUTO BUY PET"
local ProductVersion = "V1.9"
-- Reuse the same ScoopHub mark shown in the main Auto Buy Pet window.
local HubLogo = "rbxassetid://90541504618217"
local DiscordLogo = "rbxassetid://94434236999817"
local DiscordInvite = "discord.gg/WxgqUa9Qz"
local KeyUrl = "https://scoophub.pages.dev/getkey/"
local WebsiteUrl = "https://scoophub.pages.dev/"
local ValidateUrl = "https://scoophub-api.yupie1558.workers.dev/api/key/validate"

-- Main ScoopHub script loaded ONLY after a key is accepted.
local MainScriptUrl = "https://raw.githubusercontent.com/ShigeSC/GUi/refs/heads/main/mem.lua"
-- Official provider logos. Their ImageLabels have fully transparent backgrounds.
local LootLabsLogoAsset = "rbxassetid://102357888982176"
local LinkvertiseLogoAsset = "rbxassetid://77886518827598"
local SaveFolder = "ScoopHub"
local KeyPath = SaveFolder .. "/AutoBuyPetKey.txt"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function safeCall(callback, ...)
    local ok, result = pcall(callback, ...)
    if ok then
        return result
    end
    return nil
end

local function getRequestFunction()
    if type(request) == "function" then
        return request
    end
    if type(http_request) == "function" then
        return http_request
    end
    if type(syn) == "table" and type(syn.request) == "function" then
        return syn.request
    end
    if type(http) == "table" and type(http.request) == "function" then
        return http.request
    end
    return nil
end

local function getHWID()
    local candidates = {
        gethwid,
        get_hwid,
        getexecutorhwid,
        getdeviceid,
    }

    if type(syn) == "table" and type(syn.gethwid) == "function" then
        table.insert(candidates, 1, syn.gethwid)
    end

    for _, callback in ipairs(candidates) do
        if type(callback) == "function" then
            local value = safeCall(callback)
            if value and tostring(value) ~= "" then
                return tostring(value)
            end
        end
    end

    -- Stable per Roblox client installation fallback.
    local clientId = safeCall(function()
        return RbxAnalyticsService:GetClientId()
    end)

    if clientId and tostring(clientId) ~= "" then
        return tostring(clientId)
    end

    return ""
end

local function validateWithScoopHub(key)
    local requestFunction = getRequestFunction()
    if not requestFunction then
        return nil, "HTTP_REQUEST_UNAVAILABLE"
    end

    local response = safeCall(requestFunction, {
        Url = ValidateUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
        },
        Body = HttpService:JSONEncode({
            key = key,
            hwid = getHWID(),
        }),
    })

    if type(response) ~= "table" then
        return nil, "REQUEST_FAILED"
    end

    local statusCode = tonumber(response.StatusCode or response.Status or response.status_code or 0) or 0
    local body = response.Body or response.body or ""

    local data = safeCall(function()
        return HttpService:JSONDecode(body)
    end)

    if type(data) ~= "table" then
        return nil, "INVALID_SERVER_RESPONSE"
    end

    if statusCode ~= 0 and statusCode >= 500 then
        return nil, "SERVER_ERROR"
    end

    return data, nil
end

local function loadMainScript()
    local source = safeCall(function()
        return game:HttpGet(MainScriptUrl, true)
    end)

    if type(source) ~= "string" or source == "" then
        return false, "Could not download the ScoopHub script."
    end

    local compiled = safeCall(loadstring, source)
    if type(compiled) ~= "function" then
        return false, "The ScoopHub script could not be compiled."
    end

    local ok, err = pcall(compiled)
    if not ok then
        return false, "The ScoopHub script failed to start: " .. tostring(err)
    end

    return true
end

local function copyText(value)
    if setclipboard then
        safeCall(setclipboard, value)
        return true
    end
    if toclipboard then
        safeCall(toclipboard, value)
        return true
    end
    return false
end

local function getClipboardText()
    if getclipboard then
        return safeCall(getclipboard)
    end
    return nil
end

local function loadSavedKey()
    if isfile and safeCall(isfile, KeyPath) then
        return safeCall(readfile, KeyPath)
    end
    return nil
end

local function saveKey(value)
    if not (writefile and makefolder) then
        return
    end
    if isfolder and not safeCall(isfolder, SaveFolder) then
        safeCall(makefolder, SaveFolder)
    elseif not isfolder then
        safeCall(makefolder, SaveFolder)
    end
    safeCall(writefile, KeyPath, value)
end

local existing = CoreGui:FindFirstChild("ScoopHubKeySystem")
if existing then
    existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ScoopHubKeySystem"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

local function new(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    instance.Parent = parent
    return instance
end

local function imageAsset(assetId)
    if type(assetId) == "string" and assetId ~= "" then
        return assetId
    end
    return ""
end

local LootLabsLogoImage = imageAsset(LootLabsLogoAsset)
local LinkvertiseLogoImage = imageAsset(LinkvertiseLogoAsset)

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return new("UIStroke", {
        Color = color,
        Transparency = transparency,
        Thickness = thickness or 1,
    }, parent)
end

local function tween(instance, info, values)
    local animation = TweenService:Create(instance, info, values)
    animation:Play()
    return animation
end

local Overlay = new("Frame", {
    BackgroundColor3 = Color3.fromRGB(3, 3, 6),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
}, gui)

local Stars = new("Frame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
}, Overlay)

local starData = {
    { 0.06, 0.12, 1 }, { 0.11, 0.80, 1 }, { 0.18, 0.24, 2 }, { 0.25, 0.68, 1 },
    { 0.33, 0.08, 1 }, { 0.41, 0.90, 2 }, { 0.52, 0.15, 1 }, { 0.59, 0.71, 1 },
    { 0.66, 0.89, 2 }, { 0.75, 0.11, 1 }, { 0.83, 0.61, 2 }, { 0.94, 0.30, 1 },
    { 0.13, 0.50, 1 }, { 0.32, 0.45, 1 }, { 0.70, 0.39, 1 }, { 0.90, 0.83, 1 },
}
for _, data in ipairs(starData) do
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 222, 230),
        BackgroundTransparency = data[3] == 2 and 0.22 or 0.48,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(data[1], data[2]),
        Size = UDim2.fromOffset(data[3], data[3]),
    }, Stars)
end

local Main = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.fromRGB(9, 8, 12),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(400, 340),
}, Overlay)
corner(Main, 14)
stroke(Main, Color3.fromRGB(179, 52, 63), 0.86, 1)

new("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(39, 11, 17)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(8, 5, 8)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 8, 11)),
    }),
    Rotation = 90,
}, Main)

-- Keep the night-sky texture inside the panel only; never dim the game itself.
Stars.Parent = Main

new("Frame", {
    BackgroundColor3 = Color3.fromRGB(226, 39, 65),
    BackgroundTransparency = 0.93,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, 3),
    ZIndex = 2,
}, Main)

new("ImageLabel", {
    BackgroundTransparency = 1,
    Image = "rbxassetid://3926305904",
    ImageColor3 = Color3.fromRGB(237, 46, 72),
    ImageRectOffset = Vector2.new(324, 364),
    ImageRectSize = Vector2.new(36, 36),
    Visible = false,
}, Main)


local Kicker = new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "KEY SYSTEM",
    TextColor3 = Color3.fromRGB(247, 58, 84),
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(64, 14),
    Size = UDim2.fromOffset(180, 16),
}, Main)

local Brand = new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    RichText = true,
    Text = ProductName .. " " .. ProductVersion,
    TextColor3 = Color3.fromRGB(176, 152, 161),
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(64, 28),
    Size = UDim2.fromOffset(305, 19),
}, Main)

local LogoBox = new("Frame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.fromOffset(23, 11),
    Size = UDim2.fromOffset(31, 31),
}, Main)

new("ImageLabel", {
    BackgroundTransparency = 1,
    Image = HubLogo,
    ImageColor3 = Color3.fromRGB(255, 255, 255),
    ScaleType = Enum.ScaleType.Fit,
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(31, 31),
}, LogoBox)

local CloseButton = new("TextButton", {
    BackgroundColor3 = Color3.fromRGB(37, 20, 26),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = Color3.fromRGB(245, 239, 243),
    TextSize = 14,
    Position = UDim2.fromOffset(360, 13),
    Size = UDim2.fromOffset(24, 24),
}, Main)
corner(CloseButton, 6)

local Divider = new("Frame", {
    BackgroundColor3 = Color3.fromRGB(116, 19, 37),
    BackgroundTransparency = 0.38,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(24, 52),
    Size = UDim2.fromOffset(356, 1),
}, Main)

local Welcome = new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    RichText = true,
    Text = "Unlock <font color=\"#f33a57\">ScoopHub</font> access.",
    TextColor3 = Color3.fromRGB(244, 240, 243),
    TextSize = 21,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(24, 62),
    Size = UDim2.fromOffset(350, 28),
}, Main)

local Description = new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Enter your key to launch Auto Buy Pet V1.9.",
    TextColor3 = Color3.fromRGB(169, 151, 160),
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(24, 90),
    Size = UDim2.fromOffset(350, 16),
}, Main)

local PasteButton = new("TextButton", {
    BackgroundColor3 = Color3.fromRGB(61, 30, 40),
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "PASTE",
    TextColor3 = Color3.fromRGB(255, 242, 245),
    TextSize = 12,
    Position = UDim2.fromOffset(24, 113),
    Size = UDim2.fromOffset(63, 37),
}, Main)
corner(PasteButton, 8)
stroke(PasteButton, Color3.fromRGB(112, 43, 57), 0.78, 1)

local KeyBox = new("TextBox", {
    BackgroundColor3 = Color3.fromRGB(42, 30, 37),
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    PlaceholderColor3 = Color3.fromRGB(184, 170, 176),
    PlaceholderText = "Paste or enter your key here...",
    Text = "",
    TextColor3 = Color3.fromRGB(247, 242, 245),
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(97, 113),
    Size = UDim2.fromOffset(279, 37),
}, Main)
corner(KeyBox, 8)
local KeyStroke = stroke(KeyBox, Color3.fromRGB(42, 30, 37), 1, 1)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 13),
    PaddingRight = UDim.new(0, 13),
}, KeyBox)

local SubmitButton = new("TextButton", {
    BackgroundColor3 = Color3.fromRGB(151, 27, 48),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "SUBMIT KEY  >",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Position = UDim2.fromOffset(24, 160),
    Size = UDim2.fromOffset(352, 37),
}, Main)
corner(SubmitButton, 8)
stroke(SubmitButton, Color3.fromRGB(239, 59, 82), 0.76, 1)

local StatusPill = new("Frame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(24, 207),
    Size = UDim2.fromOffset(352, 18),
}, Main)
corner(StatusPill, 9)

local StatusDot = new("Frame", {
    BackgroundColor3 = Color3.fromRGB(100, 221, 168),
    BorderSizePixel = 0,
    Visible = false,
    Size = UDim2.fromOffset(4, 4),
}, StatusPill)
corner(StatusDot, 4)

local Status = new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Enter your ScoopHub key, or get one from the website below.",
    TextColor3 = Color3.fromRGB(177, 162, 168),
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Center,
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(352, 18),
}, StatusPill)

local DiscordPill = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = Color3.fromRGB(52, 31, 37),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.new(0.5, 0, 0, 230),
    Size = UDim2.fromOffset(190, 24),
}, Main)
corner(DiscordPill, 12)
stroke(DiscordPill, Color3.fromRGB(231, 47, 59), 0.62, 1)

new("ImageLabel", {
    Image = DiscordLogo,
    ImageColor3 = Color3.fromRGB(255, 255, 255),
    ScaleType = Enum.ScaleType.Fit,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 9, 0.5, -7),
    Size = UDim2.fromOffset(14, 14),
}, DiscordPill)

new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = DiscordInvite,
    TextColor3 = Color3.fromRGB(235, 235, 240),
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(30, 0),
    Size = UDim2.new(1, -38, 1, 0),
}, DiscordPill)

local DiscordButton = new("TextButton", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "",
    Size = UDim2.fromScale(1, 1),
}, DiscordPill)

local LootLabsButton = new("TextButton", {
    BackgroundColor3 = Color3.fromRGB(72, 43, 92),
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "",
    TextColor3 = Color3.fromRGB(235, 229, 236),
    TextSize = 11,
    Position = UDim2.fromOffset(24, 264),
    Size = UDim2.fromOffset(171, 28),
}, Main)
corner(LootLabsButton, 7)
stroke(LootLabsButton, Color3.fromRGB(178, 122, 219), 0.42, 1)

local LootLabsIcon = new("TextLabel", {
    BackgroundColor3 = Color3.fromRGB(137, 78, 184),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBlack,
    Text = "KEY",
    TextColor3 = Color3.fromRGB(255, 235, 133),
    TextSize = 7,
    Position = UDim2.fromOffset(7, 5),
    Size = UDim2.fromOffset(18, 18),
    Visible = LootLabsLogoImage == "",
}, LootLabsButton)
corner(LootLabsIcon, 5)
local LootLabsImage = new("ImageLabel", {
    BackgroundTransparency = 1,
    Image = LootLabsLogoImage,
    ScaleType = Enum.ScaleType.Fit,
    Visible = LootLabsLogoImage ~= "",
    Position = UDim2.fromOffset(5, 3),
    Size = UDim2.fromOffset(22, 22),
    ZIndex = 2,
}, LootLabsButton)
new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "Get Key",
    TextColor3 = Color3.fromRGB(250, 242, 255),
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(32, 0),
    Size = UDim2.fromOffset(101, 28),
}, LootLabsButton)
new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "›",
    TextColor3 = Color3.fromRGB(218, 183, 245),
    TextSize = 19,
    Position = UDim2.fromOffset(143, 2),
    Size = UDim2.fromOffset(17, 23),
}, LootLabsButton)

local LinkvertiseButton = new("TextButton", {
    BackgroundColor3 = Color3.fromRGB(101, 51, 30),
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "",
    TextColor3 = Color3.fromRGB(235, 229, 236),
    TextSize = 11,
    Position = UDim2.fromOffset(205, 264),
    Size = UDim2.fromOffset(171, 28),
}, Main)
corner(LinkvertiseButton, 7)
stroke(LinkvertiseButton, Color3.fromRGB(225, 114, 55), 0.42, 1)

local LinkvertiseIcon = new("TextLabel", {
    BackgroundColor3 = Color3.fromRGB(200, 82, 33),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBlack,
    Text = "WEB",
    TextColor3 = Color3.fromRGB(255, 236, 202),
    TextSize = 8,
    Position = UDim2.fromOffset(7, 5),
    Size = UDim2.fromOffset(18, 18),
    Visible = LinkvertiseLogoImage == "",
}, LinkvertiseButton)
corner(LinkvertiseIcon, 5)
local LinkvertiseImage = new("ImageLabel", {
    BackgroundTransparency = 1,
    Image = LinkvertiseLogoImage,
    ScaleType = Enum.ScaleType.Fit,
    Visible = LinkvertiseLogoImage ~= "",
    Position = UDim2.fromOffset(5, 3),
    Size = UDim2.fromOffset(22, 22),
    ZIndex = 2,
}, LinkvertiseButton)
new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "Website",
    TextColor3 = Color3.fromRGB(255, 244, 237),
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(32, 0),
    Size = UDim2.fromOffset(101, 28),
}, LinkvertiseButton)
new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "›",
    TextColor3 = Color3.fromRGB(255, 189, 142),
    TextSize = 19,
    Position = UDim2.fromOffset(143, 2),
    Size = UDim2.fromOffset(17, 23),
}, LinkvertiseButton)

new("Frame", {
    BackgroundColor3 = Color3.fromRGB(122, 36, 48),
    BackgroundTransparency = 0.62,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(24, 303),
    Size = UDim2.fromOffset(352, 1),
}, Main)

new("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "ScoopHub  •  Secure access powered by ScoopHub",
    TextColor3 = Color3.fromRGB(151, 127, 136),
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Center,
    Position = UDim2.fromOffset(24, 307),
    Size = UDim2.fromOffset(352, 12),
}, Main)

local isChecking = false
local function setStatus(text, color)
    Status.Text = text
    Status.TextColor3 = color or Color3.fromRGB(165, 148, 157)
    StatusDot.BackgroundColor3 = color or Color3.fromRGB(100, 221, 168)
end

local function addButtonFeedback(button, normalColor, hoverColor)
    button.MouseEnter:Connect(function()
        if not isChecking then
            tween(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = hoverColor,
            })
        end
    end)
    button.MouseLeave:Connect(function()
        if not isChecking then
            tween(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = normalColor,
            })
        end
    end)
end

addButtonFeedback(PasteButton, Color3.fromRGB(61, 30, 40), Color3.fromRGB(82, 38, 52))
addButtonFeedback(SubmitButton, Color3.fromRGB(151, 27, 48), Color3.fromRGB(182, 34, 57))
addButtonFeedback(LootLabsButton, Color3.fromRGB(72, 43, 92), Color3.fromRGB(96, 58, 121))
addButtonFeedback(LinkvertiseButton, Color3.fromRGB(101, 51, 30), Color3.fromRGB(136, 67, 38))

KeyBox.Focused:Connect(function()
    tween(KeyBox, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = Color3.fromRGB(50, 35, 43),
    })
end)
KeyBox.FocusLost:Connect(function()
    tween(KeyBox, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = Color3.fromRGB(42, 30, 37),
    })
end)

local function checkKey(value)
    if isChecking then
        return
    end

    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        setStatus("Enter a key first.", Color3.fromRGB(244, 91, 110))
        return
    end

    isChecking = true
    SubmitButton.Text = "CHECKING KEY..."
    SubmitButton.BackgroundColor3 = Color3.fromRGB(85, 21, 33)
    setStatus("Contacting ScoopHub…", Color3.fromRGB(245, 199, 80))

    task.spawn(function()
        local data, requestError = validateWithScoopHub(value)

        if not data then
            isChecking = false
            SubmitButton.Text = "SUBMIT KEY  >"
            SubmitButton.BackgroundColor3 = Color3.fromRGB(151, 27, 48)

            local requestMessages = {
                HTTP_REQUEST_UNAVAILABLE = "Your executor does not support HTTP requests.",
                REQUEST_FAILED = "Could not contact ScoopHub. Check your connection and try again.",
                INVALID_SERVER_RESPONSE = "ScoopHub returned an invalid response. Please try again.",
                SERVER_ERROR = "ScoopHub's key server is temporarily unavailable.",
            }

            setStatus(
                requestMessages[requestError] or "Could not contact ScoopHub. Please try again.",
                Color3.fromRGB(244, 91, 110)
            )
            return
        end

        if data.valid == true then
            saveKey(value)

            local remainingText = ""
            if tonumber(data.expiresIn) then
                local seconds = math.max(0, tonumber(data.expiresIn))
                local days = math.floor(seconds / 86400)
                local hours = math.floor((seconds % 86400) / 3600)

                if days > 0 then
                    remainingText = string.format(" (%dd %dh remaining)", days, hours)
                elseif hours > 0 then
                    remainingText = string.format(" (%dh remaining)", hours)
                end
            end

            setStatus(
                "Key accepted" .. remainingText .. ". Loading Auto Buy Pet…",
                Color3.fromRGB(92, 226, 171)
            )

            task.wait(0.35)

            local loaded, loadError = loadMainScript()
            if loaded then
                gui:Destroy()
                return
            end

            isChecking = false
            SubmitButton.Text = "SUBMIT KEY  >"
            SubmitButton.BackgroundColor3 = Color3.fromRGB(151, 27, 48)
            setStatus(loadError or "Key is valid, but the script could not be loaded.", Color3.fromRGB(244, 91, 110))
            return
        end

        isChecking = false
        SubmitButton.Text = "SUBMIT KEY  >"
        SubmitButton.BackgroundColor3 = Color3.fromRGB(151, 27, 48)

        local reason = tostring(data.reason or data.error or "unknown")
        local messages = {
            expired = "This key has expired. Generate or enter a new key.",
            revoked = "This key has been revoked.",
            hwid_mismatch = "This key is already linked to another device. Reset its HWID in the ScoopHub dashboard.",
            not_found = "That ScoopHub key does not exist.",
            invalid_key_format = "That key format is invalid.",
        }

        local message = messages[reason] or "Key check failed. Please try again."
        if reason == "revoked" and data.banReason and tostring(data.banReason) ~= "" then
            message = "This key has been revoked: " .. tostring(data.banReason)
        end

        setStatus(message, Color3.fromRGB(244, 91, 110))
    end)
end

PasteButton.Activated:Connect(function()
    local clipboard = getClipboardText()
    if clipboard and clipboard ~= "" then
        KeyBox.Text = clipboard
        setStatus("Key pasted. Press Submit Key to continue.", Color3.fromRGB(165, 211, 255))
    else
        setStatus("Clipboard access is unavailable in this executor.", Color3.fromRGB(244, 91, 110))
    end
end)

SubmitButton.Activated:Connect(function()
    checkKey(KeyBox.Text)
end)

KeyBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        checkKey(KeyBox.Text)
    end
end)

DiscordButton.Activated:Connect(function()
    copyText(DiscordInvite)
    setStatus("Discord invite copied to clipboard.", Color3.fromRGB(165, 211, 255))
end)

LootLabsButton.Activated:Connect(function()
    copyText(KeyUrl)
    setStatus("Get Key link copied to clipboard.", Color3.fromRGB(165, 211, 255))
end)

LinkvertiseButton.Activated:Connect(function()
    copyText(WebsiteUrl)
    setStatus("ScoopHub website copied to clipboard.", Color3.fromRGB(165, 211, 255))
end)

CloseButton.Activated:Connect(function()
    gui:Destroy()
end)

local savedKey = loadSavedKey()
if savedKey and savedKey ~= "" then
    KeyBox.Text = savedKey
    setStatus("Saved key found. Checking it…", Color3.fromRGB(245, 199, 80))
    task.defer(function()
        checkKey(savedKey)
    end)
end

local dragging = false
local dragStart
local startPosition
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

local camera = workspace.CurrentCamera
if camera and UserInputService.TouchEnabled then
    -- Keep every control intact on phones, just at roughly 70% desktop size.
    new("UIScale", {
        Scale = math.clamp(camera.ViewportSize.X / 400, 0.55, 0.70),
    }, Main)
elseif camera and camera.ViewportSize.X < 470 then
    new("UIScale", {
        Scale = math.clamp(camera.ViewportSize.X / 440, 0.62, 0.92),
    }, Main)
end
