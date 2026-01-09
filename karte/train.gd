extends Node2D

@export var speed: float = 40.0      # Pixel pro Sekunde
@export var loop: bool = false

var route: PackedVector2Array
var segment: int = 0
var t: float = 0.0
var moving: bool = false


func set_route_from_line(line: Line2D) -> void:
	route = line.points
	segment = 0
	t = 0.0
	moving = route.size() >= 2

	if route.size() > 0:
		global_position = route[0]


func _process(delta: float) -> void:
	if not moving:
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

	# Fortschritt auf Segment (0..1)
	t += (speed * delta) / seg_len

	if t >= 1.0:
		global_position = b
		t = 0.0
		segment += 1
		return

	global_position = a.lerp(b, t)

	# Sprite in Bewegungsrichtung drehen (optional)
	rotation = (b - a).angle()
