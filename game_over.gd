extends CanvasLayer

@onready var retry_button: Button = $VBoxContainer/retry_button
@onready var quit_button: Button = $VBoxContainer/quit_button
@onready var result_button: Button = $VBoxContainer/result_button
@onready var scoreboard: Panel = $ScoreBoard
@onready var close_button: Button = $ScoreBoard/VBoxContainer/close_button

@onready var boar_kills_label: Label = $ScoreBoard/VBoxContainer/boar_kills_label
@onready var boss_kills_label: Label = $ScoreBoard/VBoxContainer/boss_kills_label
@onready var words_typed_label: Label = $ScoreBoard/VBoxContainer/words_typed_label
@onready var time_label: Label = $ScoreBoard/VBoxContainer/time_label

# Stats (set before showing GameOver)
var boar_kills: int = 0
var boss_kills: int = 0
var words_typed: int = 0
var duration: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Retry button
	if retry_button:
		if retry_button.pressed.is_connected(_on_retry_button_pressed):
			retry_button.pressed.disconnect(_on_retry_button_pressed)
		retry_button.pressed.connect(_on_retry_button_pressed)

	# Quit button
	if quit_button:
		if quit_button.pressed.is_connected(_on_quit_button_pressed):
			quit_button.pressed.disconnect(_on_quit_button_pressed)
		quit_button.pressed.connect(_on_quit_button_pressed)

	# Result button
	if result_button:
		if result_button.pressed.is_connected(_on_result_button_pressed):
			result_button.pressed.disconnect(_on_result_button_pressed)
		result_button.pressed.connect(_on_result_button_pressed)

	# Close button
	if close_button:
		if close_button.pressed.is_connected(_on_close_button_pressed):
			close_button.pressed.disconnect(_on_close_button_pressed)
		close_button.pressed.connect(_on_close_button_pressed)

	# Hide scoreboard at start
	scoreboard.visible = false


func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	
	# Free the game over scene itself
	self.queue_free()  



func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main_menu_scenes/Second_Main_menu.tscn")
	self.queue_free()
	
func _on_result_button_pressed() -> void:
	_update_scoreboard()
	scoreboard.visible = true

func _on_close_button_pressed() -> void:
	scoreboard.visible = false

func set_stats(boars: int, bosses: int, words: int, time_sec: float) -> void:
	boar_kills = boars
	boss_kills = bosses
	words_typed = words
	duration = time_sec

		# Update scoreboard immediately
	_update_scoreboard()



func _update_scoreboard() -> void:
	if boar_kills_label: boar_kills_label.text = "Boars killed: %d" % boar_kills
	if boss_kills_label: boss_kills_label.text = "Bosses killed: %d" % boss_kills
	if words_typed_label: words_typed_label.text = "Words typed: %d" % words_typed
	if time_label: time_label.text = "Time: %.1f sec" % duration
