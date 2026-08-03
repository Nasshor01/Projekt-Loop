# Audit artefaktů – remake status

Staré CZ artefakty byly wipe-nuty. Live systém = `ArtifactBehavior` + katalog v `data/artifacts/catalog/`.

Viz:
- [ARTIFACT_DESIGN_LIST.md](ARTIFACT_DESIGN_LIST.md) — locked design
- [ARTIFACT_CHECKLIST.md](ARTIFACT_CHECKLIST.md) — per-artifact test status
- [ARTIFACT_COMBO_LAB.md](ARTIFACT_COMBO_LAB.md) — known spicy combos

## Architecture
- `ArtifactsData` = katalog (id, ikona, popis, `behavior_script`)
- `ArtifactBehavior` = 1 skript / artefakt
- `ArtifactManager` = event bus + registry + runtime (zones, run flags)

## DevConsole
`add_artifact forbidden_apple` · `test_artifact forbidden_apple` · `test_all_artifacts`
