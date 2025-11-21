extends Node2D

func _ready() -> void:
	setup_board()

func setup_board():
	# Setup white pieces (team = -1, bottom of board)
	for i in range(-4, 4):
		create_pawn(Vector2i(i, 2), -1)
	
	create_rook(Vector2i(-4, 3), -1)
	create_knight(Vector2i(-3, 3), -1)
	create_bishop(Vector2i(-2, 3), -1)
	create_queen(Vector2i(-1, 3), -1)
	create_king(Vector2i(0, 3), -1)
	create_bishop(Vector2i(1, 3), -1)
	create_knight(Vector2i(2, 3), -1)
	create_rook(Vector2i(3, 3), -1)
	
	# Setup black pieces (team = 1, top of board)
	for i in range(-4, 4):
		create_pawn(Vector2i(i, -3), 1)
	
	create_rook(Vector2i(-4, -4), 1)
	create_knight(Vector2i(-3, -4), 1)
	create_bishop(Vector2i(-2, -4), 1)
	create_queen(Vector2i(-1, -4), 1)
	create_king(Vector2i(0, -4), 1)
	create_bishop(Vector2i(1, -4), 1)
	create_knight(Vector2i(2, -4), 1)
	create_rook(Vector2i(3, -4), 1)

func create_pawn(pos: Vector2i, team: int):
	var piece = _create_base_piece(team)
	
	if team == -1:
		piece.texture = load("res://Assets/w_pawn_2x_ns.png")
		# White promotions - use load() instead of preload()
		piece.promotions = [
			{"texture": load("res://Assets/w_queen_2x_ns.png"), "piece_type": "Queen"},
			{"texture": load("res://Assets/w_rook_2x_ns.png"), "piece_type": "Rook"},
			{"texture": load("res://Assets/w_bishop_2x_ns.png"), "piece_type": "Bishop"},
			{"texture": load("res://Assets/w_knight_2x_ns.png"), "piece_type": "Knight"}
		]
	else:
		piece.texture = load("res://Assets/b_pawn_2x_ns.png")
		# Black promotions - use load() instead of preload()
		piece.promotions = [
			{"texture": load("res://Assets/b_queen_2x_ns.png"), "piece_type": "Queen"},
			{"texture": load("res://Assets/b_rook_2x_ns.png"), "piece_type": "Rook"},
			{"texture": load("res://Assets/b_bishop_2x_ns.png"), "piece_type": "Bishop"},
			{"texture": load("res://Assets/b_knight_2x_ns.png"), "piece_type": "Knight"}
		]
	
	piece.move_rules = [
		{"pattern": Vector2i(0, 2 * team), "min_range": 1, "max_range": 1, "jump": false, "condition": first_move_checker, "on_move": double_move},
		{"pattern": Vector2i(-1, 1 * team), "min_range": 1, "max_range": 1, "jump": false, "condition": passant_left_checker, "on_move": passant},
		{"pattern": Vector2i(1, 1 * team), "min_range": 1, "max_range": 1, "jump": false, "condition": passant_right_checker, "on_move": passant},
		{"pattern": Vector2i(0, 1 * team), "min_range": 1, "max_range": 1, "jump": false}
	]
	piece.take_rules = [
		{"pattern": Vector2i(1, 1 * team), "min_range": 1, "max_range": 1, "jump": false},
		{"pattern": Vector2i(-1, 1 * team), "min_range": 1, "max_range": 1, "jump": false}
	]
	piece.promotes = true
	
	_finalize_piece(piece, pos, team)
func double_move(piece):
	piece.holy_hell = true

func passant_left_checker(piece):
	var team = piece.team
	var pos = piece.util_position
	var left_pawn = Global.Board.probe_cell(pos + Vector2i(-1,0))
	if not left_pawn: return false
	if left_pawn.team == piece.team: return false
	if not left_pawn.holy_hell: return false
	return true



func passant_right_checker(piece):
	var team = piece.team
	var pos = piece.util_position
	var right_pawn = Global.Board.probe_cell(pos + Vector2i(1,0))
	if not right_pawn: return false
	if right_pawn.team == piece.team: return false
	if not right_pawn.holy_hell: return false
	return true

func passant(piece):
	var team = piece.team
	var pos = piece.util_position
	var pawn = Global.Board.probe_cell(pos + Vector2i(0,-1*team))
	Global.Board.last_move["pending_take"] = pawn

func first_move_checker(piece):
	return not piece.last_position
	
func castle_checker(piece):
	var team = piece.team
	var pos = piece.util_position
	if piece.threats_in.size():
		#print("in check")
		return false
	if not first_move_checker(piece): 
		#print("not king first move")
		return false
	var rook = Global.Board.probe_cell(pos + Vector2i(3, 0))
	var check_1 = Global.Board.probe_cell(pos + Vector2i(2, 0))
	var check_2 = Global.Board.probe_cell(pos + Vector2i(1, 0))
	var danger_map = Global.Board.calculate_threat_map(team*-1)
	check_1 = check_1 or (pos + Vector2i(2, 0)) in danger_map
	check_2 = check_2 or (pos + Vector2i(1, 0)) in danger_map
	if check_1 or check_2: 
		#print("piece in way, or danger in way")
		return false
	if not rook: 
		#print("no rook")
		return false
	if not first_move_checker(rook): 
		#print("not rook first move")
		return false
	return true

