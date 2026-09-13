--[[ ================================================================
     privateclub.cc  ·  murder mystery 2
     ----------------------------------------------------------------
     sidebar categories -> sub tabs -> collapsible groups.
     Right Ctrl hides the menu.

     roles: a Knife means murderer. the first player to hold a Gun in
     a round is police; anyone who picks the gun up afterwards is the
     hero. dead players are ghosts.
     ================================================================ ]]

local CFG = {
    Brand   = "privateclub",
    Brand2  = "hub",
    Script  = "Murder Mystery 2",
    Version = "v2.0",
    Toggle  = Enum.KeyCode.RightControl,
    Lobby   = CFrame.new(-108, 138, 50),
}

-- ================================================================
-- services
-- ================================================================
local Players          = game:GetService("Players")
local VirtualInput     = game:GetService("VirtualInputManager")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local VirtualUser      = game:GetService("VirtualUser")

local LP  = Players.LocalPlayer
local CAM = workspace.CurrentCamera

-- ================================================================
-- theme
-- ================================================================
local T = {
    BG0   = Color3.fromHex("0B0B10"),
    BG1   = Color3.fromHex("121218"),
    BG2   = Color3.fromHex("1A1A22"),
    BG3   = Color3.fromHex("232330"),
    LINE  = Color3.fromHex("26262F"),

    TXT   = Color3.fromHex("E8E8EE"),
    DIM   = Color3.fromHex("9A9AA6"),
    FAINT = Color3.fromHex("5E5E6B"),

    RED   = Color3.fromHex("FF2E43"),
    RED2  = Color3.fromHex("B00C24"),
    GOLD  = Color3.fromHex("FFB020"),
    OK    = Color3.fromHex("3ED598"),
    ERR   = Color3.fromHex("FF4D6A"),
}

local PALETTE = {
    "FF2E43", "FF6B2E", "FFD93D", "3ED598",
    "3EA6D5", "9B5CFF", "FF5CC8", "E8E8EE",
}

local RADIUS = 5
local EASE, QUAD, BACK = Enum.EasingStyle.Quint, Enum.EasingStyle.Quad, Enum.EasingStyle.Back

local accented = {}
local function accent(inst, prop)
    table.insert(accented, { inst = inst, prop = prop })
    return inst
end
local function setAccent(c)
    T.RED = c
    for _, e in ipairs(accented) do
        if e.inst and e.inst.Parent then
            TweenService:Create(e.inst, TweenInfo.new(0.25), { [e.prop] = c }):Play()
        end
    end
end

-- ================================================================
-- builders
-- ================================================================
local function new(class, props, kids)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    for _, kid in ipairs(kids or {}) do kid.Parent = inst end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or RADIUS) }) end

