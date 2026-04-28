--[[
    Velvet UI Library
    Premium dark glassmorphism UI for Roblox
    PC + Mobile | github.com/DexCodeSX/Velvet
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Velvet = {
    Flags = {},
    Windows = {},
    Notifications = {},
    Theme = nil,
    _connections = {},
    _listeners = {},
    _elements = {},
    _errorLog = {},
    _onError = nil,
    _activeDrag = nil, -- mutex so picker drag doesn't bleed into slider
    _version = "3.1.0"
}

-- defaults
local DEFAULT_THEME = {
    Name = "Midnight",
    Base = Color3.fromRGB(10, 10, 14),
    Surface = Color3.fromRGB(18, 18, 26),
    Panel = Color3.fromRGB(24, 24, 36),
    Border = Color3.fromRGB(45, 45, 65),
    Accent = Color3.fromRGB(124, 92, 252),
    AccentDark = Color3.fromRGB(90, 65, 200),
    Text = Color3.fromRGB(232, 232, 240),
    TextDim = Color3.fromRGB(136, 136, 170),
    TextMuted = Color3.fromRGB(80, 80, 110),
    Success = Color3.fromRGB(80, 220, 120),
    Warning = Color3.fromRGB(255, 180, 50),
    Error = Color3.fromRGB(255, 80, 80),
    Info = Color3.fromRGB(80, 160, 255),
}

Velvet.Theme = DEFAULT_THEME

-- utils
local function tween(obj, props, dur, style)
    local tw = TweenService:Create(obj, TweenInfo.new(dur or 0.22, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function create(cls, props)
    local inst = Instance.new(cls)
    for k, v in props do
        if k ~= "Parent" and k ~= "Children" then
            inst[k] = v
        end
    end
    if props.Children then
        for _, child in props.Children do
            child.Parent = inst
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Velvet.Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        Parent = parent
    })
end

local function addPadding(parent, t, b, l, r)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, t or 8),
        PaddingBottom = UDim.new(0, b or 8),
        PaddingLeft = UDim.new(0, l or 10),
        PaddingRight = UDim.new(0, r or 10),
        Parent = parent
    })
end

local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function getScreenSize()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function round(v, inc)
    inc = inc or 1
    return math.floor(v / inc + 0.5) * inc
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function color3ToHex(c)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function hexToColor3(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1,2), 16) or 0
    local g = tonumber(hex:sub(3,4), 16) or 0
    local b = tonumber(hex:sub(5,6), 16) or 0
    return Color3.fromRGB(r, g, b)
end

-- error handling
local function velvetError(source, err)
    local trace = debug.traceback(tostring(err), 3)
    local entry = {
        source = source,
        message = tostring(err),
        traceback = trace,
        time = os.clock(),
    }
    table.insert(Velvet._errorLog, entry)
    if #Velvet._errorLog > 50 then table.remove(Velvet._errorLog, 1) end

    warn(`[Velvet] {source}: {err}`)

    if Velvet._onError then
        pcall(Velvet._onError, entry)
    end

    -- show notification if Notify is available
    pcall(function()
        Velvet:Notify({
            Title = "Velvet Error",
            Content = source .. ": " .. tostring(err):sub(1, 120),
            Duration = 5,
            Type = "error",
        })
    end)
end

local function safecall(source, fn, ...)
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then velvetError(source, err) end
    end)
end

function Velvet:OnError(fn)
    self._onError = fn
end

function Velvet:GetErrors()
    return self._errorLog
end

-- flag listener system
function Velvet:OnFlagChanged(id, fn)
    if not self._listeners[id] then self._listeners[id] = {} end
    table.insert(self._listeners[id], fn)
end

local function fireListeners(id, val)
    local cbs = Velvet._listeners[id]
    if cbs then
        for _, fn in cbs do safecall(`Listener:{id}`, fn, val) end
    end
end

local function tagSearch(frame, text)
    if not frame or not text then return end
    frame:SetAttribute("VelvetSearch", string.lower(text))
end

local function setupVisibility(elem, frame, opts)
    if not opts.VisibleWhen then return end
    local depId = opts.VisibleWhen
    local function check(v)
        local vis = not not v -- truthy check
        frame.Visible = vis
    end
    -- initial state
    local cur = Velvet.Flags[depId]
    if cur ~= nil then check(cur) else frame.Visible = false end
    Velvet:OnFlagChanged(depId, check)
end

-- attach OnChanged to element objects
local function attachOnChanged(elem, id)
    function elem:OnChanged(fn)
        Velvet:OnFlagChanged(id, fn)
        return self
    end
end

-- wire tooltip if opts.Tooltip is set
local function setupTooltip(frame, opts)
    if not opts or not opts.Tooltip then return end
    if Velvet.AttachTooltip then
        pcall(function() Velvet:AttachTooltip(frame, opts.Tooltip) end)
    end
end

-- cleanup old gui
pcall(function()
    local old = gethui():FindFirstChild("VelvetUI")
    if old then old:Destroy() end
end)

-- root gui
local gui = create("ScreenGui", {
    Name = "VelvetUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 500
})
pcall(function() gui.Parent = gethui() end)
if not gui.Parent then
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- notifications live in a separate screengui so they always float above the window
local notifGui = create("ScreenGui", {
    Name = "VelvetNotifs",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 10000,
})
pcall(function() notifGui.Parent = gethui() end)
if not notifGui.Parent then
    notifGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- notification container (top right)
local notifHolder = create("Frame", {
    Name = "Notifications",
    Size = UDim2.new(0, 300, 1, 0),
    Position = UDim2.new(1, -310, 0, 10),
    BackgroundTransparency = 1,
    Parent = notifGui,
    Children = {
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        })
    }
})

-- ~~
-- ICON RESOLVER
-- accepts: rbxassetid://..., plain number id, "rbxassetid://12345",
-- or a lucide icon name ("sword", "heart", "arrow-left") if icons are bound
-- ~~
function Velvet:SetIcons(iconPack)
    self._icons = iconPack
end

function Velvet:ResolveIcon(ref)
    if not ref then return nil end
    if type(ref) == "number" then return "rbxassetid://" .. ref end
    if type(ref) ~= "string" then return nil end
    -- already an asset url
    if ref:find("rbxassetid://") or ref:find("rbxthumb://") or ref:find("rbxgameasset://") or ref:find("http") then
        return ref
    end
    -- numeric string
    if tonumber(ref) then return "rbxassetid://" .. ref end
    -- lucide name via bound icon pack
    if self._icons then
        local id = self._icons:Get(ref) or self._icons:Fuzzy(ref)
        if id then return id end
    end
    return nil
end

function Velvet:Notify(opts)
    opts = opts or {}
    local title = opts.Title or "Velvet"
    local content = opts.Content or ""
    local dur = opts.Duration or 4
    local ntype = opts.Type or "info"
    local theme = self.Theme

    local accentColor = ({
        info = theme.Info,
        success = theme.Success,
        warning = theme.Warning,
        error = theme.Error,
    })[ntype] or theme.Accent

    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.1,
        ClipsDescendants = true,
        Parent = notifHolder
    })
    addCorner(card, 10)
    addStroke(card, accentColor, 1, 0.4)

    -- accent bar left
    create("Frame", {
        Size = UDim2.new(0, 3, 1, -8),
        Position = UDim2.new(0, 6, 0, 4),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = card,
        Children = { create("UICorner", { CornerRadius = UDim.new(0, 2) }) }
    })

    local titleLbl = create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.new(0, 16, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    local contentLbl = create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 0),
        Position = UDim2.new(0, 16, 0, 26),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = theme.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card
    })

    -- calc height
    local textH = contentLbl.TextBounds.Y
    if textH < 12 then textH = 14 end
    local totalH = 26 + textH + 12

    -- animate in
    tween(card, {Size = UDim2.new(1, 0, 0, totalH)}, 0.3)

    -- auto dismiss
    task.delay(dur, function()
        tween(card, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.25)
        task.wait(0.3)
        pcall(function() card:Destroy() end)
    end)
end

