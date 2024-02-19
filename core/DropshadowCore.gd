class_name DropshadowCore
var script_class = "tool"


var ShadowShader
var SelectTool
var SidepanelScene

var sidepanel
var sidepanel_toggle

var storage setget _set_storage, _get_storage
var _internal_storage = {}
var legacy_storage_node
var using_legacy_storage = false


const RES_PATH = "res://dropshadower/"
const STORAGE_NODE_ID = 0x954AD03

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

# ===== DD MOD FUNCTIONS =====
func start() -> void:
	logi("Dropshadow Mod Startup")
	logi("Loading dropshadow.zip for UI")
	var err = ProjectSettings.load_resource_pack(Global.Root + "../dropshadower.zip")
	if err != OK:
		loge("Loading dropshadower.zip failed, aborting")
		return
	
	self.ShadowShader = ResourceLoader.load(RES_PATH + "shader/ShadowShader.shader", "Shader", true)
	self.SidepanelScene = load("res://dropshadower/ui/ShadowEditPanel.tscn")
	logv("Shader and Scenes loaded")

	Engine.set_meta("DropshadowGlobal", Global)
	Engine.set_meta("DropshadowScript", Script)
	Engine.set_meta("DropshadowCore", self)
	logv("Engine meta set")

	

	self._bootstrap_sidepanel()
	self._bootstrap_selectpanel()
	if Global.ModMapData == null:
		self._bootstrap_legacy_storage()
	self._load_data()


# ===== BOOSTRAPPING =====
func _bootstrap_sidepanel() -> void:
	self.sidepanel = SidepanelScene.instance()
	
	var sidepanel_root = Global.Editor.ObjectLibraryPanel.get_parent()
	sidepanel_root.add_child(self.sidepanel)

	self.sidepanel.toggled = false
	logv("Sidepanel bootstrap completed")

func _bootstrap_selectpanel() -> void:
	var select_panel = Global.Editor.Toolset.GetToolPanel("SelectTool")
	self.sidepanel_toggle = select_panel.CreateButton("Dropshadow Editor", "")
	self.sidepanel_toggle.toggle_mode = true
	self.sidepanel_toggle.connect("toggled", self, "on_sidepanel_toggle")
	logv("SelectTool Panel Button added")

func _bootstrap_legacy_storage() -> void:
	self.using_legacy_storage = true
	if Global.World.GetNodeByID(STORAGE_NODE_ID) != null:
		self.legacy_storage_node = Global.World.GetNodeByID(STORAGE_NODE_ID)
		var data_parsed: JSONParseResult = JSON.parse(self.legacy_storage_node.text)
		if data_parsed.error != OK:
			loge("Failed to load legacy storage data, error was %s" % data_parsed.error)
			return
		self.storage = data_parsed.result
		logv("Loaded legacy data: %s" % data_parsed.result)
	else:
		logv("Creating legacy storage Text object")
		self.legacy_storage_node = Global.World.AllLevels[0].Texts.CreateText()
		self.legacy_storage_node.Load({
			"text": "{}",
			"position": var2str(Vector2(-100000, -10000)),
			"font_name": "Papyrus",
			"font_size": 1,
			"font_color": "00000000",
			"box_shape": 0
		})
		self.legacy_storage_node.set_meta("node_id", STORAGE_NODE_ID)
		Global.World.SetNodeID(self.legacy_storage_node, STORAGE_NODE_ID)
	
	

func _load_data() -> void:
	logi("Loading shadow data")
	logv("ModMapData for Dropshadower: %s" % JSON.print(self.storage, "\t"))

	for entry in self.storage.keys():
		var shadow_data := ShadowStruct.new()
		shadow_data.from_dict(self.storage[entry])
		logv("Loaded for 0x%X, data: %s" % [int(entry), shadow_data])
		var err = shadow_data.restore()
		if err != OK:
			loge("Failed to restore shadow data, error was 0x%X" % err)
		if self.using_legacy_storage:
			self.storage.erase(entry)
		self.storage[int(entry)] = shadow_data.as_dict()

# ===== SHADOW FUNCS =====
func set_node_shadow(node: Node2D) -> int:
	logv("Setting shadow for %s" % node)
	if node == null or not is_instance_valid(node): return ERR_INVALID_PARAMETER
	var shadow_data = ShadowStruct.new()
	var err = shadow_data.from_prop(node)
	if err != OK:
		logv("Creating ShadowStruct failed: 0x%X" % err)
		return err
	
	if self.using_legacy_storage:
		self._internal_storage[shadow_data.node_id] = shadow_data.as_dict()
		self.update_legacy_data()
	else:
		self.storage[shadow_data.node_id] = shadow_data.as_dict()

	return OK

