# Soubor: scripts/autoload/PlayerData.gd (KOMPLETNÍ S VŠEMI EFEKTY)
extends Node

# --- Signály ---
signal energy_changed(new_energy_amount)
signal artifacts_changed
signal gold_changed(new_amount)
signal health_changed(new_hp, new_max_hp)
signal player_state_initialized
signal floor_changed(new_floor)
signal ng_plus_changed(new_level)
signal deck_changed

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
var gold: int = 0:
	set(value):
		if gold != value:
			gold = value
			emit_signal("gold_changed", gold)
var floors_cleared: int = 0:
	set(value):
		if floors_cleared != value:
			floors_cleared = value
			emit_signal("floor_changed", floors_cleared)
var current_run_xp: int = 0
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
var global_shield: int = 0

var ng_plus_level: int = 0:
	set(value):
		if ng_plus_level != value:
			ng_plus_level = value
			emit_signal("ng_plus_changed", ng_plus_level)

func get_current_node() -> MapNodeResource:
	if not path_taken.is_empty():
		self.floors_cleared = path_taken.size()
		return path_taken.back()
	return null

func start_new_run_state():
	EventManager.start_new_run()
	ng_plus_level = 0
	
	# 1. Resetujeme balíček na startovní
	master_deck.clear()
	if is_instance_valid(selected_subclass):
		var subclass_name = "Unknown"
		if "subclass_name" in selected_subclass and selected_subclass.subclass_name != "":
			subclass_name = selected_subclass.subclass_name
		elif "subclass_id" in selected_subclass and selected_subclass.subclass_id != "":
			subclass_name = selected_subclass.subclass_id
		
		
		if "starting_deck" in selected_subclass:
			for entry in selected_subclass.starting_deck:
				if entry is DeckEntry and is_instance_valid(entry.card):
					for i in range(entry.count):
						master_deck.append(entry.card)
		
		global_shield = 0
	# 2. Aplikujeme pasivní skilly, které mohou změnit startovní staty
	apply_passive_skills()
	
	# 2.5 KRITICKÁ OPRAVA - zajisti plné HP po aplikaci skillů
	current_hp = max_hp 

	# 3. Připravíme bojové balíčky a zbytek
	reset_battle_stats()
	path_taken.clear()
	artifacts.clear()
	floors_cleared = 0
	current_run_xp = 0
	
	# 4. Oznámíme UI, jaký je finální stav
	emit_signal("artifacts_changed")
	self.gold = gold # Trigger the setter
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("deck_changed")
	
	
	# 5. VYSLAT SIGNÁL PRO VŠECHNY, KTEŘÍ ČEKAJÍ
	emit_signal("player_state_initialized")

func start_ng_plus_state():
	current_hp = max_hp
	path_taken.clear()
	floors_cleared = 0
	current_run_xp = 0
	
	
	reset_battle_stats()
	
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("artifacts_changed")
	self.gold = gold
	self.ng_plus_level = ng_plus_level # re-emit ng+ level

