extends AspectRatioContainer
class_name DialControl



onready var sun_handle = $SunHandle


var mouse_inside: bool = false

var handle_mouseover: bool = false
var handle_grabbed: bool = false
var handle_base_scale = 0.04;
var handle_color: Color = Color.orange


var centre: Vector2 setget , _get_centre
var handle_radius: float setget , _get_handle_radius

var prev_rect_size: Vector2

var angle: float setget _set_angle, _get_angle
var magnitude: float setget _set_magnitude, _get_magnitude

var enabled := true

signal value_changed(angle, magnitude)
signal submit()




func _ready():
	self.prev_rect_size = self.rect_size
	
func _gui_input(event):
	if event is InputEventMouseButton and self.enabled:
		var handle_rect = self.sun_handle.get_rect()
		handle_rect = self.sun_handle.transform.xform(handle_rect)
		if handle_rect.has_point(event.position):
			if Input.is_mouse_button_pressed(BUTTON_LEFT):
				self.handle_grabbed = true
				self.sun_handle.position = get_local_mouse_position()
				

func _process(delta):
	if not self.enabled:
		return
		
	self.update()
	if self.handle_grabbed:
		var mouse_pos = self.get_local_mouse_position()
		var mouse_dist = mouse_pos.distance_to(self.get_rect().size / 2.0)
		self.sun_handle.position = self.centre.move_toward(
			get_local_mouse_position(), 
			min(mouse_dist, self.handle_radius)
		)
		self.emit_signal("value_changed", self.angle, self.magnitude)
		
		if not Input.is_mouse_button_pressed(BUTTON_LEFT):
			self.emit_signal("submit")
			self.handle_grabbed = false
			
	if self.mouse_inside:
		var handle_rect = self.sun_handle.get_rect()
		handle_rect = self.sun_handle.transform.xform(handle_rect)
		if handle_rect.has_point(get_local_mouse_position()):
			self.handle_mouseover = true
			self.sun_handle.modulate = self.handle_color.darkened(0.5)
			self.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND
		else:
			self.handle_mouseover = false
			self.sun_handle.modulate = self.handle_color
			self.mouse_default_cursor_shape = Input.CURSOR_ARROW

func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			self.mouse_inside = true
		NOTIFICATION_MOUSE_EXIT:
			self.mouse_inside = false
		NOTIFICATION_RESIZED:
			self.rect_min_size.y = self.rect_size.x
			self.sun_handle.position = (
				self.sun_handle.position / self.prev_rect_size
			) * self.rect_size
			self.prev_rect_size = self.rect_size
			self.sun_handle.scale = self.handle_base_scale * (self.rect_size / Vector2(64, 64))
			
func _get_angle() -> float:
	return self.sun_handle.position.angle_to_point(self.centre)
	
func _set_angle(angle: float):
	self.sun_handle.position = self.centre + polar2cartesian(
		self.handle_radius * self._get_magnitude(),
		angle + PI
	)
	
	self.emit_signal("value_changed", self.angle, self.magnitude)
	
func _get_magnitude() -> float:
	return self.sun_handle.position.distance_to(self.centre) / self.handle_radius
	
func _set_magnitude(magnitude: float):
	var max_point = polar2cartesian(self.handle_radius, self._get_angle())
	self.sun_handle.position = self.centre + polar2cartesian(
		self.handle_radius * magnitude,
		self._get_angle()
	)
	
	self.emit_signal("value_changed", self.angle, self.magnitude)
	

func rotated_point(_center, _angle, _distance):
	return _center + Vector2(sin(_angle),cos(_angle)) * _distance


func _get_centre() -> Vector2:
	return (self.rect_size / 2)
	
func _get_handle_radius() -> float:
	return (self.rect_size / 2.0).x
