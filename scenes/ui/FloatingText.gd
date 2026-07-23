# Soubor: FloatingText.gd
extends Label

func start(text_to_show: String, color: Color):
	self.text = text_to_show
	# Tint fill only so black outline stays readable.
	add_theme_color_override("font_color", color)
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(0.75, 0.75)

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

	var move_fade = create_tween()
	move_fade.set_parallel(true)
	move_fade.tween_property(self, "position:y", position.y - 56, 0.9).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	move_fade.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.3)
	await move_fade.finished
	queue_free()
