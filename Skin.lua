-- ============================================================
-- Azeroth Activity Rings - Classic-Look
-- Dunkles Leder, Innenschatten, Seil-Rand und Messingnieten.
-- Dazu Text-Helfer, die nie über ihren Bereich hinausragen.
-- ============================================================

local _, ns = ...

local ROPE_TILE = 64 -- Länge einer Seil-Kachel bei 16 px Dicke

-- 12345 -> "12,3k" (für enge Anzeigen)
function ns.Short(n)
    n = n or 0
    if n >= 1000000 then return (string.format("%.1fM", n / 1000000):gsub("%.", ",")) end
    if n >= 10000 then return (string.format("%.1fk", n / 1000):gsub("%.", ",")) end
    return ns.Num(n)
end

-- Einzeilige Schrift mit fester Breite: zu langer Text wird mit "..." gekürzt
function ns.Text(parent, size, width, justify, r, g, b, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or ns.FONT, size, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    if width then fs:SetWidth(width) end
    return fs
end

function ns.Skin(frame, rope)
    rope = rope or 12
    local w, h = frame:GetSize()
    local half = rope * 0.5

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(ns.MEDIA .. "Leather", "REPEAT", "REPEAT")
    bg:SetPoint("TOPLEFT", half, -half)
    bg:SetPoint("BOTTOMRIGHT", -half, half)
    bg:SetTexCoord(0, (w - rope) / 128, 0, (h - rope) / 128)
    local vig = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    vig:SetTexture(ns.MEDIA .. "Vignette")
    vig:SetAllPoints(bg)

    local tile = ROPE_TILE * rope / 16
    local function Edge(file, a1, a2)
        local t = frame:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(ns.MEDIA .. file, "REPEAT", "REPEAT")
        t:SetPoint(a1)
        t:SetPoint(a2)
        return t
    end
    local top = Edge("RopeH", "TOPLEFT", "TOPRIGHT")
    top:SetHeight(rope)
    top:SetTexCoord(0, w / tile, 0, 1)
    local bottom = Edge("RopeH", "BOTTOMLEFT", "BOTTOMRIGHT")
    bottom:SetHeight(rope)
    bottom:SetTexCoord(0, w / tile, 0, 1)
    local left = Edge("RopeV", "TOPLEFT", "BOTTOMLEFT")
    left:SetWidth(rope)
    left:SetTexCoord(0, 1, 0, h / tile)
    local right = Edge("RopeV", "TOPRIGHT", "BOTTOMRIGHT")
    right:SetWidth(rope)
    right:SetTexCoord(0, 1, 0, h / tile)

    local stud = rope * 1.8
    for _, corner in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local t = frame:CreateTexture(nil, "BORDER", nil, 3)
        t:SetTexture(ns.MEDIA .. "Stud")
        t:SetSize(stud, stud)
        t:SetPoint("CENTER", frame, corner[1], corner[2] * half, corner[3] * half)
    end
end
