# Card upgrade matrix — Early Alpha (#27)

**Rules:** [`.cursor/rules/card-upgrade-balance.mdc`](../.cursor/rules/card-upgrade-balance.mdc)  
**Scope:** Paladin + everyone cards available in a Paladin run (shop / reward / starter). Trapper = out of scope.  
**Status:** Design locked for implementation. Do **not** invent numbers outside this file.

Legend:

- **OK** — keep current `*_upgraded.tres` as-is  
- **REBALANCE** — change existing upgraded `.tres` to Target  
- **NEW** — create missing `*_upgraded.tres` + link from base  

---

## Locked AOE caps (anti-turret)

| Card | Forbidden | Locked target |
|------|-----------|---------------|
| **Consecration+** | 5×5 (current) | **10 holy @ 3×3**, cost 2, `PLAYER_CENTERED_AOE` |
| **Purging Burst+** | 4×4 @ 1 dmg (current) | **7 holy @ 2×2**, cost 1 (same footprint as base) |
| Any new AOE+ | 5×5 ever; 4×4 only as rare exception with sharply lower dmg | Prefer same footprint +`+2` dmg |

---

## Everyone (starter / pool)

| Card | Base | Current + | Target + | Action |
|------|------|-----------|----------|--------|
| Defend | 5 block @ 1E | 5 block @ **0E** | same | **OK** (cost −1) |
| Quick Strike | 5 dmg @ 1E | 6 dmg @ 1E | same | **OK** |
| Heavy Strike | 10 dmg @ 2E | 10 dmg + Vulnerable 1 @ 2E | same | **OK** (setup) |
| Fortify | 10 block @ 2E | 20 block + Exhaust @ 2E | **14 block @ 2E, no Exhaust** | **REBALANCE** |
| Adrenaline | +1E + end-draw 1 @ 0E | +2E + end-draw 1 @ 0E | same | **OK** (one benefit: +1E) |
| Regroup | Draw 1 @ 0E | Draw 2 @ 0E | same | **OK** |
| Nimble Move | Move 1, Draw 1 @ **0E** | Move 2, Draw 2 @ **1E** | **Move 2, Draw 1 @ 0E** | **REBALANCE** (no cost↑; one benefit: +1 move) |
| Quick Step | Initiative +5 @ 1E | *(none)* | Initiative **+8** @ 1E | **NEW** |

---

## Paladin — existing upgrades

| Card | Base | Current + | Target + | Action |
|------|------|-----------|----------|--------|
| Smite | 6 holy @ 1E | 10 @ **2E** | **9 holy @ 1E** | **REBALANCE** (no cost↑) |
| Holy Strike | 6 holy @ 1E | *(none)* | **8 holy @ 1E** | **NEW** |
| Pious Defense | 5 block @ 1E | 6 @ 1E | **8 block @ 1E** | **REBALANCE** |
| Lesser Heal | 4 HP @ 1E | 6 HP @ **0E** | same | **OK** |
| Consecration | 8 @ 3×3, 2E | 8 @ **5×5**, 2E | **10 @ 3×3, 2E** | **REBALANCE** (locked) |
| Holy Wave | 8 row @ 2E | 10 row @ 2E | same | **OK** |
| Light Pillar | 8 column @ 2E | 10 column @ 2E | same | **OK** |
| Purging Burst | 5 @ 2×2, 1E | 1 @ **4×4**, 1E | **7 @ 2×2, 1E** | **REBALANCE** (locked) |
| Divine Wrath | 8 @ 3×3 Exhaust @ 3E | 12 “all” @ **4E** Exhaust | **10 @ 3×3 Exhaust @ 3E** | **REBALANCE** (no full-board, no cost↑) |
| Shield Bash | dmg = block (max 15) @ 2E | double (max 20) @ 2E | same | **OK** (one benefit: double) |
| Lay on Hands | Full heal Exhaust, uses 2 @ 3E | Full heal Exhaust @ **5E** | Full heal Exhaust, uses **3**, @ **3E** | **REBALANCE** (no cost↑; +1 use) |
| Aura of Devotion | +1 block/turn @ 1E | +2 permanent @ **2E** | **+2 block/turn @ 1E** (not permanent, no cost↑) | **REBALANCE** |

---

## Paladin — missing upgrades (NEW)

One primary benefit each. Numbers are the **upgraded** card.

### Melee / single-target

