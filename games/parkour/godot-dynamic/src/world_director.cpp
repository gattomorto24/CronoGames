#include "world_director.hpp"

#include "parkour_actor.hpp"

#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/box_shape3d.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/canvas_layer.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/collision_object3d.hpp>
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/directional_light3d.hpp>
#include <godot_cpp/classes/environment.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_map.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/procedural_sky_material.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/sky.hpp>
#include <godot_cpp/classes/static_body3d.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/viewport_texture.hpp>
#include <godot_cpp/classes/world_environment.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {

StaticBody3D *create_dynamic_prop(
    Node3D *parent,
    const String &name,
    const Vector3 &position,
    const Vector3 &size,
    const Color &color
) {
    StaticBody3D *body = memnew(StaticBody3D);
    body->set_name(name);
    body->set_position(position);
    body->set_collision_layer(3U);
    body->add_to_group("parkour_module");
    body->set_meta(StringName("parkour_surface"), true);

    CollisionShape3D *collision = memnew(CollisionShape3D);
    Ref<BoxShape3D> shape;
    shape.instantiate();
    shape->set_size(size);
    collision->set_shape(shape);
    body->add_child(collision);

    MeshInstance3D *visual = memnew(MeshInstance3D);
    Ref<BoxMesh> mesh;
    mesh.instantiate();
    mesh->set_size(size);
    Ref<StandardMaterial3D> material;
    material.instantiate();
    material->set_albedo(color);
    material->set_roughness(0.88F);
    mesh->set_material(material);
    visual->set_mesh(mesh);
    body->add_child(visual);

    parent->add_child(body);
    return body;
}

} // namespace

void WorldDirector::_bind_methods() {}

