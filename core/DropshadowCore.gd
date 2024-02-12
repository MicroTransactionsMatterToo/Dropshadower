class_name DropshadowCore
var script_class = "tool"


var DropShader
onready var SelectTool = Global.Tools["SelectTool"]

var SidepanelTempl
var sidepanel


const RES_PATH = "res://dropshadower/"


enum SelectableTypes {
	Invalid 		= 0,
	Wall 			= 1,
	PortalFree 		= 2,
	PortalWall		= 3,
	Obj 			= 4,
	Pathway 		= 5,
	Light 			= 6,
	PatternShape	= 7,
	Roof 			= 8
}


# ===== LOGGING =====
const LOG_LEVEL = 4

func logv(msg):
	if LOG_LEVEL > 3:
		printraw("(%d) [V] <DropshadowCore>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logd(msg):
	if LOG_LEVEL > 2:
		printraw("(%d) [D] <DropshadowCore>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logi(msg):
	if LOG_LEVEL >= 1:
		printraw("(%d) [I] <DropshadowCore>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass


# ==== MOD ====
func start() -> void:
	logv("STARTUP")

	logv("Loading dropshadow.zip for UI")
	var success = ProjectSettings.load_resource_pack(Global.Root + "../dropshadower.zip")
	
	self.DropShader = ResourceLoader.load(RES_PATH + "shader/ShadowShader.shader", "Shader", true)
	self.SidepanelTempl = load("res://dropshadower/ui/ShadowEditPanel.tscn")
	
	Engine.set_meta("Global", Global)

	self._bootstrap_sidepanel()
	self._bootstrap_selectpanel()

func _bootstrap_sidepanel():
	self.sidepanel = self.SidepanelTempl.instance()
	logv("sidepanel created: %s" % self.sidepanel)

	var sidepanel_root = Global.Editor.ObjectLibraryPanel.get_parent()
	sidepanel_root.add_child(self.sidepanel)

	self.sidepanel.visible = true

func _bootstrap_selectpanel():
	var stool_panel = Global.Editor.GetToolPanel("SelectTool")
	self.stool_toggle = stool_panel.CreateButton("Dropshadow Editor", "")
	self.stool_toggle.toggle_mode = true
	self.stool_toggle.connect("toggled", self, "on_dropshadow_toggle")

func on_dropshadow_toggle(pressed):
	self.sidepanel.toggled = pressed


class ShadowStruct:
	var node_id: int
	var sun_angle 		:= 0.0
	var sun_intensity 	:= 1.0
	var shadow_dropoff 	:= 1.0
	var shadow_strength := 1.0
	var blur_radius		:= 10.0
	var dropoff_enabled := true

	var DropShader = ResourceLoader.load(Global.Root + "../shader/ShadowShader.shader", "Shader", true)
	onready var SelectTool = Global.Tools["SelectTool"]


	# ===== LOGGING =====
	const LOG_LEVEL = 4

	func logv(msg):
		if LOG_LEVEL > 3:
			printraw("(%d) [V] <ShadowStruct>: " % OS.get_ticks_msec())
			print(msg)
		else:
			pass

	func logd(msg):
		if LOG_LEVEL > 2:
			printraw("(%d) [D] <ShadowStruct>: " % OS.get_ticks_msec())
			print(msg)
		else:
			pass

	func logi(msg):
		if LOG_LEVEL >= 1:
			printraw("(%d) [I] <ShadowStruct>: " % OS.get_ticks_msec())
			print(msg)
		else:
			pass



	func _to_string() -> String:
		return "<ShadowStruct for 0x%X [θ: %.2f, I: %.2f, D: %.2f, S: %.2f]" % [
			self.node_id,
			self.sun_angle,
			self.sun_intensity,
			self.shadow_dropoff,
			self.shadow_strength
		]
	
	func apply(prop):
		match SelectTool.GetSelectableType(prop):
			SelectableTypes.Obj, 			\
			SelectableTypes.PortalClosed, 	\
			SelectableTypes.PortalFree:
				var shader_mat = ShaderMaterial.new()
				shader_mat.shader = DropShader

				for val in ["sun_angle", "sun_intensity", "shadow_dropoff", "shadow_strength"]:
					shader_mat.set_shader_param(val, self.get(val))
			_:
				logv("Invalid Prop type, ignoring")
				return
