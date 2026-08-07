#include "parkour_actor.hpp"

#include <godot_cpp/classes/animation.hpp>
#include <godot_cpp/classes/animation_player.hpp>
#include <godot_cpp/classes/animation_library.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/ray_cast3d.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/classes/skeleton_ik3d.hpp>
#include <godot_cpp/classes/spring_arm3d.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <initializer_list>

using namespace godot;

namespace {

AnimationPlayer *find_animation_player(Node *node) {
    if (AnimationPlayer *player = Object::cast_to<AnimationPlayer>(node)) {
        return player;
    }
    for (int index = 0; index < node->get_child_count(); ++index) {
        if (AnimationPlayer *player = find_animation_player(node->get_child(index))) {
            return player;
        }
    }
    return nullptr;
}

Skeleton3D *find_skeleton(Node *node) {
    if (Skeleton3D *skeleton = Object::cast_to<Skeleton3D>(node)) {
        return skeleton;
    }
    for (int index = 0; index < node->get_child_count(); ++index) {
        if (Skeleton3D *skeleton = find_skeleton(node->get_child(index))) {
            return skeleton;
        }
    }
    return nullptr;
}

bool contains_any(const String &candidate, const std::initializer_list<const char *> &needles) {
    const String lowered = candidate.to_lower();
    for (const char *needle : needles) {
        if (lowered.contains(needle)) {
            return true;
        }
    }
    return false;
}

float staged_limb_reach(float phase) {
    float amount = Math::fmod(phase, 1.0F);
    if (amount < 0.0F) {
        amount += 1.0F;
    }
    if (amount < 0.18F) {
        const float t = amount / 0.18F;
        const float eased = t * t * (3.0F - 2.0F * t);
        return Math::lerp(-1.0F, 1.0F, eased);
    }
    if (amount < 0.54F) {
        return 1.0F;
    }
    if (amount < 0.72F) {
        const float t = (amount - 0.54F) / 0.18F;
        const float eased = t * t * (3.0F - 2.0F * t);
        return Math::lerp(1.0F, -1.0F, eased);
    }
    return -1.0F;
}

} // namespace

void ParkourActor::_bind_methods() {}

bool ParkourActor::is_precision_landing_active() const {
    return state_ == MovementState::PRECISION_LAND;
}

bool ParkourActor::is_stumble_recovery_active() const {
    return state_ == MovementState::STUMBLE_RECOVERY;
}

bool ParkourActor::is_ready_for_parkour_jump() const {
    return is_on_floor() &&
        (state_ == MovementState::IDLE ||
         state_ == MovementState::RUN ||
         state_ == MovementState::BALANCE);
}

bool ParkourActor::is_parkour_jump_active() const {
    return state_ == MovementState::JUMP ||
        state_ == MovementState::LONG_JUMP;
}

void ParkourActor::trigger_forward_parkour_for_test() {
    if (is_ready_for_parkour_jump()) {
        begin_smart_jump(Vector3(0.0F, 0.0F, -1.0F));
    }
}

void ParkourActor::_ready() {
    set_process_input(true);
    create_collision_and_sensors();
    create_camera();
    load_skeletal_character();
    begin_state(MovementState::IDLE);
    was_on_floor_ = is_on_floor();
    Input::get_singleton()->set_mouse_mode(Input::MOUSE_MODE_CAPTURED);
}

void ParkourActor::create_collision_and_sensors() {
    CollisionShape3D *collision = memnew(CollisionShape3D);
    collision->set_name("AthleticCapsule");
    Ref<CapsuleShape3D> capsule;
    capsule.instantiate();
    capsule->set_radius(0.38);
    capsule->set_height(1.78);
    collision->set_shape(capsule);
    collision->set_position(Vector3(0.0, 0.89, 0.0));
    add_child(collision);

    low_wall_ray_ = memnew(RayCast3D);
    low_wall_ray_->set_name("LowObstacleSensor");
    low_wall_ray_->set_position(Vector3(0.0, 0.48F, 0.0));
    low_wall_ray_->set_target_position(Vector3(0.0, 0.0, -1.18F));
    low_wall_ray_->set_enabled(true);
    add_child(low_wall_ray_);

    wall_ray_ = memnew(RayCast3D);
    wall_ray_->set_name("WallSensor");
    wall_ray_->set_position(Vector3(0.0, 1.05, 0.0));
    wall_ray_->set_target_position(Vector3(0.0, 0.0, -1.18));
    wall_ray_->set_enabled(true);
    add_child(wall_ray_);

    head_ray_ = memnew(RayCast3D);
    head_ray_->set_name("HeadClearanceSensor");
    head_ray_->set_position(Vector3(0.0, 1.78, 0.0));
    head_ray_->set_target_position(Vector3(0.0, 0.0, -1.1));
    head_ray_->set_enabled(true);
    add_child(head_ray_);

    obstacle_top_ray_ = memnew(RayCast3D);
    obstacle_top_ray_->set_name("ObstacleHeightSensor");
    obstacle_top_ray_->set_position(Vector3(0.0, 2.55F, -1.0F));
    obstacle_top_ray_->set_target_position(Vector3(0.0, -3.0F, 0.0));
    obstacle_top_ray_->set_enabled(true);
    add_child(obstacle_top_ray_);

    floor_ray_ = memnew(RayCast3D);
    floor_ray_->set_name("BalanceSurfaceSensor");
    floor_ray_->set_position(Vector3(0.0, 0.48, 0.0));
    floor_ray_->set_target_position(Vector3(0.0, -0.9, 0.0));
    floor_ray_->set_enabled(true);
    add_child(floor_ray_);

    const float distances[] = {2.2F, 3.0F, 3.8F, 4.6F, 5.4F};
    const float lateral_offsets[] = {-0.62F, 0.0F, 0.62F};
    int probe_index = 0;
    for (float distance : distances) {
        for (float lateral : lateral_offsets) {
            RayCast3D *probe = memnew(RayCast3D);
            probe->set_name(
                String("LandingProbe_") + String::num_int64(probe_index++)
            );
            probe->set_position(Vector3(lateral, 3.15F, -distance));
            probe->set_target_position(Vector3(0.0, -5.25F, 0.0));
            probe->set_enabled(true);
            add_child(probe);
            landing_rays_.push_back(probe);
        }
    }
}

