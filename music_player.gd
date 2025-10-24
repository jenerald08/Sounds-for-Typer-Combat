# music_player.gd
extends AudioStreamPlayer

func _ready() -> void:
	# Prevent duplicates across scenes
	var tree := get_tree()
	if tree.has_meta("menu_music_playing"):
		queue_free()
		return

	tree.set_meta("menu_music_playing", true)
	play()

	# Reparent safely after the scene finishes loading
	await get_tree().process_frame
	_make_persistent()


func _make_persistent() -> void:
	# Only continue if we're still in the tree
	if !is_inside_tree():
		return

	var root := get_tree().root
	var parent_node := get_parent()

	# Safely remove and re-add
	if parent_node and parent_node != root:
		parent_node.remove_child(self)
		root.add_child(self)
		owner = null  # Prevent freeing on scene change
