--[[
╔══════════════════════════════════════════════════════════════════╗
║  RFX v2 — Radar • Farm • Bypass • Hop                            ║
║  Blox Fruits (farm fruits) + jeux à anti-cheat client            ║
║  Delta • Solara • Fluxus • Xeno (Luau)                           ║
╚══════════════════════════════════════════════════════════════════╝

  Remotes utilisés (Blox Fruits) :
    ReplicatedStorage.Remotes.CommF_
      :InvokeServer("StoreFruit", <clé>, <tool>)   -- stockage
      :InvokeServer("getInventoryFruits")           -- inventaire
      :InvokeServer("GetFruits")                    -- shop
  Pickup : firetouchinterest sur le Handle + ProximityPrompt.
  Tout est en pcall : si un remote n'existe pas, le module se désactive
  proprement au lieu de casser le script.
--]]

if _G.RFX_Unload then pcall(_G.RFX_Unload) end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TeleportService  = game:GetService("TeleportService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════════════════════
--  WHITELIST — l'ID passe par le lien, le script le vérifie
--
--  Le loader fait :  loadstring(game:HttpGet(URL .. "?id=" .. ID))(ID)
--  L'ID reçu doit :
--    1. être dans la table WHITELIST
--    2. correspondre au compte qui exécute le script (LocalPlayer.UserId)
--  Sinon : rien ne se lance, ni GUI ni hook.
-- ══════════════════════════════════════════════════════════════
local WHITELIST = {
    [12020224798] = true,   -- compte autorisé
}

-- ID transmis en argument du chunk par le loader
local LINK_ID = tonumber((...))

-- secours : loader qui passe l'ID par getgenv() au lieu d'un argument
if not LINK_ID and type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        LINK_ID = tonumber(env.RFX_LINK_ID)
    end
end

if not LINK_ID or not WHITELIST[LINK_ID] or LINK_ID ~= LocalPlayer.UserId then
    print("[RFX] accès refusé")
    return
end

math.randomseed(os.clock() * 1e6)

-- ══════════════════════════════════════════════════════════════
--  PALETTE / CONFIG
-- ══════════════════════════════════════════════════════════════
local C = {
    accent = Color3.fromRGB(0, 220, 170),
    accentDim = Color3.fromRGB(0, 120, 96),
    bg     = Color3.fromRGB(13, 13, 17),
    panel  = Color3.fromRGB(20, 20, 26),
    row    = Color3.fromRGB(28, 28, 36),
    rowHi  = Color3.fromRGB(38, 38, 48),
    text   = Color3.fromRGB(232, 232, 240),
    sub    = Color3.fromRGB(138, 138, 152),
    danger = Color3.fromRGB(220, 80, 96),
    gold   = Color3.fromRGB(255, 190, 70),
}

local CONFIG = {
    Radar = {
        enabled      = true,
        maxDistance  = 5000,
        scanInterval = 5,
        tpKey        = Enum.KeyCode.T,
    },
    Waypoint = {
        safeTp    = true,
        stepStuds = 45,
        stepDelay = 0.03,
    },
    Movement = {
        walkSpeed = 16,
        jumpPower = 50,
        antiVoid  = true,
    },
    Protect = {
        antiKick      = true,
        spoofHumanoid = false,
        antiAfk       = true,
    },
    Hop = {
        auto       = false,
        delay      = 30,
        minPlayers = 0,
        maxPlayers = 10,
        privateLink = "",
    },
    Farm = {
        target       = "Any",   -- Any | Legendary+ | Mythical | <NomDeFruit>
        autoStore    = true,
        hopOnEmpty   = true,
        solo         = false,
        pickupRetry  = 3,
        collectDelay = 0.8,
    },
}

local TARGET_CYCLE = { "Any", "Legendary+", "Mythical", "Dragon", "Leopard", "Kitsune", "Dough", "Venom" }

-- ══════════════════════════════════════════════════════════════
--  UTILS
-- ══════════════════════════════════════════════════════════════
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function httpGet(url)
    local fn
    pcall(function()
        if game.HttpGet then fn = function(u) return game:HttpGet(u) end end
    end)
    if not fn and syn and syn.request then
        fn = function(u) return syn.request({ Url = u, Method = "GET" }).Body end
    end
    if not fn and request then
        fn = function(u) local r = request({ Url = u, Method = "GET" }); return r and r.Body end
    end
    if not fn and http_request then
        fn = function(u) return http_request({ Url = u, Method = "GET" }).Body end
    end
    if not fn then return nil end
    local ok, body = pcall(fn, url)
    if ok then return body end
    return nil
end

local function getChar()
    return LocalPlayer.Character
end

local function getHRP()
    local char = getChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ══════════════════════════════════════════════════════════════
--  FRUIT DATABASE
-- ══════════════════════════════════════════════════════════════
local TIER_COLORS = {
    Common    = Color3.fromRGB(190, 190, 190),
    Uncommon  = Color3.fromRGB(120, 200, 255),
    Rare      = Color3.fromRGB(180, 130, 255),
    Legendary = Color3.fromRGB(255, 175, 70),
    Mythical  = Color3.fromRGB(255, 80, 80),
}

local TIER_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Legendary = 4, Mythical = 5 }

local FRUIT_TIERS = {
    Rocket="Common", Spin="Common", Chop="Common", Spring="Common",
    Bomb="Common", Smoke="Common", Spike="Common", Blade="Common",
    Flame="Uncommon", Falcon="Uncommon", Ice="Uncommon", Sand="Uncommon",
    Dark="Uncommon", Diamond="Uncommon", Light="Uncommon", Rubber="Uncommon",
    Barrier="Rare", Ghost="Rare", Magma="Rare", Quake="Rare",
    Buddha="Rare", Love="Rare", Spider="Rare", Sound="Rare",
    Phoenix="Legendary", Portal="Legendary", Rumble="Legendary",
    Paw="Legendary", Gravity="Legendary", Dough="Legendary",
    Shadow="Mythical", Venom="Mythical", Control="Mythical", Spirit="Mythical",
    Dragon="Mythical", Leopard="Mythical", Kitsune="Mythical", Yeti="Mythical",
    Gas="Mythical", ["T-Rex"]="Mythical", Mammoth="Mythical",
    Blizzard="Mythical", Pain="Mythical", Revive="Mythical", Creation="Mythical",
}

