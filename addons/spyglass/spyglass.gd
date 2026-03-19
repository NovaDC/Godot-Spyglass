@tool
@icon("./icon.svg")
class_name Spyglass
extends Node2D

signal hooked_node_changed()

signal window_grab_started(offset:Vector2i)
signal window_grab_finished()

@export var debug_rect_color := Color(1, 1, 1, 0.5)
@export_range(0, 10, 0.1) var debug_rect_width:float = 2
@export_range(0, 10, 0.1) var debug_rect_dash:float = 4

@export var update_on_frame := false
@export var update_on_physics_frame := false
@export var update_on_input := false
@export var update_on_input_only_when_focused := false

@export var follow_transform_when_hidden := false

@export var custom_mouse_grab_action_name:StringName = "spyglass_grab"

@export var size:Vector2:
	get:
		return size
	set(_value):
		size = _value
		item_rect_changed.emit()
		try_update_window_from_transform()

@export var local_rect:Rect2:
	get:
		return Rect2(position, scale * size)
	set(_value):
		position = _value.position
		size = _value.size / scale

@export var global_rect:Rect2:
	get:
		return Rect2(global_position, global_scale * size)
	set(_value):
		global_position = _value.position
		size = _value.size / global_scale

var _window_metascreen_rect:Rect2:
	get:
		if hooked_window == null:
			return Rect2()
		var win_rect := Rect2(Vector2(hooked_window.position), Vector2(hooked_window.size))
		if hooked_window.is_embedded():
			var parent_window := get_window()
			var parent_window_transform := parent_window.get_final_transform()
			parent_window_transform = parent_window_transform.translated(parent_window.position)
			win_rect = parent_window_transform * win_rect
		return win_rect
	set(_value):
		if hooked_window == null:
			return
		var val := _value
		if hooked_window.is_embedded():
			var parent_window := get_window()
			var parent_window_t := parent_window.get_final_transform().affine_inverse()
			parent_window_t = parent_window_t.translated_local(-parent_window.position)
			val = parent_window_t * val
		var new_pos := Vector2i(val.position.floor())
		var new_size := Vector2i(val.size.floor())
		if new_pos != hooked_window.position:
			# Some signals and notifications fire even when the window is set to the position its already at...
			hooked_window.position = new_pos
		# Some signals and notificationn fire even when the window is set to the position its already at...
		if new_size != hooked_window.size:
			hooked_window.size = new_size

var _hooked_window:Window = null
var _hooked_camera:Camera2D = null

var _is_custom_grabbed := false
var _custom_grab_offset := Vector2i.ZERO

var hooked_window:Window:
	get:
		return _hooked_window

var hooked_camera:Camera2D:
	get:
		return _hooked_camera

func rehook_window():
	var was := _hooked_window

	if _hooked_window != null:
		if _hooked_window.is_queued_for_deletion() or _hooked_window.get_parent() != self:
			if _hooked_window.window_input.is_connected(_on_window_or_nonclient_input):
				_hooked_window.window_input.disconnect(_on_window_or_nonclient_input)
			if _hooked_window.nonclient_window_input.is_connected(_on_window_or_nonclient_input):
				_hooked_window.nonclient_window_input.disconnect(_on_window_or_nonclient_input)
			if _hooked_window.child_order_changed.is_connected(rehook_camera):
				_hooked_window.child_order_changed.disconnect(rehook_camera)
			if _hooked_window.tree_exiting.is_connected(rehook_window):
				_hooked_window.tree_exiting.disconnect(rehook_window)
			if _hooked_window.size_changed.is_connected(_on_window_viewport_size_changed):
				_hooked_window.size_changed.disconnect(_on_window_viewport_size_changed)

			_hooked_window = null

	if _hooked_window == null:
		var windows := find_children("*", "Window", false, false)

		if not windows.is_empty():
			_hooked_window = windows.front()

	if _hooked_window != null:
		if not _hooked_window.window_input.is_connected(_on_window_or_nonclient_input):
			_hooked_window.window_input.connect(_on_window_or_nonclient_input)
		if not _hooked_window.nonclient_window_input.is_connected(_on_window_or_nonclient_input):
			_hooked_window.nonclient_window_input.connect(_on_window_or_nonclient_input)
		if not _hooked_window.child_order_changed.is_connected(rehook_camera):
			_hooked_window.child_order_changed.connect(rehook_camera)
		if not _hooked_window.tree_exiting.is_connected(rehook_window):
			_hooked_window.tree_exiting.connect(rehook_window)
		if not _hooked_window.size_changed.is_connected(_on_window_viewport_size_changed):
			_hooked_window.size_changed.connect(_on_window_viewport_size_changed)
		#TODO recycle old nodes, don't make new if you don't have to
		var listen := WindowPositionListener.new()
		_hooked_window.add_child(listen)
		listen.window_position_changed.connect(_on_window_update_position)

	rehook_camera()

	if was != _hooked_window:
		update_configuration_warnings()
		hooked_node_changed.emit()
		_update_settings()
		try_update()

