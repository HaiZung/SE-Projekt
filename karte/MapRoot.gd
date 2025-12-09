extends Node2D

const TILE_URL := "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const TILE_SIZE := 256
var zoom: int = 14

func _ready() -> void:
	# Zentrum: Karlsruhe
	var center_lat := 49.0069
	var center_lon := 8.4037

	var center_tile: Vector2i = latlon_to_tile(center_lat, center_lon, zoom)

	# Kamera auf Mittelposition setzen
	$Camera2D.position = Vector2(center_tile.x * TILE_SIZE, center_tile.y * TILE_SIZE)

	# Tiles laden (5x5 um die Mitte)
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var x := center_tile.x + dx
			var y := center_tile.y + dy
			load_tile(x, y)


# -------------------------------
# TILE-Berechnungen & Laden
# -------------------------------

func latlon_to_tile(lat: float, lon: float, z: int) -> Vector2i:
	var lat_rad := deg_to_rad(lat)
	var n := pow(2.0, z)
	var xtile := int((lon + 180.0) / 360.0 * n)
	var ytile := int((1.0 - log(tan(lat_rad) + 1.0 / cos(lat_rad)) / PI) / 2.0 * n)
	return Vector2i(xtile, ytile)


func load_tile(x: int, y: int) -> void:
	var url := TILE_URL.format({"z": zoom, "x": x, "y": y})

	var http := HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if response_code != 200:
			http.queue_free()
			return

		var img := Image.new()
		if img.load_png_from_buffer(body) != OK:
			http.queue_free()
			return

		var tex := ImageTexture.create_from_image(img)

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
		$TileContainer.add_child(spr)

		http.queue_free()
	)

	http.request(url)


# -------------------------------
# Kamera-Steuerung (Drag + Zoom)
# -------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Draggen
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		$Camera2D.position -= event.relative / $Camera2D.zoom.x

	# Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			$Camera2D.zoom *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			$Camera2D.zoom *= 1.1
