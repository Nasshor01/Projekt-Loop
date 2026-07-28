@tool
extends VBoxContainer
## Vizuální výběr brush tile z atlasu — klikni na sprite.

signal tile_selected(coord: Vector2i)

var _atlas: Texture2D
var _tile_px: int = 64
var _selected: Vector2i = Vector2i(0, 0)
var _grid: GridContainer
var _label: Label
var _buttons: Dictionary = {} # Vector2i -> Button

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label = Label.new()
	_label.text = "Brush: klikni na tile"
	add_child(_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)

func setup(atlas: Texture2D, tile_px: int, selected: Vector2i) -> void:
	_atlas = atlas
	_tile_px = maxi(tile_px, 1)
	_selected = selected
	_rebuild()

func set_selected(coord: Vector2i) -> void:
	_selected = coord
	_update_selection_visuals()
	_label.text = "Brush: (%d, %d)" % [coord.x, coord.y]

func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_buttons.clear()
	if _atlas == null:
		_label.text = "Žádný floor atlas"
		return

	var img: Image = _atlas.get_image()
	if img == null:
		_label.text = "Atlas nejde načíst"
		return
	if img.is_compressed():
		img.decompress()

	var cols: int = maxi(img.get_width() / _tile_px, 1)
	var rows: int = maxi(img.get_height() / _tile_px, 1)
	_grid.columns = cols

	for y in range(rows):
		for x in range(cols):
			# Poslední řádek sheetu má často prázdné buňky vpravo.
			if y == rows - 1 and x >= 2 and cols == 6:
				continue
			var region := Rect2i(x * _tile_px, y * _tile_px, _tile_px, _tile_px)
			if not Rect2i(Vector2i.ZERO, img.get_size()).encloses(region):
				continue
			var tile_img: Image = img.get_region(region)
			# Přeskoč skoro černé/prázdné
			if _is_mostly_empty(tile_img):
				continue
			var tex := ImageTexture.create_from_image(tile_img)
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(72, 72)
			btn.icon = tex
			btn.expand_icon = true
			btn.tooltip_text = "(%d, %d)" % [x, y]
			var coord := Vector2i(x, y)
			btn.pressed.connect(_on_tile_pressed.bind(coord))
			_grid.add_child(btn)
			_buttons[coord] = btn

	_update_selection_visuals()
	_label.text = "Brush: (%d, %d)" % [_selected.x, _selected.y]

func _is_mostly_empty(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var samples := 0
	var dark := 0
	for yy in range(0, h, 8):
		for xx in range(0, w, 8):
			var c := img.get_pixel(xx, yy)
			samples += 1
			if c.a < 0.05 or c.get_luminance() < 0.04:
				dark += 1
	return samples > 0 and float(dark) / float(samples) > 0.9

func _on_tile_pressed(coord: Vector2i) -> void:
	_selected = coord
	_update_selection_visuals()
	_label.text = "Brush: (%d, %d)" % [coord.x, coord.y]
	tile_selected.emit(coord)

func _update_selection_visuals() -> void:
	for coord in _buttons:
		var btn: Button = _buttons[coord]
		if coord == _selected:
			btn.modulate = Color(1.0, 0.85, 0.2)
		else:
			btn.modulate = Color.WHITE
