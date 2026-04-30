--[[
    Velvet QuickBar
    Floating draggable dock with pinned toggles + buttons.
    Visible when window is hidden. One tap fires the toggle/button.

    Each pin is a tile (iOS Control Center style):
        - toggle: icon glows accent when ON, dims when OFF
        - button: solid accent tile, fires callback on tap
        - the open-window tile is always first

    API:
        QuickBar:Bind(Velvet, Window, { MaxPins = 5, Position = UDim2.new(...) })
        QuickBar:Pin("AimbotEnabled", { Icon = "crosshair" })
        QuickBar:PinButton("Reset", { Icon = "rotate-ccw", Callback = fn })
        QuickBar:Unpin("AimbotEnabled")
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local QuickBar = {
    Library = nil,
    Window = nil,
    _pins = {},
    _cells = {},
    _bar = nil,
    _gui = nil,
    _maxPins = 5,
    _file = "VelvetQuickBar.json",
    _conns = {},
    _tip = nil,
}

-- ── helpers ──────────────────────────────────────────────

local function tw(obj, props, dur, style)
    local ti = TweenInfo.new(dur or 0.18, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thick or 1
    s.Transparency = trans or 0.5
    s.Parent = parent
    return s
end

local function conn(signal, fn)
    local c = signal:Connect(fn)
    table.insert(QuickBar._conns, c)
    return c
end

local function lucide(name, fallback)
    local lib = QuickBar.Library
    if lib and lib._icons and lib._icons[name] then
        return lib._icons[name]
    end
    return fallback or ""
end

-- ── persistence ────────────���─────────────────────────────
-- pin entries: { type = "toggle", id = "...", icon = "..." } or { type = "button", label = "...", icon = "..." }
-- buttons are NOT persisted (callbacks aren't serializable), only toggles save

local function savePins()
    pcall(function()
        local saveable = {}
        for _, p in QuickBar._pins do
            if p.type == "toggle" then
                table.insert(saveable, { id = p.id, icon = p.icon })
            end
        end
        writefile(QuickBar._file, HttpService:JSONEncode(saveable))
    end)
end

local function loadPins()
    pcall(function()
        if isfile(QuickBar._file) then
            local raw = readfile(QuickBar._file)
            local data = HttpService:JSONDecode(raw)
            if type(data) == "table" then
                local out = {}
                for _, e in data do
                    if type(e) == "string" then
                        table.insert(out, { type = "toggle", id = e })
                    elseif type(e) == "table" and e.id then
                        table.insert(out, { type = "toggle", id = e.id, icon = e.icon })
                    end
                end
                QuickBar._pins = out
            end
        end
    end)
end

-- ── tooltip (floating label below the bar) ────────────────

local function ensureTooltip()
    if QuickBar._tip then return QuickBar._tip end
    local tip = Instance.new("Frame")
    tip.Name = "Tip"
    tip.AutomaticSize = Enum.AutomaticSize.X
    tip.Size = UDim2.new(0, 0, 0, 22)
    tip.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    tip.BackgroundTransparency = 0.05
    tip.BorderSizePixel = 0
    tip.Visible = false
    tip.ZIndex = 110
    tip.Parent = QuickBar._gui
    corner(tip, 6)
    stroke(tip, QuickBar.Library.Theme.Border, 1, 0.4)

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.AutomaticSize = Enum.AutomaticSize.X
    lbl.Size = UDim2.new(0, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = QuickBar.Library.Theme.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.ZIndex = 111
    lbl.Parent = tip

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = lbl

    QuickBar._tip = tip
    QuickBar._tipLbl = lbl
    return tip
end

local function showTip(cell, text)
    local tip = ensureTooltip()
    QuickBar._tipLbl.Text = text
    tip.Visible = true
    -- position below the cell, centered
    task.defer(function()
        if not tip.Parent then return end
        local cx = cell.AbsolutePosition.X + cell.AbsoluteSize.X/2
        local cy = cell.AbsolutePosition.Y + cell.AbsoluteSize.Y + 8
        tip.Position = UDim2.new(0, cx - tip.AbsoluteSize.X/2, 0, cy)
        tip.BackgroundTransparency = 1
        tw(tip, { BackgroundTransparency = 0.05 }, 0.12)
    end)
end

local function hideTip()
    if QuickBar._tip then QuickBar._tip.Visible = false end
end

-- ── tile builder ─────────────────────────────────────────

local function buildTile(bar, pin, idx, theme, mobile)
    local tileS = mobile and 40 or 36
    local lib = QuickBar.Library

    local cell = Instance.new("TextButton")
    cell.Name = "Tile_" .. (pin.id or pin.label or tostring(idx))
    cell.Size = UDim2.new(0, tileS, 0, tileS)
    cell.AutoButtonColor = false
    cell.Text = ""
    cell.BackgroundColor3 = theme.Surface
    cell.BackgroundTransparency = 0.25
    cell.BorderSizePixel = 0
    cell.ZIndex = 102
    cell.LayoutOrder = idx
    cell.Parent = bar
    corner(cell, 10)
    local tileStroke = stroke(cell, theme.Border, 1, 0.55)

    -- icon (uses pin.icon, falls back to a sensible default)
    local iconName = pin.icon
    if not iconName then
        if pin.type == "toggle" then iconName = "zap" else iconName = "play" end
    end
    local iconAsset = lucide(iconName, "rbxassetid://104262388679305")

    local img = Instance.new("ImageLabel")
    local iconS = mobile and 18 or 16
    img.Size = UDim2.new(0, iconS, 0, iconS)
    img.Position = UDim2.new(0.5, -iconS/2, 0.5, -iconS/2)
    img.BackgroundTransparency = 1
    img.Image = iconAsset
    img.ImageColor3 = theme.TextDim
    img.ZIndex = 103
    img.Parent = cell

    -- tiny status dot bottom-right (only for toggles)
    local dot
    if pin.type == "toggle" then
        dot = Instance.new("Frame")
        local ds = mobile and 7 or 6
        dot.Size = UDim2.new(0, ds, 0, ds)
        dot.Position = UDim2.new(1, -ds-3, 1, -ds-3)
        dot.AnchorPoint = Vector2.new(0, 0)
        dot.BackgroundColor3 = theme.TextMuted
        dot.BorderSizePixel = 0
        dot.ZIndex = 104
        dot.Parent = cell
        corner(dot, ds/2)
    end

    local function refresh()
        if pin.type == "toggle" then
            local val = lib.Flags[pin.id]
            if val then
                tw(cell, { BackgroundColor3 = theme.Accent, BackgroundTransparency = 0.05 }, 0.18)
                tw(tileStroke, { Color = theme.Accent, Transparency = 0 }, 0.18)
                tw(img, { ImageColor3 = Color3.new(1, 1, 1) }, 0.18)
                tw(dot, { BackgroundColor3 = Color3.new(1, 1, 1) }, 0.18)
            else
                tw(cell, { BackgroundColor3 = theme.Surface, BackgroundTransparency = 0.25 }, 0.18)
                tw(tileStroke, { Color = theme.Border, Transparency = 0.55 }, 0.18)
                tw(img, { ImageColor3 = theme.TextDim }, 0.18)
                tw(dot, { BackgroundColor3 = theme.TextMuted }, 0.18)
            end
        elseif pin.type == "button" then
            cell.BackgroundColor3 = theme.Accent
            cell.BackgroundTransparency = 0.1
            tileStroke.Color = theme.Accent
            tileStroke.Transparency = 0.2
            img.ImageColor3 = Color3.new(1, 1, 1)
        end
    end
    refresh()

    if pin.type == "toggle" then
        lib:OnFlagChanged(pin.id, refresh)
    end

    -- hover/tap feedback
    local hovered = false
    cell.MouseEnter:Connect(function()
        hovered = true
        if pin.type == "toggle" and not lib.Flags[pin.id] then
            tw(cell, { BackgroundTransparency = 0.1 }, 0.12)
            tw(tileStroke, { Color = theme.Accent, Transparency = 0.3 }, 0.12)
        end
        showTip(cell, pin.type == "toggle" and pin.id or (pin.label or "Button"))
    end)
    cell.MouseLeave:Connect(function()
        hovered = false
        if pin.type == "toggle" and not lib.Flags[pin.id] then
            tw(cell, { BackgroundTransparency = 0.25 }, 0.12)
            tw(tileStroke, { Color = theme.Border, Transparency = 0.55 }, 0.12)
        end
        hideTip()
    end)

    return { frame = cell, img = img, dot = dot, pin = pin, refresh = refresh }
end

-- ── bar layout ───────────────────────────────────────────

local function rebuildBar()
    local lib = QuickBar.Library
    local win = QuickBar.Window
    if not lib or not win then return end

    local theme = lib.Theme
    local mobile = isMobile()
    local bar = QuickBar._bar

    -- clear old tiles (but keep open btn marker)
    for _, c in QuickBar._cells do
        if c.frame then c.frame:Destroy() end
    end
    table.clear(QuickBar._cells)
    if QuickBar._openCell and QuickBar._openCell.frame then
        QuickBar._openCell.frame:Destroy()
    end
    QuickBar._openCell = nil

    if #QuickBar._pins == 0 then
        bar.Visible = false
        if not win.Visible and win._togglePill then
            win._togglePill.Visible = true
        end
        return
    end

    local tileS = mobile and 40 or 36
    local pad = 6
    local gap = 6
    local count = #QuickBar._pins + 1 -- +1 open btn
    local barW = pad*2 + count*tileS + (count-1)*gap
    local barH = tileS + pad*2

    bar.Size = UDim2.new(0, barW, 0, barH)
    bar.BackgroundColor3 = theme.Base
    bar.BackgroundTransparency = 0.05

    -- open-window tile (always first)
    local openCell = Instance.new("TextButton")
    openCell.Name = "OpenTile"
    openCell.Size = UDim2.new(0, tileS, 0, tileS)
    openCell.AutoButtonColor = false
    openCell.Text = ""
    openCell.BackgroundColor3 = theme.Accent
    openCell.BackgroundTransparency = 0.1
    openCell.BorderSizePixel = 0
    openCell.ZIndex = 102
    openCell.LayoutOrder = 0
    openCell.Parent = bar
    corner(openCell, 10)
    local openStroke = stroke(openCell, theme.Accent, 1, 0.2)

    local openIcon = Instance.new("ImageLabel")
    local oS = mobile and 18 or 16
    openIcon.Size = UDim2.new(0, oS, 0, oS)
    openIcon.Position = UDim2.new(0.5, -oS/2, 0.5, -oS/2)
    openIcon.BackgroundTransparency = 1
    openIcon.Image = lucide("layout-grid", lucide("maximize", "rbxassetid://104262388679305"))
    openIcon.ImageColor3 = Color3.new(1, 1, 1)
    openIcon.ZIndex = 103
    openIcon.Parent = openCell

    openCell.MouseEnter:Connect(function()
        tw(openCell, { BackgroundTransparency = 0 }, 0.12)
        showTip(openCell, "Open Velvet")
    end)
    openCell.MouseLeave:Connect(function()
        tw(openCell, { BackgroundTransparency = 0.1 }, 0.12)
        hideTip()
    end)
    openCell.MouseButton1Click:Connect(function()
        if QuickBar._dragMoved then return end
        local w = QuickBar.Window
        if w then w:Show() end
    end)

    QuickBar._openCell = { frame = openCell, img = openIcon }

    for i, pin in QuickBar._pins do
        local c = buildTile(bar, pin, i, theme, mobile)
        table.insert(QuickBar._cells, c)

        c.frame.MouseButton1Click:Connect(function()
            if QuickBar._dragMoved then return end
            local libRef = QuickBar.Library
            if c.pin.type == "toggle" then
                local elem = libRef._elements and libRef._elements[c.pin.id]
                if elem and elem.Set and elem.Get then
                    elem:Set(not elem:Get())
                    -- haptic-ish bounce
                    tw(c.frame, { Size = UDim2.new(0, tileS - 4, 0, tileS - 4) }, 0.06)
                    task.delay(0.06, function()
                        tw(c.frame, { Size = UDim2.new(0, tileS, 0, tileS) }, 0.12, Enum.EasingStyle.Back)
                    end)
                end
            elseif c.pin.type == "button" and c.pin.cb then
                pcall(c.pin.cb)
                tw(c.frame, { BackgroundTransparency = 0 }, 0.06)
                task.delay(0.06, function()
                    tw(c.frame, { BackgroundTransparency = 0.1 }, 0.18)
                end)
            end
        end)
    end

    if not win.Visible then
        bar.Visible = true
        if win._togglePill then win._togglePill.Visible = false end
    end
end

-- ── drag handling on the BAR (not on tiles) ─────────────

local function setupDrag(bar)
    local dragging, dragStart, startPos = false, nil, nil
    local moved = false

    conn(bar.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            QuickBar._dragMoved = false
            dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            startPos = bar.Position
        end
    end)

    conn(UserInputService.InputChanged, function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local pos = Vector2.new(inp.Position.X, inp.Position.Y)
            local delta = pos - dragStart
            if delta.Magnitude > 6 then
                moved = true
                QuickBar._dragMoved = true
            end
            bar.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    conn(UserInputService.InputEnded, function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if not dragging then return end
        dragging = false
        -- give children a tick to read the flag, then clear
        task.delay(0.05, function() QuickBar._dragMoved = false end)
    end)
end

-- ── public api ───────────────────────────────────────────

function QuickBar:Bind(library, window, opts)
    opts = opts or {}
    self.Library = library
    self.Window = window
    self._maxPins = opts.MaxPins or 5

    if opts.File then self._file = opts.File end

    loadPins()

    -- create screengui
    local hui = (gethui and gethui()) or game:GetService("CoreGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "VelvetQuickBar"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 501
    pcall(function() gui.Parent = hui end)
    if not gui.Parent then
        gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end
    self._gui = gui

    local mobile = isMobile()
    local barH = mobile and 52 or 48

    -- bar frame (pure container, drag goes via background)
    local bar = Instance.new("Frame")
    bar.Name = "QuickBar"
    bar.Active = true
    bar.Size = UDim2.new(0, 100, 0, barH)
    bar.Position = opts.Position or UDim2.new(0, 12, 0.5, -barH/2)
    bar.BackgroundColor3 = library.Theme.Base
    bar.BackgroundTransparency = 0.05
    bar.BorderSizePixel = 0
    bar.ZIndex = 100
    bar.Visible = false
    bar.Parent = gui
    corner(bar, 14)
    stroke(bar, library.Theme.Border, 1, 0.4)

    -- glassmorphism inner highlight
    local glass = Instance.new("Frame")
    glass.Size = UDim2.new(1, -2, 0, 1)
    glass.Position = UDim2.new(0, 1, 0, 1)
    glass.BackgroundColor3 = Color3.new(1, 1, 1)
    glass.BackgroundTransparency = 0.85
    glass.BorderSizePixel = 0
    glass.ZIndex = 101
    glass.Parent = bar

    self._bar = bar

    -- horizontal layout
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 6)
    layout.Parent = bar

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = bar

    setupDrag(bar)

    -- hook show/hide to toggle bar visibility
    local origShow = window.Show
    local origHide = window.Hide

    function window:Show(...)
        if self._togglePill then self._togglePill.Visible = false end
        bar.Visible = false
        return origShow(self, ...)
    end

    function window:Hide(...)
        local result = origHide(self, ...)
        task.delay(0.25, function()
            if #QuickBar._pins > 0 then
                bar.Visible = true
                if self._togglePill then self._togglePill.Visible = false end
                -- slide-in animation
                bar.BackgroundTransparency = 1
                tw(bar, { BackgroundTransparency = 0.05 }, 0.22)
            else
                if self._togglePill then self._togglePill.Visible = true end
            end
        end)
        return result
    end

    rebuildBar()
    return self
end

local function findPinIdx(target)
    for i, p in QuickBar._pins do
        if p.type == "toggle" and p.id == target then return i end
        if p.type == "button" and p.label == target then return i end
    end
    return nil
end

local function checkMax()
    if #QuickBar._pins >= QuickBar._maxPins then
        if QuickBar.Library and QuickBar.Library.Notify then
            QuickBar.Library:Notify({ Title = "Quick Bar", Content = `Max {QuickBar._maxPins} pins`, Duration = 2, Type = "warning" })
        end
        return false
    end
    return true
end

function QuickBar:Pin(id, opts)
    if not self.Library then return end
    if findPinIdx(id) then return end
    if not checkMax() then return end
    if typeof(self.Library.Flags[id]) ~= "boolean" then return end
    opts = opts or {}
    table.insert(self._pins, { type = "toggle", id = id, icon = opts.Icon })
    savePins()
    rebuildBar()
end

function QuickBar:PinButton(label, opts)
    if not self.Library then return end
    if findPinIdx(label) then return end
    if not checkMax() then return end
    -- accept either (label, callback) or (label, { Callback = ..., Icon = ... })
    local cb, icon
    if type(opts) == "function" then
        cb = opts
    elseif type(opts) == "table" then
        cb = opts.Callback
        icon = opts.Icon
    end
    if not cb then return end
    table.insert(self._pins, { type = "button", label = label, cb = cb, icon = icon })
    rebuildBar()
end

function QuickBar:Unpin(idOrLabel)
    local idx = findPinIdx(idOrLabel)
    if not idx then return end
    table.remove(self._pins, idx)
    savePins()
    rebuildBar()
end

function QuickBar:GetPins()
    local out = {}
    for _, p in self._pins do table.insert(out, p.id or p.label) end
    return out
end

function QuickBar:IsPinned(idOrLabel)
    return findPinIdx(idOrLabel) ~= nil
end

function QuickBar:Destroy()
    for _, c in self._conns do pcall(function() c:Disconnect() end) end
    table.clear(self._conns)
    if self._gui then self._gui:Destroy() end
    self._gui = nil
    self._bar = nil
    self._tip = nil
    table.clear(self._cells)
    table.clear(self._pins)
end

return QuickBar
