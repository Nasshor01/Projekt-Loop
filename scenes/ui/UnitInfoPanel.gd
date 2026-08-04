# Soubor: res://scenes/ui/UnitInfoPanel.gd
# Kompaktní info panel (enemy hover / player). HP a intent jsou na gridu.
# Panel se AUTOMATICKY roztáhne podle obsahu; scroll jen když už není kam růst.
extends PanelContainer

const ICON_BURNING = preload("res://art/icons/status/Bleed.png")
const ICON_CHILLED = preload("res://art/icons/status/Freeze.png")
const ICON_SHOCKED = preload("res://art/icons/status/Stunned.png")
const ICON_FROZEN = preload("res://art/icons/status/Freeze.png")
const ICON_ENTANGLED = preload("res://art/icons/status/Slow_Down.png")
const ICON_MONK_BLESSING = preload("res://art/icons/status/Strenght.png")
const ICON_REGENERATION = preload("res://art/icons/status/Regeneration.png")
const ICON_SLOW = preload("res://art/icons/status/Slow_Down.png")
const ICON_VULNERABLE = preload("res://art/icons/status/Vulnerable.png")
const ICON_AIMING = preload("res://art/icons/status/Aim.png")
const ICON_AURA_DEVOTION = preload("res://art/icons/status/block.png")
const ICON_POISON = preload("res://art/icons/status/Poison.png")
const ICON_WEAKNESS = preload("res://art/icons/status/Weakness.png")
const ICON_THORNS = preload("res://art/icons/status/Thorns.png")
const ICON_BLOCK = preload("res://art/icons/status/block.png")
const ICON_RAGE = preload("res://art/icons/status/Rage_rush.png")
const ICON_LEECH = preload("res://art/icons/status/Leech.png")
const ICON_DEFAULT = preload("res://art/icons/status/Poison.png")

const PANEL_WIDTH := 260.0
const PANEL_MARGIN_V := 20.0 # top+bottom content margins
const VIEWPORT_MARGIN := 12.0
const TOP_SAFE_MARGIN := 90.0
## Keep clear of draw/discard piles anchored on the far-right edge.
const RIGHT_PILE_SAFE_MARGIN := 88.0
const STATUS_ICON_SIZE := 16
const CHIP_FONT_SIZE := 12
const MIN_PANEL_HEIGHT := 80.0

const COLOR_MUTED := Color(0.72, 0.76, 0.84, 1)
const COLOR_CHIP_BG := Color(0.14, 0.16, 0.22, 0.95)
const COLOR_CHIP_ALERT_BG := Color(0.28, 0.14, 0.12, 0.95)
const COLOR_CHIP_ALERT_FG := Color(1.0, 0.72, 0.55, 1)

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var content_root: VBoxContainer = %ContentRoot
@onready var name_label: Label = %NameLabel
@onready var class_label: Label = %ClassLabel
@onready var hp_brief_label: Label = %HpBriefLabel
@onready var vitals_row: HBoxContainer = %VitalsRow
@onready var hp_slot: HBoxContainer = %HPSlot
@onready var hp_label: Label = %HPLabel
@onready var block_slot: HBoxContainer = %BlockSlot
@onready var block_label: Label = %BlockLabel
@onready var energy_slot: HBoxContainer = %EnergySlot
@onready var energy_label: Label = %EnergyLabel
@onready var attack_slot: HBoxContainer = %AttackSlot
@onready var attack_label: Label = %AttackLabel
@onready var enemy_section: VBoxContainer = %EnemySection
@onready var intent_box: PanelContainer = %IntentBox
@onready var intent_header: Label = %IntentHeader
@onready var intent_title_label: Label = %IntentTitleLabel
@onready var intent_detail_label: Label = %IntentDetailLabel
@onready var passives_section: VBoxContainer = %PassivesSection
@onready var passives_header: Label = %PassivesHeader
@onready var passives_flow: HFlowContainer = %PassivesFlow
@onready var alerts_section: VBoxContainer = %AlertsSection
@onready var alerts_header: Label = %AlertsHeader
@onready var alerts_flow: HFlowContainer = %AlertsFlow
@onready var status_section: VBoxContainer = %StatusSection
@onready var status_header: Label = %StatusHeader
@onready var status_effects_list: VBoxContainer = %StatusEffectsList

