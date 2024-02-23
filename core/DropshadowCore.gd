class_name DropshadowCore
var script_class = "tool"


var ShadowShader
var ShadowMaterial
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
const SHADOW_NODE_NAME = "5D03"

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

enum SHADOW_Z_MODE {
	Prop   = 0,
	Layer  = 1
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
	
	self.ShadowShader = ResourceLoader.load(RES_PATH + "shader/ShadowShader.shader", "Shader", false)
	self.ShadowMaterial = ResourceLoader.load(RES_PATH + "shader/ShadowMaterial.material", "ShaderMaterial", false)
	self.SidepanelScene = load("res://dropshadower/ui/ShadowEditPanel.tscn")
	logv("Shader and Scenes loaded")

	Engine.set_meta("DropshadowGlobal", Global)
	Engine.set_meta("DropshadowScript", Script)
	Engine.set_meta("DropshadowCore", self)
	logv("Engine meta set")


	self._bootstrap_sidepanel()
	self._bootstrap_selectpanel()
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
		
		if Global.ModMapData != null:
			logv("ModMapData found and legacy data found, migrating")
			self.using_legacy_storage = false
			self.storage = self._internal_storage
			self.legacy_storage_node.queue_free()
			Global.World.DeleteNodeByID(STORAGE_NODE_ID)
			return
	else:
		if Global.ModMapData != null:
			logv("Version 1.1.0.6+, not using text object for storage")
			self.using_legacy_storage = false
			return
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
	var cull_list = []
	for entry in self.storage.keys():
		var shadow_data := ShadowStruct.new()
		shadow_data.from_dict(self.storage[entry])
		logv("Loaded for 0x%X, data: %s" % [int(entry), shadow_data])
		var err = shadow_data.restore()
		if err == ERR_INVALID_DATA:
			Global.ModMapData["Dropshadower"].erase(entry)
		if err != OK:
			loge("Failed to restore shadow data, error was 0x%X" % err)
			continue
		else:
			if self.using_legacy_storage:
				self.storage.erase(entry)
			self.storage[int(entry)] = shadow_data.as_dict()
	
# ===== SHADOW FUNCS =====
func node_has_shadow(node: Node2D) -> bool:
	if node.Sprite == null: return false
	if not node.has_meta("dropshadow_enabled"): return false
	return true

func node_shadow_visible(node: Node2D) -> bool:
	if node.Sprite == null: return false
	if not node.has_meta("dropshadow_enabled"): return false
	if not node.get_node(SHADOW_NODE_NAME): return false
	
	return node.get_node(SHADOW_NODE_NAME).visible
	
func init_node_shadow(node: Node2D) -> int:
	if node.Sprite == null: return ERR_INVALID_PARAMETER
	if node.get_node(SHADOW_NODE_NAME) != null: return OK
	
	var shadow_node: Sprite = node.Sprite.duplicate(0)
	shadow_node.material = ShadowMaterial.duplicate(true)
	shadow_node.z_as_relative = true
	
	shadow_node.name = SHADOW_NODE_NAME
	node.set_meta("dropshadow_enabled", true)
	
	node.add_child(shadow_node, true)
	node.move_child(shadow_node, 0)


	node.connect("tree_exiting", self, "_handle_node_delete", [node])
	
	logv("Created shadow node: %s" % shadow_node)
	
	return OK

func get_node_shadow(node):
	if not node_has_shadow(node):
		return ERR_INVALID_PARAMETER
	
	return node.get_node(SHADOW_NODE_NAME)

	
func set_node_shadow(node, 
		sun_angle, 
		sun_intensity, 
		shadow_quality, 
		shadow_steps, 
		shadow_strength, 
		blur_radius
  ):
	if not node_has_shadow(node): 
		logv("Unable to set shadow on node without shadow node")
		return ERR_INVALID_PARAMETER
		
	var node_shadow = node.get_node(SHADOW_NODE_NAME)
	node_shadow.visible = true
	var mat = node_shadow.material
	logv("Setting shadow for node: %s, shadow mat: %s" % [node, mat])

	mat.set_shader_param("sun_angle", sun_angle)
	mat.set_shader_param("sun_intensity", sun_intensity / 10)
	mat.set_shader_param("shadow_quality", shadow_quality)
	mat.set_shader_param("shadow_steps", shadow_steps)
	mat.set_shader_param("shadow_strength", shadow_strength)
	mat.set_shader_param("blur_radius", blur_radius)
	mat.set_shader_param("mirror_shadow", -1 if node.Mirror else 1)
	
