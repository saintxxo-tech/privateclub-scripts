--[[ ================================================================
     privateclub.cc  ·  hub
     ----------------------------------------------------------------
     boot  ->  key loader  ->  hub (sidebar nav: home / scripts /
     utility / settings). key saves after the first unlock.

     usage:  loadstring(game:HttpGet("<your raw url>"))()
     ================================================================ ]]

local CONFIG = {
    Name     = "privateclub",
    Suffix   = ".cc",
    Tagline  = "PRIVATE SCRIPT HUB",
    Version  = "v1.0",

    Discord     = "discord.gg/privateclub",
    DiscordFull = "https://discord.gg/privateclub",
    KeyLink     = "https://privateclub.cc/keys",

    SaveFile = "privateclub_data.json",
    Toggle   = Enum.KeyCode.RightShift,

    -- Host the .lua files anywhere that serves raw text and put the folder
    -- url here, with the trailing slash. Each Library entry then only needs
    -- its filename in Script. A full Url on an entry still wins over this.
    --   GitHub : https://raw.githubusercontent.com/<user>/<repo>/main/
    --   Gist   : https://gist.githubusercontent.com/<user>/<id>/raw/
    BaseUrl   = "https://raw.githubusercontent.com/saintxxo-tech/privateclub-scripts/main/games/",
    -- raw.githubusercontent caches for a few minutes; this appends a
    -- timestamp so Load always pulls what you just pushed.
    CacheBust = true,

    -- Script library. PlaceId drives the icon + the "in this game" dot.
    -- A game is playable once it resolves to a source, in this order:
    --   1. Url     an explicit full url on the entry
    --   2. Script  a filename appended to CONFIG.BaseUrl
    --   3. File    a local file in the executor's workspace folder
    -- Notes: first character is the marker  +  added   -  fixed   ~  changed
    Library = {
        -- File is a fallback: drop the .lua into your executor's workspace
        -- folder under any of these names and Load works with nothing hosted.
        { Name = "Universal", PlaceId = 0, Url = "", Script = "universal.lua",
          File = { "privateclub_universal.lua", "universal.lua" },
          Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Movement: speed, jump, noclip, infinite jump, fly",
            "+ Player ESP: boxes, names, tracers, team check",
            "+ Lighting: fullbright, no fog, x-ray",
            "+ World: gravity and time of day",
            "+ Player list with teleport and spectate",
            "+ Saveable configs and accent colours",
            "~ Right Ctrl toggles the menu",
        } },
        { Name = "Blade Ball", PlaceId = 13772394625, Url = "", Script = "bladeball.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto parry with curve prediction",
            "+ Spam parry toggle",
            "+ Ability auto-use",
            "~ Ping compensation reworked",
            "- Parry no longer misses on deflect",
        } },
        { Name = "Fisch", PlaceId = 16732694052, Url = "", Script = "fisch.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto shake and reel",
            "+ Instant catch",
            "+ Auto sell at capacity",
            "- Rod detection on rejoin",
        } },
        { Name = "Grow a Garden", PlaceId = 126884695634066, Url = "", Script = "growagarden.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto plant and harvest",
            "+ Auto buy seeds",
            "+ Pet auto-equip",
            "~ Harvest loop timing",
        } },
        { Name = "Steal a Brainrot", PlaceId = 109983668079237, Url = "", Script = "stealabrainrot.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto steal",
            "+ Base lock bypass",
            "+ Item ESP",
            "- Teleport no longer voids",
        } },
        { Name = "Murder Mystery 2", PlaceId = 142823291, Url = "", Script = "mm2.lua",
          File = { "privateclub_mm2.lua", "mm2.lua" },
          Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Five role model: murderer, police, hero, innocent, ghost",
            "+ Role ESP with chams, boxes, health bars, auras",
            "+ Knife kill all, reach and hitbox expander",
            "+ Silent aim, auto shoot, bullet tracers, hitmarkers",
            "+ Full auto farm, coin grabber, gun grabber",
            "+ Auto fling, touch fling, fling spin, anti fling",
            "+ Player list, chat logs, skybox changer",
            "~ Right Ctrl toggles the menu",
        } },
        { Name = "Da Hood", PlaceId = 2788229376, Url = "", Script = "dahood.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Aim assist",
            "+ Silent aim",
            "+ Auto farm",
            "- Camlock no longer drifts",
        } },
        { Name = "Arsenal", PlaceId = 286090429, Url = "", Script = "arsenal.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Silent aim",
            "+ Player ESP",
            "~ Hitbox expander cleaned up",
        } },
        { Name = "Jailbreak", PlaceId = 606849621, Url = "", Script = "jailbreak.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto rob all stores",
            "+ Vehicle speed",
            "+ Noclip",
        } },
        { Name = "Pet Sim 99", PlaceId = 8737899170, Url = "", Script = "petsim99.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto farm coins",
            "+ Auto hatch",
            "+ Auto upgrade",
        } },
        { Name = "Bee Swarm", PlaceId = 1537690962, Url = "", Script = "beeswarm.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto collect",
            "+ Auto quest",
            "~ Field pathing",
        } },
        { Name = "Blox Fruits", PlaceId = 2753915549, Url = "", Script = "bloxfruits.lua", Authors = "privateclub",
          Updated = "-", Notes = {
            "+ Auto farm level",
            "+ Fruit sniper",
            "+ Raid helper",
            "- Sea event teleports",
        } },
    },
}

-- ================================================================
-- services
-- ================================================================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local Lighting         = game:GetService("Lighting")

local LP = Players.LocalPlayer

-- ================================================================
-- theme  ·  red on black, hard edges
-- ================================================================
local T = {
    BG0   = Color3.fromHex("06060A"),   -- window
    BG1   = Color3.fromHex("0A0A0F"),   -- sidebar / panel
    BG2   = Color3.fromHex("101017"),   -- input / raised
    LINE  = Color3.fromHex("1C1C24"),

    TXT   = Color3.fromHex("E8E8EE"),
    DIM   = Color3.fromHex("8E8E9A"),
    FAINT = Color3.fromHex("53535E"),

    RED   = Color3.fromHex("FF2E43"),
    RED2  = Color3.fromHex("B00C24"),
    GOLD  = Color3.fromHex("FFB020"),

    OK    = Color3.fromHex("3ED598"),
    ERR   = Color3.fromHex("FF4D6A"),
}

local RADIUS = 6

local accented = {}
local function accent(inst, prop)
    table.insert(accented, { inst = inst, prop = prop })
    return inst
end
local function setAccent(colour)
    for _, e in ipairs(accented) do
        if e.inst and e.inst.Parent then
            TweenService:Create(e.inst, TweenInfo.new(0.4), { [e.prop] = colour }):Play()
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

