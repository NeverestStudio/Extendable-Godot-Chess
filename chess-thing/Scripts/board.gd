extends TextureRect

# Game state variables
var pieces = []
var captured = []
var current_turn = -1  # -1 = white, 1 = black
var special_moves = []
var last_move = {
	"piece": null,
	"location": null,
	"last_last_move": null,
	"pending_take": null
}

# Initialize board
func _ready() -> void:
	Global.Board = self

func _process(delta: float) -> void:
	pass

# Process the next turn after a move
func next_turn():
	var stored_rules
	
	# Store rules if there's a pending capture
	if last_move["pending_take"]:
		stored_rules = last_move["pending_take"].take_rules
		last_move["pending_take"].take_rules = []
	
	# Calculate threat map for opponent
	var map = calculate_threat_map(current_turn * -1)
	
	# Check if the move puts own king in check (illegal move)
	if check_check(current_turn, map):
		# Revert the move
		last_move["piece"]._move_to_cell(last_move["location"])
		last_move["piece"].last_position = last_move["last_last_move"]
		if last_move["pending_take"]:
			last_move["pending_take"].take_rules = stored_rules
			last_move["pending_take"] = null
		return
	
	# Execute the capture if valid
	if last_move["pending_take"]:
		take_piece(last_move["pending_take"])
		last_move["pending_take"] = null
	
	# Update board state and check for checkmate
	var checkmate_map = calculate_threat_map(current_turn)
	update_piece_states()
	
	if check_check(current_turn * -1, checkmate_map):
		if check_checkmate(current_turn * -1):
			print("checkmate")
			current_turn = 0
	
	# Switch turns
	current_turn *= -1

# Check if a team's essential piece (king) is in check
func check_check(team, map):
	var essential = []
	
	# Find all essential pieces for the team
	for piece in pieces:
		if piece.team == team and piece.essential == true:
			essential.append(piece)
	
	# Check if any essential piece is threatened
	for noble in essential:
		if noble.util_position in map:
			return true
	
	return false

# Check if a team is in checkmate
func check_checkmate(team):
	var threatened_essentials = []
	
	# Find all threatened essential pieces
	for piece in pieces:
		if piece.essential and (piece.threats_in.size() > 0):
			threatened_essentials.append(piece)
	
	# If only one essential piece is threatened, check if it can move
	if threatened_essentials.size() == 1:
		var essential = threatened_essentials[0]
		var legal_moves = generate_legal_moves(essential)
		if legal_moves.size() > 0:
			print("king can move")
			return false
	
	# Check if the threat can be blocked
	if threatened_essentials.size() == 1:
		var essential = threatened_essentials[0]
		if essential.threats_in.size() == 1:
			var threat = essential.threats_in[0]
			var blocks = generate_essential_blocks(threat)
			if blocks and blocks.size() > 0:
				for piece in pieces:
					if piece.team == team:
						var moves = generate_legal_moves(piece)
						for block in blocks:
							if block in moves:
								return false
	
	# Check if the threatening piece can be captured
	var threats = []
	for essential in threatened_essentials:
		for threat in essential.threats_in:
			if not threat in threats:
				threats.append(threat)
	
	if threats.size() == 1:
		var threat = threats[0]
		if can_take_without_check(threat):
			return false
	
	return true

# Add a piece to the board
func add_piece(piece):
	pieces.append(piece)

# Check if a piece is protected by another piece
func piece_protected(piece) -> bool:
	return piece.protecting.size() > 0

# Check if a piece can be taken without putting the taker in check
func can_take_without_check(piece) -> bool:
	var illegals_attacking = 0
	
	for threat in piece.threats_in:
		print(threat.pin)
		print(piece.util_position)
		print(piece.util_position in threat.pin)
		
		# Can't take if it's the king and piece is defended
		if threat.essential and piece_protected(piece):
			illegals_attacking += 1
			print("attacker defended")
		# Can't take if the piece is pinned
		elif piece.util_position in threat.pin:
			illegals_attacking += 1
			print("pinned")
	
	print(illegals_attacking)
	return piece.threats_in.size() != illegals_attacking

# Update all piece states (threats, protections, pins)
func update_piece_states():
	# Clear all piece states
	for piece in pieces:
		piece.threats_in = []
		piece.protecting = []
		piece.pin = []
	
	# Recalculate all piece states
	for piece in pieces:
		# Reset en passant flag
		if piece.holy_hell and piece.team == current_turn * -1:
			piece.holy_hell = false
		
		# Calculate threats
		var threats_out = generate_legal_takes(piece)
		for threat in threats_out:
			probe_cell(threat).threats_in.append(piece)
		
		# Calculate protections
		var protects_out = generate_protects(piece)
		for protected in protects_out:
			probe_cell(protected).protecting.append(piece)
		
		# Calculate pins
		var pins_out = generate_pins(piece)
		for pin in pins_out:
			pin["piece"].pin = pin["pinned_to"]
		
		piece.threats_out = threats_out
		piece.protects = protects_out