void ParkourActor::create_camera() {
    camera_pivot_ = memnew(Node3D);
    camera_pivot_->set_name("CameraPivot");
    camera_pivot_->set_position(Vector3(0.0, 1.45, 0.0));
    add_child(camera_pivot_);

    spring_arm_ = memnew(SpringArm3D);
    spring_arm_->set_name("CameraCollisionArm");
    spring_arm_->set_length(5.6);
    spring_arm_->set_margin(0.22);
    camera_pivot_->add_child(spring_arm_);

    camera_ = memnew(Camera3D);
    camera_->set_name("GameplayCamera");
    camera_->set_fov(67.0);
    camera_->set_current(true);
    spring_arm_->add_child(camera_);
}

void ParkourActor::load_skeletal_character() {
    const String character_path =
        "res://assets/external/ual1/Animation Library[Standard]/Godot/"
        "AnimationLibrary_Godot_Standard.glb";
    Ref<PackedScene> packed = ResourceLoader::get_singleton()->load(character_path);
    if (packed.is_null()) {
        UtilityFunctions::push_error("Impossibile caricare il personaggio scheletrico: ", character_path);
        return;
    }

    Node *instance = packed->instantiate();
    visual_root_ = Object::cast_to<Node3D>(instance);
    if (visual_root_ == nullptr) {
        instance->queue_free();
        UtilityFunctions::push_error("La scena del personaggio non ha una radice 3D.");
        return;
    }

    visual_root_->set_name("SkeletalCharacter");
    visual_root_->set_rotation(Vector3(0.0, Math_PI, 0.0));
    add_child(visual_root_);
    apply_character_materials(visual_root_);
    visual_base_position_ = visual_root_->get_position();
    animation_player_ = find_animation_player(visual_root_);

    const String parkour_path =
        "res://assets/external/ual2/Universal Animation Library 2 [Standard]/"
        "Unreal-Godot/UAL2_Standard.glb";
    Ref<PackedScene> parkour_packed = ResourceLoader::get_singleton()->load(parkour_path);
    if (animation_player_ != nullptr && parkour_packed.is_valid()) {
        Node *donor_instance = parkour_packed->instantiate();
        Node3D *donor_root = Object::cast_to<Node3D>(donor_instance);
        AnimationPlayer *donor_player = find_animation_player(donor_instance);
        if (donor_root != nullptr && donor_player != nullptr) {
            const Ref<AnimationLibrary> source_library =
                donor_player->get_animation_library(StringName());
            if (source_library.is_valid()) {
                Ref<AnimationLibrary> parkour_library;
                parkour_library.instantiate();
                const char *selected_clips[] = {
                    "ClimbUp_1m_RM",
                    "Hit_Knockback",
                    "NinjaJump_Idle_Loop",
                    "NinjaJump_Land",
                    "NinjaJump_Start",
                    "Slide_Exit",
                    "Slide_Loop",
                    "Slide_Start",
                };
                for (const char *clip_name : selected_clips) {
                    const StringName clip(clip_name);
                    if (!source_library->has_animation(clip)) {
                        continue;
                    }
                    Ref<Animation> animation = source_library->get_animation(clip)->duplicate(true);
                    for (int track = animation->get_track_count() - 1; track >= 0; --track) {
                        const String path = String(animation->track_get_path(track));
                        if (path.contains("_04_leaf")) {
                            animation->remove_track(track);
                            continue;
                        }
                        // Locomotion is owned by CharacterBody3D. The RM clip
                        // translates its root roughly 1.68 m forward and 1 m
                        // upward; retaining that track would move the mesh a
                        // second time and visibly push it through the wall.
                        if (path.ends_with(":root") &&
                            animation->track_get_type(track) ==
                                Animation::TYPE_POSITION_3D) {
                            animation->remove_track(track);
                            continue;
                        }
                        animation->track_set_path(
                            track,
                            NodePath(path.replace("Armature/", "Rig/"))
                        );
                    }
                    if (String(clip) == "ClimbUp_1m_RM") {
                        animation->set_loop_mode(Animation::LOOP_LINEAR);
                    }
                    parkour_library->add_animation(clip, animation);
                }
                animation_player_->add_animation_library("parkour", parkour_library);
            }
            donor_player->set_active(false);
            donor_root->set_visible(false);
            donor_root->set_name("ParkourAnimationDonor");
            add_child(donor_root);
        } else {
            donor_instance->queue_free();
        }
    }

    setup_climb_ik();
}

void ParkourActor::apply_character_materials(Node *node) {
    if (MeshInstance3D *mesh = Object::cast_to<MeshInstance3D>(node)) {
        Ref<StandardMaterial3D> skin;
        skin.instantiate();
        skin->set_albedo(Color(0.56F, 0.285F, 0.16F));
        skin->set_roughness(0.76F);
        skin->set_metallic(0.0F);
        skin->set_feature(
            BaseMaterial3D::FEATURE_SUBSURFACE_SCATTERING,
            true
        );
        skin->set_subsurface_scattering_strength(0.09F);

        Ref<StandardMaterial3D> joint_skin;
        joint_skin.instantiate();
        joint_skin->set_albedo(Color(0.43F, 0.19F, 0.105F));
        joint_skin->set_roughness(0.82F);
        joint_skin->set_metallic(0.0F);
        joint_skin->set_feature(
            BaseMaterial3D::FEATURE_SUBSURFACE_SCATTERING,
            true
        );
        joint_skin->set_subsurface_scattering_strength(0.07F);

        const int surface_count =
            mesh->get_surface_override_material_count();
        if (surface_count > 0) {
            mesh->set_surface_override_material(0, skin);
        }
        if (surface_count > 1) {
            mesh->set_surface_override_material(1, joint_skin);
        }
    }

    for (int index = 0; index < node->get_child_count(); ++index) {
        apply_character_materials(node->get_child(index));
    }
}

void ParkourActor::setup_climb_ik() {
    skeleton_ = find_skeleton(visual_root_);
    if (skeleton_ == nullptr) {
        return;
    }

    auto create_limb_ik = [this](
        const char *name,
        const char *root_bone,
        const char *tip_bone
    ) -> SkeletonIK3D * {
        if (skeleton_->find_bone(root_bone) < 0 ||
            skeleton_->find_bone(tip_bone) < 0) {
            return nullptr;
        }

        SkeletonIK3D *ik = memnew(SkeletonIK3D);
        ik->set_name(name);
        ik->set_root_bone(root_bone);
        ik->set_tip_bone(tip_bone);
        ik->set_max_iterations(18);
        ik->set_min_distance(0.004F);
        ik->set_interpolation(1.0F);
        ik->set_influence(0.0F);
        ik->set_use_magnet(false);
        skeleton_->add_child(ik);
        ik->start(false);
        return ik;
    };

    left_hand_ik_ =
        create_limb_ik("LeftHandWallIK", "upperarm_l", "hand_l");
    right_hand_ik_ =
        create_limb_ik("RightHandWallIK", "upperarm_r", "hand_r");
    left_foot_ik_ =
        create_limb_ik("LeftFootWallIK", "thigh_l", "foot_l");
    right_foot_ik_ =
        create_limb_ik("RightFootWallIK", "thigh_r", "foot_r");
}

