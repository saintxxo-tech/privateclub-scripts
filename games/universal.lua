--[[ ================================================================
     privateclub.cc  ·  universal
     ----------------------------------------------------------------
     multi-window in-game menu, red/black. only PANEL opens by default;
     the top bar toggles the rest. Right Ctrl hides everything.
     ================================================================ ]]

local CFG = {
    Brand   = "privateclub.cc",
    Script  = "universal",
    Version = "v1.1",
    Toggle  = Enum.KeyCode.RightControl,
    SaveDir = "privateclub_configs",
}

-- ================================================================
-- services
-- ================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")
local StarterGui        = game:GetService("StarterGui")
local TeleportService   = game:GetService("TeleportService")
local Stats             = game:GetService("Stats")
local VirtualUser       = game:GetService("VirtualUser")

local LP  = Players.LocalPlayer
local CAM = workspace.CurrentCamera

-- ================================================================
-- theme
-- ================================================================
local T = {
    BG0   = Color3.fromHex("06060A"),
    BG1   = Color3.fromHex("0A0A0F"),
    BG2   = Color3.fromHex("101017"),
    LINE  = Color3.fromHex("1C1C24"),

    TXT   = Color3.fromHex("E8E8EE"),
    DIM   = Color3.fromHex("8E8E9A"),
    FAINT = Color3.fromHex("53535E"),

    RED   = Color3.fromHex("FF2E43"),
    RED2  = Color3.fromHex("B00C24"),
    GOLD  = Color3.fromHex("FFB020"),
    OK    = Color3.fromHex("3ED598"),
    ERR   = Color3.fromHex("FF4D6A"),
    ALLY  = Color3.fromHex("3ED598"),
    ENEMY = Color3.fromHex("FF2E43"),
    NEUTRAL = Color3.fromHex("E8E8EE"),
}

local RADIUS = 4
local ACCENTS = { "FF2E43", "FF6B2E", "FFB020", "3ED598", "3EA6D5", "9B5CFF" }

local EASE  = Enum.EasingStyle.Quint
local QUAD  = Enum.EasingStyle.Quad
local BACK  = Enum.EasingStyle.Back

local accented = {}
local function accent(inst, prop)
    table.insert(accented, { inst = inst, prop = prop })
    return inst
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

