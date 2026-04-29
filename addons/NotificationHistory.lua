--[[
    Velvet NotificationHistory
    Bell icon in header + slide-out panel with scrollable notification log.

    Usage:
        local NotifHistory = loadstring(game:HttpGet(repo .. "addons/NotificationHistory.lua"))()
        NotifHistory:Bind(Velvet, Window)
        -- notifications are auto-captured. open bell to see history.
]]

local TweenService = game:GetService("TweenService")

local NotifHistory = {
    Library = nil,
    Window = nil,
    _entries = {},
    _entryFrames = {},
    _unreadCount = 0,
    _isOpen = false,
    _maxEntries = 50,
    _showTimestamp = true,
    _panel = nil,
    _bellBtn = nil,
    _badge = nil,
    _badgeLbl = nil,
    _scroll = nil,
}

-- ── helpers ──────────────────────────────────────────────

local function tw(obj, props, dur)
    local ti = TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(obj, ti, props):Play()
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function formatAge(t)
    local ago = os.clock() - t
    if ago < 60 then return "now"
    elseif ago < 3600 then return math.floor(ago / 60) .. "m"
    elseif ago < 86400 then return math.floor(ago / 3600) .. "h"
    else return math.floor(ago / 86400) .. "d" end
end

local TYPE_ICONS = {
    info = "rbxassetid://124560466474914",
    success = "rbxassetid://93898873302694",
    warning = "rbxassetid://125920361880643",
    error = "rbxassetid://76821953846248",
}

-- ── entry card builder ───────────────────────────────────

local function buildEntryCard(scroll, entry, theme)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -12, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = theme.Surface
    card.BackgroundTransparency = 0.3
    card.BorderSizePixel = 0
    card.ZIndex = 5
    card.Parent = scroll
    corner(card, 6)

    -- accent bar
    local accentColors = {
        info = theme.Info,
        success = theme.Success,
        warning = theme.Warning,
        error = theme.Error,
    }
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -6)
    accent.Position = UDim2.new(0, 3, 0, 3)
    accent.BackgroundColor3 = accentColors[entry.type] or theme.Accent
    accent.BorderSizePixel = 0
    accent.ZIndex = 6
    accent.Parent = card
    corner(accent, 2)

    -- type icon
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 12, 0, 12)
    icon.Position = UDim2.new(0, 12, 0, 6)
    icon.BackgroundTransparency = 1
    icon.Image = TYPE_ICONS[entry.type] or TYPE_ICONS.info
    icon.ImageColor3 = accentColors[entry.type] or theme.Accent
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 6
    icon.Parent = card

    -- title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 14)
    title.Position = UDim2.new(0, 28, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = entry.title or "Velvet"
    title.TextColor3 = theme.Text
    title.TextSize = 11
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = 6
    title.Parent = card

    -- timestamp
    local ts = Instance.new("TextLabel")
    ts.Name = "Timestamp"
    ts.Size = UDim2.new(0, 24, 0, 14)
    ts.Position = UDim2.new(1, -28, 0, 4)
    ts.BackgroundTransparency = 1
    ts.Text = formatAge(entry.time)
    ts.TextColor3 = theme.TextMuted
    ts.TextSize = 9
    ts.Font = Enum.Font.Gotham
    ts.TextXAlignment = Enum.TextXAlignment.Right
    ts.ZIndex = 6
    ts.Parent = card

    -- content
    if entry.content and #entry.content > 0 then
        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -38, 0, 0)
        body.Position = UDim2.new(0, 28, 0, 18)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.BackgroundTransparency = 1
        body.Text = entry.content
        body.TextColor3 = theme.TextDim
        body.TextSize = 10
        body.Font = Enum.Font.Gotham
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextWrapped = true
        body.ZIndex = 6
        body.Parent = card
    end

    -- bottom padding
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingTop = UDim.new(0, 2)
    pad.Parent = card

    return card
end

-- ── panel builder ────────────────────────────────────────

