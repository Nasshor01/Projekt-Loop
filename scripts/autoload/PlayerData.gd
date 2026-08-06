# Soubor: scripts/autoload/PlayerData.gd (KOMPLETNÍ S VŠEMI EFEKTY)
extends Node

# --- Signály ---
signal energy_changed(new_energy_amount)
signal artifacts_changed
signal gold_changed(new_amount)
signal health_changed(new_hp, new_max_hp)
signal player_state_initialized
signal floor_changed(new_floor)
signal loop_level_changed(new_level)
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
## Střepy získané v aktuálním runu (pro EndOfRun UI).
var current_run_shards: int = 0
var path_taken: Array[MapNodeResource] = []
var active_skill_tree = null
## Počet použití karet s max_uses_before_removal za tento run (card_id -> počet použití)
var card_usage_count: Dictionary = {}
## Počet karet odstraněných v obchodě za tento run (pro progresivní cenu)
var shop_card_removals_count: int = 0
var has_revive: bool = false
var global_card_damage_bonus: int = 0
var holy_damage_bonus: int = 0  ## Bonus pouze k Svatému (Holy) poškození ze skill tree
var starting_retained_block: int = 0
## Permanent seal from Tablet of Forgotten Oaths (survives combat + upgrades; Tablet is consumed).
var sealed_card_id: String = ""
var sealed_card_source_path: String = ""

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

# Card Management efekty
var first_turn_draw_bonus: int = 0
var max_hand_size_bonus: int = 0
var conditional_draw_conditions: Array[Dictionary] = []
var unlocked_cards: Array[String] = []  # Seznam odemčených karet

# Resource Management efekty
var starting_combo_points: int = 0
var starting_essence: int = 0
var starting_potions: int = 0
var starting_traps: int = 0

# Combat Bonuses
var target_bonus_damage_percent: int = 0
var target_card_cost_reduction: int = 0
var first_attack_free_count: int = 0
var spell_block_amount: int = 0

# Passive Enhancements
var passive_enhancements: Dictionary = {}  # {passive_id: bonus_value}
var passive_resonance_bonus_percent: int = 0
var passive_use_count_bonus: int = 0
var passive_threshold_overrides: Dictionary = {}  # {passive_id: new_threshold}

# Posture System (Fighter)
var posture_bonuses: Dictionary = {}  # {posture_type: bonus_percent}
var posture_switch_cost_reduction: int = 0

# DoT/Status
var poison_damage_bonus: int = 0

# Summoning (Nekromant)
var summon_health_bonus: int = 0
var enemy_to_card_conversion_percent: int = 0

# Lifesteal (Vrah Duší)
var lifesteal_percentage: int = 0
var overheal_to_temp_hp_percent: int = 0
var allied_damage_lifesteal_percent: int = 0

# Conditional Effects
var conditional_block_effects: Array[Dictionary] = []
var starting_temp_hp: int = 0

# Support (Ochránce)
var allied_defense_bonus_percent: int = 0
var force_enemy_movement_uses: int = 0

# Movement (pasivní strom – např. Svatý krok)
var movement_bonus: int = 0

# Elemental (Elementalista)
var first_spell_element_free: bool = false
var used_free_elements: Array[String] = []  # ["fire", "ice", "lightning"]

var loop_level: int = 0:
	set(value):
		if loop_level != value:
			loop_level = value
			emit_signal("loop_level_changed", loop_level)

func get_current_node() -> MapNodeResource:
	if not path_taken.is_empty():
		self.floors_cleared = path_taken.size()
		return path_taken.back()
	return null

