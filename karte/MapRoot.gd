extends Node2D

const TILE_URL := "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const TILE_SIZE := 256
var zoom: int = 14
@onready var route_line: Line2D = $RouteLine

var stop_world_by_name: Dictionary = {}

func _ready() -> void:
	# Zentrum: Karlsruhe
	print("READY: map script is running")
	var center_lat := 49.0069
	var center_lon := 8.4037
	$Camera2D.enabled = true
	$Camera2D.make_current()


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
	print("Exists? ", FileAccess.file_exists("res://karte/KVVLinesGeoJSON_v2.json"))
	print("Exists? ", FileAccess.file_exists("res://karte/KVV_Haltestelleb_v2.json"))

	load_geojson_lines("res://karte/KVVLinesGeoJSON_v2.json")
	load_stops_from_kvv_json("res://karte/KVV_Haltestellen_v2.json")

	# -------------------------------
	# TEST-ROUTE zeichnen
	# -------------------------------

	# set_route_from_geojson("res://karte/KVVLinesGeoJSON_v2.json", "4")





	




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

func draw_route_from_latlon(latlon_points: Array) -> void:
	route_line.clear_points()
	route_line.width = 5.0
	route_line.default_color = Color(1, 0, 0, 1)
	route_line.z_index = 1500
	route_line.z_as_relative = false

	for ll in latlon_points:
		var lat: float = ll.x
		var lon: float = ll.y
		var world_pos := latlon_to_world(lat, lon, zoom)
		route_line.add_point(world_pos)

		#	# Path2D aus der Line2D erzeugen
		# _sync_path_from_line()

		# # Follows initialisieren
		# _setup_follows()


# -------------------------------
# GeoJSON Linien extrahieren
# -------------------------------

func get_route_points_from_geojson(path: String, line_id: String) -> PackedVector2Array:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GeoJSON nicht gefunden: %s" % path)
		return PackedVector2Array()

	var json_text: String = file.get_as_text()
	file.close()

	var data_v: Variant = JSON.parse_string(json_text)
	if not (data_v is Dictionary):
		return PackedVector2Array()

	var data: Dictionary = data_v
	if not data.has("features"):
		return PackedVector2Array()

	var features_v: Variant = data["features"]
	if not (features_v is Array):
		return PackedVector2Array()

	var features: Array = features_v
	var best_points: PackedVector2Array = PackedVector2Array()
	var best_len: float = 0.0

	for f_v in features:
		if not (f_v is Dictionary):
			continue
		var f: Dictionary = f_v
		var props_any: Variant = f.get("properties", {})
		var props: Dictionary = props_any if props_any is Dictionary else {}

		var candidate_raw: Variant = props.get("line", props.get("name", props.get("id", "")))
		var candidate: String = str(candidate_raw).strip_edges()

		if candidate == "" or candidate.find(line_id) == -1:
			continue

		var geom_any: Variant = f.get("geometry", null)
		if not (geom_any is Dictionary):
			continue
		var geom: Dictionary = geom_any

		var pts: PackedVector2Array = _geometry_to_points_longest_part(geom)
		var L: float = _polyline_length(pts)
		if pts.size() >= 2 and L > best_len:
			best_len = L
			best_points = pts

	return best_points

# -------------------------------


