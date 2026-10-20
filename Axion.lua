-- === ACIVENNA-STYLE CLONE (FIXED DAMAGE) ===
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Connections = {}
local allTools = {}
local selectedTool = nil
local Aiming = false

local AimbotSettings = {
    Enabled = false, Method = "Camera", Key = Enum.UserInputType.MouseButton2,
    TargetPart = "Head", WallCheck = true, Smoothness = 2, InstantSnap = false,
    ShowFOV = true, FOV = 150, FOVColor = Color3.fromRGB(255, 255, 255), FOVThickness = 1
}

-- ===== HELPER =====
local function matchKeybind(Input, targetKey)
    if not targetKey then return false end
    if typeof(targetKey) == "EnumItem" then return Input.KeyCode == targetKey or Input.UserInputType == targetKey
    elseif typeof(targetKey) == "string" then
        local lowerTarget = targetKey:lower()
        return Input.KeyCode.Name:lower() == lowerTarget or Input.UserInputType.Name:lower() == lowerTarget
    end
    return false
end

local function IsVisible(targetPart)
    local Origin = Camera.CFrame.Position
    local Direction = (targetPart.Position - Origin).Unit * (targetPart.Position - Origin).Magnitude
    local RP = RaycastParams.new()
    local char = LocalPlayer.Character
    local ignore = {Camera}
    if char then table.insert(ignore, char) end
    RP.FilterDescendantsInstances = ignore
    RP.FilterType = Enum.RaycastFilterType.Blacklist
    local Result = Workspace:Raycast(Origin, Direction, RP)
    return Result == nil or Result.Instance:IsDescendantOf(targetPart.Parent)
end

-- ===== AIMBOT =====
local function GetClosestPlayer()
    local Closest, MaxDist = nil, AimbotSettings.FOV
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local TargetPart = v.Character:FindFirstChild(AimbotSettings.TargetPart) or v.Character.PrimaryPart
            local Hum = v.Character:FindFirstChild("Humanoid")
            if TargetPart and Hum and Hum.Health > 0 then
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                if OnScreen and (not AimbotSettings.WallCheck or IsVisible(TargetPart)) then
                    local MouseDist = (Vector2.new(ScreenPos.X, ScreenPos.Y) - UserInputService:GetMouseLocation()).Magnitude
                    if MouseDist < MaxDist then MaxDist = MouseDist; Closest = TargetPart end
                end
            end
        end
    end
    return Closest
end

local DrawingSupported = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and Drawing.new
local FOVCircle = nil
if DrawingSupported then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1; FOVCircle.Color = Color3.new(1,1,1)
        FOVCircle.Filled = false; FOVCircle.Transparency = 1; FOVCircle.NumSides = 64
    end)
end

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Visible = AimbotSettings.Enabled and AimbotSettings.ShowFOV
        FOVCircle.Radius = AimbotSettings.FOV
        FOVCircle.Color = AimbotSettings.FOVColor
        FOVCircle.Thickness = AimbotSettings.FOVThickness
        FOVCircle.Position = UserInputService:GetMouseLocation()
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if AimbotSettings.Enabled and Aiming then
        local TargetPart = GetClosestPlayer()
        if TargetPart then
            if AimbotSettings.Method == "Camera" then
                local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPart.Position)
                if AimbotSettings.InstantSnap then Camera.CFrame = TargetCFrame
                else Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, 1 / math.max(AimbotSettings.Smoothness, 1)) end
            elseif AimbotSettings.Method == "Mouse" then
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                if OnScreen then
                    local MousePos = UserInputService:GetMouseLocation()
                    local Dx, Dy = (ScreenPos.X - MousePos.X), (ScreenPos.Y - MousePos.Y)
                    if AimbotSettings.InstantSnap then
                        if mousemoverel then mousemoverel(Dx, Dy) end
                    else
                        local Smooth = math.max(AimbotSettings.Smoothness, 1)
                        if mousemoverel then mousemoverel(Dx / Smooth, Dy / Smooth) end
                    end
                end
            end
        end
    end
end))

table.insert(Connections, UserInputService.InputBegan:Connect(function(I)
    if matchKeybind(I, AimbotSettings.Key) then Aiming = true end
end))
table.insert(Connections, UserInputService.InputEnded:Connect(function(I)
    if matchKeybind(I, AimbotSettings.Key) then Aiming = false end
end))

-- ===== CLONE FORCE RUN (VERSI DIPERBAIKI) =====
local function CloneForceRun(toolObj)
    local ok, clone = pcall(function() return toolObj:Clone() end)
    if not ok or not clone then return false end
    
    -- 1. Masukin ke Backpack dulu
    clone.Parent = LocalPlayer:WaitForChild("Backpack")
    
    -- 2. Tunggu sampai player equip tool ini
    local equipConnection
    equipConnection = clone.Equipped:Connect(function()
        -- 3. Setelah equip, baru paksa script jalan
        task.spawn(function()
            task.wait(0.1) -- Kasih waktu handle ter-attach
            
            -- 4. Restart semua script di dalam tool (LocalScript & Script)
            for _, obj in pairs(clone:GetDescendants()) do
                if obj:IsA("LocalScript") then
                    obj.Disabled = false
                    -- Restart paksa biar dengerin event Activated
                    local oldParent = obj.Parent
                    obj.Parent = nil
                    task.wait(0.05)
                    obj.Parent = oldParent
                elseif obj:IsA("Script") then
                    pcall(function()
                        obj.RunContext = Enum.RunContext.Client
                        obj.Disabled = false
                    end)
                    local oldParent = obj.Parent
                    obj.Parent = nil
                    task.wait(0.05)
                    obj.Parent = oldParent
                end
            end
            
            -- 5. (Opsional) Coba cari RemoteEvent dan fire manual kalau script gak nembak
            -- Tapi ini harus tahu nama remote-nya (beda per game)
            
            Rayfield:Notify({Title = "Force Run", Content = "Script tool diaktifkan di client!", Duration = 3})
        end)
        
        -- Hanya perlu sekali
        if equipConnection then equipConnection:Disconnect() end
    end)
    
    return true
