--[[
    Velvet SaveManager
    Config save/load for Velvet UI Library
]]

local HttpService = game:GetService("HttpService")

local SaveManager = {
    Folder = "VelvetConfigs",
    Library = nil,
}

function SaveManager:Bind(library, folder)
    self.Library = library
    self.Folder = folder or self.Folder

    -- make sure folder exists
    pcall(function()
        if not isfolder(self.Folder) then
            makefolder(self.Folder)
        end
    end)

    return self
end

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

    local data = {}
    for flag, val in self.Library.Flags do
        local t = typeof(val)
        if t == "boolean" or t == "number" or t == "string" then
            data[flag] = { type = t, value = val }
        elseif t == "Color3" then
            data[flag] = { type = "Color3", value = { R = val.R, G = val.G, B = val.B } }
        elseif t == "EnumItem" then
            data[flag] = { type = "EnumItem", value = tostring(val) }
        elseif t == "table" then
            -- multi-select dropdown
            data[flag] = { type = "table", value = val }
        end
    end

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

    local success, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not success then return false, "Bad config format" end

    for flag, info in data do
        local val = info.value
        if info.type == "Color3" then
            val = Color3.new(val.R, val.G, val.B)
        elseif info.type == "EnumItem" then
            -- try to convert back (best effort)
            pcall(function()
                local parts = tostring(val):split(".")
                val = Enum[parts[2]][parts[3]]
            end)
        end
        self.Library.Flags[flag] = val
    end

    return true
end

function SaveManager:Delete(name)
    local ok, err = pcall(function()
        delfile(self.Folder .. "/" .. name .. ".json")
    end)
    return ok, err
end

return SaveManager
