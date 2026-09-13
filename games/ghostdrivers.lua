--[[ ================================================================
     privateclub.cc  ·  ghost drivers
     ----------------------------------------------------------------
     driving, vehicle tuning, ESP, session stats, configs, webhooks.
     Right Ctrl hides the menu.

     Nothing here hard-codes a path from the game. Vehicles are found
     through the seat you are sitting in, and stats are looked up by
     name against leaderstats, attributes and value objects. If the
     game names something differently, change the lists in CFG or use
     Settings -> Inspector to see what was actually found.
     ================================================================ ]]

local CFG = {
    Brand   = "privateclub",
    Brand2  = "hub",
    Script  = "Ghost Drivers",
    Version = "v1.0",
    Toggle  = Enum.KeyCode.RightControl,
    SaveDir = "privateclub_gd",

    -- names to try when reading a stat, first match wins
    Stats = {
        cash  = { "Cash", "Money", "Credits", "Coins", "Bank" },
        level = { "Level", "Lvl", "Rank Level" },
        rank  = { "Rank", "Title", "Prestige" },
        xp    = { "XP", "Exp", "Experience" },
    },

    -- folders that usually hold AI traffic
    TrafficFolders = {
        "Traffic", "TrafficCars", "TrafficVehicles",
        "NPCCars", "NPCVehicles", "AICars", "AI", "Cars",
    },

    -- studs/sec -> mph. tune it until it matches the in-game speedo
    MphFactor = 0.6263,
}

-- ================================================================
-- services
-- ================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")

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
if ENV.__pc_gd then pcall(function() ENV.__pc_gd:Destroy() end) end

local gui = new("ScreenGui", {
    Name = "\u{200B}pcg" .. tostring(math.random(100000, 999999)),
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 996,
})
ENV.__pc_gd = gui

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
    -- driving
    autoDrive = false, driveMode = "Waypoint", throttleHold = false,
    stopDist = 12, steerGain = 2, autoRespawn = false,

    -- traffic
    noTrafficCollide = false, hideTraffic = false, trafficGhost = false,

    -- vehicle
    tuneSpeed = false, maxSpeed = 200,
    tuneTorque = false, torque = 40,
    tuneTurn = false, turnSpeed = 40,
    infNitro = false, infFuel = false,
    noVehicleDamage = false,

    -- esp
    espOn = true, espNames = true, espSpeed = true, espLevel = false,
    espRank = false, espCash = false, espDistance = true,
    espBox = false, espChams = false, espTracers = false,
    espMaxDist = 3000, espTextSize = 13, espRefresh = 60,

    -- hud
    hudOn = true, hudSpeed = true, hudCash = true, hudSession = true,

    -- world
    fullbright = false, noFog = false, timeOn = false, timeOfDay = 14,

    -- webhook
    webhookOn = false, whSession = true, whLevel = false,
    whCash = false, whCashStep = 10000, whInterval = 300,

    mphFactor = 63,   -- shown as 0.63, divided by 100 on use
}

local WEBHOOK_URL = ""

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
-- character / vehicle
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

local function seatOf(plr)
    local c = (plr or LP).Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    local sp = hum and hum.SeatPart
    if sp and (sp:IsA("VehicleSeat") or sp:IsA("Seat")) then return sp end
    return nil
end

-- climb from the seat to the topmost model sitting directly in workspace
local function vehicleOf(plr)
    local seat = seatOf(plr)
    if not seat then return nil, nil end
    local top = seat
    while top.Parent and top.Parent ~= workspace and top.Parent ~= game do
        top = top.Parent
    end
    return top, seat
end

local function mphFactor() return S.mphFactor / 100 end

local function speedOf(plr)
    local _, seat = vehicleOf(plr)
    local part = seat
    if not part then
        local c = (plr or LP).Character
        part = c and c:FindFirstChild("HumanoidRootPart")
    end
    if not part then return 0 end
    return part.AssemblyLinearVelocity.Magnitude
end

local function mphOf(plr)
    return math.floor(speedOf(plr) * mphFactor() + 0.5)
end

-- ================================================================
-- stats, looked up by name rather than a hard-coded path
-- ================================================================
local function statOf(plr, kind)
    local names = CFG.Stats[kind]
    if not names then return nil end

    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        for _, n in ipairs(names) do
            local v = ls:FindFirstChild(n)
            if v and v:IsA("ValueBase") then return v.Value end
        end
    end

    for _, n in ipairs(names) do
        local ok, a = pcall(function() return plr:GetAttribute(n) end)
        if ok and a ~= nil then return a end
    end

    for _, n in ipairs(names) do
        local v = plr:FindFirstChild(n)
        if v and v:IsA("ValueBase") then return v.Value end
    end

    return nil
