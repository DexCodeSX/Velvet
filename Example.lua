-- Velvet UI Library - Example Script
-- github.com/DexCodeSX/Velvet

local Velvet = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/Library.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/addons/ThemeManager.lua"))()

--[[
    KEY SYSTEM (optional, remove this block if you dont need it)
    validates key before showing the main ui
    set SaveKey to a filename to remember valid keys
]]
Velvet:KeySystem({
    Title = "My Script",
    SubTitle = "Enter key to continue",
    Keys = {"free-key-123", "vip-key-456"},
    SaveKey = "MyScriptKey.txt",
    GetKeyLink = "https://your-key-link.com",
    Callback = function()
        -- everything below runs after key is validated
        loadUI()
    end
})

function loadUI()

-- bind addons
SaveManager:Bind(Velvet, "MyScriptConfig")
ThemeManager:Bind(Velvet)
ThemeManager:LoadSaved()

-- create window
-- ToggleText = custom text on the floating pill (default "V")
-- ToggleIcon = use an image instead of text (rbxassetid://...)
local Window = Velvet:CreateWindow({
    Title = "My Script",
    SubTitle = "v1.0",
    ToggleKey = Enum.KeyCode.RightShift,
    ToggleText = "MS",  -- shows "MS" on the toggle pill instead of "V"
    -- ToggleIcon = "rbxassetid://123456789",  -- or use an icon
})

-- combat tab
local Combat = Window:AddTab("Combat")
local aimSection = Combat:AddSection("Aimbot")

aimSection:AddToggle("AimbotEnabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(v)
        print("Aimbot:", v)
    end
})

aimSection:AddSlider("FOV", {
    Text = "FOV Radius",
    Min = 10,
    Max = 500,
    Default = 150,
    Increment = 5,
    Suffix = "px",
    Callback = function(v)
        print("FOV:", v)
    end
})

aimSection:AddDropdown("TargetPart", {
    Text = "Target Part",
    Values = {"Head", "HumanoidRootPart", "Torso"},
    Default = "Head",
    Callback = function(v)
        print("Target:", v)
    end
})

aimSection:AddKeybind("AimKey", {
    Text = "Aim Key",
    Default = Enum.KeyCode.E,
    Mode = "Hold",
    Callback = function(active)
        print("Aim active:", active)
    end
})

-- visuals tab
local Visuals = Window:AddTab("Visuals")
local espSection = Visuals:AddSection("ESP")

espSection:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = false,
    Callback = function(v) print("ESP:", v) end
})

espSection:AddColorPicker("ESPColor", {
    Text = "ESP Color",
    Default = Color3.fromRGB(255, 50, 50),
    Callback = function(c)
        print("Color:", c)
    end
})

espSection:AddToggle("ESPNames", {
    Text = "Show Names",
    Default = true,
})

espSection:AddToggle("ESPHealth", {
    Text = "Show Health",
    Default = true,
})

espSection:AddDivider()

espSection:AddSlider("ESPDistance", {
    Text = "Max Distance",
    Min = 100,
    Max = 5000,
    Default = 2000,
    Increment = 50,
    Suffix = " studs",
})

-- misc tab
local Misc = Window:AddTab("Misc")
local miscSection = Misc:AddSection("Utility")

miscSection:AddButton({
    Text = "Server Hop",
    Callback = function()
        Velvet:Notify({
            Title = "Server Hop",
            Content = "Finding low-population server...",
            Duration = 3,
            Type = "info"
        })
    end
})

miscSection:AddInput("Webhook", {
    Text = "Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(url)
        print("Webhook set:", url)
    end
})

miscSection:AddDropdown("Team", {
    Text = "Filter Teams",
    Values = {"All", "Enemy", "Friendly"},
    Default = "Enemy",
    Multi = false,
})

miscSection:AddParagraph({
    Title = "Info",
    Content = "Velvet UI Library by DexCodeSX. Open source on GitHub."
})

----------------------------------------------------------------
-- new stuff showcase
----------------------------------------------------------------
local New = Window:AddTab("New Stuff")

-- sub-tabs
local subA = New:AddSubTab("Elements")
local subB = New:AddSubTab("Mobile")

-- progress bar
local elemSec = subA:AddSection("New Elements")
local bar = elemSec:AddProgressBar("Loading", {
    Text = "XP Progress",
    Default = 0,
    Max = 100,
    Color = Color3.fromRGB(120, 200, 255),
})
task.spawn(function()
    for i = 1, 100 do
        bar:Set(i)
        task.wait(0.05)
    end
end)

