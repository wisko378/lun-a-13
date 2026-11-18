--[[
╔══════════════════════════════════════════════════════════════════╗
║  RFX v3 — Radar • Farm • Stats • Bypass • Hop                    ║
║  Blox Fruits                                                     ║
║  Delta • Solara • Fluxus • Xeno (Luau)                           ║
╚══════════════════════════════════════════════════════════════════╝

  Remotes (Blox Fruits) :
    ReplicatedStorage.Remotes.CommF_
      :InvokeServer("StoreFruit", <clé>, <tool>)
      :InvokeServer("AddPoint", "Melee" | "Defense" | "Sword" | "Gun" | "Demon Fruit", points)

  Données joueur :
    LocalPlayer.Data.Points.Value                    -- points de stat disponibles
    LocalPlayer.Data.Stats.<Stat>.Level.Value        -- niveau de chaque stat

  Détection : enfants directs de workspace (fruits / coffres / baies / fleurs /
  PNJ), plus les personnages des joueurs pour l'ESP joueur.
  Tout passe par pcall : remote absent = module muet, pas d'erreur en cascade.
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
--  Le loader fait : loadstring(game:HttpGet(URL .. "?id=" .. ID))(ID)
--  L'ID reçu doit être dans WHITELIST ET être le compte qui exécute.
-- ══════════════════════════════════════════════════════════════
local WHITELIST = {
    [12020224798] = true,
}

local LINK_ID = tonumber((...))

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
    accent   = Color3.fromRGB(0, 220, 170),
    accentDim= Color3.fromRGB(0, 110, 88),
    bg       = Color3.fromRGB(13, 13, 17),
    panel    = Color3.fromRGB(20, 20, 26),
    row      = Color3.fromRGB(28, 28, 36),
    rowHi    = Color3.fromRGB(40, 40, 50),
    text     = Color3.fromRGB(232, 232, 240),
    sub      = Color3.fromRGB(138, 138, 152),
    danger   = Color3.fromRGB(220, 80, 96),
    gold     = Color3.fromRGB(255, 190, 70),
    chest1   = Color3.fromRGB(170, 170, 170),
    chest2   = Color3.fromRGB(255, 220, 80),
    chest3   = Color3.fromRGB(80, 230, 255),
    berry    = Color3.fromRGB(230, 90, 140),
    flower   = Color3.fromRGB(180, 140, 255),
    dealer   = Color3.fromRGB(120, 220, 120),
    player   = Color3.fromRGB(255, 130, 90),
}

local CONFIG = {
    Radar = {
        maxDistance  = 5000,
        scanInterval = 3,
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
        auto        = false,
        delay       = 30,
        minPlayers  = 0,
        maxPlayers  = 10,
        privateLink = "",
    },
    Farm = {
        mode         = "Fruits",   -- Fruits | Chests
        target       = "Any",
        autoStore    = true,
        hopOnEmpty   = true,
        solo         = false,
        pickupRetry  = 3,
        collectDelay = 0.8,
        maxLevel     = 2600,
    },
    Combat = {
        bossName      = "",
        bossMinHealth = 1500,
        attackRate    = 0.12,
        autoEquip     = true,
    },
    Webhook = {
        url          = "",
        notifyFruits = true,
        notifyStats  = false,
    },
    Stats = {
        active       = false,
        pointsPerTick= 1,
        enabled      = { Melee = true, Defense = true, Sword = false, Gun = false, ["Demon Fruit"] = false },
    },
}

local ESP_ON = {
    Fruit  = true,
    Chest  = true,
    Berry  = false,
    Flower = false,
    Dealer = false,
    Player = false,
}

local TARGET_CYCLE = {
    "Any", "Legendary+", "Mythical",
    "Dragon", "Leopard", "Kitsune", "Dough", "Venom", "Shadow", "Control",
}

local STAT_LIST = { "Melee", "Defense", "Sword", "Gun", "Demon Fruit" }

-- Chaîne de quêtes complète : { niveau min, niveau max, mob, clé NPC, niveau de quête }
-- Sources : tables publiques de farm (Sea 1 / Sea 2 / Sea 3). Au-delà de la
-- dernière entrée le farm garde le dernier palier au lieu d'inventer une clé.
local QUESTS = {
    -- Sea 1
    { 1,    9,    "Bandit",               "BanditQuest1",       1 },
    { 10,   14,   "Monkey",               "JungleQuest",        1 },
    { 15,   29,   "Gorilla",              "JungleQuest",        2 },
    { 30,   39,   "Pirates",              "BuggyQuest1",        1 },
    { 40,   59,   "Brute",                "BuggyQuest1",        2 },
    { 60,   74,   "Desert Bandit",        "DesertQuest",        1 },
    { 75,   89,   "Desert Officer",       "DesertQuest",        2 },
    { 90,   99,   "Snow Bandits",         "SnowQuest",          1 },
    { 100,  119,  "Snowman",              "SnowQuest",          2 },
    { 120,  149,  "Chief Petty Officer",  "MarineQuest2",       1 },
    { 150,  174,  "Sky Bandit",           "SkyQuest",           1 },
    { 175,  224,  "Dark Master",          "SkyQuest",           2 },
    { 225,  274,  "Toga Warrior",         "ColosseumQuest",     1 },
    { 275,  299,  "Gladiator",            "ColosseumQuest",     2 },
    { 300,  329,  "Military Soldier",     "MagmaQuest",         1 },
    { 330,  374,  "Military Spy",         "MagmaQuest",         2 },
    { 375,  399,  "Fishman Warrior",      "FishmanQuest",       1 },
    { 400,  449,  "Fishman Commando",     "FishmanQuest",       2 },
    { 450,  474,  "God's Guards",         "SkyExp1Quest",       1 },
    { 475,  524,  "Shandas",              "SkyExp1Quest",       2 },
    { 525,  549,  "Royal Squad",          "SkyExp2Quest",       1 },
    { 550,  624,  "Royal Soldier",        "SkyExp2Quest",       2 },
    { 625,  649,  "Galley Pirate",        "FountainQuest",      1 },
    { 650,  699,  "Galley Captain",       "FountainQuest",      2 },
    -- Sea 2
    { 700,  724,  "Raider",               "Area1Quest",         1 },
    { 725,  774,  "Mercenary",            "Area1Quest",         2 },
    { 775,  799,  "Swan Pirate",          "Area2Quest",         1 },
    { 800,  874,  "Factory Staff",        "Area2Quest",         2 },
    { 875,  899,  "Marine Lieutenant",    "MarineQuest3",       1 },
    { 900,  949,  "Marine Captain",       "MarineQuest3",       2 },
    { 950,  974,  "Zombie",               "ZombieQuest",        1 },
    { 975,  999,  "Vampire",              "ZombieQuest",        2 },
    { 1000, 1049, "Snow Trooper",         "SnowMountainQuest",  1 },
    { 1050, 1099, "Winter Warrior",       "SnowMountainQuest",  2 },
    { 1100, 1124, "Lab Subordinate",      "IceSideQuest",       1 },
    { 1125, 1174, "Horned Warrior",       "IceSideQuest",       2 },
    { 1175, 1199, "Magma Ninja",          "FireSideQuest",      1 },
    { 1200, 1249, "Lava Pirate",          "FireSideQuest",      2 },
    { 1250, 1274, "Ship Deckhand",        "ShipQuest1",         1 },
    { 1275, 1299, "Ship Engineer",        "ShipQuest1",         2 },
    { 1300, 1324, "Ship Steward",         "ShipQuest2",         1 },
    { 1325, 1349, "Ship Officer",         "ShipQuest2",         2 },
    { 1350, 1374, "Arctic Warrior",       "FrostQuest",         1 },
    { 1375, 1424, "Snow Lurker",          "FrostQuest",         2 },
    { 1425, 1449, "Sea Soldier",          "ForgottenQuest",     1 },
    { 1450, 1499, "Water Fighter",        "ForgottenQuest",     2 },
    -- Sea 3
    { 1500, 1524, "Pirate Millionaire",   "PiratePortQuest",    1 },
    { 1525, 1549, "Pistol Billionaire",   "PiratePortQuest",    2 },
    { 1550, 1574, "Stone",                "PiratePortQuest",    3 },
    { 1575, 1599, "Dragon Crew Warrior",  "AmazonQuest",        1 },
    { 1600, 1624, "Dragon Crew Archer",   "AmazonQuest",        2 },
    { 1625, 1649, "Female Islander",      "AmazonQuest2",       1 },
    { 1650, 1674, "Giant Islander",       "AmazonQuest2",       2 },
    { 1675, 1699, "Island Empress",       "AmazonQuest2",       3 },
    { 1700, 1724, "Marine Commodore",     "MarineTreeIsland",   1 },
    { 1725, 1749, "Marine Rear Admiral",  "MarineTreeIsland",   2 },
    { 1750, 1774, "Kilo Admiral",         "MarineTreeIsland",   3 },
    { 1775, 1799, "Fishman Raider",       "DeepForestIsland3",  1 },
    { 1800, 1824, "Fishman Captain",      "DeepForestIsland3",  2 },
    { 1825, 1849, "Forest Pirate",        "DeepForestIsland",   1 },
    { 1850, 1874, "Mythological Pirate",  "DeepForestIsland",   2 },
    { 1875, 1899, "Captain Elephant",     "DeepForestIsland",   3 },
    { 1900, 1924, "Jungle Pirate",        "DeepForestIsland2",  1 },
    { 1925, 1949, "Musketeer Pirate",     "DeepForestIsland2",  2 },
    { 1950, 1974, "Musketeer Pirate",     "DeepForestIsland2",  3 },
    { 1975, 1999, "Reborn Skeleton",      "HauntedQuest1",      1 },
    { 2000, 2024, "Living Zombie",        "HauntedQuest1",      2 },
    { 2025, 2049, "Demonic Soul",         "HauntedQuest2",      1 },
    { 2050, 2074, "Posessed Mummy",       "HauntedQuest2",      2 },
    { 2075, 2099, "Peanut Scout",         "NutsIslandQuest",    1 },
    { 2100, 2124, "Peanut President",     "NutsIslandQuest",    2 },
    { 2125, 2149, "Ice Cream Chef",       "IceCreamIslandQuest",1 },
    { 2150, 2174, "Ice Cream Commander",  "IceCreamIslandQuest",2 },
    { 2175, 2199, "Cake Queen",           "IceCreamIslandQuest",3 },
    { 2200, 2224, "Cookie Crafter",       "CakeQuest1",         1 },
    { 2225, 2249, "Cake Guard",           "CakeQuest1",         2 },
    { 2250, 2274, "Baking Staff",         "CakeQuest2",         1 },
    { 2275, 2299, "Head Baker",           "CakeQuest2",         2 },
    { 2300, 2324, "Cocoa Warrior",        "ChocQuest1",         1 },
    { 2325, 2349, "Chocolate Bar Battler","ChocQuest1",         2 },
    { 2350, 2374, "Sweet Thief",          "ChocQuest2",         1 },
    { 2375, 2399, "Candy Rebel",          "ChocQuest2",         2 },
    { 2400, 2424, "Candy Pirate",         "CandyQuest1",        1 },
    { 2425, 2449, "Snow Demon",           "CandyQuest1",        2 },
    { 2450, 2474, "Isle Outlaw",          "TikiQuest1",         1 },
    { 2475, 2499, "Island Boy",           "TikiQuest1",         2 },
    { 2500, 2524, "Sun-kissed Warrior",   "TikiQuest2",         1 },
    { 2525, 9999, "Isle Champion",        "TikiQuest2",         2 },
}

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
    if not fn and type(request) == "function" then
        fn = function(u) local r = request({ Url = u, Method = "GET" }); return r and r.Body end
    end
    if not fn and type(http_request) == "function" then
        fn = function(u) local r = http_request({ Url = u, Method = "GET" }); return r and r.Body end
    end
    if not fn and syn and type(syn.request) == "function" then
        fn = function(u) local r = syn.request({ Url = u, Method = "GET" }); return r and r.Body end
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
--  FRUITS
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

local function fruitFilter(entry)
    local t = CONFIG.Farm.target
    if t == "Any" then return true end
    if t == "Legendary+" then return (TIER_ORDER[entry.tier] or 0) >= 4 end
    if t == "Mythical" then return entry.tier == "Mythical" end
    return entry.name == t
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
--  CLASSIFICATION — une instance = une catégorie
-- ══════════════════════════════════════════════════════════════
local function isPlayerCharacter(inst)
    if not inst:IsA("Model") then return false end
    local hum = inst:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return Players:GetPlayerFromCharacter(inst) ~= nil
end

-- Retourne : categorie, label, couleur, priorité
local function classify(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Tool")) then
        return nil
    end
    if isPlayerCharacter(inst) then return nil end

    local name = inst.Name
    local lower = name:lower()

    local fruit = matchFruit(name)
    if fruit then
        return "Fruit", fruit.name, (TIER_COLORS[fruit.tier] or C.accent), {
            tier = fruit.tier, path = fruit.name, kind = "fruit",
        }
    end

    if lower:match("^chest") then
        local color = C.chest1
        local quality = 1
        if lower:find("chest3") then color, quality = C.chest3, 3
        elseif lower:find("chest2") then color, quality = C.chest2, 2 end
        return "Chest", name, color, { path = name, kind = "chest", quality = quality }
    end

    if lower:find("berry", 1, true) then
        return "Berry", name, C.berry, { path = name, kind = "berry" }
    end

    if lower:find("flower", 1, true) then
        return "Flower", name, C.flower, { path = name, kind = "flower" }
    end

    if lower:find("dealer", 1, true) then
        return "Dealer", name, C.dealer, { path = name, kind = "dealer" }
    end

    return nil
end

-- ══════════════════════════════════════════════════════════════
--  ESP
-- ══════════════════════════════════════════════════════════════
local ESP = {
    items = {},        -- [inst] = { label, highlight, billboard, text, category, meta, pos }
    connections = {},
    cooldown = {},
}

local function espRemove(inst)
    local data = ESP.items[inst]
    if not data then return end
    if data.highlight then pcall(function() data.highlight:Destroy() end) end
    if data.billboard then pcall(function() data.billboard:Destroy() end) end
    ESP.items[inst] = nil
end

local function espAdd(inst, category, label, color, meta)
    if ESP.items[inst] then return end
    local root = getRoot(inst)
    if not root then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "RFX_HL"
    highlight.FillColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0.15
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = ESP_ON[category] == true
    highlight.Parent = inst:IsA("Model") and inst or root

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RFX_BB"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(200, 34)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Adornee = root
    billboard.Enabled = ESP_ON[category] == true

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Text = label
    text.TextColor3 = color
    text.TextStrokeTransparency = 0.35
    text.TextScaled = true
    text.Font = Enum.Font.GothamBold
    text.Parent = billboard

    billboard.Parent = root

    ESP.items[inst] = {
        category = category,
        label = label,
        meta = meta,
        highlight = highlight,
        billboard = billboard,
        text = text,
        pos = getPosition(inst),
        lastText = "",
    }
end

local function espSetCategory(category, enabled)
    ESP_ON[category] = enabled
    for _, data in pairs(ESP.items) do
        if data.category == category then
            if data.highlight then data.highlight.Enabled = enabled end
            if data.billboard then data.billboard.Enabled = enabled end
        end
    end
end

local function espClear()
    for inst in pairs(ESP.items) do espRemove(inst) end
end

local function classifyAndAdd(inst)
    if ESP.items[inst] then return end
    local category, label, color, meta = classify(inst)
    if category then espAdd(inst, category, label, color, meta) end
end

local function scanWorld()
    for _, inst in ipairs(workspace:GetChildren()) do
        classifyAndAdd(inst)
    end
end

local function playerESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char and char.Parent then
                local existing = ESP.items[char]
                if not existing then
                    espAdd(char, "Player", plr.Name, C.player, { kind = "player", userId = plr.UserId })
                end
            end
        end
    end
    for inst, data in pairs(ESP.items) do
        if data.category == "Player" then
            local plr = Players:GetPlayerFromCharacter(inst)
            if not plr then espRemove(inst) end
        end
    end
end

ESP.connections[#ESP.connections + 1] = workspace.ChildAdded:Connect(function(inst)
    task.defer(function()
        if inst.Parent == workspace then classifyAndAdd(inst) end
    end)
end)

ESP.connections[#ESP.connections + 1] = workspace.ChildRemoved:Connect(function(inst)
    if ESP.items[inst] then espRemove(inst) end
end)

ESP.connections[#ESP.connections + 1] = Players.PlayerAdded:Connect(function()
    task.wait(1)
    playerESP()
end)

ESP.connections[#ESP.connections + 1] = Players.PlayerRemoving:Connect(function(plr)
    if plr.Character and ESP.items[plr.Character] then
        espRemove(plr.Character)
    end
end)

task.spawn(function()
    while true do
        task.wait(CONFIG.Radar.scanInterval)
        pcall(scanWorld)
        pcall(playerESP)
    end
end)

task.spawn(function()
    task.wait(0.5)
    pcall(scanWorld)
    pcall(playerESP)
end)

local espAcc = 0
ESP.connections[#ESP.connections + 1] = RunService.Heartbeat:Connect(function(dt)
    espAcc = espAcc + dt
    if espAcc < 0.15 then return end
    espAcc = 0

    local hrp = getHRP()
    if not hrp then return end

    for inst, data in pairs(ESP.items) do
        if not inst.Parent then
            espRemove(inst)
        else
            local pos = getPosition(inst)
            data.pos = pos
            if pos then
                local dist = (pos - hrp.Position).Magnitude
                local txt = string.format("%s  •  %dm", data.label, math.floor(dist + 0.5))
                if txt ~= data.lastText then
                    if data.text then data.text.Text = txt end
                    data.lastText = txt
                end
                local shown = ESP_ON[data.category] == true and dist <= CONFIG.Radar.maxDistance
                if data.billboard then data.billboard.Visible = shown end
                if data.highlight then data.highlight.Enabled = shown end
            end
        end
    end
end)

-----------------------------------------------------------------
--  recherche / action
-----------------------------------------------------------------
local function nearest(category, filterFn)
    local hrp = getHRP()
    if not hrp then return nil, nil end

    local best, bestDist, bestPos
    for inst, data in pairs(ESP.items) do
        local skip = false
        local untilTime = ESP.cooldown[inst]
        if untilTime and os.clock() < untilTime then skip = true end

        if not skip and inst.Parent and data.pos and data.category == category then
            local ok = true
            if filterFn then ok = filterFn(data) end
            if ok then
                local d = (data.pos - hrp.Position).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist, bestPos = inst, d, data.pos
                end
            end
        end
    end
    return best, bestPos
end

local function collect(inst)
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

-- ══════════════════════════════════════════════════════════════
--  STORE
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
        if not tool.Parent then return true end
    end
    return false
end

function Store.all()
    local done = 0
    for _, tool in ipairs(Store.tools()) do
        if Store.one(tool) then
            done = done + 1
            Store.stored = Store.stored + 1
        end
    end
    return done
end

-- ══════════════════════════════════════════════════════════════
--  STATS — allocation automatique des points
-- ══════════════════════════════════════════════════════════════
local Stats = { lastError = "", spent = 0 }

local function playerData()
    local ok, data = pcall(function() return LocalPlayer.Data end)
    if ok then return data end
    return nil
end

function Stats.points()
    local data = playerData()
    if not data then return 0 end
    local ok, points = pcall(function()
        local p = data:FindFirstChild("Points")
        return p and p.Value or 0
    end)
    if ok and type(points) == "number" then return points end
    return 0
end

function Stats.level(stat)
    local data = playerData()
    if not data then return 0 end
    local ok, level = pcall(function()
        local statsFolder = data:FindFirstChild("Stats")
        if not statsFolder then return 0 end
        local statFolder = statsFolder:FindFirstChild(stat)
        if not statFolder then return 0 end
        local lvl = statFolder:FindFirstChild("Level")
        return lvl and lvl.Value or 0
    end)
    if ok and type(level) == "number" then return level end
    return 0
end

function Stats.spend(stat, amount)
    local remote = Remotes.get()
    if not remote then return false end
    local points = Stats.points()
    if points < 1 then return false end

    local spend = math.clamp(amount, 1, points)
    local ok = pcall(function()
        remote:InvokeServer("AddPoint", stat, spend)
    end)

    if ok then
        Stats.spent = Stats.spent + spend
        return true
    end
    Stats.lastError = "AddPoint refusé"
    return false
end

function Stats.priorityStat()
    for _, stat in ipairs(STAT_LIST) do
        if CONFIG.Stats.enabled[stat] then return stat end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.4)
        if CONFIG.Stats.active then
            local stat = Stats.priorityStat()
            if stat and Stats.points() >= 1 then
                Stats.spend(stat, CONFIG.Stats.pointsPerTick)
            end
        end
    end
end)

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
--  MERS — chaque mer est une place Roblox différente
-- ══════════════════════════════════════════════════════════════
local SEAS = {
    { n = 1, place = 2753915549, name = "First Sea" },
    { n = 2, place = 4442272183, name = "Second Sea" },
    { n = 3, place = 7449423635, name = "Third Sea" },
}