var _content_fingerprint: String = ""
var _fit_queued: bool = false
## Scene-authored bottom + side anchors — bottom stays pinned; top grows with content.
var _pinned_offset_bottom: float = -96.0
var _pinned_offset_left: float = 12.0
var _pinned_offset_right: float = 272.0
var _pins_cached: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if scroll_container:
		scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if content_root:
		# SHRINK_BEGIN is required for ScrollContainer to scroll (EXPAND breaks it).
		content_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_section_headers()
	_cache_layout_pins()
	hide_panel()


func _cache_layout_pins() -> void:
	"""Lock bottom + side slots from the scene. Top is free to grow upward."""
	_pinned_offset_bottom = offset_bottom
	_pinned_offset_left = offset_left
	_pinned_offset_right = offset_right
	_pins_cached = true

func _apply_section_headers() -> void:
	if intent_header:
		intent_header.text = tr("ui.unit_info.section.intent")
	if passives_header:
		passives_header.text = tr("ui.unit_info.section.passives")
	if alerts_header:
		alerts_header.text = tr("ui.unit_info.section.alerts")
	if status_header:
		status_header.text = tr("ui.unit_info.section.status")

func update_stats(unit_node: Node) -> void:
	if not name_label or not content_root or not status_effects_list:
		printerr(tr("UnitInfoPanel: Missing required nodes!"))
		visible = false
		return
	if not is_instance_valid(unit_node) or not unit_node.has_method("get_unit_data"):
		visible = false
		return

	var fingerprint := _build_fingerprint(unit_node)
	if visible and fingerprint == _content_fingerprint:
		return
	_content_fingerprint = fingerprint

	visible = true
	var data = unit_node.get_unit_data()
	var is_enemy: bool = data.faction == UnitData.Faction.ENEMY
	name_label.text = data.get_localized_name()

	# --- Header: class + brief HP (enemy) ---
	if is_enemy:
		class_label.visible = true
		if unit_node.has_method("get_enemy_class_name_only"):
			class_label.text = unit_node.get_enemy_class_name_only()
		elif unit_node.has_method("get_enemy_class_display"):
			class_label.text = unit_node.get_enemy_class_display()
		else:
			class_label.text = tr("ui.unit_info.class_unknown")
		hp_brief_label.visible = true
		hp_brief_label.text = TranslationHelper.tr_format(
			"ui.unit_info.hp_brief",
			{"current": unit_node.current_health, "max": data.max_health}
		)
		hp_slot.visible = false
	else:
		class_label.visible = false
		hp_brief_label.visible = false

	# --- Vitals: player HP (coop other) / Block / Energy / Attack ---
	var is_other_coop_unit := false
	if data.faction == UnitData.Faction.PLAYER:
		if GameManager.is_coop_run and unit_node.has_meta("owner_peer_id"):
			var owner_id = unit_node.get_meta("owner_peer_id")
			if owner_id != unit_node.multiplayer.get_unique_id():
				is_other_coop_unit = true
		if is_other_coop_unit:
			hp_slot.visible = true
			hp_label.text = TranslationHelper.tr_format(
				"ui.unit_info.hp",
				{"current": unit_node.current_health, "max": data.max_health}
			)
			energy_slot.visible = false
		else:
			hp_slot.visible = false
			energy_slot.visible = true
			energy_label.text = TranslationHelper.tr_format(
				"ui.unit_info.energy",
				{"current": PlayerData.current_energy, "max": PlayerData.max_energy}
			)
		attack_slot.visible = false
	else:
		energy_slot.visible = false
		attack_slot.visible = true
		attack_label.text = TranslationHelper.tr_format("ui.unit_info.atk_brief", {"value": data.attack_damage})

	# Block: u nepřítele jen když > 0 (HP bar už je na gridu)
	if unit_node.current_block > 0:
		block_slot.visible = true
		if unit_node.retained_block > 0:
			block_label.text = TranslationHelper.tr_format(
				"ui.unit_info.block_retained",
				{"current": unit_node.current_block, "retained": unit_node.retained_block}
			)
			block_label.tooltip_text = tr("ui.unit_info.block_tooltip_retained")
		else:
			block_label.text = TranslationHelper.tr_format(
				"ui.unit_info.block",
				{"value": unit_node.current_block}
			)
			block_label.tooltip_text = tr("ui.unit_info.block_tooltip")
	else:
		if is_enemy:
			block_slot.visible = false
			block_label.tooltip_text = ""
		else:
			block_slot.visible = true
			block_label.text = TranslationHelper.tr_format("ui.unit_info.block", {"value": 0})
			block_label.tooltip_text = ""

	vitals_row.visible = hp_slot.visible or block_slot.visible or energy_slot.visible or attack_slot.visible

	_update_enemy_details(unit_node, data)
	_update_status_display(unit_node)
	_queue_fit_panel_height()

