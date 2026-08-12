--[[
    ScoopHub UI Library
    Shared visual system extracted from the Mail Bypass and Auto Buy Pet UIs.

    This file contains UI only. It does not include game automation, remotes,
    saved configs, webhooks, mail logic, or pet logic.

    Example:
        local UI = loadstring(game:HttpGet("YOUR_RAW_GITHUB_LIBRARY_URL"))()
        local Window = UI:CreateWindow({ Title = "MY SCRIPT", Version = "V1.0" })
        local Tabs = Window:CreateTabs({ "HOME", "SETTINGS" })
        local Panel = UI:CreatePanel(Tabs.Pages.HOME, { Title = "WELCOME" })
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local UI = {}

UI.Theme = {
    Bg = Color3.fromRGB(9, 5, 8),
    Panel = Color3.fromRGB(22, 10, 14),
    PanelLine = Color3.fromRGB(154, 44, 53),
    Red = Color3.fromRGB(231, 47, 59),
    RedDark = Color3.fromRGB(145, 28, 39),
    Text = Color3.fromRGB(255, 111, 120),
    TextDim = Color3.fromRGB(190, 73, 84),
    Success = Color3.fromRGB(99, 215, 163),
    Warning = Color3.fromRGB(255, 205, 82),
    White = Color3.fromRGB(246, 244, 252),
    TabBg = Color3.fromRGB(35, 16, 22),
    InputBg = Color3.fromRGB(49, 41, 49),
    InputText = Color3.fromRGB(238, 240, 249),
    ObsidianTop = Color3.fromRGB(39, 11, 17),
    ObsidianMid = Color3.fromRGB(8, 5, 8),
    ObsidianLow = Color3.fromRGB(34, 8, 11),
    Surface = Color3.fromRGB(22, 10, 14),
    Surface2 = Color3.fromRGB(37, 17, 23),
    Surface3 = Color3.fromRGB(52, 31, 37),
    Stroke = Color3.fromRGB(179, 52, 63),
    Muted = Color3.fromRGB(199, 170, 176),
    Font = Enum.Font.GothamBold,
    FontBody = Enum.Font.Gotham,
}

UI.Defaults = {
    Discord = "discord.gg/WxgqUa9Qz",
    DiscordIcon = "rbxassetid://94434236999817",
    Logo = "rbxassetid://90541504618217",
    LogoColor = Color3.fromRGB(255, 255, 255),
    HubName = "ScoopHub",
}

function UI:New(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

function UI:GetGuiParent()
    local ok, parent = pcall(function()
        return gethui and gethui()
    end)
    if ok and parent then
        return parent
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function UI:Corner(parent, radius)
    return self:New("UICorner", {
        CornerRadius = UDim.new(0, radius or 6),
    }, parent)
end

function UI:Stroke(parent, color, transparency, thickness)
    return self:New("UIStroke", {
        Color = color or self.Theme.Stroke,
        Transparency = transparency == nil and 0.45 or transparency,
        Thickness = thickness or 1,
    }, parent)
end

function UI:Tween(object, info, properties)
    if not object then
        return nil
    end
    local ok, tween = pcall(function()
        return TweenService:Create(object, info, properties)
    end)
    if ok and tween then
        tween:Play()
        return tween
    end
    return nil
end

function UI:MakeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPosition

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = target.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        target.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)
end

function UI:Notify(parent, title, description, duration)
    duration = duration or 4

    local notificationGui = self:New("ScreenGui", {
        Name = "ScoopHubNotification",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)

    local frame = self:New("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = self.Theme.Bg,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 1, 90),
        Size = UDim2.fromOffset(320, 70),
        ZIndex = 20,
    }, notificationGui)
    self:Corner(frame, 8)
    self:Stroke(frame, self.Theme.Red, 0.25, 1)

    self:New("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.Font,
        Text = title or "ScoopHub",
        TextColor3 = self.Theme.White,
        TextSize = 13,
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.new(1, -24, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 21,
    }, frame)

    self:New("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.FontBody,
        Text = description or "",
        TextColor3 = self.Theme.Muted,
        TextSize = 12,
        Position = UDim2.fromOffset(12, 30),
        Size = UDim2.new(1, -24, 0, 30),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 21,
    }, frame)

    self:Tween(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 1, -24),
    })

    task.delay(duration, function()
        if not frame.Parent then
            return
        end
        self:Tween(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 1, 90),
        })
        task.delay(0.35, function()
            if notificationGui then
                notificationGui:Destroy()
            end
        end)
    end)
end