local function stroke(colour, trans, thick)
    return new("UIStroke", {
        Color = colour or T.LINE,
        Transparency = trans or 0,
        Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function pad(t, r, b, l)
    return new("UIPadding", {
        PaddingTop    = UDim.new(0, t),
        PaddingRight  = UDim.new(0, r or t),
        PaddingBottom = UDim.new(0, b or t),
        PaddingLeft   = UDim.new(0, l or r or t),
    })
end

local function list(gap, dir)
    return new("UIListLayout", {
        Padding = UDim.new(0, gap or 10),
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

local function tween(o, t, props, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t,
        style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
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

-- small caption / secondary line
local function micro(p)
    p = p or {}
    p.Font = p.Font or Enum.Font.GothamMedium
    p.TextSize = p.TextSize or 11
    return label(p)
end

-- monospace, kept only for real data: keys, ids, counters
local function code(p)
    p = p or {}
    p.Font = Enum.Font.Code
    return label(p)
end

local function panel(props, kids)
    props.BackgroundColor3 = props.BackgroundColor3 or T.BG1
    props.BorderSizePixel = 0
    local kid = kids or {}
    table.insert(kid, corner(RADIUS))
    table.insert(kid, stroke(T.LINE, 0.1))
    return new("Frame", props, kid)
end

-- ================================================================
-- key digest
-- ----------------------------------------------------------------
-- keys are never stored here in plaintext. an entered key is folded
-- to an 8-char digest and matched against KEYS.
-- add new keys with:  node keygen.js <key>
-- ================================================================
local function mul32(a, b)
    local ah, al = math.floor(a / 65536), a % 65536
    local bh, bl = math.floor(b / 65536), b % 65536
    return ((al * bl) + (((ah * bl + al * bh) % 65536) * 65536)) % 4294967296
end

local function digest(v)
    local s = "pc|v3|" .. tostring(v) .. "|x9"
    local x = 0x811c9dc5
    for i = 1, #s do
        x = bit32.bxor(x, string.byte(s, i))
        x = mul32(x, 0x01000193)
    end
    for _ = 1, 9973 do
        x = bit32.bxor(x, bit32.rshift(x, 13))
        x = mul32(x, 0x5bd1e995)
        x = bit32.bxor(x, bit32.lshift(x, 5))
    end
    return string.format("%08x", x)
end

local KEYS = {
    ["14c9f29d"] = { tier = "Standard", days = 30,  admin = false },
    ["73b60162"] = { tier = "Premium",  days = 180, admin = false },
    ["2aa11990"] = { tier = "Lifetime", days = 0,   admin = false },
    ["1a3ac67f"] = { tier = "Root",     days = 0,   admin = true  },
}

-- ================================================================
-- executor bridges  (all optional, all guarded)
-- ================================================================
local ENV = (type(getgenv) == "function" and getgenv()) or _G

local function copyTo(text)
    local fn = (type(setclipboard) == "function" and setclipboard)
            or (type(toclipboard) == "function" and toclipboard)
    if fn then return (pcall(fn, text)) end
    return false
end

local function copyFrom()
    if type(getclipboard) == "function" then
        local ok, res = pcall(getclipboard)
        if ok and type(res) == "string" then return res end
    end
    return nil
end

local function executorName()
    if type(identifyexecutor) == "function" then
        local ok, n = pcall(identifyexecutor)
        if ok and n and n ~= "" then return tostring(n) end
    end
    if type(getexecutorname) == "function" then
        local ok, n = pcall(getexecutorname)
        if ok and n and n ~= "" then return tostring(n) end
    end
    return "Unknown"
end

-- ---------- persisted data ----------
local DATA = { key = nil, activated = nil, linked = false, settings = {} }

local function readData()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return ENV.__pc_data
    end
    local ok, raw = pcall(function()
        if isfile(CONFIG.SaveFile) then return readfile(CONFIG.SaveFile) end
    end)
    if not ok or type(raw) ~= "string" then return ENV.__pc_data end
    local good, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if good and type(parsed) == "table" then return parsed end
    return ENV.__pc_data
end

local function writeData()
    ENV.__pc_data = DATA
    if type(writefile) ~= "function" then return end
    pcall(function() writefile(CONFIG.SaveFile, HttpService:JSONEncode(DATA)) end)
end

local function wipeData()
    DATA = { key = nil, activated = nil, linked = false, settings = DATA.settings or {} }
    ENV.__pc_data = nil
    if type(delfile) == "function" then pcall(delfile, CONFIG.SaveFile) end
end

local function setting(name, default)
    local v = DATA.settings and DATA.settings[name]
    if v == nil then return default end
    return v
end

-- ---------- misc ----------
local function hwid()
    local ok, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and type(id) == "string" and #id >= 8 then
        return (id:sub(1, 4) .. "-" .. id:sub(-4)):upper()
    end
    local d = digest(tostring(LP.UserId))
    return (d:sub(1, 4) .. "-" .. d:sub(5, 8)):upper()
end

local function mask(k)
    if not k then return "\u{2014}" end
    if #k <= 8 then return string.rep("\u{2022}", #k) end
    return string.rep("\u{2022}", #k - 4) .. k:sub(-4)
end

local function expiryText(rec, activated)
    if not rec then return "\u{2014}" end
    if rec.days == 0 then return "Lifetime" end
    local left = ((activated or os.time()) + rec.days * 86400) - os.time()
    if left <= 0 then return "Expired" end
    local d = math.floor(left / 86400)
    local h = math.floor((left % 86400) / 3600)
    if d > 0 then return d .. "d " .. h .. "h" end
    return h .. "h " .. math.floor((left % 3600) / 60) .. "m"
end

local function gameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and info and info.Name then return info.Name end
    return "Unknown Game"
end

-- ================================================================
-- gui root
-- ================================================================
if ENV.__pc_gui then pcall(function() ENV.__pc_gui:Destroy() end) end

local gui = new("ScreenGui", {
    Name = "\u{200B}pc" .. tostring(math.random(100000, 999999)),
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
})
ENV.__pc_gui = gui

do
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    local mounted = pcall(function()
        gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
    if not mounted then gui.Parent = LP:WaitForChild("PlayerGui") end
end

DATA = readData() or DATA
if type(DATA.settings) ~= "table" then DATA.settings = {} end

local blur
pcall(function()
    blur = new("BlurEffect", { Name = "pcblur", Size = 0, Parent = Lighting })
end)
local function setBlur(on)
    if not blur then return end
    tween(blur, 0.4, { Size = (on and setting("blur", true)) and 14 or 0 })
end

-- ================================================================
-- 1. BOOT SCREEN
-- ================================================================
local boot = new("Frame", {
    Parent = gui,
    Name = "Boot",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,     -- clear: the game shows through
    BorderSizePixel = 0,
    ZIndex = 50,
})

local bootTitle = label({
    Parent = boot,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.47),
    Size = UDim2.fromOffset(600, 40),
    Font = Enum.Font.GothamBold,
    TextSize = 30,
    TextColor3 = T.TXT,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextStrokeTransparency = 0.55,
    RichText = true,
    ZIndex = 51,
    Text = CONFIG.Name .. '<font color="#FF2E43">' .. CONFIG.Suffix .. "</font>",
})

local bootTrack = new("Frame", {
    Parent = boot,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.54),
    Size = UDim2.fromOffset(300, 3),
    BackgroundColor3 = T.LINE,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    ZIndex = 51,
}, { corner(999) })

local bootFill = accent(new("Frame", {
    Parent = bootTrack,
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    ZIndex = 52,
}, { corner(999) }), "BackgroundColor3")

local bootStatus = label({
    Parent = boot,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.585),
    Size = UDim2.fromOffset(400, 18),
    TextSize = 13,
    TextColor3 = T.DIM,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextStrokeTransparency = 0.7,
    ZIndex = 51,
    Text = "Loading",
})

-- ================================================================
-- 2. KEY LOADER
-- ================================================================
local LW, LH = 420, 366

local loaderWin = new("Frame", {
    Parent = gui,
    Name = "Loader",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(LW, LH),
    BackgroundColor3 = T.BG0,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 20,
}, { corner(RADIUS), accent(stroke(T.RED, 0.62), "Color") })

-- left rail: a solid red edge instead of a top hairline
accent(new("Frame", {
    Parent = loaderWin,
    Size = UDim2.new(0, 2, 1, 0),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    ZIndex = 21,
}, {
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(1, 0.85),
        }),
    }),
}), "BackgroundColor3")

