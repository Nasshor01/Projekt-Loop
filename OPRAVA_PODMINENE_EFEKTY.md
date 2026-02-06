# Oprava podmíněných efektů v kartách

## ✅ Co bylo opraveno

### 1. Podpora podmíněných efektů v automatickém generátoru popisů
- **Přidána podpora pro všechny typy podmínek:**
  - `target_health_above_percent` - pokud má cíl více než X% HP
  - `target_health_below_percent` - pokud má cíl méně než X% HP
  - `health_above_percent` - pokud máš ty více než X% HP
  - `health_below_percent` - pokud máš ty méně než X% HP
  - `block_above` - pokud máš více než X bloku
  - `block_below` - pokud máš méně než X bloku
  - `target_has_debuff` - pokud má cíl debuff
  - `damage_per_block` - za každý blok +1 poškození (speciální případ)
  - `took_damage_last_turn` - pokud jsi utrpěl poškození minulý tah

### 2. Formátování podmíněných efektů
Podmíněné efekty se nyní zobrazují stručně a jasně:

**Příklad: Divine Justice**
```
20 svatého dmg
Pokud >50% HP: +15 dmg
```

**Příklad: Massive Healing**
```
+20 HP
Pokud máš <30% HP: +30 HP
```

**Příklad: Holy Vengeance**
```
6 svatého dmg
Za každý blok: +1
```

### 3. Typy podmíněných efektů

#### Poškození (DEAL_DAMAGE)
- Podmíněný bonus se přidává k základní hodnotě
- Formát: `Pokud [podmínka]: +[hodnota] dmg`

#### Blok (GAIN_BLOCK)
- Podmíněný bonus se přidává k základní hodnotě
- Formát: `Pokud [podmínka]: +[hodnota] blok`

#### Léčení (HEAL_UNIT)
- Může buď přidávat bonus nebo nahrazovat celou hodnotu
- Pokud `conditional_bonus_value >= value`, nahrazuje celou hodnotu
- Formát: `Pokud [podmínka]: +[hodnota] HP`

## 📋 Jak to funguje

1. **Detekce podmínek:** Funkce `generate_compact_description()` kontroluje každý efekt, jestli má `has_condition = true`
2. **Formátování:** Pokud má podmínku, použije se `_format_conditional_effect()` pro vytvoření stručného popisu
3. **Zobrazení:** Podmíněný efekt se zobrazí na novém řádku pod základním efektem

## 🎯 Výsledek

- ✅ Podmíněné efekty jsou nyní viditelné na kartách
- ✅ Stručný a jasný formát
- ✅ Podpora všech typů podmínek
- ✅ Správné zobrazení pro poškození, blok i léčení

## 🧪 Testování

Doporučuji otestovat tyto karty:
- [ ] `divine_justice` - podmíněné poškození při >50% HP cíle
- [ ] `massive_healing` - podmíněné léčení při <30% HP
- [ ] `holy_vengeance` - poškození za každý blok
- [ ] `holy_wrath` - bonus poškození při >15 bloku
- [ ] `gods_wrath` - bonus poškození pokud má cíl debuff
- [ ] `holy_shield` - bonus bloku při <50% HP

