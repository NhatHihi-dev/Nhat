-- ========================================================
-- PHẦN 1: CẤU HÌNH THÔNG SỐ
-- ========================================================
_G.SEA_SPEED = 250
_G.BOOST_SPEED = 1000 
_G.BOOST_DISTANCE = 90
_G.DoCao = 200          
_G.MinWaterHeight = 5   
_G.MaxDistance = 5000   

_G.SeaBeast1 = true     
_G.Leviathan1 = true    
_G.TerrorShark1 = true  
_G.BoatESP = true       

-- Cấu hình chạy ngầm & Tính năng mới
local Boud = true           -- Tự động bật Buso ngầm
local Observation = true    -- Tự động bật Ken ngầm
local Sec = 1               -- Thời gian lặp lại kiểm tra (giây)
local DevilFruitESP = true  -- Tự động bật ESP Trái Ác Quỷ ngầm
local EspEventIsland = true -- Tự động bật ESP Đảo Sự Kiện ngầm
local RDeath = true         -- Tự động xóa hiệu ứng Death/Respawn
_G.DestroyHit = true        -- Xóa hiệu ứng chém kiếm
_G.TatTBDame = false   -- Tắt thông báo sát thương (Damage Counter)

local Number = math.random(1000, 9999) -- ID ngẫu nhiên cho BillboardGui tránh trùng lặp


-- ========================================================
-- PHẦN 2: HỆ THỐNG CHẠY CHÍNH
-- ========================================================
local Players = game:GetService("Players"); local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService"); local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage"); local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer; local PlayerGui = Player:WaitForChild("PlayerGui")

for _, oldGui in ipairs(PlayerGui:GetChildren()) do
    if oldGui.Name == "SeaBeastFlyUI_Axiom" then oldGui:Destroy() end
end

local Enabled = false; local TargetEntity = nil; local Dragging = false; local DragStart = nil; local StartPosition = nil; local Moved = false
local BodyVelocity = nil; local NoclipConnection = nil

local Gui = Instance.new("ScreenGui"); Gui.Name = "SeaBeastFlyUI_Axiom"; Gui.ResetOnSpawn = false; Gui.Parent = PlayerGui
local Button = Instance.new("TextButton"); Button.Name = "FlyButton"; Button.Size = UDim2.fromOffset(80, 36)
Button.Position = UDim2.new(0, 50, 0.7, 0); Button.BackgroundColor3 = Color3.fromRGB(25, 25, 35); Button.BackgroundTransparency = 0.2
Button.TextColor3 = Color3.fromRGB(255, 255, 255); Button.TextStrokeColor3 = Color3.fromRGB(0, 150, 255); Button.TextStrokeTransparency = 0
Button.Text = "FLY: OFF"; Button.Font = Enum.Font.Cartoon; Button.TextSize = 13; Button.BorderSizePixel = 0; Button.AutoButtonColor = false; Button.Active = true; Button.Parent = Gui

local Corner = Instance.new("UICorner"); Corner.CornerRadius = UDim.new(0, 8); Corner.Parent = Button
local Stroke = Instance.new("UIStroke"); Stroke.Color = Color3.fromRGB(50, 150, 255); Stroke.Thickness = 1.5; Stroke.Parent = Button

local function GetRoot()
    local Character = Player.Character; return Character and Character:FindFirstChild("HumanoidRootPart")
end

local function EnableAntiGravity(root)
    if not BodyVelocity or BodyVelocity.Parent ~= root then
        if BodyVelocity then BodyVelocity:Destroy() end
        BodyVelocity = Instance.new("BodyVelocity"); BodyVelocity.Name = "SeaBeastHover"
        BodyVelocity.Velocity = Vector3.new(0, 0, 0); BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        BodyVelocity.P = 12500; BodyVelocity.Parent = root
    end
    local Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then Humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end
end

local function DisableAntiGravity()
    if BodyVelocity then BodyVelocity:Destroy(); BodyVelocity = nil end
end

