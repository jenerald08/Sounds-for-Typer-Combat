extends Node2D

@export var boar_scene: PackedScene
@export var lava_boss_scene: PackedScene

# -------------------------
# Game stats
# -------------------------
var boar_kills: int = 0
var boss_kills: int = 0
var wave_level: int = 1
var duration: float = 0.0
var words_typed: int = 0
var current_enemy: Node = null

# -------------------------
# UI & Pause Menu
# -------------------------
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var pause_button: Button = $pause_button
# safe lookup for label/timer (node paths are relative to this script)
@onready var countdown_label: Label = get_node_or_null("CountdownLabel")
@onready var countdown_timer: Timer = get_node_or_null("CountdownTimer")
var is_game_paused: bool = false

# -------------------------
# Player ref
# -------------------------
@onready var player: Node = null
var typing_enabled: bool = false

# -------------------------
# Energy bar variables
# -------------------------
@onready var energy_bar: TextureProgressBar = $EnergyBar
var energy: float = 0.0
var max_energy: float = 100.0
var decay_rate: float = 7.6
var gain_per_letter: float = 4
var hold_time: float = 1.5
var hold_timer: float = 0.0
var is_holding: bool = false
var _pulse_time: float = 0.0
var _pulse_speed: float = 8.0

# -------------------------
# Countdown
# -------------------------
var countdown_time: int = 3
const DEFAULT_COUNTDOWN := 3

func _ready():
	# Stop persistent menu music (if any)
	var music = get_tree().root.find_node("MusicPlayer", true, false)
	if music and music is AudioStreamPlayer:
		music.stop()
		music.queue_free()
		return

	# Fallback: find any AudioStreamPlayer under root and stop the first one
	for child in get_tree().root.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
			break
				
	player = get_tree().get_first_node_in_group("player")

	# Ensure we have a Timer node to control the countdown.
	if not countdown_timer:
		countdown_timer = Timer.new()
		countdown_timer.name = "CountdownTimer"
		add_child(countdown_timer)
	# Configure Timer properties (safe even if it was placed in the scene)
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	countdown_timer.autostart = false

	# Connect the timeout safely (only once)
	if not countdown_timer.is_connected("timeout", Callable(self, "_on_countdown_tick")):
		countdown_timer.connect("timeout", Callable(self, "_on_countdown_tick"))

	# Connect pause button
	if pause_button and not pause_button.pressed.is_connected(_on_pause_button_pressed):
		pause_button.pressed.connect(_on_pause_button_pressed)

	# Start the countdown (or start immediately if there's no label)
	_start_countdown()


# -------------------------
# Countdown system (safe)
# -------------------------
func _start_countdown() -> void:
	# block typing while counting
	typing_enabled = false
	if player and player.has_method("set_typing_enabled"):
		player.set_typing_enabled(false)

	# reset time
	countdown_time = DEFAULT_COUNTDOWN

	# Update label if it exists; otherwise just start immediately
	if countdown_label:
		countdown_label.text = str(countdown_time)
		countdown_label.show()
		# start the countdown Timer
		countdown_timer.start()
	else:
		# If label missing, enable typing & spawn immediately to avoid blocking player
		typing_enabled = true
		if player and player.has_method("set_typing_enabled"):
			player.set_typing_enabled(true)
		spawn_boar()


func _on_countdown_tick() -> void:
	# Decrement
	countdown_time -= 1

	# Update UI safely
	if countdown_label:
		if countdown_time > 0:
			countdown_label.text = str(countdown_time)
		else:
			countdown_label.text = "GO!"

	# When finished:
	if countdown_time <= 0:
		# enable typing
		typing_enabled = true
		if player and player.has_method("set_typing_enabled"):
			player.set_typing_enabled(true)

		# spawn first enemy wave
		spawn_boar()

		# stop the countdown timer (do not queue_free the timer)
		if countdown_timer and countdown_timer.is_inside_tree():
			countdown_timer.stop()

		# hide the label after a short pause (await is safe)
		await get_tree().create_timer(1.0).timeout
		if countdown_label and countdown_label.is_inside_tree():
			countdown_label.hide()


# -------------------------
# Pause Menu
# -------------------------
func _on_pause_button_pressed() -> void:
	get_tree().paused = !get_tree().paused
	pause_menu.visible = get_tree().paused
	is_game_paused = get_tree().paused


