extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var frames: SpriteFrames = anim.sprite_frames
@onready var slash_scene = preload("res://scenes/Single_Player_scene/slash_projectile.tscn")

# --- Player health ---
@export var max_health: int = 100
var current_health: int = max_health
@onready var player_health_bar: TextureProgressBar = $"../HUD/MarginContainer/PlayerHealthBar"

# --- Extra Word for Slash Projectile ---
@onready var extra_word_label: RichTextLabel = $"../ExtraWordLabel"
var extra_words = ["slash", "cut", "blade", "strike", "Edge", "Storm", "flame", "knight", "Dragon", "Sword",
 "Horizon", "Ember", "Velocity", "Serene", "Forge", "Zenith", "Crystal", "Torrent", "Solace", "Valor", "Radiant", "Eclipse",
 "Haven", "Heaven", "Jesus", "Whisper", "Catalyst", "Mirage", "Triumph", "Obsidian", "Vortex", "Legacy", "Tempest", "Aurora", "Eternity",
 "Sanctum", "Mythic", "Celestial", "Ethereal", "Dominion", "Aegis", "Arcane", "Genesis", "Nebula", "Luminous", "Elysium", "Onyx", "Elysium", "Specter"]
var extra_word: String = ""
var extra_typed_progress: int = 0
var extra_mistake: bool = false
var typing_enabled: bool = false
# At the top, after your variables

# Reference to the main Single_Player scene (used to update global stats)
var main_scene: Node = null

# Attack flags
var attack_active := false
var attack_queued := false
var is_dead: bool = false

# Player stats
var boar_kills: int = 0
var boss_kills: int = 0
var words_typed: int = 0
var duration: float = 0.0

const GAME_OVER_SCENE := preload("res://scenes/Single_Player_scene/game_over.tscn")
@export var attack_knockback_strength: float = 400.0

func _ready():
	# Reference to main scene (put Single_Player in group "single_player")
	main_scene = get_tree().get_first_node_in_group("single_player")
	print("Player ready! main_scene:", main_scene)

	# Animation setup
	if frames:
		if frames.has_animation("attack"):
			frames.set_animation_loop("attack", false)
		if frames.has_animation("idle"):
			frames.set_animation_loop("idle", true)
		if frames.has_animation("damaged"):
			frames.set_animation_loop("damaged", false)
		if frames.has_animation("death"):
			frames.set_animation_loop("death", false)

	if anim and frames and frames.has_animation("idle"):
		anim.play("idle")
	if anim:
		anim.connect("animation_finished", Callable(self, "_on_anim_finished"))

	# Initialize extra word
	extra_word = get_random_extra_word()
	update_extra_word_label()

	if player_health_bar:
		player_health_bar.max_value = max_health
		player_health_bar.value = current_health

func set_typing_enabled(value: bool) -> void:
	typing_enabled = value

func _process(delta: float) -> void:
	# Update duration
	if not is_dead:
		duration += delta

func _input(event):
	if is_dead:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		var u = int(event.unicode)
		if (u >= 65 and u <= 90) or (u >= 97 and u <= 122):
			var letter = char(event.unicode)

			# --- Attack animation ---
			if attack_active:
				attack_queued = true
			else:
				perform_attack()

			# --- Enemy typing logic ---
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if enemy.has_method("check_input"):
					# Skip enemies with armor
					if enemy.has_method("has_armor") and enemy.has_armor():
						continue

					var correct = enemy.check_input(letter)
					if correct:
						# Spawn slash projectile
						spawn_slash_projectile()
						
						# Apply knockback if available
						if enemy.has_method("apply_knockback"):
							var dir = (enemy.global_position - global_position)
							dir.y = 0
							dir = dir.normalized()
							enemy.apply_knockback(dir * attack_knockback_strength)

			# --- Extra word logic ---
			check_extra_input(letter)



# --- Extra word functions ---
func update_extra_word_label() -> void:
	if not extra_word_label:
		return

	extra_word_label.clear()

	if extra_typed_progress > 0:
		extra_word_label.push_color(Color.CYAN)
		extra_word_label.append_text(extra_word.substr(0, extra_typed_progress))
		extra_word_label.pop()

	if extra_typed_progress < extra_word.length():
		if extra_mistake:
			extra_word_label.push_color(Color.RED)
			extra_word_label.append_text(extra_word[extra_typed_progress])
			extra_word_label.pop()
			if extra_typed_progress + 1 < extra_word.length():
				extra_word_label.append_text(extra_word.substr(extra_typed_progress + 1))
		else:
			extra_word_label.append_text(extra_word.substr(extra_typed_progress))

