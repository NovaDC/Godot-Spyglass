# Godot-Spyglass

> Maps a `Window` accurately into 2D world space, with full control both ways.

![The Spyglass icon](./icon.png "Icon")

A `Camera2D` inheriting node that allows for an attached `Window` node to have it's screen position and size corelate exactly to this node's `global_position` and camera size.

This supports both embedded and native windows, and allows for the screen offsets to be relative to the virtual screen space or the `SceneTree.root`.
This also ensures that the positioning and resizing of the window works both ways, allowing for full use of the native OS's window handles.

Due to heavy implementation changes introduced in Godot-Spyglass v2, Godot-Spyglass v2 is not backward compatible with Godot-Spyglass v1.

## Usage notes

- Since the `frame_window` shares the same `World2D` as this node,
additional efforts must be taken to ensure child nodes of the `frame_window` *don't* appear in the `SceneTree.root` or other viewports, such as using `CanvasLayer` nodes or different rendering layers to do this instead.
- As this inherits from (and is a type of) `Camera2D`, at least one other (properly enabled) `Camera2D` should exist in the tree to ensure that the `SceneTree.root` `Window` does not also display the view from this as a camera.
- Due to some native OS's window snapping routines, using a `anchor_mode` besides `ANCHOR_MODE_FIXED_TOP_LEFT` may result in jittering and disjoining the position from global space when resizing the window.
- Due to the rendering order of `Window` nodes, a spyglass with a native window, when moved via the window itself (as opposed to moving this spyglass in world-space), may show the view from its new world position only after the window itself is moved. This will likely be seen as a jittering effect when the window is moved at a moderate speed. To add or remove a manual delay for window-to-world or world-to-window updates, see `defer_window_updates`.
- Disabling `ignore_rotation` for this node will likely cause visual issues.