local loaderBody = new("Frame", {
    Parent = loaderWin,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 21,
}, { pad(26, 26, 26, 28), list(11) })

local loaderHead = new("Frame", {
    Parent = loaderBody,
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    ZIndex = 22,
})

local loaderMark = new("TextButton", {
    Parent = loaderHead,
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    TextSize = 14,
    TextColor3 = T.BG0,
    Text = "P",
    ZIndex = 22,
}, {
    corner(RADIUS),
    new("UIGradient", { Rotation = 130, Color = ColorSequence.new(T.RED, T.RED2) }),
})
accent(loaderMark, "BackgroundColor3")

label({
    Parent = loaderHead,
    Position = UDim2.fromOffset(42, 3),
    Size = UDim2.new(1, -42, 0, 22),
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextColor3 = T.TXT,
    RichText = true,
    ZIndex = 22,
    Text = CONFIG.Name .. '<font color="#FF2E43">' .. CONFIG.Suffix .. "</font>",
})

micro({
    Parent = loaderBody,
    LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 36),
    TextSize = 12.5,
    TextColor3 = T.DIM,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 22,
    Text = "Enter your key to unlock the hub. It saves to this device, so you only do this once.",
})

micro({
    Parent = loaderBody,
    LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 14),
    TextSize = 11,
    TextColor3 = T.FAINT,
    ZIndex = 22,
    Text = "Access key",
})

local keyField = new("Frame", {
    Parent = loaderBody,
    LayoutOrder = 4,
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    ZIndex = 22,
}, { corner(RADIUS), stroke(T.LINE, 0) })
local keyStroke = keyField:FindFirstChildOfClass("UIStroke")

accent(new("Frame", {
    Parent = keyField,
    Size = UDim2.new(0, 2, 1, 0),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    ZIndex = 23,
}), "BackgroundColor3")

local keyBox = new("TextBox", {
    Parent = keyField,
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -74, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 14,
    TextColor3 = T.TXT,
    PlaceholderText = "PC-XXXX-XXXX-XXXX",
    PlaceholderColor3 = T.FAINT,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
    ZIndex = 23,
})

local pasteBtn = new("TextButton", {
    Parent = keyField,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -6, 0.5, 0),
    Size = UDim2.fromOffset(52, 28),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    TextColor3 = T.DIM,
    Text = "Paste",
    ZIndex = 23,
}, { corner(RADIUS), stroke(T.LINE, 0.2) })

local unlockBtn = new("TextButton", {
    Parent = loaderBody,
    LayoutOrder = 5,
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 14.5,
    TextColor3 = T.BG0,
    Text = "Unlock",
    ZIndex = 22,
}, {
    corner(RADIUS),
    new("UIGradient", { Rotation = 12, Color = ColorSequence.new(T.RED, T.RED2) }),
})
accent(unlockBtn, "BackgroundColor3")

local loaderStatus = micro({
    Parent = loaderBody,
    LayoutOrder = 6,
    Size = UDim2.new(1, 0, 0, 16),
    TextSize = 12.5,
    TextColor3 = T.FAINT,
    ZIndex = 22,
    Text = "Enter your key to continue",
})

local seamLbl = micro({
    Parent = loaderBody,
    LayoutOrder = 7,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    TextSize = 10,
    TextColor3 = T.GOLD,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    Visible = false,
    ZIndex = 22,
    Text = "",
})

local loaderFoot = new("Frame", {
    Parent = loaderWin,
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 1, 1, -26),
    Size = UDim2.new(1, -54, 0, 38),
    BackgroundTransparency = 1,
    ZIndex = 22,
})

local function loaderFootBtn(x, text, hoverColour)
    local b = new("TextButton", {
        Parent = loaderFoot,
        Position = UDim2.new(x, x > 0 and 5 or 0, 0, 0),
        Size = UDim2.new(0.5, -5, 0, 38),
        BackgroundColor3 = T.BG1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = T.DIM,
        Text = text,
        ZIndex = 23,
    }, { corner(RADIUS), stroke(T.LINE, 0.15) })
    local st = b:FindFirstChildOfClass("UIStroke")
    b.MouseEnter:Connect(function()
        tween(b, 0.14, { TextColor3 = hoverColour })
        tween(st, 0.14, { Color = hoverColour, Transparency = 0.45 })
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.14, { TextColor3 = T.DIM })
        tween(st, 0.14, { Color = T.LINE, Transparency = 0.15 })
    end)
    return b
end

local ldDiscord = loaderFootBtn(0, "Discord", Color3.fromHex("8B9CFF"))
local ldGetKey  = loaderFootBtn(0.5, "Get a Key", T.RED)

local loaderVer = new("TextButton", {
    Parent = loaderWin,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -10, 1, -6),
    Size = UDim2.fromOffset(120, 14),
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Font = Enum.Font.GothamMedium,
    TextSize = 10.5,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = CONFIG.Version,
    ZIndex = 22,
})

-- ================================================================
-- 3. HUB WINDOW  ·  sidebar nav
-- ================================================================
local W, H = 720, 470
local SIDE = 154

local win = new("Frame", {
    Parent = gui,
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H),
    BackgroundColor3 = T.BG0,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
}, { corner(RADIUS), accent(stroke(T.RED, 0.62), "Color") })

-- ---------------- sidebar ----------------
local side = new("Frame", {
    Parent = win,
    Size = UDim2.new(0, SIDE, 1, 0),
    BackgroundColor3 = T.BG1,
    BorderSizePixel = 0,
})

new("Frame", {
    Parent = side,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = T.LINE,
    BorderSizePixel = 0,
})

local sideMark = new("TextButton", {
    Parent = side,
    Position = UDim2.fromOffset(16, 18),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    TextColor3 = T.BG0,
    Text = "P",
}, {
    corner(RADIUS),
    new("UIGradient", { Rotation = 130, Color = ColorSequence.new(T.RED, T.RED2) }),
})
accent(sideMark, "BackgroundColor3")

label({
    Parent = side,
    Position = UDim2.fromOffset(16, 52),
    Size = UDim2.fromOffset(SIDE - 24, 18),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = T.TXT,
    RichText = true,
    Text = CONFIG.Name .. '<font color="#FF2E43">' .. CONFIG.Suffix .. "</font>",
})

