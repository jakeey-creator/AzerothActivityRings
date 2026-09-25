-- ============================================================
-- Azeroth Activity Rings - Die Uhr
-- Eckiges Classic-Gehäuse mit Seil-Rand, Messing-Zifferblatt,
-- drei Ringen, Komplikationen (Puls, Uhrzeit, Sitzung, Gold),
-- Tooltip, Benachrichtigungen und Sounds.
-- ============================================================

local _, ns = ...

local W, H, ROPE = 236, 268, 13
local PAD = ROPE + 7                 -- Innenabstand für Texte
local RING_R, RING_T, RING_GAP = 78, 14, 3

local watch, rings = nil, {}
local ui = {}

-- ------------------------------------------------------------
-- Sounds
-- ------------------------------------------------------------

local function Sound(kind)
    if not ns.db.settings.sound then return end
    if kind == "perfect" then
        PlaySoundFile(569593, "Master") -- Level-Up
    elseif kind == "ring" then
        PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878, "Master")
    elseif kind == "medal" then
        PlaySound(SOUNDKIT.READY_CHECK or 8960, "Master")
    else
        PlaySound(SOUNDKIT.TELL_MESSAGE or 3081, "Master")
    end
end

-- ------------------------------------------------------------
-- Benachrichtigungen (Toasts)
-- ------------------------------------------------------------

local TW, TH = 340, 76
local toast
local queue = {}

local function ShowNext()
    if toast:IsShown() or #queue == 0 then return end
    local n = table.remove(queue, 1)
    local c = n.color or { 1, 0.82, 0 }
    toast.title:SetText(n.title)
    toast.title:SetTextColor(c[1], c[2], c[3])
    toast.text:SetText(n.text or "")
    if n.icon then
        toast.icon:SetTexture(n.icon)
        toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        toast.icon:SetVertexColor(1, 1, 1)
    else
        toast.icon:SetTexture(ns.MEDIA .. "Dot")
        toast.icon:SetTexCoord(0, 1, 0, 1)
        toast.icon:SetVertexColor(c[1], c[2], c[3])
    end
    toast:Show()
    toast.anim:Play()
end

local function CreateToast()
    toast = CreateFrame("Frame", "AARToast", UIParent)
    toast:SetSize(TW, TH)
    toast:SetPoint("TOP", 0, -140)
    toast:SetFrameStrata("HIGH")
    toast:EnableMouse(true)
    toast:Hide()
    ns.Skin(toast, 9)

    local textW = TW - 16 - 36 - 10 - 16
    toast.icon = toast:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(36, 36)
    toast.icon:SetPoint("LEFT", 16, 0)
    toast.title = ns.Text(toast, 14, textW)
    toast.title:SetPoint("TOPLEFT", 16 + 36 + 10, -16)
    toast.text = ns.Text(toast, 11, textW, "LEFT", 0.9, 0.85, 0.75)
    toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -5)
    toast.text:SetWordWrap(true)                -- höchstens zwei Zeilen, dann "..."
    if toast.text.SetMaxLines then toast.text:SetMaxLines(2) end

    local ag = toast:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.3); a1:SetOrder(1)
    local a2 = ag:CreateAnimation("Alpha")
    a2:SetFromAlpha(1); a2:SetToAlpha(1); a2:SetDuration(3.6); a2:SetOrder(2)
    local a3 = ag:CreateAnimation("Alpha")
    a3:SetFromAlpha(1); a3:SetToAlpha(0); a3:SetDuration(0.8); a3:SetOrder(3)
    ag:SetScript("OnFinished", function()
        toast:Hide()
        ShowNext()
    end)
    toast.anim = ag
    toast:SetScript("OnMouseUp", function() ag:Stop(); toast:Hide(); ShowNext() end)
end

function ns.Toast(title, text, color, icon)
    table.insert(queue, { title = title, text = text, color = color, icon = icon })
    ShowNext()
end

-- ------------------------------------------------------------
-- Herzfrequenz (Spaß-Simulation)
-- ------------------------------------------------------------

local bpm, beatPhase = 64, 0

