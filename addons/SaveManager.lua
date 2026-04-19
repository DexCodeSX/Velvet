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
        -- push to actual element so UI updates
        local elem = lib._elements and lib._elements[flag]
        if elem and elem.Set then
            pcall(function() elem:Set(val) end)
        end
    end
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

    applyData(self.Library, data)
    return true
end

-- Export config to base64 string (shareable)
function SaveManager:Export()
    if not self.Library then return nil, "No library bound" end
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
            data[flag] = { type = "table", value = val }
        end
    end
    local json = HttpService:JSONEncode(data)
    local enc
    pcall(function()
        if crypt and crypt.base64encode then enc = crypt.base64encode(json)
        elseif crypt and crypt.base64 and crypt.base64.encode then enc = crypt.base64.encode(json)
        elseif base64_encode then enc = base64_encode(json)
        end
    end)
    return enc or json
end

-- Import from base64 string (either encoded or raw json)
function SaveManager:Import(str)
    if not self.Library then return false, "No library bound" end
    if type(str) ~= "string" or #str == 0 then return false, "Empty string" end

    local decoded
    pcall(function()
        if crypt and crypt.base64decode then decoded = crypt.base64decode(str)
        elseif crypt and crypt.base64 and crypt.base64.decode then decoded = crypt.base64.decode(str)
        elseif base64_decode then decoded = base64_decode(str)
        end
    end)
    decoded = decoded or str

    local ok, data = pcall(function() return HttpService:JSONDecode(decoded) end)
    if not ok or type(data) ~= "table" then return false, "Bad config string" end

    applyData(self.Library, data)
    return true
end

function SaveManager:Delete(name)
    local ok, err = pcall(function()
        delfile(self.Folder .. "/" .. name .. ".json")
    end)
    return ok, err
end

return SaveManager