local function stroke(c, t)
    return new("UIStroke", {
        Color = c or T.LINE, Transparency = t or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function list(gap, dir)
    return new("UIListLayout", {
        Padding = UDim.new(0, gap or 0),
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

local function tween(o, t, props, style)
    local tw = TweenService:Create(o,
        TweenInfo.new(t, style or QUAD, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function label(p)
    p = p or {}
    p.BackgroundTransparency = p.BackgroundTransparency or 1
    p.Font           = p.Font or Enum.Font.Gotham
    p.TextColor3     = p.TextColor3 or T.DIM
    p.TextSize       = p.TextSize or 13
    p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
    return new("TextLabel", p)
end

-- ================================================================
-- gui root
-- ================================================================
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__pc_mm2 then pcall(function() ENV.__pc_mm2:Destroy() end) end

local gui = new("ScreenGui", {
    Name = "\u{200B}pcm" .. tostring(math.random(100000, 999999)),
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 997,
})
ENV.__pc_mm2 = gui

do
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    local ok = pcall(function()
        gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end

-- ================================================================
-- state
-- ================================================================
local S = {
    autoKillMurd = false, autoShootMurd = false, autoGrabGun = false,
    knifeKillAll = false, knifeReach = false, reachDist = 15,
    autoEquipKnife = false, equipDelay = 1.1,
    hitboxOn = false, hitboxSize = 10,
    silentAim = false, aimTarget = "Murderer", aimFov = 200,
    wallCheck = true, knifeCheck = true,
    showFov = false, fovFilled = false,
    aimSnap = false, shootDelay = 25, logRemotes = false, aimRemote = "",
    autoFlingSheriff = false, touchFling = false, flingSpin = true, antiFling = false,

    autoFarm = false, autoCoins = false, nearOnly = false, coinRadius = 100,
    farmMode = "Walk", farmSpeed = 20, farmStop = 4,
    antiAfk = true,

    autoStrafe = false, strafeMult = 1,
    walkOn = false, walkSpeed = 16, jumpOn = false, jumpPower = 50,
    infJump = false, noclip = false, fly = false, flySpeed = 60,
    animOn = false, hideName = false,

    tracersOn = false, tracerTime = 6, tracerWidth = 2,
    hitmarkOn = false, hitmarkSize = 14, hitmarkTime = 4,

    espOn = true,
    showMurderer = true, showPolice = true, showHero = true,
    showInnocent = true, showGhost = false,
    gunEsp = false, gunNotify = false,
    espRefresh = 60, espNames = true, espDistance = true,
    espBoxes = false, espTracers = false, espHealth = true, espChams = true,
    espTextSize = 13, espChamsFill = 60,
    auraMurd = false, auraPolice = false, auraHero = false, auraInno = false,

    sky = "Default", fullbright = false, noFog = false,
    timeOn = false, timeOfDay = 14,
}

-- role colours, cycled by the swatch buttons
local RC = {
    murderer = Color3.fromHex("FF2E43"),
    police   = Color3.fromHex("3EA6D5"),
    hero     = Color3.fromHex("FFD93D"),
    innocent = Color3.fromHex("3ED598"),
    ghost    = Color3.fromHex("9B5CFF"),
    tracer   = Color3.fromHex("FF2E43"),
    hitmark  = Color3.fromHex("E8E8EE"),
    hitbox   = Color3.fromHex("FF2E43"),
    fov      = Color3.fromHex("E8E8EE"),
}

-- ================================================================
-- toasts
-- ================================================================
local toastHolder = new("Frame", {
    Parent = gui,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -22, 1, -22),
    Size = UDim2.fromOffset(300, 320),
    BackgroundTransparency = 1,
}, {
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

local toastOrd = 0
local function toast(text, colour)
    toastOrd = toastOrd + 1
    local f = new("Frame", {
        Parent = toastHolder,
        LayoutOrder = toastOrd,
        Size = UDim2.fromOffset(0, 36),
        BackgroundColor3 = T.BG1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, { corner(RADIUS), stroke(T.LINE, 0.2) })

    new("Frame", {
        Parent = f,
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = colour or T.RED,
        BorderSizePixel = 0,
    })

    label({
        Parent = f,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -22, 1, 0),
        TextSize = 12.5,
        TextColor3 = T.TXT,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = text,
    })

    tween(f, 0.3, { Size = UDim2.fromOffset(288, 36) }, EASE)
    task.delay(2.8, function()
        tween(f, 0.25, { Size = UDim2.fromOffset(0, 36) })
        task.delay(0.3, function() f:Destroy() end)
    end)
end

-- ================================================================
-- character helpers
-- ================================================================
local function character() return LP.Character end
local function humanoid()
    local c = character()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function root()
    local c = character()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function myTool(name)
    local c = character()
    if c and c:FindFirstChild(name) then return c:FindFirstChild(name) end
    local bp = LP:FindFirstChildOfClass("Backpack")
    return bp and bp:FindFirstChild(name)
end

-- ================================================================
-- roles  (murderer / police / hero / innocent / ghost)
-- ================================================================
local function holds(plr, item)
    local char = plr.Character
    if char and char:FindFirstChild(item) then return true end
    local bp = plr:FindFirstChildOfClass("Backpack")
    return bp ~= nil and bp:FindFirstChild(item) ~= nil
end

local function isDead(plr)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return (not char) or (not hum) or hum.Health <= 0
end

local originalPolice
local murderer, police, hero

local function roleOf(plr)
    if isDead(plr) then return "ghost" end
    if holds(plr, "Knife") then return "murderer" end
    if holds(plr, "Gun") then
        if originalPolice == nil or originalPolice == plr then return "police" end
        return "hero"
    end
    return "innocent"
end

local function roleColour(r) return RC[r] or RC.innocent end

local function scanRoles()
    murderer, police, hero = nil, nil, nil
    local anyKnife = false

    for _, plr in ipairs(Players:GetPlayers()) do
        if not isDead(plr) then
            if holds(plr, "Knife") then
                murderer = plr
                anyKnife = true
            elseif holds(plr, "Gun") then
                if originalPolice == nil then originalPolice = plr end
                if originalPolice == plr then police = plr else hero = plr end
            end
        end
    end

    -- no knife anywhere means the round ended, so forget who was police
    if not anyKnife then originalPolice = nil end
end

-- ================================================================
-- ESP
-- ================================================================
local hasDrawing = pcall(function() return Drawing.new("Square"):Remove() end)

local function drawing(class, props)
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props or {}) do d[k] = v end
    return d
end

local esp = {}

local function buildEsp()
    if not hasDrawing then return nil end
    return {
        box    = drawing("Square", { Thickness = 1, Filled = false, Visible = false }),
        hpBack = drawing("Line", { Thickness = 3, Visible = false, Color = Color3.new(0, 0, 0) }),
        hpBar  = drawing("Line", { Thickness = 1, Visible = false }),
        name   = drawing("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
        info   = drawing("Text", { Size = 11, Center = true, Outline = true, Visible = false }),
        line   = drawing("Line", { Thickness = 1, Visible = false }),
    }
end

local function hideEsp(o)
    if not o then return end
    for _, d in pairs(o) do d.Visible = false end
end

local function chams(plr, colour, show)
    local char = plr.Character
    if not char then return end
    local hl = char:FindFirstChild("pc_cham")
    if not (S.espOn and S.espChams and show) then
        if hl then hl:Destroy() end
        return
    end
    if not hl then
        hl = new("Highlight", {
            Name = "pc_cham", Parent = char,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        })
    end
    hl.FillColor = colour
    hl.OutlineColor = colour
    hl.FillTransparency = S.espChamsFill / 100
end

-- flat glowing disc under the feet
local function aura(plr, r, colour)
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local want = S.espOn and (
        (r == "murderer" and S.auraMurd) or (r == "police" and S.auraPolice)
        or (r == "hero" and S.auraHero) or (r == "innocent" and S.auraInno))

    local ring = char and char:FindFirstChild("pc_aura")
    if not want or not hrp then
        if ring then ring:Destroy() end
        return
    end
    if not ring then
        ring = new("Part", {
            Name = "pc_aura", Parent = char,
            Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
            Material = Enum.Material.Neon, Transparency = 0.45,
            Size = Vector3.new(7, 0.15, 7),
        })
        new("CylinderMesh", { Parent = ring })
    end
    ring.Color = colour
    ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.9, 0))
end

local function clearVisuals(plr)
    local char = plr.Character
    if not char then return end
    for _, n in ipairs({ "pc_cham", "pc_aura" }) do
        local o = char:FindFirstChild(n)
        if o then o:Destroy() end
    end
end

local function killEsp(plr)
    local o = esp[plr]
    if o then
        for _, d in pairs(o) do pcall(function() d:Remove() end) end
        esp[plr] = nil
    end
    clearVisuals(plr)
end

local objEsp = {}
local function objTag(key, colour)
    if not objEsp[key] and hasDrawing then
        objEsp[key] = drawing("Text", { Size = 12, Center = true, Outline = true, Visible = false })
    end
    local d = objEsp[key]
    if d then d.Color = colour end
    return d
end

local function coinContainers()
    local out = {}
    for _, v in ipairs(workspace:GetChildren()) do
        local c = v:FindFirstChild("CoinContainer")
        if c then table.insert(out, c) end
    end
    return out
end

local function gunDrop() return workspace:FindFirstChild("GunDrop") end

local function roleShown(r)
    return (r == "murderer" and S.showMurderer)
        or (r == "police" and S.showPolice)
        or (r == "hero" and S.showHero)
        or (r == "innocent" and S.showInnocent)
        or (r == "ghost" and S.showGhost)
end

local espClock = 0
RunService.RenderStepped:Connect(function(dt)
    espClock = espClock + dt
    if espClock < (1 / math.max(S.espRefresh, 1)) then return end
    espClock = 0

    local myRoot = root()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local o = esp[plr]
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local r = roleOf(plr)
            local colour = roleColour(r)
            local show = S.espOn and roleShown(r)

            chams(plr, colour, show)
            aura(plr, r, colour)

            if not show or not hrp or not hum or hum.Health <= 0 then
                hideEsp(o)
            else
                if not o then o = buildEsp(); esp[plr] = o end
                if o then
                    local dist = myRoot and math.floor((myRoot.Position - hrp.Position).Magnitude) or 0
                    local pos, onScreen = CAM:WorldToViewportPoint(hrp.Position)

                    if onScreen then
                        local topV = CAM:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.2, 0))
                        local botV = CAM:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.4, 0))
                        local h = math.abs(topV.Y - botV.Y)
                        local w = h / 2
                        local x, y = pos.X - w / 2, topV.Y

                        o.box.Visible = S.espBoxes
                        if S.espBoxes then
                            o.box.Color = colour
                            o.box.Size = Vector2.new(w, h)
                            o.box.Position = Vector2.new(x, y)
                        end

                        local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.hpBack.Visible = S.espHealth
                        o.hpBar.Visible = S.espHealth
                        if S.espHealth then
                            local bx = x - 6
                            o.hpBack.From = Vector2.new(bx, y)
                            o.hpBack.To = Vector2.new(bx, y + h)
                            o.hpBar.Color = Color3.fromRGB(
                                math.floor(255 * (1 - frac)), math.floor(200 * frac + 40), 60)
                            o.hpBar.From = Vector2.new(bx, y + h)
                            o.hpBar.To = Vector2.new(bx, y + h - h * frac)
                        end

                        o.name.Visible = S.espNames
                        if S.espNames then
                            o.name.Color = colour
                            o.name.Size = S.espTextSize
                            o.name.Text = plr.DisplayName .. "  [" .. r:upper() .. "]"
                            o.name.Position = Vector2.new(pos.X, y - S.espTextSize - 3)
                        end

                        o.info.Visible = S.espDistance
                        if S.espDistance then
                            o.info.Color = colour
                            o.info.Size = S.espTextSize - 2
                            o.info.Text = dist .. "m"
                            o.info.Position = Vector2.new(pos.X, y + h + 2)
                        end

                        o.line.Visible = S.espTracers
                        if S.espTracers then
                            o.line.Color = colour
                            o.line.From = Vector2.new(CAM.ViewportSize.X / 2, CAM.ViewportSize.Y)
                            o.line.To = Vector2.new(pos.X, y + h)
                        end
                    else
                        hideEsp(o)
                    end
                end
            end
        end
    end

    local gd = gunDrop()
    local gt = objTag("gun", RC.police)
    if gt then
        if S.espOn and S.gunEsp and gd and gd:IsA("BasePart") then
            local pos, on = CAM:WorldToViewportPoint(gd.Position)
            gt.Visible = on
            if on then
                local d = myRoot and math.floor((myRoot.Position - gd.Position).Magnitude) or 0
                gt.Text = "GUN  " .. d .. "m"
                gt.Position = Vector2.new(pos.X, pos.Y)
            end
        else
            gt.Visible = false
        end
    end
end)

Players.PlayerRemoving:Connect(killEsp)

task.spawn(function()
    local had = false
    while gui.Parent do
        task.wait(0.3)
        local gd = gunDrop()
        if gd and not had then
            had = true
            if S.gunNotify then
                local r = root()
                local d = (r and gd:IsA("BasePart"))
                    and math.floor((r.Position - gd.Position).Magnitude) or 0
                toast("Gun dropped  \u{00B7}  " .. d .. "m away", RC.police)
            end
        elseif not gd then
            had = false
        end
    end
end)

-- ================================================================
-- aim FOV ring
-- ================================================================
local fovRing = drawing("Circle", {
    Thickness = 1, NumSides = 64, Filled = false, Visible = false, Transparency = 0.9,
})

RunService.RenderStepped:Connect(function()
    if not fovRing then return end
    if not S.showFov then
        fovRing.Visible = false
        return
    end
    fovRing.Visible = true
    fovRing.Color = RC.fov
    fovRing.Filled = S.fovFilled
    fovRing.Transparency = S.fovFilled and 0.12 or 0.9
    fovRing.Radius = S.aimFov
    fovRing.Position = Vector2.new(CAM.ViewportSize.X / 2, CAM.ViewportSize.Y / 2)
end)

-- ================================================================
-- hitbox expander
-- ================================================================
local hitboxCache = {}
task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if S.hitboxOn and roleOf(LP) == "murderer" then
                        if not hitboxCache[hrp] then hitboxCache[hrp] = hrp.Size end
                        hrp.Size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize)
                        hrp.Transparency = 0.7
                        hrp.Color = RC.hitbox
                        hrp.Material = Enum.Material.ForceField
                        hrp.CanCollide = false
                    elseif hitboxCache[hrp] then
                        hrp.Size = hitboxCache[hrp]
                        hrp.Transparency = 1
                        hitboxCache[hrp] = nil
                    end
                end
            end
        end
    end
end)

-- ================================================================
-- weapon visuals
-- ================================================================
local function spawnTracer(fromPos, toPos)
    if not S.tracersOn then return end
    local dist = (toPos - fromPos).Magnitude
    if dist <= 0 then return end
    local part = new("Part", {
        Parent = workspace,
        Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        Material = Enum.Material.Neon,
        Color = RC.tracer,
        Size = Vector3.new(S.tracerWidth / 10, S.tracerWidth / 10, dist),
        CFrame = CFrame.lookAt(fromPos:Lerp(toPos, 0.5), toPos),
    })
    tween(part, S.tracerTime / 10, { Transparency = 1 })
    task.delay(S.tracerTime / 10 + 0.05, function() part:Destroy() end)
end

local hitmark
local function popHitmarker()
    if not S.hitmarkOn then return end
    if not hitmark then
        hitmark = new("Frame", {
            Parent = gui,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(1, 1),
            BackgroundTransparency = 1,
        })
        for i = 1, 4 do
            local sx = (i == 1 or i == 3) and -1 or 1
            local sy = (i <= 2) and -1 or 1
            new("Frame", {
                Parent = hitmark,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(sx * 9, sy * 9),
                Size = UDim2.fromOffset(2, 10),
                Rotation = (sx == sy) and 45 or -45,
                BackgroundColor3 = RC.hitmark,
                BorderSizePixel = 0,
            })
        end
    end
    for _, arm in ipairs(hitmark:GetChildren()) do
        arm.BackgroundColor3 = RC.hitmark
        arm.BackgroundTransparency = 0
        arm.Size = UDim2.fromOffset(2, S.hitmarkSize * 0.7)
        tween(arm, S.hitmarkTime / 10, { BackgroundTransparency = 1 })
    end
end

