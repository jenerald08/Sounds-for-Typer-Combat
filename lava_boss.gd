extends CharacterBody2D

signal armor_broken  # ✅ new signal to notify spawner
signal died


@export var faces_right: bool = true
@export var speed: float = 80.0
@export var attack_range: float = 120.0
@export var max_armor: int = 150

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var word_label: RichTextLabel = $WordLabel
@onready var armor_bar: TextureProgressBar = $ArmorBar
@onready var collision: CollisionShape2D = $CollisionShape2D
@export var stun_duration: float = 2.0  # seconds the boss stays stunned
var stun_timer: float = 0.0
# Damage amount boss deals to player
@export var attack_damage: int = 10

var player: Node2D

# State
var state: String = "walk"   # "walk", "attack", "stunned", "dead"
var armor: int

# 🔥 Base pool of words
var boss_word_pool = ["Supercalifragilisticexpialidocious", "Pseudopseudohypoparathyroidism", "Floccinaucinihilipilification", "Antidisestablishmentarianism", "Honorificabilitudinitatibus", "Incomprehensibilities", "Uncharacteristically", "Counterdemonstrations"]
static var boss_words_remaining: Array = []
# Typing (enabled only when armor == 0)
var word: String = "inferno"
var typed_progress: int = 0
var mistake: bool = false
var armor_already_broken: bool = false   # ✅ prevent multiple emits

func assign_unique_word() -> void:
	# Refill & shuffle if empty
	if boss_words_remaining.is_empty():
		boss_words_remaining = boss_word_pool.duplicate()
		boss_words_remaining.shuffle()

	# Take one word
	word = boss_words_remaining.pop_front()   # ✅ assign to the class property, not a local variable
	word_label.text = ""   # ❌ hide word initially
	typed_progress = 0
	mistake = false
	_update_word_label()

func _ready() -> void:
	randomize()
	assign_unique_word()
	# Ensure this boss can be hit by your projectile filter
	add_to_group("enemy")

	player = get_tree().get_first_node_in_group("player")

	# Armor UI
	armor = max_armor
	if armor_bar:
		armor_bar.max_value = max_armor
		armor_bar.value = armor
		armor_bar.show()
		armor_bar.position = Vector2(-armor_bar.size.x / 1.5, 15)

	# Start anim
	if anim:
		_play_if_exists("walking")

	# Prepare word label (typing is gated by armor)
	_update_word_label()

	# Handle animation finished (e.g. death, attack end)
	if anim and not anim.is_connected("animation_finished", Callable(self, "_on_anim_finished")):
		anim.connect("animation_finished", Callable(self, "_on_anim_finished"))

	# Handle frame changes (for attack damage sync)
	if anim and not anim.is_connected("frame_changed", Callable(self, "_on_anim_frame_changed")):
		anim.connect("frame_changed", Callable(self, "_on_anim_frame_changed"))

# Called whenever animation frame changes
func _on_anim_frame_changed() -> void:
	if state == "attack" and anim.animation == "attack":
		if anim.frame == 3 or anim.frame == 6:
			_deal_damage_to_player()
			
func _deal_damage_to_player() -> void:
	if player and state == "attack":
		# Assuming your player has a `take_damage(amount)` function
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)


func _physics_process(delta: float) -> void:
	if not player:
		return

	match state:
		"dead":
			velocity = Vector2.ZERO
			move_and_slide()
			return

		"stunned":
			velocity = Vector2.ZERO
			_play_if_exists("stunned")
			stun_timer -= delta
			if stun_timer <= 0.0:
				# When stun ends, decide if we attack or walk
				if player and player_in_range:
					state = "attack"
					_play_if_exists("attack")
				else:
					state = "walk"
					_play_if_exists("walking")
			move_and_slide()
			return

		"attack":
			# During attack we don’t walk; animation callback returns us to walk
			velocity = Vector2.ZERO
			move_and_slide()
			return

		"walk":
			var to_player := player.global_position - global_position
			var dist := to_player.length()
			var dir := to_player.normalized() if dist > 0.0 else Vector2.ZERO

			# face player
			if anim and dir.x != 0.0:
				anim.flip_h = dir.x > 0.0 if faces_right else dir.x < 0.0

			# ✅ if in attack range → switch to attack, else move at full speed
			if dist > attack_range:
				velocity = dir * speed   # full constant speed
				_play_if_exists("walking")
			else:
				state = "attack"
				velocity = Vector2.ZERO
				_play_if_exists("attack")

			move_and_slide()

