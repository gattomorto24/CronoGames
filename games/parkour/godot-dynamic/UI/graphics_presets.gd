extends RefCounted
class_name ParkourGraphicsPresets

enum Preset {
	PERFORMANCE,
	LOW,
	MEDIUM,
	HIGH,
	ULTRA,
}

const LABELS := PackedStringArray([
	"Performance",
	"Bassa",
	"Media",
	"Alta",
	"Ultra",
])

const DETAILS := PackedStringArray([
	"Scala 75% · ombre off · effetti ambiente off · distanza breve",
	"Scala 85% · ombre minime · SSAO/Glow off · distanza ridotta",
	"Scala 100% · ombre soft low · SSAO + Glow · MSAA 2x",
	"Scala 100% · ombre soft high · SSAO/SSIL · nebbia + SSR · MSAA 4x",
	"FSR 2 nativo · ombre soft ultra · effetti completi · distanza massima",
])

static var _original_shadow_state: Dictionary = {}


static func apply(
	preset: int,
	tree: SceneTree,
	viewport: Viewport,
) -> Dictionary:
	var profile := _profile(clampi(preset, Preset.PERFORMANCE, Preset.ULTRA))
	_apply_viewport(profile, viewport)
	_apply_environment(profile, tree)
	_apply_lights(profile, tree)
	_apply_cameras(profile, tree)
	return profile


static func label(preset: int) -> String:
	return LABELS[clampi(preset, Preset.PERFORMANCE, Preset.ULTRA)]


static func detail(preset: int) -> String:
	return DETAILS[clampi(preset, Preset.PERFORMANCE, Preset.ULTRA)]


static func _apply_viewport(profile: Dictionary, viewport: Viewport) -> void:
	if viewport == null:
		return
	var viewport_rid := viewport.get_viewport_rid()
	var render_scale := float(profile["render_scale"])
	var scaling_mode := int(profile["scaling_mode"])
	var msaa := int(profile["msaa"])
	if RenderingServer.has_method("viewport_set_scaling_3d_scale"):
		RenderingServer.call(
			"viewport_set_scaling_3d_scale",
			viewport_rid,
			render_scale,
		)
	if RenderingServer.has_method("viewport_set_scaling_3d_mode"):
		RenderingServer.call(
			"viewport_set_scaling_3d_mode",
			viewport_rid,
			scaling_mode,
		)
	if RenderingServer.has_method("viewport_set_msaa_3d"):
		RenderingServer.call("viewport_set_msaa_3d", viewport_rid, msaa)
	if RenderingServer.has_method("viewport_set_use_taa"):
		RenderingServer.call(
			"viewport_set_use_taa",
			viewport_rid,
			bool(profile["taa"]),
		)
	viewport.scaling_3d_scale = render_scale
	viewport.scaling_3d_mode = scaling_mode as Viewport.Scaling3DMode
	viewport.msaa_3d = msaa as Viewport.MSAA
	viewport.use_taa = bool(profile["taa"])
	viewport.fsr_sharpness = float(profile["fsr_sharpness"])


static func _apply_environment(
	profile: Dictionary,
	tree: SceneTree,
) -> void:
	if tree == null:
		return
	for candidate: Node in tree.root.find_children(
		"*",
		"WorldEnvironment",
		true,
		false,
	):
		var world_environment := candidate as WorldEnvironment
		if world_environment == null or world_environment.environment == null:
			continue
		var environment := world_environment.environment
		environment.ssao_enabled = bool(profile["ssao"])
		environment.ssil_enabled = bool(profile["ssil"])
		environment.glow_enabled = bool(profile["glow"])
		environment.volumetric_fog_enabled = bool(profile["volumetric_fog"])
		environment.ssr_enabled = bool(profile["ssr"])
		if environment.ssao_enabled:
			environment.ssao_intensity = float(profile["ssao_intensity"])
		if environment.ssil_enabled:
			environment.ssil_intensity = float(profile["ssil_intensity"])


