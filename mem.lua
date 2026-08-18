-- =====================================================
-- AUTO BUY PET — ScoopHub Style (Custom GUI)
-- Searchable dropdown + Pets bought counter + Auto Server Hop + Config Save
-- KRNL Auto-Rejoin with queue_on_teleport support
-- =====================================================

-- =========================================================
-- KRNL AUTO-REJOIN SETUP (Must be at the very top)
-- =========================================================
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- =========================================================
-- ANTI-IDLE INPUT
-- Sends one brief Space press every three minutes, and immediately when
-- Roblox reports this player as idle. Older handlers are replaced on rerun.
-- =========================================================
if _G.ScoopHubAutoBuyPetIdleConnection then
    pcall(function()
        _G.ScoopHubAutoBuyPetIdleConnection:Disconnect()
    end)
end

_G.ScoopHubAutoBuyPetIdleToken = (_G.ScoopHubAutoBuyPetIdleToken or 0) + 1
local antiIdleToken = _G.ScoopHubAutoBuyPetIdleToken
local VirtualInputManager = game:GetService("VirtualInputManager")

local function antiIdleJump()
    local sentInput = pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
    if not sentInput then
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then humanoid.Jump = true end
    end
end

_G.ScoopHubAutoBuyPetIdleConnection = LocalPlayer.Idled:Connect(antiIdleJump)

task.spawn(function()
    while _G.ScoopHubAutoBuyPetIdleToken == antiIdleToken do
        task.wait(180)
        if _G.ScoopHubAutoBuyPetIdleToken == antiIdleToken then antiIdleJump() end
    end
end)

-- Detect KRNL and set up queue_on_teleport
local isKRNL = typeof(queue_on_teleport) == "function"
local SCRIPT_URL = "https://raw.githubusercontent.com/ShigeSC/GUi/refs/heads/main/men.lua"

-- Function to queue this script for execution after teleport
local function setupAutoRejoinQueue()
    if isKRNL and queue_on_teleport then
        -- KRNL specific: queue this script to run after teleport
        local success, err = pcall(function()
            queue_on_teleport([[
                -- Auto-resume script for KRNL
                repeat task.wait() until game:IsLoaded()
                task.wait(2)
                
                -- Fetch and execute the main script
                local success, result = pcall(function()
                    local scriptContent = game:HttpGet("]] .. SCRIPT_URL .. [[")
                    return loadstring(scriptContent)
                end)
                
                if success and result then
                    result()
                else
                    warn("[AutoBuyPet] Failed to load script after teleport: " .. tostring(result))
                end
            ]])
        end)
        
        if success then
            print("[AutoBuyPet] KRNL queue_on_teleport registered successfully")
        else
            warn("[AutoBuyPet] Failed to register queue_on_teleport: " .. tostring(err))
        end
    end
end

-- Keep exactly one teleport-state listener across script re-executions.
-- The actual server-hop handler is assigned later, after the hop controller exists.
if _G.ScoopHubAutoBuyPetTeleportConnection then
    pcall(function()
        _G.ScoopHubAutoBuyPetTeleportConnection:Disconnect()
    end)
end

_G.ScoopHubTeleportStateHandler = nil
_G.ScoopHubAutoBuyPetTeleportConnection = LocalPlayer.OnTeleport:Connect(function(teleportState)
    local handler = _G.ScoopHubTeleportStateHandler
    if type(handler) == "function" then
        handler(teleportState)
    elseif teleportState == Enum.TeleportState.Started then
        -- Fallback used only if another script teleports before the controller is ready.
        if saveSettings then
            pcall(saveSettings)
        end
    end
end)

-- Keep exactly one TeleportInitFailed listener too. This gives the controller
-- the actual Roblox failure reason (for example GameFull / Error 772), which
-- LocalPlayer.OnTeleport alone does not provide.
if _G.ScoopHubAutoBuyPetTeleportInitFailedConnection then
    pcall(function()
        _G.ScoopHubAutoBuyPetTeleportInitFailedConnection:Disconnect()
    end)
end

_G.ScoopHubTeleportInitFailedHandler = nil
_G.ScoopHubTeleport772Handler = nil
_G.ScoopHubAutoBuyPetTeleportInitFailedConnection = TeleportService.TeleportInitFailed:Connect(
    function(player, teleportResult, errorMessage, placeId, teleportOptions)
        local handler = _G.ScoopHubTeleportInitFailedHandler
        if type(handler) == "function" then
            handler(player, teleportResult, errorMessage, placeId, teleportOptions)
        end
    end
)

-- KRNL queue setup. This is intentionally called only immediately before
-- the script itself starts an automatic rejoin.
local function enableKRNLQueue()
    if isKRNL then
        setupAutoRejoinQueue()
    end
end

-- =========================================================
-- SERVICES & MODULES
-- =========================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local ShovelNet = Networking.Shovel

-- =========================================================
-- THEME
-- =========================================================
local Theme = {
    Bg = Color3.fromRGB(9, 5, 8),
    Panel = Color3.fromRGB(22, 10, 14),
    PanelLine = Color3.fromRGB(154, 44, 53),
    Red = Color3.fromRGB(231, 47, 59),
    RedDark = Color3.fromRGB(145, 28, 39),
    Text = Color3.fromRGB(255, 111, 120),
    TextDim = Color3.fromRGB(190, 73, 84),
    Success = Color3.fromRGB(99, 215, 163),
    White = Color3.fromRGB(246, 244, 252),
    TabBg = Color3.fromRGB(35, 16, 22),
    InputBg = Color3.fromRGB(49, 41, 49),
    InputText = Color3.fromRGB(238, 240, 249),
    Avatar = Color3.fromRGB(124, 106, 115),
    ObsidianTop = Color3.fromRGB(39, 11, 17),
    ObsidianMid = Color3.fromRGB(8, 5, 8),
    ObsidianLow = Color3.fromRGB(34, 8, 11),
    Surface = Color3.fromRGB(22, 10, 14),
    Surface2 = Color3.fromRGB(37, 17, 23),
    Surface3 = Color3.fromRGB(52, 31, 37),
    Stroke = Color3.fromRGB(179, 52, 63),
    Muted = Color3.fromRGB(199, 170, 176),
    Glow = Color3.fromRGB(211, 64, 75),
    Font = Enum.Font.GothamBold,
    FontBody = Enum.Font.Gotham,
}

local Config = {
    Discord = "discord.gg/WxgqUa9Qz",
    DiscordIcon = "rbxassetid://94434236999817",
    Logo = "rbxassetid://90541504618217",
    LogoColor = Color3.fromRGB(255, 255, 255),
    Title = "AUTO BUY PET",
    Version = "v2.1",
    SubTitle = "by ScoopHub",
    HubNameColor = Color3.fromRGB(242, 92, 101),
    SubTitleColor = Color3.fromRGB(166, 174, 187),
}

local function New(className, props, parent)
    local inst = Instance.new(className)
    for prop, value in pairs(props) do
        inst[prop] = value
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function GetGuiParent()
    local ok, gethui_ok = pcall(function() return gethui and gethui() end)
    if ok and gethui_ok then
        return gethui_ok
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function MakeDraggable(handle, frame)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function SafeTween(Object, Info, Properties)
    if not Object then return nil end
    local Success, Tween = pcall(function()
        return TweenService:Create(Object, Info, Properties)
    end)
    if Success and Tween then
        local Played = pcall(function() Tween:Play() end)
        if Played then return Tween end
    end
    return nil
end

-- =========================================================
-- STATE
-- =========================================================
local petProtectEnabled = false
local targetPetNames = {}
local targetDisplayText = "Select pets..."
local maxPetPrice = 50000000
local petWalkSpeed = 32
local petPunchRadius = 16
local fastCFrameMove = false
-- Optional high-value spawn priorities. When enabled, a matching size is
-- secured before the normal selected-pet list.
local buyBigPetsPriority = false
local buyHugePetsPriority = false
local petProtectThread = nil
local petsBought = 0
totalSpent = 0
serverHops = 0
serverHopInProgress = false
pendingPetDelivery = false
pendingPetDeliveryName = ""
pendingPetDeliveryCount = 0
local autoRejoin = false
local customJobIds = {}
local customJobIndex = 1
local petHistory = {}
targetPresets = {}
activityFeed = {}
dailyDate = os.date("%Y-%m-%d")
dailyPetsBought = 0
local cleanupEnabled = false
local autoSellEnabled = false
local webhookEnabled = false
local webhookUrl = ""
sellWebhookEnabled = false
sellWebhookUrl = ""
-- Built-in global log: paste your Discord webhook URL between the quotes.
-- Leave blank to disable global pet-secured alerts.
local GLOBAL_WEBHOOK_URL = "https://discord.com/api/webhooks/1531370747170259145/CcWzZasAXVgedW4TOP-3AXXT7WUryve7loGpr2zUGFCIU7h22zSroSPBLbAM2v9SceZe"
-- Built-in private log: paste your private Discord webhook URL between the quotes.
-- This log shows the full player name and is not shown anywhere in the GUI.
-- Leave blank to disable private pet-secured alerts.
local PRIVATE_WEBHOOK_URL = "https://discord.com/api/webhooks/1537116981348802670/Cp6Ej5csTO0688_IRyKsoBBiehLUwwdibrCOL5x-r-sjzTGrJT5tB45nUedP71x3NQBM"
function censorGlobalPlayerName(name)
    local text = tostring(name or "Player")
    return text:sub(1, math.min(3, #text)) .. "******"
end

webhookPetAlerts = true
webhookSellAlerts = true
webhookDisconnectAlerts = true
sellBatchInterval = 15
webhookUrlsVisible = false
lastWebhookStatus = "No webhook sent yet"
local lastDisconnectWebhookAt = 0
local sessionStartedAt = os.time()
autoBuyRuntimeSeconds = 0
autoBuyRuntimeStartedAt = nil
local lastAutoSaveAt = 0
-- This records the saved toggle state until the worker function exists.
local resumePetProtectOnLoad = false
local playerStats = {}
local currentPlayerKey = tostring(LocalPlayer.UserId)

-- Fallback rarity table for games that do not expose a Rarity attribute on
-- the wild-pet model. Rarity is now used for display only.
local PET_RARITY_OVERRIDES = {
    Frog = "Common",
    Bunny = "Common",
    Owl = "Uncommon",
    Dog = "Uncommon",
    Deer = "Rare",
    Turtle = "Rare",
    Hedgehog = "Rare",
    Turkey = "Rare",
    Robin = "Legendary",
    Bee = "Legendary",
    Butterfly = "Legendary",
    Squirrel = "Legendary",
    Swan = "Legendary",
    Jackalope = "Legendary",
    Monkey = "Mythic",
    JandelMonkey = "Mythic",
    GoldenDragonfly = "Mythic",
    Unicorn = "Mythic",
    Bear = "Mythic",
    BaldEagle = "Mythic",
    Firefly = "Mythic",
    Fox = "Mythic",
    Wolf = "Mythic",
    Scarecrow = "Mythic",
    Raccoon = "Super",
    BlackDragon = "Super",
    IceSerpent = "Super",
    ShadowDragon = "Super",
    RedPanda = "Super",
    Kitsune = "Secret",
}

-- Lower ranks are used for History order; target selection reverses this so
-- rarer WildPets are secured before lower-rarity targets.
local RARITY_RANK = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Legendary = 4,
    Mythic = 5,
    Super = 6,
    Secret = 7,
    Unknown = 0,
}

local function storeCurrentPlayerStats()
    playerStats[currentPlayerKey] = {
        username = LocalPlayer.Name,
        petsBought = petsBought,
        spent = totalSpent,
        serverHops = serverHops,
        runtimeSeconds = autoBuyRuntimeSeconds + ((petProtectEnabled and autoBuyRuntimeStartedAt)
            and math.max(0, os.time() - autoBuyRuntimeStartedAt) or 0),
        history = petHistory,
        dailyDate = dailyDate,
        dailyPetsBought = dailyPetsBought,
    }
end

local function resetAccountStats()
    -- The configuration file is shared by the executor, but the dashboard is
    -- not. Always start with a clean dashboard before restoring a UserId's own
    -- record so another account can never inherit these values in memory.
    petsBought = 0
    totalSpent = 0
    serverHops = 0
    autoBuyRuntimeSeconds = 0
    autoBuyRuntimeStartedAt = nil
    petHistory = {}
    dailyDate = os.date("%Y-%m-%d")
    dailyPetsBought = 0
end

local AllPets = {
    "Frog", "Bunny", "Owl", "Dog", "Deer", "Turtle", "Hedgehog", "Turkey",
    "Robin", "Bee", "Butterfly", "Squirrel", "Swan", "Jackalope",
    "Monkey", "JandelMonkey", "GoldenDragonfly", "Unicorn", "Bear", "BaldEagle",
    "Firefly", "Fox", "Wolf", "Scarecrow", "Raccoon", "BlackDragon", "IceSerpent",
    "ShadowDragon", "RedPanda", "Kitsune"
}

local selectedPets = {}
for _, name in ipairs(targetPetNames) do
    selectedPets[name] = true
end
local selectedSellPets = {}

local function formatList(items)
    if type(items) ~= "table" or #items == 0 then return "None" end
    if #items <= 2 then return table.concat(items, ", ") end
    return items[1] .. ", " .. items[2] .. " +" .. (#items - 2) .. " more"
end

local function Notify(title, content, duration)
    duration = duration or 3
    local notifGui = New("ScreenGui", { Name = "PetNotif", ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, GetGuiParent())
    local frame = New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 350, 1, -30),
        Size = UDim2.new(0, 280, 0, 60),
    }, notifGui)
    New("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
    New("UIStroke", { Color = Theme.Red, Thickness = 1, Transparency = 0.5 }, frame)
    New("TextLabel", {
        Text = title,
        Font = Theme.Font,
        TextSize = 14,
        TextColor3 = Theme.White,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -24, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)
    New("TextLabel", {
        Text = content,
        Font = Theme.FontBody,
        TextSize = 12,
        TextColor3 = Theme.Muted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 28),
        Size = UDim2.new(1, -24, 0, 24),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, frame)

    SafeTween(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Position = UDim2.new(1, -30, 1, -30)
    })
    task.delay(duration, function()
        if notifGui.Parent then
            SafeTween(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
                Position = UDim2.new(1, 350, 1, -30)
            })
            task.delay(0.5, function()
                if notifGui.Parent then notifGui:Destroy() end
            end)
        end
    end)
end

function addActivity(message)
    table.insert(activityFeed, 1, os.date("%H:%M") .. "  " .. tostring(message))
    while #activityFeed > 5 do
        table.remove(activityFeed)
    end
    if ActivityLabel then
        ActivityLabel.Text = "ACTIVITY  •  " .. (activityFeed[1] or "Waiting for activity")
    end
    if ActivityList then
        rebuildActivityFeed()
    end
end

local function formatWebhookElapsed()
    local elapsed = autoBuyRuntimeSeconds
    if petProtectEnabled and autoBuyRuntimeStartedAt then
        elapsed = elapsed + math.max(0, os.time() - autoBuyRuntimeStartedAt)
    end
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    end
    return string.format("%d:%02d", minutes, seconds)
end

local function formatWebhookNumber(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    return text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- =========================================================
-- WEBHOOK ALERTS
-- =========================================================
local WEBHOOK_RARITY_COLORS = {
    Common = 5763719,
    Uncommon = 5793266,
    Rare = 3447003,
    Legendary = 16766720,
    Mythic = 10181046,
    Super = 15158332,
    Secret = 11184810,
}
local WEBHOOK_PET_PAGE_NAMES = {
    GoldenDragonfly = "Golden Dragonfly",
    BlackDragon = "Black Dragon",
    IceSerpent = "Ice Serpent",
    ShadowDragon = "Shadow Dragon",
    JandelMonkey = "Jandel Monkey",
    RedPanda = "Red Panda",
}

local function stripPetSizePrefix(petName)
    local name = tostring(petName or "")
    name = name:gsub("^Huge%s+", "")
    name = name:gsub("^Big%s+", "")
    return name
end

local webhookPetImageCache = {}

local function getWebhookPetImage(petName)
    if webhookPetImageCache[petName] then
        return webhookPetImageCache[petName]
    end

    local basePetName = stripPetSizePrefix(petName)
    local pageName = WEBHOOK_PET_PAGE_NAMES[basePetName] or basePetName
    local imageUrl = nil

    -- Pet file names on the wiki are not consistently "PetName.png". Ask the
    -- wiki for the page thumbnail so every pet can use its real image.
    pcall(function()
        local apiUrl = "https://growagarden2.fandom.com/api.php?action=query&format=json&prop=pageimages&piprop=thumbnail&pithumbsize=256&titles="
            .. HttpService:UrlEncode(pageName)
        local pageData = HttpService:JSONDecode(game:HttpGet(apiUrl))
        local pages = pageData and pageData.query and pageData.query.pages
        local pageKey = pages and next(pages)
        local page = pageKey and pages[pageKey]
        imageUrl = page and page.thumbnail and page.thumbnail.source
    end)

    -- A fallback still gives Discord a chance to resolve pages whose API image
    -- is temporarily unavailable.
    imageUrl = imageUrl or ("https://growagarden2.fandom.com/wiki/Special:FilePath/"
        .. HttpService:UrlEncode(pageName .. ".png"))
    webhookPetImageCache[petName] = imageUrl
    return imageUrl
end

local function sendWebhook(title, description, color, fields, thumbnailUrl, destinationUrl, bypassMainToggle)
    local targetUrl = destinationUrl or webhookUrl
    if (not bypassMainToggle and not webhookEnabled) or targetUrl == "" then return false end

    local requestFn = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
    if type(requestFn) ~= "function" then
        warn("[AutoBuyPet] Webhook request function is unavailable in this executor.")
        lastWebhookStatus = "Last webhook failed: request unavailable"
        return false
    end

    local embed = {
        title = title,
        description = description,
        color = color or 15158203,
        -- Discord renders the timestamp below this footer as "Today at 3:18 AM".
        footer = { text = "AUTO BUY PET v2.1  •  discord.gg/WxgqUa9Qz" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    if fields then embed.fields = fields end
    if thumbnailUrl then embed.thumbnail = { url = thumbnailUrl } end

    local body = HttpService:JSONEncode({
        username = "ScoopHub | AUTO BUY PET v2.1",
        embeds = { embed },
    })

    local requestOk, response = pcall(function()
        return requestFn({
            Url = targetUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
    end)
    local statusCode = requestOk and type(response) == "table" and (response.StatusCode or response.Status)
    if not requestOk or (statusCode and (tonumber(statusCode) or 0) >= 300) then
        task.wait(0.8)
        requestOk, response = pcall(function()
            return requestFn({
                Url = targetUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end)
        statusCode = requestOk and type(response) == "table" and (response.StatusCode or response.Status)
        if not requestOk then
            lastWebhookStatus = "Last webhook failed: " .. tostring(response)
            if WebhookStatusLabel then
                WebhookStatusLabel.Text = lastWebhookStatus
                WebhookStatusLabel.TextColor3 = Theme.Text
            end
            return false, tostring(response)
        end
        if statusCode and (tonumber(statusCode) or 0) >= 300 then
            lastWebhookStatus = "Last webhook failed: HTTP " .. tostring(statusCode)
            if WebhookStatusLabel then
                WebhookStatusLabel.Text = lastWebhookStatus
                WebhookStatusLabel.TextColor3 = Theme.Text
            end
            return false, "Discord returned HTTP " .. tostring(statusCode)
        end
    end
    lastWebhookStatus = "Last sent: " .. tostring(title)
    if WebhookStatusLabel then
        WebhookStatusLabel.Text = lastWebhookStatus
        WebhookStatusLabel.TextColor3 = Theme.Success
    end
    return true
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(message)
        local lowerMessage = string.lower(tostring(message or ""))

        -- Some clients surface Error 772 through the Roblox error UI before or
        -- alongside TeleportInitFailed. Forward it to the same hop controller so
        -- it can immediately choose another Job ID from the already-fetched batch.
        if lowerMessage:find("error code: 772", 1, true) or lowerMessage:find("server is full", 1, true) then
            local fullHandler = _G.ScoopHubTeleport772Handler
            if type(fullHandler) == "function" then
                fullHandler(message)
            end
        end

        if webhookDisconnectAlerts and (lowerMessage:find("error code: 279", 1, true) or lowerMessage:find("failed to connect", 1, true))
            and tick() - lastDisconnectWebhookAt > 20 then
            lastDisconnectWebhookAt = tick()
            sendWebhook(
                "⚠️ CONNECTION LOST",
                "Roblox reported a connection failure (**Error 279**).",
                15158332,
                {
                    { name = "TOTAL PETS", value = tostring(petsBought), inline = true },
                }
            )
        end
    end)
end)

-- ScoopHub cleanup behavior: remove decoration/effects, simplify geometry,
-- and lighten the scene for maximum FPS.
local function applyLowCPU()
    if not cleanupEnabled then return end

    local Workspace = game:GetService("Workspace")
    local Lighting = game:GetService("Lighting")
    for _, item in ipairs(Workspace:GetDescendants()) do
        local nameLower = item.Name:lower()
        if nameLower:find("plant") or nameLower:find("tree") or nameLower:find("flower")
            or nameLower:find("bush") or nameLower:find("crop") or nameLower:find("grass")
            or nameLower:find("vine") or nameLower:find("mushroom") or nameLower:find("visual")
            or nameLower:find("decoration") or nameLower:find("leaf") or nameLower:find("petals") then
            pcall(function() item:Destroy() end)
        end
    end

    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("BasePart") then
            item.Material = Enum.Material.SmoothPlastic
            item.Color = Color3.fromRGB(180, 180, 200)
            item.Reflectance = 0
        elseif item:IsA("Texture") or item:IsA("Decal") or item:IsA("ParticleEmitter")
            or item:IsA("Trail") or item:IsA("Beam") then
            pcall(function() item:Destroy() end)
        end
    end

    Lighting.GlobalShadows = false
    Lighting.Brightness = 2
    Lighting.ClockTime = 12
    Lighting.FogEnd = 100000
end

local function setCleanupEnabled(enabled)
    cleanupEnabled = enabled == true
    if cleanupEnabled then
        applyLowCPU()
    end
end

-- The sell remote accepts one PetId at a time. Pet Tools keep that unique ID
-- in their PetId attribute, so names are used only to decide which tools are
-- allowed to be sold.
local lastPetSellAt = 0
local petSellBusy = false

local function sellSelectedBackpackPets()
    if petSellBusy or not autoSellEnabled or tick() - lastPetSellAt < sellBatchInterval then
        return
    end
    petSellBusy = true
    lastPetSellAt = tick()

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local attempted = 0
    local soldByName = {}
    local sellCandidates = {}
    if backpack and Networking.NPCS and Networking.NPCS.SellPet then
        for _, tool in ipairs(backpack:GetChildren()) do
            if autoSellEnabled and tool:IsA("Tool") and selectedSellPets[tool.Name] then
                local petId = tool:GetAttribute("PetId")
                local isFavorite = tool:GetAttribute("Favorite") == true
                    or tool:GetAttribute("IsFavorite") == true
                if not isFavorite and type(petId) == "string" and petId ~= "" then
                    sellCandidates[tool.Name] = sellCandidates[tool.Name] or {}
                    table.insert(sellCandidates[tool.Name], tool)
                end
            end
        end

        for petName, tools in pairs(sellCandidates) do
            for index = 1, #tools do
                local tool = tools[index]
                local petId = tool:GetAttribute("PetId")
                if autoSellEnabled and type(petId) == "string" and petId ~= "" then
                    local ok, err = pcall(function()
                        Networking.NPCS.SellPet:Fire(petId)
                    end)
                    if ok then
                        attempted = attempted + 1
                        soldByName[petName] = (soldByName[petName] or 0) + 1
                    else
                        warn("[AutoBuyPet] Could not sell " .. petName .. ": " .. tostring(err))
                    end
                    task.wait(0.12)
                end
            end
        end
    end

    if attempted > 0 then
        print("[AutoBuyPet] Sent sell request for " .. attempted .. " selected pet(s).")
        addActivity("Sold " .. attempted .. " pet(s)")
        local soldLines = {}
        for petName, amount in pairs(soldByName) do
            table.insert(soldLines, petName .. " x" .. amount)
        end
        table.sort(soldLines)
        if webhookSellAlerts and sellWebhookEnabled and sellWebhookUrl ~= "" then
            sendWebhook(
                "PETS SOLD",
                "Selected Backpack pets were sold.",
                15105570,
                {
                    { name = "SOLD", value = table.concat(soldLines, "\n"), inline = false },
                    { name = "TOTAL SOLD", value = tostring(attempted), inline = true },
                    { name = "SESSION PETS", value = formatWebhookNumber(petsBought), inline = true },
                },
                nil,
                sellWebhookUrl,
                true
            )
        end
    end
    petSellBusy = false
end

-- =========================================================
-- CONFIG SAVE / LOAD
-- =========================================================
local CONFIG_FOLDER = "AutoBuyPet"
-- Every Roblox account gets its own file. Multiple accounts running on the
-- same device can now save at the same time without overwriting one another.
local CONFIG_FILE = CONFIG_FOLDER .. "/settings_" .. tostring(LocalPlayer.UserId) .. ".json"
local LEGACY_CONFIG_FILE = CONFIG_FOLDER .. "/settings.json"

-- Make saveSettings global so teleport handler can access it
function saveSettings()
    if not (writefile and isfolder and makefolder) then return end

    storeCurrentPlayerStats()

    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)

    local data = {
        selectedPets = {},
        selectedSellPets = {},
        maxPetPrice = maxPetPrice,
        petWalkSpeed = petWalkSpeed,
        petPunchRadius = petPunchRadius,
        fastCFrameMove = fastCFrameMove,
        buyBigPetsPriority = buyBigPetsPriority,
        buyHugePetsPriority = buyHugePetsPriority,
        autoRejoin = autoRejoin,
        cleanupEnabled = cleanupEnabled,
        autoSellEnabled = autoSellEnabled,
        webhookEnabled = webhookEnabled,
        webhookUrl = webhookUrl,
        sellWebhookEnabled = sellWebhookEnabled,
        sellWebhookUrl = sellWebhookUrl,
        webhookPetAlerts = webhookPetAlerts,
        webhookSellAlerts = webhookSellAlerts,
        webhookDisconnectAlerts = webhookDisconnectAlerts,
        sellBatchInterval = sellBatchInterval,
        customJobIds = customJobIds,
        customJobIndex = customJobIndex,
        petProtectEnabled = petProtectEnabled,
        playerStats = playerStats,
        targetPresets = targetPresets,
        dailyDate = dailyDate,
        dailyPetsBought = dailyPetsBought,
    }

    for name, isOn in pairs(selectedPets) do
        if isOn then
            table.insert(data.selectedPets, name)
        end
    end
    for name, isOn in pairs(selectedSellPets) do
        if isOn then
            table.insert(data.selectedSellPets, name)
        end
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if ok then
        pcall(writefile, CONFIG_FILE, encoded)
    end
end

local function loadSettings()
    if not (readfile and isfile) then return end

    local exists = false
    local sourceFile = CONFIG_FILE
    pcall(function()
        exists = isfile(CONFIG_FILE)
    end)
    -- One-time compatibility with the old shared settings file. The contents
    -- are copied into this account's separate file after loading.
    if not exists then
        pcall(function()
            exists = isfile(LEGACY_CONFIG_FILE)
            if exists then sourceFile = LEGACY_CONFIG_FILE end
        end)
    end
    if not exists then return end

    local rawSettings = nil
    local success, data = pcall(function()
        rawSettings = readfile(sourceFile)
        return HttpService:JSONDecode(rawSettings)
    end)
    if not success or type(data) ~= "table" then return end

    if sourceFile == LEGACY_CONFIG_FILE and rawSettings then
        pcall(function()
            if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
            writefile(CONFIG_FILE, rawSettings)
        end)
    end

    -- Restore selected pets
    table.clear(selectedPets)
    if type(data.selectedPets) == "table" then
        for _, name in ipairs(data.selectedPets) do
            selectedPets[name] = true
        end
    end
    maxPetPrice = tonumber(data.maxPetPrice) or 50000000
    petWalkSpeed = tonumber(data.petWalkSpeed) or 32
    petPunchRadius = tonumber(data.petPunchRadius) or 16
    fastCFrameMove = data.fastCFrameMove == true
    buyBigPetsPriority = data.buyBigPetsPriority == true
    buyHugePetsPriority = data.buyHugePetsPriority == true
    autoRejoin = data.autoRejoin == true
    cleanupEnabled = data.cleanupEnabled == true
    autoSellEnabled = data.autoSellEnabled == true
    webhookEnabled = data.webhookEnabled == true
    webhookUrl = type(data.webhookUrl) == "string" and data.webhookUrl or ""
    sellWebhookEnabled = data.sellWebhookEnabled == true
    sellWebhookUrl = type(data.sellWebhookUrl) == "string" and data.sellWebhookUrl or ""
    webhookPetAlerts = data.webhookPetAlerts ~= false
    webhookSellAlerts = data.webhookSellAlerts ~= false
    webhookDisconnectAlerts = data.webhookDisconnectAlerts ~= false
    sellBatchInterval = math.clamp(tonumber(data.sellBatchInterval) or 15, 10, 30)
    if type(data.customJobIds) == "table" then
        customJobIds = data.customJobIds
    end
    table.clear(selectedSellPets)
    if type(data.selectedSellPets) == "table" then
        for _, name in ipairs(data.selectedSellPets) do
            selectedSellPets[name] = true
        end
    end
    customJobIndex = math.max(1, tonumber(data.customJobIndex) or 1)
    resumePetProtectOnLoad = data.petProtectEnabled == true
    if type(data.playerStats) == "table" then
        playerStats = data.playerStats
    end
    if type(data.targetPresets) == "table" then
        targetPresets = data.targetPresets
    end
    resetAccountStats()
    local savedStats = playerStats[currentPlayerKey]
    if type(savedStats) == "table" then
        petsBought = tonumber(savedStats.petsBought) or 0
        totalSpent = tonumber(savedStats.spent) or 0
        serverHops = tonumber(savedStats.serverHops) or 0
        autoBuyRuntimeSeconds = math.max(0, tonumber(savedStats.runtimeSeconds) or 0)
        if type(savedStats.history) == "table" then
            petHistory = savedStats.history
        end
        if savedStats.dailyDate == os.date("%Y-%m-%d") then
            dailyDate = savedStats.dailyDate
            dailyPetsBought = math.max(0, tonumber(savedStats.dailyPetsBought) or 0)
        end
    end
    -- Keep the in-memory setting identical to the JSON value. The worker is
    -- still started later through setPetProtectEnabled after setup is ready.
    petProtectEnabled = resumePetProtectOnLoad
end

-- =========================================================
-- ROOT GUI
-- =========================================================
local GuiParent = GetGuiParent()
local ExistingGui = GuiParent:FindFirstChild("AutoBuyPetGui")
if ExistingGui then
    ExistingGui:Destroy()
end

local ScreenGui = New("ScreenGui", {
    Name = "AutoBuyPetGui",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, GuiParent)

local DropShadowHolder = New("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 520, 0, 500),
    ZIndex = 0,
    Name = "DropShadowHolder",
    Position = UDim2.new(0.5, 0, 0.5, 0),
}, ScreenGui)

-- Keep desktop sizing unchanged. Android uses the same layout and controls,
-- just scaled down so the complete window fits comfortably on a phone.
isAndroidDevice = false
pcall(function()
    isAndroidDevice = UserInputService:GetPlatform() == Enum.Platform.Android
end)
if isAndroidDevice then
    New("UIScale", {
        Name = "AndroidScale",
        Scale = 0.70,
    }, DropShadowHolder)
end

local DropShadow = New("ImageLabel", {
    Image = "rbxassetid://6015897843",
    ImageColor3 = Color3.fromRGB(4, 5, 8),
    ImageTransparency = 0.38,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(49, 49, 450, 450),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 520, 0, 500),
    ZIndex = 0,
    Name = "DropShadow",
}, DropShadowHolder)

local Main = New("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Bg,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 520, 0, 500),
    Name = "Main",
}, DropShadow)

New("UICorner", { CornerRadius = UDim.new(0, 8) }, Main)
New("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.ObsidianTop),
        ColorSequenceKeypoint.new(0.52, Theme.ObsidianMid),
        ColorSequenceKeypoint.new(1, Theme.ObsidianLow),
    }),
    Rotation = 16,
}, Main)

