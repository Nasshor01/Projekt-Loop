# Soubor: FloatingText.gd
extends Label

# Tato funkce spustí animaci
func start(text_to_show: String, color: Color):
	# Nastaví text a barvu podle toho, co dostane z Unit skriptu
	self.text = text_to_show
	self.modulate = color
	
	# Vytvoříme Tween pro animaci
	var tween = create_tween()
	
	# Animace pohybu nahoru
	# Pohybuje uzlem o 50 pixelů nahoru za 0.8 sekundy
	tween.tween_property(self, "position:y", position.y - 50, 0.8).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	# Současně s pohybem animujeme i mizení (alpha kanál)
	# Začne mizet po 0.2 sekundách a dokončí mizení za 0.6 sekundy
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.2)
	
	# Po dokončení všech animací se uzel sám odstraní ze scény
	tween.tween_callback(queue_free)
