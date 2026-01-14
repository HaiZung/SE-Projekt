extends Node

# -----------------------------
# Backend-Dateien
# -----------------------------
@export var lines_path := "res://karte/KVV_Lines_v2.json"
@export var stops_path := "res://karte/KVV_Haltestellen_v2.json"
@export var geojson_lines_path := "res://karte/KVVLinesGeoJSON_v2.json"

# -----------------------------
# Simulation / Timing
# -----------------------------
@export var time_scale_speed := 1.0
@export var break_after_seconds := 6.0
@export var unload_wait_seconds := 2.0
@export var afternoon_wait_seconds := 3.0

# -----------------------------
# Route-Config pro Roboter (Backend-basiert)
# -----------------------------
@export var r1_line: String = "S1"
@export var r1_start_id: String = "de:08212:90"      # Karlsruhe Hbf
@export var r1_target_id: String = "de:08212:1207"   # Karlsruhe Schloss Rüppurr

@export var r2_line: String = "2"
@export var r2_start_id: String = "de:08212:90"		 # Karlsruhe Hbf
@export var r2_target_id: String = "de:08212:39"     # Mühlburger Tor

@export var r3_line: String = "3"
@export var r3_start_id: String = "de:08212:90"		 # Karlsruhe Hbf
@export var r3_target_id: String = "de:08212:80"     # Kronenplatz

# Robot4: lädt nur, keine Route
@export var r4_enabled: bool = false
@export var r4_offset_progress: float = 50.0

# -----------------------------
# Node refs
# -----------------------------
@onready var map_root := get_parent()

@onready var r1_path: Path2D = map_root.get_node("Robots/Robot1Rig/Path")
@onready var r2_path: Path2D = map_root.get_node("Robots/Robot2Rig/Path")
@onready var r3_path: Path2D = map_root.get_node("Robots/Robot3Rig/Path")
@onready var r4_path: Path2D = map_root.get_node("Robots/Robot4Rig/Path")

@onready var r1_follow: PathFollow2D = map_root.get_node("Robots/Robot1Rig/Path/Follow")
@onready var r2_follow: PathFollow2D = map_root.get_node("Robots/Robot2Rig/Path/Follow")
@onready var r3_follow: PathFollow2D = map_root.get_node("Robots/Robot3Rig/Path/Follow")
@onready var r4_follow: PathFollow2D = map_root.get_node("Robots/Robot4Rig/Path/Follow")

@export var speed1 := 40.0
@export var speed2 := 40.0
@export var speed3 := 40.0
@export var speed4 := 40.0

@onready var api := get_node_or_null("/root/MainUI/HTTPRequest")

var running := false
var r1_running := false
var r2_running := false
var r3_running := false
var r4_running := false

# Defekt-Status speichern
var r1_defective := false
var r2_defective := false
var r3_defective := false
var r4_defective := false

var _run_id: int = 0
var has_started_once := false
var paused := false
var initialized := false  

func _ready() -> void:
	# Warte bis alles geladen ist
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Backend laden für Haltestellen-Positionen
	if not _load_backend():
		return
	
	var hbf_world := stop_world_by_id.get("de:08212:90", Vector2.ZERO) as Vector2
	
	# Kamera auf HBF
	var cam := map_root.get_node_or_null("Camera2D") as Camera2D
	if cam and hbf_world != Vector2.ZERO:
		cam.make_current()
		cam.global_position = hbf_world
		cam.zoom = Vector2(0.7, 0.7)
	
	# Alle 4 Roboter am HBF initialisieren
	if hbf_world != Vector2.ZERO and map_root != null:
		# Mini-Curve für statische Position am HBF (etwas länger für Verteilung)
		var init_pts := PackedVector2Array([hbf_world, hbf_world + Vector2(50, 0)])
		
		# Curves für alle 4 Roboter setzen
		r1_path.curve = map_root.points_to_curve(init_pts)
		r2_path.curve = map_root.points_to_curve(init_pts)
		r3_path.curve = map_root.points_to_curve(init_pts)
		r4_path.curve = map_root.points_to_curve(init_pts)
		
		await get_tree().process_frame
		
		# PathFollow2D mit leicht unterschiedlichen Positionen
		var offsets := [0.0, 12.0, 24.0, 36.0]  # Pixel-Offsets entlang der Curve
		var follows := [r1_follow, r2_follow, r3_follow, r4_follow]
		
		for i in range(4):
			follows[i].loop = false
			follows[i].rotates = true
			follows[i].progress = offsets[i] + 0.1
		
		await get_tree().process_frame
		
		for i in range(4):
			follows[i].progress = offsets[i]
		
		await get_tree().process_frame
		
		# Alle sichtbar machen und einfärben
		_set_robot_visible(1)
		_set_robot_visible(2)
		_set_robot_visible(3)
		_set_robot_visible(4)
		
		_set_robot_color(1)
		_set_robot_color(2)
		_set_robot_color(3)
		_set_robot_color(4)
		
		print("All 4 robots initialized at HBF:")
		print("R1:", r1_follow.global_position)
		print("R2:", r2_follow.global_position)
		print("R3:", r3_follow.global_position)
		print("R4:", r4_follow.global_position)
	

