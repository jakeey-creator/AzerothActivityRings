-- ============================================================
-- Azeroth Activity Rings - Ring-Widget
-- Ein Fortschrittsring aus dicht überlappenden runden Punkten:
-- ergibt einen glatten Bogen mit abgerundeten Enden. Über 100 %
-- läuft eine zweite, hellere Runde mit Schatten an der Spitze.
-- ============================================================

local _, ns = ...

local TAU = math.pi * 2
local Ring = {}
Ring.__index = Ring

local function NoSnap(t)
    if t.SetSnapToPixelGrid then
        t:SetSnapToPixelGrid(false)
        t:SetTexelSnappingBias(0)
    end
end

function Ring:Place(t, frac)
    local a = frac * TAU
    t:ClearAllPoints()
    t:SetPoint("CENTER", self.frame, "CENTER", self.radius * math.sin(a), self.radius * math.cos(a))
end

function Ring:Dot(layer, sub, r, g, b, a)
    local t = self.frame:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(ns.MEDIA .. "Dot")
    t:SetSize(self.thickness, self.thickness)
    t:SetVertexColor(r, g, b, a or 1)
    NoSnap(t)
    return t
end

-- radius: Mittellinie des Rings, thickness: Strichstärke
-- opts.overflow: zweite Runde über 100 % anzeigen
-- opts.track: Helligkeit der Hintergrundspur (0..1)
function ns.CreateRing(parent, radius, thickness, color, opts)
    opts = opts or {}
    local self = setmetatable({}, Ring)
    local size = radius * 2 + thickness
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    self.frame, self.radius, self.thickness, self.color = f, radius, thickness, color

    local n = math.floor(TAU * radius / (thickness * (opts.spacing or 0.3)))
    self.n = math.max(24, math.min(n, opts.maxDots or 150))

    local r, g, b = color[1], color[2], color[3]
    local dim = opts.track or 0.22
    local lr, lg, lb = r + (1 - r) * 0.35, g + (1 - g) * 0.35, b + (1 - b) * 0.35

    self.lap1, self.lap2 = {}, nil
    if opts.overflow then self.lap2 = {} end
    for i = 1, self.n do
        local frac = (i - 1) / self.n
        self:Place(self:Dot("BACKGROUND", 2, r * dim, g * dim, b * dim), frac)
        local t = self:Dot("ARTWORK", 1, r, g, b)
        self:Place(t, frac)
        t:Hide()
        self.lap1[i] = t
        if self.lap2 then
            t = self:Dot("ARTWORK", 4, lr, lg, lb)
            self:Place(t, frac)
            t:Hide()
            self.lap2[i] = t
        end
    end
    self.tip1 = self:Dot("ARTWORK", 2, r, g, b)
    self.tip1:Hide()
    if self.lap2 then
        self.shadow = self:Dot("ARTWORK", 3, 0, 0, 0, 0.55)
        self.tip2 = self:Dot("ARTWORK", 5, lr, lg, lb)
        self.shadow:Hide()
        self.tip2:Hide()
    end
    self.shown1, self.shown2 = 0, 0

    -- Aufleuchten beim Schließen
    local glow = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetTexture(ns.MEDIA .. "Glow")
    glow:SetPoint("CENTER")
    glow:SetSize(size * 1.25, size * 1.25)
    glow:SetVertexColor(r, g, b)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    local ag = glow:CreateAnimationGroup()
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.2); fadeIn:SetOrder(1)
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(1.1); fadeOut:SetOrder(2)
    self.flash = ag

    self.display, self.target = 0, 0
    self.onUpdate = function(_, elapsed)
        local diff = self.target - self.display
        if math.abs(diff) < 0.0015 then
            self.display = self.target
            self:Draw(self.display)
            f:SetScript("OnUpdate", nil)
            self.animating = false
            return
        end
        self.display = self.display + diff * math.min(1, elapsed * 5)
        self:Draw(self.display)
    end
    return self
end

local function SetCount(list, old, new)
    for i = old + 1, new do list[i]:Show() end
    for i = new + 1, old do list[i]:Hide() end
end

-- Anzahl Rasterpunkte, die ein Bogen der Länge `frac` (0..1) abdeckt
local function Covered(frac, n)
    if frac <= 0 then return 0 end
    return math.min(n, math.floor(frac * n) + 1)
end

function Ring:Draw(p)
    local n = self.n
    local p1 = math.min(p, 1)
    local c1 = Covered(p1, n)
    SetCount(self.lap1, self.shown1, c1)
    self.shown1 = c1
    if p1 > 0 and p1 < 1 then
        self:Place(self.tip1, p1)
        self.tip1:Show()
    else
        self.tip1:Hide()
    end

    if self.lap2 then
        local p2 = math.min(math.max(p - 1, 0), 0.999)
        local c2 = Covered(p2, n)
        SetCount(self.lap2, self.shown2, c2)
        self.shown2 = c2
        if p2 > 0 then
            self:Place(self.tip2, p2)
            -- Schatten leicht vor der Spitze: wirkt, als liege die Runde oben auf
            self:Place(self.shadow, p2 + self.thickness * 0.18 / (TAU * self.radius))
            self.tip2:Show()
            self.shadow:Show()
        else
            self.tip2:Hide()
            self.shadow:Hide()
        end
    end
end

function Ring:SetValue(p, instant)
    p = math.max(0, p or 0)
    if self.lap2 then p = math.min(p, 1.999) else p = math.min(p, 1) end
    self.target = p
    if instant then
        self.display = p
        self:Draw(p)
    elseif not self.animating and self.display ~= p then
        self.animating = true
        self.frame:SetScript("OnUpdate", self.onUpdate)
    end
end

-- Von 0 aus neu hochlaufen lassen (beim Einblenden)
function Ring:Replay()
    self.display = 0
    self:Draw(0)
    self.animating = true
    self.frame:SetScript("OnUpdate", self.onUpdate)
end

function Ring:Flash()
    self.flash:Stop()
    self.flash:Play()
end
