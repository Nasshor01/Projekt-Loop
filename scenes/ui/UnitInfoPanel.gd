# Soubor: res://scenes/ui/UnitInfoPanel.gd
# Kompaktní info panel (enemy hover / player). HP a intent jsou na gridu.
# Panel se AUTOMATICKY roztáhne podle obsahu; scroll jen když už není kam růst.
extends PanelContainer

const PANEL_WIDTH := 340.0
const FONT_BODY := 20
const FONT_TITLE := 22
const PANEL_MARGIN_V := 28.0 # card padding above and below the content
const CONTENT_PAD := 32.0 # left+right margin plus border
const VIEWPORT_MARGIN := 12.0
const TOP_SAFE_MARGIN := 90.0
## Keep clear of draw/discard piles anchored on the far-right edge.
const RIGHT_PILE_SAFE_MARGIN := 88.0
## Mezera mezi spodkem panelu a hoverem karty, která do něj horizontálně zasahuje.
const HAND_CLEAR_GAP := 8.0
const STATUS_ICON_SIZE := 20
const CHIP_FONT_SIZE := 24
const MIN_PANEL_HEIGHT := 80.0

const COLOR_MUTED := Color(0.9, 0.88, 0.8, 1)
const COLOR_CHIP_BG := Color(0.14, 0.16, 0.22, 0.95)
const COLOR_CHIP_ALERT_BG := Color(0.28, 0.14, 0.12, 0.95)
const COLOR_CHIP_ALERT_FG := Color(1.0, 0.72, 0.55, 1)

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var content_root: VBoxContainer = %ContentRoot
@onready var name_label: Label = %NameLabel
@onready var class_label: Label = %ClassLabel
@onready var hp_brief_label: Label = %HpBriefLabel
@onready var stats_label: Label = %StatsLine
@onready var header_rule: HSeparator = %HeaderRule
@onready var kit_rule: HSeparator = %KitRule
@onready var intent_list: VBoxContainer = %IntentList
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
@onready var alerts_flow: VBoxContainer = %AlertsFlow
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
		who_header.visible = false
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
	_fill_hp_brief(unit_node, data)
	_fill_stats_line(unit_node, data)

	# --- Header: class. HP and the stats line sit beside / under the name. ---
	class_label.visible = false
	if is_enemy:
		hp_slot.visible = false
	else:
		class_label.visible = false

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
		attack_slot.visible = false
		if stats_label and unit_node is Unit and unit_node.get_bonus_attack_damage() > 0:
			var atk_value: int = unit_node.get_telegraphed_attack_damage() if unit_node.has_method("get_telegraphed_attack_damage") else data.attack_damage
			stats_label.tooltip_text = TranslationHelper.tr_format(
				"ui.unit_info.atk_bonus_tooltip",
				{
					"total": atk_value,
					"base": data.attack_damage,
					"bonus": unit_node.get_bonus_attack_damage(),
				}
			)
		elif stats_label:
			stats_label.tooltip_text = ""

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
	_sync_rules()
	_queue_fit_panel_height()

func _update_enemy_details(unit_node: Node, data: UnitData) -> void:
	if data.faction != UnitData.Faction.ENEMY:
		enemy_section.visible = false
		return
	enemy_section.visible = true

	_fill_intent_rows(unit_node)
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
			var named := _split_named_sentence(str(ability.get("title", "")), str(ability.get("text", "")))
			passives_flow.add_child(_make_ability_row(named.title, named.text))

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
			alerts_flow.add_child(_make_note(alert_text))
	_sync_rules()

func _fill_hp_brief(unit_node: Node, data: UnitData) -> void:
	if hp_brief_label == null or data == null:
		return
	var current := 0
	var max_hp := data.max_health
	if unit_node != null and is_instance_valid(unit_node):
		current = int(unit_node.current_health)
		if data.faction == UnitData.Faction.PLAYER and unit_node.has_method("_is_local_player") and unit_node._is_local_player():
			max_hp = PlayerData.max_hp
	else:
		current = PlayerData.current_hp
		max_hp = PlayerData.max_hp
	hp_brief_label.visible = true
	hp_brief_label.text = TranslationHelper.tr_format(
		"ui.unit_info.hp_header",
		{"current": current, "max": max_hp}
	)

