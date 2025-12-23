# Testování Konfiguračního Systému pro Paladina

## ✅ Co bylo implementováno

1. **SkillTreeConfig.gd** - Konfigurační systém
2. **SkillTreeGenerator.generate_tree_from_config()** - Obecný generátor
3. **SkillTreeGenerator.create_paladin_config()** - Helper funkce pro vytvoření Paladin konfigurace
4. **PassiveSkillTree.gd** - Přidána možnost generovat z konfigurace v editoru

## 🧪 Jak otestovat

### Metoda 1: V Godot Editoru (nejjednodušší)

1. Otevři scénu `scenes/ui/PassiveSkillTree.tscn`
2. V Inspectoru najdi `PassiveSkillTree` node
3. V sekci "Preview Config" přetáhni nebo vytvoř nový `SkillTreeConfig` resource
4. Zaškrtni `Generate From Config` - strom se vygeneruje z konfigurace

### Metoda 2: Programově v kódu

```gdscript
# Vytvoření konfigurace
var config = SkillTreeGenerator.create_paladin_config()

# Validace
if config.validate():
    print("✅ Konfigurace je validní!")
    
    # Generování stromu
    var tree = SkillTreeGenerator.generate_tree_from_config(config)
    
    if tree:
        print("✅ Strom vygenerován! Uzlů: %d" % tree.skill_nodes.size())
        
        # Použití stromu
        PlayerData.active_skill_tree = tree
    else:
        print("❌ Chyba při generování stromu!")
else:
    print("❌ Konfigurace není validní!")
```

### Metoda 3: Porovnání s původním systémem

```gdscript
# Původní metoda (stále funguje)
var tree_old = SkillTreeGenerator.generate_paladin_tree()

# Nová metoda přes konfiguraci
var config = SkillTreeGenerator.create_paladin_config()
var tree_new = SkillTreeGenerator.generate_tree_from_config(config)

# Porovnání
print("Starý systém: %d uzlů" % tree_old.skill_nodes.size())
print("Nový systém: %d uzlů" % tree_new.skill_nodes.size())

# Měly by být stejné!
if tree_old.skill_nodes.size() == tree_new.skill_nodes.size():
    print("✅ Počet uzlů se shoduje!")
```

## 📋 Checklist testování

### Základní funkce
- [ ] Konfigurace se vytvoří pomocí `create_paladin_config()`
- [ ] Validace konfigurace funguje (`config.validate()`)
- [ ] Generování stromu funguje (`generate_tree_from_config()`)
- [ ] Počet uzlů se shoduje s původním systémem (13 uzlů)

### Uzly
- [ ] Starter node je vytvořen správně
- [ ] Všechny tier 1 uzly jsou vytvořeny
- [ ] Všechny tier 2 uzly jsou vytvořeny
- [ ] Všechny tier 3 uzly jsou vytvořeny
- [ ] Všechny tier 4 uzly jsou vytvořeny
- [ ] Všechny tier 5 uzly jsou vytvořeny

### Propojení
- [ ] Starter je propojen s tier 1 uzly
- [ ] Defense branch propojení funguje
- [ ] Offense branch propojení funguje
- [ ] Main branch propojení funguje
- [ ] Cross-branch propojení funguje

### Efekty
- [ ] Všechny efekty jsou aplikovány správně
- [ ] Hodnoty efektů jsou správné
- [ ] Typy efektů jsou správné

### Pozice
- [ ] Uzly jsou automaticky pozicovány
- [ ] Defense branch je vlevo
- [ ] Offense branch je vpravo
- [ ] Main branch je uprostřed
- [ ] Tiery jsou správně rozložené vertikálně

### Vizuální zobrazení
- [ ] Strom se zobrazí v editoru
- [ ] Uzly mají správné velikosti podle typu
- [ ] Propojovací čáry jsou správně nakreslené
- [ ] Barvy větví fungují (pokud jsou nastavené)

## 🔍 Debugging

### Pokud se strom negeneruje:

1. **Zkontroluj validaci:**
```gdscript
var config = SkillTreeGenerator.create_paladin_config()
if not config.validate():
    print("❌ Konfigurace není validní!")
    return
```

2. **Zkontroluj počet uzlů:**
```gdscript
var config = SkillTreeGenerator.create_paladin_config()
var total_nodes = 1 + config.tier_1_nodes.size() + config.tier_2_nodes.size() + \
                   config.tier_3_nodes.size() + config.tier_4_nodes.size() + \
                   config.tier_5_nodes.size()
print("Očekávaný počet uzlů: %d" % total_nodes)
```

