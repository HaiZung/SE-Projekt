extends HTTPRequest

@export var url := "http://127.0.0.1:8000"
@export var path_health := "/api/health"
@export var path_robot_id := "/robotid"
@export var path_packages := "/packages"
@export var path_robot_states := "/robotstates"
@export var path_stations := "/stations"
@export var path_train_id := "/trainid"


func _ready():
	#print(await request_api_health())
	#print(await request_robot_id())
	#print(await request_packages())
	#print(await request_robot_states())
	#print(await request_stations())
	#print(await request_train_id())
	#print(await get_status_for_robot(1))
	pass

func request_http(path: String) -> String:
	print("Start request for: " + url + path)
	var err = request(url + path)
	if err != OK:
		push_error("Request failed")
		print(err)
		return ""

	var result = await request_completed
	
	var response_code = result[1]
	var body = result[3]

	if response_code != 200:
		push_error("HTTP Error %d" % response_code)
		print("HTTP Error %d" % response_code)

		return ""

	return body.get_string_from_utf8()


func request_api_health() -> String:
	return await request_http(path_health)

func request_robot_id() -> String:
	return await request_http(path_robot_id)

func request_packages() -> String:
	return await request_http(path_packages)

func request_robot_states() -> String:
	return await request_http(path_robot_states)

func request_stations() -> String:
	return await request_http(path_stations)

func request_train_id() -> String:
	return await request_http(path_train_id)





func get_status_for_robot(robotID: int):
	var data = JSON.parse_string(await request_robot_states())
	if data == null:
		push_error("Invalid JSON")
		return [""]

	for robot in data:
		if robot["roboter_id"] == robotID:
			return [robot["status"]]

	return ["Robot ID not fourd"]  # not found



func get_packages_for_robot(robotID: int):
	var data = JSON.parse_string(await request_packages())
	if data == null:
		push_error("Invalid JSON")
		return [""]

	var packages = []

	for package in data:
		if package["roboter_id"] == robotID:
			
			packages.append("Paketnummer: " + str(package["paketnummer"])  + " Gewicht: " + str(package["gewicht"]) + " Masse: " + package["masse"])
	
	if len(packages) == 0 :
		return ["No package for Robot ID"]
	
	return packages