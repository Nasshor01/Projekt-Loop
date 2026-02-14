# Plán Implementace Skill Tree Systému pro Všechny Postavy

## 📊 Analýza požadavků

### Přehled postav:
- **Tank (3):** Paladin ✅, Berserker, Ochránce
- **Fighter (2):** Mistr Zbraní, Duelant
- **Mág (3):** Elementalista, Alchymista, Nekromant
- **Assassin (3):** Stínový Vrah, Trapper, Vrah Duší

**Celkem: 11 podtříd, každá potřebuje unikátní skill tree**

### Typy efektů v plánu (co chybí v PassiveEffectData):

#### ✅ Už existuje:
- ADD_MAX_HP
- ADD_MAX_ENERGY
- ADD_RETAINED_BLOCK
- ADD_CARD_DAMAGE
- CRITICAL_CHANCE_BONUS
- HEAL_END_OF_TURN
- ENERGY_ON_KILL
- THORNS_DAMAGE

#### ❌ Chybí (potřebujeme přidat):
1. **CARD_UNLOCK** - Odemknout kartu do poolu odměn
2. **PASSIVE_ENHANCEMENT** - Vylepšení pasivní schopnosti (např. Aura Oddanosti +1 blok)
3. **DRAW_CARD_FIRST_TURN** - Líznutí karty navíc v prvním kole
4. **STARTING_RESOURCE** - Začátek souboje s resource (kombo body, essence, lektvary)
5. **CONDITIONAL_DRAW** - Líznutí karty za podmínky (např. <50% HP)
6. **CONDITIONAL_BLOCK** - Blok za podmínky (např. pokud nemáš blok)
7. **TARGET_BONUS_DAMAGE** - Bonusové poškození proti označenému cíli
8. **CARD_COST_REDUCTION_TARGET** - Snížení ceny karty proti cíli
9. **POSTURE_BONUS** - Bonus v určitém postoji (obranný/útočný)
10. **POSTURE_COST_REDUCTION** - Snížení ceny přepnutí postoje
11. **SPELL_BLOCK** - Blok za sešlání kouzla
12. **PASSIVE_RESONANCE_BONUS** - Bonus k pasivní rezonanci
13. **POISON_DAMAGE_BONUS** - Bonus k jedům
14. **PASSIVE_USE_COUNT** - Počet použití pasivní schopnosti za kolo
15. **SUMMON_HEALTH_BONUS** - Bonus HP pro vyvolané jednotky
16. **STARTING_TRAP** - Začátek souboje s pastí
17. **HAND_SIZE_BONUS** - Větší ruka
18. **LIFESTEAL_PERCENTAGE** - Procentuální lifesteal
19. **OVERHEAL_TO_TEMP_HP** - Přebytečné léčení → dočasné HP
20. **ALLIED_DAMAGE_LIFESTEAL** - Lifesteal z poškození spojenců
21. **FIRST_ATTACK_FREE** - První útok zdarma
22. **PASSIVE_TRIGGER_THRESHOLD** - Změna prahu aktivace pasivní schopnosti
23. **STARTING_TEMP_HP** - Začátek s dočasným HP
24. **ALLIED_DEFENSE_BONUS** - Bonus k obraně spojenců
25. **FORCE_ENEMY_MOVEMENT** - Donutit nepřátele k pohybu
26. **FIRST_SPELL_ELEMENT_FREE** - První kouzlo každého živlu zdarma
27. **STARTING_POTIONS** - Začátek s lektvary
28. **ENEMY_TO_CARD_CONVERSION** - Převod zabitých nepřátel na karty

---

## 🎯 Implementační plán

### Fáze 1: Rozšíření PassiveEffectData (PRIORITA VYSOKÁ)

**Úkol:** Přidat všechny chybějící typy efektů do `PassiveEffectData.gd`

**Kategorie efektů:**
1. **Card Management:**
   - CARD_UNLOCK
   - DRAW_CARD_FIRST_TURN
   - CONDITIONAL_DRAW
   - HAND_SIZE_BONUS

2. **Resource Management:**
   - STARTING_RESOURCE (kombo body, essence, lektvary)
   - STARTING_TRAP
   - STARTING_POTIONS

