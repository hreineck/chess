extends Node2D

const PAWN = 0
const BISHOP = 1
const KNIGHT = 2
const ROOK = 3
const QUEEN = 4
const KING = 5
const WHITE = 0
const BLACK = 6
const BLACKLOSE = -2
const WHITELOSE = -1
const START = 1
const COLOR = 2
const TILEWIDTH = 128

#graphics stuff
var tile_white = Color(1,.92,.7)
var tile_black = Color(.47,.44,.3, .25)
var highlight = Color(.5, 1, 1, 1)
var black_turn = load("res://black_turn_label.png")
var white_turn = load("res://white_turn_label.png")
var ai_select = load("res://vs_ai.png")
var human_select = load("res://vs_human.png")
var choose = load("res://select.png")
var white_select = load("res://white_select.png")
var black_select = load("res://black_select.png")
var white_end_text = load("res://white_died.png")
var black_end_text = load("res://black_died.png")

#game state stuff
var board = boardState.new()
var turn = START; #state of the game, and who's turn it is
var piece_selected = Vector2(-1,-1);
var possible_moves= []
var mutex = Mutex.new()
var computer = 0
var player = WHITE
var selection = 0

class boardState:
	#holds the position of every piece on a board
		
	var tiles = [] #2d array holding the piece type and color at each position
	#positions of the kings
	var king_white = Vector2()
	var king_black = Vector2()
		
	func initialize():
		king_white = Vector2(4,7)
		king_black = Vector2(4,0)
		for i in range(8):
			tiles.append([])
			for j in range(8):
				tiles[i].append(-1)

	func setup():
		#set up pieces
		var setup_order = [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
		for x in range(8):
			tiles[x][0] = (setup_order[x] + BLACK)
			tiles[x][1] = (PAWN + BLACK)
			tiles[x][6] = (PAWN + WHITE)
			tiles[x][7] = (setup_order[x] + WHITE)
			
	func copy():
		#returns a deep copy
		if tiles == []:
			return boardState.new()
		var ret = boardState.new()
		ret.initialize();
		for i in range(8):
			for j in range(8):
				ret.tiles[i][j] = tiles[i][j]
		ret.king_white = king_white
		ret.king_black = king_black
		return ret
		
	func equals(other : boardState):
		if tiles == [] || other.tiles == []:
			return false
		for i in range(8):
			for j in range(8):
				if tiles[i][j] != other.tiles[i][j]:
					return false
		return true
			
func oppositeSide(side):
	if side == WHITE:
		return BLACK
	return WHITE
			
func isMoveLegal(state : boardState, new_position : Vector2, piece : Vector2, side, checking):
	#given a position, return -1 on illegal move, 0 on legal move, or 1 on capture move, 2 on psuedolegal
	#a move is illegal if it is out of bounds, the spot is occupied by an ally,
	#or if it would put you in check
	if (new_position.x >= 0 && new_position.x <=7 && new_position.y >= 0 && new_position.y <= 7):
		var piece_at_pos = state.tiles[new_position.x][new_position.y]
		var piece_pos_side;
		if piece_at_pos == -1:
			piece_pos_side = -1
		elif piece_at_pos >= 6:
			piece_pos_side = BLACK;
		else:
			piece_pos_side = WHITE;
		if piece_pos_side == side:
			#ally there, illegal move
			return -1
		#would this move put me in check?
		#only run this check if not already checking
		if !checking && isCheck(makeMove(state, piece, new_position), side):
			return 2
			
		if piece_at_pos == -1:
			#space unoccupied
			return 0
		#capture
		return 1
	return -1

func calcLegalMoves(state : boardState, piece : Vector2, checking = false):
	#given a board state and a piece, returns a list of all legal moves
	var p = state.tiles[piece.x][piece.y]
	var piece_type
	var piece_side
	if p >= BLACK:
		piece_type = p - BLACK
		piece_side = BLACK
	else:
		piece_type = p
		piece_side = WHITE
	var legal_moves = []
	match piece_type:
		PAWN:
			if piece_side == BLACK:
				if isMoveLegal(state, piece + Vector2(0,1), piece, piece_side, checking) == 0: #space unoccupied
					legal_moves.append(Vector2(piece.x, piece.y + 1))
					if piece.y == 1: #first move
						if isMoveLegal(state, piece + Vector2(0,2), piece, piece_side, checking) == 0: #space unoccupied
							legal_moves.append(Vector2(piece.x, piece.y + 2))
				#diagonal capture
				if isMoveLegal(state, piece + Vector2(1,1), piece, piece_side, checking) == 1:
					legal_moves.append(piece + Vector2(1,1))
				if isMoveLegal(state, piece + Vector2(-1,1), piece, piece_side, checking) == 1:
					legal_moves.append(piece + Vector2(-1,1))
					
			else: #white
				if isMoveLegal(state, piece + Vector2(0,-1), piece, piece_side, checking) == 0: #space unoccupied
					legal_moves.append(Vector2(piece.x, piece.y - 1))
					if piece.y == 6: #first move
						if isMoveLegal(state, piece + Vector2(0,-2), piece, piece_side, checking) == 0: #space unoccupied
							legal_moves.append(Vector2(piece.x, piece.y - 2))
				#diagonal capture
				if isMoveLegal(state, piece + Vector2(-1,-1), piece, piece_side, checking) == 1:
					legal_moves.append(piece + Vector2(-1,-1))
				if isMoveLegal(state, piece + Vector2(1,-1), piece, piece_side, checking) == 1:
					legal_moves.append(piece + Vector2(1,-1))
				
		BISHOP:
			#try all diagonal directions until they reach an illegal move
			for direction in [Vector2(1,1), Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1)]:
				var new_position = piece + direction
				var legal = isMoveLegal(state, new_position, piece, piece_side, checking)
				while legal >= 0:
					if legal == 1 || legal == 0:
						legal_moves.append(new_position)
					new_position = new_position + direction
					if legal == 1: #can capture enemy here
						break
					legal = isMoveLegal(state, new_position, piece, piece_side, checking)
					
		KNIGHT:
			for direction in [Vector2(2,1), Vector2(1,2), Vector2(-1,2), Vector2(-2, 1),
								Vector2(2,-1), Vector2(1,-2), Vector2(-2,-1), Vector2(-1,-2)]:
				var legal = isMoveLegal(state, piece + direction, piece, piece_side, checking)
				if legal == 0 || legal == 1:
					legal_moves.append(piece + direction)
					
		ROOK:
			for direction in [Vector2(1,0), Vector2(0,1), Vector2(-1,0), Vector2(0, -1)]:
				var new_position = piece + direction
				var legal = isMoveLegal(state, new_position, piece, piece_side, checking)
				while legal >= 0:
					if legal == 1 || legal == 0:
						legal_moves.append(new_position)
					new_position = new_position + direction
					if legal == 1: #can capture enemy here
						break
					legal = isMoveLegal(state, new_position, piece, piece_side, checking)
					
		QUEEN:
			for direction in [Vector2(1,0), Vector2(0,1), Vector2(-1,0), Vector2(0, -1),
								Vector2(1,1), Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1)]:
				var new_position = piece + direction
				var legal = isMoveLegal(state, new_position, piece, piece_side, checking)
				while legal >= 0:
					if legal == 1 || legal == 0:
						legal_moves.append(new_position)
					new_position = new_position + direction
					if legal == 1: #can capture enemy here
						break
					legal = isMoveLegal(state, new_position, piece, piece_side, checking)
					
		KING:
			for direction in [Vector2(1,0), Vector2(0,1), Vector2(-1,0), Vector2(0, -1),
								Vector2(1,1), Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1)]:
				var legal = isMoveLegal(state, piece + direction, piece, piece_side, checking)
				if legal == 1 || legal == 0:
					legal_moves.append(piece + direction)
	return legal_moves
	