local sideTier = accent(micro({
    Parent = side,
    Position = UDim2.fromOffset(16, 71),
    Size = UDim2.fromOffset(SIDE - 24, 12),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = T.RED,
    Text = "\u{2014}",
}), "TextColor3")

new("Frame", {
    Parent = side,
    Position = UDim2.fromOffset(16, 96),
    Size = UDim2.new(1, -32, 0, 1),
    BackgroundColor3 = T.LINE,
    BorderSizePixel = 0,
})

local nav = new("Frame", {
    Parent = side,
    Position = UDim2.fromOffset(0, 110),
    Size = UDim2.new(1, 0, 0, 200),
    BackgroundTransparency = 1,
}, { list(2) })

-- user block, pinned to the bottom of the sidebar
new("Frame", {
    Parent = side,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 16, 1, -76),
    Size = UDim2.new(1, -32, 0, 1),
    BackgroundColor3 = T.LINE,
    BorderSizePixel = 0,
})

new("ImageLabel", {
    Parent = side,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 16, 1, -38),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150",
}, { corner(RADIUS), accent(stroke(T.RED, 0.5), "Color") })

local sideName = label({
    Parent = side,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 54, 1, -52),
    Size = UDim2.fromOffset(SIDE - 66, 14),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = T.TXT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = LP.DisplayName,
})

local sideUser = micro({
    Parent = side,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 54, 1, -38),
    Size = UDim2.fromOffset(SIDE - 66, 12),
    TextSize = 9.5,
    TextColor3 = T.FAINT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "@" .. LP.Name,
})

local sideDc = new("TextButton", {
    Parent = side,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 16, 1, -12),
    Size = UDim2.new(1, -32, 0, 14),
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Font = Enum.Font.GothamMedium,
    TextSize = 10.5,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = CONFIG.Discord,
})

-- ---------------- content header ----------------
local head = new("Frame", {
    Parent = win,
    Position = UDim2.fromOffset(SIDE, 0),
    Size = UDim2.new(1, -SIDE, 0, 38),
    BackgroundTransparency = 1,
})

new("Frame", {
    Parent = head,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = T.LINE,
    BorderSizePixel = 0,
})

local crumb = label({
    Parent = head,
    Position = UDim2.fromOffset(18, 0),
    Size = UDim2.fromOffset(200, 38),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = T.TXT,
    Text = "Home",
})

local closeBtn = new("TextButton", {
    Parent = head,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(20, 20),
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = T.FAINT,
    Text = "\u{00D7}",
})

local statLine = micro({
    Parent = head,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -42, 0.5, 0),
    Size = UDim2.fromOffset(340, 16),
    TextSize = 11.5,
    TextColor3 = T.FAINT,
    TextXAlignment = Enum.TextXAlignment.Right,
    RichText = true,
    Text = "",
})

-- ---------------- pages ----------------
local pageHolder = new("Frame", {
    Parent = win,
    Position = UDim2.fromOffset(SIDE, 39),
    Size = UDim2.new(1, -SIDE, 1, -39),
    BackgroundTransparency = 1,
})

local function makePage()
    return new("ScrollingFrame", {
        Parent = pageHolder,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = T.LINE,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, { pad(16, 18), list(10) })
end

local pgHome     = makePage()
local pgScripts  = new("Frame", {
    Parent = pageHolder,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Visible = false,
}, { pad(16, 18) })
local pgUtility  = makePage()
local pgSettings = makePage()
local pgAdmin    = makePage()

local navItems = {}
local currentTab

local function selectTab(name)
    if currentTab == name then return end
    currentTab = name
    for n, it in pairs(navItems) do
        local on = (n == name)
        it.page.Visible = on
        tween(it.btn, 0.15, {
            TextColor3 = on and T.TXT or T.FAINT,
            BackgroundTransparency = on and 0 or 1,
        })
        tween(it.bar, 0.18, { Size = UDim2.fromOffset(2, on and 20 or 0) })
    end
    crumb.Text = name
end

local navOrder = 0
local function addNav(name, page)
    navOrder = navOrder + 1
    local b = new("TextButton", {
        Parent = nav,
        LayoutOrder = navOrder,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = T.BG2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 12.5,
        TextColor3 = T.FAINT,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = name,
    }, {
        new("UIPadding", { PaddingLeft = UDim.new(0, 16) }),
    })

    local bar = accent(new("Frame", {
        Parent = b,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, -16, 0.5, 0),
        Size = UDim2.fromOffset(2, 0),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }), "BackgroundColor3")

    navItems[name] = { btn = b, page = page, bar = bar }
    b.MouseButton1Click:Connect(function() selectTab(name) end)
    b.MouseEnter:Connect(function()
        if currentTab ~= name then tween(b, 0.12, { TextColor3 = T.DIM }) end
    end)
    b.MouseLeave:Connect(function()
        if currentTab ~= name then tween(b, 0.12, { TextColor3 = T.FAINT }) end
    end)
    return b
end

addNav("Home", pgHome)
addNav("Scripts", pgScripts)
addNav("Utility", pgUtility)
addNav("Settings", pgSettings)
local adminNav = addNav("Admin", pgAdmin)
adminNav.Visible = false
adminNav.TextColor3 = T.GOLD

-- ================================================================
-- HOME  ·  terminal-style session readout
-- ================================================================
local welcome = new("Frame", {
    Parent = pgHome,
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
})

micro({
    Parent = welcome,
    Size = UDim2.new(1, 0, 0, 12),
    TextSize = 9.5,
    TextColor3 = T.FAINT,
    Text = "WELCOME BACK",
})

local welcomeName = label({
    Parent = welcome,
    Position = UDim2.fromOffset(0, 16),
    Size = UDim2.new(1, 0, 0, 26),
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    TextColor3 = T.TXT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = LP.DisplayName,
})

local session = panel({
    Parent = pgHome,
    LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 122),
})

micro({
    Parent = session,
    Position = UDim2.fromOffset(14, 11),
    Size = UDim2.new(1, -28, 0, 12),
    TextSize = 9.5,
    TextColor3 = T.FAINT,
    Text = "Session",
})

-- two columns of label -> value rows
local function readout(col, row, key)
    local x = 14 + col * 254
    local y = 32 + row * 26
    micro({
        Parent = session,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(88, 16),
        TextSize = 10.5,
        TextColor3 = T.FAINT,
        Text = key,
    })
    return micro({
        Parent = session,
        Position = UDim2.fromOffset(x + 92, y),
        Size = UDim2.fromOffset(150, 16),
        TextSize = 11.5,
        TextColor3 = T.TXT,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "\u{2014}",
    })
end

local rTier    = readout(0, 0, "Tier")
local rExpires = readout(0, 1, "Expires")
local rExec    = readout(0, 2, "Executor")
local rHwid    = readout(1, 0, "HWID")
local rLinked  = readout(1, 1, "Discord")
local rPing    = readout(1, 2, "Latency")

rTier.TextColor3 = T.RED
accent(rTier, "TextColor3")
rHwid.Font = Enum.Font.Code
rPing.Font = Enum.Font.Code

-- ---------- access key strip ----------
local keyStrip = panel({
    Parent = pgHome,
    LayoutOrder = 3,
    Size = UDim2.new(1, 0, 0, 62),
})

