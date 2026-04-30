-- velvet key system test
-- gate flow before the real UI loads

local Velvet = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/Library.lua"))()

local ok = Velvet:KeySystem({
    Title = "Velvet",
    SubTitle = "premium access required",
    Keys = { "velvet-2026", "let-me-in", "test-key" },
    SaveKey = "VelvetKeyTest.txt",
    MaxAttempts = 5,
    GetKeyLink = "https://discord.gg/velvet",
    GetKeyText = "Get Key from Discord",
    Callback = function(success)
        if success then print("[velvet] key passed, loading UI...") end
    end,
    OnLockout = function()
        warn("[velvet] too many wrong tries, locked out")
    end,
})

if not ok then return end

local Window = Velvet:CreateWindow({
    Title = "Velvet",
    SubTitle = "key system passed",
    ToggleKey = Enum.KeyCode.RightShift,
})

local tab = Window:AddTab("Main", "key")
local sec = tab:AddSection("Status")

sec:AddLabel({ Text = "key system worked" })

sec:AddButton({
    Text = "Forget key (re-prompt next run)",
    Callback = function()
        pcall(function() delfile("VelvetKeyTest.txt") end)
        Velvet:Notify({
            Title = "Velvet",
            Content = "saved key cleared",
            Type = "info",
            Duration = 3,
        })
    end
})

sec:AddButton({
    Text = "Reload script",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/KeySystemTest.lua"))()
    end
})

Velvet:Notify({
    Title = "Velvet",
    Content = "welcome back",
    Type = "success",
    Duration = 4,
})