end

local function comma(v)
    local out = tostring(math.floor(tonumber(v) or 0))
    local k
    repeat out, k = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return out
end

local function statText(plr, kind)
    local v = statOf(plr, kind)
    if v == nil then return nil end
    if type(v) == "number" then return comma(v) end
    return tostring(v)
end

-- ================================================================
-- session stats
-- ================================================================
local SESSION = {
    start = os.time(),
    distance = 0,     -- studs
    topSpeed = 0,     -- mph
    cashStart = nil,
    levelStart = nil,
    levelUps = 0,
}

local lastPos
task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        local r = root()
        if r then
            if lastPos then
                local d = (r.Position - lastPos).Magnitude
                -- ignore teleports
                if d < 400 then SESSION.distance = SESSION.distance + d end
            end
            lastPos = r.Position
        end

        local m = mphOf(LP)
        if m > SESSION.topSpeed then SESSION.topSpeed = m end

        local cash = statOf(LP, "cash")
        if type(cash) == "number" then
            if SESSION.cashStart == nil then SESSION.cashStart = cash end
        end

        local lvl = statOf(LP, "level")
        if type(lvl) == "number" then
            if SESSION.levelStart == nil then
                SESSION.levelStart = lvl
            elseif lvl > (SESSION.lastLevel or SESSION.levelStart) then
                SESSION.levelUps = SESSION.levelUps + 1
            end
            SESSION.lastLevel = lvl
        end
    end
end)

local function sessionSeconds() return os.time() - SESSION.start end

local function clockText(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return s .. "s"
end

local function milesDriven()
    -- studs -> miles using the same factor as the speedo
    return SESSION.distance * mphFactor() / 3600
end

local function cashGained()
    local now = statOf(LP, "cash")
    if type(now) ~= "number" or SESSION.cashStart == nil then return 0 end
    return now - SESSION.cashStart
end

-- ================================================================
-- traffic
-- ================================================================
local function isPlayerVehicle(model)
    for _, plr in ipairs(Players:GetPlayers()) do
        local v = vehicleOf(plr)
        if v and (v == model or model:IsDescendantOf(v)) then return true end
    end
    return false
end

local function trafficModels()
    local out = {}

    for _, name in ipairs(CFG.TrafficFolders) do
        local folder = workspace:FindFirstChild(name)
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m:IsA("Model") then table.insert(out, m) end
            end
        end
    end

    -- anything in workspace that drives but has nobody in it
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChildWhichIsA("VehicleSeat", true)
           and not isPlayerVehicle(m) then
            table.insert(out, m)
        end
    end

    return out
end

local trafficCache = {}
task.spawn(function()
    while gui.Parent do
        task.wait(0.4)
        if S.noTrafficCollide or S.hideTraffic or S.trafficGhost then
            for _, m in ipairs(trafficModels()) do
                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("BasePart") then
                        if trafficCache[p] == nil then
                            trafficCache[p] = { p.CanCollide, p.Transparency }
                        end
                        if S.noTrafficCollide then p.CanCollide = false end
                        if S.hideTraffic then
                            p.Transparency = 1
                        elseif S.trafficGhost then
                            p.Transparency = 0.6
                        end
                    end
                end
            end
        elseif next(trafficCache) then
            for p, old in pairs(trafficCache) do
                if p and p.Parent then
                    p.CanCollide = old[1]
                    p.Transparency = old[2]
                end
            end
            trafficCache = {}
        end
    end
end)

-- ================================================================
-- vehicle tuning
-- ================================================================
local function forEachValue(model, names, fn)
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ValueBase") then
            local n = d.Name:lower()
            for _, want in ipairs(names) do
                if n:find(want, 1, true) then fn(d) break end
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    local veh, seat = vehicleOf()
    if not seat then return end

    if seat:IsA("VehicleSeat") then
        if S.tuneSpeed then seat.MaxSpeed = S.maxSpeed end
        if S.tuneTorque then seat.Torque = S.torque end
        if S.tuneTurn then seat.TurnSpeed = S.turnSpeed end
    end

    if S.infNitro then
        forEachValue(veh, { "nitro", "boost", "nos" }, function(v)
            if typeof(v.Value) == "number" then v.Value = 100 end
        end)
    end
    if S.infFuel then
        forEachValue(veh, { "fuel", "gas", "petrol" }, function(v)
            if typeof(v.Value) == "number" then v.Value = 100 end
        end)
    end
    if S.noVehicleDamage then
        forEachValue(veh, { "health", "damage", "durability" }, function(v)
            if typeof(v.Value) == "number" and v.Value < 100 then v.Value = 100 end
        end)
    end

    if S.fullbright then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    end
    if S.noFog then Lighting.FogEnd = 1e6 end
    if S.timeOn then Lighting.ClockTime = S.timeOfDay end
end)

