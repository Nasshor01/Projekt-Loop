# UPRAVENÁ FUNKCE try_play_card
func try_play_card(card: CardData, initial_target: Node2D) -> void:
	DebugLogger.log_card_played(card.card_name, initial_target.name if initial_target else "none")
	if _is_action_processing: return
	if not card: return
	if not PlayerData.spend_energy(card.cost):
		print("Nedostatek energie!")
		return

	_is_action_processing = true
	var card_played_successfully = false
	
	var card_ui_to_remove = _selected_card_ui
	
	# SLEDOVÁNÍ ADRENALIN KARET
	if card.card_id == "adrenaline" or card.card_id == "adrenaline+":
		PlayerData.track_adrenaline_card_played()
		
		# Vizuální feedback podle stavu
		if PlayerData.has_adrenaline_addiction:
			# Má závislost - ukáž kolikátý adrenalin
			_show_adrenaline_counter(PlayerData.adrenaline_cards_this_turn)
		else:
			# Nemá závislost - varuj před získáním
			if PlayerData.adrenaline_cards_this_turn == 3:
				_show_addiction_warning()
	
	for effect_data in card.effects:
		var targets = _get_targets_for_effect(effect_data, initial_target)
		if not targets.is_empty():
			card_played_successfully = true
			for target_unit in targets:
				if is_instance_valid(target_unit):
					_apply_single_effect(effect_data, target_unit)
					
	if card_played_successfully:
		# DŮLEŽITÉ: Trigger artefaktů PO trackování ale PŘED aplikací efektů
		if has_node("/root/ArtifactManager"):
			var artifact_results = ArtifactManager.on_card_played(card)
			for result in artifact_results:
				print("Card play artefakt aktivován: %s" % result.description)
		
		var has_exhaust_effect = card.effects.any(func(e): return e.effect_type == CardEffectData.EffectType.EXHAUST)
		if has_exhaust_effect:
			PlayerData.add_card_to_exhaust_pile(card)
		else:
			PlayerData.add_card_to_discard_pile(card)
		PlayerData.current_hand.erase(card)
		
		if is_instance_valid(card_ui_to_remove):
			card_ui_to_remove.queue_free()
		player_hand_ui_instance._request_arrange()
		_update_pile_counts()
	else:
		print("Karta '%s' nenašla žádný platný cíl." % card.card_name)
		PlayerData.gain_energy(card.cost)

	_is_action_processing = false
	_reset_player_selection()

# NOVÁ FUNKCE - zobrazení počítadla adrenalinů
func _show_adrenaline_counter(count: int):
	"""Zobrazí počítadlo adrenalinů při závislosti"""
	var color = Color.YELLOW
	var text = "Adrenalin %d/2" % count
	
	if count > 2:
		color = Color.RED
		text = "💀 PŘEDÁVKOVÁNÍ! (%d)" % count
	elif count == 2:
		color = Color.ORANGE
		text = "⚠️ Adrenalin %d/2 - LIMIT!" % count
	
	_show_floating_notification(text, color)

# NOVÁ FUNKCE - varování před závislostí
func _show_addiction_warning():
	"""Varování před získáním závislosti"""
	var text = "⚠️ VAROVÁNÍ: Další Adrenalin = ZÁVISLOST!"
	_show_floating_notification(text, Color.ORANGE)

# NOVÁ FUNKCE - pomocná pro notifikace
func _show_floating_notification(text: String, color: Color):
	"""Pomocná funkce pro zobrazení notifikací"""
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	var canvas_layer = $CanvasLayer
	if canvas_layer:
		canvas_layer.add_child(label)
		label.position = Vector2(get_viewport().size.x / 2 - 200, 150)
		
		var tween = create_tween()
		label.modulate.a = 0
		label.scale = Vector2(0.5, 0.5)
		
		# Fade in + scale up
		tween.tween_property(label, "modulate:a", 1.0, 0.2)
		tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
		
		# Hold
		tween.tween_interval(1.5)
		
		# Fade out
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)

# UPRAVENÁ FUNKCE start_player_turn
func start_player_turn():
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	
	# NOVÉ: Počítání tahů (pouze pro normální tahy, ne extra)
	if not _is_extra_turn:
		_current_turn_number += 1
		_update_turn_display()
		print("🔄 Tah číslo: %d" % _current_turn_number)
	else:
		print("⚡ EXTRA TAH!")
		_is_extra_turn = false  # Reset pro příští tah
	
	PlayerData.reset_energy()
	PlayerData.reset_adrenaline_tracking()
	
	# Pokud má závislost, zobraz připomenutí
	if PlayerData.has_adrenaline_addiction:
		_show_floating_notification("💉 Závislost aktivní (limit: 2 Adrenaliny)", Color.PURPLE)
	
	if is_instance_valid(_player_unit_node):
		_player_unit_node.reset_for_new_turn()
		
		# START_OF_TURN artefakty
		if has_node("/root/ArtifactManager"):
			ArtifactManager.on_turn_start()
		
		# NOVÉ: Zkontroluj conditional artefakty (pro Časový krystal)
		if has_node("/root/ArtifactManager"):
			var context = {
				"current_turn": _current_turn_number,
				"turn_number": _current_turn_number,
				"target": _player_unit_node
			}
			var conditional_results = ArtifactManager.check_conditional_artifacts_with_context(context)
			
			# Zkontroluj jestli se aktivoval extra tah
			for result in conditional_results:
				if result["artifact"].custom_effect_id == "extra_turn":
					_is_extra_turn = true
					print("🔮 Časový krystal aktivován! Budeš mít extra tah!")
		
		var extra_draw = _player_unit_node.process_turn_start_statuses()
		_cards_to_draw_queue = starting_hand_size + extra_draw
		_draw_next_card_in_queue()
	
	for unit in _enemy_units:
		if is_instance_valid(unit):
			unit.reset_for_new_turn()
			unit.process_turn_start_statuses()
			
	set_enemy_intents()
	battle_grid_instance.show_danger_zone(_enemy_units)
