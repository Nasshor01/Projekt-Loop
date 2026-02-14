# Nastavení Rozestupů Skill Tree

Tento dokument popisuje, kde a jak upravit rozestupy v skill tree.

## 📍 Hlavní soubor: `data/skills/SkillTreeGenerator.gd`

Na začátku souboru (řádky 6-12) najdeš všechny konstanty pro rozestupy:

```gdscript
# ===== NASTAVENÍ ROZESTUPŮ - ZMĚŇ TYTO HODNOTY PRO ÚPRAVU LAYOUTU =====
const TIER_SPACING_Y = 400.0  # Vzdálenost mezi tiery (vertikální rozestup)
const BRANCH_SPACING_X = 600.0  # Vzdálenost mezi větvemi (horizontální rozestup)
const NODE_SPACING = 250.0  # Vzdálenost mezi uzly ve stejném tieru
const CENTER_X = 1000.0  # Střed stromu (X pozice)
const STARTER_Y_OFFSET = -250.0  # Starter je výše nad tier 1
const NODE_OFFSET_IN_TIER = 80.0  # Horizontální offset pro více uzlů ve stejném tieru
```

## 📏 Popis konstant:

### `TIER_SPACING_Y = 400.0`
- **Co dělá:** Vzdálenost mezi jednotlivými tiery (vertikální rozestup)
- **Efekt:** Čím větší hodnota, tím více prostoru mezi tier 1, tier 2, tier 3, atd.
- **Doporučené hodnoty:** 300-600 (menší = kompaktnější, větší = více prostoru)

### `BRANCH_SPACING_X = 600.0`
- **Co dělá:** Vzdálenost mezi větvemi (Defense, Offense, Utility)
- **Efekt:** Čím větší hodnota, tím více prostoru mezi levou, střední a pravou větví
- **Doporučené hodnoty:** 400-800 (menší = užší, větší = širší)

### `NODE_SPACING = 250.0`
- **Co dělá:** Základní vzdálenost mezi uzly ve stejném tieru
- **Efekt:** Ovlivňuje rozestupy mezi uzly v horizontálním směru
- **Doporučené hodnoty:** 150-350

### `CENTER_X = 1000.0`
- **Co dělá:** X pozice středu celého skill tree
- **Efekt:** Posouvá celý strom doleva/doprava
- **Doporučené hodnoty:** 600-1500 (podle velikosti obrazovky)

### `STARTER_Y_OFFSET = -250.0`
- **Co dělá:** Y pozice starter node (záporná hodnota = výše)
- **Efekt:** Čím menší (zápornější) hodnota, tím výše je starter node
- **Doporučené hodnoty:** -150 až -400

### `NODE_OFFSET_IN_TIER = 80.0`
- **Co dělá:** Horizontální offset pro více uzlů ve stejném tieru
- **Efekt:** Když je v tieru více uzlů, tento offset určuje, jak daleko jsou od sebe
- **Doporučené hodnoty:** 50-120

## 🎨 Další úpravy v `scenes/ui/PassiveSkillTree.gd`

V souboru `PassiveSkillTree.gd` můžeš také upravit rozsah pomocných čar:

### Tier čáry (řádek ~146-147):
```gdscript
line.add_point(Vector2(-800, y))  # Rozšířeno doleva
line.add_point(Vector2(2800, y))  # Rozšířeno doprava
```

### Branch čáry (řádek ~164-165):
```gdscript
line.add_point(Vector2(x, -200))  # Začátek výš
line.add_point(Vector2(x, 2000))  # Konec níž
```

## 💡 Tipy pro úpravu:

1. **Začni s malými změnami:** Změň hodnoty o 50-100 a podívej se, jak to vypadá
2. **Testuj v editoru:** Použij `generate_paladin_tree` v editoru pro rychlý náhled
3. **Vyváženost:** Pokud zvýšíš `TIER_SPACING_Y`, možná budeš chtít zvýšit i `BRANCH_SPACING_X`
4. **Starter node:** Pokud je starter moc vysoko/nízko, uprav `STARTER_Y_OFFSET`

## 📊 Aktuální hodnoty (zvýšené pro větší rozestupy):

- `TIER_SPACING_Y`: 400.0 (bylo 300.0)
- `BRANCH_SPACING_X`: 600.0 (bylo 450.0)
- `NODE_SPACING`: 250.0 (bylo 180.0)
- `CENTER_X`: 1000.0 (bylo 800.0)
- `STARTER_Y_OFFSET`: -250.0 (bylo -200.0)
- `NODE_OFFSET_IN_TIER`: 80.0 (bylo 60.0)

---

**Poznámka:** Po změně hodnot v `SkillTreeGenerator.gd` musíš znovu vygenerovat skill tree v editoru, aby se změny projevily!