-- log / console
local log = elemSec:AddLog({ Height = 120, MaxLines = 40 })
log:Success("Velvet 2.0 loaded")
log:Info("Listening for events")
log:Warn("This is a warning")
log:Error("This is an error")

-- player selector with @me, @random, @nearest
elemSec:AddPlayerSelector("Target", {
    Text = "Target Player",
    ExcludeSelf = true,
    Callback = function(v)
        log:Info("selected: " .. tostring(v))
    end
})

-- conditional visibility + tooltips
local condSec = subA:AddSection("Conditional Visibility")
condSec:AddToggle("ShowAdvanced", {
    Text = "Show Advanced",
    Default = false,
    Tooltip = "Unlocks hidden options below",
})
condSec:AddSlider("Advanced1", {
    Text = "Advanced Slider",
    Min = 0, Max = 100, Default = 50,
    VisibleWhen = "ShowAdvanced",
    Tooltip = "Only visible when Show Advanced is on",
})

-- OnChanged chaining
local chain = condSec:AddToggle("Chain1", { Text = "Chained Toggle", Default = false })
chain:OnChanged(function(v)
    log:Info("chain fired: " .. tostring(v))
end)

-- mobile / ui scale
local mobSec = subB:AddSection("Mobile Features")
mobSec:AddSlider("UIScale", {
    Text = "UI Scale",
    Min = 0.7, Max = 1.5, Default = 1, Increment = 0.05,
    Callback = function(v) Window:SetScale(v) end,
})
mobSec:AddButton({
    Text = "Collapse Sidebar",
    Callback = function() Window:ToggleSidebar() end,
})
mobSec:AddButton({
    Text = "Haptic pulse",
    Callback = function() Velvet:Haptic("heavy") end,
})
mobSec:AddParagraph({
    Title = "Gestures",
    Content = "Swipe left/right in content area to change tabs (mobile only).",
})

-- watermark
Velvet:CreateWatermark({
    Text = "Velvet | {fps} fps | {ping} ms | {user}",
})

-- config share
local shareSec = Settings:AddSection("Share Config")
local shareIn = shareSec:AddInput("ShareString", {
    Text = "Config String (base64)",
    Placeholder = "paste config here",
})
shareSec:AddButton({
    Text = "Export Config",
    Callback = function()
        local s = SaveManager:Export()
        if s then
            setclipboard(s)
            Velvet:Notify({Title="Export",Content="Copied base64 to clipboard",Duration=3,Type="success"})
        end
    end
})
shareSec:AddButton({
    Text = "Import Config",
    Callback = function()
        local ok = SaveManager:Import(Velvet.Flags.ShareString or "")
        Velvet:Notify({Title="Import",Content=ok and "Loaded" or "Failed",Duration=3,Type=ok and "success" or "error"})
    end
})
shareSec:AddButton({
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

-- settings tab
local Settings = Window:AddTab("Settings")
local themeSection = Settings:AddSection("Theme")

themeSection:AddDropdown("Theme", {
    Text = "UI Theme",
    Values = ThemeManager:GetThemes(),
    Default = ThemeManager.Current,
    Callback = function(v)
        ThemeManager:SetTheme(v)
        Velvet:Notify({Title = "Theme", Content = "Switched to " .. v, Duration = 2, Type = "success"})
    end
})

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
        Velvet:Notify({
            Title = "Config",
            Content = ok and "Saved: " .. name or "Error: " .. tostring(err),
            Duration = 3,
            Type = ok and "success" or "error"
        })
    end
})

configSection:AddButton({
    Text = "Load Config",
    Callback = function()
        local name = Velvet.Flags["ConfigName"] or "default"
        local ok, err = SaveManager:Load(name)
        Velvet:Notify({
            Title = "Config",
            Content = ok and "Loaded: " .. name or "Error: " .. tostring(err),
            Duration = 3,
            Type = ok and "success" or "error"
        })
    end
})

-- startup notification
Velvet:Notify({
    Title = "Velvet",
    Content = "Script loaded successfully.",
    Duration = 4,
    Type = "success"
})

end -- loadUI

--[[
    NO KEY SYSTEM VERSION:
    if you dont want a key system, delete the KeySystem block above
    and just call everything directly without the loadUI() wrapper:

    local Velvet = loadstring(...)()
    local Window = Velvet:CreateWindow({...})
    -- etc
]]