local function stroke(colour, trans)
    return new("UIStroke", {
        Color = colour or T.LINE,
        Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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
    p.TextSize       = p.TextSize or 12
    p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
    return new("TextLabel", p)
end

local function setAccent(colour)
    T.RED = colour
    T.ENEMY = colour
    for _, e in ipairs(accented) do
        if e.inst and e.inst.Parent then
            TweenService:Create(e.inst, TweenInfo.new(0.25), { [e.prop] = colour }):Play()
        end
    end
end

-- ================================================================
-- gui root
-- ================================================================
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__pc_uni then pcall(function() ENV.__pc_uni:Destroy() end) end

local gui = new("ScreenGui", {
    Name = "\u{200B}pcu" .. tostring(math.random(100000, 999999)),
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 998,
})
ENV.__pc_uni = gui

do
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    local mounted = pcall(function()
        gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
    if not mounted then gui.Parent = LP:WaitForChild("PlayerGui") end
end

-- ================================================================
-- state
-- ================================================================
local S = {
    -- movement
    walkSpeed = 16, walkSpeedOn = false,
    jumpPower = 50, jumpPowerOn = false,
    infJump = false, noclip = false,
    fly = false, flySpeed = 60,
    antiAfk = true, clickTp = false,

    -- esp
    espOn = false,
    espBox = true, espBoxStyle = "Corners", espFill = false,
    espHealth = true, espHealthText = false,
    espName = true, espDistance = true, espTool = false,
    espTracer = false, espTracerFrom = "Bottom",
    espSkeleton = false, espChams = false,
    espTeam = false, espArrows = false,
    espMaxDist = 2000, espTextSize = 13, espChamsFill = 60,

    -- visuals
    fullbright = false, noFog = false, xray = false, fov = 70,

    -- world
    gravity = 196, gravityOn = false,
    timeOfDay = 14, timeOn = false,

    -- ui
    watermark = true, notifications = true,
    accent = "FF2E43",
}

-- player marks: [player] = "ally" | "enemy"
local marks = {}
local function markColour(plr)
    local m = marks[plr]
    if m == "ally" then return T.ALLY end
    if m == "enemy" then return T.ENEMY end
    if S.espTeam and plr.Team == LP.Team then return T.ALLY end
    return T.NEUTRAL
end

-- ================================================================
-- toasts
-- ================================================================
local toastHolder = new("Frame", {
    Parent = gui,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -24, 1, -24),
    Size = UDim2.fromOffset(260, 260),
    BackgroundTransparency = 1,
}, {
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

local toastOrder = 0
local function toast(text, colour)
    if not S.notifications then return end
    toastOrder = toastOrder + 1

    local f = new("Frame", {
        Parent = toastHolder,
        LayoutOrder = toastOrder,
        Size = UDim2.fromOffset(0, 34),
        BackgroundColor3 = T.BG0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, { corner(RADIUS), stroke(T.LINE, 0.1) })

    new("Frame", {
        Parent = f,
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundColor3 = colour or T.RED,
        BorderSizePixel = 0,
    })

    label({
        Parent = f,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -20, 1, 0),
        TextSize = 11.5,
        TextColor3 = T.TXT,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = text,
    })

    tween(f, 0.3, { Size = UDim2.fromOffset(250, 34) }, EASE)
    task.delay(2.6, function()
        tween(f, 0.25, { Size = UDim2.fromOffset(0, 34) })
        task.delay(0.3, function() f:Destroy() end)
    end)
end

-- ================================================================
-- window system
-- ================================================================
local PANELS = {}

local function draggable(handle, target)
    local dragging, startPos, origin
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, origin = true, i.Position, target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startPos
            target.Position = UDim2.new(
                origin.X.Scale, origin.X.Offset + d.X,
                origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function Window(key, title, x, y, w, h)
    local f = new("Frame", {
        Parent = gui,
        Name = key,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = T.BG0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
    }, { corner(RADIUS), stroke(T.LINE, 0.1) })

    local head = new("Frame", {
        Parent = f,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    })

    accent(label({
        Parent = head,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -40, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T.RED,
        Text = title,
    }), "TextColor3")

    local closeBtn = new("TextButton", {
        Parent = head,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T.FAINT,
        Text = "\u{00D7}",
    })

    accent(new("Frame", {
        Parent = f,
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }), "BackgroundColor3")

    local body = new("Frame", {
        Parent = f,
        Position = UDim2.fromOffset(0, 31),
        Size = UDim2.new(1, 0, 1, -31),
        BackgroundTransparency = 1,
    })

    draggable(head, f)

    PANELS[key] = { frame = f, w = w, h = h, on = false, title = title, close = closeBtn }

    closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.12, { TextColor3 = T.ERR }) end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.12, { TextColor3 = T.FAINT }) end)

    return f, body, closeBtn
end

local barButtons = {}

local function setPanel(key, on, instant)
    local p = PANELS[key]
    if not p or p.on == on then return end
    p.on = on

    local b = barButtons[key]
    if b then
        tween(b.btn, 0.15, { TextColor3 = on and T.RED or T.FAINT })
        tween(b.dot, 0.15, { BackgroundTransparency = on and 0 or 1 })
    end

    if on then
        p.frame.Visible = true
        if instant then
            p.frame.Size = UDim2.fromOffset(p.w, p.h)
        else
            p.frame.Size = UDim2.fromOffset(p.w, 0)
            tween(p.frame, 0.32, { Size = UDim2.fromOffset(p.w, p.h) }, EASE)
        end
    else
        tween(p.frame, 0.22, { Size = UDim2.fromOffset(p.w, 0) })
        task.delay(0.24, function()
            if not p.on then p.frame.Visible = false end
        end)
    end
end

-- ---------------- sections + widgets ----------------
local function Section(parent, title, x, y, w, h)
    local f = new("Frame", {
        Parent = parent,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = T.BG1,
        BorderSizePixel = 0,
    }, { corner(RADIUS), stroke(T.LINE, 0.25) })

    label({
        Parent = f,
        Position = UDim2.fromOffset(13, 9),
        Size = UDim2.new(1, -26, 0, 12),
        Font = Enum.Font.Code,
        TextSize = 10.5,
        TextColor3 = T.DIM,
        Text = title:upper(),
    })

    -- hairline under the caption, accent on the left third
    new("Frame", {
        Parent = f,
        Position = UDim2.fromOffset(13, 26),
        Size = UDim2.new(1, -26, 0, 1),
        BackgroundColor3 = T.LINE,
        BorderSizePixel = 0,
    })
    accent(new("Frame", {
        Parent = f,
        Position = UDim2.fromOffset(13, 26),
        Size = UDim2.fromOffset(28, 1),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }), "BackgroundColor3")

    return new("Frame", {
        Parent = f,
        Position = UDim2.fromOffset(13, 36),
        Size = UDim2.new(1, -26, 1, -48),
        BackgroundTransparency = 1,
    }, {
        new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
end

local ord = 0
local function nextOrd() ord = ord + 1; return ord end

local function Toggle(parent, text, key, callback, opt)
    opt = opt or {}
    local pad = opt.indent and 16 or 0
    local row = new("Frame", {
        Parent = parent,
        LayoutOrder = nextOrd(),
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
    })

    local box = new("Frame", {
        Parent = row,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, pad, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
    }, { corner(2), stroke(T.LINE, 0) })
    local bs = box:FindFirstChildOfClass("UIStroke")

    local fill = accent(new("Frame", {
        Parent = box,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }, { corner(2) }), "BackgroundColor3")

    local txt = label({
        Parent = row,
        Position = UDim2.fromOffset(pad + 23, 0),
        Size = UDim2.new(1, -(pad + 23) - (opt.swatch and 26 or 0), 1, 0),
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = T.DIM,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = text:upper(),
    })

    -- small colour chip on the right, like the reference rows
    if opt.swatch then
        local chip = new("Frame", {
            Parent = row,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(20, 12),
            BackgroundColor3 = (opt.swatch == true) and T.RED or opt.swatch,
            BorderSizePixel = 0,
        }, { corner(2), stroke(T.LINE, 0.4) })
        if opt.swatch == true then accent(chip, "BackgroundColor3") end
    end

    local function render(on, fire, pop)
        S[key] = on
        tween(fill, 0.16, { Size = UDim2.fromOffset(on and 8 or 0, on and 8 or 0) },
              on and BACK or QUAD)
        tween(bs, 0.16, { Color = on and T.RED or T.LINE, Transparency = on and 0.2 or 0 })
        tween(txt, 0.16, { TextColor3 = on and T.TXT or T.DIM })
        if pop then
            box.Size = UDim2.fromOffset(17, 17)
            tween(box, 0.18, { Size = UDim2.fromOffset(14, 14) }, BACK)
        end
        if fire and callback then callback(on) end
    end

    local hit = new("TextButton", {
        Parent = row,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    })
    hit.MouseButton1Click:Connect(function() render(not S[key], true, true) end)
    hit.MouseEnter:Connect(function()
        if not S[key] then tween(txt, 0.12, { TextColor3 = T.TXT }) end
    end)
    hit.MouseLeave:Connect(function()
        if not S[key] then tween(txt, 0.12, { TextColor3 = T.DIM }) end
    end)

    render(S[key], false, false)
    return { set = render }
end

local function Slider(parent, text, key, min, max, suffix, callback)
    local row = new("Frame", {
        Parent = parent,
        LayoutOrder = nextOrd(),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
    })

    label({
        Parent = row,
        Size = UDim2.new(1, -70, 0, 14),
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = T.DIM,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = text:upper(),
    })

    local valLbl = label({
        Parent = row,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(70, 14),
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = T.TXT,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = tostring(S[key]) .. (suffix or ""),
    })

    local track = new("Frame", {
        Parent = row,
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 4),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
    }, { corner(999) })

    local fill = accent(new("Frame", {
        Parent = track,
        Size = UDim2.fromScale((S[key] - min) / (max - min), 1),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }, { corner(999) }), "BackgroundColor3")

    local knob = accent(new("Frame", {
        Parent = track,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale((S[key] - min) / (max - min), 0.5),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, { corner(999) }), "BackgroundColor3")

    local function apply(alpha, fire, snap)
        alpha = math.clamp(alpha, 0, 1)
        local v = math.floor(min + (max - min) * alpha + 0.5)
        S[key] = v
        if snap then
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.fromScale(alpha, 0.5)
        else
            tween(fill, 0.08, { Size = UDim2.fromScale(alpha, 1) })
            tween(knob, 0.08, { Position = UDim2.fromScale(alpha, 0.5) })
        end
        valLbl.Text = tostring(v) .. (suffix or "")
        if fire and callback then callback(v) end
    end

    local sliding = false
    local hit = new("TextButton", {
        Parent = row,
        Position = UDim2.fromOffset(0, 15),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    })

    local function grow(on)
        tween(knob, 0.15, { Size = UDim2.fromOffset(on and 10 or 0, on and 10 or 0) }, BACK)
    end
    hit.MouseEnter:Connect(function() grow(true) end)
    hit.MouseLeave:Connect(function() if not sliding then grow(false) end end)

    local function fromInput(px)
        apply((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), true, true)
    end

    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            grow(true)
            fromInput(i.Position.X)
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
        or i.UserInputType == Enum.UserInputType.Touch then
            if sliding then grow(false) end
            sliding = false
        end
    end)

    return { set = apply }
end

local function styleButton(b)
    local st = b:FindFirstChildOfClass("UIStroke")
    b.MouseEnter:Connect(function()
        tween(b, 0.13, { TextColor3 = T.TXT, BackgroundColor3 = T.BG1 })
        if st then tween(st, 0.13, { Color = T.RED, Transparency = 0.4 }) end
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.13, { TextColor3 = T.DIM, BackgroundColor3 = T.BG2 })
        if st then tween(st, 0.13, { Color = T.LINE, Transparency = 0.2 }) end
    end)
    b.MouseButton1Down:Connect(function()
        local sz = b.Size
        tween(b, 0.08, { Size = UDim2.new(sz.X.Scale, sz.X.Offset - 4, sz.Y.Scale, sz.Y.Offset - 2) })
        task.delay(0.1, function() tween(b, 0.12, { Size = sz }, BACK) end)
    end)
end

local function Button(parent, text, callback)
    local b = new("TextButton", {
        Parent = parent,
        LayoutOrder = nextOrd(),
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Code,
        TextSize = 10.5,
        TextColor3 = T.DIM,
        Text = text:upper(),
    }, { corner(RADIUS), stroke(T.LINE, 0.2) })
    styleButton(b)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end

local function Dropdown(parent, text, key, options, callback)
    local row = new("Frame", {
        Parent = parent,
        LayoutOrder = nextOrd(),
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        ZIndex = 3,
    })

    label({
        Parent = row,
        Size = UDim2.new(1, 0, 0, 12),
        Font = Enum.Font.Code,
        TextSize = 10,
        TextColor3 = T.FAINT,
        Text = text:upper(),
        ZIndex = 3,
    })

    local head = new("TextButton", {
        Parent = row,
        Position = UDim2.fromOffset(0, 16),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = T.TXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "  " .. tostring(S[key]):upper(),
        ZIndex = 3,
    }, { corner(RADIUS), stroke(T.LINE, 0.2) })

    local chev = label({
        Parent = head,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(10, 10),
        TextSize = 10,
        TextColor3 = T.FAINT,
        Text = "\u{25BE}",
        ZIndex = 4,
    })

    local menu = new("Frame", {
        Parent = row,
        Position = UDim2.fromOffset(0, 46),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 20,
    }, {
        corner(RADIUS),
        stroke(T.LINE, 0.1),
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
        new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
    })

    local open = false
    local function setOpen(v)
        open = v
        if v then menu.Visible = true end
        tween(menu, 0.2, { Size = UDim2.new(1, 0, 0, v and (#options * 24 + 6) or 0) }, EASE)
        tween(chev, 0.2, { Rotation = v and 180 or 0 })
        if not v then task.delay(0.22, function() if not open then menu.Visible = false end end) end
    end

    for i, opt in ipairs(options) do
        local b = new("TextButton", {
            Parent = menu,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextColor3 = T.DIM,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. tostring(opt):upper(),
            ZIndex = 21,
        })
        b.MouseEnter:Connect(function() tween(b, 0.1, { TextColor3 = T.TXT }) end)
        b.MouseLeave:Connect(function() tween(b, 0.1, { TextColor3 = T.DIM }) end)
        b.MouseButton1Click:Connect(function()
            S[key] = opt
            head.Text = "  " .. tostring(opt):upper()
            setOpen(false)
            if callback then callback(opt) end
        end)
    end

    head.MouseButton1Click:Connect(function() setOpen(not open) end)
    return row
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

-- ================================================================
-- movement
-- ================================================================
RunService.Stepped:Connect(function()
    if not S.noclip then return end
    local c = character()
    if not c then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
    end
end)

RunService.Heartbeat:Connect(function()
    local h = humanoid()
    if not h then return end
    if S.walkSpeedOn then h.WalkSpeed = S.walkSpeed end
    if S.jumpPowerOn then
        h.UseJumpPower = true
        h.JumpPower = S.jumpPower
    end
end)

UserInputService.JumpRequest:Connect(function()
    if not S.infJump then return end
    local h = humanoid()
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

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
        Parent = r, MaxForce = Vector3.new(1e5, 1e5, 1e5), Velocity = Vector3.zero,
    })
    flyBG = new("BodyGyro", {
        Parent = r, MaxTorque = Vector3.new(1e5, 1e5, 1e5), P = 1e4, CFrame = r.CFrame,
    })
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

LP.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- click teleport
UserInputService.InputBegan:Connect(function(i, processed)
    if processed or not S.clickTp then return end
    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
    local m = LP:GetMouse()
    local r = root()
    if r and m.Hit then r.CFrame = CFrame.new(m.Hit.Position + Vector3.new(0, 3, 0)) end
end)

-- fling
local flinging = false
local function fling(target)
    if flinging then return end
    local r, c = root(), character()
    local tc = target and target.Character
    local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
    if not r or not thrp then
        toast("No target to fling", T.ERR)
        return
    end

    flinging = true
    local home = r.CFrame
    toast("Flinging " .. target.DisplayName, T.RED)

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not flinging then conn:Disconnect(); return end
        pcall(function()
            r.CFrame = thrp.CFrame
            r.AssemblyAngularVelocity = Vector3.new(0, 90000, 0)
            r.AssemblyLinearVelocity = Vector3.new(90000, 90000, 90000)
        end)
    end)

    task.delay(1.1, function()
        flinging = false
        task.wait(0.15)
        pcall(function()
            r.AssemblyAngularVelocity = Vector3.zero
            r.AssemblyLinearVelocity = Vector3.zero
            r.CFrame = home
        end)
    end)
end

-- ================================================================
-- world / lighting
-- ================================================================
local defaultGravity   = workspace.Gravity
local defaultFog       = Lighting.FogEnd
local defaultBrightness = Lighting.Brightness
local defaultAmbient   = Lighting.Ambient
local defaultOutdoor   = Lighting.OutdoorAmbient

RunService.Heartbeat:Connect(function()
    if S.gravityOn then workspace.Gravity = S.gravity end
    if S.timeOn then Lighting.ClockTime = S.timeOfDay end
    if S.fullbright then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    end
    if S.noFog then Lighting.FogEnd = 1e6 end
    if CAM.FieldOfView ~= S.fov then CAM.FieldOfView = S.fov end
end)

local xrayCache = {}
local function setXray(on)
    if on then
        for _, part in ipairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 1
               and not Players:GetPlayerFromCharacter(part.Parent)
               and (not character() or not part:IsDescendantOf(character())) then
                xrayCache[part] = part.Transparency
                part.Transparency = 0.72
            end
        end
    else
        for part, t in pairs(xrayCache) do
            if part and part.Parent then part.Transparency = t end
        end
        xrayCache = {}
    end
end

-- ================================================================
-- ESP
-- ================================================================
local hasDrawing = pcall(function() return Drawing.new("Square"):Remove() end)

local R15_BONES = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6_BONES = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local esp = {}

local function drawing(class, props)
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props or {}) do d[k] = v end
    return d
end

local function buildEsp(plr)
    if not hasDrawing then return nil end
    local o = {
        box      = drawing("Square", { Thickness = 1, Filled = false, Visible = false }),
        boxOut   = drawing("Square", { Thickness = 3, Filled = false, Visible = false,
                                       Color = Color3.new(0, 0, 0), Transparency = 0.6 }),
        fill     = drawing("Square", { Filled = true, Visible = false, Transparency = 0.25 }),
        hpBack   = drawing("Line", { Thickness = 3, Visible = false, Color = Color3.new(0, 0, 0) }),
        hpBar    = drawing("Line", { Thickness = 1, Visible = false }),
        hpText   = drawing("Text", { Size = 11, Center = false, Outline = true, Visible = false }),
        name     = drawing("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
        info     = drawing("Text", { Size = 11, Center = true, Outline = true, Visible = false }),
        tool     = drawing("Text", { Size = 11, Center = true, Outline = true, Visible = false }),
        tracer   = drawing("Line", { Thickness = 1, Visible = false }),
        bones    = {},
    }
    for i = 1, #R15_BONES do
        o.bones[i] = drawing("Line", { Thickness = 1, Visible = false })
    end
    return o
end

local function hideEsp(o)
    if not o then return end
    for k, d in pairs(o) do
        if k == "bones" then
            for _, l in ipairs(d) do l.Visible = false end
        elseif d and d.Visible ~= nil then
            d.Visible = false
        end
    end
end

local function killEsp(plr)
    local o = esp[plr]
    if not o then return end
    for k, d in pairs(o) do
        if k == "bones" then
            for _, l in ipairs(d) do pcall(function() l:Remove() end) end
        else
            pcall(function() d:Remove() end)
        end
    end
    esp[plr] = nil
    local hl = plr.Character and plr.Character:FindFirstChild("pc_chams")
    if hl then hl:Destroy() end
end

local function updateChams(plr, colour)
    local char = plr.Character
    if not char then return end
    local hl = char:FindFirstChild("pc_chams")
    if not S.espOn or not S.espChams then
        if hl then hl:Destroy() end
        return
    end
    if not hl then
        hl = new("Highlight", {
            Name = "pc_chams",
            Parent = char,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        })
    end
    hl.FillColor = colour
    hl.OutlineColor = colour
    hl.FillTransparency = S.espChamsFill / 100
    hl.OutlineTransparency = 0
end

RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local o = esp[plr]

            if not S.espOn then
                hideEsp(o)
                local char = plr.Character
                local hl = char and char:FindFirstChild("pc_chams")
                if hl then hl:Destroy() end
            else
                if not o then
                    o = buildEsp(plr)
                    esp[plr] = o
                end

                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local head = char and char:FindFirstChild("Head")
                local skip = S.espTeam and plr.Team == LP.Team and not marks[plr]

                if o and hrp and hum and head and hum.Health > 0 and not skip then
                    local colour = markColour(plr)
                    local myRoot = root()
                    local dist = myRoot and math.floor((myRoot.Position - hrp.Position).Magnitude) or 0

                    local pos, onScreen = CAM:WorldToViewportPoint(hrp.Position)
                    if onScreen and dist <= S.espMaxDist then
                        local topV = CAM:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.2, 0))
                        local botV = CAM:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.4, 0))
                        local h = math.abs(topV.Y - botV.Y)
                        local w = h / 2
                        local x = pos.X - w / 2
                        local y = topV.Y

                        -- box
                        if S.espBox then
                            if S.espBoxStyle == "Corners" then
                                o.box.Visible = false
                                o.boxOut.Visible = false
                                -- corner brackets reuse the bone lines 1..8
                                local seg = math.max(w, h) * 0.28
                                local pts = {
                                    { Vector2.new(x, y), Vector2.new(x + seg, y) },
                                    { Vector2.new(x, y), Vector2.new(x, y + seg) },
                                    { Vector2.new(x + w, y), Vector2.new(x + w - seg, y) },
                                    { Vector2.new(x + w, y), Vector2.new(x + w, y + seg) },
                                    { Vector2.new(x, y + h), Vector2.new(x + seg, y + h) },
                                    { Vector2.new(x, y + h), Vector2.new(x, y + h - seg) },
                                    { Vector2.new(x + w, y + h), Vector2.new(x + w - seg, y + h) },
                                    { Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - seg) },
                                }
                                for i = 1, 8 do
                                    local l = o.bones[i]
                                    if l and not S.espSkeleton then
                                        l.Visible = true
                                        l.Color = colour
                                        l.Thickness = 1
                                        l.From = pts[i][1]
                                        l.To = pts[i][2]
                                    end
                                end
                            else
                                o.boxOut.Visible = true
                                o.boxOut.Size = Vector2.new(w, h)
                                o.boxOut.Position = Vector2.new(x, y)

                                o.box.Visible = true
                                o.box.Color = colour
                                o.box.Size = Vector2.new(w, h)
                                o.box.Position = Vector2.new(x, y)
                            end
                        else
                            o.box.Visible = false
                            o.boxOut.Visible = false
                        end

                        -- fill
                        o.fill.Visible = S.espFill
                        if S.espFill then
                            o.fill.Color = colour
                            o.fill.Transparency = 0.22
                            o.fill.Size = Vector2.new(w, h)
                            o.fill.Position = Vector2.new(x, y)
                        end

                        -- health bar down the left edge
                        local hpFrac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.hpBack.Visible = S.espHealth
                        o.hpBar.Visible = S.espHealth
                        if S.espHealth then
                            local bx = x - 6
                            o.hpBack.From = Vector2.new(bx, y)
                            o.hpBack.To = Vector2.new(bx, y + h)
                            o.hpBar.Color = Color3.fromRGB(
                                math.floor(255 * (1 - hpFrac)),
                                math.floor(200 * hpFrac + 40), 60)
                            o.hpBar.From = Vector2.new(bx, y + h)
                            o.hpBar.To = Vector2.new(bx, y + h - h * hpFrac)
                        end

                        o.hpText.Visible = S.espHealth and S.espHealthText
                        if o.hpText.Visible then
                            o.hpText.Color = colour
                            o.hpText.Size = S.espTextSize - 2
                            o.hpText.Text = tostring(math.floor(hum.Health))
                            o.hpText.Position = Vector2.new(x - 26, y + h - h * hpFrac - 6)
                        end

                        -- name
                        o.name.Visible = S.espName
                        if S.espName then
                            o.name.Color = colour
                            o.name.Size = S.espTextSize
                            o.name.Text = plr.DisplayName
                            o.name.Position = Vector2.new(pos.X, y - S.espTextSize - 3)
                        end

                        -- distance line under the box
                        o.info.Visible = S.espDistance
                        if S.espDistance then
                            o.info.Color = colour
                            o.info.Size = S.espTextSize - 2
                            o.info.Text = dist .. "m"
                            o.info.Position = Vector2.new(pos.X, y + h + 2)
                        end

                        -- held tool
                        local tool = char:FindFirstChildOfClass("Tool")
                        o.tool.Visible = S.espTool and tool ~= nil
                        if o.tool.Visible then
                            o.tool.Color = colour
                            o.tool.Size = S.espTextSize - 2
                            o.tool.Text = tool.Name
                            o.tool.Position = Vector2.new(pos.X, y + h + 2 + (S.espDistance and 12 or 0))
                        end

                        -- tracer
                        o.tracer.Visible = S.espTracer
                        if S.espTracer then
                            local from
                            if S.espTracerFrom == "Center" then
                                from = Vector2.new(CAM.ViewportSize.X / 2, CAM.ViewportSize.Y / 2)
                            elseif S.espTracerFrom == "Mouse" then
                                from = UserInputService:GetMouseLocation()
                            else
                                from = Vector2.new(CAM.ViewportSize.X / 2, CAM.ViewportSize.Y)
                            end
                            o.tracer.Color = colour
                            o.tracer.From = from
                            o.tracer.To = Vector2.new(pos.X, y + h)
                        end

                        -- skeleton (takes the bone lines back from the corner box)
                        if S.espSkeleton then
                            local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
                            for i, pair in ipairs(bones) do
                                local a = char:FindFirstChild(pair[1])
                                local b = char:FindFirstChild(pair[2])
                                local l = o.bones[i]
                                if l and a and b then
                                    local pa, va = CAM:WorldToViewportPoint(a.Position)
                                    local pb, vb = CAM:WorldToViewportPoint(b.Position)
                                    if va and vb then
                                        l.Visible = true
                                        l.Color = colour
                                        l.Thickness = 1
                                        l.From = Vector2.new(pa.X, pa.Y)
                                        l.To = Vector2.new(pb.X, pb.Y)
                                    else
                                        l.Visible = false
                                    end
                                elseif l then
                                    l.Visible = false
                                end
                            end
                            for i = #bones + 1, #o.bones do
                                if o.bones[i] then o.bones[i].Visible = false end
                            end
                        elseif not (S.espBox and S.espBoxStyle == "Corners") then
                            for _, l in ipairs(o.bones) do l.Visible = false end
                        end

                        updateChams(plr, colour)
                    else
                        hideEsp(o)
                        updateChams(plr, colour)
                    end
                else
                    hideEsp(o)
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    killEsp(plr)
    marks[plr] = nil
