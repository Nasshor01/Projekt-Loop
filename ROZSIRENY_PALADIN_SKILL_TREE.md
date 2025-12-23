# Rozšířený Paladin Skill Tree - Dokumentace

## ✅ Co bylo implementováno

### 1. Rozšíření stromu
- **Původní:** 13 uzlů
- **Nový:** **42 uzlů** (3x více!)
- **Struktura:**
  - TIER 1: 1 starter + 8 basic uzlů (3 defense, 3 offense, 2 utility)
  - TIER 2: 1 notable + 1 notable + 2 basic + 8 cluster uzlů (4 kolem každého notable)
  - TIER 3: 1 keystone + 1 notable + 2 basic + 8 cluster uzlů
  - TIER 4: 1 mastery + 3 notable
  - TIER 5: 1 keystone

### 2. Clustery (skupiny uzlů)
- **4 clustery** kolem notable/keystone uzlů:
  - **Fortress cluster** (Tier 2) - 4 basic uzly kolem "Pevnost"
  - **Divine Wrath cluster** (Tier 2) - 4 basic uzly kolem "Božský hněv"
  - **Sacred Thorns cluster** (Tier 3) - 4 basic uzly kolem "Svaté trny"
  - **Righteous Fury cluster** (Tier 3) - 4 basic uzly kolem "Spravedlivá zuřivost"

### 3. Vylepšený layout
- **Větší rozestupy:** TIER_SPACING_Y: 180px (z 150px)
- **Širší větve:** BRANCH_SPACING_X: 250px (z 200px)
- **Větší uzly:** NODE_SPACING: 100px (z 80px)
- **Clustery:** Uzly jsou pozicovány v kruhu kolem center uzlu (radius 120px)

### 4. Nové efekty
- **DRAW_CARD_FIRST_TURN** - Líznutí karty navíc v prvním kole
- **DOUBLE_HEALING** - Dvojnásobné léčení
- **BLOCK_ON_CARD_PLAY** - Blok za hraní karet
- **ADD_STARTING_GOLD** - Startovní zlato
- Kombinace efektů pro silnější uzly

### 5. Vylepšený vizuál
- **Větší uzly:**
  - BASIC: 36px (z 32px)
  - NOTABLE: 56px (z 48px)
  - KEYSTONE: 80px (z 64px)
  - MASTERY: 64px (z 56px)
  - STARTER: 50px (z 40px)

- **Barvy podle větví:**
  - Defense: Modrá (0.3, 0.5, 0.9)
  - Offense: Červená (0.9, 0.3, 0.3)
  - Utility: Zelená (0.5, 0.9, 0.5)
  - Main: Zlatá (0.9, 0.8, 0.3)

- **Vylepšené kreslení:**
  - Vnitřní výplň uzlů (průhlednost 20%)
  - Glow efekty pro odemčené uzly
  - Lepší rozlišení mezi typy uzlů

## 📊 Struktura rozšířeného stromu

```
TIER 5:
  [Avatar of Light] (KEYSTONE)

TIER 4:
  [Aura Mastery] (MASTERY) -- [Blessed Shield] (NOTABLE)
  [Unbreakable] (NOTABLE)    [Divine Retribution] (NOTABLE)

TIER 3:
  [Divine Protection] (KEYSTONE)
  [Sacred Thorns] (NOTABLE) + cluster (4 uzly)
  [Righteous Fury] (NOTABLE) + cluster (4 uzly)
  [Divine Healing] -- [Holy Presence]

TIER 2:
  [Fortress] (NOTABLE) + cluster (4 uzly)
  [Divine Wrath] (NOTABLE) + cluster (4 uzly)
  [Blessed Recovery] -- [Holy Aura]

TIER 1:
  [Starter] (STARTER)
  Defense: [Shield Training] [Vitality] [Iron Will]
  Offense: [Righteous Anger] [Swift Justice] [Holy Strike]
  Utility: [Blessed Gold] [Divine Favor]
```

## 🎨 Vizuální vylepšení

### Barvy větví
- **Defense (modrá):** Obranné schopnosti, blok, HP
- **Offense (červená):** Útočné schopnosti, poškození, krit
- **Utility (zelená):** Utility schopnosti, zlato, karty
- **Main (zlatá):** Hlavní cesta, aury, léčení

### Typy uzlů
- **BASIC:** Malé uzly (36px), barva podle větve
- **NOTABLE:** Střední uzly (56px), zlatá barva
- **KEYSTONE:** Velké uzly (80px), červená barva, osmiúhelník
- **MASTERY:** Střední uzly (64px), cyan barva, hvězda
- **STARTER:** Střední uzly (50px), zelená barva, diamant

## 🔗 Propojení

- **Více cest:** Několik způsobů, jak dosáhnout stejného cíle
- **Cross-branch:** Propojení mezi větvemi (např. všechny větve vedou k Aura Mastery)
- **Clustery:** Všechny cluster uzly jsou propojené se svým center uzlem

## 🧪 Jak otestovat

1. V editoru otevři `PassiveSkillTree.tscn`
2. Zaškrtni `Generate Paladin Tree`
3. Mělo by se zobrazit:
   - 42 uzlů místo 13
   - Clustery kolem notable uzlů
   - Větší rozestupy a lepší layout
   - Barvy podle větví

## 📝 Poznámky

- **Původní strom:** Zachován jako `generate_paladin_tree_old()` pro referenci
- **Nový strom:** `generate_paladin_tree_expanded()` - aktivní verze
- **Konfigurační systém:** Připraven pro budoucnost, ale zatím nepoužit kvůli omezením Godot

## 🚀 Další možné vylepšení

1. **Více clusterů** - přidat clustery i kolem dalších notable uzlů
2. **Bezier curves** - křivky místo přímek pro propojení
3. **Animace** - pulzování, rotace, efekty
4. **Pozadí** - gradient, dekorace, ornamenty
5. **Více efektů** - kombinace efektů, synergické bonusy