func start_new_run_state():
	EventManager.start_new_run()
	loop_level = 0
	
	# 1. Resetujeme balíček na startovní a počítadla použití karet
	master_deck.clear()
	card_usage_count.clear()
	shop_card_removals_count = 0
	current_run_shards = 0
	sealed_card_id = ""
	sealed_card_source_path = ""
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
						# Unique instance per slot — shared .tres refs would make Seal/meta apply to all copies.
						master_deck.append(entry.card.duplicate(true))
		
		global_shield = 0
	# 2. Nejdřív vyčisti artefakty z minulého runu, pak přepočítej startovní staty
	artifacts.clear()
	if has_node("/root/ArtifactManager"):
		ArtifactManager._refresh_artifact_cache()
	apply_passive_skills()
	
	# 2.5 Nový run: plné HP + startovní zlato (Market)
	current_hp = max_hp
	gold = 50 + VillageBonuses.get_starting_gold_bonus()

	# 3. Připravíme bojové balíčky a zbytek
	reset_battle_stats()
	path_taken.clear()
	floors_cleared = 0
	current_run_xp = 0
	current_run_shards = 0
	
	# 4. Oznámíme UI, jaký je finální stav
	emit_signal("artifacts_changed")
	self.gold = gold # Trigger the setter
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("deck_changed")
	
	
	# 5. VYSLAT SIGNÁL PRO VŠECHNY, KTEŘÍ ČEKAJÍ
	emit_signal("player_state_initialized")

func start_loop_state():
	current_hp = max_hp
	path_taken.clear()
	floors_cleared = 0
	current_run_xp = 0
	current_run_shards = 0
	shop_card_removals_count = 0
	
	reset_battle_stats()
	
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("artifacts_changed")
	self.gold = gold
	self.loop_level = loop_level # re-emit loop level

func apply_passive_skills():
	# Skill tree vypnutý — base stats + Loop Vesnice + artefakty.
	# Nesmí fullhealovat ani resetovat gold mid-run (Apple / continue).
	DebugLogger.log_info("=== APPLYING RUN BONUSES (village + artifacts) ===", "SKILLS")
	DebugLogger.start_performance_timer("apply_passive_skills")
	
	var preserved_hp: int = current_hp
	var old_max_hp: int = max_hp
	var preserved_gold: int = gold
	
	max_hp = 50
	max_energy = 3
	has_revive = false
	global_card_damage_bonus = 0
	holy_damage_bonus = 0
	starting_retained_block = 0
	
	critical_chance = 0
	heal_end_of_turn = 0
	aura_enhancement = 0
	avatar_starting_block_multiplier = 0
	thorns_damage = 0
	double_healing_bonus = 0
	energy_on_kill = 0
	block_on_card_play = 0
	
	first_turn_draw_bonus = 0
	max_hand_size_bonus = 0
	conditional_draw_conditions.clear()
	unlocked_cards.clear()
	
	starting_combo_points = 0
	starting_essence = 0
	starting_potions = 0
	starting_traps = 0
	
	target_bonus_damage_percent = 0
	target_card_cost_reduction = 0
	first_attack_free_count = 0
	spell_block_amount = 0
	
	passive_enhancements.clear()
	passive_resonance_bonus_percent = 0
	passive_use_count_bonus = 0
	passive_threshold_overrides.clear()
	
	posture_bonuses.clear()
	posture_switch_cost_reduction = 0
	
	poison_damage_bonus = 0
	
	summon_health_bonus = 0
	enemy_to_card_conversion_percent = 0
	
	lifesteal_percentage = 0
	overheal_to_temp_hp_percent = 0
	allied_damage_lifesteal_percent = 0
	
	conditional_block_effects.clear()
	starting_temp_hp = 0
	
	allied_defense_bonus_percent = 0
	force_enemy_movement_uses = 0
	movement_bonus = 0
	
	first_spell_element_free = false
	used_free_elements.clear()
	
	active_skill_tree = null
	
	if SaveManager and SaveManager.meta_progress:
		unlocked_cards = SaveManager.meta_progress.unlocked_cards.duplicate()
	
	# Loop Vesnice bonuses (starting gold se nastavuje jen při novém runu)
	max_hp += VillageBonuses.get_max_hp_bonus()
	starting_retained_block += VillageBonuses.get_battle_start_block()
	
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
	
	# Max HP změna: heal jen o delta (20/50 + Apple → 25/55), ne fullheal na max.
	var max_hp_delta: int = max_hp - old_max_hp
	if max_hp_delta > 0:
		current_hp = mini(preserved_hp + max_hp_delta, max_hp)
	else:
		current_hp = clampi(preserved_hp, 0, max_hp)
	
	# Gold mid-run nesmí přepsat Market bonus / výdělek.
	gold = preserved_gold
	
	DebugLogger.log_info("Finální staty: HP %d/%d, Gold %d, Energy %d, StartBlock %d" % [current_hp, max_hp, gold, max_energy, starting_retained_block], "SKILLS")
	DebugLogger.end_performance_timer("apply_passive_skills")
	emit_signal("health_changed", current_hp, max_hp)

