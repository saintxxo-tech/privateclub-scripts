--[[ ================================================================
     privateclub.cc  ·  bridge duels
     ----------------------------------------------------------------
     Right Ctrl hides the menu.

     HOW THE BRIDGING WORKS, because it matters
     ------------------------------------------
     Bridge Duels sends block placement through a Blink buffer on
     ReplicatedStorage.BLINK_RELIABLE_REMOTE. A Blink buffer is a
     packed binary layout, not a readable argument list, so rather
     than guess the whole schema this script captures one real
     placement of yours and reuses it as a template: it finds the
     three f32s holding the block position, then rewrites only those
     and resends the rest of the bytes untouched.

     So: open Bridge -> Capture, place one block by hand, and the
     script learns the packet. Everything else works off that.
     ================================================================ ]]

local CFG = {
    Brand   = "privateclub",
    Brand2  = "hub",
    Script  = "Bridge Duels",
    Version = "v1.0",
    Toggle  = Enum.KeyCode.RightControl,
    LibUrl  = "https://raw.githubusercontent.com/saintxxo-tech/privateclub-scripts/main/",
    Remote  = "BLINK_RELIABLE_REMOTE",
}

-- ================================================================
-- services
-- ================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RepStorage       = game:GetService("ReplicatedStorage")
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
if ENV.__pc_bridge then pcall(function() ENV.__pc_bridge:Destroy() end) end

local gui = new("ScreenGui", {
    Name = "\u{200B}pcb" .. tostring(math.random(100000, 999999)),
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 995,
})
ENV.__pc_bridge = gui

do
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    local ok = pcall(function()
        gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end

local V
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(CFG.LibUrl .. "lib/visuals.lua?t=" .. os.time()))()
    end)
    if ok and type(mod) == "table" then V = mod end
end

-- ================================================================
-- state
-- ================================================================
local S = {
    -- aimbot
    aimbot = false, aimPart = "Head", aimKey = "Right Mouse",
    aimFov = 200, aimSmooth = 14, aimVert = 14,
    aimWall = true, aimDead = false, aimLock = false,
    predict = false, predictAmount = 12,
    fovShow = true, fovFilled = false, fovThick = 1,

    -- reach / hit
    hitboxOn = false, hitboxSize = 6, reachOn = false, reachStuds = 14,
    autoClick = false, clickCps = 12,

    -- bridging
    bridgeOn = false, bridgeMode = "Forward", bridgeGrid = 3,
    bridgeRate = 14, bridgeAhead = 1, bridgeDrop = 1,
    bridgeSide = 0, towerOn = false, scaffold = false,
    captureArmed = false,

    -- apples
    appleOn = false, appleAt = 60, appleRate = 1.2,

    -- esp
    espOn = true, espBox = true, espName = true, espHealth = true,
    espDistance = true, espTracer = false, espChams = false,
    espGlow = false, espNeon = false, espRainbow = false,
    espMaxDist = 3000, espTextSize = 14, espRefresh = 60,

    -- movement
    walkOn = false, walkSpeed = 16, jumpOn = false, jumpPower = 50,
    infJump = false, noclip = false, fly = false, flySpeed = 60, bhop = false,
    noFall = false,

    -- effects
    shader = "Off", skybox = "Default", fullbright = false,

    -- packets
    logPackets = false,
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
    task.delay(3, function()
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
local function heldTool()
    local c = character()
    return c and c:FindFirstChildOfClass("Tool")
end

local function alive(plr)
    local c = plr.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return c ~= nil and hum ~= nil and hum.Health > 0
end

local function friendly(plr)
    if not LP.Team or not plr.Team then return false end
    return LP.Team == plr.Team
end

local function centre()
    return Vector2.new(CAM.ViewportSize.X / 2, CAM.ViewportSize.Y / 2)
end

-- ================================================================
-- targeting
-- ================================================================
local function partOf(plr, which)
    local c = plr.Character
    if not c then return nil end
    if which == "Torso" then
        return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head")
    end
    return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
end

local function canSee(part)
    if not S.aimWall then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character() }
    local from = CAM.CFrame.Position
    local res = workspace:Raycast(from, part.Position - from, params)
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

local function predicted(part)
    if not S.predict then return part.Position end
    return part.Position + part.AssemblyLinearVelocity * (S.predictAmount / 100)
end

local function bestTarget(which)
    local best, bestD
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and (S.aimDead or alive(plr)) and not friendly(plr) then
            local part = partOf(plr, which or S.aimPart)
            if part then
                local pos, on = CAM:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(pos.X, pos.Y) - centre()).Magnitude
                    if d <= S.aimFov and (not bestD or d < bestD) and canSee(part) then
                        best, bestD = part, d
                    end
                end
            end
        end
    end
    return best
end

-- ================================================================
-- aim key
-- ================================================================
local AIM_KEYS = {
    ["Right Mouse"] = Enum.UserInputType.MouseButton2,
    ["Left Mouse"]  = Enum.UserInputType.MouseButton1,
    ["Q"] = Enum.KeyCode.Q, ["E"] = Enum.KeyCode.E,
    ["V"] = Enum.KeyCode.V, ["C"] = Enum.KeyCode.C,
}

local holding = false
local lockedTarget

