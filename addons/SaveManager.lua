--[[
    Velvet SaveManager
    Config save/load + named profiles for Velvet UI Library
]]

local HttpService = game:GetService("HttpService")

local SaveManager = {
    Folder = "VelvetConfigs",
    Library = nil,
    _activeProfile = nil,
}

-- ── helpers ──────────────────────────────────────────────

local function ensureFolder(path)
    pcall(function()
        if not isfolder(path) then makefolder(path) end
    end)
end

local function serializeFlags(lib)
    local data = {}
    for flag, val in lib.Flags do
        local t = typeof(val)
        if t == "boolean" or t == "number" or t == "string" then
            data[flag] = { type = t, value = val }
        elseif t == "Color3" then
            data[flag] = { type = "Color3", value = { R = val.R, G = val.G, B = val.B } }
        elseif t == "EnumItem" then
            data[flag] = { type = "EnumItem", value = tostring(val) }
        elseif t == "table" then
            data[flag] = { type = "table", value = val }
        end
    end
    return data
end

local function applyData(lib, data)
    for flag, info in data do
        local val = info.value
        if info.type == "Color3" then
            val = Color3.new(val.R, val.G, val.B)
        elseif info.type == "EnumItem" then
            pcall(function()
                local parts = tostring(val):split(".")
                val = Enum[parts[2]][parts[3]]
            end)
        end
        lib.Flags[flag] = val
        local elem = lib._elements and lib._elements[flag]
        if elem and elem.Set then
            pcall(function() elem:Set(val) end)
        end
    end
end

local function b64encode(str)
    local enc
    pcall(function()
        if crypt and crypt.base64encode then enc = crypt.base64encode(str)
        elseif crypt and crypt.base64 and crypt.base64.encode then enc = crypt.base64.encode(str)
        elseif base64_encode then enc = base64_encode(str)
        end
    end)
    return enc
end

local function b64decode(str)
    local dec
    pcall(function()
        if crypt and crypt.base64decode then dec = crypt.base64decode(str)
        elseif crypt and crypt.base64 and crypt.base64.decode then dec = crypt.base64.decode(str)
        elseif base64_decode then dec = base64_decode(str)
        end
    end)
    return dec
end

-- ── core ─────────────────────────────────────────────────

function SaveManager:Bind(library, folder)
    self.Library = library
    self.Folder = folder or self.Folder
    ensureFolder(self.Folder)
    ensureFolder(self.Folder .. "/profiles")
    -- restore last active profile name
    pcall(function()
        if isfile(self.Folder .. "/_active_profile.txt") then
            self._activeProfile = readfile(self.Folder .. "/_active_profile.txt")
        end
    end)
    return self
end

-- ── configs (unchanged api) ──────────────────────────────

function SaveManager:GetConfigs()
    local configs = {}
    pcall(function()
        local files = listfiles(self.Folder)
        for _, f in files do
            local name = f:match("([^/\\]+)%.json$")
            if name then table.insert(configs, name) end
        end
    end)
    return configs
end

