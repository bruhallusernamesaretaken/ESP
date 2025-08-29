-- WA Universal ESP (Improved) + Radar (with names)
-- Adds a small radar UI with blips showing upright name + distance labels inside the radar circle.

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- containers
local Drawings = {
    ESP = {},         -- per-player main ESP
    Skeleton = {},    -- per-player skeleton lines
}
local Highlights = {}
local Connections = {}

-- colors & settings (kept structure similar to original)
local Colors = {
    Enemy = Color3.fromRGB(255, 25, 25),
    Ally = Color3.fromRGB(25, 255, 25),
    Neutral = Color3.fromRGB(255, 255, 255),
    Selected = Color3.fromRGB(255, 210, 0),
    Health = Color3.fromRGB(0, 255, 0),
    Distance = Color3.fromRGB(200, 200, 200),
    Rainbow = Color3.fromRGB(255,255,255)
}

local Settings = {
    Enabled = false,
    TeamCheck = false,
    ShowTeam = false,
    VisibilityCheck = true,        -- uses raycast to check occlusion
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
    NameMode = "DisplayName", -- DisplayName or Name
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
    HealthTextFormat = "Number", -- Number/Percentage/Both

    -- Radar-specific
    RadarEnabled = false,
    RadarRange = 300,     -- studs
    RadarSize = 180,      -- pixels (diameter)
    RadarShowNames = true -- new toggle for showing names on radar
}

-- small helper: safe Drawing.new
local function SafeDrawingNew(kind)
    local ok, res = pcall(function() return Drawing and Drawing.new(kind) end)
    if ok and res then return res end
    -- fallback table to avoid nil errors if Drawing lib missing (will be invisible)
    return {
        Visible = false,
        Remove = function() end
    }
end

-- helper to check whether a point is in viewport bounds
local function InBounds(vec2)
    local vs = Camera.ViewportSize
    return vec2.X >= 0 and vec2.X <= vs.X and vec2.Y >= 0 and vec2.Y <= vs.Y
end

-- Helper: create & initialize lines/squares/texts for an ESP entry
local function CreateESP(player)
    if player == LocalPlayer then return end
    if Drawings.ESP[player] then return end

    local esp = {}

    -- Box lines (8 lines used across styles)
    esp.Box = {
        TopLeft = SafeDrawingNew("Line"),
        TopRight = SafeDrawingNew("Line"),
        BottomLeft = SafeDrawingNew("Line"),
        BottomRight = SafeDrawingNew("Line"),
        Left = SafeDrawingNew("Line"),
        Right = SafeDrawingNew("Line"),
        Top = SafeDrawingNew("Line"),
        Bottom = SafeDrawingNew("Line"),
        -- persistent connectors for 3D boxes (4 lines)
        Connectors = {
            SafeDrawingNew("Line"), SafeDrawingNew("Line"),
            SafeDrawingNew("Line"), SafeDrawingNew("Line")
        }
    }

    -- tracer
    esp.Tracer = SafeDrawingNew("Line")

    -- healthbar
    esp.HealthBar = {
        Outline = SafeDrawingNew("Square"),
        Fill = SafeDrawingNew("Square"),
        Text = SafeDrawingNew("Text")
    }

    -- info texts
    esp.Info = {
        Name = SafeDrawingNew("Text"),
        Distance = SafeDrawingNew("Text")
    }

    -- snapline
    esp.Snapline = SafeDrawingNew("Line")

    -- init defaults (avoid doing many property sets every frame)
    local function initLine(line)
        if not line then return end
        line.Visible = false
        line.Color = Colors.Enemy
        line.Thickness = Settings.BoxThickness
    end
    for _, line in pairs(esp.Box) do
        if type(line) == "table" then
            -- some are tables (Connectors), iterate
            if #line > 0 then
                for _, l in ipairs(line) do initLine(l) end
            end
        else
            initLine(line)
        end
    end

    if esp.Tracer then
        esp.Tracer.Visible = false
        esp.Tracer.Thickness = Settings.TracerThickness
        esp.Tracer.Color = Colors.Enemy
    end

    if esp.HealthBar.Outline then
        esp.HealthBar.Outline.Visible = false
    end
    if esp.HealthBar.Fill then
        esp.HealthBar.Fill.Visible = false
    end
    if esp.HealthBar.Text then
        esp.HealthBar.Text.Visible = false
        esp.HealthBar.Text.Center = true
        esp.HealthBar.Text.Size = Settings.TextSize
        esp.HealthBar.Text.Font = Settings.TextFont
    end

    for _, text in pairs(esp.Info) do
        if text then
            text.Visible = false
            text.Center = true
            text.Size = Settings.TextSize
            text.Font = Settings.TextFont
            text.Outline = true
            text.Color = Colors.Enemy
        end
    end

    esp.Snapline.Visible = false
    esp.Snapline.Thickness = 1
    esp.Snapline.Color = Colors.Enemy

    -- highlight (chams)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Settings.ChamsFillColor
    highlight.OutlineColor = Settings.ChamsOutlineColor
    highlight.FillTransparency = Settings.ChamsTransparency
    highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = Settings.ChamsEnabled
    Highlights[player] = highlight

    -- skeleton lines (persistent)
    local skeleton = {
        Head = SafeDrawingNew("Line"),
        Neck = SafeDrawingNew("Line"),
        UpperSpine = SafeDrawingNew("Line"),
        LowerSpine = SafeDrawingNew("Line"),

        LeftShoulder = SafeDrawingNew("Line"),
        LeftUpperArm = SafeDrawingNew("Line"),
        LeftLowerArm = SafeDrawingNew("Line"),
        LeftHand = SafeDrawingNew("Line"),

        RightShoulder = SafeDrawingNew("Line"),
        RightUpperArm = SafeDrawingNew("Line"),
        RightLowerArm = SafeDrawingNew("Line"),
        RightHand = SafeDrawingNew("Line"),

        LeftHip = SafeDrawingNew("Line"),
        LeftUpperLeg = SafeDrawingNew("Line"),
        LeftLowerLeg = SafeDrawingNew("Line"),
        LeftFoot = SafeDrawingNew("Line"),

        RightHip = SafeDrawingNew("Line"),
        RightUpperLeg = SafeDrawingNew("Line"),
        RightLowerLeg = SafeDrawingNew("Line"),
        RightFoot = SafeDrawingNew("Line")
    }
    for _, l in pairs(skeleton) do
        if l then
            l.Visible = false
            l.Color = Settings.SkeletonColor
            l.Thickness = Settings.SkeletonThickness
            l.Transparency = Settings.SkeletonTransparency
        end
    end
    Drawings.Skeleton[player] = skeleton

    Drawings.ESP[player] = esp

    -- hook character events to enable/disable highlight properly
    local charConn
    charConn = player.CharacterAdded:Connect(function(char)
        local h = Highlights[player]
        if h and Settings.ChamsEnabled then
            h.Parent = char
            h.Enabled = true
        end
    end)
    Connections[player] = Connections[player] or {}
    table.insert(Connections[player], charConn)