local function buildPanel(main, theme)
    local panel = Instance.new("Frame")
    panel.Name = "NotifPanel"
    panel.Size = UDim2.new(0, 240, 1, -48)
    panel.Position = UDim2.new(1, 0, 0, 48) -- off-screen
    panel.BackgroundColor3 = theme.Base
    panel.BackgroundTransparency = 0.02
    panel.BorderSizePixel = 0
    panel.ZIndex = 4
    panel.ClipsDescendants = true
    panel.Visible = true
    panel.Parent = main
    corner(panel, 0)

    -- left border
    local border = Instance.new("Frame")
    border.Size = UDim2.new(0, 1, 1, -12)
    border.Position = UDim2.new(0, 0, 0, 6)
    border.BackgroundColor3 = theme.Border
    border.BackgroundTransparency = 0.5
    border.BorderSizePixel = 0
    border.ZIndex = 5
    border.Parent = panel

    -- header
    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 30)
    hdr.BackgroundTransparency = 1
    hdr.ZIndex = 5
    hdr.Parent = panel

    local hdrLbl = Instance.new("TextLabel")
    hdrLbl.Size = UDim2.new(1, -60, 1, 0)
    hdrLbl.Position = UDim2.new(0, 10, 0, 0)
    hdrLbl.BackgroundTransparency = 1
    hdrLbl.Text = "Notifications"
    hdrLbl.TextColor3 = theme.Text
    hdrLbl.TextSize = 12
    hdrLbl.Font = Enum.Font.GothamBold
    hdrLbl.TextXAlignment = Enum.TextXAlignment.Left
    hdrLbl.ZIndex = 5
    hdrLbl.Parent = hdr

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 40, 0, 18)
    clearBtn.Position = UDim2.new(1, -48, 0.5, -9)
    clearBtn.BackgroundColor3 = theme.Surface
    clearBtn.BackgroundTransparency = 0.5
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = theme.TextMuted
    clearBtn.TextSize = 9
    clearBtn.Font = Enum.Font.GothamMedium
    clearBtn.BorderSizePixel = 0
    clearBtn.AutoButtonColor = false
    clearBtn.ZIndex = 5
    clearBtn.Parent = hdr
    corner(clearBtn, 4)

    clearBtn.MouseButton1Click:Connect(function()
        NotifHistory:Clear()
    end)

    -- separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -16, 0, 1)
    sep.Position = UDim2.new(0, 8, 0, 30)
    sep.BackgroundColor3 = theme.Border
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    sep.ZIndex = 5
    sep.Parent = panel

    -- scroll
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, -36)
    scroll.Position = UDim2.new(0, 0, 0, 34)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = theme.Accent
    scroll.ScrollBarImageTransparency = 0.5
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 5
    scroll.Parent = panel

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = scroll

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 4)
    listPad.PaddingLeft = UDim.new(0, 6)
    listPad.PaddingRight = UDim.new(0, 6)
    listPad.PaddingBottom = UDim.new(0, 4)
    listPad.Parent = scroll

    -- empty state
    local empty = Instance.new("TextLabel")
    empty.Name = "EmptyLabel"
    empty.Size = UDim2.new(1, 0, 0, 60)
    empty.BackgroundTransparency = 1
    empty.Text = "No notifications yet"
    empty.TextColor3 = theme.TextMuted
    empty.TextSize = 11
    empty.Font = Enum.Font.Gotham
    empty.ZIndex = 5
    empty.Parent = scroll

    NotifHistory._scroll = scroll
    NotifHistory._emptyLabel = empty
    return panel
end

-- ── bell button ──────────────────────────────────────────

local function buildBell(header, theme)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.Position = UDim2.new(1, -126, 0.5, -12)
    btn.BackgroundColor3 = theme.Panel
    btn.BackgroundTransparency = 0.6
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.ZIndex = 7
    btn.AutoButtonColor = false
    btn.Parent = header
    corner(btn, 6)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 12, 0, 12)
    icon.Position = UDim2.new(0.5, -6, 0.5, -6)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://97392696311902" -- bell
    icon.ImageColor3 = theme.Text
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 8
    icon.Parent = btn

    -- hover
    btn.MouseEnter:Connect(function() tw(btn, {BackgroundTransparency = 0.2}, 0.15) end)
    btn.MouseLeave:Connect(function() tw(btn, {BackgroundTransparency = 0.6}, 0.15) end)

    -- unread badge
    local badge = Instance.new("Frame")
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Size = UDim2.new(0, 14, 0, 14)
    badge.Position = UDim2.new(1, -1, 0, -3)
    badge.BackgroundColor3 = theme.Error
    badge.BorderSizePixel = 0
    badge.Visible = false
    badge.ZIndex = 9
    badge.Parent = btn
    corner(badge, 7)

    local badgeLbl = Instance.new("TextLabel")
    badgeLbl.Size = UDim2.fromScale(1, 1)
    badgeLbl.BackgroundTransparency = 1
    badgeLbl.Text = "0"
    badgeLbl.TextColor3 = Color3.new(1, 1, 1)
    badgeLbl.TextSize = 8
    badgeLbl.Font = Enum.Font.GothamBold
    badgeLbl.ZIndex = 10
    badgeLbl.Parent = badge

    NotifHistory._bellBtn = btn
    NotifHistory._badge = badge
    NotifHistory._badgeLbl = badgeLbl
    return btn