# -----------------------------
# Backend-Daten
# -----------------------------
var stop_world_by_id: Dictionary = {}         # "de:..." -> Vector2(world)
var stop_name_by_id: Dictionary = {}          # "de:..." -> "Karlsruhe Hbf"
var line_stations_by_number: Dictionary = {}  # "s7"/"2"/"3" -> Array[String stationId]

# Merken für Rückfahrt / Defekt
var r1_pts := PackedVector2Array()
var r2_pts := PackedVector2Array()
var r3_pts := PackedVector2Array()

# =========================================================
# START
# =========================================================
func start_simulation() -> void:
	# Wenn schon läuft: nichts tun
	if running and not paused:
		print("SIM: already running -> ignore start")
		return

	# Wenn pausiert: nur weiterlaufen lassen
	if paused and initialized:
		print("SIM RESUME")
		paused = false
		running = true
		# Nur die nicht-defekten Roboter wieder starten
		if not r1_defective:
			r1_running = true
		if not r2_defective:
			r2_running = true
		if not r3_defective:
			r3_running = true
		if not r4_defective:
			r4_running = true
		set_process(true)
		return

	# Sonst: echter erster Start
	print("SIM START (fresh)")
	paused = false
	running = true
	_run_id += 1
	var my_id := _run_id
	set_process(true)

	await _run(my_id)

	# nur wenn das noch der aktuelle Run ist
	if my_id == _run_id and not paused:
		print("SIM END id=", my_id)
		running = false
		set_process(false)



func _process(delta: float) -> void:
	if not running:
		return

	var d := delta * time_scale_speed

	if r1_running and _has_curve(r1_path): r1_follow.progress += speed1 * d
	if r2_running and _has_curve(r2_path): r2_follow.progress += speed2 * d
	if r3_running and _has_curve(r3_path): r3_follow.progress += speed3 * d
	if r4_running and _has_curve(r4_path): r4_follow.progress += speed4 * d