# Remove a piece from the board
func take_piece(piece):
	piece.visible = false
	piece.global_position = Vector2(100000, 100000)
	pieces.erase(piece)
	captured.append(piece)

# Display promotion selection popup
func show_promotion_popup(options: Array, piece):
	# Debug: Check what textures we're getting
	print("Promotion options for team ", piece.team, ":")
	for opt in options:
		print("  - ", opt["piece_type"], ": ", opt["texture"].resource_path if opt["texture"] else "NO TEXTURE")
	
	# Create fullscreen darkened overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.size = get_viewport_rect().size
	overlay.position -= overlay.size / 2
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(overlay)
	
	# Create centered container for the popup
	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center_container)
	
	# Create panel with margin and vertical layout
	var panel := PanelContainer.new()
	center_container.add_child(panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Create title
	var title := Label.new()
	title.text = "Choose Promotion"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Create button row
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	
	# Create buttons for each promotion option
	for opt in options:
		var tex = opt["texture"]
		var p_type = opt["piece_type"]
		
		# Create button
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		
		# Center texture inside the button
		var btn_center := CenterContainer.new()
		btn_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(btn_center)
		
		# Create texture display
		var txtr := TextureRect.new()
		txtr.texture = tex
		txtr.custom_minimum_size = Vector2(60, 60)
		txtr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		txtr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		txtr.rotation_degrees = -90  # Rotate if board is rotated
		btn_center.add_child(txtr)
		
		# Create label under texture
		var label := Label.new()
		label.text = p_type
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_constant_override("margin_bottom", 5)
		btn.add_child(label)
		
		hbox.add_child(btn)
		
		# Connect button click to promote function
		btn.pressed.connect(func():
			promote(piece, p_type, opt)
			overlay.queue_free()
		)

# Promote a pawn to another piece type
func promote(piece: GamePiece, p_type: String, option: Dictionary):
	# Update the piece's texture
	piece.texture = option["texture"]
	
	var team = piece.team
	
	# Update move and take rules based on the piece type
	match p_type:
		"Queen":
			var rules = []
			for direction in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			]:
				rules.append({"pattern": direction, "min_range": 1, "max_range": 7, "jump": false})
			piece.move_rules = rules
			piece.take_rules = rules
		
		"Rook":
			var rules = []
			for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				rules.append({"pattern": direction, "min_range": 1, "max_range": 7, "jump": false})
			piece.move_rules = rules
			piece.take_rules = rules
		
		"Bishop":
			var rules = []
			for direction in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				rules.append({"pattern": direction, "min_range": 1, "max_range": 7, "jump": false})
			piece.move_rules = rules
			piece.take_rules = rules
		
		"Knight":
			var rules = []
			for move in [
				Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
				Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
			]:
				rules.append({"pattern": move, "min_range": 1, "max_range": 1, "jump": true})
			piece.move_rules = rules
			piece.take_rules = rules
	
	# Remove pawn-specific properties
	piece.promotes = false
	piece.promotions = []
	piece.holy_hell = false
	piece.on_move = false
	
	print("Promoted to " + p_type)

# Attempt to move a piece to a cell
func attempt_move(piece, cell):
	special_moves = []
	var move_rules = piece.get("move_rules")
	var take_rules = piece.get("take_rules")
	var legal_moves = generate_legal_moves(piece)
	var legal_takes = generate_legal_takes(piece)
	var team = piece.get("team")
	var pos = piece.get("util_position")
	
	# Validate the move is within board bounds
	if not piece._is_within_board(cell):
		return false
	if current_turn != team:
		return false
	# Check if move is legal
	var move_valid = false
	var on_move = []
	if piece.get("on_move"):
		on_move.append(piece.on_move)
	
	for legal_move in legal_moves:
		if legal_move == cell:
			move_valid = true
			for special_move in special_moves:
				print("special_move")
				if special_move[0] == cell:
					on_move.append(special_move[1])
	
	# Check if capture is legal
	var take_valid = false
	var target_piece = probe_cell(cell)
	
	for legal_take in legal_takes:
		if legal_take == cell:
			if target_piece and target_piece.get("team") != team:
				take_valid = true
				for special_move in special_moves:
					if special_move[0] == cell:
						on_move.append(special_move[1])
	
	# Execute move or capture
	if take_valid and target_piece:
		last_move["pending_take"] = target_piece
	
	if (move_valid and (not target_piece)) or take_valid:
		last_move["piece"] = piece
		last_move["location"] = piece.util_position
		last_move["last_last_move"] = piece.last_position
		piece._move_to_cell(cell)
		
		# Execute special move callbacks
		for callable in on_move:
			callable.call(piece)
		
		next_turn()
		return true
	
	return false

# Calculate all cells threatened by a team
func calculate_threat_map(team):
	var map = []
	for piece in pieces:
		if piece.team == team:
			var legal_threats = generate_legal_threats(piece)
			map = map + legal_threats
	return map

