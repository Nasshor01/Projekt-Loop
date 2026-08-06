# Projekt LOOP — Pre-Alpha 0.3.8

Deck-building roguelike (inspirovaný *Slay the Spire*) s taktickým bojem na mřížce.  
**Stav:** Pre-Alpha — očekávej bugy. Doporučená třída: **Paladin**.

---

## Co udělat po stažení ZIP

1. **Rozbal** celý ZIP do jedné složky (např. `Desktop\Projekt_LOOP`).
2. **Nespouštěj** hru přímo z ZIP / z prohlížeče — vždy z rozbalené složky.
3. Ve složce musí zůstat pohromadě:
   - `Projekt_LOOP_v0.3.8.exe` (nebo podobný název)
   - soubor `.pck` / data vedle exe
   - případné `.dll` od Godotu
4. Spusť **`.exe`**.
5. Windows SmartScreen / antivirus může varovat u nepodepsaných buildů → *Další informace* → *Přesto spustit* (pokud build máš ode mě / z Discordu).
6. Pokud hra nejde: zkontroluj, že jsi nerozbalil jen exe bez zbytku souborů.

**Systém:** Windows 64-bit.  
**Rozlišení:** hra běží v 16:9 (projekt 1920×1080).

---

## Ovládání

### Obecně / mapa
| Akce | Ovládání |
|------|----------|
| Výběr uzlu na mapě | **Levé tlačítko myši** |
| Deck / Menu | Tlačítka nahoře v Global UI |
| Tooltip artefaktu | **Najet myší** na ikonu |
| Zpět / zavřít overlay | **Esc** |

### Souboj
| Akce | Ovládání |
|------|----------|
| Pohyb kamery | **WASD** / šipky |
| Otáčení kamery | **Q** / **E** |
| Zoom | **Kolečko myši** |
| Posun kamery | **Prostřední tlačítko** + tah |
| Zahrát kartu | **Táhni** kartu z ruky na cíl / pole, nebo výběr + klik |
| Zrušit výběr / drag | **Esc** nebo **pravé tlačítko** (podle situace) |
| Detail karty (tooltip) | **Pravé tlačítko** na kartu |
| Pohyb jednotky | Klik na hráče → klik na zelené pole |
| Konec tahu | Tlačítko **End Turn** / Ukončit tah |
| Draw / Discard pile | Klik na balíčky vpravo |

### Obchod / odměny / eventy
| Akce | Ovládání |
|------|----------|
| Koupit / vybrat | **Levé tlačítko** |
| Rychlý popis karty | **Najet myší** (hover tip) |
| Detailnější tooltip karty | **Pravé tlačítko** (kde je k dispozici) |

### Debug (jen vývojové / F5 buildy)
| Akce | Ovládání |
|------|----------|
| Dev konzole | **Shift + Esc** |

---

## Krátký tip ke hře

1. Vyber **Paladina** → start runu.  
2. Na mapě jdi po cestě: souboje → odměny → obchod / event / rest.  
3. V souboji sleduj **iniciativu** nahoře (pořadí tahů).  
4. Karty stojí **energii** (orb nahoře na kartě). Blok se drží mezi tahy podle pravidel postavy/artefaktů.

---

## Feedback

Bug / nápad → Discord / feedback ve hře (Menu), ideálně se **seedem** z mapy a krátkým popisem co jsi dělal.

Díky za playtest!