| Card | Base | Target + |
|------|------|----------|
| Excommunication | 6 dmg + Vulnerable 2 @ 2E | **8 dmg** + Vulnerable 2 @ 2E |
| God's Wrath | 10 dmg; +4 if debuff @ 2E | **12 dmg**; +4 if debuff @ 2E |
| God's Lightning | 10 dmg; +1E on kill @ 2E | **12 dmg**; +1E on kill @ 2E |
| Holy Wrath | 8 dmg; +4 if block>15 @ 2E | **10 dmg**; +4 if block>15 @ 2E |
| Holy Vengeance | 5 +1/block @ 1E | **6 +1/block @ 1E** (base bump only; scaling unchanged) |
| Consecrated Weapon | 4 dmg + next holy +5 @ 2E | **4 dmg + next holy +7 @ 2E** (buff bump) |
| Shield Strike | 4 block + 5 dmg @ 1E | **4 block + 7 dmg @ 1E** |
| Holy Defense | 10 block + 5 holy @ 2E | **10 block + 7 holy @ 2E** |
| Holy Knight | 6 block + 6 dmg + 4 heal @ 2E | **6 block + 8 dmg + 4 heal @ 2E** |
| Divine Justice | 14; +8 if >50% HP; Exhaust @ 3E | **16**; +8 if >50% HP; Exhaust @ 3E |

### Block / tank

| Card | Base | Target + |
|------|------|----------|
| Consecrated Barrier | 5 block; +3 if damaged last turn @ 1E | **7 block**; +3 if damaged last turn @ 1E |
| Defensive Stance | 4 block + next hit 50% @ 1E | **6 block** + next hit 50% @ 1E |
| Holy Armor | 5 block; +2 if block>20 @ 1E | **7 block**; +2 if block>20 @ 1E |
| Holy Shield | 10 block; +5 if <50% HP @ 2E | **12 block**; +5 if <50% HP @ 2E |
| Fortification | 10 retain block @ 2E | **13 retain block @ 2E** |
| Protective Aura | 3 self + 1 allies @ 1E | **5 self + 1 allies @ 1E** |
| Protective Hand | 8 block + 5 heal @ 2E | **10 block + 5 heal @ 2E** |
| Impregnable Shield | 10 block + cleanse @ 2E | **12 block + cleanse @ 2E** |
| Purification | cleanse + 4 block @ 1E | cleanse + **6 block @ 1E** |
| Unbreakable Faith | block = current HP; Exhaust @ 3E | block = current HP; Exhaust @ **2E** (cost −1) |

### Heal / support

| Card | Base | Target + |
|------|------|----------|
| Healing Light | 8 HP @ 1E | **10 HP @ 1E** |
| Healing Aura | 8 self + 3 allies @ 2E | **10 self + 3 allies @ 2E** |
| Holy Blessing | 8 heal + 3 block @ 2E | **10 heal + 3 block @ 2E** |
| Sacred Healing | 12 heal + cleanse @ 2E | **14 heal + cleanse @ 2E** |
| Regeneration | Regen 2 for 3 turns @ 1E | Regen **3** for 3 turns @ 1E |
| Massive Healing | 15 (20 if <30% HP); remove after use @ 2E | **18** (20 if <30% HP); same remove @ 2E |
| Divine Grace | Full heal Exhaust @ 3E | Full heal Exhaust @ **2E** |

### Large package / Exhaust (keep Exhaust; modest bump; no full-board expand)

| Card | Base | Target + | Notes |
|------|------|----------|--------|
| Divine Judgment | 15 “all”; Exhaust @ 3E | **18**; Exhaust @ 3E | Keep existing targeting; do **not** widen footprint |
| Divine Protection | 12 block + 8 heal + 8 aoe; Exhaust @ 3E | **12 block + 8 heal + 10 aoe**; Exhaust @ 3E | Only dmg line +2; keep Exhaust |

---

## Implementation order (after matrix approval)

1. REBALANCE rows (Consecration+, Purging Burst+, Smite+, Divine Wrath+, Lay on Hands+, Aura+, Pious Defense+, Fortify+, Nimble Move+).  
2. NEW everyone: Quick Step+.  
3. NEW Paladin missing list (batch by archetype).  
4. `translations.csv` EN/CS for every `card.*.+` / `card.*.+.desc`.  
5. Smoke: Rest upgrade list includes every non-upgraded run card; no card without `upgraded_version`.

## Explicitly out of scope

- Trapper upgrades (#37 later)  
- Per-card unique artwork  
- Changing base (non-+) card numbers except where needed to keep + coherent  

## Done when (#27)

- [x] Rule + this matrix committed  
- [x] All REBALANCE applied in `.tres`  
- [x] All NEW created + linked  
- [x] Rest / smith: no upgradeable card without target (49/49 Paladin+everyone run cards linked)  
- [x] Visual: green `Name+` only (existing CardUI)
