--[[
    Antibys Universal
    Features: Acivenna Utility (100% Original), Aimbot, ESP, Self Mods
    UI: Rayfield
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ===== STATE (Kita punya) =====
local Connections = {}
local Aiming = false
local AutoStealActive = false
local ESP_Cache = {}

local Settings = {
    Aimbot = {
        Enabled = false, Method = "Camera", Key = Enum.UserInputType.MouseButton2,
        TargetPart = "Head", WallCheck = true, Smoothness = 2, InstantSnap = false,
        ShowFOV = true, FOV = 150, FOVColor = Color3.fromRGB(255, 255, 255), FOVThickness = 1
    },
    Visuals = {
        Enabled = false, Names = true, Tracers = true, Chams = true,
        TextColor = Color3.fromRGB(255, 255, 255), TextSize = 14,
        TracerColor = Color3.fromRGB(255, 255, 255), TracerThickness = 1, TracerOrigin = "Bottom",
        ChamsFillColor = Color3.fromRGB(255, 0, 0), ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
        ChamsFillTransparency = 0.5, ChamsOutlineTransparency = 0,
        AlwaysOnTop = true, ColorMode = "Fixed"
    },
    Self = {
        WalkSpeed = 16, JumpPower = 50, InfiniteJump = false, Noclip = false, Fly = false, FlySpeed = 50
    }
}

-- ===== HELPER (Kita punya) =====
local function matchKeybind(Input, targetKey)
    if not targetKey then return false end
    if typeof(targetKey) == "EnumItem" then
        return Input.KeyCode == targetKey or Input.UserInputType == targetKey
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
    local ignore = {Camera}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    RP.FilterDescendantsInstances = ignore
    RP.FilterType = Enum.RaycastFilterType.Blacklist
    local Result = Workspace:Raycast(Origin, Direction, RP)
    return Result == nil or Result.Instance:IsDescendantOf(targetPart.Parent)
end

-- ===== AIMBOT (Kita punya) =====
local function GetClosestPlayer()
    local Closest, MaxDist = nil, Settings.Aimbot.FOV
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local TargetPart = v.Character:FindFirstChild(Settings.Aimbot.TargetPart) or v.Character.PrimaryPart
            local Hum = v.Character:FindFirstChild("Humanoid")
            if TargetPart and Hum and Hum.Health > 0 then
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                if OnScreen and (not Settings.Aimbot.WallCheck or IsVisible(TargetPart)) then
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
        FOVCircle.Thickness = 1; FOVCircle.Filled = false
        FOVCircle.Transparency = 1; FOVCircle.NumSides = 64
    end)
end

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Visible = Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOV
        FOVCircle.Radius = Settings.Aimbot.FOV
        FOVCircle.Color = Settings.Aimbot.FOVColor
        FOVCircle.Thickness = Settings.Aimbot.FOVThickness
        FOVCircle.Position = UserInputService:GetMouseLocation()
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Settings.Aimbot.Enabled and Aiming then
        local TargetPart = GetClosestPlayer()
        if TargetPart then
            if Settings.Aimbot.Method == "Camera" then
                local TargetCFrame = CFrame.new(Camera.CFrame.Position, TargetPart.Position)
                if Settings.Aimbot.InstantSnap then Camera.CFrame = TargetCFrame
                else Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, 1 / math.max(Settings.Aimbot.Smoothness, 1)) end
            elseif Settings.Aimbot.Method == "Mouse" and mousemoverel then
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                if OnScreen then
                    local MousePos = UserInputService:GetMouseLocation()
                    local Dx, Dy = (ScreenPos.X - MousePos.X), (ScreenPos.Y - MousePos.Y)
                    if Settings.Aimbot.InstantSnap then mousemoverel(Dx, Dy)
                    else local Smooth = math.max(Settings.Aimbot.Smoothness, 1); mousemoverel(Dx / Smooth, Dy / Smooth) end
                end
            end
        end
    end
end))

table.insert(Connections, UserInputService.InputBegan:Connect(function(I)
    if matchKeybind(I, Settings.Aimbot.Key) then Aiming = true end
end))
table.insert(Connections, UserInputService.InputEnded:Connect(function(I)
    if matchKeybind(I, Settings.Aimbot.Key) then Aiming = false end
end))