# -------------------------
# Energy bar logic
# -------------------------
func _process(delta: float) -> void:
	duration += delta

	if is_holding:
		hold_timer -= delta
		_pulse_time += delta
		var pulse := (sin(_pulse_time * _pulse_speed) + 1.0) / 2.0
		energy_bar.modulate = Color(1.0, 1.0, 0.3 + 0.7 * pulse, 1.0)
		if hold_timer <= 0.0:
			is_holding = false
			_pulse_time = 0.0
			energy_bar.modulate = Color(1, 1, 1, 1)
	else:
		if energy > 0.0:
			energy -= decay_rate * delta
			if energy < 0.0:
				energy = 0.0

	_update_energy_bar()


func add_energy() -> void:
	if not is_holding:
		energy += gain_per_letter
		if energy >= max_energy:
			energy = max_energy
			is_holding = true
			hold_timer = hold_time
	_update_energy_bar()


func _update_energy_bar() -> void:
	if energy_bar:
		energy_bar.value = energy


func is_energy_full() -> bool:
	return energy >= max_energy


# -------------------------
# Enemy Spawning
# -------------------------
func spawn_boar(ui_active: bool = true) -> void:
	if boar_kills >= 5:
		spawn_lava_boss()
		return

	var boar = boar_scene.instantiate()
	boar.max_armor += (wave_level - 1) * 50
	boar.ui_active = ui_active

	if ui_active:
		boar.add_to_group("boar_active")
	else:
		boar.add_to_group("boar_hidden")

	call_deferred("add_child", boar)
	boar.set_deferred("global_position", Vector2(1250, 350))

	if ui_active:
		current_enemy = boar

	if not boar.is_connected("armor_broken", Callable(self, "_on_boar_armor_broken")):
		boar.connect("armor_broken", Callable(self, "_on_boar_armor_broken"))
	if boar.has_signal("died") and not boar.is_connected("died", Callable(self, "_on_boar_died")):
		boar.connect("died", Callable(self, "_on_boar_died"))


func spawn_lava_boss() -> void:
	var boss = lava_boss_scene.instantiate()
	boss.max_armor += (wave_level - 1) * 100

	call_deferred("add_child", boss)
	boss.set_deferred("global_position", Vector2(1250, 85))
	current_enemy = boss
	print("🔥 Lava Boss spawned!")

	if boss.has_signal("died") and not boss.is_connected("died", Callable(self, "_on_boss_died")):
		boss.connect("died", Callable(self, "_on_boss_died"))


# -------------------------
# Signal Handlers
# -------------------------
func _on_boar_armor_broken() -> void:
	if boar_kills < 10:
		spawn_boar(false)
	else:
		spawn_lava_boss()


func _on_boar_died() -> void:
	boar_kills += 1
	print("Boar killed:", boar_kills)
	if player and player.has_method("increment_boar_kills"):
		player.increment_boar_kills()

	if boar_kills < 10:
		var hidden_boars := get_tree().get_nodes_in_group("boar_hidden")
		if hidden_boars.size() > 0:
			var next_boar := hidden_boars[0]
			next_boar.remove_from_group("boar_hidden")
			next_boar.add_to_group("boar_active")
			if next_boar.has_method("activate_ui"):
				next_boar.activate_ui()
			else:
				next_boar.ui_active = true
				if next_boar.has_method("_update_ui_visibility"):
					next_boar.call_deferred("_update_ui_visibility")
			current_enemy = next_boar
	else:
		spawn_lava_boss()


func _on_boss_died() -> void:
	boss_kills += 1
	print("Boss killed:", boss_kills)
	if player and player.has_method("increment_boss_kills"):
		player.increment_boss_kills()
	wave_level += 1
	boar_kills = 0
	spawn_boar(true)


# -------------------------
# Force enemy idle
# -------------------------
func set_enemy_idle() -> void:
	if current_enemy and current_enemy.is_inside_tree():
		if current_enemy.has_node("AnimatedSprite2D"):
			current_enemy.get_node("AnimatedSprite2D").play("idle")
		elif current_enemy.has_node("AnimationPlayer"):
			var anim_player = current_enemy.get_node("AnimationPlayer")
			if anim_player.has_animation("idle"):
				anim_player.play("idle")

		current_enemy.set_process(false)
		current_enemy.set_physics_process(false)