function SaveManager:Save(name)
    if not self.Library then return false, "No library bound" end
    name = name or "default"
    local data = serializeFlags(self.Library)
    local ok, err = pcall(function()
        writefile(self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    return ok, err
end

function SaveManager:Load(name)
    if not self.Library then return false, "No library bound" end
    name = name or "default"
    local ok, raw = pcall(function()
        return readfile(self.Folder .. "/" .. name .. ".json")
    end)
    if not ok then return false, "Config not found" end
    local success, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not success then return false, "Bad config format" end
    applyData(self.Library, data)
    return true
end

function SaveManager:Delete(name)
    local ok, err = pcall(function() delfile(self.Folder .. "/" .. name .. ".json") end)
    return ok, err
end

function SaveManager:Export()
    if not self.Library then return nil, "No library bound" end
    local json = HttpService:JSONEncode(serializeFlags(self.Library))
    return b64encode(json) or json
end

function SaveManager:Import(str)
    if not self.Library then return false, "No library bound" end
    if type(str) ~= "string" or #str == 0 then return false, "Empty string" end
    local decoded = b64decode(str) or str
    local ok, data = pcall(function() return HttpService:JSONDecode(decoded) end)
    if not ok or type(data) ~= "table" then return false, "Bad config string" end
    applyData(self.Library, data)
    return true
end

-- ── profiles ─────────────────────────────────────────────

function SaveManager:GetProfiles()
    local profiles = {}
    pcall(function()
        local files = listfiles(self.Folder .. "/profiles")
        for _, f in files do
            local name = f:match("([^/\\]+)%.json$")
            if name then table.insert(profiles, name) end
        end
    end)
    return profiles
end

function SaveManager:GetActiveProfile()
    return self._activeProfile
end

function SaveManager:SaveProfile(name)
    if not self.Library then return false, "No library bound" end
    if not name or #name == 0 then return false, "No name" end
    local data = serializeFlags(self.Library)
    local ok, err = pcall(function()
        writefile(self.Folder .. "/profiles/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    if ok then
        self._activeProfile = name
        pcall(function() writefile(self.Folder .. "/_active_profile.txt", name) end)
    end
    return ok, err
end

function SaveManager:LoadProfile(name)
    if not self.Library then return false, "No library bound" end
    if not name or #name == 0 then return false, "No name" end
    local ok, raw = pcall(function()
        return readfile(self.Folder .. "/profiles/" .. name .. ".json")
    end)
    if not ok then return false, "Profile not found" end
    local success, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not success then return false, "Bad profile format" end
    applyData(self.Library, data)
    self._activeProfile = name
    pcall(function() writefile(self.Folder .. "/_active_profile.txt", name) end)
    return true
end

function SaveManager:DeleteProfile(name)
    if not name then return false end
    local ok, err = pcall(function() delfile(self.Folder .. "/profiles/" .. name .. ".json") end)
    if self._activeProfile == name then self._activeProfile = nil end
    return ok, err
end

function SaveManager:RenameProfile(old, new)
    if not old or not new or #new == 0 then return false, "Bad name" end
    local ok, raw = pcall(function()
        return readfile(self.Folder .. "/profiles/" .. old .. ".json")
    end)
    if not ok then return false, "Profile not found" end
    pcall(function()
        writefile(self.Folder .. "/profiles/" .. new .. ".json", raw)
        delfile(self.Folder .. "/profiles/" .. old .. ".json")
    end)
    if self._activeProfile == old then
        self._activeProfile = new
        pcall(function() writefile(self.Folder .. "/_active_profile.txt", new) end)
    end
    return true
end

-- ── profile ui builder ───────────────────────────────────

function SaveManager:BuildProfileUI(section)
    if not section then return end
    local lib = self.Library
    local mgr = self

    local profiles = mgr:GetProfiles()
    local active = mgr:GetActiveProfile()

    local dd = section:AddDropdown("_VelvetProfile", {
        Text = "Profile",
        Values = #profiles > 0 and profiles or {"(none)"},
        Default = active or (profiles[1] or "(none)"),
        Callback = function(v)
            if v == "(none)" then return end
            local ok, err = mgr:LoadProfile(v)
            if ok and lib.Notify then
                lib:Notify({ Title = "Profile", Content = `Loaded "{v}"`, Duration = 2, Type = "success" })
            elseif not ok and lib.Notify then
                lib:Notify({ Title = "Profile", Content = `Failed: {err}`, Duration = 3, Type = "error" })
            end
        end,
    })

    local function refreshDD()
        local list = mgr:GetProfiles()
        if #list == 0 then list = {"(none)"} end
        dd:Refresh(list)
    end

    section:AddButton({
        Text = "Save Profile",
        Callback = function()
            local name = active or "default"
            local v = lib.Flags["_VelvetProfile"]
            if v and v ~= "(none)" then name = v end
            mgr:SaveProfile(name)
            refreshDD()
            if lib.Notify then
                lib:Notify({ Title = "Profile", Content = `Saved "{name}"`, Duration = 2, Type = "success" })
            end
        end,
    })

    section:AddButton({
        Text = "New Profile",
        Callback = function()
            local n = #mgr:GetProfiles() + 1
            local name = "Profile " .. n
            mgr:SaveProfile(name)
            refreshDD()
            if dd.Set then pcall(function() dd:Set(name) end) end
            if lib.Notify then
                lib:Notify({ Title = "Profile", Content = `Created "{name}"`, Duration = 2, Type = "info" })
            end
        end,
    })

    section:AddButton({
        Text = "Delete Profile",
        Callback = function()
            local v = lib.Flags["_VelvetProfile"]
            if not v or v == "(none)" then return end
            mgr:DeleteProfile(v)
            refreshDD()
            if lib.Notify then
                lib:Notify({ Title = "Profile", Content = `Deleted "{v}"`, Duration = 2, Type = "warning" })
            end
        end,
    })

    return dd
end

return SaveManager
