@tool
extends CodeEdit

enum {
	MODE_NORMAL = 			0b00001,
	MODE_INSERT = 			0b00010,
	MODE_VISUAL =	 		0b00100,
	MODE_VISUAL_BLOCK = 	0b01000,
	MODE_COMMAND = 			0b10000,
	MODE_VISUAL_MASK = 		MODE_VISUAL | MODE_VISUAL_BLOCK
}

enum {
	COMMAND_NORMAL,
	COMMAND_MOTION,
}

const VimEditor: GDScript = preload("res://addons/another_vim_extension/vim_editor.gd")
const Vim: GDScript = preload("res://addons/another_vim_extension/vim.gd")
const MODE_NAMES: Dictionary[int, String] = {
	MODE_NORMAL: "",
	MODE_INSERT: "INSERT",
	MODE_VISUAL: "VISUAL",
	MODE_VISUAL_BLOCK: "VISUAL BLOCK",
	MODE_COMMAND: "Command",
}

static var regs: Dictionary[String, String] = {

}

var toaster: EditorToaster
var vim: Vim
var mode: int = MODE_NORMAL:
	set(value):
		mode = value
		vim.command_line.placeholder_text = MODE_NAMES.get(mode, "")
var actions: Actions = Actions.new(self)
var parsers: Dictionary[int, Parser] = {
	MODE_NORMAL: ParserNormal.new(self),
}

var command_buffer: Array[InputEventKey]
var last_command: Array[InputEventKey]
var _visual_mode_start: Vector2 = Vector2.ZERO


# Shorthands
var column: int:
	set(value):
		var amount: int = value - column
		var reselect: bool = false
		if is_visual() and line == _visual_mode_start.y and column + amount == _visual_mode_start.x:
			_visual_mode_start.x += -sign(amount)
			reselect = true
		set_caret_column(value)
		if reselect:
			select.call_deferred(_visual_mode_start.y, _visual_mode_start.x, line, column)
	get: return get_caret_column()
var line: int:
	set(value):
		if mode == MODE_VISUAL_BLOCK:
			if value < _visual_mode_start.y:
				_visual_mode_start.x = get_line(_visual_mode_start.y).length()
			elif value >= _visual_mode_start.y:
				_visual_mode_start.x = 0
		set_caret_line(value)
	get: return get_caret_line()




func _handle_unicode_input(unicode_char: int, caret_index: int) -> void:
	if mode != MODE_INSERT:
		return
	insert_text_at_caret(char(unicode_char), caret_index)
	request_code_completion.call_deferred()


func _process(delta: float) -> void:
	if has_selection() and not is_visual():
		set_mode.call_deferred(MODE_VISUAL)
	if is_visual():
		set_selection_origin_line(_visual_mode_start.y)
		set_selection_origin_column(_visual_mode_start.x)
		if mode == MODE_VISUAL_BLOCK:
			var dest_column: int = get_line(line).length() if _visual_mode_start.y <= line else 0
			select.call_deferred(
				_visual_mode_start.y, _visual_mode_start.x,
				line, dest_column
				)
	


func _gui_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey

	if not has_focus() or not key:
		return

	if key.pressed:
		_input_pressed(key)
	else:
		_input_released(key)


func _input_pressed(key: InputEventKey) -> void:
	match key.keycode:
		KEY_ENTER:
			if mode != MODE_INSERT:
				accept_event()
		KEY_BACKSPACE:
			if mode != MODE_INSERT:
				accept_event()
		KEY_DELETE:
			if mode != MODE_INSERT:
				accept_event()
		KEY_ESCAPE:
			set_mode.call_deferred(MODE_NORMAL)
		KEY_I:
			if mode == MODE_NORMAL:
				set_mode.call_deferred(MODE_INSERT)
		KEY_V:
			if mode == MODE_NORMAL:
				set_mode.call_deferred(MODE_VISUAL if not key.shift_pressed else MODE_VISUAL_BLOCK)
		KEY_LEFT:
			actions.move_column(-1)
			accept_event()
		KEY_RIGHT:
			actions.move_column(1)
			accept_event()
		KEY_UP:
			actions.move_line(-1)
			accept_event()
		KEY_DOWN:
			actions.move_line(1)
			accept_event()
	var parser: Parser = parsers.get(mode)
	if parser:
		process_command(parser.feed(key), parser)


func _input_released(key: InputEventKey) -> void:
	match key.keycode:
		_:
			pass


func set_mode(new_mode: int):
	if not (new_mode & MODE_VISUAL) and is_visual():
		deselect()
	mode = new_mode
	if is_visual() and not has_selection():
		set_visual_origin()
		if not is_dragging_cursor():
			set_selection_mode(TextEdit.SELECTION_MODE_SHIFT)
			if mode == MODE_VISUAL:
				select(_visual_mode_start.y, _visual_mode_start.x, _visual_mode_start.y, _visual_mode_start.x + 1)
			else:
				select(line, get_line(line).length(), _visual_mode_start.y, _visual_mode_start.x)
	set_mode_caret()


func setup(vim_script: Vim) -> void:
	vim = vim_script
	name = "VimEdit"
	caret_multiple = false
	set_mode_caret()
	toaster = EditorInterface.get_editor_toaster()