void WorldDirector::_ready() {
    create_input_map();
    create_environment();
    load_authored_district();
    create_physics_floor();
    create_dynamic_parkour_routes();

    const PackedStringArray arguments = OS::get_singleton()->get_cmdline_user_args();
    bool legacy_test_actor_requested = false;
    for (int index = 0; index < arguments.size(); ++index) {
        const String argument = arguments[index];
        legacy_test_actor_requested =
            legacy_test_actor_requested ||
            argument == "--climb-snapshot" ||
            argument == "--jump-snapshot" ||
            argument == "--movement-test" ||
            argument == "--climb-test" ||
            argument == "--mantle-test" ||
            argument == "--jump-test" ||
            argument == "--stumble-test" ||
            argument == "--vault-test" ||
            argument == "--balance-test";
    }

    if (legacy_test_actor_requested) {
        player_ = memnew(ParkourActor);
        player_->set_name("LegacyTestParkourActor");
        player_->set_position(Vector3(0.0, 1.15, 28.0));
        add_child(player_);
    } else if (!load_advanced_parkour_player()) {
        UtilityFunctions::push_error(
            "Dynamic Parkour non disponibile: uso temporaneamente il controller C++."
        );
        player_ = memnew(ParkourActor);
        player_->set_name("FallbackParkourActor");
        player_->set_position(Vector3(0.0, 1.15, 28.0));
        add_child(player_);
    }
    if (advanced_player_ != nullptr) {
        create_combat_enemies();
        create_stealth_world_systems();
    }

    create_interface();

    for (int index = 0; index < arguments.size(); ++index) {
        if (arguments[index] == "--snapshot") {
            snapshot_requested_ = true;
            create_overview_camera();
        } else if (arguments[index] == "--dynamic-action-snapshot") {
            dynamic_action_snapshot_requested_ = true;
            if (advanced_player_ != nullptr) {
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("move_fast");
            }
        } else if (arguments[index] == "--dynamic-ledge-snapshot") {
            dynamic_ledge_snapshot_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_advanced_ledge_test_obstacle();
                advanced_player_->set_global_position(
                    Vector3(0.0F, 0.08F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                Input::get_singleton()->action_press("go_up");
            }
        } else if (arguments[index] == "--dynamic-vault-snapshot") {
            dynamic_vault_snapshot_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_dynamic_vault_test_obstacle();
                advanced_player_->set_global_position(
                    Vector3(20.0F, 0.08F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                Input::get_singleton()->action_press("forward");
            }
        } else if (
            arguments[index] == "--dynamic-wall-climb-snapshot"
        ) {
            dynamic_wall_climb_snapshot_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_advanced_flat_wall_test_obstacle();
                advanced_player_->set_global_position(
                    Vector3(0.0F, 0.08F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("go_up");
            }
        } else if (
            arguments[index] == "--advanced-movement-test" ||
            arguments[index] == "--dynamic-movement-test"
        ) {
            advanced_movement_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                movement_test_start_ = advanced_player_->get_global_position();
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("move_fast");
            }
        } else if (
            arguments[index] == "--advanced-jump-test" ||
            arguments[index] == "--dynamic-jump-test"
        ) {
            advanced_jump_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                movement_test_start_ = advanced_player_->get_global_position();
                advanced_jump_max_height_ = movement_test_start_.y;
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("move_fast");
            }
        } else if (
            arguments[index] == "--advanced-ledge-test" ||
            arguments[index] == "--dynamic-ledge-test"
        ) {
            advanced_ledge_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_advanced_ledge_test_obstacle();
                advanced_player_->set_global_position(Vector3(0.0F, 0.08F, 0.0F));
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ = advanced_player_->get_global_position();
                Input::get_singleton()->action_press("go_up");
            }
        } else if (arguments[index] == "--dynamic-slide-test") {
            dynamic_slide_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_dynamic_slide_test_obstacle();
                advanced_player_->set_global_position(
                    Vector3(20.0F, 0.08F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ = advanced_player_->get_global_position();
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("move_fast");
            }
        } else if (
            arguments[index] == "--dynamic-predicted-jump-test"
        ) {
            dynamic_predicted_jump_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_dynamic_predicted_jump_test_course();
                advanced_player_->set_global_position(
                    Vector3(20.0F, 1.48F, 1.20F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ = advanced_player_->get_global_position();
                advanced_jump_max_height_ = movement_test_start_.y;
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("go_up");
            }
        } else if (arguments[index] == "--dynamic-vault-test") {
            dynamic_vault_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_dynamic_vault_test_obstacle();
                advanced_player_->set_global_position(
                    Vector3(20.0F, 0.08F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ = advanced_player_->get_global_position();
                advanced_jump_max_height_ = movement_test_start_.y;
                Input::get_singleton()->action_press("forward");
            }
        } else if (arguments[index] == "--dynamic-reach-test") {
            dynamic_reach_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_dynamic_reach_test_obstacle();
                advanced_player_->set_global_position(
                    Vector3(20.0F, 0.08F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ = advanced_player_->get_global_position();
                advanced_jump_max_height_ = movement_test_start_.y;
                Input::get_singleton()->action_press("forward");
            }
        } else if (
            arguments[index] == "--advanced-flat-wall-test" ||
            arguments[index] == "--dynamic-wall-climb-test"
        ) {
            advanced_flat_wall_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_advanced_flat_wall_test_obstacle();
                advanced_player_->set_global_position(Vector3(0.0F, 0.08F, 0.0F));
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ = advanced_player_->get_global_position();
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("go_up");
            }
        } else if (
            arguments[index] == "--dynamic-wall-to-wall-test"
        ) {
            dynamic_wall_to_wall_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_dynamic_wall_to_wall_test_course();
                advanced_player_->set_global_position(
                    Vector3(20.0F, 0.08F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ =
                    advanced_player_->get_global_position();
                Input::get_singleton()->action_press("forward");
                Input::get_singleton()->action_press("go_up");
            }
        } else if (
            arguments[index] == "--dynamic-edge-guard-test"
        ) {
            dynamic_edge_guard_test_requested_ = true;
            if (advanced_player_ != nullptr) {
                create_dynamic_edge_guard_test_platform();
                advanced_player_->set_global_position(
                    Vector3(20.0F, 2.015F, 0.0F)
                );
                advanced_player_->set_velocity(Vector3());
                advanced_player_->set_rotation(Vector3());
                movement_test_start_ =
                    advanced_player_->get_global_position();
                Input::get_singleton()->action_press("forward");
            }
        } else if (arguments[index] == "--climb-snapshot") {
            climb_snapshot_requested_ = true;
            create_climb_test_wall();
            player_->set_global_position(Vector3(0.0, 0.1F, 0.0));
            player_->set_velocity(Vector3());
            Input::get_singleton()->action_press("move_forward");
            Input::get_singleton()->action_press("parkour");
        } else if (arguments[index] == "--jump-snapshot") {
            jump_snapshot_requested_ = true;
            player_->set_global_position(Vector3(0.0, 0.1F, 0.0));
            player_->set_velocity(Vector3());
            Input::get_singleton()->action_press("move_forward");
        } else if (arguments[index] == "--movement-test") {
            movement_test_requested_ = true;
            movement_test_start_ = player_->get_global_position();
            Input::get_singleton()->action_press("move_forward");
        } else if (arguments[index] == "--climb-test") {
            climb_test_requested_ = true;
            create_climb_test_wall();
            player_->set_global_position(Vector3(0.0, 0.1F, 0.0));
            player_->set_velocity(Vector3());
            movement_test_start_ = player_->get_global_position();
            Input::get_singleton()->action_press("move_forward");
            Input::get_singleton()->action_press("parkour");
        } else if (arguments[index] == "--mantle-test") {
            mantle_test_requested_ = true;
            create_mantle_test_wall();
            player_->set_global_position(Vector3(0.0, 0.1F, 0.0));
            player_->set_velocity(Vector3());
            movement_test_start_ = player_->get_global_position();
            Input::get_singleton()->action_press("move_forward");
            Input::get_singleton()->action_press("parkour");
        } else if (arguments[index] == "--jump-test") {
            smart_jump_test_requested_ = true;
            player_->set_global_position(Vector3(0.0, 0.1F, 0.0));
            player_->set_velocity(Vector3());
            movement_test_start_ = player_->get_global_position();
            Input::get_singleton()->action_press("move_forward");
        } else if (arguments[index] == "--stumble-test") {
            stumble_test_requested_ = true;
            player_->set_global_position(Vector3(0.0F, 1.0F, 0.0F));
            player_->set_velocity(Vector3(0.0F, -1.0F, -7.0F));
            movement_test_start_ = player_->get_global_position();
        } else if (arguments[index] == "--vault-test") {
            vault_test_requested_ = true;
            create_vault_test_obstacle();
            player_->set_global_position(Vector3(0.0, 0.1F, 0.0));
            player_->set_velocity(Vector3());
            movement_test_start_ = player_->get_global_position();
            Input::get_singleton()->action_press("move_forward");
            Input::get_singleton()->action_press("parkour");
        } else if (arguments[index] == "--balance-test") {
            balance_test_requested_ = true;
            create_balance_test_rope();
            player_->set_global_position(Vector3(0.11F, 0.46F, 2.0F));
            player_->set_velocity(Vector3());
            movement_test_start_ = player_->get_global_position();
            Input::get_singleton()->action_press("move_forward");
        }
    }
}

void WorldDirector::create_input_map() {
    struct KeyBinding {
        const char *action;
        Key key;
    };
    const KeyBinding key_bindings[] = {
        {"move_forward", KEY_W},
        {"move_back", KEY_S},
        {"move_left", KEY_A},
        {"move_right", KEY_D},
        {"parkour", KEY_SPACE},
        {"drop", KEY_CTRL},
        {"reset_player", KEY_R},
        {"forward", KEY_W},
        {"backward", KEY_S},
        {"left", KEY_A},
        {"right", KEY_D},
        {"go_up", KEY_SPACE},
        {"move_fast", KEY_SHIFT},
        {"roll", KEY_CTRL},
        {"mouse_mode_switch", KEY_F10},
        {"assassinate", KEY_F},
        {"interact", KEY_E},
        {"toggle_map", KEY_M},
        {"map", KEY_M},
        {"pause", KEY_ESCAPE},
        {"sneak", KEY_C},
        // The imported input gatherer also polls its optional combat actions
        // every frame. Register them here so the movement-only integration
        // stays error-free even when no weapon is equipped.
        {"parry", KEY_E},
        {"block", KEY_E},
        {"light_attack", KEY_Q},
    };

    InputMap *input_map = InputMap::get_singleton();
    for (const KeyBinding &binding : key_bindings) {
        const StringName action(binding.action);
        if (!input_map->has_action(action)) {
            input_map->add_action(action, 0.22F);
        }
        Ref<InputEventKey> key_event;
        key_event.instantiate();
        key_event->set_physical_keycode(binding.key);
        input_map->action_add_event(action, key_event);
    }

    struct MouseBinding {
        const char *action;
        MouseButton button;
    };
    const MouseBinding mouse_bindings[] = {
        {"attack", MOUSE_BUTTON_LEFT},
        {"light_attack", MOUSE_BUTTON_LEFT},
    };
    for (const MouseBinding &binding : mouse_bindings) {
        const StringName action(binding.action);
        if (!input_map->has_action(action)) {
            input_map->add_action(action, 0.12F);
        }
        Ref<InputEventMouseButton> mouse_event;
        mouse_event.instantiate();
        mouse_event->set_button_index(binding.button);
        input_map->action_add_event(action, mouse_event);
    }
}

void WorldDirector::create_environment() {
    WorldEnvironment *world_environment = memnew(WorldEnvironment);
    world_environment->set_name("CinematicEnvironment");

    Ref<ProceduralSkyMaterial> sky_material;
    sky_material.instantiate();
    sky_material->set_sky_top_color(Color(0.055, 0.28, 0.72));
    sky_material->set_sky_horizon_color(Color(0.54, 0.76, 0.95));
    sky_material->set_ground_bottom_color(Color(0.27, 0.31, 0.37));
    sky_material->set_ground_horizon_color(Color(0.57, 0.73, 0.90));
    sky_material->set_sun_angle_max(24.0);
    sky_material->set_sun_curve(0.08);

    Ref<Sky> sky;
    sky.instantiate();
    sky->set_material(sky_material);

    Ref<Environment> environment;
    environment.instantiate();
    environment->set_background(Environment::BG_SKY);
    environment->set_sky(sky);
    environment->set_ambient_source(Environment::AMBIENT_SOURCE_SKY);
    environment->set_reflection_source(Environment::REFLECTION_SOURCE_SKY);
    environment->set_tonemapper(Environment::TONE_MAPPER_FILMIC);
    environment->set_ssao_enabled(true);
    environment->set_ssao_radius(2.1F);
    environment->set_ssao_intensity(2.0F);
    environment->set_ssao_power(1.35F);
    environment->set_ssil_enabled(true);
    environment->set_ssil_radius(3.4F);
    environment->set_ssil_intensity(0.9F);
    environment->set_glow_enabled(true);
    environment->set_glow_intensity(0.52F);
    environment->set_ssr_enabled(false);
    environment->set_volumetric_fog_enabled(false);
    environment->set_volumetric_fog_density(0.018F);
    environment->set_volumetric_fog_albedo(
        Color(0.72F, 0.60F, 0.48F)
    );
    environment->set_volumetric_fog_length(96.0F);
    environment->set_volumetric_fog_sky_affect(0.18F);
    environment->set("ambient_light_energy", 0.62);
    environment->set("fog_enabled", true);
    environment->set("fog_light_color", Color(0.69, 0.51, 0.35));
    environment->set("fog_light_energy", 0.44);
    environment->set("fog_density", 0.0035);
    environment->set("fog_height", 2.0);
    environment->set("fog_height_density", 0.12);
    environment->set_fog_sky_affect(0.04F);
    environment->set("adjustment_enabled", true);
    environment->set("adjustment_brightness", 1.0);
    environment->set("adjustment_contrast", 1.10);
    environment->set("adjustment_saturation", 1.04);
    world_environment->set_environment(environment);
    add_child(world_environment);

    DirectionalLight3D *sun = memnew(DirectionalLight3D);
    sun->set_name("LateAfternoonSun");
    sun->set_rotation_degrees(Vector3(-48.0, -32.0, 0.0));
    sun->set_color(Color(1.0, 0.79, 0.58));
    sun->set_param(Light3D::PARAM_ENERGY, 1.58);
    sun->set_shadow(true);
    sun->set_param(Light3D::PARAM_SHADOW_MAX_DISTANCE, 120.0);
    sun->set_param(Light3D::PARAM_SHADOW_FADE_START, 0.78);
    add_child(sun);

    DirectionalLight3D *sky_fill = memnew(DirectionalLight3D);
    sky_fill->set_name("CoolSkyFill");
    sky_fill->set_rotation_degrees(Vector3(-68.0, 145.0, 0.0));
    sky_fill->set_color(Color(0.28, 0.47, 0.82));
    sky_fill->set_param(Light3D::PARAM_ENERGY, 0.36);
    sky_fill->set_shadow(false);
    add_child(sky_fill);
}

void WorldDirector::load_authored_district() {
    const String district_path = "res://assets/models/bazaar_district.glb";
    Ref<PackedScene> packed = ResourceLoader::get_singleton()->load(district_path);
    if (packed.is_null()) {
        UtilityFunctions::push_error("Impossibile caricare il quartiere: ", district_path);
        return;
    }
    Node3D *district = Object::cast_to<Node3D>(packed->instantiate());
    if (district != nullptr) {
        district->set_name("AuthoredMediterraneanCity");
        district->set_position(Vector3(56.0F, 0.0F, -18.0F));
        district->set_rotation_degrees(Vector3(0.0F, -5.0F, 0.0F));
        configure_advanced_movement_surfaces(district);
        add_child(district);
    }
}

bool WorldDirector::load_advanced_parkour_player() {
    const String player_path =
        "res://DynamicParkour/DynamicParkourPlayer.tscn";
    Ref<PackedScene> packed_player =
        ResourceLoader::get_singleton()->load(player_path);
    if (packed_player.is_null()) {
        return false;
    }

    Node *instance = packed_player->instantiate();
    advanced_player_ = Object::cast_to<CharacterBody3D>(instance);
    if (advanced_player_ == nullptr) {
        if (instance != nullptr) {
            instance->queue_free();
        }
        return false;
    }

    advanced_player_->set_name("DynamicParkourPlayer");
    advanced_player_->set_position(Vector3(0.0F, 0.08F, 28.0F));
    advanced_player_->set_rotation(Vector3());
    add_child(advanced_player_);
    return true;
}

void WorldDirector::configure_advanced_movement_surfaces(Node *node) {
    if (node == nullptr) {
        return;
    }

    CollisionObject3D *collision_object =
        Object::cast_to<CollisionObject3D>(node);
    if (collision_object != nullptr) {
        // Layer 1 remains the physical collision layer. Layer 2 is consumed
        // by the imported floor and wall awareness rays.
        collision_object->set_collision_layer(
            collision_object->get_collision_layer() | 3U
        );
    }

    for (int index = 0; index < node->get_child_count(); ++index) {
        configure_advanced_movement_surfaces(node->get_child(index));
    }
}

void WorldDirector::create_physics_floor() {
    StaticBody3D *floor = memnew(StaticBody3D);
    floor->set_name("StreetFoundation");
    floor->set_position(Vector3(0.0, -0.22, 0.0));
    floor->set_collision_layer(3U);

    CollisionShape3D *collision = memnew(CollisionShape3D);
    Ref<BoxShape3D> shape;
    shape.instantiate();
    shape->set_size(Vector3(260.0, 0.35, 220.0));
    collision->set_shape(shape);
    floor->add_child(collision);
    add_child(floor);

    MeshInstance3D *street_bed = memnew(MeshInstance3D);
    street_bed->set_name("ContinuousStreetBed");
    street_bed->set_position(Vector3(0.0, -0.22, 0.0));
    Ref<BoxMesh> street_mesh;
    street_mesh.instantiate();
    street_mesh->set_size(Vector3(260.0, 0.34, 220.0));
    Ref<StandardMaterial3D> street_material;
    street_material.instantiate();
    street_material->set_albedo(Color(0.20, 0.125, 0.075));
    street_material->set_roughness(0.96F);
    street_material->set_metallic(0.0F);
    street_mesh->set_material(street_material);
    street_bed->set_mesh(street_mesh);
    add_child(street_bed);
}

void WorldDirector::create_open_plaza_parkour_routes() {
    const Color dark_lava(0.115F, 0.100F, 0.088F);
    const Color sun_washed_stone(0.66F, 0.56F, 0.41F);
    const Color warm_limestone(0.78F, 0.68F, 0.50F);
    const Color terracotta(0.52F, 0.22F, 0.105F);
    const Color olive_wood(0.23F, 0.15F, 0.075F);
    const Color chalk_plaster(0.72F, 0.68F, 0.58F);

    create_dynamic_prop(
        this,
        "OpenBazaarPlazaPaving",
        Vector3(0.0F, -0.005F, 1.0F),
        Vector3(54.0F, 0.10F, 66.0F),
        Color(0.34F, 0.255F, 0.175F)
    );

    create_dynamic_prop(
        this,
        "NorthSlideAwningBeam",
        Vector3(-10.0F, 1.50F, 21.0F),
        Vector3(6.7F, 0.30F, 0.70F),
        olive_wood
    );
    create_dynamic_prop(
        this,
        "NorthSlideAwningLeftPier",
        Vector3(-13.25F, 1.05F, 21.0F),
        Vector3(0.46F, 2.10F, 0.76F),
        sun_washed_stone
    );
    create_dynamic_prop(
        this,
        "NorthSlideAwningRightPier",
        Vector3(-6.75F, 1.05F, 21.0F),
        Vector3(0.46F, 2.10F, 0.76F),
        sun_washed_stone
    );
    create_dynamic_prop(
        this,
        "SouthSlideAwningBeam",
        Vector3(9.6F, 1.48F, -3.8F),
        Vector3(6.2F, 0.28F, 0.72F),
        olive_wood
    );
    create_dynamic_prop(
        this,
        "SouthSlideAwningWestPier",
        Vector3(6.55F, 1.02F, -3.8F),
        Vector3(0.44F, 2.04F, 0.76F),
        warm_limestone
    );
    create_dynamic_prop(
        this,
        "SouthSlideAwningEastPier",
        Vector3(12.65F, 1.02F, -3.8F),
        Vector3(0.44F, 2.04F, 0.76F),
        warm_limestone
    );

    create_dynamic_prop(
        this,
        "LowMarketCounterNorth",
        Vector3(4.7F, 0.42F, 23.0F),
        Vector3(3.15F, 0.84F, 0.62F),
        terracotta
    );
    create_dynamic_prop(
        this,
        "LowMarketCounterWest",
        Vector3(-5.6F, 0.40F, 13.3F),
        Vector3(2.65F, 0.80F, 0.62F),
        sun_washed_stone
    );
    create_dynamic_prop(
        this,
        "LowPlanterJumpLine",
        Vector3(6.1F, 0.47F, 9.0F),
        Vector3(2.20F, 0.94F, 1.05F),
        warm_limestone
    );
    create_dynamic_prop(
        this,
        "BrokenCartVault",
        Vector3(-1.6F, 0.46F, -7.2F),
        Vector3(3.25F, 0.92F, 0.66F),
        olive_wood
    );
    create_dynamic_prop(
        this,
        "SidewaysStoneBench",
        Vector3(-13.8F, 0.38F, -10.0F),
        Vector3(0.74F, 0.76F, 3.20F),
        chalk_plaster
    );

    create_dynamic_prop(
        this,
        "WestClimbPlatform",
        Vector3(-15.4F, 1.28F, 7.8F),
        Vector3(4.8F, 2.56F, 4.7F),
        sun_washed_stone
    );
    create_dynamic_prop(
        this,
        "WestClimbPlatformLipNorth",
        Vector3(-15.4F, 2.70F, 10.22F),
        Vector3(5.10F, 0.20F, 0.30F),
        dark_lava
    );
    create_dynamic_prop(
        this,
        "WestClimbPlatformLipEast",
        Vector3(-12.82F, 2.70F, 7.8F),
        Vector3(0.30F, 0.20F, 4.85F),
        dark_lava
    );
    create_dynamic_prop(
        this,
        "WestClimbLowerCrate",
        Vector3(-11.1F, 0.78F, 5.5F),
        Vector3(2.40F, 1.56F, 2.05F),
        terracotta
    );

    create_dynamic_prop(
        this,
        "EastFacadeClimbWall",
        Vector3(15.4F, 2.72F, 7.2F),
        Vector3(0.72F, 5.44F, 7.4F),
        chalk_plaster
    );
    create_dynamic_prop(
        this,
        "EastFacadeLowerHandhold",
        Vector3(15.0F, 2.16F, 7.2F),
        Vector3(0.22F, 0.18F, 7.25F),
        dark_lava
    );
    create_dynamic_prop(
        this,
        "EastFacadeUpperHandhold",
        Vector3(15.0F, 3.62F, 7.2F),
        Vector3(0.22F, 0.18F, 7.25F),
        dark_lava
    );

    create_dynamic_prop(
        this,
        "CentralRaisedStepOne",
        Vector3(-2.5F, 0.56F, 7.0F),
        Vector3(2.7F, 1.12F, 2.45F),
        terracotta
    );
    create_dynamic_prop(
        this,
        "CentralRaisedStepTwo",
        Vector3(1.2F, 0.68F, 3.0F),
        Vector3(2.85F, 1.36F, 2.45F),
        warm_limestone
    );
    create_dynamic_prop(
        this,
        "CentralRaisedStepThree",
        Vector3(-3.8F, 0.76F, -1.3F),
        Vector3(2.85F, 1.52F, 2.45F),
        sun_washed_stone
    );

    create_dynamic_prop(
        this,
        "SouthwestClimbBlock",
        Vector3(-15.6F, 1.66F, -16.0F),
        Vector3(5.2F, 3.32F, 4.6F),
        warm_limestone
    );
    create_dynamic_prop(
        this,
        "SouthwestClimbBlockLip",
        Vector3(-15.6F, 3.42F, -18.40F),
        Vector3(5.30F, 0.18F, 0.28F),
        dark_lava
    );
    create_dynamic_prop(
        this,
        "SoutheastTowerWall",
        Vector3(13.8F, 2.65F, -15.4F),
        Vector3(0.68F, 5.30F, 6.7F),
        terracotta
    );
    create_dynamic_prop(
        this,
        "OppositeTowerWall",
        Vector3(17.25F, 2.65F, -15.4F),
        Vector3(0.68F, 5.30F, 6.7F),
        chalk_plaster
    );
    create_dynamic_prop(
        this,
        "SoutheastWallGrabLip",
        Vector3(13.42F, 3.22F, -15.4F),
        Vector3(0.20F, 0.18F, 6.55F),
        dark_lava
    );
    create_dynamic_prop(
        this,
        "OppositeWallGrabLip",
        Vector3(16.88F, 3.86F, -15.4F),
        Vector3(0.20F, 0.18F, 6.55F),
        dark_lava
    );

    create_dynamic_prop(
        this,
        "FarSouthLandingPlatform",
        Vector3(0.0F, 1.18F, -23.0F),
        Vector3(5.8F, 2.36F, 5.6F),
        sun_washed_stone
    );
    create_dynamic_prop(
        this,
        "FarSouthPlatformNorthLip",
        Vector3(0.0F, 2.48F, -20.08F),
        Vector3(5.95F, 0.20F, 0.30F),
        dark_lava
    );
    create_dynamic_prop(
        this,
        "FarSouthShortBarrier",
        Vector3(5.4F, 0.50F, -23.0F),
        Vector3(2.35F, 1.00F, 0.62F),
        terracotta
    );

    const String zipline_path = "res://DynamicParkour/ZipLine.tscn";
    Ref<PackedScene> packed_zipline =
        ResourceLoader::get_singleton()->load(zipline_path);
    if (packed_zipline.is_valid()) {
        Node3D *west_to_center_zipline =
            Object::cast_to<Node3D>(packed_zipline->instantiate());
        if (west_to_center_zipline != nullptr) {
            west_to_center_zipline->set_name("WestPlatformZipLine");
            west_to_center_zipline->set(
                "start_point",
                Vector3(-15.4F, 4.00F, 8.8F)
            );
            west_to_center_zipline->set(
                "end_point",
                Vector3(-3.8F, 2.85F, -1.3F)
            );
            west_to_center_zipline->set("travel_speed", 9.6F);
            add_child(west_to_center_zipline);
        }

        Node3D *tower_zipline =
            Object::cast_to<Node3D>(packed_zipline->instantiate());
        if (tower_zipline != nullptr) {
            tower_zipline->set_name("TowerToSouthZipLine");
            tower_zipline->set(
                "start_point",
                Vector3(15.4F, 5.65F, -15.4F)
            );
            tower_zipline->set(
                "end_point",
                Vector3(0.0F, 3.15F, -23.0F)
            );
            tower_zipline->set("travel_speed", 10.8F);
            add_child(tower_zipline);
        }
    }

    create_outlying_camps();
}

void WorldDirector::create_outlying_camps() {
    const Color packed_dirt(0.28F, 0.19F, 0.12F);
    const Color canvas_red(0.55F, 0.16F, 0.10F);
    const Color canvas_blue(0.13F, 0.27F, 0.50F);
    const Color canvas_green(0.18F, 0.36F, 0.18F);
    const Color canvas_sand(0.72F, 0.62F, 0.44F);
    const Color canvas_violet(0.37F, 0.22F, 0.48F);
    const Color wood(0.22F, 0.12F, 0.055F);
    const Color stone(0.63F, 0.55F, 0.43F);
    const Color ember(0.95F, 0.36F, 0.08F);
    const Color dark_lip(0.10F, 0.09F, 0.08F);

    struct Camp {
        const char *node_name;
        const char *label;
        Vector3 center;
        Color canvas;
    };
    const Camp camps[] = {
        {"NorthOasisCamp", "Campo Nord", Vector3(-56.0F, 0.02F, 58.0F), canvas_blue},
        {"EastQuarryCamp", "Campo Est", Vector3(72.0F, 0.02F, 34.0F), canvas_red},
        {"SouthRuinsCamp", "Campo Sud", Vector3(3.0F, 0.02F, -82.0F), canvas_green},
        {"WestCliffCamp", "Campo Ovest", Vector3(-74.0F, 0.02F, -36.0F), canvas_sand},
        {"NorthEastWatchCamp", "Torre NE", Vector3(48.0F, 0.02F, 78.0F), canvas_violet},
    };
    const int camp_count = sizeof(camps) / sizeof(camps[0]);

    for (int index = 0; index < camp_count; ++index) {
        const Camp &camp = camps[index];
        const Vector3 center = camp.center;
        StaticBody3D *marker = create_dynamic_prop(
            this,
            String(camp.node_name),
            center + Vector3(0.0F, 0.035F, 0.0F),
            Vector3(10.5F, 0.10F, 9.2F),
            packed_dirt
        );
        marker->add_to_group("camp");
        marker->set_meta(StringName("map_label"), String(camp.label));

        create_dynamic_prop(
            this,
            String(camp.node_name) + "MainTent",
            center + Vector3(-2.7F, 0.52F, -1.8F),
            Vector3(3.7F, 1.04F, 2.8F),
            camp.canvas
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "TentRidge",
            center + Vector3(-2.7F, 1.18F, -1.8F),
            Vector3(3.9F, 0.20F, 0.32F),
            wood
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "SupplyTent",
            center + Vector3(2.8F, 0.45F, 2.2F),
            Vector3(3.0F, 0.90F, 2.4F),
            Color(
                camp.canvas.r * 0.78F,
                camp.canvas.g * 0.78F,
                camp.canvas.b * 0.78F
            )
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "Campfire",
            center + Vector3(0.2F, 0.18F, 0.2F),
            Vector3(0.80F, 0.36F, 0.80F),
            ember
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "LowCrateVault",
            center + Vector3(4.4F, 0.42F, -2.8F),
            Vector3(2.3F, 0.84F, 0.70F),
            wood
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "StoneClimbBlock",
            center + Vector3(-4.7F, 0.90F, 3.2F),
            Vector3(2.6F, 1.80F, 2.4F),
            stone
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "GrabLip",
            center + Vector3(-4.7F, 1.90F, 4.48F),
            Vector3(2.8F, 0.18F, 0.24F),
            dark_lip
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "SlideBeam",
            center + Vector3(0.8F, 1.46F, -4.0F),
            Vector3(5.2F, 0.28F, 0.62F),
            wood
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "SlidePostWest",
            center + Vector3(-1.85F, 0.96F, -4.0F),
            Vector3(0.42F, 1.92F, 0.62F),
            stone
        );
        create_dynamic_prop(
            this,
            String(camp.node_name) + "SlidePostEast",
            center + Vector3(3.45F, 0.96F, -4.0F),
            Vector3(0.42F, 1.92F, 0.62F),
            stone
        );
    }

    create_dynamic_prop(
        this,
        "NorthRoadCauseway",
        Vector3(-24.0F, 0.015F, 41.0F),
        Vector3(8.0F, 0.08F, 40.0F),
        Color(0.36F, 0.26F, 0.17F)
    );
    create_dynamic_prop(
        this,
        "EastRoadCauseway",
        Vector3(43.0F, 0.015F, 19.0F),
        Vector3(54.0F, 0.08F, 7.2F),
        Color(0.36F, 0.26F, 0.17F)
    );
    create_dynamic_prop(
        this,
        "SouthRoadCauseway",
        Vector3(1.5F, 0.015F, -51.0F),
        Vector3(7.6F, 0.08F, 52.0F),
        Color(0.36F, 0.26F, 0.17F)
    );
    create_dynamic_prop(
        this,
        "WestRoadCauseway",
        Vector3(-43.0F, 0.015F, -20.0F),
        Vector3(56.0F, 0.08F, 7.0F),
        Color(0.36F, 0.26F, 0.17F)
    );
    create_dynamic_prop(
        this,
        "NorthEastRoadCauseway",
        Vector3(29.0F, 0.015F, 50.0F),
        Vector3(7.2F, 0.08F, 56.0F),
        Color(0.36F, 0.26F, 0.17F)
    );
}

void WorldDirector::create_dynamic_parkour_routes() {
    create_open_plaza_parkour_routes();
    return;

    const Color lava_stone(0.12, 0.105, 0.095);
    const Color pale_stone(0.62, 0.51, 0.38);
    const Color terracotta(0.48, 0.18, 0.075);
    const Color aged_wood(0.20, 0.075, 0.030);

    // A market arcade creates a readable slide route without looking like a
    // test obstacle. The normal capsule meets the hanging crossbeam while the
    // original low slide capsule clears it.
    create_dynamic_prop(
        this,
        "MarketArcadeCrossbeam",
        Vector3(0.0F, 1.59F, 22.0F),
        Vector3(7.7F, 0.24F, 0.58F),
        aged_wood
    );
    create_dynamic_prop(
        this,
        "MarketArcadeLeftPier",
        Vector3(-3.58F, 1.18F, 22.0F),
        Vector3(0.52F, 2.36F, 0.72F),
        pale_stone
    );
    create_dynamic_prop(
        this,
        "MarketArcadeRightPier",
        Vector3(3.58F, 1.18F, 22.0F),
        Vector3(0.52F, 2.36F, 0.72F),
        pale_stone
    );

    // Street furniture supplies the two low-height actions from the source
    // package: hand-assisted vault and the higher reach/step-up.
    create_dynamic_prop(
        this,
        "TerracottaMarketBarrier",
        Vector3(0.0F, 0.43F, 16.0F),
        Vector3(2.45F, 0.86F, 0.58F),
        terracotta
    );
    create_dynamic_prop(
        this,
        "StoneReachTerrace",
        Vector3(2.75F, 0.76F, 12.2F),
        Vector3(2.55F, 1.52F, 2.15F),
        pale_stone
    );

    // A tall side façade and its projecting cornices reproduce the source
    // ledge setup. They support braced hanging, shimmies, lateral hops, drop,
    // wall jump and a two-stage pull-up.
    create_dynamic_prop(
        this,
        "CorniceClimbFacade",
        Vector3(3.05F, 2.55F, 8.35F),
        Vector3(3.25F, 5.10F, 0.48F),
        pale_stone
    );
    create_dynamic_prop(
        this,
        "CorniceClimbLowerLedge",
        Vector3(3.05F, 2.16F, 8.70F),
        Vector3(3.50F, 0.20F, 0.62F),
        lava_stone
    );
    create_dynamic_prop(
        this,
        "CorniceClimbUpperLedge",
        Vector3(3.05F, 3.62F, 8.70F),
        Vector3(3.50F, 0.20F, 0.62F),
        lava_stone
    );

    // Three roof-like terraces form an unobtrusive predicted-jump line along
    // the avenue edge. Landing selection remains dynamic; no scripted target
    // is forced on the player.
    create_dynamic_prop(
        this,
        "PredictedJumpTerraceA",
        Vector3(-2.75F, 0.57F, 7.0F),
        Vector3(2.35F, 1.14F, 2.20F),
        terracotta
    );
    create_dynamic_prop(
        this,
        "PredictedJumpTerraceB",
        Vector3(-2.75F, 0.62F, 2.70F),
        Vector3(2.35F, 1.24F, 2.20F),
        terracotta
    );
    create_dynamic_prop(
        this,
        "PredictedJumpTerraceC",
        Vector3(-1.45F, 0.70F, -1.70F),
        Vector3(2.35F, 1.40F, 2.20F),
        pale_stone
    );

    // A narrow passage between two low façades supports repeated wall-to-wall
    // jumps. Projecting stone courses double as real grab ledges.
    create_dynamic_prop(
        this,
        "WallJumpAlleyWestFacade",
        Vector3(-1.65F, 3.20F, -11.0F),
        Vector3(0.38F, 6.40F, 6.20F),
        pale_stone
    );
    create_dynamic_prop(
        this,
        "WallJumpAlleyEastFacade",
        Vector3(1.65F, 3.20F, -11.0F),
        Vector3(0.38F, 6.40F, 6.20F),
        terracotta
    );
    create_dynamic_prop(
        this,
        "WallJumpAlleyWestCornice",
        Vector3(-1.42F, 2.82F, -11.0F),
        Vector3(0.16F, 0.18F, 6.20F),
        lava_stone
    );
    create_dynamic_prop(
        this,
        "WallJumpAlleyEastCornice",
        Vector3(1.42F, 3.48F, -11.0F),
        Vector3(0.16F, 0.18F, 6.20F),
        lava_stone
    );

    // Only two traversal cables cross the district: they remain deliberate
    // parkour links rather than a web connecting every roof.
    const String zipline_path = "res://DynamicParkour/ZipLine.tscn";
    Ref<PackedScene> packed_zipline =
        ResourceLoader::get_singleton()->load(zipline_path);
    if (packed_zipline.is_valid()) {
        Node3D *market_zipline =
            Object::cast_to<Node3D>(packed_zipline->instantiate());
        if (market_zipline != nullptr) {
            market_zipline->set_name("MarketRoofZipLine");
            market_zipline->set(
                "start_point",
                Vector3(3.05F, 5.35F, 8.35F)
            );
            market_zipline->set(
                "end_point",
                Vector3(-2.75F, 3.25F, 2.70F)
            );
            market_zipline->set("travel_speed", 9.8F);
            add_child(market_zipline);
        }

        Node3D *alley_zipline =
            Object::cast_to<Node3D>(packed_zipline->instantiate());
        if (alley_zipline != nullptr) {
            alley_zipline->set_name("WallJumpAlleyZipLine");
            alley_zipline->set(
                "start_point",
                Vector3(-1.45F, 6.15F, -8.35F)
            );
            alley_zipline->set(
                "end_point",
                Vector3(1.45F, 4.35F, -13.60F)
            );
            alley_zipline->set("travel_speed", 10.5F);
            add_child(alley_zipline);
        }
    }
}

void WorldDirector::create_combat_enemies() {
    const String enemy_path =
        "res://CombatPrototype/ExtractedSwordsman.tscn";
    Ref<PackedScene> packed_enemy =
        ResourceLoader::get_singleton()->load(enemy_path);
    if (packed_enemy.is_null()) {
        UtilityFunctions::push_error(
            "Impossibile caricare i nemici estratti: ",
            enemy_path
        );
        return;
    }

    struct EnemySpawn {
        Vector3 position;
        float yaw;
        float vision_range;
        float vision_angle;
        float movement_speed;
    };
    const EnemySpawn spawns[] = {
        {Vector3(-4.6F, 0.12F, 21.4F), -0.30F, 8.0F, 68.0F, 2.55F},
        {Vector3(7.8F, 0.12F, 20.3F), 2.85F, 8.8F, 74.0F, 2.65F},
        {Vector3(-17.4F, 0.12F, 2.2F), 0.72F, 9.4F, 78.0F, 2.45F},
        {Vector3(10.4F, 0.12F, 6.8F), -2.10F, 8.5F, 70.0F, 2.70F},
        {Vector3(-6.4F, 0.12F, 8.9F), 1.55F, 7.8F, 66.0F, 2.50F},
        {Vector3(3.6F, 0.12F, -1.2F), -2.95F, 8.3F, 72.0F, 2.62F},
        {Vector3(11.6F, 0.12F, -8.6F), -1.35F, 9.6F, 76.0F, 2.78F},
        {Vector3(-7.4F, 0.12F, -10.7F), 2.35F, 8.7F, 70.0F, 2.55F},
        {Vector3(-20.2F, 0.12F, -15.2F), 0.40F, 9.2F, 74.0F, 2.48F},
        {Vector3(8.0F, 0.12F, -19.0F), -2.55F, 8.9F, 72.0F, 2.68F},
        {Vector3(7.6F, 0.12F, -26.5F), -1.95F, 8.4F, 68.0F, 2.58F},
        {Vector3(18.9F, 0.12F, 0.5F), -2.80F, 9.8F, 78.0F, 2.82F},
        {Vector3(-1.2F, 0.12F, 12.4F), -0.92F, 7.6F, 64.0F, 2.52F},
        {Vector3(-11.6F, 0.12F, 18.4F), 1.18F, 8.2F, 70.0F, 2.56F},
        {Vector3(15.8F, 0.12F, 13.8F), -2.65F, 8.7F, 72.0F, 2.72F},
        {Vector3(-2.0F, 0.12F, -18.4F), 0.20F, 8.5F, 68.0F, 2.62F},
        {Vector3(-60.0F, 0.12F, 55.0F), 0.90F, 9.8F, 72.0F, 2.54F},
        {Vector3(-53.0F, 0.12F, 61.0F), -2.42F, 9.1F, 68.0F, 2.48F},
        {Vector3(-56.4F, 0.12F, 52.2F), -0.20F, 8.7F, 66.0F, 2.62F},
        {Vector3(68.0F, 0.12F, 30.5F), 1.15F, 9.5F, 74.0F, 2.70F},
        {Vector3(75.6F, 0.12F, 36.8F), -2.75F, 10.2F, 76.0F, 2.80F},
        {Vector3(72.0F, 0.12F, 27.5F), 0.08F, 8.9F, 68.0F, 2.55F},
        {Vector3(-1.6F, 0.12F, -77.8F), 2.90F, 9.5F, 72.0F, 2.66F},
        {Vector3(6.5F, 0.12F, -85.5F), -0.36F, 9.0F, 68.0F, 2.58F},
        {Vector3(2.4F, 0.12F, -88.4F), -1.88F, 8.8F, 66.0F, 2.52F},
        {Vector3(-78.2F, 0.12F, -39.4F), 0.55F, 10.4F, 76.0F, 2.76F},
        {Vector3(-70.8F, 0.12F, -32.6F), -2.30F, 9.3F, 70.0F, 2.54F},
        {Vector3(-74.2F, 0.12F, -43.2F), -0.70F, 8.6F, 66.0F, 2.48F},
        {Vector3(44.8F, 0.12F, 74.0F), 0.35F, 9.6F, 72.0F, 2.62F},
        {Vector3(51.6F, 0.12F, 81.4F), -2.70F, 10.0F, 76.0F, 2.74F},
        {Vector3(49.4F, 0.12F, 72.0F), 1.82F, 8.7F, 68.0F, 2.55F},
    };
    const int spawn_count = sizeof(spawns) / sizeof(spawns[0]);
    for (int index = 0; index < spawn_count; ++index) {
        Node3D *enemy =
            Object::cast_to<Node3D>(packed_enemy->instantiate());
        if (enemy == nullptr) {
            continue;
        }
        enemy->set_name(String("PlazaSwordsman") + String::num_int64(index + 1));
        enemy->set_position(spawns[index].position);
        enemy->set_rotation(Vector3(0.0F, spawns[index].yaw, 0.0F));
        enemy->set("vision_range", spawns[index].vision_range);
        enemy->set("vision_angle_degrees", spawns[index].vision_angle);
        enemy->set("detection_radius", spawns[index].vision_range + 2.5F);
        enemy->set("disengage_radius", spawns[index].vision_range + 9.5F);
        enemy->set("movement_speed", spawns[index].movement_speed);
        enemy->set("skin_index", index);
        add_child(enemy);
    }
}

void WorldDirector::create_overview_camera() {
    Camera3D *overview = memnew(Camera3D);
    overview->set_name("MediterraneanOverviewCamera");
    overview->set_fov(55.0F);
    overview->set_near(0.2F);
    overview->set_far(420.0F);
    add_child(overview);
    overview->set_global_position(Vector3(-36.0F, 47.0F, 68.0F));
    overview->look_at(Vector3(2.0F, 5.0F, -30.0F), Vector3(0.0F, 1.0F, 0.0F));
    overview->set_current(true);

    CanvasLayer *interface_layer =
        Object::cast_to<CanvasLayer>(get_node_or_null("Interface"));
    if (interface_layer != nullptr) {
        interface_layer->set_visible(false);
    }
}

void WorldDirector::create_climb_test_wall() {
    StaticBody3D *wall = memnew(StaticBody3D);
    wall->set_name("UniversalClimbTestWall");
    wall->set_position(Vector3(0.0, 4.0F, -2.4F));

    CollisionShape3D *collision = memnew(CollisionShape3D);
    Ref<BoxShape3D> shape;
    shape.instantiate();
    shape->set_size(Vector3(8.0F, 8.0F, 0.45F));
    collision->set_shape(shape);
    wall->add_child(collision);

    MeshInstance3D *wall_visual = memnew(MeshInstance3D);
    Ref<BoxMesh> wall_mesh;
    wall_mesh.instantiate();
    wall_mesh->set_size(Vector3(8.0F, 8.0F, 0.45F));
    Ref<StandardMaterial3D> wall_material;
    wall_material.instantiate();
    wall_material->set_albedo(Color(0.43F, 0.24F, 0.12F));
    wall_material->set_roughness(0.92F);
    wall_mesh->set_material(wall_material);
    wall_visual->set_mesh(wall_mesh);
    wall->add_child(wall_visual);
    add_child(wall);
}

void WorldDirector::create_mantle_test_wall() {
    StaticBody3D *wall = memnew(StaticBody3D);
    wall->set_name("CollisionSafeMantleTestWall");
    wall->set_position(Vector3(0.0F, 1.6F, -4.175F));

    CollisionShape3D *collision = memnew(CollisionShape3D);
    Ref<BoxShape3D> shape;
    shape.instantiate();
    shape->set_size(Vector3(8.0F, 3.2F, 4.0F));
    collision->set_shape(shape);
    wall->add_child(collision);
    add_child(wall);
}

void WorldDirector::create_advanced_ledge_test_obstacle() {
    StaticBody3D *obstacle = memnew(StaticBody3D);
    obstacle->set_name("AdvancedDynamicLedgeTest");
    obstacle->set_position(Vector3(0.0F, 1.2F, -0.75F));
    obstacle->set_collision_layer(3U);

    CollisionShape3D *collision = memnew(CollisionShape3D);
    Ref<BoxShape3D> shape;
    shape.instantiate();
    shape->set_size(Vector3(3.0F, 2.4F, 0.24F));
    collision->set_shape(shape);
    obstacle->add_child(collision);
    add_child(obstacle);
}

void WorldDirector::create_advanced_flat_wall_test_obstacle() {
    create_dynamic_prop(
        this,
        "AdvancedFlatWallTest",
        Vector3(0.0F, 5.0F, -0.75F),
        Vector3(4.0F, 10.0F, 0.8F),
        Color(0.62, 0.51, 0.38)
    );
}

void WorldDirector::create_dynamic_slide_test_obstacle() {
    create_dynamic_prop(
        this,
        "DynamicSlideTestCrossbeam",
        Vector3(20.0F, 1.48F, -0.92F),
        Vector3(3.8F, 0.38F, 0.52F),
        Color(0.20, 0.075, 0.030)
    );
}

void WorldDirector::create_dynamic_predicted_jump_test_course() {
    create_dynamic_prop(
        this,
        "DynamicPredictedJumpStart",
        Vector3(20.0F, 0.70F, 1.20F),
        Vector3(2.4F, 1.40F, 2.0F),
        Color(0.48, 0.18, 0.075)
    );
    create_dynamic_prop(
        this,
        "DynamicPredictedJumpTarget",
        Vector3(20.0F, 0.70F, -2.65F),
        Vector3(2.4F, 1.40F, 2.0F),
        Color(0.62, 0.51, 0.38)
    );
}

void WorldDirector::create_dynamic_vault_test_obstacle() {
    create_dynamic_prop(
        this,
        "DynamicVaultTestObstacle",
        Vector3(20.0F, 0.43F, -0.95F),
        Vector3(2.4F, 0.86F, 0.58F),
        Color(0.48, 0.18, 0.075)
    );
}

void WorldDirector::create_dynamic_reach_test_obstacle() {
    create_dynamic_prop(
        this,
        "DynamicReachTestObstacle",
        Vector3(20.0F, 0.76F, -1.05F),
        Vector3(2.6F, 1.52F, 1.05F),
        Color(0.62, 0.51, 0.38)
    );
}

void WorldDirector::create_dynamic_wall_to_wall_test_course() {
    create_dynamic_prop(
        this,
        "DynamicWallJumpStart",
        Vector3(20.0F, 3.0F, -0.75F),
        Vector3(3.2F, 6.0F, 0.40F),
        Color(0.62, 0.51, 0.38)
    );
    create_dynamic_prop(
        this,
        "DynamicWallJumpTarget",
        Vector3(20.0F, 3.0F, 2.0F),
        Vector3(3.2F, 6.0F, 0.40F),
        Color(0.48, 0.18, 0.075)
    );
}

void WorldDirector::create_dynamic_edge_guard_test_platform() {
    create_dynamic_prop(
        this,
        "DynamicThinTopEdgeGuardTest",
        Vector3(20.0F, 1.0F, 0.0F),
        Vector3(2.8F, 2.0F, 0.26F),
        Color(0.62, 0.51, 0.38)
    );
}

void WorldDirector::create_vault_test_obstacle() {
    StaticBody3D *obstacle = memnew(StaticBody3D);
    obstacle->set_name("AutomaticLowVaultTest");
    obstacle->set_position(Vector3(0.0, 0.42F, -1.4F));

    CollisionShape3D *collision = memnew(CollisionShape3D);
    Ref<BoxShape3D> shape;
    shape.instantiate();
    shape->set_size(Vector3(2.4F, 0.84F, 0.42F));
    collision->set_shape(shape);
    obstacle->add_child(collision);
    add_child(obstacle);
}

void WorldDirector::create_balance_test_rope() {
    StaticBody3D *rope_body = memnew(StaticBody3D);
    rope_body->set_name("tightrope_balance_test");
    rope_body->set_position(Vector3(0.0F, 0.22F, 0.0F));

    CollisionShape3D *collision = memnew(CollisionShape3D);
    collision->set_rotation_degrees(Vector3(90.0F, 0.0F, 0.0F));
    Ref<CapsuleShape3D> shape;
    shape.instantiate();
    shape->set_radius(0.22F);
    shape->set_height(8.0F);
    collision->set_shape(shape);
    rope_body->add_child(collision);
    add_child(rope_body);
}

void WorldDirector::create_stealth_world_systems() {
    const String systems_path =
        "res://scripts/stealth/StealthWorldDirector.tscn";
    Ref<PackedScene> packed_systems =
        ResourceLoader::get_singleton()->load(systems_path);
    if (packed_systems.is_null()) {
        UtilityFunctions::push_warning(
            "Sistemi stealth non disponibili: ",
            systems_path
        );
        return;
    }
    Node *systems = packed_systems->instantiate();
    if (systems == nullptr) {
        return;
    }
    systems->set_name("StealthWorldDirector");
    add_child(systems);
}

void WorldDirector::create_interface() {
    CanvasLayer *interface_layer = memnew(CanvasLayer);
    interface_layer->set_name("Interface");

    Label *title = memnew(Label);
    title->set_text(
        "CRONO PARKOUR - CITTÀ MEDITERRANEA\n"
        "WASD muovi  |  SHIFT corsa  |  SPAZIO parkour/scala  |  "
        "S + SPAZIO salto muro-muro  |  CTRL scivola/scendi  |  "
        "Mouse sinistro attacco  |  F assassinio  |  E blocco/parry  |  "
        "R riparti  |  Esc mouse"
    );
    title->set_text(
        "CRONO PARKOUR - PIAZZA STEALTH APERTA\n"
        "WASD muovi  |  SHIFT corsa  |  SPAZIO parkour/scala  |  "
        "S + SPAZIO salto muro-muro  |  CTRL scivola/scendi  |  "
        "Mouse sinistro attacco  |  F assassinio  |  E blocco/parry  |  "
        "R riparti  |  Esc mouse"
    );
    title->set_position(Vector2(28.0, 24.0));
    title->add_theme_font_size_override("font_size", 18);
    title->add_theme_color_override("font_color", Color(1.0, 0.91, 0.74));
    title->add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.92));
    title->add_theme_constant_override("shadow_offset_x", 2);
    title->add_theme_constant_override("shadow_offset_y", 2);
    interface_layer->add_child(title);
    add_child(interface_layer);
}

void WorldDirector::_process(double) {
    if (advanced_player_ != nullptr &&
        Input::get_singleton()->is_action_just_pressed("reset_player")) {
        advanced_player_->set_global_position(Vector3(0.0F, 0.08F, 28.0F));
        advanced_player_->set_velocity(Vector3());
        advanced_player_->set_rotation(Vector3());
    }

    if (dynamic_ledge_snapshot_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            get_tree()->quit(1);
            return;
        }
        const String current_action =
            advanced_player_->get("current_action");
        if (
            current_action == "braced_enter" ||
            current_action == "free_enter"
        ) {
            Input::get_singleton()->action_release("go_up");
        }
        if (
            current_action == "braced_hang" ||
            current_action == "free_hang"
        ) {
            ++landing_pose_frames_;
            if (landing_pose_frames_ == 18) {
                capture_dynamic_ledge_snapshot();
            }
        }
        if (rendered_frames_ == 720) {
            get_tree()->quit(1);
        }
        return;
    }

    if (dynamic_action_snapshot_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Dynamic Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }
        const Vector3 player_position =
            advanced_player_->get_global_position();
        const Vector3 player_velocity = advanced_player_->get_velocity();
        const float horizontal_speed = Vector3(
            player_velocity.x,
            0.0F,
            player_velocity.z
        ).length();
        if (
            !advanced_jump_command_sent_ &&
            player_position.z < 23.45F &&
            horizontal_speed > 2.2F
        ) {
            Input::get_singleton()->action_press("drop");
            advanced_jump_command_sent_ = true;
        }
        const String current_action =
            advanced_player_->get("current_action");
        if (current_action == "slide") {
            Input::get_singleton()->action_release("drop");
            ++landing_pose_frames_;
            if (landing_pose_frames_ == 12) {
                capture_dynamic_action_snapshot();
            }
        }
        if (rendered_frames_ == 720) {
            UtilityFunctions::push_error(
                "Timeout cattura Dynamic Parkour."
            );
            get_tree()->quit(1);
        }
        return;
    }

    if (dynamic_vault_snapshot_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            get_tree()->quit(1);
            return;
        }
        const String current_action =
            advanced_player_->get("current_action");
        if (
            !advanced_jump_command_sent_ &&
            (
                current_action == "walk" ||
                current_action == "run"
            )
        ) {
            Input::get_singleton()->action_press("go_up");
            advanced_jump_command_sent_ = true;
        }
        if (current_action == "vault") {
            Input::get_singleton()->action_release("go_up");
            ++landing_pose_frames_;
            if (landing_pose_frames_ == 17) {
                capture_dynamic_vault_snapshot();
            }
        }
        if (rendered_frames_ == 420) {
            get_tree()->quit(1);
        }
        return;
    }

    if (dynamic_wall_climb_snapshot_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            get_tree()->quit(1);
            return;
        }
        const String current_action =
            advanced_player_->get("current_action");
        if (current_action == "wall_climb") {
            ++landing_pose_frames_;
            if (landing_pose_frames_ == 38) {
                capture_dynamic_wall_climb_snapshot();
            }
        }
        if (rendered_frames_ == 420) {
            get_tree()->quit(1);
        }
        return;
    }

    if (advanced_movement_test_requested_) {
        ++rendered_frames_;
        if (rendered_frames_ == 180) {
            Input::get_singleton()->action_release("forward");
            Input::get_singleton()->action_release("move_fast");
            if (advanced_player_ == nullptr) {
                UtilityFunctions::push_error(
                    "Advanced Parkour Player non è stato istanziato."
                );
                get_tree()->quit(1);
                return;
            }
            const Vector3 displacement =
                advanced_player_->get_global_position() - movement_test_start_;
            const bool moved_into_bazaar =
                displacement.z < -3.0F &&
                Math::abs(displacement.x) < 1.0F;
            UtilityFunctions::print(
                "Advanced controller movement displacement: ",
                displacement,
                moved_into_bazaar ? " PASS" : " FAIL"
            );
            get_tree()->quit(moved_into_bazaar ? 0 : 1);
        }
        return;
    }

    if (dynamic_slide_test_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Dynamic Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }
        const String current_action =
            advanced_player_->get("current_action");
        const Vector3 slide_velocity = advanced_player_->get_velocity();
        const float horizontal_speed = Vector3(
            slide_velocity.x,
            0.0F,
            slide_velocity.z
        ).length();
        if (
            !advanced_jump_command_sent_ &&
            current_action == "run" &&
            horizontal_speed > 2.2F
        ) {
            Input::get_singleton()->action_press("drop");
            advanced_jump_command_sent_ = true;
        }
        const bool slide_played =
            bool(advanced_player_->call("has_performed", "slide"));
        if (slide_played && !advanced_jump_command_released_) {
            Input::get_singleton()->action_release("drop");
            advanced_jump_command_released_ = true;
        }
        if (rendered_frames_ == 240) {
            Input::get_singleton()->action_release("forward");
            Input::get_singleton()->action_release("move_fast");
            const Vector3 displacement =
                advanced_player_->get_global_position() - movement_test_start_;
            const bool slide_completed =
                String(advanced_player_->get("last_completed_action")) ==
                    "slide";
            const bool passed_under_beam =
                displacement.z < -3.2F &&
                Math::abs(displacement.x) < 0.35F;
            const bool passed =
                slide_played && slide_completed && passed_under_beam;
            UtilityFunctions::print(
                "Dynamic slide displacement: ",
                displacement,
                " played/completed: ",
                slide_played,
                "/",
                slide_completed,
                passed ? " PASS" : " FAIL"
            );
            get_tree()->quit(passed ? 0 : 1);
        }
        return;
    }

    if (dynamic_predicted_jump_test_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Dynamic Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }
        if (rendered_frames_ == 8) {
            Input::get_singleton()->action_release("go_up");
        }
        advanced_jump_max_height_ = Math::max(
            advanced_jump_max_height_,
            advanced_player_->get_global_position().y
        );
        if (rendered_frames_ == 120) {
            Input::get_singleton()->action_release("forward");
            const Vector3 displacement =
                advanced_player_->get_global_position() - movement_test_start_;
            const bool prediction_played =
                bool(advanced_player_->call(
                    "has_performed",
                    "predicted_jump"
                ));
            const bool reached_target =
                displacement.z < -2.6F &&
                Math::abs(displacement.x) < 0.45F &&
                advanced_player_->get_global_position().y > 1.2F;
            const bool used_parabola =
                advanced_jump_max_height_ > movement_test_start_.y + 0.75F;
            const bool passed =
                prediction_played && reached_target && used_parabola;
            UtilityFunctions::print(
                "Dynamic predicted jump displacement: ",
                displacement,
                " peak y: ",
                advanced_jump_max_height_,
                " animation: ",
                prediction_played,
                passed ? " PASS" : " FAIL"
            );
            get_tree()->quit(passed ? 0 : 1);
        }
        return;
    }

    if (
        dynamic_vault_test_requested_ ||
        dynamic_reach_test_requested_
    ) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Dynamic Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }
        const String expected_action =
            dynamic_vault_test_requested_ ? "vault" : "reach_high";
        const String current_action =
            advanced_player_->get("current_action");
        if (
            !advanced_jump_command_sent_ &&
            (
                current_action == "walk" ||
                current_action == "run"
            )
        ) {
            Input::get_singleton()->action_press("go_up");
            advanced_jump_command_sent_ = true;
        }
        const bool action_played =
            bool(advanced_player_->call(
                "has_performed",
                expected_action
            ));
        if (action_played && !advanced_jump_command_released_) {
            Input::get_singleton()->action_release("go_up");
            advanced_jump_command_released_ = true;
        }
        advanced_jump_max_height_ = Math::max(
            advanced_jump_max_height_,
            advanced_player_->get_global_position().y
        );
        if (rendered_frames_ == 240) {
            Input::get_singleton()->action_release("forward");
            Input::get_singleton()->action_release("go_up");
            const Vector3 displacement =
                advanced_player_->get_global_position() - movement_test_start_;
            const bool completed =
                String(advanced_player_->get("last_completed_action")) ==
                    expected_action;
            const bool reached_context =
                displacement.z < -0.65F &&
                (
                    dynamic_vault_test_requested_ ||
                    advanced_jump_max_height_ > 1.25F
                );
            const bool passed =
                action_played && completed && reached_context;
            UtilityFunctions::print(
                "Dynamic ",
                expected_action,
                " displacement: ",
                displacement,
                " peak y: ",
                advanced_jump_max_height_,
                " played/completed: ",
                action_played,
                "/",
                completed,
                passed ? " PASS" : " FAIL"
            );
            get_tree()->quit(passed ? 0 : 1);
        }
        return;
    }

    if (advanced_jump_test_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Advanced Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }

        const String current_action =
            advanced_player_->get("current_action");
        if (
            !advanced_jump_command_sent_ &&
            current_action == "run"
        ) {
            Input::get_singleton()->action_press("go_up");
            advanced_jump_command_sent_ = true;
        }
        if (
            !advanced_jump_command_released_ &&
            bool(advanced_player_->call("has_performed", "jump"))
        ) {
            Input::get_singleton()->action_release("go_up");
            advanced_jump_command_released_ = true;
        }

        advanced_jump_max_height_ = Math::max(
            advanced_jump_max_height_,
            advanced_player_->get_global_position().y
        );

        saw_advanced_jump_state_ =
            saw_advanced_jump_state_ ||
            bool(advanced_player_->call("has_performed", "jump"));
        saw_advanced_midair_state_ =
            saw_advanced_midair_state_ ||
            bool(advanced_player_->call("has_performed", "fall"));
        saw_advanced_landing_state_ =
            saw_advanced_landing_state_ ||
            bool(advanced_player_->call("has_performed", "landing"));

        if (rendered_frames_ == 320) {
            Input::get_singleton()->action_release("forward");
            Input::get_singleton()->action_release("move_fast");
            Input::get_singleton()->action_release("go_up");
            const Vector3 displacement =
                advanced_player_->get_global_position() - movement_test_start_;
            const bool animated_jump =
                advanced_jump_max_height_ > movement_test_start_.y + 0.15F &&
                displacement.z < -2.0F &&
                saw_advanced_jump_state_ &&
                saw_advanced_midair_state_ &&
                saw_advanced_landing_state_;
            UtilityFunctions::print(
                "Dynamic animated jump displacement: ",
                displacement,
                " peak y: ",
                advanced_jump_max_height_,
                " states jump/midair/landing: ",
                saw_advanced_jump_state_,
                "/",
                saw_advanced_midair_state_,
                "/",
                saw_advanced_landing_state_,
                animated_jump ? " PASS" : " FAIL"
            );
            get_tree()->quit(animated_jump ? 0 : 1);
        }
        return;
    }

    if (advanced_ledge_test_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Advanced Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }

        const String current_action =
            advanced_player_->get("current_action");
        if (
            current_action == "braced_enter" ||
            current_action == "free_enter"
        ) {
            Input::get_singleton()->action_release("go_up");
        }
        if (
            !advanced_jump_command_sent_ &&
            (
                current_action == "braced_hang" ||
                current_action == "free_hang"
            )
        ) {
            Input::get_singleton()->action_press("go_up");
            advanced_jump_command_sent_ = true;
        }
        if (
            advanced_jump_command_sent_ &&
            !advanced_jump_command_released_ &&
            (
                current_action == "braced_climb" ||
                current_action == "free_climb"
            )
        ) {
            Input::get_singleton()->action_release("go_up");
            advanced_jump_command_released_ = true;
        }

        saw_advanced_ledge_climb_state_ =
            saw_advanced_ledge_climb_state_ ||
            bool(advanced_player_->call("has_performed", "braced_climb")) ||
            bool(advanced_player_->call("has_performed", "free_climb"));
        saw_advanced_ledge_completion_state_ =
            saw_advanced_ledge_completion_state_ ||
            (
                saw_advanced_ledge_climb_state_ &&
                String(advanced_player_->get("current_action")) == "idle"
            );

        if (
            saw_advanced_ledge_completion_state_ ||
            rendered_frames_ == 720
        ) {
            Input::get_singleton()->action_release("go_up");
            const Vector3 displacement =
                advanced_player_->get_global_position() - movement_test_start_;
            const bool climbed_ledge =
                saw_advanced_ledge_climb_state_ &&
                saw_advanced_ledge_completion_state_ &&
                displacement.y > 1.5F &&
                displacement.z < -0.25F;
            UtilityFunctions::print(
                "Dynamic ledge displacement: ",
                displacement,
                " saw ledge climb animation: ",
                saw_advanced_ledge_climb_state_,
                " completed: ",
                saw_advanced_ledge_completion_state_,
                climbed_ledge ? " PASS" : " FAIL"
            );
            get_tree()->quit(climbed_ledge ? 0 : 1);
        }
        return;
    }

    if (advanced_flat_wall_test_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Advanced Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }

        saw_advanced_flat_wall_climb_ =
            saw_advanced_flat_wall_climb_ ||
            bool(advanced_player_->call("has_performed", "wall_climb"));

        if (rendered_frames_ == 240) {
            Input::get_singleton()->action_release("forward");
            Input::get_singleton()->action_release("go_up");
            const Vector3 position = advanced_player_->get_global_position();
            const Vector3 displacement = position - movement_test_start_;
            const bool remained_outside_wall =
                position.z > -0.15F && position.z < 0.52F;
            const bool climbed_flat_wall =
                saw_advanced_flat_wall_climb_ &&
                displacement.y > 1.5F &&
                remained_outside_wall;
            UtilityFunctions::print(
                "Advanced flat wall displacement: ",
                displacement,
                " active climb observed: ",
                saw_advanced_flat_wall_climb_,
                " outside wall: ",
                remained_outside_wall,
                climbed_flat_wall ? " PASS" : " FAIL"
            );
            get_tree()->quit(climbed_flat_wall ? 0 : 1);
        }
        return;
    }

    if (dynamic_wall_to_wall_test_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            UtilityFunctions::push_error(
                "Dynamic Parkour Player non è stato istanziato."
            );
            get_tree()->quit(1);
            return;
        }

        const String current_action =
            advanced_player_->get("current_action");
        if (
            dynamic_wall_test_stage_ == 0 &&
            current_action == "wall_climb" &&
            advanced_player_->get_global_position().y > 0.28F
        ) {
            Input::get_singleton()->action_release("go_up");
            Input::get_singleton()->action_release("forward");
            Input::get_singleton()->action_press("backward");
            dynamic_wall_test_stage_ = 1;
        } else if (dynamic_wall_test_stage_ == 1) {
            Input::get_singleton()->action_press("go_up");
            dynamic_wall_test_stage_ = 2;
        }

        saw_dynamic_wall_jump_ =
            saw_dynamic_wall_jump_ ||
            bool(advanced_player_->call("has_performed", "wall_jump"));
        if (saw_dynamic_wall_jump_ && dynamic_wall_test_stage_ == 2) {
            Input::get_singleton()->action_release("go_up");
            Input::get_singleton()->action_release("backward");
            dynamic_wall_test_stage_ = 3;
        }

        if (
            saw_dynamic_wall_jump_ &&
            current_action == "wall_climb" &&
            advanced_player_->get_global_position().z > 0.95F
        ) {
            saw_dynamic_opposite_wall_regrab_ = true;
            ++landing_pose_frames_;
        } else if (!saw_dynamic_opposite_wall_regrab_) {
            landing_pose_frames_ = 0;
        }

        if (
            landing_pose_frames_ >= 6 ||
            rendered_frames_ == 420
        ) {
            Input::get_singleton()->action_release("go_up");
            Input::get_singleton()->action_release("forward");
            Input::get_singleton()->action_release("backward");
            const Vector3 displacement =
                advanced_player_->get_global_position() -
                movement_test_start_;
            const bool passed =
                saw_dynamic_wall_jump_ &&
                saw_dynamic_opposite_wall_regrab_ &&
                displacement.z > 0.90F;
            UtilityFunctions::print(
                "Dynamic wall-to-wall displacement: ",
                displacement,
                " jump/regrab: ",
                saw_dynamic_wall_jump_,
                "/",
                saw_dynamic_opposite_wall_regrab_,
                passed ? " PASS" : " FAIL"
            );
            get_tree()->quit(passed ? 0 : 1);
        }
        return;
    }

    if (dynamic_edge_guard_test_requested_) {
        ++rendered_frames_;
        if (advanced_player_ == nullptr) {
            get_tree()->quit(1);
            return;
        }
        if (rendered_frames_ == 150) {
            Input::get_singleton()->action_release("forward");
            const Vector3 position =
                advanced_player_->get_global_position();
            const bool guard_engaged = bool(
                advanced_player_->call(
                    "has_performed",
                    "edge_balance"
                )
            );
            const bool stayed_on_thin_top =
                position.y > 1.85F &&
                Math::abs(position.z) < 0.22F;
            const bool passed =
                guard_engaged && stayed_on_thin_top;
            UtilityFunctions::print(
                "Dynamic edge guard position: ",
                position,
                " guard/stable: ",
                guard_engaged,
                "/",
                stayed_on_thin_top,
                passed ? " PASS" : " FAIL"
            );
            get_tree()->quit(passed ? 0 : 1);
        }
        return;
    }

    if (jump_snapshot_requested_) {
        ++rendered_frames_;
        if (!jump_command_sent_ &&
            rendered_frames_ >= 30 &&
            player_->is_ready_for_parkour_jump()) {
            Input::get_singleton()->action_press("parkour");
            player_->trigger_forward_parkour_for_test();
            jump_command_sent_ = true;
        }
        saw_parkour_jump_ =
            saw_parkour_jump_ ||
            player_->is_parkour_jump_active();
        if (saw_parkour_jump_ &&
            player_->is_precision_landing_active()) {
            ++landing_pose_frames_;
            if (landing_pose_frames_ >= 8) {
                capture_jump_snapshot();
            }
        } else {
            landing_pose_frames_ = 0;
        }
        if (rendered_frames_ > 600) {
            UtilityFunctions::push_error(
                "Impossibile catturare l'atterraggio di precisione."
            );
            get_tree()->quit(1);
        }
        return;
    }

    if (stumble_test_requested_) {
        ++rendered_frames_;
        saw_stumble_recovery_ =
            saw_stumble_recovery_ ||
            player_->is_stumble_recovery_active();
        if (rendered_frames_ == 110) {
            const Vector3 displacement =
                player_->get_global_position() - movement_test_start_;
            const bool recovered =
                saw_stumble_recovery_ &&
                displacement.z < -0.5F;
            UtilityFunctions::print(
                "Near-stumble recovery test displacement: ",
                displacement,
                recovered ? " PASS" : " FAIL"
            );
            get_tree()->quit(recovered ? 0 : 1);
        }
        return;
    }

    if (climb_snapshot_requested_) {
        ++rendered_frames_;
        if (rendered_frames_ == 120) {
            capture_climb_snapshot();
        }
        return;
    }

    if (mantle_test_requested_) {
        ++rendered_frames_;
        const Vector3 current_position = player_->get_global_position();
        if (current_position.y > movement_test_start_.y + 0.25F &&
            current_position.y < 3.16F) {
            minimum_mantle_clearance_ = Math::min(
                minimum_mantle_clearance_,
                current_position.z + 2.175F
            );
        }
        if (rendered_frames_ == 330) {
            Input::get_singleton()->action_release("move_forward");
            Input::get_singleton()->action_release("parkour");
            const bool mantled =
                current_position.y > 3.18F &&
                current_position.z < -2.72F &&
                minimum_mantle_clearance_ >= 0.50F;
            UtilityFunctions::print(
                "Collision-safe mantle test position: ",
                current_position,
                " minimum pre-lift clearance: ",
                minimum_mantle_clearance_,
                mantled ? " PASS" : " FAIL"
            );
            get_tree()->quit(mantled ? 0 : 1);
        }
        return;
    }

    if (balance_test_requested_) {
        ++rendered_frames_;
        if (rendered_frames_ == 100) {
            Input::get_singleton()->action_release("move_forward");
            const Vector3 displacement =
                player_->get_global_position() - movement_test_start_;
            const bool balanced =
                displacement.z < -1.2F &&
                Math::abs(player_->get_global_position().x) < 0.085F &&
                player_->get_global_position().y > 0.30F;
            UtilityFunctions::print(
                "Tightrope auto-balance test position: ",
                player_->get_global_position(),
                " displacement: ",
                displacement,
                balanced ? " PASS" : " FAIL"
            );
            get_tree()->quit(balanced ? 0 : 1);
        }
        return;
    }

    if (vault_test_requested_) {
        ++rendered_frames_;
        if (rendered_frames_ == 150) {
            Input::get_singleton()->action_release("move_forward");
            Input::get_singleton()->action_release("parkour");
            const Vector3 displacement =
                player_->get_global_position() - movement_test_start_;
            // The obstacle's rear edge is z = -1.61. Reaching -1.75 places
            // the capsule safely beyond it; the previous -2.0 threshold
            // incorrectly required extra running after the vault itself.
            const bool vaulted =
                displacement.z < -1.75F &&
                Math::abs(displacement.x) < 0.65F &&
                displacement.y > -0.35F;
            UtilityFunctions::print(
                "Automatic obstacle classification test displacement: ",
                displacement,
                vaulted ? " PASS" : " FAIL"
            );
            get_tree()->quit(vaulted ? 0 : 1);
        }
        return;
    }

    if (smart_jump_test_requested_) {
        ++rendered_frames_;
        if (!jump_command_sent_ &&
            rendered_frames_ >= 30 &&
            player_->is_ready_for_parkour_jump()) {
            saw_precision_landing_ = false;
            Input::get_singleton()->action_press("parkour");
            player_->trigger_forward_parkour_for_test();
            jump_command_sent_ = true;
        }
        saw_parkour_jump_ =
            saw_parkour_jump_ ||
            player_->is_parkour_jump_active();
        if (saw_parkour_jump_) {
            saw_precision_landing_ =
                saw_precision_landing_ ||
                player_->is_precision_landing_active();
        }
        if (rendered_frames_ == 300) {
            Input::get_singleton()->action_release("move_forward");
            Input::get_singleton()->action_release("parkour");
            const Vector3 displacement =
                player_->get_global_position() - movement_test_start_;
            const bool guided_jump =
                displacement.z < -2.4F &&
                Math::abs(displacement.x) < 0.65F &&
                displacement.y > -0.35F &&
                saw_parkour_jump_ &&
                saw_precision_landing_;
            UtilityFunctions::print(
                "Intention jump test displacement: ",
                displacement,
                " saw airborne: ",
                saw_parkour_jump_,
                " saw foot landing: ",
                saw_precision_landing_,
                guided_jump ? " PASS" : " FAIL"
            );
            get_tree()->quit(guided_jump ? 0 : 1);
        }
        return;
    }

    if (climb_test_requested_) {
        ++rendered_frames_;
        const Vector3 current_position = player_->get_global_position();
        if (current_position.y > movement_test_start_.y + 0.25F) {
            // The test wall's front plane is z = -2.175. During climbing the
            // capsule origin must stay at least 0.50 m outside that plane.
            minimum_climb_clearance_ = Math::min(
                minimum_climb_clearance_,
                current_position.z + 2.175F
            );
        }
        if (rendered_frames_ == 240) {
            Input::get_singleton()->action_release("move_forward");
            Input::get_singleton()->action_release("parkour");
            const Vector3 displacement =
                player_->get_global_position() - movement_test_start_;
            const bool climbed_wall =
                displacement.y > 2.0F &&
                displacement.z < -1.0F &&
                Math::abs(displacement.x) < 0.8F &&
                minimum_climb_clearance_ >= 0.50F;
            UtilityFunctions::print(
                "Universal climb test displacement: ",
                displacement,
                " minimum wall clearance: ",
                minimum_climb_clearance_,
                climbed_wall ? " PASS" : " FAIL"
            );
            get_tree()->quit(climbed_wall ? 0 : 1);
        }
        return;
    }

    if (movement_test_requested_) {
        ++rendered_frames_;
        if (rendered_frames_ == 180) {
            Input::get_singleton()->action_release("move_forward");
            const Vector3 displacement =
                player_->get_global_position() - movement_test_start_;
            const bool moved_forward =
                displacement.z < -3.0F && Math::abs(displacement.x) < 1.0F;
            UtilityFunctions::print(
                "Movement test displacement: ",
                displacement,
                moved_forward ? " PASS" : " FAIL"
            );
            get_tree()->quit(moved_forward ? 0 : 1);
        }
        return;
    }

    if (!snapshot_requested_) {
        return;
    }
    ++rendered_frames_;
    if (rendered_frames_ == 120) {
        capture_snapshot();
    }
}

