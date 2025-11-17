extends PanelContainer

@onready var portrait: TextureRect = %Portrait
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_label: Label = %Tooltip/Label

var unit: Unit
var _turn_manager: Node

# NOVÉ PROMĚNNÉ: Použijeme je k "odložení" nastavení,
# dokud nebude scéna plně připravena.
var _unit_ref: Unit = null
var _turn_manager_ref: Node = null
var _is_setup_pending: bool = false


# Tato funkce se zavolá AŽ POTÉ, co jsou všechny @onready
# proměnné (jako %Portrait) úspěšně načteny.
func _ready():
	# Pokud byl setup() zavolán PŘEDTÍM, než bylo _ready hotové,
	# musíme teď ta data aplikovat.
	if _is_setup_pending:
		_apply_setup_data()
		_is_setup_pending = false


func setup(unit_ref: Unit, turn_manager: Node):
	# Krok 1: Vždy jen uložíme data, která přišla.
	_unit_ref = unit_ref
	_turn_manager_ref = turn_manager

	# Krok 2: Zkontrolujeme, jestli už je scéna "ready".
	# Uděláme to tak, že zkontrolujeme jednu z @onready proměnných.
	if portrait == null:
		# 'portrait' je @onready, takže pokud je null, scéna ještě není připravená.
		# Nastavíme si "vlaječku", že musíme počkat na _ready().
		_is_setup_pending = true
	else:
		# Scéna už připravená je (např. voláme setup() později).
		# Můžeme data aplikovat rovnou.
		_apply_setup_data()


# NOVÁ FUNKCE: Toto je kód, který byl původně v setup()
func _apply_setup_data():
	# Bezpečně zkopírujeme data z dočasných proměnných
	unit = _unit_ref
	_turn_manager = _turn_manager_ref
	
	# Pro jistotu zkontrolujeme, jestli @onready proměnné opravdu existují
	if not is_instance_valid(portrait):
		printerr("InitiativeIcon: @onready var 'portrait' se nepodařilo načíst!")
		return
	if not is_instance_valid(tooltip_label):
		printerr("InitiativeIcon: @onready var 'tooltip_label' se nepodařilo načíst!")
		return

	# Teď už můžeme bezpečně spustit původní kód ze setup()
	if is_instance_valid(unit) and is_instance_valid(unit.unit_data):
		
		if unit.unit_data.sprite_texture != null:
			portrait.texture = unit.unit_data.sprite_texture
		else:
			portrait.texture = null

		var base_init = unit.unit_data.initiative
		var mod = 0
		if _turn_manager and _turn_manager.has_method("get_initiative_modifier_for_unit"):
			mod = _turn_manager.get_initiative_modifier_for_unit(unit)
		var total_initiative = base_init + mod

		tooltip_label.text = "%s\\nIniciativa: %d" % [unit.unit_data.unit_name, total_initiative]
	else:
		portrait.texture = null
		tooltip_label.text = "Neznámá jednotka"

	tooltip.hide()


func set_active(is_active: bool):
	"""Vizuálně zvýrazní ikonu, pokud je jednotka na tahu."""
	if is_active:
		self_modulate = Color.YELLOW
	else:
		self_modulate = Color.WHITE

func _on_mouse_entered():
	tooltip.show()

func _on_mouse_exited():
	tooltip.hide()