function UI:CreateWindow(options)
    options = options or {}

    local theme = self.Theme
    local guiParent = options.Parent or self:GetGuiParent()
    local guiName = options.GuiName or "ScoopHubGui"
    local width = options.Width or 580
    local height = options.Height or 420
    local title = options.Title or "SCOOPHUB SCRIPT"
    local version = options.Version or ""
    local subtitle = options.Subtitle or "by ScoopHub"
    local discord = options.Discord or self.Defaults.Discord

    local existing = guiParent:FindFirstChild(guiName)
    if existing then
        existing:Destroy()
    end

    local gui = self:New("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, guiParent)

    local holder = self:New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(width, height),
        Name = "WindowHolder",
    }, gui)

    local scale = self:New("UIScale", {
        Name = "ResponsiveScale",
        Scale = options.DesktopScale or 1.05,
    }, holder)

    local function updateScale()
        local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        if not isMobile then
            scale.Scale = options.DesktopScale or 1.05
            return
        end

        local camera = workspace.CurrentCamera
        local viewportWidth = camera and camera.ViewportSize.X or 640
        scale.Scale = math.clamp((viewportWidth - 20) / width, 0.55, options.MobileScale or 0.82)
    end

    updateScale()
    task.defer(function()
        local camera = workspace.CurrentCamera
        if camera then
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
        end
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
    end)

    local shadow = self:New("ImageLabel", {
        Name = "DropShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxassetid://6015897843",
        ImageColor3 = Color3.fromRGB(4, 5, 8),
        ImageTransparency = 0.38,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(width, height),
        ZIndex = 0,
    }, holder)

    local main = self:New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Bg,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(width, height),
        ZIndex = 1,
    }, shadow)
    self:Corner(main, 8)
    self:Stroke(main, theme.Stroke, 0.86, 1)

    self:New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.ObsidianTop),
            ColorSequenceKeypoint.new(0.52, theme.ObsidianMid),
            ColorSequenceKeypoint.new(1, theme.ObsidianLow),
        }),
        Rotation = 16,
    }, main)

    local starField = self:New("Frame", {
        Name = "StarField",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
    }, main)

    local random = Random.new(LocalPlayer.UserId)
    local starColors = {
        Color3.fromRGB(255, 218, 218),
        Color3.fromRGB(246, 141, 151),
        Color3.fromRGB(255, 205, 156),
    }
    for _ = 1, options.StarCount or 90 do
        local bright = random:NextNumber() > 0.76
        local diameter = bright and random:NextInteger(2, 3) or 1
        local star = self:New("Frame", {
            BackgroundColor3 = starColors[random:NextInteger(1, #starColors)],
            BackgroundTransparency = bright and random:NextNumber(0.18, 0.36) or random:NextNumber(0.48, 0.72),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(random:NextNumber(0.01, 0.99), 0, random:NextNumber(0.02, 0.98), 0),
            Size = UDim2.fromOffset(diameter, diameter),
            ZIndex = 1,
        }, starField)
        self:Corner(star, diameter)
    end

    local titleBar = self:New("Frame", {
        Name = "TitleBar",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
        ZIndex = 3,
    }, main)

    local logo = self:New("ImageLabel", {
        Name = "Logo",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = options.Logo or self.Defaults.Logo,
        ImageColor3 = options.LogoColor or self.Defaults.LogoColor,
        ScaleType = Enum.ScaleType.Fit,
        Position = UDim2.new(0, 11, 0.5, -13),
        Size = UDim2.fromOffset(26, 26),
        ZIndex = 4,
    }, titleBar)
    self:Corner(logo, 6)

    local titleLabel = self:New("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = theme.Font,
        Text = title,
        TextColor3 = options.TitleColor or Color3.fromRGB(242, 92, 101),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 40, 0.5, -15),
        Size = UDim2.new(0, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 4,
    }, titleBar)
    self:Stroke(titleLabel, theme.Red, 0.62, 0.4)

    local versionLabel = self:New("TextLabel", {
        Name = "Version",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = theme.FontBody,
        Text = version,
        TextColor3 = theme.Muted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 40, 0.5, -15),
        Size = UDim2.new(0, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 4,
    }, titleBar)

    task.defer(function()
        versionLabel.Position = UDim2.new(0, 44 + titleLabel.TextBounds.X, 0.5, -15)
    end)

    self:New("TextLabel", {
        Name = "Subtitle",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = theme.FontBody,
        Text = subtitle,
        TextColor3 = options.SubtitleColor or Color3.fromRGB(166, 174, 187),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 40, 0.5, 0),
        Size = UDim2.new(0, 150, 0, 12),
        ZIndex = 4,
    }, titleBar)

    local discordPill = self:New("Frame", {
        Name = "DiscordPill",
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.Surface3,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(0, options.DiscordPosition or 200, 0.5, 0),
        Size = UDim2.fromOffset(math.clamp(#tostring(discord) * 7 + 38, 72, 190), 22),
        ZIndex = 4,
    }, titleBar)
    self:Corner(discordPill, 999)
    self:Stroke(discordPill, theme.Red, 0.62, 1)

    self:New("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = options.DiscordIcon or self.Defaults.DiscordIcon,
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        ScaleType = Enum.ScaleType.Fit,
        Position = UDim2.new(0, 8, 0.5, -7),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 5,
    }, discordPill)

    self:New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = theme.Font,
        Text = discord,
        TextColor3 = Color3.fromRGB(235, 235, 240),
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 27, 0, 0),
        Size = UDim2.new(1, -32, 1, 0),
        ZIndex = 5,
    }, discordPill)

    local discordButton = self:New("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 6,
    }, discordPill)

    local window = {
        Gui = gui,
        Holder = holder,
        Main = main,
        TitleBar = titleBar,
        Content = nil,
        Theme = theme,
        UI = self,
    }

    function window:Notify(notifyTitle, notifyDescription, duration)
        self.UI:Notify(guiParent, notifyTitle, notifyDescription, duration)
    end

    discordButton.Activated:Connect(function()
        local copied = pcall(function()
            if setclipboard then
                setclipboard(discord)
            end
        end)
        window:Notify("ScoopHub | Discord", copied and ("Copied to clipboard: " .. discord) or discord)
    end)

    local minButton = self:New("TextButton", {
        Name = "Minimize",
        BackgroundColor3 = theme.Surface2,
        BorderSizePixel = 0,
        Text = "-",
        TextColor3 = theme.White,
        Font = theme.Font,
        TextSize = 15,
        Position = UDim2.new(1, -58, 0, 6),
        Size = UDim2.fromOffset(25, 25),
        ZIndex = 5,
    }, titleBar)
    self:Corner(minButton, 5)

    local closeButton = self:New("TextButton", {
        Name = "Close",
        BackgroundColor3 = theme.Surface2,
        BorderSizePixel = 0,
        Text = "X",
        TextColor3 = theme.White,
        Font = theme.Font,
        TextSize = 13,
        Position = UDim2.new(1, -29, 0, 6),
        Size = UDim2.fromOffset(25, 25),
        ZIndex = 5,
    }, titleBar)
    self:Corner(closeButton, 5)

    local content = self:New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 39),
        Size = UDim2.new(1, 0, 1, -39),
        ZIndex = 3,
    }, main)
    window.Content = content

    local minimized = false
    minButton.Activated:Connect(function()
        minimized = not minimized
        content.Visible = not minimized
        starField.Visible = not minimized
        minButton.Text = minimized and "+" or "-"
        self:Tween(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(width, minimized and 40 or height),
        })
    end)

    closeButton.Activated:Connect(function()
        if type(options.OnClose) == "function" then
            pcall(options.OnClose)
        end
        gui:Destroy()
    end)

    self:MakeDraggable(titleBar, holder)

    function window:Destroy()
        if gui and gui.Parent then
            gui:Destroy()
        end
    end

    function window:CreateTabs(names)
        local tabBar = UI:New("Frame", {
            Name = "TabBar",
            BackgroundColor3 = theme.TabBg,
            BackgroundTransparency = 0.28,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(10, 4),
            Size = UDim2.new(1, -20, 0, 30),
            ZIndex = 4,
        }, content)
        UI:Corner(tabBar, 6)
        UI:Stroke(tabBar, theme.PanelLine, 0.42, 1)

        local pages = UI:New("Frame", {
            Name = "Pages",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(10, 42),
            Size = UDim2.new(1, -20, 1, -48),
            ZIndex = 4,
        }, content)

        local underline = UI:New("Frame", {
            BackgroundColor3 = theme.Red,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 28),
            Size = UDim2.new(0, 0, 0, 2),
            ZIndex = 6,
        }, tabBar)

        local tabObject = {
            Bar = tabBar,
            PagesHolder = pages,
            Pages = {},
            Buttons = {},
            Selected = nil,
        }

        local count = math.max(#names, 1)
        local function selectTab(name)
            if not tabObject.Pages[name] then
                return
            end
            tabObject.Selected = name
            for tabName, page in pairs(tabObject.Pages) do
                page.Visible = tabName == name
            end
            for tabName, button in pairs(tabObject.Buttons) do
                button.TextColor3 = tabName == name and theme.Red or theme.TextDim
            end

            local selectedButton = tabObject.Buttons[name]
            UI:Tween(underline, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new((table.find(names, name) - 1) / count, 0, 1, -2),
                Size = UDim2.new(1 / count, 0, 0, 2),
            })
        end

        for index, name in ipairs(names) do
            local page = UI:New("Frame", {
                Name = name .. "Page",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                ZIndex = 4,
            }, pages)

            local button = UI:New("TextButton", {
                Name = name .. "Tab",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = theme.Font,
                Text = name,
                TextColor3 = theme.TextDim,
                TextSize = 11,
                Position = UDim2.new((index - 1) / count, 0, 0, 0),
                Size = UDim2.new(1 / count, 0, 1, 0),
                ZIndex = 5,
            }, tabBar)

            tabObject.Pages[name] = page
            tabObject.Buttons[name] = button
            button.Activated:Connect(function()
                selectTab(name)
            end)
        end

        function tabObject:Select(name)
            selectTab(name)
        end

        if names[1] then
            selectTab(names[1])
        end
        return tabObject
    end

    return window
