--[[ how esp works:
    (original comment left intact)
--]]

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

local Highlights = {}

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
    NameESP = false,
    NameMode = "DisplayName",
    ShowDistance = true,
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
    ChamsEnabled = false,
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOccludedColor = Color3.fromRGB(150, 0, 0),
    ChamsTransparency = 0.5,
    ChamsOutlineTransparency = 0,
    ChamsOutlineThickness = 0.1,
    SkeletonESP = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    SkeletonThickness = 1.5,
    SkeletonTransparency = 1
}

local function CreateESP(player)
    if player == LocalPlayer then return end

    local box = {
        -- corner horizontals
        TopLeft = Drawing.new("Line"),
        TopRight = Drawing.new("Line"),
        BottomLeft = Drawing.new("Line"),
        BottomRight = Drawing.new("Line"),
        -- side verticals/edges (used for Full box & corner verticals)
        Left = Drawing.new("Line"),
        Right = Drawing.new("Line"),
        Top = Drawing.new("Line"),
        Bottom = Drawing.new("Line"),
        -- persistent connector lines for 3D mode (4 lines connecting front/back)
        Connectors = {}
    }

    -- create 4 cached connector lines (persistent rather than ephemeral)
    for i = 1, 4 do
        local conn = Drawing.new("Line")
        conn.Visible = false
        conn.Color = Colors.Enemy
        conn.Thickness = Settings.BoxThickness
        box.Connectors[i] = conn
    end

    -- Set safe properties on the line drawings (don't attempt .Filled on Line objects)
    for key, line in pairs(box) do
        if key ~= "Connectors" then
            line.Visible = false
            line.Color = Colors.Enemy
            line.Thickness = Settings.BoxThickness
        end
    end

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Colors.Enemy
    tracer.Thickness = Settings.TracerThickness

    local healthBar = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }

    for _, obj in pairs(healthBar) do
        obj.Visible = false
        if obj == healthBar.Fill then
            obj.Color = Colors.Health
            obj.Filled = true
        elseif obj == healthBar.Text then
            obj.Center = true
            obj.Size = Settings.TextSize
            obj.Color = Colors.Health
            obj.Font = Settings.TextFont
        end
    end

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

    local snapline = Drawing.new("Line")
    snapline.Visible = false
    snapline.Color = Colors.Enemy
    snapline.Thickness = 1

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Settings.ChamsFillColor
    highlight.OutlineColor = Settings.ChamsOutlineColor
    highlight.FillTransparency = Settings.ChamsTransparency
    highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = Settings.ChamsEnabled

    Highlights[player] = highlight

    local skeleton = {
        -- Spine & Head
        Head = Drawing.new("Line"),
        Neck = Drawing.new("Line"),
        UpperSpine = Drawing.new("Line"),
        LowerSpine = Drawing.new("Line"),

        -- Left Arm
        LeftShoulder = Drawing.new("Line"),
        LeftUpperArm = Drawing.new("Line"),
        LeftLowerArm = Drawing.new("Line"),
        LeftHand = Drawing.new("Line"),

        -- Right Arm
        RightShoulder = Drawing.new("Line"),
        RightUpperArm = Drawing.new("Line"),
        RightLowerArm = Drawing.new("Line"),
        RightHand = Drawing.new("Line"),

        -- Left Leg
        LeftHip = Drawing.new("Line"),
        LeftUpperLeg = Drawing.new("Line"),
        LeftLowerLeg = Drawing.new("Line"),
        LeftFoot = Drawing.new("Line"),

        -- Right Leg
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
        -- remove box lines including connectors
        for key, obj in pairs(esp.Box) do
            if key == "Connectors" then
                for _, c in ipairs(obj) do
                    if c and c.Remove then pcall(c.Remove, c) end
                end
            else
                if obj and obj.Remove then pcall(obj.Remove, obj) end
            end
        end

        if esp.Tracer and esp.Tracer.Remove then pcall(esp.Tracer.Remove, esp.Tracer) end

        for _, obj in pairs(esp.HealthBar) do
            if obj and obj.Remove then pcall(obj.Remove, obj) end
        end

        for _, obj in pairs(esp.Info) do
            if obj and obj.Remove then pcall(obj.Remove, obj) end
        end

        if esp.Snapline and esp.Snapline.Remove then pcall(esp.Snapline.Remove, esp.Snapline) end

        Drawings.ESP[player] = nil
    end

    local highlight = Highlights[player]
    if highlight then
        highlight:Destroy()
        Highlights[player] = nil
    end

    local skeleton = Drawings.Skeleton[player]
    if skeleton then
        for _, line in pairs(skeleton) do
            if line and line.Remove then pcall(line.Remove, line) end
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

local function UpdateESP(player)
    if not Settings.Enabled then return end

    local esp = Drawings.ESP[player]
    if not esp then return end

    local character = player.Character
    if not character then 
        -- Hide all drawings if character doesn't exist
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" then
                for _, c in ipairs(obj) do c.Visible = false end
            else
                obj.Visible = false
            end
        end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false

        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Visible = false
            end
        end
        return 
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then 
        -- Hide all drawings if rootPart doesn't exist
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" then
                for _, c in ipairs(obj) do c.Visible = false end
            else
                obj.Visible = false
            end
        end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false

        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Visible = false
            end
        end
        return 
    end

    -- Early screen check to hide all drawings if player is off screen
    local _, isOnScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not isOnScreen then
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" then
                for _, c in ipairs(obj) do c.Visible = false end
            else
                obj.Visible = false
            end
        end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false

        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Visible = false
            end
        end
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" then
                for _, c in ipairs(obj) do c.Visible = false end
            else
                obj.Visible = false
            end
        end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false

        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Visible = false
            end
        end
        return
    end

    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude

    if not onScreen or distance > Settings.MaxDistance then
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" then
                for _, c in ipairs(obj) do c.Visible = false end
            else
                obj.Visible = false
            end
        end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        return
    end

    if Settings.TeamCheck and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" then
                for _, c in ipairs(obj) do c.Visible = false end
            else
                obj.Visible = false
            end
        end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        return
    end

    local color = GetPlayerColor(player)
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame

    -- explicit parentheses to get the transformed CFrame position and better centering
    local topVec3, top_onscreen = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
    local bottomVec3, bottom_onscreen = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)

    if not top_onscreen or not bottom_onscreen then
        for _, obj in pairs(esp.Box) do
            if type(obj) == "table" then
                for _, c in ipairs(obj) do c.Visible = false end
            else
                obj.Visible = false
            end
        end
        return
    end

    -- screenSize guarded to avoid zero or negative values
    local screenSize = math.max(2, bottomVec3.Y - topVec3.Y)
    local boxWidth = math.max(10, screenSize * 0.65)

    -- use a centered X calculated from top and bottom to be stable across rotations
    local centerX = (topVec3.X + bottomVec3.X) / 2
    local boxPosition = Vector2.new(centerX - boxWidth/2, topVec3.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)

    -- Hide all box parts by default
    for key, obj in pairs(esp.Box) do
        if key == "Connectors" then
            for _, c in ipairs(obj) do c.Visible = false end
        else
            obj.Visible = false
        end
    end

    if Settings.BoxESP then
        if Settings.BoxStyle == "ThreeD" then
            local front = {
                TL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2)).Position),
                TR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2)).Position),
                BL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)).Position),
                BR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2)).Position)
            }

            local back = {
                TL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2)).Position),
                TR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)).Position),
                BL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)).Position),
                BR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2)).Position)
            }

            -- ensure all points are in front of camera (Z > 0)
            if not (front.TL.Z > 0 and front.TR.Z > 0 and front.BL.Z > 0 and front.BR.Z > 0 and
                   back.TL.Z > 0 and back.TR.Z > 0 and back.BL.Z > 0 and back.BR.Z > 0) then
                -- off-screen; hide connectors just in case
                for _, c in ipairs(esp.Box.Connectors) do c.Visible = false end
                for key, obj in pairs(esp.Box) do
                    if key ~= "Connectors" then obj.Visible = false end
                end
                return
            end

            -- Convert to Vector2
            local function toVector2(v3) return Vector2.new(v3.X, v3.Y) end
            local fTL, fTR, fBL, fBR = toVector2(front.TL), toVector2(front.TR), toVector2(front.BL), toVector2(front.BR)
            local bTL, bTR, bBL, bBR = toVector2(back.TL), toVector2(back.TR), toVector2(back.BL), toVector2(back.BR)

            -- Front face (draw as full rectangle using Top/Bottom/Left/Right lines)
            -- We'll map the stored lines so corner visuals stay tidy for 3D as well:
            esp.Box.Top.From = fTL
            esp.Box.Top.To = fTR
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = fBL
            esp.Box.Bottom.To = fBR
            esp.Box.Bottom.Visible = true

            esp.Box.Left.From = fTL
            esp.Box.Left.To = fBL
            esp.Box.Left.Visible = true

            esp.Box.Right.From = fTR
            esp.Box.Right.To = fBR
            esp.Box.Right.Visible = true

            -- Back face (smaller/shifted rectangle)
            -- Use leftover corner lines to hint back face
            esp.Box.TopLeft.From = bTL
            esp.Box.TopLeft.To = bTR
            esp.Box.TopLeft.Visible = true

            esp.Box.BottomLeft.From = bBL
            esp.Box.BottomLeft.To = bBR
            esp.Box.BottomLeft.Visible = true

            -- Connect front to back using persistent connectors
            local connectors = esp.Box.Connectors
            connectors[1].From = fTL; connectors[1].To = bTL; connectors[1].Visible = true
            connectors[2].From = fTR; connectors[2].To = bTR; connectors[2].Visible = true
            connectors[3].From = fBL; connectors[3].To = bBL; connectors[3].Visible = true
            connectors[4].From = fBR; connectors[4].To = bBR; connectors[4].Visible = true

            -- color/thickness for these now
            for _, line in ipairs({esp.Box.Top, esp.Box.Bottom, esp.Box.Left, esp.Box.Right, esp.Box.TopLeft, esp.Box.BottomLeft}) do
                if line then
                    line.Color = color
                    line.Thickness = Settings.BoxThickness
                end
            end
            for _, c in ipairs(connectors) do
                c.Color = color
                c.Thickness = Settings.BoxThickness
            end

        elseif Settings.BoxStyle == "Corner" then
            local cornerSize = math.clamp(boxWidth * 0.18, 6, boxWidth * 0.45) -- stable corner sizing

            -- top-left corner: horizontal then vertical
            local tl_h_from = boxPosition
            local tl_h_to = boxPosition + Vector2.new(cornerSize, 0)
            local tl_v_from = boxPosition
            local tl_v_to = boxPosition + Vector2.new(0, cornerSize)

            esp.Box.TopLeft.From = tl_h_from; esp.Box.TopLeft.To = tl_h_to; esp.Box.TopLeft.Visible = true
            esp.Box.Left.From = tl_v_from; esp.Box.Left.To = tl_v_to; esp.Box.Left.Visible = true

            -- top-right corner
            local tr_h_from = boxPosition + Vector2.new(boxSize.X - cornerSize, 0)
            local tr_h_to = boxPosition + Vector2.new(boxSize.X, 0)
            local tr_v_from = boxPosition + Vector2.new(boxSize.X, 0)
            local tr_v_to = boxPosition + Vector2.new(boxSize.X, cornerSize)

            esp.Box.TopRight.From = tr_h_from; esp.Box.TopRight.To = tr_h_to; esp.Box.TopRight.Visible = true
            esp.Box.Right.From = tr_v_from; esp.Box.Right.To = tr_v_to; esp.Box.Right.Visible = true

            -- bottom-left corner
            local bl_h_from = boxPosition + Vector2.new(0, boxSize.Y)
            local bl_h_to = boxPosition + Vector2.new(cornerSize, boxSize.Y)
            local bl_v_from = boxPosition + Vector2.new(0, boxSize.Y - cornerSize)
            local bl_v_to = boxPosition + Vector2.new(0, boxSize.Y)

            esp.Box.BottomLeft.From = bl_h_from; esp.Box.BottomLeft.To = bl_h_to; esp.Box.BottomLeft.Visible = true
            -- reuse Left for bottom-left vertical
            esp.Box.Left.From = bl_v_from; esp.Box.Left.To = bl_v_to; esp.Box.Left.Visible = true

            -- bottom-right corner
            local br_h_from = boxPosition + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
            local br_h_to = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            local br_v_from = boxPosition + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
            local br_v_to = boxPosition + Vector2.new(boxSize.X, boxSize.Y)

            esp.Box.BottomRight.From = br_h_from; esp.Box.BottomRight.To = br_h_to; esp.Box.BottomRight.Visible = true
            esp.Box.Right.From = br_v_from; esp.Box.Right.To = br_v_to; esp.Box.Right.Visible = true

            -- apply color & thickness
            for key, obj in pairs(esp.Box) do
                if key ~= "Connectors" and obj.Visible then
                    obj.Color = color
                    obj.Thickness = Settings.BoxThickness
                end
            end

        else -- Full box
            -- Full rectangle (Top, Bottom, Left, Right)
            esp.Box.Top.From = boxPosition
            esp.Box.Top.To = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.Visible = true

            esp.Box.Left.From = boxPosition
            esp.Box.Left.To = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Right.Visible = true

            -- hide corner-only lines
            esp.Box.TopLeft.Visible = false
            esp.Box.TopRight.Visible = false
            esp.Box.BottomLeft.Visible = false
            esp.Box.BottomRight.Visible = false

            for _, obj in pairs({esp.Box.Top, esp.Box.Bottom, esp.Box.Left, esp.Box.Right}) do
                obj.Color = color
                obj.Thickness = Settings.BoxThickness
            end
        end
    end

    if Settings.TracerESP then
        esp.Tracer.From = GetTracerOrigin()
        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Visible = true
        esp.Tracer.Thickness = Settings.TracerThickness
    else
        esp.Tracer.Visible = false
    end

    if Settings.HealthESP then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = (maxHealth > 0) and (health / maxHealth) or 0

        local barHeight = math.max(6, screenSize * 0.8)
        local barWidth = 4
        local barPos = Vector2.new(
            boxPosition.X - barWidth - 6,
            boxPosition.Y + (screenSize - barHeight)/2
        )

        esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
        esp.HealthBar.Outline.Position = barPos
        esp.HealthBar.Outline.Visible = true

        esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, math.clamp(barHeight * healthPercent, 0, barHeight))
        esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1 - healthPercent))
        esp.HealthBar.Fill.Color = Color3.fromRGB(math.floor(255 - (255 * healthPercent)), math.floor(255 * healthPercent), 0)
        esp.HealthBar.Fill.Visible = true

        if Settings.HealthStyle == "Both" or Settings.HealthStyle == "Text" then
            local textValue = ""
            if Settings.HealthTextFormat == "Number" then
                textValue = tostring(math.floor(health)) .. Settings.HealthTextSuffix
            elseif Settings.HealthTextFormat == "Percentage" then
                textValue = tostring(math.floor(healthPercent * 100)) .. "%"
            else
                textValue = tostring(math.floor(health)) .. " | " .. tostring(math.floor(healthPercent * 100)) .. "%"
            end
            esp.HealthBar.Text.Text = textValue
            esp.HealthBar.Text.Position = Vector2.new(barPos.X + barWidth + 6, barPos.Y + barHeight/2)
            esp.HealthBar.Text.Visible = true
        else
            esp.HealthBar.Text.Visible = false
        end
    else
        for _, obj in pairs(esp.HealthBar) do
            obj.Visible = false
        end
    end

    if Settings.NameESP then
        esp.Info.Name.Text = player.DisplayName
        esp.Info.Name.Position = Vector2.new(
            boxPosition.X + boxWidth/2,
            boxPosition.Y - 18
        )
        esp.Info.Name.Color = color
        esp.Info.Name.Size = Settings.TextSize
        esp.Info.Name.Visible = true
    else
        esp.Info.Name.Visible = false
    end

    if Settings.Snaplines then
        esp.Snapline.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        esp.Snapline.To = Vector2.new(pos.X, pos.Y)
        esp.Snapline.Color = color
        esp.Snapline.Visible = true
    else
        esp.Snapline.Visible = false
    end

    local highlight = Highlights[player]
    if highlight then
        if Settings.ChamsEnabled and character then
            highlight.Parent = character
            highlight.FillColor = Settings.ChamsFillColor
            highlight.OutlineColor = Settings.ChamsOutlineColor
            highlight.FillTransparency = Settings.ChamsTransparency
            highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
            highlight.Enabled = true
        else
            highlight.Enabled = false
        end
    end

    if Settings.SkeletonESP then
        local function getBonePositions(character)
            if not character then return nil end

            local bones = {
                Head = character:FindFirstChild("Head"),
                UpperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
                LowerTorso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso"),
                RootPart = character:FindFirstChild("HumanoidRootPart"),

                -- Left Arm
                LeftUpperArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm"),
                LeftLowerArm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm"),
                LeftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"),

                -- Right Arm
                RightUpperArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm"),
                RightLowerArm = character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm"),
                RightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"),

                -- Left Leg
                LeftUpperLeg = character:FindFirstChild("LeftUpperLeg") or character:FindFirstChild("Left Leg"),
                LeftLowerLeg = character:FindFirstChild("LeftLowerLeg") or character:FindFirstChild("Left Leg"),
                LeftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg"),

                -- Right Leg
                RightUpperLeg = character:FindFirstChild("RightUpperLeg") or character:FindFirstChild("Right Leg"),
                RightLowerLeg = character:FindFirstChild("RightLowerLeg") or character:FindFirstChild("Right Leg"),
                RightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
            }

            -- Verify we have the minimum required bones
            if not (bones.Head and bones.UpperTorso) then return nil end

            return bones
        end

        local function drawBone(from, to, line)
            if not from or not to then 
                line.Visible = false
                return 
            end

            -- Get center positions of the parts
            local fromPos = (from.CFrame * CFrame.new(0, 0, 0)).Position
            local toPos = (to.CFrame * CFrame.new(0, 0, 0)).Position

            -- Convert to screen positions with proper depth check
            local fromScreen, fromVisible = Camera:WorldToViewportPoint(fromPos)
            local toScreen, toVisible = Camera:WorldToViewportPoint(toPos)

            -- Only show if both points are visible and in front of camera
            if not (fromVisible and toVisible) or fromScreen.Z < 0 or toScreen.Z < 0 then
                line.Visible = false
                return
            end

            -- Check if points are within screen bounds
            local screenBounds = Camera.ViewportSize
            if fromScreen.X < 0 or fromScreen.X > screenBounds.X or
               fromScreen.Y < 0 or fromScreen.Y > screenBounds.Y or
               toScreen.X < 0 or toScreen.X > screenBounds.X or
               toScreen.Y < 0 or toScreen.Y > screenBounds.Y then
                line.Visible = false
                return
            end

            -- Update line with screen positions
            line.From = Vector2.new(fromScreen.X, fromScreen.Y)
            line.To = Vector2.new(toScreen.X, toScreen.Y)
            line.Color = Settings.SkeletonColor
            line.Thickness = Settings.SkeletonThickness
            line.Transparency = Settings.SkeletonTransparency
            line.Visible = true
        end

        local bones = getBonePositions(character)
        if bones then
            local skeleton = Drawings.Skeleton[player]
            if skeleton then
                -- Spine & Head
                drawBone(bones.Head, bones.UpperTorso, skeleton.Head)
                drawBone(bones.UpperTorso, bones.LowerTorso, skeleton.UpperSpine)

                -- Left Arm Chain
                drawBone(bones.UpperTorso, bones.LeftUpperArm, skeleton.LeftShoulder)
                drawBone(bones.LeftUpperArm, bones.LeftLowerArm, skeleton.LeftUpperArm)
                drawBone(bones.LeftLowerArm, bones.LeftHand, skeleton.LeftLowerArm)

                -- Right Arm Chain
                drawBone(bones.UpperTorso, bones.RightUpperArm, skeleton.RightShoulder)
                drawBone(bones.RightUpperArm, bones.RightLowerArm, skeleton.RightUpperArm)
                drawBone(bones.RightLowerArm, bones.RightHand, skeleton.RightLowerArm)

                -- Left Leg Chain
                drawBone(bones.LowerTorso, bones.LeftUpperLeg, skeleton.LeftHip)
                drawBone(bones.LeftUpperLeg, bones.LeftLowerLeg, skeleton.LeftUpperLeg)
                drawBone(bones.LeftLowerLeg, bones.LeftFoot, skeleton.LeftLowerLeg)

                -- Right Leg Chain
                drawBone(bones.LowerTorso, bones.RightUpperLeg, skeleton.RightHip)
                drawBone(bones.RightUpperLeg, bones.RightLowerLeg, skeleton.RightUpperLeg)
                drawBone(bones.RightLowerLeg, bones.RightFoot, skeleton.RightLowerLeg)
            end
        end
    else
        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Visible = false
            end
        end
    end