-- ================================================================
-- combat
-- ================================================================
local function visible(part)
    if not S.wallCheck then return true end
    local origin = CAM.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character() }
    local res = workspace:Raycast(origin, part.Position - origin, params)
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

local function targetPart(plr)
    local c = plr.Character
    return c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
end

local function screenCentre()
    return Vector2.new(CAM.ViewportSize.X / 2, CAM.ViewportSize.Y / 2)
end

-- returns the part to aim at AND the player it belongs to
local function aimTarget()
    if S.aimTarget == "Murderer" then
        if not murderer or murderer == LP or isDead(murderer) then return nil end
        local p = targetPart(murderer)
        if p and (not S.knifeCheck or holds(murderer, "Knife")) and visible(p) then
            return p, murderer
        end
        return nil
    end

    local best, bestPlr, bestD
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not isDead(plr) then
            local p = targetPart(plr)
            if p then
                local pos, on = CAM:WorldToViewportPoint(p.Position)
                if on then
                    local d = (Vector2.new(pos.X, pos.Y) - screenCentre()).Magnitude
                    if d <= S.aimFov and (not bestD or d < bestD) and visible(p) then
                        best, bestPlr, bestD = p, plr, d
                    end
                end
            end
        end
    end
    return best, bestPlr
end

-- a remote counts as the gun's if it sits inside the tool, matches the
-- name filter, or simply looks like a shoot remote. the old version only
-- accepted remotes parented under the tool, which is why nothing fired
-- when the game keeps them in ReplicatedStorage.
local function isGunRemote(self)
    if not holds(LP, "Gun") then return false end

    local filter = tostring(S.aimRemote or "")
    if filter ~= "" then
        return tostring(self.Name):lower():find(filter:lower(), 1, true) ~= nil
    end

    local gun = myTool("Gun")
    if gun and self:IsDescendantOf(gun) then return true end

    local n = tostring(self.Name):lower()
    for _, word in ipairs({ "shoot", "fire", "gun", "bullet", "hit", "damage", "kill" }) do
        if n:find(word, 1, true) then return true end
    end
    return false
end

local function retarget(args, part, plr)
    local changed = false
    for i, v in ipairs(args) do
        local t = typeof(v)
        if t == "Vector3" then
            args[i] = part.Position; changed = true
        elseif t == "CFrame" then
            args[i] = CFrame.new(part.Position); changed = true
        elseif t == "Instance" then
            if v:IsA("BasePart") then
                args[i] = part; changed = true
            elseif v:IsA("Player") and plr then
                args[i] = plr; changed = true
            elseif v:IsA("Humanoid") and plr and plr.Character then
                local h = plr.Character:FindFirstChildOfClass("Humanoid")
                if h then args[i] = h; changed = true end
            elseif v:IsA("Model") and v:FindFirstChildOfClass("Humanoid")
                   and plr and plr.Character then
                args[i] = plr.Character; changed = true
            end
        end
    end
    return changed
end

local logged = 0
do
    local hook = rawget(getfenv(), "hookmetamethod")
    local getMethod = rawget(getfenv(), "getnamecallmethod")
    if type(hook) == "function" and type(getMethod) == "function" then
        local old
        old = hook(game, "__namecall", function(self, ...)
            local method = getMethod()
            if (method == "FireServer" or method == "InvokeServer")
               and typeof(self) == "Instance" and isGunRemote(self) then

                if S.logRemotes then
                    local kinds = {}
                    for i, v in ipairs({ ... }) do kinds[i] = typeof(v) end
                    local line = self:GetFullName() .. "  (" .. table.concat(kinds, ", ") .. ")"
                    print("[privateclub] gun remote: " .. line)
                    logged = logged + 1
                    if logged <= 4 then toast("Remote: " .. self.Name, T.GOLD) end
                end

                local target, plr = nil, nil
                if S.silentAim or S.tracersOn then target, plr = aimTarget() end
                local r = root()

                if target and r then
                    if S.tracersOn then spawnTracer(r.Position, target.Position) end
                    if S.hitmarkOn then popHitmarker() end
                end

                if S.silentAim and target then
                    local args = { ... }
                    if retarget(args, target, plr) then
                        return old(self, unpack(args))
                    end
                end
            end
            return old(self, ...)
        end)
    end
end

local function equip(tool)
    if not tool then return nil end
    if tool.Parent ~= character() then
        local h = humanoid()
        if h then pcall(function() h:EquipTool(tool) end) end
    end
    return tool
end

-- fire the gun the way a real click does, so it works whether the game
-- listens to Tool.Activated or to the mouse
local function shootAt(screenPos, tool)
    if tool then pcall(function() tool:Activate() end) end
    pcall(function()
        VirtualInput:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
    end)
end

task.spawn(function()
    while gui.Parent do
        task.wait(math.max(S.shootDelay, 5) / 100)
        if S.autoShootMurd and holds(LP, "Gun") and murderer and not isDead(murderer) then
            local gun = equip(myTool("Gun"))
            local p = targetPart(murderer)
            if gun and p and visible(p) then
                local pos, on = CAM:WorldToViewportPoint(p.Position)
                if on then
                    local within = (Vector2.new(pos.X, pos.Y) - screenCentre()).Magnitude <= S.aimFov
                    if within or S.silentAim then
                        if S.aimSnap then
                            CAM.CFrame = CFrame.lookAt(CAM.CFrame.Position, p.Position)
                        end
                        shootAt(Vector2.new(pos.X, pos.Y), gun)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(math.max(S.equipDelay, 0.1) / 10)
        if roleOf(LP) == "murderer" then
            local knife = myTool("Knife")
            if S.autoEquipKnife then equip(knife) end

            if (S.knifeKillAll or S.knifeReach) and knife then
                equip(knife)
                local r = root()
                if r then
                    local reach = S.knifeReach and S.reachDist or 8
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LP and not isDead(plr) then
                            local hrp = plr.Character
                                and plr.Character:FindFirstChild("HumanoidRootPart")
                            if hrp and (hrp.Position - r.Position).Magnitude <= reach then
                                pcall(function() knife:Activate() end)
                                if not S.knifeKillAll then break end
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        if S.autoKillMurd and holds(LP, "Gun") and murderer and not isDead(murderer) then
            local gun = equip(myTool("Gun"))
            local p = targetPart(murderer)
            if gun and p then
                local pos, on = CAM:WorldToViewportPoint(p.Position)
                if S.aimSnap then
                    CAM.CFrame = CFrame.lookAt(CAM.CFrame.Position, p.Position)
                end
                shootAt(on and Vector2.new(pos.X, pos.Y) or screenCentre(), gun)
            end
        end
    end
end)

-- ================================================================
-- fling
-- ================================================================
local flinging = false
local function fling(target)
    if flinging then return end
    local r = root()
    local tc = target and target.Character
    local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
    if not r or not thrp then
        toast("No target to fling", T.ERR)
        return
    end

    flinging = true
    local home = r.CFrame
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not flinging then conn:Disconnect(); return end
        pcall(function()
            r.CFrame = thrp.CFrame
            if S.flingSpin then
                r.AssemblyAngularVelocity = Vector3.new(0, 90000, 0)
            end
            r.AssemblyLinearVelocity = Vector3.new(90000, 90000, 90000)
        end)
    end)

    task.delay(1.0, function()
        flinging = false
        task.wait(0.15)
        pcall(function()
            r.AssemblyAngularVelocity = Vector3.zero
            r.AssemblyLinearVelocity = Vector3.zero
            r.CFrame = home
        end)
    end)
end

task.spawn(function()
    while gui.Parent do
        task.wait(1.3)
        if flinging then
            task.wait(0.1)
        elseif S.autoFlingSheriff and police and police ~= LP then
            toast("Auto fling: " .. police.DisplayName, T.RED)
            fling(police)
        elseif S.touchFling then
            local r = root()
            if r then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LP and not isDead(plr) then
                        local hrp = plr.Character
                            and plr.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - r.Position).Magnitude <= 12 then
                            fling(plr)
                            break
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(0.5)
        if S.antiFling then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character then
                    for _, p in ipairs(plr.Character:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.CanCollide = false
                            p.Massless = true
                        end
                    end
                end
            end
        end
    end
end)

-- ================================================================
-- farm
-- ================================================================
local function pullGun()
    local gd, r = gunDrop(), root()
    if gd and r and gd:IsA("BasePart") then
        gd.CFrame = r.CFrame
        return true
    end
    return false
end

local function sweepCoins(limit)
    local r = root()
    if not r then return 0 end
    local n = 0
    for _, container in ipairs(coinContainers()) do
        for _, coin in ipairs(container:GetChildren()) do
            if coin:IsA("BasePart") then
                if not limit or (coin.Position - r.Position).Magnitude <= S.coinRadius then
                    coin.CFrame = r.CFrame
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function nearestCoin()
    local r = root()
    if not r then return nil end
    local best, bestD
    for _, container in ipairs(coinContainers()) do
        for _, coin in ipairs(container:GetChildren()) do
            if coin:IsA("BasePart") then
                local d = (coin.Position - r.Position).Magnitude
                if not bestD or d < bestD then best, bestD = coin, d end
            end
        end
    end
    return best, bestD
end

task.spawn(function()
    while gui.Parent do
        task.wait(0.1)
        if S.autoGrabGun or S.autoFarm then pullGun() end
        -- the instant grabber is its own toggle now; auto farm walks instead
        if S.autoCoins then sweepCoins(S.nearOnly) end
    end
end)

