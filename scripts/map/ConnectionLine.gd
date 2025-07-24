# ConnectionLine.gd
# Tento skript patří ke scéně ConnectionLine.tscn (kořenový uzel Line2D).
# Stará se o dynamické vykreslování čáry mezi dvěma uzly.
extends Line2D

var node_from: Node2D
var node_to: Node2D

# Funkce pro nastavení počátečního a koncového uzlu čáry.
func setup(from: Node2D, to: Node2D):
	node_from = from
	node_to = to
	
	# Základní nastavení vzhledu čáry.
	width = 4.0
	default_color = Color(0.8, 0.8, 0.8, 0.5)
	antialiased = true
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND

# _process se volá každý snímek. Aktualizuje pozici čáry.
func _process(_delta):
	# Zkontroluje, zda jsou oba uzly stále platné (nebyly smazány).
	if is_instance_valid(node_from) and is_instance_valid(node_to):
		# Vymaže staré body a nastaví nové.
		clear_points()
		
		# Klíčový krok: Převod globálních pozic uzlů do lokálního prostoru Line2D.
		# To je nutné, aby se čára správně vykreslila bez ohledu na to, kde
		# v hierarchii scény se nachází.
		add_point(to_local(node_from.global_position))
		add_point(to_local(node_to.global_position))