func checkHelper(state, side, list_moveable):
	#this needs to be separate for reasons
	var king = Vector2() #locate our king
	if side == WHITE:
		king = state.king_white
	else:
		king = state.king_black
	for list_moves in list_moveable:
		#first element holds the piece, ignore it
		if list_moves.size() > 1:
			for i in range(1, list_moves.size()):
				if list_moves[i] == king:
					return true
	return false
	
func scoreBoard(state : boardState, side):
	#given a legal board state (not checkmate already), returns a score
	#static evaluation only
	#positive scores indicate that the current player is "winning"
	#add the scores of all pieces
	if state.tiles == []:
		print("recieved empty board")
		return -100
	var white = 0 #white score
	var black = 0 #black score
	var white_moves = [[]]
	var black_moves = [[]]
	
	#get the "psuedo-legal" moves to calculate mobility
	#and to check if either side is in check
	for i in range(8):
		for j in range(8):
			#get all legal moves for each side
			var tile = state.tiles[i][j]
			if tile >= 0:
				var tile_side
				if tile >= 6:
					tile_side = BLACK
				else:
					tile_side = WHITE
				if tile_side == WHITE:
					#there is a moveable piece here
					var moves_list = [Vector2(i,j)]
					var legal_moves = calcLegalMoves(state, Vector2(i,j), true)
					if legal_moves.size() > 1:
						moves_list = moves_list + legal_moves
						white_moves.append(moves_list)
				else:
					var moves_list = [Vector2(i,j)]
					var legal_moves = calcLegalMoves(state, Vector2(i,j), true)
					if legal_moves.size() > 1:
						moves_list = moves_list + legal_moves
						black_moves.append(moves_list)
						
