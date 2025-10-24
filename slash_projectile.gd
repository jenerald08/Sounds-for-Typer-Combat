extends Area2D

@export var speed: float = 600.0
@export var max_distance: float = 500.0
@export var knockback: float = 220.0
@export var base_damage: int = 13
@export var boosted_damage: int = 30   # 💥 Stronger slash when energy full
@onready var sprite: Sprite2D = $Sprite2D

var damage: int
var direction: Vector2 = Vector2.RIGHT
var start_pos: Vector2

func _ready() -> void:
	# Check at spawn if EnergyBar is full
	_update_state()
	
	start_pos = global_position
	# ensure the signal is connected (or connect in the editor)
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

func _process(delta: float) -> void:
	# Continuously update color depending on energy state
	_update_state()
	
	global_position += direction * speed * delta
	position += direction * speed * delta
	if global_position.distance_to(start_pos) >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemy"):
		return

	# Enemy has projectile hit handler
	if body.has_method("take_projectile_hit"):
		body.take_projectile_hit(global_position, damage)  # ✅ pass damage properly
	else:
		# Fallback: just knockback
		if body is Node2D and body.has_method("apply_knockback"):
			var b2d: Node2D = body as Node2D
			var dir: Vector2 = (b2d.global_position - global_position)
			dir.y = 0.0
			if dir.length() == 0.0:
				dir.x = 1.0
			dir = dir.normalized()
			body.apply_knockback(dir * knockback)

	queue_free()
		
func _physics_process(delta):
	position += direction * speed * delta
	# Update state every frame (color + damage)
	_update_state()
	
	# Destroy after traveling max distance
	if global_position.distance_to(start_pos) >= max_distance:
		queue_free()

func _update_state() -> void:
	var sp = get_tree().current_scene
	if sp and sp.has_method("is_energy_full") and sp.is_energy_full():
		# Energy full → stronger slash
		damage = boosted_damage
		sprite.modulate = Color.YELLOW   # ⚡ black slash
	else:
		# Normal slash
		damage = base_damage
		sprite.modulate = Color.WHITE   # normal color