accent(new("Frame", {
    Parent = keyStrip,
    Size = UDim2.new(0, 2, 1, 0),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
}), "BackgroundColor3")

micro({
    Parent = keyStrip,
    Position = UDim2.fromOffset(14, 11),
    Size = UDim2.new(1, -28, 0, 12),
    TextSize = 9.5,
    TextColor3 = T.FAINT,
    Text = "Access key",
})

local keyDisplay = micro({
    Parent = keyStrip,
    Position = UDim2.fromOffset(14, 29),
    Size = UDim2.new(1, -180, 0, 20),
    TextSize = 14,
    TextColor3 = T.TXT,
    Text = "\u{2014}",
})

local function stripBtn(parent, xOffset, text)
    return new("TextButton", {
        Parent = parent,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, xOffset, 0.5, 0),
        Size = UDim2.fromOffset(66, 28),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 12.5,
        TextColor3 = T.DIM,
        Text = text,
    }, { corner(RADIUS), stroke(T.LINE, 0.15) })
end

keyDisplay.Font = Enum.Font.Code

local showBtn = stripBtn(keyStrip, -86, "Show")
local copyBtn = stripBtn(keyStrip, -14, "Copy")

-- ---------- discord strip ----------
local dcStrip = panel({
    Parent = pgHome,
    LayoutOrder = 4,
    Size = UDim2.new(1, 0, 0, 62),
})

accent(new("Frame", {
    Parent = dcStrip,
    Size = UDim2.new(0, 2, 1, 0),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
}), "BackgroundColor3")

micro({
    Parent = dcStrip,
    Position = UDim2.fromOffset(14, 11),
    Size = UDim2.new(1, -28, 0, 12),
    TextSize = 9.5,
    TextColor3 = T.FAINT,
    Text = "Discord  \u{00B7}  link your key for HWID resets",
})

label({
    Parent = dcStrip,
    Position = UDim2.fromOffset(14, 28),
    Size = UDim2.new(1, -180, 0, 20),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = T.TXT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = CONFIG.Discord,
})

local joinBtn = new("TextButton", {
    Parent = dcStrip,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(124, 28),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 11.5,
    TextColor3 = T.BG0,
    Text = "Copy Invite",
}, {
    corner(RADIUS),
    new("UIGradient", { Rotation = 12, Color = ColorSequence.new(T.RED, T.RED2) }),
})
accent(joinBtn, "BackgroundColor3")

-- ================================================================
-- SCRIPTS  ·  game list on the left, detail panel on the right
-- ================================================================
local LISTW = 190

local gamesPanel = panel({
    Parent = pgScripts,
    Size = UDim2.new(0, LISTW, 1, 0),
})

micro({
    Parent = gamesPanel,
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.new(1, -28, 0, 14),
    TextSize = 11,
    TextColor3 = T.FAINT,
    Text = "Games",
})

local searchField = new("Frame", {
    Parent = gamesPanel,
    Position = UDim2.fromOffset(10, 32),
    Size = UDim2.new(1, -20, 0, 28),
    BackgroundColor3 = T.BG2,
    BorderSizePixel = 0,
}, { corner(RADIUS), stroke(T.LINE, 0.25) })

local searchBox = new("TextBox", {
    Parent = searchField,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -18, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = T.TXT,
    PlaceholderText = "Search",
    PlaceholderColor3 = T.FAINT,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "",
})

local gameList = new("ScrollingFrame", {
    Parent = gamesPanel,
    Position = UDim2.fromOffset(8, 68),
    Size = UDim2.new(1, -16, 1, -78),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, { list(2) })

-- ---------------- detail pane ----------------
local detail = panel({
    Parent = pgScripts,
    Position = UDim2.fromOffset(LISTW + 10, 0),
    Size = UDim2.new(1, -(LISTW + 10), 1, 0),
})

micro({
    Parent = detail,
    Position = UDim2.fromOffset(18, 12),
    Size = UDim2.new(1, -36, 0, 14),
    TextSize = 11,
    TextColor3 = T.FAINT,
    Text = "Selection",
})

local dTitle = label({
    Parent = detail,
    Position = UDim2.fromOffset(18, 40),
    Size = UDim2.new(1, -36, 0, 28),
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    TextColor3 = T.TXT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "\u{2014}",
})

local dAuthors = label({
    Parent = detail,
    Position = UDim2.fromOffset(18, 70),
    Size = UDim2.new(1, -36, 0, 16),
    TextSize = 12,
    TextColor3 = T.FAINT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "",
})

local notes = new("ScrollingFrame", {
    Parent = detail,
    Position = UDim2.fromOffset(18, 98),
    Size = UDim2.new(1, -36, 1, -160),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = T.LINE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, { list(7) })

local scriptStatus = label({
    Parent = detail,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 18, 1, -36),
    Size = UDim2.new(1, -180, 0, 16),
    TextSize = 11.5,
    TextColor3 = T.FAINT,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "",
})

local dUpdated = micro({
    Parent = detail,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 18, 1, -18),
    Size = UDim2.new(1, -180, 0, 14),
    TextSize = 11,
    TextColor3 = T.FAINT,
    Text = "",
})

local loadBtn = new("TextButton", {
    Parent = detail,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -18, 1, -18),
    Size = UDim2.fromOffset(136, 36),
    BackgroundColor3 = T.RED,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = T.BG0,
    Text = "Load",
}, {
    corner(RADIUS),
    new("UIGradient", { Rotation = 12, Color = ColorSequence.new(T.RED, T.RED2) }),
})
accent(loadBtn, "BackgroundColor3")

-- ---------------- wiring ----------------
local gameRows = {}
local selected

-- a script can come from a raw url, or from a file sitting in the
-- executor's workspace folder (handy before anything is hosted).
local function localFile(entry)
    if not entry.File or type(isfile) ~= "function" then return nil end
    local names = entry.File
    if type(names) == "string" then names = { names } end
    for _, name in ipairs(names) do
        local ok, found = pcall(isfile, name)
        if ok and found then return name end
    end
    return nil
end

-- an explicit Url wins, otherwise BaseUrl .. Script
local function scriptUrl(entry)
    if entry.Url and entry.Url ~= "" then return entry.Url end
    if CONFIG.BaseUrl ~= "" and entry.Script and entry.Script ~= "" then
        local url = CONFIG.BaseUrl .. entry.Script
        if CONFIG.CacheBust then
            url = url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. os.time()
        end
        return url
    end
    return nil
end

local function fetchSource(entry)
    local url = scriptUrl(entry)
    if url then return game:HttpGet(url) end

    local name = localFile(entry)
    if name and type(readfile) == "function" then
        return readfile(name)
    end
    return nil
end

local function runScript(entry)
    if not entry then return end

    local hasSource = (scriptUrl(entry) ~= nil) or (localFile(entry) ~= nil)

    if not hasSource then
        scriptStatus.Text = "No script linked for " .. entry.Name .. " yet"
        scriptStatus.TextColor3 = T.FAINT
        return
    end

    scriptStatus.Text = "Loading " .. entry.Name .. "\u{2026}"
    scriptStatus.TextColor3 = T.DIM
    loadBtn.Text = "Loading"
    task.spawn(function()
        local ok, err = pcall(function()
            local src = fetchSource(entry)
            assert(src, "could not read the script source")
            loadstring(src)()
        end)
        loadBtn.Text = "Load"
        if ok then
            scriptStatus.Text = entry.Name .. " loaded"
            scriptStatus.TextColor3 = T.OK
        else
            scriptStatus.Text = "Failed: " .. tostring(err):sub(1, 56)
            scriptStatus.TextColor3 = T.ERR
        end
    end)