end

function UI:CreatePanel(parent, options)
    options = options or {}
    local panel = self:New("Frame", {
        Name = options.Name or "Panel",
        BackgroundColor3 = options.BackgroundColor3 or self.Theme.Panel,
        BackgroundTransparency = options.BackgroundTransparency == nil and 0.08 or options.BackgroundTransparency,
        BorderSizePixel = 0,
        Position = options.Position or UDim2.fromOffset(0, 0),
        Size = options.Size or UDim2.fromOffset(200, 100),
        ZIndex = options.ZIndex or 5,
    }, parent)
    self:Corner(panel, options.Radius or 7)
    self:Stroke(panel, options.StrokeColor or self.Theme.PanelLine, options.StrokeTransparency or 0.42, options.StrokeThickness or 1)

    if options.Title then
        self:New("TextLabel", {
            Name = "Title",
            BackgroundTransparency = 1,
            Font = self.Theme.Font,
            Text = options.Title,
            TextColor3 = self.Theme.Text,
            TextSize = options.TitleSize or 11,
            Position = UDim2.fromOffset(10, 8),
            Size = UDim2.new(1, -20, 0, 15),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = (options.ZIndex or 5) + 1,
        }, panel)
    end

    return panel
end

function UI:CreateLabel(parent, options)
    options = options or {}
    return self:New("TextLabel", {
        Name = options.Name or "Label",
        BackgroundTransparency = 1,
        Font = options.Font or self.Theme.FontBody,
        Text = options.Text or "",
        TextColor3 = options.TextColor3 or self.Theme.White,
        TextSize = options.TextSize or 12,
        TextWrapped = options.TextWrapped or false,
        TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = options.TextYAlignment or Enum.TextYAlignment.Center,
        Position = options.Position or UDim2.fromOffset(0, 0),
        Size = options.Size or UDim2.fromOffset(100, 20),
        ZIndex = options.ZIndex or 7,
    }, parent)