-- ~~---------
-- WINDOW
-- ~~---------
-- ~~---------
-- KEY SYSTEM
-- ~~---------
function Velvet:KeySystem(opts)
    opts = opts or {}
    local title = opts.Title or "Key System"
    local subtitle = opts.SubTitle or "Enter your key to continue"
    local keys = opts.Keys or {}
    local saveName = opts.SaveKey or "VelvetKey.txt"
    local cb = opts.Callback or function() end
    local theme = self.Theme
    local mobile = isMobile()

    -- check saved key first
    local savedKey = nil
    pcall(function()
        savedKey = readfile(saveName)
    end)
    if savedKey then
        for _, k in keys do
            if savedKey == k then
                safecall("KeySystem", cb, true)
                return true
            end
        end
    end

    local passed = false
    local keyGui = create("Frame", {
        Name = "VelvetKeySystem",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.4,
        ZIndex = 200,
        Parent = gui
    })

    local card = create("Frame", {
        Size = UDim2.new(0, mobile and 320 or 340, 0, 0),
        Position = UDim2.new(0.5, mobile and -160 or -170, 0.5, 0),
        BackgroundColor3 = theme.Base,
        ClipsDescendants = true,
        ZIndex = 201,
        Parent = keyGui
    })
    addCorner(card, 14)
    addStroke(card, theme.Border, 1, 0.3)

    -- accent line
    create("Frame", {
        Size = UDim2.new(0, 40, 0, 2),
        Position = UDim2.new(0.5, -20, 0, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 210,
        Parent = card
    })

    -- title
    create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 20),
        Position = UDim2.new(0, 20, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme.Text,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 210,
        Parent = card
    })

    create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 14),
        Position = UDim2.new(0, 20, 0, 42),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = theme.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 210,
        Parent = card
    })

    -- input
    local inputBg = create("Frame", {
        Size = UDim2.new(1, -40, 0, 38),
        Position = UDim2.new(0, 20, 0, 68),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 210,
        Parent = card
    })
    addCorner(inputBg, 8)
    local keyStroke = addStroke(inputBg, theme.Border, 1, 0.5)

    local keyInput = create("TextBox", {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Enter key...",
        TextColor3 = theme.Text,
        PlaceholderColor3 = theme.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 211,
        Parent = inputBg
    })

    keyInput.Focused:Connect(function()
        tween(keyStroke, {Color = theme.Accent, Transparency = 0}, 0.15)
    end)
    keyInput.FocusLost:Connect(function()
        tween(keyStroke, {Color = theme.Border, Transparency = 0.5}, 0.15)
    end)

    -- status label
    local statusLabel = create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 14),
        Position = UDim2.new(0, 20, 0, 112),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.Error,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 210,
        Parent = card
    })

    -- submit button
    local submitBtn = create("TextButton", {
        Size = UDim2.new(1, -40, 0, 36),
        Position = UDim2.new(0, 20, 0, 130),
        BackgroundColor3 = theme.Accent,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 210,
        Parent = card
    })
    addCorner(submitBtn, 8)

    create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "Verify",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        ZIndex = 211,
        Parent = submitBtn
    })

    submitBtn.MouseEnter:Connect(function()
        tween(submitBtn, {BackgroundColor3 = theme.AccentDark}, 0.15)
    end)
    submitBtn.MouseLeave:Connect(function()
        tween(submitBtn, {BackgroundColor3 = theme.Accent}, 0.15)
    end)

    -- get key link
    if opts.GetKeyLink then
        local linkBtn = create("TextButton", {
            Size = UDim2.new(1, -40, 0, 28),
            Position = UDim2.new(0, 20, 0, 174),
            BackgroundTransparency = 1,
            Text = "Get Key",
            TextColor3 = theme.Accent,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            ZIndex = 210,
            Parent = card
        })
        linkBtn.MouseButton1Click:Connect(function()
            pcall(function() setclipboard(opts.GetKeyLink) end)
            statusLabel.Text = "Link copied to clipboard!"
            statusLabel.TextColor3 = theme.Info
            task.delay(2, function()
                if statusLabel.Parent then statusLabel.Text = "" end
            end)
        end)
    end

    local cardH = opts.GetKeyLink and 214 or 180

    -- animate in
    tween(card, {
        Size = UDim2.new(0, mobile and 320 or 340, 0, cardH),
        Position = UDim2.new(0.5, mobile and -160 or -170, 0.5, -cardH/2),
    }, 0.3)

    -- verify
    local function tryKey()
        local input = keyInput.Text
        if input == "" then
            statusLabel.Text = "Enter a key first"
            statusLabel.TextColor3 = theme.Warning
            return
        end

        local valid = false
        for _, k in keys do
            if input == k then valid = true break end
        end

        if valid then
            statusLabel.Text = "Key accepted!"
            statusLabel.TextColor3 = theme.Success
            pcall(function() writefile(saveName, input) end)
            passed = true
            tween(card, {
                Size = UDim2.new(0, mobile and 320 or 340, 0, 0),
                Position = UDim2.new(0.5, mobile and -160 or -170, 0.5, 0),
            }, 0.25)
            tween(keyGui, {BackgroundTransparency = 1}, 0.3)
            task.delay(0.3, function()
                pcall(function() keyGui:Destroy() end)
                safecall("KeySystem", cb, true)
            end)
        else
            statusLabel.Text = "Invalid key!"
            statusLabel.TextColor3 = theme.Error
            -- shake
            local orig = card.Position
            for i = 1, 3 do
                tween(card, {Position = orig + UDim2.new(0, 8, 0, 0)}, 0.04)
                task.wait(0.04)
                tween(card, {Position = orig + UDim2.new(0, -8, 0, 0)}, 0.04)
                task.wait(0.04)
            end
            tween(card, {Position = orig}, 0.04)
        end
    end

    submitBtn.MouseButton1Click:Connect(tryKey)
    keyInput.FocusLost:Connect(function(enter)
        if enter then tryKey() end
    end)

    -- block until done (or return immediately if caller doesn't need to wait)
    return passed
end

function Velvet:CreateWindow(opts)
    opts = opts or {}
    local theme = self.Theme
    local mobile = isMobile()
    local screen = getScreenSize()

    local winW = opts.Width or (mobile and math.min(screen.X - 20, 380) or 560)
    local winH = opts.Height or (mobile and math.min(screen.Y - 80, 420) or 400)
    local tabW = opts.TabWidth or (mobile and 52 or 150)

    local window = {
        Tabs = {},
        ActiveTab = nil,
        Visible = true,
        _flags = self.Flags,
        _theme = theme,
    }

    -- main frame
    local main = create("Frame", {
        Name = "VelvetWindow",
        Size = UDim2.new(0, winW, 0, winH),
        Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.02,
        ClipsDescendants = true,
        Parent = gui
    })
    addCorner(main, 14)
    addStroke(main, theme.Border, 1, 0.25)
    -- subtle accent ambient (premium glow)
    local glowStroke = create("UIStroke", {
        Color = theme.Accent,
        Thickness = 2,
        Transparency = 0.85,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = main
    })
    window._glowStroke = glowStroke
    window._main = main

    -- ui scale (global multiplier for everything inside the window)
    local uiScale = create("UIScale", {
        Scale = opts.Scale or 1,
        Parent = main,
    })
    function window:SetScale(s)
        uiScale.Scale = math.clamp(s, 0.5, 2)
    end
    function window:GetScale() return uiScale.Scale end

    -- glass overlay
    local glass = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = main
    })
    addCorner(glass, 12)

    -- top accent line (gradient-faded edges so it feels like a glow strip)
    local accentLine = create("Frame", {
        Size = UDim2.new(0, 80, 0, 2),
        Position = UDim2.new(0.5, -40, 0, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = main
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = accentLine
    })

    -- header
    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = main
    })
    addCorner(header, 12)
    -- fix bottom corners
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = header
    })

    -- logo dot (gently pulses so window feels "alive")
    local logoDot = create("Frame", {
        Size = UDim2.new(0, 7, 0, 7),
        Position = UDim2.new(0, 16, 0.5, -3),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = header
    })
    addCorner(logoDot, 4)
    -- pulse halo
    local logoHalo = create("Frame", {
        Size = UDim2.new(0, 7, 0, 7),
        Position = UDim2.new(0, 16, 0.5, -3),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = header,
    })
    addCorner(logoHalo, 4)
    task.spawn(function()
        while logoHalo.Parent do
            tween(logoHalo, {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 12, 0.5, -8), BackgroundTransparency = 1}, 1.4, Enum.EasingStyle.Sine)
            task.wait(1.4)
            logoHalo.Size = UDim2.new(0, 7, 0, 7)
            logoHalo.Position = UDim2.new(0, 16, 0.5, -3)
            logoHalo.BackgroundTransparency = 0.6
            task.wait(0.4)
        end
    end)

    -- title
    create("TextLabel", {
        Size = UDim2.new(0, 200, 0, 16),
        Position = UDim2.new(0, 30, 0, 8),
        BackgroundTransparency = 1,
        Text = opts.Title or "Velvet",
        TextColor3 = theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
        Parent = header
    })

    -- subtitle
    if opts.SubTitle then
        create("TextLabel", {
            Size = UDim2.new(0, 200, 0, 12),
            Position = UDim2.new(0, 30, 0, 24),
            BackgroundTransparency = 1,
            Text = opts.SubTitle,
            TextColor3 = theme.TextMuted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
            Parent = header
        })
    end

    -- search bar (header right, before the 3 buttons; collapses to icon on mobile)
    local searchBarW = mobile and 28 or 160
    local searchBar = create("Frame", {
        Size = UDim2.new(0, searchBarW, 0, 26),
        Position = UDim2.new(1, -(110 + searchBarW + 6), 0.5, -13),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = mobile and 0.4 or 0.1,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = header,
    })
    addCorner(searchBar, 6)
    local searchStroke = addStroke(searchBar, theme.Border, 1, 0.5)

    -- magnifier glyph (just a textlabel for portability)
    create("TextLabel", {
        Size = UDim2.new(0, 18, 1, 0),
        Position = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1,
        Text = "⌕",
        TextColor3 = theme.TextMuted,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        ZIndex = 8,
        Parent = searchBar,
    })

    local searchBox = create("TextBox", {
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search...",
        TextColor3 = theme.Text,
        PlaceholderColor3 = theme.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 8,
        Parent = searchBar,
        Visible = not mobile,
    })

    searchBox.Focused:Connect(function()
        tween(searchStroke, {Color = theme.Accent, Transparency = 0.2}, 0.15)
    end)
    searchBox.FocusLost:Connect(function()
        tween(searchStroke, {Color = theme.Border, Transparency = 0.5}, 0.15)
    end)

    -- mobile: tap icon to expand. expanded bar sits ABOVE the buttons row
    -- (full width minus padding) so it doesnt clip the close/min/toggle.
    -- a small × at the right of the expanded bar lets users collapse it.
    local mobileExpanded = false
    local closeBtn
    if mobile then
        local tapBtn = create("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 9,
            Parent = searchBar,
        })

        -- × glyph that appears only when expanded, used to collapse
        closeBtn = create("TextButton", {
            Size = UDim2.new(0, 22, 1, 0),
            Position = UDim2.new(1, -22, 0, 0),
            BackgroundTransparency = 1,
            Text = "×",
            TextColor3 = theme.TextMuted,
            TextSize = 18,
            Font = Enum.Font.GothamBold,
            ZIndex = 10,
            Visible = false,
            Parent = searchBar,
        })

        local function collapse()
            mobileExpanded = false
            searchBox.Text = ""
            searchBox.Visible = false
            closeBtn.Visible = false
            tween(searchBar, {Size = UDim2.new(0, 28, 0, 26), Position = UDim2.new(1, -(110 + 28 + 6), 0.5, -13), BackgroundTransparency = 0.4}, 0.2)
            if window._applySearch then window:_applySearch("") end
        end

        tapBtn.MouseButton1Click:Connect(function()
            if mobileExpanded then return end
            mobileExpanded = true
            searchBox.Visible = true
            -- shrink box width to leave room for × button
            searchBox.Size = UDim2.new(1, -52, 1, 0)
            -- place expanded bar near the right edge but stop short of the action buttons
            -- header buttons take ~110px; pad 6px gap. Use full width so search has room.
            tween(searchBar, {Size = UDim2.new(1, -130, 0, 26), Position = UDim2.new(0, 12, 0.5, -13), BackgroundTransparency = 0}, 0.2)
            closeBtn.Visible = true
            task.delay(0.22, function()
                if mobileExpanded then searchBox:CaptureFocus() end
            end)
        end)

        closeBtn.MouseButton1Click:Connect(collapse)
        -- also collapse if user taps elsewhere & box loses focus with no text
        searchBox.FocusLost:Connect(function()
            if mobileExpanded and searchBox.Text == "" then
                task.wait(0.1)
                if mobileExpanded and searchBox.Text == "" then collapse() end
            end
        end)
    end

    -- core filter, walks every elem frame's VelvetSearch attr
    function window:_applySearch(q)
        q = string.lower(q or "")
        for _, t in self.Tabs do
            local content = t._content
            if content then
                for _, secFrame in content:GetChildren() do
                    if secFrame:IsA("Frame") then
                        local anyVisible = false
                        for _, child in secFrame:GetDescendants() do
                            if child:IsA("Frame") or child:IsA("TextButton") then
                                local s = child:GetAttribute("VelvetSearch")
                                if s then
                                    local match = q == "" or string.find(s, q, 1, true) ~= nil
                                    child.Visible = match
                                    if match then anyVisible = true end
                                end
                            end
                        end
                        -- hide whole section if nothing matches and there's a query
                        if q ~= "" then
                            secFrame.Visible = anyVisible
                        else
                            secFrame.Visible = true
                        end
                    end
                end
            end
        end
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        window:_applySearch(searchBox.Text)
    end)

    -- close button
    local closeBtn = create("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -36, 0.5, -12),
        BackgroundColor3 = theme.Error,
        BackgroundTransparency = 0.6,
        Text = "x",
        TextColor3 = theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 7,
        AutoButtonColor = false,
        Parent = header
    })
    addCorner(closeBtn, 6)

    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, {BackgroundTransparency = 0.2}, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, {BackgroundTransparency = 0.6}, 0.15)
    end)

    -- minimize button
    local minBtn = create("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -66, 0.5, -12),
        BackgroundColor3 = theme.Warning,
        BackgroundTransparency = 0.6,
        Text = "-",
        TextColor3 = theme.Text,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 7,
        AutoButtonColor = false,
        Parent = header
    })
    addCorner(minBtn, 6)

    minBtn.MouseEnter:Connect(function()
        tween(minBtn, {BackgroundTransparency = 0.2}, 0.15)
    end)
    minBtn.MouseLeave:Connect(function()
        tween(minBtn, {BackgroundTransparency = 0.6}, 0.15)
    end)

    -- tab sidebar
    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, tabW, 1, -48),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 4,
        ClipsDescendants = true,
        Parent = main
    })

    -- sidebar separator
    create("Frame", {
        Size = UDim2.new(0, 1, 1, -12),
        Position = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = theme.Border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = sidebar
    })

    local tabList = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -6),
        Position = UDim2.new(0, 0, 0, 6),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 5,
        Parent = sidebar,
        Children = {
            create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 2),
            }),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
            })
        }
    })

    -- active tab indicator (height adapts to tab content)
    local indicatorH = mobile and 28 or 18
    local tabIndicator = create("Frame", {
        Size = UDim2.new(0, 3, 0, indicatorH),
        Position = UDim2.new(0, 2, 0, 8),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = sidebar
    })
    addCorner(tabIndicator, 2)

    -- content area
    local contentArea = create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -(tabW + 2), 1, -48),
        Position = UDim2.new(0, tabW + 2, 0, 48),
        BackgroundTransparency = 1,
        ZIndex = 3,
        ClipsDescendants = true,
        Parent = main
    })

    -- dragging
    local dragging, dragStart, startPos = false, nil, nil

    local function beginDrag(pos)
        dragging = true
        dragStart = pos
        startPos = main.Position
    end
    local function updateDrag(pos)
        if not dragging then return end
        local delta = pos - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    local function endDrag() dragging = false end

    header.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            beginDrag(Vector2.new(inp.Position.X, inp.Position.Y))
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            updateDrag(Vector2.new(inp.Position.X, inp.Position.Y))
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)

    -- floating toggle pill
    -- toggle pill - supports text OR icon, auto-sizes
    local resolvedToggleIcon = Velvet:ResolveIcon(opts.ToggleIcon)
    local pillText = opts.ToggleText or resolvedToggleIcon or "V"
    local pillIsIcon = resolvedToggleIcon ~= nil
    local pillH = mobile and 48 or 36

    -- calc width: auto-size for text length
    local pillW = pillH -- default square
    if not pillIsIcon and #pillText > 1 then
        -- estimate text width + padding
        pillW = math.max(pillH, #pillText * (mobile and 11 or 9) + (mobile and 24 or 18))
    end

    local togglePill = create("TextButton", {
        Name = "VelvetToggle",
        Size = UDim2.new(0, pillW, 0, pillH),
        Position = UDim2.new(0, 12, 0.5, -pillH/2),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.15,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 100,
        Visible = false,
        Parent = gui
    })
    addCorner(togglePill, pillH / 2)
    addStroke(togglePill, theme.Accent, 1, 0.3)

    if pillIsIcon then
        -- icon mode: use ImageLabel
        local iconImg = create("ImageLabel", {
            Size = UDim2.new(0, mobile and 22 or 18, 0, mobile and 22 or 18),
            Position = UDim2.new(0.5, mobile and -11 or -9, 0.5, mobile and -11 or -9),
            BackgroundTransparency = 1,
            Image = resolvedToggleIcon,
            ImageColor3 = theme.Text,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 101,
            Parent = togglePill
        })
    else
        -- text mode
        create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = pillText,
            TextColor3 = theme.Text,
            TextSize = mobile and 16 or 13,
            Font = Enum.Font.GothamBold,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 101,
            Parent = togglePill
        })
    end

    -- pill drag
    local pillDrag, pillDragStart, pillStartPos = false, nil, nil
    local pillMoved = false

    togglePill.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            pillDrag = true
            pillMoved = false
            pillDragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            pillStartPos = togglePill.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not pillDrag then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local pos = Vector2.new(inp.Position.X, inp.Position.Y)
            local delta = pos - pillDragStart
            if delta.Magnitude > 5 then pillMoved = true end
            togglePill.Position = UDim2.new(pillStartPos.X.Scale, pillStartPos.X.Offset + delta.X, pillStartPos.Y.Scale, pillStartPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if pillDrag and not pillMoved then
                -- tap, toggle window
                window:Show()
            end
            pillDrag = false
        end
    end)

    -- hover glow on pill
    togglePill.MouseEnter:Connect(function()
        tween(togglePill, {BackgroundTransparency = 0}, 0.15)
    end)
    togglePill.MouseLeave:Connect(function()
        tween(togglePill, {BackgroundTransparency = 0.15}, 0.15)
    end)

    -- show/hide
    function window:Show()
        if self.Visible then return end
        self.Visible = true
        main.Visible = true
        togglePill.Visible = false
        main.Size = UDim2.new(0, winW * 0.9, 0, winH * 0.9)
        main.BackgroundTransparency = 0.5
        tween(main, {
            Size = UDim2.new(0, winW, 0, winH),
            BackgroundTransparency = 0.02
        }, 0.3)
    end

    function window:Hide()
        if not self.Visible then return end
        self.Visible = false
        tween(main, {
            Size = UDim2.new(0, winW * 0.9, 0, winH * 0.9),
            BackgroundTransparency = 0.6
        }, 0.2)
        task.delay(0.22, function()
            main.Visible = false
            togglePill.Visible = true
            tween(togglePill, {BackgroundTransparency = 0.15}, 0.2)
        end)
    end

    function window:Toggle()
        if self.Visible then self:Hide() else self:Show() end
    end

    function window:Destroy()
        pcall(function() main:Destroy() end)
        pcall(function() togglePill:Destroy() end)
    end
    window.ScreenGui = gui

    -- close / minimize
    closeBtn.MouseButton1Click:Connect(function()
        -- full nuke: window + watermark + toggle pill + listeners + all velvet stuff
        Velvet:Destroy()
    end)
    minBtn.MouseButton1Click:Connect(function()
        window:Hide()
    end)

    -- toggle key
    local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
    UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == toggleKey then
            window:Toggle()
        end
    end)

    -- open animation
    main.Size = UDim2.new(0, winW * 0.8, 0, winH * 0.8)
    main.BackgroundTransparency = 0.5
    tween(main, {
        Size = UDim2.new(0, winW, 0, winH),
        BackgroundTransparency = 0.02
    }, 0.35)

    -- ~~--------
    -- SIDEBAR COLLAPSE (mobile or opt-in)
    -- ~~--------
    local sidebarCollapsed = false
    local collapsedW = 0
    local expandedW = tabW

    local function applySidebar()
        local w = sidebarCollapsed and collapsedW or expandedW
        tween(sidebar, {Size = UDim2.new(0, w, 1, -48)}, 0.22)
        tween(contentArea, {
            Size = UDim2.new(1, -(w + 2), 1, -48),
            Position = UDim2.new(0, w + 2, 0, 48),
        }, 0.22)
    end

    function window:ToggleSidebar()
        sidebarCollapsed = not sidebarCollapsed
        applySidebar()
    end

    -- collapse toggle button in header (right side, before minimize)
    local collapseBtn = create("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -96, 0.5, -12),
        BackgroundColor3 = theme.Info,
        BackgroundTransparency = 0.6,
        Text = "=",
        TextColor3 = theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 7,
        AutoButtonColor = false,
        Parent = header
    })
    addCorner(collapseBtn, 6)
    collapseBtn.Visible = opts.SidebarToggle ~= false
    collapseBtn.MouseButton1Click:Connect(function()
        window:ToggleSidebar()
    end)
    collapseBtn.MouseEnter:Connect(function()
        tween(collapseBtn, {BackgroundTransparency = 0.2}, 0.15)
    end)
    collapseBtn.MouseLeave:Connect(function()
        tween(collapseBtn, {BackgroundTransparency = 0.6}, 0.15)
    end)

    -- ~~--------
    -- GESTURE: swipe to switch tabs on mobile
    -- ~~--------
    if mobile and opts.Gestures ~= false then
        local swipeStart
        contentArea.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then
                swipeStart = Vector2.new(inp.Position.X, inp.Position.Y)
            end
        end)
        contentArea.InputEnded:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.Touch or not swipeStart then return end
            local endP = Vector2.new(inp.Position.X, inp.Position.Y)
            local delta = endP - swipeStart
            swipeStart = nil
            if math.abs(delta.X) < 80 or math.abs(delta.Y) > 60 then return end
            -- find active idx
            local curIdx
            for i, t in window.Tabs do
                if t == window.ActiveTab then curIdx = i break end
            end
            if not curIdx then return end
            local newIdx
            if delta.X < 0 then
                newIdx = curIdx + 1
            else
                newIdx = curIdx - 1
            end
            if newIdx < 1 or newIdx > #window.Tabs then return end
            local nt = window.Tabs[newIdx]
            if nt and nt._btn then
                -- haptic
                if Velvet.Haptic then Velvet:Haptic("light") end
                pcall(function() firesignal(nt._btn.MouseButton1Click) end)
            end
        end)
    end

    -- ~~--------
    -- TAB
    -- ~~--------
    function window:AddTab(name, icon)
        local tabIdx = #self.Tabs + 1
        local tab = {
            Name = name,
            Sections = {},
            _elements = {},
        }

        -- resolve icon (can be lucide name, asset id, or url)
        local iconUrl = Velvet:ResolveIcon(icon)

        -- tab button
        local tabBtn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, mobile and 44 or 32),
            BackgroundColor3 = theme.Panel,
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = tabList
        })
        addCorner(tabBtn, 6)

        -- icon (if provided)
        local iconImg
        local iconSize = mobile and 20 or 14
        local textOffset = 10
        if iconUrl and mobile then
            -- mobile: icon centered top, text below
            iconImg = create("ImageLabel", {
                Size = UDim2.new(0, iconSize, 0, iconSize),
                Position = UDim2.new(0.5, -iconSize/2, 0, 4),
                BackgroundTransparency = 1,
                Image = iconUrl,
                ImageColor3 = theme.TextDim,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 7,
                Parent = tabBtn,
            })
        elseif iconUrl then
            -- pc: icon left, text right
            iconImg = create("ImageLabel", {
                Size = UDim2.new(0, iconSize, 0, iconSize),
                Position = UDim2.new(0, 8, 0.5, -iconSize/2),
                BackgroundTransparency = 1,
                Image = iconUrl,
                ImageColor3 = theme.TextDim,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 7,
                Parent = tabBtn,
            })
            textOffset = 8 + iconSize + 6
        end

        local tabLabel = create("TextLabel", {
            Size = mobile and UDim2.new(1, 0, 0, 12) or UDim2.new(1, -(textOffset + 4), 1, 0),
            Position = mobile and UDim2.new(0, 0, 1, -15) or UDim2.new(0, textOffset, 0, 0),
            BackgroundTransparency = 1,
            Text = mobile and name:sub(1, 3) or name,
            TextColor3 = theme.TextDim,
            TextSize = mobile and 9 or 12,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = mobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            ZIndex = 7,
            Parent = tabBtn
        })

        -- active toggle badge, top-right corner of tab btn
        local badge = create("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(1, -(mobile and 4 or 6), 0, mobile and 3 or 4),
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 8,
            Parent = tabBtn,
        })
        addCorner(badge, 7)
        local badgeLbl = create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "0",
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 9,
            Font = Enum.Font.GothamBold,
            ZIndex = 9,
            Parent = badge,
        })
        tab._badge = badge
        tab._badgeLbl = badgeLbl
        function tab:_refreshBadge()
            local n = 0
            for _, tg in self._toggles or {} do
                if tg.Get and tg:Get() then n = n + 1 end
            end
            if n > 0 then
                badge.Visible = true
                -- compact: 1234 -> 1.2k, 12345 -> 12k, 1234567 -> 1.2m
                local txt
                if n < 1000 then
                    txt = tostring(n)
                elseif n < 10000 then
                    txt = string.format("%.1fk", n/1000):gsub("%.0k$", "k")
                elseif n < 1000000 then
                    txt = string.format("%dk", math.floor(n/1000))
                elseif n < 10000000 then
                    txt = string.format("%.1fm", n/1000000):gsub("%.0m$", "m")
                else
                    txt = string.format("%dm", math.floor(n/1000000))
                end
                badgeLbl.Text = txt
                -- grow width with text length so it morphs from circle to pill
                local len = #txt
                local w = (len <= 1) and 14 or (10 + len * 5)
                tween(badge, {Size = UDim2.new(0, w, 0, 14)}, 0.18, Enum.EasingStyle.Back)
            else
                badge.Visible = false
            end
        end

        -- content scroll for this tab
        local tabContent = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = theme.Accent,
            ScrollBarImageTransparency = 0.5,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            ZIndex = 4,
            Parent = contentArea,
            Children = {
                create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 6),
                }),
                create("UIPadding", {
                    PaddingTop = UDim.new(0, 6),
                    PaddingBottom = UDim.new(0, 10),
                    PaddingLeft = UDim.new(0, 8),
                    PaddingRight = UDim.new(0, 8),
                })
            }
        })
        tab._content = tabContent
        tab._btn = tabBtn
        tab._label = tabLabel
        tab._icon = iconImg

        local function activate()
            -- deactivate all
            for _, t in self.Tabs do
                t._content.Visible = false
                tween(t._label, {TextColor3 = theme.TextDim}, 0.15)
                tween(t._btn, {BackgroundTransparency = 1}, 0.15)
                if t._icon then tween(t._icon, {ImageColor3 = theme.TextDim}, 0.15) end
            end
            -- activate this
            tabContent.Visible = true
            tween(tabLabel, {TextColor3 = theme.Text}, 0.15)
            tween(tabBtn, {BackgroundTransparency = 0.85}, 0.15)
            if iconImg then tween(iconImg, {ImageColor3 = theme.Text}, 0.15) end

            -- move indicator, center aligned to whatever the tab btn actually has (icon-only, text-only, or both)
            local btnH = mobile and 44 or 32
            local step = btnH + 2 -- list padding
            local listTop = 8 -- tabList offset (6) + padTop (2)
            local centerY = listTop + (tabIdx - 1) * step + btnH / 2
            local yPos = centerY - indicatorH / 2
            tween(tabIndicator, {Position = UDim2.new(0, 2, 0, yPos)}, 0.32, Enum.EasingStyle.Back)

            self.ActiveTab = tab
        end

        tabBtn.MouseButton1Click:Connect(activate)

        -- hover
        tabBtn.MouseEnter:Connect(function()
            if self.ActiveTab ~= tab then
                tween(tabBtn, {BackgroundTransparency = 0.9}, 0.1)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if self.ActiveTab ~= tab then
                tween(tabBtn, {BackgroundTransparency = 1}, 0.1)
            end
        end)

        table.insert(self.Tabs, tab)

        -- first tab auto-activate
        if tabIdx == 1 then
            task.defer(activate)
        end

        -- ~~----
        -- SUB-TABS (horizontal pill row inside a tab)
        -- ~~----
        tab.SubTabs = {}
        tab._activeSub = nil

        function tab:AddSubTab(subName)
            -- lazy init the sub-tab row
            if not tab._subRow then
                tab._subRow = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 34 or 28),
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    ZIndex = 5,
                    Parent = tabContent,
                })
                create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = tab._subRow,
                })
            end

            local subIdx = #tab.SubTabs + 1
            local sub = { Name = subName, _sections = {} }

            local subBtn = create("TextButton", {
                Size = UDim2.new(0, 0, 1, -4),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = theme.Surface,
                BackgroundTransparency = 0.6,
                Text = "",
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ZIndex = 6,
                LayoutOrder = subIdx,
                Parent = tab._subRow,
            })
            addCorner(subBtn, 6)
            create("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                Parent = subBtn,
            })
            local subLbl = create("TextLabel", {
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Text = subName,
                TextColor3 = theme.TextDim,
                TextSize = 11,
                Font = Enum.Font.GothamMedium,
                ZIndex = 7,
                Parent = subBtn,
            })

            -- container for this sub-tab's sections
            local subContainer = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = false,
                LayoutOrder = subIdx + 100,
                ZIndex = 4,
                Parent = tabContent,
            })
            create("UIListLayout", {
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = subContainer,
            })
            sub._container = subContainer

            local function activateSub()
                for _, s in tab.SubTabs do
                    if s._container then s._container.Visible = false end
                    if s._btn then
                        tween(s._btn, {BackgroundTransparency = 0.6}, 0.15)
                        tween(s._lbl, {TextColor3 = theme.TextDim}, 0.15)
                    end
                end
                subContainer.Visible = true
                tween(subBtn, {BackgroundTransparency = 0.1}, 0.15)
                tween(subLbl, {TextColor3 = theme.Text}, 0.15)
                tab._activeSub = sub
            end

            sub._btn = subBtn
            sub._lbl = subLbl
            subBtn.MouseButton1Click:Connect(activateSub)

            -- sections inside a subtab: proxy to container
            function sub:AddSection(name)
                -- temporarily redirect parent via an upvalue swap
                local oldContent = tabContent
                local swapped = subContainer
                -- hijack: build section then reparent
                local s = tab:AddSection(name)
                if s and s.Frame then
                    s.Frame.Parent = swapped
                end
                return s
            end

            table.insert(tab.SubTabs, sub)
            if subIdx == 1 then task.defer(activateSub) end
            return sub
        end

        -- ~~----
        -- SECTION
        -- ~~----
        function tab:AddSection(sectionName)
            local section = { Elements = {} }

            local sectionFrame = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = theme.Panel,
                BackgroundTransparency = 0.4,
                AutomaticSize = Enum.AutomaticSize.Y,
                ClipsDescendants = true,
                ZIndex = 5,
                Parent = tabContent
            })
            section.Frame = sectionFrame
            addCorner(sectionFrame, 10)
            addStroke(sectionFrame, theme.Border, 1, 0.55)
            -- accent rail on the left edge for a more premium feel
            create("Frame", {
                Size = UDim2.new(0, 2, 0, 16),
                Position = UDim2.new(0, 0, 0, 7),
                BackgroundColor3 = theme.Accent,
                BorderSizePixel = 0,
                ZIndex = 6,
                Parent = sectionFrame,
            })

            -- section header
            local sectionHeader = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 6,
                Parent = sectionFrame
            })

            create("TextLabel", {
                Size = UDim2.new(1, -20, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = sectionName or "Section",
                TextColor3 = theme.TextDim,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 7,
                Parent = sectionHeader
            })

            -- arrow
            local arrow = create("TextLabel", {
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(1, -24, 0, 0),
                BackgroundTransparency = 1,
                Text = "v",
                TextColor3 = theme.TextMuted,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                ZIndex = 7,
                Parent = sectionHeader
            })

            -- elements container
            local elemContainer = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 0, 30),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 5,
                Parent = sectionFrame,
                Children = {
                    create("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 4),
                    }),
                    create("UIPadding", {
                        PaddingTop = UDim.new(0, 2),
                        PaddingBottom = UDim.new(0, 8),
                        PaddingLeft = UDim.new(0, 10),
                        PaddingRight = UDim.new(0, 10),
                    })
                }
            })

            local collapsed = false
            sectionHeader.MouseButton1Click:Connect(function()
                collapsed = not collapsed
                tween(arrow, {Rotation = collapsed and -90 or 0}, 0.2)
                elemContainer.Visible = not collapsed
            end)

            section._container = elemContainer

            -- ===
            -- TOGGLE
            -- ===
            function section:AddToggle(id, opts)
                opts = opts or {}
                local value = opts.Default or false
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                create("TextLabel", {
                    Size = UDim2.new(1, -56, 1, 0),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                -- toggle track
                local track = create("Frame", {
                    Size = UDim2.new(0, 40, 0, 20),
                    Position = UDim2.new(1, -44, 0.5, -10),
                    BackgroundColor3 = theme.Surface,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(track, 10)
                addStroke(track, theme.Border, 1, 0.5)

                -- thumb
                local thumb = create("Frame", {
                    Size = UDim2.new(0, 16, 0, 16),
                    Position = UDim2.new(0, 2, 0.5, -8),
                    BackgroundColor3 = theme.TextDim,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                    Parent = track
                })
                addCorner(thumb, 8)

                local function update(v, silent)
                    value = v
                    if v then
                        tween(thumb, {Position = UDim2.new(0, 22, 0.5, -8), BackgroundColor3 = Color3.new(1,1,1)}, 0.28, Enum.EasingStyle.Back)
                        tween(track, {BackgroundColor3 = theme.Accent}, 0.2)
                    else
                        tween(thumb, {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = theme.TextDim}, 0.22)
                        tween(track, {BackgroundColor3 = theme.Surface}, 0.2)
                    end
                    Velvet.Flags[id] = v
                    fireListeners(id, v)
                    if not silent then safecall(`Toggle:{id}`, cb, v) end
                end

                -- click zone
                local clickBtn = create("TextButton", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 9,
                    Parent = elem
                })
                clickBtn.MouseButton1Click:Connect(function()
                    update(not value)
                end)

                update(value, true)

                local toggle = { Value = value }
                function toggle:Set(v) update(v) end
                function toggle:Get() return value end
                attachOnChanged(toggle, id)
                setupVisibility(toggle, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)

                Velvet._elements[id] = toggle
                table.insert(section.Elements, toggle)
                -- track for tab badge count
                tab._toggles = tab._toggles or {}
                table.insert(tab._toggles, toggle)
                Velvet:OnFlagChanged(id, function() if tab._refreshBadge then tab:_refreshBadge() end end)
                if tab._refreshBadge then tab:_refreshBadge() end
                return toggle
            end

            -- ===
            -- SLIDER
            -- ===
            function section:AddSlider(id, opts)
                opts = opts or {}
                local min = opts.Min or 0
                local max = opts.Max or 100
                local inc = opts.Increment or 1
                local suffix = opts.Suffix or ""
                local value = clamp(opts.Default or min, min, max)
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 48 or 42),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                local label = create("TextLabel", {
                    Size = UDim2.new(0.6, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                local valLabel = create("TextLabel", {
                    Size = UDim2.new(0.4, 0, 0, 16),
                    Position = UDim2.new(0.6, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(value) .. suffix,
                    TextColor3 = theme.Accent,
                    TextSize = 12,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7,
                    Parent = elem
                })

                -- track
                local sliderTrack = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 6),
                    Position = UDim2.new(0, 0, 0, mobile and 28 or 24),
                    BackgroundColor3 = theme.Surface,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(sliderTrack, 3)

                -- fill
                local fill = create("Frame", {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                    Parent = sliderTrack
                })
                addCorner(fill, 3)

                -- thumb circle
                local sliderThumb = create("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(0, 0, 0.5, -7),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 9,
                    Parent = sliderTrack
                })
                addCorner(sliderThumb, 7)

                local function update(v, silent)
                    v = round(clamp(v, min, max), inc)
                    value = v
                    local pct = (v - min) / (max - min)
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    sliderThumb.Position = UDim2.new(pct, -7, 0.5, -7)
                    valLabel.Text = tostring(v) .. suffix
                    Velvet.Flags[id] = v
                    fireListeners(id, v)
                    if not silent then safecall(`Slider:{id}`, cb, v) end
                end

                -- interaction
                local sliding = false
                local clickArea = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.new(0, 0, 0, mobile and 20 or 16),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 10,
                    Parent = elem
                })

                clickArea.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if Velvet._activeDrag and Velvet._activeDrag ~= "slider" then return end
                        sliding = true
                        Velvet._activeDrag = "slider"
                    end
                end)

                UserInputService.InputChanged:Connect(function(inp)
                    if not sliding then return end
                    if Velvet._activeDrag ~= "slider" then return end
                    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                        local absPos = sliderTrack.AbsolutePosition.X
                        local absSize = sliderTrack.AbsoluteSize.X
                        local rel = clamp((inp.Position.X - absPos) / absSize, 0, 1)
                        update(min + (max - min) * rel)
                    end
                end)

                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if sliding then
                            sliding = false
                            if Velvet._activeDrag == "slider" then Velvet._activeDrag = nil end
                        end
                    end
                end)

                update(value, true)

                local slider = { Value = value }
                function slider:Set(v) update(v) end
                function slider:Get() return value end
                attachOnChanged(slider, id)
                setupVisibility(slider, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)

                Velvet._elements[id] = slider
                table.insert(section.Elements, slider)
                return slider
            end

            -- ===
            -- BUTTON
            -- ===
            function section:AddButton(opts)
                opts = opts or {}
                local cb = opts.Callback or function() end

                local btn = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.3,
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 6,
                    Parent = elemContainer
                })
                addCorner(btn, 7)
                local btnStroke = addStroke(btn, theme.Border, 1, 0.55)

                create("TextLabel", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    Text = opts.Text or "Button",
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.GothamMedium,
                    ZIndex = 7,
                    Parent = btn
                })

                btn.MouseEnter:Connect(function()
                    tween(btn, {BackgroundTransparency = 0.08}, 0.15)
                    tween(btnStroke, {Color = theme.Accent, Transparency = 0.4}, 0.15)
                end)
                btn.MouseLeave:Connect(function()
                    tween(btn, {BackgroundTransparency = 0.3}, 0.15)
                    tween(btnStroke, {Color = theme.Border, Transparency = 0.55}, 0.15)
                end)
                btn.MouseButton1Click:Connect(function()
                    -- press flash + tiny scale pulse for haptic feel
                    tween(btn, {BackgroundColor3 = theme.Accent}, 0.08)
                    task.delay(0.12, function()
                        tween(btn, {BackgroundColor3 = theme.Surface}, 0.18)
                    end)
                    safecall(`Button:{opts.Text or "?"}`, cb)
                end)

                return btn
            end

            -- ===
            -- DROPDOWN
            -- ===
            function section:AddDropdown(id, opts)
                opts = opts or {}
                local values = opts.Values or {}
                local multi = opts.Multi or false
                local cb = opts.Callback or function() end
                local selected = multi and {} or (opts.Default or (values[1] or ""))

                if multi and opts.Default then
                    for _, v in opts.Default do selected[v] = true end
                end

                local hasTitle = opts.Text ~= nil
                local headerY = hasTitle and 16 or 0
                local elemH = (mobile and 38 or 32) + headerY

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, elemH),
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 6,
                    ClipsDescendants = false,
                    Parent = elemContainer
                })

                local header = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    Position = UDim2.new(0, 0, 0, headerY),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.3,
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(header, 6)
                addStroke(header, theme.Border, 1, 0.6)

                local function getDisplayText()
                    if multi then
                        local items = {}
                        for k, v in selected do
                            if v then table.insert(items, k) end
                        end
                        return #items > 0 and table.concat(items, ", ") or (opts.Text or "Select...")
                    else
                        return tostring(selected)
                    end
                end

                local headerLabel = create("TextLabel", {
                    Size = UDim2.new(1, -30, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = getDisplayText(),
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 8,
                    Parent = header
                })

                if hasTitle then
                    create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        Position = UDim2.new(0, 0, 0, 0),
                        BackgroundTransparency = 1,
                        Text = opts.Text,
                        TextColor3 = theme.TextDim,
                        TextSize = 10,
                        Font = Enum.Font.GothamMedium,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7,
                        Parent = elem
                    })
                end

                local dropArrow = create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(1, -24, 0, 0),
                    BackgroundTransparency = 1,
                    Text = "v",
                    TextColor3 = theme.TextMuted,
                    TextSize = 10,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 8,
                    Parent = header
                })

                -- dropdown list
                local dropFrame = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 0, headerY + (mobile and 42 or 36)),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.05,
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 20,
                    Parent = elem
                })
                addCorner(dropFrame, 6)
                addStroke(dropFrame, theme.Border, 1, 0.4)

                local dropList = create("ScrollingFrame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.Accent,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ZIndex = 21,
                    Parent = dropFrame,
                    Children = {
                        create("UIListLayout", {
                            SortOrder = Enum.SortOrder.LayoutOrder,
                            Padding = UDim.new(0, 1),
                        }),
                        create("UIPadding", {
                            PaddingTop = UDim.new(0, 3),
                            PaddingBottom = UDim.new(0, 3),
                            PaddingLeft = UDim.new(0, 4),
                            PaddingRight = UDim.new(0, 4),
                        })
                    }
                })

                local open = false

                local function refreshItems()
                    for _, c in dropList:GetChildren() do
                        if c:IsA("TextButton") then c:Destroy() end
                    end

                    for _, val in values do
                        local isSelected = multi and selected[val] or (selected == val)
                        local item = create("TextButton", {
                            Size = UDim2.new(1, 0, 0, mobile and 32 or 26),
                            BackgroundColor3 = isSelected and theme.Accent or theme.Panel,
                            BackgroundTransparency = isSelected and 0.6 or 0.8,
                            Text = "",
                            BorderSizePixel = 0,
                            AutoButtonColor = false,
                            ZIndex = 22,
                            Parent = dropList
                        })
                        addCorner(item, 4)

                        create("TextLabel", {
                            Size = UDim2.new(1, -10, 1, 0),
                            Position = UDim2.new(0, 8, 0, 0),
                            BackgroundTransparency = 1,
                            Text = tostring(val),
                            TextColor3 = isSelected and theme.Text or theme.TextDim,
                            TextSize = 12,
                            Font = Enum.Font.Gotham,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 23,
                            Parent = item
                        })

                        item.MouseEnter:Connect(function()
                            tween(item, {BackgroundTransparency = 0.5}, 0.1)
                        end)
                        item.MouseLeave:Connect(function()
                            local sel = multi and selected[val] or (selected == val)
                            tween(item, {BackgroundTransparency = sel and 0.6 or 0.8}, 0.1)
                        end)

                        item.MouseButton1Click:Connect(function()
                            if multi then
                                selected[val] = not selected[val]
                            else
                                selected = val
                                -- close
                                open = false
                                tween(dropFrame, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
                                task.delay(0.2, function() dropFrame.Visible = false end)
                                tween(dropArrow, {Rotation = 0}, 0.15)
                            end
                            headerLabel.Text = getDisplayText()
                            Velvet.Flags[id] = multi and selected or selected
                            fireListeners(id, multi and selected or selected)
                            refreshItems()
                            safecall(`Dropdown:{id}`, cb, multi and selected or selected)
                        end)
                    end
                end

                header.MouseButton1Click:Connect(function()
                    open = not open
                    if open then
                        refreshItems()
                        dropFrame.Visible = true
                        local itemH = mobile and 32 or 26
                        local h = math.min(#values * (itemH + 1) + 8, 180)
                        tween(dropFrame, {Size = UDim2.new(1, 0, 0, h)}, 0.2)
                        tween(dropArrow, {Rotation = 180}, 0.15)
                    else
                        tween(dropFrame, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
                        task.delay(0.2, function() dropFrame.Visible = false end)
                        tween(dropArrow, {Rotation = 0}, 0.15)
                    end
                end)

                Velvet.Flags[id] = selected
                refreshItems()

                local dropdown = { Value = selected }
                function dropdown:Set(v)
                    selected = v
                    headerLabel.Text = getDisplayText()
                    Velvet.Flags[id] = selected
                    fireListeners(id, selected)
                    refreshItems()
                end
                function dropdown:Refresh(newValues)
                    values = newValues
                    refreshItems()
                end
                function dropdown:Get() return selected end

                attachOnChanged(dropdown, id)
                setupVisibility(dropdown, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                Velvet._elements[id] = dropdown
                table.insert(section.Elements, dropdown)
                return dropdown
            end

            -- ===
            -- INPUT
            -- ===
            function section:AddInput(id, opts)
                opts = opts or {}
                local value = opts.Default or ""
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 56 or 48),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                if opts.Text then
                    create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = opts.Text,
                        TextColor3 = theme.TextDim,
                        TextSize = 10,
                        Font = Enum.Font.GothamMedium,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7,
                        Parent = elem
                    })
                end

                local inputBg = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 36 or 30),
                    Position = UDim2.new(0, 0, 1, mobile and -36 or -30),
                    BackgroundColor3 = theme.Surface,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(inputBg, 6)
                local inputStroke = addStroke(inputBg, theme.Border, 1, 0.5)

                local textBox = create("TextBox", {
                    Size = UDim2.new(1, -16, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1,
                    Text = value,
                    PlaceholderText = opts.Placeholder or "Type here...",
                    TextColor3 = theme.Text,
                    PlaceholderColor3 = theme.TextMuted,
                    TextSize = 12,
                    Font = Enum.Font.Code,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = false,
                    ZIndex = 8,
                    Parent = inputBg
                })

                textBox.Focused:Connect(function()
                    tween(inputStroke, {Color = theme.Accent, Transparency = 0}, 0.15)
                end)
                textBox.FocusLost:Connect(function(enterPressed)
                    tween(inputStroke, {Color = theme.Border, Transparency = 0.5}, 0.15)
                    value = textBox.Text
                    Velvet.Flags[id] = value
                    fireListeners(id, value)
                    safecall(`Input:{id}`, cb, value, enterPressed)
                end)

                Velvet.Flags[id] = value

                local input = { Value = value }
                function input:Set(v)
                    textBox.Text = v
                    value = v
                    Velvet.Flags[id] = v
                    fireListeners(id, v)
                end
                function input:Get() return value end

                attachOnChanged(input, id)
                setupVisibility(input, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                Velvet._elements[id] = input
                table.insert(section.Elements, input)
                return input
            end

            -- ===
            -- KEYBIND
            -- ===
            function section:AddKeybind(id, opts)
                opts = opts or {}
                local key = opts.Default or Enum.KeyCode.Unknown
                local mode = opts.Mode or "Toggle"
                local cb = opts.Callback or function() end
                local active = false
                local listening = false

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                create("TextLabel", {
                    Size = UDim2.new(1, -80, 1, 0),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                local bindBtn = create("TextButton", {
                    Size = UDim2.new(0, 70, 0, 24),
                    Position = UDim2.new(1, -74, 0.5, -12),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.3,
                    Text = key ~= Enum.KeyCode.Unknown and key.Name or "None",
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Font = Enum.Font.Code,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 8,
                    Parent = elem
                })
                addCorner(bindBtn, 4)
                addStroke(bindBtn, theme.Border, 1, 0.6)

                bindBtn.MouseButton1Click:Connect(function()
                    listening = true
                    bindBtn.Text = "..."
                    tween(bindBtn, {BackgroundColor3 = theme.Accent}, 0.15)
                end)

                UserInputService.InputBegan:Connect(function(inp, gpe)
                    if listening then
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            key = inp.KeyCode
                            bindBtn.Text = key.Name
                            listening = false
                            tween(bindBtn, {BackgroundColor3 = theme.Surface}, 0.15)
                            Velvet.Flags[id] = key
                            fireListeners(id, key)
                        end
                        return
                    end

                    if gpe then return end
                    if inp.KeyCode ~= key or key == Enum.KeyCode.Unknown then return end

                    if mode == "Toggle" then
                        active = not active
                        safecall(`Keybind:{id}`, cb, active)
                    elseif mode == "Hold" then
                        active = true
                        safecall(`Keybind:{id}`, cb, true)
                    end
                end)

                UserInputService.InputEnded:Connect(function(inp)
                    if mode == "Hold" and inp.KeyCode == key and active then
                        active = false
                        safecall(`Keybind:{id}`, cb, false)
                    end
                end)

                Velvet.Flags[id] = key

                local keybind = { Value = key, Active = active }
                function keybind:Set(k)
                    key = k
                    bindBtn.Text = k.Name
                    Velvet.Flags[id] = k
                    fireListeners(id, k)
                end
                function keybind:Get() return key end
                function keybind:IsActive() return active end

                attachOnChanged(keybind, id)
                setupVisibility(keybind, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                Velvet._elements[id] = keybind
                table.insert(section.Elements, keybind)
                return keybind
            end

            -- ===
            -- COLORPICKER
            -- ===
            function section:AddColorPicker(id, opts)
                opts = opts or {}
                local color = opts.Default or Color3.fromRGB(255, 255, 255)
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                create("TextLabel", {
                    Size = UDim2.new(1, -44, 1, 0),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                -- swatch preview
                local swatch = create("TextButton", {
                    Size = UDim2.new(0, 28, 0, 20),
                    Position = UDim2.new(1, -32, 0.5, -10),
                    BackgroundColor3 = color,
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 8,
                    Parent = elem
                })
                addCorner(swatch, 4)
                addStroke(swatch, theme.Border, 1, 0.4)

                -- picker popup (parented to gui so section ClipsDescendants doesn't clip it)
                local pickerOpen = false
                local pickerFrame = create("Frame", {
                    Size = UDim2.new(0, 180, 0, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.05,
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 100,
                    Parent = gui
                })
                addCorner(pickerFrame, 8)
                addStroke(pickerFrame, theme.Border, 1, 0.3)

                -- hue/sat canvas
                local canvas = create("Frame", {
                    Size = UDim2.new(1, -16, 0, 120),
                    Position = UDim2.new(0, 8, 0, 8),
                    BackgroundColor3 = Color3.new(1, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 31,
                    Parent = pickerFrame
                })
                addCorner(canvas, 4)

                -- sat overlay (white gradient left to right)
                local satOverlay = create("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 32,
                    Parent = canvas,
                    Children = {
                        create("UICorner", {CornerRadius = UDim.new(0, 4)}),
                        create("UIGradient", {
                            Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1)),
                            Transparency = NumberSequence.new(0, 1),
                            Rotation = 0,
                        })
                    }
                })

                -- val overlay (black gradient top to bottom)
                local valOverlay = create("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 33,
                    Parent = canvas,
                    Children = {
                        create("UICorner", {CornerRadius = UDim.new(0, 4)}),
                        create("UIGradient", {
                            Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0)),
                            Transparency = NumberSequence.new(1, 0),
                            Rotation = 90,
                        })
                    }
                })

                -- canvas cursor
                local cursor = create("Frame", {
                    Size = UDim2.new(0, 10, 0, 10),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 35,
                    Parent = canvas
                })
                addCorner(cursor, 5)
                addStroke(cursor, Color3.new(0,0,0), 1, 0)

                -- hue slider
                local hueBar = create("Frame", {
                    Size = UDim2.new(1, -16, 0, 12),
                    Position = UDim2.new(0, 8, 0, 134),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 31,
                    Parent = pickerFrame,
                    Children = {
                        create("UICorner", {CornerRadius = UDim.new(0, 6)}),
                        create("UIGradient", {
                            Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
                                ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167,1,1)),
                                ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333,1,1)),
                                ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5,1,1)),
                                ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667,1,1)),
                                ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833,1,1)),
                                ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1)),
                            })
                        })
                    }
                })

                local hueThumb = create("Frame", {
                    Size = UDim2.new(0, 4, 1, 2),
                    Position = UDim2.new(0, 0, 0, -1),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 33,
                    Parent = hueBar
                })
                addCorner(hueThumb, 2)

                -- hex input
                local hexBox = create("TextBox", {
                    Size = UDim2.new(1, -16, 0, 22),
                    Position = UDim2.new(0, 8, 0, 152),
                    BackgroundColor3 = theme.Panel,
                    Text = color3ToHex(color),
                    TextColor3 = theme.Text,
                    PlaceholderColor3 = theme.TextMuted,
                    TextSize = 11,
                    Font = Enum.Font.Code,
                    BorderSizePixel = 0,
                    ZIndex = 32,
                    Parent = pickerFrame
                })
                addCorner(hexBox, 4)

                -- state
                local h, s, v = Color3.toHSV(color)

                local function updateColor(silent)
                    color = Color3.fromHSV(h, s, v)
                    swatch.BackgroundColor3 = color
                    canvas.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    cursor.Position = UDim2.new(s, -5, 1 - v, -5)
                    hueThumb.Position = UDim2.new(h, -2, 0, -1)
                    hexBox.Text = color3ToHex(color)
                    Velvet.Flags[id] = color
                    fireListeners(id, color)
                    if not silent then safecall(`ColorPicker:{id}`, cb, color) end
                end

                -- canvas drag (claims mutex so slider underneath stays still)
                local canvasDrag = false
                canvas.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        canvasDrag = true
                        Velvet._activeDrag = "picker"
                    end
                end)
                UserInputService.InputChanged:Connect(function(inp)
                    if not canvasDrag then return end
                    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                        local pos = Vector2.new(inp.Position.X, inp.Position.Y)
                        s = clamp((pos.X - canvas.AbsolutePosition.X) / canvas.AbsoluteSize.X, 0, 1)
                        v = 1 - clamp((pos.Y - canvas.AbsolutePosition.Y) / canvas.AbsoluteSize.Y, 0, 1)
                        updateColor()
                    end
                end)
                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if canvasDrag then
                            canvasDrag = false
                            if Velvet._activeDrag == "picker" then Velvet._activeDrag = nil end
                        end
                    end
                end)

                -- hue drag
                local hueDrag = false
                hueBar.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        hueDrag = true
                        Velvet._activeDrag = "picker"
                    end
                end)
                UserInputService.InputChanged:Connect(function(inp)
                    if not hueDrag then return end
                    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                        h = clamp((inp.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
                        updateColor()
                    end
                end)
                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if hueDrag then
                            hueDrag = false
                            if Velvet._activeDrag == "picker" then Velvet._activeDrag = nil end
                        end
                    end
                end)

                -- hex input
                hexBox.FocusLost:Connect(function()
                    local ok, c = pcall(hexToColor3, hexBox.Text)
                    if ok and c then
                        h, s, v = Color3.toHSV(c)
                        updateColor()
                    end
                end)

                swatch.MouseButton1Click:Connect(function()
                    pickerOpen = not pickerOpen
                    if pickerOpen then
                        -- position next to swatch
                        local absPos = swatch.AbsolutePosition
                        local absSize = swatch.AbsoluteSize
                        local guiOff = gui.AbsolutePosition
                        local px = absPos.X - guiOff.X + absSize.X - 180
                        local py = absPos.Y - guiOff.Y + absSize.Y + 4
                        pickerFrame.Position = UDim2.new(0, px, 0, py)
                        pickerFrame.Visible = true
                        tween(pickerFrame, {Size = UDim2.new(0, 180, 0, 182)}, 0.2)
                    else
                        tween(pickerFrame, {Size = UDim2.new(0, 180, 0, 0)}, 0.15)
                        task.delay(0.15, function() pickerFrame.Visible = false end)
                    end
                end)

                updateColor(true)

                local picker = { Value = color }
                function picker:Set(c)
                    h, s, v = Color3.toHSV(c)
                    updateColor()
                end
                function picker:Get() return color end

                attachOnChanged(picker, id)
                setupVisibility(picker, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                Velvet._elements[id] = picker
                table.insert(section.Elements, picker)
                return picker
            end

            -- ===
            -- LABEL
            -- ===
            function section:AddLabel(text)
                -- accept table form too: AddLabel({ Text = "..." })
                if type(text) == "table" then text = text.Text or text.Title or "" end
                local lbl = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = tostring(text or ""),
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elemContainer
                })
                local label = {}
                function label:Set(t) lbl.Text = t end
                return label
            end

            -- ===
            -- DIVIDER
            -- ===
            function section:AddDivider()
                create("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = theme.Border,
                    BackgroundTransparency = 0.5,
                    BorderSizePixel = 0,
                    ZIndex = 6,
                    Parent = elemContainer
                })
            end

            -- ===
            -- PARAGRAPH
            -- ===
            function section:AddParagraph(opts)
                opts = opts or {}
                local frame = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                if opts.Title then
                    create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 16),
                        BackgroundTransparency = 1,
                        Text = opts.Title,
                        TextColor3 = theme.Text,
                        TextSize = 12,
                        Font = Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7,
                        Parent = frame
                    })
                end

                local bodyLbl = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 0, opts.Title and 18 or 0),
                    BackgroundTransparency = 1,
                    Text = opts.Content or "",
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 7,
                    Parent = frame
                })

                local para = {}
                function para:Set(txt) bodyLbl.Text = txt end
                return para
            end

            -- ===
            -- PROGRESS BAR
            -- ===
            function section:AddProgressBar(id, opts)
                opts = opts or {}
                local progress = opts.Default or 0
                local maxVal = opts.Max or 100
                local showText = opts.ShowText ~= false

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                local topLbl = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.TextDim,
                    TextSize = 10,
                    Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                local barBg = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 12),
                    Position = UDim2.new(0, 0, 0, 18),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(barBg, 4)
                addStroke(barBg, theme.Border, 1, 0.6)

                local fill = create("Frame", {
                    Size = UDim2.new(math.clamp(progress / maxVal, 0, 1), 0, 1, 0),
                    BackgroundColor3 = opts.Color or theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                    Parent = barBg
                })

                local pctLbl
                if showText then
                    pctLbl = create("TextLabel", {
                        Size = UDim2.new(0, 50, 0, 14),
                        Position = UDim2.new(1, -50, 0, 0),
                        BackgroundTransparency = 1,
                        Text = tostring(math.floor(progress)) .. "/" .. tostring(maxVal),
                        TextColor3 = theme.TextDim,
                        TextSize = 10,
                        Font = Enum.Font.Code,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        ZIndex = 7,
                        Parent = elem
                    })
                end

                Velvet.Flags[id] = progress

                local bar = { Value = progress }
                function bar:Set(v)
                    progress = math.clamp(v, 0, maxVal)
                    tween(fill, {Size = UDim2.new(progress / maxVal, 0, 1, 0)}, 0.12)
                    if pctLbl then pctLbl.Text = tostring(math.floor(progress)) .. "/" .. tostring(maxVal) end
                    Velvet.Flags[id] = progress
                    fireListeners(id, progress)
                end
                function bar:SetMax(m)
                    maxVal = m
                    bar:Set(progress)
                end
                function bar:SetColor(c) fill.BackgroundColor3 = c end
                function bar:Get() return progress end

                attachOnChanged(bar, id)
                setupVisibility(bar, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                Velvet._elements[id] = bar
                table.insert(section.Elements, bar)
                return bar
            end

            -- ===
            -- LOG / CONSOLE
            -- ===
            function section:AddLog(opts)
                opts = opts or {}
                local maxLines = opts.MaxLines or 50
                local lines = {}

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, opts.Height or 120),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    ZIndex = 6,
                    Parent = elemContainer
                })
                addCorner(elem, 4)
                addStroke(elem, theme.Border, 1, 0.6)

                local scroll = create("ScrollingFrame", {
                    Size = UDim2.new(1, -8, 1, -8),
                    Position = UDim2.new(0, 4, 0, 4),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.Border,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    ZIndex = 7,
                    Parent = elem
                })

                local layout = create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1),
                    Parent = scroll
                })

                local log = {}
                local function append(txt, color)
                    if #lines >= maxLines then
                        local first = lines[1]
                        if first then first:Destroy() end
                        table.remove(lines, 1)
                    end
                    local line = create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = txt,
                        TextColor3 = color or theme.TextDim,
                        TextSize = 11,
                        Font = Enum.Font.Code,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        LayoutOrder = #lines + 1,
                        ZIndex = 8,
                        Parent = scroll
                    })
                    table.insert(lines, line)
                    task.defer(function()
                        scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
                    end)
                end

                function log:Info(txt)  append("[i] " .. tostring(txt), theme.Text) end
                function log:Warn(txt)  append("[!] " .. tostring(txt), Color3.fromRGB(255, 200, 90)) end
                function log:Error(txt) append("[x] " .. tostring(txt), Color3.fromRGB(255, 90, 90)) end
                function log:Success(txt) append("[+] " .. tostring(txt), Color3.fromRGB(120, 230, 140)) end
                function log:Print(txt, color) append(tostring(txt), color) end
                function log:Clear()
                    for _, l in lines do l:Destroy() end
                    table.clear(lines)
                end

                table.insert(section.Elements, log)
                return log
            end

            -- ===
            -- PLAYER SELECTOR (dropdown preloaded with players + auto-refresh)
            -- ===
            function section:AddPlayerSelector(id, opts)
                opts = opts or {}
                local excludeSelf = opts.ExcludeSelf ~= false
                local multi = opts.Multi or false

                local function buildList()
                    local list = {}
                    if not excludeSelf then table.insert(list, "@me") end
                    table.insert(list, "@random")
                    table.insert(list, "@nearest")
                    for _, p in pairs(Players:GetPlayers()) do
                        if not excludeSelf or p ~= Players.LocalPlayer then
                            table.insert(list, p.Name)
                        end
                    end
                    return list
                end

                local dropOpts = {
                    Text = opts.Text or "Select Player",
                    Values = buildList(),
                    Default = opts.Default or (multi and {} or ""),
                    Multi = multi,
                    Callback = opts.Callback,
                    VisibleWhen = opts.VisibleWhen,
                }

                local dd = section:AddDropdown(id, dropOpts)

                -- auto-refresh on join/leave
                local conn1 = Players.PlayerAdded:Connect(function() dd:Refresh(buildList()) end)
                local conn2 = Players.PlayerRemoving:Connect(function() dd:Refresh(buildList()) end)

                function dd:GetPlayers()
                    local sel = dd:Get()
                    if type(sel) == "string" then
                        if sel == "@me" then return {Players.LocalPlayer}
                        elseif sel == "@random" then
                            local list = {}
                            for _, p in pairs(Players:GetPlayers()) do
                                if p ~= Players.LocalPlayer then table.insert(list, p) end
                            end
                            return #list > 0 and {list[math.random(1, #list)]} or {}
                        elseif sel == "@nearest" then
                            local lp = Players.LocalPlayer
                            local myChar = lp.Character
                            if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return {} end
                            local myPos = myChar.HumanoidRootPart.Position
                            local best, bd = nil, math.huge
                            for _, p in pairs(Players:GetPlayers()) do
                                if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                    local d = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                                    if d < bd then best, bd = p, d end
                                end
                            end
                            return best and {best} or {}
                        else
                            local p = Players:FindFirstChild(sel)
                            return p and {p} or {}
                        end
                    elseif type(sel) == "table" then
                        local out = {}
                        for name, on in pairs(sel) do
                            if on then
                                local p = Players:FindFirstChild(name)
                                if p then table.insert(out, p) end
                            end
                        end
                        return out
                    end
                    return {}
                end

                return dd
            end

            table.insert(tab.Sections, section)
            return section
        end

        return tab
    end

    table.insert(self.Windows, window)
    return window