end

local function RemoveESP(player)
    local esp = Drawings.ESP[player]
    if esp then
        -- remove all drawings
        if esp.Box then
            for k, v in pairs(esp.Box) do
                if type(v) == "table" then
                    for _, l in ipairs(v) do
                        if l and l.Remove then pcall(l.Remove, l) end
                    end
                else
                    if v and v.Remove then pcall(v.Remove, v) end
                end
            end
        end
        if esp.Tracer and esp.Tracer.Remove then pcall(esp.Tracer.Remove, esp.Tracer) end
        if esp.HealthBar then
            for _, v in pairs(esp.HealthBar) do if v and v.Remove then pcall(v.Remove, v) end end
        end
        if esp.Info then
            for _, v in pairs(esp.Info) do if v and v.Remove then pcall(v.Remove, v) end end
        end
        if esp.Snapline and esp.Snapline.Remove then pcall(esp.Snapline.Remove, esp.Snapline) end
        Drawings.ESP[player] = nil
    end

    local skeleton = Drawings.Skeleton[player]
    if skeleton then
        for _, line in pairs(skeleton) do if line and line.Remove then pcall(line.Remove, line) end end
        Drawings.Skeleton[player] = nil
    end

    local highlight = Highlights[player]
    if highlight then
        pcall(function() highlight:Destroy() end)
        Highlights[player] = nil
    end

    -- disconnect player-specific connections
    if Connections[player] then
        for _, c in ipairs(Connections[player]) do
            if c and c.Disconnect then
                pcall(function() c:Disconnect() end)
            elseif c and c.Disconnect == nil and type(c) == "function" then
                -- nothing
            end
        end
        Connections[player] = nil
    end
end

-- hide every drawing group helper
local function HideAllForESP(esp)
    if not esp then return end
    if esp.Box then
        for _, v in pairs(esp.Box) do
            if type(v) == "table" then
                for _, l in ipairs(v) do if l then l.Visible = false end end
            else
                if v then v.Visible = false end
            end
        end
    end
    if esp.Tracer then esp.Tracer.Visible = false end
    if esp.HealthBar then for _, v in pairs(esp.HealthBar) do if v then v.Visible = false end end end
    if esp.Info then for _, v in pairs(esp.Info) do if v then v.Visible = false end end end
    if esp.Snapline then esp.Snapline.Visible = false end
end

-- choose color for the player
local function GetPlayerColor(player, forPart)
    -- forPart: "Box"/"Tracer"/"Text" (used for rainbow options)
    if Settings.RainbowEnabled then
        if forPart == "Box" and Settings.RainbowBoxes then return Colors.Rainbow end
        if forPart == "Tracer" and Settings.RainbowTracers then return Colors.Rainbow end
        if forPart == "Text" and Settings.RainbowText then return Colors.Rainbow end
        if Settings.RainbowBoxes and Settings.RainbowTracers and Settings.RainbowText then return Colors.Rainbow end
    end
    if (player.Team ~= nil and LocalPlayer.Team ~= nil) and player.Team == LocalPlayer.Team then
        return Colors.Ally
    else
        return Colors.Enemy
    end
end

