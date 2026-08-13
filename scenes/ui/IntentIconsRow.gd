extends Control
## Thin wrapper owning 1-2 IntentIcon children for dual-intent display.
## Single-icon callers can keep using IntentIcon.tscn directly.

const IntentIconScene = preload("res://scenes/ui/IntentIcon.tscn")

## Extra edge gap between dual icons at scale 1.0 (screen px).
const DUAL_EDGE_GAP := 10.0
## Relative scale of each icon when two are shown vs one.
const DUAL_SCALE_FACTOR := 0.85
const MAX_INTENTS := 2
const _COMBINED_LABEL_FONT_SIZE := 22

var _icons: Array[Control] = []
var _screen_position: Vector2 = Vector2.ZERO
var _row_scale: float = 1.0
var _active_count: int = 0
var _combined_label: Label = null
var _combined_short_texts: PackedStringArray = PackedStringArray()


func _ready() -> void:
	visible = false
	_force_mouse_passthrough()
	_ensure_icons()
	_ensure_combined_label()
	_force_mouse_passthrough()


func _force_mouse_passthrough() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_icons() -> void:
	while _icons.size() < MAX_INTENTS:
		var icon: Control = IntentIconScene.instantiate()
		add_child(icon)
		if icon.has_method("hide_intent"):
			icon.hide_intent()
		else:
			icon.visible = false
		_icons.append(icon)


func _ensure_combined_label() -> void:
	if is_instance_valid(_combined_label):
		return
	_combined_label = Label.new()
	_combined_label.name = "CombinedIntentLabel"
	_combined_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combined_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combined_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combined_label.add_theme_color_override("font_color", Color.WHITE)
	_combined_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combined_label.add_theme_constant_override("outline_size", 5)
	_combined_label.visible = false
	add_child(_combined_label)


## intents: Array of Dictionary { icon: Texture2D, short_text: String, countdown: int = 0 }
## Empty -> hide. 1 -> centered. 2 -> side-by-side with zoom-scaled spacing + one combined label.
func set_intents(intents: Array) -> void:
	_ensure_icons()
	_ensure_combined_label()
	_force_mouse_passthrough()
	_combined_short_texts = PackedStringArray()

	if intents.is_empty():
		_active_count = 0
		for icon in _icons:
			if icon.has_method("hide_intent"):
				icon.hide_intent()
			else:
				icon.visible = false
		_hide_combined_label()
		hide_row()
		return

	_active_count = mini(intents.size(), MAX_INTENTS)
	var dual := _active_count >= 2
	for i in range(MAX_INTENTS):
		var icon: Control = _icons[i]
		if i < _active_count:
			var data: Variant = intents[i]
			var tex: Texture2D = null
			var short_text := ""
			var countdown := 0
			if data is Dictionary:
				tex = data.get("icon", null) as Texture2D
				short_text = str(data.get("short_text", ""))
				countdown = int(data.get("countdown", 0))
			if not short_text.is_empty():
				_combined_short_texts.append(short_text)
			# Dual: labels live on the row (avoids MOVE+ATTACK merging when zoomed).
			var icon_label := "" if dual else short_text
			if icon.has_method("set_intent"):
				icon.set_intent(tex, icon_label)
			if icon.has_method("set_label_visible"):
				icon.set_label_visible(not dual)
			if icon.has_method("set_countdown"):
				icon.set_countdown(countdown)
			if icon.has_method("set_compact_mode"):
				icon.set_compact_mode(dual)
			if icon.has_method("show_intent"):
				icon.show_intent()
			else:
				icon.visible = true
		else:
			if icon.has_method("set_compact_mode"):
				icon.set_compact_mode(false)
			if icon.has_method("hide_intent"):
				icon.hide_intent()
			else:
				icon.visible = false

	_apply_scales()
	_apply_layout()
	_refresh_combined_label()


func set_screen_position(pos: Vector2) -> void:
	_screen_position = pos
	# Anchor the row; children use absolute screen coords via IntentIcon.set_screen_position.
	global_position = pos
	_apply_layout()
	_refresh_combined_label()


func set_row_scale(scale_value: float) -> void:
	_row_scale = scale_value
	_apply_scales()
	_apply_layout()
	_refresh_combined_label()


func show_row() -> void:
	_force_mouse_passthrough()
	visible = true
	for i in range(_active_count):
		var icon: Control = _icons[i]
		if icon.has_method("show_intent"):
			icon.show_intent()
		else:
			icon.visible = true
	_refresh_combined_label()


func hide_row() -> void:
	visible = false
	for icon in _icons:
		if icon.has_method("hide_intent"):
			icon.hide_intent()
		else:
			icon.visible = false
	_hide_combined_label()


## First intent icon Control — for tutorial highlights.
func get_primary_intent_ui() -> Control:
	_ensure_icons()
	if _icons.size() > 0:
		return _icons[0]
	return self


## Texture size of the primary icon (for Unit scale math). Falls back to 64x64.
func get_icon_texture_size() -> Vector2:
	_ensure_icons()
	var primary := get_primary_intent_ui()
	if primary != self and primary.has_method("get_icon_texture_size"):
		return primary.get_icon_texture_size()
	return Vector2(64, 64)


func _effective_icon_scale() -> float:
	var factor := DUAL_SCALE_FACTOR if _active_count >= 2 else 1.0
	return _row_scale * factor


## Center-to-center gap tracks visual icon width so zoom-in doesn't collide icons.
func _dual_center_spacing() -> float:
	var s := _effective_icon_scale()
	var tex_w := get_icon_texture_size().x
	return (tex_w * s) + (DUAL_EDGE_GAP * s)


func _apply_layout() -> void:
	if _active_count <= 0 or _icons.is_empty():
		return
	if _active_count == 1:
		_set_child_screen_pos(_icons[0], _screen_position)
		return
	var half := _dual_center_spacing() * 0.5
	_set_child_screen_pos(_icons[0], _screen_position + Vector2(-half, 0.0))
	_set_child_screen_pos(_icons[1], _screen_position + Vector2(half, 0.0))


func _set_child_screen_pos(icon: Control, pos: Vector2) -> void:
	if icon.has_method("set_screen_position"):
		icon.set_screen_position(pos)
	else:
		icon.global_position = pos


func _apply_scales() -> void:
	if _icons.is_empty():
		return
	var s := _effective_icon_scale()
	for i in range(MAX_INTENTS):
		var icon: Control = _icons[i]
		if not icon.has_method("set_icon_scale"):
			continue
		if i < _active_count:
			icon.set_icon_scale(s)
		if icon.has_method("set_compact_mode"):
			icon.set_compact_mode(_active_count >= 2 and i < _active_count)


func _refresh_combined_label() -> void:
	_ensure_combined_label()
	if _active_count < 2 or _combined_short_texts.is_empty():
		_hide_combined_label()
		return
	var s := _effective_icon_scale()
	_combined_label.text = " ".join(_combined_short_texts)
	_combined_label.add_theme_font_size_override("font_size", maxi(12, int(round(float(_COMBINED_LABEL_FONT_SIZE) * s))))
	_combined_label.visible = visible
	# Place under the icon pair, centered on the row anchor.
	var tex_h := get_icon_texture_size().y * s
	var label_w := maxf(120.0, _dual_center_spacing() + tex_h)
	var label_h := maxf(18.0, 28.0 * s)
	_combined_label.size = Vector2(label_w, label_h)
	_combined_label.position = Vector2(-label_w * 0.5, tex_h * 0.35)
	_combined_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _hide_combined_label() -> void:
	if is_instance_valid(_combined_label):
		_combined_label.visible = false
		_combined_label.text = ""