end

local function selectGame(idx)
    local entry = CONFIG.Library[idx]
    if not entry then return end
    selected = idx

    for j, r in ipairs(gameRows) do
        local on = (j == idx)
        tween(r.btn, 0.14, {
            BackgroundTransparency = on and 0 or 1,
            TextColor3 = on and T.TXT or T.DIM,
        })
        tween(r.bar, 0.16, { Size = UDim2.fromOffset(2, on and 18 or 0) })
    end

    dTitle.Text   = entry.Name
    dAuthors.Text = entry.Authors and ("by " .. entry.Authors) or ""
    dUpdated.Text = "Last updated: " .. (entry.Updated or "\u{2014}")
    scriptStatus.Text = ""

    for _, child in ipairs(notes:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    for k, line in ipairs(entry.Notes or {}) do
        local marker = line:sub(1, 1)
        local text   = (line:sub(2):gsub("^%s+", ""))
        local colour = (marker == "+" and T.RED)
                    or (marker == "~" and T.GOLD)
                    or T.OK

        local row = new("Frame", {
            Parent = notes,
            LayoutOrder = k,
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
        })
        label({
            Parent = row,
            Size = UDim2.fromOffset(14, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = colour,
            Text = marker,
        })
        label({
            Parent = row,
            Position = UDim2.fromOffset(18, 0),
            Size = UDim2.new(1, -18, 1, 0),
            TextSize = 12,
            TextColor3 = T.DIM,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = text,
        })
    end
end

local here
for i, entry in ipairs(CONFIG.Library) do
    local inGame = (entry.PlaceId == game.PlaceId)
    if inGame then here = i end

    local b = new("TextButton", {
        Parent = gameList,
        LayoutOrder = i,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = T.BG2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = T.DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = entry.Name,
    }, {
        corner(RADIUS),
        new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 18) }),
    })

    local bar = accent(new("Frame", {
        Parent = b,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, -14, 0.5, 0),
        Size = UDim2.fromOffset(2, 0),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }), "BackgroundColor3")

    if inGame then
        accent(new("Frame", {
            Parent = b,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 8, 0.5, 0),
            Size = UDim2.fromOffset(5, 5),
            BackgroundColor3 = T.RED,
            BorderSizePixel = 0,
        }, { corner(999) }), "BackgroundColor3")
    end

    gameRows[i] = { btn = b, bar = bar, entry = entry }

    b.MouseButton1Click:Connect(function() selectGame(i) end)
    b.MouseEnter:Connect(function()
        if selected ~= i then tween(b, 0.12, { TextColor3 = T.TXT }) end
    end)
    b.MouseLeave:Connect(function()
        if selected ~= i then tween(b, 0.12, { TextColor3 = T.DIM }) end
    end)
end

loadBtn.MouseButton1Click:Connect(function()
    runScript(CONFIG.Library[selected])
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = searchBox.Text:lower()
    for _, r in ipairs(gameRows) do
        r.btn.Visible = (q == "" or r.entry.Name:lower():find(q, 1, true) ~= nil)
    end
end)

-- open on whatever game you are actually in
selectGame(here or 1)

-- ================================================================
-- UTILITY
-- ================================================================
local function sectionLabel(parent, order, text)
    return micro({
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 14),
        TextSize = 9.5,
        TextColor3 = T.FAINT,
        Text = text,
    })
end

local function rowBtn(parent, order, text)
    local b = new("TextButton", {
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = T.BG1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
    }, { corner(RADIUS), stroke(T.LINE, 0.1) })

    local st = b:FindFirstChildOfClass("UIStroke")

    local bar = new("Frame", {
        Parent = b,
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundColor3 = T.LINE,
        BorderSizePixel = 0,
    })

    label({
        Parent = b,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -60, 1, 0),
        TextSize = 12.5,
        TextColor3 = T.TXT,
        Text = text,
    })

    local chev = micro({
        Parent = b,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        TextSize = 11,
        TextColor3 = T.FAINT,
        Text = "\u{25B8}",
    })

    b.MouseEnter:Connect(function()
        tween(b, 0.14, { BackgroundColor3 = T.BG2 })
        tween(st, 0.14, { Color = T.RED, Transparency = 0.45 })
        tween(bar, 0.14, { BackgroundColor3 = T.RED })
        tween(chev, 0.14, { TextColor3 = T.RED })
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.14, { BackgroundColor3 = T.BG1 })
        tween(st, 0.14, { Color = T.LINE, Transparency = 0.1 })
        tween(bar, 0.14, { BackgroundColor3 = T.LINE })
        tween(chev, 0.14, { TextColor3 = T.FAINT })
    end)
    return b
end

sectionLabel(pgUtility, 1, "Server")
local hopBtn      = rowBtn(pgUtility, 2, "Server hop")
local rejoinBtn   = rowBtn(pgUtility, 3, "Rejoin server")
local smallSrvBtn = rowBtn(pgUtility, 4, "Join smallest server")

sectionLabel(pgUtility, 5, "Character")
local respawnBtn = rowBtn(pgUtility, 6, "Respawn")
local camBtn     = rowBtn(pgUtility, 7, "Reset camera")

local utilStatus = micro({
    Parent = pgUtility,
    LayoutOrder = 8,
    Size = UDim2.new(1, 0, 0, 16),
    TextSize = 11.5,
    TextColor3 = T.FAINT,
    Text = "",
})

-- ================================================================
-- SETTINGS
-- ================================================================
-- square checkbox, not a pill switch
local function toggleRow(parent, order, text, key, default, onChange)
    local row = panel({
        Parent = parent,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 38),
    })

    label({
        Parent = row,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -60, 1, 0),
        TextSize = 12.5,
        TextColor3 = T.TXT,
        Text = text,
    })

    local state = setting(key, default)

    local box = new("Frame", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = T.BG2,
        BorderSizePixel = 0,
    }, { corner(2), stroke(state and T.RED or T.LINE, state and 0.2 or 0) })

    local boxStroke = box:FindFirstChildOfClass("UIStroke")

    local fill = new("Frame", {
        Parent = box,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(state and 8 or 0, state and 8 or 0),
        BackgroundColor3 = T.RED,
        BorderSizePixel = 0,
    }, { corner(1) })
    accent(fill, "BackgroundColor3")

    local hit = new("TextButton", {
        Parent = row,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    })

    hit.MouseButton1Click:Connect(function()
        state = not state
        DATA.settings[key] = state
        writeData()
        tween(fill, 0.15, { Size = UDim2.fromOffset(state and 8 or 0, state and 8 or 0) })
        tween(boxStroke, 0.15, {
            Color = state and T.RED or T.LINE,
            Transparency = state and 0.2 or 0,
        })
        if onChange then onChange(state) end
    end)

    return row
end