local DISPLAY = {}
for name, tier in pairs(FRUIT_TIERS) do
    DISPLAY[name:lower()] = { name = name, tier = tier }
end

local matchCache = {}

local function normalize(raw)
    local s = raw:lower()
    s = s:gsub("%s*fruit%s*$", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function matchFruit(rawName)
    local cached = matchCache[rawName]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local n = normalize(rawName)
    local entry = DISPLAY[n]
    if not entry then
        local base = n:match("^(.+)%-%1$")
        if base then entry = DISPLAY[base] end
    end
    if entry then
        entry = { name = entry.name, tier = entry.tier }
    end

    matchCache[rawName] = entry or false
    return entry
end

local function getRoot(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    if inst:IsA("Tool") then
        return inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function getPosition(inst)
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, pivot = pcall(function() return inst:GetPivot().Position end)
        if ok and pivot then return pivot end
    end
    local root = getRoot(inst)
    return root and root.Position or nil
end

-- ══════════════════════════════════════════════════════════════
--  REMOTES
-- ══════════════════════════════════════════════════════════════
local Remotes = {}

function Remotes.get()
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if not folder then return nil end
    return folder:FindFirstChild("CommF_")
end

function Remotes.invoke(...)
    local remote = Remotes.get()
    if not remote then return nil end
    local args = { ... }
    local unpackFn = table.unpack or unpack
    local ok, result = pcall(function()
        return remote:InvokeServer(unpackFn(args))
    end)
    if ok then return result end
    return nil
end

-- ══════════════════════════════════════════════════════════════
--  PROTECT
-- ══════════════════════════════════════════════════════════════
local Protect = {
    humanoid      = nil,
    realWalkSpeed = CONFIG.Movement.walkSpeed,
    realJumpPower = CONFIG.Movement.jumpPower,
    viewWalkSpeed = 16,
    viewJumpPower = 50,
    kickHooked    = false,
    indexHooked   = false,
}

function Protect.hookKick()
    if Protect.kickHooked then return true end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        return false
    end

    local old
    local ok = pcall(function()
        old = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "Kick" and CONFIG.Protect.antiKick then
                if self == LocalPlayer then return end
            end
            return old(self, ...)
        end)
    end)

    Protect.kickHooked = ok and old ~= nil
    return Protect.kickHooked
end

function Protect.hookIndex()
    if Protect.indexHooked then return true end
    if type(hookmetamethod) ~= "function" then return false end

    local old
    local ok = pcall(function()
        old = hookmetamethod(game, "__index", function(self, key)
            if self == Protect.humanoid and CONFIG.Protect.spoofHumanoid then
                if key == "WalkSpeed" then return Protect.viewWalkSpeed end
                if key == "JumpPower" then return Protect.viewJumpPower end
            end
            return old(self, key)
        end)
    end)

    Protect.indexHooked = ok and old ~= nil
    return Protect.indexHooked
end

local function applySpeed()
    local hum = Protect.humanoid
    if not hum then return end
    hum.WalkSpeed = Protect.realWalkSpeed
    hum.JumpPower  = Protect.realJumpPower
end

local function bindCharacter(char)
    Protect.humanoid = char:WaitForChild("Humanoid", 8)
    applySpeed()
end

if getChar() then bindCharacter(getChar()) end
LocalPlayer.CharacterAdded:Connect(bindCharacter)

if CONFIG.Protect.antiKick then Protect.hookKick() end
Protect.hookIndex()

LocalPlayer.Idled:Connect(function()
    if not CONFIG.Protect.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ══════════════════════════════════════════════════════════════
--  MOVEMENT
-- ══════════════════════════════════════════════════════════════
local Movement = { token = nil }

function Movement.tp(pos)
    local hrp = getHRP()
    if not hrp or not pos then return false end

    local target = pos + Vector3.new(0, 3.5, 0)

    if not CONFIG.Waypoint.safeTp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(target) * (hrp.CFrame - hrp.CFrame.Position)
        return true
    end

    if Movement.token then Movement.token.cancelled = true end
    local token = { cancelled = false }
    Movement.token = token

    task.spawn(function()
        local step  = math.max(5, CONFIG.Waypoint.stepStuds)
        local delay = math.max(0.008, CONFIG.Waypoint.stepDelay)

        while not token.cancelled do
            local root = getHRP()
            if not root then break end

            local delta = target - root.Position
            if delta.Magnitude <= step then
                root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
                break
            end

            root.CFrame = CFrame.new(root.Position + delta.Unit * step)
                * (root.CFrame - root.CFrame.Position)
            task.wait(delay)
        end
    end)

    return true
end

function Movement.setWalk(v)
    Protect.realWalkSpeed = clamp(v, 8, 500)
    applySpeed()
end

function Movement.setJump(v)
    Protect.realJumpPower = clamp(v, 20, 500)
    applySpeed()
end

RunService.Heartbeat:Connect(function()
    if not CONFIG.Movement.antiVoid then return end
    local char = getChar()
    local hrp = getHRP()
    if not hrp then return end
    if hrp.Position.Y < -160 then
        pcall(function() char:PivotTo(CFrame.new(0, 200, 0)) end)
    end
end)

-- ══════════════════════════════════════════════════════════════
--  RADAR
-- ══════════════════════════════════════════════════════════════
local Radar = { tracked = {}, connections = {}, cooldown = {} }

local function isCandidate(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Tool")) then
        return nil
    end

    local char = getChar()
    if char and inst:IsDescendantOf(char) then return nil end
    if inst:IsA("Tool") and inst.Parent ~= workspace then return nil end

    local entry = matchFruit(inst.Name)
    if not entry then return nil end

    local p = inst.Parent
    while p and p ~= workspace do
        if matchFruit(p.Name) then return nil end
        p = p.Parent
    end

    return entry
end

function Radar.remove(inst)
    local data = Radar.tracked[inst]
    if not data then return end
    if data.highlight then pcall(function() data.highlight:Destroy() end) end
    if data.billboard then pcall(function() data.billboard:Destroy() end) end
    Radar.tracked[inst] = nil
end

function Radar.add(inst, entry, pos)
    if Radar.tracked[inst] then return end
    local root = getRoot(inst)
    if not root then return end

    local color = TIER_COLORS[entry.tier] or C.accent

    local highlight = Instance.new("Highlight")
    highlight.Name = "RFX_ESP"
    highlight.FillColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0.15
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = CONFIG.Radar.enabled
    highlight.Parent = inst:IsA("Model") and inst or root

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RFX_LABEL"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(200, 36)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Adornee = root
    billboard.Enabled = CONFIG.Radar.enabled

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = entry.name
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.35
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    billboard.Parent = root

    Radar.tracked[inst] = {
        entry = entry, pos = pos, highlight = highlight,
        billboard = billboard, label = label, lastText = "",
    }
end

function Radar.scanContainer(container)
    local list = container:GetDescendants()
    for i, inst in ipairs(list) do
        if not Radar.tracked[inst] then
            local entry = isCandidate(inst)
            if entry then
                local pos = getPosition(inst)
                if pos then Radar.add(inst, entry, pos) end
            end
        end
        if i % 400 == 0 then task.wait() end
    end
end

function Radar.clear()
    for inst in pairs(Radar.tracked) do Radar.remove(inst) end
end

function Radar.setEnabled(state)
    CONFIG.Radar.enabled = state
    for _, data in pairs(Radar.tracked) do
        if data.highlight then data.highlight.Enabled = state end
        if data.billboard then data.billboard.Enabled = state end
    end
end

function Radar.count()
    local n = 0
    for _ in pairs(Radar.tracked) do n = n + 1 end
    return n
end

function Radar.nearest(filterFn)
    local hrp = getHRP()
    if not hrp then return nil, nil end

    local best, bestDist, bestPos
    for inst, data in pairs(Radar.tracked) do
        local skip = false
        local untilTime = Radar.cooldown[inst]
        if untilTime and os.clock() < untilTime then skip = true end
        if not skip and inst.Parent and data.pos then
            if not filterFn or filterFn(data.entry) then
                local d = (data.pos - hrp.Position).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist, bestPos = inst, d, data.pos
                end
            end
        end
    end
    return best, bestPos
end

function Radar.pickup(inst)
    if not inst or not inst.Parent then return false end

    local root = getRoot(inst)
    local hrp = getHRP()
    if root and hrp and type(firetouchinterest) == "function" then
        pcall(function() firetouchinterest(hrp, root, 0) end)
        pcall(function() firetouchinterest(hrp, root, 1) end)
    end

    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            pcall(function() fireproximityprompt(d) end)
            pcall(function() d:InputHoldBegin() end)
        end
        if d:IsA("ClickDetector") and type(fireclickdetector) == "function" then
            pcall(function() fireclickdetector(d) end)
        end
    end
    return true
end

Radar.connections[#Radar.connections + 1] = workspace.DescendantAdded:Connect(function(inst)
    if Radar.tracked[inst] then return end
    local entry = isCandidate(inst)
    if entry then
        local pos = getPosition(inst)
        if pos then Radar.add(inst, entry, pos) end
    end
end)

task.spawn(function()
    while true do
        task.wait(CONFIG.Radar.scanInterval)
        if CONFIG.Radar.enabled then
            pcall(function() Radar.scanContainer(workspace) end)
        end
    end
end)

task.spawn(function()
    task.wait(0.5)
    pcall(function() Radar.scanContainer(workspace) end)
end)

local updateAcc = 0
Radar.connections[#Radar.connections + 1] = RunService.Heartbeat:Connect(function(dt)
    updateAcc = updateAcc + dt
    if updateAcc < 0.15 then return end
    updateAcc = 0

    local hrp = getHRP()
    if not hrp then return end

    for inst, data in pairs(Radar.tracked) do
        if not inst.Parent then
            Radar.remove(inst)
        else
            local pos = getPosition(inst)
            data.pos = pos
            if pos and data.label then
                local dist = (pos - hrp.Position).Magnitude
                local txt = string.format("%s  •  %dm", data.entry.name, math.floor(dist + 0.5))
                if txt ~= data.lastText then
                    data.label.Text = txt
                    data.lastText = txt
                end
                data.label.Visible = CONFIG.Radar.enabled and dist <= CONFIG.Radar.maxDistance
                if data.highlight then data.highlight.Enabled = CONFIG.Radar.enabled end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  STORE (auto store fruit)
-- ══════════════════════════════════════════════════════════════
local Store = { stored = 0 }

local function stripFruit(name)
    local n = name:gsub("%s*Fruit%s*$", "")
    n = n:gsub("^%s+", ""):gsub("%s+$", "")
    return n
end

local function isFruitTool(tool)
    if not tool:IsA("Tool") then return false end
    if tool:FindFirstChild("Fruit") then return true end
    if tool.Name:lower():find("fruit", 1, true) then return true end
    return matchFruit(tool.Name) ~= nil
end

function Store.tools()
    local list = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = getChar()

    for _, container in ipairs({ backpack, char }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if isFruitTool(tool) then list[#list + 1] = tool end
            end
        end
    end
    return list
end

function Store.one(tool)
    local remote = Remotes.get()
    if not remote then return false end

    local key = stripFruit(tool.Name)

    local attempts = {
        function() return remote:InvokeServer("StoreFruit", key, tool) end,
        function() return remote:InvokeServer("StoreFruit", key) end,
        function() return remote:InvokeServer("StoreFruit", tool.Name) end,
        function() return remote:InvokeServer("StoreFruit", tool.Name, tool) end,
    }

    for _, attempt in ipairs(attempts) do
        pcall(attempt)
        task.wait(0.12)
        if not tool.Parent or tool.Parent == game then
            return true
        end
    end
    return false
end

function Store.all()
    local tools = Store.tools()
    local done = 0
    for _, tool in ipairs(tools) do
        if Store.one(tool) then
            done = done + 1
            Store.stored = Store.stored + 1
        end
    end
    return done
end

-- ══════════════════════════════════════════════════════════════
--  HOP
-- ══════════════════════════════════════════════════════════════
local Hop = { busy = false, cooldown = 0, lastSeen = os.clock(), status = nil }

local function setStatus(text)
    if Hop.status then Hop.status.Text = text end
end

function Hop.fetch(maxOverride)
    local maxPlayers = maxOverride or CONFIG.Hop.maxPlayers
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        game.PlaceId
    )
    local body = httpGet(url)
    if not body then return {} end

    local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return {}
    end

    local list = {}
    for _, s in ipairs(decoded.data) do
        if s.id and s.playing and s.id ~= game.JobId then
            if s.playing >= CONFIG.Hop.minPlayers and s.playing <= maxPlayers then
                list[#list + 1] = s
            end
        end
    end
    table.sort(list, function(a, b) return a.playing < b.playing end)
    return list
end

function Hop.joinPrivate()
    local link = CONFIG.Hop.privateLink
    if link == "" then return false end

    local code = link:match("[Pp]rivate[Ss]erver[Ll]ink[Cc]ode=([%w]+)")
    if not code then
        setStatus("lien privé invalide")
        return false
    end

    setStatus("solo → serv privé")
    local ok = pcall(function()
        TeleportService:TeleportToPrivateServer(game.PlaceId, code, { LocalPlayer })
    end)
    if ok then return true end
    setStatus("serv privé refusé")
    return false
end

function Hop.execute(solo)
    if Hop.busy then return false end
    if os.clock() < Hop.cooldown then return false end

    Hop.busy = true
    Hop.cooldown = os.clock() + 8

    task.spawn(function()
        if solo and Hop.joinPrivate() then
            task.wait(3)
            Hop.busy = false
            return
        end

        local maxPlayers = solo and 1 or CONFIG.Hop.maxPlayers
        local servers = Hop.fetch(maxPlayers)

        local target
        if #servers > 0 then
            local pool = math.min(#servers, 15)
            target = servers[math.random(1, pool)]
        elseif solo then
            servers = Hop.fetch(2)
            if #servers > 0 then target = servers[1] end
        end

        setStatus(target and ("hop → " .. target.playing .. " joueurs") or "hop aléatoire")

        local ok = pcall(function()
            if target then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
            else
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)

        if not ok then
            setStatus("hop refusé — retry 5s")
            Hop.cooldown = os.clock() + 5
        end

        task.wait(3)
        Hop.busy = false
    end)

    return true
end

TeleportService.TeleportInitFailed:Connect(function()
    Hop.busy = false
    Hop.cooldown = os.clock() + 5
    setStatus("teleport refusé — retry 5s")
end)

-- ══════════════════════════════════════════════════════════════
--  FARM — la boucle complète
-- ══════════════════════════════════════════════════════════════
local Farm = {
    active = false,
    token  = 0,
    stats  = { collected = 0, stored = 0, hops = 0, seen = 0 },
    label  = nil,
}

function Farm.filter(entry)
    local t = CONFIG.Farm.target
    if t == "Any" then return true end
    if t == "Legendary+" then return (TIER_ORDER[entry.tier] or 0) >= 4 end
    if t == "Mythical" then return entry.tier == "Mythical" end
    return entry.name == t
end

local function farmStatsText()
    return string.format(
        "vu %d  •  ramassé %d  •  stocké %d  •  hop %d",
        Farm.stats.seen, Farm.stats.collected, Farm.stats.stored, Farm.stats.hops
    )
end

function Farm.refreshStats()
    if Farm.label then Farm.label.Text = farmStatsText() end
end

function Farm.collect(inst, pos)
    Movement.tp(pos)
    task.wait(0.3)

    for _ = 1, 25 do
        local hrp = getHRP()
        local p = getPosition(inst)
        if not hrp or not p or not inst.Parent then break end
        if (hrp.Position - p).Magnitude < 12 then break end
        task.wait(0.06)
    end

    Radar.pickup(inst)

    for _ = 1, CONFIG.Farm.pickupRetry do
        task.wait(0.35)
        if not inst.Parent then return true end
        Radar.pickup(inst)
    end

    return not inst.Parent
end

function Farm.start()
    if Farm.active then return true end
    Farm.active = true
    Farm.token = Farm.token + 1
    local myToken = Farm.token

    Radar.setEnabled(true)

    task.spawn(function()
        task.wait(1.2)

        while Farm.active and Farm.token == myToken do
            if not getChar() or not getHRP() then
                task.wait(0.5)
            else
                local inst, pos = Radar.nearest(Farm.filter)

                if inst and pos then
                    Farm.stats.seen = Farm.stats.seen + 1
                    setStatus("farm → " .. inst.Name)
                    Farm.refreshStats()

                    local ok = Farm.collect(inst, pos)
                    if ok then
                        Farm.stats.collected = Farm.stats.collected + 1
                        setStatus("ramassé " .. inst.Name)
                    else
                        Radar.cooldown[inst] = os.clock() + 12
                        setStatus("échec pickup — cooldown " .. inst.Name)
                    end

                    Radar.remove(inst)
                    Farm.refreshStats()

                    if CONFIG.Farm.autoStore then
                        local n = Store.all()
                        if n > 0 then
                            Farm.stats.stored = Farm.stats.stored + n
                            setStatus("stocké " .. n .. " fruit(s)")
                            Farm.refreshStats()
                        end
                    end

                    task.wait(CONFIG.Farm.collectDelay)
                else
                    if CONFIG.Farm.hopOnEmpty then
                        Farm.stats.hops = Farm.stats.hops + 1
                        setStatus("aucun fruit — hop")
                        Farm.refreshStats()
                        Hop.execute(CONFIG.Farm.solo)
                        task.wait(6)
                    else
                        setStatus("aucun fruit — attente")
                        task.wait(2)
                    end
                end
            end
        end
    end)

    return true
end

function Farm.stop()
    Farm.active = false
    Farm.token = Farm.token + 1
    if Movement.token then Movement.token.cancelled = true end
end

function Farm.toggle()
    if Farm.active then
        Farm.stop()
        return false
    end
    Farm.start()
    return true
end

-- auto-hop passif si le farm est off
task.spawn(function()
    while true do
        task.wait(1)
        if not Farm.active then
            local any = Radar.count() > 0
            if any then Hop.lastSeen = os.clock() end
            if CONFIG.Hop.auto and not any
                and (os.clock() - Hop.lastSeen) > CONFIG.Hop.delay then
                setStatus("rien depuis " .. CONFIG.Hop.delay .. "s — hop")
                Hop.execute(false)
                Hop.lastSeen = os.clock()
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  UI
-- ══════════════════════════════════════════════════════════════
local UI = {
    connections = {},
    tabs = {},
    current = nil,
    countLabel = nil,
    fps = 0,
    frames = 0,
    fpsClock = os.clock(),
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = o
    return c
end

local function stroke(o, col, trans)
    local s = Instance.new("UIStroke")
    s.Color = col or C.rowHi
    s.Transparency = trans or 0.5
    s.Parent = o
    return s
end

local function makeRow(parent)
    local r = new("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = C.row,
        BorderSizePixel = 0,
    }, parent)
    corner(r, 6)
    return r
end

local function makeLabel(parent, text, x, size)
    return new("TextLabel", {
        Size = size or UDim2.new(1, -16, 1, 0),
        Position = UDim2.fromOffset(x or 10, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = C.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })
end

local function makeToggle(parent, text, default, callback, accentColor)
    local row = makeRow(parent)
    makeLabel(row, text)

    local accent = accentColor or C.accent

    local track = new("Frame", {
        Size = UDim2.fromOffset(38, 20),
        Position = UDim2.new(1, -48, 0.5, -10),
        BackgroundColor3 = default and accent or C.rowHi,
        BorderSizePixel = 0,
    }, row)
    corner(track, 10)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(default and 21 or 2, 2),
        BackgroundColor3 = C.text,
        BorderSizePixel = 0,
    }, track)
    corner(knob, 8)

    local state = default

    local function refresh()
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and accent or C.rowHi,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = UDim2.fromOffset(state and 21 or 2, 2),
        }):Play()
    end

    local btn = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
    }, row)

    btn.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        if callback then callback(state) end
    end)

    return {
        set = function(v) state = v; refresh() end,
        get = function() return state end,
    }
end

local function makeSlider(parent, text, min, max, default, callback)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = C.row,
        BorderSizePixel = 0,
    }, parent)
    corner(row, 6)

    local lbl = makeLabel(row, text, 10, UDim2.new(1, -80, 0, 20))
    lbl.Position = UDim2.fromOffset(10, 4)

    local val = new("TextLabel", {
        Size = UDim2.fromOffset(70, 20),
        Position = UDim2.new(1, -80, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = C.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    local track = new("Frame", {
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.fromOffset(10, 34),
        BackgroundColor3 = C.rowHi,
        BorderSizePixel = 0,
    }, row)
    corner(track, 3)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 3)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(0, -7, 0.5, -7),
        BackgroundColor3 = C.text,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    corner(knob, 7)

    local value = default
    local dragging = false

    local function paint(rel)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
    end

    local function updateFromX(x)
        if track.AbsoluteSize.X <= 0 then return end
        local rel = clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * rel + 0.5)
        val.Text = tostring(value)
        paint(rel)
        if callback then callback(value) end
    end

    paint((default - min) / math.max(1, max - min))

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.fromOffset(0, 24),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 3,
    }, row)

    hit.MouseButton1Down:Connect(function(x)
        dragging = true
        updateFromX(x)
    end)

    UI.connections[#UI.connections + 1] = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            updateFromX(input.Position.X)
        end
    end)

    UI.connections[#UI.connections + 1] = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        set = function(v)
            value = clamp(v, min, max)
            val.Text = tostring(math.floor(value))
            paint((value - min) / math.max(1, max - min))
        end,
        get = function() return value end,
    }
