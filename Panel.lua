-- ============================================================
-- Azeroth Activity Rings - Detailfenster
-- Reiter: Heute · Woche · Auszeichnungen · Einstellungen
-- Alle Texte haben feste Breiten und werden notfalls gekürzt,
-- damit nichts über den Rahmen hinausläuft.
-- ============================================================

local _, ns = ...

local PW, PH, ROPE = 500, 484, 14
local CW = PW - 44          -- nutzbare Breite einer Seite (456)
local panel
local pages, tabs = {}, {}
local WEEKDAYS = { "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa" }
local GOLD = { 1, 0.82, 0 }
local TAN = { 0.78, 0.68, 0.5 }

local function T(parent, size, width, justify, c)
    c = c or { 1, 1, 1 }
    return ns.Text(parent, size, width, justify, c[1], c[2], c[3])
end

-- Raster aus "Bezeichnung ... Wert"-Paaren, zwei Spalten
local function Grid(page, y, count)
    local cells = {}
    local cellW = CW / 2
    for i = 1, count do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x = 4 + col * cellW
        local label = T(page, 11, 128, "LEFT", TAN)
        label:SetPoint("TOPLEFT", x, y - row * 17)
        local value = T(page, 11, cellW - 128 - 16, "RIGHT")
        value:SetPoint("LEFT", label, "RIGHT", 0, 0)
        cells[i] = { label = label, value = value }
    end
    function cells:Set(items)
        for i, cell in ipairs(self) do
            local item = items[i]
            cell.label:SetText(item and item[1] or "")
            cell.value:SetText(item and item[2] or "")
        end
    end
    return cells
end

-- Drei ineinanderliegende Ringe auf dunkler Scheibe
local function RingStack(parent, outer, thickness, gap)
    local stack = {}
    local size = outer * 2 + thickness
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    local disc = holder:CreateTexture(nil, "BACKGROUND", nil, -6)
    disc:SetTexture(ns.MEDIA .. "Dot")
    disc:SetSize(size + 6, size + 6)
    disc:SetPoint("CENTER")
    disc:SetVertexColor(0.04, 0.03, 0.02, 0.85)
    for i, r in ipairs(ns.RINGS) do
        local ring = ns.CreateRing(holder, outer - (i - 1) * (thickness + gap), thickness, r.color,
            { overflow = outer > 30, spacing = 0.45, maxDots = 90, track = 0.26 })
        ring.frame:SetPoint("CENTER")
        stack[r.key] = ring
    end
    stack.frame = holder
    function stack:Set(d, instant)
        for _, r in ipairs(ns.RINGS) do
            self[r.key]:SetValue(d and ns.Progress(d, r.key) or 0, instant)
        end
    end
    return stack
end

local function Header(page, y, text)
    local h = T(page, 13, CW - 8, "LEFT", GOLD)
    h:SetPoint("TOPLEFT", 4, y)
    h:SetText(text)
    return h
end

-- ------------------------------------------------------------
-- Heute
-- ------------------------------------------------------------

local function BuildToday(page)
    page.rings = RingStack(page, 62, 14, 2)
    page.rings.frame:SetPoint("TOPLEFT", 6, -6)

    page.rows = {}
    local x, w = 164, CW - 164
    for i, r in ipairs(ns.RINGS) do
        local row = {}
        row.name = T(page, 12, w, "LEFT", r.color)
        row.name:SetPoint("TOPLEFT", x, -4 - (i - 1) * 49)
        row.value = T(page, 18, w)
        row.value:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.sub = T(page, 10, w, "LEFT", TAN)
        row.sub:SetPoint("TOPLEFT", row.value, "BOTTOMLEFT", 0, -3)
        page.rows[r.key] = row
    end

    -- Schritte pro Stunde
    local chartTitle = T(page, 11, 220, "LEFT", TAN)
    chartTitle:SetPoint("TOPLEFT", 4, -160)
    chartTitle:SetText("Schritte pro Stunde")
    page.hoursText = T(page, 11, 220, "RIGHT", TAN)
    page.hoursText:SetPoint("TOPRIGHT", -4, -160)

    local chart = CreateFrame("Frame", nil, page)
    chart:SetPoint("TOPLEFT", 4, -176)
    chart:SetSize(CW - 8, 70)
    local bg = chart:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.35)
    bg:SetAllPoints()
    page.bars = {}
    local step = (CW - 8) / 24
    for h = 1, 24 do
        local bar = chart:CreateTexture(nil, "ARTWORK")
        bar:SetColorTexture(1, 1, 1)
        bar:SetWidth(step - 6)
        bar:SetPoint("BOTTOMLEFT", 3 + (h - 1) * step, 0)
        page.bars[h] = bar
        if (h - 1) % 6 == 0 then
            local lbl = T(page, 9, 30, "LEFT", TAN)
            lbl:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 3 + (h - 1) * step, -3)
            lbl:SetText(string.format("%02d", h - 1))
        end
    end

    page.grid = Grid(page, -268, 8)

    page.title = T(page, 14, CW - 8, "CENTER", GOLD)
    page.title:SetPoint("BOTTOM", 0, 4)