sectionLabel(pgSettings, 1, "Account")
toggleRow(pgSettings, 2, "Save key on this device", "saveKey", true)
local clearBtn = rowBtn(pgSettings, 3, "Sign out & clear saved key")

sectionLabel(pgSettings, 4, "Display")
toggleRow(pgSettings, 5, "Background blur", "blur", true, function(on)
    if blur then tween(blur, 0.3, { Size = on and 14 or 0 }) end
end)
toggleRow(pgSettings, 6, "Hide my name in the hub", "hideName", false, function(on)
    welcomeName.Text = on and "Hidden" or LP.DisplayName
    sideName.Text    = on and "Hidden" or LP.DisplayName
    sideUser.Text    = on and "@hidden" or ("@" .. LP.Name)
end)

sectionLabel(pgSettings, 7, "About")
local aboutPanel = panel({ Parent = pgSettings, LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 76) })

for i, pair in ipairs({
    { "HWID", hwid() },
    { "Build", CONFIG.Version },
    { "Toggle", "Right Shift" },
}) do
    local y = 12 + (i - 1) * 18
    micro({
        Parent = aboutPanel,
        Position = UDim2.fromOffset(16, y),
        Size = UDim2.fromOffset(70, 16),
        TextSize = 11.5,
        TextColor3 = T.FAINT,
        Text = pair[1],
    })
    code({
        Parent = aboutPanel,
        Position = UDim2.fromOffset(86, y),
        Size = UDim2.new(1, -102, 0, 16),
        TextSize = 11.5,
        TextColor3 = T.DIM,
        Text = pair[2],
    })
end

-- ================================================================
-- ADMIN
-- ================================================================
sectionLabel(pgAdmin, 1, "Root access")

local adminNote = panel({ Parent = pgAdmin, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 52) })
adminNote.BackgroundColor3 = Color3.fromHex("18110A")
adminNote:FindFirstChildOfClass("UIStroke").Color = T.GOLD
adminNote:FindFirstChildOfClass("UIStroke").Transparency = 0.5

new("Frame", {
    Parent = adminNote,
    Size = UDim2.new(0, 2, 1, 0),
    BackgroundColor3 = T.GOLD,
    BorderSizePixel = 0,
})

micro({
    Parent = adminNote,
    Position = UDim2.fromOffset(16, 11),
    Size = UDim2.new(1, -32, 0, 14),
    TextSize = 10,
    TextColor3 = T.GOLD,
    Text = "Admin mode engaged",
})
micro({
    Parent = adminNote,
    Position = UDim2.fromOffset(16, 28),
    Size = UDim2.new(1, -32, 0, 14),
    TextSize = 10.5,
    TextColor3 = T.DIM,
    Text = "Every gate is open on this session.",
})

for i, text in ipairs({
    "Key whitelist / blacklist",
    "Script vault (unreleased)",
    "Force revoke sessions",
    "Loader telemetry",
}) do
    rowBtn(pgAdmin, i + 2, text)
end

-- ================================================================
-- behaviour
-- ================================================================
local activeKey, activeRec
local keyShown = false

local function say(lbl, text, colour)
    lbl.Text = text
    lbl.TextColor3 = colour or T.FAINT
end

local function refreshHome()
    rTier.Text    = activeRec and activeRec.tier or "\u{2014}"
    rExpires.Text = expiryText(activeRec, DATA.activated)
    rExec.Text    = executorName()
    rHwid.Text    = hwid()
    rLinked.Text  = DATA.linked and "Linked" or "Not linked"
    rLinked.TextColor3 = DATA.linked and T.OK or T.ERR
    keyDisplay.Text = keyShown and (activeKey or "\u{2014}") or mask(activeKey)
    sideTier.Text = (activeRec and activeRec.tier or "\u{2014}"):upper()
    if setting("hideName", false) then
        welcomeName.Text = "Hidden"
        sideName.Text = "Hidden"
        sideUser.Text = "@hidden"
    end
end

local function goAdmin()
    setAccent(T.GOLD)
    adminNav.Visible = true
    sideTier.Text = "ROOT"
end

local function openHub(key, rec)
    activeKey, activeRec = key, rec
    refreshHome()
    if rec.admin then goAdmin() end

    loaderWin.Visible = false
    win.Visible = true
    win.Size = UDim2.fromOffset(W, 0)
    tween(win, 0.34, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Quint)
    selectTab("Home")
    setBlur(true)
end

-- ---------- unlock ----------
local busy = false
local function attempt()
    if busy then return end
    local key = keyBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then
        tween(keyStroke, 0.15, { Color = T.ERR, Transparency = 0 })
        say(loaderStatus, "Enter a key first", T.ERR)
        return
    end

    busy = true
    keyBox:ReleaseFocus()
    unlockBtn.Text = "Verifying\u{2026}"

    task.spawn(function()
        for _, msg in ipairs({ "contacting auth node", "checking signature", "binding hwid" }) do
            say(loaderStatus, msg, T.DIM)
            task.wait(0.25 + math.random() * 0.15)
        end

        local rec = KEYS[digest(key)]
        if not rec then
            tween(keyStroke, 0.15, { Color = T.ERR, Transparency = 0 })
            say(loaderStatus, "Key rejected \u{2014} invalid or revoked", T.ERR)
            unlockBtn.Text = "Unlock"
            busy = false
            return
        end

        say(loaderStatus, "Authenticated", T.OK)

        DATA.key = key
        DATA.activated = DATA.activated or os.time()
        if setting("saveKey", true) then writeData() end

        task.wait(0.35)
        openHub(key, rec)
        unlockBtn.Text = "Unlock"
        busy = false
    end)
end

unlockBtn.MouseButton1Click:Connect(attempt)
keyBox.Focused:Connect(function()
    tween(keyStroke, 0.15, { Color = T.RED, Transparency = 0 })
end)
keyBox.FocusLost:Connect(function(enter)
    tween(keyStroke, 0.2, { Color = T.LINE, Transparency = 0 })
    if enter then attempt() end
end)

pasteBtn.MouseButton1Click:Connect(function()
    local t = copyFrom()
    if t then
        keyBox.Text = (t:gsub("%s+", ""))
        say(loaderStatus, "Pasted from clipboard", T.DIM)
    else
        say(loaderStatus, "Clipboard unavailable", T.ERR)
    end
end)

ldDiscord.MouseButton1Click:Connect(function()
    copyTo(CONFIG.DiscordFull)
    say(loaderStatus, "Discord invite copied", T.DIM)
end)
ldGetKey.MouseButton1Click:Connect(function()
    copyTo(CONFIG.KeyLink)
    say(loaderStatus, "Key link copied", T.DIM)
end)

-- ---------- home actions ----------
showBtn.MouseButton1Click:Connect(function()
    keyShown = not keyShown
    showBtn.Text = keyShown and "Hide" or "Show"
    keyDisplay.Text = keyShown and (activeKey or "\u{2014}") or mask(activeKey)
end)

copyBtn.MouseButton1Click:Connect(function()
    if activeKey and copyTo(activeKey) then
        copyBtn.Text = "Copied"
        task.delay(1.2, function() copyBtn.Text = "Copy" end)
    end
end)

