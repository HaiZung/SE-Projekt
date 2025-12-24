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
@onready var robot_animation := $UILayer/MainLayout/MainLayout/WindowPanel/ScrollArea/ContentList/Heading1_Expanded4/VBoxContainer/SubViewportContainer/SubViewport/Node3D
# 3D lassen wir erstmal aus, kommt danach

@onready var window_panel := $UILayer/MainLayout/WindowPanel

var selected_robot_id := 0
var panel_open := true


# Mock-Daten (später Backend)
var robots := [
	{
		"name": "Roboter 1",
		"status": ["Status: Fährt", "Batterie: 78%", "Mode: Auto"],
		"route": ["Depot", "Haltestelle A", "Haltestelle B"],
		"packages": ["Paket 123", "Paket 456"]
	},
	{
		"name": "Roboter 2",
		"status": ["Status: Belädt", "Batterie: 55%", "Mode: Auto"],
		"route": ["Depot"],
		"packages": ["Paket 789"]
	},
	{
		"name": "Roboter 3",
		"status": ["Status: Wartung", "Batterie: 100%", "Mode: Manual"],
		"route": [],
		"packages": []
	},
	{
		"name": "Roboter 4",
		"status": ["Status: Störung", "Batterie: 12%", "Mode: Auto"],
		"route": ["Haltestelle C"],
		"packages": ["Paket 999", "Paket 111"]
	}
]

func _ready():
	# Buttons verbinden
	for i in header_buttons.size():
		header_buttons[i].pressed.connect(func(): _on_robot_selected(i))

	# Startzustand
	header_buttons[0].button_pressed = true
	_on_robot_selected(0)

func _on_robot_selected(id: int) -> void:
	selected_robot_id = id
	#buttons grün if pressed
	for b in header_buttons:
		if b!=header_buttons[id]:
			b.button_pressed=false
		else: 
			b.button_pressed=true

	var r = robots[id]

	# Status
	sec_status.set_lines(r["status"])

	# Route
	if r["route"].is_empty():
		sec_route.set_lines(["Keine Route"])
	else:
		sec_route.set_lines(r["route"])

	# Pakete
	if r["packages"].is_empty():
		sec_packages.set_lines(["Keine Pakete"])
	else:
		sec_packages.set_lines(r["packages"])


func _on_menu_button_pressed():
	panel_open = !panel_open
	window_panel.visible = panel_open