#				#tally up piece scores
				var piece_value = 0
				match (tile - tile_side):
						PAWN:
							piece_value = 2
						BISHOP:
							piece_value = 6
						KNIGHT:
							piece_value = 6
						ROOK:
							piece_value = 10
						QUEEN:
							piece_value = 18
				if tile_side == WHITE:
					white += piece_value
				else:
					black += piece_value
					
	if checkHelper(state, side, white_moves):
		#white in check
		white -= 4
	elif checkHelper(state, oppositeSide(side), black_moves):
		#black in check
		black -= 4
		
	#mobility defined by the amount of legal moves a side has
	white += white_moves.size() - 20;
	black += black_moves.size() - 20;
	
	if state.king_white.y != 7:
		white -= 2
	if state.king_black.y != 0:
		black -= 2
	if side == WHITE:
		return (white - black)
	return (black - white)
	
func calcBestMoveHelper():
	#returns the new board state after best move is calculated
	#iterates through all possible moves and returns the move that gives the best
	#board state after looking ahead
	
	var list_movable = allLegalMoves(board, turn, false)
	var moves_ahead = 2
#	if list_movable.size() < 10:
#		print("switching strats")
#		moves_ahead = 3
#	else:
#		moves_ahead = 2
	var score = -999
	var curr_move
	for piece in list_movable:
		for i in range(1, piece.size()):
			var new_move = makeMove(board, piece[0], piece[i])
			var new_score
			new_score = calcBestMove(new_move, oppositeSide(turn), moves_ahead - 1)
#			if(moves_ahead == 2):
#				new_score = calcBestMove(new_move, oppositeSide(turn), moves_ahead - 1)
#			else:
#				new_score = -calcBestMove(new_move, oppositeSide(turn), moves_ahead - 1)
			if new_score > score:
				score = new_score
				curr_move = new_move
	if !curr_move:
		print("this shouldn't happen but something went wrong")
	return curr_move
	
func calcBestMove(state : boardState, side, future):
	#given a board state and which side to play as,
	#returns the static evaluation (via scoreBoard())
	#of the endstate resulting from the board state
	
	#no more looking ahead, simply return the static evaluation
	if future == 0:
		return scoreBoard(state, side)
		
	var list_movable = allLegalMoves(state, side, false)
	
	#checkmate
	if list_movable == []:
		print("ai found checkmate")
		return 1000
		
	var score = -999
	for piece in list_movable:
		for i in range(1, piece.size()):
			var new_move = makeMove(state, piece[0], piece[i])
			var new_score = calcBestMove(new_move, oppositeSide(turn), future-1)
			if new_score > score:
				score = new_score
	return -1 * score
	#calculate all possible countermoves
	#and return the score
	
func makeMove(state : boardState, piece : Vector2, new_position : Vector2):
	#move the piece to the new location and returns the new board state
	var new_state = state.copy()
	var piece_to_move = new_state.tiles[piece.x][piece.y]
	
	if piece_to_move == KING || piece_to_move == KING+BLACK:
		if piece_to_move < BLACK:
			new_state.king_white = new_position
		else:
			new_state.king_black = new_position
	new_state.tiles[new_position.x][new_position.y] = piece_to_move
	new_state.tiles[piece.x][piece.y] = -1
	return new_state
	
