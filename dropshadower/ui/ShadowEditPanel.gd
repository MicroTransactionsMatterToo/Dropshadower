extends PanelContainer


var Global
var DropshadowCore
onready var ShadowControl = $VBox/V/DialControlM/Control
onready var VC = $VBox/V

var Defaultmat = CanvasItemMaterial.new()

var toggled: bool setget _set_toggled, _get_toggled
var _toggled := false

var disabled: bool setget _set_disabled, _get_disabled
var _disabled := true

var _selection_state = 0
var _previous_ref_node = null

var _delete_input_list

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
	self.Global = Engine.get_meta("DropshadowGlobal")
	logv("Got global")
	self.ShadowControl.connect("value_changed", self, "on_dial_change")
	self.ShadowControl.connect("submit", self, "commit_shadows")
	logv("Connected value changed")
	$VBox/V/Sliders/SD_Slider.share($VBox/V/Sliders/SD_Spinbox)
	$VBox/V/Sliders/SD_Slider.connect("value_changed", self, "_on_aux_slider_change")
	$VBox/V/Sliders/SS_Slider.share($VBox/V/Sliders/SS_Spinbox)
	$VBox/V/Sliders/SS_Slider.connect("value_changed", self, "_on_aux_slider_change")
	$VBox/V/Sliders/BR_Slider.share($VBox/V/Sliders/BR_Spinbox)
	$VBox/V/Sliders/BR_Slider.connect("value_changed", self, "_on_aux_slider_change")
	logv("Shared sliders")
	
	$VBox/V/ShadowControl/AngleVal.connect("value_changed", self, "_on_angle_change")
	$VBox/V/ShadowControl/MagnVal.connect("value_changed", self, "_on_magn_change")
	logv("Connected spinboxes")
	
	$VBox/EnableButton.connect("toggled", self, "_toggle_disabled")
	
	var dd_menu_mat = ResourceLoader.load("res://materials/MenuBackground.material")
	if dd_menu_mat != null:
		self.material = dd_menu_mat
		logv("Set menu material")
		
	if not Engine.has_meta("DropshadowCore"):
		logv("DropshadowCore not set, expect crashes")
	else:
		self.DropshadowCore = Engine.get_meta("DropshadowCore")
		
	self.disabled = true
	
func _process(delta):
	self.visible = self.toggled
	
	# Handle keyboard inputs so that the backspace key is actually usable
	var current_focus_owner = self.get_focus_owner()
	if current_focus_owner != null:
		if self.is_a_parent_of(current_focus_owner) and self._delete_input_list == null:
			logv("Current focus owner is a child, disable 'delete' action")
			self._delete_input_list = InputMap.get_action_list("delete")
			InputMap.action_erase_events("delete")
		elif not self.is_a_parent_of(current_focus_owner) and self._delete_input_list != null:
			logv("Current focus is no longer a child, enable 'delete' action")
			for event in self._delete_input_list:
				InputMap.action_add_event("delete", event)
			self._delete_input_list = null
	
	if Global == null: return
	
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	# Check if first selected object has a shadow already, and if so, use those values
	if not self.disabled:
		if self.Global == null: return

		for item in selected:
			if item.Sprite == null: continue
			if item.Sprite.material.shader == null: continue
			if item.Sprite.material.get_shader_param("sun_angle") == null: continue
			if item == self._previous_ref_node:
				break
			
			self.update_controls_from_prop(item)
			self._previous_ref_node = item
			break
			
			
	if len(selected) == 0:
		self._previous_ref_node = null
		
func _gui_input(event):
	# Make focus behaviour a bit more intuitive
	if event is InputEventMouseButton:
		self.propagate_call("release_focus", [])

func on_dial_change(angle, magn):
	self._set_slider_blocking(true)
	$VBox/V/ShadowControl/AngleVal.value = rad2deg(angle) + 180
	$VBox/V/ShadowControl/MagnVal.value = magn * 100.0
	self._set_slider_blocking(false)
	
	self.update_selected_props(angle, magn)
	
func _set_slider_blocking(blocking: bool):
	$VBox/V/ShadowControl/AngleVal.set_block_signals(blocking)
	$VBox/V/ShadowControl/MagnVal.set_block_signals(blocking)
	
func _on_angle_change(value):
	self.ShadowControl.set_block_signals(true)
	self.ShadowControl.angle = (value / 360.0) * (2 * PI)
	self.ShadowControl.set_block_signals(false)
	
	self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)
	self.commit_shadows()
	