end

local function makeButton(parent, text, callback, height)
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, height or 32),
        BackgroundColor3 = C.row,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = C.text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = true,
    }, parent)
    corner(row, 6)
    stroke(row, C.rowHi, 0.7)

    row.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    return row
end

local function makeSectionLabel(parent, text)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = text:upper(),
        TextColor3 = C.sub,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })
end

---------------------------------------------------------------
--  ROOT
---------------------------------------------------------------
local gui = new("ScreenGui", {
    Name = "RFX_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local okCore = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okCore or not gui.Parent then gui.Parent = PlayerGui end

local main = new("Frame", {
    Size = UDim2.fromOffset(430, 340),
    Position = UDim2.new(0, 40, 0, 90),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    Active = true,
}, gui)
corner(main, 10)
stroke(main, C.accent, 0.6)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
corner(header, 10)

new("TextLabel", {
    Size = UDim2.new(0, 160, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1,
    Text = "RFX v2",
    TextColor3 = C.accent,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

-- bouton FARM rapide dans le header
local headerFarmBtn = new("TextButton", {
    Size = UDim2.fromOffset(74, 24),
    Position = UDim2.new(1, -196, 0.5, -12),
    BackgroundColor3 = C.accentDim,
    Text = "FARM",
    TextColor3 = C.text,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    BorderSizePixel = 0,
}, header)
corner(headerFarmBtn, 6)

local closeBtn = new("TextButton", {
    Size = UDim2.fromOffset(26, 26),
    Position = UDim2.new(1, -34, 0.5, -13),
    BackgroundColor3 = C.row,
    Text = "×",
    TextColor3 = C.danger,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    BorderSizePixel = 0,
}, header)
corner(closeBtn, 6)

local minBtn = new("TextButton", {
    Size = UDim2.fromOffset(26, 26),
    Position = UDim2.new(1, -66, 0.5, -13),
    BackgroundColor3 = C.row,
    Text = "–",
    TextColor3 = C.sub,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, header)
corner(minBtn, 6)

local tabBar = new("Frame", {
    Size = UDim2.new(1, -16, 0, 30),
    Position = UDim2.fromOffset(8, 42),
    BackgroundTransparency = 1,
}, main)

new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local contentArea = new("Frame", {
    Size = UDim2.new(1, -16, 1, -84),
    Position = UDim2.fromOffset(8, 76),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, main)

local statusBar = new("Frame", {
    Size = UDim2.new(1, -16, 0, 26),
    Position = UDim2.new(0, 8, 1, -30),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
corner(statusBar, 6)

local statusText = new("TextLabel", {
    Size = UDim2.new(0.52, -10, 1, 0),
    Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1,
    Text = "prêt",
    TextColor3 = C.sub,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, statusBar)

local countText = new("TextLabel", {
    Size = UDim2.new(0.48, -10, 1, 0),
    Position = UDim2.new(0.52, 0, 0, 0),
    BackgroundTransparency = 1,
    Text = "0 fruit  •  0ms  •  60 fps",
    TextColor3 = C.sub,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
}, statusBar)

Hop.status = statusText
UI.countLabel = countText

---------------------------------------------------------------
--  TABS
---------------------------------------------------------------
local function createTab(name, order)
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(77, 30),
        BackgroundColor3 = C.panel,
        Text = name,
        TextColor3 = C.sub,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BorderSizePixel = 0,
        LayoutOrder = order,
    }, tabBar)
    corner(btn, 6)

    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.rowHi,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ClipsDescendants = true,
    }, contentArea)

    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, page)

    UI.tabs[name] = { button = btn, page = page }

    btn.MouseButton1Click:Connect(function()
        for n, t in pairs(UI.tabs) do
            t.page.Visible = (n == name)
            t.button.TextColor3 = (n == name) and C.accent or C.sub
        end
        UI.current = name
    end)

    return page
end

local farmPage    = createTab("Farm", 1)
local radarPage   = createTab("Radar", 2)
local waypointPage= createTab("TP", 3)
local bypassPage  = createTab("Bypass", 4)
local hopPage     = createTab("Hop", 5)

local function showTab(name)
    for n, t in pairs(UI.tabs) do
        t.page.Visible = (n == name)
        t.button.TextColor3 = (n == name) and C.accent or C.sub
    end
    UI.current = name
end

showTab("Farm")

---------------------------------------------------------------
--  FARM PAGE
---------------------------------------------------------------
local farmBig = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = C.accentDim,
    Text = "FARM FRUIT  •  OFF",
    TextColor3 = C.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
}, farmPage)
corner(farmBig, 8)
stroke(farmBig, C.accent, 0.4)

local guiMini = nil

local function refreshFarmBig()
    if Farm.active then
        farmBig.Text = "FARM FRUIT  •  ON"
        farmBig.BackgroundColor3 = C.accent
        headerFarmBtn.BackgroundColor3 = C.accent
        headerFarmBtn.TextColor3 = C.bg
        if guiMini then guiMini.BackgroundColor3 = C.accent end
    else
        farmBig.Text = "FARM FRUIT  •  OFF"
        farmBig.BackgroundColor3 = C.accentDim
        headerFarmBtn.BackgroundColor3 = C.accentDim
        headerFarmBtn.TextColor3 = C.text
        if guiMini then guiMini.BackgroundColor3 = C.panel end
    end
end

local function toggleFarm()
    Farm.toggle()
    refreshFarmBig()
    Farm.refreshStats()
end

farmBig.MouseButton1Click:Connect(toggleFarm)

local targetBtn = makeButton(farmPage, "Cible : " .. CONFIG.Farm.target, function()
    local idx = 1
    for i, v in ipairs(TARGET_CYCLE) do
        if v == CONFIG.Farm.target then idx = i break end
    end
    idx = idx % #TARGET_CYCLE + 1
    CONFIG.Farm.target = TARGET_CYCLE[idx]
    targetBtn.Text = "Cible : " .. CONFIG.Farm.target
    setStatus("cible → " .. CONFIG.Farm.target)
end, 30)

makeToggle(farmPage, "Auto store fruit", CONFIG.Farm.autoStore, function(v)
    CONFIG.Farm.autoStore = v
end)

makeToggle(farmPage, "Server hop si aucun fruit", CONFIG.Farm.hopOnEmpty, function(v)
    CONFIG.Farm.hopOnEmpty = v
end)

makeToggle(farmPage, "Mode solo (serv le moins peuplé)", CONFIG.Farm.solo, function(v)
    CONFIG.Farm.solo = v
end)

makeSlider(farmPage, "Délai après collecte (ms)", 200, 3000, math.floor(CONFIG.Farm.collectDelay * 1000), function(v)
    CONFIG.Farm.collectDelay = v / 1000
end)

makeSectionLabel(farmPage, "Fruits en sac")

local fruitRow = new("Frame", {
    Size = UDim2.new(1, 0, 0, 64),
    BackgroundColor3 = C.row,
    BorderSizePixel = 0,
}, farmPage)
corner(fruitRow, 6)

local fruitListLbl = new("TextLabel", {
    Size = UDim2.new(1, -16, 1, -8),
    Position = UDim2.fromOffset(10, 4),
    BackgroundTransparency = 1,
    Text = "aucun fruit en sac",
    TextColor3 = C.sub,
    Font = Enum.Font.Code,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, fruitRow)

makeButton(farmPage, "Store maintenant", function()
    local n = Store.all()
    if n > 0 then
        Farm.stats.stored = Farm.stats.stored + n
        setStatus("stocké " .. n .. " fruit(s)")
    else
        setStatus("rien à stocker")
    end
    Farm.refreshStats()
end, 30)

makeButton(farmPage, "Farm un seul passage", function()
    task.spawn(function()
        local wasActive = Farm.active
        if not wasActive then Farm.start() end
        task.wait(0.1)
        if not wasActive then
            task.wait(8)
            Farm.stop()
            refreshFarmBig()
            setStatus("passage terminé")
        end
    end)
end, 30)

Farm.label = new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = farmStatsText(),
    TextColor3 = C.sub,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = farmPage,
})

---------------------------------------------------------------
--  RADAR PAGE
---------------------------------------------------------------
makeSectionLabel(radarPage, "Détection")

makeToggle(radarPage, "ESP fruits", CONFIG.Radar.enabled, function(v) Radar.setEnabled(v) end)

makeSlider(radarPage, "Distance max (studs)", 200, 10000, CONFIG.Radar.maxDistance, function(v)
    CONFIG.Radar.maxDistance = v
end)

makeSectionLabel(radarPage, "Actions")

makeButton(radarPage, "TP fruit le plus proche  (T)", function()
    local inst, pos = Radar.nearest(Farm.filter)
    if inst and pos then
        Movement.tp(pos)
        setStatus("tp → " .. inst.Name)
    else
        setStatus("aucun fruit détecté")
    end
end)

makeButton(radarPage, "TP + ramasser", function()
    local inst, pos = Radar.nearest(Farm.filter)
    if inst and pos then
        Movement.tp(pos)
        task.delay(0.5, function() Radar.pickup(inst) end)
        setStatus("tp + pickup → " .. inst.Name)
    else
        setStatus("aucun fruit détecté")
    end
end)

makeButton(radarPage, "Rescan maintenant", function()
    task.spawn(function()
        Radar.clear()
        Radar.scanContainer(workspace)
        setStatus("rescan — " .. Radar.count() .. " fruit(s)")
    end)
end)

---------------------------------------------------------------
--  TP PAGE
---------------------------------------------------------------
makeSectionLabel(waypointPage, "Téléportation")

makeToggle(waypointPage, "TP par micro-pas", CONFIG.Waypoint.safeTp, function(v)
    CONFIG.Waypoint.safeTp = v
end)

makeSlider(waypointPage, "Taille du pas (studs)", 5, 150, CONFIG.Waypoint.stepStuds, function(v)
    CONFIG.Waypoint.stepStuds = v
end)

makeSlider(waypointPage, "Délai entre pas (ms)", 8, 200, math.floor(CONFIG.Waypoint.stepDelay * 1000), function(v)
    CONFIG.Waypoint.stepDelay = v / 1000
end)

makeSectionLabel(waypointPage, "Vitesse")

makeSlider(waypointPage, "WalkSpeed", 16, 300, CONFIG.Movement.walkSpeed, function(v)
    Movement.setWalk(v)
end)

makeSlider(waypointPage, "JumpPower", 50, 300, CONFIG.Movement.jumpPower, function(v)
    Movement.setJump(v)
end)

makeToggle(waypointPage, "Anti-void", CONFIG.Movement.antiVoid, function(v)
    CONFIG.Movement.antiVoid = v
end)

---------------------------------------------------------------
--  BYPASS PAGE
---------------------------------------------------------------
makeSectionLabel(bypassPage, "Protection client")

makeToggle(bypassPage, "Anti-kick (bloque LocalPlayer:Kick)", CONFIG.Protect.antiKick, function(v)
    CONFIG.Protect.antiKick = v
    if v then Protect.hookKick() end
end)

makeToggle(bypassPage, "Spoof WalkSpeed / JumpPower", CONFIG.Protect.spoofHumanoid, function(v)
    CONFIG.Protect.spoofHumanoid = v
    if v then Protect.hookIndex() end
end)

makeToggle(bypassPage, "Anti-AFK", CONFIG.Protect.antiAfk, function(v)
    CONFIG.Protect.antiAfk = v
end)

makeSectionLabel(bypassPage, "Diagnostic")

local function diagLine(text)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = C.sub,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bypassPage,
    })
