# Soubor: res://scenes/ui/UnitInfoPanel.gd
# Kompaktní info panel (enemy hover / player). HP a intent jsou na gridu.
# Panel se AUTOMATICKY roztáhne podle obsahu; scroll jen když už není kam růst.
extends PanelContainer

const PANEL_WIDTH := 260.0
const PANEL_MARGIN_V := 20.0 # top+bottom content margins
const VIEWPORT_MARGIN := 12.0
const TOP_SAFE_MARGIN := 90.0
## Keep clear of draw/discard piles anchored on the far-right edge.
const RIGHT_PILE_SAFE_MARGIN := 88.0
## Mezera mezi spodkem panelu a hoverem karty, která do něj horizontálně zasahuje.
const HAND_CLEAR_GAP := 8.0
const STATUS_ICON_SIZE := 16
const CHIP_FONT_SIZE := 20
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
@onready var passives_flow: VBoxContainer = %PassivesFlow
@onready var alerts_section: VBoxContainer = %AlertsSection
@onready var alerts_header: Label = %AlertsHeader
@onready var alerts_flow: HFlowContainer = %AlertsFlow
@onready var status_section: VBoxContainer = %StatusSection
@onready var status_header: Label = %StatusHeader
@onready var status_effects_list: VBoxContainer = %StatusEffectsList
@onready var who_header: Label = %WhoHeader
@onready var who_description: Label = %WhoDescription

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
	var hand := get_parent().get_node_or_null("PlayerHandUI") if get_parent() else null
	if hand and hand.has_signal("hand_layout_changed") and not hand.hand_layout_changed.is_connected(_queue_fit_panel_height):
		hand.hand_layout_changed.connect(_queue_fit_panel_height)
	hide_panel()


func _cache_layout_pins() -> void:
	"""Lock bottom + side slots from the scene. Top is free to grow upward."""
	_pinned_offset_bottom = offset_bottom
	_pinned_offset_left = offset_left
	_pinned_offset_right = offset_right
	_pins_cached = true

