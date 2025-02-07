#
# © 2024-present https://github.com/cengiz-pz
#

class_name DeeplinkExportConfig extends RefCounted

const PLUGIN_NODE_TYPE_NAME = "@pluginNodeName@"
const PLUGIN_NAME: String = "@pluginName@"

const CONFIG_FILE_PATH: String = "res://addons/" + PLUGIN_NAME + "/export.cfg"

const CONFIG_FILE_KEY_LABEL: String = "label"
const CONFIG_FILE_KEY_IS_AUTO_VERIFY: String = "is_auto_verify"
const CONFIG_FILE_KEY_IS_DEFAULT: String = "is_default"
const CONFIG_FILE_KEY_IS_BROWSABLE: String = "is_browsable"
const CONFIG_FILE_KEY_SCHEME: String = "scheme"
const CONFIG_FILE_KEY_HOST: String = "host"
const CONFIG_FILE_KEY_PATH_PREFIX: String = "path_prefix"

const DEFAULT_LABEL: String = ""
const DEFAULT_IS_AUTO_VERIFY: bool = true
const DEFAULT_IS_DEFAULT: bool = true
const DEFAULT_IS_BROWSABLE: bool = true
const DEFAULT_PATH_PREFIX: String = "/"

var deeplinks: Array[DeeplinkExportConfigItem]


func _init():
	deeplinks = []


func export_config_file_exists() -> bool:
	return FileAccess.file_exists(CONFIG_FILE_PATH)


func load_export_config_from_file() -> Error:
	push_warning("Loading export config from file!")

	var __result = Error.OK

	var __config_file = ConfigFile.new()

	var __load_result = __config_file.load(CONFIG_FILE_PATH)
	if __load_result == Error.OK:
		var __config_file_sections = __config_file.get_sections()
		for __config_file_section in __config_file_sections:
			push_warning("Processing config file section %s" % __config_file_section)
			if not __config_file.has_section_key(__config_file_section, CONFIG_FILE_KEY_SCHEME) \
					or not __config_file.has_section_key(__config_file_section, CONFIG_FILE_KEY_HOST):
				__result == Error.ERR_INVALID_DATA
				push_error("""Invalid export config in section "%s" of file "%s".""" % [__config_file_section, CONFIG_FILE_PATH])
			else:
				deeplinks.append(
					DeeplinkExportConfigItem.new()
						.set_label(__config_file.get_value(__config_file_section, CONFIG_FILE_KEY_LABEL, DEFAULT_LABEL))
						.set_is_auto_verify(__config_file.get_value(__config_file_section, CONFIG_FILE_KEY_IS_AUTO_VERIFY, DEFAULT_IS_AUTO_VERIFY))
						.set_is_default(__config_file.get_value(__config_file_section, CONFIG_FILE_KEY_IS_DEFAULT, DEFAULT_IS_DEFAULT))
						.set_is_browsable(__config_file.get_value(__config_file_section, CONFIG_FILE_KEY_IS_BROWSABLE, DEFAULT_IS_BROWSABLE))
						.set_scheme(__config_file.get_value(__config_file_section, CONFIG_FILE_KEY_SCHEME))
						.set_host(__config_file.get_value(__config_file_section, CONFIG_FILE_KEY_HOST))
						.set_path_prefix(__config_file.get_value(__config_file_section, CONFIG_FILE_KEY_PATH_PREFIX, DEFAULT_PATH_PREFIX))
				)
	else:
		__result = Error.ERR_CANT_OPEN
		push_error("Failed to open export config file %s!" % CONFIG_FILE_PATH)

	if __result == OK:
		print_loaded_config()

	return __result


func load_export_config_from_node() -> Error:
	push_warning("Loading export config from node!")

	var __result = OK

	var __deeplink_nodes: Array = get_plugin_nodes(EditorInterface.get_edited_scene_root())
	if __deeplink_nodes.is_empty():
		var __main_scene = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
		__deeplink_nodes = get_plugin_nodes(__main_scene)
		if __deeplink_nodes.is_empty():
			push_error("%s failed to find %s node!" % [PLUGIN_NAME, PLUGIN_NODE_TYPE_NAME])

	for __node in __deeplink_nodes:
		var __deeplink_node = __node as Deeplink
		deeplinks.append(
			DeeplinkExportConfigItem.new()
				.set_label(__deeplink_node.label)
				.set_is_auto_verify(__deeplink_node.is_auto_verify)
				.set_is_default(__deeplink_node.is_default)
				.set_is_browsable(__deeplink_node.is_browsable)
				.set_scheme(__deeplink_node.scheme)
				.set_host(__deeplink_node.host)
				.set_path_prefix(__deeplink_node.path_prefix)
		)

	print_loaded_config()

	return __result


func print_loaded_config() -> void:
	push_warning("Loaded export configuration settings:")
	for __config in deeplinks:
		push_warning("---------------------------------------------------")
		push_warning("... label: %s" % __config.label)
		push_warning("... is_auto_verify: %s" % ("true" if __config.is_auto_verify else "false"))
		push_warning("... is_default: %s" % ("true" if __config.is_default else "false"))
		push_warning("... is_browsable: %s" % ("true" if __config.is_browsable else "false"))
		push_warning("... scheme: %s" % __config.scheme)
		push_warning("... host: %s" % __config.host)
		push_warning("... path_prefix: %s" % __config.path_prefix)


func get_plugin_nodes(a_node: Node) -> Array:
	var __result: Array = []

	if a_node is Deeplink:
		__result.append(a_node)

	if a_node.get_child_count() > 0:
		for __child in a_node.get_children():
			__result.append_array(get_plugin_nodes(__child))

	return __result