do
    local StarField = New("Frame", {
        Name = "StarField",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 1,
    }, Main)
    local starRandom = Random.new(LocalPlayer.UserId)
    local starColors = {
        Color3.fromRGB(255, 218, 218),
        Color3.fromRGB(246, 141, 151),
        Color3.fromRGB(255, 205, 156),
    }
    for i = 1, 80 do
        local bright = starRandom:NextNumber() > 0.76
        local diameter = bright and starRandom:NextInteger(2, 3) or 1
        local star = New("Frame", {
            Name = "Star",
            BackgroundColor3 = starColors[starRandom:NextInteger(1, #starColors)],
            BackgroundTransparency = bright and starRandom:NextNumber(0.18, 0.36) or starRandom:NextNumber(0.48, 0.72),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(starRandom:NextNumber(0.01, 0.99), 0, starRandom:NextNumber(0.02, 0.98), 0),
            Size = UDim2.new(0, diameter, 0, diameter),
            ZIndex = 1,
        }, StarField)
        New("UICorner", { CornerRadius = UDim.new(1, 0) }, star)
    end
end

New("UIStroke", {
    Color = Theme.Stroke,
    Thickness = 1,
    Transparency = 0.86,
}, Main)

-- =========================================================
-- TITLE BAR
-- =========================================================
local MinButton
local CloseButton
do
local TitleBar = New("Frame", {
    Name = "TitleBar",
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.999,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 38),
}, Main)

local LogoImage = New("ImageLabel", {
    Image = Configuaogo,
    ImageColor3 = Config.LogoColor,
    ImageTransparency = 0,
    ScaleType = Enum.ScaleType.Fit,
    ClipsDescendants = true,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 11, 0.5, 0),
    Size = UDim2.new(0, 26, 0, 26),
    Name = "LogoImage",
}, TitleBar)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, LogoImage)

local HubTitle = New("TextLabel", {
    Font = Theme.Font,
    Text = Config.Title,
    TextColor3 = Config.HubNameColor,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 40, 0.5, -7),
    Size = UDim2.new(0, 0, 0, 16),
    AutomaticSize = Enum.AutomaticSize.X,
    Name = "HubTitle",
}, TitleBar)
New("UIStroke", { Color = Theme.Red, Thickness = 0.4 }, HubTitle)

-- Keep the release number visually lighter than the main product name.
local TitleVersion = New("TextLabel", {
    Font = Theme.FontBody,
    Text = Config.Version,
    TextColor3 = Color3.fromRGB(241, 153, 160),
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 40, 0.5, -7),
    Size = UDim2.new(0, 0, 0, 16),
    AutomaticSize = Enum.AutomaticSize.X,
    Name = "TitleVersion",
}, TitleBar)

local titleWidth = TextService:GetTextSize(Config.Title, 13, Theme.Font, Vector2.new(1000, 16)).X
TitleVersion.Position = UDim2.new(0, 45 + titleWidth, 0.5, -7)

local HubSubTitle = New("TextLabel", {
    Font = Theme.FontBody,
    Text = Config.SubTitle,
    TextColor3 = Config.SubTitleColor,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 40, 0.5, 7),
    Size = UDim2.new(0, 0, 0, 12),
    AutomaticSize = Enum.AutomaticSize.X,
    Name = "HubSubTitle",
}, TitleBar)

local DiscordPill = New("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Surface3,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 150, 0, 22),
    Name = "DiscordPill",
}, TitleBar)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, DiscordPill)
New("UIStroke", { Color = Theme.Red, Thickness = 1, Transparency = 0.62 }, DiscordPill)

local DiscordIcon = New("ImageLabel", {
    Image = Config.DiscordIcon,
    ImageColor3 = Color3.fromRGB(255, 255, 255),
    ScaleType = Enum.ScaleType.Fit,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 8, 0.5, 0),
    Size = UDim2.new(0, 14, 0, 14),
    Name = "DiscordIcon",
}, DiscordPill)

local DiscordText = New("TextLabel", {
    Font = Theme.Font,
    Text = Config.Discord,
    TextColor3 = Color3.fromRGB(235, 235, 240),
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 27, 0, 0),
    Size = UDim2.new(1, -32, 1, 0),
    Name = "DiscordText",
}, DiscordPill)

local DiscordTextWidth = math.clamp(#tostring(Config.Discord) * 7, 40, 170)
DiscordPill.Size = UDim2.new(0, math.clamp(DiscordTextWidth + 38, 72, 190), 0, 22)

local DiscordButton = New("TextButton", {
    Font = Theme.Font,
    Text = "",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    Name = "DiscordButton",
}, DiscordPill)
DiscordButton.Activated:Connect(function()
    local copyToClipboard = setclipboard or toclipboard or set_clipboard
    local copied = false

    if type(copyToClipboard) == "function" then
        copied = pcall(copyToClipboard, Config.Discord)
    end

    local existingNotification = GuiParent:FindFirstChild("ScoopHubDiscordNotification")
    if existingNotification then
        existingNotification:Destroy()
    end

    local notifGui = New("ScreenGui", {
        Name = "ScoopHubDiscordNotification",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    }, GuiParent)

    local notifFrame = New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.new(1, 400, 1, -30),
        Size = UDim2.new(0, 320, 0, 70),
    }, notifGui)
    New("UICorner", { CornerRadius = UDim.new(0, 8) }, notifFrame)

    local titleScoop = New("TextLabel", {
        Font = Theme.Font,
        Text = "ScoopHub",
        TextColor3 = Color3.fromRGB(235, 235, 240),
        TextSize = 14,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(0, 0, 0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, notifFrame)

    local titleDiscord = New("TextLabel", {
        Font = Theme.Font,
        Text = " Discord",
        TextColor3 = Theme.Red,
        TextSize = 14,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(0, 0, 0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, notifFrame)
    task.defer(function()
        if titleDiscord.Parent then
            titleDiscord.Position = UDim2.new(0, 12 + titleScoop.TextBounds.X, 0, 8)
        end
    end)

    local closeNotif = New("TextButton", {
        Text = "X",
        Font = Theme.Font,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 6),
        Size = UDim2.new(0, 22, 0, 22),
    }, notifFrame)
    closeNotif.Activated:Connect(function()
        notifGui:Destroy()
    end)

    New("TextLabel", {
        Font = Theme.FontBody,
        Text = copied and ("Copied to clipboard: " .. Config.Discord)
            or "Your executor could not copy the Discord invite.",
        TextColor3 = Color3.fromRGB(150, 150, 150),
        TextSize = 13,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 34),
        Size = UDim2.new(1, -24, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, notifFrame)

    SafeTween(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Position = UDim2.new(1, -30, 1, -30),
    })

    task.delay(5, function()
        if notifGui.Parent then
            SafeTween(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
                Position = UDim2.new(1, 400, 1, -30),
            })
            task.delay(0.5, function()
                if notifGui.Parent then notifGui:Destroy() end
            end)
        end
    end)
end)

MinButton = New("TextButton", {
    Name = "MinimizeButton",
    Text = "-",
    Font = Theme.Font,
    TextSize = 20,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.25,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -42, 0.5, 0),
    Size = UDim2.new(0, 25, 0, 25),
    BorderSizePixel = 0,
}, TitleBar)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, MinButton)

CloseButton = New("TextButton", {
    Name = "CloseButton",
    Text = "X",
    Font = Theme.Font,
    TextSize = 18,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.25,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.new(0, 25, 0, 25),
    BorderSizePixel = 0,
}, TitleBar)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, CloseButton)

local DecideFrame = New("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = Theme.Red,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 0, 0, 38),
    Size = UDim2.new(1, 0, 0, 1),
    Name = "DecideFrame",
}, Main)
New("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.ObsidianMid),
        ColorSequenceKeypoint.new(0.5, Theme.Red),
        ColorSequenceKeypoint.new(1, Theme.ObsidianMid),
    }),
}, DecideFrame)

MakeDraggable(TitleBar, DropShadowHolder)
end

local Body = New("Frame", {
    Name = "Body",
    Position = UDim2.new(0, 0, 0, 39),
    Size = UDim2.new(1, 0, 1, -39),
    BackgroundTransparency = 1,
}, Main)

-- =========================================================
-- HELPERS
-- =========================================================
local function CreatePanel(parent, name, position, size, titleText)
    local Panel = New("Frame", {
        Name = name,
        Position = position,
        Size = size,
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, parent)
    New("UICorner", { CornerRadius = UDim.new(0, 8) }, Panel)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 17, 24)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 8, 12)),
        }),
        Rotation = 20,
    }, Panel)
    New("UIStroke", { Color = Theme.PanelLine, Thickness = 1.1, Transparency = 0.42 }, Panel)
    New("TextLabel", {
        Text = titleText,
        Font = Theme.Font,
        TextSize = 11,
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 6),
        Size = UDim2.new(1, -20, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Panel)
    return Panel
end

-- =========================================================
-- NAVIGATION
-- =========================================================
local TabBar = New("Frame", {
    Name = "TabBar",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 8),
    Size = UDim2.new(1, -24, 0, 28),
}, Body)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, TabBar)
New("UIStroke", { Color = Theme.PanelLine, Thickness = 1, Transparency = 0.42 }, TabBar)

local TabUnderline = New("Frame", {
    Name = "TabUnderline",
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -2),
    Size = UDim2.new(1 / 4, 0, 0, 2),
    ZIndex = 2,
}, TabBar)

local AutoBuyPage = New("Frame", {
    Name = "AutoBuyPage",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 42),
    Size = UDim2.new(1, 0, 1, -48),
}, Body)

local SettingsPage = New("ScrollingFrame", {
    Name = "SettingsPage",
    BackgroundTransparency = 1,
    Visible = false,
    Position = UDim2.new(0, 0, 0, 42),
    Size = UDim2.new(1, 0, 1, -48),
    CanvasSize = UDim2.new(0, 0, 0, 656),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Red,
    BorderSizePixel = 0,
}, Body)

local HistoryPage = New("Frame", {
    Name = "HistoryPage",
    BackgroundTransparency = 1,
    Visible = false,
    Position = UDim2.new(0, 0, 0, 42),
    Size = UDim2.new(1, 0, 1, -48),
}, Body)

local WebhookPage = New("Frame", {
    Name = "WebhookPage",
    BackgroundTransparency = 1,
    Visible = false,
    Position = UDim2.new(0, 0, 0, 42),
    Size = UDim2.new(1, 0, 1, -48),
}, Body)

local updateHistoryUI
local TabButtons = {}
local function CreateTabButton(name, order)
    local button = New("TextButton", {
        Name = name .. "Tab",
        Text = name,
        Font = Theme.Font,
        TextSize = 11,
        TextColor3 = Theme.TextDim,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new((order - 1) / 4, 0, 0, 0),
        Size = UDim2.new(1 / 4, 0, 1, 0),
    }, TabBar)
    TabButtons[name] = button
    return button
end

local AutoBuyTab = CreateTabButton("DASHBOARD", 1)
local SettingsTab = CreateTabButton("SETUP", 2)
local HistoryTab = CreateTabButton("HISTORY", 3)
local WebhookTab = CreateTabButton("WEBHOOK", 4)

local function setActiveTab(tabName)
    AutoBuyPage.Visible = tabName == "DASHBOARD"
    SettingsPage.Visible = tabName == "SETUP"
    HistoryPage.Visible = tabName == "HISTORY"
    WebhookPage.Visible = tabName == "WEBHOOK"
    for name, button in pairs(TabButtons) do
        local active = name == tabName
        button.TextColor3 = active and Theme.Red or Theme.TextDim
        button.Font = active and Theme.Font or Theme.FontBody
        button.BackgroundTransparency = 1
    end
    local tabOrder = tabName == "DASHBOARD" and 0
        or (tabName == "SETUP" and 1 or (tabName == "HISTORY" and 2 or 3))
    SafeTween(TabUnderline, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(tabOrder / 4, 0, 1, -2),
    })
    if tabName ~= "SETUP" then
        local dropdown = Body:FindFirstChild("PetDropdown")
        if dropdown then dropdown.Visible = false end
        local importModal = Body:FindFirstChild("BackupImportModal")
        if importModal then importModal.Visible = false end
        local presetsModal = Body:FindFirstChild("PresetModal")
        if presetsModal then presetsModal.Visible = false end
    end
    if tabName == "HISTORY" and updateHistoryUI then
        updateHistoryUI()
    end
end

AutoBuyTab.Activated:Connect(function() setActiveTab("DASHBOARD") end)
SettingsTab.Activated:Connect(function() setActiveTab("SETUP") end)
HistoryTab.Activated:Connect(function() setActiveTab("HISTORY") end)
WebhookTab.Activated:Connect(function() setActiveTab("WEBHOOK") end)
setActiveTab("DASHBOARD")

-- =========================================================
-- LEFT PANEL — SELECT PETS
-- =========================================================
local PetsPanel = CreatePanel(SettingsPage, "PetsPanel", UDim2.new(0, 12, 0, 12), UDim2.new(0, 240, 0, 200), "BUY TARGET PETS")

local SelectPetsButton = New("TextButton", {
    Name = "SelectPetsButton",
    Text = "Select pets...",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.InputText,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.new(0, 10, 0, 30),
    Size = UDim2.new(1, -52, 0, 28),
}, PetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SelectPetsButton)
New("UIPadding", { PaddingLeft = UDim.new(0, 10) }, SelectPetsButton)

local RefreshPetsButton = New("TextButton", {
    Name = "RefreshPetsButton",
    Text = "",
    Font = Theme.Font,
    TextSize = 16,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -34, 0, 30),
    Size = UDim2.new(0, 24, 0, 28),
}, PetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, RefreshPetsButton)
New("UIStroke", { Color = Theme.Red, Thickness = 1 }, RefreshPetsButton)

New("ImageLabel", {
    Name = "RefreshIcon",
    Image = "rbxassetid://122032243989747",
    ImageColor3 = Theme.White,
    ScaleType = Enum.ScaleType.Fit,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 14, 0, 14),
}, RefreshPetsButton)

local SelectedCountLabel = New("TextLabel", {
    Name = "SelectedCountLabel",
    Text = "1 pet selected",
    Font = Theme.FontBody,
    TextSize = 12,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 66),
    Size = UDim2.new(1, -20, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left,
}, PetsPanel)

local SelectAllPetsButton = New("TextButton", {
    Name = "SelectAllPetsButton",
    Text = "SELECT ALL",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 92),
    Size = UDim2.new(0.5, -14, 0, 24),
}, PetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SelectAllPetsButton)
SelectAllPetsButton.Visible = false

local RemoveAllPetsButton = New("TextButton", {
    Name = "RemoveAllPetsButton",
    Text = "REMOVE ALL",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 4, 0, 92),
    Size = UDim2.new(0.5, -14, 0, 24),
}, PetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, RemoveAllPetsButton)
RemoveAllPetsButton.Visible = false

ManageTargetsButton = New("TextButton", {
    Text = "MANAGE TARGETS", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 92), Size = UDim2.new(1, -20, 0, 24),
}, PetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ManageTargetsButton)

New("TextLabel", {
    Name = "SizePriorityTitle",
    Text = "SIZE PRIORITY",
    Font = Theme.Font,
    TextSize = 9,
    TextColor3 = Theme.Red,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 122),
    Size = UDim2.new(1, -20, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, PetsPanel)

local function createSizePriorityRow(name, title, subtitle, yPosition)
    New("TextLabel", {
        Name = name .. "Label",
        Text = title,
        Font = Theme.Font,
        TextSize = 10,
        TextColor3 = Theme.White,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, yPosition),
        Size = UDim2.new(1, -76, 0, 13),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, PetsPanel)
    New("TextLabel", {
        Name = name .. "Hint",
        Text = subtitle,
        Font = Theme.FontBody,
        TextSize = 9,
        TextColor3 = Theme.Muted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, yPosition + 12),
        Size = UDim2.new(1, -76, 0, 12),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, PetsPanel)
    local toggle = New("TextButton", {
        Name = name .. "Toggle",
        Text = "",
        BackgroundColor3 = Theme.RedDark,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -58, 0, yPosition + 3),
        Size = UDim2.new(0, 48, 0, 22),
    }, PetsPanel)
    New("UICorner", { CornerRadius = UDim.new(1, 0) }, toggle)
    local knob = New("Frame", {
        Name = name .. "Knob",
        BackgroundColor3 = Theme.White,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
    }, toggle)
    New("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
    return toggle, knob
end

local BigPetsPriorityToggle, BigPetsPriorityKnob = createSizePriorityRow(
    "BigPetsPriority", "BUY BIG PETS", "Prioritize Big pets when they spawn", 140
)
local HugePetsPriorityToggle, HugePetsPriorityKnob = createSizePriorityRow(
    "HugePetsPriority", "BUY HUGE PETS", "Highest priority when they spawn", 166
)
local rebuildTargetList

local function updatePetSizePriorityUI()
    BigPetsPriorityToggle.BackgroundColor3 = buyBigPetsPriority and Theme.Success or Theme.RedDark
    HugePetsPriorityToggle.BackgroundColor3 = buyHugePetsPriority and Theme.Success or Theme.RedDark
    SafeTween(BigPetsPriorityKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = buyBigPetsPriority and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    })
    SafeTween(HugePetsPriorityKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = buyHugePetsPriority and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    })
end

BigPetsPriorityToggle.Activated:Connect(function()
    buyBigPetsPriority = not buyBigPetsPriority
    updatePetSizePriorityUI()
    rebuildTargetList()
end)

HugePetsPriorityToggle.Activated:Connect(function()
    buyHugePetsPriority = not buyHugePetsPriority
    updatePetSizePriorityUI()
    rebuildTargetList()
end)

-- =========================================================
-- REJOIN PANEL (now single toggle)
-- =========================================================
local RejoinPanel = CreatePanel(
    SettingsPage,
    "RejoinPanel",
    UDim2.new(0, 264, 0, 148),
    UDim2.new(1, -276, 0, 64),
    "SERVER HOP"
)

local RejoinToggle = New("TextButton", {
    Name = "RejoinToggle",
    Text = "SERVER HOP: OFF",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 28),
    Size = UDim2.new(1, -20, 0, 28),
}, RejoinPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, RejoinToggle)

local function updateRejoinUI()
    if autoRejoin then
        RejoinToggle.Text = "AUTO HOP: ON"
        RejoinToggle.BackgroundColor3 = Theme.Success
    else
        RejoinToggle.Text = "AUTO HOP: OFF"
        RejoinToggle.BackgroundColor3 = Theme.RedDark
    end
end

RejoinToggle.Activated:Connect(function()
    autoRejoin = not autoRejoin
    updateRejoinUI()
    saveSettings()
    
    if autoRejoin then
        Notify("Auto Server Hop", "Will hop when no pets left: " .. tostring(isKRNL) .. "", 2)
    else
        Notify("Auto Server Hop", "Disabled", 2)
    end
end)

local SellPetsPanel = CreatePanel(SettingsPage, "SellPetsPanel", UDim2.new(0, 264, 0, 12), UDim2.new(1, -276, 0, 126), "SELL TARGET PETS")

local SelectSellPetsButton = New("TextButton", {
    Name = "SelectSellPetsButton",
    Text = "Select pets...",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.InputText,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.new(0, 10, 0, 30),
    Size = UDim2.new(1, -20, 0, 28),
}, SellPetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SelectSellPetsButton)
New("UIPadding", { PaddingLeft = UDim.new(0, 10) }, SelectSellPetsButton)

local SellSelectedCountLabel = New("TextLabel", {
    Name = "SellSelectedCountLabel",
    Text = "0 pets selected for sell",
    Font = Theme.FontBody,
    TextSize = 12,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 66),
    Size = UDim2.new(1, -132, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SellPetsPanel)

local SelectAllSellPetsButton = New("TextButton", {
    Name = "SelectAllSellPetsButton",
    Text = "SELECT ALL",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 90),
    Size = UDim2.new(0.5, -14, 0, 24),
}, SellPetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SelectAllSellPetsButton)
SelectAllSellPetsButton.Visible = false

local RemoveAllSellPetsButton = New("TextButton", {
    Name = "RemoveAllSellPetsButton",
    Text = "REMOVE ALL",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 4, 0, 90),
    Size = UDim2.new(0.5, -14, 0, 24),
}, SellPetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, RemoveAllSellPetsButton)
RemoveAllSellPetsButton.Visible = false

ManageSellButton = New("TextButton", {
    Text = "MANAGE", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
    Position = UDim2.new(1, -112, 0, 62), Size = UDim2.new(0, 102, 0, 24),
}, SellPetsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ManageSellButton)

local SellToggle = New("TextButton", {
    Name = "SellToggle",
    Text = "",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -58, 0, 90),
    Size = UDim2.new(0, 48, 0, 24),
}, SellPetsPanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, SellToggle)
SellToggleKnob = New("Frame", {
    BackgroundColor3 = Theme.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(0, 18, 0, 18),
}, SellToggle)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, SellToggleKnob)

New("TextLabel", {
    Text = "AUTO SELL", Font = Theme.Font, TextSize = 11, TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 94), Size = UDim2.new(1, -80, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SellPetsPanel)

-- Dropdown
local PetDropdown = New("Frame", {
    Name = "PetDropdown",
    BackgroundColor3 = Theme.Surface2,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 50,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, 220, 0, 240),
}, Body)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, PetDropdown)
New("UIStroke", { Color = Theme.Red, Thickness = 1.5 }, PetDropdown)

local PetSearchBox = New("TextBox", {
    Name = "PetSearchBox",
    PlaceholderText = "Search pets...",
    Text = "",
    Font = Theme.FontBody,
    TextSize = 13,
    TextColor3 = Theme.White,
    PlaceholderColor3 = Color3.fromRGB(160, 160, 165),
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Position = UDim2.new(0, 4, 0, 4),
    Size = UDim2.new(1, -8, 0, 26),
    ZIndex = 51,
}, PetDropdown)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, PetSearchBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, PetSearchBox)

local PetDropdownScroll = New("ScrollingFrame", {
    Name = "PetDropdownScroll",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 4, 0, 34),
    Size = UDim2.new(1, -8, 1, -38),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Red,
    ZIndex = 51,
}, PetDropdown)
New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, PetDropdownScroll)
local petDropdownMode = "buy"
local rebuildSellList
local updateSellUI
local TargetLabel