end)

-- ================================================================
-- TOP BAR
-- ================================================================
local topbar = new("Frame", {
    Parent = gui,
    Position = UDim2.fromOffset(24, 24),
    Size = UDim2.fromOffset(700, 34),
    BackgroundColor3 = T.BG0,
    BorderSizePixel = 0,
}, { corner(RADIUS), stroke(T.LINE, 0.1) })

accent(new("Frame", {
    Parent = topbar,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
}), "BackgroundColor3")

label({
    Parent = topbar,
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.fromOffset(230, 34),
    Font = Enum.Font.GothamBold,
    TextSize = 11.5,
    TextColor3 = T.TXT,
    RichText = true,
    Text = CFG.Brand .. "  <font color='#53535E'>|</font>  "
        .. "<font color='#8E8E9A'>" .. CFG.Script .. " " .. CFG.Version .. "</font>",
})

local barHolder = new("Frame", {
    Parent = topbar,
    Position = UDim2.fromOffset(250, 0),
    Size = UDim2.new(1, -260, 1, 0),
    BackgroundTransparency = 1,
}, {
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

local barOrder = 0
local function addBarButton(key, text)
    barOrder = barOrder + 1
    local b = new("TextButton", {
        Parent = barHolder,
        LayoutOrder = barOrder,
        Size = UDim2.fromOffset(20 + #text * 7, 22),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        TextSize = 10.5,
        TextColor3 = T.FAINT,
        Text = text,
    })

    local dot = new("Frame", {
        Parent = b,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 1),
        Size = UDim2.fromOffset(14, 2),
        BackgroundColor3 = T.RED,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    accent(dot, "BackgroundColor3")

    barButtons[key] = { btn = b, dot = dot }

    b.MouseButton1Click:Connect(function()
        setPanel(key, not PANELS[key].on)
    end)
    b.MouseEnter:Connect(function()
        if not PANELS[key].on then tween(b, 0.12, { TextColor3 = T.DIM }) end
    end)
    b.MouseLeave:Connect(function()
        if not PANELS[key].on then tween(b, 0.12, { TextColor3 = T.FAINT }) end
    end)
end

draggable(topbar, topbar)

-- ================================================================
-- WATERMARK  (cell strip)
-- ================================================================
local watermark = new("Frame", {
    Parent = gui,
    Position = UDim2.fromOffset(24, 70),
    Size = UDim2.fromOffset(430, 30),
    BackgroundColor3 = T.BG0,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, { corner(RADIUS), stroke(T.LINE, 0.1) })

accent(new("Frame", {
    Parent = watermark,
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
}), "BackgroundColor3")

local wmCells = new("Frame", {
    Parent = watermark,
    Position = UDim2.fromOffset(0, 2),
    Size = UDim2.new(1, 0, 1, -2),
    BackgroundTransparency = 1,
}, {
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

local function wmCell(i, w, text, colour)
    local cell = new("Frame", {
        Parent = wmCells,
        LayoutOrder = i,
        Size = UDim2.new(0, w, 1, 0),
        BackgroundTransparency = 1,
    })
    if i > 1 then
        new("Frame", {
            Parent = cell,
            Size = UDim2.new(0, 1, 1, -10),
            Position = UDim2.fromOffset(0, 5),
            BackgroundColor3 = T.LINE,
            BorderSizePixel = 0,
        })
    end
    return label({
        Parent = cell,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = colour or T.DIM,
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = text,
    })
end

accent(wmCell(1, 130, CFG.Brand, T.RED), "TextColor3")
local wmUser = wmCell(2, 120, LP.DisplayName)
local wmFps  = wmCell(3, 90, "0 fps")
local wmPing = wmCell(4, 90, "0 ms")

draggable(watermark, watermark)

-- ================================================================
-- PANEL
-- ================================================================
local panelWin, panelBody = Window("PANEL", "PANEL", 24, 112, 660, 580)

local tabStrip = new("Frame", {
    Parent = panelBody,
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundTransparency = 1,
})

new("Frame", {
    Parent = panelBody,
    Position = UDim2.fromOffset(14, 34),
    Size = UDim2.new(1, -28, 0, 1),
    BackgroundColor3 = T.LINE,
    BorderSizePixel = 0,
})

local pageHolder = new("Frame", {
    Parent = panelBody,
    Position = UDim2.fromOffset(0, 42),
    Size = UDim2.new(1, 0, 1, -50),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
})

local pages, tabs = {}, {}
local currentPage

local function makePage()
    return new("Frame", {
        Parent = pageHolder,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    })
end

local pgMove   = makePage()
local pgEsp    = makePage()
local pgVisual = makePage()
local pgWorld  = makePage()
local pgMisc   = makePage()

local function selectPage(name)
    if currentPage == name then return end
    currentPage = name
    for n, p in pairs(pages) do
        if n == name then
            p.Visible = true
            p.Position = UDim2.fromOffset(0, 16)
            tween(p, 0.26, { Position = UDim2.fromOffset(0, 0) }, EASE)
        else
            p.Visible = false
        end
    end
    for n, t in pairs(tabs) do
        local on = (n == name)
        tween(t.btn, 0.15, { TextColor3 = on and T.TXT or T.FAINT })
        tween(t.bar, 0.2, {
            Size = UDim2.fromOffset(on and t.width or 0, 2),
        }, EASE)
    end
end

local tabX = 14
local function addTab(name, page)
    pages[name] = page
    local width = 20 + #name * 7
    local b = new("TextButton", {
        Parent = tabStrip,
        Position = UDim2.fromOffset(tabX, 0),
        Size = UDim2.fromOffset(width, 32),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = T.FAINT,
        Text = name,
    })
    local bar = accent(new("Frame", {
        Parent = b,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 2),
        Size = UDim2.fromOffset(0, 2),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }), "BackgroundColor3")

    tabs[name] = { btn = b, bar = bar, width = width }
    tabX = tabX + width + 6
    b.MouseButton1Click:Connect(function() selectPage(name) end)
    b.MouseEnter:Connect(function()
        if currentPage ~= name then tween(b, 0.12, { TextColor3 = T.DIM }) end
    end)
    b.MouseLeave:Connect(function()
        if currentPage ~= name then tween(b, 0.12, { TextColor3 = T.FAINT }) end
    end)
end

addTab("Movement", pgMove)
addTab("ESP", pgEsp)
addTab("Visuals", pgVisual)
addTab("World", pgWorld)
addTab("Misc", pgMisc)

local CW = 306   -- column width
local C1, C2 = 14, 340
local sec       -- reused by every Section below

-- ---------------- movement ----------------
sec = Section(pgMove, "SPEED & JUMP", C1, 4, CW, 190)
Toggle(sec, "Override walk speed", "walkSpeedOn")
Slider(sec, "Walk speed", "walkSpeed", 16, 400, nil, function(v)
    local h = humanoid()
    if h and S.walkSpeedOn then h.WalkSpeed = v end
end)
Toggle(sec, "Override jump power", "jumpPowerOn")
Slider(sec, "Jump power", "jumpPower", 50, 500)

sec = Section(pgMove, "TRAVERSAL", C1, 202, CW, 210)
Toggle(sec, "Infinite jump", "infJump")
Toggle(sec, "Noclip", "noclip", function(on)
    if on then return end
    local c = character()
    if not c then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end)
Toggle(sec, "Fly  (WASD / Space / Shift)", "fly", function(on)
    if on then startFly() else stopFly() end
    toast(on and "Fly enabled" or "Fly disabled", on and T.OK or T.DIM)
end)
Slider(sec, "Fly speed", "flySpeed", 20, 500)

sec = Section(pgMove, "TELEPORT", C2, 4, CW, 130)
Toggle(sec, "Ctrl + click teleport", "clickTp")
Button(sec, "Teleport to spawn", function()
    local r = root()
    local spawnPart = workspace:FindFirstChildOfClass("SpawnLocation")
    if r and spawnPart then
        r.CFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
        toast("Teleported to spawn", T.OK)
    else
        toast("No spawn found", T.ERR)
    end
end)

sec = Section(pgMove, "CHARACTER", C2, 142, CW, 170)
Toggle(sec, "Anti-AFK", "antiAfk")
Button(sec, "Respawn", function()
    local h = humanoid()
    if h then h.Health = 0 end
end)
Button(sec, "Reset camera", function()
    CAM.CameraSubject = humanoid()
    CAM.CameraType = Enum.CameraType.Custom
    toast("Camera reset", T.DIM)
end)

-- ---------------- esp ----------------
sec = Section(pgEsp, "MAIN", C1, 4, CW, 200)
Toggle(sec, "Enable ESP", "espOn", function(on)
    toast(on and "ESP enabled" or "ESP disabled", on and T.OK or T.DIM)
end)
Toggle(sec, "Boxes", "espBox")
Toggle(sec, "Box fill", "espFill")
Toggle(sec, "Skeleton", "espSkeleton")
Toggle(sec, "Chams", "espChams")

sec = Section(pgEsp, "BOX STYLE", C1, 212, CW, 86)
Dropdown(sec, "Style", "espBoxStyle", { "Corners", "Full" })

sec = Section(pgEsp, "INFO", C1, 306, CW, 150)
Toggle(sec, "Names", "espName")
Toggle(sec, "Distance", "espDistance")
Toggle(sec, "Held tool", "espTool")

sec = Section(pgEsp, "HEALTH", C2, 4, CW, 110)
Toggle(sec, "Health bar", "espHealth")
Toggle(sec, "Health number", "espHealthText")

sec = Section(pgEsp, "TRACERS", C2, 122, CW, 128)
Toggle(sec, "Tracers", "espTracer")
Dropdown(sec, "Origin", "espTracerFrom", { "Bottom", "Center", "Mouse" })

sec = Section(pgEsp, "FILTER & STYLE", C2, 258, CW, 202)
Toggle(sec, "Team check", "espTeam")
Slider(sec, "Max distance", "espMaxDist", 100, 5000, "m")
Slider(sec, "Text size", "espTextSize", 9, 22, "px")
Slider(sec, "Chams fill", "espChamsFill", 0, 100, "%")

if not hasDrawing then
    label({
        Parent = pgEsp,
        Position = UDim2.fromOffset(C1, 466),
        Size = UDim2.fromOffset(CW * 2 + 26, 30),
        TextSize = 11.5,
        TextColor3 = T.GOLD,
        TextWrapped = true,
        Text = "Your executor doesn't expose the Drawing API, so boxes/tracers/skeleton are unavailable. Chams still work.",
    })
end

-- ---------------- visuals ----------------
sec = Section(pgVisual, "LIGHTING", C1, 4, CW, 140)
Toggle(sec, "Fullbright", "fullbright", function(on)
    if on then return end
    Lighting.Brightness = defaultBrightness
    Lighting.Ambient = defaultAmbient
    Lighting.OutdoorAmbient = defaultOutdoor
end)
Toggle(sec, "Remove fog", "noFog", function(on)
    if not on then Lighting.FogEnd = defaultFog end
end)
Toggle(sec, "X-ray walls", "xray", function(on)
    setXray(on)
    toast(on and "X-ray on" or "X-ray off", on and T.OK or T.DIM)
end)

sec = Section(pgVisual, "CAMERA", C2, 4, CW, 100)
Slider(sec, "Field of view", "fov", 40, 120, nil)

-- ---------------- world ----------------
sec = Section(pgWorld, "PHYSICS", C1, 4, CW, 120)
Toggle(sec, "Override gravity", "gravityOn", function(on)
    if not on then workspace.Gravity = defaultGravity end
end)
Slider(sec, "Gravity", "gravity", 0, 400)

sec = Section(pgWorld, "TIME", C2, 4, CW, 120)
Toggle(sec, "Override time of day", "timeOn")
Slider(sec, "Clock time", "timeOfDay", 0, 24, "h")

sec = Section(pgWorld, "RESET", C1, 132, CW, 100)
Button(sec, "Restore world defaults", function()
    workspace.Gravity = defaultGravity
    Lighting.FogEnd = defaultFog
    Lighting.Brightness = defaultBrightness
    Lighting.Ambient = defaultAmbient
    Lighting.OutdoorAmbient = defaultOutdoor
    S.gravityOn, S.timeOn, S.fullbright, S.noFog = false, false, false, false
    toast("World restored", T.OK)
end)

-- ---------------- misc ----------------
sec = Section(pgMisc, "SERVER", C1, 4, CW, 180)
Button(sec, "Rejoin server", function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end)
Button(sec, "Copy job id", function()
    if type(setclipboard) == "function" then
        pcall(setclipboard, game.JobId)
        toast("Job id copied", T.OK)
    end
end)
Button(sec, "Copy place link", function()
    if type(setclipboard) == "function" then
        pcall(setclipboard, "https://www.roblox.com/games/" .. game.PlaceId)
        toast("Link copied", T.OK)
    end
end)

sec = Section(pgMisc, "INTERFACE", C2, 4, CW, 120)
Toggle(sec, "Watermark", "watermark", function(on)
    watermark.Visible = on
end)
Toggle(sec, "Notifications", "notifications")

sec = Section(pgMisc, "SERVER INFO", C1, 192, CW, 130)
local infoPlayers = label({
    Parent = sec, LayoutOrder = nextOrd(),
    Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.Code,
    TextSize = 11.5, TextColor3 = T.DIM, Text = "players  0",
})
label({
    Parent = sec, LayoutOrder = nextOrd(),
    Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.Code,
    TextSize = 11.5, TextColor3 = T.DIM, TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "job      " .. tostring(game.JobId):sub(1, 18),
})
label({
    Parent = sec, LayoutOrder = nextOrd(),
    Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.Code,
    TextSize = 11.5, TextColor3 = T.DIM, Text = "place    " .. game.PlaceId,
})

selectPage("Movement")

-- ================================================================
-- PLAYERS
-- ================================================================
local plrWin, plrBody = Window("PLAYERS", "PLAYERS", 700, 112, 470, 440)

local plrSearchField = new("Frame", {
    Parent = plrBody,
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.fromOffset(252, 28),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
}, { corner(RADIUS), stroke(T.LINE, 0.2) })

local plrSearch = new("TextBox", {
    Parent = plrSearchField,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -18, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11.5,
    TextColor3 = T.TXT,
    PlaceholderText = "Search players",
    PlaceholderColor3 = T.FAINT,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
})

local plrList = new("ScrollingFrame", {
    Parent = plrBody,
    Position = UDim2.fromOffset(14, 48),
    Size = UDim2.fromOffset(252, 340),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
    corner(RADIUS),
    stroke(T.LINE, 0.25),
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
    new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }),
})

-- right column
local RX = 280
local plrCard = new("Frame", {
    Parent = plrBody,
    Position = UDim2.fromOffset(RX, 12),
    Size = UDim2.fromOffset(176, 130),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
}, { corner(RADIUS), stroke(T.LINE, 0.25) })

local plrThumb = new("ImageLabel", {
    Parent = plrCard,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 12),
    Size = UDim2.fromOffset(58, 58),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    Image = "",
}, { corner(RADIUS), stroke(T.LINE, 0.3) })

local plrCardName = label({
    Parent = plrCard,
    Position = UDim2.fromOffset(10, 78),
    Size = UDim2.new(1, -20, 0, 16),
    Font = Enum.Font.GothamBold,
    TextSize = 12.5,
    TextColor3 = T.TXT,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "no selection",
})

local plrCardTag = label({
    Parent = plrCard,
    Position = UDim2.fromOffset(10, 96),
    Size = UDim2.new(1, -20, 0, 14),
    Font = Enum.Font.Code,
    TextSize = 10.5,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "-",
})

local plrCardMark = label({
    Parent = plrCard,
    Position = UDim2.fromOffset(10, 111),
    Size = UDim2.new(1, -20, 0, 14),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Center,
    Text = "unmarked",
})

local selectedPlayer
local spectating = false
local refreshPlayers

local function actionBtn(y, text, w, x)
    local b = new("TextButton", {
        Parent = plrBody,
        Position = UDim2.fromOffset(x or RX, y),
        Size = UDim2.fromOffset(w or 176, 30),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 11.5,
        TextColor3 = T.DIM,
        Text = text,
    }, { corner(RADIUS), stroke(T.LINE, 0.2) })
    styleButton(b)
    return b
end

label({
    Parent = plrBody,
    Position = UDim2.fromOffset(RX, 150),
    Size = UDim2.fromOffset(176, 14),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = T.FAINT,
    Text = "MARK",
})

-- mark picker: Ally / Neutral / Enemy
local MARK_OPTS = {
    { "Ally", "ally", T.ALLY },
    { "Neutral", nil, T.NEUTRAL },
    { "Enemy", "enemy", T.ENEMY },
}

local markHead = new("TextButton", {
    Parent = plrBody,
    Position = UDim2.fromOffset(RX, 168),
    Size = UDim2.fromOffset(176, 28),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamMedium,
    TextSize = 11.5,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "   Neutral",
    ZIndex = 3,
}, { corner(RADIUS), stroke(T.LINE, 0.2) })

local markDot = new("Frame", {
    Parent = markHead,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = T.NEUTRAL,
    BorderSizePixel = 0,
    ZIndex = 4,
}, { corner(999) })

local markChev = label({
    Parent = markHead,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.fromOffset(10, 10),
    TextSize = 10,
    TextColor3 = T.FAINT,
    Text = "\u{25BE}",
    ZIndex = 4,
})

local markMenu = new("Frame", {
    Parent = plrBody,
    Position = UDim2.fromOffset(RX, 198),
    Size = UDim2.fromOffset(176, 0),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
    ZIndex = 30,
}, {
    corner(RADIUS),
    stroke(T.LINE, 0.1),
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
    new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
})

local markOpen = false
local function setMarkMenu(v)
    markOpen = v
    if v then markMenu.Visible = true end
    tween(markMenu, 0.2, { Size = UDim2.fromOffset(176, v and 78 or 0) }, EASE)
    tween(markChev, 0.2, { Rotation = v and 180 or 0 })
    if not v then
        task.delay(0.22, function() if not markOpen then markMenu.Visible = false end end)
    end
end

markHead.MouseButton1Click:Connect(function() setMarkMenu(not markOpen) end)

local spectateBtn = actionBtn(212, "Spectate")
local profileBtn  = actionBtn(248, "View profile  \u{203A}")
local teleportBtn = actionBtn(284, "Teleport to")
local flingBtn    = actionBtn(320, "Fling")
local copyIdBtn   = actionBtn(356, "Copy user id")

local function stopSpectate()
    spectating = false
    spectateBtn.Text = "Spectate"
    spectateBtn.TextColor3 = T.DIM
    CAM.CameraSubject = humanoid()
end

local function refreshCard()
    if not selectedPlayer or not selectedPlayer.Parent then
        plrCardName.Text = "no selection"
        plrCardTag.Text = "-"
        plrCardMark.Text = "unmarked"
        plrCardMark.TextColor3 = T.FAINT
        plrThumb.Image = ""
        return
    end
    plrCardName.Text = selectedPlayer.DisplayName
    plrCardTag.Text = "@" .. selectedPlayer.Name
    plrThumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. selectedPlayer.UserId .. "&w=150&h=150"

    local m = marks[selectedPlayer]
    plrCardMark.Text = m and m:upper() or "unmarked"
    plrCardMark.TextColor3 = (m == "ally" and T.ALLY) or (m == "enemy" and T.ENEMY) or T.FAINT

    local word = (m == "ally" and "Ally") or (m == "enemy" and "Enemy") or "Neutral"
    local col  = (m == "ally" and T.ALLY) or (m == "enemy" and T.ENEMY) or T.NEUTRAL
    markHead.Text = "   " .. word
    markHead.TextColor3 = m and col or T.FAINT
    markDot.BackgroundColor3 = col
end

local function setMark(kind)
    if not selectedPlayer then
        toast("Pick a player first", T.ERR)
        return
    end
    marks[selectedPlayer] = kind
    toast(selectedPlayer.DisplayName .. (kind and (" marked " .. kind) or " unmarked"),
          (kind == "ally" and T.ALLY) or (kind == "enemy" and T.ENEMY) or T.DIM)
    refreshCard()
    refreshPlayers()
end

spectateBtn.MouseButton1Click:Connect(function()
    if spectating then
        stopSpectate()
        toast("Stopped spectating", T.DIM)
        return
    end
    if not selectedPlayer then
        toast("Pick a player first", T.ERR)
        return
    end
    local hum = selectedPlayer.Character and selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then
        toast("They have no character", T.ERR)
        return
    end
    spectating = true
    CAM.CameraSubject = hum
    spectateBtn.Text = "Unspectate"
    spectateBtn.TextColor3 = T.RED
    toast("Spectating " .. selectedPlayer.DisplayName, T.RED)
end)

teleportBtn.MouseButton1Click:Connect(function()
    if not selectedPlayer then
        toast("Pick a player first", T.ERR)
        return
    end
    local target = selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    local r = root()
    if target and r then
        r.CFrame = target.CFrame * CFrame.new(0, 0, 3)
        toast("Teleported to " .. selectedPlayer.DisplayName, T.OK)
    else
        toast("Can't reach them", T.ERR)
    end
end)

flingBtn.MouseButton1Click:Connect(function()
    if not selectedPlayer then
        toast("Pick a player first", T.ERR)
        return
    end
    fling(selectedPlayer)
end)

for i, opt in ipairs(MARK_OPTS) do
    local row = new("TextButton", {
        Parent = markMenu,
        LayoutOrder = i,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        TextSize = 11.5,
        TextColor3 = T.DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "   " .. opt[1],
        ZIndex = 31,
    })
    new("Frame", {
        Parent = row,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = opt[3],
        BorderSizePixel = 0,
        ZIndex = 32,
    }, { corner(999) })

    row.MouseEnter:Connect(function() tween(row, 0.1, { TextColor3 = T.TXT }) end)
    row.MouseLeave:Connect(function() tween(row, 0.1, { TextColor3 = T.DIM }) end)
    row.MouseButton1Click:Connect(function()
        setMarkMenu(false)
        setMark(opt[2])
    end)
end

copyIdBtn.MouseButton1Click:Connect(function()
    if not selectedPlayer then return end
    if type(setclipboard) == "function" then
        pcall(setclipboard, tostring(selectedPlayer.UserId))
        toast("User id copied", T.OK)
    end
end)

local plrRows = {}

refreshPlayers = function()
    for _, r in ipairs(plrRows) do r:Destroy() end
    plrRows = {}

    local q = plrSearch.Text:lower()
    for i, plr in ipairs(Players:GetPlayers()) do
        local isYou = (plr == LP)
        local shown = q == ""
            or plr.Name:lower():find(q, 1, true) ~= nil
            or plr.DisplayName:lower():find(q, 1, true) ~= nil

        if shown then
            local row = new("TextButton", {
                Parent = plrList,
                LayoutOrder = i,
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = T.BG2,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
            }, { corner(4) })

            local m = marks[plr]
            new("Frame", {
                Parent = row,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.fromOffset(5, 5),
                BackgroundColor3 = (m == "ally" and T.ALLY)
                                or (m == "enemy" and T.ENEMY)
                                or (isYou and T.RED)
                                or T.FAINT,
                BorderSizePixel = 0,
            }, { corner(999) })

            local nameLbl = label({
                Parent = row,
                Position = UDim2.fromOffset(20, 0),
                Size = UDim2.new(1, -28, 1, 0),
                TextSize = 11.5,
                TextColor3 = (plr == selectedPlayer and T.TXT) or T.DIM,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = plr.Name .. (isYou and "  (you)" or ""),
            })

            row.MouseEnter:Connect(function()
                tween(row, 0.12, { BackgroundTransparency = 0.6 })
                tween(nameLbl, 0.12, { TextColor3 = T.TXT })
            end)
            row.MouseLeave:Connect(function()
                tween(row, 0.12, { BackgroundTransparency = plr == selectedPlayer and 0 or 1 })
                if plr ~= selectedPlayer then tween(nameLbl, 0.12, { TextColor3 = T.DIM }) end
            end)
            row.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                refreshCard()
                refreshPlayers()
            end)

            if plr == selectedPlayer then row.BackgroundTransparency = 0 end
            table.insert(plrRows, row)
        end
    end
end

plrSearch:GetPropertyChangedSignal("Text"):Connect(refreshPlayers)
Players.PlayerAdded:Connect(function() task.defer(refreshPlayers) end)
Players.PlayerRemoving:Connect(function(p)
    if selectedPlayer == p then
        selectedPlayer = nil
        if spectating then stopSpectate() end
        refreshCard()
    end
    task.defer(refreshPlayers)
end)
refreshPlayers()
refreshCard()

-- ================================================================
-- CHAT LOGS
-- ================================================================
local chatWin, chatBody = Window("CHAT", "CHAT LOGS", 24, 706, 660, 280)

local chatList = new("ScrollingFrame", {
    Parent = chatBody,
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.new(1, -28, 1, -58),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
    corner(RADIUS),
    stroke(T.LINE, 0.25),
    new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
    new("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
    }),
})

local chatLines, chatCount = {}, 0

local function addChatLog(plr, msg)
    chatCount = chatCount + 1
    local colour = markColour(plr)
    if plr == LP then colour = T.RED end

    local row = new("Frame", {
        Parent = chatList,
        LayoutOrder = chatCount,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, { new("UIPadding", { PaddingBottom = UDim.new(0, 5) }) })

    local timeLbl = label({
        Parent = row,
        Size = UDim2.fromOffset(40, 16),
        Font = Enum.Font.Code,
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
        Text = plr.DisplayName,
    })

    local msgLbl = label({
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

    -- click the name to pull them up on the players tab
    nameBtn.MouseEnter:Connect(function() tween(nameBtn, 0.1, { TextColor3 = T.TXT }) end)
    nameBtn.MouseLeave:Connect(function() tween(nameBtn, 0.1, { TextColor3 = colour }) end)
    nameBtn.MouseButton1Click:Connect(function()
        if not plr.Parent then
            toast(plr.DisplayName .. " has left", T.ERR)
            return
        end
        selectedPlayer = plr
        refreshCard()
        refreshPlayers()
        setPanel("PLAYERS", true)
        toast("Pulled up " .. plr.DisplayName, colour)
    end)

    for _, e in ipairs({ timeLbl, nameBtn, msgLbl }) do
        e.TextTransparency = 1
        tween(e, 0.25, { TextTransparency = 0 })
    end

    table.insert(chatLines, {
        row = row,
        raw = os.date("%H:%M") .. "  " .. plr.Name .. ": " .. msg,
    })
    if #chatLines > 200 then
        chatLines[1].row:Destroy()
        table.remove(chatLines, 1)
    end
    task.defer(function()
        chatList.CanvasPosition = Vector2.new(0, chatList.AbsoluteCanvasSize.Y)
    end)
end

local function chatBtn(x, w, text, cb)
    local b = new("TextButton", {
        Parent = chatBody,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, x, 1, -12),
        Size = UDim2.fromOffset(w, 28),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 11.5,
        TextColor3 = T.DIM,
        Text = text,
    }, { corner(RADIUS), stroke(T.LINE, 0.2) })
    styleButton(b)
    b.MouseButton1Click:Connect(cb)
    return b
end

chatBtn(14, 120, "Clear log", function()
    for _, e in ipairs(chatLines) do e.row:Destroy() end
    chatLines, chatCount = {}, 0
    toast("Chat log cleared", T.DIM)
end)

chatBtn(142, 120, "Copy log", function()
    local out = {}
    for _, e in ipairs(chatLines) do table.insert(out, e.raw) end
    if type(setclipboard) == "function" then
        pcall(setclipboard, table.concat(out, "\n"))
        toast("Chat log copied", T.OK)
    end
end)

do
    local chatStatus = label({
        Parent = chatBody,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -18),
        Size = UDim2.fromOffset(260, 16),
        Font = Enum.Font.Code,
        TextSize = 10.5,
        TextColor3 = T.FAINT,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "listening\u{2026}",
    })

    -- Player.Chatted does NOT fire on the client for other players, which is
    -- why nothing showed up. Hook every transport and drop duplicates.
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

    -- 1. modern TextChatService
    pcall(function()
        local TCS = game:GetService("TextChatService")
        TCS.MessageReceived:Connect(function(m)
            local src = m.TextSource
            local plr = src and Players:GetPlayerByUserId(src.UserId)
            if plr then logOnce(plr, m.Text) end
        end)
        table.insert(modes, "TextChatService")
    end)

    -- 2. legacy chat replication
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
        if ok then
            table.insert(modes, "legacy")
            announce()
        end
    end)

    -- 3. Chatted, which at minimum catches your own messages
    local function hookPlayer(plr)
        plr.Chatted:Connect(function(msg) logOnce(plr, msg) end)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
    Players.PlayerAdded:Connect(hookPlayer)
    table.insert(modes, "Chatted")

    announce()
end

-- ================================================================
-- CONFIGS
-- ================================================================
local cfgWin, cfgBody = Window("CONFIGS", "CONFIGS", 1186, 112, 300, 356)

local function fileSafe(n) return (tostring(n):gsub("[^%w_%-]", "")) end

local function listConfigs()
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

local cfgList = new("ScrollingFrame", {
    Parent = cfgBody,
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.new(1, -28, 0, 160),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
    corner(RADIUS),
    stroke(T.LINE, 0.25),
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
    new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }),
})

