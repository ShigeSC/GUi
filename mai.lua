-- =====================================================
--  MAIL SCRIPT ScoopHub Style
--  MAIL + MAIL FRUITS + MAIL HISTORY (Fully Combined)
-- =====================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")

-- Anti-AFK: Roblox marks the player as idle before its inactivity kick.
-- Re-running the mail script replaces the old listener instead of stacking them.
if _G.ScoopHubMailAntiAfkConnection then
    pcall(function()
        _G.ScoopHubMailAntiAfkConnection:Disconnect()
    end)
end

local VirtualInputManager = game:GetService("VirtualInputManager")
local function MailAntiAfkJump()
    local sentInput = pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)

    if not sentInput then
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Jump = true
        end
    end
end

_G.ScoopHubMailAntiAfkConnection = LocalPlayer.Idled:Connect(MailAntiAfkJump)

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local SellValueData = require(ReplicatedStorage.SharedModules.SellValueData)

-- These are the same live modules used by the game's Steven seller.  Keep
-- them optional so the mail UI still works in older places/builds.
local SellFlags
do
    local ok, result = pcall(function()
        return require(ReplicatedStorage.SharedModules.Flags.SellFlags)
    end)
    if ok and type(result) == "table" then
        SellFlags = result
    end
end

local FruitImages
do
    local SeedData = ReplicatedStorage.SharedModules:FindFirstChild("SeedData")
    FruitImages = SeedData and SeedData:FindFirstChild("FruitImages")
end

-- The game exposes its authoritative fruit calculator. It expects the
-- harvested-fruit Instance itself, so keep a guarded fallback for places or
-- older builds where the module is unavailable.
local FruitValueCalc
do
    local ok, result = pcall(function()
        return require(ReplicatedStorage.SharedModules.FruitValueCalc)
    end)
    if ok and typeof(result) == "function" then
        FruitValueCalc = result
    end
end

local MutationData
do
    local ok, result = pcall(function()
        return require(ReplicatedStorage.SharedModules.MutationData)
    end)
    if ok and type(result) == "table" then
        MutationData = result
    end
end

-- =========================================================
-- MAIL TAB ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â categories / plant names
-- =========================================================
local MailableCategories = {
    Seeds = true,
    WateringCans = true,
    SeedPacks = true,
    Sprinklers = true,
    Trowels = true,
    Crates = true,
    Mushrooms = true,
    Tools = true,
    Eggs = true,
    Plants = true,
    Pets = true,
}

local PlantNames = {
    ["Buttercup"] = true, ["Pineapple"] = true, ["Grape"] = true, ["Apple"] = true,
    ["PartFruit"] = true, ["Tulip"] = true, ["Strawberry"] = true, ["Blueberry"] = true,
    ["Tomato"] = true, ["Pumpkin"] = true, ["Bamboo"] = true, ["Mushroom"] = true,
    ["Coconut"] = true, ["Cactus"] = true, ["Mango"] = true, ["Cherry"] = true,
    ["Lotus"] = true, ["Sunflower"] = true, ["Acorn"] = true, ["Beanstalk"] = true,
    ["Poison Apple"] = true, ["Thorn Rose"] = true, ["Pomegranate"] = true, ["Plum"] = true,
    ["Ghost Pepper"] = true, ["Poison Ivy"] = true, ["Romanesco"] = true, ["Baby Cactus"] = true,
    ["Glow Mushroom"] = true, ["Horned Melon"] = true, ["Corn"] = true, ["Pinetree"] = true,
    ["Moon Bloom"] = true, ["Banana"] = true, ["Carrot"] = true, ["Dragon Fruit"] = true,
    ["Moon Bloom OLD"] = true, ["Dragon's Breath"] = true, ["Green Bean"] = true,
    ["Venom Spitter"] = true, ["Hypno Bloom"] = true, ["Briar Rose"] = true, ["Fire Fern"] = true,
    ["Rocket Pop"] = true, ["Sun Bloom"] = true, ["Eclipse Bloom"] = true, ["Star Fruit"] = true,
    ["Venus Fly Trap"] = true, ["Cinnamon Stick"] = true, ["Conifer Cone"] = true,
    ["Atlantic Giant Pumpkin"] = true, ["Conifer Cone Sapling"] = true, ["Maple Carrot"] = true,
    ["Maple Strawberry"] = true, ["Maple Blueberry"] = true, ["Maple Tulip"] = true,
    ["Maple Tomato"] = true, ["Maple Apple"] = true, ["Maple Bamboo"] = true,
    ["Maple Corn"] = true, ["Maple Cactus"] = true, ["Maple Pineapple"] = true,
    ["Maple Mushroom"] = true, ["Maple Green Bean"] = true, ["Amber Cranberry"] = true,
    ["Maple Venom Spitter"] = true, ["Maple Poison Apple"] = true, ["Maple Pomegranate"] = true,
    ["Maple Venus Fly Trap"] = true,
}

