#
# © 2024-present https://github.com/cengiz-pz
#

@tool
extends EditorPlugin

const PLUGIN_NODE_TYPE_NAME: String = "@pluginNodeType@"
const PLUGIN_PARENT_NODE_TYPE: String = "Node"
const PLUGIN_NAME: String = "@pluginName@"
const PLUGIN_VERSION: String = "@pluginVersion@"
const PLUGIN_DEPENDENCIES: Array = [ @pluginDependencies@ ]

var android_export_plugin: AndroidExportPlugin
var ios_export_plugin: IosExportPlugin


func _enter_tree() -> void:
	add_custom_type(PLUGIN_NODE_TYPE_NAME, PLUGIN_PARENT_NODE_TYPE, preload("@pluginNodeType@.gd"), preload("icon.png"))
	android_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(android_export_plugin)
	ios_export_plugin = IosExportPlugin.new()
	add_export_plugin(ios_export_plugin)


func _exit_tree() -> void:
	remove_custom_type(PLUGIN_NODE_TYPE_NAME)
	remove_export_plugin(android_export_plugin)
	android_export_plugin = null
	remove_export_plugin(ios_export_plugin)
	ios_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = PLUGIN_NAME

	const DEEPLINK_ACTIVITY_FORMAT = """
		<activity
			android:name="org.godotengine.plugin.android.deeplink.DeeplinkActivity"
			android:theme="@android:style/Theme.Translucent.NoTitleBar.Fullscreen"
			android:excludeFromRecents="true"
			android:launchMode="singleTask"
			android:exported="true"
			android:noHistory="true">

			%s
		</activity>
"""

	const DEEPLINK_INTENT_FILTER_FORMAT = """
			<intent-filter android:label="%s" %s>
				<action android:name="android.intent.action.VIEW" />
				%s
				%s
				<data android:scheme="%s"
					android:host="%s"
					android:pathPrefix="%s" />
			</intent-filter>
"""

	const DEEPLINK_INTENT_FILTER_AUTO_VERIFY_PROPERTY = "android:autoVerify=\"true\""
	const DEEPLINK_INTENT_FILTER_DEFAULT_CATEGORY = "<category android:name=\"android.intent.category.DEFAULT\" />"
	const DEEPLINK_INTENT_FILTER_BROWSABLE_CATEGORY = "<category android:name=\"android.intent.category.BROWSABLE\" />"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		if platform is EditorExportPlatformAndroid:
			return true
		return false


	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["%s/bin/debug/%s-%s-debug.aar" % [_plugin_name, _plugin_name, PLUGIN_VERSION]])
		else:
			return PackedStringArray(["%s/bin/release/%s-%s-release.aar" % [_plugin_name, _plugin_name, PLUGIN_VERSION]])


	func _get_name() -> String:
		return _plugin_name


	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(PLUGIN_DEPENDENCIES)


	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		var __filters: String = ""

		var __deeplink_nodes: Array = Deeplink.get_deeplink_nodes(EditorInterface.get_edited_scene_root())

		for __node in __deeplink_nodes:
			var __deeplink_node = __node as Deeplink
			__filters += DEEPLINK_INTENT_FILTER_FORMAT % [
						__deeplink_node.label,
						DEEPLINK_INTENT_FILTER_AUTO_VERIFY_PROPERTY if __deeplink_node.is_auto_verify else "",
						DEEPLINK_INTENT_FILTER_DEFAULT_CATEGORY if __deeplink_node.is_default else "",
						DEEPLINK_INTENT_FILTER_BROWSABLE_CATEGORY if __deeplink_node.is_browsable else "",
						__deeplink_node.scheme,
						__deeplink_node.host,
						__deeplink_node.path_prefix
					]

		return DEEPLINK_ACTIVITY_FORMAT % __filters


class IosExportPlugin extends EditorExportPlugin:
	var _plugin_name = PLUGIN_NAME
	var _export_path: String


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		if platform is EditorExportPlatformIOS:
			return true
		return false


	func _get_name() -> String:
		return _plugin_name


	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		_export_path = path


	func _export_end() -> void:
		_regenerate_entitlements_file()


	func _regenerate_entitlements_file() -> void:
		if _export_path:
			if _export_path.ends_with(EXPORT_FILE_SUFFIX):
				var __project_path = ProjectSettings.globalize_path("res://")
				print("******** PROJECT PATH='%s'" % __project_path)
				var __directory_path = "%s%s" % [__project_path, _export_path.trim_suffix(EXPORT_FILE_SUFFIX)]
				if DirAccess.dir_exists_absolute(__directory_path):
					var __project_name = _get_project_name_from_path(__directory_path)
					var __file_path = "%s/%s.entitlements" % [__directory_path, __project_name]
					print("******** ENTITLEMENTS FILE PATH='%s'" % __file_path)
					if FileAccess.file_exists(__file_path):
						DirAccess.remove_absolute(__file_path)
					var __file = FileAccess.open(__file_path, FileAccess.WRITE)
					if __file:
						__file.store_string(ENTITLEMENTS_FILE_HEADER)

						var __deeplink_nodes: Array = Deeplink.get_deeplink_nodes(EditorInterface.get_edited_scene_root())
						for __node in __deeplink_nodes:
							var __deeplink_node = __node as Deeplink
							__file.store_line("\t\t<string>applinks:%s</string>" % __deeplink_node.host)
							# As opposed to Android, in iOS __deeplink_node.scheme, __deeplink_node.path_prefix are
							# configured on the server side (apple-app-site-association file)

						__file.store_string(ENTITLEMENTS_FILE_FOOTER)
						__file.close()
					else:
						printerr("Couldn't open file '%s' for writing." % __file_path)
				else:
					printerr("Directory '%s' doesn't exist." % __directory_path)
			else:
				printerr("Unexpected export path '%s'" % _export_path)
		else:
			printerr("Export path is not defined.")


	func _get_project_name_from_path(a_path: String) -> String:
		var __result = ""

		var __split = a_path.rsplit("/", false, 1)
		if __split.size() > 1:
			__result = __split[1]

		return __result