# -----------------------------
# Projectile / armor handling
# -----------------------------
# Aligns with slash_projectile.gd which passes the projectile's global_position.
func take_projectile_hit(_projectile_pos: Vector2, dmg: int = 15) -> void:
	if state == "dead":
		return
	_apply_damage_to_armor(dmg)

func apply_damage(amount: int) -> void:
	# Called by projectile as a backup; keep same behavior
	_apply_damage_to_armor(amount)

func _apply_damage_to_armor(amount: int) -> void:
	if armor <= 0:
		# Armor already broken; do nothing here (death via typing word)
		return

	armor = max(armor - amount, 0)
	if armor_bar:
		armor_bar.value = armor

		# Hide the bar if empty, show if not
		if armor <= 0:
			armor_bar.hide()
		else:
			armor_bar.show()

	if armor == 0 and not armor_already_broken:
		armor_already_broken = true
		state = "stunned"
		stun_timer = stun_duration
		_play_if_exists("stunned")  # make sure the name matches your SpriteFrames

		# --- NEW: reveal word immediately and reset typing state ---
		if word_label:
			word_label.show()
		typed_progress = 0
		mistake = false
		_update_word_label()
		
		emit_signal("armor_broken")   # ✅ tell spawner to spawn next enemy




# -----------------------------
# Typing (enabled only when armor is 0)
# -----------------------------
func check_input(letter: String) -> bool:
	# Gate typing until armor is gone
	if armor > 0 or state == "dead":
		return false

	var correct := false

	if typed_progress < word.length():
		var target := word.substr(typed_progress, 1)

		# Case-sensitive check
		if letter == target:
			mistake = false
			typed_progress += 1
			correct = true

			# Gain energy when correct
			var sp = get_tree().current_scene
			if sp and sp.has_method("add_energy"):
				sp.add_energy()

			# Word complete → kill boss
			if typed_progress >= word.length():
				_update_word_label()
				die()
		else:
			mistake = true

	_update_word_label()
	return correct


func _update_word_label() -> void:
	if not word_label:
		return

	word_label.clear()

	# 🔒 Hide the word entirely while armor is still intact
	if armor > 0:
		word_label.hide()
		return
	else:
		word_label.show()

	# Armor broken → show progress with colors
	if typed_progress > 0:
		word_label.push_color(Color.GREEN)
		word_label.append_text(word.substr(0, typed_progress))
		word_label.pop()

	if typed_progress < word.length():
		if mistake:
			word_label.push_color(Color.RED)
			word_label.append_text(word[typed_progress])
			word_label.pop()
			if typed_progress + 1 < word.length():
				word_label.append_text(word.substr(typed_progress + 1))
		else:
			word_label.append_text(word.substr(typed_progress))


# -----------------------------
# Anim end + death
# -----------------------------
func _on_anim_finished() -> void:
	if state == "attack" and anim.animation == "attack":
		state = "walk"
		_play_if_exists("walking")
	elif state == "dead" and anim.animation == "death":
		queue_free()

var is_dead_flag: bool = false

func die() -> void:
	if state == "dead":
		return
	state = "dead"
	is_dead_flag = true  
	velocity = Vector2.ZERO
	if collision:
		collision.set_deferred("disabled", true)

	# ✅ Emit death signal so Single_Player can detect when boss dies
	if has_signal("died"):
		emit_signal("died")

	# Play correct animation or queue_free directly
	if anim and anim.sprite_frames.has_animation("death"):
		_play_if_exists("death")
	else:
		queue_free()



# -----------------------------
# Helpers
# -----------------------------
func _play_if_exists(name: String) -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(name):
		if anim.animation != name or not anim.is_playing():
			anim.play(name)

var player_in_range: bool = false

func _on_attack_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if state != "dead" and state != "stunned":
			state = "attack"
			_play_if_exists("attack")
			velocity = Vector2.ZERO

func _on_attack_range_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if state == "attack":
			state = "walk"
			_play_if_exists("walking")
