# ===================================================================
# Soubor: res://scripts/CardUI.gd
# ===================================================================
class_name CardUI
extends Control

@export var card_data: CardData:
	set(new_card_data):
		card_data = new_card_data
		if is_inside_tree() and _ui_nodes_ready:
			update_display()

@export var placeholder_artwork: Texture2D

var initial_scale: Vector2 = Vector2.ZERO

var _ui_nodes_ready = false
@onready var artwork_texture_rect: TextureRect = $ArtworkTextureRect
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var description_label: Label = $DescriptionLabel
@onready var card_template: TextureRect = $CardTemplateImage

var original_scale: Vector2 = Vector2(0.8, 0.8)

func _ready():
	_ui_nodes_ready = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# ZMĚNA: Použijeme initial_scale, pokud je nastaveno
	if initial_scale != Vector2.ZERO:
		original_scale = initial_scale
	scale = original_scale
	
	if card_data:
		update_display()
	
	if description_label:
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD

func update_display():
	if not _ui_nodes_ready or not card_data: return

	name_label.text = card_data.get_localized_name()
	cost_label.text = str(card_data.cost)
	
	# Použijeme dynamický popis s aktuálními hodnotami poškození
	description_label.text = card_data.get_display_description()
	
	if artwork_texture_rect and card_data.artwork:
		artwork_texture_rect.texture = card_data.artwork
	
	# Nastavíme barvu karty podle rarity
	_update_rarity_colors()

func _update_rarity_colors():
	"""Nastaví barvu karty podle rarity"""
	if not card_template or not card_data:
		return
	
	# Barevné rozlišení podle rarity (lehčí modulace pro zachování čitelnosti)
	var rarity_colors = {
		CardData.CardRarity.BASIC: Color(0.9, 0.9, 0.9, 1.0),      # Bílá/Šedá
		CardData.CardRarity.COMMON: Color(1.0, 1.0, 1.0, 1.0),     # Bílá
		CardData.CardRarity.UNCOMMON: Color(0.7, 1.0, 0.7, 1.0),   # Světle zelená
		CardData.CardRarity.RARE: Color(0.7, 0.7, 1.0, 1.0),       # Světle modrá
		CardData.CardRarity.EPIC: Color(1.0, 0.7, 1.0, 1.0),       # Světle fialová
		CardData.CardRarity.LEGENDARY: Color(1.0, 0.9, 0.5, 1.0)   # Zlatá
	}
	
	if rarity_colors.has(card_data.rarity):
		# Lehce změníme barvu pozadí karty (modulace)
		card_template.modulate = rarity_colors[card_data.rarity]
	else:
		card_template.modulate = Color.WHITE

func load_card(new_card_data: CardData):
	self.card_data = new_card_data