func apply_passive_skills():
	DebugLogger.log_info("=== APPLYING PASSIVE SKILLS ===", "SKILLS")
	DebugLogger.start_performance_timer("apply_passive_skills")
	
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
	
	# DEBUG: Loguj stav skill tree
	if not is_instance_valid(active_skill_tree):
		DebugLogger.log_error("active_skill_tree je null!", "SKILLS")
		
		if is_instance_valid(selected_subclass):
			var subclass_name = "Unknown"
			if "subclass_name" in selected_subclass:
				subclass_name = selected_subclass.subclass_name
			
			DebugLogger.log_info("Pokouším se načíst tree ze subclass: %s" % subclass_name, "SKILLS")
			
			if "passive_skill_tree" in selected_subclass and is_instance_valid(selected_subclass.passive_skill_tree):
				active_skill_tree = selected_subclass.passive_skill_tree
				DebugLogger.log_info("✅ Tree načten! Nodes: %d" % active_skill_tree.skill_nodes.size(), "SKILLS")
			else:
				DebugLogger.log_error("Skill tree nebyl nalezen v subclass!", "SKILLS")
		
		if not is_instance_valid(active_skill_tree):
			DebugLogger.log_critical("Selhalo načtení skill tree!", "SKILLS")
			current_hp = max_hp
			DebugLogger.end_performance_timer("apply_passive_skills")
			return
	else:
		DebugLogger.log_info("Skill tree OK, nodes: %d" % active_skill_tree.skill_nodes.size(), "SKILLS")

	# Načteme odemčené skilly
	var unlocked_ids = SaveManager.meta_progress.unlocked_skill_ids
	DebugLogger.log_info("Aplikuji %d odemčených skillů" % unlocked_ids.size(), "SKILLS")
	
	# 4. Projdeme odemčené skilly a aplikujeme jejich EFEKTY
	for skill_id in unlocked_ids:
		var skill_node = active_skill_tree.get_node_by_id(skill_id)
		if not is_instance_valid(skill_node):
			DebugLogger.log_warning("Skill '%s' nebyl nalezen!" % skill_id, "SKILLS")
			continue
		
		DebugLogger.log_debug("Aplikuji: %s (Tier %d)" % [skill_node.skill_name, skill_node.tier], "SKILLS")
		
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
					var shield_amount = max_hp * effect_data.value
					global_shield += shield_amount
					print(" ✨ Avatar Světla přidal %d do GLOBÁLNÍHO ŠTÍTU (nyní %d)" % [shield_amount, global_shield])
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
	
	# NOVÉ: Aplikuj bonusy z artefaktů
	if has_node("/root/ArtifactManager"):
		max_hp += ArtifactManager.get_max_hp_bonus()
		max_energy += ArtifactManager.get_max_energy_bonus()
		global_card_damage_bonus += ArtifactManager.get_card_damage_bonus()
		
		var heal_bonus = ArtifactManager.get_heal_bonus()
		if heal_bonus > 0:
			double_healing_bonus += heal_bonus
		
		var block_bonus = ArtifactManager.get_block_bonus()
		if block_bonus > 0:
			starting_retained_block += block_bonus
		
		critical_chance += ArtifactManager.get_critical_chance()
		thorns_damage += ArtifactManager.get_thorns_damage()
		
		print("=== ARTEFAKT BONUSY APLIKOVÁNY ===")
	
	current_hp = max_hp
	# Loguj finální staty
	DebugLogger.log_info("Finální staty po aplikaci skillů:", "SKILLS")
	DebugLogger.log_info("  HP: %d, Gold: %d, Energy: %d" % [max_hp, gold, max_energy], "SKILLS")
	DebugLogger.log_info("  Crit: %d%%, Heal/turn: %d, Thorns: %d" % [critical_chance, heal_end_of_turn, thorns_damage], "SKILLS")
	
	DebugLogger.end_performance_timer("apply_passive_skills")
	DebugLogger.log_skill_tree_state()
	
	emit_signal("health_changed", current_hp, max_hp)
	
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
	"""Zpracuje léčení na konci tahu - již se volá z Unit.gd"""
	# Tato funkce je nyní prázdná, protože heal se zpracovává přímo v Unit.reset_for_new_turn()
	# aby se správně zobrazil floating text
	pass

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
		return int(float(amount) * (100.0 + float(double_healing_bonus)) / 100.0)
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
	
	# SMAZÁNO: Starý artefakt systém
	# for artifact in artifacts:
	#     if artifact.effect_id == "extra_energy_per_turn":
	#         current_energy += artifact.value
	#         print("Artefakt '%s' přidal hráči %d energii." % [artifact.artifact_name, artifact.value])
	
	# Bonus energie z artefaktů se teď řeší automaticky přes ArtifactManager
	# START_OF_TURN trigger přidá energii když je potřeba
	
	emit_signal("energy_changed", current_energy)