-- ===== ESP (Kita punya) =====
local function CreateESP(player)
    if ESP_Cache[player] then return end
    local cache = {}
    if DrawingSupported then
        pcall(function()
            cache.Name = Drawing.new("Text"); cache.Name.Center = true; cache.Name.Outline = true; cache.Name.Visible = false
            cache.Tracer = Drawing.new("Line"); cache.Tracer.Visible = false
        end)
    end
    local highlight = Instance.new("Highlight"); highlight.Enabled = false; highlight.Parent = game.CoreGui
    cache.Highlight = highlight
    ESP_Cache[player] = cache
end

local function RemoveESP(player)
    local cache = ESP_Cache[player]
    if cache then
        pcall(function() if cache.Name then cache.Name:Remove() end end)
        pcall(function() if cache.Tracer then cache.Tracer:Remove() end end)
        pcall(function() cache.Highlight:Destroy() end)
        ESP_Cache[player] = nil
    end
end

table.insert(Connections, Players.PlayerRemoving:Connect(RemoveESP))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if Settings.Visuals.Enabled then
                CreateESP(p)
                local cache = ESP_Cache[p]
                if cache and p.Character then
                    local char = p.Character
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head")
                    local hum = char:FindFirstChild("Humanoid")
                    
                    if root and head and hum and hum.Health > 0 then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
                        
                        local col = Settings.Visuals.TextColor
                        if Settings.Visuals.ColorMode == "Health" then col = Color3.fromHSV((hum.Health/hum.MaxHealth)*0.3, 1, 1)
                        elseif Settings.Visuals.ColorMode == "Team" and p.Team then col = p.TeamColor.Color end
                        
                        if Settings.Visuals.Names and onScreen and cache.Name then
                            cache.Name.Visible = true; cache.Name.Text = p.Name; cache.Name.Color = col
                            cache.Name.Size = Settings.Visuals.TextSize; cache.Name.Position = Vector2.new(headPos.X, headPos.Y)
                        elseif cache.Name then cache.Name.Visible = false end
                        
                        if Settings.Visuals.Tracers and onScreen and cache.Tracer then
                            cache.Tracer.Visible = true; cache.Tracer.Color = col; cache.Tracer.Thickness = Settings.Visuals.TracerThickness
                            local origin = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                            if Settings.Visuals.TracerOrigin == "Center" then origin = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                            elseif Settings.Visuals.TracerOrigin == "Mouse" then origin = UserInputService:GetMouseLocation() end
                            cache.Tracer.From = origin; cache.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        elseif cache.Tracer then cache.Tracer.Visible = false end
                        
                        if Settings.Visuals.Chams then
                            cache.Highlight.Enabled = true; cache.Highlight.Adornee = char
                            cache.Highlight.FillColor = col; cache.Highlight.OutlineColor = Settings.Visuals.ChamsOutlineColor
                            cache.Highlight.FillTransparency = Settings.Visuals.ChamsFillTransparency; cache.Highlight.OutlineTransparency = Settings.Visuals.ChamsOutlineTransparency
                            cache.Highlight.DepthMode = Settings.Visuals.AlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                        else cache.Highlight.Enabled = false end
                    else
                        if cache.Name then cache.Name.Visible = false end
                        if cache.Tracer then cache.Tracer.Visible = false end
                        cache.Highlight.Enabled = false
                    end
                end
            else RemoveESP(p) end
        end
    end
end))

-- ===== SELF MODS (Kita punya) =====
table.insert(Connections, RunService.Stepped:Connect(function()
    if Settings.Self.Noclip and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = Settings.Self.WalkSpeed
        if hum.UseJumpPower then hum.JumpPower = Settings.Self.JumpPower
        else hum.JumpHeight = Settings.Self.JumpPower / 3.5 end
    end
end))