end

diagLine("hookmetamethod      : " .. (type(hookmetamethod) == "function" and "OK" or "absent"))
diagLine("getnamecallmethod   : " .. (type(getnamecallmethod) == "function" and "OK" or "absent"))
diagLine("firetouchinterest   : " .. (type(firetouchinterest) == "function" and "OK" or "absent"))
diagLine("fireproximityprompt : " .. (type(fireproximityprompt) == "function" and "OK" or "absent"))
diagLine("CommF_              : " .. (Remotes.get() and "OK" or "absent"))

makeButton(bypassPage, "Réinstaller les hooks", function()
    Protect.kickHooked = false
    Protect.indexHooked = false
    local a = Protect.hookKick()
    local b = Protect.hookIndex()
    setStatus("hooks — kick:" .. tostring(a) .. "  index:" .. tostring(b))
end)

---------------------------------------------------------------
--  HOP PAGE
---------------------------------------------------------------
makeSectionLabel(hopPage, "Serveur")

makeToggle(hopPage, "Auto-hop si aucun fruit", CONFIG.Hop.auto, function(v)
    CONFIG.Hop.auto = v
    setStatus(v and "auto-hop activé" or "auto-hop off")
end)

makeSlider(hopPage, "Délai avant hop (s)", 5, 120, CONFIG.Hop.delay, function(v)
    CONFIG.Hop.delay = v
end)

