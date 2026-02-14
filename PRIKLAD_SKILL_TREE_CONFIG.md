# Příklad Skill Tree Konfigurace

## Jak používat SkillTreeConfig

### Základní struktura

SkillTreeConfig umožňuje definovat skill tree pomocí datových struktur místo hardcodování. Každý skill tree se definuje v `.tres` souboru typu `SkillTreeConfig`.

### Příklad: Paladin Skill Tree

```gdscript
# Vytvoření konfigurace v editoru nebo kódu:
var config = SkillTreeConfig.new()
config.tree_id = "paladin_tree"
config.subclass_id = "paladin"
config.tree_name = "Paladin Skill Tree"

# Starter node
config.starter_node_id = "paladin_start"
config.starter_node_name = "Svatý Závazek"
config.starter_node_description = "Startovní bod Paladina. Zvýší maximální zdraví o 5."
config.starter_node_effects = [
	{"type": "ADD_MAX_HP", "value": 5}
]

# Tier 1 Nodes
config.tier_1_nodes = [
	{
		"id": "paladin_block_1",
		"name": "Výcvik se štítem",
		"description": "Začni každý souboj s 3 body bloku.",
		"node_type": "BASIC",
		"branch": "defense",
		"branch_position": 0,
		"effects": [
			{"type": "ADD_RETAINED_BLOCK", "value": 3}
		]
	},
	{
		"id": "paladin_hp_1",
		"name": "Vitalita",
		"description": "Zvýší maximální zdraví o 8.",
		"node_type": "BASIC",
		"branch": "defense",
		"branch_position": 1,
		"effects": [
			{"type": "ADD_MAX_HP", "value": 8}
		]
	},
	{
		"id": "righteous_anger",
		"name": "Spravedlivý hněv",
		"description": "Všechny karty způsobí o 1 poškození navíc.",
		"node_type": "BASIC",
		"branch": "offense",
		"branch_position": 0,
		"effects": [
			{"type": "ADD_CARD_DAMAGE", "value": 1}
		]
	},
	{
		"id": "swift_justice",
		"name": "Rychlá spravedlnost",
		"description": "Začni každý souboj s 1 extra energií.",
		"node_type": "BASIC",
		"branch": "offense",
		"branch_position": 1,
		"effects": [
			{"type": "ADD_MAX_ENERGY", "value": 1}
		]
	}
]

# Tier 2 Nodes
config.tier_2_nodes = [
	{
		"id": "fortress",
		"name": "Pevnost",
		"description": "Začni každý souboj s 8 body bloku.",
		"node_type": "NOTABLE",
		"branch": "defense",
		"branch_position": 0,
		"effects": [
			{"type": "ADD_RETAINED_BLOCK", "value": 8}
		]
	},
	{
		"id": "divine_wrath",
		"name": "Božský hněv",
		"description": "Útoky mají 20% šanci způsobit kritický zásah (2x poškození).",
		"node_type": "NOTABLE",
		"branch": "offense",
		"branch_position": 0,
		"effects": [
			{"type": "CRITICAL_CHANCE_BONUS", "value": 20}
		]
	},
	{
		"id": "blessed_recovery",
		"name": "Požehnaná obnova",
		"description": "Na konci každého tahu se vyléč za 2 HP.",
		"node_type": "BASIC",
		"branch": "main",
		"branch_position": 0,
		"effects": [
			{"type": "HEAL_END_OF_TURN", "value": 2}
		]
	}
]

# Tier 3 Nodes
config.tier_3_nodes = [
	{
		"id": "divine_protection",
		"name": "Božská ochrana",
		"description": "Jednou za souboj: když by měl umřít, místo toho se vyléč na 50% HP.",
		"node_type": "KEYSTONE",
		"branch": "defense",
		"branch_position": 0,
		"effects": [
			{"type": "GRANT_REVIVE", "value": 1}
		]
	},
	{
		"id": "sacred_thorns",
		"name": "Svaté trny",
		"description": "Když utrpíš poškození, útočník utrpí 3 poškození zpět.",
		"node_type": "NOTABLE",
		"branch": "defense",
		"branch_position": 1,
		"effects": [
			{"type": "THORNS_DAMAGE", "value": 3}
		]
	},
	{
		"id": "righteous_fury",
		"name": "Spravedlivá zuřivost",
		"description": "Získej 1 energii za každého zabitého nepřítele.",
		"node_type": "NOTABLE",
		"branch": "offense",
		"branch_position": 0,
		"effects": [
			{"type": "ENERGY_ON_KILL", "value": 1}
		]
	}
]

# Tier 4 Nodes
config.tier_4_nodes = [
	{
		"id": "aura_mastery",
		"name": "Mistrovství aur",
		"description": "Všechny aury jsou o 50% silnější.",
		"node_type": "MASTERY",
		"branch": "main",
		"branch_position": 0,
		"effects": [
			{"type": "AURA_ENHANCEMENT", "value": 50}
		]
	}
]

# Tier 5 Nodes
config.tier_5_nodes = [
	{
		"id": "avatar_of_light",
		"name": "Avatár světla",
		"description": "Na začátku souboje získej blok rovný 2x tvému maximálnímu zdraví.",
		"node_type": "KEYSTONE",
		"branch": "main",
		"branch_position": 0,
		"effects": [
			{"type": "AVATAR_STARTING_BLOCK", "value": 2}
		]
	}
]

# Propojení
config.connections = [
	{"from": "paladin_start", "to": "paladin_hp_1"},
	{"from": "paladin_start", "to": "righteous_anger"},
	{"from": "paladin_start", "to": "blessed_recovery"},
	{"from": "paladin_hp_1", "to": "paladin_block_1"},
	{"from": "paladin_hp_1", "to": "fortress"},
	{"from": "paladin_block_1", "to": "fortress"},
	{"from": "fortress", "to": "divine_protection"},
	{"from": "fortress", "to": "sacred_thorns"},
	{"from": "sacred_thorns", "to": "divine_protection"},
	{"from": "righteous_anger", "to": "swift_justice"},
	{"from": "righteous_anger", "to": "divine_wrath"},
	{"from": "swift_justice", "to": "divine_wrath"},
	{"from": "divine_wrath", "to": "righteous_fury"},
	{"from": "blessed_recovery", "to": "aura_mastery"},
	{"from": "divine_protection", "to": "aura_mastery"},
	{"from": "righteous_fury", "to": "aura_mastery"},
	{"from": "sacred_thorns", "to": "aura_mastery"},
	{"from": "aura_mastery", "to": "avatar_of_light"}
]

# Vizuální nastavení
config.branch_colors = {
	"defense": Color(0.3, 0.5, 0.9),  # Modrá
	"offense": Color(0.9, 0.3, 0.3),  # Červená
	"main": Color(0.9, 0.8, 0.3)      # Zlatá
}

# Generování stromu
var tree = SkillTreeGenerator.generate_tree_from_config(config)
```