-- Keep the plant/fruit exclusion list in sync with the live game assets.
-- New crops can be added under ReplicatedStorage.Assets.Seeds without
-- requiring another hardcoded entry here.
local function RegisterSeedAsset(SeedAsset)
    if not SeedAsset then
        return
    end

    local AssetName = tostring(SeedAsset.Name or "")
    if AssetName == "" then
        return
    end

    local BaseName = AssetName
        :gsub("%s*[Ss]eed%s*$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    if BaseName ~= "" then
        PlantNames[BaseName] = true
    end
end

local function LoadSeedAssets()
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local SeedsFolder = Assets and Assets:FindFirstChild("Seeds")
    if not SeedsFolder then
        return
    end

    for _, SeedAsset in ipairs(SeedsFolder:GetChildren()) do
        RegisterSeedAsset(SeedAsset)
    end

    -- Also recognize crops added after the script starts.
    SeedsFolder.ChildAdded:Connect(RegisterSeedAsset)
end

LoadSeedAssets()

-- Declared here so the inventory scanner can safely reference it. The full
-- list is assigned below, before the UI performs its first inventory refresh.
local PetNames
local ReplicatedAssetItems = {}

local SeedPackNames = {
	["Uncommon Seed Pack"] = true,
	["Rare Seed Pack"] = true,
	["Legendary Seed Pack"] = true,
	["Common Seed Pack"] = true,   -- just in case
}

-- =========================================================
-- MAIL FRUITS TAB ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â value calculation
-- =========================================================
local DEFAULT_EXPONENT = 2.65
local EXPONENT_OVERRIDES = {
    Mushroom = 1.9,
    Bamboo = 1.75
}

local function CalculateFruitValue(fruitName, weight, fruitInstance, mutation)
    -- Keep the selection scanner side-effect-free.  The exact live seller
    -- quote is resolved only when the user sends the fruit, so a calculator
    -- mismatch can never make fruits disappear from the picker.
    local base = SellValueData[fruitName] or 0
    if base == 0 or not weight or weight <= 0 then return 0 end

    local exponent = EXPONENT_OVERRIDES[fruitName] or DEFAULT_EXPONENT
    local sizeFactor

    if weight > 5 then
        local tailExp = math.min(1.5, exponent)
        sizeFactor = (5 ^ exponent) * ((weight / 5) ^ tailExp)
    else
        sizeFactor = weight ^ exponent
    end

    local multiplier = 1
    if MutationData and type(MutationData.ReturnPriceMultiplier) == "function" and mutation then
        local ok, result = pcall(MutationData.ReturnPriceMultiplier, mutation)
        if ok and type(result) == "number" and result > 0 then
            multiplier = result
        end
    end

    local value = math.floor(base * sizeFactor * multiplier)
    if fruitName == "Carrot" and value < 4 then
        value = 4
    end
    return value
end

-- Steven's appraisal uses this server response when available.  It is the
-- exact current offer shown in-game (for example 535), rather than the raw
-- calculated value.  If the response is unavailable, retain the game's own
-- SellFlags-based calculation as a safe fallback.
local function GetCurrentSellerValue(fruitId, fallback)
    local getFruitBid = Networking
        and Networking.NPCS
        and Networking.NPCS.GetFruitBid
    if fruitId and getFruitBid then
        local ok, response = pcall(function()
            return getFruitBid:Fire(fruitId)
        end)
        if ok and type(response) == "table" then
            local current = tonumber(response.CurrentSellValue)
            if current then
                return math.floor(current), true
            end
        end
    end
    return math.floor(tonumber(fallback) or 0), false
end

-- Cache the authoritative seller quote by fruit instance ID.  The scan is
-- deliberately separate from the picker: a failed quote must never remove a
-- fruit from the selectable list.
local FruitValueCache = {}
local FruitValueScanRunning = false
local FruitValueRescanPending = false
local FruitValueLastScanAt = 0
local FruitValueRefreshCallback
local FruitPriceNextRefreshUnix
local FruitPriceServerOffset = 0
local FruitPriceCycleSeconds = 600
local FruitPriceWatcherRunning = false
local FruitPriceCountdownLabel
local FruitPriceTimerObject
local ParseFruitPriceTimer
local FruitPriceUiNextRefreshUnix
local FruitPriceLastScannedUiRefreshUnix
local FruitPriceStockMultipliers = {}

local function FormatFruitPriceMultiplier(value)
    local number = tonumber(value) or 1
    local rounded = math.floor(number * 100 + 0.5) / 100
    local text = string.format("%.2f", rounded)
        :gsub("0+$", "")
        :gsub("%.$", "")
    return "x" .. text
end

local function SampleFruitPriceTimerSilently(screenGui, timerObject)
    if not screenGui or not screenGui:IsA("ScreenGui") or not timerObject then
        return nil
    end

    local mainFrame = screenGui:FindFirstChild("Frame")

    -- FruitStockPriceController updates its timer only while the ScreenGui is
    -- enabled. Keep the Frame hidden so this one-frame sample never flashes.
    screenGui.Enabled = true
    if mainFrame then
        mainFrame.Visible = false
    end

    pcall(function()
        game:GetService("RunService").RenderStepped:Wait()
    end)
    task.wait()

    local ok, text = pcall(function()
        return tostring(timerObject.Text or "")
    end)

    -- This sampler is only for the background countdown monitor. Always
    -- close the game's stock window after reading its timer so it cannot
    -- remain stuck open when the Mail UI is running.
    if mainFrame then
        mainFrame.Visible = false
    end
    screenGui.Enabled = false

    return ok and text or nil
end

local function UpdateFruitPriceCountdownLabel()
    if not FruitPriceCountdownLabel then return end

    -- Use the last numeric sample from the game's own RefreshIn.Timer. Keep
    -- this function Instance-free because snapshot callbacks run in a packet
    -- thread that cannot access Roblox Instances safely.
    if FruitPriceUiNextRefreshUnix then
        local liveSeconds = math.max(0, math.floor(FruitPriceUiNextRefreshUnix - os.time()))
        FruitPriceCountdownLabel.Text = string.format(
            "Refresh in %dm %02ds",
            liveSeconds // 60,
            liveSeconds % 60
        )
        return
    end

    if FruitPriceNextRefreshUnix then
        local remaining = math.max(0, math.floor(
            FruitPriceNextRefreshUnix - (os.time() + FruitPriceServerOffset)
        ))
        FruitPriceCountdownLabel.Text = string.format(
            "Refresh in %dm %02ds",
            remaining // 60,
            remaining % 60
        )
    elseif not FruitPriceTimerObject then
        FruitPriceCountdownLabel.Text = "Refresh in --m --s"
    end
end

ParseFruitPriceTimer = function(text)
    text = tostring(text or ""):lower()
    local prefixes = {
        "restock%s+in%s+",
        "refresh%s+in%s+",
        "refreshes%s+in%s+",
    }

    for _, prefix in ipairs(prefixes) do
        local minutes, seconds = text:match(prefix .. "(%d+)%s*m%s*(%d+)%s*s")
        if minutes and seconds then
            return tonumber(minutes) * 60 + tonumber(seconds)
        end

        seconds = text:match(prefix .. "(%d+)%s*s")
        if seconds then
            return tonumber(seconds)
        end
    end

    return nil
end

local function SetFruitPriceCountdownFromText(text)
    local seconds = ParseFruitPriceTimer(text)
    if not seconds or not FruitPriceCountdownLabel then return end

    -- Mirror the game's own RefreshIn.Timer value so the display follows the
    -- exact same countdown the player sees, including its elapsed seconds.
    FruitPriceCountdownLabel.Text = string.format(
        "Refresh in %dm %02ds",
        seconds // 60,
        seconds % 60
    )
    FruitPriceUiNextRefreshUnix = os.time() + seconds
end

local function IsFruitPriceTimerObject(object)
    if object.Name == "FruitPriceCountdownLabel" then
        return false
    end

    if not object:IsA("TextLabel") and not object:IsA("TextButton") and not object:IsA("TextBox") then
        return false
    end

    local text = tostring(object.Text or "")
    local lowerText = text:lower()
    if not lowerText:find("restock", 1, true)
        and not lowerText:find("refresh", 1, true) then
        return false
    end

    local context = object:GetFullName():lower()
    return context:find("fruit", 1, true) ~= nil
        and (context:find("price", 1, true) ~= nil or context:find("stock", 1, true) ~= nil)
end

local function FindFruitPriceTimer()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    for _, object in ipairs(playerGui:GetDescendants()) do
        if IsFruitPriceTimerObject(object) then
            return object
        end
    end
end

local function ScanBackpackFruitValues(force)
    if FruitValueScanRunning then
        FruitValueRescanPending = true
        return
    end
    if not force and (os.clock() - FruitValueLastScanAt) < 0.5 then return end
    FruitValueScanRunning = true
    FruitValueLastScanAt = os.clock()

    print("[Mail Fruits] Scanning harvested-fruit seller values...")

    task.spawn(function()
        local seen = {}
        local containers = { Backpack }
        if LocalPlayer.Character then
            table.insert(containers, LocalPlayer.Character)
        end

        for _, container in ipairs(containers) do
            for _, item in ipairs(container:GetChildren()) do
                if item:GetAttribute("HarvestedFruit") == true then
                    local fruitId = item:GetAttribute("Id")
                    if fruitId then
                        local key = tostring(fruitId)
                        if not seen[key] then
                            seen[key] = true
                            local fallback = CalculateFruitValue(
                                item:GetAttribute("FruitName") or "Unknown",
                                item:GetAttribute("Weight") or 0,
                                item,
                                item:GetAttribute("Mutation")
                                    or item:GetAttribute("MutationName")
                                    or item:GetAttribute("Mutations")
                                    or item:GetAttribute("Variant")
                                    or item:GetAttribute("FruitMutation")
                            )
                            local value, live = GetCurrentSellerValue(fruitId, fallback)
                            if live then
                                FruitValueCache[key] = {
                                    Value = value,
                                    UpdatedAt = os.clock(),
                                }
                            end
                        end
                    end
                end

                -- No fixed delay: yield one scheduler frame between requests.
                task.wait()
            end
        end

        FruitValueScanRunning = false
        print("[Mail Fruits] Seller-value scan complete; cached values:", tostring(#seen))
        if FruitValueRefreshCallback then
            pcall(FruitValueRefreshCallback)
        end

        if FruitValueRescanPending then
            FruitValueRescanPending = false
            task.defer(function()
                ScanBackpackFruitValues(true)
            end)
        end
    end)
end

local function ScanAfterFruitPriceReset(refreshUnix)
    refreshUnix = tonumber(refreshUnix)
    if not refreshUnix or FruitPriceLastScannedUiRefreshUnix == refreshUnix then
        return
    end

    FruitPriceLastScannedUiRefreshUnix = refreshUnix
    print("[Mail Fruits] Fruit Price Stock reset confirmed; rescanning values.")
    task.defer(function()
        ScanBackpackFruitValues(true)
    end)
end

local function WatchFruitPriceRefresh()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local fruitStockGui = playerGui:FindFirstChild("FruitStockPrice")
    local timerObject = fruitStockGui
        and fruitStockGui:FindFirstChild("Frame")
        and fruitStockGui.Frame:FindFirstChild("Header")
        and fruitStockGui.Frame.Header:FindFirstChild("RefreshIn")
        and fruitStockGui.Frame.Header.RefreshIn:FindFirstChild("Timer")
    timerObject = timerObject or FindFruitPriceTimer()
    if timerObject and not fruitStockGui then
        fruitStockGui = timerObject:FindFirstAncestorWhichIsA("ScreenGui")
    end

    if fruitStockGui and timerObject then
        local sampledText = SampleFruitPriceTimerSilently(fruitStockGui, timerObject)
        if sampledText then
            SetFruitPriceCountdownFromText(sampledText)
            print("[Mail Fruits] Fruit Price Stock timer sampled silently:", sampledText)
        end
    end

    FruitPriceTimerObject = timerObject

    local function sampleUiTimer()
        if not fruitStockGui or not timerObject then return false end

        local sampledText = SampleFruitPriceTimerSilently(fruitStockGui, timerObject)
        if not sampledText then return false end

        SetFruitPriceCountdownFromText(sampledText)
        print("[Mail Fruits] Fruit Price Stock timer sampled silently:", sampledText)
        return true
    end

    -- The controller also publishes an authoritative snapshot whenever the
    -- Fruit Price Stock refreshes. Hooking it avoids relying only on UI text.
    local fruitStock = Networking and Networking.FruitStock
    local snapshotInitialized = false
    local lastSnapshotRefreshUnix
    local lastSnapshotLastRefreshUnix

    local function handleSnapshot(snapshot)
        if type(snapshot) ~= "table" then
            print("[Mail Fruits] Fruit Price Stock snapshot received without timer data.")
            return
        end

        local nextRefreshUnix = tonumber(snapshot.nextRefreshUnix)
        local snapshotLastRefreshUnix = tonumber(snapshot.lastRefreshUnix)
        local serverNowUnix = tonumber(snapshot.server_now_unix) or os.time()
        local remaining = nextRefreshUnix and math.max(0, math.floor(nextRefreshUnix - serverNowUnix))
        local multipliersChanged = false

        if type(snapshot.entries) == "table" then
            for fruitName, entry in pairs(snapshot.entries) do
                if type(entry) == "table" and tonumber(entry.multiplier) then
                    local key = tostring(fruitName)
                    local multiplier = tonumber(entry.multiplier)
                    if FruitPriceStockMultipliers[key] ~= multiplier then
                        multipliersChanged = true
                    end
                    FruitPriceStockMultipliers[key] = multiplier
                end
            end
        end

        if nextRefreshUnix then
            local currentRemaining = FruitPriceNextRefreshUnix
                and math.max(0, math.floor(
                    FruitPriceNextRefreshUnix - (os.time() + FruitPriceServerOffset)
                ))
            local firstSnapshot = FruitPriceNextRefreshUnix == nil
            local confirmedRefresh = snapshotLastRefreshUnix
                and lastSnapshotLastRefreshUnix
                and snapshotLastRefreshUnix ~= lastSnapshotLastRefreshUnix
            local timerExpired = currentRemaining ~= nil and currentRemaining <= 2

            -- Do not replace an active countdown with a fresh 10-minute value
            -- unless the server confirms that the stock actually refreshed.
            if firstSnapshot or confirmedRefresh or timerExpired then
                FruitPriceNextRefreshUnix = nextRefreshUnix
                FruitPriceServerOffset = serverNowUnix - os.time()
                FruitPriceCycleSeconds = tonumber(snapshot.cycleSeconds) or 600
            end
        end

        if multipliersChanged and FruitValueRefreshCallback then
            task.defer(function()
                pcall(FruitValueRefreshCallback)
            end)
        end

        if remaining and not FruitPriceUiNextRefreshUnix then
            print(string.format(
                "[Mail Fruits] Fruit Price Stock server timer: %dm %02ds remaining (cycle %ds)",
                remaining // 60,
                remaining % 60,
                FruitPriceCycleSeconds
            ))
        end

        if snapshotInitialized
            and nextRefreshUnix
            and lastSnapshotRefreshUnix
            and nextRefreshUnix ~= lastSnapshotRefreshUnix
            and not FruitPriceUiNextRefreshUnix then
            print("[Mail Fruits] Fruit Price Stock server refresh confirmed; rescanning values.")
            ScanAfterFruitPriceReset(nextRefreshUnix)
        end

        if nextRefreshUnix then
            lastSnapshotRefreshUnix = nextRefreshUnix
        end
        if snapshotLastRefreshUnix then
            lastSnapshotLastRefreshUnix = snapshotLastRefreshUnix
        end
        snapshotInitialized = true
    end

    if fruitStock and fruitStock.Snapshot and fruitStock.Snapshot.OnClientEvent then
        pcall(function()
            fruitStock.Snapshot.OnClientEvent:Connect(function(snapshot)
                handleSnapshot(snapshot)
            end)
        end)

        -- Request the current authoritative timer once. This prevents a stale
        -- hidden UI label from being mistaken for the live countdown.
        pcall(function()
            local ok, snapshot = pcall(function()
                return fruitStock.Request:Fire()
            end)
            if ok then
                handleSnapshot(snapshot)
            end
        end)

        -- Use the server's nextRefreshUnix as the real schedule. The UI label
        -- can be hidden or one snapshot behind, while this timestamp follows
        -- the controller's fixed 600-second cycle.
        if not FruitPriceWatcherRunning then
            FruitPriceWatcherRunning = true
            task.spawn(function()
                while true do
                    if FruitPriceNextRefreshUnix then
                        UpdateFruitPriceCountdownLabel()

                        -- The game UI only advances while enabled. Re-sample
                        -- it silently when the sampled countdown reaches zero,
                        -- then restore its original closed state.
                        local uiRemaining = FruitPriceUiNextRefreshUnix
                            and math.max(0, math.floor(FruitPriceUiNextRefreshUnix - os.time()))
                        if uiRemaining and uiRemaining <= 0 then
                            local previousUiRefresh = FruitPriceUiNextRefreshUnix
                            sampleUiTimer()
                            if FruitPriceUiNextRefreshUnix
                                and FruitPriceUiNextRefreshUnix > os.time() + 5
                                and previousUiRefresh ~= FruitPriceUiNextRefreshUnix then
                                ScanAfterFruitPriceReset(FruitPriceUiNextRefreshUnix)
                            end
                        end

                        local serverNow = os.time() + FruitPriceServerOffset
                        local remaining = FruitPriceNextRefreshUnix - serverNow

                        if remaining <= 0 then
                            local previousRefresh = FruitPriceNextRefreshUnix
                            local ok, snapshot = pcall(function()
                                return fruitStock.Request:Fire()
                            end)

                            if ok and type(snapshot) == "table" then
                                handleSnapshot(snapshot)
                            end

                            -- If the server still returns the old snapshot,
                            -- wait one timer tick and request again. No fruit
                            -- scan occurs until the refresh timestamp changes.
                            if FruitPriceNextRefreshUnix == previousRefresh then
                                task.wait(1)
                            end
                        else
                            task.wait(1)
                        end
                    else
                        task.wait(1)
                    end
                end
            end)
        end
    end

    -- Fallback for builds that expose the Fruit Price Stock UI but do not
    -- expose Networking.FruitStock.Snapshot. The hidden UI is sampled once
    -- per second and a scan is started only after its countdown resets.
    if not FruitPriceWatcherRunning and fruitStockGui and timerObject then
        FruitPriceWatcherRunning = true
        task.spawn(function()
            while timerObject and timerObject.Parent do
                local uiRemaining = FruitPriceUiNextRefreshUnix
                    and math.max(0, math.floor(FruitPriceUiNextRefreshUnix - os.time()))

                if uiRemaining and uiRemaining <= 0 then
                    local previousUiRefresh = FruitPriceUiNextRefreshUnix
                    sampleUiTimer()
                    if FruitPriceUiNextRefreshUnix
                        and FruitPriceUiNextRefreshUnix > os.time() + 5
                        and FruitPriceUiNextRefreshUnix ~= previousUiRefresh then
                        ScanAfterFruitPriceReset(FruitPriceUiNextRefreshUnix)
                    end
                else
                    UpdateFruitPriceCountdownLabel()
                end

                task.wait(1)
            end
            FruitPriceWatcherRunning = false
        end)
    end

    local function attach(object)
        local lastSeconds
        local sawZero = false

        local function check()
            local seconds = ParseFruitPriceTimer(object.Text)
            if seconds == nil then return end

            if lastSeconds == nil then
                print(string.format(
                    "[Mail Fruits] Fruit Price Stock UI timer fallback: %dm %02ds remaining (%s)",
                    seconds // 60,
                    seconds % 60,
                    object:GetFullName()
                ))
            end

            SetFruitPriceCountdownFromText(object.Text)

            if seconds <= 2 then
                sawZero = true
            end

            -- A reset is confirmed only when the countdown was near zero and
            -- then jumps back up. This prevents scans on ordinary timer ticks.
            if sawZero and lastSeconds and lastSeconds <= 2 and seconds >= 10 then
                sawZero = false
                print(string.format(
                    "[Mail Fruits] Fruit Price Stock UI timer reset at %dm %02ds.",
                    seconds // 60,
                    seconds % 60
                ))
                if not FruitPriceNextRefreshUnix then
                    -- Only use the UI reset if the server snapshot API is
                    -- unavailable in this game build.
                    ScanBackpackFruitValues()
                end
            end

            lastSeconds = seconds
        end

        object:GetPropertyChangedSignal("Text"):Connect(check)
        check()
    end

    if timerObject then
        attach(timerObject)
        return
    end

    print("[Mail Fruits] Fruit Price Stock timer not found yet; waiting for its UI.")

    -- The panel may be created after this script. Watch for it without a
    -- polling delay, then disconnect once the correct timer is found.
    local connection
    connection = playerGui.DescendantAdded:Connect(function()
        local found = FindFruitPriceTimer()
        if found then
            connection:Disconnect()
            local foundGui = found:FindFirstAncestorWhichIsA("ScreenGui")
            timerObject = found
            if foundGui then
                fruitStockGui = foundGui
            end
            local sampledText = SampleFruitPriceTimerSilently(foundGui, found)
            if sampledText then
                SetFruitPriceCountdownFromText(sampledText)
                print("[Mail Fruits] Fruit Price Stock timer sampled silently:", sampledText)
            end
            FruitPriceTimerObject = found
            attach(found)
        end
    end)
end

local function GetHarvestedFruits()
    local list = {}

    local function scan(container)
        for _, item in ipairs(container:GetChildren()) do
            if item:GetAttribute("HarvestedFruit") == true then
                local id = item:GetAttribute("Id")
                local fruitName = item:GetAttribute("FruitName") or "Unknown"
                local mutation = item:GetAttribute("Mutation")
                    or item:GetAttribute("MutationName")
                    or item:GetAttribute("Mutations")
                    or item:GetAttribute("Variant")
                    or item:GetAttribute("FruitMutation")
                local displayMutation = tostring(mutation or "Normal")
                local weight = item:GetAttribute("Weight") or 0
                local cached = id and FruitValueCache[tostring(id)]
                local value = cached and cached.Value
                    or CalculateFruitValue(fruitName, weight, item, mutation)

                if id then
                    table.insert(list, {
                        Name = item.Name,
                        FruitName = fruitName,
                        Weight = weight,
                        Id = id,
                        Value = value,
                        Multiplier = FruitPriceStockMultipliers[fruitName] or 1,
                        Mutation = displayMutation,
                        Selected = false
                    })
                end
            end
        end
    end

    scan(Backpack)
    if LocalPlayer.Character then
        scan(LocalPlayer.Character)
    end

    table.sort(list, function(a, b)
        return a.Value > b.Value
    end)

    return list
end

-- =========================================================
-- THEME
-- =========================================================
local Theme = {
    -- Graphite surfaces with a restrained ruby accent.  The contrast is high
    -- enough for gameplay, without the harsh pure-black/red look.
    Bg        = Color3.fromRGB(9, 5, 8),
    Panel     = Color3.fromRGB(22, 10, 14),
    PanelLine = Color3.fromRGB(154, 44, 53),
    Red       = Color3.fromRGB(231, 47, 59),
    RedDark   = Color3.fromRGB(145, 28, 39),
    Text      = Color3.fromRGB(255, 111, 120),
    TextDim   = Color3.fromRGB(190, 73, 84),
    Success   = Color3.fromRGB(99, 215, 163),
    White     = Color3.fromRGB(246, 244, 252),
    TabBg     = Color3.fromRGB(35, 16, 22),
    InputBg   = Color3.fromRGB(49, 41, 49),
    InputText = Color3.fromRGB(238, 240, 249),
    Avatar    = Color3.fromRGB(124, 106, 115),

    -- A midnight sky rather than a flat black backdrop.
    ObsidianTop = Color3.fromRGB(39, 11, 17),
    ObsidianMid = Color3.fromRGB(8, 5, 8),
    ObsidianLow = Color3.fromRGB(34, 8, 11),
    Surface = Color3.fromRGB(22, 10, 14),
    Surface2 = Color3.fromRGB(37, 17, 23),
    Surface3 = Color3.fromRGB(52, 31, 37),
    Stroke = Color3.fromRGB(179, 52, 63),
    Muted = Color3.fromRGB(199, 170, 176),
    Glow = Color3.fromRGB(211, 64, 75),

    Font      = Enum.Font.GothamBold,
    FontBody  = Enum.Font.Gotham,
}

local Config = {
    Discord = "discord.gg/WxgqUa9Qz",
    -- Keep this URL empty to disable webhook messages. Webhook URLs are
    -- secrets, so do not share the script publicly after filling this in.
    WebhookURL = "https://discord.com/api/webhooks/1534926281714434202/4ohhoIfY_6b1ZJ5FO4xw10lkT8drDM6lple-vvzn2eY_uamIHyV2pl-sQoereJOhpYDK",
    -- Optional public/global mail-log webhook. Names are masked and UserIds
    -- are never included in this webhook. Leave blank to keep it disabled.
    GlobalWebhookURL = "https://discord.com/api/webhooks/1535731979314667634/EuETZYQPfQwwFalpIur6PAOBd-owXI4Cu_R2jzKGbmVDVgazfVblM5keCYFQhiSaZhGY",
    -- Discord cannot read a local file path. Use a public HTTPS image URL
    -- for the Scoop logo (for example, a raw GitHub image URL).
    WebhookImageURL = "https://raw.githubusercontent.com/ShigeSC/OMSG/refs/heads/main/static%20(2).png",
    -- Fruit thumbnails used by the mail webhook. Keep the repository files
    -- named exactly like the fruit (for example, Maple%20Strawberry.jpg).
    WebhookFruitIconBaseURL = "https://raw.githubusercontent.com/ShigeSC/PIC/main/",
    WebhookFruitIconExtension = "jpg",
    DiscordIcon = "rbxassetid://94434236999817",
    RefreshIcon = "rbxassetid://122032243989747",
    Logo = "rbxassetid://90541504618217",
    LogoColor = Color3.fromRGB(255, 255, 255),
    Title = "MAIL BYPASS V1.6",
    SubTitle = "by ScoopHub",
    HubNameColor = Color3.fromRGB(242, 92, 101),
    SubTitleColor = Color3.fromRGB(166, 174, 187),
}

local function UrlEncodePathSegment(value)
    value = tostring(value or "")
    return (value:gsub("([^%w%-%._~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function FormatSheckles(value)
    local number = math.floor(tonumber(value) or 0)
    local text = tostring(number)
    local changed = true
    while changed do
        local substitutions
        text, substitutions = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
        changed = substitutions > 0
    end
    return text
end

local function FormatCompactSheckles(value, includeCurrency)
    if includeCurrency == nil then includeCurrency = true end

    local number = tonumber(value) or 0
    local absolute = math.abs(number)
    local suffix
    local divisor

    if absolute >= 1e12 then
        suffix, divisor = "T", 1e12
    elseif absolute >= 1e9 then
        suffix, divisor = "B", 1e9
    elseif absolute >= 1e6 then
        suffix, divisor = "M", 1e6
    elseif absolute >= 1e3 then
        suffix, divisor = "K", 1e3
    else
        return FormatSheckles(number) .. (includeCurrency and "\u{00A2}" or "")
    end

    local compact = string.format("%.2f", number / divisor)
        :gsub("0+$", "")
        :gsub("%.$", "")
    return compact .. suffix .. (includeCurrency and "\u{00A2}" or "")
end

local function IsHarvestedFruitMailItem(item)
    local category = tostring(item and item.Category or "")
    return category == "HarvestedFruits"
        or category == "HarvestedFruit"
        or item and item.FruitName ~= nil
end

local function GetWebhookFruitIconURL(item)
    if not IsHarvestedFruitMailItem(item) then
        return nil
    end

    local fruitName = item.FruitName or item.DisplayName or item.Name
    if not fruitName or tostring(fruitName) == "" then
        return nil
    end

    local base = tostring(Config.WebhookFruitIconBaseURL or "")
    local extension = tostring(Config.WebhookFruitIconExtension or "jpg")
    if base == "" then
        return nil
    end
    if base:sub(-1) ~= "/" then
        base = base .. "/"
    end

    return base .. UrlEncodePathSegment(fruitName) .. "." .. extension
end

local function MaskGlobalMailName(name)
    local text = tostring(name or "Unknown")
    local visible = text:sub(1, math.min(4, #text))
    return visible .. "*******"
end

local function SendSingleMailWebhook(recipient, mailedItems, source, isGlobalLog)
    local webhookUrl = tostring(isGlobalLog and Config.GlobalWebhookURL or Config.WebhookURL or "")
    if webhookUrl == "" then
        return
    end

    task.spawn(function()
        local requestFunction
        pcall(function()
            if syn and type(syn.request) == "function" then
                requestFunction = syn.request
            end
        end)
        requestFunction = requestFunction or http_request or request

        if type(requestFunction) ~= "function" then
            warn("[MailScript] Webhook skipped: no HTTP request function is available.")
            return
        end

        local itemLines = {}
        local fruitRows = {}
        local totalCount = 0
        local totalValue = 0
        local hasFruitItems = false
        for _, item in ipairs(mailedItems or {}) do
            local count = tonumber(item.Count) or 1
            local name = item.DisplayName or item.Name or item.ItemKey or "Unknown item"
            local value = tonumber(item.Value) or 0
            local isFruit = IsHarvestedFruitMailItem(item)
            local mutation = tostring(item.Mutation or "Normal")
            local weight = tonumber(item.Weight) or 0
            local valueText = value > 0
                and (" | " .. FormatCompactSheckles(value, false) .. " Sheckles")
                or ""
            table.insert(itemLines, string.format("x%d %s%s", count, tostring(name), valueText))
            totalCount += count
            totalValue += value * count

            if isFruit then
                hasFruitItems = true
                local iconURL = GetWebhookFruitIconURL(item)
                local kgText = weight > 0 and string.format("%.2f kg", weight) or "-"
                table.insert(fruitRows, {
                    Fruit = (iconURL and "\u{25C6} " or "  ") .. "x" .. tostring(count) .. " " .. tostring(name),
                    Mutation = mutation,
                    KG = kgText,
                    Value = FormatCompactSheckles(value * count, false) .. " Sheckles",
                })
            end
        end

        local imageUrl = tostring(Config.WebhookImageURL or "")
        local itemText = (#itemLines > 0) and table.concat(itemLines, "\n") or "No items"
        if #itemText > 950 then
            itemText = itemText:sub(1, 947) .. "..."
        end

        -- Discord has no native table element. A monospace code table keeps
        -- all four columns aligned, and chunks are split at row boundaries
        -- so the embed field limit never cuts off a fruit.
        local function PadTableCell(value, width)
            value = tostring(value or "")
            if #value > width then
                value = value:sub(1, math.max(1, width - 3)) .. "..."
            end
            return value .. string.rep(" ", math.max(0, width - #value))
        end

        local fruitChunks = {}
        local fruitHeader = string.format(
            "%s | %s | %s | %s",
            PadTableCell("FRUIT", 30),
            PadTableCell("MUTATION", 14),
            PadTableCell("KG", 9),
            PadTableCell("VALUE", 18)
        )
        local fruitDivider = string.rep("-", #fruitHeader)
        local chunkLines = { "```", fruitHeader, fruitDivider }
        local chunkLength = #table.concat(chunkLines, "\n")

        if #fruitRows == 0 then
            table.insert(chunkLines, PadTableCell("No fruits", 30))
        else
            for _, row in ipairs(fruitRows) do
                local rowText = string.format(
                    "%s | %s | %s | %s",
                    PadTableCell(row.Fruit, 30),
                    PadTableCell(row.Mutation, 14),
                    PadTableCell(row.KG, 9),
                    PadTableCell(row.Value, 18)
                )
                if chunkLength + #rowText + 5 > 950 and #chunkLines > 3 then
                    table.insert(chunkLines, "```")
                    table.insert(fruitChunks, table.concat(chunkLines, "\n"))
                    chunkLines = { "```", fruitHeader, fruitDivider }
                    chunkLength = #table.concat(chunkLines, "\n")
                end
                table.insert(chunkLines, rowText)
                chunkLength += #rowText + 1
            end
        end
        table.insert(chunkLines, "```")
        table.insert(fruitChunks, table.concat(chunkLines, "\n"))

        local mailedFieldName = hasFruitItems and "FRUIT MAILED" or "ITEMS MAILED"
        local mailedFieldValue = hasFruitItems and fruitChunks[1] or itemText
        local totalFieldName = hasFruitItems and "TOTAL FRUITS MAILED" or "TOTAL"

        local embed = {
            title = hasFruitItems and "FRUIT MAIL DELIVERED" or "MAIL DELIVERED",
            description = hasFruitItems
                and "A fruit mail transfer was completed successfully."
                or "A mail transfer was completed successfully.",
            color = 15804477,
            author = {
                name = "ScoopHub | Mail Monitor",
            },
            fields = {
                {
                    name = "SENDER",
                    value = isGlobalLog
                        and MaskGlobalMailName(LocalPlayer.Name)
                        or string.format("%s\nUserId: %d", LocalPlayer.Name, LocalPlayer.UserId),
                    inline = true,
                },
                {
                    name = "RECIPIENT",
                    value = isGlobalLog and MaskGlobalMailName(recipient) or tostring(recipient),
                    inline = true,
                },
                {
                    name = mailedFieldName,
                    value = mailedFieldValue,
                    inline = false,
                },
                {
                    name = totalFieldName,
                    value = tostring(totalCount) .. (hasFruitItems and " fruit(s)" or " item(s)"),
                    inline = true,
                },
                {
                    name = "TOTAL VALUE",
                    value = FormatCompactSheckles(totalValue, false) .. " Sheckles",
                    inline = true,
                },
                {
                    name = "SOURCE",
                    value = tostring(source or "Mail"),
                    inline = true,
                },
            },
            footer = {
                text = "ScoopHub Mail | discord.gg/WxgqUa9Qz",
            },
            timestamp = DateTime.now():ToIsoDate(),
        }

        local function sendEmbeds(embeds)
            local payload = {
                username = "ScoopHub Mail",
                embeds = embeds,
            }
            if imageUrl ~= "" then
                payload.avatar_url = imageUrl
            end

            local encodedOk, body = pcall(function()
                return HttpService:JSONEncode(payload)
            end)
            if not encodedOk then
                warn("[MailScript] Webhook payload could not be encoded.")
                return false
            end

            local ok, response = pcall(function()
                return requestFunction({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = body,
                })
            end)
            if not ok then
                warn("[MailScript] Webhook request failed:", response)
            end
            return ok
        end

        if imageUrl ~= "" then
            embed.author.icon_url = imageUrl
            embed.thumbnail = { url = imageUrl }
        end

        local embedsToSend = { embed }
        if hasFruitItems then
            for index = 2, #fruitChunks do
                table.insert(embedsToSend, {
                    title = "FRUIT MAILED (continued)",
                    color = 15804477,
                    fields = {
                        {
                            name = "FRUIT MAILED",
                            value = fruitChunks[index],
                            inline = false,
                        },
                    },
                    footer = { text = "ScoopHub Mail | discord.gg/WxgqUa9Qz" },
                    timestamp = DateTime.now():ToIsoDate(),
                })
            end
        end

        -- Discord permits ten embeds per request. Continuation embeds keep
        -- every mailed fruit visible without truncating a row or its icon.
        local startIndex = 1
        while startIndex <= #embedsToSend do
            local batch = {}
            local endIndex = math.min(startIndex + 9, #embedsToSend)
            for index = startIndex, endIndex do
                table.insert(batch, embedsToSend[index])
            end
            sendEmbeds(batch)
            startIndex = endIndex + 1
            if startIndex <= #embedsToSend then
                task.wait(0.25)
            end
        end
    end)
end

-- Sends the private detailed log and, when configured, a privacy-safe global
-- log. The public log keeps the same design but masks both player names.
local function SendMailWebhook(recipient, mailedItems, source)
    SendSingleMailWebhook(recipient, mailedItems, source, false)
    SendSingleMailWebhook(recipient, mailedItems, source, true)
end

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

-- Adds the same red rectangular focus ring to any editable field.
local function AddFocusBorder(box)
    if not box then return nil end

    local stroke = New("UIStroke", {
        Color = Theme.Red,
        Thickness = 1.15,
        Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, box)

    box.Focused:Connect(function()
        SafeTween(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 0,
        })
    end)

    box.FocusLost:Connect(function()
        SafeTween(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
        })
    end)

    return stroke
end

-- ==================== GET LIVE INVENTORY (Mail tab) ====================
local function GetLiveInventory()
	local items = {}
    local groupedItems = {}

        local function scan(container)
        for _, tool in ipairs(container:GetChildren()) do
            -- Pets can be stored as a non-Tool inventory instance. Let known
            -- pet names through, while retaining the normal Tool filter for
            -- every other item type.
            if tool:IsA("Tool") or PetNames[tool.Name] then
                local count = tool:GetAttribute("Count") or 1
                local rawCategory = tool:GetAttribute("MainCategory") or ""
                local categoryLower = string.lower(tostring(rawCategory):gsub("^%s+", ""):gsub("%s+$", ""))
                local name = tool.Name
                local nameLower = string.lower(name)
                local isSeedItem = categoryLower == "seed"
                    or categoryLower == "seeds"
                    or (nameLower:find("seed") and not nameLower:find("pack"))
                local replicatedCategory = ReplicatedAssetItems[name]
                local isPet = PetNames[name]
                    or tool:GetAttribute("Pet") ~= nil
                    or tool:GetAttribute("PetId") ~= nil

                -- Pets are unique tools. Their Count attribute is 0 rather
                -- than an inventory stack size, so show each one as x1.
                if isPet then
                    count = 1
                elseif count <= 0 then
                    continue
                end

                -- Harvested fruit is owned exclusively by the Mail Fruits tab.
                -- Without this guard, a weighted Strawberry can fall through to
                -- the PlantNames fallback and appear in the normal item picker.
                if tool:GetAttribute("HarvestedFruit") == true
                    or categoryLower == "harvestedfruit"
                    or categoryLower == "harvestedfruits" then
                    continue
                end

                -- Some fruit tools are reported as a generic inventory/seed
                -- category, so category filtering alone is not reliable. Match
                -- the base name as well (this covers names such as
                -- "Strawberry [1.69kg]" and stacked "Strawberry").
                local fruitBaseName = name
                    :gsub("%s*%[%d+%.?%d*kg%]$", "")
                    :gsub("^%s+", "")
                    :gsub("%s+$", "")
                -- A real seed item must remain available in the normal Mail
                -- picker even when its display name matches a plant asset.
                -- Non-seed plant/fruit tools remain exclusive to Mail Fruits.
                if not isSeedItem and (PlantNames[name] or PlantNames[fruitBaseName]) then
                    continue
                end

                local mailCategory = nil

                -- Prefer an exact asset-folder match, then fall back to the
                -- existing attribute/name heuristics for older items.
                if replicatedCategory and MailableCategories[replicatedCategory] then
                    mailCategory = replicatedCategory

                -- 1. Seed Packs
                elseif categoryLower == "seedpack" or nameLower:find("pack") then
                    mailCategory = "SeedPacks"

                -- 2. Normal Seeds
                elseif isSeedItem then
                    mailCategory = "Seeds"

                -- 3. Trowels
                elseif nameLower:find("trowel") then
                    mailCategory = "Trowels"

                -- 3a. Pets: names such as Bunny do not contain "pet".
                elseif categoryLower == "pet" or categoryLower == "pets"
                    or isPet then
                    mailCategory = "Pets"

                -- 4. Sprinklers
                elseif nameLower:find("sprinkler") then
                    mailCategory = "Sprinklers"

                -- 5. Watering Cans
                elseif nameLower:find("watering") or categoryLower:find("watering") then
                    mailCategory = "WateringCans"

                -- 6. Crates
                elseif nameLower:find("crate") then
                    mailCategory = "Crates"

                -- 7. Mushrooms
                elseif nameLower:find("mushroom") then
                    mailCategory = "Mushrooms"

                -- 8. Eggs
                elseif nameLower:find("egg") or categoryLower == "egg" or categoryLower == "eggs" then
                    mailCategory = "Eggs"

                -- 9. Other Tools / Gear
                elseif nameLower:find("pot") or nameLower:find("sign") or nameLower:find("gnome")
                    or nameLower:find("teleporter") or nameLower:find("flashbang")
                    or categoryLower == "gear" or categoryLower == "tool" or categoryLower == "tools" then
                    mailCategory = "Tools"

                -- 10. Plants
                else
                    local cleanName = name
                        :gsub("%s*%[%d+%.?%d*kg%]$", "")
                        :gsub("%s*[Ss]eed%s*$", "")
                        :gsub("^%s+", "")
                        :gsub("%s+$", "")

                    -- Fruit/plant names are intentionally not normal-mail items.
                    -- They belong in the Mail Fruits workflow, which sends IDs
                    -- and applies its fruit-specific batching rules.
                end

                -- THIS PART WAS MISSING
                if mailCategory and MailableCategories[mailCategory] then
                    -- The Mail API uses a pet's UUID, not its display name.
                    -- Other inventory categories continue to use their name.
                    local serverItemKey = isPet and tool:GetAttribute("PetId") or name
                    if mailCategory == "Pets" and (not serverItemKey or serverItemKey == "") then
                        continue
                    end
                    local groupKey = mailCategory .. "\0" .. name
                    local existing = groupedItems[groupKey]
                    if existing then
                        existing.Count = existing.Count + count
                        if isPet then
                            table.insert(existing.ItemKeys, serverItemKey)
                        end
                    else
                        local entry = {
                            Name = name,
                            Count = count,
                            Category = mailCategory,
                            ItemKey = serverItemKey,
                        }
                        if isPet then
                            entry.ItemKeys = { serverItemKey }
                        end
                        groupedItems[groupKey] = entry
                        table.insert(items, entry)
                    end
                end
            end
        end
    end

	scan(Backpack)
	if LocalPlayer.Character then
		scan(LocalPlayer.Character)
	end

	table.sort(items, function(a, b) return a.Name < b.Name end)
	return items
end

-- =========================================================
-- SEND CONFIRMATION
-- A successful Fire call only means the client submitted a request.  The game
-- is the authority on whether the mail was accepted, so confirm the matching
-- inventory item(s) actually disappeared before showing a success message,
-- writing history, firing webhooks, or clearing a queue.
-- Kept in a closed scope to avoid adding long-lived locals to this large file.
-- =========================================================
do
    local Verify = {}

    local function MailKey(category, name)
        return tostring(category or "") .. "\0" .. tostring(name or "")
    end

    function Verify.SnapshotMailQueue(entries)
        local liveByKey = {}
        local presentPetIds = {}

        for _, item in ipairs(GetLiveInventory()) do
            liveByKey[MailKey(item.Category, item.Name)] = tonumber(item.Count) or 0
            if item.Category == "Pets" and item.ItemKeys then
                for _, petId in ipairs(item.ItemKeys) do
                    presentPetIds[tostring(petId)] = true
                end
            end
        end

        local snapshot = { Entries = {}, Expected = 0 }
        for _, entry in ipairs(entries) do
            local copy = {
                Source = entry,
                Category = entry.Category,
                Name = entry.DisplayName or entry.ItemKey,
                Count = tonumber(entry.Count) or 0,
                PetIds = entry.PetIds,
            }
            copy.BeforeCount = liveByKey[MailKey(copy.Category, copy.Name)] or 0
            copy.PetWasPresent = {}
            if copy.Category == "Pets" and copy.PetIds then
                for _, petId in ipairs(copy.PetIds) do
                    copy.PetWasPresent[tostring(petId)] = presentPetIds[tostring(petId)] == true
                end
            end
            snapshot.Expected += copy.Count
            table.insert(snapshot.Entries, copy)
        end
        return snapshot
    end

    function Verify.GetMailOutcome(snapshot)
        local liveByKey = {}
        local presentPetIds = {}
        for _, item in ipairs(GetLiveInventory()) do
            liveByKey[MailKey(item.Category, item.Name)] = tonumber(item.Count) or 0
            if item.Category == "Pets" and item.ItemKeys then
                for _, petId in ipairs(item.ItemKeys) do
                    presentPetIds[tostring(petId)] = true
                end
            end
        end

        local confirmed = {}
        local remaining = {}
        local totalConfirmed = 0
        for _, entry in ipairs(snapshot.Entries) do
            if entry.Category == "Pets" and entry.PetIds then
                local sentIds, unsentIds = {}, {}
                for _, petId in ipairs(entry.PetIds) do
                    local idKey = tostring(petId)
                    if entry.PetWasPresent[idKey] and not presentPetIds[idKey] then
                        table.insert(sentIds, petId)
                    else
                        table.insert(unsentIds, petId)
                    end
                end
                if #sentIds > 0 then
                    totalConfirmed += #sentIds
                    table.insert(confirmed, {
                        Category = "Pets", ItemKey = sentIds[1], PetIds = sentIds,
                        DisplayName = entry.Name, Count = #sentIds,
                    })
                end
                if #unsentIds > 0 then
                    table.insert(remaining, {
                        Category = "Pets", ItemKey = unsentIds[1], PetIds = unsentIds,
                        DisplayName = entry.Name, Count = #unsentIds,
                    })
                end
            else
                local afterCount = liveByKey[MailKey(entry.Category, entry.Name)] or 0
                local sentCount = math.clamp(entry.BeforeCount - afterCount, 0, entry.Count)
                local leftCount = entry.Count - sentCount
                if sentCount > 0 then
                    totalConfirmed += sentCount
                    table.insert(confirmed, {
                        Category = entry.Category, ItemKey = entry.Source.ItemKey,
                        DisplayName = entry.Name, Count = sentCount,
                    })
                end
                if leftCount > 0 then
                    table.insert(remaining, {
                        Category = entry.Category, ItemKey = entry.Source.ItemKey,
                        DisplayName = entry.Name, Count = leftCount,
                    })
                end
            end
        end
        return {
            Confirmed = confirmed,
            Remaining = remaining,
            TotalConfirmed = totalConfirmed,
            FullyConfirmed = totalConfirmed >= snapshot.Expected,
        }
    end

    function Verify.WaitForMailDeduction(snapshot, timeout)
        local deadline = os.clock() + (timeout or 4)
        local outcome = Verify.GetMailOutcome(snapshot)
        while not outcome.FullyConfirmed and os.clock() < deadline do
            task.wait(0.1)
            outcome = Verify.GetMailOutcome(snapshot)
        end
        return outcome
    end

    function Verify.SnapshotFruitIds(fruits)
        local currentlyPresent = {}
        local function scan(container)
            if not container then return end
            for _, item in ipairs(container:GetChildren()) do
                if item:GetAttribute("HarvestedFruit") == true then
                    local id = item:GetAttribute("Id")
                    if id then
                        currentlyPresent[tostring(id)] = true
                    end
                end
            end
        end
        scan(Backpack)
        scan(LocalPlayer.Character)

        local ids = {}
        for _, fruit in ipairs(fruits) do
            local id = tostring(fruit.Id)
            ids[id] = {
                Fruit = fruit,
                WasPresent = currentlyPresent[id] == true,
            }
        end
        return ids
    end

    function Verify.GetFruitOutcome(expectedIds)
        local stillPresent = {}
        local function scan(container)
            if not container then return end
            for _, item in ipairs(container:GetChildren()) do
                if item:GetAttribute("HarvestedFruit") == true then
                    local id = item:GetAttribute("Id")
                    if id then
                        stillPresent[tostring(id)] = true
                    end
                end
            end
        end
        scan(Backpack)
        scan(LocalPlayer.Character)

        local confirmed, remaining = {}, {}
        for id, snapshot in pairs(expectedIds) do
            local fruit = snapshot.Fruit or snapshot
            if not snapshot.WasPresent or stillPresent[id] then
                table.insert(remaining, fruit)
            else
                table.insert(confirmed, fruit)
            end
        end
        return confirmed, remaining
    end

    function Verify.WaitForFruitDeduction(expectedIds, timeout)
        local deadline = os.clock() + (timeout or 4)
        local confirmed, remaining = Verify.GetFruitOutcome(expectedIds)
        while #remaining > 0 and os.clock() < deadline do
            task.wait(0.1)
            confirmed, remaining = Verify.GetFruitOutcome(expectedIds)
        end
        return confirmed, remaining
    end

    Theme.MailVerify = Verify
end

-- =========================================================
-- ROOT GUI
-- =========================================================
local GuiParent = GetGuiParent()

local ExistingGui = GuiParent:FindFirstChild("MailScriptGui")
if ExistingGui then
    ExistingGui:Destroy()
end

local ScreenGui = New("ScreenGui", {
    Name = "MailScriptGui",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, GuiParent)

local DropShadowHolder = New("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 580, 0, 420),
    ZIndex = 0,
    Name = "DropShadowHolder",
    Position = UDim2.new(0.5, 0, 0.5, 0),
}, ScreenGui)

-- Scale the complete window as one unit so every panel, button, and shadow
-- grows together without distorting the existing internal layout.  Desktop
-- keeps the original 105% presentation; phones use a responsive scale so the
-- full window remains usable in portrait and landscape.
local MailWindowScale = New("UIScale", {
    Name = "MailResponsiveScale",
    Scale = 1.05,
}, DropShadowHolder)

local function updateMailWindowScale()
    -- Touch-only devices are treated as mobile. Touchscreen Windows devices
    -- with a physical keyboard keep the normal desktop size.
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    if not isMobile then
        MailWindowScale.Scale = 1.05
        return
    end

    local camera = workspace.CurrentCamera
    local viewportWidth = camera and camera.ViewportSize.X or 640

    -- Leave a small horizontal margin while allowing the original layout to
    -- shrink smoothly on narrow phone screens.
    MailWindowScale.Scale = math.clamp((viewportWidth - 20) / 580, 0.55, 0.78)
end

updateMailWindowScale()
task.defer(function()
    local camera = workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMailWindowScale)
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateMailWindowScale)
end)

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
    Size = UDim2.new(0, 580, 0, 420),
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
    Size = UDim2.new(0, 580, 0, 420),
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

-- Low-contrast star texture. It is generated once, uses the local user ID as
-- its seed, and stays behind every panel so the UI remains easy to read.
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

PetNames = {
    ["BaldEagle"] = true, ["Bear"] = true, ["Bee"] = true,
    ["BlackDragon"] = true, ["Bunny"] = true, ["Butterfly"] = true,
    ["Deer"] = true, ["Dog"] = true, ["Dragonfly"] = true,
    ["Firefly"] = true, ["Fox"] = true, ["Frog"] = true,
    ["GoldenDragonfly"] = true, ["Hedgehog"] = true, ["IceSerpent"] = true,
    ["Monkey"] = true, ["Owl"] = true, ["Raccoon"] = true,
    ["Robin"] = true, ["ShadowDragon"] = true, ["Squirrel"] = true,
    ["Swan"] = true, ["Turkey"] = true, ["Turtle"] = true,
    ["Unicorn"] = true, ["Wolf"] = true,
}

-- Item names supplied by the live asset folders.  The values are the
-- existing Mail categories used by the send request; Props use the generic
-- Tools category because the Mail API handles them as tools/gears.
local ReplicatedAssetCategories = {
    Pets = "Pets",
    Crates = "Crates",
    WateringCans = "WateringCans",
    Sprinklers = "Sprinklers",
    SeedPacks = "SeedPacks",
    Props = "Tools",
    Eggs = "Eggs",
}

local function RegisterReplicatedAsset(Asset, MailCategory)
    if not Asset then
        return
    end

    local AssetName = tostring(Asset.Name or "")
    if AssetName == "" then
        return
    end

    ReplicatedAssetItems[AssetName] = MailCategory
    if MailCategory == "Pets" then
        -- This also makes non-Tool pet instances eligible for the scanner.
        PetNames[AssetName] = true
    end
end

local function LoadReplicatedAssetCategories()
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    if not Assets then
        return
    end

    for FolderName, MailCategory in pairs(ReplicatedAssetCategories) do
        local Folder = Assets:FindFirstChild(FolderName)
        if Folder then
            for _, Asset in ipairs(Folder:GetChildren()) do
                RegisterReplicatedAsset(Asset, MailCategory)
            end

            -- Pick up newly-added assets without needing to re-execute.
            Folder.ChildAdded:Connect(function(Asset)
                RegisterReplicatedAsset(Asset, MailCategory)
            end)
        end
    end
end

LoadReplicatedAssetCategories()

for i = 1, 116 do
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

-- A few stars inside translucent panels make the texture feel intentional,
-- rather than leaving it only in the thin gaps between UI sections.
local function AddPanelStars(panel, seed, count)
    local random = Random.new(seed)
    for i = 1, count do
        local bright = random:NextNumber() > 0.78
        local star = New("Frame", {
            Name = "PanelStar",
            BackgroundColor3 = starColors[random:NextInteger(1, #starColors)],
            BackgroundTransparency = bright and random:NextNumber(0.38, 0.55) or random:NextNumber(0.68, 0.84),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(random:NextNumber(0.04, 0.96), 0, random:NextNumber(0.12, 0.93), 0),
            Size = UDim2.new(0, bright and 2 or 1, 0, bright and 2 or 1),
            ZIndex = 1,
        }, panel)
        New("UICorner", { CornerRadius = UDim.new(1, 0) }, star)
    end
end

New("UIStroke", {
    Color = Theme.Stroke,
    Thickness = 1,
    Transparency = 0.86,
}, Main)

-- =========================================================
-- TITLE BAR (Logo, Title/Subtitle, Discord pill + copy notif)
-- =========================================================
local TitleBar = New("Frame", {
    Name = "TitleBar",
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.999,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 38),
}, Main)

local LogoImage = New("ImageLabel", {
    Image = Config.Logo,
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

local HubSubTitle = New("TextLabel", {
    Font = Theme.FontBody,
    Text = Config.SubTitle,
    TextColor3 = Config.SubTitleColor or Color3.fromRGB(180, 180, 180),
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
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Surface3,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.new(0, 200, 0.5, 0),
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

task.defer(function()
    local titleWidth = math.max(HubTitle.AbsoluteSize.X, HubSubTitle.AbsoluteSize.X)
    local pillX = math.clamp(40 + titleWidth + 14, 200, 315)
    DiscordPill.Position = UDim2.new(0, pillX, 0.5, 0)
end)

local DiscordButton = New("TextButton", {
    Font = Theme.Font,
    Text = "",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    Name = "DiscordButton",
}, DiscordPill)

DiscordButton.Activated:Connect(function()
    pcall(function()
        if setclipboard then
            setclipboard(Config.Discord)
        end
    end)

    local NotifGui = New("ScreenGui", {
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Name = "MailDiscordNotif",
    }, GuiParent)

    local NotifFrame = New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -30, 1, -30),
        Size = UDim2.new(0, 320, 0, 70),
    }, NotifGui)
    New("UICorner", { CornerRadius = UDim.new(0, 8) }, NotifFrame)

    local TitleScoop = New("TextLabel", {
        Font = Theme.Font,
        Text = "ScoopHub",
        TextColor3 = Theme.White,
        TextSize = 14,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(0, 0, 0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, NotifFrame)

    local TitleDiscord = New("TextLabel", {
        Font = Theme.Font,
        Text = " Discord",
        TextColor3 = Theme.Red,
        TextSize = 14,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(0, 0, 0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, NotifFrame)

    task.defer(function()
        TitleDiscord.Position = UDim2.new(0, 12 + TitleScoop.TextBounds.X, 0, 8)
    end)

    local CloseNotif = New("TextButton", {
        Text = "X",
        Font = Theme.Font,
        TextSize = 14,
        TextColor3 = Theme.Muted,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 6),
        Size = UDim2.new(0, 22, 0, 22),
    }, NotifFrame)

    CloseNotif.Activated:Connect(function()
        NotifGui:Destroy()
    end)

    New("TextLabel", {
        Font = Theme.FontBody,
        Text = "Copied to clipboard: " .. Config.Discord,
        TextColor3 = Theme.Muted,
        TextSize = 13,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 34),
        Size = UDim2.new(1, -24, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, NotifFrame)

    NotifFrame.Position = UDim2.new(1, 400, 1, -30)
    SafeTween(NotifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Position = UDim2.new(1, -30, 1, -30)
    })

    task.delay(5, function()
        if NotifGui and NotifGui.Parent then
            SafeTween(NotifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
                Position = UDim2.new(1, 400, 1, -30)
            })
            task.delay(0.5, function()
                if NotifGui then NotifGui:Destroy() end
            end)
        end
    end)
end)

local MinButton = New("TextButton", {
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

local CloseButton = New("TextButton", {
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

local Body = New("Frame", {
    Name = "Body",
    Position = UDim2.new(0, 0, 0, 39),
    Size = UDim2.new(1, 0, 1, -39),
    BackgroundTransparency = 1,
}, Main)

-- =========================================================
-- TABS: MAIL / MAIL FRUITS / MAIL HISTORY
-- =========================================================
local TabBar = New("Frame", {
    Name = "TabBar",
    Position = UDim2.new(0, 12, 0, 8),
    Size = UDim2.new(1, -24, 0, 30),
    BackgroundColor3 = Theme.TabBg,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
}, Body)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, TabBar)
New("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 20, 28)),
        ColorSequenceKeypoint.new(0.55, Theme.TabBg),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(43, 12, 17)),
    }),
    Rotation = 8,
}, TabBar)
New("UIStroke", { Color = Theme.Glow, Thickness = 1, Transparency = 0.78 }, TabBar)

local MailTabButton = New("TextButton", {
    Name = "MailTab",
    Text = "MAIL",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 16, 0, 0),
    Size = UDim2.new(0, 50, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, TabBar)

local FruitsTabButton = New("TextButton", {
    Name = "MailFruitsTab",
    Text = "MAIL FRUITS",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 75, 0, 0),
    Size = UDim2.new(0, 95, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, TabBar)

local HistoryTabButton = New("TextButton", {
    Name = "MailHistoryTab",
    Text = "MAIL HISTORY",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 180, 0, 0),
    Size = UDim2.new(0, 110, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, TabBar)

Theme.PendingTabButton = New("TextButton", {
    Name = "PendingQueueTab",
    Text = "PENDING",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 300, 0, 0),
    Size = UDim2.new(0, 78, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, TabBar)

local TabIndicator = New("Frame", {
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 16, 1, -2),
    Size = UDim2.new(0, 50, 0, 2),
}, TabBar)
New("UICorner", { CornerRadius = UDim.new(0, 1) }, TabIndicator)

local MailPage = New("Frame", {
    Name = "MailPage",
    Position = UDim2.new(0, 12, 0, 44),
    Size = UDim2.new(1, -24, 1, -52),
    BackgroundTransparency = 1,
}, Body)

local FruitsPage = New("Frame", {
    Name = "MailFruitsPage",
    Position = UDim2.new(0, 12, 0, 44),
    Size = UDim2.new(1, -24, 1, -52),
    BackgroundTransparency = 1,
    Visible = false,
}, Body)

local HistoryPage = New("Frame", {
    Name = "MailHistoryPage",
    Position = UDim2.new(0, 12, 0, 44),
    Size = UDim2.new(1, -24, 1, -52),
    BackgroundTransparency = 1,
    Visible = false,
}, Body)

Theme.PendingPage = New("Frame", {
    Name = "PendingQueuePage",
    Position = UDim2.new(0, 12, 0, 44),
    Size = UDim2.new(1, -24, 1, -52),
    BackgroundTransparency = 1,
    Visible = false,
}, Body)

-- Forward declarations used by tab switching.  The item picker is created
-- later, but it must be closable before changing pages.
local ItemDropdown
local CloseItemDropdown

local function SwitchTab(tab)
    -- Never leave the item picker floating over another page.
    if CloseItemDropdown then
        CloseItemDropdown()
    end

    MailPage.Visible = tab == "mail"
    FruitsPage.Visible = tab == "fruits"
    HistoryPage.Visible = tab == "history"
    Theme.PendingPage.Visible = tab == "pending"

    if tab == "pending" and Theme.RefreshPendingQueuePage then
        Theme.RefreshPendingQueuePage()
    end

    MailTabButton.TextColor3 = tab == "mail" and Theme.Text or Theme.TextDim
    FruitsTabButton.TextColor3 = tab == "fruits" and Theme.Text or Theme.TextDim
    HistoryTabButton.TextColor3 = tab == "history" and Theme.Text or Theme.TextDim
    Theme.PendingTabButton.TextColor3 = tab == "pending" and Theme.Text or Theme.TextDim

    local positions = {
        mail = UDim2.new(0, 16, 1, -2),
        fruits = UDim2.new(0, 75, 1, -2),
        history = UDim2.new(0, 180, 1, -2),
        pending = UDim2.new(0, 300, 1, -2),
    }
    local sizes = {
        mail = UDim2.new(0, 50, 0, 2),
        fruits = UDim2.new(0, 90, 0, 2),
        history = UDim2.new(0, 100, 0, 2),
        pending = UDim2.new(0, 66, 0, 2),
    }
    SafeTween(TabIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Position = positions[tab],
        Size = sizes[tab],
    })
end

MailTabButton.Activated:Connect(function() SwitchTab("mail") end)
FruitsTabButton.Activated:Connect(function() SwitchTab("fruits") end)
HistoryTabButton.Activated:Connect(function() SwitchTab("history") end)
Theme.PendingTabButton.Activated:Connect(function() SwitchTab("pending") end)

-- =========================================================
-- Reusable bordered panel helper
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
    AddPanelStars(Panel, LocalPlayer.UserId + (#name * 113), 14)
    New("UIStroke", { Color = Theme.PanelLine, Thickness = 1.25, Transparency = 0.22 }, Panel)

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

-- Reusable "SEND TO?" panel (used by both Mail tab and Fruits tab)
local function CreateSendToPanel(parent)
    local Panel = CreatePanel(parent, "SendToFrame", UDim2.new(0, 0, 0, 0), UDim2.new(0, 260, 0, 100), "SEND TO?")

    local box = New("TextBox", {
        Name = "RecipientInput",
        PlaceholderText = "Username of recipient",
        Text = "",
        Font = Theme.Font,
        TextSize = 14,
        TextColor3 = Theme.InputText,
        PlaceholderColor3 = Theme.InputText,
        BackgroundColor3 = Theme.InputBg,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 26),
        Size = UDim2.new(1, -16, 0, 26),
        ClearTextOnFocus = false,
    }, Panel)
    New("UICorner", { CornerRadius = UDim.new(0, 5) }, box)
    New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)

    -- Keep the recipient field clean when idle, then show a clear focus ring
    -- while it is being edited.  This is shared by Mail and Mail Fruits.
    local recipientFocusStroke = New("UIStroke", {
        Color = Theme.Red,
        Thickness = 1.15,
        Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, box)

    box.Focused:Connect(function()
        SafeTween(recipientFocusStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 0,
        })
    end)

    box.FocusLost:Connect(function()
        SafeTween(recipientFocusStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
        })
    end)

    local avatar = New("ImageLabel", {
        Name = "ImageOfUser",
        Image = "",
        ImageColor3 = Theme.TextDim,
        ImageTransparency = 0.22,
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 58),
        Size = UDim2.new(0, 34, 0, 34),
    }, Panel)
    New("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
    New("UIStroke", {
        Color = Theme.Red,
        Thickness = 1.25,
        Transparency = 0.18,
    }, avatar)

    local avatarRequestId = 0
    local function ResetAvatar()
        avatar.Image = ""
        avatar.ImageColor3 = Theme.TextDim
        avatar.ImageTransparency = 0.22
    end

    local status = New("TextLabel", {
        Name = "RecipientPreview",
        Text = "",
        Font = Theme.Font,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextWrapped = true,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 50, 0, 58),
        Size = UDim2.new(1, -58, 0, 34),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Panel)

    box:GetPropertyChangedSignal("Text"):Connect(function()
        avatarRequestId += 1
        if box.Text:gsub("%s+", "") == "" then
            status.Text = ""
            ResetAvatar()
        end
    end)

    box.FocusLost:Connect(function()
        local user = box.Text
        if user == "" then
            status.Text = ""
            ResetAvatar()
            return
        end
        local requestId = avatarRequestId
        status.TextColor3 = Theme.TextDim
        status.Text = "Checking..."
        task.spawn(function()
            local ok, userId = pcall(function()
                return Players:GetUserIdFromNameAsync(user)
            end)
            if requestId ~= avatarRequestId then
                return
            end
            if ok and userId then
                status.TextColor3 = Theme.Success
                status.Text = "Found: " .. user .. " (" .. userId .. ")"
                avatar.ImageColor3 = Theme.White
                avatar.ImageTransparency = 0
                local thumbOk, thumb = pcall(function()
                    return Players:GetUserThumbnailAsync(
                        userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100
                    )
                end)
                if requestId == avatarRequestId and thumbOk and thumb then
                    avatar.Image = thumb
                end
            else
                status.TextColor3 = Theme.Text
                status.Text = "Player not found"
                ResetAvatar()
            end
        end)
    end)

    return Panel, box
end

-- =========================================================
-- MAIL TAB
-- =========================================================
local SendToPanel, RecipientBox = CreateSendToPanel(MailPage)

local AddItemPanel = CreatePanel(
    MailPage, "AddItemFrame",
    UDim2.new(0, 270, 0, 0), UDim2.new(1, -270, 0, 100),
    "ADD ITEM TO SEND"
)

local SelectItemButton = New("TextButton", {
    Name = "SelectItemButton",
    Text = "",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.InputText,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Position = UDim2.new(0, 8, 0, 26),
    Size = UDim2.new(1, -56, 0, 26),
}, AddItemPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SelectItemButton)

-- The selected item field is composed like the dropdown rows: icon, name,
-- available quantity, and a small dropdown chevron.
local SelectedItemIcon
local SelectedItemLabel = New("TextLabel", {
    Name = "SelectedItemName",
    Text = "Select item",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.InputText,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 38, 0, 0),
    Size = UDim2.new(1, -78, 1, 0),
    ZIndex = 23,
}, SelectItemButton)
local SelectedItemCount = New("TextLabel", {
    Name = "SelectedItemCount",
    Text = "",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.TextDim,
    TextXAlignment = Enum.TextXAlignment.Right,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -42, 0, 0),
    Size = UDim2.new(0, 28, 1, 0),
    ZIndex = 23,
}, SelectItemButton)
New("TextLabel", {
    Name = "SelectedItemChevron",
    Text = "\u{25BC}",
    Font = Theme.Font,
    TextSize = 9,
    TextColor3 = Theme.TextDim,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -15, 0, 0),
    Size = UDim2.new(0, 12, 1, 0),
    ZIndex = 23,
}, SelectItemButton)

local RefreshItemButton = New("TextButton", {
    Name = "RefreshItemButton",
    Text = "",
    Font = Theme.Font,
    TextSize = 16,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -40, 0, 26),
    Size = UDim2.new(0, 32, 0, 26),
}, AddItemPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, RefreshItemButton)
New("UIStroke", { Color = Theme.Red, Thickness = 1 }, RefreshItemButton)

New("ImageLabel", {
    Name = "RefreshIcon",
    Image = Config.RefreshIcon,
    ImageColor3 = Theme.White,
    ScaleType = Enum.ScaleType.Fit,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 16, 0, 16),
}, RefreshItemButton)

local AmountBox = New("TextBox", {
    Name = "AmountInput",
    PlaceholderText = "Amount",
    Text = "",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.InputText,
    PlaceholderColor3 = Theme.InputText,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 60),
    Size = UDim2.new(1, -96, 0, 26),
    ClearTextOnFocus = false,
}, AddItemPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, AmountBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, AmountBox)
AddFocusBorder(AmountBox)

local AddButton = New("TextButton", {
    Name = "AddButton",
    Text = "ADD",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    TextStrokeColor3 = Color3.fromRGB(91, 8, 14),
    TextStrokeTransparency = 0.72,
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -80, 0, 60),
    Size = UDim2.new(0, 72, 0, 26),
}, AddItemPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, AddButton)
New("UIGradient", {
    -- A UIGradient on a TextButton also tints its text. Keep the button's
    -- solid crimson fill so ADD remains high-contrast at every size.
    Enabled = false,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Red),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(172, 27, 42)),
    }),
    Rotation = 12,
}, AddButton)
New("UIStroke", { Color = Color3.fromRGB(255, 150, 157), Thickness = 1, Transparency = 0.62 }, AddButton)

local BottomPanel = New("Frame", {
    Name = "BottomFrame",
    Position = UDim2.new(0, 0, 0, 110),
    Size = UDim2.new(1, 0, 1, -110),
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
}, MailPage)
New("UICorner", { CornerRadius = UDim.new(0, 8) }, BottomPanel)
New("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 17, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 8, 12)),
    }),
    Rotation = 20,
}, BottomPanel)
AddPanelStars(BottomPanel, LocalPlayer.UserId + 719, 22)
New("UIStroke", { Color = Theme.PanelLine, Thickness = 1.25, Transparency = 0.22 }, BottomPanel)