end

local function DisableESP()
    for _, player in ipairs(Players:GetPlayers()) do
        local esp = Drawings.ESP[player]
        if esp then
            for key, obj in pairs(esp.Box) do
                if key == "Connectors" then
                    for _, c in ipairs(obj) do c.Visible = false end
                else
                    obj.Visible = false
                end
            end
            esp.Tracer.Visible = false
            for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
            for _, obj in pairs(esp.Info) do obj.Visible = false end
            esp.Snapline.Visible = false
        end

        -- Also hide skeleton
        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do
                line.Visible = false
            end
        end
    end
end

local function CleanupESP()
    for _, player in ipairs(Players:GetPlayers()) do
        RemoveESP(player)
    end
    Drawings.ESP = {}
    Drawings.Skeleton = {}
    Highlights = {}
end

local Window = Fluent:CreateWindow({
    Title = "WA Universal ESP",
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
        Default = "Corner"
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

    local ChamsSection = Tabs.ESP:AddSection("Chams")

    local ChamsToggle = ChamsSection:AddToggle("ChamsEnabled", {
        Title = "Enable Chams",
        Default = false
    })
    ChamsToggle:OnChanged(function()
        Settings.ChamsEnabled = ChamsToggle.Value
    end)

    local ChamsFillColor = ChamsSection:AddColorpicker("ChamsFillColor", {
        Title = "Fill Color",
        Description = "Color for visible parts",
        Default = Settings.ChamsFillColor
    })
    ChamsFillColor:OnChanged(function(Value)
        Settings.ChamsFillColor = Value
    end)

    local ChamsOccludedColor = ChamsSection:AddColorpicker("ChamsOccludedColor", {
        Title = "Occluded Color",
        Description = "Color for parts behind walls",
        Default = Settings.ChamsOccludedColor
    })
    ChamsOccludedColor:OnChanged(function(Value)
        Settings.ChamsOccludedColor = Value
    end)

    local ChamsOutlineColor = ChamsSection:AddColorpicker("ChamsOutlineColor", {
        Title = "Outline Color",
        Description = "Color for character outline",
        Default = Settings.ChamsOutlineColor
    })
    ChamsOutlineColor:OnChanged(function(Value)
        Settings.ChamsOutlineColor = Value
    end)

    local ChamsTransparency = ChamsSection:AddSlider("ChamsTransparency", {
        Title = "Fill Transparency",
        Description = "Transparency of the fill color",
        Default = 0.5,
        Min = 0,
        Max = 1,
        Rounding = 2
    })
    ChamsTransparency:OnChanged(function(Value)
        Settings.ChamsTransparency = Value
    end)

    local ChamsOutlineTransparency = ChamsSection:AddSlider("ChamsOutlineTransparency", {
        Title = "Outline Transparency",
        Description = "Transparency of the outline",
        Default = 0,
        Min = 0,
        Max = 1,
        Rounding = 2
    })
    ChamsOutlineTransparency:OnChanged(function(Value)
        Settings.ChamsOutlineTransparency = Value
    end)

    local ChamsOutlineThickness = ChamsSection:AddSlider("ChamsOutlineThickness", {
        Title = "Outline Thickness",
        Description = "Thickness of the outline",
        Default = 0.1,
        Min = 0,
        Max = 1,
        Rounding = 2
    })
    ChamsOutlineThickness:OnChanged(function(Value)
        Settings.ChamsOutlineThickness = Value
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

task.spawn(function()
    while task.wait(0.1) do
        Colors.Rainbow = Color3.fromHSV(tick() * Settings.RainbowSpeed % 1, 1, 1)
    end
end)

local lastUpdate = 0
RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then 
        DisableESP()
        return 
    end

    local currentTime = tick()
    if currentTime - lastUpdate >= Settings.RefreshRate then
        for _, player in ipairs(Players:GetPlayers()) do
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

Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

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
