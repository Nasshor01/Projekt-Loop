# Vesnice — stav a další plán

Po splitu v2 (sdílené vs budovy řad). Vesnice = výdejní základna, ne STS tavern mezi Acty.  
Související issues: #49 spatial hub · #48 per-hero budovy · #47 Tavern · #36 companion · #35 materiály · #37 Trapper.

---

## Teď v kódu (shipped)

Spatial hub: `VillageWorld` (plateau + kamera) + `VillageHUD` (CanvasLayer). Entry pořád `scenes/ui/VillageScene.tscn`.

| Budova | Typ | Stav | Efekt |
|--------|-----|------|--------|
| Market | sdílená | aktivní | zlato + shop relikvie (beze změny) |
| Library | sdílená | aktivní | karty / rarity (beze změny) |
| Well | sdílená | aktivní | **+2 HP heal na začátku bitvy / level** (max 5 → +10). **Ne** max HP |
| Chapel | řada Paladin | aktivní | HP / start block / karty / move — jen Paladin run |
| Hunter’s Lodge | řada Trapper | šedá ruina | lock text, dokud Trapper není v `unlocked_heroes` |
| Tavern | TBD | art + coming soon | nekrade Chapel, není rest mezi Acty |

**Chapel křivka** (hero level **a** střepy; cena `base_cost × (level + 1)`, base 12):

| Chapel | Min Paladin Lv | V příštím Paladin runu |
|--------|----------------|------------------------|
| 1 | 1 | +8 max HP + +2 start block |
| 2 | 3 | +2 block (celkem +4) + 1× Defend → Defend+ |
| 3 | 5 | +2 block (celkem +6) + Pious Defense do odměn a 1 kopie do startu |
| 4 | 8 | +2 block (celkem +8) + move 2 → 3 |
| 5 | 12 | +2 block (celkem +10) + +8 max HP + **slot na startovní relikvii (zatím prázdný)** |

Hero XP (`MetaProgress.hero_progress`) odemyká *právo* koupit schod; střepy ho zaplatí.

**Meta schema 2:** první spuštění tohoto buildu maže starý `meta_progress.res` + `current_run.sav`. Settings / jazyk / tutorial zůstávají. Důvod: starý Well = max HP a Chapel bez hero gate by dělaly bordel.

---

## Další plán (v tomto pořadí)

### 1. Spatial polish — zbytek #49
Hub MVP je venku. Ještě:
- doladit kameru / zoom, pokud playtest křičí
- lepší tooltip / detail panel
- Chapel L4–L5 art (teď clamp na chapel 3 sprite)
- Lodge po unlocku přestat šednout

Neblokuje Alphu, pokud hub jde klikat a upgradovat.

### 2. Tavern — #47 (malá, ne Chapel)
Taverna **nesmí** být STS rest mezi Acty a **nesmí** krást identitu Chapel (HP / block / move).

Kandidáti (vybrat jedno jako MVP):
- unlock další výdejní řady (Trapper gate → `unlock_hero("trapper")` + Lodge přestane být šedá)
- a/nebo companion unlock (#36)
- malý příděl / coming-soon sloty na budoucí řady

Persist přes `unlocked_heroes` / samostatný companion flag. Střepy stačí, dokud není #35.

### 3. Companion MVP — #36
Až má Tavern (nebo Chapel-adjacent slot) unlock:
- 1 companion v souboji, ally targeting na Paladin heal/buff
- bez rosteru, bez equipmentu

### 4. Materiály + desátek — #35 (0.4.5)
Až po tomto splitu. Jedna surovina, Loop Hero DNA:

| Moment | Podíl |
|--------|--------|
| Campfire / send home | 50 % |
| Smrt | 25 % |
| Boss leave | 100 % |
| Boss continue | 50 % odejde, zbytek v runu |

Camp/extraction **nepatří do Well**.  
Až materiály existují, drahé Chapel schody 4–5 můžou chtít **druhou surovinu navíc** ke střepům a hero levelu.

### 5. Lodge = zrcadlo Chapel — #48 + #37
Až je Trapper odemčený (#47 / #37):
- stejná váha jako Chapel: HP řady, karty, move, gated `hero_level("trapper")`
- **ne** globální Well HP
- šedá ruina jen do unlocku

### 6. Chapel L5 startovní relikvie
Rezervovaný slot už je v textu. Relikvii nevybírat, dokud není artefakt, který Paladinovi sedí a nezlomí early run.

---

## Pravidla, která se nemění

- Vesnice = správa výdeje. Vyslaná nositelka se sem nevrací.
- Uvnitř runu (Act 1→2→3) žádný návrat na základnu.
- Zlato = v runu. Střepy = meta základna.
- Market / Library křivky nešahat, dokud playtest neřekne jinak.
- Skill tree (#38) sem nepatří.

Kód: `scripts/data/VillageBonuses.gd`, `scripts/data/MetaProgress.gd`, `scripts/autoload/SaveManager.gd` (`META_SCHEMA_VERSION`), `scenes/village/`.
