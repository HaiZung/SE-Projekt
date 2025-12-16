extends Node2D

const TILE_URL := "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const TILE_SIZE := 256
var zoom: int = 14


func _ready() -> void:
	# Zentrum: Karlsruhe
	var center_lat := 49.0069
	var center_lon := 8.4037

	# Weltkoordinaten des Zentrums (selbe Funktion wie für Linien)
	var center_world := latlon_to_world(center_lat, center_lon, zoom)
	$Camera2D.position = center_world

	# Tile-Index des Zentrums
	var center_tile: Vector2i = latlon_to_tile(center_lat, center_lon, zoom)

	# Tiles laden (größerer Ausschnitt)
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var x := center_tile.x + dx
			var y := center_tile.y + dy
			load_tile(x, y)

	# 👉 KVV GeoJSON laden & Linien zeichnen
	load_geojson_lines("res://data/KVVLinesGeoJSON_v2.json")



# -------------------------------
# TILE-Berechnungen & Laden
# -------------------------------

# Nur noch int-Tileindex, abgeleitet aus derselben Formel
func latlon_to_tile(lat: float, lon: float, z: int) -> Vector2i:
	var world := latlon_to_world(lat, lon, z) / TILE_SIZE
	return Vector2i(int(world.x), int(world.y))


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



# -------------------------------
# lat/lon -> Weltkoordinaten
# -------------------------------

# WGS84 -> "Slippy Map"-Pixelkoordinaten in deiner Welt
func latlon_to_world(lat: float, lon: float, z: int) -> Vector2:
	var lat_rad := deg_to_rad(lat)
	var n := pow(2.0, z)
	var x_tile := (lon + 180.0) / 360.0 * n
	var y_tile := (1.0 - log(tan(lat_rad) + 1.0 / cos(lat_rad)) / PI) / 2.0 * n
	return Vector2(x_tile * TILE_SIZE, y_tile * TILE_SIZE)



# -------------------------------
# KVV GeoJSON Linien laden
# -------------------------------
func load_geojson_lines(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Konnte GeoJSON nicht öffnen: %s" % path)
		return

	var text := file.get_as_text()
	var data = JSON.parse_string(text)
	if data == null:
		push_error("GeoJSON konnte nicht geparst werden")
		return

	if not (data is Dictionary) or not data.has("features"):
		push_error("GeoJSON hat kein 'features'-Feld")
		return

	var features: Array = data["features"]

	for feature in features:
		if not (feature is Dictionary) or not feature.has("geometry"):
			continue

		var geom = feature["geometry"]
		if not (geom is Dictionary):
			continue
		if not geom.has("type") or geom["type"] != "LineString":
			continue
		if not geom.has("coordinates"):
			continue

		var coords = geom["coordinates"]  # Array aus [lon, lat]

		var line := Line2D.new()
		line.width = 2.0
		line.antialiased = true

		# Farbe aus properties.colorCode
		if feature.has("properties"):
			var props = feature["properties"]
			if props.has("colorCode"):
				var col_str: String = props["colorCode"]
				line.default_color = Color.from_string(col_str, Color(1, 0, 0))
			else:
				line.default_color = Color(0, 0.6, 1)
		else:
			line.default_color = Color(0, 0.6, 1)

		for coord in coords:
			if coord.size() < 2:
				continue
			var lon: float = coord[0]  # GeoJSON: [lon, lat]
			var lat: float = coord[1]
			var world_pos := latlon_to_world(lat, lon, zoom)
			line.add_point(world_pos)

		if line.points.size() > 1:
			$OverlayContainer.add_child(line)