UserInputService.InputBegan:Connect(function(i, typing)
    if typing then return end
    local want = AIM_KEYS[S.aimKey]
    if want and (i.UserInputType == want or i.KeyCode == want) then
        holding = true
        if S.aimLock then
            local t = bestTarget()
            lockedTarget = t and t.Parent or nil
        end
    end
end)
UserInputService.InputEnded:Connect(function(i)
    local want = AIM_KEYS[S.aimKey]
    if want and (i.UserInputType == want or i.KeyCode == want) then
        holding = false
        lockedTarget = nil
    end
end)

local function aimingNow()
    return S.aimKey == "Always" or holding
end

-- resolve the part we should be looking at this frame
local function aimPartNow()
    if S.aimLock and lockedTarget and lockedTarget.Parent then
        local hum = lockedTarget:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            return lockedTarget:FindFirstChild(
                S.aimPart == "Torso" and "HumanoidRootPart" or "Head")
                or lockedTarget:FindFirstChild("HumanoidRootPart")
        end
        lockedTarget = nil
    end
    return bestTarget()
end

-- ================================================================
-- fov ring + camera aim
-- ----------------------------------------------------------------
-- Horizontal and vertical smoothing are separate on purpose: bridge
-- fights are mostly side to side, so you usually want the yaw to
-- track faster than the pitch.
-- ================================================================
local hasDrawing = pcall(function() return Drawing.new("Square"):Remove() end)

local function drawing(class, props)
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props or {}) do d[k] = v end
    return d
end

local fovRing = drawing("Circle", {
    Thickness = 1, NumSides = 64, Filled = false, Visible = false, Transparency = 0.9,
})

RunService.RenderStepped:Connect(function(dt)
    if fovRing then
        if S.fovShow then
            fovRing.Visible = true
            fovRing.Color = T.RED
            fovRing.Filled = S.fovFilled
            fovRing.Transparency = S.fovFilled and 0.12 or 0.9
            fovRing.Thickness = S.fovThick
            fovRing.Radius = S.aimFov
            fovRing.Position = centre()
        else
            fovRing.Visible = false
        end
    end

    if not S.aimbot or not aimingNow() then return end
    local t = aimPartNow()
    if not t then return end

    local here = CAM.CFrame
    local goal = CFrame.lookAt(here.Position, predicted(t))

    -- split the lerp so yaw and pitch can move at different speeds
    local yaw = here:Lerp(goal, math.clamp(dt * (S.aimSmooth / 2), 0, 1))
    local pitch = here:Lerp(goal, math.clamp(dt * (S.aimVert / 2), 0, 1))
    local ry = select(2, yaw:ToOrientation())
    local rx = select(1, pitch:ToOrientation())

    CAM.CFrame = CFrame.new(here.Position) * CFrame.fromOrientation(rx, ry, 0)
end)

-- ================================================================
-- reach + hitbox
-- ================================================================
local hitboxCache = {}

task.spawn(function()
    while gui.Parent do
        task.wait(0.3)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if S.hitboxOn and not friendly(plr) then
                        if not hitboxCache[hrp] then hitboxCache[hrp] = hrp.Size end
                        hrp.Size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize)
                        hrp.Transparency = 0.75
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

