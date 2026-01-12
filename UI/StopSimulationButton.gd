extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	print("STOP BUTTON CLICKED")

	# Pfad aus deinem Log:
	var sim := get_tree().root.get_node_or_null("MainUI/MapRoot/DaySimulation")
	if sim == null:
		push_error("StopButton: DaySimulation not found at /root/MainUI/MapRoot/DaySimulation")
		return

	print("StopButton found sim=", sim, " running=", sim.running)

	if sim.has_method("stop_simulation"):
		sim.stop_simulation()
	else:
		push_error("StopButton: DaySimulation has no stop_simulation()")
