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
    SubTitle = "v2.0 showcase",
    ToggleKey = Enum.KeyCode.RightShift,
    ToggleIcon = "sparkles",
})

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
log:Success("Velvet 2.0 loaded")
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

Velvet:Notify({
    Title = "Velvet",
    Content = "v2.0 loaded - " .. #Icons:All() .. " icons available",
    Duration = 4,
    Type = "success"
})

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
