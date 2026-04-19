# Velvet

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72.svg?logo=lua)](https://lua.org)
[![Roblox](https://img.shields.io/badge/Roblox-Exploit_UI-red.svg)](https://github.com/DexCodeSX/Velvet)
[![Mobile Ready](https://img.shields.io/badge/mobile-ready-brightgreen.svg)]()
[![Stars](https://img.shields.io/github/stars/DexCodeSX/Velvet?style=social)](https://github.com/DexCodeSX/Velvet)

Premium dark glassmorphism UI library for Roblox. PC + Mobile.

## Features

- Dark glassmorphism aesthetic with smooth animations
- Toggle, Slider, Button, Dropdown, Input, ColorPicker, Keybind, Label, Divider, Paragraph
- **ProgressBar, Log/Console, PlayerSelector** (new in 2.0)
- **Sub-tabs** (pill row inside a tab for grouping)
- **Conditional visibility** (`VisibleWhen = "flagId"`)
- **Tooltips** on any element (`Tooltip = "text"`)
- **OnChanged chaining** (`elem:OnChanged(fn)`)
- **Watermark/HUD** with live `{fps}`, `{ping}`, `{time}`, `{user}`, `{flag:id}` tokens
- **Config Import/Export** as base64 strings (share configs in chat)
- **Auto-update check** against GitHub releases
- **Sidebar collapse** + **swipe-to-switch-tabs** gestures on mobile
- **UIScale** for font/element scaling (`Window:SetScale(1.2)`)
- **Haptic feedback** (`Velvet:Haptic("light")`)
- Multi-select dropdowns with search
- HSV color picker with hex input
- Keybind system (Toggle/Hold/Always modes)
- Notification system (info, success, warning, error)
- Floating toggle pill (draggable)
- Full PC + Mobile touch support
- Config save/load system
- 5 built-in themes (Midnight, Ocean, Rose, Emerald, Sunset)
- Custom theme support
- Flag system for easy value access
- Collapsible sections
- Key system with saved keys
- Custom toggle pill (text or icon, auto-sizing)
- `Velvet:Destroy()` full cleanup
- Single loadstring setup

## Install

```lua
local Velvet = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/Library.lua"))()
```

### Addons (optional)

```lua
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/addons/ThemeManager.lua"))()

SaveManager:Bind(Velvet, "MyConfig")
ThemeManager:Bind(Velvet)
ThemeManager:LoadSaved()
```

## Quick Start

```lua
local Velvet = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/Library.lua"))()

local Window = Velvet:CreateWindow({
    Title = "My Script",
    SubTitle = "v1.0",
    ToggleKey = Enum.KeyCode.RightShift,
})

local Tab = Window:AddTab("Main")
local Section = Tab:AddSection("Features")

Section:AddToggle("MyToggle", {
    Text = "Enable Feature",
    Default = false,
    Callback = function(value)
        print("Toggle:", value)
    end
})

Section:AddSlider("Speed", {
    Text = "Walk Speed",
    Min = 16,
    Max = 200,
    Default = 16,
    Increment = 1,
    Callback = function(value)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
    end
})
```

## API Reference

### Velvet

| Method | Description |
|--------|-------------|
| `Velvet:CreateWindow(opts)` | Create main window |
| `Velvet:Notify(opts)` | Show notification |
| `Velvet:SetTheme(table)` | Update theme colors |
| `Velvet:GetTheme()` | Get current theme |
| `Velvet.Flags` | Access all element values by ID |

### Window Options

```lua
{
    Title = "string",
    SubTitle = "string",
    Width = number,
    Height = number,
    TabWidth = number,
    ToggleKey = Enum.KeyCode,
}
```

### Window

| Method | Description |
|--------|-------------|
| `Window:AddTab(name)` | Add tab to sidebar |
| `Window:Show()` | Show window |
| `Window:Hide()` | Hide window (shows floating pill) |
| `Window:Toggle()` | Toggle visibility |
| `Window:Destroy()` | Remove window |

### Tab

| Method | Description |
|--------|-------------|
| `Tab:AddSection(name)` | Add collapsible section |

### Section

| Method | Returns | Description |
|--------|---------|-------------|
| `Section:AddToggle(id, opts)` | Toggle | Pill-style toggle switch |
| `Section:AddSlider(id, opts)` | Slider | Draggable value slider |
| `Section:AddButton(opts)` | Button | Click button with flash animation |
| `Section:AddDropdown(id, opts)` | Dropdown | Single/multi select dropdown |
| `Section:AddInput(id, opts)` | Input | Text input field |
| `Section:AddColorPicker(id, opts)` | ColorPicker | HSV color picker with hex |
| `Section:AddKeybind(id, opts)` | Keybind | Key binding (Toggle/Hold/Always) |
| `Section:AddLabel(text)` | Label | Text label |
| `Section:AddDivider()` | nil | Horizontal separator |
| `Section:AddParagraph(opts)` | nil | Title + content text block |

### Element Options

**Toggle:** `{ Text, Default, Callback }`
**Slider:** `{ Text, Min, Max, Default, Increment, Suffix, Callback }`
**Button:** `{ Text, Callback }`
**Dropdown:** `{ Text, Values, Default, Multi, Callback }`
**Input:** `{ Text, Default, Placeholder, Callback }`
**ColorPicker:** `{ Text, Default, Callback }`
**Keybind:** `{ Text, Default, Mode, Callback }` (Mode: "Toggle", "Hold", "Always")
**Paragraph:** `{ Title, Content }`

### Element Methods

All elements with IDs have:
- `:Set(value)` - update value programmatically
- `:Get()` - get current value

Values accessible via `Velvet.Flags["elementId"]`.

### Notifications

```lua
Velvet:Notify({
    Title = "Title",
    Content = "Message body",
    Duration = 4,
    Type = "success", -- info, success, warning, error
})
```

### SaveManager

```lua
SaveManager:Bind(Velvet, "FolderName")
SaveManager:Save("configName")
SaveManager:Load("configName")
SaveManager:Delete("configName")
SaveManager:GetConfigs() -- returns { "config1", "config2" }
```

### ThemeManager

```lua
ThemeManager:Bind(Velvet)
ThemeManager:SetTheme("Ocean")
ThemeManager:GetThemes() -- { "Midnight", "Ocean", "Rose", "Emerald", "Sunset" }
ThemeManager:AddTheme("Custom", { Base = ..., Accent = ..., ... })
ThemeManager:LoadSaved() -- loads last used theme
```

### Built-in Themes

- **Midnight** (default) - violet accent, deep black
- **Ocean** - blue accent, navy tones
- **Rose** - pink accent, warm dark
- **Emerald** - green accent, forest dark
- **Sunset** - orange accent, warm brown

### Key System

```lua
Velvet:KeySystem({
    Title = "My Script",
    SubTitle = "Key Required",
    Keys = {"key123", "beta-access"},
    SaveKey = true,
    GetKeyLink = "https://link-to-key.com",
    Callback = function()
        -- runs after valid key entered
        -- create your window here
    end
})
```

### Window Toggle Pill

```lua
-- custom text on floating pill (auto-sizes to fit)
local Window = Velvet:CreateWindow({
    Title = "My Script",
    ToggleText = "MS", -- short text, auto-sizes
})

-- or use an icon instead
local Window = Velvet:CreateWindow({
    Title = "My Script",
    ToggleIcon = "rbxassetid://123456", -- icon image
})
```

### New in 2.0

```lua
-- progress bar
local bar = section:AddProgressBar("XP", { Text="XP", Default=0, Max=100, Color=Color3.fromRGB(120,200,255) })
bar:Set(42)

-- log / console
local log = section:AddLog({ Height=120, MaxLines=50 })
log:Info("hi") log:Warn("oops") log:Error("x") log:Success("done")

-- player selector (auto-refreshes on join/leave, supports @me/@random/@nearest)
local ps = section:AddPlayerSelector("Target", { ExcludeSelf=true })
for _, p in ps:GetPlayers() do print(p.Name) end

-- sub-tabs inside a tab
local sub = Tab:AddSubTab("Combat")
local s = sub:AddSection("Aimbot")

-- conditional visibility - hide until a flag is truthy
section:AddSlider("Adv", { Text="Advanced", Min=0, Max=100, Default=50, VisibleWhen="ShowAdvanced" })

-- tooltips
section:AddToggle("X", { Text="Toggle", Tooltip="Hover help text", Default=false })

-- OnChanged listener
local t = section:AddToggle("Y", { Text="Y" })
t:OnChanged(function(v) print("changed:", v) end)

-- watermark
Velvet:CreateWatermark({ Text="Velvet | {fps} fps | {ping} ms | {user}" })

-- share config as base64
local str = SaveManager:Export()
SaveManager:Import(str)

-- update check
local info = Velvet:CheckForUpdate("DexCodeSX/Velvet")
-- info.latest, info.current, info.outdated

-- UI scale, sidebar toggle, haptic
Window:SetScale(1.2)
Window:ToggleSidebar()
Velvet:Haptic("medium")

-- clean destroy
Velvet:Destroy()
```

## License

MIT
