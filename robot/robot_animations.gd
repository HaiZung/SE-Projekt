extends Node3D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var anim_all: AnimationPlayer = $AnimationPlayerAll
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var FaceMat: StandardMaterial3D = $"Movement_master/body/Face-Area/Face".get_surface_override_material(0) as StandardMaterial3D
@onready var FaceArea: ShaderMaterial = $"Movement_master/body/Face-Area".get_surface_override_material(0) as ShaderMaterial
@onready var InteractionArea: ShaderMaterial = $"Movement_master/body/Interaction-Area".get_surface_override_material(0) as ShaderMaterial
@onready var GlowRowBack: ShaderMaterial = $"Movement_master/body/GlowRow_back".get_surface_override_material(0) as ShaderMaterial
@onready var GlowRowFront: ShaderMaterial = $"Movement_master/body/GlowRow_front".get_surface_override_material(0) as ShaderMaterial
@onready var LampFrontRight: ShaderMaterial = $"Movement_master/body/lampFrontRight".get_surface_override_material(0) as ShaderMaterial
@onready var LampFrontLeft: ShaderMaterial = $"Movement_master/body/lampFrontLeft".get_surface_override_material(0) as ShaderMaterial
@onready var LampBackRight: ShaderMaterial = $"Movement_master/body/lampBackRight".get_surface_override_material(0) as ShaderMaterial
@onready var LampBackLeft: ShaderMaterial = $"Movement_master/body/lampBackLeft".get_surface_override_material(0) as ShaderMaterial
@onready var LightFrontRight: ShaderMaterial = $"Movement_master/body/lightFrontRight".get_surface_override_material(0) as ShaderMaterial
@onready var LightFrontLeft: ShaderMaterial = $"Movement_master/body/lightFrontLeft".get_surface_override_material(0) as ShaderMaterial
@onready var LightBackRight: ShaderMaterial = $"Movement_master/body/lightBackRight".get_surface_override_material(0) as ShaderMaterial
@onready var LightBackLeft: ShaderMaterial = $"Movement_master/body/lightBackLeft".get_surface_override_material(0) as ShaderMaterial

# ───────────── COLORS ─────────────
const WHITE = Color(1, 1, 1)
const RED = Color(1, 0, 0)
const ORANGE = Color(1, 0.5, 0)
const YELLOW = Color(1, 1, 0)
const GREEN = Color(0, 1, 0)
const TURQUOISE = Color(0, 1, 1)
const BLUE = Color(0, 0.2, 1)
const INDIGO = Color(0, 0, 1)
const LAMP = Color(1, 1, 0.6)

# ───────────── BOOLEANS ─────────────
var powered_on := false
var driving := false
var driving_backwards := false
var turning_left := false
var turning_right := false

var interacting := false
var charging := false
var error := false
var danger := false
var help := false
var alarm := false
var obstacle := false
var doors := false

var face_token := 0
var effects_active := false
var door_closed_rotations := {}
var door_nodes := {}
var current_open_door: String = ""  

# ───────────── FACES ─────────────
func standard_face():
	face_token += 1
	var my_token = face_token

	while my_token == face_token:
		FaceMat.albedo_texture = load("res://robot/robot-faces/Face_eyes_open.png")
		await get_tree().create_timer(3.0).timeout
		if my_token != face_token: break

		FaceMat.albedo_texture = load("res://robot/robot-faces/Face_eyes_closed.png")
		await get_tree().create_timer(0.2).timeout
func busy_face():
	face_token += 1
	var my_token = face_token

	while my_token == face_token:
		FaceMat.albedo_texture = load("res://robot/robot-faces/Thinking.png")
		await get_tree().create_timer(1.0).timeout
		if my_token != face_token: break

		FaceMat.albedo_texture = load("res://robot/robot-faces/working.png")
		await get_tree().create_timer(1.0).timeout
func sleeping_face():
	face_token += 1
	var my_token = face_token

	while my_token == face_token:
		FaceMat.albedo_texture = load("res://robot/robot-faces/sleepy_1.png")
		await get_tree().create_timer(1.5).timeout
		if my_token != face_token: break

		FaceMat.albedo_texture = load("res://robot/robot-faces/sleepy_2.png")
		await get_tree().create_timer(1.5).timeout
func happy_face():
	FaceMat.albedo_texture = load("res://robot/robot-faces/Happy.png")