func spend_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		
		# NOVÉ: Trigger energy spent artefakty
		if has_node("/root/ArtifactManager"):
			var context = {
				"energy_spent": amount,
				"current_energy": current_energy,
				"max_energy": max_energy,
				"target": null  # Bude nastaveno v ArtifactManager
			}
			ArtifactManager.trigger_artifacts(ArtifactsData.TriggerType.ON_ENERGY_SPENT, context)
		
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
	DebugLogger.log_debug("Drawing %d cards" % amount, "CARDS")
	var cards_drawn_count = 0
	
	for _i in range(amount):
		if draw_pile.is_empty():
			DebugLogger.log_debug("Draw pile empty, cannot draw more", "CARDS")
			break
		
		var drawn_card = draw_pile.pop_front()
		if drawn_card is CardData:
			current_hand.append(drawn_card)
			cards_drawn_count += 1
			DebugLogger.log_debug("Drew: %s" % drawn_card.card_name, "CARDS")
	
	# NOVÉ: Trigger draw cards artefakty pokud jsme něco dobrali
	if cards_drawn_count > 0 and has_node("/root/ArtifactManager"):
		var context = {
			"cards_drawn": cards_drawn_count,
			"total_cards_requested": amount,
			"hand_size": current_hand.size(),
			"target": null  # Bude nastaveno v ArtifactManager
		}
		ArtifactManager.trigger_artifacts(ArtifactsData.TriggerType.ON_DRAW_CARDS, context)
	
	DebugLogger.log_debug("Cards drawn: %d, Hand size: %d" % [cards_drawn_count, current_hand.size()], "CARDS")
	return cards_drawn_count

# Soubor: scripts/autoload/PlayerData.gd

func add_artifact(new_artifact_resource: ArtifactsData) -> bool:
	"""Přidá artefakt s kontrolou stackování. Vrací true, pokud byl úspěšně přidán/stacknut."""
	if not is_instance_valid(new_artifact_resource):
		printerr("Pokus o přidání nevalidního artefaktu!")
		return false
	
	# Vytvoříme si kopii, abychom neupravovali původní soubor .tres
	var new_artifact = new_artifact_resource.duplicate()

	var existing_artifact = find_artifact_by_name(new_artifact.artifact_name)

	if existing_artifact:
		# Artefakt již existuje, zkusíme přidat stack
		if existing_artifact.is_stackable and existing_artifact.current_stacks < existing_artifact.max_stacks:
			existing_artifact.current_stacks += 1
			print("✅ Přidán stack pro %s (%d/%d)" % [
				existing_artifact.artifact_name, 
				existing_artifact.current_stacks, 
				existing_artifact.max_stacks
			])
		else:
			print("❌ %s již vlastníš a nelze ho stackovat (nebo je na max)." % new_artifact.artifact_name)
			return false # Nelze přidat
	else:
		# Jedná se o úplně nový artefakt
		artifacts.append(new_artifact)
		print("✅ Získán nový artefakt: %s" % new_artifact.artifact_name)

	# Společná logika po úspěšném přidání/stackování
	emit_signal("artifacts_changed")
	
	if has_node("/root/ArtifactManager"):
		ArtifactManager._refresh_artifact_cache()

	# Pokud je artefakt pasivní, musíme přepočítat staty
	if new_artifact.trigger_type == ArtifactsData.TriggerType.PASSIVE:
		apply_passive_skills()

	emit_signal("health_changed", current_hp, max_hp) # Pro jistotu, kdyby pasivka měnila HP
	return true

func find_artifact_by_name(artifact_name: String) -> ArtifactsData:
	"""Najde artefakt podle jména"""
	for artifact in artifacts:
		if artifact.artifact_name == artifact_name:
			return artifact
	return null

func has_artifact(artifact_name: String) -> bool:
	"""Zkontroluje, jestli už artefakt vlastním"""
	return find_artifact_by_name(artifact_name) != null

func can_gain_artifact(artifact) -> bool:
	"""Zkontroluje, jestli můžu získat artefakt (pro filtrování v obchodech)"""
	var existing = find_artifact_by_name(artifact.artifact_name)
	
	if not existing:
		return true  # Nový artefakt - můžu získat
	
	if existing.max_stacks > 1 and existing.current_stacks < existing.max_stacks:
		return true  # Existující stackovatelný artefakt s volnými stacky
	
	return false  # Už mám a nedá se stackovat nebo je na max stackech

