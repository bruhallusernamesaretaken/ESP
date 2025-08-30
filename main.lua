-- Full improved WA Universal ESP (robust / defensive version)
-- Paste as a single script (LocalScript) where you run your ESP.

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- safe helpers
local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok, res
end

local function safeSet(obj, key, val)
    if not obj then return end
    pcall(function() obj[key] = val end)
end

local function safeRemove(obj)
    if not obj then return end
    pcall(function()
        -- Drawing objects often expose :Remove as function; Instances use Destroy
        if typeof(obj) == "Instance" and obj.Destroy then
            obj:Destroy()
        elseif type(obj.Remove) == "function" then
            obj:Remove()
        elseif type(obj.remove) == "function" then
            obj:remove()
        end
    end)
end

local function newDrawing(kind)
    local ok, obj = pcall(function() return Drawing.new(kind) end)
    if ok and obj then return obj end
    return nil
end

-- central data
local Drawings = {
    ESP = {},       -- player => {Box = {...}, Tracer = ..., HealthBar = {...}, Info = {...}, Snapline = ...}
    Skeleton = {}
}

local Colors = {
    Enemy = Color3.fromRGB(255, 25, 25),
    Ally = Color3.fromRGB(25, 255, 25),
    Neutral = Color3.fromRGB(255, 255, 255),
    Selected = Color3.fromRGB(255, 210, 0),
    Health = Color3.fromRGB(0, 255, 0),
    Distance = Color3.fromRGB(200, 200, 200),
    Rainbow = Color3.fromRGB(255,255,255)
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
    SkeletonTransparency = 1,
    HealthTextFormat = "Number" -- default added
}

-- Create drawing objects for a player
local function CreateESP(player)
    if not player or player == LocalPlayer then return end
    if Drawings.ESP[player] then return end

    local box = {
        TopLeft = newDrawing("Line"),
        TopRight = newDrawing("Line"),
        BottomLeft = newDrawing("Line"),
        BottomRight = newDrawing("Line"),
        Left = newDrawing("Line"),
        Right = newDrawing("Line"),
        Top = newDrawing("Line"),
        Bottom = newDrawing("Line"),
        Connectors = {}
    }

    for i = 1, 4 do
        local conn = newDrawing("Line")
        if conn then
            conn.Visible = false
            conn.Color = Colors.Enemy
            conn.Thickness = Settings.BoxThickness
            box.Connectors[i] = conn
        end
    end

    for key, line in pairs(box) do
        if key ~= "Connectors" and line then
            pcall(function()
                line.Visible = false
                line.Color = Colors.Enemy
                line.Thickness = Settings.BoxThickness
            end)
        end
    end

    local tracer = newDrawing("Line")
    if tracer then
        tracer.Visible = false
        tracer.Color = Colors.Enemy
        tracer.Thickness = Settings.TracerThickness
    end

    local healthBar = {
        Outline = newDrawing("Square"),
        Fill = newDrawing("Square"),
        Text = newDrawing("Text")
    }
    if healthBar.Outline then healthBar.Outline.Visible = false end
    if healthBar.Fill then
        healthBar.Fill.Visible = false
        pcall(function() healthBar.Fill.Filled = true end)
        healthBar.Fill.Color = Colors.Health
    end
    if healthBar.Text then
        healthBar.Text.Visible = false
        healthBar.Text.Center = true
        healthBar.Text.Size = Settings.TextSize
        healthBar.Text.Color = Colors.Health
        healthBar.Text.Font = Settings.TextFont
        healthBar.Text.Outline = true
    end

    local info = {
        Name = newDrawing("Text"),
        Distance = newDrawing("Text")
    }
    for _, text in pairs(info) do
        if text then
            text.Visible = false
            text.Center = true
            text.Size = Settings.TextSize
            text.Color = Colors.Enemy
            text.Font = Settings.TextFont
            text.Outline = true
        end
    end

    local snapline = newDrawing("Line")
    if snapline then
        snapline.Visible = false
        snapline.Color = Colors.Enemy
        snapline.Thickness = 1
    end

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Settings.ChamsFillColor
    highlight.OutlineColor = Settings.ChamsOutlineColor
    highlight.FillTransparency = Settings.ChamsTransparency
    highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = Settings.ChamsEnabled
    Highlights[player] = highlight

    local skeleton = {}
    local skeletonNames = {
        "Head", "Neck", "UpperSpine", "LowerSpine",
        "LeftShoulder","LeftUpperArm","LeftLowerArm","LeftHand",
        "RightShoulder","RightUpperArm","RightLowerArm","RightHand",
        "LeftHip","LeftUpperLeg","LeftLowerLeg","LeftFoot",
        "RightHip","RightUpperLeg","RightLowerLeg","RightFoot"
    }
    for _, name in ipairs(skeletonNames) do
        skeleton[name] = newDrawing("Line")
        if skeleton[name] then
            skeleton[name].Visible = false
            skeleton[name].Color = Settings.SkeletonColor
            skeleton[name].Thickness = Settings.SkeletonThickness
            skeleton[name].Transparency = Settings.SkeletonTransparency
        end
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
    if not player then return end
    local esp = Drawings.ESP[player]
    if esp then
        if esp.Box then
            for key, obj in pairs(esp.Box) do
                if key == "Connectors" and type(obj) == "table" then
                    for _, c in ipairs(obj) do safeRemove(c) end
                else
                    safeRemove(obj)
                end
            end
        end
        safeRemove(esp.Tracer)
        if esp.HealthBar then for _, o in pairs(esp.HealthBar) do safeRemove(o) end end
        if esp.Info then for _, o in pairs(esp.Info) do safeRemove(o) end end
        safeRemove(esp.Snapline)
        Drawings.ESP[player] = nil
    end

    local hl = Highlights[player]
    if hl then
        pcall(function() hl:Destroy() end)
        Highlights[player] = nil
    end

    local sk = Drawings.Skeleton[player]
    if sk then
        for _, l in pairs(sk) do safeRemove(l) end
        Drawings.Skeleton[player] = nil
    end