func set_route_from_geojson(path: String, line_id: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GeoJSON nicht gefunden: %s" % path)
		return

	var json_text: String = file.get_as_text()
	file.close()

	var data_v: Variant = JSON.parse_string(json_text)
	if not (data_v is Dictionary):
		push_error("GeoJSON Root ist kein Dictionary")
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

	var best_geom: Dictionary = {}
	var best_points: PackedVector2Array = PackedVector2Array()
	var best_len: float = 0.0

	for f_v in features:
		if not (f_v is Dictionary):
			continue
		var f: Dictionary = f_v

		var props_any: Variant = f.get("properties", {})
		var props: Dictionary = {}
		if props_any is Dictionary:
			props = props_any

		# HIER ggf. deinen Key anpassen: "line", "name", "id", ...
		var candidate_raw: Variant = props.get("line", props.get("name", props.get("id", "")))
		var candidate: String = str(candidate_raw).strip_edges()

		if candidate == "" or candidate.find(line_id) == -1:
			continue

		var geom_any: Variant = f.get("geometry", null)
		if not (geom_any is Dictionary):
			continue
		var geom: Dictionary = geom_any

		var pts: PackedVector2Array = _geometry_to_points_longest_part(geom)
		var L: float = _polyline_length(pts)

		if pts.size() >= 2 and L > best_len:
			best_len = L
			best_points = pts
			best_geom = geom

	if best_points.size() < 2:
		push_error("Keine passende Linie gefunden für: %s (evtl. Property-Key anpassen)" % line_id)
		_print_geojson_property_keys(features)
		return

	# RouteLine setzen
	route_line.clear_points()
	route_line.width = 6.0
	route_line.default_color = Color(1, 0, 0, 1)
	route_line.z_index = 1500
	route_line.z_as_relative = false

	for p in best_points:
		route_line.add_point(p)



#Hilfsfunktionen für Simulation
func _geometry_to_points_longest_part(geom: Dictionary) -> PackedVector2Array:
	var t_any: Variant = geom.get("type", "")
	var t: String = str(t_any).strip_edges()

	if t == "LineString":
		var coords_any: Variant = geom.get("coordinates", null)
		return _coords_to_world_points(coords_any)

	if t == "MultiLineString":
		var best: PackedVector2Array = PackedVector2Array()
		var best_len: float = 0.0
		var parts_any: Variant = geom.get("coordinates", null)
		if parts_any is Array:
			var parts: Array = parts_any
			for part in parts:
				var pts: PackedVector2Array = _coords_to_world_points(part)
				var L: float = _polyline_length(pts)
				if pts.size() >= 2 and L > best_len:
					best_len = L
					best = pts
		return best

	if t == "GeometryCollection":
		var best_gc: PackedVector2Array = PackedVector2Array()
		var best_len_gc: float = 0.0
		var geoms_any: Variant = geom.get("geometries", null)
		if geoms_any is Array:
			var geoms: Array = geoms_any
			for g in geoms:
				if g is Dictionary:
					var pts_gc: PackedVector2Array = _geometry_to_points_longest_part(g)
					var L_gc: float = _polyline_length(pts_gc)
					if pts_gc.size() >= 2 and L_gc > best_len_gc:
						best_len_gc = L_gc
						best_gc = pts_gc
		return best_gc

	return PackedVector2Array()

func _coords_to_world_points(coords_v: Variant) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	if not (coords_v is Array):
		return pts

	var coords: Array = coords_v
	for c in coords:
		if not (c is Array) or c.size() < 2:
			continue

		var lon: float = float(c[0])
		var lat: float = float(c[1])
		var world_pos: Vector2 = latlon_to_world(lat, lon, zoom)
		pts.append(world_pos)

	return pts

func _polyline_length(pts: PackedVector2Array) -> float:
	var L: float = 0.0
	for i in range(pts.size() - 1):
		L += pts[i].distance_to(pts[i + 1])
	return L

func _print_geojson_property_keys(features: Array) -> void:
	print("DEBUG: Beispiel-Properties aus GeoJSON (erste max. 5 Features):")
	var limit: int = min(5, features.size())
	for i in range(limit):
		var f_v: Variant = features[i]
		if not (f_v is Dictionary):
			continue
		var f: Dictionary = f_v
		var props_any: Variant = f.get("properties", {})
		if not (props_any is Dictionary):
			continue
		var props: Dictionary = props_any
		print("Feature ", i, " keys: ", props.keys())


#Hilfsfunktionen ende

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

	var limit: int = min(200, features.size())

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

		var name: String = str(s.get("name", "")).strip_edges()
		if name != "":
			stop_world_by_name[name] = world_pos


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



# Damit der Roboter im UI fokussiert werden kann

func focus_on_robot1(smooth: bool = true) -> void:
	var cam: Camera2D = $Camera2D
	var robot: Node2D = get_node_or_null("Robots/Robot1Rig/Path/Follow/Robot1")
	if cam == null or robot == null:
		return

	var target := robot.global_position

	if not smooth:
		cam.global_position = target
		return

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "global_position", target, 0.35)