func _apply_section_headers() -> void:
	if who_header:
		who_header.text = tr("ui.unit_info.section.who")
	if intent_header:
		intent_header.text = tr("ui.unit_info.section.intent")
	if passives_header:
		passives_header.text = tr("ui.unit_info.section.passives")
	if alerts_header:
		alerts_header.visible = false
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
	_set_who_blurb(data)

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
		var atk_value: int = data.attack_damage
		if unit_node is Unit and unit_node.has_method("get_telegraphed_attack_damage"):
			atk_value = unit_node.get_telegraphed_attack_damage()
		attack_label.text = TranslationHelper.tr_format("ui.unit_info.atk_brief", {"value": atk_value})
		if unit_node is Unit and unit_node.get_bonus_attack_damage() > 0:
			attack_label.tooltip_text = TranslationHelper.tr_format(
				"ui.unit_info.atk_bonus_tooltip",
				{
					"total": atk_value,
					"base": data.attack_damage,
					"bonus": unit_node.get_bonus_attack_damage(),
				}
			)
		else:
			attack_label.tooltip_text = ""

	# Block: u nepřítele jen když > 0 (HP bar už je na gridu)
	if unit_node.current_block > 0:
		block_slot.visible = true
		var kept_block: int = unit_node.retained_block + unit_node.carried_block
		if kept_block > 0:
			block_label.text = TranslationHelper.tr_format(
				"ui.unit_info.block_retained",
				{"current": unit_node.current_block, "retained": kept_block}
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

	var intent_pair := _resolve_intent_texts(unit_node)
	var short_txt: String = intent_pair.short_text
	var detail_txt: String = intent_pair.detail_text

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

	_clear_container(passives_flow)
	var abilities: Array = []
	if unit_node.has_method("get_enemy_ability_entries"):
		abilities = unit_node.get_enemy_ability_entries()
	elif unit_node.has_method("get_enemy_passives_list"):
		for passive_text in unit_node.get_enemy_passives_list():
			abilities.append({"title": "", "text": passive_text})
	if abilities.is_empty():
		passives_section.visible = false
	else:
		passives_section.visible = true
		for ability in abilities:
			if typeof(ability) != TYPE_DICTIONARY:
				continue
			passives_flow.add_child(_make_ability_row(str(ability.get("title", "")), str(ability.get("text", ""))))

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

## Resolves up to 2 intents for the panel.
## Preferred Unit API: get_intent_entries() -> Array of {short_text, text} (max 2 used).
## Fallback: primary get_intent_* + optional get_secondary_intent_* methods.
func _resolve_intent_texts(unit_node: Node) -> Dictionary:
	var entries: Array = _collect_intent_entries(unit_node)
	var shorts: PackedStringArray = PackedStringArray()
	var details: PackedStringArray = PackedStringArray()
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var short_txt := str(entry.get("short_text", "")).strip_edges()
		var detail_txt := _strip_intent_detail_prefix(str(entry.get("text", "")).strip_edges())
		if short_txt.is_empty() and detail_txt.is_empty():
			continue
		if not short_txt.is_empty():
			shorts.append(short_txt)
		if not detail_txt.is_empty():
			details.append(detail_txt)
	return {
		"short_text": " → ".join(shorts),
		"detail_text": " → ".join(details),
	}

func _collect_intent_entries(unit_node: Node) -> Array:
	if unit_node.has_method("get_intent_entries"):
		var raw = unit_node.get_intent_entries()
		if typeof(raw) == TYPE_ARRAY and not raw.is_empty():
			var capped: Array = []
			for i in mini(raw.size(), 2):
				capped.append(raw[i])
			return capped

	var primary := _read_primary_intent_entry(unit_node)
	var secondary := _read_secondary_intent_entry(unit_node)
	var out: Array = []
	if not primary.is_empty():
		out.append(primary)
	if not secondary.is_empty():
		out.append(secondary)
	return out

func _read_primary_intent_entry(unit_node: Node) -> Dictionary:
	var short_txt := ""
	var detail_txt := ""
	if unit_node.has_method("get_intent_short_text"):
		short_txt = str(unit_node.get_intent_short_text()).strip_edges()
	if unit_node.has_method("get_intent_detail_text"):
		detail_txt = str(unit_node.get_intent_detail_text()).strip_edges()
	elif unit_node.has_method("get_intent_display_text"):
		detail_txt = str(unit_node.get_intent_display_text()).strip_edges()
	if short_txt.is_empty() and detail_txt.is_empty():
		return {}
	return {"short_text": short_txt, "text": detail_txt}

func _read_secondary_intent_entry(unit_node: Node) -> Dictionary:
	var short_txt := ""
	var detail_txt := ""
	if unit_node.has_method("get_secondary_intent_short_text"):
		short_txt = str(unit_node.get_secondary_intent_short_text()).strip_edges()
	if unit_node.has_method("get_secondary_intent_detail_text"):
		detail_txt = str(unit_node.get_secondary_intent_detail_text()).strip_edges()
	elif unit_node.has_method("get_secondary_intent_display_text"):
		detail_txt = str(unit_node.get_secondary_intent_display_text()).strip_edges()
	elif unit_node.has_method("get_secondary_intent_text"):
		detail_txt = str(unit_node.get_secondary_intent_text()).strip_edges()
	if short_txt.is_empty() and detail_txt.is_empty():
		return {}
	return {"short_text": short_txt, "text": detail_txt}

func _strip_intent_detail_prefix(detail_txt: String) -> String:
	# Strip redundant "Next Move:" — section header already says NEXT.
	for prefix in ["Next Move: ", "Další tah: ", "Next: "]:
		if detail_txt.begins_with(prefix):
			return detail_txt.substr(prefix.length()).strip_edges()
	return detail_txt

func _update_status_display(unit_node: Node) -> void:
	_clear_container(status_effects_list)
	if not (unit_node is Unit) or unit_node.active_statuses.is_empty():
		status_section.visible = false
		return

	status_section.visible = true
	for status_id in unit_node.active_statuses:
		var status_data = unit_node.active_statuses[status_id]
		status_effects_list.add_child(_create_status_row(status_id, status_data))

func _create_status_row(status_id: String, status_data: Dictionary) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 1)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _get_status_icon(status_id)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)

	var info := _get_status_display_info(status_id, status_data)
	var label := Label.new()
	_style_info_label(label, 20, info.color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = info.text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	wrap.add_child(row)

	var sentence := _status_sentence(status_id, status_data)
	if not sentence.is_empty() and sentence != info.text:
		var sentence_label := Label.new()
		_style_info_label(sentence_label, 16, COLOR_MUTED)
		sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sentence_label.text = sentence
		sentence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(sentence_label)
	var tip: String = sentence if not sentence.is_empty() else str(info.text)
	wrap.tooltip_text = tip
	return wrap

func _set_who_blurb(data: UnitData) -> void:
	if who_header:
		who_header.visible = true
		who_header.text = tr("ui.unit_info.section.who")
	if who_description == null or data == null:
		return
	var text := data.get_localized_description().strip_edges()
	if text.is_empty() or text == data.description or text == "Popis jednotky." or text == "Unit description.":
		who_description.visible = false
		who_description.text = ""
		return
	who_description.visible = true
	who_description.text = text

func _make_ability_row(title: String, sentence: String) -> Control:
	var body := sentence.strip_edges()
	var heading := title.strip_edges()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = body if heading.is_empty() else "%s\n%s" % [heading, body]
	if not heading.is_empty():
		var title_label := Label.new()
		_style_info_label(title_label, 18, Color(1, 0.92, 0.55, 1))
		title_label.text = heading
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(title_label)
	if not body.is_empty():
		var text_label := Label.new()
		_style_info_label(text_label, 17, COLOR_MUTED)
		text_label.text = body
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text_label)
	return box