void ParkourActor::set_ik_world_target(
    SkeletonIK3D *ik,
    const Vector3 &world_position,
    float influence
) {
    if (skeleton_ == nullptr || ik == nullptr) {
        return;
    }
    const Transform3D world_target(Basis(), world_position);
    const Transform3D local_target =
        skeleton_->get_global_transform().affine_inverse() * world_target;
    ik->set_target_transform(local_target);
    ik->set_influence(Math::clamp(influence, 0.0F, 1.0F));
}

void ParkourActor::set_climb_ik_influence(float influence) {
    const float amount = Math::clamp(influence, 0.0F, 1.0F);
    if (left_hand_ik_ != nullptr) {
        left_hand_ik_->set_influence(amount);
    }
    if (right_hand_ik_ != nullptr) {
        right_hand_ik_->set_influence(amount);
    }
    if (left_foot_ik_ != nullptr) {
        left_foot_ik_->set_influence(amount);
    }
    if (right_foot_ik_ != nullptr) {
        right_foot_ik_->set_influence(amount);
    }
}

void ParkourActor::update_climb_ik() {
    if (skeleton_ == nullptr) {
        return;
    }

    const bool on_wall =
        state_ == MovementState::WALL_CLIMB ||
        state_ == MovementState::LEDGE_HANG ||
        state_ == MovementState::MANTLE;
    if (!on_wall) {
        set_climb_ik_influence(0.0F);
        if (state_ == MovementState::JUMP ||
            state_ == MovementState::PRECISION_LAND) {
            Vector3 actor_right =
                action_direction_.cross(Vector3(0.0F, 1.0F, 0.0F));
            if (actor_right.length_squared() < 0.01F) {
                actor_right = Vector3(1.0F, 0.0F, 0.0F);
            } else {
                actor_right = actor_right.normalized();
            }

            const Vector3 actor_position = get_global_position();
            const bool taking_off = state_ == MovementState::JUMP;
            const float duration =
                taking_off ? takeoff_duration_ : 0.42F;
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / duration,
                0.0F,
                1.0F
            );
            const float support =
                taking_off
                    ? 1.0F - Math::smoothstep(0.58F, 1.0F, amount)
                    : 1.0F - Math::smoothstep(0.46F, 1.0F, amount);
            const Vector3 left_plant =
                actor_position - actor_right * 0.16F -
                action_direction_ * 0.11F +
                Vector3(0.0F, 0.025F, 0.0F);
            const Vector3 right_plant =
                actor_position + actor_right * 0.16F +
                action_direction_ * 0.13F +
                Vector3(0.0F, 0.025F, 0.0F);
            set_ik_world_target(
                left_foot_ik_,
                left_plant,
                support
            );
            set_ik_world_target(
                right_foot_ik_,
                right_plant,
                support * (taking_off ? 0.82F : 1.0F)
            );
        }
        return;
    }

    const Vector3 wall_right =
        Vector3(0.0F, 1.0F, 0.0F).cross(wall_normal_).normalized();
    const Vector3 actor_position = get_global_position();
    Vector3 wall_plane =
        actor_position - wall_normal_ * wall_clearance_;
    if (state_ == MovementState::MANTLE) {
        wall_plane =
            mantle_lift_target_ - wall_normal_ * wall_clearance_;
        wall_plane.y = actor_position.y;
    }
    const float step_phase = static_cast<float>(state_time_ / 0.74);
    float influence = 0.92F;

    Vector3 left_hand;
    Vector3 right_hand;
    Vector3 left_foot;
    Vector3 right_foot;

    if (state_ == MovementState::LEDGE_HANG) {
        const float top_y = wall_top_point_.y;
        left_hand =
            wall_plane + wall_right * -0.27F +
            Vector3(0.0F, top_y - actor_position.y, 0.0F);
        right_hand =
            wall_plane + wall_right * 0.27F +
            Vector3(0.0F, top_y - actor_position.y, 0.0F);
        left_foot =
            wall_plane + wall_right * -0.18F +
            Vector3(0.0F, 0.42F, 0.0F);
        right_foot =
            wall_plane + wall_right * 0.18F +
            Vector3(0.0F, 0.27F, 0.0F);
        influence = 1.0F;
    } else {
        const float left_stride = staged_limb_reach(step_phase);
        const float right_stride =
            staged_limb_reach(step_phase + 0.5F);
        left_hand =
            wall_plane + wall_right * -0.28F +
            Vector3(0.0F, 1.42F + left_stride * 0.17F, 0.0F);
        right_hand =
            wall_plane + wall_right * 0.28F +
            Vector3(0.0F, 1.42F + right_stride * 0.17F, 0.0F);
        left_foot =
            wall_plane + wall_right * -0.20F +
            Vector3(0.0F, 0.38F + right_stride * 0.12F, 0.0F);
        right_foot =
            wall_plane + wall_right * 0.20F +
            Vector3(0.0F, 0.38F + left_stride * 0.12F, 0.0F);

        if (state_ == MovementState::MANTLE) {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / mantle_duration_,
                0.0F,
                1.0F
            );
            influence = 1.0F - Math::smoothstep(0.48F, 0.92F, amount);
        }
    }

    const Vector3 contact_offset = wall_normal_ * 0.018F;
    set_ik_world_target(left_hand_ik_, left_hand + contact_offset, influence);
    set_ik_world_target(right_hand_ik_, right_hand + contact_offset, influence);
    set_ik_world_target(left_foot_ik_, left_foot + contact_offset, influence * 0.82F);
    set_ik_world_target(right_foot_ik_, right_foot + contact_offset, influence * 0.82F);
}