func _fill_stats_line(unit_node: Node, data: UnitData) -> void:
	if stats_label == null or data == null:
		return
	var atk := data.attack_damage
	if unit_node is Unit and unit_node.has_method("get_telegraphed_attack_damage"):
		atk = unit_node.get_telegraphed_attack_damage()
	var move := data.movement_range
	if unit_node != null and unit_node.has_method("get_current_movement_range"):
		move = unit_node.get_current_movement_range()
	stats_label.visible = true
	stats_label.text = TranslationHelper.tr_format(
		"ui.unit_info.stats_line",
		{
			"atk": atk,
			"move": move,
			"range": data.attack_range,
		}
	)

func _sync_rules() -> void:
	if header_rule:
		header_rule.visible = enemy_section != null and enemy_section.visible
	if kit_rule:
		kit_rule.visible = passives_section != null and passives_section.visible

func _fill_intent_rows(unit_node: Node) -> void:
	if intent_list:
		_clear_container(intent_list)
	var entries := _collect_intent_entries(unit_node)
	if entries.is_empty():
		if intent_title_label:
			intent_title_label.visible = true
			intent_title_label.text = tr("ui.unit_info.intent_unknown")
		if intent_detail_label:
			intent_detail_label.visible = false
		return
	if intent_title_label:
		intent_title_label.visible = false
	if intent_detail_label:
		intent_detail_label.visible = false
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY or intent_list == null:
			continue
		intent_list.add_child(_make_intent_row(unit_node, entry))

func _make_intent_row(unit_node: Node, entry: Dictionary) -> Control:
	var presented := _present_intent(unit_node, entry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = presented.sentence

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unit_node.has_method("get_intent_icon"):
		icon_rect.texture = unit_node.get_intent_icon(str(presented.id))
	row.add_child(icon_rect)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 1)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label := Label.new()
	_style_info_label(title_label, FONT_TITLE, Color(1, 0.92, 0.55, 1))
	title_label.text = presented.title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(title_label)

	if not str(presented.sentence).is_empty():
		var sentence_label := Label.new()
		_style_info_label(sentence_label, FONT_BODY, COLOR_MUTED)
		sentence_label.text = presented.sentence
		sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(sentence_label)
	if not str(presented.again).is_empty():
		var again_label := Label.new()
		_style_info_label(again_label, FONT_BODY, Color(0.95, 0.78, 0.42, 1))
		again_label.text = presented.again
		again_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(again_label)
	row.add_child(text_col)
	return row

func _present_intent(unit_node: Node, entry: Dictionary) -> Dictionary:
	var intent_id := str(entry.get("id", "")).strip_edges()
	var short_txt := str(entry.get("short_text", "")).strip_edges()
	var detail_txt := _strip_intent_detail_prefix(str(entry.get("text", "")).strip_edges())
	var countdown := int(entry.get("countdown", 0))
	var title := ""
	var sentence := ""
	var again := ""
	for sep in [":", " — ", " – "]:
		var idx := detail_txt.find(sep)
		if idx > 0:
			title = detail_txt.substr(0, idx).strip_edges()
			sentence = _capitalize_sentence(detail_txt.substr(idx + sep.length()).strip_edges())
			break
	if title.is_empty():
		title = _intent_title(intent_id, short_txt)
	if sentence.is_empty() or _is_bare_intent_name(sentence, short_txt, title):
		sentence = _generic_intent_sentence(unit_node, intent_id, short_txt, detail_txt)
	if countdown > 0 and not _sentence_has_countdown(sentence):
		again = TranslationHelper.tr_format("ui.unit_info.intent_again", {"value": countdown})
	if title.is_empty():
		title = sentence
		sentence = ""
	return {"id": intent_id, "title": title, "sentence": sentence, "again": again}

func _intent_title(intent_id: String, short_txt: String) -> String:
	if not _is_bare_intent_name(short_txt, "", "") and not _is_number_token(short_txt):
		return short_txt
	match intent_id:
		"move":
			return tr("MOVE")
		"heal":
			return tr("ui.unit_info.intent_name.heal")
		"buff", "block", "defend":
			return tr("ui.unit_info.intent_name.block")
		"attack", "slam", "pierce", "gust", "windup", "bite", "aiming", "rush", "meteor":
			return tr("ATTACK")
		_:
			if _is_number_token(short_txt):
				return tr("ATTACK")
			return short_txt if not short_txt.is_empty() else tr("ATTACK")

