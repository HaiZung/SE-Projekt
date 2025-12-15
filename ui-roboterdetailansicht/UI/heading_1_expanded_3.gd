extends VBoxContainer

@onready var toggle_btn = $ToggleBtn
@onready var content = $Content

var is_open := true

func _ready():
    content.visible = is_open
    toggle_btn.pressed.connect(_on_toggle)

func _on_toggle():
    is_open = !is_open
    content.visible = is_open