-- tracer origin helper
local function GetTracerOrigin()
    local origin = Settings.TracerOrigin
    local vs = Camera.ViewportSize
    if origin == "Bottom" then
        return Vector2.new(vs.X / 2, vs.Y)
    elseif origin == "Top" then
        return Vector2.new(vs.X / 2, 0)
    elseif origin == "Mouse" then
        local m = UserInputService:GetMouseLocation()
        -- GetMouseLocation returns absolute screen coordinates that include top bar. Safe enough usually.
        return Vector2.new(m.X, m.Y)
    else -- Center
        return Vector2.new(vs.X / 2, vs.Y / 2)
    end
end

-- Visibility check using raycast: returns true if visible (no obstacle between camera and part center)
local function IsVisibleToCamera(targetPart, character)
    if not Settings.VisibilityCheck then return true end
    if not targetPart or not targetPart.Position then return true end
    local origin = Camera.CFrame.Position
    local dir = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(origin, dir, params)
    if not result then
        return true
    end
    -- If hit something that's NOT the target character, then occluded
    return result.Instance:IsDescendantOf(character)
end

-- get bones robustly (works for R6/R15)
local function GetBones(character)
    if not character then return nil end
    local bones = {}
    bones.Head = character:FindFirstChild("Head")
    bones.UpperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    bones.LowerTorso = character:FindFirstChild("LowerTorso") or bones.UpperTorso
    bones.RootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    bones.LeftUpperArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
    bones.LeftLowerArm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
    bones.LeftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
    bones.RightUpperArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
    bones.RightLowerArm = character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm")
    bones.RightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    bones.LeftUpperLeg = character:FindFirstChild("LeftUpperLeg") or character:FindFirstChild("Left Leg")
    bones.LeftLowerLeg = character:FindFirstChild("LeftLowerLeg") or character:FindFirstChild("Left Leg")
    bones.LeftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
    bones.RightUpperLeg = character:FindFirstChild("RightUpperLeg") or character:FindFirstChild("Right Leg")
    bones.RightLowerLeg = character:FindFirstChild("RightLowerLeg") or character:FindFirstChild("Right Leg")
    bones.RightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")

    -- require minimal bones
    if not (bones.Head and bones.UpperTorso and bones.RootPart) then return nil end
    return bones
end

-- === Radar UI Creation ===
local radarGui, radarFrame, radarBlipContainer
do
    -- create ScreenGui (only once)
    radarGui = Instance.new("ScreenGui")
    radarGui.Name = "WA_ESP_Radar"
    radarGui.ResetOnSpawn = false
    radarGui.Parent = PlayerGui

    radarFrame = Instance.new("Frame")
    radarFrame.Name = "Circle"
    radarFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    radarFrame.BackgroundTransparency = 0.25
    radarFrame.BorderSizePixel = 0
    radarFrame.Size = UDim2.fromOffset(Settings.RadarSize, Settings.RadarSize)
    radarFrame.Position = UDim2.new(0, 16, 1, - (Settings.RadarSize + 16)) -- bottom-left offset
    radarFrame.AnchorPoint = Vector2.new(0, 0)
    radarFrame.Parent = radarGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = radarFrame

    local inner = Instance.new("Frame")
    inner.Name = "Inner"
    inner.Size = UDim2.fromScale(1, 1)
    inner.BackgroundTransparency = 1
    inner.Parent = radarFrame

    radarBlipContainer = Instance.new("Folder")
    radarBlipContainer.Name = "Blips"
    radarBlipContainer.Parent = radarFrame
end

-- Helper: create a blip UI (frame + upright distance label + name) for a player
local function CreateBlipFor(player)
    if not radarBlipContainer then return end
    if radarBlipContainer:FindFirstChild(player.Name) then return radarBlipContainer[player.Name] end

    local blip = Instance.new("Frame")
    blip.Name = player.Name
    blip.Size = UDim2.fromOffset(8, 8)
    blip.AnchorPoint = Vector2.new(0.5, 0.5)
    blip.BackgroundColor3 = Colors.Enemy
    blip.BorderSizePixel = 0
    blip.Parent = radarBlipContainer

    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(1,0)
    uic.Parent = blip

    -- Name label (above distance)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.fromOffset(64, 16)
    nameLabel.AnchorPoint = Vector2.new(0.5, 1) -- bottom center of the label attached to blip
    nameLabel.Position = UDim2.new(0.5, 0, 0, -20) -- above distance label
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.Text = ""
    nameLabel.TextYAlignment = Enum.TextYAlignment.Bottom
    nameLabel.Parent = blip

    -- Distance label (just above the blip)
    local label = Instance.new("TextLabel")
    label.Name = "DistanceLabel"
    label.Size = UDim2.fromOffset(48, 14)
    label.AnchorPoint = Vector2.new(0.5, 1) -- bottom center anchored to the blip
    label.Position = UDim2.new(0.5, 0, 0, -6) -- sits just above the blip (below nameLabel)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Text = ""
    label.Parent = blip

    return blip
end