end

function UI:CreateButton(parent, options)
    options = options or {}
    local button = self:New("TextButton", {
        Name = options.Name or "Button",
        BackgroundColor3 = options.BackgroundColor3 or self.Theme.RedDark,
        BorderSizePixel = 0,
        Font = options.Font or self.Theme.Font,
        Text = options.Text or "BUTTON",
        TextColor3 = options.TextColor3 or self.Theme.White,
        TextSize = options.TextSize or 12,
        Position = options.Position or UDim2.fromOffset(0, 0),
        Size = options.Size or UDim2.fromOffset(120, 30),
        ZIndex = options.ZIndex or 7,
        AutoButtonColor = false,
    }, parent)
    self:Corner(button, options.Radius or 5)

    if options.Stroke then
        self:Stroke(button, options.StrokeColor or self.Theme.Red, options.StrokeTransparency or 0.55, 1)
    end

    if options.Hover ~= false then
        local normalColor = button.BackgroundColor3
        button.MouseEnter:Connect(function()
            if button.Active then
                button.BackgroundColor3 = options.HoverColor or self.Theme.Red
            end
        end)
        button.MouseLeave:Connect(function()
            if button.Parent then
                button.BackgroundColor3 = normalColor
            end
        end)
    end

    if type(options.Callback) == "function" then
        button.Activated:Connect(options.Callback)
    end
    return button
end

