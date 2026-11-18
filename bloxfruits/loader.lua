--[[
  RFX v2 — loader
  Passe l'ID du compte dans le lien, puis le script se vérifie lui-même.

  Usage : coller ce fichier dans l'executor et exécuter.
  L'ID ci-dessous doit être celui du compte qui joue, ET figurer dans
  la table WHITELIST de rfx_v2.lua, sinon le script refuse de démarrer.
--]]

local ROBLOX_ID = "12020224798"
local BASE_URL  = "https://raw.githubusercontent.com/wisko378/lun-a-13/main/bloxfruits/rfx_v2.lua"

local url = BASE_URL .. "?id=" .. ROBLOX_ID

local function fetch(u)
    if type(request) == "function" then
        local ok, r = pcall(function()
            return request({ Url = u, Method = "GET" })
        end)
        if ok and type(r) == "table" and r.Body then return r.Body end
    end
    if type(http_request) == "function" then
        local ok, r = pcall(function()
            return http_request({ Url = u, Method = "GET" })
        end)
        if ok and type(r) == "table" and r.Body then return r.Body end
    end
    if syn and type(syn.request) == "function" then
        local ok, r = pcall(function()
            return syn.request({ Url = u, Method = "GET" })
        end)
        if ok and type(r) == "table" and r.Body then return r.Body end
    end
    if type(game.HttpGet) == "function" then
        local ok, r = pcall(function() return game:HttpGet(u) end)
        if ok and type(r) == "string" then return r end
    end
    return nil
end

local body = fetch(url)
if not body then
    print("[RFX] échec du téléchargement")
    return
end

local chunk, err = loadstring(body)
if not chunk then
    print("[RFX] erreur de chargement : " .. tostring(err))
    return
end

-- l'ID part en argument du chunk : le script le compare à UserId
-- l'URL part en 2e argument : elle sert au bouton « auto-exécute »
-- (queue_on_teleport recharge le script après hop / changement de mer)
if type(getgenv) == "function" then
    pcall(function()
        getgenv().RFX_URL = BASE_URL
        getgenv().RFX_LINK_ID = ROBLOX_ID
    end)
end

chunk(ROBLOX_ID, BASE_URL)
