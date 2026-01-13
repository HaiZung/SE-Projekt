extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	print("RESET BUTTON CLICKED")

	var sim := get_tree().root.get_node_or_null("MainUI/MapRoot/DaySimulation")
	if sim == null:
		push_error("ResetButton: DaySimulation not found")
		return

	sim.reset_simulation()