-- sword reach, where the game reads it off the tool
task.spawn(function()
    while gui.Parent do
        task.wait(0.25)
        if S.reachOn then
            local tool = heldTool()
            if tool then
                for _, d in ipairs(tool:GetDescendants()) do
                    if d:IsA("ValueBase") and typeof(d.Value) == "number" then
                        local n = d.Name:lower()
                        if n:find("range", 1, true) or n:find("reach", 1, true)
                        or n:find("distance", 1, true) then
                            d.Value = S.reachStuds
                        end
                    end
                end
                local ok, attrs = pcall(function() return tool:GetAttributes() end)
                if ok and type(attrs) == "table" then
                    for name, v in pairs(attrs) do
                        if typeof(v) == "number" then
                            local n = name:lower()
                            if n:find("range", 1, true) or n:find("reach", 1, true) then
                                pcall(function() tool:SetAttribute(name, S.reachStuds) end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- autoclicker, for swords the game drives off Tool.Activated
task.spawn(function()
    local VIM = game:GetService("VirtualInputManager")
    while gui.Parent do
        task.wait(1 / math.clamp(S.clickCps, 1, 30))
        if S.autoClick and holding then
            local tool = heldTool()
            if tool then pcall(function() tool:Activate() end) end
            local m = UserInputService:GetMouseLocation()
            pcall(function()
                VIM:SendMouseButtonEvent(m.X, m.Y, 0, true, game, 0)
                VIM:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 0)
            end)
        end
    end
end)

-- ================================================================
-- gold apples
-- ----------------------------------------------------------------
-- Straight from the captured call:
--   Character.GoldApple.__comm__.RF.Eat:InvokeServer(true, serverTime)
-- The timestamp is server time, so take it live rather than reusing
-- the captured number.
-- ================================================================
local function appleRemote()
    local c = character()
    if not c then return nil end
    local apple = c:FindFirstChild("GoldApple")
    if not apple then return nil end
    local comm = apple:FindFirstChild("__comm__")
    local rf = comm and comm:FindFirstChild("RF")
    local eat = rf and rf:FindFirstChild("Eat")
    if eat and eat:IsA("RemoteFunction") then return eat end
    return nil
end

local function eatApple()
    local remote = appleRemote()
    if not remote then return false, "no GoldApple equipped" end
    local ok, err = pcall(function()
        remote:InvokeServer(true, workspace:GetServerTimeNow())
    end)
    return ok, ok and "eaten" or tostring(err)
end

task.spawn(function()
    while gui.Parent do
        task.wait(math.clamp(S.appleRate, 0.2, 10))
        if S.appleOn then
            local h = humanoid()
            if h and h.Health > 0 then
                local pct = h.Health / math.max(h.MaxHealth, 1) * 100
                if pct <= S.appleAt then eatApple() end
            end
        end
    end
end)

-- ================================================================
-- the blink packet layer
-- ----------------------------------------------------------------
-- A Blink buffer is packed binary, so instead of rebuilding the
-- schema we keep one real packet of yours and rewrite only the three
-- f32s that hold the position. findPos locates them by checking
-- every offset for a triplet that lands near where you were standing
-- when the packet went out.
-- ================================================================
local PK = {
    remote   = RepStorage:FindFirstChild(CFG.Remote),
    template = nil,   -- { bytes = {}, extra = {}, offset = n, id = n }
    captures = {},    -- recent packets, newest first
    seenIds  = {},
    sent     = 0,
}

if not PK.remote then
    task.spawn(function()
        local found = RepStorage:WaitForChild(CFG.Remote, 20)
        PK.remote = found
    end)
end

local function bytesOf(buf)
    local out = {}
    local len = buffer.len(buf)
    for i = 0, len - 1 do out[i + 1] = buffer.readu8(buf, i) end
    return out
end

local function bufferOf(bytes)
    local b = buffer.create(#bytes)
    for i = 1, #bytes do buffer.writeu8(b, i - 1, bytes[i]) end
    return b
end

local function hexOf(bytes, limit)
    local out = {}
    for i = 1, math.min(#bytes, limit or 48) do
        out[i] = string.format("%02X", bytes[i])
    end
    return table.concat(out, " ") .. (#bytes > (limit or 48) and " .." or "")
end

-- read an f32 triplet at a byte offset, 1-based byte list
local function tripletAt(bytes, off)
    if off + 11 > #bytes then return nil end
    local b = buffer.create(12)
    for i = 0, 11 do buffer.writeu8(b, i, bytes[off + i]) end
    return Vector3.new(buffer.readf32(b, 0), buffer.readf32(b, 4), buffer.readf32(b, 8))
end

-- which offset holds a position near `nearPos`
local function findPos(bytes, nearPos, radius)
    radius = radius or 40
    for off = 1, #bytes - 11 do
        local v = tripletAt(bytes, off)
        if v and v.Magnitude < 1e5
           and v.X == v.X and v.Y == v.Y and v.Z == v.Z
           and (v - nearPos).Magnitude <= radius then
            return off, v
        end
    end
    return nil
end

local function writeTriplet(bytes, off, v)
    local b = buffer.create(12)
    buffer.writef32(b, 0, v.X)
    buffer.writef32(b, 4, v.Y)
    buffer.writef32(b, 8, v.Z)
    for i = 0, 11 do bytes[off + i] = buffer.readu8(b, i) end
end

-- deep copy of the argument list, so resends cannot be mutated
local function copyArgs(args)
    local out = {}
    for i, v in ipairs(args) do
        if type(v) == "table" then
            local t = {}
            for k, vv in pairs(v) do t[k] = vv end
            out[i] = t
        else
            out[i] = v
        end
    end
    return out
end

local onCapture   -- set once the UI exists
local function capture(bytes, extra)
    local id = bytes[1] or -1
    local rec = {
        bytes = bytes, extra = extra, id = id,
        len = #bytes, at = os.clock(),
        pos = root() and findPos(bytes, root().Position, 60) or nil,
    }
    table.insert(PK.captures, 1, rec)
    if #PK.captures > 40 then table.remove(PK.captures) end
    PK.seenIds[id] = (PK.seenIds[id] or 0) + 1
    if onCapture then onCapture(rec) end
end

-- the hook. Blink sends one buffer plus whatever else the event
-- carries, so keep every argument and only ever rewrite the buffer.
do
    local hook = rawget(getfenv(), "hookmetamethod")
    local getMethod = rawget(getfenv(), "getnamecallmethod")
    if type(hook) == "function" and type(getMethod) == "function" then
        local old
        old = hook(game, "__namecall", function(self, ...)
            local method = getMethod()
            if (method == "FireServer" or method == "InvokeServer")
               and typeof(self) == "Instance" and self.Name == CFG.Remote then
                local args = { ... }
                if typeof(args[1]) == "buffer" then
                    local bytes = bytesOf(args[1])
                    local extra = {}
                    for i = 2, #args do extra[i - 1] = args[i] end
                    if S.logPackets or S.captureArmed then
                        pcall(capture, bytes, copyArgs(extra))
                    end
                end
            end
            return old(self, ...)
        end)
    end
end

local function placeAt(pos)
    local tpl = PK.template
    if not tpl then return false, "no template captured yet" end
    if not PK.remote then return false, "remote not found" end

    local bytes = {}
    for i, b in ipairs(tpl.bytes) do bytes[i] = b end
    writeTriplet(bytes, tpl.offset, pos)

    local ok = pcall(function()
        PK.remote:FireServer(bufferOf(bytes), unpack(copyArgs(tpl.extra)))
    end)
    if ok then PK.sent = PK.sent + 1 end
    return ok
end

-- ================================================================
-- bridging
-- ----------------------------------------------------------------
-- Grid size is a slider because it is the one number that has to
-- match the game's block size exactly, and a wrong guess just makes
-- every placement land in the wrong cell.
-- ================================================================
local function snap(v, grid)
    return Vector3.new(
        math.floor(v.X / grid + 0.5) * grid,
        math.floor(v.Y / grid + 0.5) * grid,
        math.floor(v.Z / grid + 0.5) * grid)
end

local function flatLook()
    local l = CAM.CFrame.LookVector
    local f = Vector3.new(l.X, 0, l.Z)
    return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
end

-- where the next block goes, per mode
local function nextCell()
    local r = root()
    if not r then return nil end
    local g = math.max(S.bridgeGrid, 0.5)
    local look = flatLook()
    local right = Vector3.new(-look.Z, 0, look.X)
    local base = r.Position - Vector3.new(0, S.bridgeDrop * g, 0)

    local ahead = look * (S.bridgeAhead * g)
    local side = right * (S.bridgeSide * g)

    if S.bridgeMode == "Forward" then
        return snap(base + ahead + side, g)

    elseif S.bridgeMode == "Behind" then
        -- the classic: lay the block you just walked off
        return snap(base - ahead + side, g)

    elseif S.bridgeMode == "Diagonal" then
        return snap(base + ahead + right * g, g)

    elseif S.bridgeMode == "Under" then
        return snap(base + side, g)

    elseif S.bridgeMode == "Tower" then
        return snap(r.Position - Vector3.new(0, g, 0), g)
    end

    return snap(base + ahead, g)
end

local lastCell
task.spawn(function()
    while gui.Parent do
        task.wait(1 / math.clamp(S.bridgeRate, 1, 40))
        if S.bridgeOn and PK.template then
            local cell = nextCell()
            if cell then
                -- do not spam the same cell; the server will ignore it
                -- and it only burns rate
                if not lastCell or (cell - lastCell).Magnitude > 0.1 then
                    placeAt(cell)
                    lastCell = cell
                end
            end
        end
    end
end)

-- tower: hold space and keep stacking under yourself
task.spawn(function()
    while gui.Parent do
        task.wait(0.08)
        if S.towerOn and PK.template then
            local r, h = root(), humanoid()
            if r and h then
                local g = math.max(S.bridgeGrid, 0.5)
                h:ChangeState(Enum.HumanoidStateType.Jumping)
                placeAt(snap(r.Position - Vector3.new(0, g, 0), g))
            end
        end
    end
end)

-- scaffold: only place when there is nothing beneath you
task.spawn(function()
    while gui.Parent do
        task.wait(0.06)
        if S.scaffold and PK.template then
            local r = root()
            if r then
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = { character() }
                local hit = workspace:Raycast(r.Position, Vector3.new(0, -6, 0), params)
                if not hit then
                    local g = math.max(S.bridgeGrid, 0.5)
                    placeAt(snap(r.Position - Vector3.new(0, g, 0), g))
                end
            end
        end
    end
end)

-- ================================================================
-- ESP
-- ================================================================
local esp = {}

local function buildEsp()
    if not hasDrawing then return nil end
    return {
        box    = drawing("Square", { Thickness = 1, Filled = false, Visible = false }),
        hpBack = drawing("Line", { Thickness = 3, Visible = false, Color = Color3.new(0, 0, 0) }),
        hpBar  = drawing("Line", { Thickness = 1, Visible = false }),
        name   = drawing("Text", { Size = 14, Center = true, Outline = true, Visible = false }),
        info   = drawing("Text", { Size = 12, Center = true, Outline = true, Visible = false }),
        line   = drawing("Line", { Thickness = 1, Visible = false }),
    }
end

local function hideEsp(o)
    if not o then return end
    for _, d in pairs(o) do d.Visible = false end
end

local function espColour(plr)
    if S.espRainbow and V then return V.rainbow() end
    if friendly(plr) then return T.OK end
    return T.RED
end

local function killEsp(plr)
    local o = esp[plr]
    if o then
        for _, d in pairs(o) do pcall(function() d:Remove() end) end
        esp[plr] = nil
    end
    local c = plr.Character
    if c then
        for _, n in ipairs({ "pc_cham", "pc_glow" }) do
            local x = c:FindFirstChild(n)
            if x then x:Destroy() end
        end
    end
end

Players.PlayerRemoving:Connect(killEsp)

local function chams(plr, colour, show)
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
    hl.FillColor = colour
    hl.OutlineColor = colour
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
            local c = plr.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local show = S.espOn
            local colour = espColour(plr)

            chams(plr, colour, show)
            if V then
                V.glow(c, colour, {
                    enabled = S.espOn and S.espGlow and show,
                    rainbow = S.espRainbow,
                    fill = 0.55, outline = 0,
                })
                V.neon(c, colour, S.espOn and S.espNeon and show)
            end

            if not show or not hrp or not hum or hum.Health <= 0 then
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
                                math.floor(255 * (1 - frac)),
                                math.floor(200 * frac + 40), 60)
                            o.hpBar.From = Vector2.new(bx, y + h)
                            o.hpBar.To = Vector2.new(bx, y + h - h * frac)
                        end

                        o.name.Visible = S.espName
                        if S.espName then
                            o.name.Color = colour
                            o.name.Size = S.espTextSize
                            o.name.Text = plr.DisplayName
                            o.name.Position = Vector2.new(pos.X, y - S.espTextSize - 4)
                        end

                        o.info.Visible = S.espDistance
                        if S.espDistance then
                            o.info.Color = colour
                            o.info.Size = S.espTextSize - 2
                            o.info.Text = dist .. "m  " .. math.floor(hum.Health) .. "hp"
                            o.info.Position = Vector2.new(pos.X, y + h + 3)
                        end

                        o.line.Visible = S.espTracer
                        if S.espTracer then
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
end)

-- ================================================================
-- movement
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

RunService.RenderStepped:Connect(function()
    if not S.fly then return end
    local r = root()
    if not r or not flyBV then return end
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
end)

RunService.Heartbeat:Connect(function()
    local h = humanoid()
    if h then
        if S.walkOn then h.WalkSpeed = S.walkSpeed end
        if S.jumpOn then h.UseJumpPower = true; h.JumpPower = S.jumpPower end
        if S.bhop and UserInputService:IsKeyDown(Enum.KeyCode.Space)
           and h.FloorMaterial ~= Enum.Material.Air then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    if S.noclip then
        local c = character()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end

    if S.noFall then
        local r = root()
        if r and r.AssemblyLinearVelocity.Y < -40 then
            r.AssemblyLinearVelocity = Vector3.new(
                r.AssemblyLinearVelocity.X, -40, r.AssemblyLinearVelocity.Z)
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if not S.infJump then return end
    local h = humanoid()
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ================================================================
-- inspector
-- ================================================================
local function inspectReport()
    local lines = {}
    local tool = heldTool()
    local c = character()

    table.insert(lines, "place id        " .. game.PlaceId)
    table.insert(lines, "team            " .. (LP.Team and LP.Team.Name or "none"))
    table.insert(lines, "held tool       " .. (tool and tool.Name or "nothing equipped"))
    table.insert(lines, "blink remote    " .. (PK.remote and "found" or "MISSING"))
    table.insert(lines, "template        " ..
        (PK.template and ("id " .. PK.template.id .. ", " .. #PK.template.bytes
            .. " bytes, pos at offset " .. PK.template.offset) or "not captured"))
    table.insert(lines, "packets sent    " .. PK.sent)
    table.insert(lines, "drawing api     " .. tostring(hasDrawing))
    table.insert(lines, "visuals lib     " .. tostring(V ~= nil))
    table.insert(lines, "gold apple      " .. (appleRemote() and "found" or "not equipped"))

    local ids = {}
    for id, n in pairs(PK.seenIds) do table.insert(ids, id .. "x" .. n) end
    table.insert(lines, "blink event ids " ..
        (#ids > 0 and table.concat(ids, ", ") or "none seen yet"))

    if c then
        local kids = {}
        for _, d in ipairs(c:GetChildren()) do
            if not d:IsA("BasePart") and not d:IsA("Humanoid")
            and not d:IsA("Accessory") and not d:IsA("Shirt")
            and not d:IsA("Pants") and not d:IsA("BodyColors") then
                table.insert(kids, d.Name .. " (" .. d.ClassName .. ")")
            end
        end
        table.insert(lines, "character kids  " .. table.concat(kids, ", "))
    end

    if tool then
        local vals = {}
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("ValueBase") then
                table.insert(vals, d.Name .. "=" .. tostring(d.Value))
            end
        end
        table.insert(lines, "tool values     " ..
            (#vals > 0 and table.concat(vals, ", ") or "none"))
    end

    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        local names = {}
        for _, v in ipairs(ls:GetChildren()) do
            table.insert(names, v.Name .. "=" .. tostring(v.Value))
        end
        table.insert(lines, "leaderstats     " .. table.concat(names, ", "))
    end

    table.insert(lines, "")
    table.insert(lines, "-- recent blink packets --")
    for i = 1, math.min(#PK.captures, 12) do
        local rec = PK.captures[i]
        table.insert(lines, "id " .. rec.id .. "  len " .. rec.len
            .. (rec.pos and ("  pos@" .. rec.pos) or "  pos@?")
            .. "  " .. hexOf(rec.bytes, 32))
    end

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

local pingLabel = label({
    Parent = titleBar,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -52, 0.5, 0),
    Size = UDim2.fromOffset(300, 18),
    Font = Enum.Font.Code,
    TextSize = 11,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Right,
    RichText = true,
    Text = "",
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

local function Note(g, text, colour)
    label({
        Parent = Row(g, 56, text),
        Size = UDim2.fromScale(1, 1),
        TextSize = 11.5,
        TextColor3 = colour or T.FAINT,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = text,
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

addCat("Bridge",   { "Auto Bridge", "Capture" })
addCat("Combat",   { "Aimbot", "Reach" })
addCat("Visuals",  { "ESP", "Effects" })
addCat("Movement", { "Main" })
addCat("Players",  { "List" })
addCat("Settings", { "Menu", "Inspector" })

-- ================================================================
-- BRIDGE
-- ================================================================
local L, R = makeSub("Bridge", "Auto Bridge")

local tplLabel
local g = Group(L, "auto bridge")
Toggle(g, "Enabled", "bridgeOn", {
    desc = "Needs a captured packet first \u{2014} see the Capture tab",
    callback = function(on)
        if on and not PK.template then
            toast("Capture a block placement first", T.ERR)
        else
            toast(on and "Auto bridge on" or "Auto bridge off", on and T.OK or T.DIM)
        end
    end })
Dropdown(g, "Mode", "bridgeMode",
    { "Forward", "Behind", "Diagonal", "Under", "Tower" })
Slider(g, "Blocks per second", "bridgeRate", 1, 40)
Note(g, "Behind lays the block you just walked off, which is what you want "
      .. "for a normal speed bridge. Diagonal offsets one cell sideways for "
      .. "god bridging. Under fills the cell you are standing in.")

g = Group(L, "geometry")
Slider(g, "Block size", "bridgeGrid", 1, 12, "studs")
Slider(g, "Blocks ahead", "bridgeAhead", 0, 4)
Slider(g, "Blocks below", "bridgeDrop", 0, 3)
Slider(g, "Side offset", "bridgeSide", -3, 3)
Note(g, "Block size has to match the game exactly or every placement lands "
      .. "in the wrong cell. Capture a placement and the Capture tab will "
      .. "tell you the size it measured.", T.GOLD)

g = Group(R, "extras")
Toggle(g, "Tower", "towerOn", {
    desc = "Jumps and stacks a block under you on a loop" })
Toggle(g, "Scaffold", "scaffold", {
    desc = "Only places when a raycast finds nothing beneath you" })

g = Group(R, "gold apples")
Toggle(g, "Auto eat", "appleOn", {
    desc = "Uses the Eat remote on the apple in your character" })
Slider(g, "Eat below", "appleAt", 10, 100, "% hp")
Slider(g, "Check every", "appleRate", 0.2, 5, "s")
Button(g, "Eat one now", function()
    local ok, why = eatApple()
    toast(tostring(why), ok and T.OK or T.ERR)
end)

-- ---------------- Capture ----------------
L, R = makeSub("Bridge", "Capture")

g = Group(L, "teach the script")
Note(g, "1. Press Arm below.\n"
      .. "2. Go place one block by hand, the normal way.\n"
      .. "3. The script grabs that packet and reuses it as a template, "
      .. "rewriting only the position bytes.\n"
      .. "Recapture whenever you switch block type.", T.TXT)
Button(g, "Arm capture", function()
    S.captureArmed = true
    PK.template = nil
    toast("Armed \u{2014} place one block now", T.GOLD)
end)
Button(g, "Clear template", function()
    PK.template = nil
    S.bridgeOn = false
    if tplLabel then tplLabel.Text = "no template" end
    toast("Template cleared", T.DIM)
end)
Button(g, "Test place in front", function()
    local cell = nextCell()
    if not cell then toast("No character", T.ERR); return end
    local ok, why = placeAt(cell)
    toast(ok and ("Sent to " .. tostring(cell)) or tostring(why), ok and T.OK or T.ERR)
end)

g = Group(L, "template")
local tplRow = Row(g, 76, "template status")
tplLabel = label({
    Parent = tplRow,
    Size = UDim2.fromScale(1, 1),
    Font = Enum.Font.Code,
    TextSize = 11.5,
    TextColor3 = T.DIM,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "no template",
})

g = Group(R, "packet log")
Toggle(g, "Log blink packets", "logPackets", {
    desc = "Records every buffer the game sends on " .. CFG.Remote })
local logRow = Row(g, 240, "packet log output")
local logBox = new("ScrollingFrame", {
    Parent = logRow,
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

local logText = label({
    Parent = logBox,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Font = Enum.Font.Code,
    TextSize = 11,
    TextColor3 = T.DIM,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Text = "nothing captured yet",
})

Button(g, "Copy packet log", function()
    if type(setclipboard) ~= "function" then
        toast("No clipboard on this executor", T.ERR); return
    end
    local out = {}
    for i, rec in ipairs(PK.captures) do
        out[i] = "id " .. rec.id .. "  len " .. rec.len
            .. (rec.pos and ("  pos@" .. rec.pos) or "  pos@?")
            .. "  " .. hexOf(rec.bytes, 64)
    end
    pcall(setclipboard, table.concat(out, "\n"))
    toast("Packet log copied \u{2014} paste it back to me", T.OK)
end)
Button(g, "Clear log", function()
    PK.captures = {}
    logText.Text = "nothing captured yet"
end)

-- a capture arrives: fill the log, and claim the template if armed
onCapture = function(rec)
    if S.captureArmed and rec.pos then
        local r = root()
        PK.template = {
            bytes = rec.bytes, extra = rec.extra,
            offset = rec.pos, id = rec.id,
        }
        S.captureArmed = false

        local placed = tripletAt(rec.bytes, rec.pos)
        local guess = ""
        if placed and r then
            -- the placed cell is grid aligned, so its coordinates are
            -- multiples of the block size: the gcd of the non-zero
            -- components is a decent first guess
            local function gcd(a, b)
                a, b = math.abs(a), math.abs(b)
                while b > 0.01 do a, b = b, a % b end
                return a
            end
            local size = gcd(gcd(placed.X, placed.Y), placed.Z)
            if size >= 0.5 and size <= 12 then
                S.bridgeGrid = math.floor(size * 10 + 0.5) / 10
                guess = "\nblock size looks like " .. S.bridgeGrid .. " studs"
            end
        end

        tplLabel.Text = "captured  event id " .. rec.id
            .. "\n" .. rec.len .. " bytes, position at offset " .. rec.pos
            .. "\nplaced at " .. tostring(placed)
            .. "\n" .. #rec.extra .. " extra argument(s)" .. guess
        toast("Template captured \u{2014} auto bridge is ready", T.OK)

    elseif S.captureArmed then
        tplLabel.Text = "saw a packet (id " .. rec.id .. ", " .. rec.len
            .. " bytes) but found no position near you.\n"
            .. "Try again standing right next to the block you place."
    end

    if S.logPackets then
        local out = {}
        for i = 1, math.min(#PK.captures, 14) do
            local c = PK.captures[i]
            out[i] = "id " .. c.id .. "  len " .. c.len
                .. (c.pos and ("  pos@" .. c.pos) or "  pos@?")
                .. "\n  " .. hexOf(c.bytes, 28)
        end
        logText.Text = table.concat(out, "\n")
    end
end

-- ================================================================
-- COMBAT
-- ================================================================
L, R = makeSub("Combat", "Aimbot")

g = Group(L, "aimbot")
Toggle(g, "Enabled", "aimbot", {
    desc = "Eases the camera onto the nearest target while you hold the aim key",
    callback = function(on)
        toast(on and "Aimbot armed" or "Aimbot off", on and T.OK or T.DIM)
    end })
Dropdown(g, "Target part", "aimPart", { "Head", "Torso" })
Dropdown(g, "Hold to aim", "aimKey",
    { "Right Mouse", "Left Mouse", "Q", "E", "V", "C", "Always" })
Slider(g, "Aim FOV", "aimFov", 20, 800, "px")

g = Group(L, "smoothing")
Slider(g, "Horizontal", "aimSmooth", 1, 40)
Slider(g, "Vertical", "aimVert", 1, 40)
Note(g, "Low is slow and smooth, high snaps. Yaw and pitch are separate "
      .. "because bridge fights are mostly side to side, so most people "
      .. "want horizontal faster than vertical.")

g = Group(R, "targeting")
Toggle(g, "Wall check", "aimWall")
Toggle(g, "Target downed players", "aimDead")
Toggle(g, "Lock to first target", "aimLock", {
    desc = "Sticks to whoever you locked on rather than swapping mid fight" })
Toggle(g, "Lead moving targets", "predict")
Slider(g, "Lead amount", "predictAmount", 1, 60)

g = Group(R, "fov circle")
Toggle(g, "Show FOV", "fovShow")
Toggle(g, "Filled", "fovFilled")
Slider(g, "Thickness", "fovThick", 1, 6)

-- ---------------- Reach ----------------
L, R = makeSub("Combat", "Reach")

g = Group(L, "melee")
Toggle(g, "Sword reach", "reachOn", {
    desc = "Rewrites range values on the tool you hold" })
Slider(g, "Reach", "reachStuds", 5, 40, "studs")
Toggle(g, "Autoclicker", "autoClick", {
    desc = "Clicks while you hold the aim key" })
Slider(g, "Clicks per second", "clickCps", 1, 30, "cps")

g = Group(R, "hitbox")
Toggle(g, "Hitbox expander", "hitboxOn")
Slider(g, "Hitbox size", "hitboxSize", 2, 30, "studs")
Note(g, "Reach and hitbox only land if the server trusts the client on hit "
      .. "distance. If neither does anything, the game is checking server "
      .. "side and no client script will change that.", T.GOLD)

-- ================================================================
-- VISUALS
-- ================================================================
L, R = makeSub("Visuals", "ESP")

g = Group(L, "player esp")
Toggle(g, "Enabled", "espOn")
Toggle(g, "Boxes", "espBox")
Toggle(g, "Names", "espName")
Toggle(g, "Health bars", "espHealth")
Toggle(g, "Distance and hp", "espDistance")
Toggle(g, "Tracers", "espTracer")

g = Group(L, "highlight")
Toggle(g, "Chams", "espChams")
Toggle(g, "Glow", "espGlow")
Toggle(g, "Neon bodies", "espNeon", {
    callback = function(on) if not on and V then V.clearNeon() end end })
Toggle(g, "Rainbow", "espRainbow")

g = Group(R, "options")
Slider(g, "Max distance", "espMaxDist", 200, 8000, "studs")
Slider(g, "Text size", "espTextSize", 9, 30)
Slider(g, "Refresh rate", "espRefresh", 10, 240, "hz")

if not hasDrawing then
    g = Group(R, "notice")
    Note(g, "This executor has no Drawing API, so boxes, names and tracers "
          .. "are unavailable. Chams and glow still work.", T.GOLD)
end

-- ---------------- Effects ----------------
L, R = makeSub("Visuals", "Effects")

if V then
    g = Group(L, "shaders")
    Dropdown(g, "Preset", "shader", V.Presets, function(name)
        local ok, why = V.applyPreset(name)
        toast(ok and ("Shader: " .. tostring(why)) or "Shader failed",
              ok and T.OK or T.ERR)
    end)
    Button(g, "Test shader", function()
        toast(V.testShader() and "Test applied, screen should be red"
            or "Could not add effects here", T.GOLD)
    end)

    g = Group(L, "lighting")
    Toggle(g, "Fullbright", "fullbright", {
        callback = function(on) V.fullbright(on) end })

    g = Group(R, "skybox")
    Dropdown(g, "Sky", "skybox", V.skyboxNames(), function(name)
        local ok, why = V.setSkybox(name)
        toast(ok and ("Skybox: " .. tostring(why)) or tostring(why),
              ok and T.OK or T.ERR)
    end)
    local skyBox = TextField(g, "custom skybox asset id")
    Button(g, "Apply custom sky", function()
        local ok, why = V.customSkybox(skyBox.Text)
        toast(tostring(why), ok and T.OK or T.ERR)
    end)
    Button(g, "Restore default sky", function()
        V.restoreSky()
        toast("Sky restored", T.DIM)
    end)
else
    g = Group(L, "unavailable")
    Note(g, "The shared visuals engine could not be downloaded, so shaders "
          .. "and skyboxes are unavailable here.", T.GOLD)
end

-- ================================================================
-- MOVEMENT
-- ================================================================
L, R = makeSub("Movement", "Main")

g = Group(L, "speed and jump")
Toggle(g, "Override walk speed", "walkOn")
Slider(g, "Walk speed", "walkSpeed", 16, 300, nil, function(v)
    local h = humanoid()
    if h and S.walkOn then h.WalkSpeed = v end
end)
Toggle(g, "Override jump power", "jumpOn")
Slider(g, "Jump power", "jumpPower", 50, 400)

g = Group(R, "traversal")
Toggle(g, "Infinite jump", "infJump")
Toggle(g, "Bunny hop", "bhop", { desc = "Auto jumps while you hold space" })
Toggle(g, "Clamp fall speed", "noFall", {
    desc = "Caps downward velocity, which saves a lot of void deaths" })
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
Slider(g, "Fly speed", "flySpeed", 20, 400)

g = Group(L, "character")
Button(g, "Respawn", function()
    local h = humanoid()
    if h then h.Health = 0 end
end)
Button(g, "Rejoin server", function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end)

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
local selInfo = label({
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
Button(g, "Teleport to", function()
    if not selectedPlayer then toast("Pick a player first", T.ERR); return end
    local t = selectedPlayer.Character
        and selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    local r = root()
    if t and r then r.CFrame = t.CFrame * CFrame.new(0, 0, 4)
    else toast("Can't reach them", T.ERR) end
end)
Button(g, "Copy user id", function()
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
        selInfo.Text = "-"
        selThumb.Image = ""
        return
    end
    selName.Text = selectedPlayer.DisplayName
    selThumb.Image = "rbxthumb://type=AvatarHeadShot&id="
        .. selectedPlayer.UserId .. "&w=150&h=150"
    local c = selectedPlayer.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    selInfo.Text = "@" .. selectedPlayer.Name
        .. "   \u{00B7}   " .. (selectedPlayer.Team and selectedPlayer.Team.Name or "no team")
        .. "   \u{00B7}   " .. (hum and math.floor(hum.Health) or 0) .. " hp"
end

local plrRows = {}
refreshPlayers = function()
    for _, row in ipairs(plrRows) do row:Destroy() end
    plrRows = {}
    for i, plr in ipairs(Players:GetPlayers()) do
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
            BackgroundColor3 = (plr == LP and T.GOLD)
                or (friendly(plr) and T.OK) or T.RED,
            BorderSizePixel = 0,
        }, { corner(999) })
        label({
            Parent = row,
            Position = UDim2.fromOffset(24, 0),
            Size = UDim2.new(1, -34, 1, 0),
            TextSize = 12.5,
            TextColor3 = plr == selectedPlayer and T.TXT or T.DIM,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = plr.Name .. (plr == LP and "  (you)" or ""),
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
-- SETTINGS
-- ================================================================
L, R = makeSub("Settings", "Menu")

g = Group(L, "menu")
local bindRow = Row(g, 62, "menu bind")
rowLabel(bindRow, "Menu bind")
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

Button(g, "Unload", function()
    for _, plr in ipairs(Players:GetPlayers()) do killEsp(plr) end
    if fovRing then pcall(function() fovRing:Remove() end) end
    for hrp, size in pairs(hitboxCache) do
        if hrp and hrp.Parent then hrp.Size = size; hrp.Transparency = 1 end
    end
    stopFly()
    if V then V.unload() end
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
local inspectHolder = Row(g, 290, "inspector output")
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
Button(g, "Scan game", function()
    inspectText.Text = inspectReport()
    toast("Scan complete", T.OK)
end)
Button(g, "Copy report", function()
    if type(setclipboard) == "function" then
        pcall(setclipboard, inspectReport())
        toast("Report copied \u{2014} paste it back to me", T.OK)
    end
end)
Note(g, "This dumps the Blink event ids it has seen, the captured template, "
      .. "what is inside your character and the held tool. Paste it back to "
      .. "me and I can target the real names instead of matching on "
      .. "guesses.")

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
    local frames, clock = 0, os.clock()
    RunService.RenderStepped:Connect(function() frames = frames + 1 end)
    while gui.Parent do
        task.wait(0.5)
        local now = os.clock()
        local fps = math.floor(frames / math.max(now - clock, 0.001) + 0.5)
        frames, clock = 0, now

        local ok, ping = pcall(function()
            return math.floor(game:GetService("Stats").Network
                .ServerStatsItem["Data Ping"]:GetValue() + 0.5)
        end)
        ping = ok and ping or 0

        local hex = (fps >= 50 and "#3ED598") or (fps >= 25 and "#FFB020") or "#FF4D6A"
        pingLabel.Text = "<font color='" .. hex .. "'>" .. fps .. "</font> fps"
            .. "   <font color='#FF2E43'>" .. ping .. "</font> ms"
            .. "   <font color='#5E5E6B'>" .. PK.sent .. " placed</font>"

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

selectCat("Bridge")

win.Size = UDim2.fromOffset(W, 0)
tween(win, 0.36, { Size = UDim2.fromOffset(W, H) }, EASE)

task.delay(0.5, function()
    toast(CFG.Script .. " loaded  \u{00B7}  " .. CFG.Toggle.Name .. " to hide", T.RED)
    task.wait(1.2)
    if not PK.remote then
        toast("Could not find " .. CFG.Remote .. " \u{2014} bridging is off", T.ERR)
    else
        toast("Open Bridge \u{2192} Capture and place one block", T.GOLD)
    end
end)
