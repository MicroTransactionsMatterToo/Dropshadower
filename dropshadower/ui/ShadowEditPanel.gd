extends PanelContainer


var Global
onready var ShadowControl = $VBox/DialControlM/Control

var toggled: bool setget _set_toggled, _get_toggled
var _toggled := false

signal dropshadow_updated(node)


# ===== LOGGING =====
const LOG_LEVEL = 4

func logv(msg):
	if LOG_LEVEL > 3:
		printraw("(%d) [V] <ShadowEditPanel>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logd(msg):
	if LOG_LEVEL > 2:
		printraw("(%d) [D] <ShadowEditPanel>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logi(msg):
	if LOG_LEVEL >= 1:
		printraw("(%d) [I] <ShadowEditPanel>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass


# Called when the node enters the scene tree for the first time.
func _ready():
	logv("ShadowEditPanel _ready")
	self.Global = Engine.get_meta("Global")
	logv("Got global")
	self.ShadowControl.connect("value_changed", self, "on_dial_change")
	logv("Connected value changed")
	$VBox/Sliders/SD_Slider.share($VBox/Sliders/SD_Spinbox)
	$VBox/Sliders/SD_Slider.connect("value_changed", self, "_on_aux_slider_change")
	$VBox/Sliders/SS_Slider.share($VBox/Sliders/SS_Spinbox)
	$VBox/Sliders/SS_Slider.connect("value_changed", self, "_on_aux_slider_change")
	$VBox/Sliders/BR_Slider.share($VBox/Sliders/BR_Spinbox)
	$VBox/Sliders/SR_Slider.connect("value_changed", self, "_on_aux_slider_change")
	logv("Shared sliders")
	
	$VBox/ShadowControl/AngleVal.connect("value_changed", self, "_on_angle_change")
	$VBox/ShadowControl/MagnVal.connect("value_changed", self, "_on_magn_change")
	logv("Connected spinboxes")
	
	var dd_menu_mat = ResourceLoader.load("res://materials/MenuBackground.material")
	if dd_menu_mat != null:
		self.material = dd_menu_mat
		logv("Set menu material")
	
func _process(delta):
	self.visible = self.toggled
	if self.visible:
		self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)

func on_dial_change(angle, magn):
	self._set_slider_blocking(true)
	$VBox/ShadowControl/AngleVal.value = rad2deg(angle) + 180
	$VBox/ShadowControl/MagnVal.value = magn * 100.0
	self._set_slider_blocking(false)
	
	self.update_selected_props(angle, magn)
	
func _set_slider_blocking(blocking: bool):
	$VBox/ShadowControl/AngleVal.set_block_signals(blocking)
	$VBox/ShadowControl/MagnVal.set_block_signals(blocking)
	
func _on_angle_change(value):
	self.ShadowControl.set_block_signals(true)
	self.ShadowControl.angle = (value / 360.0) * (2 * PI)
	self.ShadowControl.set_block_signals(false)
	
	self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)
	
func _on_magn_change(value: float):
	self.ShadowControl.set_block_signals(true)
	self.ShadowControl.magnitude = value / 100.0
	self.ShadowControl.set_block_signals(false)
	
	self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)
	
func _on_aux_slider_change(val):
	self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)

func update_selected_props(angle, magn):
	if self.Global == null: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in select_tool.Selected:
		if item.Sprite != null:
			var item_sprite = item.Sprite
			if item_sprite.material is ShaderMaterial:
				item_sprite.set_meta("base_angle", angle / (2 * PI))
				item_sprite.material.set_shader_param("sun_angle", angle / (2 * PI))
				item_sprite.material.set_shader_param("sun_intensity", magn / 10)
				item_sprite.material.set_shader_param("shadow_dropoff", $VBox/Sliders/SD_Spinbox.value / 100.0)
				item_sprite.material.set_shader_param("shadow_strength", $VBox/Sliders/SS_Spinbox.value / 100.0)
				item_sprite.material.set_shader_param("blur_radius", $VBox/Sliders/BR_Spinbox.value)
				item_sprite.material.set_shader_param("node_rotation", item.global_rotation)
				var rot_mod = abs(PI + (item.global_rotation * 2))
				logv("Node Rotation set to %f (rot_mod: %.2f, rot_mod2: %.2f)" % [
					item.global_rotation,
					rot_mod,
					rot_mod / (2.0 * PI)
				])
			else:
				var material = ShaderMaterial.new()
				material.shader = ResourceLoader.load(Global.Root + "../dropshadower/shader/ShadowShader.shader", "", true)
				print(material.shader)
				
				item_sprite.material = material
				
func _set_toggled(val):
	self._toggled = val

func _get_toggled():
	if Global == null: return true
	else:
		return self._toggled and Global.Editor.Toolset.GetToolPanel("SelectTool").visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
