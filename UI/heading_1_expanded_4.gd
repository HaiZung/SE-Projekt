extends VBoxContainer

@onready var toggle_button: Button = $ToggleBtn
@onready var content: Control = $Content
@onready var viewport: Viewport = $Content/SubViewportContainer/SubViewport

var is_open := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	content.visible = is_open
	toggle_button.pressed.connect(_on_toggle)
	_apply_viewport_mode()

func _on_toggle() -> void:
	is_open = !is_open
	content.visible = is_open
	_apply_viewport_mode()

func _apply_viewport_mode() -> void:
	if viewport == null:
		return
	viewport.render_target_update_mode = (SubViewport.UPDATE_WHEN_VISIBLE if is_open else SubViewport.UPDATE_DISABLED)
