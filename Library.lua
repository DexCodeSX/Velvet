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
    _version = "1.0.0"
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
    local tw = TweenService:Create(obj, TweenInfo.new(dur or 0.25, style or Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), props)
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
    DisplayOrder = 999
})
pcall(function() gui.Parent = gethui() end)
if not gui.Parent then
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- notification container (top right)
local notifHolder = create("Frame", {
    Name = "Notifications",
    Size = UDim2.new(0, 300, 1, 0),
    Position = UDim2.new(1, -310, 0, 10),
    BackgroundTransparency = 1,
    Parent = gui,
    Children = {
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        })
    }
})

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

------------------------------------------------------------------------
-- WINDOW
------------------------------------------------------------------------
function Velvet:CreateWindow(opts)
    opts = opts or {}
    local theme = self.Theme
    local mobile = isMobile()
    local screen = getScreenSize()

    local winW = opts.Width or (mobile and math.min(screen.X - 20, 380) or 560)
    local winH = opts.Height or (mobile and math.min(screen.Y - 80, 420) or 400)
    local tabW = opts.TabWidth or (mobile and 44 or 150)

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
    addCorner(main, 12)
    addStroke(main, theme.Border, 1, 0.3)
    window._main = main

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

    -- top accent line
    create("Frame", {
        Size = UDim2.new(0, 50, 0, 2),
        Position = UDim2.new(0.5, -25, 0, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = main
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

    -- logo dot
    local logoDot = create("Frame", {
        Size = UDim2.new(0, 7, 0, 7),
        Position = UDim2.new(0, 16, 0.5, -3),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = header
    })
    addCorner(logoDot, 4)

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

    -- active tab indicator
    local tabIndicator = create("Frame", {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 2, 0, 12),
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
    local togglePill = create("TextButton", {
        Name = "VelvetToggle",
        Size = UDim2.new(0, mobile and 48 or 36, 0, mobile and 48 or 36),
        Position = UDim2.new(0, 12, 0.5, mobile and -24 or -18),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.15,
        Text = "V",
        TextColor3 = theme.Text,
        TextSize = mobile and 18 or 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 100,
        Visible = false,
        Parent = gui
    })
    addCorner(togglePill, mobile and 24 or 18)
    addStroke(togglePill, theme.Accent, 1, 0.3)

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

    -- close / minimize
    closeBtn.MouseButton1Click:Connect(function()
        window:Hide()
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

    -----------------------------------------------------------------------
    -- TAB
    -----------------------------------------------------------------------
    function window:AddTab(name, icon)
        local tabIdx = #self.Tabs + 1
        local tab = {
            Name = name,
            Sections = {},
            _elements = {},
        }

        -- tab button
        local tabBtn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, mobile and 40 or 32),
            BackgroundColor3 = theme.Panel,
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = tabList
        })
        addCorner(tabBtn, 6)

        local tabLabel = create("TextLabel", {
            Size = UDim2.new(1, mobile and 0 or -12, 1, 0),
            Position = UDim2.new(0, mobile and 0 or 10, 0, 0),
            BackgroundTransparency = 1,
            Text = mobile and (name:sub(1,2)) or name,
            TextColor3 = theme.TextDim,
            TextSize = mobile and 13 or 12,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = mobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            ZIndex = 7,
            Parent = tabBtn
        })

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

        local function activate()
            -- deactivate all
            for _, t in self.Tabs do
                t._content.Visible = false
                tween(t._label, {TextColor3 = theme.TextDim}, 0.15)
                tween(t._btn, {BackgroundTransparency = 1}, 0.15)
            end
            -- activate this
            tabContent.Visible = true
            tween(tabLabel, {TextColor3 = theme.Text}, 0.15)
            tween(tabBtn, {BackgroundTransparency = 0.85}, 0.15)

            -- move indicator
            local yPos = (tabIdx - 1) * (mobile and 42 or 34) + (mobile and 12 or 8)
            tween(tabIndicator, {Position = UDim2.new(0, 2, 0, yPos)}, 0.2)

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

        -------------------------------------------------------------------
        -- SECTION
        -------------------------------------------------------------------
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
            addCorner(sectionFrame, 8)
            addStroke(sectionFrame, theme.Border, 1, 0.6)

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

            ---------------------------------------------------------------
            -- TOGGLE
            ---------------------------------------------------------------
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
                        tween(thumb, {Position = UDim2.new(0, 22, 0.5, -8), BackgroundColor3 = Color3.new(1,1,1)}, 0.2)
                        tween(track, {BackgroundColor3 = theme.Accent}, 0.2)
                    else
                        tween(thumb, {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = theme.TextDim}, 0.2)
                        tween(track, {BackgroundColor3 = theme.Surface}, 0.2)
                    end
                    Velvet.Flags[id] = v
                    if not silent then task.spawn(cb, v) end
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
                function toggle:Set(v)
                    update(v)
                end
                function toggle:Get() return value end

                table.insert(section.Elements, toggle)
                return toggle
            end

            ---------------------------------------------------------------
            -- SLIDER
            ---------------------------------------------------------------
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
                    local trackW = sliderTrack.AbsoluteSize.X
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    sliderThumb.Position = UDim2.new(0, math.max(0, pct * trackW - 7), 0.5, -7)
                    valLabel.Text = tostring(v) .. suffix
                    Velvet.Flags[id] = v
                    if not silent then task.spawn(cb, v) end
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
                        sliding = true
                    end
                end)

                UserInputService.InputChanged:Connect(function(inp)
                    if not sliding then return end
                    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                        local absPos = sliderTrack.AbsolutePosition.X
                        local absSize = sliderTrack.AbsoluteSize.X
                        local rel = clamp((inp.Position.X - absPos) / absSize, 0, 1)
                        update(min + (max - min) * rel)
                    end
                end)

                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)

                update(value, true)

                local slider = { Value = value }
                function slider:Set(v) update(v) end
                function slider:Get() return value end

                table.insert(section.Elements, slider)
                return slider
            end

            ---------------------------------------------------------------
            -- BUTTON
            ---------------------------------------------------------------
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
                addCorner(btn, 6)
                addStroke(btn, theme.Border, 1, 0.6)

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
                    tween(btn, {BackgroundTransparency = 0.1}, 0.1)
                end)
                btn.MouseLeave:Connect(function()
                    tween(btn, {BackgroundTransparency = 0.3}, 0.1)
                end)
                btn.MouseButton1Click:Connect(function()
                    -- press flash
                    tween(btn, {BackgroundColor3 = theme.Accent}, 0.08)
                    task.delay(0.12, function()
                        tween(btn, {BackgroundColor3 = theme.Surface}, 0.15)
                    end)
                    task.spawn(cb)
                end)

                return btn
            end

            ---------------------------------------------------------------
            -- DROPDOWN
            ---------------------------------------------------------------
            function section:AddDropdown(id, opts)
                opts = opts or {}
                local values = opts.Values or {}
                local multi = opts.Multi or false
                local cb = opts.Callback or function() end
                local selected = multi and {} or (opts.Default or (values[1] or ""))

                if multi and opts.Default then
                    for _, v in opts.Default do selected[v] = true end
                end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 32),
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 6,
                    ClipsDescendants = false,
                    Parent = elemContainer
                })

                local header = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
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

                -- title above
                if opts.Text then
                    create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        Position = UDim2.new(0, 0, 0, -16),
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
                    Position = UDim2.new(0, 0, 0, mobile and 42 or 36),
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
                            refreshItems()
                            task.spawn(cb, multi and selected or selected)
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
                    refreshItems()
                end
                function dropdown:Refresh(newValues)
                    values = newValues
                    refreshItems()
                end
                function dropdown:Get() return selected end

                table.insert(section.Elements, dropdown)
                return dropdown
            end

            ---------------------------------------------------------------
            -- INPUT
            ---------------------------------------------------------------
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
                    task.spawn(cb, value, enterPressed)
                end)

                Velvet.Flags[id] = value

                local input = { Value = value }
                function input:Set(v)
                    textBox.Text = v
                    value = v
                    Velvet.Flags[id] = v
                end
                function input:Get() return value end

                table.insert(section.Elements, input)
                return input
            end

            ---------------------------------------------------------------
            -- KEYBIND
            ---------------------------------------------------------------
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
                        end
                        return
                    end

                    if gpe then return end
                    if inp.KeyCode ~= key or key == Enum.KeyCode.Unknown then return end

                    if mode == "Toggle" then
                        active = not active
                        task.spawn(cb, active)
                    elseif mode == "Hold" then
                        active = true
                        task.spawn(cb, true)
                    end
                end)

                UserInputService.InputEnded:Connect(function(inp)
                    if mode == "Hold" and inp.KeyCode == key and active then
                        active = false
                        task.spawn(cb, false)
                    end
                end)

                Velvet.Flags[id] = key

                local keybind = { Value = key, Active = active }
                function keybind:Set(k)
                    key = k
                    bindBtn.Text = k.Name
                    Velvet.Flags[id] = k
                end
                function keybind:Get() return key end
                function keybind:IsActive() return active end

                table.insert(section.Elements, keybind)
                return keybind
            end

            ---------------------------------------------------------------
            -- COLORPICKER
            ---------------------------------------------------------------
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

                -- picker popup
                local pickerOpen = false
                local pickerFrame = create("Frame", {
                    Size = UDim2.new(0, 180, 0, 0),
                    Position = UDim2.new(1, -184, 0, mobile and 40 or 34),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.05,
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 30,
                    Parent = elem
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
                    if not silent then task.spawn(cb, color) end
                end

                -- canvas drag
                local canvasDrag = false
                canvas.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        canvasDrag = true
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
                        canvasDrag = false
                    end
                end)

                -- hue drag
                local hueDrag = false
                hueBar.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        hueDrag = true
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
                        hueDrag = false
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

                table.insert(section.Elements, picker)
                return picker
            end

            ---------------------------------------------------------------
            -- LABEL
            ---------------------------------------------------------------
            function section:AddLabel(text)
                local lbl = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = text or "",
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

            ---------------------------------------------------------------
            -- DIVIDER
            ---------------------------------------------------------------
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

            ---------------------------------------------------------------
            -- PARAGRAPH
            ---------------------------------------------------------------
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

                create("TextLabel", {
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
            end

            table.insert(tab.Sections, section)
            return section
        end

        return tab
    end

    table.insert(self.Windows, window)
    return window
end

-- theme setter
function Velvet:SetTheme(themeTable)
    for k, v in themeTable do
        self.Theme[k] = v
    end
end

function Velvet:GetTheme()
    return self.Theme
end

return Velvet
