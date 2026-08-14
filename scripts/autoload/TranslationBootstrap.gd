extends Node

## UI / labels. Spoken dialogue lives in DialogueCatalog (data/dialogue/dialogue.csv).
const CSV_PATH := "res://translations.csv"

func _ready() -> void:
	_load_translations_from_csv()

func _load_translations_from_csv() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_warning("TranslationBootstrap: missing %s" % CSV_PATH)
		return

	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("TranslationBootstrap: cannot open %s" % CSV_PATH)
		return

	var header := file.get_csv_line()
	if header.size() < 2:
		return

	var locales: PackedStringArray = PackedStringArray()
	for column_index in range(1, header.size()):
		var locale := String(header[column_index]).strip_edges()
		if locale.is_empty() or locale.begins_with("_"):
			continue
		locales.append(locale)

	if locales.is_empty():
		return

	var translations: Array[Translation] = []
	for locale in locales:
		var translation := Translation.new()
		translation.locale = locale
		translations.append(translation)

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty():
			continue

		var key := String(row[0]).strip_edges()
		if key.is_empty():
			continue

		for locale_index in range(locales.size()):
			var column_index := locale_index + 1
			if column_index >= row.size():
				continue

			var message := String(row[column_index])
			if message.is_empty():
				continue

			translations[locale_index].add_message(key, message)

	for translation in translations:
		TranslationServer.add_translation(translation)

	if has_node("/root/DebugLogger"):
		DebugLogger.log_info("Translations loaded from CSV: %s" % ", ".join(locales))