local selectedConfig, cfgRows = nil, {}

local function refreshConfigs()
    for _, r in ipairs(cfgRows) do r:Destroy() end
    cfgRows = {}
    for i, name in ipairs(listConfigs()) do
        local b = new("TextButton", {
            Parent = cfgList,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            TextSize = 11.5,
            TextColor3 = name == selectedConfig and T.RED or T.DIM,
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = name,
        })
        b.MouseButton1Click:Connect(function()
            selectedConfig = name
            for _, r in ipairs(cfgRows) do r.TextColor3 = T.DIM end
            b.TextColor3 = T.RED
        end)
        table.insert(cfgRows, b)
    end
end

local cfgNameField = new("Frame", {
    Parent = cfgBody,
    Position = UDim2.fromOffset(14, 182),
    Size = UDim2.new(1, -28, 0, 28),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
}, { corner(RADIUS), stroke(T.LINE, 0.2) })

local cfgName = new("TextBox", {
    Parent = cfgNameField,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -18, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11.5,
    TextColor3 = T.TXT,
    PlaceholderText = "config name",
    PlaceholderColor3 = T.FAINT,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
})

local function cfgBtn(x, y, w, text, cb)
    local b = new("TextButton", {
        Parent = cfgBody,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, 28),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 11.5,
        TextColor3 = T.DIM,
        Text = text,
    }, { corner(RADIUS), stroke(T.LINE, 0.2) })
    styleButton(b)
    b.MouseButton1Click:Connect(cb)
    return b
