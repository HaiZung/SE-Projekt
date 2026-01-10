extends Node2D

var segment_positions: PackedVector2Array 

var speed: float = 200.0
var time_at_ends: float = 2.0
var wait_timer: float = 0.0

var is_moving: bool = true
var is_moving_back: bool = false

var current_segment_index_b: int = 1
var current_position: Vector2

var finished: bool

func _ready() -> void:
    if segment_positions.size() > 0:
        current_position = segment_positions[0]
        global_position = current_position

func _process(delta: float) -> void:
    if not is_moving:
        return

    if wait_timer > 0:
        wait_timer -= delta
        return

    move_to_next_segment(delta)
    
    if is_at_segment_end():
        handle_segment_transition()

func move_to_next_segment(delta: float):
    var target_pos = segment_positions[current_segment_index_b]
    current_position = current_position.move_toward(target_pos, speed * delta)
    global_position = current_position 

func is_at_segment_end() -> bool:
    return current_position == segment_positions[current_segment_index_b]

func handle_segment_transition() -> void:
    if is_moving_back:
        if current_segment_index_b > 0:
            current_segment_index_b -= 1
        else:
            # Reached the very start after going back
            is_moving = false 
			finished = true
    else:
        if current_segment_index_b < segment_positions.size() - 1:
            current_segment_index_b += 1
        else:
            # Reached the very end, start wait timer and flip direction
            wait_timer = time_at_ends
            is_moving_back = true
            current_segment_index_b -= 1 # Set target to the previous point