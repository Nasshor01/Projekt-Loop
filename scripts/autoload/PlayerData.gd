# Soubor: scripts/autoload/PlayerData.gd (KOMPLETNÍ S VŠEMI EFEKTY)
extends Node

# --- Signály ---
signal energy_changed(new_energy_amount)
signal artifacts_changed
signal gold_changed(new_amount)
signal health_changed(new_hp, new_max_hp)
signal player_state_initialized

# --- Proměnné pro jeden "run" ---
var selected_class = null
var selected_subclass = null
var master_deck: Array[CardData] = []
var current_hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var draw_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []
var current_energy: int = 3
var max_energy: int = 3
var max_hp: int = 50
var current_hp: int = 50
var artifacts: Array[ArtifactsData] = []
var gold: int = 0
var floors_cleared: int = 0
var path_taken: Array[MapNodeResource] = []
var active_skill_tree = null
var has_revive: bool = false
var global_card_damage_bonus: int = 0
var starting_retained_block: int = 0

# --- NOVÉ PROMĚNNÉ PRO PASIVNÍ EFEKTY ---
var critical_chance: int = 0
var heal_end_of_turn: int = 0
var aura_enhancement: int = 0
var avatar_starting_block_multiplier: int = 0
var thorns_damage: int = 0
var double_healing_bonus: int = 0
var energy_on_kill: int = 0
var block_on_card_play: int = 0

func get_current_node() -> MapNodeResource:
	if not path_taken.is_empty():
		floors_cleared = path_taken.size()
		return path_taken.back()
	return null

func start_new_run_state():
	print("=== START NEW RUN STATE ===")
	
	# 1. Resetujeme balíček na startovní
	master_deck.clear()
	if is_instance_valid(selected_subclass):
		var subclass_name = "Unknown"
		if "subclass_name" in selected_subclass and selected_subclass.subclass_name != "":
			subclass_name = selected_subclass.subclass_name
		elif "subclass_id" in selected_subclass and selected_subclass.subclass_id != "":
			subclass_name = selected_subclass.subclass_id
		
		print("Načítám startovní balíček z: %s" % subclass_name)
		
		if "starting_deck" in selected_subclass:
			for entry in selected_subclass.starting_deck:
				if entry is DeckEntry and is_instance_valid(entry.card):
					for i in range(entry.count):
						master_deck.append(entry.card)
		
		print("Startovní balíček obsahuje %d karet" % master_deck.size())
	
	# 2. Aplikujeme pasivní skilly, které mohou změnit startovní staty
	apply_passive_skills()

	# 3. Připravíme bojové balíčky a zbytek
	reset_battle_stats()
	path_taken.clear()
	artifacts.clear()
	floors_cleared = 0
	
	# 4. Oznámíme UI, jaký je finální stav
	emit_signal("artifacts_changed")
	emit_signal("gold_changed", gold)
	emit_signal("health_changed", current_hp, max_hp)
	
	print("=== RUN STATE INICIALIZOVÁN ===")
	
	# 5. VYSLAT SIGNÁL PRO VŠECHNY, KTEŘÍ ČEKAJÍ
	emit_signal("player_state_initialized")

func start_ng_plus_state():
	current_hp = max_hp
	path_taken.clear()
	floors_cleared = 0
	
	print("--- STAV PRO NG+ ---")
	print("  - Ponecháno zlata: %d" % gold)
	print("  - Ponecháno artefaktů: %d" % artifacts.size())
	print("  - Ponecháno karet v balíčku: %d" % master_deck.size())
	print("--------------------")
	
	reset_battle_stats()
	
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("artifacts_changed")
	emit_signal("gold_changed", gold)

