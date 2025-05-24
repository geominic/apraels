extends Area2D

@export var speed : float = 400.0
@export var damage : int = 10
@export var lifetime : float = 2.0
@export var fire_rate : float = 0.2  # Time in seconds between shots
@export var spread : float = 0.0  # Max spread angle in degrees (0 = no spread)

var direction : Vector2 = Vector2.RIGHT
var source : Node = null  # Who fired this projectile

func _ready() -> void:
	# Set up lifetime timer
	$Timer.wait_time = lifetime
	$Timer.one_shot = true
	$Timer.start()
	$Timer.connect("timeout", _on_timer_timeout)

	# Connect body entered signal
	connect("body_entered", _on_body_entered)

func _physics_process(delta: float) -> void:
	# Move in the set direction
	position += direction * speed * delta

func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	# Apply spread if any
	if spread > 0.0:
		var angle_offset = deg_to_rad(randf_range(-spread/2.0, spread/2.0))
		direction = direction.rotated(angle_offset)
	# Rotate sprite to face direction
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	# Skip collision with source
	if body == source:
		return

	# Skip collision with allies (converted enemies)
	if source.is_in_group("ally") and body.is_in_group("player"):
		return
	if source.is_in_group("player") and body.is_in_group("ally"):
		return
	if source.is_in_group("ally") and body.is_in_group("ally"):
		return

	# Handle collision with enemies or player or ally
	if (source.is_in_group("player") and body.is_in_group("enemy")) or \
	   (source.is_in_group("enemy") and body.is_in_group("player")) or \
	   (source.is_in_group("ally") and body.is_in_group("enemy")) or \
	   (source.is_in_group("enemy") and body.is_in_group("ally")):
		# Apply damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	# Collide with environment
	elif body is StaticBody2D:
		queue_free()

func _on_timer_timeout() -> void:
	queue_free()