func destroy() -> void:
	caret_multiple = true
	set_caret(false)


func set_mode_caret() -> void:
	if mode == MODE_INSERT or mode == MODE_VISUAL:
		set_caret(false)
	else:
		set_caret(true)


func set_caret(block: bool) -> void:
	caret_type = TextEdit.CARET_TYPE_LINE
	if block:
		var font: Font = get_theme_font("font")
		var width: int = font.get_string_size(
			"A",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			get_theme_font_size("font_size")
		).x

		add_theme_constant_override("caret_width", width)
		add_theme_color_override("caret_color", Color8(255, 255, 255, 128))
	else:
		remove_theme_constant_override("caret_width")
		remove_theme_color_override("caret_color")


func is_visual() -> bool:
	return bool(mode & MODE_VISUAL_MASK)


func set_visual_origin() -> void:
	if not is_visual():
		return
	
	if mode == MODE_VISUAL:
		_visual_mode_start = Vector2(column, line)
	elif mode == MODE_VISUAL_BLOCK:
		_visual_mode_start = Vector2(0, line)


func process_command(command: Dictionary[String, Variant], parser: Parser) -> void:
	if command.get("reset", false):
		parser.reset()
		vim.input_line.text = ""
	vim.input_line.text += command.get("char", "")
	
	if not command.get("completed", false):
		return
	
	parser.process_command(command)


class Parser:
	enum {
		START,
		COUNT_BEFORE,
		COUNT_AFTER,
	}
	
	const OPERATORS: Array[String] = ["c", "d", "y", ">", "<", "J", "g"]
	const MOTIONS: Array[String] = ["w", "W", "e", "E", "b", "B", "$", "0", "h", "j", "k", "l", "H", "K", "L"]
	
	var operators: Dictionary[String, Callable]
	var motions: Dictionary[String, Callable]
	
	var ed: VimEditor
	var actions: Actions:
		get: return ed.actions
	var status: int
	var operator: String
	var count: int = 1
	var motion: String
	
	func _init(editor: VimEditor) -> void:
		ed = editor

	func reset() -> void:
		status = START
		operator = ""
		count = 1
		motion = ""

	func feed(key: InputEventKey) -> Dictionary[String, Variant]:
		if key.keycode == KEY_ESCAPE:
			return { "reset": true }
		
		var char: String = OS.get_keycode_string(key.keycode)
		if not key.shift_pressed:
			char = char.to_lower()
		
		if status == START:
			if char.is_valid_int() and char != "0":
				count = int(char)
				status = COUNT_BEFORE
				return { "pending": true, "char": char }
			elif char in MOTIONS:
				motion = char
				return { "completed": true, "motion": motion, "operator": "", "count": count, "reset": true }
			elif char in OPERATORS:
				pass
		elif status == COUNT_BEFORE:
			if char.is_valid_int():
				count = count * 10 + int(char)
				return { "pending": true, "char": char }
			elif char in MOTIONS:
				motion = char
				status = START
				return { "completed": true, "motion": motion, "operator": "", "count": count, "reset": true }
	
		return { "reset": true }
	
	func process_command(command: Dictionary[String, Variant]) -> void:
		if command.get("motion") and not command.get("operator"):
			for i: int in command.get("count", 1):
				var fun: Callable = motions.get(command.motion, Callable())
				fun.call()


class ParserNormal extends Parser:
	func _init(ed: VimEditor) -> void:
		super(ed)
		motions = {
			"h": actions.move_column.bind(-1),
			"l": actions.move_column.bind(1),
			"j": actions.move_line.bind(1),
			"k": actions.move_line.bind(-1),
			"e": actions.move_to_word_end.bind(false),
			"E": actions.move_to_word_end.bind(true),
		}


class Actions:
	var ed: VimEditor

	func _init(editor: VimEditor) -> void:
		ed = editor


	func _pos_is_eof(position: Vector2) -> bool:
		return position.y >= ed.get_line_count() and position.x >= ed.get_line(ed.get_line_count() - 1).length() 


	func _offset_position(position: Vector2, amount: int) -> Vector2:
		position.x += amount
		var line: String = ed.get_line(position.y)
		if position.x >= line.length():
			position.x -= line.length()
			position.y += 1
		elif position.x < 0:
			position.y -= 1
			position.x = ed.get_line(position.y).length() + position.x

		return position


	func _is_char_word(char: String, big: bool = false) -> bool:
		if big:
			return not (char in [" ", "\n", "\t"])
		else:
			return (char.to_lower() >= "a" and char.to_lower() <= "z") or char.is_valid_int() or char == "_"


	func move_column(amount: int) -> void:
		ed.column = ed.column + amount


	func move_line(amount: int) -> void:
		ed.line = ed.line + amount


	func move_to_word_end(big_word: bool) -> void:
		var pos: Vector2 = get_word_end(big_word)
		ed.line = pos.y
		ed.column = pos.x


	func get_word_end(big_word: bool, position: Vector2 = Vector2(ed.column, ed.line)) -> Vector2:
		# TODO
		return position