func _style_info_label(label: Label, font_size: int, color: Color) -> void:
	if name_label:
		var font := name_label.get_theme_font("font")
		if font:
			label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _status_sentence(status_id: String, status_data: Dictionary) -> String:
	var dur := int(status_data.get("duration", 0))
	var val := int(status_data.get("value", 0))
	var amount := absi(val)
	var sentence_key := "status.sentence." + status_id.to_lower()
	var from_key := TranslationHelper.tr_format(sentence_key, {"value": amount, "duration": dur})
	if from_key != sentence_key:
		return from_key
	var keyword_id := _keyword_id_for_status(status_id)
	if keyword_id != "" and has_node("/root/KeywordManager") and KeywordManager.KEYWORDS.has(keyword_id):
		return KeywordManager.get_keyword_description(keyword_id)
	var long_key := _long_status_key(status_id)
	if long_key != "":
		var long_text := TranslationHelper.tr_format(long_key, {"value": val, "duration": dur})
		if long_text != long_key:
			return long_text
	return ""

func _keyword_id_for_status(status_id: String) -> String:
	match status_id:
		"burning", "chilled", "frozen", "poison", "vulnerable", "aiming", "regeneration", "taunted", "consecrated_weapon", "aura_devotion":
			return status_id
		_:
			return ""

