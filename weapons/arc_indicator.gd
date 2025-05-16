extends Node2D

var swing_angle : float = 90.0
var swing_direction : int = 1
var arc_radius : float = 50.0
var arc_color : Color = Color(1.0, 0.5, 0.0, 0.5)
var arc_thickness : float = 2.0

func _ready() -> void:
	# Make sure we redraw when properties change
	set_notify_transform(true)

func _draw() -> void:
	# Draw the arc to visualize the swing
	var start_angle = -swing_angle / 2.0 * swing_direction
	var end_angle = swing_angle / 2.0 * swing_direction
	
	# Convert to radians
	start_angle = deg_to_rad(start_angle)
	end_angle = deg_to_rad(end_angle)
	
	# Draw the arc
	draw_arc(Vector2.ZERO, arc_radius, start_angle, end_angle, 32, arc_color, arc_thickness)
	
	# Draw lines to indicate the start and end of the arc
	var start_point = Vector2(cos(start_angle), sin(start_angle)) * arc_radius
	var end_point = Vector2(cos(end_angle), sin(end_angle)) * arc_radius
	
	draw_line(Vector2.ZERO, start_point, arc_color, arc_thickness)
	draw_line(Vector2.ZERO, end_point, arc_color, arc_thickness)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()
