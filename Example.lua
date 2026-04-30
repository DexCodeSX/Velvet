-- Velvet UI Library - Full Example
-- github.com/DexCodeSX/Velvet
-- run directly via executor, or loadstring from raw github (repo must be public)

----------------------------------------------------------------
-- LOAD (pick one method)
----------------------------------------------------------------
local repo = "https://raw.githubusercontent.com/DexCodeSX/Velvet/main/"
local Velvet = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local Icons = loadstring(game:HttpGet(repo .. "addons/Icons.lua"))()
local QuickBar = loadstring(game:HttpGet(repo .. "addons/QuickBar.lua"))()
local NotifHistory = loadstring(game:HttpGet(repo .. "addons/NotificationHistory.lua"))()

----------------------------------------------------------------
-- SETUP
----------------------------------------------------------------
Velvet:SetIcons(Icons)
SaveManager:Bind(Velvet, "VelvetExample")
ThemeManager:Bind(Velvet)

----------------------------------------------------------------
-- WINDOW (with lucide icon on toggle pill)
----------------------------------------------------------------
local Window = Velvet:CreateWindow({
    Title = "Velvet",
    SubTitle = "v3.2 showcase",
    ToggleKey = Enum.KeyCode.RightShift,
    ToggleIcon = "sparkles",
})

----------------------------------------------------------------
-- ADDONS BIND
----------------------------------------------------------------
QuickBar:Bind(Velvet, Window, { MaxPins = 5 })
NotifHistory:Bind(Velvet, Window)

----------------------------------------------------------------
-- COMBAT TAB
----------------------------------------------------------------
local Combat = Window:AddTab("Combat", "sword")
local aimSection = Combat:AddSection("Aimbot")

aimSection:AddToggle("AimbotEnabled", {
    Text = "Enable Aimbot",
    Default = false,
    Tooltip = "Locks camera to nearest player head",
    Callback = function(v) print("Aimbot:", v) end
})

aimSection:AddSlider("FOV", {
    Text = "FOV Radius",
    Min = 10, Max = 500, Default = 150, Increment = 5,
    Suffix = "px",
    VisibleWhen = "AimbotEnabled",
    Callback = function(v) print("FOV:", v) end
})

aimSection:AddDropdown("TargetPart", {
    Text = "Target Part",
    Values = {"Head", "HumanoidRootPart", "Torso"},
    Default = "Head",
    VisibleWhen = "AimbotEnabled",
})

aimSection:AddKeybind("AimKey", {
    Text = "Aim Key",
    Default = Enum.KeyCode.E,
    Mode = "Hold",
    VisibleWhen = "AimbotEnabled",
    Callback = function(active) print("Aim:", active) end
})

-- player selector
aimSection:AddPlayerSelector("AimTarget", {
    Text = "Lock Target",
    ExcludeSelf = true,
    VisibleWhen = "AimbotEnabled",
})

----------------------------------------------------------------
-- VISUALS TAB
----------------------------------------------------------------
local Visuals = Window:AddTab("Visuals", "eye")
local espSection = Visuals:AddSection("ESP")

espSection:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = false,
    Callback = function(v) print("ESP:", v) end
})

espSection:AddColorPicker("ESPColor", {
    Text = "ESP Color",
    Default = Color3.fromRGB(255, 50, 50),
    VisibleWhen = "ESPEnabled",
})

espSection:AddToggle("ESPNames", {
    Text = "Show Names",
    Default = true,
    VisibleWhen = "ESPEnabled",
})

espSection:AddToggle("ESPHealth", {
    Text = "Show Health",
    Default = true,
    VisibleWhen = "ESPEnabled",
})

espSection:AddDivider()

espSection:AddSlider("ESPDistance", {
    Text = "Max Distance",
    Min = 100, Max = 5000, Default = 2000, Increment = 50,
    Suffix = " studs",
    VisibleWhen = "ESPEnabled",
})

----------------------------------------------------------------
-- MISC TAB (with sub-tabs)
----------------------------------------------------------------
local Misc = Window:AddTab("Misc", "wrench")

local subUtil = Misc:AddSubTab("Utility")
local subNew = Misc:AddSubTab("New 2.0")