end

local function HideAllDrawingsForESP(esp)
    if not esp then return end
    if esp.Box then
        for key, obj in pairs(esp.Box) do
            if key == "Connectors" and type(obj) == "table" then
                for _, c in ipairs(obj) do pcall(function() c.Visible = false end) end
            else
                pcall(function() if obj then obj.Visible = false end end)
            end
        end
    end
    pcall(function() if esp.Tracer then esp.Tracer.Visible = false end end)
    if esp.HealthBar then for _, o in pairs(esp.HealthBar) do pcall(function() if o then o.Visible = false end end) end end
    if esp.Info then for _, o in pairs(esp.Info) do pcall(function() if o then o.Visible = false end end) end end
    pcall(function() if esp.Snapline then esp.Snapline.Visible = false end end)
end

local function GetPlayerColor(player)
    if Settings.RainbowEnabled then
        if Settings.RainbowBoxes and Settings.BoxESP then return Colors.Rainbow end
        if Settings.RainbowTracers and Settings.TracerESP then return Colors.Rainbow end
        if Settings.RainbowText and (Settings.NameESP or Settings.HealthESP) then return Colors.Rainbow end
    end
    return (player.Team == LocalPlayer.Team) and Colors.Ally or Colors.Enemy
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

-- Main per-player update
local function UpdateESP(player)
    if not Settings.Enabled then return end
    if not player or player == LocalPlayer then return end

    local esp = Drawings.ESP[player]
    if not esp then return end

    local character = player.Character
    if not character then
        HideAllDrawingsForESP(esp)
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, l in pairs(skeleton) do pcall(function() l.Visible = false end) end end
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        HideAllDrawingsForESP(esp)
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, l in pairs(skeleton) do pcall(function() l.Visible = false end) end end
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        HideAllDrawingsForESP(esp)
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, l in pairs(skeleton) do pcall(function() l.Visible = false end) end end
        return
    end

    local worldPoint, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if not onScreen or distance > Settings.MaxDistance then
        HideAllDrawingsForESP(esp)
        return
    end

    if Settings.TeamCheck and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
        HideAllDrawingsForESP(esp)
        return
    end

    local color = GetPlayerColor(player)
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame

    local topV3, topOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
    local bottomV3, bottomOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)
    if not topOn or not bottomOn then HideAllDrawingsForESP(esp) return end

    local screenSize = math.max(2, bottomV3.Y - topV3.Y)
    local boxWidth = math.max(10, screenSize * 0.65)
    local centerX = (topV3.X + bottomV3.X) / 2
    local boxPosition = Vector2.new(centerX - boxWidth/2, topV3.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)

    -- default hide box parts
    for key, obj in pairs(esp.Box) do
        if key == "Connectors" then
            for _, c in ipairs(obj) do pcall(function() c.Visible = false end) end
        else
            pcall(function() if obj then obj.Visible = false end end)
        end
    end

    -- BOX DRAWING
    if Settings.BoxESP then
        if Settings.BoxStyle == "ThreeD" then
            local function vp(p) return Camera:WorldToViewportPoint(p) end
            local fTL = vp((cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2)).Position)
            local fTR = vp((cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2)).Position)
            local fBL = vp((cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)).Position)
            local fBR = vp((cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2)).Position)

            local bTL = vp((cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2)).Position)
            local bTR = vp((cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)).Position)
            local bBL = vp((cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)).Position)
            local bBR = vp((cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2)).Position)

            if not (fTL.Z > 0 and fTR.Z > 0 and fBL.Z > 0 and fBR.Z > 0 and bTL.Z > 0 and bTR.Z > 0 and bBL.Z > 0 and bBR.Z > 0) then
                for _, c in ipairs(esp.Box.Connectors) do pcall(function() c.Visible = false end) end
            else
                local function v2(v3) return Vector2.new(v3.X, v3.Y) end
                local ftl, ftr, fbl, fbr = v2(fTL), v2(fTR), v2(fBL), v2(fBR)
                local btl, btr, bbl, bbr = v2(bTL), v2(bTR), v2(bBL), v2(bBR)

                pcall(function()
                    if esp.Box.Top then esp.Box.Top.From, esp.Box.Top.To, esp.Box.Top.Visible = ftl, ftr, true end
                    if esp.Box.Bottom then esp.Box.Bottom.From, esp.Box.Bottom.To, esp.Box.Bottom.Visible = fbl, fbr, true end
                    if esp.Box.Left then esp.Box.Left.From, esp.Box.Left.To, esp.Box.Left.Visible = ftl, fbl, true end
                    if esp.Box.Right then esp.Box.Right.From, esp.Box.Right.To, esp.Box.Right.Visible = ftr, fbr, true end
                end)

                pcall(function()
                    if esp.Box.TopLeft then esp.Box.TopLeft.From, esp.Box.TopLeft.To, esp.Box.TopLeft.Visible = btl, btr, true end
                    if esp.Box.BottomLeft then esp.Box.BottomLeft.From, esp.Box.BottomLeft.To, esp.Box.BottomLeft.Visible = bbl, bbr, true end
                end)

                local connectors = esp.Box.Connectors
                if connectors then
                    local con = { {ftl,btl}, {ftr,btr}, {fbl,bbl}, {fbr,bbr} }
                    for i = 1, 4 do
                        local c = connectors[i]
                        if c and con[i] then
                            pcall(function()
                                c.From = con[i][1]
                                c.To = con[i][2]
                                c.Visible = true
                                c.Color = color
                                c.Thickness = Settings.BoxThickness
                            end)
                        end
                    end
                end

                for _, lineKey in ipairs({"Top","Bottom","Left","Right","TopLeft","BottomLeft"}) do
                    local l = esp.Box[lineKey]
                    if l then
                        pcall(function()
                            l.Color = color
                            l.Thickness = Settings.BoxThickness
                        end)
                    end
                end
            end

        elseif Settings.BoxStyle == "Corner" then
            local cornerSize = math.clamp(boxWidth * 0.18, 6, boxWidth * 0.45)

            local tl_h_from = boxPosition
            local tl_h_to = boxPosition + Vector2.new(cornerSize, 0)
            local tl_v_from = boxPosition
            local tl_v_to = boxPosition + Vector2.new(0, cornerSize)

            pcall(function()
                if esp.Box.TopLeft then esp.Box.TopLeft.From, esp.Box.TopLeft.To, esp.Box.TopLeft.Visible = tl_h_from, tl_h_to, true end
                if esp.Box.Left then esp.Box.Left.From, esp.Box.Left.To, esp.Box.Left.Visible = tl_v_from, tl_v_to, true end
            end)

            local tr_h_from = boxPosition + Vector2.new(boxSize.X - cornerSize, 0)
            local tr_h_to = boxPosition + Vector2.new(boxSize.X, 0)
            local tr_v_from = boxPosition + Vector2.new(boxSize.X, 0)
            local tr_v_to = boxPosition + Vector2.new(boxSize.X, cornerSize)

            pcall(function()
                if esp.Box.TopRight then esp.Box.TopRight.From, esp.Box.TopRight.To, esp.Box.TopRight.Visible = tr_h_from, tr_h_to, true end
                if esp.Box.Right then esp.Box.Right.From, esp.Box.Right.To, esp.Box.Right.Visible = tr_v_from, tr_v_to, true end
            end)

            local bl_h_from = boxPosition + Vector2.new(0, boxSize.Y)
            local bl_h_to = boxPosition + Vector2.new(cornerSize, boxSize.Y)
            local bl_v_from = boxPosition + Vector2.new(0, boxSize.Y - cornerSize)
            local bl_v_to = boxPosition + Vector2.new(0, boxSize.Y)

            pcall(function()
                if esp.Box.BottomLeft then esp.Box.BottomLeft.From, esp.Box.BottomLeft.To, esp.Box.BottomLeft.Visible = bl_h_from, bl_h_to, true end
                if esp.Box.Left then esp.Box.Left.From, esp.Box.Left.To, esp.Box.Left.Visible = bl_v_from, bl_v_to, true end
            end)

            local br_h_from = boxPosition + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
            local br_h_to = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            local br_v_from = boxPosition + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
            local br_v_to = boxPosition + Vector2.new(boxSize.X, boxSize.Y)

            pcall(function()
                if esp.Box.BottomRight then esp.Box.BottomRight.From, esp.Box.BottomRight.To, esp.Box.BottomRight.Visible = br_h_from, br_h_to, true end
                if esp.Box.Right then esp.Box.Right.From, esp.Box.Right.To, esp.Box.Right.Visible = br_v_from, br_v_to, true end
            end)

            for key, obj in pairs(esp.Box) do
                if key ~= "Connectors" and obj and obj.Visible then
                    pcall(function()
                        obj.Color = color
                        obj.Thickness = Settings.BoxThickness
                    end)
                end
            end

        else -- Full
            pcall(function()
                if esp.Box.Top then esp.Box.Top.From, esp.Box.Top.To, esp.Box.Top.Visible = boxPosition, boxPosition + Vector2.new(boxSize.X, 0), true end
                if esp.Box.Bottom then esp.Box.Bottom.From, esp.Box.Bottom.To, esp.Box.Bottom.Visible = boxPosition + Vector2.new(0, boxSize.Y), boxPosition + Vector2.new(boxSize.X, boxSize.Y), true end
                if esp.Box.Left then esp.Box.Left.From, esp.Box.Left.To, esp.Box.Left.Visible = boxPosition, boxPosition + Vector2.new(0, boxSize.Y), true end
                if esp.Box.Right then esp.Box.Right.From, esp.Box.Right.To, esp.Box.Right.Visible = boxPosition + Vector2.new(boxSize.X, 0), boxPosition + Vector2.new(boxSize.X, boxSize.Y), true end

                if esp.Box.TopLeft then esp.Box.TopLeft.Visible = false end
                if esp.Box.TopRight then esp.Box.TopRight.Visible = false end
                if esp.Box.BottomLeft then esp.Box.BottomLeft.Visible = false end
                if esp.Box.BottomRight then esp.Box.BottomRight.Visible = false end

                for _, obj in pairs({esp.Box.Top, esp.Box.Bottom, esp.Box.Left, esp.Box.Right}) do
                    if obj then
                        obj.Color = color
                        obj.Thickness = Settings.BoxThickness
                    end
                end
            end)
        end
    end

    -- TRACER
    if Settings.TracerESP and esp.Tracer then
        pcall(function()
            esp.Tracer.From = GetTracerOrigin()
            esp.Tracer.To = Vector2.new(worldPoint.X, worldPoint.Y)
            esp.Tracer.Color = color
            esp.Tracer.Visible = true
            esp.Tracer.Thickness = Settings.TracerThickness
        end)
    else
        pcall(function() if esp.Tracer then esp.Tracer.Visible = false end end)
    end

    -- HEALTH
    if Settings.HealthESP and esp.HealthBar then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = (maxHealth > 0) and (health / maxHealth) or 0

        local barHeight = math.max(6, screenSize * 0.8)
        local barWidth = 4
        local barPos = Vector2.new(
            boxPosition.X - barWidth - 6,
            boxPosition.Y + (screenSize - barHeight)/2
        )

        pcall(function()
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
        end)
    else
        if esp.HealthBar then for _, o in pairs(esp.HealthBar) do pcall(function() if o then o.Visible = false end end) end end
    end

    -- NAME
    if Settings.NameESP and esp.Info and esp.Info.Name then
        pcall(function()
            esp.Info.Name.Text = player.DisplayName or player.Name
            esp.Info.Name.Position = Vector2.new(boxPosition.X + boxWidth/2, boxPosition.Y - 18)
            esp.Info.Name.Color = color
            esp.Info.Name.Size = Settings.TextSize
            esp.Info.Name.Visible = true
        end)
    else
        pcall(function() if esp.Info and esp.Info.Name then esp.Info.Name.Visible = false end end)
    end

    -- SNAPLINES
    if Settings.Snaplines and esp.Snapline then
        pcall(function()
            esp.Snapline.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
            esp.Snapline.To = Vector2.new(worldPoint.X, worldPoint.Y)
            esp.Snapline.Color = color
            esp.Snapline.Visible = true
        end)
    else
        pcall(function() if esp.Snapline then esp.Snapline.Visible = false end end)
    end

    -- CHAMS / HIGHLIGHT
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

    -- SKELETON
    if Settings.SkeletonESP then
        local function findPart(...)
            for i = 1, select("#", ...) do
                local name = select(i, ...)
                local p = character:FindFirstChild(name)
                if p then return p end
            end
            return nil
        end

        local bones = {
            Head = findPart("Head"),
            UpperTorso = findPart("UpperTorso", "Torso"),
            LowerTorso = findPart("LowerTorso", "Torso"),
            RootPart = findPart("HumanoidRootPart"),

            LeftUpperArm = findPart("LeftUpperArm", "Left Arm"),
            LeftLowerArm = findPart("LeftLowerArm", "Left Arm"),
            LeftHand = findPart("LeftHand", "Left Arm"),

            RightUpperArm = findPart("RightUpperArm", "Right Arm"),
            RightLowerArm = findPart("RightLowerArm", "Right Arm"),
            RightHand = findPart("RightHand", "Right Arm"),

            LeftUpperLeg = findPart("LeftUpperLeg", "Left Leg"),
            LeftLowerLeg = findPart("LeftLowerLeg", "Left Leg"),
            LeftFoot = findPart("LeftFoot", "Left Leg"),

            RightUpperLeg = findPart("RightUpperLeg", "Right Leg"),
            RightLowerLeg = findPart("RightLowerLeg", "Right Leg"),
            RightFoot = findPart("RightFoot", "Right Leg")
        }

        local function drawBone(fromPart, toPart, line)
            if not fromPart or not toPart or not line then
                pcall(function() if line then line.Visible = false end end)
                return
            end
            local fromPos = fromPart.Position
            local toPos = toPart.Position
            local fromScreen, fromVisible = Camera:WorldToViewportPoint(fromPos)
            local toScreen, toVisible = Camera:WorldToViewportPoint(toPos)
            if not fromVisible or not toVisible or fromScreen.Z < 0 or toScreen.Z < 0 then
                pcall(function() line.Visible = false end)
                return
            end
            local w, h = Camera.ViewportSize.X, Camera.ViewportSize.Y
            if fromScreen.X < 0 or fromScreen.X > w or fromScreen.Y < 0 or fromScreen.Y > h or toScreen.X < 0 or toScreen.X > w or toScreen.Y < 0 or toScreen.Y > h then
                pcall(function() line.Visible = false end)
                return
            end

            pcall(function()
                line.From = Vector2.new(fromScreen.X, fromScreen.Y)
                line.To = Vector2.new(toScreen.X, toScreen.Y)
                line.Color = Settings.SkeletonColor
                line.Thickness = Settings.SkeletonThickness
                line.Transparency = Settings.SkeletonTransparency
                line.Visible = true
            end)
        end

        local sk = Drawings.Skeleton[player]
        if sk then
            drawBone(bones.Head, bones.UpperTorso, sk.Head)
            drawBone(bones.UpperTorso, bones.LowerTorso, sk.UpperSpine)

            drawBone(bones.UpperTorso, bones.LeftUpperArm, sk.LeftShoulder)
            drawBone(bones.LeftUpperArm, bones.LeftLowerArm, sk.LeftUpperArm)
            drawBone(bones.LeftLowerArm, bones.LeftHand, sk.LeftLowerArm)

            drawBone(bones.UpperTorso, bones.RightUpperArm, sk.RightShoulder)
            drawBone(bones.RightUpperArm, bones.RightLowerArm, sk.RightUpperArm)
            drawBone(bones.RightLowerArm, bones.RightHand, sk.RightLowerArm)

            drawBone(bones.LowerTorso, bones.LeftUpperLeg, sk.LeftHip)
            drawBone(bones.LeftUpperLeg, bones.LeftLowerLeg, sk.LeftUpperLeg)
            drawBone(bones.LeftLowerLeg, bones.LeftFoot, sk.LeftLowerLeg)

            drawBone(bones.LowerTorso, bones.RightUpperLeg, sk.RightHip)
            drawBone(bones.RightUpperLeg, bones.RightLowerLeg, sk.RightUpperLeg)
            drawBone(bones.RightLowerLeg, bones.RightFoot, sk.RightLowerLeg)
        end
    else
        local sk = Drawings.Skeleton[player]
        if sk then for _, l in pairs(sk) do pcall(function() l.Visible = false end) end end
    end