local function TargetBPM()
    if ns.IsDead() then return 0 end
    local target = ns.IsResting() and 58 or 64
    local speed = ns.Speed()
    if speed > 0 and not ns.OnTaxi() then
        target = ns.IsRiding() and 74 or (68 + speed * 2.6)
    end
    if ns.InCombat() then
        target = 118
        local hp, max = UnitHealth("player"), UnitHealthMax("player")
        if not ns.IsSecret(hp) and not ns.IsSecret(max) and max > 0 then
            target = target + (1 - hp / max) * 64 -- niedriges Leben = Herzrasen
        end
    end
    return target + math.random(-2, 2)
end

-- ------------------------------------------------------------
-- Uhr
-- ------------------------------------------------------------

local function Icon(parent, path, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(path)
    t:SetSize(size, size)
    return t
end

local function SavePosition()
    local point, _, rel, x, y = watch:GetPoint()
    ns.db.settings.point = { point, rel, x, y }
end

local function ApplySettings()
    local s = ns.db.settings
    watch:SetScale(s.scale)
    watch:ClearAllPoints()
    if s.point then
        watch:SetPoint(s.point[1], UIParent, s.point[2], s.point[3], s.point[4])
    else
        watch:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -220, 220)
    end
    local full, data = s.face == "full", s.face == "data"
    ui.heart:SetShown(full); ui.bpm:SetShown(full)
    ui.clockIcon:SetShown(full); ui.session:SetShown(full)
    ui.goldIcon:SetShown(full); ui.gold:SetShown(full)
    ui.center:SetShown(s.face ~= "minimal")
    for _, v in ipairs(ui.values) do v:SetShown(data) end
    local wasShown = watch:IsShown()
    watch:SetShown(s.shown)
    if s.shown and not wasShown then
        for _, r in pairs(rings) do r:Replay() end
    end
end

local function Refresh()
    if not watch or not watch:IsShown() then return end
    local d = ns.Today()
    for _, r in ipairs(ns.RINGS) do rings[r.key]:SetValue(ns.Progress(d, r.key)) end

    local streak = ns.CurrentStreak()
    ui.streak:SetText(streak > 999 and "999+" or streak)
    ui.streakLabel:SetText(streak == 1 and "Tag" or "Tage")
    if streak > 0 then ui.streak:SetTextColor(1, 0.82, 0) else ui.streak:SetTextColor(0.5, 0.45, 0.35) end

    ui.values[1]:SetText(ns.Short(d.steps))
    ui.values[2]:SetText(math.floor(d.active / 60) .. "/" .. d.goals.active)
    ui.values[3]:SetText((d.quests + d.bosses) .. "/" .. d.goals.quest)
end

local function Clock()
    ui.time:SetText(date("%H:%M"))
    ui.session:SetText((ns.Duration(time() - ns.db.session.start):gsub(" h", ""):gsub(" Min%.", "m")))
    ui.gold:SetText(ns.Short(math.floor(ns.SafeNumber(GetMoney()) / 10000)))

    local target = TargetBPM()
    bpm = bpm + (target - bpm) * 0.3
    local d = ns.Today()
    if bpm > d.maxBpm then d.maxBpm = math.floor(bpm) end
    if target == 0 then
        ui.bpm:SetText("--")
    else
        ui.bpm:SetText(math.floor(bpm + 0.5))
    end
end

