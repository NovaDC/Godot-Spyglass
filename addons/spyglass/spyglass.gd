@tool
@icon("./icon.svg")
class_name Spyglass
extends Camera2D

signal frame_window_changed()

signal window_custom_grab_started(offset:Vector2i)
signal window_custom_grab_finished()

@export var frame_window:Window:
	get:
		return frame_window
	set(_value):
		if not (is_node_ready() and is_inside_tree()):
			set_deferred("frame_window", _value)
			return

		if _value != null:
			if _value.is_queued_for_deletion():
				_value = null
			var tree := get_tree()
			if tree != null and tree.root == _value:
				_value = null

		var was := frame_window

		var lis_child:_SpyglassListener = null

		if frame_window != null:
			var lis_children := frame_window.find_children("*", "_SpyglassListener", false, false)
			lis_child = lis_children.pop_back()
			for c in lis_children:
				c.queue_free()
			if frame_window.tree_exiting.is_connected(_refresh_frame_window):
				frame_window.tree_exiting.disconnect(_refresh_frame_window)
			if frame_window.window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.window_input.disconnect(_on_window_or_nonclient_input)
			if frame_window.nonclient_window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.nonclient_window_input.disconnect(_on_window_or_nonclient_input)
			if frame_window.visibility_changed.is_connected(update_spyglass):
				frame_window.visibility_changed.disconnect(update_spyglass)
			if frame_window.about_to_popup.is_connected(update_spyglass):
				frame_window.about_to_popup.disconnect(update_spyglass)
			if frame_window.size_changed.is_connected(_on_window_update_size):
				frame_window.size_changed.disconnect(_on_window_update_size)

		frame_window = _value

		if frame_window != null:
			if lis_child == null or lis_child.is_queued_for_deletion():
				lis_child = _SpyglassListener.new()
			elif lis_child.get_parent() != null:
				lis_child.get_parent().remove_child(lis_child)
			frame_window.add_child(lis_child)
			if not lis_child.window_position_changed.is_connected(_on_window_update_position):
				lis_child.window_position_changed.connect(_on_window_update_position)

			frame_window.world_2d = get_world_2d()
			custom_viewport = frame_window
			make_current()

			if not frame_window.tree_exiting.is_connected(_refresh_frame_window):
				frame_window.tree_exiting.connect(_refresh_frame_window)
			if not frame_window.window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.window_input.connect(_on_window_or_nonclient_input)
			if not frame_window.nonclient_window_input.is_connected(_on_window_or_nonclient_input):
				frame_window.nonclient_window_input.connect(_on_window_or_nonclient_input)
			if not frame_window.visibility_changed.is_connected(update_spyglass):
				frame_window.visibility_changed.connect(update_spyglass)
			if not frame_window.about_to_popup.is_connected(update_spyglass):
				frame_window.about_to_popup.connect(update_spyglass)
			if not frame_window.size_changed.is_connected(_on_window_update_size):
				frame_window.size_changed.connect(_on_window_update_size)

			frame_window.visible = visible

		if was != frame_window:
			frame_window_changed.emit()
			update_spyglass()
		update_configuration_warnings()

@export_custom(PROPERTY_HINT_NONE, "suffix:px") var window_custom_screen_offset := Vector2i.ZERO:
	get:
		return window_custom_screen_offset
	set(_value):
		window_custom_screen_offset = _value
		update_spyglass()

@export var relative_to_root_window := true:
	get:
		return relative_to_root_window
	set(_value):
		var changed:bool = _value != relative_to_root_window
		relative_to_root_window = _value
		update_configuration_warnings()
		if changed:
			update_spyglass()

@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin,loose_mode")
var custom_mouse_grab_action:StringName = "spyglass_grab"

@export_group("Update")
@export_range(-8, 8, 1, "prefer_slider", "suffix:frames") var defer_window_updates:int = 0
@export var update_on_window_moved := true
@export var update_on_transform_changed := true
@export var update_on_process := false
@export var update_on_physics_process := false
@export var update_on_input := false
@export var update_on_window_input := false

var window_adjusted_screen_rect:Rect2i:
	get:
		var rect := get_window_virtual_screen_rect()
		if relative_to_root_window and is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				rect.position -= tree.root.position
		rect.position -= window_custom_screen_offset
		return rect
	set(_value):
		if relative_to_root_window and is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				_value.position += tree.root.position
		_value.position += window_custom_screen_offset
		return set_window_virtual_screen_rect(_value)

var window_virtual_screen_rect:Rect2i:
	get = get_window_virtual_screen_rect, set = set_window_virtual_screen_rect

var _latest_transform:Transform2D
var _os_window_moved_instance := false
var _os_window_sized_instance := false

var _is_custom_grabbed := false
var _custom_grab_offset := Vector2i.ZERO