end

local function DisableESP()
    for _, player in ipairs(Players:GetPlayers()) do
        local esp = Drawings.ESP[player]
        if esp then HideAllDrawingsForESP(esp) end
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do pcall(function() line.Visible = false end) end end
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

-- ========== UI (full reinserted) ==========

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
            -- call Unload implemented later
            if type(_G.__WA_UnloadESP) == "function" then
                pcall(_G.__WA_UnloadESP)
            else
                -- fallback
                CleanupESP()
                if renderConnection and renderConnection.Disconnect then pcall(function() renderConnection:Disconnect() end) end
                pcall(function() Window:Destroy() end)
            end
        end
    })
end

-- skeleton section UI (keep at end)
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
                if line then pcall(function() line.Color = Value end) end
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
                if line then pcall(function() line.Thickness = Value end) end
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
                if line then pcall(function() line.Transparency = Value end) end
            end
        end
    end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "WA Universal ESP", Content = "Loaded successfully!", Duration = 5 })

-- Rainbow updater
task.spawn(function()
    while task.wait(0.05) do
        Colors.Rainbow = Color3.fromHSV((tick() * (Settings.RainbowSpeed or 1)) % 1, 1, 1)
    end
end)

-- Render loop (store connection so we can disconnect on unload)
local renderConnection
local lastUpdate = 0
renderConnection = RunService.RenderStepped:Connect(function()
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

-- player events
Players.PlayerAdded:Connect(function(pl)
    if pl ~= LocalPlayer then CreateESP(pl) end
end)
Players.PlayerRemoving:Connect(function(pl)
    RemoveESP(pl)
end)

-- init existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then CreateESP(player) end
end

-- Unload helper accessible to UI callback
local function Unload()
    CleanupESP()
    if renderConnection and renderConnection.Disconnect then
        pcall(function() renderConnection:Disconnect() end)
    end
    if Window and type(Window.Destroy) == "function" then
        pcall(function() Window:Destroy() end)
    end
    -- clear any global pointer we set
    _G.__WA_UnloadESP = nil
end

-- let SaveManager UI call it
_G.__WA_UnloadESP = Unload

-- End of script