end

-- theme setter with live recolor
function Velvet:SetTheme(themeTable)
    -- build old->new color map
    local colorMap = {}
    for k, v in themeTable do
        if typeof(v) == "Color3" and typeof(self.Theme[k]) == "Color3" then
            local old = self.Theme[k]
            colorMap[string.format("%d_%d_%d", math.floor(old.R*255+.5), math.floor(old.G*255+.5), math.floor(old.B*255+.5))] = v
        end
        self.Theme[k] = v
    end

    -- recolor all descendants of VelvetUI + VelvetNotifs
    local colorProps = {"BackgroundColor3", "TextColor3", "PlaceholderColor3", "ImageColor3", "ScrollBarImageColor3"}
    local containers = {}
    pcall(function()
        for _, g in gethui():GetChildren() do
            if g.Name == "VelvetUI" or g.Name == "VelvetNotifs" then
                table.insert(containers, g)
            end
        end
    end)

    for _, container in containers do
        for _, desc in container:GetDescendants() do
            for _, prop in colorProps do
                pcall(function()
                    local cur = desc[prop]
                    if typeof(cur) == "Color3" then
                        local key = string.format("%d_%d_%d", math.floor(cur.R*255+.5), math.floor(cur.G*255+.5), math.floor(cur.B*255+.5))
                        if colorMap[key] then
                            desc[prop] = colorMap[key]
                        end
                    end
                end)
            end
            -- UIStroke
            if desc:IsA("UIStroke") then
                pcall(function()
                    local cur = desc.Color
                    local key = string.format("%d_%d_%d", math.floor(cur.R*255+.5), math.floor(cur.G*255+.5), math.floor(cur.B*255+.5))
                    if colorMap[key] then desc.Color = colorMap[key] end
                end)
            end
        end
    end

    -- also update watermark if exists
    if self._watermark then
        pcall(function()
            for _, desc in self._watermark:GetDescendants() do
                for _, prop in colorProps do
                    pcall(function()
                        local cur = desc[prop]
                        if typeof(cur) == "Color3" then
                            local key = string.format("%d_%d_%d", math.floor(cur.R*255+.5), math.floor(cur.G*255+.5), math.floor(cur.B*255+.5))
                            if colorMap[key] then desc[prop] = colorMap[key] end
                        end
                    end)
                end
            end
        end)
    end
