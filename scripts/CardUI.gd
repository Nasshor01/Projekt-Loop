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

var _selection_tween: Tween
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

	name_label.text = card_data.card_name
	cost_label.text = str(card_data.cost)
	description_label.text = card_data.card_description
	if artwork_texture_rect and card_data.artwork:
		artwork_texture_rect.texture = card_data.artwork

func load_card(new_card_data: CardData):
	self.card_data = new_card_data
