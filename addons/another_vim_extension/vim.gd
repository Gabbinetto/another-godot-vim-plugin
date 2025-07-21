@tool
extends EditorPlugin

const VimEditor: GDScript = preload("res://addons/another_vim_extension/vim_editor.gd")

var script_editor: ScriptEditor
var current_editor: VimEditor

var bottom_bar: HBoxContainer
var command_line: LineEdit
var input_line: Label


func _ready() -> void:
	script_editor = get_editor_interface().get_script_editor()
	await get_tree().process_frame

	script_editor.editor_script_changed.connect(
		func(_script: Script): check_editors()
	)

	EditorInterface.set_main_screen_editor("Script")
	check_editors()

	#var ref: ReferenceRect = ReferenceRect.new()
	#ref.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#ref.border_color = Color.GREEN
	#var node: Variant = script_editor.get_child(0).get_child(1).get_child(1)
	#node.get_child(0).add_child(ref)
	#printt(
		#node, node.get_child(0)
	#)

	# TODO: Fix
	var container: Node = current_editor
	while container and (container != VBoxContainer or container == script_editor):
		container = container.get_parent_control()
		if not container:
			break
	if container != script_editor and container is VBoxContainer:
		_make_command_line(container)
	
	# Fallback:
	if not bottom_bar:
		print("Bottom bar fallback")
		for child: Node in script_editor.get_children():
			if child is VBoxContainer:
				_make_command_line(child)
				break


func _exit_tree() -> void:
	if bottom_bar:
		bottom_bar.queue_free()
	
	destroy_editors()


func _make_command_line(control: Control) -> void:
	if not control:
		return

	bottom_bar = HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	command_line = LineEdit.new()
	command_line.name = "CommandLine"
	command_line.flat = true
	command_line.editable = false
	command_line.placeholder_text = "Command"
	input_line = Label.new()
	input_line.name = "InputLine"
	input_line.text = "Input"
	bottom_bar.add_child(command_line)
	bottom_bar.add_child(input_line)
	command_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_line.size_flags_stretch_ratio = 0.3

	control.add_child(bottom_bar)


func check_editors() -> void:
	for editor: ScriptEditorBase in script_editor.get_open_script_editors():
		var control: Control = editor.get_base_editor()
		if control is CodeEdit:
			if not VimEditor.instance_has(control):
				control.set_script(VimEditor)
				control.setup(self)
				control.visibility_changed.connect(check_editors.call_deferred)
	if current_editor:
		current_editor.set_process(false)
		current_editor.set_process_input(false)
		current_editor = null
	var editor_base: ScriptEditorBase = script_editor.get_current_editor()
	if not editor_base:
		return
	current_editor = editor_base.get_base_editor()
	if current_editor:
		current_editor.set_process(true)
		current_editor.set_process_input(true)


func destroy_editors() -> void:
	for editor: ScriptEditorBase in script_editor.get_open_script_editors():
		var control: Control = editor.get_base_editor()
		if VimEditor.instance_has(control):
			control.destroy()
			control.set_process(false)
			control.set_process_input(false)
			control.set_script(null)
