extends Control

@onready var choices_label = $ChoicesLabel
@onready var start_button = $Start_Test
@onready var time_option = $Time_Option
# Called when the node enters the scene tree for the first time.
func _ready():
	
	   # Connect signals
	choices_label.connect("meta_clicked", Callable(self, "_on_choice_clicked"))
	start_button.connect("pressed", Callable(self, "_on_start_test_pressed"))
	
	
	$ChoicesLabel.bbcode_text = """
	1. [url=choice1]The quick brown fox jumps over the lazy dog.[/url]
	2. [url=choice2]Typing improves speed and accuracy over time.[/url]
	3. [url=choice3]Practice makes perfect when learning to type fast.[/url]
	4. [url=choice4]Keep your fingers on the home row to type better.[/url]
	5. [url=choice5]Mistakes are okay, just keep improving![/url]
	6. [url=choice6]Typing games make learning more fun and engaging.[/url]
	"""
	
func _on_choice_clicked(meta):
	Global.selected_text = str(meta)
	print("Selected:", Global.selected_text)
	match meta:
		"choice1":
			Global.selected_text = "The quick brown fox jumps over the lazy dog."
		"choice2":
			Global.selected_text = "Typing improves speed and accuracy over time."
		"choice3":
			Global.selected_text = "Practice makes perfect when learning to type fast."
		"choice4":
			Global.selected_text = "Keep your fingers on the home row to type better."
		"choice5":
			Global.selected_text = "Mistakes are okay, just keep improving!"
		"choice6":
			Global.selected_text = "Typing games make learning more fun and engaging."

			print("Saved choice:", Global.selected_text)
			
func _on_start_test_pressed():
	if Global.selected_text == "":
		print("Please select a sentence.")
		return
		
		# Get the selected time from OptionButton
	var selected_index = time_option.get_selected_id()
	Global.selected_time = selected_index
	print("Selected time (seconds):", Global.selected_time)
	get_tree().change_scene_to_file("res://scenes/Typing_test_scene/Typing_test.tscn")



func _on_start_test_button_pressed() -> void:
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main_menu_scenes/Second_Main_menu.tscn")