local function ShowTooltip(self)
    local d = ns.Today()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Azeroth Activity Rings", 1, 0.82, 0)
    local title = ns.CurrentTitle()
    if title then GameTooltip:AddLine("<" .. title .. ">", 1, 1, 1) end
    GameTooltip:AddLine(" ")
    for _, r in ipairs(ns.RINGS) do
        local c = r.color
        local value = r.key == "active" and math.floor(d.active / 60) or ns.Value(d, r.key)
        GameTooltip:AddDoubleLine(r.name,
            string.format("%s / %s %s  (%d%%)", ns.Num(value), ns.Num(d.goals[r.key]), r.unit,
                ns.Progress(d, r.key) * 100),
            c[1], c[2], c[3], 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Zu Fuß / beritten", ns.Km(d.footYards) .. " / " .. ns.Km(d.rideYards), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Aktive Stunden", ns.ActiveHours(d), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Serie", ns.CurrentStreak() .. " (Rekord " .. ns.db.streak.best .. ")", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Klick: Details  ·  Rechtsklick: Zifferblatt", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("Ziehen: verschieben  ·  Shift+Mausrad: Größe", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local FACES = { "full", "data", "minimal" }

local function CreateWatch()
    watch = CreateFrame("Button", "AARWatch", UIParent)
    watch:SetSize(W, H)
    watch:SetFrameStrata("MEDIUM")
    watch:SetClampedToScreen(true)
    watch:SetMovable(true)
    watch:RegisterForDrag("LeftButton")
    watch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns.Skin(watch, ROPE)

    -- Zifferblatt: Messingrand mit dunkler Scheibe
    local holder = CreateFrame("Frame", nil, watch)
    local size = RING_R * 2 + RING_T
    holder:SetSize(size, size)
    holder:SetPoint("CENTER", 0, 0)
    local rim = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    rim:SetTexture(ns.MEDIA .. "Dot")
    rim:SetSize(size + 14, size + 14)
    rim:SetPoint("CENTER")
    rim:SetVertexColor(0.55, 0.40, 0.18)
    local rimShade = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
    rimShade:SetTexture(ns.MEDIA .. "Dot")
    rimShade:SetSize(size + 10, size + 10)
    rimShade:SetPoint("CENTER")
    rimShade:SetVertexColor(0.30, 0.21, 0.09)
    local dial = holder:CreateTexture(nil, "BACKGROUND", nil, -6)
    dial:SetTexture(ns.MEDIA .. "Dot")
    dial:SetSize(size + 6, size + 6)
    dial:SetPoint("CENTER")
    dial:SetVertexColor(0.05, 0.035, 0.025)

    for i, r in ipairs(ns.RINGS) do
        local radius = RING_R - (i - 1) * (RING_T + RING_GAP)
        local ring = ns.CreateRing(holder, radius, RING_T, r.color, { overflow = true, track = 0.26 })
        ring.frame:SetPoint("CENTER")
        rings[r.key] = ring
    end

    -- Mitte: Serie
    ui.center = CreateFrame("Frame", nil, holder)
    ui.center:SetAllPoints()
    ui.streak = ns.Text(ui.center, 20, 60, "CENTER")
    ui.streak:SetPoint("CENTER", 0, 5)
    ui.streakLabel = ns.Text(ui.center, 9, 60, "CENTER", 0.75, 0.65, 0.45)
    ui.streakLabel:SetPoint("TOP", ui.streak, "BOTTOM", 0, -2)

    -- Oben: Puls links, Uhrzeit rechts
    ui.heart = Icon(watch, ns.MEDIA .. "Heart", 14)
    ui.heart:SetVertexColor(0.9, 0.12, 0.12)
    ui.heart:SetPoint("TOPLEFT", PAD, -PAD)
    ui.bpm = ns.Text(watch, 13, 60, "LEFT", 1, 0.35, 0.3)
    ui.bpm:SetPoint("LEFT", ui.heart, "RIGHT", 4, 0)
    ui.time = ns.Text(watch, 15, 80, "RIGHT", 1, 0.82, 0)
    ui.time:SetPoint("TOPRIGHT", -PAD, -PAD + 1)

    -- Unten: Sitzung links, Gold rechts
    ui.clockIcon = Icon(watch, "Interface\\Icons\\INV_Misc_PocketWatch_01", 14)
    ui.clockIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    ui.clockIcon:SetPoint("BOTTOMLEFT", PAD, PAD)
    ui.session = ns.Text(watch, 13, 64, "LEFT", 0.9, 0.85, 0.75)
    ui.session:SetPoint("LEFT", ui.clockIcon, "RIGHT", 4, 0)
    ui.goldIcon = Icon(watch, "Interface\\MoneyFrame\\UI-GoldIcon", 12)
    ui.goldIcon:SetPoint("BOTTOMRIGHT", -PAD, PAD + 1)
    ui.gold = ns.Text(watch, 13, 70, "RIGHT", 1, 0.82, 0)
    ui.gold:SetPoint("RIGHT", ui.goldIcon, "LEFT", -3, 0)

    -- Zifferblatt "Daten": Werte statt Komplikationen, je ein Drittel der Breite
    ui.values = {}
    local third = (W - PAD * 2) / 3
    for i, r in ipairs(ns.RINGS) do
        local v = ns.Text(watch, 13, third - 4, "CENTER", r.color[1], r.color[2], r.color[3])
        v:SetPoint("BOTTOM", watch, "BOTTOMLEFT", PAD + third * (i - 0.5), PAD)
        ui.values[i] = v
    end

    -- Herzschlag-Animation
    local beat = ui.heart:CreateAnimationGroup()
    local up = beat:CreateAnimation("Scale")
    up:SetScale(1.35, 1.35); up:SetDuration(0.08); up:SetOrder(1)
    local down = beat:CreateAnimation("Scale")
    down:SetScale(1 / 1.35, 1 / 1.35); down:SetDuration(0.16); down:SetOrder(2)

    local clockAcc = 1
    watch:SetScript("OnUpdate", function(_, elapsed)
        clockAcc = clockAcc + elapsed
        if clockAcc >= 1 then
            Clock()
            clockAcc = 0
        end
        if bpm >= 1 then
            beatPhase = beatPhase + elapsed * bpm / 60
            if beatPhase >= 1 then
                beatPhase = beatPhase - 1
                if ui.heart:IsShown() then beat:Play() end
            end
        end
    end)

    -- Bedienung
    watch:SetScript("OnDragStart", function(self)
        if not ns.db.settings.locked then self:StartMoving() end
    end)
    watch:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    watch:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            local s = ns.db.settings
            for i, f in ipairs(FACES) do
                if f == s.face then s.face = FACES[i % #FACES + 1]; break end
            end
            ApplySettings()
            Refresh()
        else
            ns:TogglePanel()
        end
    end)
    watch:SetScript("OnMouseWheel", function(_, delta)
        if not IsShiftKeyDown() then return end
        local s = ns.db.settings
        s.scale = math.max(0.5, math.min(2, s.scale + delta * 0.05))
        watch:SetScale(s.scale)
    end)
    watch:EnableMouseWheel(true)
    watch:SetScript("OnEnter", ShowTooltip)
    watch:SetScript("OnLeave", GameTooltip_Hide)
    watch:SetScript("OnShow", Refresh)

    ApplySettings()
    Refresh()
    for _, r in pairs(rings) do r:Replay() end
end

-- ------------------------------------------------------------
-- Verdrahtung
-- ------------------------------------------------------------

ns:On("Init", function()
    CreateToast()
    CreateWatch()
end)

ns:On("Update", Refresh)
ns:On("Settings", function() ApplySettings(); Refresh() end)

ns:On("RingClosed", function(r)
    if rings[r.key] then rings[r.key]:Flash() end
    Sound("ring")
    ns.Toast(r.name .. "-Ring geschlossen!", "Tagesziel erreicht – stark!", r.color)
end)

ns:On("PerfectDay", function(_, streak)
    for _, ring in pairs(rings) do ring:Flash() end
    Sound("perfect")
    local text = streak > 1 and string.format("%d perfekte Tage in Folge!", streak) or "Alle drei Ringe geschlossen."
    ns.Toast("Perfekter Tag!", text, { 1, 0.82, 0 }, "Interface\\Icons\\Spell_Holy_HolyBolt")
end)

ns:On("Medal", function(m, rec)
    Sound("medal")
    local text = m.desc
    if rec.count > 1 then text = string.format("Zum %d. Mal verdient!", rec.count) end
    ns.Toast("Auszeichnung: " .. m.name, text, { 1, 0.82, 0 }, "Interface\\Icons\\" .. m.icon)
    if m.title and rec.count == 1 then
        ns.Print("Neuer Titel freigeschaltet: |cffffd200" .. m.title .. "|r")
    end
end)

ns:On("Notify", function(key, title, text)
    Sound("notify")
    ns.Toast(title, text, ns.RING_BY_KEY[key].color)
end)