	var node_rotation = node.global_rotation
	mat.set_shader_param("node_rotation", node_rotation)


	return

func set_node_shadow_z(node: Node2D, z_mode):
	if not node_has_shadow(node):
		logv("Unable to set Z-mode of node with no shadow")
		return ERR_INVALID_PARAMETER
	
	var node_shadow = node.get_node(SHADOW_NODE_NAME)
	logv("Setting node z-level to %s" % z_mode)

	match z_mode:
		SHADOW_Z_MODE.Prop:
			node_shadow.z_index = 0
			node_shadow.z_as_relative = true
		SHADOW_Z_MODE.Layer:
			node_shadow.z_index = -1
			node_shadow.z_as_relative = true
		_:
			pass

	logv("Set z-index to %d" % node_shadow.z_index)
	
	return OK

func save_node_shadow(node: Node2D) -> int:
	logv("Saving shadow for %s" % node)
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

func load_node_shadow(node: Node2D):
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

	node.get_node(SHADOW_NODE_NAME).visible = false
	self.storage.erase(node.get_meta("node_id"))
	if self.using_legacy_storage:
		self.update_legacy_data()



func _handle_node_delete(node):
	var node_id = node.get_meta("node_id")
	logv("Node %s (%d) was deleted, removing entry %s" % [node, node_id, JSON.print(self.storage[node_id])])
	Global.ModMapData["Dropshadower"].erase(node_id)
	logv("post deletion %s (%d) was deleted, removing entry %s" % [node, node_id, JSON.print(self.storage[node_id])])

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
	var shadow_quality 	:= 8
	var shadow_steps	:= 4
	var shadow_strength := 1.0
	var blur_radius		:= 10.0
	var force_z			:= false
	var mirror_shadow	:= 1
	var dropoff_enabled := true


	var DropShader
	var ShadowMaterial
	var SelectTool
	var Global
	var DropshadowCore

	# ===== LOGGING =====
	const LOG_LEVEL = 4
	const SHADOW_PARAMS = [
		"sun_angle", 
		"sun_intensity", 
		"shadow_quality", 
		"shadow_steps", 
		"shadow_strength", 
		"blur_radius",
		"mirror_shadow"
	]

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
			"node_id": self.node_id,
			"force_z": self.force_z
		}
		for key in SHADOW_PARAMS:
			rval[key] = self.get(key)
		
		return rval

	func _init():
		self.Global = Engine.get_meta("DropshadowGlobal")
		self.DropshadowCore = Engine.get_meta("DropshadowCore")
		self.SelectTool = Global.Editor.Tools["SelectTool"]
		self.DropShader = ResourceLoader.load(RES_PATH + "shader/ShadowShader.shader", "Shader", false)
		self.ShadowMaterial = ResourceLoader.load(RES_PATH + "shader/ShadowMaterial.material", "ShaderMaterial", false)

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

		DropshadowCore.init_node_shadow(prop)

		return self.apply(prop)

	func apply(prop) -> int:
		match SelectTool.GetSelectableType(prop):
			SelectableTypes.Obj, 			\
			SelectableTypes.PortalClosed, 	\
			SelectableTypes.PortalFree:
				var shader_mat = ShadowMaterial.duplicate(true)

				for val in SHADOW_PARAMS:
					shader_mat.set_shader_param(val, self.get(val))

				shader_mat.set_shader_param("node_rotation", prop.global_rotation)
				shader_mat.set_shader_param("mirror_shadow", -1 if prop.Mirror else 1)

				var shadow_node = prop.get_node(SHADOW_NODE_NAME)
				shadow_node.material = shader_mat
				shadow_node.z_index = -1 if self.force_z else 0
				shadow_node.z_as_relative = true

				
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
				if not DropshadowCore.node_has_shadow(prop): return ERR_INVALID_PARAMETER
				var shadow_node = prop.get_node(SHADOW_NODE_NAME)
				var shader_mat = shadow_node.material

				if prop.has_meta("node_id"):
					self.node_id = prop.get_meta("node_id")
					logv("Got node_id: 0x%X" % self.node_id)

				self.force_z = shadow_node.z_index == -1

				logv("Material: %s" % shader_mat)
				
				for val in SHADOW_PARAMS:
					if shader_mat.get_shader_param(val) == null: continue
					self.set(val, shader_mat.get_shader_param(val))
					logv("Set param %s to %d (%d)" % [val, self.get(val), shader_mat.get_shader_param(val)])
				
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
		self.force_z = dict["force_z"]
		return OK