func _update_enemy_details(unit_node: Node, data: UnitData) -> void:
	if data.faction != UnitData.Faction.ENEMY:
		enemy_section.visible = false
		return
	enemy_section.visible = true

	var short_txt := ""
	var detail_txt := ""
	if unit_node.has_method("get_intent_short_text"):
		short_txt = str(unit_node.get_intent_short_text()).strip_edges()
	if unit_node.has_method("get_intent_detail_text"):
		detail_txt = str(unit_node.get_intent_detail_text()).strip_edges()
	elif unit_node.has_method("get_intent_display_text"):
		detail_txt = str(unit_node.get_intent_display_text()).strip_edges()

	# Strip redundant "Next Move:" — section header already says NEXT.
	for prefix in ["Next Move: ", "Další tah: ", "Next: "]:
		if detail_txt.begins_with(prefix):
			detail_txt = detail_txt.substr(prefix.length()).strip_edges()
			break

	if short_txt.is_empty() and detail_txt.is_empty():
		intent_title_label.text = tr("ui.unit_info.intent_unknown")
		intent_detail_label.visible = false
	elif short_txt.is_empty():
		intent_title_label.text = detail_txt
		intent_detail_label.visible = false
	elif detail_txt.is_empty() or detail_txt.to_upper() == short_txt.to_upper():
		intent_title_label.text = short_txt
		intent_detail_label.visible = false
	else:
		intent_title_label.text = short_txt
		intent_detail_label.text = detail_txt
		intent_detail_label.visible = true
	intent_box.visible = true

	# Passives jako chipy
	_clear_container(passives_flow)
	var passives: PackedStringArray = PackedStringArray()
	if unit_node.has_method("get_enemy_passives_list"):
		passives = unit_node.get_enemy_passives_list()
	if passives.is_empty():
		passives_section.visible = false
	else:
		passives_section.visible = true
		for passive_text in passives:
			passives_flow.add_child(_make_chip(passive_text, COLOR_CHIP_BG, COLOR_MUTED))

	# Alerts / counters — jen když něco je
	_clear_container(alerts_flow)
	var alerts: PackedStringArray = PackedStringArray()
	if unit_node.has_method("get_status_counters_list"):
		alerts = unit_node.get_status_counters_list()
	if alerts.is_empty():
		alerts_section.visible = false
	else:
		alerts_section.visible = true
		for alert_text in alerts:
			alerts_flow.add_child(_make_chip(alert_text, COLOR_CHIP_ALERT_BG, COLOR_CHIP_ALERT_FG))

func _update_status_display(unit_node: Node) -> void:
	_clear_container(status_effects_list)
	if not (unit_node is Unit) or unit_node.active_statuses.is_empty():
		status_section.visible = false
		return

	status_section.visible = true
	for status_id in unit_node.active_statuses:
		var status_data = unit_node.active_statuses[status_id]
		status_effects_list.add_child(_create_status_row(status_id, status_data))