func get_node_shadow(node: Node2D):
	if node == null or not is_instance_valid(node): return null
	if not node.has_meta("node_id"):
		loge("Provided node has no NodeID, returning null")
		return null
	
	var shadow_data = ShadowStruct.new()
	var err = shadow_data.from_prop(node)
	if err != OK:
		logv("Creating ShadowStruct failed: 0x%X" % err)
		return err
	return self.storage[node.get_meta("node_id")]

func erase_node_shadow(node: Node2D):
	if node == null or not is_instance_valid(node): return null
	if not node.has_meta("node_id"):
		loge("Provided node has no NodeID, returning null")
		return null

	self.storage.erase(node.get_meta("node_id"))
	if self.using_legacy_storage:
		self.update_legacy_data()

func update_legacy_data():
	if self.legacy_storage_node != null:
		self.legacy_storage_node.text = JSON.print(self.storage)
		logv("Updated text node: %s" % JSON.print(self.storage, "\t"))
	
func on_sidepanel_toggle(pressed):
	self.sidepanel.toggled = pressed

# ===== GETTERS/SETTERS =====

# --- self.storage get
func _get_storage() -> Dictionary:
	if self.using_legacy_storage:
		return self._internal_storage

	if Global.ModMapData["Dropshadower"] == null:
		Global.ModMapData["Dropshadower"] = {}
	
	return Global.ModMapData["Dropshadower"]

# --- self.storage set
func _set_storage(val: Dictionary) -> void:
	if self.using_legacy_storage:
		self._internal_storage = val
	else:
		Global.ModMapData["Dropshadower"] = val

class ShadowStruct extends Reference:
	var node_id: int
	var sun_angle 		:= 0.0
	var sun_intensity 	:= 1.0
	var shadow_dropoff 	:= 1.0
	var shadow_strength := 1.0
	var blur_radius		:= 10.0
	var dropoff_enabled := true

	var DropShader
	var SelectTool
	var Global

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

	func _to_string():
		return self.as_dict()

	func as_dict() -> Dictionary:
		var rval = {
			"node_id": self.node_id
		}
		for key in SHADOW_PARAMS:
			rval[key] = self.get(key)
		
		return rval

	func _init():
		self.Global = Engine.get_meta("DropshadowGlobal")
		self.SelectTool = Global.Editor.Tools["SelectTool"]
		self.DropShader = ResourceLoader.load(Global.Root + "../dropshadower/shader/ShadowShader.shader", "", true)

	func restore() -> int:
		if not Engine.has_meta("DropshadowGlobal"):
			print("Global meta-val not found on Engine, aborting")
			return ERR_BUG
		
		if self.node_id == null:
			logi("Ignoring attempt to restore ShadowStruct with no NodeID")
			return ERR_INVALID_DATA
		
		var prop = Global.World.GetNodeByID(self.node_id)
		if prop == null:
			logi("Attempted to restore ShadowStruct with invalid NodeID: %s" % self.node_id)
			return ERR_INVALID_DATA

		return self.apply(prop)

	func apply(prop) -> int:
		match SelectTool.GetSelectableType(prop):
			SelectableTypes.Obj, 			\
			SelectableTypes.PortalClosed, 	\
			SelectableTypes.PortalFree:
				var shader_mat = ShaderMaterial.new()
				shader_mat.shader = DropShader

				for val in SHADOW_PARAMS:
					shader_mat.set_shader_param(val, self.get(val))

				shader_mat.set_shader_param("node_rotation", prop.global_rotation)

				prop.Sprite.material = shader_mat
				
				return OK
			_:
				logv("Invalid Prop type, ignoring")
				return ERR_INVALID_PARAMETER

	func from_prop(prop) -> int:
		logv("Creating ShadowStruct from prop: %s" % prop)
		match SelectTool.GetSelectableType(prop):
			SelectableTypes.Obj, 			\
			SelectableTypes.PortalClosed, 	\
			SelectableTypes.PortalFree:
				logv("Got SelectableType")
				var shader_mat = prop.Sprite.material

				if prop.has_meta("node_id"):
					self.node_id = prop.get_meta("node_id")
					logv("Got node_id: 0x%X" % self.node_id)

				for val in SHADOW_PARAMS:
					self.set(val, shader_mat.get_shader_param(val))
					logv("Set param %s to %d" % [val, self.get(val)])
				
				return OK
			_:
				logv("Invalid Prop type, ignoring")
				return ERR_INVALID_PARAMETER

	func from_dict(dict: Dictionary):
		if not dict.has("node_id"):
			loge("Aborting load, dictionary has no NodeID set")
			return ERR_INVALID_DATA
		logv("Starting load from_dict")

		for key in SHADOW_PARAMS:
			if dict.has(key):
				self.set(key, dict[key])
		
		self.node_id = dict["node_id"]
		return OK