#Hilsfunktion für Routen-Trimmung
#simulation

func _nearest_point_index_on_route(route: PackedVector2Array, target: Vector2) -> int:
	var best_i := 0
	var best_d := INF
	for i in range(route.size()):
		var d := route[i].distance_squared_to(target)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

func trim_route_from_nearest_projected(route: PackedVector2Array, start_pos: Vector2) -> PackedVector2Array:
	if route.size() < 2:
		return route

	var best_i := 0
	var best_t := 0.0
	var best_d := INF

	# Finde das nächste Segment + Projektion (exakter Punkt auf dem Segment!)
	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var ab := b - a
		var ab_len2 := ab.length_squared()
		if ab_len2 < 0.0001:
			continue

		var t := ((start_pos - a).dot(ab)) / ab_len2
		t = clamp(t, 0.0, 1.0)
		var p := a + ab * t
		var d := p.distance_squared_to(start_pos)

		if d < best_d:
			best_d = d
			best_i = i
			best_t = t

	# Route neu bauen: exakter Startpunkt + restliche Punkte
	var out := PackedVector2Array()
	var a0 := route[best_i]
	var b0 := route[best_i + 1]
	var p0 := a0.lerp(b0, best_t)

	out.append(p0)
	for k in range(best_i + 1, route.size()):
		out.append(route[k])

	# Sicherheit
	if out.size() < 2:
		return route

	return out

func rotate_route_from_nearest_projected(route: PackedVector2Array, start_pos: Vector2) -> PackedVector2Array:
	if route.size() < 2:
		return route

	var best_i := 0
	var best_t := 0.0
	var best_d := INF

	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var ab := b - a
		var ab_len2 := ab.length_squared()
		if ab_len2 < 0.0001:
			continue

		var t := ((start_pos - a).dot(ab)) / ab_len2
		t = clamp(t, 0.0, 1.0)
		var p := a + ab * t
		var d := p.distance_squared_to(start_pos)

		if d < best_d:
			best_d = d
			best_i = i
			best_t = t

	var p0 := route[best_i].lerp(route[best_i + 1], best_t)

	var out := PackedVector2Array()
	out.append(p0)

	# ab nächstem Punkt bis Ende
	for k in range(best_i + 1, route.size()):
		out.append(route[k])
	# dann Anfang bis zum Segment
	for k in range(0, best_i + 1):
		out.append(route[k])

	return out


func debug_show_all_trains() -> void:
	var cam: Camera2D = $Camera2D
	if cam == null:
		print("debug_show_all_trains: NO Camera2D")
		return

	var trains: Array[Node2D] = []
	for name in ["Train1", "Train2", "Train3", "Train4"]:
		if has_node(name):
			trains.append(get_node(name))

	if trains.size() == 0:
		print("debug_show_all_trains: NO trains found")
		return

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	for tr in trains:
		var p := tr.global_position
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)

	var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	cam.global_position = center

	# FIXED zoom raus, damit man "sicher" was sieht
	cam.zoom = Vector2(2.5, 2.5)

	print("debug_show_all_trains OK center=", center, " zoom=", cam.zoom)
	print("train positions:",
		"t1=", trains[0].global_position if trains.size()>0 else "na",
		"t2=", trains[1].global_position if trains.size()>1 else "na",
		"t3=", trains[2].global_position if trains.size()>2 else "na",
		"t4=", trains[3].global_position if trains.size()>3 else "na"
	)


