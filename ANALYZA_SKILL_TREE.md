# Analýza Passive Skill Tree Systému

## 📊 Současný stav

### ✅ Co funguje dobře:
1. **Čistá architektura** - SubclassData → PassiveSkillTreeData → PassiveSkillNode
2. **Flexibilní systém efektů** - PassiveEffectData podporuje různé typy efektů
3. **Typy uzlů** - BASIC, NOTABLE, KEYSTONE, MASTERY, STARTER
4. **Tier systém** - 5 úrovní obtížnosti
5. **Automatické pozicování** - podle tieru a branch

### ❌ Hlavní problémy:

#### 1. **Hardcoded generátor pro Paladina**
```gdscript
// SkillTreeGenerator.gd - generate_paladin_tree()
// Pro každou novou postavu bys musel vytvořit novou funkci
// generate_rogue_tree(), generate_mage_tree(), atd.
```

**Problém:** Není škálovatelné pro více postav.

#### 2. **Příliš malý strom (13 uzlů)**
- Path of Exile má stovky uzlů
- Tvůj strom má jen 13 uzlů
- Chybí větvení a alternativní cesty
- Lineární progrese místo komplexního stromu

#### 3. **Jednoduchý layout algoritmus**
```gdscript
// auto_position_nodes() - jen jednoduché rozložení podle tieru a branch
// Chybí:
// - Cluster nodes (skupiny malých uzlů kolem větších)
// - Křivky a organické tvary
// - Vizuální hierarchie
// - Více cest k stejnému cíli
```

#### 4. **Chybí vizuální "majestátnost"**
- Všechny uzly jsou stejně velké (kromě typu)
- Chybí gradienty, efekty, animace
- Propojovací čáry jsou jednoduché
- Chybí pozadí nebo dekorativní prvky

#### 5. **Problém s více postavami**
- Každá postava potřebuje vlastní `.tres` soubor
- Generátor je specifický pro Paladina
- Chybí obecný systém pro vytváření stromů

---

## 🎯 Návrhy na zlepšení

### 1. **Refaktorovat generátor na obecný systém**

**Návrh:** Vytvořit konfigurační systém pro skill tree

```gdscript
// SkillTreeConfig.gd - nový resource
class_name SkillTreeConfig
extends Resource

@export var tree_id: String
@export var starter_node: Dictionary  # {id, name, description, effects}
@export var node_groups: Array[Dictionary]  # Skupiny uzlů pro každý tier
@export var connections: Array[Dictionary]  # Propojení mezi uzly
@export var clusters: Array[Dictionary]  # Cluster definice

// SkillTreeGenerator.gd - obecná funkce
static func generate_tree_from_config(config: SkillTreeConfig) -> PassiveSkillTreeData
```

**Výhody:**
- Jedna funkce pro všechny postavy
- Konfigurace v `.tres` souborech
- Snadné přidávání nových postav

### 2. **Vytvořit větší, komplexnější strom**

**Cíle:**
- **50-100 uzlů** místo 13
- **Více větvení** - 3-4 hlavní větve
- **Cluster nodes** - skupiny malých uzlů kolem větších
- **Alternativní cesty** - více způsobů, jak dosáhnout stejného cíle
- **Cross-branch propojení** - uzly propojující různé větve

**Struktura navrženého stromu:**
```
TIER 1 (Startovní):
  - STARTER (1 uzel)
  - BASIC nodes (8-10 uzlů) - 3-4 v každé větvi

TIER 2 (Specializace):
  - NOTABLE nodes (6-8 uzlů)
  - BASIC nodes (10-12 uzlů) - cluster kolem notable

TIER 3 (Pokročilé):
  - KEYSTONE nodes (2-3 uzly)
  - NOTABLE nodes (8-10 uzlů)
  - BASIC nodes (15-20 uzlů) - clustery

TIER 4 (Mistrovství):
  - MASTERY nodes (3-4 uzly)
  - NOTABLE nodes (6-8 uzlů)
  - Cross-branch propojení

TIER 5 (Ultimátní):
  - KEYSTONE nodes (1-2 uzly)
  - Finální build-defining uzly
```

### 3. **Vylepšit layout algoritmus**

**Návrh:** Více sofistikovaný algoritmus

```gdscript
// Nový algoritmus:
1. Umísti STARTER uzel do středu
2. Vytvoř hlavní větve (defense, offense, utility) - radiálně od středu
3. Pro každý tier:
   a. Umísti NOTABLE/KEYSTONE uzly na hlavní větve
   b. Vytvoř clustery BASIC uzlů kolem notable
   c. Přidej cross-branch propojení
4. Optimalizuj pozice pro minimalizaci překrývání
5. Vytvoř křivky pro propojovací čáry (Bezier curves)
```

**Vizuální vylepšení:**
- **Gradient pozadí** - tmavší směrem k okrajům
- **Dekorativní prvky** - ornamenty, symboly
- **Animace** - pulzující uzly, svítící propojení
- **Efekty** - glow, stíny, partikly