makeSlider(hopPage, "Joueurs max par serveur", 1, 30, CONFIG.Hop.maxPlayers, function(v)
    CONFIG.Hop.maxPlayers = v
end)

makeButton(hopPage, "Hop maintenant", function() Hop.execute(false) end)

makeButton(hopPage, "Hop solo (le moins peuplé)", function() Hop.execute(true) end)

local linkBox = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = C.row,
    BorderSizePixel = 0,
    Text = CONFIG.Hop.privateLink,
    PlaceholderText = "lien serv privé (…?privateServerLinkCode=XXXX)",
    TextColor3 = C.text,
    PlaceholderColor3 = C.sub,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, hopPage)
corner(linkBox, 6)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, linkBox)

linkBox.FocusLost:Connect(function()
    CONFIG.Hop.privateLink = linkBox.Text
    setStatus(CONFIG.Hop.privateLink ~= "" and "lien privé enregistré" or "lien privé vidé")
end)

---------------------------------------------------------------
--  DRAG / MINIMIZE / MINI BOUTON
---------------------------------------------------------------
local dragging = false
local dragStart, startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UI.connections[#UI.connections + 1] = UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        main:TweenSize(UDim2.fromOffset(430, 38), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        contentArea.Visible = false
        tabBar.Visible = false
        statusBar.Visible = false
    else
        main:TweenSize(UDim2.fromOffset(430, 340), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        contentArea.Visible = true
        tabBar.Visible = true
        statusBar.Visible = true
    end
end)

-- bouton flottant quand le panneau est fermé
guiMini = new("TextButton", {
    Size = UDim2.fromOffset(54, 54),
    Position = UDim2.new(1, -74, 0.5, -27),
    BackgroundColor3 = C.panel,
    Text = "FARM",
    TextColor3 = C.accent,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    BorderSizePixel = 0,
    Visible = false,
    Parent = gui,
})
corner(guiMini, 12)
stroke(guiMini, C.accent, 0.5)

guiMini.MouseButton1Click:Connect(function()
    main.Visible = true
    guiMini.Visible = false
end)

local miniDrag = false
local miniStart, miniPos

guiMini.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        miniDrag = true
        miniStart = input.Position
        miniPos = guiMini.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                miniDrag = false
            end
        end)
    end