-- auto farm: actually walk over to the nearest coin and pick it up
local farmSpeedCache
task.spawn(function()
    while gui.Parent do
        task.wait(0.12)
        if not S.autoFarm then
            if farmSpeedCache then
                local h = humanoid()
                if h and not S.walkOn then h.WalkSpeed = farmSpeedCache end
                farmSpeedCache = nil
            end
        else
            local hum, r = humanoid(), root()
            local coin, dist = nearestCoin()

            if hum and r and coin then
                if not farmSpeedCache then farmSpeedCache = hum.WalkSpeed end
                if not S.walkOn then hum.WalkSpeed = S.farmSpeed end

                if S.farmMode == "Glide" then
                    -- ease the root toward the coin so it reads as movement,
                    -- not a teleport
                    local goal = coin.Position + Vector3.new(0, 2, 0)
                    local step = math.min(S.farmSpeed * 0.12, dist)
                    if dist > S.farmStop then
                        local dir = (goal - r.Position).Unit
                        r.CFrame = CFrame.lookAt(r.Position + dir * step, goal)
                    end
                else
                    if dist > S.farmStop then
                        hum:MoveTo(coin.Position)
                    end
                end
            end
        end
    end
end)

-- ================================================================
-- movement, world, animation
-- ================================================================
local flyBV, flyBG
local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end
local function startFly()
    local r = root()
    if not r then return end
    stopFly()
    flyBV = new("BodyVelocity", {
        Parent = r, MaxForce = Vector3.new(1e5, 1e5, 1e5), Velocity = Vector3.zero })
    flyBG = new("BodyGyro", {
        Parent = r, MaxTorque = Vector3.new(1e5, 1e5, 1e5), P = 1e4, CFrame = r.CFrame })
end

local strafePhase = 0
RunService.RenderStepped:Connect(function(dt)
    if S.fly then
        local r = root()
        if r and flyBV then
            local dir = Vector3.zero
            local look, right = CAM.CFrame.LookVector, CAM.CFrame.RightVector
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end
            if dir.Magnitude > 0 then dir = dir.Unit * S.flySpeed end
            flyBV.Velocity = dir
            flyBG.CFrame = CAM.CFrame
        end
    end

    if S.autoStrafe and not S.fly then
        local hum, r = humanoid(), root()
        if hum and r and hum.MoveDirection.Magnitude > 0 then
            strafePhase = strafePhase + dt * 7

            local forward = hum.MoveDirection * hum.WalkSpeed
            local side = CAM.CFrame.RightVector
                * math.sin(strafePhase) * (S.strafeMult * 7)
            local want = forward + Vector3.new(side.X, 0, side.Z)

            -- never let it exceed a sane multiple of walk speed
            local cap = hum.WalkSpeed * (1 + S.strafeMult * 0.6)
            if want.Magnitude > cap then want = want.Unit * cap end

            r.AssemblyLinearVelocity = Vector3.new(
                want.X, r.AssemblyLinearVelocity.Y, want.Z)
        end
    end
end)

local defaults = {
    brightness = Lighting.Brightness, ambient = Lighting.Ambient,
    outdoor = Lighting.OutdoorAmbient, fogEnd = Lighting.FogEnd,
    fogColour = Lighting.FogColor, clock = Lighting.ClockTime,
}
local originalSky = Lighting:FindFirstChildOfClass("Sky")

local function applySky(preset)
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Sky") and v.Name == "pc_sky" then v:Destroy() end
    end
    if originalSky then originalSky.Parent = Lighting end

    Lighting.Brightness = defaults.brightness
    Lighting.Ambient = defaults.ambient
    Lighting.OutdoorAmbient = defaults.outdoor
    Lighting.FogEnd = defaults.fogEnd
    Lighting.FogColor = defaults.fogColour
    Lighting.ClockTime = defaults.clock

    if preset == "Midnight" then
        Lighting.ClockTime = 0
        Lighting.Ambient = Color3.fromRGB(18, 20, 34)
        Lighting.OutdoorAmbient = Color3.fromRGB(24, 26, 44)
    elseif preset == "Sunset" then
        Lighting.ClockTime = 17.6
        Lighting.Ambient = Color3.fromRGB(90, 52, 40)
        Lighting.OutdoorAmbient = Color3.fromRGB(120, 70, 50)
    elseif preset == "Overcast" then
        Lighting.ClockTime = 12
        Lighting.Ambient = Color3.fromRGB(105, 108, 115)
        Lighting.FogEnd = 620
    elseif preset == "Crimson" then
        Lighting.ClockTime = 0
        Lighting.Ambient = Color3.fromRGB(60, 10, 16)
        Lighting.OutdoorAmbient = Color3.fromRGB(80, 14, 22)
    elseif preset == "Void" then
        if originalSky then originalSky.Parent = nil end
        Lighting.ClockTime = 0
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
        Lighting.FogEnd = 260
        Lighting.FogColor = Color3.fromRGB(0, 0, 0)
    end
end

local function customSky(id)
    id = tostring(id):gsub("%D", "")
    if id == "" then toast("Enter a numeric asset id", T.ERR); return end
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Sky") and v.Name == "pc_sky" then v:Destroy() end
    end
    if originalSky then originalSky.Parent = nil end
    local tex = "rbxassetid://" .. id
    new("Sky", {
        Name = "pc_sky", Parent = Lighting,
        SkyboxBk = tex, SkyboxDn = tex, SkyboxFt = tex,
        SkyboxLf = tex, SkyboxRt = tex, SkyboxUp = tex,
    })
    toast("Skybox set to " .. id, T.OK)
end

local animTrack
local function playAnim(id)
    if animTrack then pcall(function() animTrack:Stop() end); animTrack = nil end
    id = tostring(id):gsub("%D", "")
    if id == "" or not S.animOn then return end
    local hum = humanoid()
    if not hum then return end
    local ok = pcall(function()
        local anim = new("Animation", { AnimationId = "rbxassetid://" .. id })
        local animator = hum:FindFirstChildOfClass("Animator") or hum
        animTrack = animator:LoadAnimation(anim)
        animTrack.Looped = true
        animTrack:Play()
    end)
    toast(ok and "Animation playing" or "Could not load that animation", ok and T.OK or T.ERR)
end

RunService.Heartbeat:Connect(function()
    local h = humanoid()
    if h then
        if S.walkOn then h.WalkSpeed = S.walkSpeed end
        if S.jumpOn then h.UseJumpPower = true; h.JumpPower = S.jumpPower end
        h.DisplayDistanceType = S.hideName
            and Enum.HumanoidDisplayDistanceType.None
            or Enum.HumanoidDisplayDistanceType.Viewer
    end

    if S.noclip then
        local c = character()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end

    if S.antiFling and not flinging then
        local r = root()
        if r then
            if r.AssemblyAngularVelocity.Magnitude > 60 then
                r.AssemblyAngularVelocity = Vector3.zero
            end
            if r.AssemblyLinearVelocity.Magnitude > 350 then
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end

    if S.fullbright then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    end
    if S.noFog then Lighting.FogEnd = 1e6 end
    if S.timeOn then Lighting.ClockTime = S.timeOfDay end
end)

UserInputService.JumpRequest:Connect(function()
    if not S.infJump then return end
    local h = humanoid()
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

LP.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ================================================================
-- window chrome
-- ================================================================
local W, H = 1060, 640
local SIDE = 210

local win = new("Frame", {
    Parent = gui,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H),
    BackgroundColor3 = T.BG0,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, { corner(8), stroke(T.LINE, 0.15) })

local titleBar = new("Frame", {
    Parent = win,
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
})

local mark = accent(new("Frame", {
    Parent = titleBar,
    Position = UDim2.fromOffset(16, 13),
    Size = UDim2.fromOffset(20, 18),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
}, { corner(4) }), "BackgroundColor3")

label({
    Parent = mark,
    Size = UDim2.fromScale(1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = T.BG0,
    TextXAlignment = Enum.TextXAlignment.Center,
    Text = "PC",
})

label({
    Parent = titleBar,
    Position = UDim2.fromOffset(46, 0),
    Size = UDim2.fromOffset(500, 44),
    TextSize = 13.5,
    TextColor3 = T.TXT,
    Text = CFG.Brand .. CFG.Brand2 .. "  |  " .. CFG.Script,
})

local closeBtn = new("TextButton", {
    Parent = titleBar,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.5, 0),
    Size = UDim2.fromOffset(24, 24),
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    TextColor3 = T.DIM,
    Text = "\u{00D7}",
})
closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.12, { TextColor3 = T.ERR }) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.12, { TextColor3 = T.DIM }) end)
closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)

do
    local dragging, startPos, origin
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, origin = true, i.Position, win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startPos
            win.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X,
                                     origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local sidebar = new("Frame", {
    Parent = win,
    Position = UDim2.fromOffset(0, 44),
    Size = UDim2.fromOffset(SIDE, H - 44),
    BackgroundTransparency = 1,
})

new("Frame", {
    Parent = sidebar,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = T.LINE,
    BorderSizePixel = 0,
})

local navHolder = new("Frame", {
    Parent = sidebar,
    Position = UDim2.fromOffset(0, 8),
    Size = UDim2.new(1, 0, 1, -80),
    BackgroundTransparency = 1,
}, { list(2) })

label({
    Parent = sidebar,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 22, 1, -32),
    Size = UDim2.fromOffset(SIDE - 30, 18),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = T.TXT,
    RichText = true,
    Text = CFG.Brand .. '<font color="#FF2E43">' .. CFG.Brand2 .. "</font>",
})

label({
    Parent = sidebar,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 22, 1, -14),
    Size = UDim2.fromOffset(SIDE - 30, 16),
    TextSize = 11.5,
    TextColor3 = T.FAINT,
    Text = CFG.Script,
})

