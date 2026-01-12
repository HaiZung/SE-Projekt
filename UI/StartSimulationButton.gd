extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	print("START SIMULATION BUTTON CLICKED")

	# 1) Sicherster Weg: aktuelle Scene als Startpunkt
	var root_scene := get_tree().current_scene
	print("Current scene:", root_scene.name)

	var sim := root_scene.get_node_or_null("MapRoot/DaySimulation")
	if sim == null:
		# 2) Fallback: absoluter Pfad (falls current_scene anders ist)
		sim = get_node_or_null("/root/MainUI/MapRoot/DaySimulation")

	if sim == null:
		push_error("DaySimulation NOT FOUND (checked MapRoot/DaySimulation and /root/MainUI/MapRoot/DaySimulation)")
		return

	print("Found DaySimulation:", sim.get_path())
	sim.start_simulation()