func _create_status_row(status_id: String, status_data: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _get_status_icon(status_id)
	row.add_child(icon_rect)

	var label = Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var info = _get_status_display_info(status_id, status_data)
	label.text = info.text
	label.add_theme_color_override("font_color", info.color)
	row.add_child(label)
	return row

func _make_chip(text: String, bg: Color, fg: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
	label.add_theme_color_override("font_color", fg)
	chip.add_child(label)
	return chip

func _clear_container(container: Node) -> void:
	if not container:
		return
	var children := container.get_children()
	for child in children:
		container.remove_child(child)
		child.queue_free()

func _get_status_icon(status_id: String) -> Texture2D:
	match status_id:
		"burning":
			return ICON_BURNING
		"chilled":
			return ICON_CHILLED
		"shocked":
			return ICON_SHOCKED
		"frozen":
			return ICON_FROZEN
		"entangled":
			return ICON_ENTANGLED
		"monk_blessing":
			return ICON_MONK_BLESSING
		"regeneration":
			return ICON_REGENERATION
		"Slow":
			return ICON_SLOW
		"vulnerable":
			return ICON_VULNERABLE
		"aiming":
			return ICON_AIMING
		"aura_devotion", "aura_devotion_plus":
			return ICON_AURA_DEVOTION
		"weakness":
			return ICON_WEAKNESS
		"thorns":
			return ICON_THORNS
		"poison":
			return ICON_POISON
		"rage":
			return ICON_RAGE
		"defensive_stance":
			return ICON_BLOCK
		"leech":
			return ICON_LEECH
	return ICON_DEFAULT

func _get_status_display_info(status_id: String, status_data: Dictionary) -> Dictionary:
	var dur = status_data.get("duration", 0)
	var val = status_data.get("value", 0)

	match status_id:
		"aiming":
			return {"text": TranslationHelper.tr_format("status.label.aiming", {"value": val}), "color": Color.ORANGE}
		"aura_devotion":
			return {"text": TranslationHelper.tr_format("status.label.aura_devotion", {"value": val}), "color": Color.LIGHT_BLUE}
		"aura_devotion_plus":
			return {"text": TranslationHelper.tr_format("status.label.aura_devotion_plus", {"value": val}), "color": Color.CYAN}
		"burning":
			return {"text": "%d DMG (%d t)" % [val, dur], "color": Color.ORANGE_RED}
		"chilled":
			return {"text": "-%d Move (%d t)" % [val, dur], "color": Color.LIGHT_BLUE}
		"shocked":
			return {"text": "Shocked (%d t)" % dur, "color": Color.YELLOW}
		"frozen":
			return {"text": "FROZEN! (%d t)" % dur, "color": Color.DEEP_SKY_BLUE}
		"entangled":
			return {"text": "Rooted (%d t)" % dur, "color": Color.DARK_GREEN}
		"monk_blessing":
			return {"text": "+%d DMG (%d t)" % [val, dur], "color": Color.GOLD}
		"regeneration":
			return {"text": "+%d HP/t (%d t)" % [val, dur], "color": Color.GREEN}
		"Slow":
			return {"text": "%d Move (%d t)" % [val, dur], "color": Color.SLATE_GRAY}
		"vulnerable":
			return {"text": "+50%% DMG (%d t)" % dur, "color": Color.INDIAN_RED}
		"defensive_stance":
			return {"text": tr("status.defensive_stance.short"), "color": Color.STEEL_BLUE}
		"consecrated_weapon":
			return {"text": TranslationHelper.tr_format("status.consecrated_weapon", {"value": val}), "color": Color.GOLD}
		"weakness":
			return {"text": "-%d DMG (%d t)" % [val, dur], "color": Color.DIM_GRAY}
		"thorns":
			return {"text": "%d reflect (%d t)" % [val, dur], "color": Color.DARK_ORANGE}
		"poison":
			return {"text": "%d DMG/t (%d t)" % [val, dur], "color": Color.PURPLE}
		"rage":
			return {"text": "+%d DMG (%d t)" % [val, dur], "color": Color.RED}
		_:
			var display_name = status_id.replace("_", " ").capitalize()
			return {"text": "%s %d (%d t)" % [display_name, val, dur], "color": Color.WHITE}

func hide_panel() -> void:
	visible = false
	_content_fingerprint = ""
	_fit_queued = false

func update_from_player_data() -> void:
	var unit_data = PlayerData.selected_subclass.specific_unit_data
	if not is_instance_valid(unit_data):
		hide_panel()
		return
	_content_fingerprint = ""
	name_label.text = unit_data.get_localized_name()
	class_label.visible = false
	hp_brief_label.visible = false
	hp_slot.visible = false
	block_slot.visible = true
	block_label.text = TranslationHelper.tr_format("ui.unit_info.block", {"value": 0})
	block_label.tooltip_text = ""
	energy_slot.visible = true
	energy_label.text = TranslationHelper.tr_format(
		"ui.unit_info.energy",
		{"current": PlayerData.current_energy, "max": PlayerData.max_energy}
	)
	attack_slot.visible = false
	vitals_row.visible = true
	enemy_section.visible = false
	status_section.visible = false
	_clear_container(status_effects_list)
	_clear_container(passives_flow)
	_clear_container(alerts_flow)
	show()
	_queue_fit_panel_height()

func update_energy_display() -> void:
	"""Aktualizuje jen zobrazení energie (volá se při změně energie u hráče)."""
	if visible and energy_slot.visible and energy_label:
		energy_label.text = TranslationHelper.tr_format(
			"ui.unit_info.energy",
			{"current": PlayerData.current_energy, "max": PlayerData.max_energy}
		)

func _build_fingerprint(unit_node: Node) -> String:
	var parts: PackedStringArray = []
	parts.append(str(unit_node.get_instance_id()))
	parts.append(str(unit_node.current_health))
	parts.append(str(unit_node.current_block))
	parts.append(str(unit_node.retained_block))
	if unit_node.has_method("get_intent_short_text"):
		parts.append(str(unit_node.get_intent_short_text()))
	if unit_node.has_method("get_intent_detail_text"):
		parts.append(str(unit_node.get_intent_detail_text()))
	elif unit_node is Unit:
		parts.append(str(unit_node.current_intent_text))
	if unit_node is Unit:
		parts.append(str(unit_node.active_statuses))
	if unit_node.has_method("get_status_counters_list"):
		parts.append(",".join(unit_node.get_status_counters_list()))
	if unit_node.get_unit_data().faction == UnitData.Faction.PLAYER:
		parts.append("%d/%d" % [PlayerData.current_energy, PlayerData.max_energy])
	return "|".join(parts)

func _queue_fit_panel_height() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	if is_inside_tree():
		get_tree().process_frame.connect(_fit_panel_height, CONNECT_ONE_SHOT)
	else:
		call_deferred("_fit_panel_height")

func _fit_panel_height() -> void:
	"""Auto-expand panel to content height. Scroll only when viewport cap is hit."""
	_fit_queued = false
	if not visible or not is_instance_valid(scroll_container) or not is_instance_valid(content_root):
		return
	if not _pins_cached:
		_cache_layout_pins()

	var content_width := PANEL_WIDTH - 24.0
	_set_wrap_width(content_root, content_width)
	content_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Measure natural content height (no artificial scroll min-height).
	scroll_container.scroll_vertical = 0
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.custom_minimum_size = Vector2(content_width, 0)

	# One more frame so chips/labels finish layout before measuring.
	if is_inside_tree():
		await get_tree().process_frame
	if not visible or not is_instance_valid(content_root):
		return

	var content_h: float = content_root.get_combined_minimum_size().y
	var desired: float = content_h + PANEL_MARGIN_V
	var max_h: float = _get_max_panel_height()
	var height: float = clampf(desired, MIN_PANEL_HEIGHT, max_h)
	var needs_scroll: bool = desired > max_h + 0.5

	_apply_anchored_height(height)

	# Scroll fills the panel; content stays shrink so overflow can scroll.
	scroll_container.custom_minimum_size = Vector2.ZERO
	if needs_scroll:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _apply_anchored_height(height: float) -> void:
	"""Bottom-anchored: pin bottom/sides, grow/shrink top to match content height."""
	if not _pins_cached:
		_cache_layout_pins()
	if anchor_bottom < 0.99:
		custom_minimum_size = Vector2(PANEL_WIDTH, height)
		return

	offset_bottom = _pinned_offset_bottom
	offset_top = _pinned_offset_bottom - height

	if anchor_right >= 0.99 and anchor_left >= 0.99:
		offset_right = minf(_pinned_offset_right, -RIGHT_PILE_SAFE_MARGIN)
		offset_left = offset_right - PANEL_WIDTH
	else:
		offset_left = _pinned_offset_left
		offset_right = _pinned_offset_right

	custom_minimum_size = Vector2(PANEL_WIDTH, height)

func _set_wrap_width(node: Node, width: float) -> void:
	if node is Label:
		var label := node as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			label.custom_minimum_size.x = width
	elif node is RichTextLabel:
		var rtl := node as RichTextLabel
		rtl.custom_minimum_size.x = width
	elif node is HFlowContainer:
		(node as HFlowContainer).custom_minimum_size.x = width
	for child in node.get_children():
		_set_wrap_width(child, width)

func _get_max_panel_height() -> float:
	"""Max height = from pinned bottom up to GlobalUI / top safe line (full auto-expand room)."""
	if not is_inside_tree():
		return 420.0
	var viewport_h := get_viewport().get_visible_rect().size.y
	var top_safe := TOP_SAFE_MARGIN
	if Engine.is_editor_hint():
		top_safe = VIEWPORT_MARGIN
	else:
		var gm = get_node_or_null("/root/GameManager")
		if gm == null or not is_instance_valid(gm.global_ui_instance) or not gm.global_ui_instance.visible:
			top_safe = VIEWPORT_MARGIN
	# offset_bottom is negative from bottom; available height above that pin.
	var available: float = viewport_h + _pinned_offset_bottom - top_safe
	return maxf(MIN_PANEL_HEIGHT, available)
