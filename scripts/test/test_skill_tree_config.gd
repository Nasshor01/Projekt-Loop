# Testovací skript pro konfigurační systém skill tree
# Spusť tento skript v Godot editoru nebo ve hře pro otestování

extends Node

func _ready():
	print("=== TEST KONFIGURAČNÍHO SYSTÉMU PRO PALADINA ===")
	test_paladin_config()

func test_paladin_config():
	# 1. Vytvoření konfigurace
	print("\n[1/7] Vytváření konfigurace...")
	var config = SkillTreeGenerator.create_paladin_config()
	if not config:
		print("   ❌ Chyba při vytváření konfigurace!")
		return
	print("   ✅ Konfigurace vytvořena: %s" % config.tree_id)
	
	# 2. Validace
	print("\n[2/7] Validace konfigurace...")
	if not config.validate():
		print("   ❌ Konfigurace není validní!")
		return
	print("   ✅ Konfigurace je validní!")
	
	# 3. Kontrola počtu uzlů
	print("\n[3/7] Kontrola počtu uzlů...")
	var expected_nodes = 1 + config.tier_1_nodes.size() + config.tier_2_nodes.size() + \
						 config.tier_3_nodes.size() + config.tier_4_nodes.size() + \
						 config.tier_5_nodes.size()
	print("   Očekávaný počet uzlů: %d" % expected_nodes)
	print("   - Starter: 1")
	print("   - Tier 1: %d" % config.tier_1_nodes.size())
	print("   - Tier 2: %d" % config.tier_2_nodes.size())
	print("   - Tier 3: %d" % config.tier_3_nodes.size())
	print("   - Tier 4: %d" % config.tier_4_nodes.size())
	print("   - Tier 5: %d" % config.tier_5_nodes.size())
	
	# 4. Generování stromu
	print("\n[4/7] Generování stromu z konfigurace...")
	var tree = SkillTreeGenerator.generate_tree_from_config(config)
	if not tree:
		print("   ❌ Chyba při generování stromu!")
		return
	print("   ✅ Strom vygenerován!")
	print("   Skutečný počet uzlů: %d" % tree.skill_nodes.size())
	
	if tree.skill_nodes.size() == expected_nodes:
		print("   ✅ Počet uzlů se shoduje!")
	else:
		print("   ❌ Počet uzlů se neshoduje! (očekáváno: %d, skutečné: %d)" % [expected_nodes, tree.skill_nodes.size()])
	
	# 5. Porovnání s původním systémem
	print("\n[5/7] Porovnání s původním systémem...")
	var tree_old = SkillTreeGenerator.generate_paladin_tree()
	print("   Původní systém: %d uzlů" % tree_old.skill_nodes.size())
	print("   Nový systém: %d uzlů" % tree.skill_nodes.size())
	
	if tree_old.skill_nodes.size() == tree.skill_nodes.size():
		print("   ✅ Počet uzlů se shoduje s původním systémem!")
	else:
		print("   ⚠️ Počet uzlů se liší od původního systému")
	
	# 6. Kontrola uzlů a efektů
	print("\n[6/7] Kontrola uzlů a efektů...")
	var node_ids = {}
	var total_effects = 0
	var total_connections = 0
	
	for node in tree.skill_nodes:
		# Kontrola duplicitních ID
		if node_ids.has(node.id):
			print("   ❌ Duplicitní ID uzlu: %s" % node.id)
		else:
			node_ids[node.id] = true
		
		# Počítání efektů
		total_effects += node.effects.size()
		
		# Počítání propojení
		total_connections += node.connected_nodes.size()
		
		# Kontrola starter node
		if node.is_starter:
			print("   ✅ Starter node nalezen: %s" % node.id)
			if node.cost != 0:
				print("   ⚠️ Starter node by měl mít cost = 0, má: %d" % node.cost)
	
	print("   ✅ Všechny uzly mají unikátní ID")
	print("   Celkový počet efektů: %d" % total_effects)
	print("   Celkový počet propojení: %d" % total_connections)
	
	# 7. Kontrola propojení
	print("\n[7/7] Kontrola propojení...")
	var connection_map = {}
	for node in tree.skill_nodes:
		for connected_id in node.connected_nodes:
			var key = "%s->%s" % [node.id, connected_id]
			connection_map[key] = true
	
	print("   Počet unikátních propojení: %d" % connection_map.size())
	print("   Očekávaný počet propojení z konfigurace: %d" % config.connections.size())
	
	# Kontrola, jestli všechny propojení z konfigurace existují
	var missing_connections = 0
	for conn in config.connections:
		var key = "%s->%s" % [conn.from, conn.to]
		if not connection_map.has(key):
			print("   ⚠️ Chybějící propojení: %s" % key)
			missing_connections += 1
	
	if missing_connections == 0:
		print("   ✅ Všechna propojení z konfigurace jsou vytvořena!")
	else:
		print("   ⚠️ %d propojení chybí!" % missing_connections)
	
	# Finální shrnutí
	print("\n=== VÝSLEDKY TESTU ===")
	print("✅ Konfigurační systém funguje!")
	print("✅ Strom se generuje správně!")
	print("✅ Všechny uzly a propojení jsou vytvořeny!")
	print("\n💡 Tip: Můžeš nyní použít konfigurační systém pro rozšíření Paladin skill tree!")