rebuildTargetList = function()
    targetPetNames = {}
    for name, isOn in pairs(selectedPets) do
        if isOn then
            table.insert(targetPetNames, name)
        end
    end
    table.sort(targetPetNames)

    local displayTargets = table.clone(targetPetNames)
    if buyBigPetsPriority then table.insert(displayTargets, "BIG PETS") end
    if buyHugePetsPriority then table.insert(displayTargets, "HUGE PETS") end
    targetDisplayText = #displayTargets > 0 and formatList(displayTargets) or "Select pets..."

    local count = #targetPetNames
    if count == 0 then
        SelectPetsButton.Text = "Select pets..."
        SelectedCountLabel.Text = "0 pets selected"
    elseif count == 1 then
        SelectPetsButton.Text = targetPetNames[1]
        SelectedCountLabel.Text = "1 pet selected"
    else
        SelectPetsButton.Text = formatList(targetPetNames)
        SelectedCountLabel.Text = count .. " pets selected"
    end
    if TargetLabel then
        TargetLabel.Text = "TARGETS  •  " .. targetDisplayText
    end
    saveSettings()
end

SelectAllPetsButton.Activated:Connect(function()
    for _, petName in ipairs(AllPets) do
        selectedPets[petName] = true
    end
    rebuildTargetList()
    PetDropdown.Visible = false
end)

RemoveAllPetsButton.Activated:Connect(function()
    table.clear(selectedPets)
    rebuildTargetList()
    PetDropdown.Visible = false
end)

SelectAllSellPetsButton.Activated:Connect(function()
    for _, petName in ipairs(AllPets) do
        selectedSellPets[petName] = true
    end
    rebuildSellList()
    PetDropdown.Visible = false
end)

RemoveAllSellPetsButton.Activated:Connect(function()
    table.clear(selectedSellPets)
    rebuildSellList()
    PetDropdown.Visible = false
end)

SellToggle.Activated:Connect(function()
    if not autoSellEnabled and next(selectedSellPets) == nil then
        Notify("Sell Pet", "Select at least one pet first.", 2)
        return
    end
    autoSellEnabled = not autoSellEnabled
    updateSellUI()
    saveSettings()
    Notify("Sell Pet", autoSellEnabled and "Enabled for selected Backpack pets." or "Disabled.", 2)
    if autoSellEnabled then
        task.spawn(sellSelectedBackpackPets)
    end
end)

local function UpdatePetDropdownPosition(button)
    local success = pcall(function()
        local basePos = Body.AbsolutePosition
        button = button or SelectPetsButton
        local btnPos = button.AbsolutePosition
        local btnSize = button.AbsoluteSize
        local x = btnPos.X - basePos.X
        local y = btnPos.Y - basePos.Y + btnSize.Y + 4
        PetDropdown.Position = UDim2.new(0, x, 0, y)
        PetDropdown.Size = UDim2.new(0, btnSize.X, 0, PetDropdown.Size.Y.Offset)
    end)
    if not success then
        PetDropdown.Position = UDim2.new(0, 22, 0, 78)
    end
end

local function BuildPetDropdown(filterText)
    for _, child in ipairs(PetDropdownScroll:GetChildren()) do
        -- Keep only the layout object. The bulk-action row is a Frame, so it
        -- must be cleared too or it stacks every time this dropdown opens.
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    local query = string.lower(tostring(filterText or ""))
    local filtered = {}
    for _, name in ipairs(AllPets) do
        if query == "" or string.find(string.lower(name), query, 1, true) then
            table.insert(filtered, name)
        end
    end

    local activeSelections = petDropdownMode == "sell" and selectedSellPets or selectedPets

    -- The compact dashboard keeps bulk actions here, inside the manager, instead
    -- of permanently taking space from the main page.
    local bulkActions = New("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0, ZIndex = 52,
    }, PetDropdownScroll)
    local selectAll = New("TextButton", {
        Text = "SELECT ALL", Font = Theme.Font, TextSize = 11, TextColor3 = Theme.White,
        BackgroundColor3 = Theme.RedDark, BorderSizePixel = 0,
        Size = UDim2.new(0.5, -3, 1, 0), ZIndex = 53,
        AutoButtonColor = false,
    }, bulkActions)
    New("UICorner", { CornerRadius = UDim.new(0, 4) }, selectAll)

    local clearAll = New("TextButton", {
        Text = "CLEAR ALL", Font = Theme.Font, TextSize = 11, TextColor3 = Theme.White,
        BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
        Position = UDim2.new(0.5, 3, 0, 0), Size = UDim2.new(0.5, -3, 1, 0),
        ZIndex = 53, AutoButtonColor = false,
    }, bulkActions)
    New("UICorner", { CornerRadius = UDim.new(0, 4) }, clearAll)

    selectAll.Activated:Connect(function()
        for _, petName in ipairs(AllPets) do
            activeSelections[petName] = true
        end
        if petDropdownMode == "sell" then rebuildSellList() else rebuildTargetList() end
        BuildPetDropdown(PetSearchBox.Text)
    end)

    clearAll.Activated:Connect(function()
        table.clear(activeSelections)
        if petDropdownMode == "sell" then rebuildSellList() else rebuildTargetList() end
        BuildPetDropdown(PetSearchBox.Text)
    end)

    if #filtered == 0 then
        New("TextLabel", {
            Text = "No matches",
            Font = Theme.FontBody,
            TextSize = 14,
            TextColor3 = Theme.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = 1,
        }, PetDropdownScroll)
        PetDropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 62)
        return
    end

    for i, petName in ipairs(filtered) do
        local isSelected = activeSelections[petName] == true
        local row = New("TextButton", {
            Name = "PetOption",
            Text = "",
            Font = Theme.Font,
            TextSize = 14,
            BackgroundColor3 = isSelected and Color3.fromRGB(55, 22, 30) or Theme.Surface2,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = i + 1,
            ZIndex = 52,
            AutoButtonColor = false,
        }, PetDropdownScroll)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, row)

        local check = New("TextLabel", {
            Text = isSelected and "✓" or "",
            Font = Theme.Font,
            TextSize = 14,
            TextColor3 = Theme.Success,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(0, 18, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 53,
        }, row)

        New("TextLabel", {
            Text = petName,
            Font = Theme.Font,
            TextSize = 14,
            TextColor3 = Theme.White,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 28, 0, 0),
            Size = UDim2.new(1, -36, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 53,
        }, row)

        row.MouseEnter:Connect(function()
            if not activeSelections[petName] then
                row.BackgroundColor3 = Theme.RedDark
            end
        end)
        row.MouseLeave:Connect(function()
            row.BackgroundColor3 = activeSelections[petName] and Color3.fromRGB(55, 22, 30) or Theme.Surface2
        end)

        row.Activated:Connect(function()
            activeSelections[petName] = not activeSelections[petName]
            check.Text = activeSelections[petName] and "✓" or ""
            row.BackgroundColor3 = activeSelections[petName] and Color3.fromRGB(55, 22, 30) or Theme.Surface2
            if petDropdownMode == "sell" then
                rebuildSellList()
            else
                rebuildTargetList()
            end
        end)
    end

    PetDropdownScroll.CanvasSize = UDim2.new(0, 0, 0, (#filtered * 32) + 30)
end

local function ClosePetDropdown()
    PetDropdown.Visible = false
end

SelectPetsButton.Activated:Connect(function()
    petDropdownMode = "buy"
    PetDropdown.Visible = not PetDropdown.Visible
    if PetDropdown.Visible then
        UpdatePetDropdownPosition()
        PetSearchBox.Text = ""
        BuildPetDropdown("")
    end
end)

RefreshPetsButton.Activated:Connect(function()
    BuildPetDropdown(PetSearchBox.Text)
end)

PetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    BuildPetDropdown(PetSearchBox.Text)
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if not PetDropdown.Visible then return end
    task.defer(function()
        local mousePos = UserInputService:GetMouseLocation()
        local hitObjects = GuiService:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
        local clickedInside = false
        for _, obj in ipairs(hitObjects) do
            if obj == PetDropdown or obj:IsDescendantOf(PetDropdown)
                or obj == SelectPetsButton or obj == SelectSellPetsButton or obj == RefreshPetsButton
                or obj == ManageTargetsButton or obj == ManageSellButton then
                clickedInside = true
                break
            end
        end
        if not clickedInside then
            ClosePetDropdown()
        end
    end)
end)

-- =========================================================
-- RIGHT PANEL — SETTINGS
-- =========================================================
SettingsPanel = CreatePanel(SettingsPage, "SettingsPanel", UDim2.new(0, 12, 0, 224), UDim2.new(1, -24, 0, 206), "BUY & MOVEMENT")

New("TextLabel", {
    Text = "Max Price",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 28),
    Size = UDim2.new(1/3, -16, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

local PriceBox = New("TextBox", {
    Name = "PriceBox",
    Text = "50000000",
    PlaceholderText = "50000000",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.InputText,
    PlaceholderColor3 = Theme.Muted,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 46),
    Size = UDim2.new(1/3, -16, 0, 28),
    ClearTextOnFocus = false,
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, PriceBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, PriceBox)

PriceBox.FocusLost:Connect(function()
    local num = tonumber(PriceBox.Text)
    if num then
        maxPetPrice = num
        saveSettings()
    else
        PriceBox.Text = tostring(maxPetPrice)
    end
end)

New("TextLabel", {
    Text = "Walk Speed (28-40)",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(1/3, 4, 0, 28),
    Size = UDim2.new(1/3, -16, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

local SpeedBox = New("TextBox", {
    Name = "SpeedBox",
    Text = "32",
    PlaceholderText = "32",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.InputText,
    PlaceholderColor3 = Theme.Muted,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    Position = UDim2.new(1/3, 4, 0, 46),
    Size = UDim2.new(1/3, -16, 0, 28),
    ClearTextOnFocus = false,
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SpeedBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, SpeedBox)

SpeedBox.FocusLost:Connect(function()
    local num = tonumber(SpeedBox.Text)
    if num then
        petWalkSpeed = math.clamp(num, 16, 100)
        SpeedBox.Text = tostring(petWalkSpeed)
        saveSettings()
    else
        SpeedBox.Text = tostring(petWalkSpeed)
    end
end)

New("TextLabel", {
    Text = "Punch Radius",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(2/3, -4, 0, 28),
    Size = UDim2.new(1/3, -8, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

local RadiusBox = New("TextBox", {
    Name = "RadiusBox",
    Text = "16",
    PlaceholderText = "16",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.InputText,
    PlaceholderColor3 = Theme.Muted,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    Position = UDim2.new(2/3, -4, 0, 46),
    Size = UDim2.new(1/3, -8, 0, 28),
    ClearTextOnFocus = false,
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, RadiusBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, RadiusBox)

RadiusBox.FocusLost:Connect(function()
    local num = tonumber(RadiusBox.Text)
    if num then
        petPunchRadius = math.clamp(num, 8, 40)
        RadiusBox.Text = tostring(petPunchRadius)
        saveSettings()
    else
        RadiusBox.Text = tostring(petPunchRadius)
    end
end)

SelectSellPetsButton.Activated:Connect(function()
    petDropdownMode = "sell"
    PetDropdown.Visible = not PetDropdown.Visible
    if PetDropdown.Visible then
        UpdatePetDropdownPosition(SelectSellPetsButton)
        PetSearchBox.Text = ""
        BuildPetDropdown("")
    end
end)

ManageTargetsButton.Activated:Connect(function()
    petDropdownMode = "buy"
    PetDropdown.Visible = true
    UpdatePetDropdownPosition(SelectPetsButton)
    PetSearchBox.Text = ""
    BuildPetDropdown("")
end)

ManageSellButton.Activated:Connect(function()
    petDropdownMode = "sell"
    PetDropdown.Visible = true
    UpdatePetDropdownPosition(SelectSellPetsButton)
    PetSearchBox.Text = ""
    BuildPetDropdown("")
end)

New("TextLabel", {
    Text = "Enable Cleanup",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 88),
    Size = UDim2.new(1, -100, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

New("TextLabel", {
    Text = "Remove plants, trees, and effects for better FPS",
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 103),
    Size = UDim2.new(1, -100, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

local CleanupToggle = New("TextButton", {
    Name = "CleanupToggle",
    Text = "",
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -62, 0, 91),
    Size = UDim2.new(0, 48, 0, 24),
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, CleanupToggle)
local CleanupKnob = New("Frame", {
    Name = "CleanupKnob",
    BackgroundColor3 = Theme.White,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 3, 0.5, 0),
    Size = UDim2.new(0, 18, 0, 18),
}, CleanupToggle)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, CleanupKnob)

local function updateCleanupUI()
    CleanupToggle.BackgroundColor3 = cleanupEnabled and Theme.Success or Theme.RedDark
    SafeTween(CleanupKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = cleanupEnabled and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    })
end

CleanupToggle.Activated:Connect(function()
    setCleanupEnabled(not cleanupEnabled)
    updateCleanupUI()
    saveSettings()
    Notify("Cleanup", cleanupEnabled and "ScoopHub cleanup enabled." or "Cleanup disabled. A rejoin restores removed visuals.", 2)
end)

New("TextLabel", {
    Text = "Fast CFrame Move",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 124),
    Size = UDim2.new(1, -100, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

New("TextLabel", {
    Text = "Instantly move beside selected WildPets",
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 139),
    Size = UDim2.new(1, -100, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

local CFrameMoveToggle = New("TextButton", {
    Name = "CFrameMoveToggle",
    Text = "",
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -62, 0, 127),
    Size = UDim2.new(0, 48, 0, 24),
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, CFrameMoveToggle)
local CFrameMoveKnob = New("Frame", {
    Name = "CFrameMoveKnob",
    BackgroundColor3 = Theme.White,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 3, 0.5, 0),
    Size = UDim2.new(0, 18, 0, 18),
}, CFrameMoveToggle)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, CFrameMoveKnob)

local function updateCFrameMoveUI()
    CFrameMoveToggle.BackgroundColor3 = fastCFrameMove and Theme.Success or Theme.RedDark
    SafeTween(CFrameMoveKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = fastCFrameMove and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    })
end

CFrameMoveToggle.Activated:Connect(function()
    fastCFrameMove = not fastCFrameMove
    updateCFrameMoveUI()
    saveSettings()
    Notify("Movement", fastCFrameMove and "Fast CFrame movement enabled." or "Normal walking enabled.", 2)
end)

New("TextLabel", {
    Text = "SETTINGS BACKUP",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 162),
    Size = UDim2.new(1, -24, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPanel)

local ExportSettingsButton = New("TextButton", {
    Name = "ExportSettingsButton",
    Text = "EXPORT",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 180),
    Size = UDim2.new(1/3, -16, 0, 22),
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ExportSettingsButton)

local ImportSettingsButton = New("TextButton", {
    Name = "ImportSettingsButton",
    Text = "IMPORT",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    Position = UDim2.new(1/3, 4, 0, 180),
    Size = UDim2.new(1/3, -16, 0, 22),
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ImportSettingsButton)

PresetsButton = New("TextButton", {
    Text = "PRESETS", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
    Position = UDim2.new(2/3, -4, 0, 180), Size = UDim2.new(1/3, -8, 0, 22),
}, SettingsPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, PresetsButton)

local BackupImportModal = New("Frame", {
    Name = "BackupImportModal",
    Visible = false,
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 18, 0, 74),
    Size = UDim2.new(1, -36, 0, 290),
    ZIndex = 80,
}, Body)
New("UICorner", { CornerRadius = UDim.new(0, 7) }, BackupImportModal)
New("UIStroke", { Color = Theme.Red, Thickness = 1.4 }, BackupImportModal)

New("TextLabel", {
    Text = "IMPORT SETTINGS BACKUP",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.White,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 10),
    Size = UDim2.new(1, -24, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 81,
}, BackupImportModal)

New("TextLabel", {
    Text = "Paste a backup created with Export. This replaces the current saved settings.",
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 32),
    Size = UDim2.new(1, -24, 0, 30),
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 81,
}, BackupImportModal)

local BackupImportBox = New("TextBox", {
    Name = "BackupImportBox",
    Text = "",
    PlaceholderText = "Paste settings JSON here...",
    MultiLine = true,
    ClearTextOnFocus = false,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.InputText,
    PlaceholderColor3 = Theme.Muted,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 68),
    Size = UDim2.new(1, -24, 0, 160),
    ZIndex = 81,
}, BackupImportModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, BackupImportBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, BackupImportBox)

local ConfirmImportButton = New("TextButton", {
    Text = "IMPORT BACKUP",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 1, -34),
    Size = UDim2.new(0.5, -16, 0, 22),
    ZIndex = 81,
}, BackupImportModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ConfirmImportButton)

local CancelImportButton = New("TextButton", {
    Text = "CANCEL",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 4, 1, -34),
    Size = UDim2.new(0.5, -16, 0, 22),
    ZIndex = 81,
}, BackupImportModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, CancelImportButton)

PresetModal = New("Frame", {
    Name = "PresetModal", Visible = false, BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
    Position = UDim2.new(0, 18, 0, 74), Size = UDim2.new(1, -36, 0, 290), ZIndex = 84,
}, Body)
New("UICorner", { CornerRadius = UDim.new(0, 7) }, PresetModal)
New("UIStroke", { Color = Theme.Red, Thickness = 1.4 }, PresetModal)
New("TextLabel", {
    Text = "TARGET PRESETS", Font = Theme.Font, TextSize = 13, TextColor3 = Theme.White,
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -56, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 85,
}, PresetModal)
PresetCloseButton = New("TextButton", {
    Text = "X", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.White, BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0, Position = UDim2.new(1, -34, 0, 8), Size = UDim2.new(0, 22, 0, 22), ZIndex = 85,
}, PresetModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, PresetCloseButton)
New("TextLabel", {
    Text = "Save the current selected target pets under a name, then load it anytime.",
    Font = Theme.FontBody, TextSize = 11, TextColor3 = Theme.Muted, BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 34), Size = UDim2.new(1, -24, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 85,
}, PresetModal)
PresetNameBox = New("TextBox", {
    Text = "", PlaceholderText = "Preset name...", Font = Theme.FontBody, TextSize = 12,
    TextColor3 = Theme.InputText, PlaceholderColor3 = Theme.Muted, BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0, ClearTextOnFocus = false, Position = UDim2.new(0, 12, 0, 60),
    Size = UDim2.new(1, -118, 0, 26), ZIndex = 85,
}, PresetModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, PresetNameBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, PresetNameBox)
SavePresetButton = New("TextButton", {
    Text = "SAVE", Font = Theme.Font, TextSize = 11, TextColor3 = Theme.White, BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0, Position = UDim2.new(1, -98, 0, 60), Size = UDim2.new(0, 86, 0, 26), ZIndex = 85,
}, PresetModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SavePresetButton)
PresetList = New("ScrollingFrame", {
    Name = "PresetList", BackgroundColor3 = Theme.Surface2, BackgroundTransparency = 0.18, BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 96), Size = UDim2.new(1, -24, 1, -108), CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Red, ZIndex = 85,
}, PresetModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, PresetList)
New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, PresetList)
New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.Name }, PresetList)

function rebuildPresetList()
    for _, child in ipairs(PresetList:GetChildren()) do
        if child.Name == "PresetRow" or child.Name == "EmptyPreset" then
            child:Destroy()
        end
    end
    local names = {}
    for presetName in pairs(targetPresets) do
        table.insert(names, presetName)
    end
    table.sort(names)
    if #names == 0 then
        New("TextLabel", {
            Name = "EmptyPreset", Text = "No presets saved yet.", Font = Theme.FontBody, TextSize = 11,
            TextColor3 = Theme.Muted, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 86,
        }, PresetList)
        return
    end
    for index, presetName in ipairs(names) do
        local savedTargets = targetPresets[presetName] or {}
        local row = New("Frame", {
            Name = "PresetRow", LayoutOrder = index, BackgroundColor3 = Theme.Surface3, BackgroundTransparency = 0.12,
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30), ZIndex = 86,
        }, PresetList)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
        New("TextLabel", {
            Text = presetName .. "  •  " .. #savedTargets .. " pet(s)", Font = Theme.FontBody, TextSize = 11,
            TextColor3 = Theme.White, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -102, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 87,
        }, row)
        local loadButton = New("TextButton", {
            Text = "LOAD", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White, BackgroundColor3 = Theme.RedDark,
            BorderSizePixel = 0, Position = UDim2.new(1, -88, 0, 4), Size = UDim2.new(0, 52, 0, 22), ZIndex = 87,
        }, row)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, loadButton)
        local deleteButton = New("TextButton", {
            Text = "X", Font = Theme.Font, TextSize = 11, TextColor3 = Theme.White, BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0, Position = UDim2.new(1, -30, 0, 4), Size = UDim2.new(0, 22, 0, 22), ZIndex = 87,
        }, row)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, deleteButton)
        loadButton.Activated:Connect(function()
            table.clear(selectedPets)
            for _, petName in ipairs(savedTargets) do
                selectedPets[petName] = true
            end
            rebuildTargetList()
            saveSettings()
            addActivity("Loaded preset " .. presetName)
            Notify("Presets", "Loaded " .. presetName, 2)
            PresetModal.Visible = false
        end)
        deleteButton.Activated:Connect(function()
            targetPresets[presetName] = nil
            saveSettings()
            rebuildPresetList()
        end)
    end
end

PresetsButton.Activated:Connect(function()
    PresetNameBox.Text = ""
    PresetModal.Visible = true
    rebuildPresetList()
end)
PresetCloseButton.Activated:Connect(function() PresetModal.Visible = false end)
SavePresetButton.Activated:Connect(function()
    local presetName = tostring(PresetNameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if presetName == "" then
        Notify("Presets", "Enter a preset name first.", 2)
        return
    end
    local savedTargets = {}
    for petName, enabled in pairs(selectedPets) do
        if enabled then table.insert(savedTargets, petName) end
    end
    table.sort(savedTargets)
    if #savedTargets == 0 then
        Notify("Presets", "Select at least one target pet first.", 2)
        return
    end
    targetPresets[presetName] = savedTargets
    saveSettings()
    rebuildPresetList()
    addActivity("Saved preset " .. presetName)
    Notify("Presets", "Saved " .. presetName, 2)
end)

-- =========================================================
-- SETTINGS TAB — OPTIONAL SERVER ROTATION
-- =========================================================
JobIdPanel = CreatePanel(SettingsPage, "JobIdPanel", UDim2.new(0, 12, 0, 442), UDim2.new(1, -24, 0, 200), "SERVER HOP ROTATION")

New("TextLabel", {
    Text = "Add Job IDs to hop through them in order. Leave empty for random 1-6 player servers.",
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 27),
    Size = UDim2.new(1, -24, 0, 18),
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, JobIdPanel)

local JobIdInput = New("TextBox", {
    Name = "JobIdInput",
    Text = "",
    PlaceholderText = "Paste a server Job ID...",
    Font = Theme.FontBody,
    TextSize = 12,
    TextColor3 = Theme.InputText,
    PlaceholderColor3 = Theme.Muted,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Position = UDim2.new(0, 12, 0, 50),
    Size = UDim2.new(1, -112, 0, 28),
}, JobIdPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, JobIdInput)
New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, JobIdInput)

local AddJobIdButton = New("TextButton", {
    Text = "ADD ID",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -92, 0, 50),
    Size = UDim2.new(0, 80, 0, 28),
}, JobIdPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, AddJobIdButton)

local JobIdsLabel = New("TextLabel", {
    Name = "JobIdsLabel",
    Visible = false,
    Text = "No saved Job IDs — random hopping is active.",
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 84),
    Size = UDim2.new(1, -112, 0, 42),
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, JobIdPanel)

local ClearJobIdsButton = New("TextButton", {
    Text = "CLEAR ALL",
    Font = Theme.Font,
    TextSize = 10,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -92, 1, -36),
    Size = UDim2.new(0, 80, 0, 24),
}, JobIdPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ClearJobIdsButton)

local JobIdList = New("ScrollingFrame", {
    Name = "JobIdList",
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 86),
    Size = UDim2.new(1, -24, 1, -130),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Red,
}, JobIdPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, JobIdList)
New("UIPadding", {
    PaddingTop = UDim.new(0, 4),
    PaddingBottom = UDim.new(0, 4),
    PaddingLeft = UDim.new(0, 5),
    PaddingRight = UDim.new(0, 5),
}, JobIdList)
New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, JobIdList)

local JobRouteLabel = New("TextLabel", {
    Name = "JobRouteLabel",
    Text = "Random 1-6 player servers are active.",
    Font = Theme.FontBody,
    TextSize = 10,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 1, -34),
    Size = UDim2.new(1, -112, 0, 22),
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, JobIdPanel)

local function updateJobIdsUI()
    if #customJobIds == 0 then
        JobIdsLabel.Text = "No saved Job IDs — random hopping is active."
        return
    end
    local lines = {}
    for index, jobId in ipairs(customJobIds) do
        local marker = index == customJobIndex and "Next: " or "      "
        table.insert(lines, marker .. index .. ". " .. tostring(jobId))
    end
    JobIdsLabel.Text = table.concat(lines, "\n")
end

local function rebuildJobIdList()
    for _, child in ipairs(JobIdList:GetChildren()) do
        if child.Name == "JobIdRow" or child.Name == "EmptyJobIds" then
            child:Destroy()
        end
    end

    if #customJobIds == 0 then
        JobRouteLabel.Text = "Random 1-6 player servers are active."
        New("TextLabel", {
            Name = "EmptyJobIds",
            Text = "No saved Job IDs. Add one above to use a custom rotation.",
            Font = Theme.FontBody,
            TextSize = 11,
            TextColor3 = Theme.Muted,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            TextXAlignment = Enum.TextXAlignment.Center,
        }, JobIdList)
        return
    end

    JobRouteLabel.Text = #customJobIds .. " saved server" .. (#customJobIds == 1 and " — rotates in order." or "s — rotates in order.")
    for index, jobId in ipairs(customJobIds) do
        local row = New("Frame", {
            Name = "JobIdRow",
            LayoutOrder = index,
            BackgroundColor3 = index == customJobIndex and Color3.fromRGB(62, 23, 31) or Theme.Surface3,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 28),
        }, JobIdList)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
        New("TextLabel", {
            Text = (index == customJobIndex and "NEXT  " or "") .. tostring(jobId),
            Font = Theme.FontBody,
            TextSize = 11,
            TextColor3 = index == customJobIndex and Theme.White or Theme.Muted,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -42, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local removeButton = New("TextButton", {
            Text = "X",
            Font = Theme.Font,
            TextSize = 12,
            TextColor3 = Theme.Text,
            BackgroundColor3 = Theme.RedDark,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -26, 0, 3),
            Size = UDim2.new(0, 22, 0, 22),
        }, row)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, removeButton)
        removeButton.Activated:Connect(function()
            table.remove(customJobIds, index)
            customJobIndex = #customJobIds > 0 and math.clamp(customJobIndex, 1, #customJobIds) or 1
            rebuildJobIdList()
            saveSettings()
        end)
    end
end

local function addJobId()
    local jobId = tostring(JobIdInput.Text or ""):gsub("%s+", "")
    if jobId == "" then
        Notify("Server Hop", "Paste a Job ID first.", 2)
        return
    end
    for _, existingId in ipairs(customJobIds) do
        if existingId == jobId then
            Notify("Server Hop", "That Job ID is already in the rotation.", 2)
            return
        end
    end
    table.insert(customJobIds, jobId)
    JobIdInput.Text = ""
    updateJobIdsUI()
    rebuildJobIdList()
    saveSettings()
end