local QueueHeader = New("TextLabel", {
    Name = "QueueHeader",
    Text = "Queue \u{2022} 0 items \u{2022} 0 total",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 8),
    Size = UDim2.new(0.6, -14, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
}, BottomPanel)

local QueueList = New("ScrollingFrame", {
    Name = "QueueList",
    BackgroundColor3 = Theme.ObsidianMid,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 28),
    Size = UDim2.new(0.62, -14, 1, -38),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Red,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, BottomPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, QueueList)
New("UIStroke", { Color = Theme.PanelLine, Thickness = 1 }, QueueList)
New("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 5, 8)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 8, 13)),
    }),
    Rotation = 90,
}, QueueList)
New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, QueueList)
New("UIPadding", {
    PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
}, QueueList)

local QueuePlaceholder = New("TextLabel", {
    Name = "QueuePlaceholder",
    Text = "Queue is empty",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.TextDim,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
}, QueueList)

local StatusLabel = New("TextLabel", {
    Name = "StatusLabel",
    Text = "",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.62, 6, 0, 26),
    -- Status messages can be a few lines long when a mail request is not
    -- confirmed. Give the label room instead of silently clipping it.
    Size = UDim2.new(0.38, -14, 0, 38),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
}, BottomPanel)

local RefreshStatusLabel = New("TextLabel", {
    Name = "RefreshStatusLabel",
    Text = "",
    Font = Theme.FontBody,
    TextSize = 10,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.62, 6, 0, 66),
    Size = UDim2.new(0.38, -14, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true,
}, BottomPanel)

