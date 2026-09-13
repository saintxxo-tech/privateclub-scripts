--[[ ================================================================
     privateclub.cc  ·  shared visuals engine
     ----------------------------------------------------------------
     Skyboxes, post-processing shaders, glow/neon ESP helpers and an
     audio player. No UI of its own: each script builds its own rows
     and calls into this, so adding it to another hub is a small
     block of widgets rather than a second implementation.

     usage:
       local V = loadstring(game:HttpGet(BASE .. "lib/visuals.lua"))()
       V.setSkybox(V.Skyboxes[3])
       V.applyPreset("Cinematic")
       V.Music.add("Song", 1837879082); V.Music.play(1)
     ================================================================ ]]

local Lighting   = game:GetService("Lighting")
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Http       = game:GetService("HttpService")
local LP         = Players.LocalPlayer

local V = {}
V.Version = "1.0"

-- ================================================================
-- skyboxes
-- ----------------------------------------------------------------
-- Creator-store skyboxes are usually a Sky packaged inside a model,
-- so we try InsertService first and fall back to treating the id as
-- a plain texture applied to all six faces.
-- ================================================================
V.Skyboxes = {
    { name = "Default",        id = 0 },
    { name = "Heaven Clouds",  id = 193659810 },
    { name = "Realistic",      id = 8238531417 },
    { name = "Night",          id = 15803128405 },
    { name = "Sunset",         id = 3017752195 },
    { name = "Classic Roblox", id = 339406852 },
    { name = "Scary Red Sky",  id = 136055162054954 },
    { name = "Candy",          id = 76584711398016 },
    { name = "Venus v2",       id = 110450592899174 },
    { name = "c00lkidd",       id = 133973334152130 },
    { name = "John Pork",      id = 8532598482 },
}

function V.skyboxNames()
    local out = {}
    for _, e in ipairs(V.Skyboxes) do table.insert(out, e.name) end
    return out
end

function V.skyboxByName(name)
    for _, e in ipairs(V.Skyboxes) do
        if e.name == name then return e end
    end
    return nil
end

local originalSky = Lighting:FindFirstChildOfClass("Sky")

local function clearOurSky()
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Sky") and v.Name == "pc_sky" then v:Destroy() end
    end
end

function V.restoreSky()
    clearOurSky()
    if originalSky and not originalSky.Parent then originalSky.Parent = Lighting end
end

-- builds a Sky for an asset id, whichever shape the asset happens to be
function V.skyFromAsset(id)
    local sky

    local ok, model = pcall(function()
        return game:GetService("InsertService"):LoadAsset(id)
    end)
    if ok and model then
        local found = model:FindFirstChildWhichIsA("Sky", true)
        if found then sky = found:Clone() end
        pcall(function() model:Destroy() end)
    end

    if not sky then
        local tex = "rbxassetid://" .. tostring(id)
        sky = Instance.new("Sky")
        sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = tex, tex, tex
        sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = tex, tex, tex
    end

    sky.Name = "pc_sky"
    return sky
end

-- accepts an entry from V.Skyboxes, a name, or a raw id
function V.setSkybox(which)
    local entry = which
    if type(which) == "string" then entry = V.skyboxByName(which) end
    if type(which) == "number" then entry = { name = tostring(which), id = which } end
    if not entry then return false, "unknown skybox" end

    if entry.id == 0 then
        V.restoreSky()
        return true, "default sky restored"
    end

    clearOurSky()
    if originalSky then originalSky.Parent = nil end

    local sky = V.skyFromAsset(entry.id)
    sky.Parent = Lighting
    return true, entry.name
end

function V.customSkybox(id)
    local clean = tostring(id):gsub("%D", "")
    if clean == "" then return false, "enter a numeric asset id" end
    return V.setSkybox(tonumber(clean))
end

-- ================================================================
-- shaders  ·  post-processing effects
-- ================================================================
local FX = {}          -- name -> instance we created
local defaults = {
    brightness = Lighting.Brightness,
    ambient = Lighting.Ambient,
    outdoor = Lighting.OutdoorAmbient,
    fogEnd = Lighting.FogEnd,
    fogStart = Lighting.FogStart,
    fogColour = Lighting.FogColor,
    clock = Lighting.ClockTime,
    exposure = Lighting.ExposureCompensation,
    globalShadows = Lighting.GlobalShadows,
}

local function fx(class, name)
    if FX[name] and FX[name].Parent then return FX[name] end
    local inst = Instance.new(class)
    inst.Name = "pc_" .. name
    inst.Parent = Lighting
    FX[name] = inst
    return inst
end