table.insert(Connections, UserInputService.JumpRequest:Connect(function()
    if Settings.Self.InfiniteJump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Settings.Self.Fly then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local move = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0,1,0) end
            hrp.Velocity = move.Magnitude > 0 and move.Unit * Settings.Self.FlySpeed or Vector3.new(0, 0.1, 0)
        end
    end
end))

-- ===== RAYFIELD UI =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Antibys Universal",
    LoadingTitle = "Antibys Engine", LoadingSubtitle = "by Operator",
    ConfigurationSaving = {Enabled = false}, KeySystem = false
})

-- ===== TAB TOOLS: 100% KODE ACIVENNA (TANPA MODIFIKASI) =====
local UtilityTab = Window:CreateTab("Tools", "wrench")
UtilityTab:CreateSection("Tool Grabber")

-- [KODE ACIVENNA ASLI]
UtilityTab:CreateButton({
    Name = "Steal Tools Once",
    Callback = function()
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            
            local found = false
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Tool") and obj:FindFirstChild("Handle") then
                    local parent = obj.Parent
                    if parent == Workspace or parent:IsA("Folder") or (parent:IsA("Model") and not Players:GetPlayerFromCharacter(parent)) then
                        found = true
                        -- Panggil fungsi GrabToolInstant dari Acivenna
                        local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                        local handle = obj:FindFirstChild("Handle")
                        if hrp and handle then
                            if firetouchinterest then
                                firetouchinterest(hrp, handle, 0)
                                task.wait()
                                firetouchinterest(hrp, handle, 1)
                            else
                                local origCFrame = hrp.CFrame
                                local startTime = tick()
                                local steerConnection = RunService.Stepped:Connect(function()
                                    for _, part in pairs(char:GetDescendants()) do
                                        if part:IsA("BasePart") then part.CanCollide = false end
                                    end
                                end)
                                while obj.Parent ~= char and obj.Parent ~= LocalPlayer:FindFirstChild("Backpack") and (tick() - startTime < 0.5) do
                                    hrp.CFrame = handle.CFrame
                                    task.wait(0.01)
                                end
                                steerConnection:Disconnect()
                                hrp.CFrame = origCFrame
                            end
                        end
                    end
                end
            end
            
            if found then
                Rayfield:Notify({Title = "Tool Stealer", Content = "Collected loose tools!", Duration = 3})
            else
                Rayfield:Notify({Title = "Tool Stealer", Content = "No loose tools found.", Duration = 3})
            end
        end)
    end
})

UtilityTab:CreateToggle({
    Name = "Auto Steal Tools",
    CurrentValue = false,
    Callback = function(state)
        AutoStealActive = state
    end
})

UtilityTab:CreateSection("Tool Cloner / Giver")

local gameToolObjects = {}

local function GetGameTools()
    local tools = {}
    local toolObjects = {}
    
    for _, service in pairs(game:GetChildren()) do
        pcall(function()
            for _, v in pairs(service:GetDescendants()) do
                if v:IsA("Tool") then
                    local isLocal = false
                    local parent = v.Parent
                    while parent do
                        if parent == LocalPlayer or parent == LocalPlayer:FindFirstChild("Backpack") or (LocalPlayer.Character and parent == LocalPlayer.Character) then
                            isLocal = true
                            break
                        end
                        parent = parent.Parent
                    end
                    
                    if not isLocal then
                        if not toolObjects[v.Name] then
                            toolObjects[v.Name] = v
                            table.insert(tools, v.Name)
                        end
                    end
                end
            end
        end)
    end
    
    table.sort(tools)
    if #tools == 0 then
        table.insert(tools, "No tools found (Scan again)")
    end
    return tools, toolObjects
end

local ToolDropdown
ToolDropdown = UtilityTab:CreateDropdown({
    Name = "Select Tool to Clone",
    Options = {"Scan to load tools..."},
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(Option)
        local toolName = Option[1]
        local toolObj = gameToolObjects[toolName]
        if toolObj and toolName ~= "No tools found (Scan again)" then
            pcall(function()
                local clone = toolObj:Clone()
                clone.Parent = LocalPlayer:WaitForChild("Backpack")
                
                task.spawn(function()
                    for _, s in pairs(clone:GetDescendants()) do
                        if s:IsA("LocalScript") then
                            s.Disabled = true
                            task.wait(0.02)
                            s.Disabled = false
                        elseif s:IsA("Script") then
                            pcall(function()
                                s.RunContext = Enum.RunContext.Client
                            end)
                            s.Disabled = true
                            task.wait(0.02)
                            s.Disabled = false
                        end
                    end
                end)
                
                Rayfield:Notify({Title = "Tool Cloner", Content = "Cloned " .. toolName .. " with active scripts!", Duration = 3})
            end)
        end
    end,
})