local content = new("Frame", {
    Parent = win,
    Position = UDim2.fromOffset(SIDE + 1, 44),
    Size = UDim2.new(1, -SIDE - 1, 1, -44),
    BackgroundTransparency = 1,
})

local searchBar = new("Frame", {
    Parent = content,
    Position = UDim2.fromOffset(24, 12),
    Size = UDim2.new(1, -48, 0, 40),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
}, { corner(RADIUS), stroke(T.LINE, 0.3) })

label({
    Parent = searchBar,
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.fromOffset(22, 40),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Center,
    Text = "\u{2315}",
})

local searchBox = new("TextBox", {
    Parent = searchBar,
    Position = UDim2.fromOffset(44, 0),
    Size = UDim2.new(1, -56, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = T.TXT,
    PlaceholderText = "Search..",
    PlaceholderColor3 = T.FAINT,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
})

local subTabBar = new("Frame", {
    Parent = content,
    Position = UDim2.fromOffset(24, 62),
    Size = UDim2.new(1, -48, 0, 36),
    BackgroundTransparency = 1,
})

local pageArea = new("Frame", {
    Parent = content,
    Position = UDim2.fromOffset(24, 104),
    Size = UDim2.new(1, -48, 1, -120),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
})

-- ================================================================
-- widget framework
-- ================================================================
local CATS, SUBS, ROWS = {}, {}, {}
local currentCat
local COLW = math.floor((W - SIDE - 1 - 48 - 16) / 2)

local function makeSub(catName, subName)
    local page = new("Frame", {
        Parent = pageArea,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    })
    local cols = {}
    for i = 1, 2 do
        cols[i] = new("ScrollingFrame", {
            Parent = page,
            Position = UDim2.fromOffset((i - 1) * (COLW + 16), 0),
            Size = UDim2.new(0, COLW, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = T.LINE,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, { list(14) })
    end
    SUBS[catName .. "/" .. subName] = page
    return cols[1], cols[2]
end

local groupOrd = 0

local function Group(col, title)
    groupOrd = groupOrd + 1
    local frame = new("Frame", {
        Parent = col,
        LayoutOrder = groupOrd,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.BG1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, { corner(RADIUS), stroke(T.LINE, 0.35), list(0) })

    local headRow = new("Frame", {
        Parent = frame,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
    })

    accent(new("Frame", {
        Parent = headRow,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, -1),
        Size = UDim2.fromOffset(5, 5),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }, { corner(999) }), "BackgroundColor3")

    label({
        Parent = headRow,
        Position = UDim2.fromOffset(29, 0),
        Size = UDim2.new(1, -63, 1, 0),
        TextSize = 13.5,
        TextColor3 = T.TXT,
        Text = title,
    })

    local chev = accent(label({
        Parent = headRow,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T.RED,
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = "\u{25BC}",
    }), "TextColor3")

    accent(new("Frame", {
        Parent = headRow,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -1),
        Size = UDim2.new(1, -32, 0, 1),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.55,
    }), "BackgroundColor3")

    local bodyF = new("Frame", {
        Parent = frame,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, {
        list(5),
        new("UIPadding", {
            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
        }),
    })

    local open = true
    local hit = new("TextButton", {
        Parent = headRow,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    })
    hit.MouseButton1Click:Connect(function()
        open = not open
        bodyF.Visible = open
        tween(chev, 0.2, { Rotation = open and 0 or -90 })
    end)

    return { frame = frame, body = bodyF, rows = {} }
end

local function Row(g, height, text)
    local r = new("Frame", {
        Parent = g.body,
        LayoutOrder = #g.rows + 1,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
    })
    table.insert(g.rows, r)
    table.insert(ROWS, { row = r, group = g, text = (text or ""):lower() })
    return r
end

local function rowLabel(r, text, desc)
    label({
        Parent = r,
        Position = UDim2.fromOffset(0, desc and 4 or 0),
        Size = UDim2.new(1, -110, 0, desc and 18 or r.Size.Y.Offset),
        TextSize = 13,
        TextColor3 = T.DIM,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = text,
    })
    if desc then
        label({
            Parent = r,
            Position = UDim2.fromOffset(0, 22),
            Size = UDim2.new(1, -110, 0, 28),
            TextSize = 11,
            TextColor3 = T.FAINT,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = desc,
        })
    end
end

local function Toggle(g, text, key, opt)
    opt = opt or {}
    local r = Row(g, opt.desc and 54 or 34, text .. " " .. (opt.desc or ""))
    rowLabel(r, text, opt.desc)

    if opt.colour then
        local sw = new("TextButton", {
            Parent = r,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -52, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            BackgroundColor3 = RC[opt.colour] or T.RED,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
        }, { corner(4), stroke(T.LINE, 0.4) })

        local idx = 1
        sw.MouseButton1Click:Connect(function()
            idx = idx % #PALETTE + 1
            RC[opt.colour] = Color3.fromHex(PALETTE[idx])
            sw.BackgroundColor3 = RC[opt.colour]
        end)
    end

    local track = new("Frame", {
        Parent = r,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = T.BG3,
        BorderSizePixel = 0,
    }, { corner(999) })

    local knob = new("Frame", {
        Parent = track,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = T.DIM,
        BorderSizePixel = 0,
    }, { corner(999) })

    local function render(on, fire)
        S[key] = on
        tween(track, 0.18, { BackgroundColor3 = on and T.RED or T.BG3 })
        tween(knob, 0.18, {
            Position = UDim2.new(0, on and 23 or 3, 0.5, 0),
            BackgroundColor3 = on and Color3.new(1, 1, 1) or T.DIM,
        }, BACK)
        if fire and opt.callback then opt.callback(on) end
    end

    local hit = new("TextButton", {
        Parent = r, Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
    })
    hit.MouseButton1Click:Connect(function() render(not S[key], true) end)

    render(S[key], false)
end

local function Slider(g, text, key, min, max, suffix, callback)
    local r = Row(g, 40, text)

    local bar = new("Frame", {
        Parent = r,
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, -76, 0, 30),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, { corner(4) })

    local fill = accent(new("Frame", {
        Parent = bar,
        Size = UDim2.fromScale((S[key] - min) / (max - min), 1),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.15,
    }, { corner(4) }), "BackgroundColor3")

    local barTxt = label({
        Parent = bar,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -18, 1, 0),
        TextSize = 12.5,
        TextColor3 = T.TXT,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = text .. ": " .. tostring(S[key]) .. (suffix and (" " .. suffix) or ""),
        ZIndex = 2,
    })

    local box = new("Frame", {
        Parent = r,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 4),
        Size = UDim2.fromOffset(70, 30),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
    }, { corner(4) })

    local boxTxt = label({
        Parent = box,
        Size = UDim2.fromScale(1, 1),
        TextSize = 12,
        TextColor3 = T.DIM,
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = tostring(S[key]) .. (suffix and (" " .. suffix) or ""),
    })

    local function apply(alpha, fire)
        alpha = math.clamp(alpha, 0, 1)
        local raw = min + (max - min) * alpha
        local v = ((max - min) <= 20) and (math.floor(raw * 10 + 0.5) / 10)
                                      or math.floor(raw + 0.5)
        S[key] = v
        fill.Size = UDim2.fromScale(alpha, 1)
        local shown = tostring(v) .. (suffix and (" " .. suffix) or "")
        barTxt.Text = text .. ": " .. shown
        boxTxt.Text = shown
        if fire and callback then callback(v) end
    end

    local sliding = false
    local function fromInput(px)
        apply((px - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), true)
    end

    local hit = new("TextButton", {
        Parent = bar, Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 3,
    })
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            sliding = true; fromInput(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement
                     or i.UserInputType == Enum.UserInputType.Touch) then
            fromInput(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end)
end

local function Button(g, text, cb)
    local r = Row(g, 36, text)
    local b = new("TextButton", {
        Parent = r,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = T.TXT,
        Text = text,
    }, { corner(4) })
    b.MouseEnter:Connect(function() tween(b, 0.13, { BackgroundColor3 = T.BG3 }) end)
    b.MouseLeave:Connect(function() tween(b, 0.13, { BackgroundColor3 = T.BG2 }) end)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

local function Dropdown(g, text, key, options, cb)
    local r = Row(g, 62, text)
    rowLabel(r, text)

    local head = new("TextButton", {
        Parent = r,
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        TextSize = 12.5,
        TextColor3 = T.DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "   " .. tostring(S[key]),
        ZIndex = 2,
    }, { corner(4) })

    local chev = label({
        Parent = head,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        TextSize = 11,
        TextColor3 = T.FAINT,
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = "\u{25B6}",
        ZIndex = 3,
    })

    local menu = new("Frame", {
        Parent = r,
        Position = UDim2.fromOffset(0, 56),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = T.BG3,
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 20,
    }, { corner(4), list(0),
         new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })

    -- an open menu expands its own row, so the rows underneath move
    -- down instead of the menu floating behind them
    local menuH = #options * 26 + 8
    local open = false
    local function setOpen(v)
        open = v
        if v then menu.Visible = true end
        r.ZIndex = v and 50 or 1
        tween(r, 0.18, { Size = UDim2.new(1, 0, 0, v and (62 + menuH + 6) or 62) }, EASE)
        tween(menu, 0.18, { Size = UDim2.new(1, 0, 0, v and menuH or 0) }, EASE)
        tween(chev, 0.18, { Rotation = v and 90 or 0 })
        if not v then
            task.delay(0.2, function() if not open then menu.Visible = false end end)
        end
    end

    for i, opt in ipairs(options) do
        local b = new("TextButton", {
            Parent = menu,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 12.5,
            TextColor3 = T.DIM,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "   " .. tostring(opt),
            ZIndex = 21,
        })
        b.MouseEnter:Connect(function() tween(b, 0.1, { TextColor3 = T.TXT }) end)
        b.MouseLeave:Connect(function() tween(b, 0.1, { TextColor3 = T.DIM }) end)
        b.MouseButton1Click:Connect(function()
            S[key] = opt
            head.Text = "   " .. tostring(opt)
            setOpen(false)
            if cb then cb(opt) end
        end)
    end

    head.MouseButton1Click:Connect(function() setOpen(not open) end)
end

local function TextField(g, placeholder, cb)
    local r = Row(g, 40, placeholder)
    local f = new("Frame", {
        Parent = r,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
    }, { corner(4) })
    local box = new("TextBox", {
        Parent = f,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 12.5,
        TextColor3 = T.TXT,
        PlaceholderText = placeholder,
        PlaceholderColor3 = T.FAINT,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    })
    box.FocusLost:Connect(function(enter) if enter and cb then cb(box.Text) end end)
    return box
end

-- ---------------- category + sub tab wiring ----------------
local subButtons = {}

local function showSub(cat, sub)
    for key, page in pairs(SUBS) do
        page.Visible = (key == cat .. "/" .. sub)
    end
end

local function buildSubTabs(cat)
    for _, b in ipairs(subButtons) do b:Destroy() end
    subButtons = {}

    local x = 0
    for idx, sub in ipairs(CATS[cat].subs) do
        local w = 24 + #sub * 8
        local b = new("TextButton", {
            Parent = subTabBar,
            Position = UDim2.fromOffset(x, 0),
            Size = UDim2.fromOffset(w, 34),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = idx == 1 and T.TXT or T.FAINT,
            Text = sub,
        })
        local bar = accent(new("Frame", {
            Parent = b,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.fromOffset(idx == 1 and (w - 20) or 0, 2),
            BackgroundColor3 = T.RED,
            BorderSizePixel = 0,
        }), "BackgroundColor3")

        b.MouseButton1Click:Connect(function()
            showSub(cat, sub)
            for _, other in ipairs(subButtons) do
                tween(other, 0.15, { TextColor3 = T.FAINT })
                local ob = other:FindFirstChildOfClass("Frame")
                if ob then tween(ob, 0.18, { Size = UDim2.fromOffset(0, 2) }) end
            end
            tween(b, 0.15, { TextColor3 = T.TXT })
            tween(bar, 0.18, { Size = UDim2.fromOffset(w - 20, 2) }, EASE)
        end)

        table.insert(subButtons, b)
        x = x + w + 6
    end

    showSub(cat, CATS[cat].subs[1])
end

local navButtons = {}
local navOrd = 0

local function selectCat(cat)
    if currentCat == cat then return end
    currentCat = cat
    for name, nb in pairs(navButtons) do
        local on = (name == cat)
        tween(nb.btn, 0.15, { TextColor3 = on and T.TXT or T.FAINT,
                              BackgroundTransparency = on and 0 or 1 })
        tween(nb.bar, 0.18, { Size = UDim2.fromOffset(3, on and 20 or 0) })
    end
    buildSubTabs(cat)
end

local function addCat(name, subs)
    navOrd = navOrd + 1
    CATS[name] = { subs = subs }

    local b = new("TextButton", {
        Parent = navHolder,
        LayoutOrder = navOrd,
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = T.BG1,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        TextSize = 13.5,
        TextColor3 = T.FAINT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = name,
    }, { new("UIPadding", { PaddingLeft = UDim.new(0, 26) }) })

    local bar = accent(new("Frame", {
        Parent = b,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, -26, 0.5, 0),
        Size = UDim2.fromOffset(3, 0),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }), "BackgroundColor3")

    navButtons[name] = { btn = b, bar = bar }
    b.MouseButton1Click:Connect(function() selectCat(name) end)
    b.MouseEnter:Connect(function()
        if currentCat ~= name then tween(b, 0.12, { TextColor3 = T.DIM }) end
    end)
    b.MouseLeave:Connect(function()
        if currentCat ~= name then tween(b, 0.12, { TextColor3 = T.FAINT }) end
    end)
