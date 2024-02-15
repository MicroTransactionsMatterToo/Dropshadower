class_name DropshadowCore
var script_class = "tool"


var DropShader
onready var SelectTool = Global.Tools["SelectTool"]

var SidepanelTempl
var sidepanel

var stool_toggle

var storage
var live_storage = {}



const RES_PATH = "res://dropshadower/"
const STORAGE_NODE_ID = 0xD60954AD03


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

func loge(msg):
	if LOG_LEVEL > 0:
		printraw("(%d) [E] <DropshadowCore>: " % OS.get_ticks_msec())
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
	Engine.set_meta("DropshadowCore", self)

	self._bootstrap_sidepanel()
	self._bootstrap_selectpanel()
	self._bootstrap_storage()

func _bootstrap_sidepanel():
	self.sidepanel = self.SidepanelTempl.instance()
	logv("sidepanel created: %s" % self.sidepanel)

	var sidepanel_root = Global.Editor.ObjectLibraryPanel.get_parent()
	sidepanel_root.add_child(self.sidepanel)
	logv("Sidepanel added")

	self.sidepanel.toggled = true
	logv("Toggle set")

func _bootstrap_selectpanel():
	logv("Boostrapping SelectPanel")
	var stool_panel = Global.Editor.Toolset.GetToolPanel("SelectTool")
	self.stool_toggle = stool_panel.CreateButton("Dropshadow Editor", "")
	logv("Created toggle button: %s" % self.stool_toggle)
	self.stool_toggle.toggle_mode = true
	self.stool_toggle.connect("toggled", self, "on_dropshadow_toggle")
	logv("Connected button")

func _bootstrap_storage():
	logv("Bootstrapping storage")
	if Global.World.GetNodeByID(STORAGE_NODE_ID) != null:
		self.storage = Global.World.GetNodeByID(STORAGE_NODE_ID)
		logv("Found existing storage node: %s" % self.storage.text)
	else:
		logv("No existing storage node found, creating new one")
		self.storage = Global.World.AllLevels[0].Texts.CreateText()
		self.storage.Load({
			"text": "{}",
			"position": var2str(Vector2(-100000, -10000)),
			"font_name": "Papyrus",
			"font_size": 1,
			"font_color": "00000000",
			"box_shape": 0
		})
		Global.World.SetNodeID(self.storage, STORAGE_NODE_ID)
	logv("Storage node found: %s" % self.storage)

func _load_data():
	var parsed_data = JSON.parse(self.storage.text)
	if parsed_data.error != OK:
		loge("Failed to load data, aborting")
		return
	
	var loaded = parsed_data.result

	for key in loaded.keys():
		var data = ShadowStruct.new()
		var success = data.from_dict(loaded[key])
		if not success:
			logi("Failed to load %s to ShadowStruct" % loaded[key])
			continue
		
		logv("Loaded %s" % data)
		self.live_storage[key] = data




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
	const SHADOW_PARAMS = ["sun_angle", "sun_intensity", "shadow_dropoff", "shadow_strength", "blur_radius"]

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
	
	func loge(msg):
		if LOG_LEVEL > 0:
			printraw("(%d) [E] <ShadowStruct>: " % OS.get_ticks_msec())
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
		return "<ShadowStruct for 0x%X [θ: %.2f, I: %.2f, D: %.2f, S: %.2f]>" % [
			self.node_id,
			self.sun_angle,
			self.sun_intensity,
			self.shadow_dropoff,
			self.shadow_strength
		]

	func as_dict() -> Dictionary:
		var rval = {
			"node_id": self.node_id
		}
		for key in SHADOW_PARAMS:
			rval[key] = self.get(key)
		
		return rval

	func restore():
		if not Engine.has_meta("Global"):
			print("Global meta-val not found on Engine, aborting")
			return false
		
		if self.node_id == null:
			logi("Ignoring attempt o resture ShadowStruct with no NodeID")
			return false
		
		var Global = Engine.get_meta("Global")
		var prop = Global.World.GetNodeByID(self.node_id)
		if prop == null:
			logi("Attempted to restore ShadowStruct with invalid NodeID: %s" % self.node_id)
			return false

		return self.apply(prop)

	func apply(prop):
		match SelectTool.GetSelectableType(prop):
			SelectableTypes.Obj, 			\
			SelectableTypes.PortalClosed, 	\
			SelectableTypes.PortalFree:
				var shader_mat = ShaderMaterial.new()
				shader_mat.shader = DropShader

				for val in SHADOW_PARAMS:
					shader_mat.set_shader_param(val, self.get(val))

				shader_mat.set_shader_param("node_rot", prop.rotation)

				prop.Sprite.material = shader_mat
				
				return true
			_:
				logv("Invalid Prop type, ignoring")
				return false

	func from_prop(prop):
		match SelectTool.GetSelectableType(prop):
			SelectableTypes.Obj, 			\
			SelectableTypes.PortalClosed, 	\
			SelectableTypes.PortalFree:
				var shader_mat = ShaderMaterial.new()
				shader_mat.shader = DropShader

				for val in SHADOW_PARAMS:
					self.set(val, shader_mat.get_shader_param(val))
			_:
				logv("Invalid Prop type, ignoring")
				return

	func from_dict(dict: Dictionary):
		if not dict.has("node_id"):
			loge("Aborting load, dictionary has no NodeID set")
			return false

		for key in SHADOW_PARAMS:
			if dict.has(key):
				self.set(key, dict[key])
		
		self.node_id = dict["node_id"]
		return true