end

cfgBtn(14, 220, 130, "Save", function()
    local name = fileSafe(cfgName.Text ~= "" and cfgName.Text or (selectedConfig or ""))
    if name == "" then
        toast("Name the config first", T.ERR)
        return
    end
    if type(writefile) ~= "function" then
        toast("No filesystem access", T.ERR)
        return
    end
    if type(makefolder) == "function" then pcall(makefolder, CFG.SaveDir) end
    local ok = pcall(function()
        writefile(CFG.SaveDir .. "/" .. name .. ".json", HttpService:JSONEncode(S))
    end)
    toast(ok and ("Saved " .. name) or "Save failed", ok and T.OK or T.ERR)
    refreshConfigs()
end)

cfgBtn(156, 220, 130, "Load", function()
    if not selectedConfig then
        toast("Pick a config", T.ERR)
        return
    end
    if type(readfile) ~= "function" then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CFG.SaveDir .. "/" .. selectedConfig .. ".json"))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do S[k] = v end
        if S.accent then setAccent(Color3.fromHex(S.accent)) end
        watermark.Visible = S.watermark
        toast("Loaded " .. selectedConfig, T.OK)
    else
        toast("Load failed", T.ERR)
    end
end)

cfgBtn(14, 256, 272, "Delete selected", function()
    if not selectedConfig then return end
    if type(delfile) == "function" then
        pcall(delfile, CFG.SaveDir .. "/" .. selectedConfig .. ".json")
    end
    selectedConfig = nil
    toast("Config deleted", T.DIM)
    refreshConfigs()
end)