end

addCat("Autofarm", { "Combat", "Farm", "Extras" })
addCat("Character", { "Main", "Visuals" })
addCat("Visuals",   { "Weapons", "Hit Effects", "ESP" })
addCat("World",     { "Environment" })
addCat("Players",   { "List" })
addCat("Chat",      { "Logs" })
addCat("Misc",      { "Server" })
addCat("Settings",  { "Menu" })

-- ================================================================
-- AUTOFARM
-- ================================================================
local L, R = makeSub("Autofarm", "Combat")

local g = Group(L, "sheriff")
Toggle(g, "Auto Kill Murderer", "autoKillMurd")
Toggle(g, "Auto Shoot Murderer", "autoShootMurd", {
    desc = "Shoots the murderer when they are inside FOV (and wall/knife checks pass)" })
Toggle(g, "Snap Camera To Target", "aimSnap", {
    desc = "Points the camera at the murderer before firing" })
Slider(g, "Shoot Delay", "shootDelay", 5, 200, "cs")
Toggle(g, "Auto Grab Drop Gun", "autoGrabGun")

g = Group(L, "murderer")
Toggle(g, "Knife Kill All", "knifeKillAll")
Toggle(g, "Knife Reach", "knifeReach")
Slider(g, "Reach Distance", "reachDist", 5, 60, "studs")
Toggle(g, "Auto Equip Knife", "autoEquipKnife")
Slider(g, "Equip Knife Delay", "equipDelay", 0.1, 5)
Toggle(g, "Hitbox Expander", "hitboxOn", { colour = "hitbox" })
Slider(g, "Hitbox Size", "hitboxSize", 3, 40, "studs")

g = Group(R, "silent aim")
Toggle(g, "Enabled", "silentAim")
Dropdown(g, "Target", "aimTarget", { "Murderer", "Closest" })
Slider(g, "Aim FOV", "aimFov", 40, 800, "px")
Toggle(g, "Show FOV", "showFov", { colour = "fov",
    desc = "Draws the aim circle at your crosshair" })
Toggle(g, "Filled FOV", "fovFilled")
Toggle(g, "Wall Check", "wallCheck")
Toggle(g, "Knife Check", "knifeCheck")
Toggle(g, "Log Gun Remotes", "logRemotes", {
    desc = "Prints every remote the gun fires to the console, so you can find its name" })
local remoteBox = TextField(g, "remote name filter (blank = auto)")
remoteBox.FocusLost:Connect(function()
    S.aimRemote = remoteBox.Text or ""
    toast(S.aimRemote == "" and "Remote filter cleared"
        or ("Remote filter: " .. S.aimRemote), T.OK)
end)

g = Group(R, "fling")
Toggle(g, "Auto Fling Sheriff", "autoFlingSheriff")
Toggle(g, "Touch Fling", "touchFling", { desc = "Get near someone and they get flung" })
Toggle(g, "Fling Spin", "flingSpin", { desc = "Spin while flinging for stronger hits" })
Toggle(g, "Anti Fling", "antiFling")
Button(g, "Fling Murderer", function()
    if murderer then fling(murderer) else toast("No murderer found", T.ERR) end
end)
Button(g, "Fling Sheriff", function()
    if police then fling(police) else toast("No sheriff found", T.ERR) end
end)

g = Group(R, "player")
local flingPick = TextField(g, "player name")
Button(g, "Fling Selected Player", function()
    local q = (flingPick.Text or ""):lower()
    if q == "" then toast("Type a player name first", T.ERR); return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and (plr.Name:lower():find(q, 1, true)
                       or plr.DisplayName:lower():find(q, 1, true)) then
            fling(plr)
            return
        end
    end
    toast("No player matched " .. q, T.ERR)
end)

-- ---------------- Farm ----------------
L, R = makeSub("Autofarm", "Farm")

g = Group(L, "coins")
Toggle(g, "Auto Collect Coins", "autoCoins")
Toggle(g, "Only Nearby", "nearOnly")
Slider(g, "Collect Radius", "coinRadius", 20, 500, "studs")
Button(g, "Sweep Coins Once", function()
    local n = sweepCoins(false)
    toast(n > 0 and (n .. " coins pulled") or "No coins found", n > 0 and T.GOLD or T.ERR)
end)

g = Group(R, "auto farm")
Toggle(g, "Full Auto Farm", "autoFarm", {
    desc = "Walks you to the nearest coin, then the next one",
    callback = function(on)
        toast(on and "Auto farm running" or "Auto farm stopped", on and T.OK or T.DIM)
    end })
Dropdown(g, "Movement", "farmMode", { "Walk", "Glide" })
Slider(g, "Farm Speed", "farmSpeed", 8, 120)
Slider(g, "Stop Distance", "farmStop", 2, 20, "studs")
Button(g, "Grab Gun Once", function()
    local got = pullGun()
    toast(got and "Gun pulled" or "No gun drop right now", got and T.OK or T.ERR)
end)

-- ---------------- Extras ----------------
L, R = makeSub("Autofarm", "Extras")

g = Group(L, "session")
Toggle(g, "Anti AFK", "antiAfk")
Button(g, "Teleport To Lobby", function()
    local r = root()
    if r then r.CFrame = CFG.Lobby; toast("Teleported to lobby", T.OK) end
end)
Button(g, "Respawn", function()
    local h = humanoid()
    if h then h.Health = 0 end
end)

g = Group(R, "round")
Button(g, "Go To Sheriff", function()
    local r = root()
    local t = police and police.Character and police.Character:FindFirstChild("HumanoidRootPart")
    if r and t then r.CFrame = t.CFrame * CFrame.new(0, 0, 4)
    else toast("No sheriff found", T.ERR) end
end)
Button(g, "Go To Murderer", function()
    local r = root()
    local t = murderer and murderer.Character
        and murderer.Character:FindFirstChild("HumanoidRootPart")
    if r and t then r.CFrame = t.CFrame * CFrame.new(0, 0, 6)
    else toast("No murderer found", T.ERR) end
end)

