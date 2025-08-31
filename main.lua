-- (Replaces your original script. All features preserved; internal implementation optimized.)
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Drawings = {
    ESP = {},
    Tracers = {},
    Boxes = {},
    Healthbars = {},
    Names = {},
    Distances = {},
    Snaplines = {},
    Skeleton = {}
}

local Colors = {
    Enemy = Color3.fromRGB(255, 25, 25),
    Ally = Color3.fromRGB(25, 255, 25),
    Neutral = Color3.fromRGB(255, 255, 255),
    Selected = Color3.fromRGB(255, 210, 0),
    Health = Color3.fromRGB(0, 255, 0),
    Distance = Color3.fromRGB(200, 200, 200),
    Rainbow = nil
}

local Settings = {
    Enabled = false,
    TeamCheck = false,
    ShowTeam = false,
    VisibilityCheck = true,
    BoxESP = false,
    BoxStyle = "Corner",
    BoxOutline = true,
    BoxFilled = false,
    BoxFillTransparency = 0.5,
    BoxThickness = 1,
    TracerESP = false,
    TracerOrigin = "Bottom",
    TracerStyle = "Line",
    TracerThickness = 1,
    HealthESP = false,
    HealthStyle = "Bar",
    HealthBarSide = "Left",
    HealthTextSuffix = "HP",
    NameESP = true,
    NameMode = "DisplayName",
    ShowDistance = false,
    DistanceUnit = "studs",
    TextSize = 14,
    TextFont = 2,
    RainbowSpeed = 1,
    MaxDistance = 1000,
    RefreshRate = 1/144,
    Snaplines = false,
    SnaplineStyle = "Straight",
    RainbowEnabled = false,
    RainbowBoxes = false,
    RainbowTracers = false,
    RainbowText = false,
    SkeletonESP = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    SkeletonThickness = 1.5,
    SkeletonTransparency = 1
}

-- Helper: safely set Visible=false for all esp pieces (used in early returns)
local function hideAllForESP(esp)
    if not esp then return end
    if esp.Box then
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" and obj.Connectors then
                -- box.Sub items include connectors table - handle separately
                for _, c in ipairs(obj.Connectors) do c.Visible = false end
            elseif typeof(obj) == "Instance" or type(obj) == "table" then
                -- instance-like Drawing objects in the box table
                if obj.Visible ~= nil then obj.Visible = false end
            end
        end
    end
    if esp.Tracer and esp.Tracer.Visible ~= nil then esp.Tracer.Visible = false end
    if esp.HealthBar then
        for _, obj in pairs(esp.HealthBar) do if obj and obj.Visible ~= nil then obj.Visible = false end end
    end
    if esp.Info then
        for _, obj in pairs(esp.Info) do if obj and obj.Visible ~= nil then obj.Visible = false end end
    end
    if esp.Snapline and esp.Snapline.Visible ~= nil then esp.Snapline.Visible = false end
end

