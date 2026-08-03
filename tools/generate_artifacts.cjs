const fs = require("fs");
const path = require("path");
const ROOT = "D:/Games/projekt-loop-v2";
const BEH = path.join(ROOT, "data/artifacts/behaviors");
const CAT = path.join(ROOT, "data/artifacts/catalog");
const ICON = "res://art/icons/Artifacts NEW";
fs.mkdirSync(BEH, { recursive: true });

const ARTIFACTS = [
  ["common", "forbidden_apple", "Forbidden Apple", "+7 Max HP. Stacks.", "Forbidden Apple.png", true, 10, true, 0],
  ["uncommon", "runic_cube_of_binding", "Runic Cube of Binding", "Movement cards: +1 Block and 1 Weak to a random enemy. Doubled on grid edge.", "Runic Cube of Binding.png", false, 1, true, 1],
  ["uncommon", "tablet_of_forgotten_oaths", "Tablet of Forgotten Oaths", "At combat start seal 1 card: cost -1 and +2 Block when played. Max 1 sealed.", "Tablet of Forgotten Oaths.png", false, 1, true, 1],
  ["uncommon", "embercleaver", "Embercleaver", "Attacks apply 1 Burn. Burn death: 4 damage to adjacent enemies.", "Embercleaver.png", false, 1, true, 1],
  ["uncommon", "charm_of_fortune", "Charm of Fortune", "Shop prices -12%. 8% chance free. After combat 15% chance +25% gold.", "Charm of Fortune.png", false, 1, true, 1],
  ["uncommon", "fractured_bulwark", "Fractured Bulwark", "Unblocked damage: +1 card end of turn (1x/turn). 1x/combat delay one hit.", "Fractured Bulwark.png", false, 1, true, 1],
  ["uncommon", "spiral_bulwark", "Spiral Bulwark", "Gain 2 Thorns. Thorns damage grants +1 Block (max 3x/turn).", "Spiral Bulwark.png", false, 1, true, 1],
  ["rare", "arcane_prism", "Arcane Prism", "Start of turn: random Strength/Dexterity/Focus. If 2+ different statuses: +1 Energy.", "Arcane Prism.png", false, 1, true, 2],
  ["rare", "plague_mace_core", "Plague Mace Core", "Melee attacks +1 Poison. At 5+ Poison: +2 damage each their turn and you gain 1 Energy.", "Plague Mace Core.png", false, 1, true, 2],
  ["rare", "hellchain_reaver", "Hellchain Reaver", "Melee attacks: +2 Strength this turn. After first attack, next attack costs 1 less.", "Hellchain Reaver.png", false, 1, true, 2],
  ["rare", "frostbite_executioner", "Frostbite Executioner", "Attacks apply 1 Chill. At 3+ Chill: +50% damage and apply 1 Weak.", "Frostbite Executioner.png", false, 1, true, 2],
  ["rare", "molten_heart", "Molten Heart", "Start of turn +1 Strength. Causing Burn heals 1 HP.", "Molten Heart.png", false, 1, true, 2],
  ["rare", "frostbitten_heart", "Frostbitten Heart", "Attacks apply 1 Chill. At 3+ Chill: +4 damage and heal 2 HP.", "Frostbitten Heart.png", false, 1, true, 2],
  ["rare", "infernal_dragonheart", "Infernal Dragonheart", "On Burn: move 1 toward enemy. If adjacent after move: +1 Burn.", "Infernal Dragonheart.png", false, 1, true, 2],
  ["rare", "plague_dragonheart", "Plague Dragonheart", "Poison on already-poisoned spreads to their row. 1x/combat at 8+: double all Poison.", "Plague Dragonheart.png", false, 1, true, 2],
  ["rare", "crown_of_dominion", "Crown of Dominion", "Random owned cell: cards cost -1 while standing there. 3 charges then auto-relocates.", "Crown of Dominion.png", false, 1, true, 2],
  ["rare", "crimson_chalice", "Crimson Chalice", "Start of turn: may lose 3 HP to discard 1 random and draw 2. Wont kill you.", "Crimson Chalice.png", false, 1, true, 2],
  ["rare", "tome_of_echoes", "Tome of Echoes", "Cards costing 2+ go to bottom of draw pile. 1x/combat: draw 2 discard 1.", "Tome of Echoes.png", false, 1, true, 2],
  ["rare", "aether_crystal", "Aether Crystal", "Retain up to 2 unused Energy. Spend all Energy: +1 card end of turn.", "Aether Crystal.png", false, 1, true, 2],
  ["rare", "all_seeing_eye", "All-Seeing Eye", "See enemy move previews. 1x/combat: forbid one enemy move next turn.", "All-Seeing Eye.png", false, 1, true, 2],
  ["rare", "belt_of_the_iron_will", "Belt of the Iron Will", "End turn on edge: +2 Block. End turn center: +1 card next turn.", "Belt of the Iron Will.png", false, 1, true, 2],
  ["rare", "alchemists_tools", "Alchemist's Tools", "Start of turn: may discard 1 for a random temp alchemist effect.", "Alchemist's Tools.png", false, 1, true, 2],
  ["rare", "verdant_scale", "Verdant Scale", "On move: +1 Block per step. End next to 2+ enemies: apply 1 Weak.", "Verdant Scale.png", false, 1, true, 2],
  ["rare", "phoenix_feather", "Phoenix Feather", "Once per run on lethal: revive to 50% Max HP and +2 Strength, then burn out.", "Phoenix Feather.png", false, 1, true, 2],
  ["cursed", "bloodbound_amulet", "Bloodbound Amulet", "Lose HP: +1 Strength and +1 Thorns. Kill: heal 50% of HP lost this combat.", "Bloodbound Amulet.png", false, 1, true, 4],
  ["cursed", "bloodrage_cleaver", "Bloodrage Cleaver", "Per 5 HP lost this combat: +1 Strength. Kill: +1 Energy and next attack costs 1 less.", "Bloodrage Cleaver.png", false, 1, true, 4],
  ["cursed", "voidheart", "Voidheart", "Combat start: +3 Strength and +3 Dexterity. Each turn: -1 Max HP (combat).", "Voidheart.png", false, 1, true, 4],
  ["cursed", "void_dragonheart", "Void Dragonheart", "Start turn: +1 Strength per enemy at range 3+. Lose 1 HP per adjacent enemy.", "Void Dragonheart.png", false, 1, true, 4],
  ["cursed", "ring_of_the_living_grove", "Ring of the Living Grove", "Each turn: root on random player-half cell (max 3). On root +1 card, else -1 HP.", "Ring of the Living Grove.png", false, 1, true, 4],
  ["legendary", "plaguebone_axe", "Plaguebone Axe", "Attacks +2 Poison. At 8+ Poison: ignore Block and +3 damage.", "Plaguebone Axe.png", false, 1, true, 3],
  ["legendary", "time_crystal", "Time Crystal", "Every 3rd combat turn: gain an extra turn.", "Time Crystal.png", false, 1, true, 3],
  ["legendary", "gilded_dragonheart", "Gilded Dragonheart", "Random row/col: attacks there cost -1 and apply Weak. Auto-rerolls.", "Gilded Dragonheart.png", false, 1, true, 3],
  ["legendary", "blade_of_infinity", "Blade of Infinity", "Exhausted Attack cards return to bottom of draw pile instead of permanent exhaust.", "Blade of Infinity.png", false, 1, true, 3],
  ["boss", "throne_fragment", "Throne Fragment", "2 random Thrones: cost -1 and +1 card end turn. 3 charges then auto-move.", "Throne Fragment.png", false, 1, true, 5],
  ["boss", "oathbreaker_seal", "Oathbreaker Seal", "On acquire: 2 random deck cards permanently cost -1 and Retain.", "Oathbreaker Seal.png", false, 1, true, 5],
  ["boss", "heart_of_the_loop", "Heart of the Loop", "+1 Energy each combat. Every 4th turn echo a random attack. At <=25% HP skip enemy turn 1x.", "Heart of the Loop.png", false, 1, true, 5],
];