end

local function RefreshToday(page)
    local d = ns.Today()
    page.rings:Set(d)
    local rows = page.rows
    rows.move.value:SetText(ns.Num(d.steps) .. " / " .. ns.Num(d.goals.move))
    rows.move.sub:SetText("Schritte · " .. ns.Km(d.footYards) .. " zu Fuß")
    rows.active.value:SetText(math.floor(d.active / 60) .. " / " .. d.goals.active .. " Min.")
    rows.active.sub:SetText("aktiv · " .. ns.Num(d.kills) .. " Todesstöße")
    rows.quest.value:SetText((d.quests + d.bosses) .. " / " .. d.goals.quest)
    rows.quest.sub:SetText(d.quests .. " Quests · " .. d.bosses .. " Bosse")
    for _, r in ipairs(ns.RINGS) do
        rows[r.key].name:SetText(string.format("%s  %d%%", r.name, ns.Progress(d, r.key) * 100))
    end

    local max = ns.ACTIVE_HOUR_STEPS * 4
    for h = 1, 24 do max = math.max(max, d.hourly[h] or 0) end
    local c = ns.RINGS[1].color
    for h, bar in ipairs(page.bars) do
        local v = d.hourly[h] or 0
        bar:SetHeight(math.max(2, v / max * 66))
        local f = v >= ns.ACTIVE_HOUR_STEPS and 1 or 0.35
        bar:SetColorTexture(c[1] * f, c[2] * f, c[3] * f)
    end
    page.hoursText:SetText(ns.ActiveHours(d) .. " aktive Stunden")

    local db = ns.db
    page.grid:Set({
        { "Serie", ns.CurrentStreak() .. " Tage" },
        { "Rekord-Serie", db.streak.best .. " Tage" },
        { "Perfekte Tage", ns.Num(db.totals.perfect) },
        { "Beritten heute", ns.Km(d.rideYards) },
        { "Online heute", ns.Duration(d.online) },
        { "Max. Puls", d.maxBpm },
        { "Sitzung", ns.Duration(time() - db.session.start) },
        { "Level-ups heute", d.levels },
    })
    local title = ns.CurrentTitle()
    page.title:SetText(title and ("<" .. title .. ">") or "Noch kein Titel – schließ deine Ringe!")
end

-- ------------------------------------------------------------
-- Woche & Gesamt
-- ------------------------------------------------------------

local function BuildWeek(page)
    page.days = {}
    local colW = CW / 7
    for i = 1, 7 do
        local col = {}
        local cx = colW * (i - 0.5)
        col.label = T(page, 11, colW - 4, "CENTER")
        col.label:SetPoint("TOP", page, "TOPLEFT", cx, -2)
        col.rings = RingStack(page, 24, 7, 1)
        col.rings.frame:SetPoint("TOP", page, "TOPLEFT", cx, -20)
        col.date = T(page, 9, colW - 4, "CENTER", TAN)
        col.date:SetPoint("TOP", col.rings.frame, "BOTTOM", 0, -5)
        col.star = page:CreateTexture(nil, "OVERLAY")
        col.star:SetTexture(ns.MEDIA .. "Stud")
        col.star:SetSize(12, 12)
        col.star:SetPoint("TOP", col.date, "BOTTOM", 0, -2)
        page.days[i] = col
    end

    Header(page, -106, "Letzte 7 Tage")
    page.week = Grid(page, -124, 8)
    Header(page, -200, "Gesamt")
    page.total = Grid(page, -218, 12)