local function EnableNoclip()
    if not NoclipConnection then
        NoclipConnection = RunService.Stepped:Connect(function()
            if Enabled and Player.Character then
                for _, part in ipairs(Player.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end)
    end
end

local function DisableNoclip()
    if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
end

local function IsEntityAlive(entity)
    if not entity or not entity.Parent then return false end
    
    local health = entity:FindFirstChild("Health")
    if health and health:IsA("NumberValue") then
        if health.Value <= 0 then return false end
    end

    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if humanoid.Health <= 0 then return false end
    end

    local root = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso") or entity.PrimaryPart
    if not root then return false end

    return true
end

-- Hàm tìm thuyền của bản thân
local function FindMyBoat()
    local boatsFolder = Workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    
    for _, boat in ipairs(boatsFolder:GetChildren()) do
        local isMyBoat = false
        if boat.Name:find(Player.Name) then
            isMyBoat = true
        else
            for _, descendant in ipairs(boat:GetDescendants()) do
                if descendant:IsA("ObjectValue") and descendant.Value == Player then
                    isMyBoat = true
                    break
                elseif descendant:IsA("StringValue") and descendant.Value == Player.Name then
                    isMyBoat = true
                    break
                end
            end
        end
        
        if isMyBoat then
            local seat = boat:FindFirstChild("VehicleSeat", true) or boat:FindFirstChild("Seat", true) or boat.PrimaryPart or boat:FindFirstChildOfClass("BasePart")
            if seat then
                return seat
            end
        end
    end
    return nil
end

-- Hàm tìm quái quanh đây (Sea Beast, Leviathan, Terror Shark)
local function FindNearestSeaMonster()
    local MyRoot = GetRoot(); if not MyRoot then return nil end
    local Nearest = nil; local NearestDistance = _G.MaxDistance 

    local seaBeastsFolder = Workspace:FindFirstChild("SeaBeasts")
    if seaBeastsFolder then
        for _, entity in ipairs(seaBeastsFolder:GetChildren()) do
            local name = entity.Name:lower()
            if (_G.SeaBeast1 and (name:find("seabeast") or name:find("sea beast"))) or (_G.Leviathan1 and name:find("leviathan")) then
                if IsEntityAlive(entity) then
                    local root = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso") or entity.PrimaryPart
                    local distance = (root.Position - MyRoot.Position).Magnitude
                    if distance < NearestDistance then Nearest = entity; NearestDistance = distance end
                end
            end
        end
    end

    if _G.TerrorShark1 then
        local enemiesFolder = Workspace:FindFirstChild("Enemies")
        if enemiesFolder then
            for _, entity in ipairs(enemiesFolder:GetChildren()) do
                local name = entity.Name:lower()
                if name:find("terror") or name:find("shark") or name:find("piranha") then
                    if IsEntityAlive(entity) then
                        local root = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso") or entity.PrimaryPart
                        local distance = (root.Position - MyRoot.Position).Magnitude
                        if distance < NearestDistance then Nearest = entity; NearestDistance = distance end
                    end
                end
            end
        end
    end
    
    return Nearest
end

local function SetButtonOff()
    Enabled = false; TargetEntity = nil; DisableAntiGravity(); DisableNoclip()
    if Button.Parent then 
        Button.Text = "FLY: OFF"
        Stroke.Color = Color3.fromRGB(50, 150, 255)
        Button.TextColor3 = Color3.fromRGB(255, 255, 255) 
    end
end

local function SetButtonOn()
    Enabled = true
    Button.Text = "FLY: ON"
    Stroke.Color = Color3.fromRGB(0, 220, 255)
    Button.TextColor3 = Color3.fromRGB(200, 240, 255)
end

Button.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true; Moved = false; DragStart = Input.Position; StartPosition = Button.Position
    end
end)

UserInputService.InputChanged:Connect(function(Input)
    if not Dragging or (Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch) then return end
    local Delta = Input.Position - DragStart
    if math.abs(Delta.X) > 5 or math.abs(Delta.Y) > 5 then Moved = true end
    Button.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then Dragging = false end
end)

Button.Activated:Connect(function()
    if Moved then Moved = false; return end
    if Enabled then SetButtonOff(); return end
    
    SetButtonOn()
    -- Ưu tiên tìm quái trước, nếu không có mới tìm thuyền
    TargetEntity = FindNearestSeaMonster() or FindMyBoat()
end)

