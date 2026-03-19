@tool
extends EditorPlugin

## The name of this plugin.
const PLUGIN_NAME := "Spyglass"

## The icon of this plugin.
const PLUGIN_ICON:Texture2D = preload("./icon.svg")

const _ENSURE_SCRIPT_DOCS:Array[Script] = [
    preload("./spyglass.gd")
]

# Every once ands a while the script docs simply refuse to update properly.
# This nudges the docs into a ensuring that the important scripts added by
# this addon are actually loaded.
func _ensure_script_docs() -> void:
	var edit := EditorInterface.get_script_editor()
	for scr in _ENSURE_SCRIPT_DOCS:
		edit.update_docs_from_script(scr)

func _get_plugin_name() -> String:
	return PLUGIN_NAME

func _get_plugin_icon() -> Texture2D:
	return PLUGIN_ICON
