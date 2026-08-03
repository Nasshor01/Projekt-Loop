# Soubor: scripts/ui/ArtifactIcon.gd
extends TextureRect
class_name ArtifactIcon

var artifact_data: ArtifactsData

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_refresh_tooltip()

func set_artifact(data: ArtifactsData) -> void:
	artifact_data = data
	if artifact_data and artifact_data.texture:
		texture = artifact_data.texture
	else:
		texture = null
	_refresh_tooltip()

func _refresh_tooltip() -> void:
	"""Hover tooltip: název + co artefakt dělá (plain text)."""
	mouse_filter = Control.MOUSE_FILTER_STOP
	if artifact_data == null:
		tooltip_text = ""
		return

	var lines: PackedStringArray = []
	var art_name := artifact_data.get_localized_name().strip_edges()
	var art_desc := artifact_data.get_formatted_description().strip_edges()
	# Native tooltip nemá BBCode — odstraň jednoduché tagy, pokud by se objevily.
	art_desc = _strip_bbcode(art_desc)

	if not art_name.is_empty():
		lines.append(art_name)
	if not art_desc.is_empty():
		lines.append(art_desc)

	tooltip_text = "\n".join(lines)

func _strip_bbcode(text: String) -> String:
	var out := text
	# Odstraní [tag]...[/tag] a samotné [tag] / [/tag]
	var re := RegEx.new()
	if re.compile("\\[[^\\]]+\\]") == OK:
		out = re.sub(out, "", true)
	return out.strip_edges()