RunService.Heartbeat:Connect(function(DeltaTime)
    if not Enabled then 
        DisableAntiGravity()
        DisableNoclip()
        return 
    end

    local MyRoot = GetRoot()
    if not Player.Character or not MyRoot then 
        DisableAntiGravity()
        DisableNoclip()
        return 
    end

    -- LUÔN ƯU TIÊN KIỂM TRA QUÁI MỚI SPAWN HOẶC QUÁI CŨ CÒN SỐNG
    local currentMonster = FindNearestSeaMonster()
    if currentMonster then
        TargetEntity = currentMonster -- Nếu có quái xuất hiện, đổi mục tiêu ngay lập tức sang quái
    else
        -- Nếu không có quái quanh đây thì kiểm tra xem Target hiện tại có phải là quái chết chưa, nếu chết rồi thì chuyển sang tìm thuyền
        if TargetEntity and TargetEntity.Parent then
            if TargetEntity:IsA("Model") and not IsEntityAlive(TargetEntity) then
                TargetEntity = FindMyBoat()
            end
        else
            TargetEntity = FindMyBoat()
        end
    end

    if not TargetEntity then 
        DisableAntiGravity()
        DisableNoclip()
        return 
    end

    local targetPos
    local isBoat = false
    if TargetEntity:IsA("BasePart") then
        targetPos = TargetEntity.Position + Vector3.new(0, 3, 0)
        isBoat = true
    else
        local EntityRoot = TargetEntity:FindFirstChild("HumanoidRootPart") or TargetEntity:FindFirstChild("Torso") or TargetEntity.PrimaryPart
        if not EntityRoot then return end
        local targetY = EntityRoot.Position.Y + _G.DoCao
        if EntityRoot.Position.Y < 10 then 
            targetY = math.max(targetY, _G.MinWaterHeight + _G.DoCao)
        end
        targetPos = Vector3.new(EntityRoot.Position.X, targetY, EntityRoot.Position.Z)
    end

    local TargetCFrame = CFrame.new(targetPos)
    local Distance = (TargetCFrame.Position - MyRoot.Position).Magnitude

    -- Nếu là thuyền và đã đến gần thì tạm dừng bay để di chuyển tự do
    if isBoat and Distance < 5 then
        DisableAntiGravity()
        DisableNoclip()
        return
    end

    EnableAntiGravity(MyRoot)
    EnableNoclip()

    if Distance > 0.05 then
        local ActiveSpeed = _G.SEA_SPEED
        if Distance <= _G.BOOST_DISTANCE then ActiveSpeed = _G.BOOST_SPEED end
        local StepProgress = (ActiveSpeed * DeltaTime) / math.max(Distance, 0.001)
        MyRoot.CFrame = MyRoot.CFrame:Lerp(TargetCFrame, math.clamp(StepProgress, 0, 1))
    end
end)
-- ========================================================
-- CÁC TÍNH NĂNG CHẠY NGẦM TỰ ĐỘNG & BỔ SUNG
-- ========================================================

-- 1. Tự động đi trên nước ngầm
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local waterPlane = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("WaterBase-Plane")
            if waterPlane then
                waterPlane.Size = Vector3.new(1000, 112, 1000)
            end
        end)
    end
end)

-- 2. Tự động bật Buso ngầm
spawn(function()
    while wait(Sec) do
        pcall(function()
            if Boud and Player.Character then
                local _HasBuso = {"HasBuso", "Buso"}
                if not Player.Character:FindFirstChild(_HasBuso[1]) then 
                    ReplicatedStorage.Remotes.CommF_:InvokeServer(_HasBuso[2]) 
                end
            end
        end)
    end
end)

-- 3. Tự động bật Ken ngầm
spawn(function()
    while wait() do
        pcall(function()
            if Observation then
                ReplicatedStorage.Remotes.CommE:FireServer("Ken", true)
            end
        end)
    end
end)

-- 4. Tự động tăng tốc tất cả các thuyền trên biển
task.spawn(function()
    while task.wait(0.01) do
        pcall(function()
            local boatsFolder = Workspace:FindFirstChild("Boats")
            if boatsFolder then
                for _, v in pairs(boatsFolder:GetDescendants()) do
                    if v:FindFirstChild("VehicleSeat") then
                        v.VehicleSeat.MaxSpeed = 300
                        v.VehicleSeat.Torque = 0.15
                        v.VehicleSeat.TurnSpeed = 3
                        v.VehicleSeat.HeadsUpDisplay = true
                    end
                end
            end
        end)
    end
end)

