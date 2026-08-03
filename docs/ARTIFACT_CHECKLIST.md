# Artifact Implementation Checklist (remake)

Pre-launch audit (2026-08-03): critical wiring bugs fixed — see notes below.

Statuses: `UNTESTED` | `SMOKE` | `COMBO` | `FIXED`

## Common
| ID | Name | Status | Notes |
|---|---|---|---|
| forbidden_apple | Forbidden Apple | SMOKE | +7 Max HP stacks |

## Uncommon
| ID | Name | Status | Notes |
|---|---|---|---|
| runic_cube_of_binding | Runic Cube of Binding | UNTESTED | MOVE tag |
| tablet_of_forgotten_oaths | Tablet of Forgotten Oaths | UNTESTED | auto-seal |
| embercleaver | Embercleaver | UNTESTED | |
| charm_of_fortune | Charm of Fortune | UNTESTED | shop+gold wired |
| fractured_bulwark | Fractured Bulwark | FIXED | draw next turn (not end-turn) |
| spiral_bulwark | Spiral Bulwark | UNTESTED | |

## Rare
| ID | Name | Status | Notes |
|---|---|---|---|
| arcane_prism | Arcane Prism | UNTESTED | |
| plague_mace_core | Plague Mace Core | UNTESTED | |
| hellchain_reaver | Hellchain Reaver | UNTESTED | |
| frostbite_executioner | Frostbite Executioner | UNTESTED | |
| molten_heart | Molten Heart | UNTESTED | |
| frostbitten_heart | Frostbitten Heart | UNTESTED | |
| infernal_dragonheart | Infernal Dragonheart | FIXED | grid move via battle_grid |
| plague_dragonheart | Plague Dragonheart | FIXED | |
| crown_of_dominion | Crown of Dominion | UNTESTED | |
| crimson_chalice | Crimson Chalice | FIXED | fires on_hand_ready |
| tome_of_echoes | Tome of Echoes | UNTESTED | |
| aether_crystal | Aether Crystal | FIXED | retain + draw next turn |
| all_seeing_eye | All-Seeing Eye | UNTESTED | preview flag only |
| belt_of_the_iron_will | Belt of the Iron Will | UNTESTED | |
| alchemists_tools | Alchemist's Tools | FIXED | on_hand_ready; curly-apostrophe icon |
| verdant_scale | Verdant Scale | UNTESTED | |
| phoenix_feather | Phoenix Feather | FIXED | deferred self-remove |

## Cursed
| ID | Name | Status | Notes |
|---|---|---|---|
| bloodbound_amulet | Bloodbound Amulet | UNTESTED | |
| bloodrage_cleaver | Bloodrage Cleaver | UNTESTED | |
| voidheart | Voidheart | UNTESTED | |
| void_dragonheart | Void Dragonheart | FIXED | absi parse |
| ring_of_the_living_grove | Ring of the Living Grove | FIXED | draw next turn |

## Legendary
| ID | Name | Status | Notes |
|---|---|---|---|
| plaguebone_axe | Plaguebone Axe | UNTESTED | |
| time_crystal | Time Crystal | FIXED | on_turn_end + once-per-turn guard |
| gilded_dragonheart | Gilded Dragonheart | UNTESTED | |
| blade_of_infinity | Blade of Infinity | UNTESTED | |

## Boss
| ID | Name | Status | Notes |
|---|---|---|---|
| throne_fragment | Throne Fragment | FIXED | draw next turn |
| oathbreaker_seal | Oathbreaker Seal | FIXED | mutates master_deck in place |
| heart_of_the_loop | Heart of the Loop | UNTESTED | echo log-only |

## Audit fixes applied
- Runtime preserved across behavior cache refresh
- `get_enemies()` uses `BattleScene.get_all_enemies()`
- `check_conditional_*` no longer double-fires `on_turn_end`
- `on_hand_ready` after draw (Chalice / Alchemist)
- Turn-end draws deferred to next turn start (discard-safe)
- Pool `.tres` typed as `Array[ArtifactsData]`