-- ================================================================
-- auto drive
-- ================================================================
local waypoint
local followTarget

RunService.Heartbeat:Connect(function()
    local veh, seat = vehicleOf()
    if not seat or not seat:IsA("VehicleSeat") then return end

    if S.throttleHold and not S.autoDrive then
        seat.Throttle = 1
        return
    end
    if not S.autoDrive then return end

    local goal
    if S.driveMode == "Waypoint" then
        goal = waypoint
    elseif S.driveMode == "Follow" then
        local t = followTarget
        local c = t and t.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        goal = hrp and hrp.Position or nil
    end

    if not goal then
        seat.Throttle = 1
        return
    end

    local flat = Vector3.new(goal.X - seat.Position.X, 0, goal.Z - seat.Position.Z)
    if flat.Magnitude <= S.stopDist then
        seat.Throttle = 0
        seat.Steer = 0
        return
    end

    seat.Throttle = 1
    local dir = flat.Unit
    local right = seat.CFrame.RightVector
    local forward = seat.CFrame.LookVector

    -- reverse out if the goal is behind us
    if forward:Dot(dir) < -0.4 then
        seat.Throttle = -1
        seat.Steer = right:Dot(dir) > 0 and -1 or 1
        return
    end

    seat.Steer = math.clamp(right:Dot(dir) * (S.steerGain / 10) * 10, -1, 1)
end)

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
        box  = drawing("Square", { Thickness = 1, Filled = false, Visible = false }),
        name = drawing("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
        info = drawing("Text", { Size = 11, Center = true, Outline = true, Visible = false }),
        line = drawing("Line", { Thickness = 1, Visible = false }),
    }
end

local function hideEsp(o)
    if not o then return end
    for _, d in pairs(o) do d.Visible = false end
end

local function chams(plr, show)
    local c = plr.Character
    if not c then return end
    local hl = c:FindFirstChild("pc_cham")
    if not (S.espOn and S.espChams and show) then
        if hl then hl:Destroy() end
        return
    end
    if not hl then
        hl = new("Highlight", {
            Name = "pc_cham", Parent = c,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency = 0.6,
        })
    end
    hl.FillColor = T.RED
    hl.OutlineColor = T.RED
end

local function killEsp(plr)
    local o = esp[plr]
    if o then
        for _, d in pairs(o) do pcall(function() d:Remove() end) end
        esp[plr] = nil
    end
    local c = plr.Character
    local hl = c and c:FindFirstChild("pc_cham")
    if hl then hl:Destroy() end
end

Players.PlayerRemoving:Connect(killEsp)

local espClock = 0
RunService.RenderStepped:Connect(function(dt)
    espClock = espClock + dt
    if espClock < (1 / math.max(S.espRefresh, 1)) then return end
    espClock = 0

    local myRoot = root()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local o = esp[plr]
            local c = plr.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")

            chams(plr, S.espOn)

            if not S.espOn or not hrp or not hum or hum.Health <= 0 then
                hideEsp(o)
            else
                if not o then o = buildEsp(); esp[plr] = o end
                if o then
                    local dist = myRoot
                        and math.floor((myRoot.Position - hrp.Position).Magnitude) or 0
                    local pos, on = CAM:WorldToViewportPoint(hrp.Position)

                    if on and dist <= S.espMaxDist then
                        local topV = CAM:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.2, 0))
                        local botV = CAM:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.4, 0))
                        local h = math.abs(topV.Y - botV.Y)
                        local w = h / 2
                        local x, y = pos.X - w / 2, topV.Y

                        o.box.Visible = S.espBox
                        if S.espBox then
                            o.box.Color = T.RED
                            o.box.Size = Vector2.new(w, h)
                            o.box.Position = Vector2.new(x, y)
                        end

                        o.name.Visible = S.espNames
                        if S.espNames then
                            o.name.Color = T.RED
                            o.name.Size = S.espTextSize
                            o.name.Text = plr.DisplayName
                            o.name.Position = Vector2.new(pos.X, y - S.espTextSize - 3)
                        end

                        -- the detail line is assembled from whichever
                        -- toggles are on
                        local bits = {}
                        if S.espSpeed then table.insert(bits, mphOf(plr) .. " mph") end
                        if S.espLevel then
                            local v = statText(plr, "level")
                            table.insert(bits, v and ("lvl " .. v) or "lvl ?")
                        end
                        if S.espRank then
                            local v = statText(plr, "rank")
                            table.insert(bits, v or "rank ?")
                        end
                        if S.espCash then
                            local v = statText(plr, "cash")
                            table.insert(bits, v and ("$" .. v) or "$?")
                        end
                        if S.espDistance then table.insert(bits, dist .. "m") end

                        o.info.Visible = #bits > 0
                        if o.info.Visible then
                            o.info.Color = T.DIM
                            o.info.Size = S.espTextSize - 2
                            o.info.Text = table.concat(bits, "  ")
                            o.info.Position = Vector2.new(pos.X, y + h + 2)
                        end

                        o.line.Visible = S.espTracers
                        if S.espTracers then
                            o.line.Color = T.RED
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
end)