-- 5. Xóa hiệu ứng ánh sáng / sương mù & Chỉnh FogEnd = 9e9
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if Lighting:FindFirstChild("LightingLayers") then Lighting.LightingLayers:Destroy() end
            if Lighting:FindFirstChild("SeaTerrorCC") then Lighting.SeaTerrorCC:Destroy() end
            if Lighting:FindFirstChild("FantasySky") then Lighting.FantasySky:Destroy() end
            
            Lighting.FogEnd = 9e9
            Lighting.GlobalShadows = false
        end)
    end
end)

-- 6. Xóa hiệu ứng Death / Respawn
spawn(function()
    while wait(Sec) do
        pcall(function()
            if RDeath and ReplicatedStorage:FindFirstChild("Effect") and ReplicatedStorage.Effect:FindFirstChild("Container") then
                local container = ReplicatedStorage.Effect.Container
                if container:FindFirstChild("Death") then container.Death:Destroy() end
                if container:FindFirstChild("Respawn") then container.Respawn:Destroy() end
            end
        end)
    end
end)

-- 7. Xóa hiệu ứng chém / hitbox kiếm
local HitEffects = {"SlashHit", "CurvedRing", "SwordSlash", "SlashTail"}
task.spawn(function()
    while task.wait(Sec) do
        if _G.DestroyHit then
            pcall(function()
                local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
                if worldOrigin then
                    for _, v in pairs(worldOrigin:GetChildren()) do
                        if table.find(HitEffects, v.Name) then
                            v:Destroy()
                        end
                    end
                end
            end)
        end
    end
end)

-- 8. Tự động quét ESP Trái Ác Quỷ ngầm (Size 12, Font mặc định, Không icon)
local function DevEsp()
    for _, v in ipairs(Workspace:GetChildren()) do
        pcall(function()
            if DevilFruitESP then
                if string.find(v.Name, "Fruit") and v:FindFirstChild('Handle') then
                    local myRoot = GetRoot()
                    if myRoot then
                        local handle = v.Handle
                        local bill = handle:FindFirstChild('NameEsp'..Number)
                        local distMeters = math.floor((myRoot.Position - handle.Position).Magnitude / 10)
                        
                        if not bill then
                            bill = Instance.new('BillboardGui', handle)
                            bill.Name = 'NameEsp'..Number
                            bill.Size = UDim2.new(0, 200, 0, 50)
                            bill.StudsOffset = Vector3.new(0, 4, 0)
                            bill.AlwaysOnTop = true
                            
                            local name = Instance.new('TextLabel', bill)
                            name.Name = 'Text'
                            name.Size = UDim2.new(1, 0, 1, 0)
                            name.BackgroundTransparency = 1
                            name.TextSize = 9
                            name.TextColor3 = Color3.fromRGB(0, 255, 255)
                            name.TextStrokeTransparency = 0
                            name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        end
                        
                        local textLabel = bill:FindFirstChild('Text')
                        if textLabel then
                            textLabel.Text = v.Name .. "\n" .. distMeters .. "m"
                        end
                    end
                end
            end
        end)
    end
end

task.spawn(function()
    while task.wait(0.5) do
        if DevilFruitESP then
            pcall(DevEsp)
        end
    end
end)

-- 9. Tự động quét ESP Đảo Sự Kiện ngầm (Size 12, Font mặc định, Không icon, Không dấu [ ])
local function EventIslandEsp()
    local locationsFolder = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if locationsFolder then
        for _, v in ipairs(locationsFolder:GetChildren()) do
            pcall(function()
                if EspEventIsland then
                    if v.Name == "Mirage Island" or v.Name == "Prehistoric Island" or v.Name == "Kitsune Island" or v.Name == "Frozen Dimension" then
                        local myRoot = GetRoot()
                        if myRoot then
                            local bill = v:FindFirstChild("NameEsp")
                            local distMeters = math.floor((myRoot.Position - v.Position).Magnitude / 10)
                            
                            if not bill then
                                bill = Instance.new("BillboardGui", v)
                                bill.Name = "NameEsp"
                                bill.StudsOffset = Vector3.new(0, 5, 0)
                                bill.Size = UDim2.new(0, 200, 0, 50)
                                bill.AlwaysOnTop = true
                                
                                local name = Instance.new("TextLabel", bill)
                                name.Name = "Text"
                                name.Size = UDim2.new(1, 0, 1, 0)
                                name.BackgroundTransparency = 1
                                name.TextSize = 9
                                name.TextColor3 = Color3.fromRGB(80, 245, 245)
                                name.TextStrokeTransparency = 0
                                name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            end
                            
                            local textLabel = bill:FindFirstChild("Text")
                            if textLabel then
                                textLabel.Text = v.Name .. "\n" .. distMeters .. "m"
                            end
                        end
                    end
                else
                    if v:FindFirstChild("NameEsp") then
                        v:FindFirstChild("NameEsp"):Destroy()
                    end
                end
            end)
        end
    end