func _generic_intent_sentence(unit_node: Node, intent_id: String, short_txt: String, detail_txt: String) -> String:
	if intent_id == "block" or intent_id == "defend":
		return _block_intent_sentence(short_txt, detail_txt)
	if not _is_bare_intent_name(detail_txt, short_txt, "") and not _is_number_token(detail_txt) and detail_txt.length() > 3:
		return _capitalize_sentence(detail_txt)
	match intent_id:
		"move":
			return tr("ui.unit_info.intent.move")
		"heal":
			return tr("ui.unit_info.intent.heal")
		"buff":
			return tr("ui.unit_info.intent.buff")
		"block", "defend":
			return _block_intent_sentence(short_txt, detail_txt)
		_:
			var amount := _intent_damage_amount(unit_node, short_txt)
			if amount > 0:
				return TranslationHelper.tr_format("ui.unit_info.intent.attack", {"value": amount})
			return tr("ui.unit_info.intent.attack_plain")

func _block_intent_sentence(short_txt: String, detail_txt: String) -> String:
	var source := short_txt if short_txt.is_valid_int() else detail_txt
	var digits := ""
	for i in source.length():
		if source[i].is_valid_int():
			digits += source[i]
		elif not digits.is_empty():
			break
	if digits.is_valid_int() and int(digits) > 0:
		return TranslationHelper.tr_format("ui.unit_info.intent.block", {"value": int(digits)})
	return tr("ui.unit_info.intent.block_plain")

func _intent_damage_amount(unit_node: Node, short_txt: String) -> int:
	if _is_number_token(short_txt):
		return int(short_txt.trim_prefix("+").trim_prefix("-"))
	if unit_node is Unit and unit_node.has_method("get_telegraphed_attack_damage"):
		return unit_node.get_telegraphed_attack_damage()
	return 0

func _is_bare_intent_name(text: String, short_txt: String, title: String) -> bool:
	var raw := text.strip_edges()
	if raw.is_empty() or _is_number_token(raw):
		return true
	var folded := raw.to_lower()
	var bare := [
		"attack", "útok", "utok", "move", "pohyb", "heal", "léčení", "leceni",
		"buff", "block", "blok", "defend", "obrana",
		tr("ATTACK").to_lower(), tr("MOVE").to_lower(),
	]
	if folded in bare:
		return true
	if not short_txt.is_empty() and folded == short_txt.strip_edges().to_lower():
		return true
	if not title.is_empty() and folded == title.strip_edges().to_lower():
		return true
	return false

func _sentence_has_countdown(sentence: String) -> bool:
	var folded := sentence.to_lower()
	return folded.contains("tah") or folded.contains("turn") or folded.contains("again")

func _is_number_token(text: String) -> bool:
	var raw := text.strip_edges().trim_prefix("+").trim_prefix("-")
	return raw.is_valid_int()

func _capitalize_sentence(text: String) -> String:
	var raw := text.strip_edges()
	if raw.is_empty():
		return ""
	return raw.substr(0, 1).to_upper() + raw.substr(1)

func _split_named_sentence(title: String, body: String) -> Dictionary:
	var heading := title.strip_edges()
	var sentence := body.strip_edges()
	if heading.is_empty():
		for sep in [":", " — ", " – "]:
			var idx := sentence.find(sep)
			if idx > 0:
				heading = sentence.substr(0, idx).strip_edges()
				sentence = _capitalize_sentence(sentence.substr(idx + sep.length()))
				break
	else:
		sentence = _capitalize_sentence(sentence)
	return {"title": heading, "text": sentence}

func _status_headline(status_id: String, status_data: Dictionary) -> String:
	var key := "status.name." + status_id.to_lower()
	var name := tr(key)
	if name == key:
		name = status_id.replace("_", " ").capitalize()
	var amount := absi(int(status_data.get("value", 0)))
	if amount > 0:
		return "%s %d" % [name, amount]
	return name

func _strip_repeated_name(headline: String, sentence: String) -> String:
	var raw := sentence.strip_edges()
	if raw.is_empty():
		return ""
	var name := headline.strip_edges()
	var space := name.find(" ")
	if space > 0:
		name = name.substr(0, space)
	for sep in [":", " — ", " – "]:
		var prefix: String = name + str(sep)
		if raw.to_lower().begins_with(prefix.to_lower()):
			return _capitalize_sentence(raw.substr(prefix.length()))
	return raw

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