---

## Příklad: Berserker Skill Tree (s clustery)

```gdscript
var config = SkillTreeConfig.new()
config.tree_id = "berserker_tree"
config.subclass_id = "berserker"

# Starter
config.starter_node_id = "berserker_start"
config.starter_node_name = "Krvavý Závazek"
config.starter_node_description = "Startovní bod Berserkra. Zvýší maximální zdraví o 5."
config.starter_node_effects = [
	{"type": "ADD_MAX_HP", "value": 5},
	{"type": "STARTING_RESOURCE", "value": 1, "string_value": "combo"}
]

# Tier 1
config.tier_1_nodes = [
	{
		"id": "victory_scars",
		"name": "Jizvy Vítězství",
		"description": "Zvyš maximální zdraví Berserkra o 15.",
		"node_type": "BASIC",
		"branch": "defense",
		"branch_position": 0,
		"effects": [
			{"type": "ADD_MAX_HP", "value": 15}
		]
	},
	{
		"id": "first_blood",
		"name": "První Krev",
		"description": "První útok, který v souboji provedeš, je zdarma.",
		"node_type": "BASIC",
		"branch": "offense",
		"branch_position": 0,
		"effects": [
			{"type": "FIRST_ATTACK_FREE", "value": 1}
		]
	}
]

# Tier 2 s clusterem
config.tier_2_nodes = [
	{
		"id": "enhanced_blood_fury",
		"name": "Vylepšená Krvavá Zuřivost",
		"description": "Pasivní schopnost Krvavá Zuřivost se nyní aktivuje za každých 8% chybějícího zdraví.",
		"node_type": "NOTABLE",
		"branch": "defense",
		"branch_position": 0,
		"effects": [
			{"type": "PASSIVE_TRIGGER_THRESHOLD", "value": 8, "string_value": "blood_fury"}
		]
	},
	# Basic uzly kolem notable (budou v clusteru)
	{
		"id": "blood_fury_basic_1",
		"name": "Divoký Vztek",
		"description": "+1 energie za každých 10% chybějícího HP.",
		"node_type": "BASIC",
		"branch": "defense",
		"branch_position": 1,
		"cluster_id": "enhanced_blood_fury",
		"cluster_position": 1,
		"effects": [
			{"type": "ENERGY_ON_KILL", "value": 1}  # Zjednodušený efekt
		]
	},
	{
		"id": "blood_fury_basic_2",
		"name": "Krvavá Touha",
		"description": "+2 poškození karet.",
		"node_type": "BASIC",
		"branch": "defense",
		"branch_position": 2,
		"cluster_id": "enhanced_blood_fury",
		"cluster_position": 2,
		"effects": [
			{"type": "ADD_CARD_DAMAGE", "value": 2}
		]
	}
]

# Cluster definice
config.clusters = [
	{
		"center_id": "enhanced_blood_fury",
		"basic_node_ids": ["blood_fury_basic_1", "blood_fury_basic_2"],
		"radius": 100.0
	}
]

# Propojení
config.connections = [
	{"from": "berserker_start", "to": "victory_scars"},
	{"from": "berserker_start", "to": "first_blood"},
	{"from": "victory_scars", "to": "enhanced_blood_fury"},
	{"from": "first_blood", "to": "enhanced_blood_fury"}
]

var tree = SkillTreeGenerator.generate_tree_from_config(config)
```