# =========================================================
# MAIN RUN
# =========================================================
func _run(my_id: int) -> void:
	if my_id != _run_id:
		return
	if not _load_backend():
		return
	if my_id != _run_id:
		return

	# 0) Backend laden
	if not _load_backend():
		return

	# 1) Start (HBF) World
	var hbf_world := stop_world_by_id.get("de:08212:90", Vector2.ZERO) as Vector2
	if hbf_world == Vector2.ZERO:
		push_error("HBF stop id de:08212:90 not found in stops JSON")
		return

	# Kamera auf HBF
	var cam := map_root.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
		cam.global_position = hbf_world
		cam.zoom = Vector2(0.7, 0.7)

	# 2) Routen bauen
	r1_pts = build_route_points(r1_line, r1_start_id, r1_target_id)
	r2_pts = build_route_points(r2_line, r2_start_id, r2_target_id)
	r3_pts = build_route_points(r3_line, r3_start_id, r3_target_id)

	if r1_pts.size() < 2 or r2_pts.size() < 2 or r3_pts.size() < 2:
		push_error("One or more routes are too short. Check line + station ids.")
		print("sizes r1=", r1_pts.size(), " r2=", r2_pts.size(), " r3=", r3_pts.size())
		return
	
	# 3) Curves setzen (dein map_root hat points_to_curve)
	r1_path.curve = map_root.points_to_curve(r1_pts)
	print("HBF world:", stop_world_by_id.get("de:08212:90", Vector2.ZERO))
	print("Robot1 start global:", r1_follow.global_position)
	print("Curve first:", r1_path.curve.get_point_position(0))
	print("Curve last:", r1_path.curve.get_point_position(r1_path.curve.get_point_count()-1))

	r2_path.curve = map_root.points_to_curve(r2_pts)
	r3_path.curve = map_root.points_to_curve(r3_pts)

	# Robot4: erstmal "charging" am HBF (statische Position)
	var r4_pts := PackedVector2Array([hbf_world, hbf_world + Vector2(1, 0)])
	r4_path.curve = map_root.points_to_curve(r4_pts)
	initialized = true

	print("CURVE COUNTS:",
		"r1=", r1_path.curve.get_point_count() if r1_path.curve else -1,
		"r2=", r2_path.curve.get_point_count() if r2_path.curve else -1,
		"r3=", r3_path.curve.get_point_count() if r3_path.curve else -1
	)

	# 4) Follow Setup (Offsets nur damit sie nicht exakt übereinander liegen)
	_setup_follow(r1_follow, 0.0)
	var r1 := map_root.get_node_or_null("Robots/Robot1Rig/Path/Follow/Robot1") as Node2D
	print("Robot1 local pos in Follow:", str(r1.position) if r1 else "NULL")
	print("Robot1Rig pos:", map_root.get_node("Robots/Robot1Rig").position)
	print("Path pos:", r1_path.position, "Follow pos:", r1_follow.position)
	print("Rig scale:", map_root.get_node("Robots/Robot1Rig").scale, "Follow scale:", r1_follow.scale)

	_setup_follow(r2_follow, 15.0)
	_setup_follow(r3_follow, 30.0)
	_setup_follow(r4_follow, 0.0)  # Robot 4 am Anfang der Curve

	_set_robot_visible(1)
	_set_robot_visible(2)
	_set_robot_visible(3)
	_set_robot_visible(4)
	
	_set_robot_color(1)
	_set_robot_color(2)
	_set_robot_color(3)
	_set_robot_color(4)

	await get_tree().process_frame

	print("R1 start:", r1_follow.global_position, " target:", stop_world_by_id.get(r1_target_id, Vector2.ZERO))
	print("R2 start:", r2_follow.global_position, " target:", stop_world_by_id.get(r2_target_id, Vector2.ZERO))
	print("R3 start:", r3_follow.global_position, " target:", stop_world_by_id.get(r3_target_id, Vector2.ZERO))

	# 5) States
	await _set_state(1, "aktiv")
	await _set_state(2, "aktiv")
	await _set_state(3, "aktiv")
	await _set_state(4, "charging")

	# 6) Start fahren
	r1_running = true
	r2_running = true
	r3_running = true
	r4_running = true

	# 7) Robot3 wird defekt
	await get_tree().create_timer(break_after_seconds).timeout
	r3_running = false
	r3_defective = true  # Defekt-Status speichern
	await _set_state(3, "defective")

	# 8) Warten bis 1 + 2 am Ende (am Ziel)
	await _wait_arrive_follow(r1_follow)
	await _set_state(1, "unloading")
	await get_tree().create_timer(unload_wait_seconds).timeout
	await _set_state(1, "waiting_return")

	await _wait_arrive_follow(r2_follow)
	await _set_state(2, "unloading")
	await get_tree().create_timer(unload_wait_seconds).timeout
	await _set_state(2, "waiting_return")

	await _wait_arrive_follow(r2_follow)
	await _set_state(3, "unloading")
	await get_tree().create_timer(unload_wait_seconds).timeout
	await _set_state(3, "waiting_return")

	# 9) Warten bis pakete leer sind
	await get_tree().create_timer(afternoon_wait_seconds).timeout

	# 10) Rückfahrt (Route reversed)
	var r1_back := r1_pts.duplicate()
	r1_back.reverse()
	var r2_back := r2_pts.duplicate()
	r2_back.reverse()
	var r3_back := r3_pts.duplicate()
	r3_back.reverse()


	r1_path.curve = map_root.points_to_curve(r1_back)
	r2_path.curve = map_root.points_to_curve(r2_back)
	r3_path.curve = map_root.points_to_curve(r3_back)

	_setup_follow(r1_follow, 0.0)
	_setup_follow(r2_follow, 15.0)
	_setup_follow(r3_follow, 30.0)

	await _set_state(1, "returning")
	await _set_state(2, "returning")
	await _set_state(3, "maintenance_en_route")

	r1_running = true
	r2_running = true
	r3_running = true

	await _wait_arrive_follow(r1_follow)
	await _wait_arrive_follow(r2_follow)
	await _wait_arrive_follow(r3_follow)

	await _set_state(1, "done")
	await _set_state(2, "done")
	await _set_state(3, "maintenance")
	await _set_state(4, "ready")