end

function Velvet:GetTheme()
    return self.Theme
end

-- ~~
-- WATERMARK / HUD
-- ~~
function Velvet:CreateWatermark(opts)
    opts = opts or {}
    local theme = self.Theme

    -- kill old
    if self._watermark then
        pcall(function() self._watermark:Destroy() end)
    end

    local frame = create("Frame", {
        Name = "VelvetWatermark",
        Size = UDim2.new(0, 200, 0, 26),
        Position = opts.Position or UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 200,
        Parent = gui
    })
    addCorner(frame, 6)
    addStroke(frame, theme.Accent, 1, 0.4)

    local pad = create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = frame,
    })

    local lbl = create("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = opts.Text or "Velvet | {fps} fps | {ping} ms",
        TextColor3 = theme.Text,
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
        Parent = frame,
    })

    self._watermark = frame

    -- live update
    local template = opts.Text or "Velvet | {fps} fps | {ping} ms"
    local lastTick = tick()
    local frames = 0
    local fps = 60

    local RS = game:GetService("RunService")
    local stats = game:GetService("Stats")
    local lp = Players.LocalPlayer

    local conn
    conn = RS.RenderStepped:Connect(function()
        frames = frames + 1
        local now = tick()
        if now - lastTick >= 0.5 then
            fps = math.floor(frames / (now - lastTick))
            frames = 0
            lastTick = now
        end

        local ping = 0
        pcall(function()
            ping = math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)

        local txt = template
        txt = txt:gsub("{fps}", tostring(fps))
        txt = txt:gsub("{ping}", tostring(ping))
        txt = txt:gsub("{time}", os.date("%H:%M:%S"))
        txt = txt:gsub("{user}", lp and lp.Name or "?")
        txt = txt:gsub("{place}", tostring(game.PlaceId))

        -- substitute flags
        txt = txt:gsub("{flag:([%w_]+)}", function(flag)
            local v = Velvet.Flags[flag]
            if v == nil then return "?" end
            return tostring(v)
        end)

        lbl.Text = txt
    end)

    local watermark = {}
    function watermark:SetText(t) template = t end
    function watermark:SetPosition(p) frame.Position = p end
    function watermark:Destroy()
        if conn then conn:Disconnect() end
        pcall(function() frame:Destroy() end)
        Velvet._watermark = nil
    end
    function watermark:Show() frame.Visible = true end
    function watermark:Hide() frame.Visible = false end

    return watermark
