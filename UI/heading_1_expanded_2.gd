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
	
func set_lines(lines: Array) -> void:
	for c in $Content.get_children():
		c.queue_free()

	for t in lines:
		var l := Label.new()
		l.text = str(t)
		l.add_theme_color_override("font_color", Color.BLACK)
		$Content.add_child(l)
