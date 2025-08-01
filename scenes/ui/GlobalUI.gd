# Soubor: res://scenes/ui/GlobalUI.gd (OPRAVENÁ VERZE)
extends CanvasLayer

# --- OPRAVENÉ CESTY PODLE TVÉHO SCREENSHOTU ---
@onready var gold_label: Label = $MarginContainer/MainLayout/TopRow/GoldDisplay/GoldLabel
# Cesta nyní vede přímo k samotnému HP labelu
@onready var hp_label: Label = $MarginContainer/MainLayout/BottomLeft/HPDisplay/HPLabel
# Cesta ke kontejneru, který budeme skrývat (ten se jmenuje BottomLeft)
@onready var hp_container: PanelContainer = $MarginContainer/MainLayout/BottomLeft


func _ready():
	# Připojíme se na signály z PlayerData
	PlayerData.gold_changed.connect(_on_gold_changed)
	PlayerData.health_changed.connect(_on_health_changed)

	# Ihned po vytvoření nastavíme správné počáteční hodnoty
	_on_gold_changed(PlayerData.gold)
	_on_health_changed(PlayerData.current_hp, PlayerData.max_hp)


func _on_gold_changed(new_amount: int):
	if is_instance_valid(gold_label):
		gold_label.text = "Zlato: %d" % new_amount


func _on_health_changed(new_hp: int, new_max_hp: int):
	# Nyní máme přímý odkaz na hp_label, takže je to jednodušší a bezpečnější
	if is_instance_valid(hp_label):
		hp_label.text = "HP: %d/%d" % [new_hp, new_max_hp]


func show_hp():
	if is_instance_valid(hp_container):
		hp_container.show()


func hide_hp():
	if is_instance_valid(hp_container):
		hp_container.hide()
