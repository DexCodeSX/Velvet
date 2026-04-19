--[[
    Velvet ThemeManager
    Theme switching for Velvet UI Library
]]

local ThemeManager = {
    Library = nil,
    Current = "Midnight",
    Themes = {
        Midnight = {
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
        },
        Ocean = {
            Name = "Ocean",
            Base = Color3.fromRGB(8, 12, 18),
            Surface = Color3.fromRGB(14, 22, 34),
            Panel = Color3.fromRGB(20, 30, 46),
            Border = Color3.fromRGB(35, 55, 80),
            Accent = Color3.fromRGB(50, 140, 255),
            AccentDark = Color3.fromRGB(35, 100, 200),
            Text = Color3.fromRGB(220, 235, 250),
            TextDim = Color3.fromRGB(120, 150, 180),
            TextMuted = Color3.fromRGB(60, 85, 110),
            Success = Color3.fromRGB(60, 210, 140),
            Warning = Color3.fromRGB(255, 190, 60),
            Error = Color3.fromRGB(255, 90, 90),
            Info = Color3.fromRGB(80, 170, 255),
        },
        Rose = {
            Name = "Rose",
            Base = Color3.fromRGB(14, 10, 12),
            Surface = Color3.fromRGB(26, 18, 22),
            Panel = Color3.fromRGB(36, 24, 30),
            Border = Color3.fromRGB(65, 40, 50),
            Accent = Color3.fromRGB(240, 80, 130),
            AccentDark = Color3.fromRGB(190, 55, 100),
            Text = Color3.fromRGB(245, 230, 235),
            TextDim = Color3.fromRGB(170, 130, 145),
            TextMuted = Color3.fromRGB(110, 75, 90),
            Success = Color3.fromRGB(100, 220, 140),
            Warning = Color3.fromRGB(255, 180, 60),
            Error = Color3.fromRGB(255, 80, 80),
            Info = Color3.fromRGB(120, 160, 255),
        },
        Emerald = {
            Name = "Emerald",
            Base = Color3.fromRGB(8, 14, 10),
            Surface = Color3.fromRGB(14, 24, 18),
            Panel = Color3.fromRGB(20, 34, 26),
            Border = Color3.fromRGB(35, 60, 45),
            Accent = Color3.fromRGB(50, 210, 120),
            AccentDark = Color3.fromRGB(35, 160, 90),
            Text = Color3.fromRGB(225, 245, 232),
            TextDim = Color3.fromRGB(120, 170, 140),
            TextMuted = Color3.fromRGB(65, 100, 80),
            Success = Color3.fromRGB(80, 230, 130),
            Warning = Color3.fromRGB(255, 190, 50),
            Error = Color3.fromRGB(255, 85, 85),
            Info = Color3.fromRGB(80, 170, 240),
        },
        Sunset = {
            Name = "Sunset",
            Base = Color3.fromRGB(16, 10, 8),
            Surface = Color3.fromRGB(28, 18, 14),
            Panel = Color3.fromRGB(40, 26, 20),
            Border = Color3.fromRGB(70, 45, 35),
            Accent = Color3.fromRGB(255, 130, 50),
            AccentDark = Color3.fromRGB(200, 95, 35),
            Text = Color3.fromRGB(250, 238, 228),
            TextDim = Color3.fromRGB(180, 145, 120),
            TextMuted = Color3.fromRGB(110, 80, 60),
            Success = Color3.fromRGB(90, 220, 120),
            Warning = Color3.fromRGB(255, 200, 60),
            Error = Color3.fromRGB(255, 75, 75),
            Info = Color3.fromRGB(100, 170, 255),
        },
    }
}

function ThemeManager:Bind(library)
    self.Library = library
    return self
end

function ThemeManager:SetTheme(name)
    if not self.Themes[name] then return false end
    self.Current = name
    if self.Library then
        self.Library:SetTheme(self.Themes[name])
    end
    -- save preference
    pcall(function()
        writefile("VelvetTheme.txt", name)
    end)
    return true
end

function ThemeManager:GetThemes()
    local names = {}
    for k in self.Themes do
        table.insert(names, k)
    end
    return names
end

function ThemeManager:AddTheme(name, themeTable)
    themeTable.Name = name
    self.Themes[name] = themeTable
end

-- auto-load saved theme
function ThemeManager:LoadSaved()
    pcall(function()
        local saved = readfile("VelvetTheme.txt")
        if saved and self.Themes[saved] then
            self:SetTheme(saved)
        end
    end)
end

return ThemeManager