void ParkourActor::_input(const Ref<InputEvent> &event) {
    Ref<InputEventMouseMotion> mouse = event;
    if (mouse.is_valid() && Input::get_singleton()->get_mouse_mode() == Input::MOUSE_MODE_CAPTURED) {
        const Vector2 relative = mouse->get_relative();
        camera_yaw_ -= relative.x * 0.0024;
        camera_pitch_ = Math::clamp(camera_pitch_ - relative.y * 0.0020, -0.82, 0.42);
    }

    Ref<InputEventKey> key = event;
    if (key.is_valid() && key->is_pressed() && key->get_keycode() == KEY_ESCAPE) {
        const Input::MouseMode current = Input::get_singleton()->get_mouse_mode();
        Input::get_singleton()->set_mouse_mode(
            current == Input::MOUSE_MODE_CAPTURED ? Input::MOUSE_MODE_VISIBLE : Input::MOUSE_MODE_CAPTURED
        );
    }
}

Vector3 ParkourActor::desired_world_direction() const {
    const Vector2 input = Input::get_singleton()->get_vector(
        "move_left",
        "move_right",
        "move_forward",
        "move_back"
    );
    if (input.length_squared() < 0.01) {
        return Vector3();
    }

    // camera_yaw_ is a world-space heading. Do not derive movement from the
    // pivot's global basis: the pivot is parented to the actor, so doing that
    // feeds the actor's own rotation back into the next movement frame and
    // makes a held key describe a circle.
    const Vector3 forward(
        -Math::sin(camera_yaw_),
        0.0,
        -Math::cos(camera_yaw_)
    );
    const Vector3 right(
        Math::cos(camera_yaw_),
        0.0,
        -Math::sin(camera_yaw_)
    );
    return (right * input.x + forward * -input.y).normalized();
}

void ParkourActor::update_camera(double delta) {
    const Vector3 rotation = camera_pivot_->get_rotation();
    const float weight = Math::clamp(static_cast<float>(delta * 12.0), 0.0F, 1.0F);
    const float local_yaw_target = camera_yaw_ - get_global_rotation().y;
    camera_pivot_->set_rotation(Vector3(
        Math::lerp(rotation.x, camera_pitch_, weight),
        local_yaw_target,
        0.0
    ));
}

bool ParkourActor::refresh_wall_contact() {
    wall_ray_->force_raycast_update();
    if (!wall_ray_->is_colliding()) {
        return false;
    }

    const Vector3 normal = wall_ray_->get_collision_normal().normalized();
    // Floors, sloped roofs and canopy tops are not climbable walls. Every
    // actual vertical collision surface is accepted without a material tag or
    // hand-authored climb marker.
    if (Math::abs(normal.y) > 0.52F) {
        return false;
    }

    wall_normal_ = normal;
    wall_contact_point_ = wall_ray_->get_collision_point();
    action_direction_ = -wall_normal_;
    return true;
}

bool ParkourActor::find_wall_top(Vector3 &top_point) {
    obstacle_top_ray_->force_raycast_update();
    if (!obstacle_top_ray_->is_colliding() ||
        obstacle_top_ray_->get_collision_normal().y < 0.68F) {
        return false;
    }

    const Vector3 candidate = obstacle_top_ray_->get_collision_point();
    const float relative_height = candidate.y - get_global_position().y;
    if (relative_height < 0.42F || relative_height > 2.72F) {
        return false;
    }

    top_point = candidate;
    return true;
}

void ParkourActor::enforce_wall_clearance(float follow_weight) {
    Vector3 position = get_global_position();
    const float signed_distance =
        (position - wall_contact_point_).dot(wall_normal_);
    const float error = wall_clearance_ - signed_distance;

    // Penetration is corrected fully in the same physics frame. Moving a
    // little too far away is eased back so contact never looks like a snap.
    const float correction =
        error > 0.0F
            ? error
            : error * Math::clamp(follow_weight, 0.0F, 1.0F);
    position += wall_normal_ * correction;
    set_global_position(position);
}

bool ParkourActor::find_best_landing(Vector3 &landing) const {
    const Vector3 origin = get_global_position();
    const float horizontal_speed =
        Vector2(get_velocity().x, get_velocity().z).length();
    const float preferred_distance =
        Math::clamp(2.8F + horizontal_speed * 0.42F, 2.5F, 5.3F);
    float best_score = -100000.0F;
    bool found = false;

    for (RayCast3D *probe : landing_rays_) {
        probe->force_raycast_update();
        if (!probe->is_colliding()) {
            continue;
        }

        const Vector3 normal = probe->get_collision_normal().normalized();
        if (normal.y < 0.68F) {
            continue;
        }

        const Vector3 point = probe->get_collision_point();
        const Vector3 offset = point - origin;
        Vector3 horizontal(offset.x, 0.0, offset.z);
        const float distance = horizontal.length();
        if (distance < 1.65F || distance > 5.85F ||
            offset.y < -2.25F || offset.y > 2.35F) {
            continue;
        }

        const float alignment =
            horizontal.normalized().dot(action_direction_.normalized());
        if (alignment < 0.72F) {
            continue;
        }

        const float score =
            alignment * 1.6F +
            normal.y * 0.35F -
            Math::abs(distance - preferred_distance) * 1.15F -
            Math::abs(offset.y) * 0.18F;
        if (score > best_score) {
            best_score = score;
            landing = point + normal * 0.055F;
            found = true;
        }
    }

    return found;
}

void ParkourActor::begin_smart_jump(const Vector3 &desired_direction) {
    if (desired_direction.length_squared() < 0.01F) {
        return;
    }

    action_direction_ = desired_direction.normalized();
    Vector3 rotation = get_rotation();
    rotation.y = Math::atan2(-action_direction_.x, -action_direction_.z);
    set_rotation(rotation);

    jump_start_ = get_global_position();
    has_guided_landing_ = find_best_landing(landing_target_);
    if (!has_guided_landing_) {
        landing_target_ =
            jump_start_ + action_direction_ * 3.25F +
            Vector3(0.0, -0.12F, 0.0);
    }

    Vector3 horizontal_delta = landing_target_ - jump_start_;
    horizontal_delta.y = 0.0;
    const float distance = horizontal_delta.length();
    jump_duration_ = Math::clamp(distance / 7.1F, 0.48F, 0.88F);
    jump_apex_height_ =
        Math::clamp(0.92F + distance * 0.16F, 1.15F, 1.82F);
    parkour_jump_pending_landing_ = true;
    begin_state(MovementState::JUMP);
}

