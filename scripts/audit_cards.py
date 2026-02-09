#!/usr/bin/env python3
"""Audit all CardData .tres files and output a Markdown table + Top 5 analysis."""
import os
import re
from pathlib import Path

# Paths relative to project root
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CARDS_DIR = PROJECT_ROOT / "data" / "cards"
TRANSLATIONS_CSV = PROJECT_ROOT / "translations.csv"
OUTPUT_MD = PROJECT_ROOT / "docs" / "CARD_AUDIT.md"

# Enums from CardData.gd / CardEffectData.gd
RARITY_NAMES = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "BASIC"]
EFFECT_RANGE_NAMES = ["NONE", "SELF", "MELEE", "RANGED_FIXED", "RANGED_LINE", "GRID_AOE", "FULL_BOARD"]
TARGET_NAMES = ["SELF", "SELECTED_ENEMY", "SELECTED_ALLY", "ALL_ENEMIES", "ALL_ALLIES", "EMPTY_CELL", "ANY_CELL"]
AOE_NAMES = ["SINGLE", "ROW", "COLUMN", "SQUARE_X_Y", "ALL_ON_GRID"]
DAMAGE_TYPE_NAMES = ["Normal", "Holy", "Fire", "Ice", "Lightning", "Poison", "Arcane"]
EFFECT_TYPE_NAMES = [
    "DEAL_DAMAGE", "DEAL_DAMAGE_FROM_BLOCK", "GAIN_BLOCK", "DRAW_CARDS", "GAIN_ENERGY",
    "APPLY_STATUS", "SUMMON_UNIT", "HEAL_UNIT", "HEAL_TO_FULL", "EXHAUST",
    "GAIN_EXTRA_MOVE", "DEAL_DOUBLE_DAMAGE_FROM_BLOCK", "MODIFY_INITIATIVE_NEXT_ROUND"
]