end

-- ===== STEAL (PINDAHIN LANGSUNG) =====
local function StealTool(toolObj)
    if not toolObj or not toolObj.Parent then return false end
    local ok, err = pcall(function()
        toolObj.Parent = LocalPlayer:WaitForChild("Backpack")
    end)
    if ok and toolObj.Parent == LocalPlayer:WaitForChild("Backpack") then
        return true
    end
    return CloneForceRun(toolObj)
end

-- ===== SCAN =====
local function ScanTools()
    allTools = {}
    local seen = {}
    for _, service in pairs(game:GetChildren()) do
        pcall(function()
            for _, v in pairs(service:GetDescendants()) do
                if v:IsA("Tool") and v:FindFirstChild("Handle") then
                    local isLocal = false
                    local p = v.Parent
                    while p do
                        if p == LocalPlayer or p == LocalPlayer:FindFirstChild("Backpack") or (LocalPlayer.Character and p == LocalPlayer.Character) then
                            isLocal = true; break
                        end
                        p = p.Parent
                    end
                    if not isLocal and not seen[v.Name] then
                        seen[v.Name] = true
                        table.insert(allTools, v)
                    end
                end
            end
        end)
    end
    return allTools
end

-- ===== RAYFIELD UI =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "AXION Steal & Aim (Acivenna Core)",
    LoadingTitle = "Loading Engine", LoadingSubtitle = "by Operator",
    ConfigurationSaving = {Enabled = false}, KeySystem = false
})

local ToolsTab = Window:CreateTab("Tools", "package")
ToolsTab:CreateSection("Scan & Take")

local ToolDropdown
local selectedToolName = nil

ToolDropdown = ToolsTab:CreateDropdown({
    Name = "Select Tool",
    Options = {"Klik SCAN dulu..."},
    CurrentOption = {}, MultipleOptions = false,
    Callback = function(Option)
        selectedToolName = Option[1]
        for _, t in ipairs(allTools) do if t.Name == selectedToolName then selectedTool = t; break end end
    end
})

ToolsTab:CreateButton({
    Name = "SCAN TOOLS",
    Callback = function()
        ScanTools()
        local names = {}
        for _, t in ipairs(allTools) do table.insert(names, t.Name) end
        if #names == 0 then table.insert(names, "Tidak ada tool.") end
        pcall(function()
            if ToolDropdown.Refresh then ToolDropdown:Refresh(names)
            elseif ToolDropdown.Set then ToolDropdown:Set(names) end
        end)
        Rayfield:Notify({Title = "Scan", Content = ("Ditemukan %d tool."):format(#allTools), Duration = 3})
    end
})

ToolsTab:CreateButton({
    Name = "CLONE (Force Run on Equip)",
    Callback = function()
        if selectedTool and selectedTool.Parent then
            if CloneForceRun(selectedTool) then
                Rayfield:Notify({Title = "Clone", Content = "Cloned: " .. selectedTool.Name .. ". Equip dulu!", Duration = 4})
            else
                Rayfield:Notify({Title = "Error", Content = "Clone gagal.", Duration = 2})
            end
        else
            Rayfield:Notify({Title = "Error", Content = "Pilih tool dulu.", Duration = 2})
        end
    end
})

ToolsTab:CreateButton({
    Name = "STEAL (Pindah Langsung)",
    Callback = function()
        if selectedTool and selectedTool.Parent then
            if StealTool(selectedTool) then
                Rayfield:Notify({Title = "Steal", Content = "Berhasil: " .. selectedTool.Name, Duration = 2})
            else
                Rayfield:Notify({Title = "Error", Content = "Gagal pindahin.", Duration = 2})
            end
        else
            Rayfield:Notify({Title = "Error", Content = "Pilih tool dulu.", Duration = 2})
        end
    end
})

-- ===== AIMBOT TAB =====
local AimTab = Window:CreateTab("Aimbot", "crosshair")
AimTab:CreateSection("Aimbot Engine")
AimTab:CreateToggle({Name = "Aimbot Enabled", CurrentValue = false, Callback = function(s) AimbotSettings.Enabled = s end})
AimTab:CreateDropdown({Name = "Method", Options = {"Camera", "Mouse"}, CurrentOption = {"Camera"}, Callback = function(O) AimbotSettings.Method = O[1] end})
AimTab:CreateDropdown({Name = "Target Part", Options = {"Head", "HumanoidRootPart"}, CurrentOption = {"Head"}, Callback = function(O) AimbotSettings.TargetPart = O[1] end})
AimTab:CreateToggle({Name = "Wall Check", CurrentValue = true, Callback = function(s) AimbotSettings.WallCheck = s end})
AimTab:CreateToggle({Name = "Instant Snap", CurrentValue = false, Callback = function(s) AimbotSettings.InstantSnap = s end})
AimTab:CreateSlider({Name = "Smoothness", Range = {1, 30}, Increment = 1, CurrentValue = 2, Callback = function(v) AimbotSettings.Smoothness = v end})
AimTab:CreateToggle({Name = "Show FOV", CurrentValue = true, Callback = function(s) AimbotSettings.ShowFOV = s end})
AimTab:CreateSlider({Name = "FOV Radius", Range = {10, 800}, Increment = 5, CurrentValue = 150, Callback = function(v) AimbotSettings.FOV = v end})

Rayfield:Notify({Title = "AXION", Content = "Menu siap. Clone -> Equip -> Tembak!", Duration = 4})