func apply_passive_skills():
	print("=== APLIKACE PASIVNÍCH SKILLŮ ===")
	
	# 1. Resetujeme všechny hodnoty na úplný základ
	max_hp = 50
	gold = 50
	max_energy = 3
	has_revive = false
	global_card_damage_bonus = 0
	starting_retained_block = 0
	
	# Resetujeme nové efekty
	critical_chance = 0
	heal_end_of_turn = 0
	aura_enhancement = 0
	avatar_starting_block_multiplier = 0
	thorns_damage = 0
	double_healing_bonus = 0
	energy_on_kill = 0
	block_on_card_play = 0
	
	# 2. DEBUG: Zkontrolujeme skill tree
	print("Kontrolujem skill tree...")
	if not is_instance_valid(active_skill_tree):
		print("❌ PROBLÉM: active_skill_tree je null!")
		
		# Zkusíme ho načíst ze selected_subclass
		if is_instance_valid(selected_subclass):
			var subclass_name = "Unknown"
			if "subclass_name" in selected_subclass and selected_subclass.subclass_name != "":
				subclass_name = selected_subclass.subclass_name
			elif "subclass_id" in selected_subclass and selected_subclass.subclass_id != "":
				subclass_name = selected_subclass.subclass_id
			
			print("Zkouším načíst tree ze selected_subclass: %s" % subclass_name)
			
			if "passive_skill_tree" in selected_subclass and is_instance_valid(selected_subclass.passive_skill_tree):
				active_skill_tree = selected_subclass.passive_skill_tree
				print("✅ Tree úspěšně načten ze subclass!")
			else:
				print("❌ selected_subclass.passive_skill_tree je také null nebo neexistuje!")
		else:
			print("❌ selected_subclass je null!")
		
		if not is_instance_valid(active_skill_tree):
			print("❌ Skill tree se nepodařilo načíst. Končím apply_passive_skills().")
			current_hp = max_hp
			return
	else:
		print("✅ active_skill_tree je načten správně")

	# 3. Načteme odemčené skilly
	var unlocked_ids = SaveManager.meta_progress.unlocked_skill_ids
	print("Odemčené skilly (%d): %s" % [unlocked_ids.size(), unlocked_ids])
	
	# 4. Projdeme odemčené skilly a aplikujeme jejich EFEKTY
	for skill_id in unlocked_ids:
		var skill_node = active_skill_tree.get_node_by_id(skill_id)
		if not is_instance_valid(skill_node):
			print("⚠️ Skill s ID '%s' nebyl nalezen v tree!" % skill_id)
			continue
		
		print("Aplikuji pasivní skill: %s" % skill_node.skill_name)
		
		# Projdeme všechny efekty definované v uzlu
		for effect_data in skill_node.effects:
			if not is_instance_valid(effect_data):
				continue
			
			# Aplikujeme efekt podle typu
			match effect_data.effect_type:
				PassiveEffectData.EffectType.ADD_MAX_HP:
					max_hp += effect_data.value
					print("  + %d max HP (nyní %d)" % [effect_data.value, max_hp])
				PassiveEffectData.EffectType.ADD_STARTING_GOLD:
					gold += effect_data.value
					print("  + %d zlato (nyní %d)" % [effect_data.value, gold])
				PassiveEffectData.EffectType.ADD_MAX_ENERGY:
					max_energy += effect_data.value
					print("  + %d max energie (nyní %d)" % [effect_data.value, max_energy])
				PassiveEffectData.EffectType.GRANT_REVIVE:
					if effect_data.value > 0: 
						has_revive = true
						print("  ✅ Získán revive")
				PassiveEffectData.EffectType.ADD_CARD_DAMAGE:
					global_card_damage_bonus += effect_data.value
					print("  + %d poškození karet (nyní %d)" % [effect_data.value, global_card_damage_bonus])
				PassiveEffectData.EffectType.ADD_RETAINED_BLOCK:
					starting_retained_block += effect_data.value
					print("  + %d startovní blok (nyní %d)" % [effect_data.value, starting_retained_block])
				PassiveEffectData.EffectType.CRITICAL_CHANCE_BONUS:
					critical_chance += effect_data.value
					print("  + %d%% kritická šance (nyní %d%%)" % [effect_data.value, critical_chance])
				PassiveEffectData.EffectType.HEAL_END_OF_TURN:
					heal_end_of_turn += effect_data.value
					print("  + %d HP za konec tahu (nyní %d)" % [effect_data.value, heal_end_of_turn])
				PassiveEffectData.EffectType.AURA_ENHANCEMENT:
					aura_enhancement += effect_data.value
					print("  + %d%% vylepšení aur (nyní %d%%)" % [effect_data.value, aura_enhancement])
				PassiveEffectData.EffectType.AVATAR_STARTING_BLOCK:
					avatar_starting_block_multiplier = effect_data.value
					print("  ✅ Avatar blok: %dx max HP na začátku souboje" % effect_data.value)
				PassiveEffectData.EffectType.THORNS_DAMAGE:
					thorns_damage += effect_data.value
					print("  + %d poškození trny (nyní %d)" % [effect_data.value, thorns_damage])
				PassiveEffectData.EffectType.DOUBLE_HEALING:
					double_healing_bonus += effect_data.value
					print("  + %d%% léčení bonus (nyní %d%%)" % [effect_data.value, double_healing_bonus])
				PassiveEffectData.EffectType.ENERGY_ON_KILL:
					energy_on_kill += effect_data.value
					print("  + %d energie za zabití (nyní %d)" % [effect_data.value, energy_on_kill])
				PassiveEffectData.EffectType.BLOCK_ON_CARD_PLAY:
					block_on_card_play += effect_data.value
					print("  + %d blok za kartu (nyní %d)" % [effect_data.value, block_on_card_play])
	
	current_hp = max_hp
	print("=== APLIKACE DOKONČENA ===")
	print("Finální staty: HP=%d, Gold=%d, Energy=%d, Retained Block=%d" % [max_hp, gold, max_energy, starting_retained_block])
	print("Speciální efekty: Crit=%d%%, Heal/turn=%d, Thorns=%d" % [critical_chance, heal_end_of_turn, thorns_damage])