func rehook_camera():
	var was := _hooked_camera

	if _hooked_camera != null:
		if _hooked_camera.is_queued_for_deletion() or _hooked_window == null or _hooked_camera.get_parent() != _hooked_window:
			if _hooked_camera.tree_exiting.is_connected(rehook_camera):
				_hooked_camera.tree_exiting.disconnect(rehook_camera)
			_hooked_camera = null

	if _hooked_window != null:
		var cameras := _hooked_window.find_children("*", "Camera2D", false, false)

		if not cameras.is_empty():
			_hooked_camera = cameras.front()

	if _hooked_camera != null:
		if not _hooked_camera.tree_exiting.is_connected(rehook_camera):
			_hooked_camera.tree_exiting.connect(rehook_camera)

	if was != _hooked_camera:
		_update_settings()
		update_configuration_warnings()
		hooked_node_changed.emit()
		try_update()

func _get_configuration_warnings() -> PackedStringArray:
	var warn := PackedStringArray()
	if hooked_window == null:
		warn.append("No child Window found. Spyglass will not function.")

	if hooked_camera == null:
		warn.append("No grandchild Camera found. Spyglass will not function.")
		if hooked_window != null and not find_children("*", "Camera2D", false, false).is_empty():
			warn.append("Camera must be a child of the Window node, not the Spyglass node itself.")

	return warn


func _ready() -> void:
	set_notify_transform(true)
	if not child_order_changed.is_connected(rehook_window):
		child_order_changed.connect(rehook_window)
	if not child_order_changed.is_connected(rehook_camera):
		child_order_changed.connect(rehook_camera)
	if not child_order_changed.is_connected(update_configuration_warnings):
		child_order_changed.connect(update_configuration_warnings)
	_latest_transform = global_transform
	rehook_window()

var _latest_transform := Transform2D()
func _notification(what: int) -> void:
	match (what):
		NOTIFICATION_VISIBILITY_CHANGED:
			_update_settings()
		NOTIFICATION_TRANSFORM_CHANGED when global_transform != _latest_transform:
			item_rect_changed.emit()
			try_update_window_from_transform()
			_latest_transform = global_transform

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

	if update_on_frame:
		try_update()

	#debug testing
	if not Engine.is_editor_hint():
		var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		position += v * delta * 120

func _draw():
	if not Engine.is_editor_hint():
		return

	var top_left := Vector2.ZERO
	var bottom_left := global_rect.size * Vector2.DOWN
	var top_right := global_rect.size * Vector2.RIGHT
	var bottom_right := global_rect.size

	draw_dashed_line(top_left, top_right, debug_rect_color, debug_rect_width, debug_rect_dash)
	draw_dashed_line(top_right, bottom_right, debug_rect_color, debug_rect_width, debug_rect_dash)
	draw_dashed_line(bottom_right, bottom_left, debug_rect_color, debug_rect_width, debug_rect_dash)
	draw_dashed_line(bottom_left, top_left, debug_rect_color, debug_rect_width, debug_rect_dash)