func _notification(what: int) -> void:
	match(what):
		NOTIFICATION_MOVED_IN_PARENT, NOTIFICATION_PARENTED, NOTIFICATION_UNPARENTED:
			if Engine.is_editor_hint():
				notify_property_list_changed()
		NOTIFICATION_READY, NOTIFICATION_WORLD_2D_CHANGED:
			_refresh_frame_window()
			if Engine.is_editor_hint():
				if not child_order_changed.is_connected(notify_property_list_changed):
					child_order_changed.connect(notify_property_list_changed)
			set_notify_transform(true)
			_latest_transform = global_transform
		NOTIFICATION_TRANSFORM_CHANGED when _latest_transform != global_transform:
			if update_on_transform_changed:
				update_spyglass()
			_latest_transform = global_transform
		NOTIFICATION_PROCESS when update_on_process:
			update_spyglass()
		NOTIFICATION_PHYSICS_PROCESS when update_on_physics_process:
			update_spyglass()
		NOTIFICATION_VISIBILITY_CHANGED when frame_window != null:
			frame_window.visible = visible
			update_spyglass()
		NOTIFICATION_WM_POSITION_CHANGED when frame_window != null:
			if relative_to_root_window != frame_window.is_embedded():
				# Avoid unnecessary updates in situations that won't need them
				update_spyglass()

func _input(_event: InputEvent) -> void:
	if update_on_input:
		update_spyglass()

func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name" : "Update/_manual_spyglass_update",
			"type" : TYPE_CALLABLE,
			"hint" : PROPERTY_HINT_TOOL_BUTTON,
			"hint_string" : "Manual Spyglass Update",
			"usage" : PROPERTY_USAGE_EDITOR,
		}
	]

func _get(property: StringName) -> Variant:
	match(property):
		"_manual_spyglass_update":
			return update_spyglass
	return null

func _set(property: StringName, _value: Variant) -> bool:
	match(property):
		"_manual_spyglass_update":
			return true
	return false

func _get_configuration_warnings() -> PackedStringArray:
	var warn := PackedStringArray()
	if frame_window == null:
		warn.append("No frame window. Spyglass will not function.")
	if anchor_mode != ANCHOR_MODE_FIXED_TOP_LEFT:
		const MSG := ("Spyglass may misbehave when anchor_mode is not set to" +
					"ANCHOR_MODE_FIXED_TOP_LEFT on some OSes when using OS resizing methods."
					)
		warn.append(MSG)
	if is_inside_tree() and get_tree() != null:
		var tree := get_tree()
		if relative_to_root_window and tree.root.find_children("*", "Camera2D", true, false).size() <= 1:
			warn.append("Spyglass will not work if its the only Camera2D to display.")
	return warn

func _property_can_revert(property: StringName) -> bool:
	match (property):
		"update_on_process", "update_on_physics_process":
			return true
		"anchor_mode":
			return true
		"window_adjusted_screen_rect":
			return true
		"frame_window" when is_inside_tree():
			return true
	return false

func _property_get_revert(property: StringName) -> Variant:
	match (property):
		"update_on_process":
			return process_callback == CAMERA2D_PROCESS_IDLE
		"update_on_physics_process":
			return process_callback == CAMERA2D_PROCESS_PHYSICS
		"anchor_mode":
			# The only way to know when the anchor mode is changed
			# The property list notification doesn't work for some reason...
			update_configuration_warnings()
			return ANCHOR_MODE_FIXED_TOP_LEFT
		"window_adjusted_screen_rect":
			return window_adjusted_screen_rect
		"frame_window" when is_inside_tree():
			var local_tree := get_tree()
			for immediate_child in find_children("*", "Window", false, false):
				if not immediate_child.is_queued_for_deletion():
					return immediate_child
			for recursive_child in find_children("*", "Window", true, false):
				if not recursive_child.is_queued_for_deletion():
					return recursive_child
			var p := get_parent()
			while p != null and p.get_tree() == local_tree:
				if p is Window and not p.is_queued_for_deletion():
					return p
				p = p.get_parent()
	return null

func _on_window_update_position():
	if update_on_window_moved:
		_os_window_moved_instance = true
		update_spyglass()

func _on_window_update_size():
	_os_window_sized_instance = true
	update_spyglass()
	update_spyglass.call_deferred()

func _on_window_or_nonclient_input(event:InputEvent):
	if InputMap.has_action(custom_mouse_grab_action):
		var mouse_v_screen := DisplayServer.mouse_get_position()
		var mouse_in_v_screen := window_virtual_screen_rect.has_point(mouse_v_screen)
		if mouse_in_v_screen and event.is_action_pressed(custom_mouse_grab_action):
			start_custom_mouse_grab(mouse_v_screen - frame_window.position)
		elif event.is_action_released(custom_mouse_grab_action):
			end_custom_mouse_grab()

	if is_custom_grabbed():
		update_spyglass()
	elif update_on_window_input:
		update_spyglass()

func _refresh_frame_window():
	frame_window = frame_window