end

-- ── public api ───────────────────────────────────────────

function NotifHistory:Bind(library, window, opts)
    opts = opts or {}
    self.Library = library
    self.Window = window
    self._maxEntries = opts.MaxEntries or 50
    self._showTimestamp = opts.ShowTimestamp ~= false

    local main = window._main
    local header = main:FindFirstChild("Header")
    local theme = library.Theme

    -- shift search bar left to make room for bell
    local searchBar = header and header:FindFirstChild("VelvetSearchBar")
    if searchBar then
        local pos = searchBar.Position
        searchBar.Position = UDim2.new(pos.X.Scale, pos.X.Offset - 30, pos.Y.Scale, pos.Y.Offset)
    end

    -- build bell + panel
    buildBell(header, theme)
    self._panel = buildPanel(main, theme)

    -- bell click toggles panel
    self._bellBtn.MouseButton1Click:Connect(function()
        if self._isOpen then
            self:_closePanel()
        else
            self:_openPanel()
        end
    end)

    -- hook into Velvet:Notify
    library._notifHook = function(nOpts)
        self:_addEntry(nOpts)
    end

    return self
end

function NotifHistory:_addEntry(opts)
    opts = opts or {}
    local entry = {
        title = opts.Title or "Velvet",
        content = opts.Content or "",
        type = opts.Type or "info",
        time = os.clock(),
    }

    -- add to front (newest first)
    table.insert(self._entries, 1, entry)

    -- cap
    while #self._entries > self._maxEntries do
        table.remove(self._entries)
    end

    -- increment unread
    if not self._isOpen then
        self._unreadCount = self._unreadCount + 1
        self:_updateBadge()
    else
        -- panel is open, render the new entry immediately
        self:_rebuildCards()
    end
end

function NotifHistory:_updateBadge()
    if self._unreadCount > 0 then
        self._badge.Visible = true
        local txt = self._unreadCount < 100 and tostring(self._unreadCount) or "99+"
        self._badgeLbl.Text = txt
        local w = #txt <= 1 and 14 or (8 + #txt * 5)
        tw(self._badge, {Size = UDim2.new(0, w, 0, 14)}, 0.18)
    else
        self._badge.Visible = false
    end
end

function NotifHistory:_openPanel()
    self._isOpen = true
    self._unreadCount = 0
    self:_updateBadge()
    self:_rebuildCards()
    tw(self._panel, {Position = UDim2.new(1, -240, 0, 48)}, 0.25)
end

function NotifHistory:_closePanel()
    self._isOpen = false
    tw(self._panel, {Position = UDim2.new(1, 0, 0, 48)}, 0.2)
end

function NotifHistory:_rebuildCards()
    -- clear old
    for _, f in self._entryFrames do
        if f and f.Parent then f:Destroy() end
    end
    table.clear(self._entryFrames)

    local theme = self.Library.Theme

    -- empty state
    if self._emptyLabel then
        self._emptyLabel.Visible = #self._entries == 0
    end

    for i, entry in self._entries do
        local card = buildEntryCard(self._scroll, entry, theme)
        card.LayoutOrder = i
        table.insert(self._entryFrames, card)
    end
end

function NotifHistory:GetEntries()
    return self._entries
end

function NotifHistory:GetUnreadCount()
    return self._unreadCount
end

function NotifHistory:MarkAllRead()
    self._unreadCount = 0
    self:_updateBadge()
end

function NotifHistory:Clear()
    table.clear(self._entries)
    self._unreadCount = 0
    self:_updateBadge()
    self:_rebuildCards()
end

function NotifHistory:Destroy()
    if self.Library then self.Library._notifHook = nil end
    if self._panel then self._panel:Destroy() end
    if self._bellBtn then self._bellBtn:Destroy() end
    table.clear(self._entries)
    table.clear(self._entryFrames)
end

return NotifHistory
