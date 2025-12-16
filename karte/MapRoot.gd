extends Node2D

const TILE_URL := "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const TILE_SIZE := 256
var zoom: int = 14


func _ready() -> void:
	# Zentrum: Karlsruhe
	print("READY: map script is running")
	var center_lat := 49.0069
	var center_lon := 8.4037
	$Camera2D.enabled = true


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
	print("Exists? ", FileAccess.file_exists("res://KVVLinesGeoJSON_v2.json"))
	print("Exists? ", FileAccess.file_exists("res://KVV_Haltestelleb_v2.json"))

	load_geojson_lines("res://KVVLinesGeoJSON_v2.json")
	load_stops_from_kvv_json("res://KVV_Haltestellen_v2.json")




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
		spr.centered = false            # ✅ WICHTIG
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
	print("LOAD_GEOJSON start: ", path)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Konnte GeoJSON nicht öffnen: %s" % path)
		return

	var text: String = file.get_as_text()
	print("GeoJSON text length: ", text.length())

	var data_v: Variant = JSON.parse_string(text)
	if data_v == null:
		push_error("GeoJSON konnte nicht geparst werden")
		return

	if not (data_v is Dictionary):
		push_error("GeoJSON root ist kein Dictionary")
		return

	var data: Dictionary = data_v
	if not data.has("features"):
		push_error("GeoJSON hat kein 'features'-Feld")
		return

	var features_v: Variant = data["features"]
	if not (features_v is Array):
		push_error("'features' ist kein Array")
		return

	var features: Array = features_v
	print("GeoJSON features: ", features.size())

	var limit: int = mini(200, features.size())

	var added: int = 0
	var skipped: int = 0
	var type_counts: Dictionary = {}

	for i: int in range(limit):
		var feature_v: Variant = features[i]
		if not (feature_v is Dictionary):
			skipped += 1
			continue
		var feature: Dictionary = feature_v

		var geom_v: Variant = feature.get("geometry", null)
		if geom_v == null or not (geom_v is Dictionary):
			skipped += 1
			continue
		var geom: Dictionary = geom_v

		var t: String = str(geom.get("type", "")).strip_edges()
		type_counts[t] = int(type_counts.get(t, 0)) + 1

		# Farbe
		var col: Color = Color(0, 0.6, 1, 1)
		var props_v: Variant = feature.get("properties", null)
		if props_v is Dictionary:
			var props: Dictionary = props_v
			if props.has("colorCode"):
				var col_str: String = str(props["colorCode"]).strip_edges()
				if col_str.length() == 6 and not col_str.begins_with("#"):
					col_str = "#" + col_str
				col = Color.from_string(col_str, col)

		# Koordinaten-Teile sammeln (LineString => 1 Teil, MultiLineString => mehrere)
		var parts: Array = []

		if t == "LineString":
			var coords1_v: Variant = geom.get("coordinates", null)
			if coords1_v is Array:
				parts.append(coords1_v)
			else:
				skipped += 1
				continue

		elif t == "MultiLineString":
			var coords2_v: Variant = geom.get("coordinates", null)
			if coords2_v is Array:
				var coords2: Array = coords2_v
				for part_v: Variant in coords2:
					if part_v is Array:
						parts.append(part_v)
			else:
				skipped += 1
				continue

		elif t == "GeometryCollection":
			# nur zählen im Debug (noch keine Rekursion)
			skipped += 1
			continue
		else:
			skipped += 1
			continue

		for coords_v: Variant in parts:
			if not (coords_v is Array):
				continue
			var coords: Array = coords_v

			var line: Line2D = Line2D.new()
			line.width = 3.0
			line.antialiased = true
			line.default_color = col
			line.z_index = 1000
			line.z_as_relative = false

			var points_added: int = 0

			for coord_v: Variant in coords:
				if not (coord_v is Array):
					continue
				var coord: Array = coord_v
				if coord.size() < 2:
					continue

				var lon: float = float(coord[0])
				var lat: float = float(coord[1])
				line.add_point(latlon_to_world(lat, lon, zoom))
				points_added += 1

			if points_added >= 2:
				$OverlayContainer.add_child(line)
				added += 1
			else:
				line.queue_free()

	print("GeoJSON DEBUG done. processed: ", limit, " added lines: ", added, " skipped: ", skipped)
	print("Geometry types seen (first ", limit, "): ", type_counts)