func angry_face():
	FaceMat.albedo_texture = load("res://robot/robot-faces/Angry.png")
func sad_face():
	FaceMat.albedo_texture = load("res://robot/robot-faces/Sad.png")
func critical_face():
	FaceMat.albedo_texture = load("res://robot/robot-faces/critical.png")
func reset_face():
	face_token += 1

# ───────────── DOORS ─────────────
func toggle_door(door_name: String, anim_name: String) -> void:
	var door = door_nodes[door_name] 
	if door.rotation.is_equal_approx(door_closed_rotations[door_name]):
		open_door(anim_name)
	else:
		close_door(door_name)
func open_door(anim_name: String):
	anim_all.play(anim_name)
func close_door(door_name: String, duration := 0.35):
	var door = door_nodes[door_name]
	var tween = create_tween()
	tween.tween_property(
		door,
		"rotation",
		door_closed_rotations[door_name],
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		anim_all.stop(true)
	)

# ───────────── EFFECTS ─────────────
var t := 0.0
var pulse_active := {}
var blink_active := {}
func pulse(material, min_strength, max_strength, speed, id = ""):
	if id != "" and not pulse_active.get(id, true):
		return
	var v = lerp(min_strength, max_strength, (sin(t * speed) + 1.0) * 0.5)
	material.set_shader_parameter("emission_strength", v)
func blink(material, color_on, color_off, strength_on, strength_off, speed, id = ""):
	if id != "" and not blink_active.get(id, true):
		return
	var on = sin(t * speed) > 0
	material.set_shader_parameter("emission_color", color_on if on else color_off)
	material.set_shader_parameter("emission_strength", strength_on if on else strength_off)
func clear_all_effects():
	for key in pulse_active.keys():
		pulse_active[key] = false
	for key in blink_active.keys():
		blink_active[key] = false
func offline():
	anim_tree.active = false
	var mats = [
		LightFrontRight,
		LightFrontLeft,
		LightBackRight,
		LightBackLeft,
		GlowRowBack,
		GlowRowFront,
		FaceArea,
		InteractionArea,
		LampFrontRight,
		LampFrontLeft,
		LampBackRight,
		LampBackLeft
	]
	for m in mats:
		if m:
			m.set_shader_parameter("emission_strength", 0.0)

# ───────────── MAIN ─────────────
func _ready():
	door_nodes["door_left_top"] = $Movement_master/body/top/door_left_top
	door_nodes["door_left_middle_top"] = $Movement_master/body/top/door_left_middle_top
	door_nodes["door_left_middle_bottom"] = $Movement_master/body/top/door_left_middle_bottom
	door_nodes["door_left_bottom"] = $Movement_master/body/top/door_left_bottom
	door_nodes["door_right_top"] = $Movement_master/body/top/door_right_top
	door_nodes["door_right_middle_top"] = $Movement_master/body/top/door_right_middle_top
	door_nodes["door_right_middle_bottom"] = $Movement_master/body/top/door_right_middle_bottom
	door_nodes["door_right_bottom"] = $Movement_master/body/top/door_right_bottom
	for door_name in door_nodes.keys():
		door_closed_rotations[door_name] = door_nodes[door_name].rotation