-- Update radar each frame (clamp blips inside circle, labels upright)
local function UpdateRadar()
    if not Settings.RadarEnabled then
        if radarFrame and radarFrame.Parent then radarFrame.Visible = false end
        return
    end
    if not radarFrame or not radarBlipContainer then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        radarFrame.Visible = false
        return
    end

    radarFrame.Visible = true
    -- update size if changed by settings
    local sizePx = math.max(32, Settings.RadarSize)
    if radarFrame.Size.X.Offset ~= sizePx or radarFrame.Size.Y.Offset ~= sizePx then
        radarFrame.Size = UDim2.fromOffset(sizePx, sizePx)
        radarFrame.Position = UDim2.new(0, 16, 1, - (sizePx + 16))
    end

    local radarRadius = radarFrame.AbsoluteSize.X / 2
    local center = Vector2.new(radarRadius, radarRadius)
    local localHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end

    -- mark seen players to later remove stale blips
    local seen = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP = player.Character.HumanoidRootPart
            local offset = targetHRP.Position - localHRP.Position
            local distance = offset.Magnitude

            if distance <= Settings.RadarRange then
                local angle = math.atan2(offset.X, offset.Z) -- angle relative to forward
                local scaled = (distance / Settings.RadarRange) * radarRadius
                -- clamp to inside circle (leave margin for label)
                local margin = 18
                scaled = math.clamp(scaled, 0, radarRadius - margin)

                local localX = center.X + math.sin(angle) * scaled
                local localY = center.Y - math.cos(angle) * scaled

                local blip = radarBlipContainer:FindFirstChild(player.Name) or CreateBlipFor(player)
                if blip then
                    blip.Position = UDim2.fromOffset(localX - blip.Size.X.Offset/2, localY - blip.Size.Y.Offset/2)
                    blip.BackgroundColor3 = (player.Team == LocalPlayer.Team and Colors.Ally) or Colors.Enemy
                    blip.Visible = true

                    local nameLabel = blip:FindFirstChild("NameLabel")
                    local label = blip:FindFirstChild("DistanceLabel")

                    -- set name text using NameMode (DisplayName/Name)
                    if Settings.RadarShowNames and nameLabel then
                        local nm = (Settings.NameMode == "DisplayName" and player.DisplayName) or player.Name
                        nameLabel.Text = nm
                        nameLabel.Visible = true
                        nameLabel.TextColor3 = GetPlayerColor(player, "Text") or Colors.Neutral
                    elseif nameLabel then
                        nameLabel.Visible = false
                    end

                    if label then
                        label.Text = tostring(math.floor(distance + 0.5)) .. "m"
                        label.Visible = true
                        label.TextColor3 = Colors.Distance
                    end

                    -- ensure label/blip stays inside circle (if too close to edge, push toward center)
                    local distFromCenter = (Vector2.new(localX, localY) - center).Magnitude
                    if distFromCenter > (radarRadius - margin) then
                        local push = (distFromCenter - (radarRadius - margin))
                        local moveDir = (center - Vector2.new(localX, localY)).Unit
                        local newLocal = Vector2.new(localX, localY) + moveDir * push
                        blip.Position = UDim2.fromOffset(newLocal.X - blip.Size.X.Offset/2, newLocal.Y - blip.Size.Y.Offset/2)
                    end
                end
                seen[player.Name] = true
            else
                -- hide if out of radar range
                local old = radarBlipContainer:FindFirstChild(player.Name)
                if old then old.Visible = false end
            end
        else
            -- hide if no character
            local old = radarBlipContainer:FindFirstChild(player.Name)
            if old then old.Visible = false end
        end
    end

    -- cleanup stale blips (players who left or not seen)
    for _, child in ipairs(radarBlipContainer:GetChildren()) do
        if not seen[child.Name] then
            child.Visible = false
        end
    end
end

-- === End Radar UI ===