# Generate all legal moves for a piece
func generate_legal_moves(piece):
	var move_rules = piece.get("move_rules")
	var pos = piece.get("util_position")
	var threat_map = false
	var legal_moves = []
	
	# Kings need to avoid threatened squares
	if piece.essential:
		threat_map = calculate_threat_map(current_turn * -1)
	
	for rule in move_rules:
		# Check conditional rules
		if "condition" in rule:
			if not rule["condition"].call(piece):
				continue
		
		var pattern = rule["pattern"]
		for i in range(rule["min_range"], rule["max_range"] + 1):
			var cell = probe_cell(pos + (pattern * i))
			
			# Add move if valid (jumping or empty cell, not threatened for king)
			if (rule["jump"] or not cell) and (not (threat_map and (pos + (pattern * i) in threat_map)) and piece._is_within_board(pos + (pattern * i))):
				if threat_map:
					print(pos + (pattern * i) in threat_map)
				legal_moves.append(pos + (pattern * i))
				
				# Store special move callbacks
				if rule.has("on_move"):
					special_moves.append([pos + (pattern * i), rule["on_move"]])
			else:
				break
	
	return legal_moves

# Generate all legal captures for a piece
func generate_legal_takes(piece):
	var take_rules = piece.get("take_rules")
	var pos = piece.get("util_position")
	var team = piece.get("team")
	var legal_takes = []
	
	for rule in take_rules:
		var pattern = rule["pattern"]
		for i in range(rule["min_range"], rule["max_range"] + 1):
			var cell = probe_cell(pos + (pattern * i))
			
			if cell:
				if cell.get("team") == team:
					# Can't capture own piece, stop if not jumping
					if not rule["jump"]:
						break
				else:
					# Can capture enemy piece
					legal_takes.append(pos + (pattern * i))
					if not rule["jump"]:
						break
	
	return legal_takes

# Generate all cells threatened by a piece (including empty squares)
func generate_legal_threats(piece):
	var take_rules = piece.get("take_rules")
	var pos = piece.get("util_position")
	var team = piece.get("team")
	var legal_threats = []
	
	for rule in take_rules:
		var pattern = rule["pattern"]
		for i in range(rule["min_range"], rule["max_range"] + 1):
			var cell = probe_cell(pos + (pattern * i))
			
			if cell:
				legal_threats.append(pos + (pattern * i))
				if not rule["jump"]:
					break
			else:
				legal_threats.append(pos + (pattern * i))
	
	return legal_threats

# Generate all cells protected by a piece
func generate_protects(piece):
	var take_rules = piece.get("take_rules")
	var pos = piece.get("util_position")
	var team = piece.get("team")
	var legal_protects = []
	
	for rule in take_rules:
		var pattern = rule["pattern"]
		for i in range(rule["min_range"], rule["max_range"] + 1):
			var cell = probe_cell(pos + (pattern * i))
			
			if cell:
				if cell.get("team") != team:
					# Enemy piece blocks protection
					if not rule["jump"]:
						break
				else:
					# Protecting own piece
					legal_protects.append(pos + (pattern * i))
					if not rule["jump"]:
						break
	
	return legal_protects

# Generate all pins created by a piece
func generate_pins(piece):
	var take_rules = piece.get("take_rules")
	var pos = piece.get("util_position")
	var team = piece.get("team")
	var pinned = []
	
	for rule in take_rules:
		# Jumping pieces can't pin
		if rule["jump"]:
			continue
		
		var attacked = []
		var pattern = rule["pattern"]
		var pin_ray = []
		
		for i in range(rule["min_range"], rule["max_range"] + 1):
			pin_ray.append(pos + (pattern * i))
			var cell = probe_cell(pos + (pattern * i))
			
			if cell:
				if cell.get("team") == team:
					# Own piece blocks the pin
					break
				else:
					attacked.append(cell)
					# Pin exists if two pieces attacked and second is essential
					if (attacked.size() == 2) and cell.essential:
						pinned.append({"piece": cell, "pinned_to": pin_ray})
	
	return pinned

# Generate cells that can block a check from a piece
func generate_essential_blocks(piece):
	var take_rules = piece.get("take_rules")
	var pos = piece.get("util_position")
	var team = piece.get("team")
	var block_ray = false
	
	for rule in take_rules:
		# Jumping pieces can't be blocked
		if rule["jump"]:
			continue
		
		var attacked = []
		var pattern = rule["pattern"]
		var take_ray = []
		
		for i in range(rule["min_range"], rule["max_range"] + 1):
			take_ray.append(pos + (pattern * i))
			var cell = probe_cell(pos + (pattern * i))
			
			if cell:
				if cell.get("team") == team:
					break
				else:
					attacked.append(pos + (pattern * i))
					# Return blocking squares if attacking essential piece
					if (attacked.size() == 1) and cell.essential:
						block_ray = take_ray
	
	return block_ray

# Get the piece at a specific cell
func probe_cell(cell):
	for piece in pieces:
		if piece.get("util_position") == cell:
			return piece
	return false