void ParkourActor::begin_ledge_hang() {
    const Vector3 point = wall_ray_->get_collision_point();
    const Vector3 normal = wall_ray_->get_collision_normal().normalized();
    wall_normal_ = normal;
    wall_contact_point_ = point;
    action_direction_ = -normal;

    if (!find_wall_top(wall_top_point_)) {
        wall_top_point_ = point + Vector3(0.0F, 0.50F, 0.0F);
    }

    Vector3 hang_position = point + normal * wall_clearance_;
    hang_position.y = wall_top_point_.y - 1.52F;
    set_global_position(hang_position);

    Vector3 rotation = get_rotation();
    rotation.y = Math::atan2(-action_direction_.x, -action_direction_.z);
    set_rotation(rotation);
    begin_state(MovementState::LEDGE_HANG);
    set_velocity(Vector3());
}

bool ParkourActor::try_begin_wall_climb() {
    if (!Input::get_singleton()->is_action_pressed("parkour") ||
        !refresh_wall_contact()) {
        return false;
    }

    const float target_yaw =
        Math::atan2(-action_direction_.x, -action_direction_.z);
    Vector3 rotation = get_rotation();
    rotation.y = target_yaw;
    set_rotation(rotation);

    // Keep the capsule at a stable reach distance. This is the subtle
    // traversal "magnet": it corrects centimeters, never an impossible jump.
    Vector3 position = get_global_position();
    set_global_position(position);
    enforce_wall_clearance(0.72F);

    begin_state(MovementState::WALL_CLIMB);
    set_velocity(Vector3(0.0, 3.10F, 0.0));
    return true;
}

bool ParkourActor::prepare_mantle_from_wall() {
    Vector3 detected_top;
    if (find_wall_top(detected_top)) {
        wall_top_point_ = detected_top;
    } else if (wall_top_point_.y <= get_global_position().y + 0.35F) {
        return false;
    }

    mantle_start_ = get_global_position();
    mantle_lift_target_ =
        wall_contact_point_ + wall_normal_ * wall_clearance_;
    mantle_lift_target_.y = wall_top_point_.y + 0.07F;
    mantle_target_ =
        wall_top_point_ +
        action_direction_ * 0.48F +
        Vector3(0.0F, 0.07F, 0.0F);
    begin_state(MovementState::MANTLE);
    return true;
}

void ParkourActor::update_procedural_pose() {
    if (visual_root_ == nullptr) {
        return;
    }

    Vector3 position = visual_base_position_;
    Vector3 rotation(0.0, Math_PI, 0.0);
    const float phase = static_cast<float>(state_time_ * 7.2);

    switch (state_) {
        case MovementState::JUMP: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / takeoff_duration_,
                0.0F,
                1.0F
            );
            const float compression =
                Math::sin(amount * Math_PI * 0.82F);
            rotation.x = -compression * 0.12F;
            position.y -= compression * 0.105F;
            break;
        }
        case MovementState::LONG_JUMP: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / jump_duration_,
                0.0F,
                1.0F
            );
            rotation.x = -Math::sin(amount * Math_PI) * 0.22F;
            position.z -= Math::sin(amount * Math_PI) * 0.06F;
            break;
        }
        case MovementState::WALL_CLIMB:
            // The authored climb supplies the large body motion. These small
            // offsets give alternating weight transfer and prevent a rigid,
            // perfectly centered repetition on long walls.
            rotation.x = -0.045F;
            rotation.z = Math::sin(phase) * 0.055F;
            position.x += Math::sin(phase) * 0.035F;
            position.y += Math::sin(phase * 2.0F) * 0.025F;
            position.z += 0.025F;
            break;
        case MovementState::LEDGE_HANG:
            rotation.x = 0.075F;
            rotation.z = Math::sin(phase * 0.42F) * 0.025F;
            position.y -= 0.08F;
            position.z += 0.035F;
            break;
        case MovementState::MANTLE: {
            const float amount =
                Math::clamp(
                    static_cast<float>(state_time_) / mantle_duration_,
                    0.0F,
                    1.0F
                );
            rotation.x = -Math::sin(amount * Math_PI) * 0.18F;
            break;
        }
        case MovementState::VAULT: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / vault_duration_,
                0.0F,
                1.0F
            );
            rotation.x = -Math::sin(amount * Math_PI) * 0.34F;
            position.y -= Math::sin(amount * Math_PI) * 0.08F;
            break;
        }
        case MovementState::PRECISION_LAND: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / 0.42F,
                0.0F,
                1.0F
            );
            const float compression =
                Math::sin(amount * Math_PI);
            rotation.x = compression * 0.10F;
            position.y -= compression * 0.085F;
            break;
        }
        case MovementState::STUMBLE_RECOVERY: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / 0.70F,
                0.0F,
                1.0F
            );
            const float instability =
                Math::sin(amount * Math_PI);
            rotation.x = -instability * 0.18F;
            rotation.z =
                Math::sin(amount * Math_PI * 2.0F) *
                instability * 0.09F;
            position.x +=
                Math::sin(amount * Math_PI * 2.0F) * 0.045F;
            break;
        }
        case MovementState::BALANCE:
            rotation.z = Math::sin(phase * 0.36F) * 0.035F;
            break;
        default:
            break;
    }

    visual_root_->set_position(position);
    visual_root_->set_rotation(rotation);
}

