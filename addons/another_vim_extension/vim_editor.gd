@tool
extends CodeEdit

enum {
	MODE_NORMAL,
	MODE_INSERT,
	MODE_VISUAL,
	MODE_COMMAND,
}

const VimEditor: GDScript = preload("res://addons/another_vim_extension/vim_editor.gd")
const Vim: GDScript = preload("res://addons/another_vim_extension/vim.gd")
const MODE_NAMES: Dictionary[int, String] = {
	MODE_NORMAL: "",
	MODE_INSERT: "INSERT",
	MODE_VISUAL: "VISUAL",
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

# Shorthands
var column: int:
	set(value):
		var amount: int = value - column
		var reselect: bool = false
		if line == _visual_mode_start.y and column + amount == _visual_mode_start.x:
			_visual_mode_start.x += -sign(amount)
			reselect = true
		set_caret_column(value)
		if reselect:
			select.call_deferred(_visual_mode_start.y, _visual_mode_start.x, line, column)
	get: return get_caret_column()
var line: int:
	set(value): set_caret_line(value)
	get: return get_caret_line()




func _handle_unicode_input(unicode_char: int, caret_index: int) -> void:
	if mode != MODE_INSERT:
		return
	insert_text_at_caret(char(unicode_char), caret_index)
	request_code_completion.call_deferred()


func _process(delta: float) -> void:
	if has_selection() and mode != MODE_VISUAL:
		set_mode.call_deferred(MODE_VISUAL)
	if mode == MODE_VISUAL:
		set_selection_origin_line(_visual_mode_start.y)
		set_selection_origin_column(_visual_mode_start.x)
	
	


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
				set_mode.call_deferred(MODE_VISUAL)
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
	if new_mode != MODE_VISUAL and mode == MODE_VISUAL:
		deselect()
	mode = new_mode
	if mode == MODE_VISUAL and not has_selection():
		_visual_mode_start = Vector2(get_caret_column(), get_caret_line())
		if not is_dragging_cursor():
			set_selection_mode(TextEdit.SELECTION_MODE_SHIFT)
			select(_visual_mode_start.y, _visual_mode_start.x, _visual_mode_start.y, _visual_mode_start.x + 1)
	set_mode_caret()


func setup(vim_script: Vim) -> void:
	vim = vim_script
	name = "VimEdit"
	caret_multiple = false
	set_mode_caret()
	toaster = EditorInterface.get_editor_toaster()
	set_process_input(true)


func destroy() -> void:
	caret_multiple = true
	set_caret(false)
	set_process_input(false)


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


class Actions:
	var ed: VimEditor
	
	func _init(editor: VimEditor) -> void:
		ed = editor
	
	func move_column(amount: int) -> void:
		ed.column = ed.column + amount

	func move_line(amount: int) -> void:
		ed.line = ed.line + amount