3. **Combat Bonuses:**
   - TARGET_BONUS_DAMAGE
   - CARD_COST_REDUCTION_TARGET
   - FIRST_ATTACK_FREE
   - SPELL_BLOCK

4. **Passive Enhancements:**
   - PASSIVE_ENHANCEMENT (obecný systém)
   - PASSIVE_RESONANCE_BONUS
   - PASSIVE_USE_COUNT
   - PASSIVE_TRIGGER_THRESHOLD

5. **Posture System (Fighter):**
   - POSTURE_BONUS
   - POSTURE_COST_REDUCTION

6. **DoT/Status:**
   - POISON_DAMAGE_BONUS

7. **Summoning (Nekromant):**
   - SUMMON_HEALTH_BONUS
   - ENEMY_TO_CARD_CONVERSION

8. **Lifesteal (Vrah Duší):**
   - LIFESTEAL_PERCENTAGE
   - OVERHEAL_TO_TEMP_HP
   - ALLIED_DAMAGE_LIFESTEAL

9. **Conditional Effects:**
   - CONDITIONAL_BLOCK
   - STARTING_TEMP_HP

10. **Support (Ochránce):**
	- ALLIED_DEFENSE_BONUS
	- FORCE_ENEMY_MOVEMENT

11. **Elemental (Elementalista):**
	- FIRST_SPELL_ELEMENT_FREE

---

### Fáze 2: Konfigurační systém pro Skill Tree

**Nový soubor:** `SkillTreeConfig.gd`

```gdscript
class_name SkillTreeConfig
extends Resource

# Identifikace
@export var tree_id: String = ""
@export var subclass_id: String = ""

# Starter node
@export var starter_node: Dictionary = {}

# Node groups (skupiny uzlů pro každý tier)
@export var tier_1_nodes: Array[Dictionary] = []
@export var tier_2_nodes: Array[Dictionary] = []
@export var tier_3_nodes: Array[Dictionary] = []
@export var tier_4_nodes: Array[Dictionary] = []
@export var tier_5_nodes: Array[Dictionary] = []

# Propojení mezi uzly
@export var connections: Array[Dictionary] = []

# Cluster definice (skupiny malých uzlů kolem větších)
@export var clusters: Array[Dictionary] = []

# Vizuální nastavení
@export var branch_colors: Dictionary = {}  # {"defense": Color.BLUE, ...}
@export var tree_theme: String = "default"  # Pro různé vizuální styly
```

**Struktura node dictionary:**
```gdscript
{
	"id": "berserker_victory_scars",
	"name": "Jizvy Vítězství",
	"description": "Zvyš maximální zdraví Berserkra o 15.",
	"tier": 1,
	"node_type": "BASIC",  # BASIC, NOTABLE, KEYSTONE, MASTERY, STARTER
	"branch": "defense",  # defense, offense, utility, main
	"cost": 1,
	"effects": [
		{"type": "ADD_MAX_HP", "value": 15}
	],
	"prerequisites": [],  # ID uzlů, které musí být odemčeny
	"cluster_id": "",  # Pokud patří do clusteru
	"cluster_position": 0  # Pozice v clusteru (0 = střed)
}
```

---

### Fáze 3: Obecný generátor

**Refaktorovat:** `SkillTreeGenerator.gd`

**Nová struktura:**
```gdscript
class_name SkillTreeGenerator
extends RefCounted

# Obecná funkce pro generování z konfigurace
static func generate_tree_from_config(config: SkillTreeConfig) -> PassiveSkillTreeData

# Pomocné funkce
static func create_node_from_dict(node_dict: Dictionary) -> PassiveSkillNode
static func setup_connections_from_config(tree: PassiveSkillTreeData, config: SkillTreeConfig)
static func create_clusters(tree: PassiveSkillTreeData, config: SkillTreeConfig)
static func auto_position_nodes(tree: PassiveSkillTreeData, config: SkillTreeConfig)

# Specifické generátory (pro zpětnou kompatibilitu)
static func generate_paladin_tree() -> PassiveSkillTreeData
static func generate_berserker_tree() -> PassiveSkillTreeData
# ... atd.
```

---

### Fáze 4: Rozšíření stromů

**Aktuální stav:** Paladin má 13 uzlů

