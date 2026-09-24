-- ============================================================
-- Azeroth Activity Rings - Auszeichnungen
-- daily = kann an jedem Tag einmal verdient werden (mit Zähler)
-- title = Titel, der im Add-on angezeigt wird (höchster Rang gewinnt)
-- ============================================================

local _, ns = ...

local MARATHON_YARDS = 42195 / 0.9144

local function P(d, key) return ns.Progress(d, key) end

local function ClosedHour(d, key)
    return d.closed[key] and tonumber(date("%H", d.closed[key]))
end

ns.MEDALS = {
    -- Tägliche Auszeichnungen
    { id = "perfect_day", daily = true, icon = "Spell_Holy_HolyBolt",
      name = "Perfekter Tag", desc = "Schließe alle drei Ringe an einem Tag.",
      test = function(d) return d.perfect end },
    { id = "move_200", daily = true, icon = "Ability_Mount_JungleTiger",
      name = "Doppelter Pfad", desc = "Erreiche 200 % deines Pfadfinder-Ziels.",
      test = function(d) return P(d, "move") >= 2 end },
    { id = "move_300", daily = true, icon = "Spell_Nature_Swiftness", rank = 3, title = "Rastloser Wanderer",
      name = "Dreifacher Pfad", desc = "Erreiche 300 % deines Pfadfinder-Ziels.",
      test = function(d) return P(d, "move") >= 3 end },
    { id = "active_200", daily = true, icon = "Ability_Warrior_BattleShout",
      name = "Unermüdlich", desc = "Erreiche 200 % deines Eiferer-Ziels.",
      test = function(d) return P(d, "active") >= 2 end },
    { id = "quest_200", daily = true, icon = "INV_Misc_Book_09",
      name = "Questmaschine", desc = "Erreiche 200 % deines Abenteurer-Ziels.",
      test = function(d) return P(d, "quest") >= 2 end },
    { id = "marathon", daily = true, icon = "Ability_Rogue_Sprint", rank = 6, title = "Marathonläufer",
      name = "Marathon", desc = "Lege an einem Tag 42,195 km zu Fuß zurück.",
      test = function(d) return d.footYards >= MARATHON_YARDS end },
    { id = "early_bird", daily = true, icon = "INV_Misc_PocketWatch_01", rank = 1, title = "Frühaufsteher",
      name = "Frühaufsteher", desc = "Schließe den Pfadfinder-Ring vor 9 Uhr.",
      test = function(d) local h = ClosedHour(d, "move"); return h and h < 9 end },
    { id = "night_owl", daily = true, icon = "Spell_Shadow_Twilight", rank = 1, title = "Nachteule",
      name = "Nachteule", desc = "Schließe einen Ring zwischen 0 und 4 Uhr.",
      test = function(d)
          for _, r in ipairs(ns.RINGS) do
              local h = ClosedHour(d, r.key)
              if h and h < 4 then return true end
          end
      end },
    { id = "all_hours", daily = true, icon = "Spell_Nature_TimeStop", rank = 4, title = "Der Unermüdliche",
      name = "Rund um die Uhr", desc = "12 aktive Stunden an einem Tag (je 250+ Schritte).",
      test = function(d) return ns.ActiveHours(d) >= 12 end },
    { id = "level_perfect", daily = true, icon = "Spell_Holy_PowerInfusion",
      name = "Aufstieg in Form", desc = "Steige auf und schließe am selben Tag alle Ringe.",
      test = function(d) return d.perfect and d.levels > 0 end },
    { id = "weekend", daily = true, icon = "Ability_Warrior_Challange", rank = 2, title = "Wochenendkrieger",
      name = "Wochenendkrieger", desc = "Perfekter Samstag und perfekter Sonntag.",
      test = function(d)
          if not d.perfect or date("%w", d.perfect - ns.db.settings.resetHour * 3600) ~= "0" then return end
          local sat = ns.db.days[ns.KeyOffset(1)]
          return sat and sat.perfect
      end },
    { id = "comeback", daily = true, icon = "Spell_Holy_Resurrection",
      name = "Comeback", desc = "Perfekter Tag nach mindestens 3 Tagen ohne geschlossenen Ring.",
      test = function(d)
          if not d.perfect or time() - ns.db.created < 4 * 86400 then return end
          for i = 1, 3 do
              local p = ns.db.days[ns.KeyOffset(i)]
              if p and next(p.closed) then return end
          end
          return true
      end },

    -- Einmalige Meilensteine
    { id = "first_ring", icon = "INV_Jewelry_Ring_03",
      name = "Erster Ring", desc = "Schließe zum ersten Mal einen Ring.",
      test = function() return ns.db.totals.rings >= 1 end },
    { id = "week_streak", icon = "Spell_Holy_SealOfMight", rank = 5, title = "Eiserner Wille",
      name = "Perfekte Woche", desc = "7 perfekte Tage in Folge.",
      test = function() return ns.db.streak.current >= 7 end },
    { id = "month_streak", icon = "INV_Misc_Head_Dragon_01", rank = 9, title = "Legende von Azeroth",
      name = "Perfekter Monat", desc = "30 perfekte Tage in Folge.",
      test = function() return ns.db.streak.current >= 30 end },
    { id = "rings_100", icon = "INV_Jewelry_Ring_04", rank = 4, title = "Ringsammler",
      name = "Ringsammler", desc = "Schließe insgesamt 100 Ringe.",
      test = function() return ns.db.totals.rings >= 100 end },
    { id = "steps_100k", icon = "Ability_Tracking",
      name = "100.000 Schritte", desc = "Gehe insgesamt 100.000 Schritte.",
      test = function() return ns.db.totals.steps >= 100000 end },
    { id = "steps_1m", icon = "Ability_Hunter_Pathfinding", rank = 8, title = "Azeroths Marathonläufer",
      name = "Eine Million", desc = "Gehe insgesamt 1.000.000 Schritte.",
      test = function() return ns.db.totals.steps >= 1000000 end },
    { id = "km_100", icon = "INV_Misc_Map_01", rank = 5, title = "Weltenbummler",
      name = "Weltenbummler", desc = "Lege insgesamt 100 km zu Fuß zurück.",
      test = function() return ns.db.totals.footYards >= 100000 / 0.9144 end },
    { id = "active_24h", icon = "Spell_Nature_BloodLust", rank = 6, title = "Farmkönig",
      name = "Farmkönig", desc = "Insgesamt 24 Stunden aktiv (Eiferer).",
      test = function() return ns.db.totals.active >= 24 * 3600 end },
    { id = "quests_100", icon = "INV_Scroll_03", rank = 3, title = "Held des Volkes",
      name = "Held des Volkes", desc = "Gib insgesamt 100 Quests ab.",
      test = function() return ns.db.totals.quests >= 100 end },
    { id = "quests_1000", icon = "INV_Misc_Book_11", rank = 7, title = "Chronist Azeroths",
      name = "Chronist", desc = "Gib insgesamt 1.000 Quests ab.",
      test = function() return ns.db.totals.quests >= 1000 end },
    { id = "bosses_25", icon = "INV_Misc_Bone_HumanSkull_01", rank = 5, title = "Bossbezwinger",
      name = "Bossbezwinger", desc = "Besiege insgesamt 25 Dungeon- oder Raidbosse.",
      test = function() return ns.db.totals.bosses >= 25 end },
    { id = "kills_1000", icon = "Ability_Warrior_Cleave", rank = 4, title = "Schlächter",
      name = "Schlächter", desc = "Lande insgesamt 1.000 Todesstöße.",
      test = function() return ns.db.totals.kills >= 1000 end },
}

function ns.CheckMedals(d)
    local db = ns.db
    for _, m in ipairs(ns.MEDALS) do
        local rec = db.medals[m.id]
        local open
        if m.daily then open = not d.medals[m.id] else open = not rec end
        if open and m.test(d) then
            rec = rec or { count = 0, first = time() }
            rec.count = rec.count + 1
            rec.last = time()
            db.medals[m.id] = rec
            if m.daily then d.medals[m.id] = true end
            ns:Fire("Medal", m, rec)
        end
    end
end

function ns.CurrentTitle()
    local best, bestRank
    for _, m in ipairs(ns.MEDALS) do
        if m.title and ns.db.medals[m.id] and (m.rank or 0) > (bestRank or -1) then
            best, bestRank = m.title, m.rank or 0
        end
    end
    return best
end