local function CreateESP(player)
    if player == LocalPlayer then return end

    -- Box (8 core lines)
    local box = {
        TopLeft = Drawing.new("Line"),
        TopRight = Drawing.new("Line"),
        BottomLeft = Drawing.new("Line"),
        BottomRight = Drawing.new("Line"),
        Left = Drawing.new("Line"),
        Right = Drawing.new("Line"),
        Top = Drawing.new("Line"),
        Bottom = Drawing.new("Line"),
        -- Precreate connectors for 3D boxes (reuse each frame)
        Connectors = {
            Drawing.new("Line"),
            Drawing.new("Line"),
            Drawing.new("Line"),
            Drawing.new("Line")
        }
    }

    -- Initialize box lines quickly
    for _, line in pairs(box) do
        if type(line) == "table" then
            for _, c in ipairs(line) do
                c.Visible = false
                c.Color = Colors.Enemy
                c.Thickness = Settings.BoxThickness
            end
        else
            line.Visible = false
            line.Color = Colors.Enemy
            line.Thickness = Settings.BoxThickness
        end
    end

    -- Tracer
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Colors.Enemy
    tracer.Thickness = Settings.TracerThickness

    -- Healthbar
    local healthBar = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }
    healthBar.Outline.Visible = false
    healthBar.Fill.Visible = false
    healthBar.Text.Visible = false
    healthBar.Fill.Filled = true
    healthBar.Text.Center = true
    healthBar.Text.Size = Settings.TextSize
    healthBar.Text.Color = Colors.Health
    healthBar.Text.Font = Settings.TextFont

    -- Info texts
    local info = {
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }
    for _, text in pairs(info) do
        text.Visible = false
        text.Center = true
        text.Size = Settings.TextSize
        text.Color = Colors.Enemy
        text.Font = Settings.TextFont
        text.Outline = true
    end

    -- Snapline
    local snapline = Drawing.new("Line")
    snapline.Visible = false
    snapline.Color = Colors.Enemy
    snapline.Thickness = 1

    -- Skeleton (precreate all lines)
    local skeleton = {
        Head = Drawing.new("Line"),
        Neck = Drawing.new("Line"),
        UpperSpine = Drawing.new("Line"),
        LowerSpine = Drawing.new("Line"),

        LeftShoulder = Drawing.new("Line"),
        LeftUpperArm = Drawing.new("Line"),
        LeftLowerArm = Drawing.new("Line"),
        LeftHand = Drawing.new("Line"),

        RightShoulder = Drawing.new("Line"),
        RightUpperArm = Drawing.new("Line"),
        RightLowerArm = Drawing.new("Line"),
        RightHand = Drawing.new("Line"),

        LeftHip = Drawing.new("Line"),
        LeftUpperLeg = Drawing.new("Line"),
        LeftLowerLeg = Drawing.new("Line"),
        LeftFoot = Drawing.new("Line"),

        RightHip = Drawing.new("Line"),
        RightUpperLeg = Drawing.new("Line"),
        RightLowerLeg = Drawing.new("Line"),
        RightFoot = Drawing.new("Line")
    }
    for _, line in pairs(skeleton) do
        line.Visible = false
        line.Color = Settings.SkeletonColor
        line.Thickness = Settings.SkeletonThickness
        line.Transparency = Settings.SkeletonTransparency
    end

    -- Save references
    Drawings.Skeleton[player] = skeleton
    Drawings.ESP[player] = {
        Box = box,
        Tracer = tracer,
        HealthBar = healthBar,
        Info = info,
        Snapline = snapline
    }
end

local function RemoveESP(player)
    local esp = Drawings.ESP[player]
    if esp then
        if esp.Box then
            for k, obj in pairs(esp.Box) do
                if k == "Connectors" and type(obj) == "table" then
                    for _, c in ipairs(obj) do c:Remove() end
                elseif obj and obj.Remove then
                    obj:Remove()
                end
            end
        end
        if esp.Tracer and esp.Tracer.Remove then esp.Tracer:Remove() end
        if esp.HealthBar then
            for _, obj in pairs(esp.HealthBar) do if obj and obj.Remove then obj:Remove() end end
        end
        if esp.Info then
            for _, obj in pairs(esp.Info) do if obj and obj.Remove then obj:Remove() end end
        end
        if esp.Snapline and esp.Snapline.Remove then esp.Snapline:Remove() end
        Drawings.ESP[player] = nil
    end

    local skeleton = Drawings.Skeleton[player]
    if skeleton then
        for _, line in pairs(skeleton) do
            if line and line.Remove then line:Remove() end
        end
        Drawings.Skeleton[player] = nil
    end
end

local function GetPlayerColor(player)
    if Settings.RainbowEnabled then
        if Settings.RainbowBoxes and Settings.BoxESP then return Colors.Rainbow end
        if Settings.RainbowTracers and Settings.TracerESP then return Colors.Rainbow end
        if Settings.RainbowText and (Settings.NameESP or Settings.HealthESP) then return Colors.Rainbow end
    end
    return player.Team == LocalPlayer.Team and Colors.Ally or Colors.Enemy
end

local function GetBoxCorners(cf, size)
    local corners = {
        Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
        Vector3.new(-size.X/2, -size.Y/2, size.Z/2),
        Vector3.new(-size.X/2, size.Y/2, -size.Z/2),
        Vector3.new(-size.X/2, size.Y/2, size.Z/2),
        Vector3.new(size.X/2, -size.Y/2, -size.Z/2),
        Vector3.new(size.X/2, -size.Y/2, size.Z/2),
        Vector3.new(size.X/2, size.Y/2, -size.Z/2),
        Vector3.new(size.X/2, size.Y/2, size.Z/2)
    }

    for i, corner in ipairs(corners) do
        corners[i] = cf:PointToWorldSpace(corner)
    end

    return corners