# Gibt ein Array von Linien zurück, jede Linie ist Array[Vector2]
# Unterstützt LineString, MultiLineString, GeometryCollection
func _extract_lines_from_geometry(geom: Dictionary, type_counts: Dictionary) -> Array:
	var result: Array = []

	var t := str(geom.get("type", "")).strip_edges()
	if t == "":
		return result

	# type zählen (zum Debug)
	type_counts[t] = int(type_counts.get(t, 0)) + 1

	if t == "LineString":
		var coords = geom.get("coordinates", null)
		var pts := _coords_to_points(coords)
		if pts.size() >= 2:
			result.append(pts)
		return result

	if t == "MultiLineString":
		var parts = geom.get("coordinates", null)
		if parts is Array:
			for part in parts:
				var pts := _coords_to_points(part)
				if pts.size() >= 2:
					result.append(pts)
		return result

	if t == "GeometryCollection":
		var geoms = geom.get("geometries", null)
		if geoms is Array:
			for g in geoms:
				if g is Dictionary:
					result.append_array(_extract_lines_from_geometry(g, type_counts))
		return result

	# alles andere ignorieren
	return result


# Erwartet GeoJSON coords als Array von [lon, lat]
func _coords_to_points(coords) -> Array:
	var pts: Array = []
	if not (coords is Array):
		return pts

	for coord in coords:
		if not (coord is Array) or coord.size() < 2:
			continue

		var lon := float(coord[0])
		var lat := float(coord[1])

		# WGS84 lat/lon -> Pixelwelt
		var world_pos := latlon_to_world(lat, lon, zoom)
		pts.append(world_pos)

	return pts



func _add_linestring_points(line: Line2D, coords) -> void:
	if coords == null or not (coords is Array):
		return

	for coord in coords:
		if coord == null or not (coord is Array) or coord.size() < 2:
			continue

		# GeoJSON: [lon, lat]
		var lon: float = float(coord[0])
		var lat: float = float(coord[1])

		var world_pos := latlon_to_world(lat, lon, zoom)
		line.add_point(world_pos)



# -------------------------------
# Haltestellen Marker (kleiner Kreis)
# -------------------------------
class StopDot extends Node2D:
	var radius: float = 4.0
	var col: Color = Color(1, 1, 1, 1)

	func _ready() -> void:
		z_index = 2000
		z_as_relative = false

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, col)

	func set_style(r: float, c: Color) -> void:
		radius = r
		col = c
		queue_redraw()


# -------------------------------
# KVV Haltestellen (GeoJSON Points) laden
# -------------------------------
func load_stops_from_kvv_json(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Konnte Haltestellen-Datei nicht öffnen: %s" % path)
		return

	var text: String = file.get_as_text()

	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("Stops JSON Parse-Error: %s (line %d, col %d)"
			% [json.get_error_message(), json.get_error_line(), json.get_error_column()])
		return

	if not (json.data is Array):
		push_error("Stops: Root ist kein Array")
		return

	var stops: Array = json.data

	var added: int = 0
	for s_v: Variant in stops:
		if not (s_v is Dictionary):
			continue
		var s: Dictionary = s_v

		var pos_v: Variant = s.get("coordPositionWGS84", null)
		if not (pos_v is Dictionary):
			continue
		var pos: Dictionary = pos_v

		if not pos.has("lat") or not pos.has("long"):
			continue

		var lat: float = float(str(pos["lat"]))
		var lon: float = float(str(pos["long"]))

		var world_pos: Vector2 = latlon_to_world(lat, lon, zoom)

		var dot := StopDot.new()
		dot.position = world_pos
		dot.set_style(4.5, Color(1, 0, 0, 0.95)) # gut sichtbar
		dot.z_index = 2000
		dot.z_as_relative = false

		$OverlayContainer.add_child(dot)
		added += 1

	print("Stops added:", added)




func _add_stop_from_coord(coord_v: Variant) -> void:
	if not (coord_v is Array):
		return
	var coord: Array = coord_v
	if coord.size() < 2:
		return

	# GeoJSON: [lon, lat]
	var lon: float = float(coord[0])
	var lat: float = float(coord[1])

	var pos: Vector2 = latlon_to_world(lat, lon, zoom)

	var dot := StopDot.new()
	dot.set_style(8, Color(1, 1, 1, 0.9)) # Radius + Farbe
	dot.position = pos

	# Damit es über den Tiles & Linien liegt:
	$OverlayContainer.add_child(dot)