end

-- ~~
-- HAPTIC FEEDBACK (mobile-ish, uses HapticService + visual flash)
-- ~~
function Velvet:Haptic(strength)
    -- strength: "light" | "medium" | "heavy"
    strength = strength or "light"
    local HapticService = game:GetService("HapticService")
    pcall(function()
        local motor = Enum.VibrationMotor.Large
        local amp = strength == "heavy" and 1 or strength == "medium" and 0.6 or 0.3
        -- try all gamepads
        for _, gp in pairs(Enum.UserInputType:GetEnumItems()) do
            if tostring(gp):find("Gamepad") then
                pcall(function()
                    HapticService:SetMotor(gp, motor, amp)
                    task.delay(0.05, function()
                        pcall(function() HapticService:SetMotor(gp, motor, 0) end)
                    end)
                end)
            end
        end
    end)
end

-- ~~
-- AUTO-UPDATE CHECK (fetches latest tag from github)
-- ~~
function Velvet:CheckForUpdate(repo)
    repo = repo or "DexCodeSX/Velvet"
    local url = "https://api.github.com/repos/" .. repo .. "/releases/latest"
    local ok, resp = pcall(function()
        if request then
            return request({Url = url, Method = "GET"})
        elseif http_request then
            return http_request({Url = url, Method = "GET"})
        end
    end)
    if not ok or not resp or not resp.Body then return nil end
    local HttpService = game:GetService("HttpService")
    local okDec, data = pcall(function() return HttpService:JSONDecode(resp.Body) end)
    if not okDec or not data.tag_name then return nil end
    return {
        latest = data.tag_name,
        current = self._version,
        outdated = data.tag_name ~= self._version,
        url = data.html_url,
        body = data.body,
    }
