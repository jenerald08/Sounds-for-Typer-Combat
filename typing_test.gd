extends Node

@onready var typing_label = $TypingLabel
@onready var typing_input = $TypingInput
@onready var timer_label = $TimerLabel
@onready var countdown_timer = $CountdownTimer
@onready var view_result_button = $ViewResultButton


var lock_index := 0
var backspace_triggered := false
var locked_text := ""
var current_word_index := 0
var prompt_text := ""
var time_left := 0
var timer_started := false
var time_taken := 0.0

func _ready():
	if get_tree().has_meta("menu_music_playing"):
		get_tree().set_meta("menu_music_playing", false)
		var music = get_tree().root.find_node("MusicPlayer", true, false)
		if music:
			music.stop()
			music.queue_free()
	
	prompt_text = Global.selected_text.strip_edges()
	typing_label.bbcode_enabled = true
	typing_input.text = ""
	typing_input.editable = true
	typing_input.connect("text_changed", Callable(self, "_on_typing_input_text_changed"))
	
	time_left = Global.selected_time
	update_timer_label()

	countdown_timer.wait_time = 1.0
	countdown_timer.connect("timeout", Callable(self, "_on_timer_timeout"))

	update_colored_prompt("")  # Initial prompt display

func _on_typing_input_text_changed():
	var user_input = typing_input.text

	# Start the timer once
	if not timer_started:
		countdown_timer.start()
		timer_started = true
		print("Timer started!")

	var typed_words = user_input.strip_edges().split(" ", false)
	var prompt_words = prompt_text.split(" ")

	# Handle spacebar press: lock input up to this point
	if user_input.ends_with(" "):
		if current_word_index < typed_words.size():
			var typed_word = typed_words[current_word_index].strip_edges()
			if typed_word.length() > 0:
				current_word_index += 1
				lock_index = typing_input.text.length()
				locked_text = typing_input.text  # Save locked portion
			print("Lock index updated to:", lock_index)

	# Prevent deleting locked input
	if Input.is_key_pressed(KEY_BACKSPACE) and typing_input.text.length() < lock_index:
		# Restore locked part of the input
		typing_input.text = locked_text
		typing_input.set_caret_column(lock_index)
		return

	# Prevent moving caret before locked area
	var cursor_column = typing_input.get_caret_column()
	if cursor_column < lock_index:
		typing_input.set_caret_column(lock_index)

	update_colored_prompt(user_input)

	# ✅ New finish condition — based on letter count of last word
	if typed_words.size() == prompt_words.size():
		var last_typed = typed_words[-1] if typed_words.size() > 0 else ""
		var last_prompt = prompt_words[-1]

		# If last typed word length >= prompt last word length → finish
		if last_typed.length() >= last_prompt.length():
			if timer_started:
				countdown_timer.stop()
				timer_started = false
				typing_input.editable = false
				print("Typing finished before time!")
				view_result_button.visible = true



func update_colored_prompt(_user_input: String):
	var prompt_words = prompt_text.split(" ")
	var display_words: Array = []

	for i in range(prompt_words.size()):
		var word = prompt_words[i]
		if i < current_word_index:
			display_words.append("[color=green]" + word + "[/color]")
		elif i == current_word_index:
			display_words.append("[color=red]" + word + "[/color]")
		else:
			display_words.append(word)

	typing_label.bbcode_text = " ".join(display_words)

func _on_timer_timeout():
	time_left -= 1
	update_timer_label()

	if time_left <= 0:
		countdown_timer.stop()
		typing_input.editable = false
		print("Time is up!")
		view_result_button.visible = true

func update_timer_label():
	var minutes = int(time_left / 60)
	var seconds = time_left % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_view_result_button_pressed():
	go_to_result()

func go_to_result():
	var user_input = typing_input.text.strip_edges()
	var prompt_words = prompt_text.split(" ")
	var input_words = user_input.split(" ")

	var correct = 0
	var incorrect = 0
	for i in range(min(prompt_words.size(), input_words.size())):
		if prompt_words[i].to_lower() == input_words[i].to_lower():
			correct += 1
		else:
			incorrect += 1

	var total_time_minutes = float(Global.selected_time - time_left) / 60.0
	var wpm = correct / total_time_minutes if total_time_minutes > 0 else 0.0

	var total_typed = correct + incorrect
	var accuracy = float(correct) / total_typed * 100.0 if total_typed > 0 else 0.0

	Global.result_data = {
		"correct_words": correct,
		"incorrect_words": incorrect,
		"total_time": Global.selected_time - time_left,
		"wpm": wpm,
		"accuracy": accuracy
	}
	get_tree().change_scene_to_file("res://scenes/Typing_test_scene/Typing_test_result.tscn")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Typing_test_scene/Text_Selection.tscn")
