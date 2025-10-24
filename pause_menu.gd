extends CanvasLayer

# NOTE: If you connected the buttons in the editor, DO NOT connect them again in code.
func _ready() -> void:
	# Make this CanvasLayer keep processing when the SceneTree is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Start hidden
	visible = false

# These functions should be connected from the Editor (Node -> Signals -> pressed())
func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	visible = false

func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main_menu_scenes/Second_Main_menu.tscn")
