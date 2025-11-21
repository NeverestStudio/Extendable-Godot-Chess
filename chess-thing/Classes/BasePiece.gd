extends TextureRect
class_name GamePiece

# Grid settings
@export var grid_offset: int = 20  # Size of each grid cell in pixels
@export var move_rules = []
@export var take_rules = []


# Game state
var util_position = Vector2i(0,0)
var team = 0  # -1 = white, 0 = neutral, 1 = black
var threats_out = []  # Pieces this piece threatens
var threats_in = []  # Pieces this piece is threatened by
var protects = []  # Pieces this piece protects
var protecting = []  # Pieces protecting this piece
var pin := []
var essential = false
var just = false
var last_position = false
var holy_hell = false
# Internal state
var is_dragging: bool = false
var drag_start_pos: Vector2
var grid_start_pos: Vector2i
var valid_positions: Array[Vector2] = []
var on_move = false
var promotions = []
var promotes = false

func _ready():
	# Ghost until spawned
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func init():
	# Register with board
	Global.Board.add_piece(self)
	
	
	# Make visible
	visible = true
	
	# Setup mouse detection
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag()
			else:
				_end_drag()
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			_handle_drag(event.position)

func _start_drag():
	is_dragging = true
	drag_start_pos = global_position
	grid_start_pos = world_to_grid(global_position)
	z_index = 100  # Bring to front

func _handle_drag(mouse_pos: Vector2):
	# Move piece with mouse
	var offset = get_global_mouse_position() - get_rect().size / 2
	global_position = offset

func _end_drag():
	is_dragging = false
	z_index = 0
	
	if not Global.Board.attempt_move(self,world_to_grid(global_position)):
		# Return to start if no valid position
		global_position = drag_start_pos

func _move_to_cell(cell, silent = false):
	var target_row
	if team == -1:
		target_row = -4
	if team == 1:
		target_row = 3
	if not silent:
		last_position = util_position
	global_position = grid_to_world(cell)
	util_position = cell
	if cell.y == target_row and promotes:
		Global.Board.show_promotion_popup(promotions,self)


func _is_within_board(grid_pos: Vector2i) -> bool:
	# Board is 8x8 centered on (0,0), so ranges from -4 to 3 in grid coordinates
	return grid_pos.x >= -4 and grid_pos.x < 4 and grid_pos.y >= -4 and grid_pos.y < 4

func world_to_grid(world_pos: Vector2) -> Vector2i:
	# Convert world position to grid coordinates
	return Vector2i(
		roundi(world_pos.x / grid_offset),
		roundi(world_pos.y / grid_offset)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Convert grid coordinates to world position (centered on grid cell)
	return Vector2(
		grid_pos.x * grid_offset,
		grid_pos.y * grid_offset
	)

func snap_to_grid():
	# Snap current position to nearest grid position
	var grid_pos = world_to_grid(global_position)
	global_position = grid_to_world(grid_pos)

# Example preset functions for common pieces
static func create_king_rules():
	var moves = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x != 0 or y != 0:  # Exclude (0,0)
				moves.append({
					"pattern" = Vector2i(x,y),
					"jump" = false,
					"min_range" = 1,
					"max_range" = 1
				})
	return moves