end)

UI.connections[#UI.connections + 1] = UserInputService.InputChanged:Connect(function(input)
    if not miniDrag then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - miniStart
        guiMini.Position = UDim2.new(
            miniPos.X.Scale, miniPos.X.Offset + delta.X,
            miniPos.Y.Scale, miniPos.Y.Offset + delta.Y
        )
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    guiMini.Visible = true
end)

headerFarmBtn.MouseButton1Click:Connect(function()
    toggleFarm()
    showTab("Farm")
end)

-- ══════════════════════════════════════════════════════════════
--  FPS / STATS
-- ══════════════════════════════════════════════════════════════
UI.connections[#UI.connections + 1] = RunService.RenderStepped:Connect(function()
    UI.frames = UI.frames + 1
    local now = os.clock()
    if now - UI.fpsClock >= 0.5 then
        UI.fps = math.floor(UI.frames / (now - UI.fpsClock) + 0.5)
        UI.frames = 0
        UI.fpsClock = now

        local ping = 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)

        UI.countLabel.Text = string.format(
            "%d fruit  •  %dms  •  %d fps", Radar.count(), ping, UI.fps
        )

        local tools = Store.tools()
        if #tools > 0 then
            local names = {}
            for i, t in ipairs(tools) do
                if i > 6 then names[#names + 1] = "…" break end
                names[#names + 1] = t.Name
            end
            fruitListLbl.Text = table.concat(names, "  ·  ")
            fruitListLbl.TextColor3 = C.gold
        else
            fruitListLbl.Text = "aucun fruit en sac"
            fruitListLbl.TextColor3 = C.sub
        end
    end
end)

---------------------------------------------------------------
--  KEYBINDS
---------------------------------------------------------------
UI.connections[#UI.connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == CONFIG.Radar.tpKey then
        local inst, pos = Radar.nearest(Farm.filter)
        if inst and pos then
            Movement.tp(pos)
            setStatus("tp → " .. inst.Name)
        else
            setStatus("aucun fruit détecté")
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════════════════════════════
_G.RFX_Unload = function()
    Farm.stop()
    CONFIG.Protect.antiKick = false
    CONFIG.Protect.spoofHumanoid = false
    CONFIG.Protect.antiAfk = false
    CONFIG.Radar.enabled = false

    for _, c in ipairs(Radar.connections) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(UI.connections) do pcall(function() c:Disconnect() end) end

    Radar.clear()
    pcall(function() gui:Destroy() end)
    _G.RFX_Unload = nil
end

setStatus("prêt — FARM dans le header, T = tp")
refreshFarmBig()
