# UI readability source of truth for Projekt Loop.
# Font: res://art/fonts/Ithaca-LVB75.ttf
# Theme: res://art/ui/game_theme.tres (also set in Project Settings > GUI > Theme)
# Prefer theme defaults. Only override size/color when a screen truly needs it.
# Battle HP bars: scenes/ui/UnitHealthBar.tscn (spawned from Unit.gd)
#
# Pixel chrome (navy / gold / sapphire ninepatch):
#   art/ui/chrome/*.png — StyleBoxTexture in game_theme.tres
#   Type variations: HudBar (GlobalUI top bar), HudChip (HP/gold chips), GoldPanel (intent box)
#   Buttons inherit Button/styles/* automatically.