-- Kept separate from StatusLabel so a queued delivery never replaces the
-- green success/cooldown state of the request that is currently finishing.
local QueuedSendLabel = New("TextLabel", {
    Name = "QueuedSendLabel",
    Text = "",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.62, 6, 0, 48),
    Size = UDim2.new(0.38, -14, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
}, BottomPanel)

local SendButton = New("TextButton", {
    Name = "SendButton",
    Text = "SEND",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    TextStrokeColor3 = Color3.fromRGB(91, 8, 14),
    TextStrokeTransparency = 0.72,
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(0.62, 6, 1, -40),
    Size = UDim2.new(0.38, -14, 0, 28),
}, BottomPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, SendButton)
New("UIGradient", {
    -- Same treatment as ADD: a clear, opaque action button.
    Enabled = false,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Red),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(172, 27, 42)),
    }),
    Rotation = 12,
}, SendButton)
New("UIStroke", { Color = Color3.fromRGB(255, 150, 157), Thickness = 1, Transparency = 0.58 }, SendButton)


-- Item dropdown popup ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â parented to Body so it can paint over BottomPanel
ItemDropdown = New("Frame", {
    Name = "ItemDropdown",
    BackgroundColor3 = Theme.Surface2,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 50,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, 234, 0, 210),
}, Body)

local CurrentDropdownWidth = 234
local MaxDropdownVisibleRows = 6
local DropdownRowHeight = 34
local DropdownTopPadding = 42
local DropdownBottomBuffer = 6 -- keeps the last row clear of the clipped edge

New("UICorner", { CornerRadius = UDim.new(0, 6) }, ItemDropdown)
New("UIStroke", { Color = Theme.Red, Thickness = 1.5 }, ItemDropdown)

local ItemSearchBox = New("TextBox", {
    Name = "ItemSearchBox",
    PlaceholderText = "Search items...",
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
}, ItemDropdown)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, ItemSearchBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 8) }, ItemSearchBox)
AddFocusBorder(ItemSearchBox)

local ItemDropdownScroll = New("ScrollingFrame", {
    Name = "ItemDropdownScroll",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 4, 0, 34),
    Size = UDim2.new(1, -8, 1, -38),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Red,
    ZIndex = 51,
}, ItemDropdown)
New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, ItemDropdownScroll)

local function UpdateItemDropdownPosition()
    local Success = pcall(function()
        local BasePos = Body.AbsolutePosition
        local BtnPos = SelectItemButton.AbsolutePosition
        local BtnSize = SelectItemButton.AbsoluteSize
        local RefreshSize = RefreshItemButton.AbsoluteSize

        -- AbsolutePosition/AbsoluteSize already include the window UIScale.
        -- ItemDropdown is parented to Body, so convert those screen pixels back
        -- to Body's local units before assigning Position/Size. Without this,
        -- the dropdown is scaled a second time and shifts right/gets too wide.
        local WindowScale = 1
        local ScaleObject = DropShadowHolder:FindFirstChildOfClass("UIScale")
        if ScaleObject then
            WindowScale = math.max(tonumber(ScaleObject.Scale) or 1, 0.01)
        end

        local X = (BtnPos.X - BasePos.X) / WindowScale
        local Y = (BtnPos.Y - BasePos.Y + BtnSize.Y + 4) / WindowScale
        local Width = (BtnSize.X + RefreshSize.X + 4) / WindowScale

        CurrentDropdownWidth = Width
        ItemDropdown.Position = UDim2.new(0, X, 0, Y)
        ItemDropdown.Size = UDim2.new(0, Width, 0, ItemDropdown.Size.Y.Offset)
    end)

    if not Success then
        ItemDropdown.Position = UDim2.new(0, 278, 0, 60)
    end
