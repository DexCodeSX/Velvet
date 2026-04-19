# Velvet

Premium dark glassmorphism UI library for Roblox. PC + Mobile.

## Features

- Dark glassmorphism aesthetic with smooth animations
- Toggle, Slider, Button, Dropdown, Input, ColorPicker, Keybind, Label, Divider, Paragraph
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

## License

MIT
