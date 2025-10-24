extends Control

@onready var result_label = $ResultLabel

func _ready():
	
	var result = Global.result_data
	var correct = result["correct_words"]
	var incorrect = result["incorrect_words"]
	var time = result["total_time"]
	var wpm = result["wpm"]
	var accuracy = result["accuracy"]

	result_label.text = "Correct Words: %d\nIncorrect Words: %d\nTime: %d seconds\nWPM: %.2f\nAccuracy: %.2f%%" % [correct, incorrect, time, wpm, accuracy]
	


func _on_back_to_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Typing_test_scene/Text_Selection.tscn")