func initialize_player(p_class, p_subclass):
	print("=== INICIALIZACE HRÁČE ===")
	
	if not p_class or not p_subclass:
		printerr("PlayerData: Chyba inicializace! Chybí třída nebo podtřída.")
		return
		
	selected_class = p_class
	selected_subclass = p_subclass
	active_skill_tree = null
	
	print("Třída načtena")
	print("Podtřída načtena")
	
	if SaveManager and SaveManager.meta_progress:
		unlocked_cards = SaveManager.meta_progress.unlocked_cards.duplicate()
		print("✅ Načteno %d odemčených karet" % unlocked_cards.size())
	
	print("=== INICIALIZACE DOKONČENA (skill tree disabled) ===")

# NOVÉ FUNKCE PRO POKROČILÉ EFEKTY

func apply_avatar_starting_block():
	"""Aplikuje Avatar of Light efekt na začátku souboje"""
	if avatar_starting_block_multiplier > 0:
		var bonus_block = int(max_hp * avatar_starting_block_multiplier / 100.0)
		starting_retained_block += bonus_block
		print("Avatar of Light: +%d bloku na začátku souboje (%d%% z %d max HP)" % [bonus_block, avatar_starting_block_multiplier, max_hp])

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
func ensure_unique_master_deck_instances() -> void:
	"""Split shared CardData refs so Seal/meta/upgrades apply to one physical card only."""
	var seen_ids: Dictionary = {}
	for i in master_deck.size():
		var card: CardData = master_deck[i]
		if card == null:
			continue
		var iid: int = card.get_instance_id()
		if seen_ids.has(iid):
			var copy: CardData = card.duplicate(true)
			if copy.has_meta("artifact_sealed"):
				copy.remove_meta("artifact_sealed")
			master_deck[i] = copy
		else:
			seen_ids[iid] = true


func reset_battle_stats():
	ensure_unique_master_deck_instances()
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
			ArtifactManager.on_energy_spent(amount)
		
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

## Vrátí počet použití karty (card_id) v tomto runu. Pro karty s max_uses_before_removal.
func get_card_usage_count(card_id: String) -> int:
	return card_usage_count.get(card_id, 0)

## Zvýší počet použití karty o 1; vrátí novou hodnotu.
func increment_card_usage(card_id: String) -> int:
	var n: int = card_usage_count.get(card_id, 0) + 1
	card_usage_count[card_id] = n
	return n

func discard_hand():
	if current_hand.is_empty():
		return
	var retained: Array[CardData] = []
	for card in current_hand:
		if card != null and card.has_meta("artifact_retain") and bool(card.get_meta("artifact_retain")):
			retained.append(card)
		else:
			add_card_to_discard_pile(card)
	current_hand.clear()
	for card in retained:
		current_hand.append(card)

func reshuffle_discard_into_draw_pile():
	if not discard_pile.is_empty():
		draw_pile.assign(discard_pile)
		discard_pile.clear()
		draw_pile.shuffle()
		if has_node("/root/AudioManager"):
			AudioManager.play_card_shuffle()

func draw_new_hand(hand_size: int = 5):
	current_hand.clear()
	draw_cards(hand_size)

func draw_cards(amount: int) -> int:
	DebugLogger.log_debug("Drawing %d cards" % amount, "CARDS")
	var cards_drawn_count = 0
	
	for _i in range(amount):
		if draw_pile.is_empty():
			# STS-style: reshuffle discard mid-draw when the draw pile runs out.
			if discard_pile.is_empty():
				DebugLogger.log_debug("Draw pile empty, cannot draw more", "CARDS")
				break
			reshuffle_discard_into_draw_pile()
			if draw_pile.is_empty():
				DebugLogger.log_debug("Still empty after reshuffle", "CARDS")
				break
		
		var drawn_card = draw_pile.pop_front()
		if drawn_card is CardData:
			current_hand.append(drawn_card)
			cards_drawn_count += 1
			DebugLogger.log_debug("Drew: %s" % drawn_card.card_name, "CARDS")
	
	# NOVÉ: Trigger draw cards artefakty pokud jsme něco dobrali
	if cards_drawn_count > 0 and has_node("/root/ArtifactManager"):
		ArtifactManager.on_draw_cards(cards_drawn_count, amount)
	
	DebugLogger.log_debug("Cards drawn: %d, Hand size: %d" % [cards_drawn_count, current_hand.size()], "CARDS")
	return cards_drawn_count