static func _apply_lights(profile: Dictionary, tree: SceneTree) -> void:
	if tree == null:
		return
	var shadows_enabled := bool(profile["shadows"])
	for candidate: Node in tree.root.find_children(
		"*",
		"Light3D",
		true,
		false,
	):
		var light := candidate as Light3D
		if light == null:
			continue
		var instance_id := light.get_instance_id()
		if not _original_shadow_state.has(instance_id):
			_original_shadow_state[instance_id] = light.shadow_enabled
		light.shadow_enabled = (
			bool(_original_shadow_state[instance_id])
			and shadows_enabled
		)
		if light is DirectionalLight3D:
			light.directional_shadow_max_distance = float(
				profile["shadow_distance"],
			)
	var quality := int(profile["shadow_quality"])
	if RenderingServer.has_method(
		"directional_soft_shadow_filter_set_quality",
	):
		RenderingServer.call(
			"directional_soft_shadow_filter_set_quality",
			quality,
		)
	if RenderingServer.has_method(
		"positional_soft_shadow_filter_set_quality",
	):
		RenderingServer.call(
			"positional_soft_shadow_filter_set_quality",
			quality,
		)


static func _apply_cameras(profile: Dictionary, tree: SceneTree) -> void:
	if tree == null:
		return
	for candidate: Node in tree.root.find_children(
		"*",
		"Camera3D",
		true,
		false,
	):
		var camera := candidate as Camera3D
		if camera != null:
			camera.far = float(profile["camera_far"])


static func _profile(preset: int) -> Dictionary:
	match preset:
		Preset.PERFORMANCE:
			return {
				"name": label(preset),
				"render_scale": 0.75,
				"scaling_mode": Viewport.SCALING_3D_MODE_BILINEAR,
				"msaa": Viewport.MSAA_DISABLED,
				"taa": false,
				"fsr_sharpness": 0.2,
				"shadows": false,
				"shadow_quality": 0,
				"shadow_distance": 55.0,
				"camera_far": 130.0,
				"ssao": false,
				"ssao_intensity": 0.0,
				"ssil": false,
				"ssil_intensity": 0.0,
				"glow": false,
				"volumetric_fog": false,
				"ssr": false,
			}
		Preset.LOW:
			return {
				"name": label(preset),
				"render_scale": 0.85,
				"scaling_mode": Viewport.SCALING_3D_MODE_BILINEAR,
				"msaa": Viewport.MSAA_DISABLED,
				"taa": false,
				"fsr_sharpness": 0.2,
				"shadows": true,
				"shadow_quality": 1,
				"shadow_distance": 78.0,
				"camera_far": 180.0,
				"ssao": false,
				"ssao_intensity": 0.0,
				"ssil": false,
				"ssil_intensity": 0.0,
				"glow": false,
				"volumetric_fog": false,
				"ssr": false,
			}
		Preset.HIGH:
			return {
				"name": label(preset),
				"render_scale": 1.0,
				"scaling_mode": Viewport.SCALING_3D_MODE_BILINEAR,
				"msaa": Viewport.MSAA_4X,
				"taa": false,
				"fsr_sharpness": 0.2,
				"shadows": true,
				"shadow_quality": 4,
				"shadow_distance": 150.0,
				"camera_far": 340.0,
				"ssao": true,
				"ssao_intensity": 2.0,
				"ssil": true,
				"ssil_intensity": 0.9,
				"glow": true,
				"volumetric_fog": true,
				"ssr": true,
			}
		Preset.ULTRA:
			return {
				"name": label(preset),
				"render_scale": 1.0,
				"scaling_mode": Viewport.SCALING_3D_MODE_FSR2,
				"msaa": Viewport.MSAA_DISABLED,
				"taa": false,
				"fsr_sharpness": 0.15,
				"shadows": true,
				"shadow_quality": 5,
				"shadow_distance": 220.0,
				"camera_far": 440.0,
				"ssao": true,
				"ssao_intensity": 2.2,
				"ssil": true,
				"ssil_intensity": 1.0,
				"glow": true,
				"volumetric_fog": true,
				"ssr": true,
			}
		_:
			return {
				"name": label(Preset.MEDIUM),
				"render_scale": 1.0,
				"scaling_mode": Viewport.SCALING_3D_MODE_BILINEAR,
				"msaa": Viewport.MSAA_2X,
				"taa": false,
				"fsr_sharpness": 0.2,
				"shadows": true,
				"shadow_quality": 2,
				"shadow_distance": 110.0,
				"camera_far": 260.0,
				"ssao": true,
				"ssao_intensity": 1.5,
				"ssil": false,
				"ssil_intensity": 0.0,
				"glow": true,
				"volumetric_fog": false,
				"ssr": false,
			}