func _physics_process(delta: float) -> void:
	if update_on_physics_frame:
		try_update()

func _input(event: InputEvent) -> void:
	if update_on_input:
		if update_on_input_only_when_focused and not hooked_window.has_focus():
			return
		try_update()

func _on_window_or_nonclient_input(event:InputEvent):
	if not custom_mouse_grab_action_name.is_empty():
		var mouse_meta := DisplayServer.mouse_get_position()
		if event.is_action_pressed(custom_mouse_grab_action_name) and _window_metascreen_rect.has_point(mouse_meta):
			start_custom_mouse_grab(mouse_meta - Vector2i(_window_metascreen_rect.position))
		elif event.is_action_released(custom_mouse_grab_action_name):
			end_custom_mouse_grab()

	if is_custom_grabbed():
		try_update_transform_from_window()

func is_spyglass_enabled() -> bool:
	return is_inside_tree() and is_node_ready() and (follow_transform_when_hidden or visible) and not Engine.is_editor_hint()

func _on_window_update_position(_ign):
	if hooked_window.borderless:
		return
	_os_window_moved_instance = true
	force_update_transform_from_window()

func _on_window_viewport_size_changed():
	if hooked_window.borderless: #unresizable windows may still be resized when maximizing
		return
	_os_just_updated_window_size = true
	force_update_transform_from_window()


var _os_just_updated_window_size := false
var _os_window_moved_instance := false
func is_window_controlling() -> bool:
	return is_custom_grabbed() or _os_window_moved_instance or _os_just_updated_window_size



func is_custom_grabbed() -> bool:
	return _is_custom_grabbed

func get_latest_custom_grab_offset() -> Vector2i:
	return _custom_grab_offset

func start_custom_mouse_grab(window_cursor_offset:Vector2i) -> bool:
	if is_custom_grabbed():
		return false
	_is_custom_grabbed = true
	_custom_grab_offset = window_cursor_offset
	try_update_transform_from_window()
	window_grab_started.emit(window_cursor_offset)
	return true

func end_custom_mouse_grab() -> bool:
	if not is_custom_grabbed():
		return false
	_is_custom_grabbed = false
	window_grab_finished.emit()
	return true


#TODO why can this just be in the forced updates?
func _update_settings() -> void:
	if hooked_window == null:
		return

	if hooked_camera == null or not is_spyglass_enabled():
		return

	if get_window() != null:
		hooked_window.own_world_3d = false
		hooked_window.world_2d = get_window().world_2d
		hooked_window.world_3d = get_window().world_3d
	else:
		hooked_window.own_world_3d = true
	hooked_window.visible = visible

func try_update():
	if not is_spyglass_enabled():
		return
	force_update()

func force_update():
	if is_window_controlling():
		force_update_transform_from_window()
	else:
		force_update_window_from_transform()

func try_update_transform_from_window():
	if (not is_spyglass_enabled()) or not is_window_controlling():
		return
	force_update_transform_from_window()

func try_update_window_from_transform():
	if (not is_spyglass_enabled()) or is_window_controlling():
		return
	force_update_window_from_transform()

func force_update_transform_from_window():
	if hooked_window == null or hooked_camera == null:
		return
	_update_settings()

	if is_custom_grabbed():
		_window_metascreen_rect.position = Vector2(DisplayServer.mouse_get_position() - get_latest_custom_grab_offset())

	#TODO find appropriate transform
	var trans := Transform2D()

	print("position from window")
	global_rect = trans * Rect2(_window_metascreen_rect)
	hooked_camera.global_transform = global_transform
	hooked_camera.align()
	set_deferred("_os_window_moved_instance", false)
	set_deferred("_os_just_updated_window_size", false)

func force_update_window_from_transform():
	if hooked_window == null or hooked_camera == null:
		return
	_update_settings()

	#TODO find appropriate transform
	var trans := Transform2D()

	print("window from position")

	_window_metascreen_rect = trans * Rect2(global_rect)
	hooked_camera.global_transform = global_transform
	hooked_camera.align()