end

local function RefreshWeek(page)
    local db = ns.db
    local sum = { steps = 0, active = 0, quests = 0, perfect = 0, foot = 0, days = 0 }
    for i = 1, 7 do
        local key = ns.KeyOffset(7 - i)
        local d = db.days[key]
        local col = page.days[i]
        local y, m, dd = key:match("(%d+)-(%d+)-(%d+)")
        local wday = date("*t", time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 })).wday
        col.label:SetText(i == 7 and "Heute" or WEEKDAYS[wday])
        if i == 7 then col.label:SetTextColor(1, 0.82, 0) else col.label:SetTextColor(1, 1, 1) end
        col.date:SetText(dd .. "." .. m .. ".")
        col.rings:Set(d)
        col.star:SetShown(d and d.perfect and true or false)
        if d then
            sum.days = sum.days + 1
            sum.steps = sum.steps + d.steps
            sum.active = sum.active + d.active
            sum.quests = sum.quests + d.quests + d.bosses
            sum.foot = sum.foot + d.footYards
            if d.perfect then sum.perfect = sum.perfect + 1 end
        end
    end
    local n = math.max(1, sum.days)
    page.week:Set({
        { ns.Hex("move") .. "Schritte|r", ns.Num(sum.steps) },
        { "Ø pro Tag", ns.Num(sum.steps / n) },
        { ns.Hex("active") .. "Aktiv|r", ns.Duration(sum.active) },
        { "Ø pro Tag", math.floor(sum.active / 60 / n) .. " Min." },
        { ns.Hex("quest") .. "Quests & Bosse|r", sum.quests },
        { "Ø pro Tag", (string.format("%.1f", sum.quests / n):gsub("%.", ",")) },
        { "Zu Fuß", ns.Km(sum.foot) },
        { "Perfekte Tage", sum.perfect .. " / 7" },
    })

    local t = db.totals
    local earned = 0
    for _ in pairs(db.medals) do earned = earned + 1 end
    page.total:Set({
        { "Schritte", ns.Num(t.steps) },
        { "Zu Fuß", ns.Km(t.footYards) },
        { "Beritten", ns.Km(t.rideYards) },
        { "Aktive Zeit", ns.Duration(t.active) },
        { "Quests", ns.Num(t.quests) },
        { "Bosse", ns.Num(t.bosses) },
        { "Todesstöße", ns.Num(t.kills) },
        { "Ringe geschlossen", ns.Num(t.rings) },
        { "Perfekte Tage", ns.Num(t.perfect) },
        { "Beste Serie", db.streak.best .. " Tage" },
        { "Auszeichnungen", earned .. " / " .. #ns.MEDALS },
        { "Dabei seit", date("%d.%m.%Y", db.created) },
    })
end

-- ------------------------------------------------------------
-- Auszeichnungen
-- ------------------------------------------------------------

local function MedalTooltip(self)
    local m = self.medal
    local rec = ns.db.medals[m.id]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(m.name, 1, 0.82, 0)
    GameTooltip:AddLine(m.desc, 1, 1, 1, true)
    if m.daily then GameTooltip:AddLine("Täglich wiederholbar", 0.5, 0.8, 1) end
    if m.title then GameTooltip:AddLine("Titel: " .. m.title, 0.64, 0.21, 0.93) end
    if rec then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Erhalten am " .. date("%d.%m.%Y", rec.first), 0.4, 1, 0.4)
        if rec.count > 1 then
            GameTooltip:AddLine(rec.count .. "-mal verdient, zuletzt " .. date("%d.%m.%Y", rec.last), 0.4, 1, 0.4)
        end
    else
        GameTooltip:AddLine("Noch nicht verdient", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function BuildMedals(page)
    page.header = Header(page, -2, "")
    page.buttons = {}
    local perRow, size = 6, 34
    local cellW, cellH = CW / perRow, 64
    for i, m in ipairs(ns.MEDALS) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(cellW, cellH)
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        b:SetPoint("TOPLEFT", col * cellW, -24 - row * cellH)
        b.border = b:CreateTexture(nil, "BACKGROUND")
        b.border:SetColorTexture(0, 0, 0, 0.6)
        b.border:SetSize(size + 4, size + 4)
        b.border:SetPoint("TOP", 0, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture("Interface\\Icons\\" .. m.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon:SetSize(size, size)
        b.icon:SetPoint("TOP", 0, -2)
        b.count = T(b, 11, size, "RIGHT")
        b.count:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 1, 1)
        b.name = T(b, 9, cellW - 4, "CENTER")
        b.name:SetPoint("TOP", b.icon, "BOTTOM", 0, -4)
        b.name:SetText(m.name)
        b.medal = m
        b:SetScript("OnEnter", MedalTooltip)
        b:SetScript("OnLeave", GameTooltip_Hide)
        page.buttons[i] = b
    end
end

local function RefreshMedals(page)
    local earned = 0
    for _, b in ipairs(page.buttons) do
        local rec = ns.db.medals[b.medal.id]
        b.icon:SetDesaturated(not rec)
        b.icon:SetAlpha(rec and 1 or 0.3)
        if rec then b.name:SetTextColor(1, 0.82, 0) else b.name:SetTextColor(0.5, 0.45, 0.38) end
        b.count:SetText(rec and rec.count > 1 and rec.count or "")
        if rec then earned = earned + 1 end
    end
    page.header:SetText(string.format("%d von %d Auszeichnungen freigeschaltet", earned, #ns.MEDALS))
end

-- ------------------------------------------------------------
-- Einstellungen
-- ------------------------------------------------------------

local CTRL_X = 212

local function Stepper(page, y, label, get, set, step, min, max, fmt)
    local l = T(page, 12, CTRL_X - 16)
    l:SetPoint("TOPLEFT", 8, y)
    l:SetText(label)
    local minus = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    minus:SetSize(24, 22)
    minus:SetPoint("TOPLEFT", CTRL_X, y + 4)
    minus:SetText("-")
    local value = T(page, 11, 130, "CENTER")
    value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    local plus = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    plus:SetSize(24, 22)
    plus:SetPoint("LEFT", value, "RIGHT", 4, 0)
    plus:SetText("+")
    local function Update() value:SetText(fmt(get())) end
    local function Change(dir)
        local v = get() + dir * (IsShiftKeyDown() and step * 5 or step)
        set(math.max(min, math.min(max, math.floor(v * 100 + 0.5) / 100)))
        Update()
    end
    minus:SetScript("OnClick", function() Change(-1) end)
    plus:SetScript("OnClick", function() Change(1) end)
    return Update
end

local function Check(page, x, y, label, key, onChange)
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local l = T(page, 12, CW / 2 - 40)
    l:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    l:SetText(label)
    cb:SetScript("OnClick", function(self)
        ns.db.settings[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    return function() cb:SetChecked(ns.db.settings[key]) end
end

local function BuildSettings(page)
    local s = function() return ns.db.settings end
    local g = function() return ns.db.goals end
    local fire = function() ns:Fire("Settings") end
    page.updaters = {}
    local u = page.updaters
    local function add(fn) table.insert(u, fn) end

    Header(page, -2, "Tagesziele  (Shift-Klick = 5er-Schritte)")
    add(Stepper(page, -28, ns.Hex("move") .. "Pfadfinder|r", function() return g().move end,
        function(v) ns.SetGoal("move", v) end, 500, 1000, 100000,
        function(v) return ns.Num(v) .. " Schritte" end))
    add(Stepper(page, -56, ns.Hex("active") .. "Eiferer|r", function() return g().active end,
        function(v) ns.SetGoal("active", v) end, 5, 5, 600,
        function(v) return v .. " Min." end))
    add(Stepper(page, -84, ns.Hex("quest") .. "Abenteurer|r", function() return g().quest end,
        function(v) ns.SetGoal("quest", v) end, 1, 1, 100,
        function(v) return v .. " Quests/Bosse" end))

    Header(page, -118, "Tracking & Uhr")
    add(Stepper(page, -144, "Reiten zählt als Schritte", function() return s().mountedFactor end,
        function(v) s().mountedFactor = v end, 0.05, 0, 1,
        function(v) return math.floor(v * 100 + 0.5) .. " %" end))
    add(Stepper(page, -172, "Tageswechsel um", function() return s().resetHour end,
        function(v) s().resetHour = v; ns:Evaluate() end, 1, 0, 8,
        function(v) return string.format("%02d:00 Uhr", v) end))
    add(Stepper(page, -200, "Größe der Uhr", function() return s().scale end,
        function(v) s().scale = v; fire() end, 0.05, 0.5, 2,
        function(v) return math.floor(v * 100 + 0.5) .. " %" end))

    local faceLabel = T(page, 12, CTRL_X - 16)
    faceLabel:SetPoint("TOPLEFT", 8, -228)
    faceLabel:SetText("Zifferblatt")
    local faces = { { "full", "Voll" }, { "data", "Daten" }, { "minimal", "Minimal" } }
    local faceButtons = {}
    local bw = (CW - CTRL_X - 8) / 3
    for i, f in ipairs(faces) do
        local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        b:SetSize(bw - 4, 22)
        b:SetPoint("TOPLEFT", CTRL_X + (i - 1) * bw, -224)
        b:SetText(f[2])
        b:SetScript("OnClick", function()
            s().face = f[1]
            fire()
            for _, fn in ipairs(u) do fn() end
        end)
        faceButtons[f[1]] = b
    end
    add(function()
        for key, b in pairs(faceButtons) do
            if key == s().face then b:LockHighlight() else b:UnlockHighlight() end
        end
    end)

    add(Check(page, 4, -258, "Uhr anzeigen", "shown", fire))
    add(Check(page, 4, -284, "Uhr fixieren", "locked"))
    add(Check(page, CW / 2, -258, "Sounds", "sound"))
    add(Check(page, CW / 2, -284, "Erinnerungen", "remind"))

    local hint = T(page, 10, CW - 8, "LEFT", TAN)
    hint:SetPoint("BOTTOMLEFT", 4, 4)
    hint:SetWordWrap(true)
    if hint.SetMaxLines then hint:SetMaxLines(4) end
    hint:SetText("1 Schritt = 0,8 Yards. Aktiv zählt: Kampf, Plündern/Sammeln (+20 s) und Kanalisieren " ..
        "wie Angeln. Quests: jede abgegebene Quest und jeder besiegte Boss. Befehle: /aar help")
end

local function RefreshSettings(page)
    for _, fn in ipairs(page.updaters) do fn() end
end

-- ------------------------------------------------------------
-- Fenster
-- ------------------------------------------------------------

local PAGES = {
    { "Heute", BuildToday, RefreshToday },
    { "Woche", BuildWeek, RefreshWeek },
    { "Erfolge", BuildMedals, RefreshMedals },
    { "Optionen", BuildSettings, RefreshSettings },
}

local current = 1

local function Select(i)
    current = i
    for j, p in ipairs(pages) do
        p:SetShown(i == j)
        if i == j then tabs[j]:LockHighlight() else tabs[j]:UnlockHighlight() end
    end
    PAGES[i][3](pages[i])
    if i == 1 then for _, r in ipairs(ns.RINGS) do pages[1].rings[r.key]:Replay() end end
    if i == 2 then
        for _, col in ipairs(pages[2].days) do
            for _, r in ipairs(ns.RINGS) do col.rings[r.key]:Replay() end
        end
    end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "AARPanel", UIParent)
    panel:SetSize(PW, PH)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    table.insert(UISpecialFrames, "AARPanel") -- ESC schließt
    ns.Skin(panel, ROPE)

    local title = T(panel, 16, PW - 120, "CENTER")
    title:SetPoint("TOP", 0, -22)
    title:SetText("|cffff8000Azeroth|r |cffa335eeActivity|r |cff0070ddRings|r")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -20, -18)

    local tabW = CW / #PAGES
    for i, p in ipairs(PAGES) do
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(tabW - 4, 24)
        b:SetPoint("TOPLEFT", 22 + (i - 1) * tabW, -46)
        b:SetText(p[1])
        b:SetScript("OnClick", function() Select(i) end)
        tabs[i] = b

        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", 22, -80)
        page:SetPoint("BOTTOMRIGHT", -22, 22)
        page:Hide()
        p[2](page)
        pages[i] = page
    end

    panel:SetScript("OnShow", function() Select(current) end)
    Select(current)
end

function ns:TogglePanel()
    if not panel then
        CreatePanel()
        return
    end
    panel:SetShown(not panel:IsShown())
end

ns:On("Update", function()
    if panel and panel:IsShown() then PAGES[current][3](pages[current]) end
end)
