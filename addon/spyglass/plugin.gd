@tool
extends EditorPlugin

const PLUGIN_NAME := "Spyglass"

const PLUGIN_ICON := preload("res://addon/spyglass/spyglass.svg")

func _get_plugin_name() -> String:
	return PLUGIN_NAME

func _get_plugin_icon() -> Texture2D:
	return PLUGIN_ICON