end

local function GetTracerOrigin()
    local origin = Settings.TracerOrigin
    if origin == "Bottom" then
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
    elseif origin == "Top" then
        return Vector2.new(Camera.ViewportSize.X/2, 0)
    elseif origin == "Mouse" then
        return UserInputService:GetMouseLocation()
    else
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end
end

-- Utility: world to viewport wrapper that returns (vec2, visible, z)
local function W2V(point)
    local v3, vis = Camera:WorldToViewportPoint(point)
    return Vector2.new(v3.X, v3.Y), vis, v3.Z
end

local function UpdateESP(player)
    if not Settings.Enabled then return end

    local esp = Drawings.ESP[player]
    if not esp then return end

    local character = player.Character
    if not character then
        hideAllForESP(esp)
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        hideAllForESP(esp)
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    -- Single W2V for root to reduce repeated calls
    local rootVec3, rootOnScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not rootOnScreen then
        hideAllForESP(esp)
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        hideAllForESP(esp)
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    local pos, onScreen, z = Vector2.new(rootVec3.X, rootVec3.Y), rootOnScreen, rootVec3.Z
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if not onScreen or distance > Settings.MaxDistance then
        hideAllForESP(esp)
        return
    end

    if Settings.TeamCheck and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
        hideAllForESP(esp)
        return
    end

    local color = GetPlayerColor(player)
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame

    -- Localize viewport size for bounds checks
    local viewport = Camera.ViewportSize
    local vW, vH = viewport.X, viewport.Y

    -- Compute top & bottom points for box size calculation only when needed
    local topVec3, topOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
    local botVec3, botOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)
    if not topOn or not botOn then
        hideAllForESP(esp)
        return
    end

    local screenSize = botVec3.Y - topVec3.Y
    local boxWidth = screenSize * 0.65
    local boxPosition = Vector2.new(topVec3.X - boxWidth/2, topVec3.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)

    -- Hide all box lines to begin with (cheap)
    for _, obj in pairs(esp.Box) do
        if type(obj) == "table" and obj.Connectors then
            for _, c in ipairs(obj.Connectors) do c.Visible = false end
        else
            if obj.Visible ~= nil then obj.Visible = false end
        end
    end

    -- BOX
    if Settings.BoxESP then
        if Settings.BoxStyle == "ThreeD" then
            -- front face
            local fTLv3 = (cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2)).Position
            local fTRv3 = (cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2)).Position
            local fBLv3 = (cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)).Position
            local fBRv3 = (cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2)).Position

            -- back face
            local bTLv3 = (cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2)).Position
            local bTRv3 = (cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)).Position
            local bBLv3 = (cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)).Position
            local bBRv3 = (cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2)).Position

            local fTL, fTLOn, fTLZ = Camera:WorldToViewportPoint(fTLv3)
            local fTR, fTROn, fTRZ = Camera:WorldToViewportPoint(fTRv3)
            local fBL, fBLOn, fBLZ = Camera:WorldToViewportPoint(fBLv3)
            local fBR, fBROn, fBRZ = Camera:WorldToViewportPoint(fBRv3)

            local bTL, bTLOn, bTLZ = Camera:WorldToViewportPoint(bTLv3)
            local bTR, bTROn, bTRZ = Camera:WorldToViewportPoint(bTRv3)
            local bBL, bBLOn, bBLZ = Camera:WorldToViewportPoint(bBLv3)
            local bBR, bBROn, bBRZ = Camera:WorldToViewportPoint(bBRv3)

            if not (fTLOn and fTROn and fBLOn and fBROn and bTLOn and bTROn and bBLOn and bBROn) then
                hideAllForESP(esp)
                return
            end

            local function toV2(v3) return Vector2.new(v3.X, v3.Y) end
            fTL, fTR, fBL, fBR = toV2(fTL), toV2(fTR), toV2(fBL), toV2(fBR)
            bTL, bTR, bBL, bBR = toV2(bTL), toV2(bTR), toV2(bBL), toV2(bBR)

            -- Front face (use precreated lines)
            esp.Box.TopLeft.From = fTL
            esp.Box.TopLeft.To = fTR
            esp.Box.TopLeft.Visible = true

            esp.Box.TopRight.From = fTR
            esp.Box.TopRight.To = fBR
            esp.Box.TopRight.Visible = true

            esp.Box.BottomLeft.From = fBL
            esp.Box.BottomLeft.To = fBR
            esp.Box.BottomLeft.Visible = true

            esp.Box.BottomRight.From = fTL
            esp.Box.BottomRight.To = fBL
            esp.Box.BottomRight.Visible = true

            -- Back face (reuse lines)
            esp.Box.Left.From = bTL
            esp.Box.Left.To = bTR
            esp.Box.Left.Visible = true

            esp.Box.Right.From = bTR
            esp.Box.Right.To = bBR
            esp.Box.Right.Visible = true

            esp.Box.Top.From = bBL
            esp.Box.Top.To = bBR
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = bTL
            esp.Box.Bottom.To = bBL
            esp.Box.Bottom.Visible = true

            -- Connectors (reuse precreated connectors)
            local connectors = esp.Box.Connectors
            local conPts = {
                {fTL, bTL},
                {fTR, bTR},
                {fBL, bBL},
                {fBR, bBR}
            }
            for i = 1, 4 do
                local c = connectors[i]
                c.From = conPts[i][1]
                c.To = conPts[i][2]
                c.Color = color
                c.Thickness = Settings.BoxThickness
                c.Visible = true
            end

        elseif Settings.BoxStyle == "Corner" then
            local cornerSize = boxWidth * 0.2

            esp.Box.TopLeft.From = boxPosition
            esp.Box.TopLeft.To = boxPosition + Vector2.new(cornerSize, 0)
            esp.Box.TopLeft.Visible = true

            esp.Box.TopRight.From = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.TopRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, 0)
            esp.Box.TopRight.Visible = true

            esp.Box.BottomLeft.From = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.BottomLeft.To = boxPosition + Vector2.new(cornerSize, boxSize.Y)
            esp.Box.BottomLeft.Visible = true

            esp.Box.BottomRight.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.BottomRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
            esp.Box.BottomRight.Visible = true

            esp.Box.Left.From = boxPosition
            esp.Box.Left.To = boxPosition + Vector2.new(0, cornerSize)
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, cornerSize)
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Top.To = boxPosition + Vector2.new(0, boxSize.Y - cornerSize)
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
            esp.Box.Bottom.Visible = true

        else -- Full box
            esp.Box.Left.From = boxPosition
            esp.Box.Left.To = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPosition
            esp.Box.Top.To = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.Visible = true

            esp.Box.TopLeft.Visible = false
            esp.Box.TopRight.Visible = false
            esp.Box.BottomLeft.Visible = false
            esp.Box.BottomRight.Visible = false
        end

        -- Apply color/thickness to visible box lines (cheap loop)
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" and obj.Connectors then
                for _, c in ipairs(obj.Connectors) do
                    if c.Visible then
                        c.Color = color
                        c.Thickness = Settings.BoxThickness
                    end
                end
            else
                if obj.Visible then
                    obj.Color = color
                    obj.Thickness = Settings.BoxThickness
                end
            end
        end
    end

    -- TRACER
    if Settings.TracerESP then
        esp.Tracer.From = GetTracerOrigin()
        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Thickness = Settings.TracerThickness
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end

    -- HEALTH
    if Settings.HealthESP then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = health / maxHealth

        local barHeight = screenSize * 0.8
        local barWidth = 4
        local barPos = Vector2.new(
            boxPosition.X - barWidth - 2,
            boxPosition.Y + (screenSize - barHeight) / 2
        )

        esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
        esp.HealthBar.Outline.Position = barPos

        esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
        esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1 - healthPercent))
        esp.HealthBar.Fill.Color = Color3.fromRGB(255 - (255 * healthPercent), 255 * healthPercent, 0)

        esp.HealthBar.Text.Text = math.floor(health) .. Settings.HealthTextSuffix
        esp.HealthBar.Text.Position = Vector2.new(barPos.X + barWidth - 20, barPos.Y + barHeight / 2)

        if Settings.HealthStyle == "Both" then
            esp.HealthBar.Fill.Visible = true
            esp.HealthBar.Outline.Visible = true
            esp.HealthBar.Text.Visible = true
        elseif Settings.HealthStyle == "Text" then
            esp.HealthBar.Fill.Visible = false
            esp.HealthBar.Outline.Visible = false
            esp.HealthBar.Text.Visible = true
        else
            esp.HealthBar.Fill.Visible = true
            esp.HealthBar.Outline.Visible = true
            esp.HealthBar.Text.Visible = false
        end
    else
        for _, obj in pairs(esp.HealthBar) do
            if obj and obj.Visible ~= nil then obj.Visible = false end
        end
    end

    -- NAME
    if Settings.NameESP then
        esp.Info.Name.Text = player.DisplayName
        esp.Info.Name.Position = Vector2.new(
            boxPosition.X + boxWidth / 2,
            boxPosition.Y
        )
        esp.Info.Name.Color = color
        esp.Info.Name.Visible = true
    else
        esp.Info.Name.Visible = false
    end

    -- SNAPLINE
    if Settings.Snaplines then
        esp.Snapline.From = Vector2.new(vW / 2, vH)
        esp.Snapline.To = Vector2.new(pos.X, pos.Y)
        esp.Snapline.Color = color
        esp.Snapline.Visible = true
    else
        esp.Snapline.Visible = false
    end

    -- SKELETON
    if Settings.SkeletonESP then
        local function getBonePositions(character)
            if not character then return nil end

            local find = character.FindFirstChild
            local bones = {
                Head = find(character, "Head"),
                UpperTorso = find(character, "UpperTorso") or find(character, "Torso"),
                LowerTorso = find(character, "LowerTorso") or find(character, "Torso"),
                RootPart = find(character, "HumanoidRootPart"),

                LeftUpperArm = find(character, "LeftUpperArm") or find(character, "Left Arm"),
                LeftLowerArm = find(character, "LeftLowerArm") or find(character, "Left Arm"),
                LeftHand = find(character, "LeftHand") or find(character, "Left Arm"),

                RightUpperArm = find(character, "RightUpperArm") or find(character, "Right Arm"),
                RightLowerArm = find(character, "RightLowerArm") or find(character, "Right Arm"),
                RightHand = find(character, "RightHand") or find(character, "Right Arm"),

                LeftUpperLeg = find(character, "LeftUpperLeg") or find(character, "Left Leg"),
                LeftLowerLeg = find(character, "LeftLowerLeg") or find(character, "Left Leg"),
                LeftFoot = find(character, "LeftFoot") or find(character, "Left Leg"),

                RightUpperLeg = find(character, "RightUpperLeg") or find(character, "Right Leg"),
                RightLowerLeg = find(character, "RightLowerLeg") or find(character, "Right Leg"),
                RightFoot = find(character, "RightFoot") or find(character, "Right Leg")
            }

            if not (bones.Head and bones.UpperTorso) then return nil end
            return bones
        end

        local function drawBone(from, to, line)
            if not from or not to then line.Visible = false return end
            local fromPos = from.Position
            local toPos = to.Position
            local fromScreen3, fromVis = Camera:WorldToViewportPoint(fromPos)
            local toScreen3, toVis = Camera:WorldToViewportPoint(toPos)
            if not (fromVis and toVis) or fromScreen3.Z < 0 or toScreen3.Z < 0 then
                line.Visible = false
                return
            end
            local fx, fy = fromScreen3.X, fromScreen3.Y
            local tx, ty = toScreen3.X, toScreen3.Y
            if fx < 0 or fx > vW or fy < 0 or fy > vH or tx < 0 or tx > vW or ty < 0 or ty > vH then
                line.Visible = false
                return
            end
            line.From = Vector2.new(fx, fy)
            line.To = Vector2.new(tx, ty)
            line.Color = Settings.SkeletonColor
            line.Thickness = Settings.SkeletonThickness
            line.Transparency = Settings.SkeletonTransparency
            line.Visible = true
        end

        local bones = getBonePositions(character)
        if bones then
            local skeleton = Drawings.Skeleton[player]
            if skeleton then
                drawBone(bones.Head, bones.UpperTorso, skeleton.Head)
                drawBone(bones.UpperTorso, bones.LowerTorso, skeleton.UpperSpine)

                drawBone(bones.UpperTorso, bones.LeftUpperArm, skeleton.LeftShoulder)
                drawBone(bones.LeftUpperArm, bones.LeftLowerArm, skeleton.LeftUpperArm)
                drawBone(bones.LeftLowerArm, bones.LeftHand, skeleton.LeftLowerArm)

                drawBone(bones.UpperTorso, bones.RightUpperArm, skeleton.RightShoulder)
                drawBone(bones.RightUpperArm, bones.RightLowerArm, skeleton.RightUpperArm)
                drawBone(bones.RightLowerArm, bones.RightHand, skeleton.RightLowerArm)

                drawBone(bones.LowerTorso, bones.LeftUpperLeg, skeleton.LeftHip)
                drawBone(bones.LeftUpperLeg, bones.LeftLowerLeg, skeleton.LeftUpperLeg)
                drawBone(bones.LeftLowerLeg, bones.LeftFoot, skeleton.LeftLowerLeg)

                drawBone(bones.LowerTorso, bones.RightUpperLeg, skeleton.RightHip)
                drawBone(bones.RightUpperLeg, bones.RightLowerLeg, skeleton.RightUpperLeg)
                drawBone(bones.RightLowerLeg, bones.RightFoot, skeleton.RightLowerLeg)
            end
        end
    else
        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do line.Visible = false end
        end
    end
