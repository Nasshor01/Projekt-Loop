# Projekt LOOP — Pre-Alpha 0.3.8

Playtest UX + artifact remake od 0.3.7. Pořád Pre-Alpha, ne 0.4.

## Initiative (BG3-style)
- Vlevo = zbývající tahy TOHOTO kola
- Vpravo = live preview PŘÍŠTÍHO kola (můžeš být 2×)
- Oddělovač kol
- Čísla initiative vždy vidět

## Artifacts
- Remake katalog + behavior vrstva (live pool)
- Playtest UX: Chalice / Alchemist / Eye prompty nad rukou / bokem
- GlobalUI strip artefaktů

## Shop / rewards / 1920 UI
- LayoutSlot, shop economy, větší čitelnost karet

---

## Dodatky (06.08 — před playtestem)

### UI / čitelnost
- Karty: Ithaca font, větší hand/shop face (240×300), curse text světlý na tmavém framu
- Hover tipy (pinned, velké) v shopu, rewards, treasure, event/rest pick — **ne** v battle ruce
- Větší artifact tipy + ikony v GlobalUI (56px)
- Eventy: GlobalUI viditelné; při zisku artefaktu ikona + tip v outcome panelu
- Crimson Chalice HandPrompt nad GlobalUI (vrstva 50) s panelem Drink/Skip

### Opravy
- Energy UI: znovu napojený `energy_changed` → PlayerInfoPanel
- Artifact tipy: CanvasLayer + clamp u ikony (editor embed)

### Artifact audit (live pool)
- Blade of Infinity: Exhaust Attack → spodek balíčku (BattleScene volá `on_exhaust`)
- Frostbitten Heart / Plaguebone Axe: threshold dmg (+ heal / ignore block) přes reálné hooky
- Opravy wiring: Plague Dragonheart, Hellchain, Plague Mace (enemy turn), Gilded line cost, Fractured Bulwark, Tome/Bloodrage/Bloodbound combat reset, Arcane Focus draw
- ~32 WORKING, 4 PARTIAL (Infernal teleport edge, Prism aura duration, Heart echo raw dmg, Gilded cost UI bez cíle), 0 BROKEN v live poolu
