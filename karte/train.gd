extends Node2D

@export var speed: float = 40.0
@export var loop: bool = false

var route: PackedVector2Array = PackedVector2Array()
var segment: int = 0
var t: float = 0.0
var moving: bool = false


# Backwards kompatibel
func set_route(points: PackedVector2Array) -> void:
	set_route_starting_at(points, global_position)
	
func set_route_starting_at(points: PackedVector2Array, start_pos: Vector2) -> void:
	# Route übernehmen
	route = points
	segment = 0
	t = 0.0

	if route.size() < 2:
		moving = false
		return

	# besten Segment-Start nahe start_pos finden
	var best_i := 0
	var best_d := INF
	for i in range(route.size()):
		var d := route[i].distance_squared_to(start_pos)
		if d < best_d:
			best_d = d
			best_i = i

	# wir starten dann ab dem nächsten Punkt, damit Bewegung sichtbar ist
	segment = clamp(best_i, 0, route.size() - 2)

	# NICHT teleportieren – Position bleibt wie sie ist
	moving = true
	set_process(true)


func _process(delta: float) -> void:
	if not moving:
		return

	if route.size() < 2:
		moving = false
		return

	if segment >= route.size() - 1:
		if loop:
			segment = 0
		else:
			moving = false
			return

	var a: Vector2 = route[segment]
	var b: Vector2 = route[segment + 1]

	var seg_len := a.distance_to(b)
	if seg_len < 0.001:
		segment += 1
		return

	# ✅ DAS HAT DIR GEFEHLT
	t += (speed * delta) / seg_len

	# mehrere Segmente “aufholen” (bei hoher speed)
	while t >= 1.0 and moving:
		global_position = b
		t -= 1.0
		segment += 1

		if segment >= route.size() - 1:
			if loop:
				segment = 0
			else:
				moving = false
				return

		a = route[segment]
		b = route[segment + 1]
		seg_len = a.distance_to(b)
		if seg_len < 0.001:
			continue

	global_position = a.lerp(b, t)
	rotation = (b - a).angle()
