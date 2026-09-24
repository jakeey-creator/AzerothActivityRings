-- ============================================================
-- Azeroth Activity Rings - Core
-- Datenhaltung, Tagesverwaltung, Tracking (Schritte, Aktivität,
-- Quests/Bosse), Serien, Erinnerungen und Slash-Befehle.
-- ============================================================

local ADDON, ns = ...
_G.AzerothActivityRings = ns

ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
ns.FONT = "Fonts\\FRIZQT__.TTF"
ns.STRIDE = 0.8              -- Yards pro Schritt
ns.RUN_SPEED = 7             -- normale Laufgeschwindigkeit (Yards/s)
ns.ACTIVE_HOUR_STEPS = 250   -- Schritte, damit eine Stunde als "bewegt" zählt
ns.LOOT_ACTIVE_SECONDS = 20  -- Plündern/Sammeln hält dich so lange "aktiv"
ns.HISTORY_DAYS = 120

ns.RINGS = {
    { key = "move",   name = "Pfadfinder", unit = "Schritte", color = { 1.00, 0.50, 0.00 }, hex = "ff8000" },
    { key = "active", name = "Eiferer",    unit = "Min.",     color = { 0.64, 0.21, 0.93 }, hex = "a335ee" },
    { key = "quest",  name = "Abenteurer", unit = "Quests",   color = { 0.00, 0.44, 0.87 }, hex = "0070dd" },
}
ns.RING_BY_KEY = {}
for _, r in ipairs(ns.RINGS) do ns.RING_BY_KEY[r.key] = r end

local DEFAULTS = {
    goals = { move = 10000, active = 30, quest = 10 },
    settings = {
        scale = 1, locked = false, shown = true, face = "full",
        sound = true, remind = true, mountedFactor = 0.25, resetHour = 0,
    },
    totals = {
        steps = 0, footYards = 0, rideYards = 0, active = 0, quests = 0,
        bosses = 0, kills = 0, rings = 0, perfect = 0,
    },
    streak = { current = 0, best = 0, last = nil },
    medals = {},
    days = {},
    session = { start = 0, lastSeen = 0 },
}

local db

-- ------------------------------------------------------------
-- Hilfsfunktionen
-- ------------------------------------------------------------

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end
ns.IsSecret = IsSecret

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.Print(msg)
    print("|cffff8000A|r|cffa335eeA|r|cff0070ddR|r: " .. msg)
end