# =========================================================
# BACKEND LOAD + ROUTE BUILD
# =========================================================
func _load_backend() -> bool:
	stop_world_by_id.clear()
	stop_name_by_id.clear()
	line_stations_by_number.clear()

	# -------------------------
	# Stops laden
	# -------------------------
	var stops_text := _read_text(stops_path)
	if stops_text == "":
		push_error("Could not read stops_path: " + stops_path)
		return false

	var stops_parsed: Variant = JSON.parse_string(stops_text)
	var stops_data: Array = []

	if stops_parsed is Array:
		stops_data = stops_parsed
	elif stops_parsed is Dictionary:
		# falls mal in einem wrapper liegt
		var d: Dictionary = stops_parsed
		for k in ["stops", "stations", "haltestellen", "data"]:
			if d.has(k) and d[k] is Array:
				stops_data = d[k]
				break
	else:
		push_error("Stops JSON has unknown root type.")
		return false

	if stops_data.is_empty():
		push_error("Stops JSON array is empty or not found.")
		return false

	for s_v in stops_data:
		if not (s_v is Dictionary): continue
		var s: Dictionary = s_v

		var sid := str(s.get("triasID", "")).strip_edges()
		if sid == "": continue

		stop_name_by_id[sid] = str(s.get("name", ""))

		var pos_v: Variant = s.get("coordPositionWGS84", null)
		if not (pos_v is Dictionary): continue
		var pos: Dictionary = pos_v

		if not pos.has("lat") or not pos.has("long"): continue

		var lat := float(str(pos["lat"]))
		var lon := float(str(pos["long"]))

		var world := _latlon_to_world(lat, lon)
		stop_world_by_id[sid] = world



	# -------------------------
	# Lines laden
	# -------------------------
	var lines_text := _read_text(lines_path)
	if lines_text == "":
		push_error("Could not read lines_path: " + lines_path)
		return false

	var lines_parsed: Variant = JSON.parse_string(lines_text)
	var lines_data: Array = []

	# WICHTIG: bei dir ist das oft { "lines": [ ... ] }
	if lines_parsed is Array:
		lines_data = lines_parsed
	elif lines_parsed is Dictionary:
		var d2: Dictionary = lines_parsed
		if d2.has("lines") and d2["lines"] is Array:
			lines_data = d2["lines"]
	else:
		push_error("Lines JSON has unknown root type.")
		return false

	if lines_data.is_empty():
		push_error("Lines JSON array is empty or not found.")
		return false

	for l_v in lines_data:
		if not (l_v is Dictionary): continue
		var l: Dictionary = l_v

		var num := str(l.get("number", l.get("disassembledName", l.get("name", "")))).strip_edges()
		if num == "": continue

		var stations_v: Variant = l.get("stations", null)
		if not (stations_v is Array): continue

		line_stations_by_number[num.to_lower()] = stations_v

	print("BACKEND loaded. stops=", stop_world_by_id.size(), " lines=", line_stations_by_number.size())
	return true

func build_route_points(line_number: String, start_id: String, target_id: String) -> PackedVector2Array:
	start_id = _normalize_station_id(start_id)
	target_id = _normalize_station_id(target_id)

	var key := line_number.to_lower()
	if not line_stations_by_number.has(key):
		push_warning("Line not found in backend: " + line_number)
		return PackedVector2Array()

	if not stop_world_by_id.has(start_id):
		push_warning("Start stop id not found in stops: " + start_id)
		return PackedVector2Array()
	if not stop_world_by_id.has(target_id):
		push_warning("Target stop id not found in stops: " + target_id)
		return PackedVector2Array()

	var stations: Array = line_stations_by_number[key]
	var start_world: Vector2 = stop_world_by_id[start_id]
	var target_world: Vector2 = stop_world_by_id[target_id]

	# Indexe finden: wenn start/target nicht direkt in Liste, nimm nächstgelegene Station dieser Linie
	var a := stations.find(start_id)
	if a == -1:
		a = _find_nearest_station_index(stations, start_world)

	var b := stations.find(target_id)
	if b == -1:
		b = _find_nearest_station_index(stations, target_world)

	if a == -1 or b == -1:
		push_warning("Could not resolve indices for line " + line_number + " | start=" + start_id + " target=" + target_id)
		return PackedVector2Array()

	var pts := PackedVector2Array()

	# Damit es wirklich am “HBF-Punkt” startet (auch wenn HBF nicht in stations drin ist)
	pts.append(start_world)

	if a <= b:
		for i in range(a, b + 1):
			var sid := _normalize_station_id(str(stations[i]))
			if stop_world_by_id.has(sid):
				pts.append(stop_world_by_id[sid])
	else:
		for i in range(a, b - 1, -1):
			var sid := _normalize_station_id(str(stations[i]))
			if stop_world_by_id.has(sid):
				pts.append(stop_world_by_id[sid])

	# Und wirklich am Ziel enden (auch wenn Ziel evtl. nicht exakt getroffen wurde)
	pts.append(target_world)

	# Dedupe: falls gleiche Punkte direkt hintereinander
	return _compress_consecutive_duplicates(pts)

