-- Velvet UI Library - Example Script
-- github.com/DexCodeSX/Velvet

local Velvet = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/Library.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/addons/ThemeManager.lua"))()

-- bind addons
SaveManager:Bind(Velvet, "MyScriptConfig")
ThemeManager:Bind(Velvet)
ThemeManager:LoadSaved()

-- create window
local Window = Velvet:CreateWindow({
    Title = "My Script",
    SubTitle = "v1.0",
    ToggleKey = Enum.KeyCode.RightShift,
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