end

-- ~~
-- TOOLTIP helper (attach to any GuiObject)
-- ~~
function Velvet:AttachTooltip(guiObj, text)
    if not guiObj or not text then return end
    local theme = self.Theme
    local tip
    local function show()
        if tip then pcall(function() tip:Destroy() end) end
        tip = create("Frame", {
            Name = "VelvetTooltip",
            Size = UDim2.new(0, 0, 0, 22),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = theme.Base,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ZIndex = 250,
            Parent = gui,
        })
        addCorner(tip, 4)
        addStroke(tip, theme.Border, 1, 0.5)
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            Parent = tip,
        })
        create("TextLabel", {
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = theme.Text,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            ZIndex = 251,
            Parent = tip,
        })
        local pos = guiObj.AbsolutePosition
        local sz = guiObj.AbsoluteSize
        tip.Position = UDim2.new(0, pos.X, 0, pos.Y + sz.Y + 4)
    end
    local function hide()
        if tip then pcall(function() tip:Destroy() end) tip = nil end
    end
    guiObj.MouseEnter:Connect(show)
    guiObj.MouseLeave:Connect(hide)
    if guiObj:IsA("GuiButton") then
        guiObj.MouseButton1Click:Connect(hide)
    end
end

-- cleanup: destroy all velvet windows, clear listeners, disconnect everything
function Velvet:Destroy()
    -- fire cleanup listener if registered
    if self._onDestroy then
        for _, fn in self._onDestroy do pcall(fn) end
    end

    -- destroy all tracked connections
    if self._connections then
        for _, c in self._connections do
            pcall(function() c:Disconnect() end)
        end
        table.clear(self._connections)
    end

    -- nuke watermark if exists
    if self._watermark then
        pcall(function() self._watermark:Destroy() end)
        self._watermark = nil
    end

    -- destroy all window screengui's
    for _, w in self.Windows do
        if w and w.ScreenGui then
            pcall(function() w.ScreenGui:Destroy() end)
        end
    end

    -- also blow away any leftover gui under gethui named Velvet/VelvetUI/VelvetNotifs
    local hui = (gethui and gethui()) or game:GetService("CoreGui")
    for _, g in pairs(hui:GetChildren()) do
        if g.Name == "Velvet" or g.Name == "VelvetUI" or g.Name == "VelvetNotifs" then
            pcall(function() g:Destroy() end)
        end
    end

    table.clear(self.Windows)
    table.clear(self.Flags)
    table.clear(self._listeners)
    table.clear(self._elements)
end

function Velvet:OnDestroy(fn)
    if not self._onDestroy then self._onDestroy = {} end
    table.insert(self._onDestroy, fn)
end

return Velvet
