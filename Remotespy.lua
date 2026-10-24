--[[
    Remote Spy (Rayfield UI)
    Core Logic: 100% Alqvirqq's RemoteSpy v0.01
    UI: Rayfield
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ===== STATE =====
local logs = {}
local excluded = {}
local currentRemote = nil
local currentMethod = nil
local currentArgs = nil

-- ===== HELPER (Alqvirqq Core) =====
local function fixargs(...)
    local args = {...}
    local strings = {}

    local function serialize(arg)
        if typeof(arg) == "string" then
            return string.format("%q", arg)
        elseif typeof(arg) == "Instance" then
            return string.format("\"%s\"", arg:GetFullName())
        elseif typeof(arg) == "table" then
            local serialized = {}
            for k, v in pairs(arg) do
                if typeof(k) == "string" then
                    table.insert(serialized, string.format("\"%s\"", k))
                end
                if typeof(v) == "string" then
                    table.insert(serialized, string.format("\"%s\"", v))
                elseif typeof(v) == "Instance" then
                    table.insert(serialized, string.format("\"%s\"", v:GetFullName()))
                else
                    table.insert(serialized, tostring(v))
                end
            end
            return "{" .. table.concat(serialized, ", ") .. "}"
        else
            return tostring(arg)
        end
    end

    for _, v in ipairs(args) do
        table.insert(strings, serialize(v))
    end

    return "{\n    " .. table.concat(strings, ",\n    ") .. "\n}"
end

-- ===== RAYFIELD UI =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Remote Spy (Rayfield)",
    LoadingTitle = "Alqvirqq Core", LoadingSubtitle = "by Operator",
    ConfigurationSaving = {Enabled = false}, KeySystem = false
})

local MainTab = Window:CreateTab("Spy", "eye")
MainTab:CreateSection("Remote List")

local RemoteDropdown
RemoteDropdown = MainTab:CreateDropdown({
    Name = "Detected Remotes",
    Options = {"Menunggu remote..."},
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(Option)
        local name = Option[1]
        if logs[name] then
            currentRemote = logs[name].remote
            currentMethod = logs[name].method
            currentArgs = logs[name].args
            
            -- Update Output TextBox
            OutputBox:Set(logs[name].txt)
            Rayfield:Notify({Title = "Loaded", Content = "Remote: " .. name, Duration = 2})
        end
    end
})

MainTab:CreateSection("Payload Editor (Ubah Argumen)")

local OutputBox
OutputBox = MainTab:CreateInput({
    Name = "Payload (Lua Table)",
    PlaceholderText = "local args = { ... }",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        -- gak ngelakuin apa-apa, cuma nyimpen teks
    end
})

MainTab:CreateButton({
    Name = "FIRE / INVOKE (Manual)",
    Callback = function()
        if not currentRemote or not currentMethod then
            Rayfield:Notify({Title = "Error", Content = "Pilih remote dulu.", Duration = 2}) return
        end
        
        local txt = OutputBox:Get()
        local success, args = pcall(function()
            -- Ekstrak isi tabel dari teks
            local func = loadstring("return " .. txt)
            if func then return func() end
        end)
        
        if not success or type(args) ~= "table" then
            Rayfield:Notify({Title = "Error", Content = "Format tabel salah.", Duration = 2}) return
        end
        
        pcall(function()
            if currentMethod == "FireServer" then
                currentRemote:FireServer(table.unpack(args))
            elseif currentMethod == "InvokeServer" then
                local result = currentRemote:InvokeServer(table.unpack(args))
                Rayfield:Notify({Title = "Return", Content = tostring(result), Duration = 3})
            end
        end)
        Rayfield:Notify({Title = "Sent", Content = "Perintah dikirim ke " .. currentRemote.Name, Duration = 2})
    end
})

MainTab:CreateSection("Utility")

MainTab:CreateButton({
    Name = "Clear Logs",
    Callback = function()
        logs = {}
        excluded = {}
        pcall(function() RemoteDropdown:Refresh({"Menunggu remote..."}) end)
        Rayfield:Notify({Title = "Cleared", Content = "Logs dibersihkan.", Duration = 2})
    end
})

MainTab:CreateButton({
    Name = "Exclude Selected Remote",
    Callback = function()
        if currentRemote then
            excluded[currentRemote] = true
            Rayfield:Notify({Title = "Excluded", Content = "Remote diabaikan.", Duration = 2})
        end
    end
})

-- ===== CORE: SADAP REMOTE (100% Alqvirqq) =====
local function log(remote, method, ...)
    if excluded[remote] then return end
    
    local args = fixargs(...)
    local fullPath = "game." .. remote:GetFullName()
    local txt = string.format("local args = %s\ngame.%s:%s(table.unpack(args))", args, remote:GetFullName(), method)
    
    if not logs[remote.Name] then
        logs[remote.Name] = {
            remote = remote,
            method = method,
            args = args,
            txt = txt
        }
    end
    
    -- Update dropdown
    local names = {}
    for k, _ in pairs(logs) do table.insert(names, k) end
    pcall(function() if RemoteDropdown then RemoteDropdown:Refresh(names) end end)
end

-- Sadap semua remote yang ada
for _, remote in ipairs(game:GetDescendants()) do
    if remote:IsA("RemoteEvent") then
        pcall(function()
            remote.OnClientEvent:Connect(function(...)
                log(remote, "FireServer", ...) -- FireServer buat balikin
            end)
        end)
    elseif remote:IsA("RemoteFunction") then
        pcall(function()
            remote.OnClientInvoke = function(...)
                log(remote, "InvokeServer", ...)
            end
        end)
    end
end

-- Sadap remote yang baru muncul
game.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("RemoteEvent") then
        pcall(function()
            descendant.OnClientEvent:Connect(function(...)
                log(descendant, "FireServer", ...)
            end)
        end)
    elseif descendant:IsA("RemoteFunction") then
        pcall(function()
            descendant.OnClientInvoke = function(...)
                log(descendant, "InvokeServer", ...)
            end
        end)
    end
end)

Rayfield:Notify({Title = "Remote Spy", Content = "Siap nyadap. Lakuin riset manual dulu.", Duration = 5})