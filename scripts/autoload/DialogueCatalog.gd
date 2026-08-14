extends Node

## Spoken lines (tutorial, later village / events / bosses).
## Content: res://data/dialogue/dialogue.csv
## ID prefix = place: tutorial.*, village.*, event.*, boss.*
## UI chrome (buttons, menus) stays in translations.csv.
## Map-event choice text stays on EventData + translations.csv until it is spoken.

const CSV_PATH := "res://data/dialogue/dialogue.csv"

var _speakers: Dictionary = {}
var _has_action: Dictionary = {}
var _known: Dictionary = {}

func _ready() -> void:
	_load_csv()

func has_line(id: String) -> bool:
	return _known.has(id)

func line(id: String) -> Dictionary:
	if not _known.has(id):
		push_warning("DialogueCatalog: unknown line id '%s'" % id)
	var speaker_key := String(_speakers.get(id, ""))
	var speaker := tr(speaker_key) if not speaker_key.is_empty() else ""
	return {
		"id": id,
		"speaker_key": speaker_key,
		"speaker": speaker,
		"body": tr(_body_key(id)),
		"action": tr(_action_key(id)) if bool(_has_action.get(id, false)) else "",
	}

func body(id: String) -> String:
	return String(line(id).get("body", ""))

func speaker(id: String) -> String:
	return String(line(id).get("speaker", ""))

func action(id: String) -> String:
	return String(line(id).get("action", ""))

func _body_key(id: String) -> String:
	return "dialogue.%s" % id

func _action_key(id: String) -> String:
	return "dialogue.%s.action" % id

func _load_csv() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_warning("DialogueCatalog: missing %s" % CSV_PATH)
		return

	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("DialogueCatalog: cannot open %s" % CSV_PATH)
		return

	var header := file.get_csv_line()
	var id_col := _column_index(header, "id")
	var speaker_col := _column_index(header, "speaker")
	var en_col := _column_index(header, "en")
	var cs_col := _column_index(header, "cs")
	var action_en_col := _column_index(header, "action_en")
	var action_cs_col := _column_index(header, "action_cs")
	if id_col < 0 or en_col < 0 or cs_col < 0:
		push_warning("DialogueCatalog: CSV needs id, en, cs columns")
		return

	var en_translation := Translation.new()
	en_translation.locale = "en"
	var cs_translation := Translation.new()
	cs_translation.locale = "cs"

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty():
			continue
		var id := _cell(row, id_col)
		if id.is_empty() or id.begins_with("#"):
			continue
		if _known.has(id):
			push_warning("DialogueCatalog: duplicate id '%s'" % id)
			continue

		_known[id] = true
		_speakers[id] = _cell(row, speaker_col)

		var en_body := _cell(row, en_col)
		var cs_body := _cell(row, cs_col)
		if not en_body.is_empty():
			en_translation.add_message(_body_key(id), en_body)
		if not cs_body.is_empty():
			cs_translation.add_message(_body_key(id), cs_body)

		var action_en := _cell(row, action_en_col)
		var action_cs := _cell(row, action_cs_col)
		if not action_en.is_empty() or not action_cs.is_empty():
			_has_action[id] = true
			if not action_en.is_empty():
				en_translation.add_message(_action_key(id), action_en)
			if not action_cs.is_empty():
				cs_translation.add_message(_action_key(id), action_cs)

	TranslationServer.add_translation(en_translation)
	TranslationServer.add_translation(cs_translation)

	if has_node("/root/DebugLogger"):
		DebugLogger.log_info("DialogueCatalog loaded %d lines from %s" % [_known.size(), CSV_PATH])

func _column_index(header: PackedStringArray, name: String) -> int:
	for i in header.size():
		if String(header[i]).strip_edges() == name:
			return i
	return -1

func _cell(row: PackedStringArray, index: int) -> String:
	if index < 0 or index >= row.size():
		return ""
	return String(row[index]).strip_edges()