function V.clearShaders()
    for _, inst in pairs(FX) do
        if inst and inst.Parent then inst:Destroy() end
    end
    FX = {}
    Lighting.Brightness = defaults.brightness
    Lighting.Ambient = defaults.ambient
    Lighting.OutdoorAmbient = defaults.outdoor
    Lighting.FogEnd = defaults.fogEnd
    Lighting.FogStart = defaults.fogStart
    Lighting.FogColor = defaults.fogColour
    Lighting.ClockTime = defaults.clock
    Lighting.ExposureCompensation = defaults.exposure
    Lighting.GlobalShadows = defaults.globalShadows
end

-- individual controls, safe to call every frame
function V.colorCorrection(opts)
    local c = fx("ColorCorrectionEffect", "cc")
    if opts.brightness then c.Brightness = opts.brightness end
    if opts.contrast then c.Contrast = opts.contrast end
    if opts.saturation then c.Saturation = opts.saturation end
    if opts.tint then c.TintColor = opts.tint end
    c.Enabled = true
    return c
end

function V.bloom(opts)
    local b = fx("BloomEffect", "bloom")
    if opts.intensity then b.Intensity = opts.intensity end
    if opts.size then b.Size = opts.size end
    if opts.threshold then b.Threshold = opts.threshold end
    b.Enabled = true
    return b
end

function V.sunRays(opts)
    local s = fx("SunRaysEffect", "sun")
    if opts.intensity then s.Intensity = opts.intensity end
    if opts.spread then s.Spread = opts.spread end
    s.Enabled = true
    return s
end

function V.depthOfField(opts)
    local d = fx("DepthOfFieldEffect", "dof")
    if opts.focus then d.FocusDistance = opts.focus end
    if opts.inFocus then d.InFocusRadius = opts.inFocus end
    if opts.far then d.FarIntensity = opts.far end
    if opts.near then d.NearIntensity = opts.near end
    d.Enabled = true
    return d
end

function V.blur(size)
    local b = fx("BlurEffect", "blur")
    b.Size = size or 0
    b.Enabled = (size or 0) > 0
    return b
end

function V.atmosphere(opts)
    local a = fx("Atmosphere", "atmo")
    if opts.density then a.Density = opts.density end
    if opts.offset then a.Offset = opts.offset end
    if opts.haze then a.Haze = opts.haze end
    if opts.glare then a.Glare = opts.glare end
    if opts.colour then a.Color = opts.colour end
    if opts.decay then a.Decay = opts.decay end
    return a
end

-- ---------------- presets ----------------
V.Presets = {
    "Off", "Vivid", "Cinematic", "Clarity", "Noir",
    "Dream", "Night Vision", "Infrared", "Vaporwave", "Midnight",
}

function V.applyPreset(name)
    V.clearShaders()
    if name == "Off" then return true, "shaders off" end

    if name == "Vivid" then
        V.colorCorrection({ saturation = 0.42, contrast = 0.18, brightness = 0.02 })
        V.bloom({ intensity = 1.1, size = 22, threshold = 0.85 })
        V.atmosphere({ density = 0.28, haze = 0.6, glare = 0.2 })

    elseif name == "Cinematic" then
        V.colorCorrection({
            saturation = -0.08, contrast = 0.28,
            tint = Color3.fromRGB(255, 244, 232) })
        V.bloom({ intensity = 0.8, size = 30, threshold = 1.1 })
        V.depthOfField({ focus = 0.1, inFocus = 60, far = 0.32, near = 0 })
        V.atmosphere({ density = 0.36, haze = 1.4, glare = 0.4 })
        Lighting.ExposureCompensation = 0.25

    elseif name == "Clarity" then
        V.colorCorrection({ saturation = 0.16, contrast = 0.12 })
        V.atmosphere({ density = 0.05, haze = 0, glare = 0 })
        Lighting.FogEnd = 1e6
        Lighting.Brightness = 2.4

    elseif name == "Noir" then
        V.colorCorrection({ saturation = -1, contrast = 0.34, brightness = -0.02 })
        V.bloom({ intensity = 0.5, size = 34, threshold = 1.2 })

    elseif name == "Dream" then
        V.colorCorrection({
            saturation = 0.3, brightness = 0.06,
            tint = Color3.fromRGB(255, 236, 250) })
        V.bloom({ intensity = 2.2, size = 56, threshold = 0.6 })
        V.blur(5)

    elseif name == "Night Vision" then
        V.colorCorrection({
            saturation = -0.7, contrast = 0.5, brightness = 0.12,
            tint = Color3.fromRGB(120, 255, 140) })
        V.bloom({ intensity = 1.6, size = 18, threshold = 0.5 })
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(70, 120, 70)
        Lighting.ClockTime = 0

    elseif name == "Infrared" then
        V.colorCorrection({
            saturation = -0.5, contrast = 0.42,
            tint = Color3.fromRGB(255, 110, 110) })
        V.bloom({ intensity = 1.4, size = 20, threshold = 0.6 })
        Lighting.Ambient = Color3.fromRGB(120, 40, 40)

    elseif name == "Vaporwave" then
        V.colorCorrection({
            saturation = 0.5, contrast = 0.2,
            tint = Color3.fromRGB(255, 190, 255) })
        V.bloom({ intensity = 1.9, size = 44, threshold = 0.7 })
        V.atmosphere({
            density = 0.42, haze = 2, glare = 0.8,
            colour = Color3.fromRGB(255, 170, 230) })
        Lighting.ClockTime = 18.4

    elseif name == "Midnight" then
        V.colorCorrection({
            saturation = -0.2, contrast = 0.24,
            tint = Color3.fromRGB(200, 215, 255) })
        V.bloom({ intensity = 1.2, size = 38, threshold = 0.9 })
        V.atmosphere({
            density = 0.4, haze = 1.8,
            colour = Color3.fromRGB(120, 140, 200) })
        Lighting.ClockTime = 0
        Lighting.Brightness = 1.2
    end

    return true, name