func get_window_virtual_screen_rect() -> Rect2i:
	if frame_window == null:
		return Rect2i()

	var int_rect := Rect2i(frame_window.position, frame_window.size)

	if frame_window.is_embedded():
		var closest_parent_window := frame_window.get_parent().get_window()
		var float_rect := closest_parent_window.get_screen_transform() * Rect2(int_rect)
		int_rect = Rect2i(float_rect.position.floor(), float_rect.size.floor())
		if is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				int_rect.position += tree.root.position

	return int_rect

func set_window_virtual_screen_rect(value:Variant):
	if frame_window == null:
		return

	value = Rect2(value)

	if frame_window.is_embedded():
		if is_inside_tree():
			var tree := get_tree()
			if tree != null and tree.root != null and tree.root != frame_window:
				value.position -= Vector2(tree.root.position)

		var parent_window := frame_window.get_parent().get_window()
		value = parent_window.get_screen_transform().affine_inverse() * value

	value = Rect2i(value.position.floor(), value.size.floor())

	frame_window.position = value.position
	#frame_window.size = value.size

func get_window_screen_rect(screen_id:int = 0) -> Rect2i:
	if frame_window == null:
		return Rect2i()
	var rect := window_adjusted_screen_rect
	rect.position -= DisplayServer.screen_get_position(screen_id)
	return rect

func set_window_screen_rect(value:Rect2i, screen_id:int = 0):
	if frame_window == null:
		return
	value.position += DisplayServer.screen_get_position(screen_id)
	window_adjusted_screen_rect = value

func get_window_relative_window_rect(window:Window) -> Rect2i:
	if frame_window == null:
		return Rect2i()
	var rect := window_adjusted_screen_rect
	rect.position -= window.position
	return rect

func set_window_relative_window_rect(value:Rect2i, window:Window):
	if frame_window == null:
		return
	value.position += window.position
	window_adjusted_screen_rect = value

func get_camera_world_rect() -> Rect2:
	if frame_window == null:
		return Rect2()
	var size := frame_window.get_visible_rect().size / zoom
	var pos := global_position
	if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
		pos -= size/2
	return Rect2(pos, size)

func is_spyglass_enabled() -> bool:
	if not is_inside_tree() or not is_node_ready() or frame_window == null:
		return false
	if not enabled or not visible:
		return false
	return enabled and visible and frame_window.visible

func is_window_controlling() -> bool:
	if not is_spyglass_enabled():
		return false
	if Engine.is_editor_hint() and EditorInterface.get_editor_viewport_2d().is_ancestor_of(self):
		return false
	if is_custom_grabbed():
		return true
	return (_os_window_moved_instance and not _os_window_sized_instance)

func update_spyglass():
	if not is_spyglass_enabled():
		return
	var f:Callable
	if is_window_controlling():
		if is_custom_grabbed():
			var mouse_pos := DisplayServer.mouse_get_position()
			frame_window.position = Vector2(mouse_pos - get_last_custom_grab_offset())
		f = func ():
			print("position from window")
			var new_pos := Vector2(window_adjusted_screen_rect.position)
			if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
				new_pos += Vector2(window_adjusted_screen_rect.size) / 2
			global_position = new_pos
			align()
			item_rect_changed.emit()
			set_deferred("_os_window_moved_instance", false)
		if defer_window_updates <= -1:
			for _x in range(absi(defer_window_updates)):
				f = f.call_deferred
	else:
		f = func ():
			print("window from position")
			var fpos := global_position
			if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
				fpos -= Vector2(window_adjusted_screen_rect.size) / 2
			var rect := window_adjusted_screen_rect
			rect.position = Vector2i(fpos.floor())
			window_adjusted_screen_rect = rect
			align()
			item_rect_changed.emit()
			set_deferred("_os_window_sized_instance", false)
		if defer_window_updates >= 1:
			for _x in range(absi(defer_window_updates)):
				f = f.call_deferred
	f.call()

func is_custom_grabbed() -> bool:
	return _is_custom_grabbed

func get_last_custom_grab_offset() -> Vector2i:
	return _custom_grab_offset

func start_custom_mouse_grab(window_cursor_offset:Vector2i) -> bool:
	if is_custom_grabbed():
		return false
	_is_custom_grabbed = true
	_custom_grab_offset = window_cursor_offset
	window_custom_grab_started.emit(window_cursor_offset)
	return true

func end_custom_mouse_grab() -> bool:
	if not is_custom_grabbed():
		return false
	_is_custom_grabbed = false
	window_custom_grab_finished.emit()
	return true

class _SpyglassListener extends Node:
	signal window_position_changed()

	var _last_position := Vector2i.ZERO

	func _notification(what: int) -> void:
		if not is_node_ready():
			return

		if what == NOTIFICATION_WM_POSITION_CHANGED:
			var pos := get_window().position
			if _last_position != pos:
				window_position_changed.emit()
				_last_position = pos
