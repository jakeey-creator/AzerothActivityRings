# Patch Notes

## 1.2.1: Keine Lua-Fehler mehr in Bosskämpfen

- **Behoben:** In Bosskämpfen kam dauerhaft der Fehler *„attempt to perform boolean test on a secret boolean value“*. Neuere Clients geben dort Werte wie Kampfstatus, AFK, Tod, Tempo, Leben und Kampflog als „geheim“ heraus, und Add-ons dürfen sie nicht prüfen. Alle Abfragen laufen jetzt über sichere Helfer mit Ersatzwerten.
- **Verbessert:** Die Kampfzeit (Eiferer-Ring) zählt auch in Bosskämpfen weiter. Als Ersatz dient die Kampfsperre der Oberfläche.
- **Verbessert:** Bosse werden über `ENCOUNTER_END` oder `BOSS_KILL` erkannt und pro Kill nur einmal gezählt.

## 1.2.0: Fortschritt geht nicht mehr verloren

- **Behoben:** Auf manchen Clients (z. B. Classic Beta 1.60) war der Fortschritt nach jedem Neustart weg. Der Client lud die gespeicherten Daten nicht wieder ein.
- **Neu:** Der Fortschritt wird doppelt gespeichert, accountweit und zusätzlich pro Charakter. Beim Start wird zusammengeführt, was geladen wurde, ohne dass etwas doppelt zählt.
- **Neu:** Beim Login zeigt der Chat, welche Speicher geladen wurden und wie viele Schritte insgesamt drin sind.
- **Neu:** Befehl `/aar status` zeigt, ob der Speicher richtig verbunden ist.
- **Neu:** `Rescue.lua` bietet Platz für eine einmalige Datenrettung (normalerweise leer).

## 1.1.1: Laden der gespeicherten Daten

- **Behoben:** Das Add-on startet jetzt erst, wenn WoW die gespeicherten Daten geladen hat (`ADDON_LOADED`), und nicht schon beim Login.
- **Neu:** Kommen gespeicherte Daten erst später an, werden sie nachträglich übernommen.

## 1.1.0: Classic-Design

- **Neu:** Eckiges Gehäuse mit gedrehtem Seil als Rand, Messingnieten und dunklem Leder
- **Neu:** Messing-Zifferblatt hinter den Ringen und Schrift Friz Quadrata
- **Neu:** Ringfarben nach Item-Qualität: Legendär-Orange, Episch-Lila, Selten-Blau
- **Neu:** Detailfenster und Einblendungen im gleichen Classic-Look
- **Behoben:** Zahlen und Texte laufen nicht mehr über den Rand. Alle Texte haben feste Breiten, große Zahlen werden abgekürzt (z. B. 12,3k).
- Unterstützung für Classic Beta (Interface 16001)

## 1.0.0: Erste Version

- Drei Ringe: Pfadfinder (10.000 Schritte), Eiferer (30 Min. aktiv), Abenteurer (10 Quests/Bosse)
- Uhr mit Puls, Uhrzeit, Sitzungsdauer und Gold; 3 Zifferblätter
- Serien, 24 Auszeichnungen und Titel nur im Add-on
- Erinnerungen, Tagesbilanz, Detailfenster (Heute, Woche, Erfolge, Optionen)
