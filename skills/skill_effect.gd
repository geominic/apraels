extends Node2D

@export var duration : float = 1.0
@export var scale_curve : Curve
@export var alpha_curve : Curve
@export var rotation_speed : float = 0.0
@export var color : Color = Color(1.0, 1.0, 1.0, 1.0)

var timer : float = 0.0
var initial_scale : Vector2

func _ready() -> void:
	initial_scale = scale
	modulate = color
	
	# Auto-destroy after duration
	var destroy_timer = get_tree().create_timer(duration)
	destroy_timer.timeout.connect(queue_free)

func _process(delta: float) -> void:
	timer += delta
	var progress = timer / duration
	
	# Apply scale curve
	if scale_curve:
		var scale_factor = scale_curve.sample(progress)
		scale = initial_scale * scale_factor
	
	# Apply alpha curve
	if alpha_curve:
		var alpha = alpha_curve.sample(progress)
		modulate.a = alpha
	
	# Apply rotation
	if rotation_speed != 0:
		rotation += rotation_speed * delta
	
	# Destroy when done
	if timer >= duration:
		queue_free()