function UI:CreateTextBox(parent, options)
    options = options or {}
    local box = self:New("TextBox", {
        Name = options.Name or "TextBox",
        BackgroundColor3 = options.BackgroundColor3 or self.Theme.InputBg,
        BorderSizePixel = 0,
        ClearTextOnFocus = options.ClearTextOnFocus == true,
        Font = options.Font or self.Theme.Font,
        PlaceholderColor3 = options.PlaceholderColor3 or self.Theme.Muted,
        PlaceholderText = options.PlaceholderText or "Enter text...",
        Text = options.Text or "",
        TextColor3 = options.TextColor3 or self.Theme.InputText,
        TextSize = options.TextSize or 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left,
        Position = options.Position or UDim2.fromOffset(0, 0),
        Size = options.Size or UDim2.fromOffset(180, 30),
        ZIndex = options.ZIndex or 7,
    }, parent)
    self:Corner(box, options.Radius or 5)

    local padding = self:New("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, box)

    local stroke = self:Stroke(box, self.Theme.Red, 0.72, 1)
    box.Focused:Connect(function()
        stroke.Transparency = 0.05
        stroke.Thickness = 1.35
    end)
    box.FocusLost:Connect(function(enterPressed)
        stroke.Transparency = 0.72
        stroke.Thickness = 1
        if type(options.OnFocusLost) == "function" then
            options.OnFocusLost(box.Text, enterPressed)
        end
    end)
    return box
end

function UI:CreateToggle(parent, options)
    options = options or {}
    local enabled = options.Default == true
    local zIndex = options.ZIndex or 7
    local holder = self:New("Frame", {
        Name = options.Name or "ToggleRow",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = options.Position or UDim2.fromOffset(0, 0),
        Size = options.Size or UDim2.fromOffset(240, 40),
        ZIndex = zIndex,
    }, parent)

    self:CreateLabel(holder, {
        Text = options.Title or "Toggle",
        Font = self.Theme.Font,
        TextColor3 = self.Theme.Text,
        TextSize = 11,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -58, 0, 16),
        ZIndex = zIndex + 1,
    })

    if options.Description then
        self:CreateLabel(holder, {
            Text = options.Description,
            TextColor3 = self.Theme.Muted,
            TextSize = 10,
            Position = UDim2.fromOffset(0, 17),
            Size = UDim2.new(1, -58, 0, 18),
            ZIndex = zIndex + 1,
        })
    end

    local toggle = self:New("TextButton", {
        Name = "Toggle",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = enabled and self.Theme.Success or self.Theme.Surface3,
        BorderSizePixel = 0,
        Text = "",
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(44, 24),
        ZIndex = zIndex + 2,
    }, holder)
    self:Corner(toggle, 999)
    self:Stroke(toggle, self.Theme.Red, 0.5, 1)

    local knob = self:New("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Theme.White,
        BorderSizePixel = 0,
        Position = UDim2.new(enabled and 1 or 0, enabled and -12 or 12, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        ZIndex = zIndex + 3,
    }, toggle)
    self:Corner(knob, 999)

    local api = {
        Holder = holder,
        Button = toggle,
        Knob = knob,
        Value = enabled,
    }

    function api:Set(value, silent)
        self.Value = value == true
        UI:Tween(toggle, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = self.Value and UI.Theme.Success or UI.Theme.Surface3,
        })
        UI:Tween(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(self.Value and 1 or 0, self.Value and -12 or 12, 0.5, 0),
        })
        if not silent and type(options.Callback) == "function" then
            options.Callback(self.Value)
        end
    end

    toggle.Activated:Connect(function()
        api:Set(not api.Value)
    end)
    api:Set(enabled, true)
    return api
end

function UI:CreateScroll(parent, options)
    options = options or {}
    local scroll = self:New("ScrollingFrame", {
        Name = options.Name or "Scroll",
        BackgroundColor3 = options.BackgroundColor3 or self.Theme.Panel,
        BackgroundTransparency = options.BackgroundTransparency == nil and 0.1 or options.BackgroundTransparency,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = self.Theme.Red,
        ScrollBarThickness = options.ScrollBarThickness or 3,
        Position = options.Position or UDim2.fromOffset(0, 0),
        Size = options.Size or UDim2.fromOffset(200, 200),
        ZIndex = options.ZIndex or 7,
    }, parent)
    self:Corner(scroll, options.Radius or 5)
    self:Stroke(scroll, self.Theme.PanelLine, 0.62, 1)

    local layout = self:New("UIListLayout", {
        Padding = UDim.new(0, options.Padding or 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)

    self:New("UIPadding", {
        PaddingTop = UDim.new(0, options.EdgePadding or 7),
        PaddingBottom = UDim.new(0, options.EdgePadding or 7),
        PaddingLeft = UDim.new(0, options.EdgePadding or 7),
        PaddingRight = UDim.new(0, options.EdgePadding or 7),
    }, scroll)

    return scroll, layout
end

return UI