void ParkourActor::update_ground_movement(double delta) {
    Vector3 velocity = get_velocity();
    const Vector3 desired = desired_world_direction();
    const bool parkour_held = Input::get_singleton()->is_action_pressed("parkour");
    const float top_speed = parkour_held ? 7.8F : 5.1F;
    const float acceleration = is_on_floor() ? 24.0F : 8.0F;
    const float delta_f = static_cast<float>(delta);

    velocity.x = Math::move_toward(velocity.x, desired.x * top_speed, acceleration * delta_f);
    velocity.z = Math::move_toward(velocity.z, desired.z * top_speed, acceleration * delta_f);

    if (!is_on_floor()) {
        velocity.y -= 22.0 * delta;
    } else if (velocity.y < 0.0) {
        velocity.y = -0.5;
    }

    if (desired.length_squared() > 0.01) {
        action_direction_ = desired;
        const float target_yaw = Math::atan2(-desired.x, -desired.z);
        Vector3 rotation = get_rotation();
        const float turn_weight = Math::clamp(static_cast<float>(delta * 13.0), 0.0F, 1.0F);
        rotation.y = Math::lerp_angle(rotation.y, target_yaw, turn_weight);
        set_rotation(rotation);
    }

    bool contextual_action_started = false;
    if (parkour_held &&
        (desired.length_squared() > 0.01F || !is_on_floor()) &&
        state_ != MovementState::VAULT &&
        state_ != MovementState::MANTLE) {
        low_wall_ray_->force_raycast_update();
        wall_ray_->force_raycast_update();
        head_ray_->force_raycast_update();
        obstacle_top_ray_->force_raycast_update();

        RayCast3D *obstacle_ray =
            wall_ray_->is_colliding() ? wall_ray_ : low_wall_ray_;
        const bool vertical_obstacle =
            obstacle_ray->is_colliding() &&
            Math::abs(obstacle_ray->get_collision_normal().y) <= 0.52F;
        float obstacle_height = 1000.0F;
        if (obstacle_top_ray_->is_colliding() &&
            obstacle_top_ray_->get_collision_normal().y > 0.65F) {
            obstacle_height =
                obstacle_top_ray_->get_collision_point().y -
                get_global_position().y;
        }

        const bool low_obstacle =
            vertical_obstacle &&
            is_on_floor() &&
            ((!wall_ray_->is_colliding() &&
              low_wall_ray_->is_colliding()) ||
             (obstacle_height > 0.12F &&
              obstacle_height < 1.05F));
        if (low_obstacle) {
            action_direction_ =
                -obstacle_ray->get_collision_normal().normalized();
            action_direction_.y = 0.0F;
            action_direction_ = action_direction_.normalized();
            vault_start_ = get_global_position();
            vault_target_ = vault_start_ + action_direction_ * 1.85F;
            velocity = Vector3();
            begin_state(MovementState::VAULT);
            contextual_action_started = true;
        } else if (vertical_obstacle && wall_ray_->is_colliding()) {
            if (!is_on_floor() &&
                velocity.y < -0.35F &&
                !head_ray_->is_colliding()) {
                begin_ledge_hang();
                contextual_action_started = true;
            } else {
                contextual_action_started = try_begin_wall_climb();
            }
            if (contextual_action_started) {
                velocity = get_velocity();
            }
        }
    }

    if (!contextual_action_started &&
        is_on_floor() &&
        Input::get_singleton()->is_action_just_pressed("parkour") &&
        desired.length_squared() > 0.01F) {
        begin_smart_jump(desired);
    }

    set_velocity(velocity);
}

void ParkourActor::update_parkour(double delta) {
    state_time_ += delta;
    Vector3 velocity = get_velocity();
    const bool parkour_held = Input::get_singleton()->is_action_pressed("parkour");

    switch (state_) {
        case MovementState::JUMP: {
            const float horizontal_speed = Math::max(
                Vector2(velocity.x, velocity.z).length(),
                3.25F
            );
            velocity =
                action_direction_ *
                Math::min(horizontal_speed, 5.4F);
            velocity.y = -0.16F;
            set_velocity(velocity);

            if (state_time_ >= takeoff_duration_) {
                jump_start_ = get_global_position();
                Vector3 remaining = landing_target_ - jump_start_;
                remaining.y = 0.0F;
                const float distance = remaining.length();
                jump_duration_ =
                    Math::clamp(distance / 7.1F, 0.44F, 0.84F);
                jump_apex_height_ =
                    Math::clamp(
                        0.88F + distance * 0.16F,
                        1.05F,
                        1.72F
                    );
                begin_state(MovementState::LONG_JUMP);
            }
            break;
        }
        case MovementState::LONG_JUMP: {
            const float progress = Math::clamp(
                static_cast<float>(state_time_) / jump_duration_,
                0.0F,
                1.15F
            );
            const Vector3 total_delta = landing_target_ - jump_start_;
            Vector3 horizontal_velocity(
                total_delta.x / jump_duration_,
                0.0,
                total_delta.z / jump_duration_
            );

            if (has_guided_landing_ && progress > 0.34F) {
                const float assistance = Math::clamp(
                    (progress - 0.34F) / 0.66F,
                    0.0F,
                    1.0F
                );
                const float smooth_assistance =
                    assistance * assistance * (3.0F - 2.0F * assistance);
                Vector3 remaining = landing_target_ - get_global_position();
                remaining.y = 0.0;
                const float remaining_time =
                    Math::max(jump_duration_ - static_cast<float>(state_time_), 0.13F);
                Vector3 correction =
                    remaining / remaining_time - horizontal_velocity;
                if (correction.length() > 2.35F) {
                    correction = correction.normalized() * 2.35F;
                }
                horizontal_velocity += correction * smooth_assistance;
            }

            const float vertical_velocity =
                total_delta.y / jump_duration_ +
                (4.0F * jump_apex_height_ / jump_duration_) *
                    (1.0F - 2.0F * Math::min(progress, 1.0F));
            velocity = horizontal_velocity;
            velocity.y = vertical_velocity;

            Vector3 facing = horizontal_velocity;
            facing.y = 0.0;
            if (facing.length_squared() > 0.01F) {
                action_direction_ = facing.normalized();
                Vector3 rotation = get_rotation();
                rotation.y =
                    Math::atan2(-action_direction_.x, -action_direction_.z);
                set_rotation(rotation);
            }
            set_velocity(velocity);

            if (progress >= 1.03F && !is_on_floor()) {
                begin_state(MovementState::FALL);
            }
            break;
        }
        case MovementState::WALL_CLIMB: {
            if (!parkour_held ||
                Input::get_singleton()->is_action_just_pressed("drop")) {
                set_velocity(wall_normal_ * 1.4F + Vector3(0.0, -1.0F, 0.0));
                begin_state(MovementState::FALL);
                break;
            }

            head_ray_->force_raycast_update();
            const bool has_wall = refresh_wall_contact();
            if (!has_wall) {
                if (state_time_ <= 0.14 ||
                    !prepare_mantle_from_wall()) {
                    begin_state(MovementState::FALL);
                }
                break;
            }

            const float target_yaw =
                Math::atan2(-action_direction_.x, -action_direction_.z);
            Vector3 rotation = get_rotation();
            rotation.y = target_yaw;
            set_rotation(rotation);

            enforce_wall_clearance(0.34F);

            const Vector2 climb_input = Input::get_singleton()->get_vector(
                "move_left",
                "move_right",
                "move_forward",
                "move_back"
            );
            const Vector3 wall_right =
                Vector3(0.0, 1.0, 0.0).cross(wall_normal_).normalized();
            const float grip_cycle = Math::fmod(
                static_cast<float>(state_time_),
                0.74F
            ) / 0.74F;
            float hesitation = 1.0F;
            if (grip_cycle < 0.12F) {
                const float t = grip_cycle / 0.12F;
                hesitation =
                    0.42F + 0.58F *
                    (t * t * (3.0F - 2.0F * t));
            }
            const float vertical_speed =
                climb_input.y > 0.35F
                    ? -1.55F
                    : 2.18F * hesitation;
            velocity =
                wall_right * climb_input.x * 1.65F +
                Vector3(0.0, vertical_speed, 0.0);
            set_velocity(velocity);

            if (!head_ray_->is_colliding() && state_time_ > 0.18) {
                if (!prepare_mantle_from_wall()) {
                    begin_state(MovementState::FALL);
                }
            } else if (Math::abs(wall_normal_.y) > 0.52F) {
                begin_state(MovementState::FALL);
            }
            break;
        }
        case MovementState::LEDGE_HANG: {
            set_velocity(Vector3());
            if ((parkour_held && state_time_ > 0.46) ||
                Input::get_singleton()->is_action_just_pressed("parkour")) {
                if (!prepare_mantle_from_wall()) {
                    begin_state(MovementState::FALL);
                }
            } else if (Input::get_singleton()->is_action_just_pressed("drop")) {
                begin_state(MovementState::FALL);
            }
            break;
        }
        case MovementState::MANTLE: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / mantle_duration_,
                0.0F,
                1.0F
            );
            Vector3 position;
            if (amount < 0.62F) {
                const float lift_amount = amount / 0.62F;
                const float eased =
                    lift_amount * lift_amount *
                    (3.0F - 2.0F * lift_amount);
                position = mantle_start_.lerp(mantle_lift_target_, eased);
            } else {
                const float cross_amount = (amount - 0.62F) / 0.38F;
                const float eased =
                    cross_amount * cross_amount *
                    (3.0F - 2.0F * cross_amount);
                position = mantle_lift_target_.lerp(mantle_target_, eased);
            }
            set_global_position(position);
            set_velocity(Vector3());
            if (amount >= 1.0F) {
                begin_state(MovementState::RUN);
            }
            break;
        }
        case MovementState::VAULT: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / vault_duration_,
                0.0F,
                1.0F
            );
            const float eased =
                amount * amount * (3.0F - 2.0F * amount);
            Vector3 position = vault_start_.lerp(vault_target_, eased);
            position.y += Math::sin(amount * Math_PI) * 1.18F;
            set_global_position(position);
            set_velocity(Vector3());
            if (amount >= 1.0F) {
                begin_state(MovementState::FALL);
            }
            break;
        }
        case MovementState::PRECISION_LAND: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / 0.42F,
                0.0F,
                1.0F
            );
            const float speed =
                Math::lerp(
                    Vector2(velocity.x, velocity.z).length(),
                    2.4F,
                    amount
                );
            set_velocity(action_direction_ * speed);
            if (amount >= 1.0F) {
                begin_state(
                    speed > 0.4F
                        ? MovementState::RUN
                        : MovementState::IDLE
                );
            }
            break;
        }
        case MovementState::STUMBLE_RECOVERY: {
            const float amount = Math::clamp(
                static_cast<float>(state_time_) / 0.70F,
                0.0F,
                1.0F
            );
            const float recovery_speed =
                Math::lerp(4.4F, 2.6F, amount);
            set_velocity(action_direction_ * recovery_speed);
            if (amount >= 1.0F) {
                begin_state(MovementState::RUN);
            }
            break;
        }
        case MovementState::LAND_ROLL:
            if (state_time_ < 0.48) {
                const float roll_amount = static_cast<float>(state_time_ / 0.48);
                set_velocity(action_direction_ * (6.8F + (3.7F - 6.8F) * roll_amount));
            } else {
                begin_state(MovementState::RUN);
            }
            break;
        default:
            break;
    }
}

