--[[
    Velvet QuickBar
    Floating draggable toggle strip - pin your most-used toggles.
    Visible when window is hidden. One-tap toggle without opening the full UI.

    Usage:
        local QuickBar = loadstring(game:HttpGet(repo .. "addons/QuickBar.lua"))()
        QuickBar:Bind(Velvet, Window, { MaxPins = 5 })
        QuickBar:Pin("AimbotEnabled")
        QuickBar:Unpin("AimbotEnabled")
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

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
    _visible = false,
}

-- ── helpers ──────────────────────────────────────────────

local function tw(obj, props, dur)
    local ti = TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(obj, ti, props):Play()
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

-- ── persistence ──────────────────────────────────────────
-- pin entries: { type = "toggle", id = "..." } or { type = "button", label = "..." }
-- buttons are NOT persisted (callbacks aren't serializable), only toggles save

local function savePins()
    pcall(function()
        local saveable = {}
        for _, p in QuickBar._pins do
            if p.type == "toggle" then table.insert(saveable, p.id) end
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
                for _, id in data do
                    if type(id) == "string" then
                        table.insert(out, { type = "toggle", id = id })
                    end
                end
                QuickBar._pins = out
            end
        end
    end)
end

-- ── cell builder ─────────────────────────────────────────

local function buildCell(bar, pin, idx, theme, mobile)
    local cellW = mobile and 52 or 56
    local lib = QuickBar.Library

    local cell = Instance.new("Frame")
    cell.Name = "Cell_" .. (pin.id or pin.label or tostring(idx))
    cell.Size = UDim2.new(0, cellW, 1, 0)
    cell.BackgroundTransparency = 1
    cell.ZIndex = 101
    cell.LayoutOrder = idx
    cell.Parent = bar

    -- visual indicator (dot for toggle, square for button)
    local indSize = mobile and 14 or 12
    local ind = Instance.new("Frame")
    ind.Size = UDim2.new(0, indSize, 0, indSize)
    ind.Position = UDim2.new(0.5, -indSize/2, 0, mobile and 5 or 4)
    ind.ZIndex = 102
    ind.BorderSizePixel = 0
    ind.Parent = cell
    if pin.type == "button" then
        corner(ind, 3)
        ind.BackgroundColor3 = theme.Accent
    else
        corner(ind, indSize/2)
    end

    -- label
    local labelText = pin.type == "button" and (pin.label or "Btn") or pin.id
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 10)
    lbl.Position = UDim2.new(0, 2, 1, mobile and -13 or -12)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.sub(labelText, 1, 6)
    lbl.TextSize = mobile and 8 or 7
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = theme.TextMuted
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 102
    lbl.Parent = cell

    local function refresh()
        if pin.type == "toggle" then
            local val = lib.Flags[pin.id]
            ind.BackgroundColor3 = val and theme.Accent or theme.TextMuted
        end
    end
    refresh()

    if pin.type == "toggle" then
        lib:OnFlagChanged(pin.id, refresh)
    end

    return { frame = cell, ind = ind, label = lbl, pin = pin, refresh = refresh }
end

-- ── bar layout ───────────────────────────────────────────

local function rebuildBar()
    local lib = QuickBar.Library
    local win = QuickBar.Window
    if not lib or not win then return end

    local theme = lib.Theme
    local mobile = isMobile()
    local bar = QuickBar._bar

    -- clear old cells
    for _, c in QuickBar._cells do
        if c.frame then c.frame:Destroy() end
    end
    table.clear(QuickBar._cells)

    if #QuickBar._pins == 0 then
        bar.Visible = false
        -- show original pill if window hidden
        if not win.Visible and win._togglePill then
            win._togglePill.Visible = true
        end
        return
    end

    local cellW = mobile and 52 or 56
    local openW = mobile and 36 or 30
    local barH = mobile and 40 or 34
    local barW = openW + #QuickBar._pins * cellW + 8

    bar.Size = UDim2.new(0, barW, 0, barH)
    bar.BackgroundColor3 = theme.Base
    corner(bar, 10)

    -- open-window button (first cell, accent colored dot with arrow icon)
    local openCell = Instance.new("Frame")
    openCell.Name = "OpenBtn"
    openCell.Size = UDim2.new(0, openW, 1, 0)
    openCell.BackgroundTransparency = 1
    openCell.ZIndex = 101
    openCell.LayoutOrder = 0
    openCell.Parent = bar

    local openDot = Instance.new("Frame")
    local ds = mobile and 16 or 14
    openDot.Size = UDim2.new(0, ds, 0, ds)
    openDot.Position = UDim2.new(0.5, -ds/2, 0.5, -ds/2)
    openDot.BackgroundColor3 = theme.Accent
    openDot.BorderSizePixel = 0
    openDot.ZIndex = 102
    openDot.Parent = openCell
    corner(openDot, ds/2)

    -- separator line between open btn and toggle cells
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0, 1, 0.6, 0)
    sep.Position = UDim2.new(1, 0, 0.2, 0)
    sep.BackgroundColor3 = theme.Border
    sep.BackgroundTransparency = 0.4
    sep.BorderSizePixel = 0
    sep.ZIndex = 102
    sep.Parent = openCell

    QuickBar._openCellW = openW

    for i, pin in QuickBar._pins do
        local c = buildCell(bar, pin, i, theme, mobile)
        table.insert(QuickBar._cells, c)
    end

    -- show bar only when window is hidden
    if not win.Visible then
        bar.Visible = true
        if win._togglePill then win._togglePill.Visible = false end
    end