func get_artifact_stack_info(artifact_name: String) -> String:
	"""Vrátí info o stackech pro UI"""
	var existing = find_artifact_by_name(artifact_name)
	if not existing:
		return "Nový"
	
	if existing.max_stacks > 1:
		return "Stack +1 (%d/%d)" % [existing.current_stacks + 1, existing.max_stacks]
	else:
		return "Už vlastníš"

# V PlayerData.gd - NOVÁ POMOCNÁ FUNKCE:
func _find_stackable_artifact(new_artifact: ArtifactsData) -> ArtifactsData:
	for existing in artifacts:
		if (existing.artifact_name == new_artifact.artifact_name and 
			existing.max_stacks > 1 and 
			existing.current_stacks < existing.max_stacks):
			return existing
	return null

func remove_artifact(artifact_data: ArtifactsData):
	if artifacts.has(artifact_data):
		artifacts.erase(artifact_data)
		emit_signal("artifacts_changed")

func add_gold(amount: int):
	self.gold += amount

func spend_gold(amount: int) -> bool:
	if self.gold >= amount:
		self.gold -= amount
		return true
	return false

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	emit_signal("health_changed", current_hp, max_hp)

func heal(amount: int):
	var enhanced_amount = should_heal_enhanced(amount)
	current_hp = min(max_hp, current_hp + enhanced_amount)
	emit_signal("health_changed", current_hp, max_hp)

func add_curse(curse_type: String = "basic"):
	"""Přidá curse kartu do balíčku"""
	var curse_path = "res://data/cards/curses/"
	var curse_card: CardData
	
	match curse_type:
		"basic":
			curse_card = load(curse_path + "basic_curse.tres")
		"weakness":
			curse_card = load(curse_path + "curse_weakness.tres")
		"pain":
			curse_card = load(curse_path + "curse_pain.tres")
		_:
			curse_card = load(curse_path + "basic_curse.tres")
	
	if curse_card:
		master_deck.append(curse_card)
		DebugLogger.log_info("Added curse: %s" % curse_card.card_name, "CARDS")
		emit_signal("deck_changed")

func remove_all_curses():
	"""Odstraní všechny curse karty z balíčku"""
	var removed_count = 0
	var cards_to_remove = []
	
	for card in master_deck:
		if card and card.tags.has(CardData.CardTag.DEBUFF) and "curse" in card.card_id.to_lower():
			cards_to_remove.append(card)
	
	for card in cards_to_remove:
		master_deck.erase(card)
		removed_count += 1
	
	if removed_count > 0:
		emit_signal("deck_changed")

	DebugLogger.log_info("Removed %d curse cards" % removed_count, "CARDS")
	return removed_count

func get_curse_count() -> int:
	"""Vrátí počet curse karet v balíčku"""
	var count = 0
	for card in master_deck:
		if card and card.tags.has(CardData.CardTag.DEBUFF) and "curse" in card.card_id.to_lower():
			count += 1
	return count

func change_max_hp(amount: int):
	"""
	Bezpečně změní maximální HP hráče a zajistí aktualizaci UI.
	'amount' může být kladné (zvýšení) i záporné (snížení).
	"""
	# Změníme maximální HP
	max_hp += amount
	
	# Zajistíme, aby hráč neměl víc životů, než je nové maximum
	current_hp = min(current_hp, max_hp)
	
	# Pokud by snížení max_hp zabilo hráče, necháme ho na 1 životě
	if current_hp <= 0:
		current_hp = 1
	
	# KLÍČOVÝ KROK: Oznámíme všem (včetně GlobalUI), že se zdraví změnilo
	emit_signal("health_changed", current_hp, max_hp)

func emit_deck_changed():
	deck_changed.emit()

func emit_all_signals():
	health_changed.emit(current_hp, max_hp)
	gold_changed.emit(gold)
	deck_changed.emit()
	floor_changed.emit(floors_cleared)
	ng_plus_changed.emit(ng_plus_level)
	artifacts_changed.emit()