void ParkourActor::_physics_process(double delta) {
    if (Input::get_singleton()->is_action_just_pressed("reset_player")) {
        set_global_position(Vector3(0.0, 1.2, 28.0));
        set_velocity(Vector3());
        begin_state(MovementState::IDLE);
    }

    const bool authored_motion =
        state_ == MovementState::JUMP ||
        state_ == MovementState::LONG_JUMP ||
        state_ == MovementState::VAULT ||
        state_ == MovementState::PRECISION_LAND ||
        state_ == MovementState::STUMBLE_RECOVERY ||
        state_ == MovementState::WALL_CLIMB ||
        state_ == MovementState::LEDGE_HANG ||
        state_ == MovementState::MANTLE ||
        state_ == MovementState::LAND_ROLL;

    if (!authored_motion) {
        update_ground_movement(delta);
    }
    update_parkour(delta);
    // Update after the actor has turned so the child pivot cancels that turn
    // in the same frame and keeps a stable world-space camera heading.
    update_camera(delta);

    if (state_ != MovementState::MANTLE && state_ != MovementState::LEDGE_HANG) {
        move_and_slide();
    }

    const bool grounded = is_on_floor();
    Vector3 velocity = get_velocity();
    bool on_balance_surface = false;
    if (grounded) {
        floor_ray_->force_raycast_update();
        if (floor_ray_->is_colliding()) {
            Node *surface = Object::cast_to<Node>(floor_ray_->get_collider());
            on_balance_surface =
                surface != nullptr &&
                String(surface->get_name()).to_lower().contains("tightrope");
        }
        if (on_balance_surface) {
            Vector2 horizontal(velocity.x, velocity.z);
            if (horizontal.length() > 2.4F) {
                horizontal = horizontal.normalized() * 2.4F;
                velocity.x = horizontal.x;
                velocity.z = horizontal.y;
                set_velocity(velocity);
            }

            // A rounded invisible proxy gives us a useful surface normal:
            // away from the top of the rope it tilts sideways. Nudge the
            // capsule against that component so balance is assisted without
            // snapping or teleporting the player.
            const Vector3 surface_normal =
                floor_ray_->get_collision_normal().normalized();
            Vector3 lateral_normal(
                surface_normal.x,
                0.0F,
                surface_normal.z
            );
            if (lateral_normal.length() > 0.055F) {
                Vector3 position = get_global_position();
                const float correction = Math::min(
                    static_cast<float>(delta) * 0.72F,
                    0.024F
                );
                position -= lateral_normal.normalized() * correction;
                set_global_position(position);
            }
            begin_state(MovementState::BALANCE);
        }
    }

    if (!grounded && velocity.y < -0.25 &&
        state_ != MovementState::WALL_CLIMB &&
        state_ != MovementState::MANTLE) {
        wall_ray_->force_raycast_update();
        head_ray_->force_raycast_update();
        if (wall_ray_->is_colliding() &&
            !head_ray_->is_colliding() &&
            Input::get_singleton()->is_action_pressed("parkour") &&
            velocity.y < -1.0) {
            begin_ledge_hang();
        } else if (state_ != MovementState::LONG_JUMP && state_ != MovementState::JUMP) {
            begin_state(MovementState::FALL);
        }
    }

    const bool preserving_parkour_state =
        state_ == MovementState::WALL_CLIMB ||
        state_ == MovementState::LEDGE_HANG ||
        state_ == MovementState::MANTLE;

    if (grounded && !was_on_floor_ && !preserving_parkour_state) {
        const double horizontal_speed = Vector2(velocity.x, velocity.z).length();
        Vector3 landing_direction(velocity.x, 0.0F, velocity.z);
        if (landing_direction.length_squared() > 0.01F) {
            action_direction_ = landing_direction.normalized();
        }

        if (parkour_jump_pending_landing_ &&
            (has_guided_landing_ || horizontal_speed <= 7.6)) {
            begin_state(MovementState::PRECISION_LAND);
        } else if (horizontal_speed > 5.8) {
            begin_state(MovementState::LAND_ROLL);
        } else if (horizontal_speed > 3.2) {
            begin_state(MovementState::STUMBLE_RECOVERY);
        } else {
            begin_state(MovementState::PRECISION_LAND);
        }
        parkour_jump_pending_landing_ = false;
    } else if (
        grounded &&
        !on_balance_surface &&
        !preserving_parkour_state &&
        state_ != MovementState::JUMP &&
        state_ != MovementState::LONG_JUMP &&
        state_ != MovementState::LAND_ROLL &&
        state_ != MovementState::PRECISION_LAND &&
        state_ != MovementState::STUMBLE_RECOVERY &&
        state_ != MovementState::VAULT
    ) {
        const double horizontal_speed = Vector2(velocity.x, velocity.z).length();
        begin_state(horizontal_speed > 0.35 ? MovementState::RUN : MovementState::IDLE);
    }

    was_on_floor_ = grounded;
    update_animation();
    update_procedural_pose();
    update_climb_ik();
}

