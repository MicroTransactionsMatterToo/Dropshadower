extends PanelContainer


var Global
onready var ShadowControl = $VBox/DialControlM/Control

var toggled: bool setget _set_toggled, _get_toggled
var _toggled := false

signal dropshadow_updated(node)


# Called when the node enters the scene tree for the first time.
func _ready():
	self.Global = Engine.get_meta("Global")
	self.ShadowControl.connect("value_changed", self, "on_dial_change")
	var dd_menu_mat = ResourceLoader.load("res://materials/MenuBackground.material")
	if dd_menu_mat != null:
		self.material = dd_menu_mat
	
func _process(delta):
	self.visible = self.toggled

func on_dial_change(angle, magn):
	$VBox/ShadowControl/AngleVal.value = rad2deg(angle) + 180
	$VBox/ShadowControl/MagnVal.value = magn * 100.0
	
	self.update_selected_props(angle, magn)
	
func _on_angle_change(value):
	self.ShadowControl.angle = value * (2 * PI)

func update_selected_props(angle, magn):
	if self.Global == null: return
	var select_tool = Global.Editor.Tools["SelectTool"]
	var selected = select_tool.Selected
	print(select_tool)
	print(selected)
	
	for item in select_tool.Selected:
		if item.Sprite != null:
			var item_sprite = item.Sprite
			if item_sprite.material is ShaderMaterial:
				print("FUCKER")
				item_sprite.material.set_shader_param("sun_angle", angle / (2 * PI))
				item_sprite.material.set_shader_param("sun_intensity", magn / 10)
			else:
				var material = ShaderMaterial.new()
				material.shader = ResourceLoader.load("res://dropshadower/shader/ShadowShader.shader", "", true)
				print(material.shader)
				
				item_sprite.material = material
				
func _set_toggled(val):
	self._toggled = val

func _get_toggled():
	if Global == null: return true
	else:
		return self._toggled and Global.Editor.GetToolPanel("SelectTool").visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