func allLegalMoves(state: boardState, side, checking = false):
	#returns a list of all legal moves possible by the player
	#these moves are represented as a 2d array mapping each movable piece to all of its moves
	#the first element of each array is the piece, and subsequent elements are the moves
	#var time_start = OS.get_ticks_usec()
	var moves = []
	var threads = []
	var count = -1
	for i in range(8):
		for j in range(8):
			var tile = state.tiles[i][j]
			if tile >= 0:
				var tile_side
				if tile >= BLACK:
					tile_side = BLACK
				else:
					tile_side = WHITE
				if tile_side == side:
					#there is a moveable piece here
					var thread = Thread.new()
					threads.append(thread)
					thread.start(self, "allLegalHelper", [state, checking, moves, i, j])
	for t in threads:
		t.wait_to_finish()
	return moves
	
func allLegalHelper(args):
	#print("i am a thread")
	#appends to the moves list if it has moves to add
	var moves_list = [Vector2(args[3],args[4])]
	var legal_moves = calcLegalMoves(args[0], Vector2(args[3],args[4]), args[1])
	if legal_moves.size() >= 1:
		#if moves can be made, append to the total list of moves
		moves_list = moves_list + legal_moves
		mutex.lock()
		args[2].append(moves_list)
		mutex.unlock()
	
func isCheck(state : boardState, side, alt_list = [[]]):
	#given a boardstate and the player's side, determines if that player is in check
	#iterates through all possible moves of the opposing side
	#and returns true if any of their moves could hit the king
	#note that these hypothetical moves are legal even if they would put themselves in check
	var list_moveable = [[]]
	list_moveable = allLegalMoves(state, oppositeSide(side), true)
	var king = Vector2() #locate our king
	if side == WHITE:
		king = state.king_white
	else:
		king = state.king_black
	for list_moves in list_moveable:
		#first element holds the piece, ignore it
		for i in range(1, list_moves.size()):
			if list_moves[i] == king:
				return true
	return false

# Called when the node enters the scene tree for the first time.
func _ready():
	#place pieces
	board.initialize()
	board.setup()
	
func _draw():
	#draw the background
	for x in range(8):
		for y in range(8):
			if x%2 == y%2:
				draw_rect(Rect2(x*TILEWIDTH, y*TILEWIDTH, TILEWIDTH, TILEWIDTH), tile_white);
			else:
				draw_rect(Rect2(x*TILEWIDTH, y*TILEWIDTH, TILEWIDTH, TILEWIDTH), tile_black);
				
	#draw pieces
	for i in range(8):
		for j in range(8):
			var piece = board.tiles[i][j]
			if piece >= 0:
				#if this is a piece
				var tex = get_child(piece).texture
				
				var x = i
				var y = j
				if player == BLACK:
					x = (7-i)
					y = (7-j)
				#if it's currently selected, hop up a bit
				if piece_selected.x == i && piece_selected.y == j:
					draw_texture(tex, Vector2(x * TILEWIDTH,y * TILEWIDTH - 24))
				else:
					draw_texture(tex, Vector2(x * TILEWIDTH,y * TILEWIDTH))
					
				
	#draw highlights
	for move in possible_moves:
		var x = move.x
		var y = move.y
		if player == BLACK:
			x = 7-x
			y = 7-y
		draw_circle(Vector2(x,y) * Vector2(128,127) + Vector2(64,64), 16, highlight)
		
	#draw text
	match turn:
		WHITE:
			draw_texture(white_turn, Vector2(0,-8))
		BLACK:
			draw_texture(black_turn, Vector2(0,-8))
		START:
			if selection == 1:
				draw_texture(ai_select, Vector2(0, + 12))
			else:
				draw_texture(ai_select, Vector2(0, 0))
			if selection == 2:
				draw_texture(human_select, Vector2(0, 256 + 12))
			else:
				draw_texture(human_select, Vector2(0, 256))
		COLOR:
			#draw_texture(choose, Vector2(0, 0))
			if selection == 1:
				draw_texture(white_select, Vector2(0, + 12))
			else:
				draw_texture(white_select, Vector2(0, 0))
			if selection == 2:
				draw_texture(black_select, Vector2(0, 256 + 12))
			else:
				draw_texture(black_select, Vector2(0, 256))
		WHITELOSE:
			draw_texture(white_end_text, Vector2(0,0))
		BLACKLOSE:
			draw_texture(black_end_text, Vector2(0,0))
		
		