end

local function ResizeItemDropdown(rowCount)
    local VisibleRows = math.clamp(rowCount, 1, MaxDropdownVisibleRows)
    local ContentHeight = DropdownTopPadding + (VisibleRows * DropdownRowHeight) + DropdownBottomBuffer
    ItemDropdown.Size = UDim2.new(0, CurrentDropdownWidth, 0, ContentHeight)
end

-- =========================================================
-- MAIL FRUITS TAB
-- =========================================================
local FruitsSendTo, FruitsRecipientBox = CreateSendToPanel(FruitsPage)

local FruitPickerPanel = CreatePanel(
    FruitsPage, "FruitPickerFrame",
    UDim2.new(0, 270, 0, 0), UDim2.new(1, -270, 0, 100),
    "ADD ITEM TO SEND"
)

local OpenFruitPickerBtn = New("TextButton", {
    Text = "Choose fruits (0/20)",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.InputText,
    BackgroundColor3 = Theme.InputBg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 26),
    Size = UDim2.new(1, -16, 0, 26),
}, FruitPickerPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, OpenFruitPickerBtn)

local FruitsSendAllButton = New("TextButton", {
    Text = "SEND ALL FRUITS",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 60),
    Size = UDim2.new(1, -16, 0, 26),
}, FruitPickerPanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, FruitsSendAllButton)

local FruitSelectWindow = New("Frame", {
    Name = "FruitSelectWindow",
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 100,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    ClipsDescendants = true,
}, FruitsPage)
New("UICorner", { CornerRadius = UDim.new(0, 10) }, FruitSelectWindow)
New("UIStroke", { Color = Theme.Stroke, Thickness = 1.5, Transparency = 0.15 }, FruitSelectWindow)

local FruitHeaderBar = New("Frame", {
    BackgroundColor3 = Theme.Surface2,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 42),
}, FruitSelectWindow)
New("UICorner", { CornerRadius = UDim.new(0, 10) }, FruitHeaderBar)

New("Frame", {
    BackgroundColor3 = Theme.Surface2,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -10),
    Size = UDim2.new(1, 0, 0, 10),
}, FruitHeaderBar)

New("TextLabel", {
    Text = "Up to 20  \u{2022}  highest value first  \u{2022}  current prices",
    Font = Theme.Font,
    TextSize = 11,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 0, 0),
    Size = UDim2.new(0.48, -14, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, FruitHeaderBar)

local FruitCounterLabel = New("TextLabel", {
    Text = "0/20",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.Success,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.49, 0, 0, 0),
    Size = UDim2.new(0.10, 0, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
}, FruitHeaderBar)

local FruitTotalValueLabel = New("TextLabel", {
    Text = "Total: 0\u{00A2}",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(246, 196, 104),
    BackgroundTransparency = 1,
    Position = UDim2.new(0.61, 0, 0, 0),
    Size = UDim2.new(0.17, 0, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
}, FruitHeaderBar)

local FruitDoneBtn = New("TextButton", {
    Text = "Done",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Theme.Success,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.new(0, 74, 0, 28),
}, FruitHeaderBar)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, FruitDoneBtn)

local FruitFullList = New("ScrollingFrame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 42),
    Size = UDim2.new(1, 0, 1, -42),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 5,
    ScrollBarImageColor3 = Theme.Muted,
}, FruitSelectWindow)
local FruitFullListLayout = New("UIListLayout", {
    Padding = UDim.new(0, 3),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, FruitFullList)
New("UIPadding", {
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
}, FruitFullList)

local function UpdateFruitFullListCanvas()
    if not FruitFullList or not FruitFullListLayout then return end

    -- AbsoluteContentSize includes every row and its inter-row spacing;
    -- include the ScrollingFrame's top/bottom UIPadding so the last row can
    -- be brought completely above the bottom edge.
    FruitFullList.CanvasSize = UDim2.new(
        0,
        0,
        0,
        math.max(0, math.ceil(FruitFullListLayout.AbsoluteContentSize.Y) + 16)
    )
end

FruitFullListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateFruitFullListCanvas)

local FruitsQueuePanel = New("Frame", {
    BackgroundColor3 = Theme.Surface,
    -- Match the Mail queue: this is a transparent layout holder, not a
    -- filled burgundy card. The list and action buttons stay solid.
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 108),
    Size = UDim2.new(1, 0, 1, -108),
}, FruitsPage)
New("UICorner", { CornerRadius = UDim.new(0, 8) }, FruitsQueuePanel)
New("UIGradient", {
    Enabled = false,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 17, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 8, 12)),
    }),
    Rotation = 20,
}, FruitsQueuePanel)
AddPanelStars(FruitsQueuePanel, LocalPlayer.UserId + 941, 22)
New("UIStroke", { Color = Theme.PanelLine, Thickness = 1.25, Transparency = 0.22 }, FruitsQueuePanel)

local FruitsQueueHeader = New("TextLabel", {
    Text = "Queue \u{2022} 0 items",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 6),
    Size = UDim2.new(0.55, -12, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, FruitsQueuePanel)

local FruitsQueueTotalLabel = New("TextLabel", {
    Text = "TOTAL VALUE: 0\u{00A2}",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(246, 196, 104),
    BackgroundTransparency = 1,
    Position = UDim2.new(0.20, 0, 0, 6),
    Size = UDim2.new(0.43, -12, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, FruitsQueuePanel)

local FruitsQueueList = New("ScrollingFrame", {
    BackgroundColor3 = Theme.Bg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 28),
    Size = UDim2.new(0.62, -14, 1, -40),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Red,
}, FruitsQueuePanel)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, FruitsQueueList)
New("UIStroke", { Color = Theme.PanelLine, Thickness = 1.2 }, FruitsQueueList)
New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, FruitsQueueList)
New("UIPadding", {
    PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
}, FruitsQueueList)

local QueueEmptyLabel = New("TextLabel", {
    Name = "QueueEmpty",
    Text = "Queue is empty",
    Font = Theme.Font,
    TextSize = 14,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
}, FruitsQueueList)

local FruitsSuccessLabel = New("TextLabel", {
    Text = "",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.Success,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.62, 6, 0, 26),
    Size = UDim2.new(0.38, -14, 0, 32),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
}, FruitsQueuePanel)

local FruitsCooldownLabel = New("TextLabel", {
    Text = "",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.62, 6, 0, 62),
    Size = UDim2.new(0.38, -14, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, FruitsQueuePanel)

New("TextLabel", {
    Name = "FruitPriceStockTitle",
    Text = "Fruit Price Stock:",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0.62, 6, 1, -128),
    Size = UDim2.new(0.38, -14, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
}, FruitsQueuePanel)

FruitPriceCountdownLabel = New("TextLabel", {
    Name = "FruitPriceCountdownLabel",
    Text = "Refresh in --m --s",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Theme.Surface3,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Position = UDim2.new(0.62, 6, 1, -106),
    Size = UDim2.new(0.38, -14, 0, 24),
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
}, FruitsQueuePanel)
New("UICorner", { CornerRadius = UDim.new(1, 0) }, FruitPriceCountdownLabel)
New("UIStroke", {
    Color = Theme.Red,
    Thickness = 1,
    Transparency = 0.62,
}, FruitPriceCountdownLabel)

local FruitsClearQueueBtn = New("TextButton", {
    Text = "CLEAR ALL",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.RedDark,
    BorderSizePixel = 0,
    Position = UDim2.new(0.62, 6, 1, -74),
    Size = UDim2.new(0.38, -14, 0, 26),
}, FruitsQueuePanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, FruitsClearQueueBtn)
New("UIStroke", { Color = Color3.fromRGB(226, 95, 105), Thickness = 1, Transparency = 0.62 }, FruitsClearQueueBtn)

local FruitsSendButton = New("TextButton", {
    Text = "SEND",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.White,
    BackgroundColor3 = Theme.Red,
    BorderSizePixel = 0,
    Position = UDim2.new(0.62, 6, 1, -40),
    Size = UDim2.new(0.38, -14, 0, 28),
}, FruitsQueuePanel)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, FruitsSendButton)
New("UIStroke", { Color = Color3.fromRGB(255, 150, 157), Thickness = 1, Transparency = 0.58 }, FruitsSendButton)

-- =========================================================
-- MAIL HISTORY TAB
-- =========================================================
local HistoryCountLabel = New("TextLabel", {
    Name = "HistoryCountLabel",
    Text = "0 sends logged",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, -70, 0, 16),
}, HistoryPage)

local HistoryClearButton = New("TextButton", {
    Name = "HistoryClearButton",
    Text = "Clear",
    Font = Theme.Font,
    TextSize = 12,
    TextColor3 = Theme.Text,
    BackgroundColor3 = Theme.RedDark,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 60, 0, 22),
}, HistoryPage)
New("UICorner", { CornerRadius = UDim.new(0, 5) }, HistoryClearButton)
New("UIStroke", { Color = Theme.Red, Thickness = 1, Transparency = 0.4 }, HistoryClearButton)

local HistorySearchBox = New("TextBox", {
    Name = "HistorySearchBox",
    PlaceholderText = "Search a username (sender or recipient)...",
    Text = "",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.White,
    PlaceholderColor3 = Color3.fromRGB(150, 150, 158),
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Position = UDim2.new(0, 0, 0, 24),
    Size = UDim2.new(1, 0, 0, 28),
}, HistoryPage)
New("UICorner", { CornerRadius = UDim.new(0, 6) }, HistorySearchBox)
New("UIPadding", { PaddingLeft = UDim.new(0, 10) }, HistorySearchBox)
AddFocusBorder(HistorySearchBox)

local HistoryList = New("ScrollingFrame", {
    Name = "HistoryList",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 58),
    Size = UDim2.new(1, 0, 1, -58),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Red,
}, HistoryPage)
New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, HistoryList)

local HistoryEmptyLabel = New("TextLabel", {
    Name = "HistoryEmptyLabel",
    Text = "No mail sent yet.",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 30),
}, HistoryList)

-- =========================================================
-- MAIL HISTORY PERSISTENCE
-- =========================================================
local MailHistoryFolder = "MailScriptData"
local MailHistoryFile = MailHistoryFolder .. "/MailHistory_" .. LocalPlayer.UserId .. ".json"
local MaxHistoryEntries = 200

local function HasFileSupport()
    return writefile and readfile and isfile and isfolder and makefolder
end

local function SaveMailHistory(historyTable)
    if not HasFileSupport() then
        warn("[MailScript] Executor doesn't support file I/O ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â history won't persist.")
        return
    end

    pcall(function()
        if not isfolder(MailHistoryFolder) then
            makefolder(MailHistoryFolder)
        end
    end)

    local Serializable = {}
    for i, entry in ipairs(historyTable) do
        if i > MaxHistoryEntries then break end
        table.insert(Serializable, {
            Recipient = entry.Recipient,
            TimeText = entry.TimeText,
            Items = entry.Items,
        })
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(Serializable)
    end)
    if not ok then
        warn("[MailScript] Failed to encode mail history:", encoded)
        return
    end

    local writeOk, writeErr = pcall(writefile, MailHistoryFile, encoded)
    if not writeOk then
        warn("[MailScript] Failed to write mail history file:", writeErr)
    end
end

local function LoadMailHistory()
    if not HasFileSupport() then
        return {}
    end

    local existsOk, exists = pcall(isfile, MailHistoryFile)
    if not existsOk or not exists then
        return {}
    end

    local readOk, contents = pcall(readfile, MailHistoryFile)
    if not readOk then
        warn("[MailScript] Failed to read mail history file:", contents)
        return {}
    end

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(contents)
    end)
    if not decodeOk or type(decoded) ~= "table" then
        warn("[MailScript] Failed to decode mail history file:", decoded)
        return {}
    end

    for _, entry in ipairs(decoded) do
        entry.Open = false
    end
    return decoded
end

-- =========================================================
-- MAIL TAB LOGIC
-- =========================================================
local inventoryCache = {}
local selectedItem = nil
local queue = {}
Theme.FruitsQueue = {}
local mailHistory = LoadMailHistory()

local FindItemAsset
local CreateItemIcon
local ResolveHistoryCategory

-- =========================================================
-- PENDING QUEUE TAB
-- Shows the two queues this script can currently hold: normal Mail and
-- Mail Fruits. A queue can be cancelled here without touching its history.
-- =========================================================
-- This isolated scope is intentional: the main script is close to the Luau
-- local-register limit. The UI references remain captured by the refresh
-- callback, but they no longer stay as locals in the main chunk.
do
PendingHeaderLabel = New("TextLabel", {
    Text = "PENDING DELIVERIES",
    Font = Theme.Font,
    TextSize = 13,
    TextColor3 = Theme.Text,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left,
}, Theme.PendingPage)

PendingSubLabel = New("TextLabel", {
    Text = "Queued sends are delivered automatically when their cooldown ends.",
    Font = Theme.FontBody,
    TextSize = 10,
    TextColor3 = Theme.Muted,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 18),
    Size = UDim2.new(1, 0, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
}, Theme.PendingPage)

PendingList = New("ScrollingFrame", {
    Name = "PendingList",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 40),
    Size = UDim2.new(1, 0, 1, -40),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Red,
}, Theme.PendingPage)
New("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, PendingList)

PendingEmptyLabel = New("TextLabel", {
    Name = "PendingEmptyLabel",
    Text = "No pending deliveries.",
    Font = Theme.FontBody,
    TextSize = 13,
    TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 40),
}, PendingList)

function Theme.GetRecipientThumbnail(username)
    if not username or username == "" then return "" end
    Theme.PendingAvatarCache = Theme.PendingAvatarCache or {}
    if Theme.PendingAvatarCache[username] ~= nil then
        return Theme.PendingAvatarCache[username]
    end
    local ok, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)
    if not ok or not userId then
        Theme.PendingAvatarCache[username] = ""
        return ""
    end
    local imageOk, image = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    Theme.PendingAvatarCache[username] = imageOk and image or ""
    return Theme.PendingAvatarCache[username]
end

