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

var _copy_params

signal dropshadow_updated(node)

const control_nodes = [
	["SS", "shadow_strength"],
	["SQ", "shadow_quality"],
	["BR", "blur_radius"],
	["SS2", "shadow_steps"]
]


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
	self._setup_controls()
	
	$VBox/V/ShadowControl/AngleVal.connect("value_changed", self, "_on_angle_change")
	$VBox/V/ShadowControl/MagnVal.connect("value_changed", self, "_on_magn_change")
	logv("Connected spinboxes")
	
	$VBox/EnableButton.connect("toggled", self, "_toggle_disabled")
	$VBox/V/ZMode/Button.connect("item_selected", self, "_on_aux_slider_change")
	
	$VBox/CopyPaste/Copy.connect("pressed", self, "_on_copy_pressed")
	$VBox/CopyPaste/Paste.connect("pressed", self, "_on_paste_pressed")
	
	var dd_menu_mat = ResourceLoader.load("res://materials/MenuBackground.material")
	if dd_menu_mat != null:
		self.material = dd_menu_mat
		logv("Set menu material")
		
	if not Engine.has_meta("DropshadowCore"):
		logv("DropshadowCore not set, expect crashes")
	else:
		self.DropshadowCore = Engine.get_meta("DropshadowCore")
		
	self.disabled = true

func _exit_tree():
	Engine.remove_meta("DropshadowCore")
	Engine.remove_meta("DropshadowGlobal")
	Engine.remove_meta("DropshadowScript")

func _setup_controls():
	for entry in self.control_nodes:
		var spinbox = self.VC.get_node("Sliders/%s_Spinbox" % entry[0])
		var slider = self.VC.get_node("Sliders/%s_Slider" % entry[0])
		slider.share(spinbox)
		slider.connect("value_changed", self, "_on_aux_slider_change")
	
func _process(delta):
	self.visible = self.toggled
	
	# Handle keyboard inputs so that the backspace key is actually usable
	var current_focus_owner = self.get_focus_owner()
	if current_focus_owner == null and self._delete_input_list != null:
		logv("Re-enabled delete keys")
		for event in self._delete_input_list:
			InputMap.action_add_event("delete", event)
		self._delete_input_list = null
			
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
	if not self.disabled or DropshadowCore.node_shadow_visible(selected[0]):
		if self.Global == null: return

		for item in selected:
			if item.Sprite != null: $VBox/CopyPaste/Paste.disabled = false
			if not DropshadowCore.node_has_shadow(item): continue
			if item == self._previous_ref_node:
				break
			
			self.update_controls_from_prop(item)
			
			self._previous_ref_node = item
			$VBox/CopyPaste/Copy.disabled = false
			break
		
		for item in selected:
			if not DropshadowCore.node_has_shadow(item): continue
			var shadow = DropshadowCore.get_node_shadow(item)
			shadow.material.set_shader_param("node_rotation", item.global_rotation)
			
			
	if len(selected) == 0:
		self._previous_ref_node = null
		$VBox/CopyPaste/Copy.disabled = true
		$VBox/CopyPaste/Paste.disabled = true
		
func _gui_input(event):
	# Make focus behaviour a bit more intuitive
	if event is InputEventMouseButton:
		logv(event.button_index in [BUTTON_LEFT])
		if event.button_index in [BUTTON_LEFT, BUTTON_RIGHT, BUTTON_MIDDLE]:
			logv(self._delete_input_list)
			self.propagate_call("release_focus", [])
			

func on_dial_change(angle, magn):
	logv("Dial Change | A: %.2f, M: %.2f" % [angle, magn])
	self._set_slider_blocking(true)
	$VBox/V/ShadowControl/AngleVal.value = rad2deg(angle)
	$VBox/V/ShadowControl/MagnVal.value = magn * 100.0
	self._set_slider_blocking(false)
	
	self.update_selected_props(angle, magn)
	
func get_control_values() -> Dictionary:
	var values = {}
	for entry in self.control_nodes:
		var node = self.VC.get_node("Sliders/%s_Spinbox" % entry[0])
		values[entry[1]] = node.value 

	values["z_mode"] = self.VC.get_node("ZMode/Button").selected

	return values
	
func _set_slider_blocking(blocking: bool):
	$VBox/V/ShadowControl/AngleVal.set_block_signals(blocking)
	$VBox/V/ShadowControl/MagnVal.set_block_signals(blocking)
	
func _on_angle_change(value):
	self.ShadowControl.set_block_signals(true)
	logv("Setting angle to %.2f" % deg2rad(value))
	self.ShadowControl.angle = deg2rad(value)
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
	logv("AUX CHANGE")
	self.update_selected_props(self.ShadowControl.angle, self.ShadowControl.magnitude)
	self.commit_shadows()
	
func _on_copy_pressed():
	logv("Copy pressed")
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in selected:
		if not DropshadowCore.node_has_shadow(item): continue
		
		logv("Copying shadow params from %s" % item)
		self._copy_params = DropshadowCore.ShadowStruct.new()
		self._copy_params.from_prop(item)
		logv("CopyParams is %s" % self._copy_params.as_dict())
		
		return
		
func _on_paste_pressed():
	logv("Paste pressed")
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in selected:
		if not DropshadowCore.node_has_shadow(item): continue
		
		self._copy_params.apply(item)
		
	
func _toggle_disabled(button_state):
	self.disabled = !button_state
	
func _block_signals(val):
	self.ShadowControl.set_block_signals(val)

	for entry in self.control_nodes:
		self.VC.get_node("%s_Slider" % entry[0]).set_block_signals(val)
	$VBox/V/ShadowControl/AngleVal.set_block_signals(val)
	$VBox/V/ShadowControl/MagnVal.set_block_signals(val)
	
func update_controls_from_prop(prop):
	if not DropshadowCore.node_has_shadow(prop): return
	var node_shadow = DropshadowCore.get_node_shadow(prop)
	if node_shadow == null: return
	
	var shadow_mat: ShaderMaterial = node_shadow.material
	
	self._block_signals(true)
	
	self.ShadowControl.angle = shadow_mat.get_shader_param("sun_angle")
	self.VC.get_node("ShadowControl/AngleVal").value = rad2deg(self.ShadowControl.angle)
	self.ShadowControl.magnitude = shadow_mat.get_shader_param("sun_intensity") * 10
	
	for entry in self.control_nodes:
		self.VC.get_node("%s_Slider" % entry[0]).value = shadow_mat.get_shader_param(entry[1])
		
	self._block_signals(false)
	

func update_selected_props(angle, magn):
	if self.Global == null: return
	if self.disabled: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in select_tool.Selected:
		if item.Sprite != null and not DropshadowCore.node_has_shadow(item):
			DropshadowCore.init_node_shadow(item)

		if DropshadowCore.node_has_shadow(item):
			var control_values = self.get_control_values()
			logv(control_values)
			DropshadowCore.set_node_shadow(
				item,
				angle,
				magn,
				int(control_values["shadow_quality"]),
				int(control_values["shadow_steps"]),
				control_values["shadow_strength"] / 100.0,
				control_values["blur_radius"]
			)
			DropshadowCore.set_node_shadow_z(item, control_values["z_mode"])

func commit_shadows():
	if self.Global == null: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in select_tool.Selected:
		if DropshadowCore.node_has_shadow(item):
			DropshadowCore.save_node_shadow(item)

func erase_shadows():
	if self.Global == null: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	
	for item in select_tool.Selected:
		if DropshadowCore.node_has_shadow(item):
			DropshadowCore.erase_node_shadow(item)
				
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