void WorldDirector::capture_snapshot() {
    Ref<Image> image = get_viewport()->get_texture()->get_image();
    if (image.is_valid()) {
        image->save_png("res://artifacts/bazaar_preview.png");
        UtilityFunctions::print("Anteprima salvata in res://artifacts/bazaar_preview.png");
    }
    get_tree()->quit();
}

void WorldDirector::capture_dynamic_action_snapshot() {
    Ref<Image> image = get_viewport()->get_texture()->get_image();
    if (image.is_valid()) {
        image->save_png(
            "res://artifacts/dynamic_parkour_preview.png"
        );
        UtilityFunctions::print(
            "Anteprima Dynamic Parkour salvata in "
            "res://artifacts/dynamic_parkour_preview.png"
        );
    }
    Input::get_singleton()->action_release("forward");
    Input::get_singleton()->action_release("move_fast");
    Input::get_singleton()->action_release("drop");
    get_tree()->quit();
}

void WorldDirector::capture_dynamic_ledge_snapshot() {
    const Vector3 left_hand = advanced_player_->call(
        "get_bone_world_position",
        "LeftHand"
    );
    const Vector3 right_hand = advanced_player_->call(
        "get_bone_world_position",
        "RightHand"
    );
    UtilityFunctions::print(
        "Dynamic ledge hands left/right: ",
        left_hand,
        " / ",
        right_hand,
        " ledge target: ",
        advanced_player_->get("ledge_top")
    );
    Ref<Image> image = get_viewport()->get_texture()->get_image();
    if (image.is_valid()) {
        image->save_png(
            "res://artifacts/dynamic_ledge_preview.png"
        );
        UtilityFunctions::print(
            "Anteprima sporgenza salvata in "
            "res://artifacts/dynamic_ledge_preview.png"
        );
    }
    Input::get_singleton()->action_release("go_up");
    get_tree()->quit();
}