end

function V.fullbright(on)
    if on then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = defaults.brightness
        Lighting.Ambient = defaults.ambient
        Lighting.OutdoorAmbient = defaults.outdoor
        Lighting.GlobalShadows = defaults.globalShadows
    end
end

-- ================================================================
-- glow / neon ESP helpers
-- ================================================================
function V.rainbow(speed, offset)
    local t = (tick() * (speed or 0.4) + (offset or 0)) % 1
    return Color3.fromHSV(t, 0.85, 1)
end

function V.pulse(colour, speed)
    local a = (math.sin(tick() * (speed or 3)) + 1) / 2
    return colour:Lerp(Color3.new(1, 1, 1), a * 0.45)
end

-- a soft, glowing highlight rather than a flat fill
function V.glow(char, colour, opts)
    if not char then return end
    opts = opts or {}
    local hl = char:FindFirstChild("pc_glow")

    if not opts.enabled then
        if hl then hl:Destroy() end
        return
    end

    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "pc_glow"
        hl.Parent = char
    end

    hl.DepthMode = opts.throughWalls == false
        and Enum.HighlightDepthMode.Occluded
        or Enum.HighlightDepthMode.AlwaysOnTop

    local c = colour or Color3.new(1, 1, 1)
    if opts.rainbow then c = V.rainbow(opts.rainbowSpeed) end
    if opts.pulse then c = V.pulse(c, opts.pulseSpeed) end

    hl.FillColor = c
    hl.OutlineColor = c
    hl.FillTransparency = opts.fill == nil and 0.55 or opts.fill
    hl.OutlineTransparency = opts.outline == nil and 0 or opts.outline
    return hl
end

-- the "shades" look: the body itself becomes neon
local neonCache = {}
function V.neon(char, colour, on)
    if not char then return end

    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            if on then
                if neonCache[p] == nil then
                    neonCache[p] = { p.Material, p.Color }
                end
                p.Material = Enum.Material.Neon
                p.Color = colour or Color3.new(1, 1, 1)
            elseif neonCache[p] then
                p.Material = neonCache[p][1]
                p.Color = neonCache[p][2]
                neonCache[p] = nil
            end
        end
    end
end

function V.clearNeon()
    for p, old in pairs(neonCache) do
        if p and p.Parent then
            p.Material = old[1]
            p.Color = old[2]
        end
    end
    neonCache = {}
end

-- ================================================================
-- audio player
-- ----------------------------------------------------------------
-- Roblox cannot stream Spotify, so this plays Roblox audio assets.
-- V.Spotify below talks to the real Spotify Web API for now-playing
-- and transport control, which is the closest thing that works.
-- ================================================================
local Music = {}
V.Music = Music

Music.playlist = {}
Music.index = 0
Music.loop = false
Music.shuffle = false

local sound = Instance.new("Sound")
sound.Name = "pc_music"
sound.Volume = 0.5
sound.Looped = false
sound.Parent = game:GetService("SoundService")
Music.sound = sound

function Music.add(name, id)
    local clean = tostring(id):gsub("%D", "")
    if clean == "" then return false, "bad id" end
    table.insert(Music.playlist, { name = name ~= "" and name or ("Track " .. clean), id = clean })
    return true, #Music.playlist
end

function Music.remove(i)
    if Music.playlist[i] then table.remove(Music.playlist, i) end
    if Music.index > #Music.playlist then Music.index = #Music.playlist end
end

function Music.clear()
    sound:Stop()
    Music.playlist = {}
    Music.index = 0
end

function Music.play(i)
    i = i or Music.index
    if i < 1 or i > #Music.playlist then return false, "nothing to play" end
    Music.index = i
    local track = Music.playlist[i]
    sound.SoundId = "rbxassetid://" .. track.id
    sound.TimePosition = 0
    sound:Play()
    return true, track.name