-- ================================================================
-- CHARACTER
-- ================================================================
L, R = makeSub("Character", "Main")

g = Group(L, "movement")
Toggle(g, "Auto Strafe", "autoStrafe")
Slider(g, "Strafe Multiplier", "strafeMult", 0.1, 5)
Toggle(g, "Override Walk Speed", "walkOn")
Slider(g, "Walk Speed", "walkSpeed", 16, 300, nil, function(v)
    local h = humanoid()
    if h and S.walkOn then h.WalkSpeed = v end
end)
Toggle(g, "Override Jump Power", "jumpOn")
Slider(g, "Jump Power", "jumpPower", 50, 400)

g = Group(L, "traversal")
Toggle(g, "Infinite Jump", "infJump")
Toggle(g, "Noclip", "noclip", { callback = function(on)
    if on then return end
    local c = character()
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
    end
end })
Toggle(g, "Fly", "fly", { desc = "WASD to move, Space up, Shift down",
    callback = function(on) if on then startFly() else stopFly() end end })
Slider(g, "Fly Speed", "flySpeed", 20, 400)

g = Group(R, "animation player")
local animBox
Toggle(g, "Enabled", "animOn", { callback = function(on)
    if on then playAnim(animBox and animBox.Text or "") else playAnim("") end
end })
animBox = TextField(g, "animation asset id", function(txt)
    if S.animOn then playAnim(txt) end
end)

L, R = makeSub("Character", "Visuals")

g = Group(L, "self")
Toggle(g, "Hide My Name Tag", "hideName")

-- ================================================================
-- VISUALS
-- ================================================================
L, R = makeSub("Visuals", "Weapons")

g = Group(L, "bullet tracers")
Toggle(g, "Enabled", "tracersOn", { colour = "tracer",
    desc = "Draws a beam from you to the shot target" })
Slider(g, "Tracer Duration", "tracerTime", 1, 30)
Slider(g, "Tracer Width", "tracerWidth", 1, 20)

L, R = makeSub("Visuals", "Hit Effects")

g = Group(L, "hitmarkers")
Toggle(g, "Enabled", "hitmarkOn", { colour = "hitmark" })
Slider(g, "Hitmarker Size", "hitmarkSize", 6, 40)
Slider(g, "Fade Time", "hitmarkTime", 1, 20)

L, R = makeSub("Visuals", "ESP")

g = Group(L, "player esp")
Toggle(g, "Enabled", "espOn")

g = Group(L, "filters")
Toggle(g, "Show Murderer", "showMurderer", { colour = "murderer" })
Toggle(g, "Show Police", "showPolice", { colour = "police" })
Toggle(g, "Show Hero", "showHero", { colour = "hero" })
Toggle(g, "Show Innocent", "showInnocent", { colour = "innocent" })
Toggle(g, "Show Ghost", "showGhost", { colour = "ghost" })
Toggle(g, "Dropped Gun ESP", "gunEsp")
Toggle(g, "Gun Drop Notification", "gunNotify", {
    desc = "Notify when a gun drops (with distance)" })

g = Group(R, "player options")
Slider(g, "Refresh Rate", "espRefresh", 10, 240, "hz")
Toggle(g, "Chams", "espChams")
Toggle(g, "Boxes", "espBoxes")
Toggle(g, "Names", "espNames")
Toggle(g, "Distance", "espDistance")
Toggle(g, "Health Bars", "espHealth")
Toggle(g, "Tracers", "espTracers")
Slider(g, "Text Size", "espTextSize", 9, 22)
Slider(g, "Chams Fill", "espChamsFill", 0, 100)

g = Group(R, "role auras")
Toggle(g, "Murderer Aura", "auraMurd", { colour = "murderer" })
Toggle(g, "Police Aura", "auraPolice", { colour = "police" })
Toggle(g, "Hero Aura", "auraHero", { colour = "hero" })
Toggle(g, "Innocent Aura", "auraInno", { colour = "innocent" })

-- ================================================================
-- WORLD
-- ================================================================
L, R = makeSub("World", "Environment")

g = Group(L, "skybox")
Dropdown(g, "Preset", "sky",
    { "Default", "Midnight", "Sunset", "Overcast", "Crimson", "Void" },
    function(v) applySky(v); toast("Skybox: " .. v, T.OK) end)
local skyBox = TextField(g, "custom skybox asset id", function(txt) customSky(txt) end)
Button(g, "Apply Custom Skybox", function() customSky(skyBox.Text) end)

g = Group(R, "lighting")
Toggle(g, "Fullbright", "fullbright", { callback = function(on)
    if on then return end
    Lighting.Brightness = defaults.brightness
    Lighting.Ambient = defaults.ambient
    Lighting.OutdoorAmbient = defaults.outdoor
end })
Toggle(g, "Remove Fog", "noFog", { callback = function(on)
    if not on then Lighting.FogEnd = defaults.fogEnd end
end })
Toggle(g, "Override Time", "timeOn")
Slider(g, "Clock Time", "timeOfDay", 0, 24, "h")

-- ================================================================
-- PLAYERS
-- ================================================================
L, R = makeSub("Players", "List")