UtilityTab:CreateButton({
    Name = "Scan & Update Tool List",
    Callback = function()
        local tools, objects = GetGameTools()
        gameToolObjects = objects
        pcall(function()
            if ToolDropdown then
                if ToolDropdown.Refresh then
                    ToolDropdown:Refresh(tools)
                elseif ToolDropdown.Set then
                    ToolDropdown:Set(tools)
                end
            end
        end)
        Rayfield:Notify({Title = "Tool Scanner", Content = "Scanned game: Found " .. tostring(#tools) .. " tool templates!", Duration = 3})
    end
})

-- Auto Steal Loop (Acivenna asli, pakai AutoStealActive dari atas)
task.spawn(function()
    while true do
        task.wait(0.3)
        if AutoStealActive then
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if not AutoStealActive then break end
                    if obj:IsA("Tool") and obj:FindFirstChild("Handle") then
                        local parent = obj.Parent
                        if parent == Workspace or parent:IsA("Folder") or (parent:IsA("Model") and not Players:GetPlayerFromCharacter(parent)) then
                            local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                            local handle = obj:FindFirstChild("Handle")
                            if hrp and handle then
                                if firetouchinterest then
                                    firetouchinterest(hrp, handle, 0)
                                    task.wait()
                                    firetouchinterest(hrp, handle, 1)
                                else
                                    local origCFrame = hrp.CFrame
                                    local startTime = tick()
                                    local steerConnection = RunService.Stepped:Connect(function()
                                        for _, part in pairs(char:GetDescendants()) do
                                            if part:IsA("BasePart") then part.CanCollide = false end
                                        end
                                    end)
                                    while obj.Parent ~= char and obj.Parent ~= LocalPlayer:FindFirstChild("Backpack") and (tick() - startTime < 0.5) do
                                        hrp.CFrame = handle.CFrame
                                        task.wait(0.01)
                                    end
                                    steerConnection:Disconnect()
                                    hrp.CFrame = origCFrame
                                end
                            end
                            task.wait(0.05)
                        end
                    end
                end
            end)
        end
    end
end)

-- Tab: Aimbot
local AimTab = Window:CreateTab("Aimbot", "crosshair")
AimTab:CreateSection("Aimbot Engine")
AimTab:CreateToggle({Name = "Aimbot Enabled", CurrentValue = false, Callback = function(s) Settings.Aimbot.Enabled = s end})
AimTab:CreateDropdown({Name = "Method", Options = {"Camera", "Mouse"}, CurrentOption = {"Camera"}, Callback = function(O) Settings.Aimbot.Method = O[1] end})
AimTab:CreateDropdown({Name = "Target Part", Options = {"Head", "HumanoidRootPart"}, CurrentOption = {"Head"}, Callback = function(O) Settings.Aimbot.TargetPart = O[1] end})
AimTab:CreateToggle({Name = "Wall Check", CurrentValue = true, Callback = function(s) Settings.Aimbot.WallCheck = s end})
AimTab:CreateToggle({Name = "Instant Snap", CurrentValue = false, Callback = function(s) Settings.Aimbot.InstantSnap = s end})
AimTab:CreateSlider({Name = "Smoothness", Range = {1, 30}, Increment = 1, CurrentValue = 2, Callback = function(v) Settings.Aimbot.Smoothness = v end})
AimTab:CreateToggle({Name = "Show FOV", CurrentValue = true, Callback = function(s) Settings.Aimbot.ShowFOV = s end})
AimTab:CreateSlider({Name = "FOV Radius", Range = {10, 800}, Increment = 5, CurrentValue = 150, Callback = function(v) Settings.Aimbot.FOV = v end})
AimTab:CreateColorPicker({Name = "FOV Color", Color = Color3.fromRGB(255,255,255), Callback = function(c) Settings.Aimbot.FOVColor = c end})

-- Tab: Visuals
local VisTab = Window:CreateTab("Visuals", "eye")
VisTab:CreateSection("ESP Settings")
VisTab:CreateToggle({Name = "ESP Enabled", CurrentValue = false, Callback = function(s) Settings.Visuals.Enabled = s end})
VisTab:CreateDropdown({Name = "Color Mode", Options = {"Fixed", "Team", "Health"}, CurrentOption = {"Fixed"}, Callback = function(O) Settings.Visuals.ColorMode = O[1] end})
VisTab:CreateSection("Name ESP")
VisTab:CreateToggle({Name = "Show Names", CurrentValue = true, Callback = function(s) Settings.Visuals.Names = s end})
VisTab:CreateSlider({Name = "Text Size", Range = {10, 24}, Increment = 1, CurrentValue = 14, Callback = function(v) Settings.Visuals.TextSize = v end})
VisTab:CreateColorPicker({Name = "Text Color", Color = Color3.fromRGB(255,255,255), Callback = function(c) Settings.Visuals.TextColor = c end})
VisTab:CreateSection("Tracer ESP")
VisTab:CreateToggle({Name = "Show Tracers", CurrentValue = true, Callback = function(s) Settings.Visuals.Tracers = s end})
VisTab:CreateDropdown({Name = "Tracer Origin", Options = {"Bottom", "Center", "Mouse"}, CurrentOption = {"Bottom"}, Callback = function(O) Settings.Visuals.TracerOrigin = O[1] end})
VisTab:CreateSlider({Name = "Tracer Thickness", Range = {1, 5}, Increment = 1, CurrentValue = 1, Callback = function(v) Settings.Visuals.TracerThickness = v end})
VisTab:CreateColorPicker({Name = "Tracer Color", Color = Color3.fromRGB(255,255,255), Callback = function(c) Settings.Visuals.TracerColor = c end})
VisTab:CreateSection("Chams ESP")
VisTab:CreateToggle({Name = "Show Chams", CurrentValue = true, Callback = function(s) Settings.Visuals.Chams = s end})
VisTab:CreateToggle({Name = "Always On Top", CurrentValue = true, Callback = function(s) Settings.Visuals.AlwaysOnTop = s end})
VisTab:CreateSlider({Name = "Fill Transparency", Range = {0, 10}, Increment = 1, CurrentValue = 5, Callback = function(v) Settings.Visuals.ChamsFillTransparency = v / 10 end})
VisTab:CreateColorPicker({Name = "Chams Fill Color", Color = Color3.fromRGB(255,0,0), Callback = function(c) Settings.Visuals.ChamsFillColor = c end})

-- Tab: Self
local SelfTab = Window:CreateTab("Self Mods", "user")
SelfTab:CreateSection("Movement")
SelfTab:CreateSlider({Name = "WalkSpeed", Range = {16, 300}, Increment = 1, CurrentValue = 16, Callback = function(v) Settings.Self.WalkSpeed = v end})
SelfTab:CreateSlider({Name = "JumpPower", Range = {50, 500}, Increment = 5, CurrentValue = 50, Callback = function(v) Settings.Self.JumpPower = v end})
SelfTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Callback = function(s) Settings.Self.InfiniteJump = s end})
SelfTab:CreateToggle({Name = "Noclip", CurrentValue = false, Callback = function(s) Settings.Self.Noclip = s end})
SelfTab:CreateToggle({Name = "Fly", CurrentValue = false, Callback = function(s) Settings.Self.Fly = s end})
SelfTab:CreateSlider({Name = "Fly Speed", Range = {10, 300}, Increment = 5, CurrentValue = 50, Callback = function(v) Settings.Self.FlySpeed = v end})

Rayfield:Notify({Title = "Antibys Universal", Content = "Loaded. Utility = Acivenna Original.", Duration = 5})