void WorldDirector::capture_dynamic_vault_snapshot() {
    Ref<Image> image = get_viewport()->get_texture()->get_image();
    if (image.is_valid()) {
        image->save_png(
            "res://artifacts/dynamic_vault_preview.png"
        );
        UtilityFunctions::print(
            "Anteprima vault calibrato salvata in "
            "res://artifacts/dynamic_vault_preview.png"
        );
    }
    Input::get_singleton()->action_release("forward");
    Input::get_singleton()->action_release("go_up");
    get_tree()->quit();
}

void WorldDirector::capture_dynamic_wall_climb_snapshot() {
    const Vector3 left_hand = advanced_player_->call(
        "get_bone_world_position",
        "LeftHand"
    );
    const Vector3 right_hand = advanced_player_->call(
        "get_bone_world_position",
        "RightHand"
    );
    UtilityFunctions::print(
        "Wall climb hands left/right: ",
        left_hand,
        " / ",
        right_hand,
        " player: ",
        advanced_player_->get_global_position()
    );
    Ref<Image> image = get_viewport()->get_texture()->get_image();
    if (image.is_valid()) {
        image->save_png(
            "res://artifacts/dynamic_wall_climb_preview.png"
        );
        UtilityFunctions::print(
            "Anteprima scalata verticale salvata in "
            "res://artifacts/dynamic_wall_climb_preview.png"
        );
    }
    Input::get_singleton()->action_release("forward");
    Input::get_singleton()->action_release("go_up");
    get_tree()->quit();
}

void WorldDirector::capture_climb_snapshot() {
    Ref<Image> image = get_viewport()->get_texture()->get_image();
    if (image.is_valid()) {
        image->save_png("res://artifacts/climb_preview.png");
        UtilityFunctions::print(
            "Anteprima scalata salvata in res://artifacts/climb_preview.png"
        );
    }
    Input::get_singleton()->action_release("move_forward");
    Input::get_singleton()->action_release("parkour");
    get_tree()->quit();
}

void WorldDirector::capture_jump_snapshot() {
    Ref<Image> image = get_viewport()->get_texture()->get_image();
    if (image.is_valid()) {
        image->save_png("res://artifacts/jump_landing_preview.png");
        UtilityFunctions::print(
            "Anteprima atterraggio salvata in "
            "res://artifacts/jump_landing_preview.png"
        );
    }
    Input::get_singleton()->action_release("move_forward");
    Input::get_singleton()->action_release("parkour");
    get_tree()->quit();
}