end
task.spawn(function()
    while task.wait(0.5) do
        if EspEventIsland then
            pcall(EventIslandEsp)
        end
    end
end)

-- 10. Tắt thông báo sát thương (Damage Counter)
task.spawn(function()
    while task.wait(Sec) do
        pcall(function()
            if ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("GUI") and ReplicatedStorage.Assets.GUI:FindFirstChild("DamageCounter") then
                if _G.TatTBDame then
                    ReplicatedStorage.Assets.GUI.DamageCounter.Enabled = false
                else
                    ReplicatedStorage.Assets.GUI.DamageCounter.Enabled = true
                end
            end
        end)
    end
end)

-- 11. Tự động tắt va chạm và làm trong suốt vật liệu Slate trong phạm vi 100 studs
local rockNames = {
    rock1 = true,
    rock2 = true,
    rock3 = true,
    rock4 = true,
    ["bloxfruit_island2_Cylinder.104"] = true
}

local function RemoveRock(obj)
    if not obj:IsA("BasePart") then
        return
    end

    local isRock =
        rockNames[obj.Name]
        or obj:GetFullName():find("Meshes/bloxfruit_island2_Cylinder.104", 1, true)

    if isRock and obj.Material == Enum.Material.Slate then
        obj.Size = Vector3.new(0.0001, 0.0001, 0.0001)
        obj.LocalTransparencyModifier = 1
        obj.CanCollide = false
        obj.CanTouch = false
        obj.CanQuery = false
    end
end

for _, obj in ipairs(workspace:GetDescendants()) do
    RemoveRock(obj)
end

workspace.DescendantAdded:Connect(function(obj)
    task.defer(function()
        RemoveRock(obj)
    end)
end)

-- ========================================================
-- HỆ THỐNG ESP THUYỀN (Size 12, Font mặc định, Không icon)
-- ========================================================
task.spawn(function()
    while task.wait(0.2) do
        if _G.BoatESP then
            pcall(function()
                local boatsFolder = Workspace:FindFirstChild("Boats")
                local myRoot = GetRoot()
                
                if boatsFolder and myRoot then
                    for _, boat in ipairs(boatsFolder:GetChildren()) do
                        local isMyBoat = false
                        if boat.Name:find(Player.Name) then
                            isMyBoat = true
                        else
                            for _, descendant in ipairs(boat:GetDescendants()) do
                                if descendant:IsA("ObjectValue") and descendant.Value == Player then
                                    isMyBoat = true
                                    break
                                elseif descendant:IsA("StringValue") and descendant.Value == Player.Name then
                                    isMyBoat = true
                                    break
                                end
                            end
                        end
                        
                        if isMyBoat then
                            local boatCore = boat.PrimaryPart or boat:FindFirstChild("Hull") or boat:FindFirstChild("Seat") or boat:FindFirstChildOfClass("BasePart")
                            if boatCore then
                                local bill = boatCore:FindFirstChild("AxiomBoatESP")
                                local distMeters = math.floor((boatCore.Position - myRoot.Position).Magnitude / 10)
                                
                                if not bill then
                                    bill = Instance.new("BillboardGui")
                                    bill.Name = "AxiomBoatESP"
                                    bill.Size = UDim2.new(0, 200, 0, 50)
                                    bill.StudsOffset = Vector3.new(0, 6, 0)
                                    bill.AlwaysOnTop = true
                                    
                                    local txt = Instance.new("TextLabel")
                                    txt.Name = "Text"
                                    txt.Size = UDim2.new(1, 0, 1, 0)
                                    txt.BackgroundTransparency = 1
                                    txt.TextColor3 = Color3.fromRGB(0, 255, 255)
                                    txt.TextStrokeTransparency = 0
                                    txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                                    txt.TextSize = 9
                                    txt.Parent = bill
                                    
                                    bill.Parent = boatCore
                                end
                                
                                local textLabel = bill:FindFirstChild("Text")
                                if textLabel then
                                    textLabel.Text = "THUYỀN\n[" .. distMeters .. "m]"
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)
