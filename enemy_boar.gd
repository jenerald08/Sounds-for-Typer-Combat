extends CharacterBody2D

signal died
signal armor_broken  # signal to notify the spawner when armor first reaches 0
@export var faces_right: bool = true
@export var debug_knockback: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var frames: SpriteFrames = anim.sprite_frames
@onready var word_label: RichTextLabel = $WordLabel
@onready var armor_bar: TextureProgressBar = $ArmorBar   # 👈 Armor bar UI

# Typing state
var word: String = "boar"
var typed_progress: int = 0
var mistake: bool = false
var ui_active: bool = true

# Movement state
@export var walk_speed: float = 50.0
@export var run_speed: float = 175.0
@export var run_distance: float = 500.0
@export var attack_distance: float = 40.0
var player: Node2D
var state: String = "walk"
var is_vanishing: bool = false

# Knockback state
var knockback_velocity: Vector2 = Vector2.ZERO
@export var knockback_strength: float = 200.0
@export var player_attack_knockback: float = 120.0
@export var knockback_decay: float = 8000.0

# Stagger effect
var stagger_timer: float = 0.0
@export var stagger_duration: float = 0.2
@export var stagger_animation: String = "hit"

# Armor / HP system
@export var max_armor: int = 100
var armor: int
var armor_broken_emitted: bool = false   # <- renamed flag to avoid collision with the signal

# Damage values
@export var melee_damage: int = 25
@export var projectile_damage: int = 15

var boar_word_pool = ["Snort", "Boar", "Mud", "Hoof", "Charge", "Wild", "Grunt", "Tusk", "Feral"
, "Eclipse", "Aether", "Runeblade", "Sentinel", "Dominus", "Harbinger", "Lumina", "Chimera", "Paragon", "Abyss"]

func assign_random_word() -> void:
	if boar_word_pool.size() > 0:
		var random_index = randi() % boar_word_pool.size()
		word = boar_word_pool[random_index]
		word_label.text = word
		typed_progress = 0
		mistake = false
		boar_word_pool.remove_at(random_index)  # 👈 prevents repeat in same wave


func _ready() -> void:
	armor = max_armor
	armor_bar.max_value = max_armor
	armor_bar.value = armor
	armor_bar.show()

	# Position armor bar above enemy
	armor_bar.position = Vector2(-armor_bar.size.x / 1.7, -33)

	randomize()
	assign_random_word()

	update_label()
	player = get_tree().get_first_node_in_group("player")
	if anim and frames and frames.has_animation("walk"):
		anim.play("walk")
		anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
	
	_update_ui_visibility()  # 👈 apply initial state

func _update_ui_visibility() -> void:
	if word_label:
		word_label.visible = ui_active
	if armor_bar:
		armor_bar.visible = ui_active
		
	if ui_active:
		word_label.visible = armor > 0
		armor_bar.visible = armor > 0
	else:
		word_label.hide()
		armor_bar.hide()

func activate_ui() -> void:
	ui_active = true
	_update_ui_visibility()

func deactivate_ui():
	ui_active = false
	_update_ui_visibility()

func _take_damage(damage: int) -> void:
	armor -= damage
	if armor <= 0:
		armor = 0
		emit_signal("armor_broken")
	_update_armor_bar()
	_update_ui_visibility()

func _update_armor_bar() -> void:
	armor_bar.value = armor
	if armor <= 0:
		armor_bar.hide()
		word_label.show()   # 👈 show word when armor breaks
	else:
		word_label.hide()   # 👈 keep word hidden while armor is intact


func has_armor() -> bool:
	return armor > 0