**Cíl:** Každá postava má 30-50 uzlů s:
- Více větvení
- Cluster nodes
- Alternativní cesty
- Cross-branch propojení

**Struktura rozšířeného stromu:**
```
TIER 1 (5-8 uzlů):
  - STARTER (1)
  - BASIC nodes (4-7) - rozložené do větví

TIER 2 (8-12 uzlů):
  - NOTABLE nodes (2-3)
  - BASIC nodes (6-9) - clustery kolem notable

TIER 3 (10-15 uzlů):
  - KEYSTONE nodes (1-2)
  - NOTABLE nodes (3-4)
  - BASIC nodes (6-9) - clustery

TIER 4 (6-10 uzlů):
  - MASTERY nodes (1-2)
  - NOTABLE nodes (2-3)
  - Cross-branch propojení

TIER 5 (2-4 uzly):
  - KEYSTONE nodes (1-2)
  - Finální build-defining uzly
```

---

### Fáze 5: Vylepšení layoutu a vizuálu

**Layout algoritmus:**
1. Radiální rozložení od středu (starter)
2. Hlavní větve se rozbíhají do stran
3. Cluster nodes kolem notable/keystone
4. Bezier curves pro propojení
5. Optimalizace pozic

**Vizuální vylepšení:**
- Barvy podle větví
- Větší rozlišení velikostí
- Efekty a animace
- Pozadí a dekorace

---

## 📝 Konkrétní příklad: Berserker Skill Tree

### Struktura (5 skillů z plánu → rozšířeno na 35 uzlů):

**TIER 1 (Starter + 6 BASIC):**
1. STARTER: "Krvavý Závazek" - +5 HP, začátek s 1 kombo bodem
2. BASIC: "Jizvy Vítězství" - +15 HP
3. BASIC: "První Krev" - První útok zdarma
4. BASIC: "Divoký Vztek" - +1 energie za každých 10% chybějícího HP
5. BASIC: "Krvavá Touha" - +2 poškození karet
6. BASIC: "Nezlomná Vůle" - +3 startovní blok
7. BASIC: "Berserkerské Srdce" - +1 max energie

**TIER 2 (2 NOTABLE + 8 BASIC v clusterech):**
8. NOTABLE: "Vylepšená Krvavá Zuřivost" - Aktivace každých 8% HP
9. NOTABLE: "Krvavý Hlad" - +5 poškození, -2 HP za útok
10-17. BASIC cluster kolem každého notable (4 uzly každý)

**TIER 3 (1 KEYSTONE + 3 NOTABLE + 10 BASIC):**
18. KEYSTONE: "Nezastavitelný Vztek" - Líznutí karty při <50% HP
19. NOTABLE: "Poslední Vzepětí" - +50% poškození při <25% HP
20. NOTABLE: "Krvavá Oběť" - Můžeš zaplatit HP místo energie
21. NOTABLE: "Bezhlavý Útok" - Kritický zásah při <30% HP
22-31. BASIC nodes (clustery a propojení)

**TIER 4 (1 MASTERY + 2 NOTABLE + 6 BASIC):**
32. MASTERY: "Do Bitvy!" - Odemknout kartu
33. NOTABLE: "Krvavý Rituál" - Začátek s 2 kombo body
34. NOTABLE: "Nekonečný Vztek" - Energie za zabití
35-40. BASIC nodes

**TIER 5 (1 KEYSTONE):**
41. KEYSTONE: "Berserkerská Zuřivost" - Finální schopnost

---

## 🚀 Priorita implementace

1. **✅ Fáze 1** - Rozšíření PassiveEffectData (KRITICKÉ)
2. **✅ Fáze 2** - Konfigurační systém
3. **✅ Fáze 3** - Obecný generátor
4. **⏳ Fáze 4** - Rozšíření stromů (postupně pro každou postavu)
5. **⏳ Fáze 5** - Vizuální vylepšení

---

## 💡 Další poznámky

- **Škálovatelnost:** Konfigurační systém umožní snadné přidávání nových postav
- **Flexibilita:** Každá postava může mít jiný počet uzlů a strukturu
- **Vizuální rozlišení:** Barvy a efekty podle třídy/postavy
- **Balancování:** Snadné úpravy hodnot v konfiguraci