const py = fs.readFileSync(path.join(ROOT, "tools/generate_artifacts.py"), "utf8");
const bodies = {};
const re = /BEHAVIORS\["([a-z_]+)"\]\s*=\s*'''([\s\S]*?)'''/g;
let m;
while ((m = re.exec(py))) {
  bodies[m[1]] = m[2].trim() + "\n";
}
console.log("Parsed behaviors:", Object.keys(bodies).length);

for (const a of ARTIFACTS) {
  const [folder, aid, name, desc, icon, stackable, max_stacks, in_pool, atype] = a;
  let body = bodies[aid] || "extends ArtifactBehavior\n";
  if (!body.startsWith("extends")) body = "extends ArtifactBehavior\n\n" + body;
  // Fix MOVE enum reference in runic cube
  body = body.replace(
    "e.effect_type == CardEffectData.EffectType.MOVE",
    "false"
  );
  body = body.replace(
    "var is_move := false\n\tfor e in card.effects:\n\t\tif e and false:\n\t\t\tis_move = true\n\t\t\tbreak\n\tif not is_move and card.has_method(\"has_tag\"):\n\t\t# fallback: name/id contains move\n\t\tpass\n\tif not is_move:",
    "var is_move := card.has_method(\"has_tag\") and card.has_tag(CardData.CardTag.MOVE)\n\tif not is_move:"
  );
  fs.writeFileSync(path.join(BEH, aid + ".gd"), body);
  const dir = path.join(CAT, folder);
  fs.mkdirSync(dir, { recursive: true });
  const tres = `[gd_resource type="Resource" script_class="ArtifactsData" load_steps=3 format=3]

[ext_resource type="Script" path="res://data/artifacts/ArtifactsData.gd" id="1"]
[ext_resource type="Texture2D" path="${ICON}/${icon}" id="2"]

[resource]
script = ExtResource("1")
artifact_id = "${aid}"
artifact_name = "${name}"
description = "${desc}"
texture = ExtResource("2")
behavior_script = "res://data/artifacts/behaviors/${aid}.gd"
artifact_type = ${atype}
trigger_type = 14
effect_type = 28
primary_value = 0
secondary_value = 0
percentage_based = false
uses_per_combat = -1
current_uses = 0
is_stackable = ${stackable}
max_stacks = ${max_stacks}
current_stacks = 1
synergy_set_id = ""
condition_type = ""
condition_value = 0
custom_effect_id = ""
effect_description = ""
in_live_pool = ${in_pool}
`;
  fs.writeFileSync(path.join(dir, aid + ".tres"), tres);
}