func _physics_process(delta: float) -> void:
	if not player:
		return

	# Knockback first
	if knockback_velocity.length() > 0.001:
		self.velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
		if knockback_velocity.length() < 1.0:
			knockback_velocity = Vector2.ZERO

		if stagger_timer > 0.0:
			stagger_timer = max(stagger_timer - delta, 0.0)

		if debug_knockback:
			print("Knockback active, vel:", self.velocity, "remaining:", knockback_velocity)
		return

	# Handle stagger
	if stagger_timer > 0.0:
		stagger_timer = max(stagger_timer - delta, 0.0)
		if anim and frames and frames.has_animation(stagger_animation) and anim.animation != stagger_animation:
			anim.play(stagger_animation)
		return

	# AI movement
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if dist > 0.0 else Vector2.ZERO
	var desired_velocity := Vector2.ZERO

	if anim and dir.x != 0.0:
		anim.flip_h = dir.x > 0.0 if faces_right else dir.x < 0.0

	match state:
		"walk":
			if frames and frames.has_animation("walk") and anim.animation != "walk":
				anim.play("walk")
			desired_velocity = dir * walk_speed
			if dist <= run_distance:
				state = "run"

		"run":
			if frames and frames.has_animation("run") and anim.animation != "run":
				anim.play("run")
			desired_velocity = dir * run_speed
			if dist <= attack_distance:
				state = "vanish"
				desired_velocity = Vector2.ZERO
				vanish()

		"vanish":
			desired_velocity = Vector2.ZERO

	self.velocity = desired_velocity
	move_and_slide()

	# Collision knockback (enemy → player)
	if desired_velocity != Vector2.ZERO:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider and collider.is_in_group("player"):
				var knock_dir: Vector2 = global_position - collider.global_position
				knock_dir.y = 0
				if knock_dir.length() == 0:
					knock_dir.x = 1.0
				knock_dir = knock_dir.normalized()
				apply_knockback(knock_dir * knockback_strength)

				if collider.has_method("take_damage"):
					collider.take_damage()

# -----------------------------
# Knockback / stagger
# -----------------------------
func apply_knockback(force: Vector2) -> void:
	force.y = 0
	knockback_velocity = force
	stagger_timer = stagger_duration
	if debug_knockback:
		print("apply_knockback:", force)
	if anim and frames and frames.has_animation(stagger_animation):
		anim.play(stagger_animation)

func take_hit_from_player(player_pos: Vector2) -> void:
	if is_vanishing:
		return
	var knock_dir: Vector2 = global_position - player_pos
	knock_dir.y = 0
	if knock_dir.length() == 0:
		knock_dir.x = 1.0
	knock_dir = knock_dir.normalized()
	apply_knockback(knock_dir * player_attack_knockback)
	apply_damage(25) # melee does more damage

# -----------------------------
# Damage / Armor
# -----------------------------
func apply_damage(amount: int) -> void:
	armor -= amount
	if armor < 0:
		armor = 0
	armor_bar.value = armor

	# Hide the bar if empty, otherwise show it
	if armor <= 0:
		armor_bar.hide()
		word_label.show()   # 👈 ensure word appears when armor is broken

		# 👇 Trigger spawn when armor breaks (only once)
		if not armor_broken_emitted:
			armor_broken_emitted = true
			emit_signal("armor_broken")   # will be used by Spawner
	else:
		armor_bar.show()
		word_label.hide()   # 👈 keep hidden while armor > 0

	print("Enemy armor left:", armor)



# Projectile hit (from ExtraWordLabel slashes)
func take_projectile_hit(projectile_pos: Vector2, dmg: int = 15) -> void:
	print("Enemy hit by projectile slash!")

	# Knockback direction away from projectile
	var dir = (global_position - projectile_pos).normalized()
	dir.y = 0
	if dir.length() == 0:
		dir.x = 1.0
	apply_knockback(dir * (player_attack_knockback * 0.8))

	# Slash projectiles damage armor
	apply_damage(dmg)

	# Optional stagger
	stagger_timer = stagger_duration

# -----------------------------
# Vanish / death
# -----------------------------
func vanish() -> void:
	if is_vanishing:
		return
	is_vanishing = true
	print("Enemy vanishing:", name)
	if frames and frames.has_animation("vanish"):
		frames.set_animation_loop("vanish", false)
		anim.play("vanish")
	else:
		queue_free()

func _on_animation_finished() -> void:
	if is_vanishing and anim.animation == "vanish":
		queue_free()

# -----------------------------
# Typing / colored word UI
# -----------------------------
func update_label() -> void:
	word_label.clear()

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

func check_input(letter: String) -> bool:
	var correct := false

	if typed_progress < word.length():
		var target := word.substr(typed_progress, 1)

		# Case-sensitive comparison
		if letter == target:
			mistake = false
			typed_progress += 1
			correct = true

			# Give energy to the Single_Player scene (if it exists)
			var sp = get_tree().current_scene
			if sp and sp.has_method("add_energy"):
				sp.add_energy()

			if typed_progress >= word.length():
				update_label()
				die()
		else:
			mistake = true

	update_label()
	return correct

var is_dead_flag: bool = false

func die() -> void:
	if is_vanishing or is_dead_flag:
		return
	is_dead_flag = true
	state = "vanish"
	emit_signal("died")   # 👈 only here will kill record increment
	vanish()