func _long_status_key(status_id: String) -> String:
	match status_id:
		"defensive_stance", "fury", "fury_engine", "radiance", "holy_edge", "radiance_vulnerable", "block_on_attack", "block_on_attack_carry":
			return "status." + status_id
		_:
			return ""

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
	return StatusIcons.get_icon(status_id)

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
		"block_on_attack":
			return {"text": TranslationHelper.tr_format("status.block_on_attack", {"value": val}), "color": Color.LIGHT_BLUE}
		"fury_engine":
			return {"text": TranslationHelper.tr_format("status.fury_engine", {"value": val}), "color": Color.INDIAN_RED}
		"fury":
			return {"text": TranslationHelper.tr_format("status.fury", {"value": val}), "color": Color.ORANGE_RED}
		"radiance":
			return {"text": TranslationHelper.tr_format("status.radiance", {"value": val}), "color": Color.GOLD}
		"radiance_vulnerable":
			return {"text": TranslationHelper.tr_format("status.radiance_vulnerable", {"value": val}), "color": Color.GOLD}
		"holy_edge":
			return {"text": TranslationHelper.tr_format("status.holy_edge", {"value": val}), "color": Color.GOLD}
		"defensive_stance_turn":
			return {"text": tr("status.defensive_stance_turn.short"), "color": Color.STEEL_BLUE}
		"block_on_attack_carry":
			return {"text": tr("status.block_on_attack_carry"), "color": Color.LIGHT_BLUE}
		"burning":
			return {"text": TranslationHelper.tr_format("status.label.burning", {"value": val}), "color": Color.ORANGE_RED}
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
		"regeneration_permanent":
			return {"text": "+%d HP/t" % val, "color": Color.GREEN}
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
			return {"text": "-25%% DMG (%d t)" % dur, "color": Color.DIM_GRAY}
		"silenced":
			return {"text": tr("status.float.silence") + " (%d t)" % dur, "color": Color(0.62, 0.45, 1.0)}
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
	_set_who_blurb(unit_data)
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
	parts.append(str(unit_node.carried_block))
	var intent_pair := _resolve_intent_texts(unit_node)
	parts.append(intent_pair.short_text)
	parts.append(intent_pair.detail_text)
	if unit_node is Unit:
		parts.append(str(unit_node.active_statuses))
		parts.append(str(unit_node.get_bonus_attack_damage()))
	if unit_node.has_method("get_enemy_ability_entries"):
		for ability in unit_node.get_enemy_ability_entries():
			if typeof(ability) == TYPE_DICTIONARY:
				parts.append(str(ability.get("text", "")))
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
	var bottom_offset: float = _bottom_offset_clear_of_hand()
	var max_h: float = _get_max_panel_height(bottom_offset)
	var height: float = clampf(desired, MIN_PANEL_HEIGHT, max_h)
	var needs_scroll: bool = desired > max_h + 0.5

	_apply_anchored_height(height, bottom_offset)

	# Scroll fills the panel; content stays shrink so overflow can scroll.
	scroll_container.custom_minimum_size = Vector2.ZERO
	if needs_scroll:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _apply_anchored_height(height: float, bottom_offset: float) -> void:
	"""Bottom-anchored: pin bottom/sides, grow/shrink top to match content height."""
	if not _pins_cached:
		_cache_layout_pins()
	if anchor_bottom < 0.99:
		custom_minimum_size = Vector2(PANEL_WIDTH, height)
		return

	offset_bottom = bottom_offset
	offset_top = bottom_offset - height

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

func _bottom_offset_clear_of_hand() -> float:
	"""Zvedne spodní pin jen když vějíř zasahuje do X panelu. Jinak zůstane u spodní hrany."""
	if anchor_bottom < 0.99 or not is_inside_tree():
		return _pinned_offset_bottom
	var hand := get_parent().get_node_or_null("PlayerHandUI") if get_parent() else null
	if hand == null or not hand.has_method("get_fan_top_global_y"):
		return _pinned_offset_bottom
	var span := _panel_horizontal_span()
	var fan_top: float = hand.get_fan_top_global_y(span.x, span.y)
	if fan_top >= 1.0e8:
		return _pinned_offset_bottom
	var viewport_h := get_viewport().get_visible_rect().size.y
	return minf(_pinned_offset_bottom, fan_top - HAND_CLEAR_GAP - viewport_h)

func _panel_horizontal_span() -> Vector2:
	var viewport_w := get_viewport().get_visible_rect().size.x
	if anchor_right >= 0.99 and anchor_left >= 0.99:
		var right := viewport_w + minf(_pinned_offset_right, -RIGHT_PILE_SAFE_MARGIN)
		return Vector2(right - PANEL_WIDTH, right)
	return Vector2(viewport_w * anchor_left + _pinned_offset_left, viewport_w * anchor_right + _pinned_offset_right)

func _get_max_panel_height(bottom_offset: float) -> float:
	"""Max height = from the (possibly lifted) bottom up to GlobalUI / top safe line."""
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
	var available: float = viewport_h + bottom_offset - top_safe
	return maxf(MIN_PANEL_HEIGHT, available)
