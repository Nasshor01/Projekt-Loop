# Building sprite on the village plateau. Texture follows meta level when art exists.
@tool
class_name VillageBuildingSlot
extends Area2D

const LEVEL_TEXTURES := {
	"well": [
		"res://art/sprites/village/Well/Well 0.png",
		"res://art/sprites/village/Well/Well 1.png",
	],
	"market": [
		"res://art/sprites/village/market/Market 0.png",
		"res://art/sprites/village/market/Market 1.png",
	],
	"library": [
		"res://art/sprites/village/Library/Library 0.png",
		"res://art/sprites/village/Library/Library 1.png",
	],
	"chapel": [
		"res://art/sprites/village/Chapel/chapel 0.png",
		"res://art/sprites/village/Chapel/chapel 1.png",
		"res://art/sprites/village/Chapel/chapel 2.png",
		"res://art/sprites/village/Chapel/chapel 3.png",
	],
	"tavern": [
		"res://art/sprites/village/Tavern/Tavern 0.png",
		"res://art/sprites/village/Tavern/Tavern 1.png",
		"res://art/sprites/village/Tavern/Tavern 2.png",
		"res://art/sprites/village/Tavern/Tavern 3.png",
	],
	"hunters_lodge": [
		"res://art/sprites/village/Hunter’s Lodge/Hunter’s Lodge 0.png",
		"res://art/sprites/village/Hunter’s Lodge/Hunter’s Lodge 1.png",
		"res://art/sprites/village/Hunter’s Lodge/Hunter’s Lodge 2.png",
		"res://art/sprites/village/Hunter’s Lodge/Hunter’s Lodge 3.png",
	],
}

## Extra sprite scale per level index. Chapel 3 art is ~2× taller than 2 — shrink only that jump.
const LEVEL_SPRITE_SCALE := {
	"chapel": [0.62, 1.38, 1.28, 0.75],
}

@export var building_id: String = ""
@export var ruin_texture: Texture2D:
	set(value):
		ruin_texture = value
		if is_inside_tree() and Engine.is_editor_hint():
			_apply_texture()

signal slot_clicked(building_id: String)
signal slot_hovered(building_id: String)
signal slot_unhovered

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _level_tex_cache: Dictionary = {}
var display_level: int = 0


func _ready() -> void:
	_apply_texture()
	if Engine.is_editor_hint():
		return
	input_pickable = true
	monitoring = true
	monitorable = false
	collision_mask = 0
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func set_locked_visual(locked: bool) -> void:
	modulate = Color(0.42, 0.42, 0.48, 1.0) if locked else Color.WHITE


func set_display_level(level: int) -> void:
	display_level = maxi(0, level)
	var paths: Variant = LEVEL_TEXTURES.get(building_id, [])
	if paths is Array and not paths.is_empty():
		var idx := clampi(display_level, 0, paths.size() - 1)
		var path := String(paths[idx])
		var tex: Texture2D = _level_tex_cache.get(path) as Texture2D
		if tex == null:
			tex = load(path) as Texture2D
			if tex:
				_level_tex_cache[path] = tex
		var spr := _sprite()
		if spr and tex:
			spr.texture = tex
			_apply_level_scale(idx)
			_sync_collision()
			return
	_apply_texture()


func _sprite() -> Sprite2D:
	return sprite if sprite else get_node_or_null("Sprite2D") as Sprite2D


func _apply_texture() -> void:
	var spr := _sprite()
	if spr == null:
		return
	if ruin_texture:
		spr.texture = ruin_texture
	_apply_level_scale(0)
	_sync_collision()


func _apply_level_scale(level_idx: int) -> void:
	var spr := _sprite()
	if spr == null:
		return
	var scales: Variant = LEVEL_SPRITE_SCALE.get(building_id, [])
	var extra := 1.0
	if scales is Array and level_idx >= 0 and level_idx < scales.size():
		extra = float(scales[level_idx])
	spr.scale = Vector2(extra, extra)
	spr.centered = true
	spr.position = Vector2.ZERO


func _sync_collision() -> void:
	var spr := _sprite()
	var col := collision if collision else get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or spr == null or spr.texture == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = spr.texture.get_size() * spr.scale.abs()
	col.shape = shape


func get_screen_rect() -> Rect2:
	var spr := _sprite()
	if spr == null or spr.texture == null:
		var p := get_global_transform_with_canvas().origin
		return Rect2(p - Vector2(24, 24), Vector2(48, 48))
	var tex_size := spr.texture.get_size()
	var xf := spr.get_global_transform_with_canvas()
	var canvas_size := Vector2(absf(tex_size.x * xf.x.x), absf(tex_size.y * xf.y.y))
	return Rect2(xf.origin - canvas_size * 0.5, canvas_size)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not building_id.is_empty():
		slot_clicked.emit(building_id)
		get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	if not building_id.is_empty():
		slot_hovered.emit(building_id)


func _on_mouse_exited() -> void:
	slot_unhovered.emit()