local seaCooldown = 0

local function currentSea()
    for _, s in ipairs(SEAS) do
        if game.PlaceId == s.place then return s end
    end
    return nil
end

local function goSea(n)
    local target
    for _, s in ipairs(SEAS) do
        if s.n == n then target = s end
    end
    if not target then return end

    if os.clock() < seaCooldown then
        setStatus("mer : cooldown 8s")
        return
    end

    if game.PlaceId == target.place then
        setStatus("déjà en " .. target.name)
        return
    end

    seaCooldown = os.clock() + 8
    setStatus("→ " .. target.name)

    local ok = pcall(function()
        TeleportService:Teleport(target.place, LocalPlayer)
    end)
    if not ok then
        setStatus(target.name .. " refusée")
    end
end

-- ══════════════════════════════════════════════════════════════
--  FARM
-- ══════════════════════════════════════════════════════════════
local Webhook = {}   -- rempli par le module webhook, plus bas

local Farm = {
    active = false,
    token  = 0,
    stats  = { seen = 0, collected = 0, stored = 0, hops = 0 },
    label  = nil,
}

local function farmStatsText()
    return string.format(
        "vu %d  •  ramassé %d  •  stocké %d  •  hop %d",
        Farm.stats.seen, Farm.stats.collected, Farm.stats.stored, Farm.stats.hops
    )
