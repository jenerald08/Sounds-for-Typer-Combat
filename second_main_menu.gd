extends Node

func _on_typing_test_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Typing_test_scene/Text_Selection.tscn")


func _on_single_player_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Single_Player_scene/Single_Player.tscn")


func _on_back_button_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/Main_menu_scenes/Main_menu.tscn")