### 4. **Přidat cluster systém**

**Cluster nodes** - skupiny malých BASIC uzlů kolem většího NOTABLE/KEYSTONE uzlu

```gdscript
// PassiveSkillNode.gd - přidat:
@export var cluster_id: String = ""  # ID clusteru, do kterého patří
@export var cluster_position: int = 0  # Pozice v clusteru (0 = střed)

// SkillTreeGenerator.gd - nová funkce:
static func create_cluster(center_node: PassiveSkillNode, 
						   basic_nodes: Array[PassiveSkillNode],
						   radius: float = 100.0)
```

**Vizuálně:**
- Střední uzel (NOTABLE) větší
- 4-6 malých BASIC uzlů kolem něj v kruhu
- Všechny propojené se středem

### 5. **Vylepšit vizuální design**

**Návrhy:**
- **Větší rozlišení velikostí:**
  - BASIC: 32px
  - NOTABLE: 56px
  - KEYSTONE: 80px
  - MASTERY: 64px
  - STARTER: 72px

- **Barvy podle větve:**
  - Defense: Modrá/Modrošedá
  - Offense: Červená/Červeno-oranžová
  - Utility: Zelená/Zeleno-žlutá
  - Main: Zlatá/Bílá

- **Efekty:**
  - Glow pro odemčené uzly
  - Pulzování pro dostupné uzly
  - Stíny pro hloubku
  - Partikly pro KEYSTONE uzly

- **Propojovací čáry:**
  - Bezier curves místo přímek
  - Tloušťka podle tieru
  - Animace pro aktivní cesty

### 6. **Přidat více efektů a kombinací**

**Nové efekty:**
- Synergie mezi uzly
- Conditional efekty (aktivní pouze pokud máš jiný uzel)
- Scaling efekty (silnější s více uzly v branchi)
- Unique mechaniky pro každou postavu

---

## 🛠️ Implementační plán

### Fáze 1: Refaktorování (1-2 dny)
1. Vytvořit `SkillTreeConfig.gd`
2. Refaktorovat `SkillTreeGenerator` na obecný systém
3. Převést Paladin tree na konfiguraci

### Fáze 2: Rozšíření stromu (2-3 dny)
1. Navrhnout nový větší strom (50+ uzlů)
2. Implementovat cluster systém
3. Přidat více větvení a cross-branch propojení

### Fáze 3: Vylepšení layoutu (2-3 dny)
1. Nový layout algoritmus
2. Bezier curves pro propojení
3. Optimalizace pozic

### Fáze 4: Vizuální vylepšení (2-3 dny)
1. Větší rozlišení velikostí
2. Barvy podle větví
3. Efekty a animace
4. Pozadí a dekorace

### Fáze 5: Testování a optimalizace (1-2 dny)
1. Test s více postavami
2. Performance optimalizace
3. UX testování

---

## 💡 Konkrétní příklady

### Příklad: Cluster node
```
	  [B]     [B]
		\   /
		 [N]  <- Notable (střed)
		/   \
	  [B]     [B]
```

### Příklad: Větvení
```
TIER 1: [S] (Starter)
		 |
	+----+----+
	|    |    |
TIER 2: [D] [O] [U]  (Defense, Offense, Utility)
	|    |    |
	+----+----+
		 |
TIER 3: [K] (Keystone - vyžaduje uzly ze všech větví)
```

### Příklad: Cross-branch propojení
```
Defense branch:  [D1] -- [D2] -- [D3]
					  \       /
					   \     /
						[CB]  <- Cross-branch node
					   /     \
					  /       \
Offense branch:  [O1] -- [O2] -- [O3]
```

---

## 🎨 Vizuální reference

**Path of Exile inspirace:**
- Velký, komplexní strom
- Cluster nodes kolem notable
- Více cest k stejnému cíli
- Vizuální hierarchie (velikost, barva, efekty)
- Organické tvary a křivky

**Tvůj cíl:**
- Podobně majestátní, ale menší (50-100 uzlů místo 1000+)
- Zachovat přehlednost
- Unikátní vizuální styl pro tvou hru

---

## 📝 Závěr

**Hlavní body:**
1. ✅ Architektura je dobrá, ale generátor je příliš specifický
2. ✅ Strom je příliš malý - potřebuje 3-4x více uzlů
3. ✅ Layout je jednoduchý - potřebuje cluster systém a lepší algoritmus
4. ✅ Vizuální design je základní - potřebuje více efektů a hierarchie

**Doporučení:**
- Začít s refaktoringem generátoru (Fáze 1)
- Pak rozšířit strom (Fáze 2)
- Nakonec vylepšit vizuál (Fáze 4)

**Priorita:** Vysoká - systém je funkční, ale není škálovatelný a vizuálně není dostatečně působivý.