end

function Farm.refreshStats()
    if Farm.label then Farm.label.Text = farmStatsText() end
end

local function waitNear(inst, maxDist, tries)
    for _ = 1, tries or 25 do
        local hrp = getHRP()
        local p = getPosition(inst)
        if not hrp or not p or not inst.Parent then return false end
        if (hrp.Position - p).Magnitude < (maxDist or 12) then return true end
        task.wait(0.06)
    end
    return false
end

local function farmOne(inst, pos)
    Movement.tp(pos)
    task.wait(0.25)
    waitNear(inst, 14, 20)

    collect(inst)

    for _ = 1, CONFIG.Farm.pickupRetry do
        task.wait(0.3)
        if not inst.Parent then return true end
        collect(inst)
    end
    return not inst.Parent
end

function Farm.start()
    if Farm.active then return true end
    Farm.active = true
    Farm.token = Farm.token + 1
    local myToken = Farm.token

    task.spawn(function()
        task.wait(1)

        while Farm.active and Farm.token == myToken do
            if not getHRP() then
                task.wait(0.5)
            elseif CONFIG.Farm.mode == "Fruits" then
                local inst, pos = nearest("Fruit", fruitFilter)

                if inst and pos then
                    Farm.stats.seen = Farm.stats.seen + 1
                    setStatus("farm → " .. inst.Name)
                    Farm.refreshStats()

                    if farmOne(inst, pos) then
                        Farm.stats.collected = Farm.stats.collected + 1
                        setStatus("ramassé " .. inst.Name)
                        if CONFIG.Webhook.notifyFruits then
                            pcall(function()
                                Webhook.send(
                                    "Fruit ramassé",
                                    inst.Name .. " • " .. LocalPlayer.Name,
                                    15844367
                                )
                            end)
                        end
                    else
                        ESP.cooldown[inst] = os.clock() + 12
                        setStatus("échec pickup — cooldown")
                    end

                    ESP.cooldown[inst] = ESP.cooldown[inst] or (os.clock() + 3)
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
                elseif CONFIG.Farm.hopOnEmpty then
                    Farm.stats.hops = Farm.stats.hops + 1
                    setStatus("aucun fruit — hop")
                    Farm.refreshStats()
                    Hop.execute(CONFIG.Farm.solo)
                    task.wait(6)
                else
                    setStatus("aucun fruit — attente")
                    task.wait(2)
                end
            else
                -- mode coffres
                local inst, pos = nearest("Chest")

                if inst and pos then
                    Farm.stats.seen = Farm.stats.seen + 1
                    setStatus("coffre → " .. inst.Name)

                    if farmOne(inst, pos) then
                        Farm.stats.collected = Farm.stats.collected + 1
                        setStatus("coffre ouvert")
                    else
                        ESP.cooldown[inst] = os.clock() + 15
                    end
                    Farm.refreshStats()
                    task.wait(0.4)
                else
                    setStatus("aucun coffre — attente")
                    task.wait(2)
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

-- auto-hop passif hors farm
task.spawn(function()
    while true do
        task.wait(1)
        if not Farm.active then
            local any = false
            for _, data in pairs(ESP.items) do
                if data.category == "Fruit" then any = true break end
            end
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
--  COMBAT — cibles, équipement, coups
-- ══════════════════════════════════════════════════════════════
local Combat = { fastAttack = false }

local function enemiesFolder()
    return workspace:FindFirstChild("Enemies")
end

function Combat.enemies(filter)
    local list = {}
    local folder = enemiesFolder()
    if not folder then return list end

    for _, e in ipairs(folder:GetChildren()) do
        local hum = e:FindFirstChildOfClass("Humanoid")
        local root = e:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then
            if not filter or filter(e, hum) then
                list[#list + 1] = e
            end
        end
    end
    return list
end

function Combat.nearest(name, minHealth)
    local hrp = getHRP()
    if not hrp then return nil end

    local needle = (name and #name > 0) and name:lower() or nil

    local best, bestDist
    for _, e in ipairs(Combat.enemies(function(inst, hum)
        if needle and not inst.Name:lower():find(needle, 1, true) then
            return false
        end
        if minHealth and hum.MaxHealth < minHealth then return false end
        return true
    end)) do
        local root = e:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (root.Position - hrp.Position).Magnitude
            if not bestDist or d < bestDist then
                best, bestDist = e, d
            end
        end
    end
    return best
end

local function normalizeEnemy(name)
    local n = name:lower()
    n = n:gsub("%s*%[lv%.%s*%d+%s*%]%s*$", "")
    n = n:gsub("^%s+", ""):gsub("%s+$", "")
    return n
end

function Combat.nearestExact(target)
    if not target then return Combat.nearest() end

    local want = normalizeEnemy(target)
    local hrp = getHRP()
    if not hrp then return nil end

    local best, bestDist
    for _, e in ipairs(Combat.enemies()) do
        local name = normalizeEnemy(e.Name)
        if name == want or name == want .. "s" or name .. "s" == want then
            local root = e:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - hrp.Position).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist = e, d
                end
            end
        end
    end
    return best
end

function Combat.equip()
    if not CONFIG.Combat.autoEquip then return end

    local char = getChar()
    if not char then return end
    if char:FindFirstChildOfClass("Tool") then return end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not backpack or not hum then return end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() hum:EquipTool(tool) end)
            return
        end
    end
end

function Combat.hit(target)
    local char = getChar()
    if not char then return end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end

    pcall(function()
        local vim = game:GetService("VirtualUser")
        vim:CaptureController()
        vim:ClickButton1(Vector2.new(0, 0))
    end)

    local remote = Remotes.get()
    if remote and target then
        pcall(function() remote:InvokeServer("Attack", target) end)
    end
end

task.spawn(function()
    while true do
        task.wait(math.max(0.03, CONFIG.Combat.attackRate))
        if Combat.fastAttack then
            Combat.equip()
            Combat.hit()
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  AUTO FARM LEVEL — quête + mobs
-- ══════════════════════════════════════════════════════════════
local FarmLevel = { active = false, token = 0 }

local function playerLevel()
    local data = playerData()
    if not data then return 0 end
    local ok, lvl = pcall(function()
        local l = data:FindFirstChild("Level")
        return l and l.Value or 0
    end)
    if ok and type(lvl) == "number" then return lvl end
    return 0
end

local function hasQuest()
    local ok, visible = pcall(function()
        local main = LocalPlayer.PlayerGui:FindFirstChild("Main")
        local quest = main and main:FindFirstChild("Quest")
        return quest and quest.Visible or false
    end)
    return ok and visible == true
end

function FarmLevel.entryFor(level)
    local found
    for _, q in ipairs(QUESTS) do
        if level >= q[1] then
            found = { from = q[1], to = q[2], mob = q[3], quest = q[4], qlvl = q[5] }
        end
        if level >= q[1] and level <= q[2] then
            break
        end
    end
    return found
end

function FarmLevel.start()
    if FarmLevel.active then return true end
    FarmLevel.active = true
    FarmLevel.token = FarmLevel.token + 1
    local myToken = FarmLevel.token

    task.spawn(function()
        task.wait(1)

        while FarmLevel.active and FarmLevel.token == myToken do
            local level = playerLevel()
            local q = FarmLevel.entryFor(level)

            if level >= CONFIG.Farm.maxLevel then
                setStatus("niveau max atteint (" .. level .. ")")
                FarmLevel.active = false
                task.wait(1)
            elseif not q then
                setStatus("farm level : palier inconnu (lv " .. level .. ")")
                task.wait(2)
            else
                if not hasQuest() then
                    setStatus("farm level " .. level .. " : quête " .. q.quest)
                    Remotes.invoke("StartQuest", q.quest, q.qlvl)
                    task.wait(0.8)
                end

                local enemy = Combat.nearestExact(q.mob)
                if enemy then
                    local root = enemy:FindFirstChild("HumanoidRootPart")
                    if root then
                        Movement.tp(root.Position)
                        task.wait(0.12)
                        Combat.equip()
                        Combat.hit(enemy)
                    end
                else
                    setStatus("farm level : aucun " .. q.mob .. " — attente")
                    task.wait(1.5)
                end
            end

            task.wait(0.1)
        end
    end)

    return true
end

-- ══════════════════════════════════════════════════════════════
--  AUTO FARM BOSS
-- ══════════════════════════════════════════════════════════════
local FarmBoss = { active = false, token = 0 }

function FarmBoss.start()
    if FarmBoss.active then return true end
    FarmBoss.active = true
    FarmBoss.token = FarmBoss.token + 1
    local myToken = FarmBoss.token

    task.spawn(function()
        task.wait(1)

        while FarmBoss.active and FarmBoss.token == myToken do
            local boss = Combat.nearest(CONFIG.Combat.bossName, CONFIG.Combat.bossMinHealth)

            if boss then
                local root = boss:FindFirstChild("HumanoidRootPart")
                local hum = boss:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    setStatus(string.format("boss %s — %d hp", boss.Name, math.floor(hum.Health)))
                    Movement.tp(root.Position)
                    task.wait(0.12)
                    Combat.equip()
                    Combat.hit(boss)
                end
            else
                setStatus("boss introuvable — attente")
                task.wait(2)
            end

            task.wait(0.1)
        end
    end)

    return true
end

-- ══════════════════════════════════════════════════════════════
--  WEBHOOK — notifications Discord
-- ══════════════════════════════════════════════════════════════
Webhook = Webhook or {}

local function httpPost(url, body)
    local fn
    if type(request) == "function" then
        fn = function()
            return request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end
    elseif type(http_request) == "function" then
        fn = function()
            return http_request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end
    elseif syn and type(syn.request) == "function" then
        fn = function()
            return syn.request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end
    elseif type(game.HttpPost) == "function" then
        fn = function() return game:HttpPost(url, body) end
    end

    if not fn then return false end
    local ok = pcall(fn)
    return ok
end

function Webhook.send(title, description, color)
    if CONFIG.Webhook.url == "" then return false end

    local payload = {
        username = "RFX",
        embeds = { {
            title = title,
            description = description,
            color = color or 3771456,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        } },
    }

    local ok, body = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then return false end

    return httpPost(CONFIG.Webhook.url, body)
end

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
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = C.row,
        BorderSizePixel = 0,
    }, parent)
    corner(row, 6)
    local label = makeLabel(row, text)

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
        button = btn,
        label = label,
        row = row,
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

local function makeInfo(parent, text, height)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, height or 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = C.sub,
        Font = Enum.Font.Code,
        TextSize = 11,
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
    Size = UDim2.fromOffset(448, 356),
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
    Size = UDim2.new(0, 140, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1,
    Text = "RFX v3",
    TextColor3 = C.accent,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local headerFarmBtn = new("TextButton", {
    Size = UDim2.fromOffset(70, 24),
    Position = UDim2.new(1, -196, 0.5, -12),
    BackgroundColor3 = C.accentDim,
    Text = "FARM",
    TextColor3 = C.text,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    BorderSizePixel = 0,
}, header)
corner(headerFarmBtn, 6)

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
    Size = UDim2.new(0.55, -10, 1, 0),
    Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1,
    Text = "prêt",
    TextColor3 = C.sub,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, statusBar)

local countText = new("TextLabel", {
    Size = UDim2.new(0.45, -10, 1, 0),
    Position = UDim2.new(0.55, 0, 0, 0),
    BackgroundTransparency = 1,
    Text = "0 cible  •  0ms  •  60 fps",
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
        Size = UDim2.fromOffset(50, 30),
        BackgroundColor3 = C.panel,
        Text = name,
        TextColor3 = C.sub,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
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

local farmPage  = createTab("Farm", 1)
local espPage   = createTab("ESP", 2)
local tpPage    = createTab("TP", 3)
local statsPage = createTab("Stats", 4)
local protPage  = createTab("Protect", 5)
local hopPage   = createTab("Hop", 6)
local combatPage= createTab("Combat", 7)
local webPage   = createTab("Web", 8)

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
    Size = UDim2.new(1, 0, 0, 44),
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
        farmBig.Text = "FARM " .. CONFIG.Farm.mode:upper() .. "  •  ON"
        farmBig.BackgroundColor3 = C.accent
        headerFarmBtn.BackgroundColor3 = C.accent
        headerFarmBtn.TextColor3 = C.bg
        if guiMini then guiMini.BackgroundColor3 = C.accent end
    else
        farmBig.Text = "FARM " .. CONFIG.Farm.mode:upper() .. "  •  OFF"
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

local modeBtn
modeBtn = makeButton(farmPage, "Mode : Fruits", function()
    CONFIG.Farm.mode = (CONFIG.Farm.mode == "Fruits") and "Chests" or "Fruits"
    modeBtn.Text = "Mode : " .. CONFIG.Farm.mode
    refreshFarmBig()
    setStatus("mode → " .. CONFIG.Farm.mode)
end, 30)

local targetBtn
targetBtn = makeButton(farmPage, "Cible : " .. CONFIG.Farm.target, function()
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

makeToggle(farmPage, "Server hop si vide", CONFIG.Farm.hopOnEmpty, function(v)
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
    Size = UDim2.new(1, 0, 0, 60),
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
--  ESP PAGE
---------------------------------------------------------------
makeSectionLabel(espPage, "Catégories")

makeToggle(espPage, "Fruits", ESP_ON.Fruit, function(v) espSetCategory("Fruit", v) end)
makeToggle(espPage, "Coffres", ESP_ON.Chest, function(v) espSetCategory("Chest", v) end)
makeToggle(espPage, "Baies (Berry)", ESP_ON.Berry, function(v) espSetCategory("Berry", v) end)
makeToggle(espPage, "Fleurs", ESP_ON.Flower, function(v) espSetCategory("Flower", v) end)
makeToggle(espPage, "Dealers / PNJ", ESP_ON.Dealer, function(v) espSetCategory("Dealer", v) end)
makeToggle(espPage, "Joueurs", ESP_ON.Player, function(v) espSetCategory("Player", v) end)

makeSectionLabel(espPage, "Réglages")

makeSlider(espPage, "Distance max (studs)", 200, 10000, CONFIG.Radar.maxDistance, function(v)
    CONFIG.Radar.maxDistance = v
end)

makeButton(espPage, "Rescan du monde", function()
    task.spawn(function()
        espClear()
        scanWorld()
        playerESP()
        local n = 0
        for _ in pairs(ESP.items) do n = n + 1 end
        setStatus("rescan — " .. n .. " cible(s)")
    end)
end)

---------------------------------------------------------------
--  TP PAGE
---------------------------------------------------------------
makeSectionLabel(tpPage, "Téléportation")

makeToggle(tpPage, "TP par micro-pas", CONFIG.Waypoint.safeTp, function(v)
    CONFIG.Waypoint.safeTp = v
end)

makeSlider(tpPage, "Taille du pas (studs)", 5, 150, CONFIG.Waypoint.stepStuds, function(v)
    CONFIG.Waypoint.stepStuds = v
end)

makeSlider(tpPage, "Délai entre pas (ms)", 8, 200, math.floor(CONFIG.Waypoint.stepDelay * 1000), function(v)
    CONFIG.Waypoint.stepDelay = v / 1000
end)

makeSectionLabel(tpPage, "Mers")

local here = currentSea()
makeInfo(tpPage, "mer actuelle : " .. (here and here.name or ("place " .. game.PlaceId)))

makeButton(tpPage, "Aller en Sea 1  (First Sea)", function() goSea(1) end)
makeButton(tpPage, "Aller en Sea 2  (Second Sea)", function() goSea(2) end)
makeButton(tpPage, "Aller en Sea 3  (Third Sea)", function() goSea(3) end)

makeSectionLabel(tpPage, "Raccourcis")

makeButton(tpPage, "TP fruit le plus proche  (T)", function()
    local inst, pos = nearest("Fruit", fruitFilter)
    if inst and pos then
        Movement.tp(pos)
        setStatus("tp → " .. inst.Name)
    else
        setStatus("aucun fruit")
    end
end)

makeButton(tpPage, "TP coffre le plus proche", function()
    local inst, pos = nearest("Chest")
    if inst and pos then
        Movement.tp(pos)
        setStatus("tp → " .. inst.Name)
    else
        setStatus("aucun coffre")
    end
end)

makeButton(tpPage, "TP dealer", function()
    local inst, pos = nearest("Dealer")
    if inst and pos then
        Movement.tp(pos)
        setStatus("tp → " .. inst.Name)
    else
        setStatus("aucun dealer")
    end
end)

makeSectionLabel(tpPage, "Vitesse")

makeSlider(tpPage, "WalkSpeed", 16, 300, CONFIG.Movement.walkSpeed, function(v)
    Movement.setWalk(v)
end)

makeSlider(tpPage, "JumpPower", 50, 300, CONFIG.Movement.jumpPower, function(v)
    Movement.setJump(v)
end)

makeToggle(tpPage, "Anti-void", CONFIG.Movement.antiVoid, function(v)
    CONFIG.Movement.antiVoid = v
end)

---------------------------------------------------------------
--  STATS PAGE
---------------------------------------------------------------
local pointsInfo = makeInfo(statsPage, "points dispo : —", 18)
local spentInfo = makeInfo(statsPage, "dépensés cette session : 0", 18)

makeSectionLabel(statsPage, "Priorité")

local statToggles = {}
for _, stat in ipairs(STAT_LIST) do
    statToggles[stat] = makeToggle(statsPage, stat .. "  (" .. Stats.level(stat) .. ")", CONFIG.Stats.enabled[stat], function(v)
        CONFIG.Stats.enabled[stat] = v
    end)
end

makeSlider(statsPage, "Points par tick", 1, 100, CONFIG.Stats.pointsPerTick, function(v)
    CONFIG.Stats.pointsPerTick = v
end)

makeToggle(statsPage, "Auto stats", CONFIG.Stats.active, function(v)
    CONFIG.Stats.active = v
    setStatus(v and "auto stats ON" or "auto stats OFF")
end)

makeButton(statsPage, "Dépenser tout maintenant", function()
    local stat = Stats.priorityStat()
    if not stat then
        setStatus("aucune stat cochée")
        return
    end
    local available = Stats.points()
    if available < 1 then
        setStatus("aucun point disponible")
        return
    end
    if Stats.spend(stat, available) then
        setStatus("+" .. available .. " " .. stat)
    else
        setStatus("AddPoint refusé")
    end
end)

---------------------------------------------------------------
--  PROTECT PAGE
---------------------------------------------------------------
makeSectionLabel(protPage, "Protection client")

makeToggle(protPage, "Anti-kick (LocalPlayer:Kick)", CONFIG.Protect.antiKick, function(v)
    CONFIG.Protect.antiKick = v
    if v then Protect.hookKick() end
end)

makeToggle(protPage, "Spoof WalkSpeed / JumpPower", CONFIG.Protect.spoofHumanoid, function(v)
    CONFIG.Protect.spoofHumanoid = v
    if v then Protect.hookIndex() end
end)

makeToggle(protPage, "Anti-AFK", CONFIG.Protect.antiAfk, function(v)
    CONFIG.Protect.antiAfk = v
end)

makeSectionLabel(protPage, "Diagnostic")

makeInfo(protPage, "hookmetamethod      : " .. (type(hookmetamethod) == "function" and "OK" or "absent"))
makeInfo(protPage, "getnamecallmethod   : " .. (type(getnamecallmethod) == "function" and "OK" or "absent"))
makeInfo(protPage, "firetouchinterest   : " .. (type(firetouchinterest) == "function" and "OK" or "absent"))
makeInfo(protPage, "fireproximityprompt : " .. (type(fireproximityprompt) == "function" and "OK" or "absent"))
makeInfo(protPage, "CommF_              : " .. (Remotes.get() and "OK" or "absent"))

makeButton(protPage, "Réinstaller les hooks", function()
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
--  COMBAT PAGE
---------------------------------------------------------------
makeSectionLabel(combatPage, "Farm automatique")

makeToggle(combatPage, "Auto farm level (quête + mobs)", false, function(v)
    if v then
        FarmLevel.start()
        setStatus("farm level ON")
    else
        FarmLevel.active = false
        setStatus("farm level OFF")
    end
end)

makeToggle(combatPage, "Auto farm boss", false, function(v)
    if v then
        FarmBoss.start()
        setStatus("farm boss ON")
    else
        FarmBoss.active = false
        setStatus("farm boss OFF")
    end
end)

local bossBox = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = C.row,
    BorderSizePixel = 0,
    Text = CONFIG.Combat.bossName,
    PlaceholderText = "nom du boss (vide = le plus costaud)",
    TextColor3 = C.text,
    PlaceholderColor3 = C.sub,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, combatPage)
corner(bossBox, 6)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, bossBox)

bossBox.FocusLost:Connect(function()
    CONFIG.Combat.bossName = bossBox.Text
    setStatus(#bossBox.Text > 0 and ("boss → " .. bossBox.Text) or "boss → auto")
end)

makeSlider(combatPage, "Boss — HP minimum", 200, 30000, CONFIG.Combat.bossMinHealth, function(v)
    CONFIG.Combat.bossMinHealth = v
end)

makeSlider(combatPage, "Farm level — niveau max", 700, 3000, CONFIG.Farm.maxLevel, function(v)
    CONFIG.Farm.maxLevel = v
end)

makeSectionLabel(combatPage, "Combat")

makeToggle(combatPage, "Attaque rapide (no CD)", false, function(v)
    Combat.fastAttack = v
end)

makeSlider(combatPage, "Intervalle d'attaque (ms)", 40, 500, math.floor(CONFIG.Combat.attackRate * 1000), function(v)
    CONFIG.Combat.attackRate = v / 1000
end)

makeToggle(combatPage, "Auto équiper une arme", CONFIG.Combat.autoEquip, function(v)
    CONFIG.Combat.autoEquip = v
end)

---------------------------------------------------------------
--  WEBHOOK PAGE
---------------------------------------------------------------
makeSectionLabel(webPage, "Discord webhook")

local hookBox = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = C.row,
    BorderSizePixel = 0,
    Text = CONFIG.Webhook.url,
    PlaceholderText = "https://discord.com/api/webhooks/…",
    TextColor3 = C.text,
    PlaceholderColor3 = C.sub,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, webPage)
corner(hookBox, 6)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, hookBox)

hookBox.FocusLost:Connect(function()
    CONFIG.Webhook.url = hookBox.Text
    setStatus(CONFIG.Webhook.url ~= "" and "webhook enregistré" or "webhook vidé")
end)

makeToggle(webPage, "Notifier les fruits", CONFIG.Webhook.notifyFruits, function(v)
    CONFIG.Webhook.notifyFruits = v
end)

makeToggle(webPage, "Notifier les points de stat", CONFIG.Webhook.notifyStats, function(v)
    CONFIG.Webhook.notifyStats = v
end)

makeButton(webPage, "Envoyer un test", function()
    local ok = Webhook.send("RFX — test", "Le webhook répond. Script chargé sur " .. LocalPlayer.Name, 3771456)
    setStatus(ok and "webhook : envoyé" or "webhook : échec")
end)

makeButton(webPage, "Envoyer le résumé du farm", function()
    local ok = Webhook.send(
        "RFX — résumé",
        string.format("vu %d • ramassé %d • stocké %d • hop %d",
            Farm.stats.seen, Farm.stats.collected, Farm.stats.stored, Farm.stats.hops),
        3771456
    )
    setStatus(ok and "webhook : résumé envoyé" or "webhook : échec")
end)

makeInfo(webPage, "l'URL du webhook est visible par qui lit le script", 32)

---------------------------------------------------------------
--  DRAG / MINIMIZE
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
        main:TweenSize(UDim2.fromOffset(448, 38), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        contentArea.Visible = false
        tabBar.Visible = false
        statusBar.Visible = false
    else
        main:TweenSize(UDim2.fromOffset(448, 356), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
        contentArea.Visible = true
        tabBar.Visible = true
        statusBar.Visible = true
    end
end)

guiMini = new("TextButton", {
    Size = UDim2.fromOffset(54, 54),
    Position = UDim2.new(1, -74, 0.5, -27),
    BackgroundColor3 = C.panel,
    Text = "RFX",
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
--  BOUCLE UI (fps, stats, liste du sac)
-- ══════════════════════════════════════════════════════════════
UI.connections[#UI.connections + 1] = RunService.RenderStepped:Connect(function()
    UI.frames = UI.frames + 1
    local now = os.clock()
    if now - UI.fpsClock < 0.5 then return end

    UI.fps = math.floor(UI.frames / (now - UI.fpsClock) + 0.5)
    UI.frames = 0
    UI.fpsClock = now

    local ping = 0
    pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)

    local count = 0
    for _ in pairs(ESP.items) do count = count + 1 end
    UI.countLabel.Text = string.format("%d cible  •  %dms  •  %d fps", count, ping, UI.fps)

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

    pointsInfo.Text = "points dispo : " .. Stats.points()
    spentInfo.Text = "dépensés cette session : " .. Stats.spent

    for _, stat in ipairs(STAT_LIST) do
        local t = statToggles[stat]
        if t and t.label then
            t.label.Text = stat .. "  (" .. Stats.level(stat) .. ")"
        end
    end
end)

---------------------------------------------------------------
--  KEYBIND
---------------------------------------------------------------
UI.connections[#UI.connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.Radar.tpKey then
        local inst, pos = nearest("Fruit", fruitFilter)
        if inst and pos then
            Movement.tp(pos)
            setStatus("tp → " .. inst.Name)
        else
            setStatus("aucun fruit")
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════════════════════════════
_G.RFX_Unload = function()
    Farm.stop()
    FarmLevel.active = false
    FarmBoss.active = false
    Combat.fastAttack = false
    CONFIG.Stats.active = false
    CONFIG.Protect.antiKick = false
    CONFIG.Protect.spoofHumanoid = false
    CONFIG.Protect.antiAfk = false
    for category in pairs(ESP_ON) do ESP_ON[category] = false end

    for _, c in ipairs(ESP.connections) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(UI.connections) do pcall(function() c:Disconnect() end) end

    espClear()
    pcall(function() gui:Destroy() end)
    _G.RFX_Unload = nil
end

setStatus("prêt — T = tp fruit")
refreshFarmBig()