func _process(delta):
	t += delta
	if not powered_on:
		offline()
		anim_tree.active = false
		return

	# ───────────── RESET LIGHTS ─────────────
	LampFrontRight.set_shader_parameter("emission_color", LAMP)
	LampFrontRight.set_shader_parameter("emission_strength", 3.0)
	LampFrontLeft.set_shader_parameter("emission_color", LAMP)
	LampFrontLeft.set_shader_parameter("emission_strength", 3.0)
	LampBackRight.set_shader_parameter("emission_color", LAMP)
	LampBackRight.set_shader_parameter("emission_strength", 3.0)
	LampBackLeft.set_shader_parameter("emission_color", LAMP)
	LampBackLeft.set_shader_parameter("emission_strength", 3.0)
	LightFrontRight.set_shader_parameter("emission_color", WHITE)
	LightFrontRight.set_shader_parameter("emission_strength", 2.5)
	LightFrontLeft.set_shader_parameter("emission_color", WHITE)
	LightFrontLeft.set_shader_parameter("emission_strength", 2.5)
	LightBackRight.set_shader_parameter("emission_color", RED)
	LightBackRight.set_shader_parameter("emission_strength", 2.5)
	LightBackLeft.set_shader_parameter("emission_color", RED)
	LightBackLeft.set_shader_parameter("emission_strength", 2.5)
	GlowRowFront.set_shader_parameter("emission_color", WHITE)
	GlowRowFront.set_shader_parameter("emission_strength", 2.5)
	GlowRowBack.set_shader_parameter("emission_color", WHITE)
	GlowRowBack.set_shader_parameter("emission_strength", 2.5)
	InteractionArea.set_shader_parameter("emission_color", WHITE)
	InteractionArea.set_shader_parameter("emission_strength", 2.0)
	FaceArea.set_shader_parameter("emission_color", WHITE)
	FaceArea.set_shader_parameter("emission_strength", 2.0)

	# ───────────── MOVEMENT ─────────────
	if driving:
		anim_tree.active = true
		GlowRowFront.set_shader_parameter("emission_color", WHITE)
		GlowRowBack.set_shader_parameter("emission_color", TURQUOISE)
		pulse(GlowRowBack, 2.0, 3.0, 2.0)

	if driving_backwards:
		FaceArea.set_shader_parameter("emission_color", YELLOW)
		GlowRowBack.set_shader_parameter("emission_color", YELLOW)
		GlowRowFront.set_shader_parameter("emission_color", YELLOW)
		blink(LightBackLeft, YELLOW, RED, 3.0, 2.5, 6.0) 
		blink(LightBackRight, YELLOW, RED, 3.0, 2.5, 6.0) 
		pulse(GlowRowFront, 2.0, 4.0, 3.0) 
		pulse(GlowRowBack, 2.0, 4.0, 3.0)

	if turning_left:
		FaceArea.set_shader_parameter("emission_color", WHITE)
		GlowRowBack.set_shader_parameter("emission_color", YELLOW)
		GlowRowFront.set_shader_parameter("emission_color", YELLOW)
		pulse(GlowRowBack, 2.0, 4.0, 3.0)
		blink(LightFrontLeft, YELLOW, WHITE, 3.0, 2.5, 6.0) 
		blink(LightBackLeft, YELLOW, RED, 3.0, 2.5, 6.0)

	if turning_right:
		FaceArea.set_shader_parameter("emission_color", WHITE)
		GlowRowBack.set_shader_parameter("emission_color", YELLOW)
		GlowRowFront.set_shader_parameter("emission_color", YELLOW)
		pulse(GlowRowBack, 2.0, 4.0, 3.0)
		blink(LightFrontRight, YELLOW, WHITE, 3.0, 2.5, 6.0) 
		blink(LightBackRight, YELLOW, RED, 3.0, 2.5, 6.0)

	if obstacle:
		FaceArea.set_shader_parameter("emission_color", WHITE)
		GlowRowBack.set_shader_parameter("emission_color", YELLOW)
		GlowRowFront.set_shader_parameter("emission_color", YELLOW)
		pulse(GlowRowBack, 2.0, 4.0, 3.0)

	# ───────────── SPECIAL STATES ─────────────
	if interacting:
		FaceArea.set_shader_parameter("emission_color", INDIGO)
		GlowRowFront.set_shader_parameter("emission_color", WHITE)
		GlowRowFront.set_shader_parameter("emission_strength", 3.0)
		GlowRowBack.set_shader_parameter("emission_color", INDIGO)
		InteractionArea.set_shader_parameter("emission_color", INDIGO)
		InteractionArea.set_shader_parameter("emission_strength", 3.2)
		pulse(GlowRowBack, 2.0, 4.0, 3.0)

	if charging:
		FaceArea.set_shader_parameter("emission_color", BLUE)
		GlowRowFront.set_shader_parameter("emission_color", BLUE)
		pulse(GlowRowFront, 2.0, 3.0, 3.0)
		GlowRowBack.set_shader_parameter("emission_color", BLUE)
		pulse(GlowRowBack, 2.0, 3.0, 3.0)

	if error:
		FaceArea.set_shader_parameter("emission_color", WHITE)
		GlowRowFront.set_shader_parameter("emission_color", RED)
		pulse(GlowRowFront, 2.0, 3.0, 3.0)
		GlowRowBack.set_shader_parameter("emission_color", RED)
		pulse(GlowRowBack, 2.0, 3.0, 3.0)

	if help:
		FaceArea.set_shader_parameter("emission_color", ORANGE)
		GlowRowFront.set_shader_parameter("emission_color", ORANGE)
		pulse(GlowRowFront, 2.0, 3.0, 8.0)
		GlowRowBack.set_shader_parameter("emission_color", ORANGE)
		pulse(GlowRowBack, 2.0, 3.0, 8.0)

	if danger:
		FaceArea.set_shader_parameter("emission_color", RED)
		blink(GlowRowFront, RED, ORANGE, 3.0, 3.0, 8.0)
		blink(GlowRowBack, RED, ORANGE, 3.0, 3.0, 8.0)

	if alarm:
		blink(FaceArea, RED, INDIGO, 3.0, 3.0, 9.0)
		blink(GlowRowBack, RED, INDIGO, 3.0, 3.0, 9.0)
		blink(GlowRowFront, RED, INDIGO, 3.0, 3.0, 9.0)
		