-- utility sub-tab
local utilSection = subUtil:AddSection("Tools")

utilSection:AddButton({
    Text = "Server Hop",
    Callback = function()
        Velvet:Notify({Title="Server Hop", Content="Finding server...", Duration=3, Type="info"})
    end
})

utilSection:AddInput("Webhook", {
    Text = "Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
})

utilSection:AddDropdown("Team", {
    Text = "Filter Teams",
    Values = {"All", "Enemy", "Friendly"},
    Default = "Enemy",
})

utilSection:AddParagraph({
    Title = "Info",
    Content = "Velvet UI Library by DexCodeSX. Open source on GitHub."
})

-- new 2.0 sub-tab
local newSection = subNew:AddSection("Progress + Log")

local bar = newSection:AddProgressBar("XPBar", {
    Text = "XP Progress",
    Default = 0, Max = 100,
    Color = Color3.fromRGB(120, 200, 255),
})

local log = newSection:AddLog({ Height = 120, MaxLines = 40 })
log:Success("Velvet 3.1 loaded")
log:Info("listening for events")
log:Warn("this is a warning")
log:Error("this is an error")

-- progress demo
task.spawn(function()
    for i = 1, 97, 4 do
        bar:Set(i)
        task.wait(0.06)
    end
    bar:Set(100)
    log:Success("XP bar done")
end)

-- conditional visibility + tooltips
local condSection = subNew:AddSection("Conditional Visibility")

condSection:AddToggle("ShowAdvanced", {
    Text = "Show Advanced",
    Default = false,
    Tooltip = "unlocks hidden options below",
})

condSection:AddSlider("AdvSlider", {
    Text = "Advanced Slider",
    Min = 0, Max = 100, Default = 50,
    VisibleWhen = "ShowAdvanced",
    Tooltip = "only visible when Show Advanced is on",
})

-- OnChanged chaining
local chained = condSection:AddToggle("Chained", { Text = "Chained Toggle", Default = false })
chained:OnChanged(function(v)
    log:Info("chained fired: " .. tostring(v))
end)

----------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------
local Settings = Window:AddTab("Settings", "settings")

-- theme
local themeSection = Settings:AddSection("Theme")
themeSection:AddDropdown("Theme", {
    Text = "UI Theme",
    Values = ThemeManager:GetThemes(),
    Default = ThemeManager.Current,
    Callback = function(v)
        ThemeManager:SetTheme(v)
        Velvet:Notify({Title="Theme", Content="Switched to " .. v, Duration=2, Type="success"})
    end
})

-- config save/load
local configSection = Settings:AddSection("Config")
configSection:AddInput("ConfigName", {
    Text = "Config Name",
    Default = "default",
    Placeholder = "config name",
})
configSection:AddButton({
    Text = "Save Config",
    Callback = function()
        local name = Velvet.Flags["ConfigName"] or "default"
        local ok, err = SaveManager:Save(name)
        Velvet:Notify({Title="Config", Content=ok and ("Saved: "..name) or ("Error: "..tostring(err)), Duration=3, Type=ok and "success" or "error"})
    end
})
configSection:AddButton({
    Text = "Load Config",
    Callback = function()
        local name = Velvet.Flags["ConfigName"] or "default"
        local ok, err = SaveManager:Load(name)
        Velvet:Notify({Title="Config", Content=ok and ("Loaded: "..name) or ("Error: "..tostring(err)), Duration=3, Type=ok and "success" or "error"})
    end
})

