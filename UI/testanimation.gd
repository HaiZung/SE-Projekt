extends Node3D

enum State {
	IDLE,
	DRIVING,
	LOADING,
	MAINTENANCE,
	ERROR
}

@export var animation_player_path: NodePath
@export var fallback_animation: StringName = "Idle"

var _ap: AnimationPlayer

const STATE_TO_ANIMATION := {
	State.IDLE: "Idle",
	State.DRIVING: "Drive",
	State.LOADING: "Load",
	State.MAINTENANCE: "Maintenance",
	State.ERROR: "Error"
}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_ap = get_node_or_null(animation_player_path)
	if _ap == null:
		push_warning("AnimationPlayer nicht gefunden")
		return
	
func set_state(state: int) -> void:
	if _ap == null:
		return

	var animation: StringName = STATE_TO_ANIMATION.get(state, fallback_animation)

	if _ap.has_animation(animation):
		_ap.play(animation)
	else:
		if _ap.has_animation(fallback_animation):
			_ap.play(fallback_animation)
		else:
			push_warning("Keine gueltige Animation gefunden im AnimationPlayer")