-- ================================================================
-- speed HUD
-- ================================================================
local hud = new("Frame", {
    Parent = gui,
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -28),
    Size = UDim2.fromOffset(300, 62),
    BackgroundColor3 = T.BG0,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
}, { corner(RADIUS), stroke(T.LINE, 0.25) })

accent(new("Frame", {
    Parent = hud,
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
}), "BackgroundColor3")

local hudSpeed = label({
    Parent = hud,
    Position = UDim2.fromOffset(16, 8),
    Size = UDim2.fromOffset(120, 34),
    Font = Enum.Font.GothamBold,
    TextSize = 28,
    TextColor3 = T.TXT,
    Text = "0",
})

label({
    Parent = hud,
    Position = UDim2.fromOffset(16, 40),
    Size = UDim2.fromOffset(120, 14),
    TextSize = 10.5,
    TextColor3 = T.FAINT,
    Text = "MPH",
})

local hudCash = label({
    Parent = hud,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 12),
    Size = UDim2.fromOffset(150, 18),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = T.OK,
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "$0",
})

local hudSession = label({
    Parent = hud,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 34),
    Size = UDim2.fromOffset(150, 16),
    TextSize = 11,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "0m  ·  0 mi",
})

do
    local dragging, startPos, origin
    hud.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, origin = true, i.Position, hud.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startPos
            hud.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X,
                                     origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

task.spawn(function()
    while gui.Parent do
        task.wait(0.1)
        hud.Visible = S.hudOn
        if S.hudOn then
            hudSpeed.Visible = S.hudSpeed
            hudSpeed.Text = tostring(mphOf(LP))

            hudCash.Visible = S.hudCash
            local cash = statText(LP, "cash")
            hudCash.Text = cash and ("$" .. cash) or "$?"

            hudSession.Visible = S.hudSession
            hudSession.Text = clockText(sessionSeconds())
                .. "  \u{00B7}  " .. string.format("%.1f mi", milesDriven())
        end
    end
end)

-- ================================================================
-- webhook
-- ================================================================
local function httpPost(url, body)
    local req = (syn and syn.request)
             or (type(http) == "table" and http.request)
             or http_request
             or request
    if type(req) ~= "function" then return false, "executor has no http request" end
    local ok, res = pcall(req, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(body),
    })
    if not ok then return false, "request failed" end
    local code = (type(res) == "table" and (res.StatusCode or res.Status)) or 0
    return code >= 200 and code < 300, "http " .. tostring(code)
end

local function sessionEmbed(title)
    local cash = statText(LP, "cash") or "?"
    local lvl = statText(LP, "level") or "?"
    local rank = statText(LP, "rank") or "?"
    return {
        username = "privateclub.cc",
        embeds = { {
            title = title,
            color = 16723523,
            fields = {
                { name = "Player", value = LP.DisplayName .. " (@" .. LP.Name .. ")", inline = true },
                { name = "Session", value = clockText(sessionSeconds()), inline = true },
                { name = "Distance", value = string.format("%.1f mi", milesDriven()), inline = true },
                { name = "Top speed", value = SESSION.topSpeed .. " mph", inline = true },
                { name = "Cash", value = "$" .. cash, inline = true },
                { name = "Earned", value = "$" .. comma(cashGained()), inline = true },
                { name = "Level", value = tostring(lvl), inline = true },
                { name = "Rank", value = tostring(rank), inline = true },
                { name = "Level ups", value = tostring(SESSION.levelUps), inline = true },
            },
            footer = { text = CFG.Brand .. CFG.Brand2 .. "  \u{00B7}  " .. CFG.Script },
        } },
    }
end

local function sendWebhook(title, silent)
    if WEBHOOK_URL == "" then
        if not silent then toast("Set a webhook url first", T.ERR) end
        return false
    end
    local ok, why = httpPost(WEBHOOK_URL, sessionEmbed(title))
    if not silent then
        toast(ok and "Webhook sent" or ("Webhook failed: " .. why), ok and T.OK or T.ERR)
    end
    return ok