func debug_draw_train_markers() -> void:
	print("debug_draw_train_markers() CALLED")

	# alte Marker löschen (falls vorhanden)
	for c in get_children():
		if c.name.begins_with("DBG_"):
			c.queue_free()

	for name in ["Train1","Train2","Train3","Train4"]:
		if not has_node(name):
			print("DBG: Missing train node:", name)
			continue

		var tr := get_node(name) as Node2D
		print("DBG:", name, "pos=", tr.global_position)

		var dot := Node2D.new()
		dot.name = "DBG_" + name
		dot.position = tr.global_position
		dot.z_index = 99999
		dot.z_as_relative = false

		# eigener Draw: roter Kreis
		dot.set_process(false)
		dot.set_physics_process(false)

		# Trick: CanvasItem draw geht nur in _draw einer Node2D mit Script,
		# deshalb nutzen wir einen ColorRect als Marker (funktioniert IMMER).
		var rect := ColorRect.new()
		rect.color = Color(1,1,1,1)
		if name == "Train1": rect.color = Color(1,0,0,1)
		if name == "Train2": rect.color = Color(0,1,0,1)
		if name == "Train3": rect.color = Color(0,0,1,1)
		if name == "Train4": rect.color = Color(1,1,0,1)
		rect.size = Vector2(14, 14)
		rect.position = Vector2(-7, -7)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		dot.add_child(rect)
		add_child(dot)

	print("DBG markers ADDED")


func draw_route_debug(points: PackedVector2Array, col: Color, width := 5.0) -> void:
	if points.size() < 2:
		return
	var line := Line2D.new()
	line.width = width
	line.default_color = col
	line.z_as_relative = false
	line.z_index = 2000
	for p in points:
		line.add_point(p)
	$OverlayContainer.add_child(line)

func draw_debug_route(points: PackedVector2Array, col: Color = Color(1, 1, 0), width: float = 4.0) -> void:
	if points.size() < 2:
		print("draw_debug_route: too few points")
		return

	var line := Line2D.new()
	line.width = width
	line.default_color = col
	line.antialiased = true
	line.z_as_relative = false
	line.z_index = 2000  # über tiles & kvv-lines

	for p in points:
		line.add_point(p)

	# wichtig: in denselben OverlayContainer wie deine anderen Linien/Dots
	if has_node("OverlayContainer"):
		$OverlayContainer.add_child(line)
	else:
		add_child(line)


# func _sync_path_from_line() -> void:
# 	if route_line.points.size() < 2:
# 		push_error("RouteLine hat zu wenige Punkte -> Path kann nicht gebaut werden.")
# 		return

# 	var curve := Curve2D.new()
# 	for p in route_line.points:
# 		curve.add_point(p)

# 	route_path.curve = curve

# func _setup_follows() -> void:
# 	for f in follows:
# 		f.loop = true
# 		f.rotates = true  # Zug richtet sich entlang der Strecke aus (optional)

# 	# Start-Abstände (damit sie nicht übereinander stehen)
# 	follows[0].progress = 0.0
# 	follows[1].progress = 300.0
# 	follows[2].progress = 600.0
# 	follows[3].progress = 900.0

# func _process(delta: float) -> void:
# 	# nur fahren, wenn Route gesetzt ist
# 	if route_path.curve == null or route_path.curve.get_point_count() < 2:
# 		return

# 	for i in range(follows.size()):
# 		follows[i].progress += train_speeds[i] * delta



func point_at_distance(route: PackedVector2Array, dist: float) -> Vector2:
	if route.size() < 2:
		return Vector2.ZERO

	var remaining := dist
	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.001:
			continue
		if remaining <= seg:
			return a.lerp(b, remaining / seg)
		remaining -= seg

	return route[route.size() - 1]


func points_to_curve(points: PackedVector2Array) -> Curve2D:
	var curve := Curve2D.new()
	for p in points:
		curve.add_point(p)
	return curve


func _get_all_robots() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for i in [1,2,3,4]:
		var r := get_node_or_null("Robots/Robot%dRig/Path/Follow/Robot%d" % [i,i]) as Node2D
		if r != null:
			out.append(r)
	return out

func debug_show_all_robots() -> void:
	var cam: Camera2D = $Camera2D
	if cam == null:
		return

	var robots := _get_all_robots()
	if robots.size() == 0:
		print("debug_show_all_robots: none found")
		return

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	for r in robots:
		var p := r.global_position
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)

	cam.global_position = Vector2((min_x+max_x)*0.5, (min_y+max_y)*0.5)
	cam.zoom = Vector2(2.5, 2.5)