# Soubor: scripts/autoload/PlayerData.gd

func add_artifact(new_artifact_resource: ArtifactsData) -> bool:
	"""Přidá artefakt s kontrolou stackování. Vrací true, pokud byl úspěšně přidán/stacknut."""
	if not is_instance_valid(new_artifact_resource):
		printerr("Pokus o přidání nevalidního artefaktu!")
		return false
	
	# Vytvoříme si kopii, abychom neupravovali původní soubor .tres
	var source_path: String = new_artifact_resource.resource_path
	if source_path.is_empty() or source_path == "res://":
		if new_artifact_resource.has_meta("source_path"):
			source_path = str(new_artifact_resource.get_meta("source_path"))
	var new_artifact: ArtifactsData = new_artifact_resource.duplicate()
	if not source_path.is_empty() and source_path != "res://":
		new_artifact.set_meta("source_path", source_path)

	var existing_artifact = find_artifact_by_name(new_artifact.artifact_name)

	if existing_artifact:
		# Artefakt již existuje, zkusíme přidat stack
		# max_stacks > 1 znamená stackovatelný i bez explicitního is_stackable (např. Bojovníkův náramek)
		var can_stack = (existing_artifact.is_stackable or existing_artifact.max_stacks > 1) and existing_artifact.current_stacks < existing_artifact.max_stacks
		if can_stack:
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
		var added_for_behavior = existing_artifact if existing_artifact else new_artifact
		ArtifactManager.on_artifact_acquired(added_for_behavior)

	# Pokud je artefakt pasivní NEBO remake behavior, přepočítat staty
	# (BEHAVIOR Max HP žije v get_passive_max_hp_bonus — apply_passive resetuje base max_hp)
	var added_artifact = existing_artifact if existing_artifact else new_artifact
	if new_artifact.trigger_type == ArtifactsData.TriggerType.PASSIVE \
			or new_artifact.effect_type == ArtifactsData.EffectType.BEHAVIOR \
			or (added_artifact and added_artifact.behavior_script != null):
		apply_passive_skills()

	emit_signal("health_changed", current_hp, max_hp)
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
	"""Vrátí info o stackech pro UI. Pro nové artefakty vrací prázdný řetězec (zbytečně neukazujeme 'nový')."""
	var existing = find_artifact_by_name(artifact_name)
	if not existing:
		return ""  # Nový artefakt - nepřidávat redundantní (nový)
	
	if existing.max_stacks > 1:
		return TranslationHelper.tr_format("ui.shop.artifact.stack", {"current": existing.current_stacks + 1, "max": existing.max_stacks})
	else:
		return tr("ui.shop.artifact.owned")

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
		if has_node("/root/ArtifactManager"):
			ArtifactManager.on_artifact_removed(artifact_data)
			ArtifactManager._refresh_artifact_cache()
		emit_signal("artifacts_changed")


func is_card_instance_sealed(card: CardData) -> bool:
	return card != null and card.has_meta("artifact_sealed") and bool(card.get_meta("artifact_sealed"))


func transfer_seal_on_upgrade(old_card: CardData, new_card: CardData) -> void:
	"""Keep permanent seal across Rest/event upgrades (instance meta only — not card_id)."""
	if old_card == null or new_card == null:
		return
	if not is_card_instance_sealed(old_card):
		return
	if old_card.has_meta("artifact_sealed"):
		old_card.remove_meta("artifact_sealed")
	new_card.set_meta("artifact_sealed", true)
	sealed_card_id = new_card.card_id
	var src := new_card.resource_path
	if src.is_empty() and new_card.has_meta("source_path"):
		src = str(new_card.get_meta("source_path"))
	sealed_card_source_path = src

func add_gold(amount: int):
	self.gold += amount
	if amount > 0 and has_node("/root/AudioManager"):
		AudioManager.play_coins()

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
	loop_level_changed.emit(loop_level)
	artifacts_changed.emit()