g = Group(L, "players")
local plrHolder = Row(g, 320, "player list")
local plrList = new("ScrollingFrame", {
    Parent = plrHolder,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, { corner(4), list(2),
     new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

g = Group(R, "selected")
local selRow = Row(g, 96, "selected player")
local selThumb = new("ImageLabel", {
    Parent = selRow,
    Size = UDim2.fromOffset(80, 80),
    Position = UDim2.fromOffset(0, 8),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    Image = "",
}, { corner(4) })
local selName = label({
    Parent = selRow,
    Position = UDim2.fromOffset(94, 18),
    Size = UDim2.new(1, -100, 0, 20),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = T.TXT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "no selection",
})
local selRole = label({
    Parent = selRow,
    Position = UDim2.fromOffset(94, 42),
    Size = UDim2.new(1, -100, 0, 18),
    TextSize = 12,
    TextColor3 = T.FAINT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "-",
})

local selectedPlayer, spectating
local refreshPlayers

local spectateBtn = Button(g, "Spectate")
Button(g, "Teleport To", function()
    if not selectedPlayer then toast("Pick a player first", T.ERR); return end
    local t = selectedPlayer.Character
        and selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    local r = root()
    if t and r then r.CFrame = t.CFrame * CFrame.new(0, 0, 3)
    else toast("Can't reach them", T.ERR) end
end)
Button(g, "Fling", function()
    if not selectedPlayer then toast("Pick a player first", T.ERR); return end
    fling(selectedPlayer)
end)
Button(g, "Copy User Id", function()
    if selectedPlayer and type(setclipboard) == "function" then
        pcall(setclipboard, tostring(selectedPlayer.UserId))
        toast("User id copied", T.OK)
    end
end)

spectateBtn.MouseButton1Click:Connect(function()
    if spectating then
        spectating = false
        spectateBtn.Text = "Spectate"
        CAM.CameraSubject = humanoid()
        toast("Stopped spectating", T.DIM)
        return
    end
    if not selectedPlayer then toast("Pick a player first", T.ERR); return end
    local hum = selectedPlayer.Character
        and selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then toast("They have no character", T.ERR); return end
    spectating = true
    CAM.CameraSubject = hum
    spectateBtn.Text = "Unspectate"
    toast("Spectating " .. selectedPlayer.DisplayName, T.RED)
end)

local function refreshSel()
    if not selectedPlayer or not selectedPlayer.Parent then
        selName.Text = "no selection"
        selRole.Text = "-"
        selRole.TextColor3 = T.FAINT
        selThumb.Image = ""
        return
    end
    selName.Text = selectedPlayer.DisplayName
    selThumb.Image = "rbxthumb://type=AvatarHeadShot&id="
        .. selectedPlayer.UserId .. "&w=150&h=150"
    local r = roleOf(selectedPlayer)
    selRole.Text = "@" .. selectedPlayer.Name .. "   \u{00B7}   " .. r:upper()
    selRole.TextColor3 = roleColour(r)
end

local plrRows = {}
refreshPlayers = function()
    for _, row in ipairs(plrRows) do row:Destroy() end
    plrRows = {}
    for i, plr in ipairs(Players:GetPlayers()) do
        local r = roleOf(plr)
        local row = new("TextButton", {
            Parent = plrList,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = T.BG3,
            BackgroundTransparency = plr == selectedPlayer and 0 or 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
        })
        new("Frame", {
            Parent = row,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(6, 6),
            BackgroundColor3 = roleColour(r),
            BorderSizePixel = 0,
        }, { corner(999) })
        label({
            Parent = row,
            Position = UDim2.fromOffset(24, 0),
            Size = UDim2.new(1, -90, 1, 0),
            TextSize = 12.5,
            TextColor3 = plr == selectedPlayer and T.TXT or T.DIM,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = plr.Name .. (plr == LP and "  (you)" or ""),
        })
        label({
            Parent = row,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = UDim2.fromOffset(62, 28),
            TextSize = 11,
            TextColor3 = roleColour(r),
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = r,
        })
        row.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            refreshSel()
            refreshPlayers()
        end)
        table.insert(plrRows, row)
    end
end

Players.PlayerAdded:Connect(function() task.defer(refreshPlayers) end)
Players.PlayerRemoving:Connect(function(p)
    if selectedPlayer == p then selectedPlayer = nil; refreshSel() end
    task.defer(refreshPlayers)
end)
refreshPlayers()
refreshSel()

-- ================================================================
-- CHAT
-- ================================================================
L, R = makeSub("Chat", "Logs")

g = Group(L, "chat logs")
local chatHolder = Row(g, 360, "chat log")
local chatList = new("ScrollingFrame", {
    Parent = chatHolder,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, { corner(4), list(4),
     new("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

local chatLines, chatCount = {}, 0

local function addChatLog(plr, msg)
    chatCount = chatCount + 1
    local r = roleOf(plr)
    local colour = (plr == LP) and T.RED or roleColour(r)

    local row = new("Frame", {
        Parent = chatList,
        LayoutOrder = chatCount,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, { new("UIPadding", { PaddingBottom = UDim.new(0, 4) }) })

    label({
        Parent = row,
        Size = UDim2.fromOffset(40, 16),
        TextSize = 11,
        TextColor3 = T.FAINT,
        Text = os.date("%H:%M"),
    })

    local nameBtn = new("TextButton", {
        Parent = row,
        Position = UDim2.fromOffset(46, 0),
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = colour,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = plr.DisplayName .. "  [" .. r:sub(1, 4):upper() .. "]",
    })

    label({
        Parent = row,
        Position = UDim2.fromOffset(46, 17),
        Size = UDim2.new(1, -52, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = 12,
        TextColor3 = T.DIM,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = msg,
    })

    nameBtn.MouseButton1Click:Connect(function()
        if not plr.Parent then toast(plr.DisplayName .. " has left", T.ERR); return end
        selectedPlayer = plr
        refreshSel()
        refreshPlayers()
        selectCat("Players")
        toast("Pulled up " .. plr.DisplayName, colour)
    end)

    table.insert(chatLines, {
        row = row, raw = os.date("%H:%M") .. "  " .. plr.Name .. ": " .. msg })
    if #chatLines > 200 then
        chatLines[1].row:Destroy()
        table.remove(chatLines, 1)
    end
    task.defer(function()
        chatList.CanvasPosition = Vector2.new(0, chatList.AbsoluteCanvasSize.Y)
    end)
end

g = Group(R, "log controls")
Button(g, "Clear Log", function()
    for _, e in ipairs(chatLines) do e.row:Destroy() end
    chatLines, chatCount = {}, 0
    toast("Chat log cleared", T.DIM)
end)
Button(g, "Copy Log", function()
    local out = {}
    for _, e in ipairs(chatLines) do table.insert(out, e.raw) end
    if type(setclipboard) == "function" then
        pcall(setclipboard, table.concat(out, "\n"))
        toast("Chat log copied", T.OK)
    end
end)
local chatStatus = label({
    Parent = Row(g, 24, "status"),
    Size = UDim2.fromScale(1, 1),
    TextSize = 11.5,
    TextColor3 = T.FAINT,
    Text = "listening\u{2026}",
})

do
    local seen = {}
    local function logOnce(plr, msg)
        if not plr or type(msg) ~= "string" or msg == "" then return end
        local key = tostring(plr.UserId) .. "|" .. msg
        local now = os.clock()
        if seen[key] and now - seen[key] < 1.5 then return end
        seen[key] = now
        addChatLog(plr, msg)
    end

    local modes = {}
    local function announce()
        chatStatus.Text = "listening \u{00B7} " .. table.concat(modes, " + ")
    end

    pcall(function()
        local TCS = game:GetService("TextChatService")
        TCS.MessageReceived:Connect(function(m)
            local src = m.TextSource
            local plr = src and Players:GetPlayerByUserId(src.UserId)
            if plr then logOnce(plr, m.Text) end
        end)
        table.insert(modes, "TextChatService")
    end)

    task.spawn(function()
        local ok = pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local events = rs:WaitForChild("DefaultChatSystemChatEvents", 8)
            local filtered = events and events:WaitForChild("OnMessageDoneFiltering", 8)
            if not filtered then error("no legacy chat") end
            filtered.OnClientEvent:Connect(function(data)
                if type(data) ~= "table" then return end
                local plr = data.FromSpeaker and Players:FindFirstChild(data.FromSpeaker)
                if plr then logOnce(plr, data.Message) end
            end)
        end)
        if ok then table.insert(modes, "legacy"); announce() end
    end)

    local function hookPlayer(plr)
        plr.Chatted:Connect(function(msg) logOnce(plr, msg) end)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
    Players.PlayerAdded:Connect(hookPlayer)
    table.insert(modes, "Chatted")
    announce()
end

-- ================================================================
-- MISC
-- ================================================================
L, R = makeSub("Misc", "Server")

g = Group(L, "server")
Button(g, "Rejoin Server", function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end)
Button(g, "Server Hop", function()
    toast("Finding a server\u{2026}", T.DIM)
    task.spawn(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok then toast("Server list request failed", T.ERR); return end
        local good, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not good or not data.data then toast("Could not read server list", T.ERR); return end
        for _, srv in ipairs(data.data) do
            if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LP)
                end)
                return
            end
        end
        toast("No other servers available", T.ERR)
    end)
end)
Button(g, "Copy Job Id", function()
    if type(setclipboard) == "function" then
        pcall(setclipboard, game.JobId)
        toast("Job id copied", T.OK)
    end
end)

g = Group(R, "round info")
local infoMurd = label({
    Parent = Row(g, 24, "murderer"),
    Size = UDim2.fromScale(1, 1), TextSize = 12.5, TextColor3 = T.FAINT,
    Text = "murderer: unknown",
})
local infoPolice = label({
    Parent = Row(g, 24, "police"),
    Size = UDim2.fromScale(1, 1), TextSize = 12.5, TextColor3 = T.FAINT,
    Text = "police: unknown",
})
local infoHero = label({
    Parent = Row(g, 24, "hero"),
    Size = UDim2.fromScale(1, 1), TextSize = 12.5, TextColor3 = T.FAINT,
    Text = "hero: none",
})
local infoYou = label({
    Parent = Row(g, 24, "your role"),
    Size = UDim2.fromScale(1, 1), TextSize = 12.5, TextColor3 = T.FAINT,
    Text = "you: unknown",
})

-- ================================================================
-- SETTINGS
-- ================================================================
L, R = makeSub("Settings", "Menu")

g = Group(L, "menu")
local bindRow = Row(g, 62, "menu bind")
rowLabel(bindRow, "Menu Bind")
local bindBtn = new("TextButton", {
    Parent = bindRow,
    Position = UDim2.fromOffset(0, 22),
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.Gotham,
    TextSize = 12.5,
    TextColor3 = T.TXT,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "   " .. CFG.Toggle.Name,
}, { corner(4) })

local awaitingBind = false
bindBtn.MouseButton1Click:Connect(function()
    awaitingBind = true
    bindBtn.Text = "   press a key\u{2026}"
    bindBtn.TextColor3 = T.RED
end)

Button(g, "Unload Hub", function()
    for _, plr in ipairs(Players:GetPlayers()) do killEsp(plr) end
    for _, d in pairs(objEsp) do pcall(function() d:Remove() end) end
    gui:Destroy()
end)

g = Group(R, "accent")
local swRow = Row(g, 40, "accent colour")
for i, hex in ipairs(PALETTE) do
    local sw = new("TextButton", {
        Parent = swRow,
        Position = UDim2.fromOffset((i - 1) * 34, 4),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = Color3.fromHex(hex),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
    }, { corner(4), stroke(T.LINE, 0.4) })
    sw.MouseButton1Click:Connect(function()
        setAccent(Color3.fromHex(hex))
        toast("Accent changed", Color3.fromHex(hex))
    end)
end

-- ================================================================
-- search
-- ================================================================
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = searchBox.Text:lower()
    local hits = {}
    for _, entry in ipairs(ROWS) do
        local match = (q == "") or entry.text:find(q, 1, true) ~= nil
        entry.row.Visible = match
        if match then hits[entry.group] = true end
    end
    for _, entry in ipairs(ROWS) do
        entry.group.frame.Visible = (q == "") or (hits[entry.group] == true)
    end
end)

-- ================================================================
-- runtime
-- ================================================================
task.spawn(function()
    while gui.Parent do
        task.wait(0.4)
        scanRoles()
        infoMurd.Text = "murderer: " .. (murderer and murderer.DisplayName or "unknown")
        infoMurd.TextColor3 = murderer and RC.murderer or T.FAINT
        infoPolice.Text = "police: " .. (police and police.DisplayName or "unknown")
        infoPolice.TextColor3 = police and RC.police or T.FAINT
        infoHero.Text = "hero: " .. (hero and hero.DisplayName or "none")
        infoHero.TextColor3 = hero and RC.hero or T.FAINT
        local mine = roleOf(LP)
        infoYou.Text = "you: " .. mine
        infoYou.TextColor3 = roleColour(mine)
        if selectedPlayer then refreshSel() end
    end
end)

UserInputService.InputBegan:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end

    if awaitingBind then
        awaitingBind = false
        CFG.Toggle = i.KeyCode
        bindBtn.Text = "   " .. i.KeyCode.Name
        bindBtn.TextColor3 = T.TXT
        toast("Menu bind set to " .. i.KeyCode.Name, T.OK)
        return
    end

    if i.KeyCode == CFG.Toggle then win.Visible = not win.Visible end
end)

selectCat("Autofarm")

win.Size = UDim2.fromOffset(W, 0)
tween(win, 0.36, { Size = UDim2.fromOffset(W, H) }, EASE)

task.delay(0.5, function()
    toast(CFG.Script .. " loaded  \u{00B7}  " .. CFG.Toggle.Name .. " to hide", T.RED)
end)