end

-- ── drag + tap handling ──────────────────────────────────

local function setupDrag(bar)
    local dragging, dragStart, startPos = false, nil, nil
    local moved = false
    local mobile = isMobile()

    conn(bar.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            startPos = bar.Position
        end
    end)

    conn(UserInputService.InputChanged, function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local pos = Vector2.new(inp.Position.X, inp.Position.Y)
            local delta = pos - dragStart
            if delta.Magnitude > 5 then moved = true end
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

        if not moved then
            local tapX = inp.Position.X
            local barAbsX = bar.AbsolutePosition.X
            local cellW = mobile and 52 or 56
            local openW = QuickBar._openCellW or (mobile and 36 or 30)
            local relX = tapX - barAbsX - 4 -- 4px left padding

            if relX < openW then
                -- tapped the open button, show window
                local win = QuickBar.Window
                if win then win:Show() end
            else
                -- tapped a pin cell
                local toggleX = relX - openW
                local idx = math.floor(toggleX / cellW) + 1
                local pin = QuickBar._pins[idx]
                if pin then
                    local lib = QuickBar.Library
                    if pin.type == "toggle" then
                        local elem = lib._elements and lib._elements[pin.id]
                        if elem and elem.Set and elem.Get then
                            elem:Set(not elem:Get())
                        end
                    elseif pin.type == "button" and pin.cb then
                        pcall(pin.cb)
                    end
                end
            end
        end
    end)
end

-- ── public api ───────────────────────────────────────���───

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
    local barH = mobile and 40 or 34

    -- bar frame
    local bar = Instance.new("TextButton")
    bar.Name = "QuickBar"
    bar.Size = UDim2.new(0, 100, 0, barH)
    bar.Position = opts.Position or UDim2.new(0, 12, 0.5, -barH/2)
    bar.BackgroundColor3 = library.Theme.Base
    bar.BackgroundTransparency = 0.08
    bar.Text = ""
    bar.BorderSizePixel = 0
    bar.AutoButtonColor = false
    bar.ZIndex = 100
    bar.Visible = false
    bar.Parent = gui
    corner(bar, 10)
    stroke(bar, library.Theme.Accent, 1, 0.4)
    self._bar = bar

    -- layout for cells
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 0)
    layout.Parent = bar

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
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

function QuickBar:Pin(id)
    if not self.Library then return end
    if findPinIdx(id) then return end
    if not checkMax() then return end
    if typeof(self.Library.Flags[id]) ~= "boolean" then return end
    table.insert(self._pins, { type = "toggle", id = id })
    savePins()
    rebuildBar()
end

function QuickBar:PinButton(label, callback)
    if not self.Library or not callback then return end
    if findPinIdx(label) then return end
    if not checkMax() then return end
    table.insert(self._pins, { type = "button", label = label, cb = callback })
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
    table.clear(self._cells)
    table.clear(self._pins)
end

return QuickBar