end

-- periodic session report, only while the toggle is on
task.spawn(function()
    local last = os.time()
    while gui.Parent do
        task.wait(5)
        if S.webhookOn and S.whSession and WEBHOOK_URL ~= "" then
            if os.time() - last >= S.whInterval then
                last = os.time()
                sendWebhook("Session report", true)
            end
        end
    end
end)

-- level up + cash milestone alerts
task.spawn(function()
    local lastLevel, lastStep
    while gui.Parent do
        task.wait(2)
        if S.webhookOn and WEBHOOK_URL ~= "" then
            local lvl = statOf(LP, "level")
            if type(lvl) == "number" then
                if lastLevel and lvl > lastLevel and S.whLevel then
                    sendWebhook("Level up \u{2014} now level " .. lvl, true)
                end
                lastLevel = lvl
            end

            if S.whCash then
                local gained = cashGained()
                local step = math.floor(gained / math.max(S.whCashStep, 1))
                if lastStep and step > lastStep then
                    sendWebhook("Earned $" .. comma(gained) .. " this session", true)
                end
                lastStep = step
            end
        end
    end
end)

-- ================================================================
-- configs
-- ================================================================
local function configList()
    local out = {}
    if type(listfiles) ~= "function" then return out end
    local ok, files = pcall(listfiles, CFG.SaveDir)
    if not ok or type(files) ~= "table" then return out end
    for _, f in ipairs(files) do
        local n = tostring(f):match("([^/\\]+)%.json$")
        if n then table.insert(out, n) end
    end
    return out
end

local function saveConfig(name)
    name = tostring(name):gsub("[^%w_%-]", "")
    if name == "" then return false, "bad name" end
    if type(writefile) ~= "function" then return false, "no filesystem" end
    if type(makefolder) == "function" then pcall(makefolder, CFG.SaveDir) end
    local blob = { settings = S, webhook = WEBHOOK_URL }
    local ok = pcall(function()
        writefile(CFG.SaveDir .. "/" .. name .. ".json", HttpService:JSONEncode(blob))
    end)
    return ok, name
end

local function loadConfig(name)
    if type(readfile) ~= "function" then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CFG.SaveDir .. "/" .. name .. ".json"))
    end)
    if not ok or type(data) ~= "table" then return false end
    if type(data.settings) == "table" then
        for k, v in pairs(data.settings) do S[k] = v end
    end
    if type(data.webhook) == "string" then WEBHOOK_URL = data.webhook end
    return true
end