func check_extra_input(letter: String) -> void:
	if not typing_enabled:
		return  # 🚫 ignore input until countdown finishes
	if extra_typed_progress < extra_word.length():
		var target = extra_word.substr(extra_typed_progress, 1)
		if letter == target:
			extra_mistake = false
			extra_typed_progress += 1

			var sp = get_tree().current_scene
			if sp and sp.has_method("add_energy"):
				sp.add_energy()

			spawn_slash_projectile()

			if extra_typed_progress >= extra_word.length():
				words_typed += 1
				extra_typed_progress = 0
				extra_word = get_random_extra_word()
		else:
			extra_mistake = true

	update_extra_word_label()

func get_random_extra_word() -> String:
	return extra_words[randi() % extra_words.size()]

func spawn_slash_projectile():
	if is_dead:
		return
	
	var slash = slash_scene.instantiate()
	get_parent().add_child(slash)

	var dir = Vector2.RIGHT
	if anim.flip_h:
		dir = Vector2.LEFT

	var slash_offset = Vector2(-450, -350)
	if anim.flip_h:
		slash_offset = Vector2(-40, -20)

	slash.global_position = global_position + slash_offset
	slash.direction = dir

# --- Attack ---
func perform_attack():
	if is_dead or not anim:
		return
	attack_active = true
	attack_queued = false
	call_deferred("_play_attack_anim")

func _play_attack_anim() -> void:
	if not anim:
		return
	if frames and frames.has_animation("attack"):
		frames.set_animation_loop("attack", false)
	anim.stop()
	anim.play("attack")
	anim.frame = 0

func take_damage(amount: int = 3) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	if player_health_bar:
		player_health_bar.value = current_health

	if current_health <= 0:
		die()
	else:
		# Don't interrupt an active attack animation.
		# If the player is attacking, defer showing "damaged" until the attack animation ends.
		if not attack_active:
			if anim and frames and frames.has_animation("damaged"):
				anim.play("damaged")
		else:
			# Optional: remember we were damaged while attacking and show "damaged" after attack finishes
			# (uncomment if you want this behavior)
			# damaged_queued = true
			pass


func die():
	if not anim or current_health > 0:
		return
	is_dead = true
	set_process_input(false)
	velocity = Vector2.ZERO
	if $CollisionShape2D:
		$CollisionShape2D.set_deferred("disabled", true)

	var sp = get_tree().get_root().get_node_or_null("Single_Player")
	if sp and sp.has_method("set_enemy_idle"):
		sp.set_enemy_idle()

	if frames and frames.has_animation("death"):
		anim.stop()
		anim.play("death")
	else:
		queue_free()

var game_over_instance: Node = null

func _show_game_over_and_cleanup() -> void:
	if game_over_instance:
		game_over_instance.queue_free()  # remove old one if somehow exists

	game_over_instance = GAME_OVER_SCENE.instantiate()
	# Pass stats
	game_over_instance.set_stats(boar_kills, boss_kills, words_typed, duration)
	get_tree().root.add_child(game_over_instance)
	queue_free()

# Add these methods
func increment_boar_kills():
	boar_kills += 1
	words_typed += 1   # optional: count full word typed
	print("Player boar_kills:", boar_kills)

func increment_boss_kills():
	boss_kills += 1
	words_typed += 1
	print("Player boss_kills:", boss_kills)

func _on_anim_finished():
	if anim.animation == "attack":
		attack_active = false
		if attack_queued:
			call_deferred("perform_attack")
		else:
			if frames and frames.has_animation("idle") and not is_dead:
				anim.play("idle")
	elif anim.animation == "damaged":
		if frames and frames.has_animation("idle"):
			anim.play("idle")
	elif anim.animation == "death":
		var sp = get_tree().get_root().get_node_or_null("Single_Player")
		if sp and sp.has_method("set_enemy_idle"):
			sp.set_enemy_idle()
		call_deferred("_show_game_over_and_cleanup")