rebuildSellList = function()
    local names = {}
    for name, isOn in pairs(selectedSellPets) do
        if isOn then
            table.insert(names, name)
        end
    end
    table.sort(names)

    local count = #names
    if count == 0 then
        SelectSellPetsButton.Text = "Select pets..."
        SellSelectedCountLabel.Text = "0 pets selected for sell"
    elseif count == 1 then
        SelectSellPetsButton.Text = names[1]
        SellSelectedCountLabel.Text = "1 pet selected for sell"
    else
        SelectSellPetsButton.Text = formatList(names)
        SellSelectedCountLabel.Text = count .. " pets selected for sell"
    end
    saveSettings()
end

updateSellUI = function()
    SellToggle.BackgroundColor3 = autoSellEnabled and Theme.Success or Theme.RedDark
    SafeTween(SellToggleKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = autoSellEnabled and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    })
end

AddJobIdButton.Activated:Connect(addJobId)
JobIdInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then addJobId() end
end)
ClearJobIdsButton.Activated:Connect(function()
    table.clear(customJobIds)
    customJobIndex = 1
    updateJobIdsUI()
    rebuildJobIdList()
    saveSettings()
    Notify("Server Hop", "Custom Job ID rotation cleared.", 2)
end)

-- =========================================================
-- SHARED MULTI-ACCOUNT SERVER CLAIMS
-- =========================================================
-- Stored behind one controller table so this very large Luau chunk does not
-- consume dozens of extra top-level local registers.
Theme.ServerHopClaims = Theme.ServerHopClaims or {}
do
    local C = Theme.ServerHopClaims
    C.Folder = "AutoBuyPet/ServerHopClaims"
    C.ClaimTTL = 90
    C.HeartbeatSeconds = 10
    C.FailedTTL = 75
    C.File = C.Folder .. "/claim_" .. tostring(LocalPlayer.UserId) .. ".json"
    C.SharedSupported = type(writefile) == "function"
        and type(readfile) == "function"
        and type(listfiles) == "function"
        and type(isfolder) == "function"
        and type(makefolder) == "function"
    C.OwnReservedJobId = nil
    C.FailedJobIds = {}
    C.VisitedJobIds = { [game.JobId] = true }
    C.SelectionSequence = 0
    C.ServerFetchSerial = 0
    C.DebugFile = "AutoBuyPet/ServerHopDebug_" .. tostring(LocalPlayer.UserId) .. ".txt"
    C.DebugLines = {}

    -- V12 shared server batch:
    -- All ScoopHub accounts on the same executor filesystem reuse one saved
    -- 100-server page instead of independently hitting games.roblox.com.
    C.SharedBatchTTL = 120
    C.SharedBatchHardTTL = 600
    C.RefreshIntentTTL = 12
    C.SharedBatchFile = C.Folder .. "/server_batch_" .. tostring(game.PlaceId) .. ".json"
    C.SharedCooldownFile = C.Folder .. "/server_batch_cooldown_" .. tostring(game.PlaceId) .. ".json"
    C.RefreshIntentFile = C.Folder .. "/refresh_" .. tostring(LocalPlayer.UserId) .. ".json"
    C.ExhaustedBatchIds = {}
    C.LastBatchId = nil
    C.MemoryNextPageCursor = nil
    C.MemoryRequestedCursor = nil
    C.MemoryBatchExhausted = false

    function C.Debug(message)
        local line = string.format("[%s] %s", os.date("%Y-%m-%d %H:%M:%S"), tostring(message or ""))
        print("[AutoBuyPet][ServerHopDebug] " .. tostring(message or ""))
        table.insert(C.DebugLines, line)
        while #C.DebugLines > 250 do table.remove(C.DebugLines, 1) end
        if type(writefile) == "function" then
            pcall(function()
                if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("AutoBuyPet") then
                    makefolder("AutoBuyPet")
                end
                writefile(C.DebugFile, table.concat(C.DebugLines, "\n"))
            end)
        end
    end

    function C.BodyPreview(body)
        if type(body) ~= "string" then return "<" .. typeof(body) .. ">" end
        local preview = body:sub(1, 320):gsub("[\r\n\t]+", " ")
        if #body > 320 then preview = preview .. "..." end
        return preview
    end

    function C.DecodeServerPage(body, transportName, statusCode, pageNumber, attemptNumber)
        if type(body) ~= "string" or body == "" then
            C.Debug(string.format(
                "page=%s attempt=%s transport=%s status=%s INVALID_BODY body=%s",
                tostring(pageNumber), tostring(attemptNumber), tostring(transportName),
                tostring(statusCode or "n/a"), C.BodyPreview(body)
            ))
            return nil, "empty/non-string response"
        end

        local decodeOk, decoded = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        if not decodeOk or type(decoded) ~= "table" then
            C.Debug(string.format(
                "page=%s attempt=%s transport=%s status=%s JSON_DECODE_FAILED len=%d preview=%s",
                tostring(pageNumber), tostring(attemptNumber), tostring(transportName),
                tostring(statusCode or "n/a"), #body, C.BodyPreview(body)
            ))
            return nil, "JSON decode failed"
        end

        if type(decoded.data) ~= "table" then
            C.Debug(string.format(
                "page=%s attempt=%s transport=%s status=%s WRONG_SHAPE preview=%s",
                tostring(pageNumber), tostring(attemptNumber), tostring(transportName),
                tostring(statusCode or "n/a"), C.BodyPreview(body)
            ))
            return nil, "response was JSON but not a Roblox server list"
        end

        C.Debug(string.format(
            "page=%s attempt=%s transport=%s status=%s OK servers=%d nextCursor=%s",
            tostring(pageNumber), tostring(attemptNumber), tostring(transportName),
            tostring(statusCode or "n/a"), #decoded.data, decoded.nextPageCursor and "yes" or "no"
        ))
        return decoded, nil
    end

    function C.FetchServerPage(url)
        -- V11 transport: exactly ONE network request when this account wins shared refresh ownership.
        -- Prefer the executor request API because it exposes StatusCode + Body.
        -- If the executor has no request API, fall back to ONE game:HttpGet call.
        -- There is intentionally NO second transport attempt inside this function.
        C.ServerFetchSerial = C.ServerFetchSerial + 1
        C.LastLookupRetryDelay = nil

        local stagger = 0.10 + (((LocalPlayer.UserId + C.ServerFetchSerial * 13) % 13) * 0.06)
        C.Debug(string.format(
            "server-list request=%d stagger=%.2fs mode=ONE_REQUEST_STATUS_AWARE",
            C.ServerFetchSerial, stagger
        ))
        task.wait(stagger)

        local requestFn = request
            or http_request
            or (http and http.request)
            or (syn and syn.request)

        if type(requestFn) == "function" then
            local callOk, response = pcall(function()
                return requestFn({
                    Url = url,
                    Method = "GET",
                    Headers = {
                        ["Accept"] = "application/json",
                    },
                })
            end)

            if not callOk then
                local errorText = tostring(response or "executor request failed")
                local lowerError = string.lower(errorText)
                if lowerError:find("429", 1, true)
                    or lowerError:find("too many requests", 1, true) then
                    C.LastLookupRetryDelay = 25 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 11)
                    C.Debug(string.format(
                        "ONE_REQUEST TRANSPORT_ERROR rate_limited=true cooldown=%ss error=%s",
                        tostring(C.LastLookupRetryDelay), errorText
                    ))
                    return nil, "Roblox server list is rate-limited (HTTP 429)"
                end

                C.LastLookupRetryDelay = 10 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 6)
                C.Debug(string.format(
                    "ONE_REQUEST TRANSPORT_ERROR rate_limited=false cooldown=%ss error=%s",
                    tostring(C.LastLookupRetryDelay), errorText
                ))
                return nil, "Executor server-list request failed"
            end

            local statusCode = type(response) == "table"
                and tonumber(response.StatusCode or response.Status or response.status)
                or nil
            local responseBody = type(response) == "table"
                and (response.Body or response.body or response.ResponseBody)
                or nil

            -- Honor Retry-After when the executor exposes response headers.
            local retryAfter = nil
            if type(response) == "table" and type(response.Headers or response.headers) == "table" then
                local headers = response.Headers or response.headers
                retryAfter = tonumber(
                    headers["Retry-After"]
                    or headers["retry-after"]
                    or headers["retry_after"]
                )
            end

            C.Debug(string.format(
                "ONE_REQUEST RESPONSE transport=executor status=%s len=%s",
                tostring(statusCode or "n/a"),
                type(responseBody) == "string" and tostring(#responseBody) or tostring(typeof(responseBody))
            ))

            if statusCode == 429 then
                C.LastLookupRetryDelay = math.max(
                    tonumber(retryAfter) or 0,
                    25 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 11)
                )
                C.Debug(string.format(
                    "ONE_REQUEST HTTP_429 cooldown=%ss preview=%s",
                    tostring(C.LastLookupRetryDelay), C.BodyPreview(responseBody)
                ))
                return nil, "Roblox server list is rate-limited (HTTP 429)"
            end

            if statusCode and (statusCode < 200 or statusCode >= 300) then
                C.LastLookupRetryDelay = 12 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 7)
                C.Debug(string.format(
                    "ONE_REQUEST HTTP_ERROR status=%s cooldown=%ss preview=%s",
                    tostring(statusCode), tostring(C.LastLookupRetryDelay), C.BodyPreview(responseBody)
                ))
                return nil, "Roblox server list returned HTTP " .. tostring(statusCode)
            end

            if type(responseBody) ~= "string" or responseBody == "" then
                -- Potassium previously returned an empty HttpGet body while the
                -- server-list endpoint was being throttled. Treat an empty 2xx/
                -- unknown-status body conservatively instead of retrying every 7s.
                C.LastLookupRetryDelay = 25 + ((LocalPlayer.UserId + C.ServerFetchSerial * 3) % 11)
                C.Debug(string.format(
                    "ONE_REQUEST EMPTY_BODY status=%s cooldown=%ss",
                    tostring(statusCode or "n/a"), tostring(C.LastLookupRetryDelay)
                ))
                return nil, "Roblox server list returned an empty response"
            end

            local lowerBody = string.lower(responseBody)
            if lowerBody:find("too many requests", 1, true)
                or lowerBody:find('"code":429', 1, true) then
                C.LastLookupRetryDelay = math.max(
                    tonumber(retryAfter) or 0,
                    25 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 11)
                )
                C.Debug(string.format(
                    "ONE_REQUEST BODY_RATE_LIMIT cooldown=%ss preview=%s",
                    tostring(C.LastLookupRetryDelay), C.BodyPreview(responseBody)
                ))
                return nil, "Roblox server list is rate-limited (HTTP 429)"
            end

            local decodeOk, page = pcall(function()
                return HttpService:JSONDecode(responseBody)
            end)
            if not decodeOk or type(page) ~= "table" or type(page.data) ~= "table" then
                C.LastLookupRetryDelay = 12 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 7)
                C.Debug(string.format(
                    "ONE_REQUEST JSON_INVALID status=%s len=%d preview=%s",
                    tostring(statusCode or "n/a"), #responseBody, C.BodyPreview(responseBody)
                ))
                return nil, "Roblox server list returned invalid data"
            end

            C.Debug(string.format(
                "ONE_REQUEST OK transport=executor status=%s servers=%d nextCursor=%s",
                tostring(statusCode or "n/a"), #page.data,
                page.nextPageCursor and "yes" or "no"
            ))
            return page, nil
        end

        -- Compatibility fallback for executors without request/http_request.
        -- Still only ONE network request for this batch.
        local requestOk, responseBody = pcall(function()
            return game:HttpGet(url)
        end)

        if not requestOk then
            local errorText = tostring(responseBody or "server-list request failed")
            local lowerError = string.lower(errorText)
            if lowerError:find("429", 1, true)
                or lowerError:find("too many requests", 1, true) then
                C.LastLookupRetryDelay = 25 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 11)
                C.Debug(string.format(
                    "ONE_REQUEST HTTPGET_ERROR rate_limited=true cooldown=%ss error=%s",
                    tostring(C.LastLookupRetryDelay), errorText
                ))
                return nil, "Roblox server list is rate-limited (HTTP 429)"
            end

            C.LastLookupRetryDelay = 10 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 6)
            C.Debug(string.format(
                "ONE_REQUEST HTTPGET_ERROR rate_limited=false cooldown=%ss error=%s",
                tostring(C.LastLookupRetryDelay), errorText
            ))
            return nil, "Roblox server-list request failed"
        end

        if type(responseBody) ~= "string" or responseBody == "" then
            C.LastLookupRetryDelay = 25 + ((LocalPlayer.UserId + C.ServerFetchSerial * 3) % 11)
            C.Debug(string.format(
                "ONE_REQUEST HTTPGET_EMPTY cooldown=%ss body=%s",
                tostring(C.LastLookupRetryDelay), C.BodyPreview(responseBody)
            ))
            return nil, "Roblox server list returned an empty response"
        end

        local decodeOk, page = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        if not decodeOk or type(page) ~= "table" or type(page.data) ~= "table" then
            C.LastLookupRetryDelay = 12 + ((LocalPlayer.UserId + C.ServerFetchSerial) % 7)
            C.Debug(string.format(
                "ONE_REQUEST HTTPGET_JSON_INVALID len=%d preview=%s",
                #responseBody, C.BodyPreview(responseBody)
            ))
            return nil, "Roblox server list returned invalid data"
        end

        C.Debug(string.format(
            "ONE_REQUEST OK transport=game.HttpGet servers=%d nextCursor=%s",
            #page.data, page.nextPageCursor and "yes" or "no"
        ))
        return page, nil
    end

    function C.EnsureFolder()
        if not C.SharedSupported then return false end
        return pcall(function()
            if not isfolder("AutoBuyPet") then makefolder("AutoBuyPet") end
            if not isfolder(C.Folder) then makefolder(C.Folder) end
        end)
    end

    function C.ReadJsonFile(path)
        if not C.SharedSupported or not C.EnsureFolder() then return nil end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if not ok or type(data) ~= "table" then return nil end
        return data
    end

    function C.WriteJsonFile(path, data)
        if not C.SharedSupported or not C.EnsureFolder() then return false end
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if not ok then return false end
        return pcall(writefile, path, encoded)
    end

    function C.DeleteFileSafe(path)
        if type(delfile) ~= "function" then return end
        pcall(function()
            if type(isfile) ~= "function" or isfile(path) then
                delfile(path)
            end
        end)
    end

    -- =========================================================
    -- V12 GLOBAL USED-JOBID HISTORY
    -- =========================================================
    -- One permanent file per successfully entered JobId.
    --
    -- IMPORTANT:
    -- * A failed / 772 / unavailable JobId is NEVER written here.
    -- * A JobId is written here only after TeleportState.Started.
    -- * The record is independent of the current 100-server batch, so a later
    --   refreshed page containing the same JobId will still be rejected.
    -- * We intentionally do not expire these files. "Used once" means used.
    function C.UsedJobPath(jobId)
        jobId = tostring(jobId or "")
        if jobId == "" then return nil end
        return C.Folder
            .. "/used_" .. tostring(game.PlaceId)
            .. "_" .. jobId .. ".json"
    end

    function C.LegacyConsumedJobPath(jobId)
        jobId = tostring(jobId or "")
        if jobId == "" then return nil end
        return C.Folder
            .. "/consumed_" .. tostring(game.PlaceId)
            .. "_" .. jobId .. ".json"
    end

    function C.PathExists(path)
        if not path or path == "" then return false end

        if type(isfile) == "function" then
            local ok, exists = pcall(isfile, path)
            return ok and exists == true
        end

        local ok = pcall(readfile, path)
        return ok
    end

    function C.MarkGloballyUsed(jobId, source)
        jobId = tostring(jobId or "")
        if jobId == "" then return false end

        -- Session-local protection still works even if this executor does not
        -- expose a shared filesystem.
        C.VisitedJobIds[jobId] = true

        if not C.SharedSupported then
            C.Debug(string.format(
                "GLOBAL_USED session-only jobId=%s source=%s sharedFilesystem=false",
                jobId, tostring(source or "TeleportState.Started")
            ))
            return true
        end

        local path = C.UsedJobPath(jobId)
        if not path then return false end

        local ok = C.WriteJsonFile(path, {
            version = 12,
            placeId = game.PlaceId,
            jobId = jobId,
            usedByUserId = LocalPlayer.UserId,
            usedByUsername = LocalPlayer.Name,
            usedAt = os.time(),
            source = tostring(source or "TeleportState.Started"),
        })

        C.Debug(string.format(
            "GLOBAL_USED WRITE success=%s jobId=%s userId=%s path=%s",
            tostring(ok), jobId, tostring(LocalPlayer.UserId), path
        ))
        return ok
    end

    function C.IsGloballyUsed(jobId)
        jobId = tostring(jobId or "")
        if jobId == "" then return false end

        -- The in-session table protects this account immediately.
        if C.VisitedJobIds[jobId] then
            return true
        end

        if not C.SharedSupported then
            return false
        end

        local usedPath = C.UsedJobPath(jobId)
        if usedPath and C.PathExists(usedPath) then
            local data = C.ReadJsonFile(usedPath)

            -- Conservative behavior: once the dedicated used-file exists, block
            -- this JobId even if the file became partially corrupted. This is
            -- safer than accidentally reusing a server.
            if type(data) ~= "table" then
                C.Debug("GLOBAL_USED BLOCK invalid-record jobId=" .. jobId)
                return true
            end

            if tonumber(data.placeId) == game.PlaceId
                and tostring(data.jobId or "") == jobId then
                return true
            end

            C.Debug("GLOBAL_USED BLOCK mismatched-record jobId=" .. jobId)
            return true
        end

        -- V11 compatibility/migration: if this JobId was successfully consumed
        -- by V11 before V12 was installed, promote that record into the permanent
        -- global used history.
        local legacyPath = C.LegacyConsumedJobPath(jobId)
        if legacyPath and C.PathExists(legacyPath) then
            local legacy = C.ReadJsonFile(legacyPath)
            if type(legacy) == "table"
                and tonumber(legacy.placeId) == game.PlaceId
                and tostring(legacy.jobId or "") == jobId then
                C.MarkGloballyUsed(jobId, "V11 consumed-record migration")
                C.Debug("GLOBAL_USED MIGRATED legacy consumed jobId=" .. jobId)
                return true
            end
        end

        return false
    end

    function C.GetConsumedJobIds(batchId)
        local consumed = {}
        if not C.SharedSupported or not C.EnsureFolder() then return consumed end

        local ok, paths = pcall(listfiles, C.Folder)
        if not ok or type(paths) ~= "table" then return consumed end

        local now = os.time()
        for _, path in ipairs(paths) do
            path = tostring(path)
            if path:match("consumed_%d+_[%x%-]+%.json$") then
                local data = C.ReadJsonFile(path)
                if type(data) == "table" then
                    local age = now - (tonumber(data.updatedAt) or 0)
                    if age > C.SharedBatchHardTTL + 120 then
                        C.DeleteFileSafe(path)
                    elseif tonumber(data.placeId) == game.PlaceId
                        and tostring(data.batchId or "") == tostring(batchId or "")
                        and tostring(data.jobId or "") ~= "" then
                        consumed[tostring(data.jobId)] = true
                    end
                end
            end
        end

        return consumed
    end

    function C.ReadSharedBatch()
        if not C.SharedSupported then return nil, nil end

        local data = C.ReadJsonFile(C.SharedBatchFile)
        if type(data) ~= "table"
            or tonumber(data.placeId) ~= game.PlaceId
            or type(data.servers) ~= "table"
            or tostring(data.batchId or "") == "" then
            return nil, nil
        end

        local age = math.max(0, os.time() - (tonumber(data.createdAt) or 0))
        if age > C.SharedBatchHardTTL then
            C.Debug(string.format(
                "SHARED_BATCH expired hardTTL age=%ss batchId=%s",
                tostring(age), tostring(data.batchId)
            ))
            return nil, age
        end

        local consumed = C.GetConsumedJobIds(data.batchId)
        local servers = {}
        for _, server in ipairs(data.servers) do
            local jobId = tostring(type(server) == "table" and server.id or "")
            if jobId ~= ""
                and not consumed[jobId]
                and not C.IsGloballyUsed(jobId) then
                table.insert(servers, server)
            end
        end

        return {
            data = servers,
            nextPageCursor = data.nextPageCursor,
            previousPageCursor = data.previousPageCursor,
            _ScoopHubRequestedCursor = data.requestedCursor,
            _ScoopHubBatchId = tostring(data.batchId),
            _ScoopHubCacheAge = age,
            _ScoopHubFromSharedCache = true,
        }, age
    end

    function C.WriteSharedBatch(page)
        if not C.SharedSupported or type(page) ~= "table" or type(page.data) ~= "table" then
            return nil
        end

        local batchId = string.format(
            "%d_%d_%d",
            os.time(),
            LocalPlayer.UserId,
            C.ServerFetchSerial
        )

        local data = {
            version = 13,
            placeId = game.PlaceId,
            batchId = batchId,
            createdAt = os.time(),
            createdByUserId = LocalPlayer.UserId,
            requestedCursor = page._ScoopHubRequestedCursor,
            nextPageCursor = page.nextPageCursor,
            previousPageCursor = page.previousPageCursor,
            servers = page.data,
        }

        if not C.WriteJsonFile(C.SharedBatchFile, data) then
            C.Debug("SHARED_BATCH write failed")
            return nil
        end

        C.ExhaustedBatchIds[batchId] = nil
        C.Debug(string.format(
            "SHARED_BATCH SAVED batchId=%s servers=%d creator=%s",
            batchId, #page.data, tostring(LocalPlayer.UserId)
        ))

        C.DeleteFileSafe(C.SharedCooldownFile)
        return batchId
    end

    function C.ConsumeSuccessfulJobId(jobId, batchId)
        -- This function is called ONLY after TeleportState.Started.
        -- Failed/full Job IDs never come here.
        jobId = tostring(jobId or "")
        batchId = tostring(batchId or "")
        if jobId == "" or batchId == "" then return false end

        -- V12 permanent history. This is idempotent and is reached only from
        -- the successful TeleportState.Started path.
        C.MarkGloballyUsed(jobId, "successful shared-batch consume")

        if C.SharedSupported then
            local consumedPath = C.Folder
                .. "/consumed_" .. tostring(game.PlaceId)
                .. "_" .. jobId .. ".json"

            C.WriteJsonFile(consumedPath, {
                version = 11,
                placeId = game.PlaceId,
                batchId = batchId,
                jobId = jobId,
                consumedByUserId = LocalPlayer.UserId,
                updatedAt = os.time(),
            })

            -- Best-effort physical removal from the shared JSON too. The
            -- per-JobId consumed file above is authoritative and prevents a
            -- concurrent writer from accidentally reintroducing this JobId.
            local data = C.ReadJsonFile(C.SharedBatchFile)
            if type(data) == "table"
                and tostring(data.batchId or "") == batchId
                and type(data.servers) == "table" then
                local changed = false
                for index = #data.servers, 1, -1 do
                    if tostring(data.servers[index] and data.servers[index].id or "") == jobId then
                        table.remove(data.servers, index)
                        changed = true
                    end
                end
                if changed then
                    C.WriteJsonFile(C.SharedBatchFile, data)
                end
            end
        end

        C.Debug(string.format(
            "SHARED_BATCH CONSUME ON SUCCESS batchId=%s jobId=%s",
            batchId, jobId
        ))
        return true
    end

    function C.MarkBatchExhausted(batchId)
        batchId = tostring(batchId or "")
        if batchId ~= "" then
            C.ExhaustedBatchIds[batchId] = true
            if batchId:find("memory_", 1, true) == 1 then
                C.MemoryBatchExhausted = true
            end
            C.Debug("SHARED_BATCH exhausted locally batchId=" .. batchId)
        end
    end

    function C.ReadSharedCooldown()
        if not C.SharedSupported then return 0, nil end
        local data = C.ReadJsonFile(C.SharedCooldownFile)
        if type(data) ~= "table" or tonumber(data.placeId) ~= game.PlaceId then
            return 0, nil
        end

        local remaining = (tonumber(data.untilAt) or 0) - os.time()
        if remaining <= 0 then
            C.DeleteFileSafe(C.SharedCooldownFile)
            return 0, nil
        end

        return remaining, tostring(data.reason or "shared cooldown")
    end

    function C.SetSharedCooldown(seconds, reason)
        if not C.SharedSupported then return end
        seconds = math.max(1, math.floor(tonumber(seconds) or 15))
        C.WriteJsonFile(C.SharedCooldownFile, {
            version = 11,
            placeId = game.PlaceId,
            untilAt = os.time() + seconds,
            ownerUserId = LocalPlayer.UserId,
            reason = tostring(reason or "server-list request failed"),
            updatedAt = os.time(),
        })
        C.Debug(string.format(
            "SHARED_COOLDOWN set seconds=%d reason=%s",
            seconds, tostring(reason or "")
        ))
    end

    function C.ReleaseRefreshIntent()
        C.DeleteFileSafe(C.RefreshIntentFile)
    end

    function C.AcquireRefreshOwnership()
        if not C.SharedSupported or not C.EnsureFolder() then
            return true, LocalPlayer.UserId
        end

        C.WriteJsonFile(C.RefreshIntentFile, {
            version = 11,
            placeId = game.PlaceId,
            userId = LocalPlayer.UserId,
            requestedAt = os.time(),
            updatedAt = os.time(),
        })

        task.wait(0.35 + ((LocalPlayer.UserId % 7) * 0.04))

        local ok, paths = pcall(listfiles, C.Folder)
        if not ok or type(paths) ~= "table" then
            return true, LocalPlayer.UserId
        end

        local winnerUserId = LocalPlayer.UserId
        local winnerRequestedAt = math.huge
        local now = os.time()

        for _, path in ipairs(paths) do
            path = tostring(path)
            if path:match("refresh_%d+%.json$") then
                local data = C.ReadJsonFile(path)
                if type(data) == "table" and tonumber(data.placeId) == game.PlaceId then
                    local requestedAt = tonumber(data.requestedAt) or 0
                    local age = now - requestedAt
                    local uid = tonumber(data.userId)

                    if age > C.RefreshIntentTTL then
                        C.DeleteFileSafe(path)
                    elseif uid then
                        if requestedAt < winnerRequestedAt
                            or (requestedAt == winnerRequestedAt and uid < winnerUserId) then
                            winnerRequestedAt = requestedAt
                            winnerUserId = uid
                        end
                    end
                end
            end
        end

        if winnerRequestedAt == math.huge then
            winnerUserId = LocalPlayer.UserId
        end

        local ours = winnerUserId == LocalPlayer.UserId
        C.Debug(string.format(
            "REFRESH_ELECTION ours=%s winnerUserId=%s",
            tostring(ours), tostring(winnerUserId)
        ))
        return ours, winnerUserId
    end

    function C.BuildServerPageUrl(baseUrl, cursor)
        cursor = tostring(cursor or "")
        if cursor == "" then
            return baseUrl
        end

        local encodedCursor = cursor
        pcall(function()
            encodedCursor = HttpService:UrlEncode(cursor)
        end)

        return baseUrl .. "&cursor=" .. encodedCursor
    end

    function C.GetSharedServerPage(url)
        -- Executors whose file APIs are not shared keep V10's one-request
        -- behavior. When shared storage is available, prefer the shared cache.
        if not C.SharedSupported then
            local memoryCursor = nil

            if C.MemoryBatchExhausted then
                memoryCursor = C.MemoryNextPageCursor
                -- nil cursor after exhaustion means wrap to page 1.
            else
                memoryCursor = C.MemoryRequestedCursor
            end

            local memoryUrl = C.BuildServerPageUrl(url, memoryCursor)
            local page, err = C.FetchServerPage(memoryUrl)
            if page then
                C.MemoryRequestedCursor = memoryCursor
                C.MemoryNextPageCursor = page.nextPageCursor
                C.MemoryBatchExhausted = false
                page._ScoopHubRequestedCursor = memoryCursor
                page._ScoopHubBatchId = "memory_" .. tostring(LocalPlayer.UserId)
                    .. "_" .. tostring(C.ServerFetchSerial)
            end
            return page, err
        end

        local cachedPage, cacheAge = C.ReadSharedBatch()
        local cachedBatchId = cachedPage and tostring(cachedPage._ScoopHubBatchId or "") or ""
        local cacheExhausted = cachedBatchId ~= ""
            and C.ExhaustedBatchIds[cachedBatchId] == true
        local cacheHasNoUsableServers = cachedPage ~= nil and #cachedPage.data == 0

        -- V13 cursor rotation:
        -- * Exhausted current 100-server batch -> request nextPageCursor.
        -- * Shared cache has zero remaining globally-usable JobIds -> nextPageCursor.
        -- * If nextPageCursor is nil, wrap to page 1.
        -- * A normal TTL refresh does NOT advance pages; it refreshes the same
        --   requested page so age alone cannot burn through the cursor chain.
        local shouldAdvanceCursor = cachedPage ~= nil
            and (cacheExhausted or cacheHasNoUsableServers)

        local refreshCursor = nil
        local refreshReason = "page1"
        if shouldAdvanceCursor then
            refreshCursor = cachedPage.nextPageCursor
            if refreshCursor and tostring(refreshCursor) ~= "" then
                refreshReason = "nextPageCursor"
            else
                refreshCursor = nil
                refreshReason = "cursor-chain-end-wrap-page1"
            end
        elseif cachedPage and cachedPage._ScoopHubRequestedCursor then
            -- TTL/stale refresh of an existing page: refresh that same page,
            -- not the next one.
            refreshCursor = cachedPage._ScoopHubRequestedCursor
            refreshReason = "same-page-refresh"
        end

        local refreshUrl = C.BuildServerPageUrl(url, refreshCursor)

        if cachedPage
            and #cachedPage.data > 0
            and not cacheExhausted
            and (tonumber(cacheAge) or math.huge) <= C.SharedBatchTTL then
            C.Debug(string.format(
                "SHARED_BATCH HIT batchId=%s age=%ss servers=%d networkRequest=0",
                cachedBatchId, tostring(cacheAge), #cachedPage.data
            ))
            return cachedPage, nil
        end

        local cooldownRemaining, cooldownReason = C.ReadSharedCooldown()
        if cooldownRemaining > 0 then
            if cachedPage and #cachedPage.data > 0 and not cacheExhausted then
                C.Debug(string.format(
                    "SHARED_BATCH STALE_REUSE cooldown=%ss batchId=%s age=%ss servers=%d",
                    tostring(cooldownRemaining), cachedBatchId,
                    tostring(cacheAge), #cachedPage.data
                ))
                return cachedPage, nil
            end

            C.LastLookupRetryDelay = cooldownRemaining
            return nil, "Shared server-list cooldown active: " .. tostring(cooldownReason)
        end

        local oldBatchId = cachedBatchId

        C.Debug(string.format(
            "CURSOR_ROTATION refreshReason=%s oldBatchId=%s requestedCursor=%s nextCursorAvailable=%s",
            tostring(refreshReason),
            tostring(oldBatchId),
            refreshCursor and "yes" or "no",
            tostring(cachedPage ~= nil and cachedPage.nextPageCursor ~= nil)
        ))

        local ownsRefresh, winnerUserId = C.AcquireRefreshOwnership()

        if not ownsRefresh then
            -- Another account is the designated refresher. Wait briefly for its
            -- single request to populate the shared cache; do not hit Roblox.
            local deadline = tick() + 3.5
            repeat
                task.wait(0.20)
                local newPage, newAge = C.ReadSharedBatch()
                local newBatchId = newPage and tostring(newPage._ScoopHubBatchId or "") or ""
                if newPage
                    and #newPage.data > 0
                    and newBatchId ~= ""
                    and newBatchId ~= oldBatchId
                    and not C.ExhaustedBatchIds[newBatchId] then
                    C.ReleaseRefreshIntent()
                    C.Debug(string.format(
                        "SHARED_BATCH RECEIVED_FROM_ACCOUNT winner=%s batchId=%s age=%ss servers=%d networkRequest=0",
                        tostring(winnerUserId), newBatchId, tostring(newAge), #newPage.data
                    ))
                    return newPage, nil
                end
            until tick() >= deadline

            C.ReleaseRefreshIntent()

            -- If the refresh owner hit 429, it will have written a shared
            -- cooldown. Every other account obeys the same cooldown.
            cooldownRemaining, cooldownReason = C.ReadSharedCooldown()
            if cooldownRemaining > 0 then
                if cachedPage and #cachedPage.data > 0 and not cacheExhausted then
                    C.Debug(string.format(
                        "SHARED_BATCH FALLBACK_OLD_CACHE cooldown=%ss batchId=%s servers=%d",
                        tostring(cooldownRemaining), cachedBatchId, #cachedPage.data
                    ))
                    return cachedPage, nil
                end
                C.LastLookupRetryDelay = cooldownRemaining
                return nil, "Shared server-list cooldown active: " .. tostring(cooldownReason)
            end

            if cachedPage and #cachedPage.data > 0 and not cacheExhausted then
                C.Debug(string.format(
                    "SHARED_BATCH FALLBACK_OLD_CACHE owner=%s batchId=%s servers=%d",
                    tostring(winnerUserId), cachedBatchId, #cachedPage.data
                ))
                return cachedPage, nil
            end

            C.LastLookupRetryDelay = 3 + ((LocalPlayer.UserId % 5) * 0.4)
            return nil, "Another ScoopHub account is refreshing the shared server list"
        end

        -- We won the election. Re-check in case another instance wrote a new
        -- batch while the election was settling.
        local newestPage, newestAge = C.ReadSharedBatch()
        local newestBatchId = newestPage and tostring(newestPage._ScoopHubBatchId or "") or ""
        if newestPage
            and #newestPage.data > 0
            and newestBatchId ~= ""
            and newestBatchId ~= oldBatchId
            and not C.ExhaustedBatchIds[newestBatchId]
            and (tonumber(newestAge) or math.huge) <= C.SharedBatchTTL then
            C.ReleaseRefreshIntent()
            C.Debug(string.format(
                "SHARED_BATCH WON_ELECTION_BUT_CACHE_ALREADY_REFRESHED batchId=%s networkRequest=0",
                newestBatchId
            ))
            return newestPage, nil
        end

        local page, fetchError = C.FetchServerPage(refreshUrl)
        if page then
            page._ScoopHubRequestedCursor = refreshCursor
            C.Debug(string.format(
                "CURSOR_ROTATION FETCH_OK reason=%s requestedCursor=%s nextCursor=%s servers=%d",
                tostring(refreshReason),
                refreshCursor and "yes" or "page1",
                page.nextPageCursor and "yes" or "no",
                type(page.data) == "table" and #page.data or 0
            ))
        end

        if not page then
            local delay = tonumber(C.LastLookupRetryDelay) or 15
            C.SetSharedCooldown(delay, fetchError or "server-list request failed")
            C.ReleaseRefreshIntent()

            -- A stale cache is still preferable to every account retrying the
            -- Roblox endpoint. Failed JobIds are merely skipped locally.
            if cachedPage and #cachedPage.data > 0 and not cacheExhausted then
                C.Debug(string.format(
                    "SHARED_BATCH REQUEST_FAILED_REUSE_OLD batchId=%s servers=%d error=%s",
                    cachedBatchId, #cachedPage.data, tostring(fetchError)
                ))
                return cachedPage, nil
            end

            return nil, fetchError
        end

        local newBatchId = C.WriteSharedBatch(page)
        C.ReleaseRefreshIntent()

        if newBatchId then
            local sharedPage = C.ReadSharedBatch()
            if sharedPage then
                return sharedPage, nil
            end
        end

        -- If persistence unexpectedly fails, still use this successful HTTP
        -- response for the current account rather than wasting it.
        page._ScoopHubBatchId = "memory_" .. tostring(LocalPlayer.UserId)
            .. "_" .. tostring(C.ServerFetchSerial)
        return page, nil
    end

    function C.Decode(path)
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if not ok or type(data) ~= "table" then return nil end
        if tonumber(data.placeId) ~= game.PlaceId then return nil end
        if os.time() - (tonumber(data.updatedAt) or 0) > C.ClaimTTL then
            if type(delfile) == "function" then pcall(delfile, path) end
            return nil
        end
        return data
    end

    function C.Read()
        local claims = {}
        if not C.SharedSupported or not C.EnsureFolder() then return claims end
        local ok, paths = pcall(listfiles, C.Folder)
        if not ok or type(paths) ~= "table" then return claims end
        for _, path in ipairs(paths) do
            path = tostring(path)
            if path:match("claim_%d+%.json$") then
                local data = C.Decode(path)
                if data then table.insert(claims, data) end
            end
        end
        return claims
    end

    function C.WriteOwn()
        if not C.SharedSupported or not C.EnsureFolder() then return false end
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode({
                userId = LocalPlayer.UserId,
                username = LocalPlayer.Name,
                placeId = game.PlaceId,
                currentJobId = game.JobId,
                reservedJobId = C.OwnReservedJobId,
                updatedAt = os.time(),
            })
        end)
        if not ok then return false end
        return pcall(writefile, C.File, encoded)
    end

    function C.GetClaimed()
        local claimed = {}
        for _, claim in ipairs(C.Read()) do
            if tonumber(claim.userId) ~= LocalPlayer.UserId then
                local current = tostring(claim.currentJobId or "")
                local reserved = tostring(claim.reservedJobId or "")
                if current ~= "" then claimed[current] = true end
                if reserved ~= "" then claimed[reserved] = true end
            end
        end
        return claimed
    end

    function C.Clear()
        C.OwnReservedJobId = nil
        C.WriteOwn()
    end

    function C.IsBlocked(jobId, allowVisited)
        jobId = tostring(jobId or "")
        if jobId == "" or jobId == game.JobId then return true end

        -- V12: permanent used history overrides allowVisited. Once any ScoopHub
        -- account successfully entered this JobId, no future batch/custom
        -- selection may reserve it again.
        if C.IsGloballyUsed(jobId) then return true end

        if not allowVisited and C.VisitedJobIds[jobId] then return true end
        local failedAt = C.FailedJobIds[jobId]
        if failedAt then
            if tick() - failedAt < C.FailedTTL then return true end
            C.FailedJobIds[jobId] = nil
        end
        return false
    end

    function C.TryReserve(jobId, allowVisited)
        jobId = tostring(jobId or "")
        if C.IsBlocked(jobId, allowVisited) then return false end
        if not C.SharedSupported then
            C.OwnReservedJobId = jobId
            return true
        end
        if C.GetClaimed()[jobId] then return false end

        C.OwnReservedJobId = jobId
        if not C.WriteOwn() then
            C.OwnReservedJobId = nil
            return false
        end

        task.wait(0.25 + ((LocalPlayer.UserId % 7) * 0.025))
        for verificationRound = 1, 2 do
            -- Another account may have succeeded into this JobId after this
            -- account loaded its copy of the 100-server batch but before our
            -- reservation verification completed.
            if C.IsGloballyUsed(jobId) then
                C.Debug(string.format(
                    "RESERVE REJECT global-used jobId=%s verificationRound=%d",
                    jobId, verificationRound
                ))
                C.Clear()
                return false
            end

            local winnerUserId = LocalPlayer.UserId
            local occupiedByOther = false
            for _, claim in ipairs(C.Read()) do
                local claimUserId = tonumber(claim.userId)
                if claimUserId and claimUserId ~= LocalPlayer.UserId then
                    if tostring(claim.currentJobId or "") == jobId then
                        occupiedByOther = true
                        break
                    elseif tostring(claim.reservedJobId or "") == jobId then
                        winnerUserId = math.min(winnerUserId, claimUserId)
                    end
                end
            end
            if occupiedByOther or winnerUserId ~= LocalPlayer.UserId then
                C.Clear()
                return false
            end
            if verificationRound == 1 then task.wait(0.25) end
        end
        return true
    end

    function C.MarkVisited(jobId)
        jobId = tostring(jobId or "")
        if jobId ~= "" then C.VisitedJobIds[jobId] = true end
    end

    function C.MarkFailed(jobId)
        jobId = tostring(jobId or "")
        if jobId ~= "" then
            C.FailedJobIds[jobId] = tick()
            C.VisitedJobIds[jobId] = true
        end
    end

    function C.NextSelectionIndex(candidateCount)
        if candidateCount <= 0 then return 1 end
        C.SelectionSequence = C.SelectionSequence + 1
        return ((LocalPlayer.UserId + C.SelectionSequence * 17) % candidateCount) + 1
    end

    function C.NextCustomJobId()
        if #customJobIds == 0 then return nil end
        local claimed = C.GetClaimed()
        customJobIndex = math.clamp(customJobIndex, 1, #customJobIds)
        for _ = 1, #customJobIds do
            local jobId = tostring(customJobIds[customJobIndex] or "")
            customJobIndex = (customJobIndex % #customJobIds) + 1
            if jobId ~= "" and not C.IsBlocked(jobId) and not claimed[jobId] then
                updateJobIdsUI()
                rebuildJobIdList()
                return jobId
            end
        end
        updateJobIdsUI()
        rebuildJobIdList()
        return nil
    end

    function C.Shutdown()
        _G.ScoopHubServerClaimHeartbeatToken = (_G.ScoopHubServerClaimHeartbeatToken or 0) + 1
        C.OwnReservedJobId = nil
        if type(delfile) == "function" and type(isfile) == "function" then
            pcall(function()
                if isfile(C.File) then delfile(C.File) end
            end)
        end
    end

    C.WriteOwn()
    C.DebugLines = {}
    C.Debug(string.format("V13 cursor-rotating shared 100-batch + global-used JobId guard start user=%s userId=%s placeId=%s jobId=%s sharedClaims=%s",
        tostring(LocalPlayer.Name), tostring(LocalPlayer.UserId), tostring(game.PlaceId), tostring(game.JobId), tostring(C.SharedSupported)))
    _G.ScoopHubServerClaimHeartbeatToken = (_G.ScoopHubServerClaimHeartbeatToken or 0) + 1
    C.HeartbeatToken = _G.ScoopHubServerClaimHeartbeatToken
    task.spawn(function()
        while _G.ScoopHubServerClaimHeartbeatToken == C.HeartbeatToken do
            task.wait(C.HeartbeatSeconds)
            if _G.ScoopHubServerClaimHeartbeatToken == C.HeartbeatToken then
                C.WriteOwn()
            end
        end
    end)
end

-- =========================================================
-- STATUS + TOGGLE PANEL
-- =========================================================
DashboardProfilePanel = CreatePanel(AutoBuyPage, "DashboardProfilePanel", UDim2.new(0, 12, 0, 12), UDim2.new(1, -24, 0, 88), "PLAYER PROFILE")

DashboardAvatar = New("ImageLabel", {
    Name = "DashboardAvatar",
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=100&h=100",
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 29),
    Size = UDim2.new(0, 44, 0, 44),
    ScaleType = Enum.ScaleType.Crop,
}, DashboardProfilePanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, DashboardAvatar)
New("UIStroke", { Color = Theme.PanelLine, Thickness = 1, Transparency = 0.38 }, DashboardAvatar)

DashboardDisplayNameLabel = New("TextLabel", {
    Text = LocalPlayer.DisplayName,
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.White,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 66, 0, 31),
    Size = UDim2.new(0.52, -66, 0, 18),
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
}, DashboardProfilePanel)