end

function Music.toggle()
    if #Music.playlist == 0 then return false, "playlist is empty" end
    if sound.IsPlaying then
        sound:Pause()
        return true, "paused"
    end
    if sound.SoundId == "" then return Music.play(1) end
    sound:Resume()
    return true, "playing"
end

function Music.stop() sound:Stop() end

function Music.next()
    if #Music.playlist == 0 then return false end
    if Music.shuffle then
        return Music.play(math.random(1, #Music.playlist))
    end
    local i = Music.index + 1
    if i > #Music.playlist then i = 1 end
    return Music.play(i)
end

function Music.prev()
    if #Music.playlist == 0 then return false end
    local i = Music.index - 1
    if i < 1 then i = #Music.playlist end
    return Music.play(i)
end

function Music.setVolume(v)
    sound.Volume = math.clamp((tonumber(v) or 50) / 100, 0, 1)
end

function Music.seek(pct)
    if sound.TimeLength > 0 then
        sound.TimePosition = sound.TimeLength * math.clamp(pct, 0, 1)
    end
end

function Music.nowPlaying()
    local track = Music.playlist[Music.index]
    if not track then return "nothing queued", 0, 0 end
    return track.name, sound.TimePosition, sound.TimeLength
end

-- auto advance
sound.Ended:Connect(function()
    if Music.loop then
        Music.play(Music.index)
    else
        Music.next()
    end
end)

-- ================================================================
-- spotify web api
-- ----------------------------------------------------------------
-- Read-out and transport only. Needs an OAuth access token from
-- developer.spotify.com, and playback control needs Premium. Tokens
-- expire after about an hour, so this is a paste-it-again affair.
-- ================================================================
local Spotify = { token = "" }
V.Spotify = Spotify

local function httpRequest(opts)
    local req = (syn and syn.request)
             or (type(http) == "table" and http.request)
             or http_request
             or request
    if type(req) ~= "function" then return nil, "executor has no http request" end
    local ok, res = pcall(req, opts)
    if not ok then return nil, "request failed" end
    return res
end

function Spotify.setToken(t)
    Spotify.token = tostring(t or ""):gsub("^%s*Bearer%s+", ""):gsub("%s", "")
    return Spotify.token ~= ""
end

local function spotifyCall(method, path, body)
    if Spotify.token == "" then return nil, "no token set" end
    local res, err = httpRequest({
        Url = "https://api.spotify.com/v1" .. path,
        Method = method,
        Headers = {
            ["Authorization"] = "Bearer " .. Spotify.token,
            ["Content-Type"] = "application/json",
        },
        Body = body and Http:JSONEncode(body) or nil,
    })
    if not res then return nil, err end

    local code = res.StatusCode or res.Status or 0
    if code == 401 then return nil, "token expired, paste a fresh one" end
    if code == 403 then return nil, "Spotify Premium required for that" end
    if code == 204 then return {}, "nothing playing" end
    if code < 200 or code >= 300 then return nil, "spotify http " .. tostring(code) end

    if res.Body and res.Body ~= "" then
        local ok, data = pcall(function() return Http:JSONDecode(res.Body) end)
        if ok then return data end
    end
    return {}
end

function Spotify.nowPlaying()
    local data, err = spotifyCall("GET", "/me/player/currently-playing")
    if not data then return nil, err end
    if not data.item then return nil, "nothing playing" end

    local artists = {}
    for _, a in ipairs(data.item.artists or {}) do
        table.insert(artists, a.name)
    end

    return {
        track = data.item.name or "?",
        artist = #artists > 0 and table.concat(artists, ", ") or "?",
        album = data.item.album and data.item.album.name or "?",
        playing = data.is_playing == true,
        progress = math.floor((data.progress_ms or 0) / 1000),
        length = math.floor((data.item.duration_ms or 0) / 1000),
    }
end

function Spotify.play()  return spotifyCall("PUT",  "/me/player/play") end
function Spotify.pause() return spotifyCall("PUT",  "/me/player/pause") end
function Spotify.next()  return spotifyCall("POST", "/me/player/next") end
function Spotify.prev()  return spotifyCall("POST", "/me/player/previous") end

function Spotify.volume(pct)
    return spotifyCall("PUT", "/me/player/volume?volume_percent="
        .. tostring(math.clamp(math.floor(pct or 50), 0, 100)))
end

-- ================================================================
-- teardown
-- ================================================================
function V.unload()
    V.clearShaders()
    V.restoreSky()
    V.clearNeon()
    Music.stop()
    if sound then sound:Destroy() end
    for _, plr in ipairs(Players:GetPlayers()) do
        local c = plr.Character
        local hl = c and c:FindFirstChild("pc_glow")
        if hl then hl:Destroy() end
    end
end

return V