func initialize_player(p_class, p_subclass):
	print("=== INICIALIZACE HRÁČE ===")
	
	if not p_class or not p_subclass:
		printerr("PlayerData: Chyba inicializace! Chybí třída nebo podtřída.")
		return
		
	selected_class = p_class
	selected_subclass = p_subclass
	
	print("Třída načtena")
	print("Podtřída načtena")
	
	# Načteme skill tree - nejjednodušší způsob
	if "passive_skill_tree" in p_subclass:
		active_skill_tree = p_subclass.passive_skill_tree
	
	if is_instance_valid(active_skill_tree):
		print("✅ Skill tree načten: " + str(active_skill_tree.skill_nodes.size()) + " uzlů")
	else:
		print("⚠️ Žádný skill tree nebyl nastaven.")
	
	print("=== INICIALIZACE DOKONČENA ===")

# NOVÉ FUNKCE PRO POKROČILÉ EFEKTY

func apply_avatar_starting_block():
	"""Aplikuje Avatar of Light efekt na začátku souboje"""
	if avatar_starting_block_multiplier > 0:
		var bonus_block = max_hp * avatar_starting_block_multiplier
		starting_retained_block += bonus_block
		print("🌟 Avatar of Light: +%d bloku na začátku souboje!" % bonus_block)

func process_heal_end_of_turn():
	"""Zpracuje léčení na konci tahu"""
	if heal_end_of_turn > 0:
		var heal_amount = heal_end_of_turn
		if double_healing_bonus > 0:
			heal_amount = heal_amount * (100 + double_healing_bonus) / 100
		heal(heal_amount)
		print("💚 Požehnaná obnova: +%d HP" % heal_amount)

func process_energy_on_kill():
	"""Zpracuje bonus energie za zabití nepřítele"""
	if energy_on_kill > 0:
		gain_energy(energy_on_kill)
		print("⚡ Spravedlivá zuřivost: +%d energie za zabití!" % energy_on_kill)

func process_block_on_card_play():
	"""Zpracuje bonus blok za zahrání karty"""
	if block_on_card_play > 0:
		# Toto by se volalo z battle systému
		print("🛡️ Blok za kartu: +%d bloku" % block_on_card_play)
		return block_on_card_play
	return 0

func get_critical_chance() -> int:
	"""Vrátí aktuální šanci na kritický zásah"""
	return critical_chance

func get_thorns_damage() -> int:
	"""Vrátí poškození od trnů"""
	return thorns_damage

func should_heal_enhanced(amount: int) -> int:
	"""Vrátí vylepšené léčení, pokud je aktivní bonus"""
	if double_healing_bonus > 0:
		return amount * (100 + double_healing_bonus) / 100
	return amount

# Zbytek funkcí zůstává stejný...
func reset_battle_stats():
	draw_pile.clear()
	discard_pile.clear()
	current_hand.clear()
	exhaust_pile.clear()
	draw_pile.assign(master_deck)
	draw_pile.shuffle()

func reset_energy():
	current_energy = max_energy
	
	for artifact in artifacts:
		if artifact.effect_id == "extra_energy_per_turn":
			current_energy += artifact.value
			print("Artefakt '%s' přidal hráči %d energii." % [artifact.artifact_name, artifact.value])
	
	emit_signal("energy_changed", current_energy)

func spend_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		emit_signal("energy_changed", current_energy)
		return true
	return false

func gain_energy(amount: int):
	current_energy += amount
	emit_signal("energy_changed", current_energy)

func add_card_to_discard_pile(card: CardData):
	if card is CardData:
		discard_pile.append(card)

func add_card_to_exhaust_pile(card: CardData):
	if card is CardData:
		exhaust_pile.append(card)

func discard_hand():
	if current_hand.is_empty():
		return
	for card in current_hand:
		add_card_to_discard_pile(card)
	current_hand.clear()

func reshuffle_discard_into_draw_pile():
	if not discard_pile.is_empty():
		draw_pile.assign(discard_pile)
		discard_pile.clear()
		draw_pile.shuffle()

func draw_new_hand(hand_size: int = 5):
	current_hand.clear()
	draw_cards(hand_size)

func draw_cards(amount: int) -> int:
	var cards_drawn_count = 0
	for _i in range(amount):
		if draw_pile.is_empty():
			break
		
		var drawn_card = draw_pile.pop_front()
		if drawn_card is CardData:
			current_hand.append(drawn_card)
			cards_drawn_count += 1
			
	return cards_drawn_count

func add_artifact(artifact_data: ArtifactsData):
	if not artifacts.has(artifact_data):
		artifacts.append(artifact_data)
		emit_signal("artifacts_changed")

func remove_artifact(artifact_data: ArtifactsData):
	if artifacts.has(artifact_data):
		artifacts.erase(artifact_data)
		emit_signal("artifacts_changed")

func add_gold(amount: int):
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_signal("gold_changed", gold)
		return true
	return false

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	emit_signal("health_changed", current_hp, max_hp)

func heal(amount: int):
	var enhanced_amount = should_heal_enhanced(amount)
	current_hp = min(max_hp, current_hp + enhanced_amount)
	emit_signal("health_changed", current_hp, max_hp)