-- Main update function for a single player
local function UpdateESP(player)
    if not Settings.Enabled then return end
    if player == LocalPlayer then return end

    local esp = Drawings.ESP[player]
    if not esp then return end

    local character = player.Character
    if not character then
        HideAllForESP(esp)
        -- hide skeleton
        local sk = Drawings.Skeleton[player]
        if sk then for _, l in pairs(sk) do if l then l.Visible = false end end end
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        HideAllForESP(esp)
        local sk = Drawings.Skeleton[player]
        if sk then for _, l in pairs(sk) do if l then l.Visible = false end end end
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        HideAllForESP(esp)
        local sk = Drawings.Skeleton[player]
        if sk then for _, l in pairs(sk) do if l then l.Visible = false end end end
        return
    end

    local pos3, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if not onScreen or distance > Settings.MaxDistance then
        HideAllForESP(esp)
        return
    end

    if Settings.TeamCheck and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
        HideAllForESP(esp)
        return
    end

    -- visibility (raycast) check
    local visible = true
    if Settings.VisibilityCheck then
        visible = IsVisibleToCamera(rootPart, character)
    end

    -- compute box corners & screen size
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame

    -- compute top & bottom screen positions
    local topPos3, topOn = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, size.Y/2, 0))
    local botPos3, botOn = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, -size.Y/2, 0))
    if not topOn or not botOn then
        HideAllForESP(esp)
        return
    end

    local screenHeight = math.abs(botPos3.Y - topPos3.Y)
    local boxWidth = screenHeight * 0.65
    local boxPos = Vector2.new(topPos3.X - boxWidth/2, topPos3.Y)
    local boxSize = Vector2.new(boxWidth, screenHeight)

    -- color selection (accounting for rainbow)
    local boxColor = GetPlayerColor(player, "Box")
    local tracerColor = GetPlayerColor(player, "Tracer")
    local textColor = GetPlayerColor(player, "Text")

    -- apply rainbow if enabled
    if Settings.RainbowEnabled then
        boxColor = Settings.RainbowBoxes and Colors.Rainbow or boxColor
        tracerColor = Settings.RainbowTracers and Colors.Rainbow or tracerColor
        textColor = Settings.RainbowText and Colors.Rainbow or textColor
    end

    -- Hide all box lines by default
    for _, v in pairs(esp.Box) do
        if type(v) == "table" then
            for _, l in ipairs(v) do if l then l.Visible = false end end
        else
            if v then v.Visible = false end
        end
    end

    -- BOX: Corner / Full / ThreeD
    if Settings.BoxESP then
        if Settings.BoxStyle == "ThreeD" then
            -- compute front/back corners
            local function vwp(vec) return Camera:WorldToViewportPoint(vec) end
            local frontTL = vwp(cf * CFrame.new(-size.X/2,  size.Y/2, -size.Z/2))
            local frontTR = vwp(cf * CFrame.new( size.X/2,  size.Y/2, -size.Z/2))
            local frontBL = vwp(cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2))
            local frontBR = vwp(cf * CFrame.new( size.X/2, -size.Y/2, -size.Z/2))

            local backTL = vwp(cf * CFrame.new(-size.X/2,  size.Y/2, size.Z/2))
            local backTR = vwp(cf * CFrame.new( size.X/2,  size.Y/2, size.Z/2))
            local backBL = vwp(cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2))
            local backBR = vwp(cf * CFrame.new( size.X/2, -size.Y/2, size.Z/2))

            -- ensure all parts are in front of camera
            if frontTL.Z <= 0 or frontTR.Z <= 0 or frontBL.Z <= 0 or frontBR.Z <= 0 or
               backTL.Z <= 0  or backTR.Z <= 0  or backBL.Z <= 0  or backBR.Z <= 0 then
                HideAllForESP(esp)
                return
            end

            -- convert to Vector2
            local fTL = Vector2.new(frontTL.X, frontTL.Y)
            local fTR = Vector2.new(frontTR.X, frontTR.Y)
            local fBL = Vector2.new(frontBL.X, frontBL.Y)
            local fBR = Vector2.new(frontBR.X, frontBR.Y)

            local bTL = Vector2.new(backTL.X, backTL.Y)
            local bTR = Vector2.new(backTR.X, backTR.Y)
            local bBL = Vector2.new(backBL.X, backBL.Y)
            local bBR = Vector2.new(backBR.X, backBR.Y)

            -- front face (use TopLeft..BottomRight to draw rectangle edges)
            esp.Box.TopLeft.From = fTL
            esp.Box.TopLeft.To   = fTR
            esp.Box.TopLeft.Color = boxColor
            esp.Box.TopLeft.Thickness = Settings.BoxThickness
            esp.Box.TopLeft.Visible = true

            esp.Box.TopRight.From = fTR
            esp.Box.TopRight.To   = fBR
            esp.Box.TopRight.Color = boxColor
            esp.Box.TopRight.Thickness = Settings.BoxThickness
            esp.Box.TopRight.Visible = true

            esp.Box.BottomLeft.From = fBL
            esp.Box.BottomLeft.To   = fBR
            esp.Box.BottomLeft.Color = boxColor
            esp.Box.BottomLeft.Thickness = Settings.BoxThickness
            esp.Box.BottomLeft.Visible = true

            esp.Box.BottomRight.From = fTL
            esp.Box.BottomRight.To   = fBL
            esp.Box.BottomRight.Color = boxColor
            esp.Box.BottomRight.Thickness = Settings.BoxThickness
            esp.Box.BottomRight.Visible = true

            -- back face (use Left/Right/Top/Bottom for back edges)
            esp.Box.Left.From = bTL
            esp.Box.Left.To   = bTR
            esp.Box.Left.Color = boxColor
            esp.Box.Left.Thickness = Settings.BoxThickness
            esp.Box.Left.Visible = true

            esp.Box.Right.From = bTR
            esp.Box.Right.To   = bBR
            esp.Box.Right.Color = boxColor
            esp.Box.Right.Thickness = Settings.BoxThickness
            esp.Box.Right.Visible = true

            esp.Box.Top.From = bBL
            esp.Box.Top.To   = bBR
            esp.Box.Top.Color = boxColor
            esp.Box.Top.Thickness = Settings.BoxThickness
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = bTL
            esp.Box.Bottom.To   = bBL
            esp.Box.Bottom.Color = boxColor
            esp.Box.Bottom.Thickness = Settings.BoxThickness
            esp.Box.Bottom.Visible = true

            -- connectors (persistent)
            local con = esp.Box.Connectors
            con[1].From = fTL; con[1].To = bTL; con[1].Color = boxColor; con[1].Thickness = Settings.BoxThickness; con[1].Visible = true
            con[2].From = fTR; con[2].To = bTR; con[2].Color = boxColor; con[2].Thickness = Settings.BoxThickness; con[2].Visible = true
            con[3].From = fBL; con[3].To = bBL; con[3].Color = boxColor; con[3].Thickness = Settings.BoxThickness; con[3].Visible = true
            con[4].From = fBR; con[4].To = bBR; con[4].Color = boxColor; con[4].Thickness = Settings.BoxThickness; con[4].Visible = true

        elseif Settings.BoxStyle == "Corner" then
            local cornerSize = math.clamp(boxWidth * 0.18, 8, boxWidth * 0.35)

            -- top horizontal lines
            esp.Box.TopLeft.From = boxPos
            esp.Box.TopLeft.To = boxPos + Vector2.new(cornerSize, 0)
            esp.Box.TopLeft.Color = boxColor
            esp.Box.TopLeft.Visible = true

            esp.Box.TopRight.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.TopRight.To = boxPos + Vector2.new(boxSize.X - cornerSize, 0)
            esp.Box.TopRight.Color = boxColor
            esp.Box.TopRight.Visible = true

            -- bottom horizontals
            esp.Box.BottomLeft.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.BottomLeft.To = boxPos + Vector2.new(cornerSize, boxSize.Y)
            esp.Box.BottomLeft.Color = boxColor
            esp.Box.BottomLeft.Visible = true

            esp.Box.BottomRight.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.BottomRight.To = boxPos + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
            esp.Box.BottomRight.Color = boxColor
            esp.Box.BottomRight.Visible = true

            -- vertical smalls
            esp.Box.Left.From = boxPos
            esp.Box.Left.To = boxPos + Vector2.new(0, cornerSize)
            esp.Box.Left.Color = boxColor
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPos + Vector2.new(boxSize.X, cornerSize)
            esp.Box.Right.Color = boxColor
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.Top.To = boxPos + Vector2.new(0, boxSize.Y - cornerSize)
            esp.Box.Top.Color = boxColor
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
            esp.Box.Bottom.Color = boxColor
            esp.Box.Bottom.Visible = true

        else -- Full box
            esp.Box.Left.From = boxPos
            esp.Box.Left.To = Vector2.new(boxPos.X, boxPos.Y + boxSize.Y)
            esp.Box.Left.Color = boxColor
            esp.Box.Left.Visible = true

            esp.Box.Right.From = Vector2.new(boxPos.X + boxSize.X, boxPos.Y)
            esp.Box.Right.To = Vector2.new(boxPos.X + boxSize.X, boxPos.Y + boxSize.Y)
            esp.Box.Right.Color = boxColor
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPos
            esp.Box.Top.To = Vector2.new(boxPos.X + boxSize.X, boxPos.Y)
            esp.Box.Top.Color = boxColor
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = Vector2.new(boxPos.X, boxPos.Y + boxSize.Y)
            esp.Box.Bottom.To = Vector2.new(boxPos.X + boxSize.X, boxPos.Y + boxSize.Y)
            esp.Box.Bottom.Color = boxColor
            esp.Box.Bottom.Visible = true

            -- hide corner lines
            esp.Box.TopLeft.Visible = false
            esp.Box.TopRight.Visible = false
            esp.Box.BottomLeft.Visible = false
            esp.Box.BottomRight.Visible = false
        end

        -- apply thickness to shown lines
        for _, v in pairs(esp.Box) do
            if type(v) == "table" then
                for _, l in ipairs(v) do
                    if l and l.Visible then l.Thickness = Settings.BoxThickness end
                end
            else
                if v and v.Visible then v.Thickness = Settings.BoxThickness end
            end
        end
    end

    -- Tracers
    if Settings.TracerESP then
        esp.Tracer.From = GetTracerOrigin()
        esp.Tracer.To = Vector2.new(pos3.X, pos3.Y)
        esp.Tracer.Color = tracerColor
        esp.Tracer.Thickness = Settings.TracerThickness
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end

    -- Health
    if Settings.HealthESP then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100
        local percent = math.clamp(health / maxHealth, 0, 1)

        local barHeight = screenHeight * 0.8
        barHeight = math.clamp(barHeight, 20, 200)
        local barWidth = 6

        local barX = boxPos.X - barWidth - 6
        if Settings.HealthBarSide == "Right" then
            barX = boxPos.X + boxSize.X + 6
        end
        local barY = boxPos.Y + (screenHeight - barHeight) / 2

        if esp.HealthBar.Outline then
            esp.HealthBar.Outline.Position = Vector2.new(barX, barY)
            esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
            esp.HealthBar.Outline.Visible = true
            esp.HealthBar.Outline.Color = Color3.fromRGB(30,30,30)
        end

        if esp.HealthBar.Fill then
            esp.HealthBar.Fill.Position = Vector2.new(barX + 1, barY + barHeight * (1 - percent))
            esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * percent)
            esp.HealthBar.Fill.Visible = true
            esp.HealthBar.Fill.Filled = true
            esp.HealthBar.Fill.Color = Color3.new(1 - (1 - percent), percent, 0) -- simple gradient (red->green)
        end

        if Settings.HealthStyle == "Text" or Settings.HealthStyle == "Both" then
            local txt = ""
            if Settings.HealthTextFormat == "Number" then
                txt = tostring(math.floor(health)) .. Settings.HealthTextSuffix
            elseif Settings.HealthTextFormat == "Percentage" then
                txt = tostring(math.floor(percent * 100)) .. "%"
            else
                txt = tostring(math.floor(health)) .. " | " .. tostring(math.floor(percent * 100)) .. "%"
            end
            esp.HealthBar.Text.Text = txt
            esp.HealthBar.Text.Position = Vector2.new(barX + barWidth / 2 + (Settings.HealthBarSide == "Right" and 20 or -20), barY + barHeight / 2)
            esp.HealthBar.Text.Center = true
            esp.HealthBar.Text.Color = Colors.Health
            esp.HealthBar.Text.Size = Settings.TextSize
            esp.HealthBar.Text.Visible = true
        else
            if esp.HealthBar.Text then esp.HealthBar.Text.Visible = false end
        end
    else
        if esp.HealthBar then for _, v in pairs(esp.HealthBar) do if v then v.Visible = false end end end
    end

    -- Name text
    if Settings.NameESP then
        local nm = (Settings.NameMode == "DisplayName" and player.DisplayName) or player.Name
        esp.Info.Name.Text = nm
        esp.Info.Name.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y - (Settings.TextSize + 4))
        esp.Info.Name.Color = textColor
        esp.Info.Name.Size = Settings.TextSize
        esp.Info.Name.Visible = true
    else
        if esp.Info.Name then esp.Info.Name.Visible = false end
    end

    -- Distance text (existing on-screen box distance)
    if Settings.ShowDistance and esp.Info.Distance then
        local distTxt = tostring(math.floor(distance)) .. " " .. (Settings.DistanceUnit or "studs")
        esp.Info.Distance.Text = distTxt
        esp.Info.Distance.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y + boxSize.Y + 4)
        esp.Info.Distance.Visible = true
        esp.Info.Distance.Color = Colors.Distance
        esp.Info.Distance.Size = math.max(12, Settings.TextSize - 2)
    else
        if esp.Info.Distance then esp.Info.Distance.Visible = false end
    end

    -- Snapline
    if Settings.Snaplines then
        local vs = Camera.ViewportSize
        esp.Snapline.From = Vector2.new(vs.X/2, vs.Y)
        esp.Snapline.To = Vector2.new(pos3.X, pos3.Y)
        esp.Snapline.Color = boxColor
        esp.Snapline.Visible = true
    else
        esp.Snapline.Visible = false
    end

    -- Chams (Highlight) -- set Parent if enabled & visible
    local highlight = Highlights[player]
    if highlight then
        if Settings.ChamsEnabled and character then
            highlight.Parent = character
            highlight.FillColor = (visible and Settings.ChamsFillColor) or Settings.ChamsOccludedColor
            highlight.OutlineColor = Settings.ChamsOutlineColor
            highlight.FillTransparency = Settings.ChamsTransparency
            highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
            highlight.Enabled = true
        else
            highlight.Enabled = false
        end
    end

    -- Skeleton
    if Settings.SkeletonESP then
        local bones = GetBones(character)
        local skeleton = Drawings.Skeleton[player]
        if bones and skeleton then
            local function drawBonePart(a, b, line)
                if not a or not b or not line then
                    if line then line.Visible = false end
                    return
                end
                local aPos3, aOn = Camera:WorldToViewportPoint(a.Position)
                local bPos3, bOn = Camera:WorldToViewportPoint(b.Position)
                if not aOn or not bOn or aPos3.Z <= 0 or bPos3.Z <= 0 then
                    line.Visible = false
                    return
                end
                local a2 = Vector2.new(aPos3.X, aPos3.Y)
                local b2 = Vector2.new(bPos3.X, bPos3.Y)
                if not (InBounds(a2) or InBounds(b2)) then
                    line.Visible = false
                    return
                end
                line.From = a2
                line.To = b2
                line.Color = Settings.SkeletonColor
                line.Thickness = Settings.SkeletonThickness
                line.Transparency = Settings.SkeletonTransparency
                line.Visible = true
            end

            -- Head -> UpperTorso
            drawBonePart(bones.Head, bones.UpperTorso, skeleton.Head)
            -- UpperTorso -> LowerTorso
            drawBonePart(bones.UpperTorso, bones.LowerTorso, skeleton.UpperSpine)

            -- left arm chain
            drawBonePart(bones.UpperTorso, bones.LeftUpperArm, skeleton.LeftShoulder)
            drawBonePart(bones.LeftUpperArm, bones.LeftLowerArm, skeleton.LeftUpperArm)
            drawBonePart(bones.LeftLowerArm, bones.LeftHand, skeleton.LeftLowerArm)

            -- right arm chain
            drawBonePart(bones.UpperTorso, bones.RightUpperArm, skeleton.RightShoulder)
            drawBonePart(bones.RightUpperArm, bones.RightLowerArm, skeleton.RightUpperArm)
            drawBonePart(bones.RightLowerArm, bones.RightHand, skeleton.RightLowerArm)

            -- left leg chain
            drawBonePart(bones.LowerTorso, bones.LeftUpperLeg, skeleton.LeftHip)
            drawBonePart(bones.LeftUpperLeg, bones.LeftLowerLeg, skeleton.LeftUpperLeg)
            drawBonePart(bones.LeftLowerLeg, bones.LeftFoot, skeleton.LeftLowerLeg)

            -- right leg chain
            drawBonePart(bones.LowerTorso, bones.RightUpperLeg, skeleton.RightHip)
            drawBonePart(bones.RightUpperLeg, bones.RightLowerLeg, skeleton.RightUpperLeg)
            drawBonePart(bones.RightLowerLeg, bones.RightFoot, skeleton.RightLowerLeg)
        else
            -- hide skeleton if bones not available
            if Drawings.Skeleton[player] then
                for _, l in pairs(Drawings.Skeleton[player]) do if l then l.Visible = false end end
            end
        end
    else
        if Drawings.Skeleton[player] then for _, l in pairs(Drawings.Skeleton[player]) do if l then l.Visible = false end end end
    end