-- 12345.6 -> "12.346"
function ns.Num(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local r
    repeat s, r = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2") until r == 0
    return s
end

function ns.Km(yards)
    local s = string.format("%.1f km", (yards or 0) * 0.9144 / 1000)
    return (s:gsub("%.", ","))
end

function ns.Duration(sec)
    sec = math.floor(sec or 0)
    local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
    if h > 0 then return string.format("%d:%02d h", h, m) end
    return string.format("%d Min.", m)
end

function ns.Hex(key)
    return "|cff" .. ns.RING_BY_KEY[key].hex
end

-- ------------------------------------------------------------
-- Ereignisse innerhalb des Add-ons (Ring geschlossen, Medaille ...)
-- ------------------------------------------------------------

local listeners = {}
function ns:On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end
function ns:Fire(event, ...)
    for _, fn in ipairs(listeners[event] or {}) do fn(...) end
end

-- ------------------------------------------------------------
-- Tage
-- ------------------------------------------------------------

function ns.DayKey(t)
    return date("%Y-%m-%d", (t or time()) - (db.settings.resetHour or 0) * 3600)
end

-- Schlüssel des Tages vor `days` Tagen (12 Uhr als Anker, damit Sommerzeit nicht stört)
function ns.KeyOffset(days)
    local t = date("*t", time() - (db.settings.resetHour or 0) * 3600)
    t.hour, t.min, t.sec = 12, 0, 0
    return date("%Y-%m-%d", time(t) - days * 86400)
end

local function NewDay(key)
    local d = {
        key = key, goals = {}, steps = 0, footYards = 0, rideYards = 0, active = 0,
        online = 0, quests = 0, bosses = 0, kills = 0, levels = 0, maxBpm = 0,
        hourly = {}, closed = {}, medals = {},
    }
    for k, v in pairs(db.goals) do d.goals[k] = v end
    for h = 1, 24 do d.hourly[h] = 0 end
    return d
end

local currentKey
function ns.Today()
    local key = ns.DayKey()
    local d = db.days[key]
    if not d then
        d = NewDay(key)
        db.days[key] = d
    end
    if currentKey ~= key then
        local first = currentKey == nil
        currentKey = key
        ns:Fire("NewDay", d, first)
    end
    return d
end

function ns.Value(d, key)
    if key == "move" then return d.steps
    elseif key == "active" then return d.active / 60
    else return d.quests + d.bosses end
end

function ns.Progress(d, key)
    local g = d.goals[key] or db.goals[key]
    if not g or g <= 0 then return 0 end
    return ns.Value(d, key) / g
end

function ns.ActiveHours(d)
    local n = 0
    for h = 1, 24 do
        if (d.hourly[h] or 0) >= ns.ACTIVE_HOUR_STEPS then n = n + 1 end
    end
    return n
end

function ns.CurrentStreak()
    local st = db.streak
    if st.last == ns.DayKey() or st.last == ns.KeyOffset(1) then return st.current end
    return 0
end

function ns.SetGoal(key, value)
    db.goals[key] = value
    ns.Today().goals[key] = value
    ns:Evaluate()
end

-- ------------------------------------------------------------
-- Auswertung: Ringe schließen, perfekter Tag, Serien
-- ------------------------------------------------------------

function ns:Evaluate()
    local d = ns.Today()
    local now = time()
    local all = true
    for _, r in ipairs(ns.RINGS) do
        if ns.Progress(d, r.key) >= 1 then
            if not d.closed[r.key] then
                d.closed[r.key] = now
                db.totals.rings = db.totals.rings + 1
                ns:Fire("RingClosed", r, d)
            end
        else
            all = false
        end
    end
    if all and not d.perfect then
        d.perfect = now
        local st = db.streak
        if st.last == ns.KeyOffset(1) then st.current = st.current + 1 else st.current = 1 end
        st.last = d.key
        st.best = math.max(st.best, st.current)
        db.totals.perfect = db.totals.perfect + 1
        ns:Fire("PerfectDay", d, st.current)
    end
    if ns.CheckMedals then ns.CheckMedals(d) end
    ns:Fire("Update", d)
end

-- ------------------------------------------------------------
-- Tracking
-- ------------------------------------------------------------

local activeUntil = 0
local lastEval = 0
ns.lastMove = GetTime()

function ns.IsActive()
    if UnitIsAFK("player") or UnitIsDeadOrGhost("player") then return false end
    if UnitAffectingCombat("player") then return true end
    if GetTime() < activeUntil then return true end
    if UnitChannelInfo("player") then return true end -- Angeln & Co.
    return false
end

function ns.IsRiding()
    return IsMounted() or (UnitInVehicle and UnitInVehicle("player")) or false
end

local function Tick(dt)
    local d = ns.Today()
    local t = db.totals
    d.online = d.online + dt

    local speed = GetUnitSpeed("player")
    if speed and not IsSecret(speed) and speed > 0 and not UnitOnTaxi("player") then
        local yards = speed * dt
        local steps = yards / ns.STRIDE
        if ns.IsRiding() then
            d.rideYards = d.rideYards + yards
            t.rideYards = t.rideYards + yards
            steps = steps * db.settings.mountedFactor
        else
            d.footYards = d.footYards + yards
            t.footYards = t.footYards + yards
        end
        local h = tonumber(date("%H")) + 1
        d.hourly[h] = (d.hourly[h] or 0) + steps
        d.steps = d.steps + steps
        t.steps = t.steps + steps
        ns.lastMove = GetTime()
    end

    if ns.IsActive() then
        d.active = d.active + dt
        t.active = t.active + dt
    end

    local now = GetTime()
    if now - lastEval >= 1 then
        lastEval = now
        db.session.lastSeen = time()
        ns:Evaluate()
    end
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:Hide()
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    local dt = acc
    acc = 0
    if dt > 2 then return end -- Ladebildschirm / Ruckler nicht mitzählen
    Tick(dt)
end)

-- ------------------------------------------------------------
-- Erinnerungen (wie "Zeit aufzustehen" auf der Uhr)
-- ------------------------------------------------------------

local remindedHour
local function Reminders()
    if not db.settings.remind then return end
    if UnitAffectingCombat("player") or UnitIsAFK("player") then return end
    local d = ns.Today()
    local t = date("*t")

    if t.min >= 50 and remindedHour ~= t.hour and (d.hourly[t.hour + 1] or 0) < ns.ACTIVE_HOUR_STEPS then
        remindedHour = t.hour
        local missing = ns.ACTIVE_HOUR_STEPS - (d.hourly[t.hour + 1] or 0)
        ns:Fire("Notify", "move", "Zeit, dich zu bewegen!",
            string.format("Noch %s Schritte, dann zählt diese Stunde als aktiv.", ns.Num(missing)))
    end

    if t.hour >= 20 and not d.coached and not d.closed.move then
        d.coached = true
        local remaining = d.goals.move - d.steps
        local minutes = math.ceil(remaining * ns.STRIDE / ns.RUN_SPEED / 60)
        ns:Fire("Notify", "move", "Du schaffst das heute noch!",
            string.format("%s Schritte fehlen – etwa %d Min. zu Fuß laufen.", ns.Num(remaining), minutes))
    end