-- ================================================================
-- inspector: what the script actually found in this game
-- ================================================================
local function inspectReport()
    local veh, seat = vehicleOf()
    local lines = {}

    table.insert(lines, "place id       " .. game.PlaceId)
    table.insert(lines, "vehicle        " .. (veh and veh.Name or "not seated"))
    table.insert(lines, "seat class     " .. (seat and seat.ClassName or "-"))
    table.insert(lines, "speed          " .. string.format("%.1f studs/s  =  %d mph",
        speedOf(LP), mphOf(LP)))

    for _, kind in ipairs({ "cash", "level", "rank", "xp" }) do
        local v = statOf(LP, kind)
        table.insert(lines, string.format("%-14s %s", kind,
            v == nil and "not found" or tostring(v)))
    end

    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        local names = {}
        for _, v in ipairs(ls:GetChildren()) do
            table.insert(names, v.Name .. "=" .. tostring(v.Value))
        end
        table.insert(lines, "leaderstats    " .. table.concat(names, ", "))
    else
        table.insert(lines, "leaderstats    none")
    end

    if veh then
        local vals = {}
        for _, d in ipairs(veh:GetDescendants()) do
            if d:IsA("ValueBase") then
                table.insert(vals, d.Name .. "=" .. tostring(d.Value))
            end
        end
        table.insert(lines, "vehicle values " ..
            (#vals > 0 and table.concat(vals, ", ") or "none"))
    end

    local found = {}
    for _, name in ipairs(CFG.TrafficFolders) do
        if workspace:FindFirstChild(name) then table.insert(found, name) end
    end
    table.insert(lines, "traffic folders " ..
        (#found > 0 and table.concat(found, ", ") or "none matched"))
    table.insert(lines, "traffic models  " .. #trafficModels())

    return table.concat(lines, "\n")
end

-- ================================================================
-- window chrome
-- ================================================================
local W, H = 1020, 620
local SIDE = 200

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
    Size = UDim2.fromOffset(520, 44),
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

local function Readout(g, caption)
    local r = Row(g, 24, caption)
    label({
        Parent = r,
        Size = UDim2.fromOffset(150, 24),
        TextSize = 12.5,
        TextColor3 = T.FAINT,
        Text = caption,
    })
    return label({
        Parent = r,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(1, -150, 0, 24),
        Font = Enum.Font.GothamBold,
        TextSize = 12.5,
        TextColor3 = T.TXT,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "-",
    })
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

addCat("Driving",  { "Auto", "Traffic" })
addCat("Vehicle",  { "Tuning", "Boost" })
addCat("Visuals",  { "ESP", "HUD", "World" })
addCat("Stats",    { "Session" })
addCat("Webhook",  { "Discord" })
addCat("Config",   { "Saves" })
addCat("Settings", { "Menu", "Inspector" })

-- ================================================================
-- DRIVING
-- ================================================================
local L, R = makeSub("Driving", "Auto")

local g = Group(L, "auto drive")
Toggle(g, "Auto Drive", "autoDrive", {
    desc = "Holds throttle and steers toward the target",
    callback = function(on)
        toast(on and "Auto drive on" or "Auto drive off", on and T.OK or T.DIM)
    end })
Dropdown(g, "Mode", "driveMode", { "Waypoint", "Follow", "Free" })
Slider(g, "Stop Distance", "stopDist", 4, 80, "studs")
Slider(g, "Steer Gain", "steerGain", 1, 10)

g = Group(L, "throttle")
Toggle(g, "Throttle Hold", "throttleHold", {
    desc = "Keeps the accelerator down without steering" })
Toggle(g, "Auto Respawn Vehicle", "autoRespawn")

g = Group(R, "waypoint")
local wpLabel = Readout(g, "saved")
Button(g, "Set Waypoint Here", function()
    local r = root()
    if not r then toast("No character", T.ERR); return end
    waypoint = r.Position
    wpLabel.Text = string.format("%d, %d, %d",
        waypoint.X, waypoint.Y, waypoint.Z)
    toast("Waypoint saved", T.OK)
end)
Button(g, "Clear Waypoint", function()
    waypoint = nil
    wpLabel.Text = "-"
    toast("Waypoint cleared", T.DIM)
end)

g = Group(R, "follow")
local followBox = TextField(g, "player name")
Button(g, "Set Follow Target", function()
    local q = (followBox.Text or ""):lower()
    if q == "" then toast("Type a player name", T.ERR); return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and (plr.Name:lower():find(q, 1, true)
                       or plr.DisplayName:lower():find(q, 1, true)) then
            followTarget = plr
            toast("Following " .. plr.DisplayName, T.OK)
            return
        end
    end
    toast("No player matched " .. q, T.ERR)
end)

-- ---------------- Traffic ----------------
L, R = makeSub("Driving", "Traffic")

g = Group(L, "traffic")
Toggle(g, "No Traffic Collision", "noTrafficCollide", {
    desc = "Drive straight through AI cars" })
Toggle(g, "Ghost Traffic", "trafficGhost", {
    desc = "Makes traffic see-through so you can read the road" })
Toggle(g, "Hide Traffic", "hideTraffic")

g = Group(R, "detected")
local trafficCount = Readout(g, "traffic models")
local trafficFolders = Readout(g, "folders matched")
Button(g, "Rescan Now", function()
    trafficCount.Text = tostring(#trafficModels())
    local found = {}
    for _, n in ipairs(CFG.TrafficFolders) do
        if workspace:FindFirstChild(n) then table.insert(found, n) end
    end
    trafficFolders.Text = #found > 0 and table.concat(found, ", ") or "none"
    toast("Traffic rescanned", T.DIM)
end)

-- ================================================================
-- VEHICLE
-- ================================================================
L, R = makeSub("Vehicle", "Tuning")

g = Group(L, "performance")
Toggle(g, "Override Top Speed", "tuneSpeed")
Slider(g, "Top Speed", "maxSpeed", 20, 1000)
Toggle(g, "Override Torque", "tuneTorque")
Slider(g, "Torque", "torque", 5, 300)

g = Group(R, "handling")
Toggle(g, "Override Turn Speed", "tuneTurn")
Slider(g, "Turn Speed", "turnSpeed", 5, 200)
Toggle(g, "No Vehicle Damage", "noVehicleDamage", {
    desc = "Keeps health style values pinned at full" })

g = Group(R, "current vehicle")
local vehName = Readout(g, "vehicle")
local vehSeat = Readout(g, "seat class")
local vehSpeed = Readout(g, "speed")

-- ---------------- Boost ----------------
L, R = makeSub("Vehicle", "Boost")

g = Group(L, "boost")
Toggle(g, "Infinite Nitro", "infNitro", {
    desc = "Refills any value named nitro, boost or nos" })
Toggle(g, "Infinite Fuel", "infFuel", {
    desc = "Refills any value named fuel, gas or petrol" })

g = Group(R, "speedometer")
Slider(g, "MPH Factor", "mphFactor", 10, 200, nil, function()
    toast("Tune until it matches the game's speedo", T.DIM)
end)

-- ================================================================
-- VISUALS
-- ================================================================
L, R = makeSub("Visuals", "ESP")

g = Group(L, "player esp")
Toggle(g, "Enabled", "espOn")
Toggle(g, "Names", "espNames")
Toggle(g, "Boxes", "espBox")
Toggle(g, "Chams", "espChams")
Toggle(g, "Tracers", "espTracers")

g = Group(L, "detail line")
Toggle(g, "Speed (mph)", "espSpeed")
Toggle(g, "Level", "espLevel")
Toggle(g, "Rank", "espRank")
Toggle(g, "Cash", "espCash")
Toggle(g, "Distance", "espDistance")

g = Group(R, "esp options")
Slider(g, "Max Distance", "espMaxDist", 200, 8000, "studs")
Slider(g, "Text Size", "espTextSize", 9, 22)
Slider(g, "Refresh Rate", "espRefresh", 10, 240, "hz")

-- ---------------- HUD ----------------
L, R = makeSub("Visuals", "HUD")

g = Group(L, "speed hud")
Toggle(g, "Show HUD", "hudOn")
Toggle(g, "Speed", "hudSpeed")
Toggle(g, "Cash", "hudCash")
Toggle(g, "Session", "hudSession")

-- ---------------- World ----------------
L, R = makeSub("Visuals", "World")

g = Group(L, "lighting")
Toggle(g, "Fullbright", "fullbright")
Toggle(g, "Remove Fog", "noFog")
Toggle(g, "Override Time", "timeOn")
Slider(g, "Clock Time", "timeOfDay", 0, 24, "h")

-- ================================================================
-- STATS
-- ================================================================
L, R = makeSub("Stats", "Session")

g = Group(L, "session")
local stTime = Readout(g, "time played")
local stDist = Readout(g, "distance")
local stTop = Readout(g, "top speed")
local stEarned = Readout(g, "cash earned")
local stLevelUps = Readout(g, "level ups")

g = Group(R, "account")
local stCash = Readout(g, "cash")
local stLevel = Readout(g, "level")
local stRank = Readout(g, "rank")
local stXp = Readout(g, "xp")

g = Group(R, "controls")
Button(g, "Reset Session", function()
    SESSION.start = os.time()
    SESSION.distance = 0
    SESSION.topSpeed = 0
    SESSION.cashStart = statOf(LP, "cash")
    SESSION.levelUps = 0
    toast("Session reset", T.DIM)
end)
Button(g, "Copy Session Report", function()
    if type(setclipboard) ~= "function" then return end
    local cash = statText(LP, "cash") or "?"
    pcall(setclipboard, table.concat({
        CFG.Script .. " session",
        "time      " .. clockText(sessionSeconds()),
        "distance  " .. string.format("%.1f mi", milesDriven()),
        "top speed " .. SESSION.topSpeed .. " mph",
        "earned    $" .. comma(cashGained()),
        "cash      $" .. cash,
    }, "\n"))
    toast("Session report copied", T.OK)
end)

-- ================================================================
-- WEBHOOK
-- ================================================================
L, R = makeSub("Webhook", "Discord")

g = Group(L, "discord webhook")
Toggle(g, "Enabled", "webhookOn", {
    desc = "Nothing is sent anywhere until you turn this on" })
local whBox = TextField(g, "https://discord.com/api/webhooks/...", function(txt)
    WEBHOOK_URL = txt or ""
    toast(WEBHOOK_URL == "" and "Webhook url cleared" or "Webhook url set",
          WEBHOOK_URL == "" and T.DIM or T.OK)
end)
Button(g, "Send Test Report", function() sendWebhook("Test report") end)

g = Group(R, "what to send")
Toggle(g, "Periodic Session Report", "whSession")
Slider(g, "Report Interval", "whInterval", 60, 3600, "s")
Toggle(g, "Level Ups", "whLevel")
Toggle(g, "Cash Milestones", "whCash")
Slider(g, "Cash Step", "whCashStep", 1000, 500000)

-- ================================================================
-- CONFIG
-- ================================================================
L, R = makeSub("Config", "Saves")

g = Group(L, "saved configs")
local cfgHolder = Row(g, 200, "config list")
local cfgList = new("ScrollingFrame", {
    Parent = cfgHolder,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, { corner(4), list(2),
     new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

local selectedConfig
local cfgRows = {}

local function refreshConfigs()
    for _, row in ipairs(cfgRows) do row:Destroy() end
    cfgRows = {}
    for i, name in ipairs(configList()) do
        local b = new("TextButton", {
            Parent = cfgList,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 12.5,
            TextColor3 = name == selectedConfig and T.RED or T.DIM,
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = name,
        })
        b.MouseButton1Click:Connect(function()
            selectedConfig = name
            for _, r2 in ipairs(cfgRows) do r2.TextColor3 = T.DIM end
            b.TextColor3 = T.RED
        end)
        table.insert(cfgRows, b)
    end
end

g = Group(R, "manage")
local cfgName = TextField(g, "config name")
Button(g, "Save", function()
    local ok, name = saveConfig(cfgName.Text ~= "" and cfgName.Text or (selectedConfig or ""))
    toast(ok and ("Saved " .. name) or "Save failed", ok and T.OK or T.ERR)
    refreshConfigs()
end)
Button(g, "Load", function()
    if not selectedConfig then toast("Pick a config", T.ERR); return end
    local ok = loadConfig(selectedConfig)
    toast(ok and ("Loaded " .. selectedConfig .. " \u{2014} reopen the menu to redraw")
             or "Load failed", ok and T.OK or T.ERR)
end)
Button(g, "Delete", function()
    if not selectedConfig then return end
    if type(delfile) == "function" then
        pcall(delfile, CFG.SaveDir .. "/" .. selectedConfig .. ".json")
    end
    selectedConfig = nil
    refreshConfigs()
    toast("Config deleted", T.DIM)
end)
Button(g, "Refresh List", refreshConfigs)
refreshConfigs()

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

Button(g, "Rejoin Server", function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end)
Button(g, "Unload", function()
    for _, plr in ipairs(Players:GetPlayers()) do killEsp(plr) end
    for p, old in pairs(trafficCache) do
        if p and p.Parent then p.CanCollide = old[1]; p.Transparency = old[2] end
    end
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

-- ---------------- Inspector ----------------
L, R = makeSub("Settings", "Inspector")

g = Group(L, "what the script found")
local inspectHolder = Row(g, 250, "inspector output")
local inspectBox = new("ScrollingFrame", {
    Parent = inspectHolder,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, { corner(4), new("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

local inspectText = label({
    Parent = inspectBox,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Font = Enum.Font.Code,
    TextSize = 11.5,
    TextColor3 = T.DIM,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "Press Scan.",
})

g = Group(R, "inspector")
Button(g, "Scan Game", function()
    inspectText.Text = inspectReport()
    toast("Scan complete", T.OK)
end)
Button(g, "Copy Report", function()
    if type(setclipboard) == "function" then
        pcall(setclipboard, inspectReport())
        toast("Report copied \u{2014} paste it to me", T.OK)
    end
end)

label({
    Parent = Row(g, 60, "inspector help"),
    Size = UDim2.new(1, 0, 1, 0),
    TextSize = 11.5,
    TextColor3 = T.FAINT,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "Sit in a car, press Scan, then Copy Report. That tells us the real "
        .. "names this game uses so the stat and traffic lookups can be exact.",
})

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
-- live readouts
-- ================================================================
task.spawn(function()
    while gui.Parent do
        task.wait(0.5)

        local veh, seat = vehicleOf()
        vehName.Text = veh and veh.Name or "not seated"
        vehSeat.Text = seat and seat.ClassName or "-"
        vehSpeed.Text = mphOf(LP) .. " mph"

        stTime.Text = clockText(sessionSeconds())
        stDist.Text = string.format("%.2f mi", milesDriven())
        stTop.Text = SESSION.topSpeed .. " mph"
        stEarned.Text = "$" .. comma(cashGained())
        stLevelUps.Text = tostring(SESSION.levelUps)

        stCash.Text = statText(LP, "cash") and ("$" .. statText(LP, "cash")) or "not found"
        stLevel.Text = statText(LP, "level") or "not found"
        stRank.Text = statText(LP, "rank") or "not found"
        stXp.Text = statText(LP, "xp") or "not found"
    end
end)

-- ================================================================
-- input
-- ================================================================
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

selectCat("Driving")

win.Size = UDim2.fromOffset(W, 0)
tween(win, 0.36, { Size = UDim2.fromOffset(W, H) }, EASE)

task.delay(0.5, function()
    toast(CFG.Script .. " loaded  \u{00B7}  " .. CFG.Toggle.Name .. " to hide", T.RED)
end)