-- config share (base64)
local shareSection = Settings:AddSection("Share Config")
shareSection:AddInput("ShareString", {
    Text = "Config String",
    Placeholder = "paste base64 config here",
})
shareSection:AddButton({
    Text = "Export to Clipboard",
    Callback = function()
        local s = SaveManager:Export()
        if s then
            pcall(setclipboard, s)
            Velvet:Notify({Title="Export", Content="Copied " .. #s .. " bytes to clipboard", Duration=3, Type="success"})
        end
    end
})
shareSection:AddButton({
    Text = "Import from String",
    Callback = function()
        local ok = SaveManager:Import(Velvet.Flags.ShareString or "")
        Velvet:Notify({Title="Import", Content=ok and "Loaded" or "Failed", Duration=3, Type=ok and "success" or "error"})
    end
})

-- profiles
local profileSection = Settings:AddSection("Profiles")
SaveManager:BuildProfileUI(profileSection)

-- mobile / ui
local uiSection = Settings:AddSection("UI")
uiSection:AddSlider("UIScale", {
    Text = "UI Scale",
    Min = 0.7, Max = 1.5, Default = 1, Increment = 0.05,
    Callback = function(v) Window:SetScale(v) end,
})
uiSection:AddButton({
    Text = "Toggle Sidebar",
    Callback = function() Window:ToggleSidebar() end,
})
uiSection:AddButton({
    Text = "Haptic Pulse",
    Callback = function() Velvet:Haptic("heavy") end,
})

-- icon search
local iconSection = Settings:AddSection("Icon Search (" .. #Icons:All() .. " icons)")
iconSection:AddInput("IconQuery", {
    Text = "Search Icons",
    Placeholder = "e.g. 'arrow' or 'heart'",
    Callback = function(q)
        log:Clear()
        local results = Icons:Search(q, 10)
        if #results == 0 then
            log:Warn("no icons found for: " .. q)
        else
            for _, r in ipairs(results) do
                log:Info(r.name .. "  ->  " .. r.id)
            end
        end
    end
})

-- update check
uiSection:AddButton({
    Text = "Check for Update",
    Callback = function()
        local info = Velvet:CheckForUpdate("DexCodeSX/Velvet")
        if info then
            Velvet:Notify({
                Title = "Update",
                Content = info.outdated and ("New: " .. info.latest) or "Up to date",
                Duration = 4,
                Type = info.outdated and "info" or "success",
            })
        end
    end
})

----------------------------------------------------------------
-- WATERMARK + STARTUP
----------------------------------------------------------------
Velvet:CreateWatermark({
    Text = "Velvet | {fps} fps | {ping} ms | {user}",
})

-- pin demo: toggles get a lucide icon, plus a quick-action button
QuickBar:Pin("AimbotEnabled", { Icon = "crosshair" })
QuickBar:Pin("ESPEnabled",    { Icon = "eye" })
QuickBar:PinButton("Reset", {
    Icon = "rotate-ccw",
    Callback = function()
        Velvet:Notify({ Title = "Reset", Content = "All flags reset", Duration = 2, Type = "info" })
        for k, v in Velvet.Flags do
            if typeof(v) == "boolean" and v then
                local elem = Velvet._elements and Velvet._elements[k]
                if elem and elem.Set then elem:Set(false) end
            end
        end
    end,
})

----------------------------------------------------------------
-- THEME PREVIEW SHOWCASE (lives in Settings > Theme)
----------------------------------------------------------------
local previewSection = Settings:AddSection("Theme Preview")
previewSection:AddParagraph({
    Title = "Built-in Pro Themes",
    Content = "Tap any below to apply instantly. Velvet ships 9 curated dev-favorite themes.",
})

local themeList = { "Midnight", "Catppuccin", "TokyoNight", "Dracula", "Nord", "Rose", "Cyberpunk", "Monochrome" }
for _, name in themeList do
    previewSection:AddButton({
        Text = name,
        Callback = function()
            local theme = Velvet.Themes and Velvet.Themes[name]
            if theme then
                Velvet:SetTheme(theme)
                Velvet:Notify({ Title = "Theme", Content = name, Duration = 2, Type = "success" })
            end
        end,
    })
end

----------------------------------------------------------------
-- PROOF / TEST PANEL (visible review for first-time users)
----------------------------------------------------------------
local Proof = Window:AddTab("Showcase", "sparkles")
local proofSection = Proof:AddSection("v3.2 Feature Tour")

proofSection:AddParagraph({
    Title = "What's new in v3.2",
    Content = "Quick Bar with icon dock · Config Profiles · Notification History · 9 pro themes · hardened key system.",
})

local function fakeWork(label, dur)
    Velvet:Notify({ Title = label, Content = "running...", Duration = dur or 2, Type = "info" })
end

proofSection:AddButton({
    Text = "1. Trigger info notification",
    Callback = function() Velvet:Notify({ Title="Velvet", Content="info ping", Type="info", Duration=3 }) end,
})
proofSection:AddButton({
    Text = "2. Trigger success notification",
    Callback = function() Velvet:Notify({ Title="Done", Content="action completed", Type="success", Duration=3 }) end,
})
proofSection:AddButton({
    Text = "3. Trigger warning notification",
    Callback = function() Velvet:Notify({ Title="Heads up", Content="check your config", Type="warning", Duration=3 }) end,
})
proofSection:AddButton({
    Text = "4. Trigger error notification",
    Callback = function() Velvet:Notify({ Title="Error", Content="something went wrong", Type="error", Duration=3 }) end,
})
proofSection:AddButton({
    Text = "5. Burst (5 stacked notifications)",
    Callback = function()
        for i = 1, 5 do
            task.delay(i * 0.15, function()
                Velvet:Notify({ Title = "Burst #" .. i, Content = "stacked", Type = ({"info","success","warning","error","info"})[i], Duration = 4 })
            end)
        end
    end,
})

local interactSection = Proof:AddSection("Try Each Element")
interactSection:AddToggle("ProofToggle",  { Text = "Toggle me", Default = false })
interactSection:AddSlider("ProofSlider",  { Text = "Slide me",  Min = 0, Max = 100, Default = 25, Suffix = "%" })
interactSection:AddDropdown("ProofDD",    { Text = "Dropdown",  Values = {"Alpha","Beta","Gamma","Delta"}, Default = "Beta" })
interactSection:AddInput("ProofInput",    { Text = "Type here", Placeholder = "anything..." })
interactSection:AddKeybind("ProofKey",    { Text = "Bind a key", Default = Enum.KeyCode.G, Mode = "Toggle" })
interactSection:AddColorPicker("ProofCol",{ Text = "Pick a color", Default = Color3.fromRGB(124, 92, 252) })

local statSection = Proof:AddSection("Live Stats")
local fpsBar = statSection:AddProgressBar("FPSMeter", {
    Text = "FPS (cap 144)", Default = 60, Max = 144,
    Color = Color3.fromRGB(120, 200, 255),
})
local liveLog = statSection:AddLog({ Height = 100, MaxLines = 30 })
liveLog:Success("Velvet 3.2 runtime up")

local lastUpdate = 0
game:GetService("RunService").RenderStepped:Connect(function(dt)
    lastUpdate = lastUpdate + dt
    if lastUpdate < 0.25 then return end
    lastUpdate = 0
    local fps = math.floor(1 / dt + 0.5)
    fpsBar:Set(math.min(fps, 144))
end)

interactSection:AddButton({
    Text = "Log a random event",
    Callback = function()
        local kinds = { "Info", "Warn", "Error", "Success" }
        local k = kinds[math.random(1, #kinds)]
        liveLog[k](liveLog, "event @ " .. os.date("%H:%M:%S"))
    end,
})

----------------------------------------------------------------
-- STARTUP NOTIFY
----------------------------------------------------------------
Velvet:Notify({
    Title = "Velvet v3.2",
    Content = "loaded · " .. #Icons:All() .. " icons · 9 themes",
    Duration = 4,
    Type = "success",
})
task.delay(0.6, function()
    Velvet:Notify({
        Title = "Try this",
        Content = "press RightShift to hide and see the Quick Bar dock",
        Duration = 6,
        Type = "info",
    })
end)

-- v3.2 hints (in code so reviewers see them):
-- header search bar: type 'fov' or 'esp' to live filter every element
-- tab badges count ON toggles, hidden ones are excluded
-- bell icon top-right: notification history with unread count
-- RightShift hides window, dock with icon tiles appears
-- Settings > Profiles: save/load named config presets
-- Settings > Theme Preview: tap any theme to apply live
-- Showcase tab: full tour of every feature

--[[
    KEY SYSTEM (optional, wrap everything above in a function):

    Velvet:KeySystem({
        Title = "My Script",
        SubTitle = "Enter key",
        Keys = {"2026"},
        SaveKey = "MyKey.txt",
        Callback = function()
            -- put all the code above here
        end
    })
]]
