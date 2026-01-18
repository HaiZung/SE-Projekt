extends Control

# --- Buttons ---
@onready var header_buttons := [
	$UILayer/MainLayout/WindowPanel/WindowVBox/WindowHeader/HeaderButtons/RedBtn1,
	$UILayer/MainLayout/WindowPanel/WindowVBox/WindowHeader/HeaderButtons/RedBtn2,
	$UILayer/MainLayout/WindowPanel/WindowVBox/WindowHeader/HeaderButtons/RedBtn3,
	$UILayer/MainLayout/WindowPanel/WindowVBox/WindowHeader/HeaderButtons/RedBtn4
]

# --- Sections ---
@onready var sec_status   := $UILayer/MainLayout/WindowPanel/WindowVBox/ScrollArea/ContentList/Heading1_Expanded
@onready var sec_route    := $UILayer/MainLayout/WindowPanel/WindowVBox/ScrollArea/ContentList/Heading1_Expanded2
@onready var sec_packages := $UILayer/MainLayout/WindowPanel/WindowVBox/ScrollArea/ContentList/Heading1_Expanded3
@onready var sec_3d := $UILayer/MainLayout/WindowPanel/WindowVBox/ScrollArea/ContentList/Heading1_Expanded4
@onready var viewport_camera: Camera3D = get_node_or_null("UILayer/MainLayout/WindowPanel/WindowVBox/ScrollArea/ContentList/Heading1_Expanded4/Content/SubViewportContainer/SubViewport/Node3D/Camera3D") as Camera3D
@onready var robot_preview_model: Node3D = get_node_or_null("UILayer/MainLayout/WindowPanel/WindowVBox/ScrollArea/ContentList/Heading1_Expanded4/Content/SubViewportContainer/SubViewport/robot_animations") as Node3D
@onready var robot_viewport_container: SubViewportContainer = get_node_or_null("UILayer/MainLayout/WindowPanel/WindowVBox/ScrollArea/ContentList/Heading1_Expanded4/Content/SubViewportContainer") as SubViewportContainer

@onready var window_panel := $UILayer/MainLayout/WindowPanel

@onready var api := $HTTPRequest as HTTPRequest

# --- Map Root ---
@export var map_root_path: NodePath
@onready var map_root: Node = get_node_or_null(map_root_path)

var update_timer = 0
var update_perdiod = 5.0

var selected_robot_id := 0
var panel_open := true

var _robot_dragging := false
var _robot_last_mouse_pos := Vector2.ZERO

func _ready():
	# Buttons verbinden
	for i in range(header_buttons.size()):
		header_buttons[i].pressed.connect(func(): _on_robot_selected(i))

	# Startzustand
	header_buttons[0].button_pressed = true
	_on_robot_selected(0)

	#hide pannel 
	_on_menu_button_pressed()

	if robot_preview_model == null:
		print("UI WARN: robot_preview_model not found -> skipping 3D")
	elif viewport_camera != null:
		viewport_camera.make_current()


func _on_robot_selected(id: int) -> void:
	selected_robot_id = id
	#buttons grün if pressed
	for b in header_buttons:
		if b!=header_buttons[id]:
			b.button_pressed=false
		else: 
			b.button_pressed=true
			
	# Status
	sec_status.set_lines(await api.get_status_for_robot(id +1))
	# Route
	sec_route.set_lines(await api.get_route_for_robot(id +1))
	# Pakete
	sec_packages.set_lines(await api.get_packages_for_robot(id +1))
	# Kamera zum gewählten Roboter bewegen
	var day_sim := map_root.get_node_or_null("DaySimulation")
	if day_sim and day_sim.has_method("focus_camera_on_robot"):
		day_sim.focus_camera_on_robot(id + 1)


func _process(delta):
	update_timer += delta
	if update_timer > update_perdiod:
		_perdiodic_update_selected()
		update_timer = 0
	
func _perdiodic_update_selected() -> void:
	if panel_open: 
		# Status
		sec_status.set_lines(await api.get_status_for_robot(selected_robot_id +1))
		# Route
		sec_route.set_lines(await api.get_route_for_robot(selected_robot_id +1))
		# Pakete
		sec_packages.set_lines(await api.get_packages_for_robot(selected_robot_id +1))

func _on_menu_button_pressed():
	panel_open = !panel_open
	window_panel.visible = panel_open

func check_api_connection()->bool:
	return true


func _input(event: InputEvent) -> void:
	var is_3d_open := sec_3d != null and bool(sec_3d.get("is_open"))
	if not is_3d_open:
		_robot_dragging = false
		return

	if robot_viewport_container == null or robot_preview_model == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var over_viewport := robot_viewport_container.get_global_rect().has_point(mouse_pos)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		var mb := event as InputEventMouseButton
		if mb.pressed and over_viewport:
			_robot_dragging = true
			_robot_last_mouse_pos = mb.position
			get_viewport().set_input_as_handled()
		else:
			_robot_dragging = false
		return

	if event is InputEventMouseMotion and _robot_dragging:
		var motion := event as InputEventMouseMotion
		if not over_viewport:
			_robot_dragging = false
			return
		var delta: Vector2 = motion.position - _robot_last_mouse_pos
		_robot_last_mouse_pos = motion.position
		robot_preview_model.rotate_y(delta.x * 0.01)
		get_viewport().set_input_as_handled()

	# ZUM TESTEN VON ANIMATIONEN DURCH INPUT IN UI
	if event is InputEventKey:
		if robot_preview_model != null and robot_preview_model.has_method("_input"):
			robot_preview_model.call("_input", event)