---

## Použití v editoru

1. Vytvoř nový Resource v Godot editoru
2. Vyber typ `SkillTreeConfig`
3. Vyplň všechna pole podle příkladu výše
4. Ulož jako `.tres` soubor (např. `paladin_tree_config.tres`)
5. Použij v kódu:

```gdscript
var config = load("res://data/skills/paladin_tree_config.tres")
var tree = SkillTreeGenerator.generate_tree_from_config(config)
```

---

## Výhody konfiguračního systému

1. **Žádné hardcodování** - všechny skill tree jsou v `.tres` souborech
2. **Snadné přidávání postav** - stačí vytvořit nový config soubor
3. **Vizuální editace** - lze upravovat v Godot editoru
4. **Verzování** - konfigurace jsou v souborech, lze je verzovat v Gitu
5. **Testování** - snadné vytváření testovacích stromů

---

## Poznámky

- **Efekty s string_value:** Některé efekty potřebují `string_value` (např. `CARD_UNLOCK`, `PASSIVE_ENHANCEMENT`)
- **Clustery:** Clustery se automaticky pozicují kolem center uzlu
- **Propojení:** Propojení jsou obousměrná - pokud A → B, automaticky se vytvoří i B → A (pokud je potřeba)
- **Validace:** Vždy zavolej `config.validate()` před generováním stromu