New("TextLabel", {
    Text = "@" .. LocalPlayer.Name,
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 66, 0, 51),
    Size = UDim2.new(0.52, -66, 0, 16),
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
}, DashboardProfilePanel)

New("TextLabel", {
    Text = "USER ID",
    Font = Theme.Font,
    TextSize = 9,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.58, 0, 0, 31),
    Size = UDim2.new(0.4, -12, 0, 12),
    TextXAlignment = Enum.TextXAlignment.Left,
}, DashboardProfilePanel)

New("TextLabel", {
    Text = tostring(LocalPlayer.UserId),
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.58, 0, 0, 43),
    Size = UDim2.new(0.4, -12, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, DashboardProfilePanel)

DashboardProfileStatusLabel = New("TextLabel", {
    Text = "AUTO BUY: STOPPED",
    Font = Theme.Font,
    TextSize = 10,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.58, 0, 0, 59),
    Size = UDim2.new(0.4, -12, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, DashboardProfilePanel)

StatusPanel = CreatePanel(AutoBuyPage, "StatusPanel", UDim2.new(0, 12, 0, 112), UDim2.new(1, -24, 0, 236), "SESSION STATUS")

SessionNameLabel = New("TextLabel", {
    Name = "SessionNameLabel",
    Text = LocalPlayer.Name .. " • 00:00",
    Font = Theme.FontBody,
    TextSize = 10,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 20),
    Size = UDim2.new(0.5, -16, 0, 12),
    TextXAlignment = Enum.TextXAlignment.Left,
}, StatusPanel)
SessionNameLabel.Visible = false

local LiveChip = New("Frame", {
    Name = "LiveChip",
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -98, 0, 7),
    Size = UDim2.new(0, 86, 0, 18),
}, StatusPanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, LiveChip)
local LiveChipLabel = New("TextLabel", {
    Name = "LiveChipLabel",
    Text = "● STOPPED",
    Font = Theme.Font,
    TextSize = 9,
    TextColor3 = Theme.White,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Center,
}, LiveChip)

local function CreateStatusCard(name, position, labelText, valueColor)
    local isLarge = name == "ElapsedCard" or name == "SessionPetsCard"
    local card = New("Frame", {
        Name = name,
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Position = position,
        Size = UDim2.new(0.5, -16, 0, isLarge and 52 or 30),
    }, StatusPanel)
    New("UICorner", { CornerRadius = UDim.new(0, 5) }, card)
    New("UIStroke", { Color = Theme.PanelLine, Thickness = 0.8, Transparency = 0.62 }, card)
    New("TextLabel", {
        Text = labelText,
        Font = Theme.Font,
        TextSize = 9,
        TextColor3 = Theme.Muted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, isLarge and 7 or 3),
        Size = UDim2.new(1, -16, 0, isLarge and 10 or 8),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    return New("TextLabel", {
        Name = "Value",
        Text = "--",
        Font = Theme.Font,
        TextSize = isLarge and 21 or 13,
        TextColor3 = valueColor,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, isLarge and 21 or 12),
        Size = UDim2.new(1, -16, 0, isLarge and 25 or 16),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
end

ElapsedLabel = CreateStatusCard("ElapsedCard", UDim2.new(0, 12, 0, 36), "ELAPSED", Theme.White)
local BoughtLabel = CreateStatusCard("SessionPetsCard", UDim2.new(0.5, 4, 0, 36), "SESSION PETS", Theme.Success)
local ShecklesLabel = CreateStatusCard("ShecklesCard", UDim2.new(0, 12, 0, 92), "SHECKLES", Color3.fromRGB(123, 222, 151))
SpentLabel = CreateStatusCard("SpentCard", UDim2.new(0.5, 4, 0, 92), "SPENT", Color3.fromRGB(255, 166, 112))
ServerHopsLabel = CreateStatusCard("ServerHopsCard", UDim2.new(0, 12, 0, 126), "SERVER HOPS", Theme.Text)

TargetLabel = New("TextLabel", {
    Name = "TargetLabel",
    Text = "TARGETS  •  " .. targetDisplayText,
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 160),
    Size = UDim2.new(1, -24, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, StatusPanel)

ActivityLabel = New("TextButton", {
    Name = "ActivityLabel",
    Text = "ACTIVITY  •  Waiting for activity",
    Font = Theme.FontBody,
    TextSize = 10,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 116),
    Size = UDim2.new(1, -24, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    AutoButtonColor = false,
}, StatusPanel)
ActivityLabel.Visible = false

local ToggleButton = New("TextButton", {
    Name = "ToggleButton",
    Text = "ENABLE AUTO BUY PET",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 4, 1, -48),
    Size = UDim2.new(0.5, -16, 0, 34),
}, StatusPanel)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, ToggleButton)
New("UIStroke", { Color = Color3.fromRGB(255, 150, 157), Thickness = 1, Transparency = 0.55 }, ToggleButton)

ForceHopButton = New("TextButton", {
    Name = "ForceHopButton",
    Text = "FORCE HOP",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 1, -48),
    Size = UDim2.new(0.5, -16, 0, 34),
}, StatusPanel)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, ForceHopButton)
New("UIStroke", { Color = Theme.PanelLine, Thickness = 1, Transparency = 0.45 }, ForceHopButton)

ActivityModal = New("Frame", {
    Name = "ActivityModal", Visible = false, BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
    Position = UDim2.new(0, 16, 0, 28), Size = UDim2.new(1, -32, 0, 184), ZIndex = 70,
}, AutoBuyPage)
New("UICorner", { CornerRadius = UDim.new(0, 7) }, ActivityModal)
New("UIStroke", { Color = Theme.Red, Thickness = 1.2 }, ActivityModal)
New("TextLabel", { Text = "RECENT ACTIVITY", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.White, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -52, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 71 }, ActivityModal)
ActivityCloseButton = New("TextButton", { Text = "X", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.White, BackgroundColor3 = Theme.RedDark, BorderSizePixel = 0, Position = UDim2.new(1, -34, 0, 8), Size = UDim2.new(0, 22, 0, 22), ZIndex = 71 }, ActivityModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ActivityCloseButton)
ActivityList = New("ScrollingFrame", { BackgroundColor3 = Theme.Surface2, BackgroundTransparency = 0.18, BorderSizePixel = 0, Position = UDim2.new(0, 12, 0, 38), Size = UDim2.new(1, -24, 1, -50), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Red, ZIndex = 71 }, ActivityModal)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ActivityList)
New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, ActivityList)
New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, ActivityList)

function rebuildActivityFeed()
    for _, child in ipairs(ActivityList:GetChildren()) do
        if child.Name == "ActivityRow" or child.Name == "ActivityEmpty" then child:Destroy() end
    end
    if #activityFeed == 0 then
        New("TextLabel", { Name = "ActivityEmpty", Text = "No activity yet.", Font = Theme.FontBody, TextSize = 11, TextColor3 = Theme.Muted, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 72 }, ActivityList)
        return
    end
    for index, message in ipairs(activityFeed) do
        New("TextLabel", { Name = "ActivityRow", LayoutOrder = index, Text = message, Font = Theme.FontBody, TextSize = 11, TextColor3 = Theme.White, BackgroundColor3 = Theme.Surface3, BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 25), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 72 }, ActivityList)
    end
end

ActivityLabel.Activated:Connect(function()
    ActivityModal.Visible = true
    rebuildActivityFeed()
end)
ActivityCloseButton.Activated:Connect(function() ActivityModal.Visible = false end)

-- =========================================================
-- HISTORY TAB
-- =========================================================
HistoryPanel = CreatePanel(HistoryPage, "HistoryPanel", UDim2.new(0, 12, 0, 12), UDim2.new(1, -24, 1, -24), "PET HISTORY")

local HistoryTotalLabel = New("TextLabel", {
    Name = "HistoryTotalLabel",
    Text = "Total pets: 0",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.Success,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 1, -44),
    Size = UDim2.new(1, -24, 0, 20),
    TextXAlignment = Enum.TextXAlignment.Left,
}, HistoryPanel)

HistoryDailyLabel = New("TextLabel", {
    Name = "HistoryDailyLabel",
    Text = "Today: 0 pets",
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 1, -24),
    Size = UDim2.new(1, -24, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Center,
}, HistoryPanel)

HistoryColumns = New("Frame", {
    Name = "HistoryColumns",
    BackgroundColor3 = Theme.Surface3,
    BackgroundTransparency = 0.28,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 28),
    Size = UDim2.new(1, -24, 0, 20),
}, HistoryPanel)
New("UICorner", { CornerRadius = UDim.new(0, 4) }, HistoryColumns)

local function CreateHistoryColumn(text, position, size, alignment)
    New("TextLabel", {
        Text = text,
        Font = Theme.Font,
        TextSize = 10,
        TextColor3 = Theme.TextDim,
        BackgroundTransparency = 1,
        Position = position,
        Size = size,
        TextXAlignment = alignment,
    }, HistoryColumns)
end
CreateHistoryColumn("PET NAME", UDim2.new(0, 10, 0, 0), UDim2.new(0.55, -10, 1, 0), Enum.TextXAlignment.Left)
CreateHistoryColumn("AMOUNT", UDim2.new(0.55, 0, 0, 0), UDim2.new(0.2, 0, 1, 0), Enum.TextXAlignment.Center)
CreateHistoryColumn("RARITY", UDim2.new(0.75, 0, 0, 0), UDim2.new(0.25, -10, 1, 0), Enum.TextXAlignment.Right)

local HistoryScroll = New("ScrollingFrame", {
    Name = "HistoryScroll",
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.22,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 52),
    Size = UDim2.new(1, -24, 1, -126),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Red,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, HistoryPanel)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, HistoryScroll)
New("UIPadding", {
    PaddingTop = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 5),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
}, HistoryScroll)
New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.Name }, HistoryScroll)

-- Fandom images are downloaded once and cached locally because ImageLabel
-- cannot display normal web URLs directly.
local WIKI_PET_PAGE_NAMES = {
    GoldenDragonfly = "Golden Dragonfly",
    BlackDragon = "Black Dragon",
    IceSerpent = "Ice Serpent",
    ShadowDragon = "Shadow Dragon",
}
local petIconCache = {}
local petIconLoading = {}
local petIconFolder = CONFIG_FOLDER .. "/pet_icons"
local customAsset = getcustomasset or getsynasset

local function getInGamePetIcon(petName)
    for _, container in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
        if container then
            local petTool = container:FindFirstChild(petName)
            if petTool and petTool:IsA("Tool") and petTool.TextureId ~= "" then
                return petTool.TextureId
            end
        end
    end
    return nil
end

local function setPetIcon(petName, imageLabel)
    local inGameIcon = getInGamePetIcon(petName)
    if inGameIcon then
        imageLabel.Image = inGameIcon
        return
    end
    if petIconCache[petName] then
        imageLabel.Image = petIconCache[petName]
        return
    end
    if petIconLoading[petName] or type(customAsset) ~= "function" then return end
    petIconLoading[petName] = true

    task.spawn(function()
        local safeName = tostring(petName):gsub("[^%w]", "_")
        local iconFile = petIconFolder .. "/" .. safeName .. ".png"
        local iconAsset = nil

        pcall(function()
            if isfolder and makefolder and not isfolder(petIconFolder) then
                makefolder(petIconFolder)
            end
            if isfile and isfile(iconFile) then
                iconAsset = customAsset(iconFile)
                return
            end

            local pageName = WIKI_PET_PAGE_NAMES[petName] or petName
            local apiUrl = "https://growagarden2.fandom.com/api.php?action=query&format=json&prop=pageimages&piprop=thumbnail&pithumbsize=128&titles="
                .. HttpService:UrlEncode(pageName)
            local pageData = HttpService:JSONDecode(game:HttpGet(apiUrl))
            local pages = pageData and pageData.query and pageData.query.pages
            local page = pages and next(pages) and pages[next(pages)]
            local imageUrl = page and page.thumbnail and page.thumbnail.source
            if imageUrl then
                writefile(iconFile, game:HttpGet(imageUrl))
                iconAsset = customAsset(iconFile)
            end
        end)

        petIconLoading[petName] = nil
        if iconAsset then
            petIconCache[petName] = iconAsset
            if imageLabel and imageLabel.Parent then
                imageLabel.Image = iconAsset
            end
        end
    end)
