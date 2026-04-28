-- velvet key system test
-- gate flow before the real UI loads

local Velvet = loadstring(game:HttpGet("https://raw.githubusercontent.com/DexCodeSX/Velvet/main/Library.lua"))()

local ok = Velvet:KeySystem({
    Title = "Velvet",
    SubTitle = "premium access required",
    Keys = { "velvet-2026", "let-me-in", "test-key" },
    SaveKey = "VelvetKeyTest.txt", -- saves the key so we dont prompt every run
    Note = "key auto saves, type it once and youre good",
    DiscordInvite = "https://discord.gg/velvet",
    Callback = function(success)
        if not success then
            warn("[velvet] key denied, bailing")
            return
        end
        print("[velvet] key passed, loading UI...")
    end
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