func _create_status_row(status_id: String, status_data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _get_status_icon(status_id)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon_rect)

	var info := _get_status_display_info(status_id, status_data)
	var headline := _status_headline(status_id, status_data)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 1)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	_style_info_label(label, FONT_TITLE, info.color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = headline
	text_col.add_child(label)

	var sentence := _status_sentence(status_id, status_data)
	sentence = _strip_repeated_name(headline, sentence)
	if sentence.is_empty():
		var dur := int(status_data.get("duration", 0))
		if dur > 0:
			sentence = TranslationHelper.tr_format("ui.unit_info.status_turns", {"duration": dur})
	if not sentence.is_empty() and sentence != headline:
		var sentence_label := Label.new()
		_style_info_label(sentence_label, FONT_BODY, COLOR_MUTED)
		sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sentence_label.text = sentence
		text_col.add_child(sentence_label)
	row.add_child(text_col)
	var tip: String = sentence if not sentence.is_empty() else str(info.text)
	row.tooltip_text = tip
	return row

func _set_who_blurb(_data: UnitData) -> void:
	if who_header:
		who_header.visible = false
	if who_description:
		who_description.visible = false
		who_description.text = ""

func _make_ability_row(title: String, sentence: String) -> Control:
	var body := sentence.strip_edges()
	var heading := title.strip_edges()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = body if heading.is_empty() else "%s\n%s" % [heading, body]

	var bullet := Label.new()
	_style_info_label(bullet, FONT_TITLE, Color(0.95, 0.78, 0.42, 1))
	bullet.text = "•"
	row.add_child(bullet)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not heading.is_empty():
		var title_label := Label.new()
		_style_info_label(title_label, FONT_TITLE, Color(0.96, 0.93, 0.84, 1))
		title_label.text = heading
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(title_label)
	if not body.is_empty():
		var text_label := Label.new()
		_style_info_label(text_label, FONT_BODY, COLOR_MUTED)
		text_label.text = body
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text_label)
	row.add_child(box)
	return row

func _make_note(text: String) -> Label:
	var label := Label.new()
	_style_info_label(label, FONT_BODY, Color(1.0, 0.78, 0.55, 1))
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _style_info_label(label: Label, font_size: int, color: Color) -> void:
	if name_label:
		var font := name_label.get_theme_font("font")
		if font:
			label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("line_spacing", 4)
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
	_fill_hp_brief(null, unit_data)
	_fill_stats_line(null, unit_data)
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
	_sync_rules()
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
	for entry in _collect_intent_entries(unit_node):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		parts.append(str(entry.get("id", "")))
		parts.append(str(entry.get("short_text", "")))
		parts.append(str(entry.get("text", "")))
		parts.append(str(entry.get("countdown", 0)))
	if unit_node is Unit:
		parts.append(str(unit_node.active_statuses))
		parts.append(str(unit_node.get_bonus_attack_damage()))
		parts.append(str(unit_node.get_current_movement_range()))
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

	var content_width := _content_width()
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

func _content_width() -> float:
	var panel_w := PANEL_WIDTH
	if not (anchor_right >= 0.99 and anchor_left >= 0.99):
		panel_w = _pinned_offset_right - _pinned_offset_left
	if panel_w < 200.0:
		panel_w = PANEL_WIDTH
	return maxf(160.0, panel_w - CONTENT_PAD)

func _set_wrap_width(node: Node, width: float) -> void:
	if node is HBoxContainer:
		var box := node as HBoxContainer
		var reserved := 0.0
		var text_children: Array[Node] = []
		for child in box.get_children():
			if child is TextureRect or (child is Label and (child as Label).autowrap_mode == TextServer.AUTOWRAP_OFF):
				reserved += maxf((child as Control).custom_minimum_size.x, 16.0)
			else:
				text_children.append(child)
		var gaps := maxi(box.get_child_count() - 1, 0) * box.get_theme_constant("separation")
		var inner := maxf(80.0, width - reserved - float(gaps))
		for child in text_children:
			_set_wrap_width(child, inner)
		return
	if node is Label:
		var label := node as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			label.custom_minimum_size.x = width
	elif node is RichTextLabel:
		var rtl := node as RichTextLabel
		rtl.custom_minimum_size.x = width
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