end

updateHistoryUI = function()
    for _, child in ipairs(HistoryScroll:GetChildren()) do
        if child.Name == "HistoryRow" or child.Name == "HistoryEmpty" then
            child:Destroy()
        end
    end

    HistoryTotalLabel.Text = "Total pets: " .. petsBought
    HistoryDailyLabel.Text = "Today: " .. dailyPetsBought .. " pets"

    local names = {}
    for petName, count in pairs(petHistory) do
        if tonumber(count) and tonumber(count) > 0 then
            table.insert(names, petName)
        end
    end
    table.sort(names, function(first, second)
        local firstBaseName = stripPetSizePrefix(first)
        local secondBaseName = stripPetSizePrefix(second)
        local firstRank = RARITY_RANK[PET_RARITY_OVERRIDES[firstBaseName] or "Unknown"] or 0
        local secondRank = RARITY_RANK[PET_RARITY_OVERRIDES[secondBaseName] or "Unknown"] or 0
        if firstRank ~= secondRank then
            return firstRank < secondRank
        end
        return first < second
    end)

    if #names == 0 then
        New("TextLabel", {
            Name = "HistoryEmpty",
            Text = "No pets secured yet.",
            Font = Theme.FontBody,
            TextSize = 13,
            TextColor3 = Theme.Muted,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            TextXAlignment = Enum.TextXAlignment.Center,
        }, HistoryScroll)
        return
    end

    for _, petName in ipairs(names) do
        local basePetName = stripPetSizePrefix(petName)
        local row = New("Frame", {
            Name = "HistoryRow",
            BackgroundColor3 = Theme.Surface3,
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
        }, HistoryScroll)
        New("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
        local petIcon = New("ImageLabel", {
            Name = "PetIcon",
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            ScaleType = Enum.ScaleType.Fit,
            Position = UDim2.new(0, 4, 0, 4),
            Size = UDim2.new(0, 22, 0, 22),
            Image = "",
        }, row)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, petIcon)
        setPetIcon(basePetName, petIcon)
        New("TextLabel", {
            Text = petName,
            Font = Theme.Font,
            TextSize = 13,
            TextColor3 = Theme.White,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 32, 0, 0),
            Size = UDim2.new(0.55, -32, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        New("TextLabel", {
            Text = tostring(petHistory[petName]),
            Font = Theme.Font,
            TextSize = 13,
            TextColor3 = Theme.Success,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.55, 0, 0, 0),
            Size = UDim2.new(0.2, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
        }, row)
        local rarity = PET_RARITY_OVERRIDES[basePetName] or "Unknown"
        New("TextLabel", {
            Text = rarity,
            Font = Theme.Font,
            TextSize = 13,
            TextColor3 = rarity == "Unknown" and Theme.Muted or Theme.Success,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.75, 0, 0, 0),
            Size = UDim2.new(0.25, -10, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, row)
    end
end

-- =========================================================
-- WEBHOOK TAB
-- =========================================================
WebhookPanel = CreatePanel(WebhookPage, "WebhookPanel", UDim2.new(0, 12, 0, 12), UDim2.new(1, -24, 1, -24), "WEBHOOK ALERTS")

New("TextLabel", {
    Text = "Main alerts stay separate from sell summaries. Choose exactly which alerts you receive.",
    Font = Theme.FontBody,
    TextSize = 12,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 28),
    Size = UDim2.new(1, -24, 0, 24),
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, WebhookPanel)

New("TextLabel", {
    Text = "Discord Webhook URL",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 58),
    Size = UDim2.new(1, -24, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, WebhookPanel)

local WebhookUrlBox = New("TextBox", {
    Name = "WebhookUrlBox",
    Text = "",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    Font = Theme.FontBody,
    TextSize = 12,
    TextColor3 = Theme.InputText,
    PlaceholderColor3 = Theme.Muted,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ClearTextOnFocus = false,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 12, 0, 76),
    Size = UDim2.new(1, -96, 0, 28),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, WebhookUrlBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, WebhookUrlBox)

WebhookUrlShowButton = New("TextButton", {
    Text = "SHOW", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
    Position = UDim2.new(1, -76, 0, 76), Size = UDim2.new(0, 64, 0, 28),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, WebhookUrlShowButton)

New("TextLabel", {
    Text = "Sell Webhook URL", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 112), Size = UDim2.new(1, -24, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, WebhookPanel)
SellWebhookUrlBox = New("TextBox", {
    Name = "SellWebhookUrlBox", Text = "", PlaceholderText = "https://discord.com/api/webhooks/...",
    Font = Theme.FontBody, TextSize = 12, TextColor3 = Theme.InputText, PlaceholderColor3 = Theme.Muted,
    BackgroundColor3 = Theme.InputBg, BorderSizePixel = 0, ClipsDescendants = true, ClearTextOnFocus = false,
    TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 12, 0, 130), Size = UDim2.new(1, -96, 0, 28),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SellWebhookUrlBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, SellWebhookUrlBox)
SellWebhookUrlShowButton = New("TextButton", {
    Text = "SHOW", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
    Position = UDim2.new(1, -76, 0, 130), Size = UDim2.new(0, 64, 0, 28),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SellWebhookUrlShowButton)

New("TextLabel", {
    Text = "Enable Main Webhook",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 170),
    Size = UDim2.new(1, -100, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, WebhookPanel)
local WebhookToggle = New("TextButton", {
    Name = "WebhookToggle",
    Text = "",
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -62, 0, 167),
    Size = UDim2.new(0, 48, 0, 24),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, WebhookToggle)
local WebhookKnob = New("Frame", {
    Name = "WebhookKnob",
    BackgroundColor3 = Theme.White,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 3, 0.5, 0),
    Size = UDim2.new(0, 18, 0, 18),
}, WebhookToggle)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, WebhookKnob)

local TestWebhookButton = New("TextButton", {
    Text = "TEST MAIN",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0, 216),
    Size = UDim2.new(0.5, -16, 0, 26),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, TestWebhookButton)

New("TextLabel", {
    Text = "Enable Sell Webhook", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 256), Size = UDim2.new(1, -100, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, WebhookPanel)
SellWebhookToggle = New("TextButton", {
    Text = "", BackgroundColor3 = Theme.RedDark, BorderSizePixel = 0,
    Position = UDim2.new(1, -62, 0, 253), Size = UDim2.new(0, 48, 0, 24),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, SellWebhookToggle)
SellWebhookKnob = New("Frame", {
    BackgroundColor3 = Theme.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(0, 18, 0, 18),
}, SellWebhookToggle)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, SellWebhookKnob)
TestSellWebhookButton = New("TextButton", {
    Text = "TEST SELL", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark, BorderSizePixel = 0,
    Position = UDim2.new(0.5, 4, 0, 216), Size = UDim2.new(0.5, -16, 0, 26),
}, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, TestSellWebhookButton)

New("TextLabel", {
    Text = "ALERTS", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 290), Size = UDim2.new(1, -24, 0, 12),
    TextXAlignment = Enum.TextXAlignment.Left,
}, WebhookPanel)
PetAlertButton = New("TextButton", { Text = "PET: ON", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White, BackgroundColor3 = Theme.Success, BorderSizePixel = 0, Position = UDim2.new(0, 12, 0, 306), Size = UDim2.new(1/3, -16, 0, 22) }, WebhookPanel)
SellAlertButton = New("TextButton", { Text = "SELL: ON", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White, BackgroundColor3 = Theme.Success, BorderSizePixel = 0, Position = UDim2.new(1/3, 4, 0, 306), Size = UDim2.new(1/3, -16, 0, 22) }, WebhookPanel)
DisconnectAlertButton = New("TextButton", { Text = "ERROR: ON", Font = Theme.Font, TextSize = 10, TextColor3 = Theme.White, BackgroundColor3 = Theme.Success, BorderSizePixel = 0, Position = UDim2.new(2/3, -4, 0, 306), Size = UDim2.new(1/3, -8, 0, 22) }, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, PetAlertButton)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SellAlertButton)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, DisconnectAlertButton)

New("TextLabel", { Text = "Sell batch interval (10-30 seconds)", Font = Theme.Font, TextSize = 11, TextColor3 = Theme.TextDim, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 340), Size = UDim2.new(0.65, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left }, WebhookPanel)
SellBatchIntervalBox = New("TextBox", { Text = "15", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.InputText, BackgroundColor3 = Theme.InputBg, BorderSizePixel = 0, ClearTextOnFocus = false, Position = UDim2.new(1, -82, 0, 336), Size = UDim2.new(0, 70, 0, 24), TextXAlignment = Enum.TextXAlignment.Center }, WebhookPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SellBatchIntervalBox)

WebhookStatusLabel = New("TextLabel", {
    Name = "WebhookStatusLabel",
    Text = "Webhook is OFF",
    Font = Theme.FontBody,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 1, -26),
    Size = UDim2.new(1, -24, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, WebhookPanel)

function updateWebhookUI()
    WebhookUrlBox.Text = webhookUrl
    SellWebhookUrlBox.Text = sellWebhookUrl
    WebhookUrlBox.TextTransparency = webhookUrlsVisible and 0 or 1
    SellWebhookUrlBox.TextTransparency = webhookUrlsVisible and 0 or 1
    WebhookUrlShowButton.Text = webhookUrlsVisible and "HIDE" or "SHOW"
    SellWebhookUrlShowButton.Text = webhookUrlsVisible and "HIDE" or "SHOW"
    WebhookToggle.BackgroundColor3 = webhookEnabled and Theme.Success or Theme.RedDark
    SafeTween(WebhookKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = webhookEnabled and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    })
    SellWebhookToggle.BackgroundColor3 = sellWebhookEnabled and Theme.Success or Theme.RedDark
    SafeTween(SellWebhookKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = sellWebhookEnabled and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    })
    PetAlertButton.Text = webhookPetAlerts and "PET: ON" or "PET: OFF"
    SellAlertButton.Text = webhookSellAlerts and "SELL: ON" or "SELL: OFF"
    DisconnectAlertButton.Text = webhookDisconnectAlerts and "ERROR: ON" or "ERROR: OFF"
    PetAlertButton.BackgroundColor3 = webhookPetAlerts and Theme.Success or Theme.RedDark
    SellAlertButton.BackgroundColor3 = webhookSellAlerts and Theme.Success or Theme.RedDark
    DisconnectAlertButton.BackgroundColor3 = webhookDisconnectAlerts and Theme.Success or Theme.RedDark
    SellBatchIntervalBox.Text = tostring(sellBatchInterval)
    WebhookStatusLabel.Text = lastWebhookStatus
    WebhookStatusLabel.TextColor3 = string.find(lastWebhookStatus, "failed", 1, true) and Theme.Text
        or (string.find(lastWebhookStatus, "sent", 1, true) and Theme.Success or Theme.Muted)
end

WebhookUrlBox.FocusLost:Connect(function()
    webhookUrl = tostring(WebhookUrlBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    saveSettings()
    updateWebhookUI()
end)

local webhookSaveSerial = 0
WebhookUrlBox:GetPropertyChangedSignal("Text"):Connect(function()
    webhookSaveSerial = webhookSaveSerial + 1
    local currentSerial = webhookSaveSerial
    task.delay(0.7, function()
        if currentSerial ~= webhookSaveSerial then return end
        webhookUrl = tostring(WebhookUrlBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        saveSettings()
    end)
end)

SellWebhookUrlBox.FocusLost:Connect(function()
    sellWebhookUrl = tostring(SellWebhookUrlBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    saveSettings()
    updateWebhookUI()
end)

SellWebhookUrlBox:GetPropertyChangedSignal("Text"):Connect(function()
    webhookSaveSerial = webhookSaveSerial + 1
    local currentSerial = webhookSaveSerial
    task.delay(0.7, function()
        if currentSerial ~= webhookSaveSerial then return end
        sellWebhookUrl = tostring(SellWebhookUrlBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        saveSettings()
    end)
end)

WebhookUrlShowButton.Activated:Connect(function()
    webhookUrlsVisible = not webhookUrlsVisible
    updateWebhookUI()
end)
SellWebhookUrlShowButton.Activated:Connect(function()
    webhookUrlsVisible = not webhookUrlsVisible
    updateWebhookUI()
end)

WebhookToggle.Activated:Connect(function()
    if not webhookEnabled and webhookUrl == "" then
        Notify("Webhook", "Paste your Discord webhook URL first.", 2)
        return
    end
    webhookEnabled = not webhookEnabled
    saveSettings()
    updateWebhookUI()
end)

SellWebhookToggle.Activated:Connect(function()
    if not sellWebhookEnabled and sellWebhookUrl == "" then
        Notify("Sell Webhook", "Paste your Sell Webhook URL first.", 2)
        return
    end
    sellWebhookEnabled = not sellWebhookEnabled
    saveSettings()
    updateWebhookUI()
end)


PetAlertButton.Activated:Connect(function() webhookPetAlerts = not webhookPetAlerts; saveSettings(); updateWebhookUI() end)
SellAlertButton.Activated:Connect(function() webhookSellAlerts = not webhookSellAlerts; saveSettings(); updateWebhookUI() end)
DisconnectAlertButton.Activated:Connect(function() webhookDisconnectAlerts = not webhookDisconnectAlerts; saveSettings(); updateWebhookUI() end)

SellBatchIntervalBox.FocusLost:Connect(function()
    sellBatchInterval = math.clamp(tonumber(SellBatchIntervalBox.Text) or sellBatchInterval, 10, 30)
    saveSettings()
    updateWebhookUI()
end)

TestWebhookButton.Activated:Connect(function()
    if not webhookEnabled or webhookUrl == "" then
        Notify("Webhook", "Enable Webhook and add a URL first.", 2)
        return
    end
    local sent, reason = sendWebhook("Webhook Connected", "Test alert from AUTO BUY PET v2.1.", 5763719)
    if sent then
        Notify("Webhook", "Test alert delivered.", 2)
    else
        Notify("Webhook", "Test failed: " .. tostring(reason or "request unavailable"), 4)
    end
    updateWebhookUI()
end)

TestSellWebhookButton.Activated:Connect(function()
    if not sellWebhookEnabled or sellWebhookUrl == "" then
        Notify("Sell Webhook", "Enable Sell Webhook and add a URL first.", 2)
        return
    end
    local sent, reason = sendWebhook("Sell Webhook Connected", "Test sell-summary alert from AUTO BUY PET v2.1.", 15105570, nil, nil, sellWebhookUrl, true)
    Notify("Sell Webhook", sent and "Test alert delivered." or ("Test failed: " .. tostring(reason or "request unavailable")), sent and 2 or 4)
    updateWebhookUI()
end)


local shecklesValueObject = nil

function readNumber(value)
    if type(value) == "number" then return value end
    if type(value) == "string" then
        return tonumber(value:gsub("[^%d%-%.]", ""))
    end
    return nil
end

function formatSheckles(value)
    local suffixes = {
        { 1000000000000, "T" },
        { 1000000000, "B" },
        { 1000000, "M" },
        { 1000, "K" },
    }
    for _, unit in ipairs(suffixes) do
        if value >= unit[1] then
            local text = string.format("%.1f", value / unit[1]):gsub("%.0$", "")
            return text .. unit[2]
        end
    end
    return tostring(math.floor(value))
end

function getSheckles()
    -- Prefer the actual replicated player stat, then fall back to a matching
    -- player attribute.  The found ValueBase is cached for cheap live updates.
    if shecklesValueObject and shecklesValueObject.Parent then
        return readNumber(shecklesValueObject.Value)
    end

    local directAttribute = readNumber(LocalPlayer:GetAttribute("Sheckles"))
        or readNumber(LocalPlayer:GetAttribute("Scheckles"))
        or readNumber(LocalPlayer:GetAttribute("Leaves"))
    if directAttribute ~= nil then return directAttribute end

    for _, item in ipairs(LocalPlayer:GetDescendants()) do
        local name = string.lower(item.Name)
        -- Garden Valley exposes Sheckles; Fall Harvest exposes Leaves. Both
        -- are shown as Sheckles in this hub for one consistent dashboard.
        if (name == "sheckles" or name == "scheckles" or name == "leaves") and item:IsA("ValueBase") then
            shecklesValueObject = item
            return readNumber(item.Value)
        end
    end
    return nil
end

function updateShecklesUI()
    local sheckles = getSheckles()
    ShecklesLabel.Text = sheckles and formatSheckles(sheckles) or "Not found"
end

function updateStatusUI()
    if petProtectEnabled then
        LiveChipLabel.Text = "● RUNNING"
        LiveChip.BackgroundColor3 = Color3.fromRGB(37, 126, 89)
        DashboardProfileStatusLabel.Text = "AUTO BUY: RUNNING"
        DashboardProfileStatusLabel.TextColor3 = Theme.Success
        ToggleButton.Text = "DISABLE AUTO BUY PET"
        ToggleButton.BackgroundColor3 = Theme.RedDark
    else
        LiveChipLabel.Text = "● STOPPED"
        LiveChip.BackgroundColor3 = Theme.RedDark
        DashboardProfileStatusLabel.Text = "AUTO BUY: STOPPED"
        DashboardProfileStatusLabel.TextColor3 = Theme.TextDim
        ToggleButton.Text = "ENABLE AUTO BUY PET"
        ToggleButton.BackgroundColor3 = Theme.Red
    end
    ElapsedLabel.Text = formatWebhookElapsed()
    BoughtLabel.Text = formatWebhookNumber(petsBought)
    SpentLabel.Text = totalSpent > 0 and "-" .. formatSheckles(totalSpent) or "0"
    ServerHopsLabel.Text = formatWebhookNumber(serverHops)
    updateShecklesUI()
    TargetLabel.Text = "TARGETS  •  " .. targetDisplayText
end

function normalizeRarity(value)
    if type(value) ~= "string" then return nil end
    local lowered = string.lower(value)
    for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Legendary", "Mythic", "Super", "Secret" }) do
        if lowered == string.lower(rarity) then
            return rarity
        end
    end
    return nil
end

function findRarityOverride(petName)
    if type(petName) ~= "string" or petName == "" then return nil end

    local exact = PET_RARITY_OVERRIDES[petName]
    if exact then return exact end

    -- Wild-pet models can be named "Bunny_123", "Bunny (1)", etc.
    -- Compare normalized names so these still match the confirmed table.
    local normalizedName = string.lower(petName):gsub("[^%a%d]", "")
    for configuredName, rarity in pairs(PET_RARITY_OVERRIDES) do
        local normalizedConfigured = string.lower(configuredName):gsub("[^%a%d]", "")
        if normalizedName == normalizedConfigured
            or string.find(normalizedName, normalizedConfigured, 1, true) then
            return rarity
        end
    end
    return nil
end

function getWildPetSpeciesName(pet)
    -- Spawn names follow: WildPet_<Species>_WildPet_<random id>
    -- Example: WildPet_Bunny_WildPet_ce4fb5c1-...
    local species = pet.Name:match("^WildPet_([^_]+)_WildPet_")
    return species or pet.Name
end

function getSizeTierFromInstance(instance)
    if not instance then return nil end

    for _, attributeName in ipairs({
        "Size", "SizeType", "PetSize", "PetSizeType", "Variant", "VariantType", "SpecialType",
    }) do
        local value = instance:GetAttribute(attributeName)
        if type(value) == "string" then
            local lowered = string.lower(value)
            if lowered:find("huge", 1, true) or lowered:find("giant", 1, true) then
                return "Huge"
            end
            if lowered:find("big", 1, true) then
                return "Big"
            end
        end
    end

    if instance:GetAttribute("IsHuge") == true or instance:GetAttribute("Huge") == true then
        return "Huge"
    end
    if instance:GetAttribute("IsBig") == true or instance:GetAttribute("Big") == true then
        return "Big"
    end

    for _, attributeName in ipairs({ "SizeMultiplier", "ScaleMultiplier", "PetScale" }) do
        local value = tonumber(instance:GetAttribute(attributeName))
        if value then
            if value >= 1.5 then return "Huge" end
            if value > 1.1 then return "Big" end
        end
    end

    local name = string.lower(tostring(instance.Name or ""))
    if name:find("huge", 1, true) or name:find("giant", 1, true) then
        return "Huge"
    end
    if name:find("big", 1, true) then
        return "Big"
    end
    return nil
end

function getPetSizeTier(pet, petRef, petName)
    local bestTier = nil
    local function consider(instance)
        local tier = getSizeTierFromInstance(instance)
        if tier == "Huge" then
            bestTier = "Huge"
        elseif tier == "Big" and not bestTier then
            bestTier = "Big"
        end
    end

    consider(pet)
    consider(petRef)

    -- Never infer size from another same-species tool in Backpack. An older
    -- Big Squirrel must not label every newly bought normal Squirrel as Big.

    return bestTier
end

-- Wild-pet spawn models can expose the size on either the model itself or a
-- descendant. Unlike the inventory helper above, this deliberately never
-- reads Backpack tools: it is used only to decide what to chase next.
function getWildPetSizeTier(pet)
    local foundBig = false
    local function consider(instance)
        local tier = getSizeTierFromInstance(instance)
        if tier == "Huge" then return "Huge" end
        if tier == "Big" then foundBig = true end
        return nil
    end

    if consider(pet) == "Huge" then return "Huge" end
    if pet then
        for _, descendant in ipairs(pet:GetDescendants()) do
            if consider(descendant) == "Huge" then return "Huge" end
        end

        -- Some places keep the live WildPet size on its matching Map ref.
        -- Check it as well, without ever consulting already-owned pets.
        local map = workspace:FindFirstChild("Map")
        local refs = map and map:FindFirstChild("WildPetRef")
        if refs then
            for _, ref in ipairs(refs:GetChildren()) do
                if ref.Name ~= "" and string.find(pet.Name, ref.Name, 1, true) then
                    if consider(ref) == "Huge" then return "Huge" end
                    break
                end
            end
        end
    end
    return foundBig and "Big" or nil
end

function getWildPetSizePriority(pet)
    local sizeTier = getWildPetSizeTier(pet)
    if sizeTier == "Huge" and buyHugePetsPriority then
        return 2, sizeTier
    end
    if sizeTier == "Big" and buyBigPetsPriority then
        return 1, sizeTier
    end
    return 0, sizeTier
end

function getPetRarity(pet)
    -- Try the model name first, then common species/name attributes used by
    -- wild-pet containers in case the model itself has a generic name.
    local candidateNames = { getWildPetSpeciesName(pet), pet.Name }
    for _, attributeName in ipairs({ "PetName", "Species", "PetSpecies" }) do
        local attributeValue = pet:GetAttribute(attributeName)
        if type(attributeValue) == "string" then
            table.insert(candidateNames, attributeValue)
        end
    end
    for _, candidateName in ipairs(candidateNames) do
        local override = findRarityOverride(candidateName)
        if override then
            return override
        end
    end

    for _, attributeName in ipairs({ "Rarity", "PetRarity", "Tier" }) do
        local rarity = normalizeRarity(pet:GetAttribute(attributeName))
        if rarity then return rarity end

        local valueObject = pet:FindFirstChild(attributeName, true)
        if valueObject and valueObject:IsA("StringValue") then
            rarity = normalizeRarity(valueObject.Value)
            if rarity then return rarity end
        end
    end

    for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Legendary", "Mythic", "Super", "Secret" }) do
        if string.find(string.lower(pet.Name), string.lower(rarity), 1, true) then
            return rarity
        end
    end

    return "Unknown"
end

-- =========================================================
-- ALWAYS-ON WILD PET LABELS
-- Shown independently from Auto Buy Pet. Re-executing the hub replaces the
-- old labels so duplicate text is never left above pets.
-- =========================================================
local WILD_PET_LABEL_FOLDER = "ScoopHubWildPetLabels"
local WILD_PET_RARITY_COLORS = {
    Common = Color3.fromRGB(235, 235, 235),
    Uncommon = Color3.fromRGB(91, 235, 120),
    Rare = Color3.fromRGB(82, 184, 255),
    Legendary = Color3.fromRGB(255, 211, 75),
    Mythic = Color3.fromRGB(255, 83, 99),
    Super = Color3.fromRGB(196, 113, 255),
    Secret = Color3.fromRGB(255, 255, 255),
    Unknown = Color3.fromRGB(235, 235, 235),
}

local wildPetLabelConnections = {}
local wildPetLabels = {}
local sharedEnvironment = type(getgenv) == "function" and getgenv() or _G

if type(sharedEnvironment.ScoopHubStopWildPetLabels) == "function" then
    pcall(sharedEnvironment.ScoopHubStopWildPetLabels)
end

function stopWildPetLabels()
    for _, connection in ipairs(wildPetLabelConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(wildPetLabelConnections)
    table.clear(wildPetLabels)

    local existingFolder = workspace:FindFirstChild(WILD_PET_LABEL_FOLDER)
    if existingFolder then
        existingFolder:Destroy()
    end
end

sharedEnvironment.ScoopHubStopWildPetLabels = stopWildPetLabels

function startWildPetLabels()
    stopWildPetLabels()

    local labelFolder = Instance.new("Folder")
    labelFolder.Name = WILD_PET_LABEL_FOLDER
    labelFolder.Parent = workspace

    local function removeLabel(pet)
        local label = wildPetLabels[pet]
        if label then
            wildPetLabels[pet] = nil
            label:Destroy()
        end
    end

    local function addLabel(pet)
        if not pet or not pet:IsA("Model") or wildPetLabels[pet] or not pet.Parent then
            return
        end

        local adornee = pet.PrimaryPart or pet:FindFirstChildWhichIsA("BasePart", true)
        if not adornee then
            return
        end

        local petName = getWildPetSpeciesName(pet)
        local sizeTier = getWildPetSizeTier(pet) or "Normal"
        local rarity = getPetRarity(pet)

        local label = Instance.new("BillboardGui")
        label.Name = "WildPetLabel"
        label.Adornee = adornee
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.Size = UDim2.fromOffset(240, 34)
        label.StudsOffset = Vector3.new(0, 4, 0)
        label.Parent = labelFolder

        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.BorderSizePixel = 0
        text.Size = UDim2.fromScale(1, 1)
        text.Font = Enum.Font.GothamBold
        text.TextSize = 15
        text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        text.TextStrokeTransparency = 0.2
        text.TextColor3 = WILD_PET_RARITY_COLORS[rarity] or WILD_PET_RARITY_COLORS.Unknown
        text.Text = string.format("%s [%s] • %s", petName, sizeTier, rarity)
        text.Parent = label

        wildPetLabels[pet] = label
        table.insert(wildPetLabelConnections, pet.AncestryChanged:Connect(function(_, parent)
            if not parent then
                removeLabel(pet)
            end
        end))
    end

    task.spawn(function()
        local deadline = os.clock() + 20
        local wildPetSpawns
        repeat
            local map = workspace:FindFirstChild("Map")
            wildPetSpawns = map and map:FindFirstChild("WildPetSpawns")
            if not wildPetSpawns then
                task.wait(0.25)
            end
        until wildPetSpawns or os.clock() >= deadline

        if not wildPetSpawns or not labelFolder.Parent then
            return
        end

        for _, pet in ipairs(wildPetSpawns:GetChildren()) do
            addLabel(pet)
            task.delay(1, function()
                addLabel(pet)
            end)
        end

        table.insert(wildPetLabelConnections, wildPetSpawns.ChildAdded:Connect(function(pet)
            task.delay(0.1, function()
                addLabel(pet)
            end)
            task.delay(1, function()
                addLabel(pet)
            end)
        end))
        table.insert(wildPetLabelConnections, wildPetSpawns.ChildRemoved:Connect(removeLabel))
    end)
end

-- =========================================================
-- PET PROTECT LOGIC + CENTRALIZED AUTO SERVER HOP V13
-- =========================================================
Theme.GetServerHopCandidates = function()
    local freshLow = {}
    local visitedLow = {}
    local freshAny = {}
    local visitedAny = {}
    local claimed = Theme.ServerHopClaims.GetClaimed()

    Theme.ServerHopClaims.Debug("=== V13 CURSOR-ROTATING SHARED 100-BATCH SEARCH START ===")

    -- One request, one page, up to 100 servers.  This mirrors the request
    -- pattern confirmed by the working comparison script.
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"

    local page, fetchError = Theme.ServerHopClaims.GetSharedServerPage(url)
    if not page then
        Theme.ServerHopClaims.LastLookupError = fetchError or "shared server-list request failed"
        Theme.ServerHopClaims.Debug("SEARCH RESULT: fetch/cache failed: " .. tostring(Theme.ServerHopClaims.LastLookupError))
        return nil
    end

    Theme.ServerHopClaims.LastLookupError = nil
    Theme.ServerHopClaims.LastBatchId = tostring(page._ScoopHubBatchId or "")
    Theme.ServerHopClaims.Debug(string.format(
        "SEARCH SOURCE batchId=%s cacheAge=%s shared=%s",
        tostring(Theme.ServerHopClaims.LastBatchId),
        tostring(page._ScoopHubCacheAge or "live"),
        tostring(page._ScoopHubFromSharedCache == true)
    ))

    local accepted = 0
    local claimedByOther = 0
    local blocked = 0
    local full = 0

    for _, server in ipairs(page.data or {}) do
        local players = tonumber(server.playing) or 0
        local maxPlayers = tonumber(server.maxPlayers) or math.huge
        local jobId = tostring(server.id or "")

        if jobId == "" then
            blocked = blocked + 1
        elseif players >= maxPlayers then
            full = full + 1
        elseif claimed[jobId] then
            claimedByOther = claimedByOther + 1
        elseif Theme.ServerHopClaims.IsBlocked(jobId, true) then
            blocked = blocked + 1
        elseif players >= 1 then
            accepted = accepted + 1
            local wasVisited = Theme.ServerHopClaims.VisitedJobIds[jobId] == true
            if players <= 6 then
                table.insert(wasVisited and visitedLow or freshLow, server)
            else
                table.insert(wasVisited and visitedAny or freshAny, server)
            end
        end
    end

    local function sortPool(pool)
        table.sort(pool, function(a, b)
            local ap = tonumber(a.playing) or math.huge
            local bp = tonumber(b.playing) or math.huge
            if ap ~= bp then return ap < bp end
            local aping = tonumber(a.ping) or math.huge
            local bping = tonumber(b.ping) or math.huge
            if aping ~= bping then return aping < bping end
            return tostring(a.id or "") < tostring(b.id or "")
        end)
    end

    sortPool(freshLow)
    sortPool(visitedLow)
    sortPool(freshAny)
    sortPool(visitedAny)

    local candidates = {}
    local function appendPool(pool, allowVisited, label)
        if #pool == 0 then return end

        -- Give each account a different starting position inside the same
        -- server page.  Reservations still arbitrate any collision.
        local startIndex = ((LocalPlayer.UserId + Theme.ServerHopClaims.SelectionSequence * 17) % #pool) + 1
        for offset = 0, #pool - 1 do
            local index = ((startIndex + offset - 1) % #pool) + 1
            local server = pool[index]
            server._ScoopHubAllowVisited = allowVisited
            server._ScoopHubPopulationLabel = label
            table.insert(candidates, server)
        end
    end

    Theme.ServerHopClaims.SelectionSequence = Theme.ServerHopClaims.SelectionSequence + 1
    appendPool(freshLow, false, "1-6 player")
    appendPool(visitedLow, true, "1-6 player (previously visited)")
    appendPool(freshAny, false, "non-full")
    appendPool(visitedAny, true, "non-full (previously visited)")

    Theme.ServerHopClaims.Debug(string.format(
        "ONE_PAGE parsed=%d accepted=%d claimedByOther=%d blocked=%d full=%d pools[freshLow=%d visitedLow=%d freshAny=%d visitedAny=%d] candidates=%d",
        #(page.data or {}), accepted, claimedByOther, blocked, full,
        #freshLow, #visitedLow, #freshAny, #visitedAny, #candidates
    ))

    if #candidates == 0 then
        Theme.ServerHopClaims.Debug("SEARCH RESULT: no usable candidate in this 100-server page")
        return {}
    end

    local first = candidates[1]
    Theme.ServerHopClaims.Debug(string.format(
        "SEARCH RESULT: first candidate jobId=%s players=%s/%s category=%s totalCandidates=%d",
        tostring(first.id), tostring(first.playing), tostring(first.maxPlayers),
        tostring(first._ScoopHubPopulationLabel), #candidates
    ))
    return candidates
end

-- Compatibility helper for any external/debug code that still calls the old
-- singular function name.  It performs the same single request and returns the
-- first candidate only.
Theme.FindLowPopulationServer = function()
    local candidates = Theme.GetServerHopCandidates()
    return candidates and candidates[1] or nil
end

function waitForPendingPetDelivery()
    local startedAt = tick()
    while pendingPetDelivery and tick() - startedAt < 20 do
        task.wait(0.1)
    end
    return not pendingPetDelivery
end

Theme.ServerHopController = Theme.ServerHopController or {}
do
    local H = Theme.ServerHopController
    H.Source = nil
    H.RetryCount = 0
    H.CycleToken = 0
    H.TargetJobId = nil
    H.StartCounted = false
    H.QueuePrepared = false
    H.BatchCandidates = nil
    H.BatchIndex = 0
    -- Job IDs stay physically inside BatchCandidates after failures.
    -- This table only remembers which entries were already attempted during
    -- the current batch so we can move forward without deleting them.
    H.BatchAttempted = {}
    H.BatchId = nil
    H.TargetBatchIndex = nil
    H.CurrentRoute = nil
    H.CurrentPopulationLabel = "server"
    H.IgnoreTeleportStateFailedUntil = 0
    H.LastFullFailureAt = 0

    function H.RetryDelay()
        -- A fresh retry means one fresh server-list request. Keep those attempts
        -- spaced out; Error 772 does NOT use this path while batch candidates remain.
        local delays = { 4.0, 6.0, 8.0, 10.0, 12.0 }
        local base = delays[math.min(H.RetryCount, #delays)] or 12.0
        return base + (((LocalPlayer.UserId + H.RetryCount * 11) % 7) * 0.15)
    end

    function H.ResetBatch()
        H.BatchCandidates = nil
        H.BatchIndex = 0
        H.BatchAttempted = {}
        H.BatchId = nil
        H.TargetBatchIndex = nil
        H.CurrentRoute = nil
        H.CurrentPopulationLabel = "server"
    end

    function H.RemoveSuccessfulBatchJobId(jobId)
        -- IMPORTANT: a Job ID is removed from the in-memory 100-server batch
        -- ONLY after Roblox reports TeleportState.Started for that exact target.
        -- Failed/full/unavailable Job IDs remain in BatchCandidates and are only
        -- marked attempted for this batch.
        if H.CurrentRoute ~= "random" or type(H.BatchCandidates) ~= "table" then
            return false
        end

        jobId = tostring(jobId or "")
        if jobId == "" then return false end

        for index = #H.BatchCandidates, 1, -1 do
            local server = H.BatchCandidates[index]
            if tostring(server and server.id or "") == jobId then
                table.remove(H.BatchCandidates, index)
                if H.BatchIndex >= index then
                    H.BatchIndex = math.max(0, H.BatchIndex - 1)
                end
                H.BatchAttempted[jobId] = nil
                H.TargetBatchIndex = nil
                Theme.ServerHopClaims.ConsumeSuccessfulJobId(jobId, H.BatchId)
                Theme.ServerHopClaims.Debug(string.format(
                    "BATCH DELETE ON SUCCESS jobId=%s batchId=%s remaining=%d",
                    jobId, tostring(H.BatchId or ""), #H.BatchCandidates
                ))
                return true
            end
        end

        return false
    end

    function H.Cancel(showMessage)
        if not serverHopInProgress then return end
        H.CycleToken = H.CycleToken + 1
        serverHopInProgress = false
        H.Source = nil
        H.RetryCount = 0
        H.TargetJobId = nil
        H.TargetBatchIndex = nil
        H.StartCounted = false
        H.QueuePrepared = false
        H.IgnoreTeleportStateFailedUntil = 0
        H.ResetBatch()
        Theme.ServerHopClaims.Clear()
        if showMessage then Notify("Server Hop", tostring(showMessage), 2) end
    end

    function H.ScheduleRetry(message, delayOverride)
        if not serverHopInProgress then return end
        H.RetryCount = H.RetryCount + 1
        local delaySeconds = tonumber(delayOverride) or H.RetryDelay()
        local token = H.CycleToken

        -- A scheduled retry is a brand-new attempt, so discard the old 100-server
        -- page. Same-page failover is handled separately by TryNextBatchCandidate().
        H.ResetBatch()

        if message and message ~= "" then
            Notify(
                "Server Hop",
                tostring(message) .. " Retrying in " .. string.format("%.1f", delaySeconds) .. "s...",
                3
            )
        end

        task.delay(delaySeconds, function()
            if serverHopInProgress and H.CycleToken == token then
                H.Perform()
            end
        end)
    end

    function H.ReserveNextBatchCandidate()
        if type(H.BatchCandidates) ~= "table" then return nil, nil end

        while H.BatchIndex < #H.BatchCandidates do
            H.BatchIndex = H.BatchIndex + 1
            local server = H.BatchCandidates[H.BatchIndex]
            local jobId = tostring(server and server.id or "")
            local allowVisited = server and server._ScoopHubAllowVisited == true

            -- Do not delete failed entries. We just skip anything already attempted
            -- during this one downloaded batch and move to the next stored Job ID.
            if jobId ~= "" and not H.BatchAttempted[jobId] then
                if Theme.ServerHopClaims.TryReserve(jobId, allowVisited) then
                    H.BatchAttempted[jobId] = true
                    H.TargetBatchIndex = H.BatchIndex
                    return jobId, tostring(server._ScoopHubPopulationLabel or "server")
                end
            end
            task.wait(0.03)
        end

        return nil, nil
    end

    function H.FinalReservationStillOurs(targetJobId)
        -- V12 final permanent-history check. Do this even before the claim scan
        -- so a stale in-memory candidate can never be launched after another
        -- account has already successfully entered it.
        if Theme.ServerHopClaims.IsGloballyUsed(targetJobId) then
            Theme.ServerHopClaims.Debug(
                "FINAL RESERVATION REJECT global-used jobId=" .. tostring(targetJobId)
            )
            return false
        end

        if not Theme.ServerHopClaims.SharedSupported then return true end

        local stillOurs = false
        local blockedByCurrent = false
        local winnerUserId = LocalPlayer.UserId

        for _, claim in ipairs(Theme.ServerHopClaims.Read()) do
            local uid = tonumber(claim.userId)
            if uid == LocalPlayer.UserId and tostring(claim.reservedJobId or "") == targetJobId then
                stillOurs = true
            elseif uid and uid ~= LocalPlayer.UserId then
                if tostring(claim.currentJobId or "") == targetJobId then
                    blockedByCurrent = true
                elseif tostring(claim.reservedJobId or "") == targetJobId then
                    winnerUserId = math.min(winnerUserId, uid)
                end
            end
        end

        if Theme.ServerHopClaims.IsGloballyUsed(targetJobId) then
            Theme.ServerHopClaims.Debug(
                "FINAL RESERVATION REJECT global-used-after-claim-scan jobId="
                    .. tostring(targetJobId)
            )
            return false
        end

        return stillOurs and not blockedByCurrent and winnerUserId == LocalPlayer.UserId
    end

    function H.LaunchReservedTarget(routeName, populationLabel, messageOverride)
        if not serverHopInProgress or not H.TargetJobId then return false end

        local token = H.CycleToken
        local targetJobId = H.TargetJobId
        H.CurrentRoute = routeName or H.CurrentRoute or "random"
        H.CurrentPopulationLabel = populationLabel or H.CurrentPopulationLabel or "server"
        H.StartCounted = false

        Notify(
            "Server Hop",
            messageOverride
                or (H.CurrentRoute == "custom"
                    and "Reserved a unique saved Job ID. Hopping..."
                    or ("Reserved a unique " .. H.CurrentPopulationLabel .. " server. Hopping...")),
            2
        )

        if isKRNL and not H.QueuePrepared then
            enableKRNLQueue()
            H.QueuePrepared = true
        end

        saveSettings()
        task.wait(0.35)

        if not serverHopInProgress or H.CycleToken ~= token or H.TargetJobId ~= targetJobId then
            return false
        end

        -- Final shared-filesystem ownership check immediately before teleport.
        if not H.FinalReservationStillOurs(targetJobId) then
            H.TargetJobId = nil
            H.TargetBatchIndex = nil
            Theme.ServerHopClaims.Clear()

            if H.CurrentRoute == "random" then
                local nextJobId, nextLabel = H.ReserveNextBatchCandidate()
                if nextJobId then
                    H.TargetJobId = nextJobId
                    task.spawn(function()
                        H.LaunchReservedTarget(
                            "random",
                            nextLabel,
                            "Another account won that Job ID. Trying another server from the same list..."
                        )
                    end)
                    return false
                end
            end

            H.ScheduleRetry("Another account won that Job ID reservation.", 4.0)
            return false
        end

        Theme.ServerHopClaims.Debug(string.format(
            "TELEPORT TRY batchIndex=%s/%s jobId=%s route=%s",
            tostring(H.BatchIndex),
            type(H.BatchCandidates) == "table" and tostring(#H.BatchCandidates) or "custom",
            tostring(targetJobId),
            tostring(H.CurrentRoute)
        ))

        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, LocalPlayer)
        end)

        if not success then
            H.HandleFailure(err, H.CurrentRoute == "random", false)
            return false
        end

        return true
    end

    function H.TryNextBatchCandidate(reason)
        if not serverHopInProgress or H.CurrentRoute ~= "random" then return false end

        local nextJobId, nextLabel = H.ReserveNextBatchCandidate()
        if not nextJobId then
            return false
        end

        H.TargetJobId = nextJobId
        H.StartCounted = false

        Theme.ServerHopClaims.Debug(string.format(
            "SAME_BATCH FAILOVER nextJobId=%s batchIndex=%d/%d reason=%s",
            tostring(nextJobId),
            H.BatchIndex,
            type(H.BatchCandidates) == "table" and #H.BatchCandidates or 0,
            tostring(reason or "unknown")
        ))

        task.spawn(function()
            H.LaunchReservedTarget(
                "random",
                nextLabel,
                "Previous server was unavailable. Trying another Job ID from the same 100-server list..."
            )
        end)
        return true
    end

    function H.HandleFailure(reason, preferSameBatch, isServerFull)
        if not serverHopInProgress or not H.TargetJobId then return end

        local failedJobId = H.TargetJobId
        H.TargetJobId = nil
        H.TargetBatchIndex = nil
        H.StartCounted = false
        H.IgnoreTeleportStateFailedUntil = tick() + 1.75

        -- V9 rule: NEVER delete/remove the failed Job ID from the downloaded
        -- 100-server batch. It is already marked in BatchAttempted, which is
        -- enough to skip it for the rest of this batch. Do not call MarkFailed()
        -- here because that would globally block/consume the Job ID before a
        -- successful hop. Release only our cross-account reservation.
        if H.CurrentRoute == "random" then
            H.BatchAttempted[failedJobId] = true
        end
        Theme.ServerHopClaims.Clear()

        print("[AutoBuyPet] Teleport failed for " .. tostring(failedJobId) .. ": " .. tostring(reason or "unknown"))
        Theme.ServerHopClaims.Debug(string.format(
            "TELEPORT FAILED jobId=%s serverFull=%s keptInBatch=%s reason=%s",
            tostring(failedJobId), tostring(isServerFull == true),
            tostring(H.CurrentRoute == "random"), tostring(reason or "unknown")
        ))

        local token = H.CycleToken
        task.delay(isServerFull and 0.45 or 0.60, function()
            if not serverHopInProgress or H.CycleToken ~= token or H.TargetJobId then return end

            -- For random hopping, ANY target-specific teleport failure first walks
            -- the remaining Job IDs already stored in this same 100-server batch.
            if (preferSameBatch or H.CurrentRoute == "random")
                and H.CurrentRoute == "random"
                and H.TryNextBatchCandidate(reason) then
                return
            end

            if H.CurrentRoute == "random" then
                Theme.ServerHopClaims.MarkBatchExhausted(H.BatchId)
                H.ScheduleRetry(
                    "All usable Job IDs in this shared 100-server batch were tried; advancing to the next cursor page.",
                    isServerFull and 4.0 or nil
                )
            else
                H.ScheduleRetry("Teleport failed; choosing a different server.")
            end
        end)
    end

    function H.IsServerFullFailure(teleportResult, errorMessage)
        local text = string.lower(tostring(teleportResult or "") .. " " .. tostring(errorMessage or ""))
        return text:find("772", 1, true) ~= nil
            or text:find("server is full", 1, true) ~= nil
            or text:find("gamefull", 1, true) ~= nil
            or text:find("game full", 1, true) ~= nil
    end

    function H.Perform()
        if not serverHopInProgress then return end

        if not waitForPendingPetDelivery() then
            H.Cancel("Waiting for " .. (pendingPetDeliveryName ~= "" and pendingPetDeliveryName or "the bought pet") .. " to arrive in your Backpack.")
            return
        end

        H.ResetBatch()

        local targetJobId = nil
        local routeName = "random"
        local populationLabel = "server"

        -- Custom Job IDs need no server-list HTTP request. Try the saved rotation
        -- first, while still respecting cross-account reservations.
        if #customJobIds > 0 then
            for _ = 1, #customJobIds do
                local customJobId = Theme.ServerHopClaims.NextCustomJobId()
                if not customJobId then break end
                if Theme.ServerHopClaims.TryReserve(customJobId, false) then
                    targetJobId = customJobId
                    routeName = "custom"
                    populationLabel = "saved Job ID"
                    break
                end
                task.wait(0.05)
            end
        end

        -- Random route: exactly ONE server-list request for this Perform() call.
        -- Keep the ENTIRE filtered candidate list in memory. Failed Job IDs are
        -- never removed from this table; they are only marked attempted. A Job ID
        -- is deleted from the batch only after TeleportState.Started confirms success.
        if not targetJobId then
            local candidates = Theme.GetServerHopCandidates()

            if candidates == nil then
                local retryDelay = Theme.ServerHopClaims.LastLookupRetryDelay
                H.ScheduleRetry(
                    (Theme.ServerHopClaims.LastLookupError or "Server-list request failed")
                        .. "; debug saved to " .. Theme.ServerHopClaims.DebugFile .. ".",
                    retryDelay
                )
                return
            end

            H.BatchCandidates = candidates
            H.BatchId = Theme.ServerHopClaims.LastBatchId
            H.BatchIndex = 0
            targetJobId, populationLabel = H.ReserveNextBatchCandidate()
            routeName = "random"
        end

        if not targetJobId then
            if routeName == "random" then
                Theme.ServerHopClaims.MarkBatchExhausted(H.BatchId)
            end
            H.ScheduleRetry("No unique usable server was free in this shared 100-server batch; advancing cursor page.", 5.0)
            return
        end

        H.TargetJobId = targetJobId
        H.CurrentRoute = routeName
        H.CurrentPopulationLabel = populationLabel
        H.StartCounted = false
        H.LaunchReservedTarget(routeName, populationLabel)
    end

    function H.Begin(source)
        source = source or "manual"

        if serverHopInProgress then
            if source == "manual" then
                Notify("Server Hop", "A server hop is already being prepared.", 2)
            end
            return false
        end

        H.CycleToken = H.CycleToken + 1
        serverHopInProgress = true
        H.Source = source
        H.RetryCount = 0
        H.TargetJobId = nil
        H.TargetBatchIndex = nil
        H.StartCounted = false
        H.QueuePrepared = false
        H.IgnoreTeleportStateFailedUntil = 0
        H.ResetBatch()
        task.spawn(H.Perform)
        return true
    end

    function H.GetSource()
        return H.Source
    end

    _G.ScoopHubTeleportStateHandler = function(teleportState)
        if teleportState == Enum.TeleportState.Started then
            print("[AutoBuyPet] Teleport started - saving state...")

            if serverHopInProgress and H.TargetJobId and not H.StartCounted then
                H.StartCounted = true

                -- V12: this is the permanent cross-account "used once" commit.
                -- It runs only after Roblox confirms TeleportState.Started.
                -- Failed / 772 JobIds never reach this write.
                Theme.ServerHopClaims.MarkGloballyUsed(
                    H.TargetJobId,
                    "TeleportState.Started"
                )

                -- This is the ONLY point where a random Job ID is deleted from
                -- the in-memory batch: Roblox has confirmed the teleport started.
                H.RemoveSuccessfulBatchJobId(H.TargetJobId)
                Theme.ServerHopClaims.MarkVisited(H.TargetJobId)
                serverHops = serverHops + 1
                if ServerHopsLabel then
                    ServerHopsLabel.Text = formatWebhookNumber(serverHops)
                end
                addActivity("Server hop " .. tostring(serverHops) .. " started")
            end

            if saveSettings then pcall(saveSettings) end
        elseif teleportState == Enum.TeleportState.Failed then
            -- TeleportInitFailed / ErrorMessageChanged may already have handled a
            -- GameFull (772) and queued the next same-page target. Ignore that
            -- duplicate state event briefly so it cannot fail the new Job ID.
            if tick() >= (H.IgnoreTeleportStateFailedUntil or 0) then
                H.HandleFailure(
                    "Roblox reported TeleportState.Failed",
                    H.CurrentRoute == "random",
                    false
                )
            end
        end
    end

    _G.ScoopHubTeleportInitFailedHandler = function(player, teleportResult, errorMessage, placeId, teleportOptions)
        if player ~= LocalPlayer or not serverHopInProgress or not H.TargetJobId then return end

        local isFull = H.IsServerFullFailure(teleportResult, errorMessage)
        local reason = tostring(teleportResult or "TeleportInitFailed")
            .. (tostring(errorMessage or "") ~= "" and (": " .. tostring(errorMessage)) or "")

        if isFull then
            H.LastFullFailureAt = tick()
            Notify(
                "Server Hop",
                "Server is full (Error 772). Trying another Job ID from the same 100-server list...",
                3
            )
            H.HandleFailure(reason, true, true)
        else
            H.HandleFailure(reason, H.CurrentRoute == "random", false)
        end
    end

    _G.ScoopHubTeleport772Handler = function(message)
        if not serverHopInProgress or not H.TargetJobId then return end
        -- Avoid double-handling when both TeleportInitFailed and the Roblox error
        -- UI report the same full-server failure.
        if tick() - (H.LastFullFailureAt or 0) < 1.5 then return end

        H.LastFullFailureAt = tick()
        Notify(
            "Server Hop",
            "Server is full (Error 772). Trying another Job ID from the same 100-server list...",
            3
        )
        H.HandleFailure(tostring(message or "Error 772: Server is full"), true, true)
    end
end

Theme.SetPetProtectEnabled = function(enabled)
    petProtectEnabled = enabled == true
    if petProtectEnabled and not autoBuyRuntimeStartedAt then
        autoBuyRuntimeStartedAt = os.time()
    elseif not petProtectEnabled and autoBuyRuntimeStartedAt then
        autoBuyRuntimeSeconds = autoBuyRuntimeSeconds + math.max(0, os.time() - autoBuyRuntimeStartedAt)
        autoBuyRuntimeStartedAt = nil
    end
    rebuildTargetList()
    updateStatusUI()
    saveSettings()

    if not petProtectEnabled then
        if serverHopInProgress and Theme.ServerHopController.GetSource() == "auto" then
            Theme.ServerHopController.Cancel(nil)
        end
        -- Cancel any outstanding MoveTo immediately. Waiting for the worker's
        -- next loop made the character keep walking after the toggle was OFF.
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid:Move(Vector3.new(0, 0, 0), false)
            if root then
                humanoid:MoveTo(root.Position)
            end
            humanoid.WalkSpeed = 16
        end
    end

    if petProtectEnabled then
        if #targetPetNames == 0 and not buyBigPetsPriority and not buyHugePetsPriority then
            Notify("Error", "Select a target pet or enable a size priority first!", 3)
            petProtectEnabled = false
            if autoBuyRuntimeStartedAt then
                autoBuyRuntimeSeconds = autoBuyRuntimeSeconds + math.max(0, os.time() - autoBuyRuntimeStartedAt)
                autoBuyRuntimeStartedAt = nil
            end
            updateStatusUI()
            saveSettings()
            return
        end

        Notify("Buy Protect", "Started — Buying and Protecting: " .. formatList(targetPetNames), 3)
        addActivity("Auto Buy Pet enabled")

        petProtectThread = task.spawn(function()
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")
            local hrp = character:WaitForChild("HumanoidRootPart")
            local backpack = LocalPlayer:WaitForChild("Backpack")

            local FOLLOW_DISTANCE = 1.0
            local RETURN_DISTANCE = 9
            local MIN_Y = -20
            local NO_PET_TIMEOUT = 18 -- seconds with no pets before rejoin

            humanoid.WalkSpeed = petWalkSpeed
            humanoid.AutoRotate = true

            local runTarget = nil
            local currentTargetPet = nil
            local fastApproach = false
            local claimedWildPets = {}
            local noPetTimer = 0
            local targetSpawnConn = nil

            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and string.find(string.lower(tool.Name), "shovel") then
                    humanoid:EquipTool(tool)
                    break
                end
            end

            local groundReferences = {}
            local baseplateModel = workspace:FindFirstChild("Baseplate")
            if baseplateModel then
                local topLayer = baseplateModel:FindFirstChild("TopLayer")
                table.insert(groundReferences, topLayer or baseplateModel)
            end
            if workspace:FindFirstChild("Terrain") then
                table.insert(groundReferences, workspace.Terrain)
            end

            local groundRaycastParams = nil
            if #groundReferences > 0 then
                groundRaycastParams = RaycastParams.new()
                groundRaycastParams.FilterType = Enum.RaycastFilterType.Include
                groundRaycastParams.FilterDescendantsInstances = groundReferences
            end

            local function getGroundY(position)
                if not groundRaycastParams then return -math.huge end
                local result = workspace:Raycast(
                    position + Vector3.new(0, 50, 0),
                    Vector3.new(0, -2000, 0),
                    groundRaycastParams
                )
                return result and result.Position.Y or -math.huge
            end

            local GROUND_CLEARANCE = (humanoid.HipHeight or 2) + (hrp.Size.Y / 2) + 0.05

            local function cframeBeside(position, stopDistance)
                if not hrp or not position then return end

                local horizontal = Vector3.new(
                    position.X - hrp.Position.X,
                    0,
                    position.Z - hrp.Position.Z
                )
                if horizontal.Magnitude < 0.1 then return end

                local destination = position - (horizontal.Unit * (stopDistance or 3))
                local destinationGroundY = getGroundY(destination)
                if destinationGroundY > -math.huge then
                    destination = Vector3.new(
                        destination.X,
                        destinationGroundY + GROUND_CLEARANCE,
                        destination.Z
                    )
                else
                    destination = Vector3.new(destination.X, position.Y + 2.5, destination.Z)
                end

                hrp.CFrame = CFrame.lookAt(
                    destination,
                    Vector3.new(position.X, destination.Y, position.Z)
                )
            end

            local function forceRun()
                if not humanoid then return end
                if not petProtectEnabled then
                    humanoid:Move(Vector3.new(0, 0, 0), false)
                    return
                end
                -- Some in-game interfaces temporarily put the character in a
                -- non-walkable state.  Like the older script, clear this on
                -- every heartbeat so the opening game GUI cannot leave the
                -- character frozen before a pet is found.
                humanoid.PlatformStand = false
                humanoid.Sit = false
                humanoid.AutoRotate = true
                if hrp then
                    hrp.Anchored = false
                end
                -- Read the current setting every heartbeat so edits take
                -- effect immediately without having to restart Auto Buy.
                -- Always respect the configured walk speed while Auto Buy Pet
                -- is enabled. Target distance must never silently force 70+.
                humanoid.WalkSpeed = petWalkSpeed

                -- No matching pet: do not submit a MoveTo command. The player
                -- keeps full manual control while the script waits.
                if not runTarget then return end

                if fastCFrameMove then
                    -- All scripted target movement uses CFrame while this
                    -- option is enabled; no Humanoid pathing is used here.
                    cframeBeside(runTarget, 3)
                    return
                end

                humanoid:MoveTo(runTarget)
                local groundY = getGroundY(hrp.Position)
                if groundY > -math.huge then
                    local minY = groundY + GROUND_CLEARANCE
                    if hrp.Position.Y < minY then
                        hrp.CFrame = CFrame.new(hrp.Position.X, minY, hrp.Position.Z)
                            * (hrp.CFrame - hrp.CFrame.Position)
                    end
                end
            end

            local function forceNoclip()
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end

            local walkConn = RunService.Heartbeat:Connect(forceRun)
            local noclipConn = RunService.Stepped:Connect(forceNoclip)

            local function getTargetPart(model)
                return model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
            end

            -- Start walking as soon as a requested wild pet appears.  This is
            -- intentionally independent of any game or hub GUI being open;
            -- GUI focus must not delay the trip to the pet.
            local function isRequestedWildPet(pet)
                if not pet or not pet:IsA("Model") then return false end
                -- Big/Huge priority is a separate opt-in target class. Once
                -- enabled, that size is worth securing even if its base
                -- species is not currently selected below.
                local sizePriority = getWildPetSizePriority(pet)
                if sizePriority > 0 then
                    return true
                end
                local petName = string.lower(getWildPetSpeciesName(pet))
                for _, requestedName in ipairs(targetPetNames) do
                    if string.find(petName, string.lower(requestedName), 1, true) then
                        return true
                    end
                end
                return false
            end

            local wildPetSpawns = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
            if wildPetSpawns then
                targetSpawnConn = wildPetSpawns.ChildAdded:Connect(function(pet)
                    if not petProtectEnabled or currentTargetPet or not isRequestedWildPet(pet) then return end
                    task.defer(function()
                        local targetPart = getTargetPart(pet)
                        if targetPart and pet.Parent and petProtectEnabled then
                            runTarget = targetPart.Position
                        end
                    end)
                end)
            end

            local function findWildPets(names)
                local spawns = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
                if not spawns or not names
                    or (#names == 0 and not buyBigPetsPriority and not buyHugePetsPriority) then
                    return {}
                end
                local lowerNames = {}
                for _, n in ipairs(names) do
                    table.insert(lowerNames, string.lower(n))
                end
                local matches = {}
                for _, pet in ipairs(spawns:GetChildren()) do
                    if pet:IsA("Model") and not claimedWildPets[pet] then
                        local sizePriority = getWildPetSizePriority(pet)
                        local lowerPetName = string.lower(getWildPetSpeciesName(pet))
                        if sizePriority > 0 then
                            table.insert(matches, pet)
                        else
                            for _, n in ipairs(lowerNames) do
                                if string.find(lowerPetName, n) then
                                    table.insert(matches, pet)
                                    break
                                end
                            end
                        end
                    end
                end
                table.sort(matches, function(first, second)
                    local firstSizePriority = getWildPetSizePriority(first)
                    local secondSizePriority = getWildPetSizePriority(second)
                    if firstSizePriority ~= secondSizePriority then
                        return firstSizePriority > secondSizePriority
                    end
                    local firstRarity = getPetRarity(first)
                    local secondRarity = getPetRarity(second)
                    local firstRank = RARITY_RANK[firstRarity] or 0
                    local secondRank = RARITY_RANK[secondRarity] or 0
                    if firstRank ~= secondRank then
                        return firstRank > secondRank
                    end
                    local firstPart = getTargetPart(first)
                    local secondPart = getTargetPart(second)
                    local firstDistance = firstPart and (hrp.Position - firstPart.Position).Magnitude or math.huge
                    local secondDistance = secondPart and (hrp.Position - secondPart.Position).Magnitude or math.huge
                    return firstDistance < secondDistance
                end)
                return matches
            end

            local function aimAtNextWildPet()
                local nextPet = findWildPets(targetPetNames)[1]
                local nextPart = getTargetPart(nextPet)
                runTarget = nextPart and nextPart.Position or nil
            end

            local function isInsideSafeZone(pos)
                local zones = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("SafeZones")
                if not zones then return false end
                for _, zone in ipairs(zones:GetDescendants()) do
                    if zone:IsA("BasePart") then
                        local size = zone.Size / 2
                        local rel = zone.CFrame:PointToObjectSpace(pos)
                        if math.abs(rel.X) <= size.X and math.abs(rel.Y) <= size.Y and math.abs(rel.Z) <= size.Z then
                            return true
                        end
                    end
                end
                return false
            end

            local function getPromptPrice(prompt)
                if not prompt or not prompt.ObjectText then return nil end
                local text = prompt.ObjectText:gsub("[¢,\s]", ""):upper()
                local num = tonumber(text:match("[%d%.]+"))
                if not num then return nil end
                if text:find("K") then num = num * 1000
                elseif text:find("M") then num = num * 1000000
                elseif text:find("B") then num = num * 1000000000 end
                return num
            end

            local function getClosestIntruder(petPos, preferredPlayer)
                -- When a pet has just been taken, its recorded owner is the
                -- important defender target. Prefer them whenever they are
                -- inside the same protection radius.
                if preferredPlayer and preferredPlayer ~= LocalPlayer and preferredPlayer.Character then
                    local preferredHRP = preferredPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if preferredHRP and (preferredHRP.Position - petPos).Magnitude < petPunchRadius then
                        return preferredPlayer
                    end
                end

                local closest, closestDist = nil, petPunchRadius
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= LocalPlayer and other.Character then
                        local otherHRP = other.Character:FindFirstChild("HumanoidRootPart")
                        if otherHRP then
                            local dist = (otherHRP.Position - petPos).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closest = other
                            end
                        end
                    end
                end
                return closest
            end

            local function getShovelTool()
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and string.find(string.lower(tool.Name), "shovel") then
                        return tool
                    end
                end
                for _, tool in ipairs(character:GetChildren()) do
                    if tool:IsA("Tool") and string.find(string.lower(tool.Name), "shovel") then
                        return tool
                    end
                end
                return nil
            end

            local function countOwnedPet(petName)
                local amount = 0
                for _, container in ipairs({ backpack, character }) do
                    if container then
                        for _, item in ipairs(container:GetChildren()) do
                            if item:IsA("Tool") and item.Name == petName then
                                amount = amount + 1
                            end
                        end
                    end
                end
                return amount
            end

            local function getWildPetRef(pet)
                local map = workspace:FindFirstChild("Map")
                local refs = map and map:FindFirstChild("WildPetRef")
                if not refs or not pet then
                    return nil
                end
                for _, ref in ipairs(refs:GetChildren()) do
                    if ref.Name ~= "" and string.find(pet.Name, ref.Name, 1, true) then
                        return ref
                    end
                end
                return nil
            end

            local function isWildPetOwnedByMe(ref)
                if not ref then
                    return false
                end
                return tonumber(ref:GetAttribute("OwnerUserId")) == LocalPlayer.UserId
                    or tostring(ref:GetAttribute("OwnerName") or "") == LocalPlayer.Name
            end

            local function waitForPetInBackpack(pet, petName, ownedBefore, petRef)
                pendingPetDeliveryCount = pendingPetDeliveryCount + 1
                pendingPetDelivery = true
                pendingPetDeliveryName = petName
                local arrived = false
                local result = "timeout"

                -- A WildPet disappearing from Workspace is NOT treated as a
                -- successful purchase by itself. Give the game a short delivery
                -- window and confirm that our Backpack/Character pet count really
                -- increased before anything is recorded as secured.
                for _ = 1, 80 do
                    if countOwnedPet(petName) > ownedBefore then
                        arrived = true
                        result = "arrived"
                        break
                    end
                    task.wait(0.1)
                end

                if not arrived then
                    if pet and pet.Parent then
                        result = "still_alive"
                    elseif petRef and not isWildPetOwnedByMe(petRef) then
                        result = "owner_changed"
                    else
                        result = "not_in_backpack"
                    end
                end

                pendingPetDeliveryCount = math.max(0, pendingPetDeliveryCount - 1)
                pendingPetDelivery = pendingPetDeliveryCount > 0
                if not pendingPetDelivery then
                    pendingPetDeliveryName = ""
                end
                return arrived, result
            end

            local function recordSecuredPet(pet, petName, purchasePrice, purchaseRequested, petRef)
                local rarity = getPetRarity(pet)
                local sizeTier = getPetSizeTier(pet, petRef, petName)
                local displayPetName = sizeTier and (sizeTier .. " " .. petName) or petName
                petsBought = petsBought + 1
                if purchasePrice > 0 then
                    totalSpent = totalSpent + purchasePrice
                end
                if dailyDate ~= os.date("%Y-%m-%d") then
                    dailyDate = os.date("%Y-%m-%d")
                    dailyPetsBought = 0
                end
                dailyPetsBought = dailyPetsBought + 1
                petHistory[displayPetName] = (tonumber(petHistory[displayPetName]) or 0) + 1
                addActivity("Secured " .. displayPetName .. " (" .. rarity .. ")")
                print("[AutoBuyPet] Secured", displayPetName, rarity, "Total pets:", petsBought)
                saveSettings()
                updateStatusUI()
                if updateHistoryUI then updateHistoryUI() end
                local baseWebhookPetName = WEBHOOK_PET_PAGE_NAMES[petName] or petName
                local webhookPetName = sizeTier and (sizeTier .. " " .. baseWebhookPetName) or baseWebhookPetName
                if webhookPetAlerts then
                    sendWebhook(
                        "PET SECURED",
                        "**" .. webhookPetName .. "** was secured successfully.",
                        WEBHOOK_RARITY_COLORS[rarity] or 5763719,
                        {
                            { name = "PET", value = webhookPetName, inline = true },
                            { name = "RARITY", value = rarity, inline = true },
                            { name = "TOTAL PETS", value = tostring(petsBought), inline = true },
                        },
                        getWebhookPetImage(petName)
                    )
                end
                if GLOBAL_WEBHOOK_URL ~= "" then
                    sendWebhook(
                        "PET SECURED",
                        "**" .. webhookPetName .. "** was secured successfully.",
                        WEBHOOK_RARITY_COLORS[rarity] or 5763719,
                        {
                            { name = "PLAYER", value = censorGlobalPlayerName(LocalPlayer.Name), inline = true },
                            { name = "PET", value = webhookPetName, inline = true },
                            { name = "RARITY", value = rarity, inline = true },
                        },
                        getWebhookPetImage(petName),
                        GLOBAL_WEBHOOK_URL,
                        true
                    )
                end
                if PRIVATE_WEBHOOK_URL ~= "" then
                    sendWebhook(
                        "PET SECURED",
                        "**" .. webhookPetName .. "** was secured successfully.",
                        WEBHOOK_RARITY_COLORS[rarity] or 5763719,
                        {
                            { name = "PLAYER", value = LocalPlayer.Name, inline = true },
                            { name = "PET", value = webhookPetName, inline = true },
                            { name = "RARITY", value = rarity, inline = true },
                        },
                        getWebhookPetImage(petName),
                        PRIVATE_WEBHOOK_URL,
                        true
                    )
                end
                Notify("Secured!", displayPetName .. " bought! " .. rarity, 2)
            end

            local function securePet(pet)
                local expectedPetName = getWildPetSpeciesName(pet)
                local ownedBefore = countOwnedPet(expectedPetName)
                local petRef = getWildPetRef(pet)
                local wasOwnedByMe = isWildPetOwnedByMe(petRef)
                local lastOwnerName = petRef and tostring(petRef:GetAttribute("OwnerName") or "") or ""
                local reclaimOwnerName = nil
                currentTargetPet = pet
                Notify("Target Locked", "Now Buying And Protecting: " .. expectedPetName, 2)
                noPetTimer = 0
                local refPrice = petRef and tonumber(petRef:GetAttribute("Price")) or 0
                local purchasePrice = refPrice
                local purchaseRequested = false

                while petProtectEnabled do
                    if not pet then
                        break
                    end
                    if not pet.Parent then
                        -- Disappearance only starts verification. Do not count,
                        -- webhook, or report success until the matching pet is
                        -- actually visible in our Backpack/Character.
                        fastApproach = false
                        runTarget = nil
                        Notify("Verifying Purchase", expectedPetName .. " disappeared — checking Backpack...", 2)

                        local arrived, deliveryResult = waitForPetInBackpack(
                            pet,
                            expectedPetName,
                            ownedBefore,
                            petRef
                        )

                        claimedWildPets[pet] = true
                        if arrived then
                            recordSecuredPet(pet, expectedPetName, purchasePrice, purchaseRequested, petRef)
                        else
                            print("[AutoBuyPet] NOT secured:", expectedPetName, "delivery result:", deliveryResult)
                            if deliveryResult == "owner_changed" then
                                Notify("Purchase Failed", expectedPetName .. " disappeared, but ownership changed and it was not found in your Backpack.", 3)
                            else
                                Notify("Purchase Failed", expectedPetName .. " disappeared but was not found in your Backpack.", 3)
                            end
                        end

                        aimAtNextWildPet()
                        break
                    else
                        -- Target is still present; continue through the normal
                        -- purchase and protection loop below.
                    end

                    local targetPart = getTargetPart(pet)
                    if not targetPart then break end

                    if petRef then
                        local ownerName = tostring(petRef:GetAttribute("OwnerName") or "")
                        if purchaseRequested and ownerName ~= lastOwnerName and not isWildPetOwnedByMe(petRef) then
                            Notify("Ownership Changed", expectedPetName .. " changed owner. Returning to buy it again.", 2)
                            reclaimOwnerName = ownerName ~= "" and ownerName or nil
                            runTarget = targetPart.Position
                            purchaseRequested = false
                            wasOwnedByMe = false
                        elseif isWildPetOwnedByMe(petRef) then
                            -- The pet is back under our name, so the reclaim
                            -- combat focus is no longer needed.
                            reclaimOwnerName = nil
                            wasOwnedByMe = true
                        end
                        lastOwnerName = ownerName
                    end

                    if false and purchaseRequested and not wasOwnedByMe and isWildPetOwnedByMe(petRef) then
                        local arrived, result = waitForPetInBackpack(pet, expectedPetName, ownedBefore, petRef)
                        if arrived then
                            claimedWildPets[pet] = true
                            recordSecuredPet(pet, expectedPetName, purchasePrice, purchaseRequested, petRef)
                            aimAtNextWildPet()
                            break
                        elseif result == "still_alive" then
                            -- The pet is still on the map, so keep guarding it
                            -- instead of moving to another WildPet early.
                            runTarget = targetPart.Position
                            task.wait(0.1)
                        else
                            Notify("Purchase Pending", expectedPetName .. " disappeared but did not reach your Backpack.", 3)
                            aimAtNextWildPet()
                            break
                        end
                    end

                    if purchaseRequested and petRef and wasOwnedByMe and not pet.Parent then
                        if waitForPetInBackpack(pet, expectedPetName, ownedBefore, petRef) then
                            claimedWildPets[pet] = true
                            recordSecuredPet(pet, expectedPetName, purchasePrice, purchaseRequested, petRef)
                            aimAtNextWildPet()
                        else
                            Notify("Purchase Pending", expectedPetName .. " is still being delivered to your Backpack.", 3)
                        end
                        break
                    end

                    local petPos = targetPart.Position

                    if hrp.Position.Y < MIN_Y then
                        hrp.CFrame = CFrame.new(petPos + Vector3.new(0, 5, 0))
                        task.wait(0.1)
                        continue
                    end

                    local distanceToPet = (hrp.Position - petPos).Magnitude
                    local prompt = pet:FindFirstChildWhichIsA("ProximityPrompt", true)
                    local ownerName = petRef and tostring(petRef:GetAttribute("OwnerName") or "") or ""
                    fastApproach = ownerName == "" and distanceToPet > FOLLOW_DISTANCE

                    -- Reclaim comes first: get back to the same pet and send a
                    -- purchase request before switching to the former owner's
                    -- combat priority.
                    if reclaimOwnerName and distanceToPet <= FOLLOW_DISTANCE and prompt and prompt.Enabled then
                        if not purchaseRequested then
                            purchasePrice = refPrice > 0 and refPrice or (getPromptPrice(prompt) or 0)
                            purchaseRequested = true
                        end
                        pcall(function()
                            fireproximityprompt(prompt)
                        end)
                        task.wait(0.12)
                    end

                    local reclaimOwner = reclaimOwnerName and Players:FindFirstChild(reclaimOwnerName) or nil
                    local intruder = getClosestIntruder(petPos, reclaimOwner)

                    if intruder and intruder.Character then
                        fastApproach = false
                        local otherHRP = intruder.Character:FindFirstChild("HumanoidRootPart")
                        if otherHRP then
                            -- A nearby player gets combat priority. Keep updating the
                            -- movement target to their live position and keep swinging
                            -- until they leave the configured protection radius.
                            runTarget = otherHRP.Position
                            -- Combat uses CFrame regardless of the normal
                            -- movement setting so the player is reached at once.
                            cframeBeside(otherHRP.Position, 2.5)
                            pcall(function() ShovelNet.HitPlayer:Fire(intruder.UserId) end)
                            pcall(function() ShovelNet.SwingShovel:Fire(intruder.Character) end)

                            local shovelTool = getShovelTool()
                            if shovelTool then
                                local equipped = character:FindFirstChildOfClass("Tool")
                                if equipped ~= shovelTool then
                                    humanoid:EquipTool(shovelTool)
                                end
                                pcall(function() shovelTool:Activate() end)
                            end

                            task.wait(0.06)
                            continue
                        end
                    end

                    if distanceToPet > RETURN_DISTANCE then
                        runTarget = petPos
                        task.wait(0.05)
                        continue
                    end

                    if distanceToPet <= FOLLOW_DISTANCE then
                        fastApproach = false
                    end
                    if distanceToPet > FOLLOW_DISTANCE then
                        runTarget = petPos
                    end

                    if prompt and prompt.Enabled then
                        local price = getPromptPrice(prompt)
                        if not price or price < maxPetPrice then
                            if not purchaseRequested then
                                purchasePrice = refPrice > 0 and refPrice or (price or 0)
                                purchaseRequested = true
                            end
                            fireproximityprompt(prompt)
                            task.wait(0.25)
                        end
                    end

                    task.wait(0.06)
                end
                if currentTargetPet == pet then
                    currentTargetPet = nil
                end
                fastApproach = false
            end

            while petProtectEnabled do
                local matches = findWildPets(targetPetNames)

                if #matches == 0 then
                    if serverHopInProgress and Theme.ServerHopController.GetSource() == "auto" then
                        runTarget = nil
                        fastApproach = false
                        humanoid:MoveTo(hrp.Position)
                        task.wait(0.25)
                        continue
                    end
                    -- No target is alive: stop the previous MoveTo target so
                    -- the player regains normal movement while waiting.
                    runTarget = nil
                    fastApproach = false
                    humanoid:MoveTo(hrp.Position)
                    noPetTimer = noPetTimer + 1
                    if autoRejoin and noPetTimer >= NO_PET_TIMEOUT then
                        if not waitForPendingPetDelivery() then
                            Notify("Server Hop", "Still waiting for " .. (pendingPetDeliveryName ~= "" and pendingPetDeliveryName or "a purchased pet") .. " to reach your Backpack.", 3)
                            noPetTimer = 0
                            task.wait(2)
                            continue
                        end

                        -- A WildPet can spawn while a delivery check is running.
                        -- Scan once more immediately before hopping so we never
                        -- leave a server that still has a selected target alive.
                        if #findWildPets(targetPetNames) > 0 then
                            noPetTimer = 0
                            continue
                        end

                        Notify("Server Hop", "No pets left — reserving a unique server...", 3)
                        Theme.ServerHopController.Begin("auto")
                        noPetTimer = 0
                    end
                    task.wait(1)
                else
                    if serverHopInProgress and Theme.ServerHopController.GetSource() == "auto" then
                        Theme.ServerHopController.Cancel(nil)
                    end
                    noPetTimer = 0
                    securePet(matches[1])
                end
            end

            walkConn:Disconnect()
            noclipConn:Disconnect()
            if targetSpawnConn then
                targetSpawnConn:Disconnect()
            end
            humanoid.WalkSpeed = 16
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end)
    else
        Notify("Pet Protect", "Stopped", 3)
        addActivity("Auto Buy Pet stopped")
    end
end

ToggleButton.Activated:Connect(function()
    Theme.SetPetProtectEnabled(not petProtectEnabled)
end)

ForceHopButton.Activated:Connect(function()
    Theme.ServerHopController.Begin("manual")
end)

ExportSettingsButton.Activated:Connect(function()
    saveSettings()
    local exported = nil
    pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            exported = readfile(CONFIG_FILE)
        end
    end)
    if not exported then
        Notify("Settings Backup", "Could not read the settings file.", 3)
        return
    end

    local copy = setclipboard or toclipboard
    if type(copy) == "function" then
        local copied = pcall(copy, exported)
        if copied then
            Notify("Settings Backup", "Backup copied to clipboard.", 3)
            return
        end
    end

    BackupImportBox.Text = exported
    BackupImportModal.Visible = true
    Notify("Settings Backup", "Clipboard unavailable — copy the text manually.", 3)
end)

ImportSettingsButton.Activated:Connect(function()
    BackupImportBox.Text = ""
    BackupImportModal.Visible = true
end)

CancelImportButton.Activated:Connect(function()
    BackupImportModal.Visible = false
end)

ConfirmImportButton.Activated:Connect(function()
    local rawBackup = tostring(BackupImportBox.Text or "")
    local decodedOk, backupData = pcall(function()
        return HttpService:JSONDecode(rawBackup)
    end)
    if not decodedOk or type(backupData) ~= "table" then
        Notify("Settings Backup", "That backup text is not valid JSON.", 3)
        return
    end
    if not (writefile and isfolder and makefolder) then
        Notify("Settings Backup", "Your executor cannot save imported settings.", 3)
        return
    end

    local wrote = pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        writefile(CONFIG_FILE, rawBackup)
    end)
    if not wrote then
        Notify("Settings Backup", "Could not write the imported backup.", 3)
        return
    end

    local wasAutoBuyEnabled = petProtectEnabled
    loadSettings()
    local importedAutoBuyEnabled = petProtectEnabled

    PriceBox.Text = tostring(maxPetPrice)
    SpeedBox.Text = tostring(petWalkSpeed)
    RadiusBox.Text = tostring(petPunchRadius)
    rebuildTargetList()
    rebuildSellList()
    updateSellUI()
    updateRejoinUI()
    updatePetSizePriorityUI()
    updateJobIdsUI()
    rebuildJobIdList()
    updateCleanupUI()
    updateCFrameMoveUI()
    updateWebhookUI()
    if updateHistoryUI then updateHistoryUI() end
    if cleanupEnabled then setCleanupEnabled(true) end

    if wasAutoBuyEnabled ~= importedAutoBuyEnabled then
        Theme.SetPetProtectEnabled(importedAutoBuyEnabled)
    end
    BackupImportModal.Visible = false
    Notify("Settings Backup", "Backup restored successfully.", 3)
end)

-- =========================================================
-- Minimize / Close
-- =========================================================
_G.ScoopHubAutoBuyPetMinimized = _G.ScoopHubAutoBuyPetMinimized or false
MinButton.Activated:Connect(function()
    _G.ScoopHubAutoBuyPetMinimized = not _G.ScoopHubAutoBuyPetMinimized
    Body.Visible = not _G.ScoopHubAutoBuyPetMinimized
    local size = _G.ScoopHubAutoBuyPetMinimized and UDim2.new(0, 520, 0, 38) or UDim2.new(0, 520, 0, 500)
    SafeTween(Main, TweenInfo.new(0.2), { Size = size })
    SafeTween(DropShadowHolder, TweenInfo.new(0.2), { Size = size })
    SafeTween(DropShadow, TweenInfo.new(0.2), { Size = size })
end)

CloseButton.Activated:Connect(function()
    ScreenGui.Enabled = false
    if petProtectEnabled then
        Theme.SetPetProtectEnabled(false)
    end
    if serverHopInProgress then
        Theme.ServerHopController.Cancel(nil)
    end
    Theme.ServerHopClaims.Shutdown()
    saveSettings()
end)

-- =========================================================
-- INIT — Load saved settings
-- =========================================================
loadSettings()

-- Apply loaded values to UI
PriceBox.Text = tostring(maxPetPrice)
SpeedBox.Text = tostring(petWalkSpeed)
RadiusBox.Text = tostring(petPunchRadius)

rebuildTargetList()
rebuildSellList()
updateSellUI()
updateRejoinUI()
updatePetSizePriorityUI()
updateStatusUI()
updateJobIdsUI()
rebuildJobIdList()
if updateHistoryUI then updateHistoryUI() end
updateCleanupUI()
updateCFrameMoveUI()
updateWebhookUI()
startWildPetLabels()
if cleanupEnabled then
    setCleanupEnabled(true)
end

-- Keep auto-sell independent from Auto Buy Pet. It runs while enabled and
-- re-scans the Backpack, so newly obtained matching pets are handled too.
task.spawn(function()
    while ScreenGui.Parent do
        if autoSellEnabled then
            sellSelectedBackpackPets()
        end
        task.wait(0.4)
    end
end)

-- Currency can change without any action in this hub, so refresh just this
-- status line in the background instead of waiting for another UI update.
task.spawn(function()
    while ScreenGui.Parent do
        updateShecklesUI()
        if ElapsedLabel then
            ElapsedLabel.Text = formatWebhookElapsed()
        end
        if petProtectEnabled and os.time() - lastAutoSaveAt >= 15 then
            lastAutoSaveAt = os.time()
            saveSettings()
        end
        if SessionNameLabel then
            SessionNameLabel.Text = LocalPlayer.Name .. " • " .. formatWebhookElapsed()
        end
        task.wait(0.5)
    end
end)

-- Restore exactly what the user chose before the previous teleport.
-- Do this immediately: rebuildTargetList above saves the temporary OFF
-- setup state, so deferring this restoration can leave it saved as OFF.
if resumePetProtectOnLoad then
    Theme.SetPetProtectEnabled(true)
end

print("[AutoBuyPet] Loaded: " .. tostring(isKRNL) .. " | SERVER HOPPING: " .. tostring(autoRejoin))
addActivity("Script loaded")
Notify("Loaded", "Settings restored: " .. tostring(isKRNL), 3)
--
