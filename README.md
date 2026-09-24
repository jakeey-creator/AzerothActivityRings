# Azeroth Activity Rings

Dein Abenteurer-Tracker für World of Warcraft Classic: ein Fitness-Tracker im Classic-Look (Seil-Rand, Messingnieten, Leder), der deine Aktivität im Spiel in drei Ringen anzeigt.

| Ring | Farbe | Tagesziel | Was zählt |
|---|---|---|---|
| **Pfadfinder** | Legendär-Orange | 10.000 Schritte | Zurückgelegte Strecke (0,8 Yards = 1 Schritt). Reiten zählt zu 25 %, Flugrouten gar nicht. |
| **Eiferer** | Episch-Lila | 30 Minuten | Aktive Zeit: Kampf, Plündern/Sammeln, Angeln. AFK zählt nicht. |
| **Abenteurer** | Selten-Blau | 10 | Abgegebene Quests und besiegte Bosse. |

## Features

- Animierte Ringe mit zweiter Runde über 100 %
- Uhr mit Puls (steigt beim Laufen und im Kampf), Uhrzeit, Sitzungsdauer und Gold
- 3 Zifferblätter: Voll, Daten, Minimal (Rechtsklick auf die Uhr)
- Serien für perfekte Tage in Folge
- 24 Auszeichnungen, einige davon täglich wiederholbar, dazu Titel nur im Add-on
- Erinnerung um :50, wenn du dich in der Stunde kaum bewegt hast; abends ein Hinweis, wie viele Schritte noch fehlen
- Detailfenster: Heute (Schritte pro Stunde), Woche, Erfolge, Optionen
- Fortschritt wird accountweit gespeichert

## Installation

1. Den Ordner `AzerothActivityRings` nach `World of Warcraft\_classic_era_\Interface\AddOns\` kopieren (bzw. in den Ordner deiner Spielversion).
2. WoW **komplett neu starten** (`/reload` reicht bei neuen Dateien nicht).

## Befehle

```
/aar                          Uhr ein-/ausblenden
/aar details                  Detailfenster
/aar ziel schritte 12000      Tagesziel setzen (auch: aktiv 45, quests 15)
/aar face voll/minimal/daten  Zifferblatt wechseln
/aar scale 1.2                Größe
/aar lock                     Uhr fixieren
/aar reset                    Position zurücksetzen
/aar sound                    Sounds an/aus
/aar erinnerung               Erinnerungen an/aus
/aar help                     Alle Befehle
```

Klick auf die Uhr öffnet die Details. Ziehen verschiebt sie, Shift + Mausrad ändert die Größe.

## Kompatibilität

Geschrieben für WoW Classic Era (1.15.x) und Classic Beta (1.60.x). Die TOC-Datei enthält außerdem Interface-Nummern für TBC, MoP Classic und Retail. Getestet wurde es bisher nur auf Classic Era und Classic Beta.