func long_castle_checker(piece):
	var team = piece.team
	var pos = piece.util_position
	if piece.threats_in.size():
		#print("in check")
		return false
	if not first_move_checker(piece): 
		#print("not king first move")
		return false
	var rook = Global.Board.probe_cell(pos + Vector2i(-4, 0))
	var check_1 = Global.Board.probe_cell(pos + Vector2i(-3, 0))
	var check_2 = Global.Board.probe_cell(pos + Vector2i(-2, 0))
	var check_3 = Global.Board.probe_cell(pos + Vector2i(-1, 0))
	var danger_map = Global.Board.calculate_threat_map(team*-1)
	check_1 = check_1 or (pos + Vector2i(-3, 0)) in danger_map
	check_2 = check_2 or (pos + Vector2i(-2, 0)) in danger_map
	check_3 = check_3 or (pos + Vector2i(-1, 0)) in danger_map
	if check_1 or check_2 or check_3: 
		#print("piece in way, or danger in way")
		return false
	if not rook: 
		#print("no rook")
		return false
	if not first_move_checker(rook): 
		#print("not rook first move")
		return false
	return true

func create_rook(pos: Vector2i, team: int):
	var piece = _create_base_piece(team)
	
	if team == -1:
		piece.texture = load("res://Assets/w_rook_2x_ns.png")
	else:
		piece.texture = load("res://Assets/b_rook_2x_ns.png")
	
	var rules = []
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		rules.append({"pattern": direction, "min_range": 1, "max_range": 7, "jump": false})
	
	piece.move_rules = rules
	piece.take_rules = rules
	
	_finalize_piece(piece, pos, team)

func create_knight(pos: Vector2i, team: int):
	var piece = _create_base_piece(team)
	
	if team == -1:
		piece.texture = load("res://Assets/w_knight_2x_ns.png")
	else:
		piece.texture = load("res://Assets/b_knight_2x_ns.png")
	
	var rules = []
	for move in [
		Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
	]:
		rules.append({"pattern": move, "min_range": 1, "max_range": 1, "jump": true})
	
	piece.move_rules = rules
	piece.take_rules = rules
	
	_finalize_piece(piece, pos, team)

func create_bishop(pos: Vector2i, team: int):
	var piece = _create_base_piece(team)
	
	if team == -1:
		piece.texture = load("res://Assets/w_bishop_2x_ns.png")
	else:
		piece.texture = load("res://Assets/b_bishop_2x_ns.png")
	
	var rules = []
	for direction in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		rules.append({"pattern": direction, "min_range": 1, "max_range": 7, "jump": false})
	
	piece.move_rules = rules
	piece.take_rules = rules
	
	_finalize_piece(piece, pos, team)

func create_queen(pos: Vector2i, team: int):
	var piece = _create_base_piece(team)
	
	if team == -1:
		piece.texture = load("res://Assets/w_queen_2x_ns.png")
	else:
		piece.texture = load("res://Assets/b_queen_2x_ns.png")
	
	var rules = []
	# All 8 directions (rook + bishop)
	for direction in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]:
		rules.append({"pattern": direction, "min_range": 1, "max_range": 7, "jump": false})
	
	piece.move_rules = rules
	piece.take_rules = rules
	
	_finalize_piece(piece, pos, team)

func create_king(pos: Vector2i, team: int):
	var piece = _create_base_piece(team)
	
	if team == -1:
		piece.texture = load("res://Assets/w_king_2x_ns.png")
	else:
		piece.texture = load("res://Assets/b_king_2x_ns.png")
	
	var rules = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x != 0 or y != 0:  # Exclude (0,0)
				rules.append({
					"pattern": Vector2i(x, y),
					"min_range": 1,
					"max_range": 1,
					"jump": false
				})
	rules.append({
					"pattern": Vector2i(2,0),
					"min_range": 1,
					"max_range": 1,
					"jump": false,
					"condition": castle_checker,
					"on_move": castle
				})
	rules.append({
					"pattern": Vector2i(-2,0),
					"min_range": 1,
					"max_range": 1,
					"jump": false,
					"condition": long_castle_checker,
					"on_move": long_castle
				})
	piece.move_rules = rules
	piece.take_rules = rules
	piece.essential = true
	_finalize_piece(piece, pos, team)

func castle(piece):
	var rook = Global.Board.probe_cell(piece.util_position + Vector2i(1,0))
	rook._move_to_cell(piece.util_position + Vector2i(-1,0))
func long_castle(piece):
	var rook = Global.Board.probe_cell(piece.util_position + Vector2i(-2,0))
	rook._move_to_cell(piece.util_position + Vector2i(1,0))

func _create_base_piece(team: int) -> TextureRect:
	var pawn = preload("res://Classes/BasePiece.gd")
	var piece = TextureRect.new()
	piece.set_script(pawn)
	piece.grid_offset = 20
	piece.scale = Vector2(0.025, 0.025)
	return piece

func _finalize_piece(piece: TextureRect, pos: Vector2i, team: int):
	add_child(piece)
	piece.global_position = piece.grid_to_world(pos)
	piece.team = team
	piece.util_position = pos
	piece.init()