end

local function DisableESP_full()
    for _, player in ipairs(Players:GetPlayers()) do
        local esp = Drawings.ESP[player]
        if esp then hideAllForESP(esp) end
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
    end
end

local function CleanupESP()
    for _, player in ipairs(Players:GetPlayers()) do
        RemoveESP(player)
    end
    Drawings.ESP = {}
    Drawings.Skeleton = {}
end

-- UI / Fluent setup (unchanged semantics)
local Window = Fluent:CreateWindow({
    Title = "Universal ESP",
    SubTitle = "by WA",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Config = Window:AddTab({ Title = "Config", Icon = "save" })
}

do
    local MainSection = Tabs.ESP:AddSection("Main ESP")

    local EnabledToggle = MainSection:AddToggle("Enabled", {
        Title = "Enable ESP",
        Default = false
    })
    EnabledToggle:OnChanged(function()
        Settings.Enabled = EnabledToggle.Value
        if not Settings.Enabled then
            CleanupESP()
        else
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    CreateESP(player)
                end
            end
        end
    end)

    local TeamCheckToggle = MainSection:AddToggle("TeamCheck", {
        Title = "Team Check",
        Default = false
    })
    TeamCheckToggle:OnChanged(function()
        Settings.TeamCheck = TeamCheckToggle.Value
    end)

    local ShowTeamToggle = MainSection:AddToggle("ShowTeam", {
        Title = "Show Team",
        Default = false
    })
    ShowTeamToggle:OnChanged(function()
        Settings.ShowTeam = ShowTeamToggle.Value
    end)

    local BoxSection = Tabs.ESP:AddSection("Box ESP")

    local BoxESPToggle = BoxSection:AddToggle("BoxESP", {
        Title = "Box ESP",
        Default = false
    })
    BoxESPToggle:OnChanged(function()
        Settings.BoxESP = BoxESPToggle.Value
    end)

    local BoxStyleDropdown = BoxSection:AddDropdown("BoxStyle", {
        Title = "Box Style",
        Values = {"Corner", "Full", "ThreeD"},
        Default = "ThreeD"
    })
    BoxStyleDropdown:OnChanged(function(Value)
        Settings.BoxStyle = Value
    end)

    local TracerSection = Tabs.ESP:AddSection("Tracer ESP")

    local TracerESPToggle = TracerSection:AddToggle("TracerESP", {
        Title = "Tracer ESP",
        Default = false
    })
    TracerESPToggle:OnChanged(function()
        Settings.TracerESP = TracerESPToggle.Value
    end)

    local TracerOriginDropdown = TracerSection:AddDropdown("TracerOrigin", {
        Title = "Tracer Origin",
        Values = {"Bottom", "Top", "Mouse", "Center"},
        Default = "Bottom"
    })
    TracerOriginDropdown:OnChanged(function(Value)
        Settings.TracerOrigin = Value
    end)

    local HealthSection = Tabs.ESP:AddSection("Health ESP")

    local HealthESPToggle = HealthSection:AddToggle("HealthESP", {
        Title = "Health Bar",
        Default = false
    })
    HealthESPToggle:OnChanged(function()
        Settings.HealthESP = HealthESPToggle.Value
    end)

    local HealthStyleDropdown = HealthSection:AddDropdown("HealthStyle", {
        Title = "Health Style",
        Values = {"Bar", "Text", "Both"},
        Default = "Bar"
    })
    HealthStyleDropdown:OnChanged(function(Value)
        Settings.HealthStyle = Value
    end)
end

do
    local ColorsSection = Tabs.Settings:AddSection("Colors")

    local EnemyColor = ColorsSection:AddColorpicker("EnemyColor", {
        Title = "Enemy Color",
        Description = "Color for enemy players",
        Default = Colors.Enemy
    })
    EnemyColor:OnChanged(function(Value)
        Colors.Enemy = Value
    end)

    local AllyColor = ColorsSection:AddColorpicker("AllyColor", {
        Title = "Ally Color",
        Description = "Color for team members",
        Default = Colors.Ally
    })
    AllyColor:OnChanged(function(Value)
        Colors.Ally = Value
    end)

    local HealthColor = ColorsSection:AddColorpicker("HealthColor", {
        Title = "Health Bar Color",
        Description = "Color for full health",
        Default = Colors.Health
    })
    HealthColor:OnChanged(function(Value)
        Colors.Health = Value
    end)

    local BoxSection = Tabs.Settings:AddSection("Box Settings")

    local BoxThickness = BoxSection:AddSlider("BoxThickness", {
        Title = "Box Thickness",
        Default = 1,
        Min = 1,
        Max = 5,
        Rounding = 1
    })
    BoxThickness:OnChanged(function(Value)
        Settings.BoxThickness = Value
    end)

    local BoxTransparency = BoxSection:AddSlider("BoxTransparency", {
        Title = "Box Transparency",
        Default = 1,
        Min = 0,
        Max = 1,
        Rounding = 2
    })
    BoxTransparency:OnChanged(function(Value)
        Settings.BoxFillTransparency = Value
    end)

    local ESPSection = Tabs.Settings:AddSection("ESP Settings")

    local MaxDistance = ESPSection:AddSlider("MaxDistance", {
        Title = "Max Distance",
        Default = 1000,
        Min = 100,
        Max = 5000,
        Rounding = 0
    })
    MaxDistance:OnChanged(function(Value)
        Settings.MaxDistance = Value
    end)

    local TextSize = ESPSection:AddSlider("TextSize", {
        Title = "Text Size",
        Default = 14,
        Min = 10,
        Max = 24,
        Rounding = 0
    })
    TextSize:OnChanged(function(Value)
        Settings.TextSize = Value
    end)

    local HealthTextFormat = ESPSection:AddDropdown("HealthTextFormat", {
        Title = "Health Format",
        Values = {"Number", "Percentage", "Both"},
        Default = "Number"
    })
    HealthTextFormat:OnChanged(function(Value)
        Settings.HealthTextFormat = Value
    end)

    local EffectsSection = Tabs.Settings:AddSection("Effects")

    local RainbowToggle = EffectsSection:AddToggle("RainbowEnabled", {
        Title = "Rainbow Mode",
        Default = false
    })
    RainbowToggle:OnChanged(function()
        Settings.RainbowEnabled = RainbowToggle.Value
    end)

    local RainbowSpeed = EffectsSection:AddSlider("RainbowSpeed", {
        Title = "Rainbow Speed",
        Default = 1,
        Min = 0.1,
        Max = 5,
        Rounding = 1
    })
    RainbowSpeed:OnChanged(function(Value)
        Settings.RainbowSpeed = Value
    end)

    local RainbowOptions = EffectsSection:AddDropdown("RainbowParts", {
        Title = "Rainbow Parts",
        Values = {"All", "Box Only", "Tracers Only", "Text Only"},
        Default = "All",
        Multi = false
    })
    RainbowOptions:OnChanged(function(Value)
        if Value == "All" then
            Settings.RainbowBoxes = true
            Settings.RainbowTracers = true
            Settings.RainbowText = true
        elseif Value == "Box Only" then
            Settings.RainbowBoxes = true
            Settings.RainbowTracers = false
            Settings.RainbowText = false
        elseif Value == "Tracers Only" then
            Settings.RainbowBoxes = false
            Settings.RainbowTracers = true
            Settings.RainbowText = false
        elseif Value == "Text Only" then
            Settings.RainbowBoxes = false
            Settings.RainbowTracers = false
            Settings.RainbowText = true
        end
    end)

    local PerformanceSection = Tabs.Settings:AddSection("Performance")

    local RefreshRate = PerformanceSection:AddSlider("RefreshRate", {
        Title = "Refresh Rate",
        Default = 144,
        Min = 1,
        Max = 144,
        Rounding = 0
    })
    RefreshRate:OnChanged(function(Value)
        Settings.RefreshRate = 1/Value
    end)
end

do
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("WAUniversalESP")
    SaveManager:SetFolder("WAUniversalESP/configs")

    InterfaceManager:BuildInterfaceSection(Tabs.Config)
    SaveManager:BuildConfigSection(Tabs.Config)

    local UnloadSection = Tabs.Config:AddSection("Unload")

    local UnloadButton = UnloadSection:AddButton({
        Title = "Unload ESP",
        Description = "Completely remove the ESP",
        Callback = function()
            CleanupESP()
            for _, connection in pairs(getconnections(RunService.RenderStepped)) do
                connection:Disable()
            end
            Window:Destroy()
            Drawings = nil
            Settings = nil
            for k, v in pairs(getfenv(1)) do
                getfenv(1)[k] = nil
            end
        end
    })
end

-- Rainbow updater (throttled)
task.spawn(function()
    while true do
        if Settings.RainbowEnabled then
            Colors.Rainbow = Color3.fromHSV(tick() * Settings.RainbowSpeed % 1, 1, 1)
        end
        task.wait(0.1)
    end
end)

local lastUpdate = 0
local lastEnabled = Settings.Enabled

-- Render loop (optimized)
RunService.RenderStepped:Connect(function()
    -- If toggled off, ensure it's cleaned once and avoid repeating heavy work
    if not Settings.Enabled then
        if lastEnabled then
            DisableESP_full()
            lastEnabled = false
        end
        return
    end
    lastEnabled = true

    local currentTime = tick()
    if currentTime - lastUpdate >= Settings.RefreshRate then
        local players = Players:GetPlayers()
        for _, player in ipairs(players) do
            if player ~= LocalPlayer then
                if not Drawings.ESP[player] then
                    CreateESP(player)
                end
                UpdateESP(player)
            end
        end
        lastUpdate = currentTime
    end
end)

Players.PlayerAdded:Connect(function(p) CreateESP(p) end)
Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Window:SelectTab(1)

Fluent:Notify({
    Title = "WA Universal ESP",
    Content = "Loaded successfully!",
    Duration = 5
})

local SkeletonSection = Tabs.ESP:AddSection("Skeleton ESP")

local SkeletonESPToggle = SkeletonSection:AddToggle("SkeletonESP", {
    Title = "Skeleton ESP",
    Default = false
})
SkeletonESPToggle:OnChanged(function()
    Settings.SkeletonESP = SkeletonESPToggle.Value
end)

local SkeletonColor = SkeletonSection:AddColorpicker("SkeletonColor", {
    Title = "Skeleton Color",
    Default = Settings.SkeletonColor
})
SkeletonColor:OnChanged(function(Value)
    Settings.SkeletonColor = Value
    for _, player in ipairs(Players:GetPlayers()) do
        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Color = Value
            end
        end
    end
end)

local SkeletonThickness = SkeletonSection:AddSlider("SkeletonThickness", {
    Title = "Line Thickness",
    Default = 1,
    Min = 1,
    Max = 3,
    Rounding = 1
})
SkeletonThickness:OnChanged(function(Value)
    Settings.SkeletonThickness = Value
    for _, player in ipairs(Players:GetPlayers()) do
        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Thickness = Value
            end
        end
    end
end)

local SkeletonTransparency = SkeletonSection:AddSlider("SkeletonTransparency", {
    Title = "Transparency",
    Default = 1,
    Min = 0,
    Max = 1,
    Rounding = 2
})
SkeletonTransparency:OnChanged(function(Value)
    Settings.SkeletonTransparency = Value
    for _, player in ipairs(Players:GetPlayers()) do
        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Transparency = Value
            end
        end
    end
end)