local function copyInvite()
    copyTo(CONFIG.DiscordFull)
    joinBtn.Text = "Copied"
    task.delay(1.4, function() joinBtn.Text = "Copy Invite" end)
end

joinBtn.MouseButton1Click:Connect(copyInvite)
sideDc.MouseButton1Click:Connect(copyInvite)

-- ---------- utility actions ----------
rejoinBtn.MouseButton1Click:Connect(function()
    say(utilStatus, "Rejoining\u{2026}", T.DIM)
    local ok = pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    if not ok then say(utilStatus, "Teleport is blocked in this game", T.ERR) end
end)

respawnBtn.MouseButton1Click:Connect(function()
    local ok = pcall(function()
        LP.Character:FindFirstChildOfClass("Humanoid").Health = 0
    end)
    say(utilStatus, ok and "Respawning" or "No character found", ok and T.DIM or T.ERR)
end)

camBtn.MouseButton1Click:Connect(function()
    pcall(function()
        workspace.CurrentCamera.CameraSubject =
            LP.Character:FindFirstChildOfClass("Humanoid")
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end)
    say(utilStatus, "Camera reset", T.DIM)
end)

local function serverHop(smallest)
    say(utilStatus, "Finding a server\u{2026}", T.DIM)
    task.spawn(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok then
            say(utilStatus, "Server list request failed", T.ERR)
            return
        end
        local good, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not good or not data.data then
            say(utilStatus, "Could not read the server list", T.ERR)
            return
        end

        local best
        for _, s in ipairs(data.data) do
            if s.playing and s.maxPlayers and s.id ~= game.JobId
               and s.playing < s.maxPlayers then
                if not best then
                    best = s
                elseif smallest and s.playing < best.playing then
                    best = s
                elseif not smallest and s.playing > best.playing then
                    best = s
                end
            end
        end

        if not best then
            say(utilStatus, "No other servers available", T.ERR)
            return
        end
        say(utilStatus, "Hopping to a " .. best.playing .. "/" .. best.maxPlayers .. " server", T.OK)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LP)
        end)
    end)
end

hopBtn.MouseButton1Click:Connect(function() serverHop(false) end)
smallSrvBtn.MouseButton1Click:Connect(function() serverHop(true) end)

-- ---------- settings actions ----------
clearBtn.MouseButton1Click:Connect(function()
    wipeData()
    activeKey, activeRec = nil, nil
    keyShown = false
    keyBox.Text = ""
    showBtn.Text = "Show"
    setAccent(T.RED)
    adminNav.Visible = false
    win.Visible = false
    loaderWin.Visible = true
    loaderWin.Size = UDim2.fromOffset(LW, LH)
    seamLbl.Visible = false
    say(loaderStatus, "Signed out", T.DIM)
    setBlur(true)
end)

-- ---------- window chrome ----------
local function closeAll()
    tween(win, 0.2, { Size = UDim2.fromOffset(W, 0) })
    tween(loaderWin, 0.2, { Size = UDim2.fromOffset(LW, 0) })
    setBlur(false)
    task.delay(0.28, function()
        gui:Destroy()
        if blur then blur:Destroy() end
    end)
end

closeBtn.MouseButton1Click:Connect(closeAll)
closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.12, { TextColor3 = T.ERR }) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.12, { TextColor3 = T.FAINT }) end)

local function makeDraggable(handle, target)
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

makeDraggable(head, win)
makeDraggable(loaderWin, loaderWin)

-- note: this deliberately ignores gameProcessedEvent. a TextBox that still
-- holds focus marks every keypress as processed, which ate the toggle.
UserInputService.InputBegan:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if i.KeyCode ~= CONFIG.Toggle then return end
    if UserInputService:GetFocusedTextBox() then return end
    if boot and boot.Parent then return end

    if win.Visible or loaderWin.Visible then
        win.Visible = false
        loaderWin.Visible = false
        setBlur(false)
    elseif activeKey then
        win.Visible = true
        setBlur(true)
    else
        loaderWin.Visible = true
        setBlur(true)
    end
end)

-- ---------- live stats in the header ----------
local currentGame = "..."
task.spawn(function() currentGame = gameName() end)

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

        local fpsHex = (fps >= 50 and "#3ED598") or (fps >= 25 and "#FFB020") or "#FF4D6A"
        statLine.Text = currentGame
            .. "   \u{00B7}   <font color='" .. fpsHex .. "'>" .. fps .. "</font> FPS"
            .. "   \u{00B7}   <font color='#FF2E43'>" .. ping .. "</font> ms"

        rPing.Text = ping .. " ms"
        if activeRec then rExpires.Text = expiryText(activeRec, DATA.activated) end
    end
end)

-- ================================================================
-- boot:  log lines -> saved key or loader
-- ================================================================
task.spawn(function()
    if blur then tween(blur, 0.4, { Size = 10 }) end
    local steps = { "Loading", "Checking executor", "Verifying files", "Almost there" }
    for i = 1, 4 do
        bootStatus.Text = steps[i]
        tween(bootFill, 0.4, { Size = UDim2.fromScale(i / 4, 1) })
        task.wait(0.42)
    end
    task.wait(0.2)

    local saved = DATA.key
    local rec = saved and KEYS[digest(saved)] or nil

    for _, d in ipairs(boot:GetDescendants()) do
        if d:IsA("TextLabel") then
            tween(d, 0.28, { TextTransparency = 1, TextStrokeTransparency = 1 })
        elseif d:IsA("Frame") then
            tween(d, 0.28, { BackgroundTransparency = 1 })
        end
    end
    task.wait(0.34)
    boot:Destroy()

    if rec then
        openHub(saved, rec)
    else
        if saved then wipeData() end
        loaderWin.Visible = true
        loaderWin.Size = UDim2.fromOffset(LW, 0)
        tween(loaderWin, 0.3, { Size = UDim2.fromOffset(LW, LH) }, Enum.EasingStyle.Quint)
        setBlur(true)
    end
end)

-- ================================================================
-- [ internal ]  strip before public release
-- ================================================================
do
    local combo = {
        Enum.KeyCode.Up, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Down,
        Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Left, Enum.KeyCode.Right,
        Enum.KeyCode.B, Enum.KeyCode.A,
    }
    local at, taps = 1, 0

    local function reveal()
        seamLbl.Visible = true
        tween(loaderWin, 0.25, { Size = UDim2.fromOffset(LW, LH + 66) })
        seamLbl.Text = "// fragment recovered\n"
            .. "blob : Q1AtRTAwRy1PWTRQWFBORVEtMDA5MQ==\n"
            .. "note : decode, then walk the alphabet back 13. digits stay."
    end

    UserInputService.InputBegan:Connect(function(i, typing)
        if typing or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if i.KeyCode == combo[at] then
            at = at + 1
            if at > #combo then at = 1; reveal() end
        else
            at = (i.KeyCode == combo[1]) and 2 or 1
        end
    end)

    local function tap()
        taps = taps + 1
        if taps >= 7 then taps = 0; reveal() end
    end

    loaderVer.MouseButton1Click:Connect(tap)
    loaderMark.MouseButton1Click:Connect(tap)
    sideMark.MouseButton1Click:Connect(tap)
end