Theme.RefreshPendingQueuePage = function()
    if Theme.PendingRefreshScheduled then return end
    Theme.PendingRefreshScheduled = true
    task.defer(function()
        Theme.PendingRefreshScheduled = false
        if not Theme.PendingPage or not Theme.PendingPage.Parent then return end
        if not Theme.PendingPage.Visible then return end

    for _, child in ipairs(PendingList:GetChildren()) do
        if child.Name == "PendingCard" then
            child:Destroy()
        end
    end

    local pendingCards = {}
    for queueNumber, job in ipairs(Theme.PendingMailDeliveries or {}) do
        table.insert(pendingCards, {
            Kind = "MAIL",
            Recipient = job.Recipient,
            Items = job.Items,
            Queued = true,
            Job = job,
            QueueNumber = queueNumber,
        })
    end
    if #Theme.FruitsQueue > 0 then
        table.insert(pendingCards, {
            Kind = "MAIL FRUITS",
            Recipient = FruitsRecipientBox.Text,
            Items = Theme.FruitsQueue,
            Queued = false,
        })
    end

    PendingEmptyLabel.Visible = #pendingCards == 0
    PendingList.CanvasSize = UDim2.new(0, 0, 0, #pendingCards * 130)

    for index, data in ipairs(pendingCards) do
        local card = New("Frame", {
            Name = "PendingCard",
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Size = UDim2.new(1, 0, 0, 122),
            LayoutOrder = index,
        }, PendingList)
        New("UICorner", { CornerRadius = UDim.new(0, 7) }, card)
        New("UIStroke", { Color = Theme.PanelLine, Thickness = 1, Transparency = 0.35 }, card)
        New("Frame", {
            BackgroundColor3 = data.Kind == "MAIL FRUITS" and Theme.Success or Theme.Red,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 3, 1, 0),
        }, card)

        local avatar = New("ImageLabel", {
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
            Image = "",
            Position = UDim2.new(0, 12, 0, 12),
            Size = UDim2.new(0, 36, 0, 36),
        }, card)
        New("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
        New("UIStroke", { Color = Theme.PanelLine, Thickness = 1, Transparency = 0.4 }, avatar)
        local cachedImage = Theme.PendingAvatarCache and Theme.PendingAvatarCache[data.Recipient]
        if cachedImage ~= nil then
            avatar.Image = cachedImage
        else
            task.spawn(function()
                local image = Theme.GetRecipientThumbnail(data.Recipient)
                if avatar.Parent then avatar.Image = image end
            end)
        end

        New("TextLabel", {
            Text = data.Kind == "MAIL" and ("QUEUE " .. tostring(data.QueueNumber or index)) or "MAIL FRUITS",
            Font = Theme.Font,
            TextSize = 10,
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 58, 0, 10),
            Size = UDim2.new(0, 110, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
        New("TextLabel", {
            Text = data.Recipient ~= "" and data.Recipient or "Recipient not set",
            Font = Theme.Font,
            TextSize = 14,
            TextColor3 = Theme.White,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 58, 0, 23),
            Size = UDim2.new(1, -146, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)

        local remaining = math.max(0, math.ceil((Theme.MailCooldownEndTime or 0) - os.clock()))
        local stateText
        if data.Kind == "MAIL" and data.Job == Theme.ActivePendingMailDelivery then
            stateText = "SENDING"
        elseif data.Kind == "MAIL" and data.Queued and remaining > 0 then
            stateText = "QUEUED - " .. remaining .. "s"
        elseif data.Kind == "MAIL" and remaining > 0 then
            stateText = "COOLDOWN - " .. remaining .. "s"
        else
            stateText = "READY"
        end
        New("TextLabel", {
            Text = stateText,
            Font = Theme.Font,
            TextSize = 10,
            TextColor3 = data.Queued and Theme.Success or Theme.TextDim,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 13),
            Size = UDim2.new(0, 120, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, card)

        local count, value = 0, 0
        local names = {}
        for itemIndex, item in ipairs(data.Items) do
            count += tonumber(item.Count) or 1
            value += tonumber(item.Value) or 0
            if itemIndex <= 3 then
                table.insert(names, (item.DisplayName or item.FruitName or item.Name or item.ItemKey) .. " x" .. (item.Count or 1))
            end
        end
        if #data.Items > 3 then table.insert(names, "+" .. (#data.Items - 3) .. " more") end
        local detail = data.Kind == "MAIL FRUITS"
            and (count .. " fruit" .. (count == 1 and "" or "s") .. " - " .. FormatCompactSheckles(value))
            or (count .. " item" .. (count == 1 and "" or "s"))
        New("TextLabel", {
            Text = detail,
            Font = Theme.Font,
            TextSize = 12,
            TextColor3 = data.Kind == "MAIL FRUITS" and Theme.Success or Theme.White,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 58),
            Size = UDim2.new(1, -115, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
        New("TextLabel", {
            Text = table.concat(names, "  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢  "),
            Font = Theme.FontBody,
            TextSize = 10,
            TextColor3 = Theme.Muted,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 78),
            Size = UDim2.new(1, -24, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Visible = false,
        }, card)

        local firstPendingItem = data.Items[1]
        if firstPendingItem then
            local pendingItemName = firstPendingItem.DisplayName or firstPendingItem.FruitName or firstPendingItem.Name or firstPendingItem.ItemKey or "Unknown item"
            local pendingItemCount = tonumber(firstPendingItem.Count) or 1
            local pendingItemIcon = CreateItemIcon(card, pendingItemName, firstPendingItem.Category or (data.Kind == "MAIL FRUITS" and "HarvestedFruits" or nil), 22)
            pendingItemIcon.Position = UDim2.new(0, 12, 0, 82)
            pendingItemIcon.Size = UDim2.new(0, 22, 0, 22)

            New("TextLabel", {
                Text = string.format("%dx %s", pendingItemCount, pendingItemName),
                Font = Theme.Font,
                TextSize = 12,
                TextColor3 = Theme.White,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 42, 0, 79),
                Size = UDim2.new(1, -142, 0, 25),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, card)

            if #data.Items > 1 then
                New("TextLabel", {
                    Text = "+" .. (#data.Items - 1) .. " more",
                    Font = Theme.FontBody,
                    TextSize = 10,
                    TextColor3 = Theme.Muted,
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -102, 0, 84),
                    Size = UDim2.new(0, 72, 0, 16),
                    TextXAlignment = Enum.TextXAlignment.Right,
                }, card)
            end
        end

        local cancel = New("TextButton", {
            Text = "CANCEL",
            Font = Theme.Font,
            TextSize = 10,
            TextColor3 = Theme.White,
            BackgroundColor3 = Theme.RedDark,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -12, 1, -10),
            Size = UDim2.new(0, 82, 0, 24),
        }, card)
        New("UICorner", { CornerRadius = UDim.new(0, 5) }, cancel)
        cancel.Activated:Connect(function()
            if data.Kind == "MAIL" then
                for jobIndex, job in ipairs(Theme.PendingMailDeliveries or {}) do
                    if job == data.Job then
                        table.remove(Theme.PendingMailDeliveries, jobIndex)
                        break
                    end
                end
                if Theme.ActivePendingMailDelivery == data.Job then
                    Theme.ActivePendingMailDelivery = nil
                end
                if Theme.PendingAvatarCache then
                    Theme.PendingAvatarCache[data.Recipient] = nil
                end
            else
                Theme.FruitsQueue = {}
                Theme.RefreshFruitsQueue()
            end
            Theme.RefreshPendingQueuePage()
        end)
    end
    end)
end
end

Theme.RefreshQueueDisplay = function()
    for _, child in ipairs(QueueList:GetChildren()) do
        if child.Name ~= "QueuePlaceholder" and child:IsA("Frame") then
            child:Destroy()
        end
    end

    local totalCount = 0
    for _, entry in ipairs(queue) do
        totalCount += entry.Count
    end
    QueueHeader.Text = string.format("Queue \u{2022} %d item%s \u{2022} %d total",
        #queue, (#queue == 1) and "" or "s", totalCount)

    QueuePlaceholder.Visible = (#queue == 0)
    QueueList.CanvasSize = UDim2.new(0, 0, 0, #queue * 34)

    for i, entry in ipairs(queue) do
        local Row = New("Frame", {
            Name = "QueueRow",
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = i,
        }, QueueList)
        New("UICorner", { CornerRadius = UDim.new(0, 5) }, Row)
        CreateItemIcon(Row, entry.DisplayName or entry.ItemKey, entry.Category, 22)

        New("TextLabel", {
            Name = "QueueItemText",
            Text = entry.DisplayName or entry.ItemKey,
            Font = Theme.FontBody,
            TextSize = 13,
            TextColor3 = Theme.White,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 42, 0, 0),
            Size = UDim2.new(1, -110, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 23,
        }, Row)

        New("TextLabel", {
            Name = "QueueCount",
            Text = "x" .. entry.Count,
            Font = Theme.Font,
            TextSize = 12,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -78, 0, 0),
            Size = UDim2.new(0, 42, 1, 0),
            ZIndex = 23,
        }, Row)

        local RemoveBtn = New("TextButton", {
            Text = "\u{00D7}",
            Font = Theme.Font,
            TextSize = 16,
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.new(0, 22, 0, 22),
        }, Row)

        RemoveBtn.Activated:Connect(function()
            table.remove(queue, i)
            Theme.RefreshQueueDisplay()
        end)
    end

    if Theme.RefreshPendingQueuePage then
        Theme.RefreshPendingQueuePage()
    end
end

local function RefreshHistoryList(FilterText)
    for _, child in ipairs(HistoryList:GetChildren()) do
        if child.Name == "HistoryCard" then
            child:Destroy()
        end
    end

    HistoryCountLabel.Text = #mailHistory .. " send" .. ((#mailHistory == 1) and "" or "s") .. " logged"

    local Query = string.lower(tostring(FilterText or ""))
    local Filtered = {}
    for _, entry in ipairs(mailHistory) do
        if Query == "" or string.find(string.lower(entry.Recipient), Query, 1, true) then
            table.insert(Filtered, entry)
        end
    end

    HistoryEmptyLabel.Visible = (#Filtered == 0)
    HistoryEmptyLabel.Text = (#mailHistory == 0) and "No mail sent yet." or "No matches."

    local yOffset = 0
    for i, entry in ipairs(Filtered) do
        local CollapsedHeight = 46
        local ItemRowHeight = 30
        local ExpandedHeight = CollapsedHeight + (#entry.Items * ItemRowHeight) + 8
        local CardHeight = entry.Open and ExpandedHeight or CollapsedHeight
        local EntryTotalValue = 0
        for _, historyItem in ipairs(entry.Items or {}) do
            EntryTotalValue += (tonumber(historyItem.Value) or 0) * (tonumber(historyItem.Count) or 1)
        end

        local Card = New("Frame", {
            Name = "HistoryCard",
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, CardHeight),
        }, HistoryList)
        New("UICorner", { CornerRadius = UDim.new(0, 6) }, Card)
        New("UIStroke", { Color = Theme.PanelLine, Thickness = 1, Transparency = 0.5 }, Card)
        New("Frame", {
            BackgroundColor3 = Theme.Red,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 3, 1, 0),
        }, Card)

        local HeaderButton = New("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, CollapsedHeight),
        }, Card)

        New("TextLabel", {
            Text = "You \u{2192} " .. entry.Recipient,
            Font = Theme.Font,
            TextSize = 14,
            TextColor3 = Theme.White,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 6),
            Size = UDim2.new(1, -60, 0, 16),
        }, Card)

        New("TextLabel", {
            Text = entry.TimeText,
            Font = Theme.Font,
            TextSize = 13,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 24),
            Size = UDim2.new(0.6, -12, 0, 16),
        }, Card)

        New("TextLabel", {
            Text = (#entry.Items .. " item" .. ((#entry.Items == 1) and "" or "s"))
                .. (EntryTotalValue > 0 and (" \u{2022} " .. FormatCompactSheckles(EntryTotalValue)) or ""),
            Font = Theme.Font,
            TextSize = 13,
            TextColor3 = Theme.Success,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.6, 0, 0, 24),
            Size = UDim2.new(0.4, -30, 0, 16),
        }, Card)

        local Arrow = New("TextLabel", {
            Text = entry.Open and "\u{25BC}" or "\u{25B6}",
            Font = Theme.Font,
            TextSize = 12,
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0, CollapsedHeight / 2),
            Size = UDim2.new(0, 16, 0, 16),
        }, Card)

        if entry.Open then
            local ItemsHolder = New("Frame", {
                Name = "ItemsHolder",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, CollapsedHeight),
                Size = UDim2.new(1, -20, 0, #entry.Items * ItemRowHeight),
            }, Card)
            New("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, ItemsHolder)

            for j, itemEntry in ipairs(entry.Items) do
                local ItemName = itemEntry.DisplayName or itemEntry.FruitName or itemEntry.ItemKey or "Unknown item"
                local ItemRow = New("Frame", {
                    Name = "HistoryItemRow",
                    BackgroundColor3 = Theme.Surface2,
                    BackgroundTransparency = 0.18,
                    BorderSizePixel = 0,
                    LayoutOrder = j,
                    Size = UDim2.new(1, 0, 0, ItemRowHeight),
                }, ItemsHolder)
                New("UICorner", { CornerRadius = UDim.new(0, 4) }, ItemRow)
                local ItemCategory = ResolveHistoryCategory(itemEntry.Category, ItemName, itemEntry.FruitName, itemEntry.Value)
                local IsFruitHistoryItem = ItemCategory == "HarvestedFruits"
                    or ItemCategory == "HarvestedFruit"

                local ItemLabel = ItemName
                if ItemCategory == "Seeds" then
                    ItemLabel = ItemName .. " (Seed)"
                elseif IsFruitHistoryItem then
                    ItemLabel = ItemName .. " (Fruits)"
                end

                local MutationText = IsFruitHistoryItem
                    and tostring(itemEntry.Mutation or "Normal")
                    or ""
                local ItemTextRightOffset = IsFruitHistoryItem and 190 or 112

                New("TextLabel", {
                    Text = itemEntry.Count .. "x " .. ItemLabel,
                    Font = Theme.Font,
                    TextSize = 13,
                    TextColor3 = Theme.White,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 38, 0, 0),
                    Size = UDim2.new(1, -ItemTextRightOffset, 1, 0),
                    ZIndex = 23,
                }, ItemRow)

                if IsFruitHistoryItem then
                    New("TextLabel", {
                        Name = "HistoryItemMutation",
                        Text = MutationText,
                        Font = Theme.FontBody,
                        TextSize = 11,
                        TextColor3 = Theme.TextDim,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(1, -150, 0, 0),
                        Size = UDim2.new(0, 78, 1, 0),
                        ZIndex = 23,
                    }, ItemRow)
                end

                if itemEntry.Value then
                    New("TextLabel", {
                        Name = "HistoryItemValue",
                        Text = FormatCompactSheckles(itemEntry.Value),
                        Font = Theme.Font,
                        TextSize = 12,
                        TextColor3 = Theme.Success,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(1, -68, 0, 0),
                        Size = UDim2.new(0, 60, 1, 0),
                        ZIndex = 23,
                    }, ItemRow)
                end

                -- Draw the row first; icon/model work happens separately so
                -- History never flashes as an empty panel while opening.
                task.spawn(function()
                    if ItemRow.Parent then
                        CreateItemIcon(ItemRow, ItemName, ItemCategory, 22)
                    end
                end)
            end
        end

        HeaderButton.Activated:Connect(function()
            entry.Open = not entry.Open
            RefreshHistoryList(HistorySearchBox.Text)
        end)

        yOffset += CardHeight + 6
    end

    HistoryList.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

HistorySearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RefreshHistoryList(HistorySearchBox.Text)
end)

HistoryClearButton.Activated:Connect(function()
    mailHistory = {}
    RefreshHistoryList(HistorySearchBox.Text)
    SaveMailHistory(mailHistory)
end)

local function LogMailHistory(recipient, sentQueue)
    local itemsCopy = {}
    for _, entry in ipairs(sentQueue) do
        table.insert(itemsCopy, {
            ItemKey = entry.DisplayName or entry.ItemKey,
            DisplayName = entry.DisplayName or entry.ItemKey,
            Category = entry.Category,
            Count = entry.Count,
            FruitName = entry.FruitName,
            Weight = entry.Weight,
            Value = entry.Value,
            Mutation = entry.Mutation,
        })
    end

    table.insert(mailHistory, 1, {
        Recipient = recipient,
        TimeText = os.date("%Y-%m-%d %H:%M:%S"),
        Items = itemsCopy,
        Open = false,
    })

    RefreshHistoryList(HistorySearchBox.Text)
    SaveMailHistory(mailHistory)
end

-- =========================================================
-- ITEM ICONS
-- =========================================================
-- Asset folders contain 3D models rather than ImageLabels, so icons are
-- rendered in small ViewportFrames. Missing assets simply use the themed
-- placeholder tile; this never affects the mail payload.
local IconAssetFoldersByCategory = {
    Pets = { "Pets" },
    Crates = { "Crates" },
    WateringCans = { "WateringCans" },
    Sprinklers = { "Sprinklers" },
    SeedPacks = { "SeedPacks" },
    Seeds = { "Seeds" },
    HarvestedFruits = { "Fruits" },
    HarvestedFruit = { "Fruits" },
    Tools = { "Props" },
    Trowels = { "Props" },
    Eggs = { "Eggs" },
}

-- Optional external produce icons. JPG is tried first, followed by JPEG and
-- PNG. The repository should contain files named after the fruit, for example
-- "Maple Apple.jpg". Files are cached locally when the executor supports
-- writefile/getcustomasset.
local FruitIconRemoteBaseURL = "https://raw.githubusercontent.com/ShigeSC/PIC/main/"
local FruitIconCacheFolder = "ScoopHub/FruitIcons"
local FruitIconExtensions = { ".jpg", ".jpeg", ".png" }

-- The game already publishes the exact inventory icon IDs here.  Prefer this
-- local source before any external download or 3D-model fallback so history
-- opens instantly and still works after the fruit leaves the Backpack.
local function GetLiveFruitImage(ItemName)
    local Folder = FruitImages
    if not Folder or not Folder.Parent then
        local SeedData = ReplicatedStorage.SharedModules:FindFirstChild("SeedData")
        Folder = SeedData and SeedData:FindFirstChild("FruitImages")
        FruitImages = Folder
    end
    if not Folder then
        return nil
    end

    local CleanName = tostring(ItemName or "")
        :gsub("%s*%b[]", "")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if CleanName == "" then
        return nil
    end

    local Candidates = { CleanName }
    local BaseName = CleanName:match("^Maple%s+(.+)$")
    if BaseName and BaseName ~= "" then
        table.insert(Candidates, BaseName)
    end

    for _, Candidate in ipairs(Candidates) do
        local ValueObject = Folder:FindFirstChild(Candidate)
        if ValueObject and ValueObject:IsA("StringValue") then
            local TextureId = tostring(ValueObject.Value or "")
            if TextureId ~= "" then
                return TextureId
            end
        end
    end

    return nil
end

local function EncodeURLPath(Text)
    return tostring(Text or ""):gsub("[^%w%-%._~ ]", function(Character)
        return string.format("%%%02X", string.byte(Character))
    end):gsub(" ", "%%20")
end

local function SafeIconFileName(Text)
    return tostring(Text or ""):gsub("[^%w%-%._]", "_")
end

local function GetFruitIconFromRepository(ItemName)
    local GetAsset = getcustomasset or getsynasset
    if type(GetAsset) ~= "function" or type(writefile) ~= "function" then
        return nil
    end

    local CleanName = tostring(ItemName or "")
        :gsub("%s*%[%d+%.?%d*kg%]$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if CleanName == "" then
        return nil
    end

    local NamesToTry = { CleanName }
    local BaseName = CleanName:match("^%S+%s+(.+)$")
    if BaseName and BaseName ~= "" and BaseName ~= CleanName then
        table.insert(NamesToTry, BaseName)
    end

    local RequestFunction
    pcall(function()
        if syn and type(syn.request) == "function" then
            RequestFunction = syn.request
        end
    end)
    RequestFunction = RequestFunction or http_request or request
    if type(RequestFunction) ~= "function" then
        return nil
    end

    pcall(function()
        if not isfolder or not isfolder("ScoopHub") then
            if makefolder then makefolder("ScoopHub") end
        end
        if not isfolder or not isfolder(FruitIconCacheFolder) then
            if makefolder then makefolder(FruitIconCacheFolder) end
        end
    end)

    for _, Name in ipairs(NamesToTry) do
        for _, Extension in ipairs(FruitIconExtensions) do
            local FileName = SafeIconFileName(Name) .. Extension
            local LocalPath = FruitIconCacheFolder .. "/" .. FileName
            if isfile and isfile(LocalPath) then
                local Ok, AssetPath = pcall(GetAsset, LocalPath)
                if Ok and AssetPath then
                    return AssetPath
                end
            end

            local Ok, Response = pcall(function()
                return RequestFunction({
                    Url = FruitIconRemoteBaseURL .. EncodeURLPath(Name) .. Extension,
                    Method = "GET",
                })
            end)
            local Status = Ok and Response and (Response.StatusCode or Response.Status)
            local Body = Ok and Response and (Response.Body or Response.body)
            if Ok and tonumber(Status) == 200 and type(Body) == "string" and #Body > 0 then
                local Wrote = pcall(writefile, LocalPath, Body)
                if Wrote then
                    local AssetOk, AssetPath = pcall(GetAsset, LocalPath)
                    if AssetOk and AssetPath then
                        return AssetPath
                    end
                end
            end
        end
    end

    return nil
end

local FruitIconMemoryCache = {}
local FruitIconFetchPending = {}

local function QueueFruitIconDownload(ItemName, IconTile, AddImage)
    local CacheKey = string.lower(tostring(ItemName or ""))
    if CacheKey == "" then
        return
    end

    local Cached = FruitIconMemoryCache[CacheKey]
    if Cached and IconTile.Parent and not IconTile:FindFirstChild("FruitImage") then
        AddImage(Cached)
        return
    elseif Cached == false or FruitIconFetchPending[CacheKey] then
        return
    end

    FruitIconFetchPending[CacheKey] = true
    task.spawn(function()
        local TexturePath = GetFruitIconFromRepository(ItemName)
        FruitIconMemoryCache[CacheKey] = TexturePath or false
        FruitIconFetchPending[CacheKey] = nil

        if TexturePath and IconTile.Parent and not IconTile:FindFirstChild("FruitImage") then
            AddImage(TexturePath)
        end
    end)
end

FindItemAsset = function(ItemName, Category)
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    if not Assets then
        return nil
    end

    local Candidates = { tostring(ItemName or "") }
    local WithoutWeight = tostring(ItemName or "")
        :gsub("%s*%[%d+%.?%d*kg%]$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if WithoutWeight ~= Candidates[1] and WithoutWeight ~= "" then
        table.insert(Candidates, WithoutWeight)
    end

    local WithoutSeedSuffix = WithoutWeight
        :gsub("%s*[Ss]eed%s*$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if WithoutSeedSuffix ~= Candidates[1] and WithoutSeedSuffix ~= "" then
        table.insert(Candidates, WithoutSeedSuffix)
    end

    -- Harvested fruit tools can include a mutation prefix in their display
    -- name (for example "Maple Apple"), while the matching model in
    -- ReplicatedStorage.Assets.Fruits is stored under its base name ("Apple").
    -- Keep the full name first, then try the base name only for fruit icons so
    -- multi-word assets in other categories are not accidentally shortened.
    if Category == "HarvestedFruits" or Category == "Seeds" then
        local BaseFruitName = WithoutSeedSuffix:match("^%S+%s+(.+)$")
        if BaseFruitName and BaseFruitName ~= "" then
            table.insert(Candidates, BaseFruitName)
        end
    end

    local FolderNames = IconAssetFoldersByCategory[Category] or {}
    for _, FolderName in ipairs(FolderNames) do
        local Folder = Assets:FindFirstChild(FolderName)
        if Folder then
            for _, Candidate in ipairs(Candidates) do
                local Asset = Folder:FindFirstChild(Candidate)
                if Asset then
                    return Asset
                end

                -- Some game assets omit spaces or use a slightly different
                -- casing from the inventory display name. Compare a compact
                -- normalized form as a fallback (exact names still win).
                local NormalizedCandidate = string.lower(Candidate):gsub("[^%w]", "")
                if NormalizedCandidate ~= "" then
                    for _, PossibleAsset in ipairs(Folder:GetChildren()) do
                        local NormalizedAsset = string.lower(PossibleAsset.Name):gsub("[^%w]", "")
                        if NormalizedAsset == NormalizedCandidate then
                            return PossibleAsset
                        end
                    end
                end

                -- Some fruit assets are nested inside a variant folder rather
                -- than being direct children of Assets.Fruits.
                for _, PossibleAsset in ipairs(Folder:GetDescendants()) do
                    if PossibleAsset.Name == Candidate then
                        return PossibleAsset
                    end
                end

                if NormalizedCandidate ~= "" then
                    for _, PossibleAsset in ipairs(Folder:GetDescendants()) do
                        local NormalizedAsset = string.lower(PossibleAsset.Name):gsub("[^%w]", "")
                        if NormalizedAsset == NormalizedCandidate then
                            return PossibleAsset
                        end
                    end
                end
            end
        end
    end

    return nil
end

CreateItemIcon = function(Parent, ItemName, Category, ZIndex)
    local IconTile = New("Frame", {
        Name = "ItemIcon",
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 6, 0.5, -14),
        Size = UDim2.new(0, 28, 0, 28),
        ZIndex = ZIndex or 22,
    }, Parent)

    local function AddImage(TextureId)
        if not TextureId or tostring(TextureId) == "" then
            return false
        end
        New("ImageLabel", {
            Name = "FruitImage",
            Image = tostring(TextureId),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScaleType = Enum.ScaleType.Fit,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            ZIndex = (ZIndex or 22) + 1,
        }, IconTile)
        return true
    end

    local LiveTexture = GetLiveFruitImage(ItemName)
    if LiveTexture and AddImage(LiveTexture) then
        return IconTile
    end

    -- Download repository produce images in the background. This prevents
    -- opening/rebuilding Mail History from blocking on HTTP requests.
    if Category == "HarvestedFruits" or Category == "HarvestedFruit" then
        QueueFruitIconDownload(ItemName, IconTile, AddImage)
    end

    -- The live harvested-fruit tool uses the exact inventory icon. Use it as
    -- a fallback when the corresponding ReplicatedStorage model is absent.
    if Category == "HarvestedFruits" or Category == "HarvestedFruit" then
        local Wanted = string.lower(tostring(ItemName or "")):gsub("%s*%[%d+%.?%d*kg%]$", "")
        local WantedCompact = Wanted:gsub("[^%w]", "")
        local Containers = { Backpack, LocalPlayer.Character }
        for _, Container in ipairs(Containers) do
            if Container then
                for _, Tool in ipairs(Container:GetChildren()) do
                    if Tool:IsA("Tool") then
                        local FruitName = tostring(Tool:GetAttribute("FruitName") or Tool.Name)
                        local FruitCompact = string.lower(FruitName):gsub("[^%w]", "")
                        if FruitCompact == WantedCompact or FruitCompact:find(WantedCompact, 1, true) then
                            local TextureId = Tool.TextureId
                            if AddImage(TextureId) then
                                return IconTile
                            end
                        end
                    end
                end
            end
        end
    end

    local Asset = FindItemAsset(ItemName, Category)
    if not Asset then
        return IconTile
    end

    -- Fruit assets can contain both a Seed and Produce model. History rows
    -- must render the Produce model, not the planting seed model.
    if Category == "HarvestedFruits" or Category == "HarvestedFruit" then
        local ProduceAsset = Asset:FindFirstChild("Produce", true)
        if ProduceAsset then
            Asset = ProduceAsset
        end
    end

    -- Fruit models contain the same Decal/texture used by the inventory.
    -- Prefer that image for harvested-fruit history rows; it is more reliable
    -- than a tiny 3D viewport for models made mostly from decal faces.
    if Category == "HarvestedFruits" or Category == "HarvestedFruit" then
        local TextureId
        pcall(function()
            for _, Descendant in ipairs(Asset:GetDescendants()) do
                if (Descendant:IsA("Decal") or Descendant:IsA("Texture"))
                    and tostring(Descendant.Texture or "") ~= "" then
                    TextureId = Descendant.Texture
                    break
                elseif Descendant:IsA("MeshPart") and tostring(Descendant.TextureID or "") ~= "" then
                    TextureId = Descendant.TextureID
                    break
                end
            end
        end)

        if TextureId and AddImage(TextureId) then
            return IconTile
        end
    end

    local Viewport = New("ViewportFrame", {
        Name = "Viewport",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        Ambient = Color3.fromRGB(190, 190, 200),
        LightColor = Color3.fromRGB(255, 235, 235),
        LightDirection = Vector3.new(-1, -1, -1),
        ZIndex = (ZIndex or 22) + 1,
    }, IconTile)

    local WorldModel = Instance.new("WorldModel")
    WorldModel.Name = "IconWorld"
    WorldModel.Parent = Viewport

    local Holder = Instance.new("Model")
    Holder.Name = "IconModel"
    Holder.Parent = WorldModel

    local CloneOk, Clone = pcall(function()
        return Asset:Clone()
    end)
    if not CloneOk or not Clone then
        return IconTile
    end
    Clone.Parent = Holder

    for _, Descendant in ipairs(Clone:GetDescendants()) do
        if Descendant:IsA("BasePart") then
            Descendant.Anchored = true
            Descendant.CanCollide = false
        elseif Descendant:IsA("Script")
            or Descendant:IsA("LocalScript")
            or Descendant:IsA("ModuleScript") then
            Descendant:Destroy()
        end
    end

    local Camera = Instance.new("Camera")
    Camera.Name = "IconCamera"
    Camera.FieldOfView = 40
    Camera.Parent = Viewport
    Viewport.CurrentCamera = Camera

    local BoxOk, BoxCFrame, BoxSize = pcall(function()
        return Holder:GetBoundingBox()
    end)
    if BoxOk and BoxCFrame and BoxSize then
        local Focus = BoxCFrame.Position
        local Largest = math.max(BoxSize.X, BoxSize.Y, BoxSize.Z, 0.1)
        Camera.CFrame = CFrame.new(
            Focus + Vector3.new(Largest * 1.15, Largest * 0.55, Largest * 1.15),
            Focus
        )
    else
        Camera.CFrame = CFrame.new(Vector3.new(3, 2, 3), Vector3.zero)
    end

    return IconTile
end

local function UpdateSelectedItemButton(item)
    if SelectedItemIcon then
        SelectedItemIcon:Destroy()
        SelectedItemIcon = nil
    end

    if not item then
        SelectedItemLabel.Text = "Select item"
        SelectedItemCount.Text = ""
        return
    end

    SelectedItemLabel.Text = item.Name
    SelectedItemCount.Text = "x" .. tostring(item.Count)
    SelectedItemIcon = CreateItemIcon(SelectItemButton, item.Name, item.Category, 22)
    SelectedItemIcon.Size = UDim2.new(0, 22, 0, 22)
    SelectedItemIcon.Position = UDim2.new(0, 6, 0.5, -11)
    SelectedItemIcon.ZIndex = 22
end

ResolveHistoryCategory = function(StoredCategory, ItemName, StoredFruitName, StoredValue)
    -- Entries without a stored category can still be recognized from a
    -- mutation name whose base model exists in ReplicatedStorage.Assets.Fruits.
    local HistoryName = tostring(ItemName or "")
        :gsub("%s*%[%d+%.?%d*kg%]$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    local BaseFruitName = HistoryName:match("^%S+%s+(.+)$")
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local FruitsFolder = Assets and Assets:FindFirstChild("Fruits")
    local IsKnownFruit = FruitsFolder and BaseFruitName and FruitsFolder:FindFirstChild(BaseFruitName)

    -- Fruit history entries carry FruitName; use that explicit marker rather
    -- than guessing from a shared name such as "Maple Apple". Seed entries
    -- must remain in the Seeds folder even when a matching fruit model exists.
    if tostring(StoredFruitName or "") ~= "" or StoredValue ~= nil then
        return "HarvestedFruits"
    end

    if StoredCategory and IconAssetFoldersByCategory[StoredCategory] then
        return StoredCategory
    end

    if IsKnownFruit then
        return "HarvestedFruits"
    end

    local KnownCategory = ReplicatedAssetItems[ItemName]
    if KnownCategory then
        return KnownCategory
    end

    if PetNames[ItemName] then
        return "Pets"
    end

    local LowerName = string.lower(tostring(ItemName or ""))
    if LowerName:find("crate", 1, true) then
        return "Crates"
    elseif LowerName:find("sprinkler", 1, true) then
        return "Sprinklers"
    elseif LowerName:find("watering", 1, true) then
        return "WateringCans"
    elseif LowerName:find("pack", 1, true) then
        return "SeedPacks"
    elseif LowerName:find("egg", 1, true) then
        return "Eggs"
    elseif PlantNames[ItemName] then
        return "Seeds"
    end

    return "Tools"
end

CloseItemDropdown = function()
    ItemDropdown.Visible = false
end

local function BuildItemDropdown(FilterText)
    for _, child in ipairs(ItemDropdownScroll:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local Query = string.lower(tostring(FilterText or ""))
    local Filtered = {}
    for _, item in ipairs(inventoryCache) do
        if Query == "" or string.find(string.lower(item.Name), Query, 1, true) then
            table.insert(Filtered, item)
        end
    end

    if #Filtered == 0 then
        New("TextLabel", {
            Text = (#inventoryCache == 0) and "No mailable items found" or "No matches",
            Font = Theme.FontBody,
            TextSize = 14,
            TextColor3 = Theme.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
        }, ItemDropdownScroll)
        ItemDropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 30)
        ResizeItemDropdown(1)
        return
    end

    for i, item in ipairs(Filtered) do
        local Row = New("TextButton", {
            Name = "ItemOption",
            Text = "",
            Font = Theme.Font,
            TextSize = 15,
            TextColor3 = Theme.White,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = Theme.Surface2,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 32),
            LayoutOrder = i,
            ZIndex = 21,
            AutoButtonColor = false,
        }, ItemDropdownScroll)
        New("UICorner", { CornerRadius = UDim.new(0, 4) }, Row)
        -- Reserve one fixed-width icon column.  This keeps item names and
        -- quantities aligned even when a model is visually narrow (Bamboo).
        local DropdownIcon = CreateItemIcon(Row, item.Name, item.Category, 22)
        DropdownIcon.Position = UDim2.new(0, 8, 0.5, -12)
        DropdownIcon.Size = UDim2.new(0, 24, 0, 24)
        New("TextLabel", {
            Name = "ItemText",
            Text = item.Name,
            Font = Theme.FontBody,
            TextSize = 13,
            TextColor3 = Theme.White,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 40, 0, 0),
            Size = UDim2.new(1, -96, 1, 0),
            ZIndex = 23,
        }, Row)
        New("TextLabel", {
            Name = "ItemCount",
            Text = "x" .. item.Count,
            Font = Theme.Font,
            TextSize = 12,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -50, 0, 0),
            Size = UDim2.new(0, 42, 1, 0),
            ZIndex = 23,
        }, Row)

        Row.MouseEnter:Connect(function()
            Row.BackgroundColor3 = Theme.RedDark
        end)
        Row.MouseLeave:Connect(function()
            Row.BackgroundColor3 = Theme.Surface2
        end)

        Row.Activated:Connect(function()
            selectedItem = item
            UpdateSelectedItemButton(item)
            AmountBox.Text = "1"
            CloseItemDropdown()
        end)
    end

    ItemDropdownScroll.CanvasSize = UDim2.new(0, 0, 0, #Filtered * 34)
    ResizeItemDropdown(#Filtered)
end

ItemSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    BuildItemDropdown(ItemSearchBox.Text)
end)

Theme.RefreshItemOptions = function()
    inventoryCache = GetLiveInventory()

    -- Reset the selection so Refresh actually behaves like a refresh
    -- instead of leaving a stale "ItemName (xN avail.)" from before.
    selectedItem = nil
    UpdateSelectedItemButton(nil)
    AmountBox.Text = ""

    BuildItemDropdown(ItemSearchBox.Text)
    RefreshStatusLabel.Text = "Refreshed (" .. #inventoryCache .. " items)."
end

SelectItemButton.Activated:Connect(function()
    ItemDropdown.Visible = not ItemDropdown.Visible
    if ItemDropdown.Visible then
        UpdateItemDropdownPosition()
        ItemSearchBox.Text = ""
        BuildItemDropdown("")
    end
end)

RefreshItemButton.Activated:Connect(function()
    Theme.RefreshItemOptions()
end)

AddButton.Activated:Connect(function()
    if not selectedItem then
        StatusLabel.TextColor3 = Theme.Text
        StatusLabel.Text = "Pick an item first!"
        return
    end

    local amount = tonumber(AmountBox.Text) or 1
    if amount > selectedItem.Count then
        amount = selectedItem.Count
    end
    if amount < 1 then
        amount = 1
    end

    if selectedItem.Category == "Pets" and selectedItem.ItemKeys then
        -- The picker groups same-name pets, but each pet still needs its own
        -- UUID in the actual batch. Do not queue a UUID twice.
        local usedPetIds = {}
        for _, queuedEntry in ipairs(queue) do
            if queuedEntry.PetIds then
                for _, petId in ipairs(queuedEntry.PetIds) do
                    usedPetIds[petId] = true
                end
            end
        end

        local selectedIds = {}
        for _, petId in ipairs(selectedItem.ItemKeys) do
            if not usedPetIds[petId] then
                table.insert(selectedIds, petId)
                if #selectedIds >= amount then break end
            end
        end
        amount = #selectedIds
        if amount == 0 then
            StatusLabel.TextColor3 = Theme.Text
            StatusLabel.Text = "All available " .. selectedItem.Name .. " are already queued."
            return
        end

        table.insert(queue, {
            Category = "Pets",
            ItemKey = selectedIds[1],
            PetIds = selectedIds,
            DisplayName = selectedItem.Name,
            Count = amount,
        })
    else
        table.insert(queue, {
            Category = selectedItem.Category,
            ItemKey = selectedItem.ItemKey or selectedItem.Name,
            DisplayName = selectedItem.Name,
            Count = amount,
        })
    end

    StatusLabel.TextColor3 = Theme.Success
    StatusLabel.Text = string.format("Added %dx %s", amount, selectedItem.Name)
    AmountBox.Text = ""
    Theme.RefreshQueueDisplay()
end)

Theme.StartNormalMailSend = function()
    local activeJob = Theme.ActivePendingMailDelivery
    local usingPendingQueue = activeJob ~= nil
    local sendingQueue = usingPendingQueue and activeJob.Items or queue
    local user = usingPendingQueue and activeJob.Recipient or RecipientBox.Text
    if user == "" then
        StatusLabel.TextColor3 = Theme.Text
        StatusLabel.Text = "Enter recipient username!"
        return
    end
    if #sendingQueue == 0 then
        StatusLabel.TextColor3 = Theme.Text
        StatusLabel.Text = "Queue is empty - add an item first!"
        return
    end

    if Theme.MailSendInFlight then
        StatusLabel.TextColor3 = Theme.TextDim
        StatusLabel.Text = "A delivery is already being verified."
        return
    end

    local cooldownRemaining = math.ceil((Theme.MailCooldownEndTime or 0) - os.clock())
    if cooldownRemaining > 0 then
        -- Move this delivery out of the editable Mail queue immediately. It
        -- remains visible and cancellable in PENDING while the cooldown runs.
        if usingPendingQueue then return end
        Theme.PendingMailDeliveries = Theme.PendingMailDeliveries or {}
        table.insert(Theme.PendingMailDeliveries, {
            Recipient = user,
            Items = queue,
        })
        queue = {}
        Theme.RefreshQueueDisplay()
        RecipientBox.Text = ""
        selectedItem = nil
        UpdateSelectedItemButton(nil)
        AmountBox.Text = ""
        QueuedSendLabel.Text = 'Queued: "' .. user .. '"'
        StatusLabel.TextColor3 = Theme.Success
        StatusLabel.Text = "Cooldown: " .. cooldownRemaining .. "s"
        if Theme.RefreshPendingQueuePage then Theme.RefreshPendingQueuePage() end
        return
    end

    if user == "" then
        StatusLabel.TextColor3 = Theme.Text
        StatusLabel.Text = "Enter recipient username!"
        return
    end
    if #sendingQueue == 0 then
        StatusLabel.TextColor3 = Theme.Text
        StatusLabel.Text = "Queue is empty ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â add an item first!"
        return
    end

    QueuedSendLabel.Text = ""
    Theme.MailSendInFlight = true
    StatusLabel.TextColor3 = Theme.TextDim
    StatusLabel.Text = "Sending..."

    task.spawn(function()
        local ok, targetId = pcall(function()
            return Players:GetUserIdFromNameAsync(user)
        end)
        if not ok or not targetId then
            StatusLabel.TextColor3 = Theme.Text
            StatusLabel.Text = "Player not found"
            Theme.MailSendInFlight = false
            return
        end

        local MAX_PER_ENTRY = 9999
        local finalBatch = {}

        for _, entry in ipairs(sendingQueue) do
            if entry.Category == "Pets" and entry.PetIds then
                for _, petId in ipairs(entry.PetIds) do
                    table.insert(finalBatch, {
                        Category = "Pets",
                        ItemKey = petId,
                        Count = 1,
                    })
                end
            else
                local remaining = entry.Count
                while remaining > 0 do
                    local chunk = math.min(remaining, MAX_PER_ENTRY)
                    table.insert(finalBatch, {
                        Category = entry.Category,
                        ItemKey = entry.ItemKey,
                        Count = chunk
                    })
                    remaining = remaining - chunk
                end
            end
        end

        local queuedSnapshot = Theme.MailVerify.SnapshotMailQueue(sendingQueue)
        local requestSent, requestError = pcall(function()
            -- Send exactly once. A second FireServer call could duplicate an
            -- accepted request and makes local verification unreliable.
            Networking.Mailbox.SendBatch:Fire(targetId, finalBatch, "GUI Send")
        end)

        if not requestSent then
            StatusLabel.TextColor3 = Theme.Text
            StatusLabel.Text = "Send request failed"
            warn("[Mail] SendBatch failed:", requestError)
            Theme.MailSendInFlight = false
            return
        end

        local outcome = Theme.MailVerify.WaitForMailDeduction(queuedSnapshot, 4)
        if outcome.FullyConfirmed then
            local cooldownSeconds = 10
            Theme.MailCooldownEndTime = os.clock() + cooldownSeconds
            Theme.MailCooldownToken = (Theme.MailCooldownToken or 0) + 1
            local cooldownToken = Theme.MailCooldownToken

            StatusLabel.TextColor3 = Theme.Success
            StatusLabel.Text = 'Sent successfully to "' .. user .. '"!\nCooldown: ' .. cooldownSeconds .. "s"
            LogMailHistory(user, outcome.Confirmed)
            SendMailWebhook(user, outcome.Confirmed, "Mail")
            if usingPendingQueue then
                for jobIndex, job in ipairs(Theme.PendingMailDeliveries or {}) do
                    if job == activeJob then
                        table.remove(Theme.PendingMailDeliveries, jobIndex)
                        break
                    end
                end
                Theme.ActivePendingMailDelivery = nil
                if Theme.PendingAvatarCache then
                    Theme.PendingAvatarCache[user] = nil
                end
            else
                queue = {}
                -- The recipient panel listens for text changes and restores
                -- its empty avatar state automatically.
                RecipientBox.Text = ""
            end
            Theme.RefreshQueueDisplay()
            if Theme.RefreshPendingQueuePage then Theme.RefreshPendingQueuePage() end
            task.wait(0.2)
            Theme.RefreshItemOptions()

            task.spawn(function()
                while Theme.MailCooldownToken == cooldownToken do
                    local secondsLeft = math.max(0, math.ceil((Theme.MailCooldownEndTime or 0) - os.clock()))
                    if secondsLeft <= 0 then break end
                    StatusLabel.TextColor3 = Theme.Success
                    StatusLabel.Text = 'Sent successfully to "' .. user .. '"!\nCooldown: ' .. secondsLeft .. "s"
                    task.wait(0.2)
                end
                if Theme.MailCooldownToken == cooldownToken then
                    -- If SEND was clicked during the cooldown, use the same
                    -- confirmation path now rather than asking the player to
                    -- click again.
                    if Theme.PendingMailDeliveries and #Theme.PendingMailDeliveries > 0 then
                        Theme.ActivePendingMailDelivery = Theme.PendingMailDeliveries[1]
                        QueuedSendLabel.Text = ""
                        Theme.StartNormalMailSend()
                    else
                        StatusLabel.Text = ""
                        QueuedSendLabel.Text = ""
                    end
                end
            end)
        elseif outcome.TotalConfirmed > 0 then
            -- Preserve only the entries that are still in the inventory, so a
            -- retry cannot send items that already left the Backpack.
            if usingPendingQueue then
                activeJob.Items = outcome.Remaining
                Theme.ActivePendingMailDelivery = nil
            else
                queue = outcome.Remaining
            end
            Theme.RefreshQueueDisplay()
            if Theme.RefreshPendingQueuePage then Theme.RefreshPendingQueuePage() end
            StatusLabel.TextColor3 = Theme.Text
            StatusLabel.Text = string.format(
                "Only %d/%d item(s) were deducted. Remaining items stayed queued.",
                outcome.TotalConfirmed,
                queuedSnapshot.Expected
            )
            LogMailHistory(user, outcome.Confirmed)
            SendMailWebhook(user, outcome.Confirmed, "Mail")
            Theme.RefreshItemOptions()
        else
            StatusLabel.TextColor3 = Theme.Text
            StatusLabel.Text = "Failed: inventory was not deducted. Queue kept."
        end
        Theme.MailSendInFlight = false
    end)
end

SendButton.Activated:Connect(Theme.StartNormalMailSend)

-- Refresh the Pending tab only while it is visible, so its cooldown/status
-- is live without repeatedly rebuilding hidden UI or fetching avatars.
task.spawn(function()
    while ScreenGui.Parent do
        if Theme.PendingPage.Visible and Theme.RefreshPendingQueuePage then
            Theme.RefreshPendingQueuePage()
        end
        task.wait(1)
    end
end)

-- Close the dropdown when clicking elsewhere.
-- Uses GetGuiObjectsAtPosition (what's actually rendered at that pixel)
-- instead of manual AABB math, so clicks on the last row near the clipped
-- edge always register correctly.
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if not ItemDropdown.Visible then
        return
    end

    task.defer(function()
        local mousePos = UserInputService:GetMouseLocation()
        local hitObjects = GuiService:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
        local clickedInside = false
        for _, obj in ipairs(hitObjects) do
            if obj == ItemDropdown or obj:IsDescendantOf(ItemDropdown)
                or obj == SelectItemButton then
                clickedInside = true
                break
            end
        end

        if not clickedInside then
            CloseItemDropdown()
        end
    end)
end)

-- =========================================================
-- MAIL FRUITS TAB LOGIC
-- =========================================================
local harvestedCache = {}
local isSendingAll = false
local cooldownEndTime = 0

local function UpdateFruitSelectionSummary()
    local selectedCount = 0
    local totalValue = 0

    for _, fruit in ipairs(harvestedCache) do
        if fruit.Selected then
            selectedCount += 1
            totalValue += tonumber(fruit.Value) or 0
        end
    end

    FruitCounterLabel.Text = selectedCount .. "/20"
    FruitTotalValueLabel.Text = "Total: " .. FormatCompactSheckles(totalValue)
    OpenFruitPickerBtn.Text = "Choose fruits (" .. selectedCount .. "/20)"
end

Theme.RefreshFruitsQueue = function()
    for _, child in ipairs(FruitsQueueList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local totalValue = 0
    for _, entry in ipairs(Theme.FruitsQueue) do
        totalValue += entry.Value
    end

    FruitsQueueHeader.Text = string.format("Queue \u{2022} %d items", #Theme.FruitsQueue)
    FruitsQueueTotalLabel.Text = "TOTAL VALUE: " .. FormatCompactSheckles(totalValue)
    FruitsQueueList.CanvasSize = UDim2.new(0, 0, 0, #Theme.FruitsQueue * 34)

    local emptyLabel = FruitsQueueList:FindFirstChild("QueueEmpty")
    if emptyLabel then
        emptyLabel.Visible = (#Theme.FruitsQueue == 0)
    end

    OpenFruitPickerBtn.Text = "Choose fruits (" .. #Theme.FruitsQueue .. "/20)"

    for i, entry in ipairs(Theme.FruitsQueue) do
        local row = New("Frame", {
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = i,
        }, FruitsQueueList)
        New("UICorner", { CornerRadius = UDim.new(0, 5) }, row)

        New("TextLabel", {
            Text = entry.Name .. "  (" .. FormatCompactSheckles(entry.Value) .. ")",
            Font = Theme.Font,
            TextSize = 13,
            TextColor3 = Theme.White,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -30, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)

        local remove = New("TextButton", {
            Text = "\u{00D7}",
            Font = Theme.Font,
            TextSize = 16,
            TextColor3 = Theme.Text,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.new(0, 22, 0, 22),
        }, row)

        remove.Activated:Connect(function()
            table.remove(Theme.FruitsQueue, i)
            Theme.RefreshFruitsQueue()
        end)
    end

    if Theme.RefreshPendingQueuePage then
        Theme.RefreshPendingQueuePage()
    end
end

FruitsClearQueueBtn.Activated:Connect(function()
    Theme.FruitsQueue = {}
    Theme.RefreshFruitsQueue()
    FruitsSuccessLabel.Text = ""
    FruitsCooldownLabel.Text = ""
end)

local function RefreshFullFruitList()
    for _, child in ipairs(FruitFullList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    harvestedCache = GetHarvestedFruits()

    local selectedIds = {}
    for _, entry in ipairs(Theme.FruitsQueue) do
        selectedIds[entry.Id] = true
    end

    local selectedCount = 0

    for i, fruit in ipairs(harvestedCache) do
        if selectedIds[fruit.Id] then
            fruit.Selected = true
            selectedCount += 1
        end

        local row = New("TextButton", {
            Text = "",
            BackgroundColor3 = fruit.Selected and Color3.fromRGB(37, 92, 66) or Theme.Surface2,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 34),
            LayoutOrder = i,
            AutoButtonColor = false,
        }, FruitFullList)
        New("UICorner", { CornerRadius = UDim.new(0, 6) }, row)

        New("TextLabel", {
            Text = fruit.Name,
            Font = Theme.Font,
            TextSize = 14,
            TextColor3 = Theme.White,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 0),
            Size = UDim2.new(0.66, -12, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)

        New("TextLabel", {
            Text = FormatFruitPriceMultiplier(fruit.Multiplier),
            Font = Theme.Font,
            TextSize = 12,
            TextColor3 = Theme.Success,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.66, 0, 0, 0),
            Size = UDim2.new(0.10, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, row)

        New("TextLabel", {
            Text = FormatCompactSheckles(fruit.Value, false),
            Font = Theme.Font,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(246, 196, 104),
            BackgroundTransparency = 1,
            Position = UDim2.new(0.78, 0, 0, 0),
            Size = UDim2.new(0.22, -12, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, row)

        row.Activated:Connect(function()
            if fruit.Selected then
                fruit.Selected = false
                row.BackgroundColor3 = Theme.Surface2
            else
                local count = 0
                for _, f in ipairs(harvestedCache) do
                    if f.Selected then count += 1 end
                end
                if count >= 20 then return end
                fruit.Selected = true
                row.BackgroundColor3 = Color3.fromRGB(37, 92, 66)
            end

            UpdateFruitSelectionSummary()
        end)
    end

    task.defer(UpdateFruitFullListCanvas)
    UpdateFruitSelectionSummary()
end

-- Apply newly scanned seller quotes without rebuilding the picker until the
-- scan is complete. Existing queue entries keep their selection and receive
-- the refreshed value by fruit ID.
FruitValueRefreshCallback = function()
    local selectedById = {}
    for _, fruit in ipairs(harvestedCache or {}) do
        if fruit.Selected then
            selectedById[tostring(fruit.Id)] = true
        end
    end

    local latest = GetHarvestedFruits()
    local latestById = {}
    for _, fruit in ipairs(latest) do
        fruit.Selected = selectedById[tostring(fruit.Id)] == true
        latestById[tostring(fruit.Id)] = fruit
    end

    for _, entry in ipairs(Theme.FruitsQueue) do
        local fresh = latestById[tostring(entry.Id)]
        if fresh then
            entry.Value = fresh.Value
            entry.Mutation = fresh.Mutation
            entry.Weight = fresh.Weight
        end
    end

    harvestedCache = latest
    Theme.RefreshFruitsQueue()
    if FruitSelectWindow.Visible then
        RefreshFullFruitList()
    end
end

OpenFruitPickerBtn.Activated:Connect(function()
    FruitSelectWindow.Visible = true
    RefreshFullFruitList()
end)

FruitDoneBtn.Activated:Connect(function()
    Theme.FruitsQueue = {}
    for _, fruit in ipairs(harvestedCache) do
        if fruit.Selected then
            table.insert(Theme.FruitsQueue, {
                Name = fruit.Name,
                FruitName = fruit.FruitName,
                Weight = fruit.Weight,
                Id = fruit.Id,
                Value = fruit.Value,
                Mutation = fruit.Mutation,
            })
        end
    end
    FruitSelectWindow.Visible = false
    Theme.RefreshFruitsQueue()
end)

FruitsSendButton.Activated:Connect(function()
    if isSendingAll then return end

    local remaining = math.ceil(cooldownEndTime - tick())
    if remaining > 0 then
        FruitsSuccessLabel.Text = ""
        FruitsCooldownLabel.TextColor3 = Theme.Text
        FruitsCooldownLabel.Text = "Wait " .. remaining .. "s..."
        return
    end

    local user = FruitsRecipientBox.Text
    if user == "" then
        FruitsSuccessLabel.Text = ""
        FruitsCooldownLabel.TextColor3 = Theme.Text
        FruitsCooldownLabel.Text = "Enter recipient!"
        return
    end
    if #Theme.FruitsQueue == 0 then
        FruitsSuccessLabel.Text = ""
        FruitsCooldownLabel.TextColor3 = Theme.Text
        FruitsCooldownLabel.Text = "Queue is empty!"
        return
    end

    isSendingAll = true
    FruitsSuccessLabel.Text = ""
    FruitsCooldownLabel.TextColor3 = Theme.TextDim
    FruitsCooldownLabel.Text = "Sending..."

    task.spawn(function()
        local ok, targetId = pcall(function()
            return Players:GetUserIdFromNameAsync(user)
        end)

        if not ok or not targetId then
            FruitsSuccessLabel.Text = ""
            FruitsCooldownLabel.TextColor3 = Theme.Text
            FruitsCooldownLabel.Text = "Player not found"
            isSendingAll = false
            return
        end

        local total = #Theme.FruitsQueue
        local sent = 0
        local batchSize = 20
        local cooldown = 10
        local historyItems = {}

        while #Theme.FruitsQueue > 0 do
            local batch = {}
            local historyBatch = {}
            local sourceBatch = {}
            local currentBatchSize = math.min(batchSize, #Theme.FruitsQueue)

            for i = 1, currentBatchSize do
                local fruit = Theme.FruitsQueue[i]
                table.insert(sourceBatch, fruit)
                -- Resolve Steven's live offer immediately before the fruit is
                -- removed from the Backpack.  This keeps history/webhooks
                -- tied to the exact item that was actually mailed.
                local sellerValue, usedLiveOffer = GetCurrentSellerValue(fruit.Id, fruit.Value)
                fruit.Value = sellerValue
                print(string.format(
                    "[Mail Fruits] %s [%s] -> %d Sheckles (%s)",
                    tostring(fruit.FruitName or fruit.Name or "Unknown"),
                    tostring(fruit.Mutation or "Normal"),
                    sellerValue,
                    usedLiveOffer and "CurrentSellValue" or "SellFlags fallback"
                ))
                table.insert(batch, {
                    Category = "HarvestedFruits",
                    ItemKey = fruit.Id,
                    Count = 1
                })
                table.insert(historyBatch, {
                    Category = "HarvestedFruits",
                    ItemKey = fruit.Id,
                    DisplayName = fruit.FruitName or fruit.Name,
                    FruitName = fruit.FruitName,
                    Weight = fruit.Weight,
                    Value = sellerValue,
                    Mutation = fruit.Mutation,
                    Count = 1,
                })
            end

            -- Capture presence before the request. Otherwise a very fast
            -- server response could look like a pre-existing missing fruit.
            local fruitSnapshot = Theme.MailVerify.SnapshotFruitIds(sourceBatch)
            local requestSent, requestError = pcall(function()
                Networking.Mailbox.SendBatch:Fire(targetId, batch, "Mail Fruits")
            end)
            if not requestSent then
                FruitsSuccessLabel.Text = ""
                FruitsCooldownLabel.TextColor3 = Theme.Text
                FruitsCooldownLabel.Text = "Send request failed. Queue kept."
                warn("[Mail Fruits] SendBatch failed:", requestError)
                break
            end

            local confirmedFruits, remainingFruits = Theme.MailVerify.WaitForFruitDeduction(fruitSnapshot, 4)
            if #confirmedFruits == 0 then
                FruitsSuccessLabel.Text = ""
                FruitsCooldownLabel.TextColor3 = Theme.Text
                FruitsCooldownLabel.Text = "Not confirmed: fruits were not deducted. Queue kept."
                break
            end

            local confirmedIds = {}
            for _, fruit in ipairs(confirmedFruits) do
                confirmedIds[tostring(fruit.Id)] = true
            end
            local confirmedHistory = {}
            for _, item in ipairs(historyBatch) do
                if confirmedIds[tostring(item.ItemKey)] then
                    table.insert(confirmedHistory, item)
                end
            end

            -- Remove only confirmed fruit IDs. A partial server result never
            -- erases items from the queue that still exist in the Backpack.
            local newQueue = {}
            for _, fruit in ipairs(Theme.FruitsQueue) do
                if not confirmedIds[tostring(fruit.Id)] then
                    table.insert(newQueue, fruit)
                end
            end
            Theme.FruitsQueue = newQueue

            sent += #confirmedFruits
            Theme.RefreshFruitsQueue()

            for _, item in ipairs(confirmedHistory) do
                table.insert(historyItems, item)
            end
            SendMailWebhook(user, confirmedHistory, "Mail Fruits")

            local fruitWord = sent == 1 and "fruit" or "fruits"
            if #remainingFruits > 0 then
                FruitsSuccessLabel.TextColor3 = Theme.Text
                FruitsSuccessLabel.Text = string.format(
                    "Only %d/%d fruits were deducted. Remaining fruits stayed queued.",
                    sent,
                    total
                )
                FruitsCooldownLabel.Text = ""
                break
            end

            FruitsSuccessLabel.Text = "Successfully sent " .. sent .. "/" .. total .. " " .. fruitWord .. " to " .. user .. "!"

            -- Cooldown
            cooldownEndTime = tick() + cooldown
            for sec = cooldown, 1, -1 do
                FruitsCooldownLabel.TextColor3 = Theme.Text
                FruitsCooldownLabel.Text = "Cooldown " .. sec .. "s..."
                task.wait(1)
            end
            FruitsCooldownLabel.Text = ""
        end
        if #historyItems > 0 then
            LogMailHistory(user, historyItems)
        end

        -- Keep a failed or partial-confirmation warning visible. Clearing it
        -- here made an unverified transfer look successful or disappear.
        if #Theme.FruitsQueue == 0 then
            FruitsSuccessLabel.Text = ""
            OpenFruitPickerBtn.Text = "Choose fruits (0/20)"
            FruitsRecipientBox.Text = ""
        end
        isSendingAll = false
    end)
end)

FruitsSendAllButton.Activated:Connect(function()
    local allFruits = GetHarvestedFruits()

    if #allFruits == 0 then
        FruitsSuccessLabel.Text = ""
        FruitsCooldownLabel.TextColor3 = Theme.Text
        FruitsCooldownLabel.Text = "No harvested fruits found!"
        return
    end

    Theme.FruitsQueue = {}
    for _, fruit in ipairs(allFruits) do
        table.insert(Theme.FruitsQueue, {
            Name = fruit.Name,
            FruitName = fruit.FruitName,
            Weight = fruit.Weight,
            Id = fruit.Id,
            Value = fruit.Value,
            Mutation = fruit.Mutation
        })
    end

    Theme.RefreshFruitsQueue()
    FruitsSuccessLabel.TextColor3 = Theme.Success
    FruitsSuccessLabel.Text = "Added " .. #allFruits .. " fruits to queue"
    FruitsCooldownLabel.Text = ""
    OpenFruitPickerBtn.Text = "Choose fruits (" .. #allFruits .. "/20)"
end)

-- =========================================================
-- Minimize / Close
-- =========================================================
local minimized = false
MinButton.Activated:Connect(function()
    minimized = not minimized
    Body.Visible = not minimized
    local size = minimized and UDim2.new(0, 580, 0, 38) or UDim2.new(0, 580, 0, 420)
    SafeTween(Main, TweenInfo.new(0.2), { Size = size })
    SafeTween(DropShadowHolder, TweenInfo.new(0.2), { Size = size })
    SafeTween(DropShadow, TweenInfo.new(0.2), { Size = size })
end)

CloseButton.Activated:Connect(function()
    ScreenGui.Enabled = false
end)

-- =========================================================
-- INIT
-- =========================================================
Theme.RefreshQueueDisplay()
Theme.RefreshItemOptions()
RefreshHistoryList("")
Theme.RefreshFruitsQueue()
SwitchTab("mail")

-- Initial authoritative scan, followed by automatic scans only when the
-- Fruit Price Stock countdown resets.
ScanBackpackFruitValues()
WatchFruitPriceRefresh()

-- Refresh immediately when a newly harvested fruit enters storage or is
-- equipped. Keep this in a separate task scope: this UI file is large enough
-- that declaring more top-level locals can exceed Luau's 200-register limit.
task.spawn(function()
    local KnownHarvestedFruitIds = {}

    local function PrimeKnownHarvestedFruitIds()
        local containers = { Backpack }
        if LocalPlayer.Character then
            table.insert(containers, LocalPlayer.Character)
        end

        for _, container in ipairs(containers) do
            for _, item in ipairs(container:GetChildren()) do
                if item:GetAttribute("HarvestedFruit") == true then
                    local fruitId = item:GetAttribute("Id")
                    if fruitId then
                        KnownHarvestedFruitIds[tostring(fruitId)] = true
                    end
                end
            end
        end
    end

    local function WatchNewHarvestedFruit(container, containerName)
        container.ChildAdded:Connect(function(item)
            task.defer(function()
                if not item or not item.Parent then return end

                local function tryRefresh()
                    if item:GetAttribute("HarvestedFruit") ~= true then
                        return false
                    end

                    local fruitId = item:GetAttribute("Id")
                    if not fruitId then
                        return false
                    end

                    local fruitKey = tostring(fruitId)
                    -- Equipping/un-equipping reparents the same Tool between
                    -- Backpack and Character. It is not a new fruit, so ignore
                    -- any ID that was already present during the initial scan.
                    if KnownHarvestedFruitIds[fruitKey] then
                        return false
                    end

                    KnownHarvestedFruitIds[fruitKey] = true
                    FruitValueCache[fruitKey] = nil
                    print(string.format(
                        "[Mail Fruits] New harvested fruit detected in %s: %s; refreshing value.",
                        containerName,
                        tostring(item:GetAttribute("FruitName") or item.Name)
                    ))
                    ScanBackpackFruitValues(true)
                    return true
                end

                if tryRefresh() then return end

                -- Some builds add the Tool first and assign its attributes one
                -- frame later, so wait for the relevant attributes without using
                -- a fixed polling delay.
                local attributeConnection
                attributeConnection = item.AttributeChanged:Connect(function(attributeName)
                    if attributeName == "HarvestedFruit"
                        or attributeName == "Id"
                        or attributeName == "FruitName" then
                        if tryRefresh() and attributeConnection then
                            attributeConnection:Disconnect()
                        end
                    end
                end)
            end)
        end)
    end

    PrimeKnownHarvestedFruitIds()
    WatchNewHarvestedFruit(Backpack, "Backpack")
    if LocalPlayer.Character then
        WatchNewHarvestedFruit(LocalPlayer.Character, "Character")
    end
    LocalPlayer.CharacterAdded:Connect(function(character)
        WatchNewHarvestedFruit(character, "Character")
    end)
end)

print("MAIL BYPASS SCRIPT BY SCOOPHUB")