void ParkourActor::begin_state(MovementState next) {
    if (state_ == next) {
        return;
    }
    state_ = next;
    state_time_ = 0.0;
    if (next == MovementState::WALL_CLIMB ||
        next == MovementState::LEDGE_HANG ||
        next == MovementState::MANTLE) {
        current_animation_ = StringName();
    }
}

StringName ParkourActor::find_animation_for_state(MovementState desired) const {
    if (animation_player_ == nullptr) {
        return StringName();
    }
    const char *preferred = nullptr;
    switch (desired) {
        case MovementState::IDLE:
            preferred = "Idle_Loop";
            break;
        case MovementState::RUN:
            preferred = "Sprint_Loop";
            break;
        case MovementState::JUMP:
        case MovementState::LONG_JUMP:
            preferred = "parkour/NinjaJump_Start";
            break;
        case MovementState::FALL:
            preferred = "Jump_Loop";
            break;
        case MovementState::WALL_CLIMB:
        case MovementState::MANTLE:
            preferred = "parkour/ClimbUp_1m_RM";
            break;
        case MovementState::LEDGE_HANG:
            preferred = "parkour/NinjaJump_Idle_Loop";
            break;
        case MovementState::VAULT:
            preferred = "parkour/NinjaJump_Start";
            break;
        case MovementState::PRECISION_LAND:
            preferred = "parkour/NinjaJump_Land";
            break;
        case MovementState::STUMBLE_RECOVERY:
            preferred = "parkour/Hit_Knockback";
            break;
        case MovementState::LAND_ROLL:
            preferred = "Roll";
            break;
        case MovementState::BALANCE:
            preferred = "Idle_Loop";
            break;
    }
    if (preferred != nullptr && animation_player_->has_animation(preferred)) {
        return StringName(preferred);
    }

    const PackedStringArray animations = animation_player_->get_animation_list();
    for (int index = 0; index < animations.size(); ++index) {
        const String candidate = animations[index];
        bool matches = false;
        switch (desired) {
            case MovementState::IDLE:
                matches = contains_any(candidate, {"idle", "stand"});
                break;
            case MovementState::RUN:
                matches = contains_any(candidate, {"sprint", "run"});
                break;
            case MovementState::JUMP:
            case MovementState::LONG_JUMP:
                matches = contains_any(candidate, {"long jump", "jump", "leap"});
                break;
            case MovementState::FALL:
                matches = contains_any(candidate, {"fall", "air"});
                break;
            case MovementState::WALL_CLIMB:
                matches = contains_any(candidate, {"climb", "wall"});
                break;
            case MovementState::LEDGE_HANG:
                matches = contains_any(candidate, {"hang", "ledge"});
                break;
            case MovementState::MANTLE:
                matches = contains_any(candidate, {"mantle", "climb up", "ledge"});
                break;
            case MovementState::VAULT:
                matches = contains_any(candidate, {"vault"});
                break;
            case MovementState::PRECISION_LAND:
                matches = contains_any(candidate, {"jump land", "land"});
                break;
            case MovementState::STUMBLE_RECOVERY:
                matches =
                    contains_any(candidate, {"knockback", "hit", "recover"});
                break;
            case MovementState::LAND_ROLL:
                matches = contains_any(candidate, {"roll"});
                break;
            case MovementState::BALANCE:
                matches = contains_any(candidate, {"balance", "beam"});
                break;
        }
        if (matches) {
            return StringName(candidate);
        }
    }
    return animations.is_empty() ? StringName() : StringName(animations[0]);
}

void ParkourActor::update_animation() {
    if (animation_player_ == nullptr) {
        return;
    }
    StringName next = find_animation_for_state(state_);
    if (state_ == MovementState::LONG_JUMP &&
        state_time_ > jump_duration_ * 0.34F &&
        animation_player_->has_animation("parkour/NinjaJump_Idle_Loop")) {
        next = StringName("parkour/NinjaJump_Idle_Loop");
    }
    if (!next.is_empty() && next != current_animation_) {
        float animation_speed = 1.0F;
        if (state_ == MovementState::WALL_CLIMB) {
            animation_speed = 0.84F;
        } else if (state_ == MovementState::PRECISION_LAND) {
            animation_speed = 0.92F;
        } else if (state_ == MovementState::STUMBLE_RECOVERY) {
            animation_speed = 1.05F;
        }
        animation_player_->play(next, 0.16, animation_speed, false);
        current_animation_ = next;
    }
}