func ai_move():
	#the ai makes a move based on the current board state
	print("ai turn")
	board = calcBestMoveHelper()
	pass_turn()
	
func pass_turn():
	#pass turn and check if the last move won the game
	turn = oppositeSide(turn)
	print("passed turn to", turn)
	#check for checkmate
	if allLegalMoves(board, turn) == []:
		print("checkmate")
		computer = 0
		if turn == WHITE:
			turn = WHITELOSE
		else:
			turn = BLACKLOSE
	else:
		print("score for ", turn, scoreBoard(board, turn))
	
	#ai takes its move
	if computer == 1:
		if turn != player:
			ai_move()
				
func process_turn(mouse : Vector2):
	if piece_selected[0] >= 0:
		#iterate through possible moves and make a move, or deselect
		for move in possible_moves:
			if move == mouse:
				#move selected
				print("making move")
				board = makeMove(board, piece_selected, move)
				piece_selected = Vector2(-1,-1)
				possible_moves = []
				update()
				#timer is here because, for some reason,
				#Godot likes to calculate the AI's
				#next move before actually updating the screen
				#which looked ugly
				#timer is a hacky way to force it to process graphics first
				var t = Timer.new()
				t.set_wait_time(.05)
				t.set_one_shot(true)
				self.add_child(t)
				t.start()
				yield(t, "timeout")
				#pass turn
				pass_turn()
				break;
		#clicked away from selected piece
		piece_selected = Vector2(-1,-1)
		possible_moves = []
		print('deselect')
		update()
	else:
		var tile = board.tiles[mouse.x][mouse.y]
		if tile >= 0:
			var tile_side
			if tile >= BLACK:
				tile_side = BLACK
			else:
				tile_side = WHITE
			if tile_side == turn:
				print("piece selected")
				piece_selected = Vector2(mouse.x, mouse.y)
				possible_moves = calcLegalMoves(board, Vector2(mouse.x, mouse.y))
				update()
				
func navigateMenu(x1, x2, y1, y2, pressed):
	#takes in the coordinates of the second button
	var mouse = get_global_mouse_position()
	print(mouse)
	#clicked top button
	if (mouse.x >= 268 && mouse.x <= 710 && mouse.y >= 328 && mouse.y <= 478):
		if pressed == true:
			selection = 1
		elif selection == 1:
			selection = 0
			if turn == START:
				#selected AI
				print("going to color")
				turn = COLOR
				computer = 1
			elif turn == COLOR:
				#selected white
				turn = BLACK
				pass_turn()
		else:
			selection = 0;
	#clicked bottom button
	elif (mouse.x >= x1 && mouse.x <= x2 && mouse.y >= y1 && mouse.y <= y2):
		if pressed == true:
			selection = 2
		elif selection == 2:
			if turn == COLOR:
				player = BLACK
			selection = 0
			turn = BLACK
			pass_turn()
		else:
			selection = 0
	else:
		if pressed == false:
			selection = 0;
	update();
			
func _input(event):
	#left mouse button
	if event is InputEventMouseButton && event.button_index == 1:
		if turn == START:
			navigateMenu(132, 863, 576, 736, event.pressed)
		elif turn == COLOR:
			navigateMenu(258, 710, 584, 736, event.pressed)

		elif event.pressed == true:
			if turn == WHITELOSE || turn == BLACKLOSE:
				#restart game
				board = boardState.new()
				board.initialize()
				board.setup()
				player = WHITE
				turn = START
				update()
			else:
				var mouse = get_global_mouse_position()
				mouse.x = round((mouse.x/128 - .5))
				mouse.y = round((mouse.y/128 - .5))
				if player == BLACK:
					mouse.x = 7 - mouse.x
					mouse.y = 7-mouse.y
				print(mouse)
				process_turn(mouse)