# ───────────── INPUT ─────────────
func _input(event):
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_0:
				powered_on = true
				return

			driving = false
			driving_backwards = false
			turning_left = false
			turning_right = false
			obstacle = false
			anim_tree.active = false

			match event.keycode:
				KEY_UP: driving = true; anim_tree.active = true; reset_face(); standard_face(); clear_all_effects()
				KEY_DOWN: driving_backwards = true; driving = true; anim_tree.active = true; reset_face(); busy_face(); clear_all_effects()
				KEY_LEFT: turning_left = true; driving = true; anim_tree.active = true; reset_face(); standard_face(); clear_all_effects()
				KEY_RIGHT: turning_right = true; driving = true; anim_tree.active = true; reset_face(); standard_face(); clear_all_effects()
				KEY_O: obstacle = true; driving = true; anim_tree.active = true; reset_face(); busy_face(); clear_all_effects()
				KEY_I: interacting = true; reset_face(); busy_face(); clear_all_effects()
				KEY_C: charging = true; reset_face(); sleeping_face(); clear_all_effects()
				KEY_E: error = true; reset_face(); critical_face(); clear_all_effects()
				KEY_H: help = true; reset_face(); sad_face(); clear_all_effects()
				KEY_D: danger = true; reset_face(); angry_face(); clear_all_effects()
				KEY_A: alarm = true; reset_face(); critical_face(); clear_all_effects()
				
				KEY_1: toggle_door("door_left_top", "door_left_top"); doors = true; reset_face(); happy_face(); clear_all_effects()
				KEY_2: toggle_door("door_left_middle_top", "door_left_middle_top"); doors = true; reset_face(); happy_face(); clear_all_effects()
				KEY_3: toggle_door("door_left_middle_bottom", "door_left_middle_bottom"); doors = true; reset_face(); happy_face(); clear_all_effects()
				KEY_4: toggle_door("door_left_bottom", "door_left_bottom"); doors = true; reset_face(); happy_face(); clear_all_effects()
				KEY_5: toggle_door("door_right_top", "door_right_top"); doors = true; reset_face(); happy_face(); clear_all_effects()
				KEY_6: toggle_door("door_right_middle_top", "door_right_middle_top"); doors = true; reset_face(); happy_face(); clear_all_effects()
				KEY_7: toggle_door("door_right_middle_bottom", "door_right_middle_bottom"); doors = true; reset_face(); happy_face(); clear_all_effects()
				KEY_8: toggle_door("door_right_bottom", "door_right_bottom"); doors = true; reset_face(); happy_face(); clear_all_effects()

		elif not event.pressed:
			match event.keycode:
				KEY_UP: driving = false; anim_tree.active = false; reset_face(); standard_face()
				KEY_DOWN: driving_backwards = false; driving = false; anim_tree.active = false; reset_face(); standard_face()
				KEY_LEFT: turning_left = false; driving = false; anim_tree.active = false; reset_face(); standard_face()
				KEY_RIGHT: turning_right = false; driving = false; anim_tree.active = false; reset_face(); standard_face()
				KEY_O: obstacle = false; driving = false; anim_tree.active = false; reset_face(); standard_face()
				KEY_I: interacting = false; reset_face(); standard_face()
				KEY_C: charging = false; reset_face(); standard_face()
				KEY_E: error = false; reset_face(); standard_face()
				KEY_H: help = false; reset_face(); standard_face()
				KEY_D: danger = false; reset_face(); standard_face()
				KEY_A: alarm = false; reset_face(); standard_face()