end

-- Hide all ESP (fast path)
local function DisableESP()
    for player, esp in pairs(Drawings.ESP) do
        HideAllForESP(esp)
    end
    for player, sk in pairs(Drawings.Skeleton) do
        for _, l in pairs(sk) do if l then l.Visible = false end end
    end
    if radarFrame then radarFrame.Visible = false end
end

-- Full cleanup
local function CleanupESP()
    for _, player in ipairs(Players:GetPlayers()) do
        RemoveESP(player)
    end
    Drawings = { ESP = {}, Skeleton = {} }
    Highlights = {}
    -- destroy radar UI
    if radarGui and radarGui.Parent then
        pcall(function() radarGui:Destroy() end)
    end
end

-- Build UI (keeps your original Fluent layout and hooks)
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
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then CreateESP(p) end
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

    -- Radar section in ESP tab
    local RadarSection = Tabs.ESP:AddSection("Radar")
    local RadarToggle = RadarSection:AddToggle("RadarEnabled", {
        Title = "Enable Radar",
        Default = false
    })
    RadarToggle:OnChanged(function()
        Settings.RadarEnabled = RadarToggle.Value
        radarFrame.Visible = Settings.RadarEnabled
    end)

    local RadarRangeSlider = RadarSection:AddSlider("RadarRange", {
        Title = "Radar Range (studs)",
        Default = Settings.RadarRange,
        Min = 50,
        Max = 2000,
        Rounding = 0
    })
    RadarRangeSlider:OnChanged(function(Value)
        Settings.RadarRange = Value
    end)

    local RadarSizeSlider = RadarSection:AddSlider("RadarSize", {
        Title = "Radar Size (px)",
        Default = Settings.RadarSize,
        Min = 64,
        Max = 400,
        Rounding = 0
    })
    RadarSizeSlider:OnChanged(function(Value)
        Settings.RadarSize = Value
        radarFrame.Size = UDim2.fromOffset(Value, Value)
        radarFrame.Position = UDim2.new(0, 16, 1, - (Value + 16))
    end)

    local RadarNameToggle = RadarSection:AddToggle("RadarShowNames", {
        Title = "Show Names",
        Default = true
    })
    RadarNameToggle:OnChanged(function()
        Settings.RadarShowNames = RadarNameToggle.Value
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
            -- try to disconnect the RenderStepped connection(s)
            for _, connection in ipairs(getconnections or {}) do
                pcall(function() if connection and connection.Disable then connection:Disable() end end)
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

-- rainbow updater (cached tick)
local lastRainbowTick = 0
local function UpdateRainbow(dt)
    if not Settings.RainbowEnabled then return end
    local h = (tick() * Settings.RainbowSpeed) % 1
    Colors.Rainbow = Color3.fromHSV(h, 1, 1)
end

-- Render loop
local lastUpdate = 0
local function RenderLoop()
    local now = tick()
    if now - lastUpdate < Settings.RefreshRate then return end
    lastUpdate = now

    -- update viewport cached rainbow & size
    UpdateRainbow(now - lastUpdate)

    -- iterate players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if Settings.Enabled and not Drawings.ESP[player] then
                CreateESP(player)
            end
            if Drawings.ESP[player] then
                UpdateESP(player)
            end
        end
    end

    -- update Radar (UI)
    UpdateRadar()
end

-- main connection
local renderConn = RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        DisableESP()
        return
    end
    RenderLoop()
end)

-- players connect/disconnect
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then CreateESP(p) end
end)
Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p)
    -- also remove blip
    if radarBlipContainer and radarBlipContainer:FindFirstChild(p.Name) then
        pcall(function() radarBlipContainer[p.Name]:Destroy() end)
    end
end)

-- initial create
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end

Window:SelectTab(1)

Fluent:Notify({
    Title = "WA Universal ESP",
    Content = "Loaded successfully!",
    Duration = 4
})

-- skeleton section UI (kept at bottom as in original)
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
                if line then line.Color = Value end
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
                if line then line.Thickness = Value end
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
                if line then line.Transparency = Value end
            end
        end
    end
end)