func _on_magn_change(value: float):
	self.ShadowControl.set_block_signals(true)
	self.ShadowControl.magnitude = value / 100.0
	self.ShadowControl.set_block_signals(false)
	
	self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)
	self.commit_shadows()
	
func _on_aux_slider_change(val):
	self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)
	self.commit_shadows()
	
func _toggle_disabled(button_state):
	self.disabled = !button_state
	
func _block_signals(val):
	self.ShadowControl.set_block_signals(val)

	$VBox/V/Sliders/SD_Spinbox.set_block_signals(val)
	$VBox/V/Sliders/SS_Spinbox.set_block_signals(val)
	$VBox/V/Sliders/BR_Spinbox.set_block_signals(val)
	$VBox/V/ShadowControl/AngleVal.set_block_signals(val)
	$VBox/V/ShadowControl/MagnVal.set_block_signals(val)
	
func update_controls_from_prop(prop):
	var spriteshader: ShaderMaterial = prop.Sprite.material
		
	self._block_signals(true)	
	logv("Sun Intensity: %.2f" % spriteshader.get_shader_param("sun_intensity") * 10.0)
	self.ShadowControl.magnitude = spriteshader.get_shader_param("sun_intensity") * 10.0
	logv("Sun Angle: %.2f" % (2*PI) * spriteshader.get_shader_param("sun_angle"))
	self.ShadowControl.angle =	((2*PI) * spriteshader.get_shader_param("sun_angle")) - PI
	
	$VBox/V/ShadowControl/AngleVal.value = rad2deg(self.ShadowControl.angle) + 180
	$VBox/V/ShadowControl/MagnVal.value = self.ShadowControl.magnitude * 100.0
	
	$VBox/V/Sliders/SD_Spinbox.value = spriteshader.get_shader_param("shadow_dropoff") * 100.0
	$VBox/V/Sliders/SS_Spinbox.value = spriteshader.get_shader_param("shadow_strength") * 100.0
	$VBox/V/Sliders/BR_Spinbox.value = spriteshader.get_shader_param("blur_radius")
	
	self._block_signals(false)

func update_selected_props(angle, magn):
	if self.Global == null: return
	if self.disabled: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in select_tool.Selected:
		if item.Sprite != null:
			var item_sprite = item.Sprite
			if not item_sprite.material is ShaderMaterial:
				var material = ShaderMaterial.new()
				material.shader = ResourceLoader.load(Global.Root + "../dropshadower/shader/ShadowShader.shader", "", true)

				item_sprite.material = material
			
			item_sprite.material.set_shader_param("sun_angle", angle / (2 * PI))
			item_sprite.material.set_shader_param("sun_intensity", magn / 10)
			item_sprite.material.set_shader_param("shadow_dropoff", 	$VBox/V/Sliders/SD_Spinbox.value / 100.0)
			item_sprite.material.set_shader_param("shadow_strength", 	$VBox/V/Sliders/SS_Spinbox.value / 100.0)
			item_sprite.material.set_shader_param("blur_radius", 		$VBox/V/Sliders/BR_Spinbox.value)
			item_sprite.material.set_shader_param("node_rotation", item.global_rotation)

func commit_shadows():
	if self.Global == null: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in select_tool.Selected:
		if item.Sprite != null:
			if DropshadowCore == null:
				return
				
			
			
			DropshadowCore.set_node_shadow(item)

func erase_shadows():
	if self.Global == null: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in select_tool.Selected:
		if item.Sprite != null:
			if DropshadowCore == null:
				return
			
			DropshadowCore.erase_node_shadow(item)
			item.Sprite.material = Defaultmat
				
func _set_toggled(val):
	self._toggled = val

func _get_toggled():
	if Global == null: return true
	else:
		return self._toggled and Global.Editor.Toolset.GetToolPanel("SelectTool").visible

func _set_disabled(val: bool) -> void:
	self._disabled = val
	if val:
		self.VC.modulate = Color.gray.darkened(0.5)
		self.VC.propagate_call("set", ["disabled", true])
		self.VC.propagate_call("set", ["editable", false])
		self.ShadowControl.enabled = false
		self.erase_shadows()
	else:
		self.VC.modulate = Color.white
		self.VC.propagate_call("set", ["disabled", false])
		self.VC.propagate_call("set", ["editable", true])
		self.ShadowControl.enabled = true
		self.commit_shadows()
		
func _get_disabled() -> bool:
	return self._disabled
