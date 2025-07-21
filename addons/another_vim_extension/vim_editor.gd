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

var _visual_mode_start: Vector2 = Vector2.ZERO
var _last_command: String

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
			print(dest_column)
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
	else:
		remove_theme_constant_override("caret_width")


func is_visual() -> bool:
	return bool(mode & MODE_VISUAL_MASK)

func set_visual_origin() -> void:
	if not is_visual():
		return
	
	if mode == MODE_VISUAL:
		_visual_mode_start = Vector2(column, line)
	elif mode == MODE_VISUAL_BLOCK:
		_visual_mode_start = Vector2(0, line)



class Actions:
	var ed: VimEditor
	
	func _init(editor: VimEditor) -> void:
		ed = editor
	
	func move_column(amount: int) -> void:
		ed.column = ed.column + amount

	func move_line(amount: int) -> void:
		ed.line = ed.line + amount