func _find_nearest_station_index(stations: Array, world: Vector2) -> int:
	var best_i := -1
	var best_d := INF

	for i in range(stations.size()):
		var sid := str(stations[i])
		if not stop_world_by_id.has(sid):
			continue
		var p: Vector2 = stop_world_by_id[sid]
		var d := p.distance_squared_to(world)
		if d < best_d:
			best_d = d
			best_i = i

	return best_i


func _compress_consecutive_duplicates(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var last := Vector2(INF, INF)
	for p in pts:
		if p != last:
			out.append(p)
			last = p
	return out

func _latlon_to_world(lat: float, lon: float) -> Vector2:
	# nutzt deine MapRoot-Funktion, falls vorhanden
	if map_root != null and map_root.has_method("latlon_to_world"):
		var z := 14
		# sicher "zoom" lesen, ohne has_variable()
		if map_root != null:
			var zv: Variant = map_root.get("zoom")   # gibt null zurück, wenn nicht vorhanden
			if zv != null:
				z = int(zv)
		return map_root.latlon_to_world(lat, lon, z)

	# Fallback (sollte bei dir praktisch nie passieren)
	return Vector2(lon * 100000.0, -lat * 100000.0)


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

# =========================================================
# HELPERS
# =========================================================
func _setup_follow(f: PathFollow2D, start_progress: float) -> void:
	f.loop = false
	f.rotates = true
	f.progress = start_progress

	# wichtig: keine Offsets im Follow selbst
	f.position = Vector2.ZERO
	f.rotation = 0.0
	f.scale = Vector2.ONE

	# optional: den Roboter-Child im Follow auf 0 setzen
	for c in f.get_children():
		if c is Node2D:
			(c as Node2D).position = Vector2.ZERO
			(c as Node2D).rotation = 0.0
			(c as Node2D).scale = Vector2.ONE


func _has_curve(p: Path2D) -> bool:
	return p != null and p.curve != null and p.curve.get_point_count() >= 2

func _wait_arrive_follow(f: PathFollow2D) -> void:
	while f.progress_ratio < 1.0:
		await get_tree().process_frame

func _set_state(id: int, status: String) -> void:
	if api != null and api.has_method("update_robot_status"):
		await api.update_robot_status(id, status)
	else:
		print("STATE:", id, status)

func _set_robot_visible(i: int) -> void:
	var robot := map_root.get_node_or_null("Robots/Robot%dRig/Path/Follow/Robot%d" % [i, i]) as Node2D
	if robot:
		robot.visible = true
		robot.z_as_relative = false
		robot.z_index = 250
		print("Set Robot", i, "visible. Position:", robot.global_position)
	else:
		print("WARNING: Robot", i, "node not found!")

func _set_robot_color(i: int) -> void:
	var sprite := map_root.get_node_or_null("Robots/Robot%dRig/Path/Follow/Robot%d/Sprite2D" % [i, i]) as Sprite2D
	if sprite:
		var colors := [
			Color(0.2, 0.6, 1.0),  # Robot 1: Blau
			Color(1.0, 0.4, 0.2),  # Robot 2: Orange
			Color(0.3, 1.0, 0.3),  # Robot 3: Grün
			Color(1.0, 1.0, 0.2)   # Robot 4: Gelb (Techniker)
		]
		sprite.modulate = colors[i - 1]

func _normalize_station_id(id: String) -> String:
	var s := id.strip_edges()
	# Wenn Stop nicht existiert und ID hat extra Suffix (z.B. :4), schneide hinten ab
	while (not stop_world_by_id.has(s)) and s.count(":") >= 3:
		var cut := s.rfind(":")
		if cut <= 0:
			break
		s = s.substr(0, cut)
	return s


func stop_simulation() -> void:
	print("SIM PAUSE pressed. running=", running)

	if not initialized:
		return

	paused = true
	running = false

	# Bewegungen stoppen
	r1_running = false
	r2_running = false
	r3_running = false
	r4_running = false

	set_process(false)

	# optional UI/backend status:
	await _set_state(1, "paused")
	await _set_state(2, "paused")
	await _set_state(3, "paused")
	await _set_state(4, "paused")

	
func reset_simulation() -> void:
	print("SIM RESET")

	# 1) alles stoppen + laufende awaits killen
	_run_id += 1
	paused = false
	running = false
	r1_running = false
	r2_running = false
	r3_running = false
	r4_running = false
	# Defekt-Status zurücksetzen
	r1_defective = false
	r2_defective = false
	r3_defective = false
	r4_defective = false
	set_process(false)

	# 2) sicherstellen, dass wir wieder Start-Pfade haben
	#    (wenn noch keine pts da sind, einmal neu bauen)
	if r1_pts.size() < 2 or r2_pts.size() < 2 or r3_pts.size() < 2:
		if _load_backend():
			r1_pts = build_route_points(r1_line, r1_start_id, r1_target_id)
			r2_pts = build_route_points(r2_line, r2_start_id, r2_target_id)
			r3_pts = build_route_points(r3_line, r3_start_id, r3_target_id)

	# 3) Curves wieder auf "Hinweg" setzen - aber erstmal alle am HBF
	var hbf_world := stop_world_by_id.get("de:08212:90", Vector2.ZERO) as Vector2
	if hbf_world != Vector2.ZERO:
		# Gleiche Mini-Curve wie beim Programmstart
		var init_pts := PackedVector2Array([hbf_world, hbf_world + Vector2(50, 0)])
		
		r1_path.curve = map_root.points_to_curve(init_pts)
		r2_path.curve = map_root.points_to_curve(init_pts)
		r3_path.curve = map_root.points_to_curve(init_pts)
		r4_path.curve = map_root.points_to_curve(init_pts)
		
		await get_tree().process_frame
		
		# Gleiche Offsets wie beim Start
		var offsets := [0.0, 12.0, 24.0, 36.0]
		var follows := [r1_follow, r2_follow, r3_follow, r4_follow]
		
		for i in range(4):
			follows[i].loop = false
			follows[i].rotates = true
			follows[i].progress = offsets[i] + 0.1
		
		await get_tree().process_frame
		
		for i in range(4):
			follows[i].progress = offsets[i]
		
		await get_tree().process_frame

	_set_robot_visible(1)
	_set_robot_visible(2)
	_set_robot_visible(3)
	_set_robot_visible(4)
	
	_set_robot_color(1)
	_set_robot_color(2)
	_set_robot_color(3)
	_set_robot_color(4)

	# 5) Kamera wieder auf HBF (optional, aber fühlt sich "reset" an)
	var cam := map_root.get_node_or_null("Camera2D") as Camera2D
	if cam and hbf_world != Vector2.ZERO:
		cam.global_position = hbf_world

	# 6) Zustand zurücksetzen
	initialized = true  # wichtig: wir HABEN ja wieder Curves gesetzt
	await _set_state(1, "ready")
	await _set_state(2, "ready")
	await _set_state(3, "ready")
	await _set_state(4, "ready")

	print("RESET done. Robots snapped to start.")

# =========================================================
# KAMERA FOKUS
# =========================================================
func focus_camera_on_robot(robot_id: int) -> void:
	var cam := map_root.get_node_or_null("Camera2D") as Camera2D
	if not cam:
		push_warning("Camera2D not found")
		return
	
	var follow: PathFollow2D = null
	match robot_id:
		1: follow = r1_follow
		2: follow = r2_follow
		3: follow = r3_follow
		4: follow = r4_follow
		_:
			push_warning("Invalid robot_id: " + str(robot_id))
			return
	
	if follow:
		cam.global_position = follow.global_position
		cam.zoom = Vector2(0.7, 0.7)