def load_translations():
    """Load card name translations: key -> English (column 2)."""
    trans = {}
    if not TRANSLATIONS_CSV.exists():
        return trans
    with open(TRANSLATIONS_CSV, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("keys,"):
                continue
            parts = line.split(",", 2)
            if len(parts) >= 2:
                key = parts[0].strip('"')
                en = parts[1].strip('"')
                if key.startswith("card.") and ".desc" not in key and key != "card.description.placeholder" and key != "card.name.placeholder":
                    if "card.effect." in key or "card.condition." in key or "card.rarity." in key or "card.target." in key or "card.tooltip." in key:
                        continue
                    trans[key] = en
    return trans


def parse_tres_file(filepath: Path) -> dict | None:
    """Parse a single .tres file. Returns dict with card info or None if not CardData."""
    text = filepath.read_text(encoding="utf-8")
    if "script_class=\"CardData\"" not in text and "CardData.gd" not in text:
        return None
    # Skip pool files
    if "CardPool" in text and "script_class" in text:
        return None

    data = {}
    # Card-level
    m = re.search(r'card_id\s*=\s*"([^"]*)"', text)
    data["card_id"] = m.group(1) if m else ""
    m = re.search(r'card_name\s*=\s*"([^"]*)"', text)
    data["card_name_key"] = m.group(1) if m else ""
    m = re.search(r'cost\s*=\s*(\d+)', text)
    data["cost"] = int(m.group(1)) if m else 0
    m = re.search(r'rarity\s*=\s*(\d+)', text)
    data["rarity"] = int(m.group(1)) if m else 0
    m = re.search(r'range_type\s*=\s*(\d+)', text)
    data["range_type"] = int(m.group(1)) if m else 0
    m = re.search(r'range_value\s*=\s*(\d+)', text)
    data["range_value"] = int(m.group(1)) if m else 1
    m = re.search(r'is_upgraded\s*=\s*(true|false)', text)
    data["is_upgraded"] = m.group(1) == "true" if m else False
    data["upgraded_version_path"] = ""
    # upgraded_version = ExtResource("3_xxx") -> find ext_resource with that id and path
    m = re.search(r'upgraded_version\s*=\s*ExtResource\("([^"]+)"\)', text)
    if m:
        ext_id = m.group(1)
        ext_m = re.search(rf'\[ext_resource[^\]]*id="{re.escape(ext_id)}"[^\]]*path="([^"]+)"', text)
        if ext_m:
            data["upgraded_version_path"] = ext_m.group(1).replace("res://", "")

    # Parse sub_resources (effects)
    data["effects"] = []
    for block in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\](.*?)(?=\n\[|\n\[gd_resource]|\Z)', text, re.DOTALL):
        block_id = block.group(1)
        body = block.group(2)
        eff = {}
        for key in ["effect_type", "value", "target_type", "area_of_effect_type", "damage_type",
                    "has_condition", "condition_type", "condition_value", "conditional_bonus_value", "string_value"]:
            m = re.search(rf'{key}\s*=\s*([^\n]+)', body)
            if m:
                val = m.group(1).strip()
                if val in ("true", "false"):
                    eff[key] = val == "true"
                elif val.isdigit() or (val.startswith("-") and val[1:].isdigit()):
                    eff[key] = int(val)
                else:
                    eff[key] = val.strip('"')
        if eff.get("effect_type") is not None:
            data["effects"].append(eff)

    # If no sub_resources found, effects might be inline; try to get from [resource] effects = Array
    if not data["effects"] and "effects = Array" in text:
        # Some cards have effects = Array[ExtResource(...)]([SubResource("Resource_xxx")]) - we already parsed sub_resources
        # But sub_resource might use different id format - search again for script = ExtResource (CardEffectData)
        for block in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\](.*?)(?=\n\[|\Z)', text, re.DOTALL):
            block_id = block.group(1)
            body = block.group(2)
            if "CardEffectData" not in body and "effect_type" in body:
                eff = {}
                for key in ["effect_type", "value", "target_type", "area_of_effect_type", "damage_type",
                            "has_condition", "condition_type", "condition_value", "conditional_bonus_value", "string_value"]:
                    m = re.search(rf'{key}\s*=\s*([^\n]+)', body)
                    if m:
                        val = m.group(1).strip()
                        if val in ("true", "false"):
                            eff[key] = val == "true"
                        elif val.isdigit() or (val.startswith("-") and val[1:].isdigit()):
                            eff[key] = int(val)
                        else:
                            eff[key] = val.strip('"') if val != '""' else ""
                if eff.get("effect_type") is not None:
                    data["effects"].append(eff)

    return data


def format_effects(effects: list, trans: dict) -> str:
    parts = []
    for e in effects:
        et = e.get("effect_type", 0)
        name = EFFECT_TYPE_NAMES[et] if et < len(EFFECT_TYPE_NAMES) else f"Effect_{et}"
        val = e.get("value", 0)
        sval = e.get("string_value", "")
        if name == "DEAL_DAMAGE":
            dt = e.get("damage_type", 0)
            dmg_type = DAMAGE_TYPE_NAMES[dt] if dt < len(DAMAGE_TYPE_NAMES) else "?"
            parts.append(f"DEAL_DAMAGE: {val} ({dmg_type})")
        elif name == "GAIN_BLOCK":
            if sval == "max_hp":
                parts.append("GAIN_BLOCK: max_hp")
            else:
                parts.append(f"GAIN_BLOCK: {val}")
        elif name == "HEAL_UNIT":
            parts.append(f"HEAL: {val}")
        elif name == "HEAL_TO_FULL":
            parts.append("HEAL_TO_FULL")
        elif name == "DRAW_CARDS":
            parts.append(f"DRAW_CARDS: {val}")
        elif name == "GAIN_ENERGY":
            parts.append(f"GAIN_ENERGY: {val}")
        elif name == "APPLY_STATUS":
            parts.append(f"APPLY_STATUS: {sval or val}")
        elif name == "EXHAUST":
            parts.append("EXHAUST")
        elif name == "DEAL_DAMAGE_FROM_BLOCK":
            parts.append("DEAL_DAMAGE_FROM_BLOCK (value from block)")
        elif name == "DEAL_DOUBLE_DAMAGE_FROM_BLOCK":
            parts.append("DEAL_DOUBLE_DAMAGE_FROM_BLOCK")
        elif name == "MODIFY_INITIATIVE_NEXT_ROUND":
            parts.append(f"MODIFY_INITIATIVE: {val}")
        else:
            parts.append(f"{name}: {val}" + (f" ({sval})" if sval else ""))
    return "; ".join(parts) if parts else "—"


def format_damage_type(effects: list) -> str:
    for e in effects:
        if e.get("effect_type") == 0:  # DEAL_DAMAGE
            dt = e.get("damage_type", 0)
            return DAMAGE_TYPE_NAMES[dt] if dt < len(DAMAGE_TYPE_NAMES) else "?"
    return "—"


def format_range_target(card: dict) -> str:
    rt = card.get("range_type", 0)
    rv = card.get("range_value", 1)
    range_name = EFFECT_RANGE_NAMES[rt] if rt < len(EFFECT_RANGE_NAMES) else f"Range_{rt}"
    # Target from first effect
    targets = []
    for e in card.get("effects", []):
        tt = e.get("target_type", 1)
        aoe = e.get("area_of_effect_type", 0)
        tname = TARGET_NAMES[tt] if tt < len(TARGET_NAMES) else ""
        aoe_name = AOE_NAMES[aoe] if aoe < len(AOE_NAMES) else ""
        if aoe == 4:  # ALL_ON_GRID
            targets.append("All Enemies")
        elif aoe == 1:
            targets.append("Row")
        elif aoe == 2:
            targets.append("Column")
        elif aoe == 3:
            targets.append(f"Grid {e.get('aoe_param_x',1)}x{e.get('aoe_param_y',1)}")
        elif tt == 1:
            targets.append("Melee/Single")
        elif tt == 0:
            targets.append("Self")
        elif tt == 3:
            targets.append("All Enemies")
        else:
            targets.append(tname or "—")
    if not targets:
        return range_name + (f" ({rv})" if rv and range_name != "NONE" else "")
    return range_name + (f" ({rv})" if rv and range_name in ("MELEE", "RANGED_FIXED", "RANGED_LINE") else "") + " · " + ", ".join(targets[:2])


def format_condition(card: dict) -> str:
    for e in card.get("effects", []):
        if e.get("has_condition"):
            ct = e.get("condition_type", "")
            cv = e.get("condition_value", 0)
            cb = e.get("conditional_bonus_value", 0)
            return f"Yes ({ct} {cv}; bonus {cb})"
    return "No"


def has_upgraded(card: dict) -> str:
    if card.get("upgraded_version_path"):
        return "Yes"
    return "No"


def get_display_name(card: dict, trans: dict) -> str:
    key = card.get("card_name_key", "")
    if key and key in trans:
        return trans[key]
    return card.get("card_id", "?") or "?"


def damage_and_aoe_score(card: dict) -> tuple:
    """Return (total_damage, is_aoe, cost) for ranking. Only damage effects."""
    total_dmg = 0
    is_aoe = False
    for e in card.get("effects", []):
        if e.get("effect_type") == 0:
            total_dmg += e.get("value", 0)
            if e.get("area_of_effect_type") == 4 or e.get("target_type") == 3:
                is_aoe = True
            if e.get("area_of_effect_type") in (1, 2, 3):
                is_aoe = True
    return (total_dmg, is_aoe, card.get("cost", 1))


def main():
    trans = load_translations()
    cards = []
    for root, dirs, files in os.walk(CARDS_DIR):
        for f in files:
            if not f.endswith(".tres"):
                continue
            filepath = Path(root) / f
            if "pool" in f.lower():
                continue
            data = parse_tres_file(filepath)
            if data is None:
                continue
            data["_path"] = str(filepath.relative_to(PROJECT_ROOT))
            cards.append(data)

    # Sort by folder then card_id
    cards.sort(key=lambda c: (c.get("_path", ""), c.get("card_id", "")))

    # Build markdown
    lines = [
        "# Card Audit — Projekt Loop",
        "",
        "Generated from `data/cards/` (all .tres CardData resources, excluding pools).",
        "",
        "## Full card table",
        "",
        "| Card Name | Cost | Rarity | Base Effects | Damage Type | Range & Target | Has Condition? | Upgraded Version? |",
        "|-----------|------|--------|---------------|--------------|----------------|----------------|-------------------|",
    ]

    for c in cards:
        name = get_display_name(c, trans)
        cost = c.get("cost", 0)
        rarity = RARITY_NAMES[c["rarity"]] if c["rarity"] < len(RARITY_NAMES) else str(c["rarity"])
        effects = format_effects(c.get("effects", []), trans)
        dmg_type = format_damage_type(c.get("effects", []))
        range_tgt = format_range_target(c)
        cond = format_condition(c)
        upg = has_upgraded(c)
        # Escape pipe in cells
        for x in [name, effects, range_tgt, cond]:
            if "|" in str(x):
                x = str(x).replace("|", "\\|")
        lines.append(f"| {name} | {cost} | {rarity} | {effects} | {dmg_type} | {range_tgt} | {cond} | {upg} |")

    # Top 5 by damage-to-cost and AOE potential
    damage_cards = []
    for c in cards:
        dmg, aoe, cost = damage_and_aoe_score(c)
        if cost <= 0:
            cost = 1
        ratio = dmg / cost
        damage_cards.append((c, dmg, aoe, ratio))

    damage_cards.sort(key=lambda x: (x[2], x[3], x[1]), reverse=True)  # AOE first, then ratio, then raw damage
    top5 = damage_cards[:5]
    # Re-sort for display: by ratio * (1.5 if AOE else 1) then damage
    top5_scored = [(c, dmg, aoe, ratio * (1.5 if aoe else 1.0)) for c, dmg, aoe, ratio in top5]
    top5_scored.sort(key=lambda x: x[3], reverse=True)
    top5 = [(x[0], x[1], x[2], x[3]) for x in top5_scored[:5]]

    lines.extend([
        "",
        "---",
        "",
        "## Top 5 most powerful cards (Damage-to-Cost + AOE potential)",
        "",
        "Ranking favors AOE and high damage-per-energy.",
        "",
    ])
    for i, (c, dmg, aoe, score) in enumerate(top5, 1):
        name = get_display_name(c, trans)
        cost = c.get("cost", 1)
        ratio = dmg / cost if cost else dmg
        aoe_str = "Yes (all/line/area)" if aoe else "No"
        lines.append(f"{i}. **{name}** — Cost: {cost}, Damage: {dmg}, Dmg/Cost: {ratio:.1f}, AOE: {aoe_str}")
        lines.append("")

    OUTPUT_MD.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT_MD} ({len(cards)} cards)")


if __name__ == "__main__":
    main()