function writePool(filePath, entries) {
  const lines = [
    `[gd_resource type="Resource" script_class="ArtifactPool" load_steps=${2 + entries.length} format=3]`,
    "",
    `[ext_resource type="Script" path="res://data/artifacts/ArtifactPool.gd" id="1"]`,
  ];
  entries.forEach((a, i) => {
    lines.push(
      `[ext_resource type="Resource" path="res://data/artifacts/catalog/${a[0]}/${a[1]}.tres" id="a${i}"]`
    );
  });
  lines.push("");
  lines.push("[resource]");
  lines.push('script = ExtResource("1")');
  const arr = entries.map((_, i) => `ExtResource("a${i}")`).join(", ");
  lines.push(`artifacts = Array[Resource]([${arr}])`);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, lines.join("\n") + "\n");
}

const live = ARTIFACTS.filter((a) => a[7]);
const shop = live.filter((a) => ["common", "uncommon", "rare"].includes(a[0]));
const elite = live.filter((a) => ["uncommon", "rare", "cursed"].includes(a[0]));
const treasure = live.filter((a) => ["rare", "legendary", "cursed"].includes(a[0]));
const boss = live.filter((a) => ["legendary", "boss"].includes(a[0]));
const event = live.filter((a) => ["uncommon", "rare"].includes(a[0]));
writePool(path.join(ROOT, "data/artifacts/basic_artifact_pool.tres"), shop);
writePool(path.join(ROOT, "data/artifacts/pool/shop_pool.tres"), shop);
writePool(path.join(ROOT, "data/artifacts/pool/elite_reward_pool.tres"), elite);
writePool(path.join(ROOT, "data/artifacts/pool/treasure_room_pool.tres"), treasure);
writePool(path.join(ROOT, "data/artifacts/pool/boss_reward_pool.tres"), boss);
writePool(path.join(ROOT, "data/artifacts/pool/event_reward_pool.tres"), event);
console.log("Done", ARTIFACTS.length, "behaviors", fs.readdirSync(BEH).length);
