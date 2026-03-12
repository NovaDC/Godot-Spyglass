## Written by NovaDC

class_name PerfectPoint

## PerfectPoint
##
## A external Godot library that supplies static functions that give transforms to and from various canvas items,
## as well as various other helper utilities.[br]
## Used primarily for the [Spyglass] addon.

## Gets a transform for a given [param target] [CanvasItem] in metascreen (virtual screen) space.
static func get_true_metascreen_transform(target:CanvasItem) -> Transform2D:
	var w := target.get_window()
	return get_true_window_transform(target, w).translated(w.position)
## Gets a inverse transform for a given [param target] [CanvasItem] in metascreen (virtual screen) space.
static func get_true_metascreen_inverse_transform(target:CanvasItem) -> Transform2D:
	var w := target.get_window()
	return get_true_window_inverse_transform(target, w).translated_local(-w.position)
## Gets the metascreen (virtual screen) position of a given [param target] [CanvasItem].
static func get_global_metascreen_position(target:CanvasItem) -> Vector2:
	return get_true_metascreen_transform(target).origin
## Sets the metascreen (virtual screen) position of a given [param target] [CanvasItem].
static func set_global_metascreen_position(target:CanvasItem, scr_position:Vector2):
	target.global_position = get_true_metascreen_inverse_transform(target) * scr_position

## Gets a transform for a given [param target] [CanvasItem] in screen space for the given [param screen_index].
static func get_true_screen_transform(target:CanvasItem, screen_index:int) -> Transform2D:
	return get_true_metascreen_transform(target) * get_screen_metascreen_transform(screen_index)
## Gets a inverse transform for a given [param target] [CanvasItem] in screen space for the given [param screen_index].
static func get_true_screen_inverse_transform(target:CanvasItem, screen_index:int) -> Transform2D:
	return get_true_metascreen_inverse_transform(target) * get_screen_metascreen_inverse_transform(screen_index)
## Gets the screen (for the given [param screen_index]) position of a given [param target] [CanvasItem].
static func get_global_screen_position(target:CanvasItem, screen_index:int) -> Vector2:
	return get_true_screen_transform(target, screen_index).origin
## Sets the screen (for the given [param screen_index]) position of a given [param target] [CanvasItem].
static func set_global_screen_position(target:CanvasItem, scr_position:Vector2, screen_index:int):
	target.global_position = get_true_screen_inverse_transform(target, screen_index) * scr_position

## Gets a transform for a given [param target] [CanvasItem] in window space for the given [param window].
## Leaving [param window] [code]null[/code] will have the target window be whatever the window [param target] is in.
static func get_true_window_transform(target:CanvasItem, window:Window = null) -> Transform2D:
	if window == null:
		window = target.get_window()
	return (window.get_final_transform() * target.get_global_transform_with_canvas())
## Gets a inverse transform for a given [param target] [CanvasItem] in window space for the given [param window].
## Leaving [param window] [code]null[/code] will have the target window be whatever the window [param target] is in.
static func get_true_window_inverse_transform(target:CanvasItem, window:Window = null) -> Transform2D:
	if window == null:
		window = target.get_window()
	return (window.get_final_transform() * target.get_canvas_transform()).affine_inverse()
## Gets the position of a given [param target] [CanvasItem] in the given [param window].
## Leaving [param window] [code]null[/code] will have the target window be whatever the window [param target] is in.
static func get_global_window_position(target:CanvasItem, window:Window = null) -> Vector2:
	return get_true_window_transform(target, window).origin
## Sets the position of a given [param target] [CanvasItem] in the given [param window].
## Leaving [param window] [code]null[/code] will have the target window be whatever the window [param target] is in.
static func set_global_window_position(target:CanvasItem, win_position:Vector2, window:Window = null):
	target.global_position = get_true_window_inverse_transform(target, window) * win_position

## Returns the given screen id's transform in the virtual screen space.
static func get_screen_metascreen_transform(screen_id:int) -> Transform2D:
	return Transform2D(0, DisplayServer.screen_get_position(screen_id))
## Returns the given screen id's inverse transform in the virtual screen space.
static func get_screen_metascreen_inverse_transform(screen_id:int) -> Transform2D:
	return Transform2D(0, DisplayServer.screen_get_position(screen_id)).affine_inverse()

## Returns a [Rect2] that encloses all of the given [param rects].[br]
## Contrary to it's name, [param rects] can contain [Rect2] as well as [Rect2i]s,
## [Vector2]s, and [Vector2i]s.
## It may also be a [PackedVector2Array].
## Any other provided types (including their 3d counterparts), will be ignored.
static func enclosing_rect(rects:Variant) -> Rect2:
	var ret := Rect2()
	if typeof(rects) not in [TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY]:
		return ret
	for rect in rects:
		match (typeof(rect)):
			TYPE_RECT2, TYPE_RECT2I:
				ret = ret.expand(Vector2(rect.position))
				ret = ret.expand(Vector2(rect.end))
			TYPE_VECTOR2, TYPE_VECTOR2I:
				ret = ret.expand(Vector2(rect))
	return ret


## Gets a single [Rect2] for all recursively all child [Control]s,
## such that the rect encloses all the [Control]s in global space.
## The [param parent] will not be included in this rect.
static func control_get_recursive_enclosing_rect(parent:Node, owned := false) -> Rect2:
	var children := parent.find_children("*", "Control", true, owned)
	return enclosing_rect(children.map(func(x:Control): return x.get_global_rect()))

## Gets a single [Rect2] for all recursively all child [Node2D]s,
## such that the rect encloses all the [Line2D]s, [TileMapLayer]s, [TimeMap]s,
## [Sprite2D]s, and [Polygon2D]s in global space.
## [AnimatedSprite2D]s are not currently supported.
## The [param parent] will not be included in this rect.
static func node2d_get_recursive_enclosing_rect(parent:Node, owned:=false) -> Rect2:
	var parts:Array[Variant] = []

	for sprite in parent.find_children("*", "Sprite2D", true, owned):
		parts.append(sprite.to_global(sprite.get_rect().position))
		parts.append(sprite.to_global(sprite.get_rect().end))

	for polygon in parent.find_children("*", "Polygon2D", true, owned):
		var poly_points:Array[Vector2] = Array(polygon.polygon)
		poly_points = poly_points.map(polygon.to_global)
		parts.append_array(poly_points)

	for line in parent.find_children("*", "Line2D", true, owned):
		var points:Array[Vector2] = Array(line.points)
		points = points.map(line.to_global)
		parts.append_array(points)

	for map in (parent.find_children("*", "TileMapLayer", true, owned) +
				parent.find_children("*", "TileMap", true, owned)
				):
		var used:Rect2i = map.get_used_rect()
		parts.append(map.to_global(map.map_to_local(used.position)))
		parts.append(map.to_global(map.map_to_local(used.end)))

	return enclosing_rect(parts)

## Gets a single [Rect2] for all recursively all child [Nodes]s,
## such that the rect encloses all the [Control]s, [Sprite2D]s, and [Polygon2D]s in canvas space.
## The [param parent] will be ignored.
## See [control_get_recursive_enclosing_rect] and [node2d_get_recursive_enclosing_rect]
static func canvas_item_get_recursive_enclosing_rect(parent:Node, owned := false) -> Rect2:
	return enclosing_rect([node2d_get_recursive_enclosing_rect(parent, owned),
							control_get_recursive_enclosing_rect(parent, owned)
							])