cfgBtn(14, 292, 272, "Refresh list", refreshConfigs)
refreshConfigs()

-- ================================================================
-- APPEARANCE
-- ================================================================
local appWin, appBody = Window("APPEARANCE", "APPEARANCE", 1186, 468, 300, 250)

label({
    Parent = appBody,
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.new(1, -28, 0, 14),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = T.FAINT,
    Text = "ACCENT COLOUR",
})

local swatchRow = new("Frame", {
    Parent = appBody,
    Position = UDim2.fromOffset(14, 32),
    Size = UDim2.new(1, -28, 0, 30),
    BackgroundTransparency = 1,
}, {
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

for i, hex in ipairs(ACCENTS) do
    local sw = new("TextButton", {
        Parent = swatchRow,
        LayoutOrder = i,
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = Color3.fromHex(hex),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
    }, { corner(RADIUS), stroke(T.LINE, 0.3) })

    sw.MouseEnter:Connect(function() tween(sw, 0.12, { Size = UDim2.fromOffset(34, 34) }, BACK) end)
    sw.MouseLeave:Connect(function() tween(sw, 0.12, { Size = UDim2.fromOffset(30, 30) }) end)
    sw.MouseButton1Click:Connect(function()
        S.accent = hex
        setAccent(Color3.fromHex(hex))
        toast("Accent changed", Color3.fromHex(hex))
    end)
end

label({
    Parent = appBody,
    Position = UDim2.fromOffset(14, 78),
    Size = UDim2.new(1, -28, 0, 14),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = T.FAINT,
    Text = "MENU BIND",
})

local bindBox = new("TextButton", {
    Parent = appBody,
    Position = UDim2.fromOffset(14, 98),
    Size = UDim2.new(1, -28, 0, 28),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.Code,
    TextSize = 11.5,
    TextColor3 = T.TXT,
    Text = CFG.Toggle.Name,
}, { corner(RADIUS), stroke(T.LINE, 0.2) })
styleButton(bindBox)

local awaitingBind = false
bindBox.MouseButton1Click:Connect(function()
    awaitingBind = true
    bindBox.Text = "press a key\u{2026}"
    bindBox.TextColor3 = T.RED
end)

local appOpts = new("Frame", {
    Parent = appBody,
    Position = UDim2.fromOffset(14, 140),
    Size = UDim2.new(1, -28, 0, 90),
    BackgroundTransparency = 1,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

Toggle(appOpts, "Watermark", "watermark", function(on) watermark.Visible = on end)
Toggle(appOpts, "Notifications", "notifications")

-- ================================================================
-- PROFILE  ·  full account breakdown for the selected player
-- ================================================================
local profWin, profBody = Window("PROFILE", "PROFILE", 700, 566, 470, 450)

-- executors expose different http calls; try them all
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and res ~= "" then return res end

    local req = (syn and syn.request)
             or (type(http) == "table" and http.request)
             or http_request
             or request
    if type(req) == "function" then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and type(r) == "table" and type(r.Body) == "string" then return r.Body end
    end
    return nil
end

local function getJson(url)
    local body = httpGet(url)
    if not body then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if ok then return data end
    return nil
end

local function fmtDate(iso)
    if type(iso) ~= "string" then return nil end
    local y, m, d = iso:match("^(%d+)-(%d+)-(%d+)")
    if not y then return nil end
    return d .. "/" .. m .. "/" .. y
end

local function ageDays(iso)
    if type(iso) ~= "string" then return nil end
    local y, m, d = iso:match("^(%d+)-(%d+)-(%d+)")
    if not y then return nil end
    local t = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    return math.floor((os.time() - t) / 86400)
end

local function comma(v)
    local out = tostring(v or 0)
    local k
    repeat out, k = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return out
end

-- ---------------- header ----------------
local profThumb = new("ImageLabel", {
    Parent = profBody,
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.fromOffset(74, 74),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
    Image = "",
}, { corner(RADIUS), accent(stroke(T.RED, 0.5), "Color") })

local profName = label({
    Parent = profBody,
    Position = UDim2.fromOffset(100, 16),
    Size = UDim2.fromOffset(340, 24),
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = T.TXT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "no selection",
})

local profUser = label({
    Parent = profBody,
    Position = UDim2.fromOffset(100, 42),
    Size = UDim2.fromOffset(340, 16),
    Font = Enum.Font.Code,
    TextSize = 11.5,
    TextColor3 = T.DIM,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "-",
})

local profMark = label({
    Parent = profBody,
    Position = UDim2.fromOffset(100, 62),
    Size = UDim2.fromOffset(340, 16),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = T.FAINT,
    Text = "UNMARKED",
})

local function profBtn(x, w, text, cb)
    local b = new("TextButton", {
        Parent = profBody,
        Position = UDim2.fromOffset(x, 98),
        Size = UDim2.fromOffset(w, 28),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 11.5,
        TextColor3 = T.DIM,
        Text = text,
    }, { corner(RADIUS), stroke(T.LINE, 0.2) })
    styleButton(b)
    b.MouseButton1Click:Connect(cb)
    return b
end

local profScroll = new("ScrollingFrame", {
    Parent = profBody,
    Position = UDim2.fromOffset(14, 136),
    Size = UDim2.new(1, -28, 1, -150),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, {
    corner(RADIUS),
    stroke(T.LINE, 0.25),
    new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }),
})

local profOrd = 0
local function profClear()
    profOrd = 0
    for _, c in ipairs(profScroll:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function profHeading(text)
    profOrd = profOrd + 1
    local h = label({
        Parent = profScroll,
        LayoutOrder = profOrd,
        Size = UDim2.new(1, 0, 0, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = T.FAINT,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        Text = text,
    })
    h.TextTransparency = 1
    tween(h, 0.25, { TextTransparency = 0 })
end

local function profRow(k, v, colour)
    profOrd = profOrd + 1
    local row = new("Frame", {
        Parent = profScroll,
        LayoutOrder = profOrd,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
    })
    label({
        Parent = row,
        Size = UDim2.fromOffset(140, 18),
        TextSize = 11.5,
        TextColor3 = T.FAINT,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = k,
    })
    local val = label({
        Parent = row,
        Position = UDim2.fromOffset(146, 0),
        Size = UDim2.new(1, -146, 1, 0),
        TextSize = 11.5,
        TextColor3 = colour or T.TXT,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = tostring(v),
    })
    val.TextTransparency = 1
    tween(val, 0.25, { TextTransparency = 0 })
end

local function profPara(text, colour)
    profOrd = profOrd + 1
    local p = label({
        Parent = profScroll,
        LayoutOrder = profOrd,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = 11.5,
        TextColor3 = colour or T.DIM,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = text,
    })
    p.TextTransparency = 1
    tween(p, 0.25, { TextTransparency = 0 })
end

-- ---------------- fetch + render ----------------
local profTarget
local profToken = 0

local function openProfile(plr)
    if not plr then
        toast("Pick a player first", T.ERR)
        return
    end

    profTarget = plr
    profToken = profToken + 1
    local token = profToken

    setPanel("PROFILE", true)

    profThumb.Image = "rbxthumb://type=AvatarBust&id=" .. plr.UserId .. "&w=180&h=180"
    profName.Text = plr.DisplayName
    profUser.Text = "@" .. plr.Name .. "  \u{00B7}  id " .. plr.UserId

    local m = marks[plr]
    profMark.Text = m and (m:upper()) or "UNMARKED"
    profMark.TextColor3 = (m == "ally" and T.ALLY) or (m == "enemy" and T.ENEMY) or T.FAINT

    profClear()
    profPara("Loading profile\u{2026}", T.FAINT)

    task.spawn(function()
        local uid = plr.UserId
        local info    = getJson("https://users.roblox.com/v1/users/" .. uid)
        local hist    = getJson("https://users.roblox.com/v1/users/" .. uid .. "/username-history?limit=50&sortOrder=Asc")
        local groups  = getJson("https://groups.roblox.com/v1/users/" .. uid .. "/groups/roles")
        local favs    = getJson("https://games.roblox.com/v2/users/" .. uid .. "/favorite/games?accessFilter=2&limit=10")
        local friends = getJson("https://friends.roblox.com/v1/users/" .. uid .. "/friends/count")
        local folw    = getJson("https://friends.roblox.com/v1/users/" .. uid .. "/followers/count")

        if token ~= profToken then return end
        profClear()

        if not info then
            profPara("The Roblox web API didn't answer \u{2014} your executor may block "
                .. "outbound http. Everything below comes from the game client instead.", T.GOLD)
        end

        profHeading("ACCOUNT")
        profRow("Display name", (info and info.displayName) or plr.DisplayName)
        profRow("Username", (info and info.name) or plr.Name)
        profRow("User ID", uid)
        profRow("Created", (info and fmtDate(info.created)) or "unknown")

        local days = (info and ageDays(info.created)) or plr.AccountAge
        if days and days > 0 then
            profRow("Account age", comma(days) .. " days  ("
                .. string.format("%.1f", days / 365) .. " years)")
        else
            profRow("Account age", "unknown")
        end

        profRow("Friends", friends and comma(friends.count) or "unknown")
        profRow("Followers", folw and comma(folw.count) or "unknown")
        profRow("Verified badge", info and (info.hasVerifiedBadge and "yes" or "no") or "unknown",
                info and info.hasVerifiedBadge and T.OK or nil)
        profRow("Banned", info and (info.isBanned and "yes" or "no") or "unknown",
                info and info.isBanned and T.ERR or nil)
        profRow("Team", plr.Team and plr.Team.Name or "none")

        profHeading("DESCRIPTION")
        local desc = info and info.description
        profPara((desc and desc ~= "" and desc) or "No description set.")

        profHeading("PAST USERNAMES")
        if hist and type(hist.data) == "table" and #hist.data > 0 then
            local names = {}
            for _, e in ipairs(hist.data) do table.insert(names, e.name) end
            profPara(table.concat(names, ",  "))
        else
            profPara("None on record.")
        end

        profHeading("GROUPS")
        if groups and type(groups.data) == "table" and #groups.data > 0 then
            profRow("Total", #groups.data)
            for i, g in ipairs(groups.data) do
                if i > 20 then
                    profPara("\u{2026} and " .. (#groups.data - 20) .. " more")
                    break
                end
                profRow(g.group and g.group.Name or g.group and g.group.name or "group",
                        g.role and g.role.name or "member")
            end
        else
            profPara("None, or the list is private.")
        end

        profHeading("FAVOURITE GAMES")
        if favs and type(favs.data) == "table" and #favs.data > 0 then
            for i, g in ipairs(favs.data) do
                if i > 10 then break end
                profRow(g.name or "game", comma(g.placeVisits or 0) .. " visits")
            end
        else
            profPara("None, or favourites are private.")
        end
    end)
end

profBtn(14, 130, "Refresh", function()
    if profTarget then openProfile(profTarget) end
end)

profBtn(152, 150, "Copy profile link", function()
    if not profTarget then return end
    if type(setclipboard) == "function" then
        pcall(setclipboard, "https://www.roblox.com/users/" .. profTarget.UserId .. "/profile")
        toast("Profile link copied", T.OK)
    end
end)

profBtn(310, 132, "Pull up in tab", function()
    if not profTarget then return end
    selectedPlayer = profTarget
    refreshCard()
    refreshPlayers()
    setPanel("PLAYERS", true)
end)

-- the arrow on the players card opens this window
profileBtn.MouseButton1Click:Connect(function()
    openProfile(selectedPlayer)
end)

-- every window's X closes just that window
for key, p in pairs(PANELS) do
    p.close.MouseButton1Click:Connect(function() setPanel(key, false) end)
end

-- ================================================================
-- top bar buttons  (order matters)
-- ================================================================
addBarButton("PANEL", "PANEL")
addBarButton("PLAYERS", "PLAYERS")
addBarButton("PROFILE", "PROFILE")
addBarButton("CHAT", "CHAT")
addBarButton("CONFIGS", "CONFIGS")
addBarButton("APPEARANCE", "APPEARANCE")

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
            return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
        end)
        ping = ok and ping or 0

        wmFps.Text = fps .. " fps"
        wmFps.TextColor3 = (fps >= 50 and T.OK) or (fps >= 25 and T.GOLD) or T.ERR
        wmPing.Text = ping .. " ms"
        wmUser.Text = LP.DisplayName
        infoPlayers.Text = "players  " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers
    end
end)

local menuHidden = false
local function setMenu(show)
    menuHidden = not show
    topbar.Visible = show
    watermark.Visible = show and S.watermark
    for key, p in pairs(PANELS) do
        p.frame.Visible = show and p.on
        if show and p.on then p.frame.Size = UDim2.fromOffset(p.w, p.h) end
    end
end

UserInputService.InputBegan:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end

    if awaitingBind then
        awaitingBind = false
        CFG.Toggle = i.KeyCode
        bindBox.Text = i.KeyCode.Name
        bindBox.TextColor3 = T.TXT
        toast("Menu bind set to " .. i.KeyCode.Name, T.OK)
        return
    end

    if i.KeyCode == CFG.Toggle then setMenu(menuHidden) end
end)

-- open with PANEL only, animated
setAccent(Color3.fromHex(S.accent))
watermark.Visible = S.watermark

topbar.Size = UDim2.fromOffset(700, 0)
tween(topbar, 0.3, { Size = UDim2.fromOffset(700, 34) }, EASE)
watermark.Size = UDim2.fromOffset(430, 0)
task.delay(0.1, function()
    tween(watermark, 0.3, { Size = UDim2.fromOffset(430, 30) }, EASE)
end)
task.delay(0.2, function() setPanel("PANEL", true) end)

task.delay(0.6, function()
    toast(CFG.Brand .. " loaded  \u{00B7}  " .. CFG.Toggle.Name .. " to hide", T.RED)
end)