end

-- ------------------------------------------------------------
-- WoW-Events
-- ------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("LOOT_OPENED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
-- Das Kampflog steht ab Midnight (12.0) Add-ons nicht mehr frei zur Verfügung.
local legacyCombatLog = select(4, GetBuildInfo()) < 120000
if legacyCombatLog then ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end

local playerGUID

local handlers = {}

local addonLoaded, loggedIn, started

local function UseDB(t)
    db = t
    Merge(db, DEFAULTS)
    db.created = db.created or time()
    ns.db = db
    AAR_DB = db
end

local function CountDays(t)
    local n = 0
    for _ in pairs(t.days or {}) do n = n + 1 end
    return n
end

-- Zahlen aus `src` auf `dst` addieren (für nachträglich geladene Daten)
local function AddNumbers(dst, src)
    for k, v in pairs(src) do
        if k == "maxBpm" then
            dst[k] = math.max(type(dst[k]) == "number" and dst[k] or 0, v)
        elseif type(v) == "number" and k ~= "key" then
            dst[k] = (type(dst[k]) == "number" and dst[k] or 0) + v
        elseif type(v) == "table" and k ~= "goals" and k ~= "closed" and k ~= "medals" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            AddNumbers(dst[k], v)
        end
    end
end

-- Sicherheitsnetz: Setzt WoW die gespeicherten Daten erst nach unserem Start ein,
-- übernehmen wir sie und rechnen die bisherigen Werte dieser Sitzung dazu.
local function AdoptLateData()
    if not db or type(AAR_DB) ~= "table" or AAR_DB == db then return end
    local late, session = AAR_DB, db
    local key = ns.DayKey()
    UseDB(late)
    if session.days[key] then
        if db.days[key] then AddNumbers(db.days[key], session.days[key]) else db.days[key] = session.days[key] end
    end
    AddNumbers(db.totals, session.totals)
    ns.Print(string.format("Gespeicherter Fortschritt nachgeladen (%d Tage).", CountDays(db)))
    ns:Fire("Settings")
    ns:Evaluate()
end

local function Start()
    if started or not addonLoaded or not loggedIn then return end
    started = true
    local fresh = type(AAR_DB) ~= "table"
    UseDB(fresh and {} or AAR_DB)
    if fresh then
        ns.Print("Willkommen! Neue Datenbank angelegt.")
    else
        ns.Print(string.format("Fortschritt geladen (%d Tage).", CountDays(db)))
    end
    playerGUID = UnitGUID("player")

    -- Sitzung: /reload setzt die Sitzungsdauer nicht zurück
    if time() - (db.session.lastSeen or 0) > 120 then db.session.start = time() end
    db.session.lastSeen = time()

    -- alte Tage aufräumen
    local cutoff = ns.KeyOffset(ns.HISTORY_DAYS)
    for key in pairs(db.days) do
        if key < cutoff then db.days[key] = nil end
    end

    ns:Fire("Init")
    ns.Today()
    ns:Evaluate()
    ticker:Show()
    C_Timer.NewTicker(30, Reminders)
    C_Timer.After(5, AdoptLateData)
end

-- Gespeicherte Daten sind erst ab ADDON_LOADED sicher da, die Spielwelt erst ab PLAYER_LOGIN.
-- Gestartet wird, sobald beides passiert ist – egal in welcher Reihenfolge.
function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    addonLoaded = true
    Start()
end

function handlers.PLAYER_LOGIN()
    loggedIn = true
    Start()
end

function handlers.PLAYER_ENTERING_WORLD()
    AdoptLateData()
end

function handlers.PLAYER_LOGOUT()
    if db then db.session.lastSeen = time() end
end

function handlers.QUEST_TURNED_IN()
    local d = ns.Today()
    d.quests = d.quests + 1
    db.totals.quests = db.totals.quests + 1
    ns:Evaluate()
end

function handlers.ENCOUNTER_END(_, _, _, _, success)
    if success == 1 or success == true then
        local d = ns.Today()
        d.bosses = d.bosses + 1
        db.totals.bosses = db.totals.bosses + 1
        ns:Evaluate()
    end
end

function handlers.LOOT_OPENED()
    activeUntil = GetTime() + ns.LOOT_ACTIVE_SECONDS
end

function handlers.PLAYER_REGEN_ENABLED()
    -- Nach dem Kampf: Zeit zum Plündern zählt noch mit
    activeUntil = math.max(activeUntil, GetTime() + 10)
end

function handlers.PLAYER_LEVEL_UP()
    local d = ns.Today()
    d.levels = d.levels + 1
    ns:Evaluate()
end

function handlers.COMBAT_LOG_EVENT_UNFILTERED()
    local _, sub, _, src = CombatLogGetCurrentEventInfo()
    if sub == "PARTY_KILL" and src == playerGUID then
        local d = ns.Today()
        d.kills = d.kills + 1
        db.totals.kills = db.totals.kills + 1
    end
end

ev:SetScript("OnEvent", function(_, event, ...)
    if not db and event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" then return end
    handlers[event](...)
end)

-- Tagesbilanz von gestern beim ersten Login / nach Mitternacht
ns:On("NewDay", function(d, first)
    local y = db.days[ns.KeyOffset(1)]
    if not y or (first and d.online > 0) then return end
    local closed = 0
    for _, r in ipairs(ns.RINGS) do if y.closed[r.key] then closed = closed + 1 end end
    ns.Print(string.format("Bilanz von gestern: %d/3 Ringe · %s Schritte · %d Min. aktiv · %d Quests/Bosse%s",
        closed, ns.Num(y.steps), math.floor(y.active / 60), y.quests + y.bosses,
        y.perfect and " · |cffffd200Perfekter Tag!|r" or ""))
end)

-- ------------------------------------------------------------
-- Slash-Befehle
-- ------------------------------------------------------------

local GOAL_ALIASES = {
    schritte = "move", move = "move", steps = "move", rot = "move",
    aktiv = "active", farm = "active", active = "active", gruen = "active", ["grün"] = "active",
    quests = "quest", quest = "quest", blau = "quest",
}

local HELP = {
    "|cffffd200/aar|r – Uhr ein-/ausblenden",
    "|cffffd200/aar details|r – Übersicht, Verlauf & Auszeichnungen",
    "|cffffd200/aar ziel schritte/aktiv/quests <Zahl>|r – Tagesziel setzen",
    "|cffffd200/aar face voll/minimal/daten|r – Zifferblatt wechseln",
    "|cffffd200/aar scale <0.5-2>|r · |cffffd200/aar lock|r · |cffffd200/aar reset|r (Position)",
    "|cffffd200/aar sound|r · |cffffd200/aar erinnerung|r – an/aus",
}

SLASH_AZEROTHACTIVITYRINGS1 = "/aar"
SLASH_AZEROTHACTIVITYRINGS2 = "/rings"
SlashCmdList.AZEROTHACTIVITYRINGS = function(msg)
    local cmd, a, b = strsplit(" ", strlower(strtrim(msg or "")))
    local s = db.settings
    if cmd == "" then
        s.shown = not s.shown
        ns:Fire("Settings")
    elseif cmd == "details" or cmd == "d" or cmd == "stats" then
        ns:TogglePanel()
    elseif cmd == "ziel" or cmd == "goal" then
        local key, value = GOAL_ALIASES[a or ""], tonumber(b)
        if not key or not value or value <= 0 then
            ns.Print("Beispiel: /aar ziel schritte 12000  ·  /aar ziel aktiv 45  ·  /aar ziel quests 15")
            return
        end
        ns.SetGoal(key, math.floor(value))
        ns.Print(string.format("%s%s|r-Ziel: %s %s", ns.Hex(key), ns.RING_BY_KEY[key].name,
            ns.Num(value), ns.RING_BY_KEY[key].unit))
    elseif cmd == "face" then
        local map = { voll = "full", full = "full", minimal = "minimal", daten = "data", data = "data" }
        s.face = map[a or ""] or s.face
        ns:Fire("Settings")
    elseif cmd == "scale" then
        local v = tonumber(a)
        if v then s.scale = math.max(0.5, math.min(2, v)); ns:Fire("Settings") end
    elseif cmd == "lock" then
        s.locked = not s.locked
        ns.Print(s.locked and "Uhr fixiert." or "Uhr kann verschoben werden.")
    elseif cmd == "reset" then
        s.point = nil
        ns:Fire("Settings")
    elseif cmd == "sound" then
        s.sound = not s.sound
        ns.Print("Sounds " .. (s.sound and "an" or "aus") .. ".")
    elseif cmd == "erinnerung" or cmd == "remind" then
        s.remind = not s.remind
        ns.Print("Erinnerungen " .. (s.remind and "an" or "aus") .. ".")
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end