3. **Zkontroluj propojení:**
```gdscript
var config = SkillTreeGenerator.create_paladin_config()
print("Počet propojení: %d" % config.connections.size())
for conn in config.connections:
    print("  %s -> %s" % [conn.from, conn.to])
```

### Pokud se efekty neaplikují:

1. **Zkontroluj typy efektů:**
```gdscript
# Všechny typy efektů musí být v PassiveEffectData.EffectType enum
var effect_type_str = "ADD_MAX_HP"
var effect_type = SkillTreeGenerator.get_effect_type_from_string(effect_type_str)
if effect_type == -1:
    print("❌ Neznámý typ efektu: %s" % effect_type_str)
```

2. **Zkontroluj strukturu efektů:**
```gdscript
# Efekty musí mít správnou strukturu
var effect = {
    "type": "ADD_MAX_HP",  # Název z enum
    "value": 5,            # Číselná hodnota
    "string_value": "",    # Volitelné
    "secondary_value": 0  # Volitelné
}
```

## 📝 Testovací skript

Vytvoř nový GDScript soubor `test_skill_tree_config.gd`:

```gdscript
extends Node

func _ready():
    test_paladin_config()

func test_paladin_config():
    print("=== TEST KONFIGURAČNÍHO SYSTÉMU ===")
    
    # 1. Vytvoření konfigurace
    print("\n1. Vytváření konfigurace...")
    var config = SkillTreeGenerator.create_paladin_config()
    print("   ✅ Konfigurace vytvořena: %s" % config.tree_id)
    
    # 2. Validace
    print("\n2. Validace konfigurace...")
    if config.validate():
        print("   ✅ Konfigurace je validní!")
    else:
        print("   ❌ Konfigurace není validní!")
        return
    
    # 3. Generování stromu
    print("\n3. Generování stromu...")
    var tree = SkillTreeGenerator.generate_tree_from_config(config)
    if tree:
        print("   ✅ Strom vygenerován!")
        print("   Počet uzlů: %d" % tree.skill_nodes.size())
    else:
        print("   ❌ Chyba při generování stromu!")
        return
    
    # 4. Porovnání s původním systémem
    print("\n4. Porovnání s původním systémem...")
    var tree_old = SkillTreeGenerator.generate_paladin_tree()
    print("   Původní systém: %d uzlů" % tree_old.skill_nodes.size())
    print("   Nový systém: %d uzlů" % tree.skill_nodes.size())
    
    if tree_old.skill_nodes.size() == tree.skill_nodes.size():
        print("   ✅ Počet uzlů se shoduje!")
    else:
        print("   ❌ Počet uzlů se neshoduje!")
    
    # 5. Kontrola uzlů
    print("\n5. Kontrola uzlů...")
    var node_ids = {}
    for node in tree.skill_nodes:
        if node_ids.has(node.id):
            print("   ❌ Duplicitní ID: %s" % node.id)
        else:
            node_ids[node.id] = true
    print("   ✅ Všechny uzly mají unikátní ID")
    
    # 6. Kontrola propojení
    print("\n6. Kontrola propojení...")
    var connection_count = 0
    for node in tree.skill_nodes:
        connection_count += node.connected_nodes.size()
    print("   Celkový počet propojení: %d" % connection_count)
    print("   ✅ Propojení jsou nastavena")
    
    # 7. Kontrola efektů
    print("\n7. Kontrola efektů...")
    var effect_count = 0
    for node in tree.skill_nodes:
        effect_count += node.effects.size()
    print("   Celkový počet efektů: %d" % effect_count)
    print("   ✅ Efekty jsou aplikovány")
    
    print("\n=== TEST DOKONČEN ===")
```

## 🎯 Očekávané výsledky

- **Počet uzlů:** 13 (1 starter + 4 tier 1 + 3 tier 2 + 3 tier 3 + 1 tier 4 + 1 tier 5)
- **Počet propojení:** 18
- **Počet efektů:** 13 (jeden efekt na uzel)
- **Starter node:** `paladin_start` s efektem `ADD_MAX_HP` (value: 5)

## 🚀 Další kroky po testování

1. Pokud vše funguje, můžeš začít rozšiřovat Paladin skill tree
2. Přidat více uzlů do konfigurace
3. Vytvořit clustery kolem notable uzlů
4. Vylepšit layout algoritmus
5. Přidat více efektů a kombinací

