#pragma once

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <vector>

namespace godot {

class AnimationPlayer;
class Camera3D;
class Node3D;
class RayCast3D;
class Skeleton3D;
class SkeletonIK3D;
class SpringArm3D;

class ParkourActor : public CharacterBody3D {
    GDCLASS(ParkourActor, CharacterBody3D)

public:
    enum class MovementState {
        IDLE,
        RUN,
        JUMP,
        LONG_JUMP,
        FALL,
        WALL_CLIMB,
        LEDGE_HANG,
        MANTLE,
        VAULT,
        PRECISION_LAND,
        STUMBLE_RECOVERY,
        LAND_ROLL,
        BALANCE,
    };

    ParkourActor() = default;
    ~ParkourActor() override = default;

    void _ready() override;
    void _physics_process(double delta) override;
    void _input(const Ref<InputEvent> &event) override;
    bool is_precision_landing_active() const;
    bool is_stumble_recovery_active() const;
    bool is_ready_for_parkour_jump() const;
    bool is_parkour_jump_active() const;
    void trigger_forward_parkour_for_test();

protected:
    static void _bind_methods();

private:
    void create_collision_and_sensors();
    void create_camera();
    void load_skeletal_character();
    void apply_character_materials(Node *node);
    void update_camera(double delta);
    void update_ground_movement(double delta);
    void update_parkour(double delta);
    void setup_climb_ik();
    void update_climb_ik();
    void set_climb_ik_influence(float influence);
    void set_ik_world_target(
        SkeletonIK3D *ik,
        const Vector3 &world_position,
        float influence
    );
    bool try_begin_wall_climb();
    bool refresh_wall_contact();
    bool find_wall_top(Vector3 &top_point);
    void enforce_wall_clearance(float follow_weight);
    bool find_best_landing(Vector3 &landing) const;
    void begin_smart_jump(const Vector3 &desired_direction);
    void begin_ledge_hang();
    bool prepare_mantle_from_wall();
    void update_procedural_pose();
    void begin_state(MovementState next);
    void update_animation();
    StringName find_animation_for_state(MovementState desired) const;
    Vector3 desired_world_direction() const;

    Node3D *visual_root_ = nullptr;
    AnimationPlayer *animation_player_ = nullptr;
    Skeleton3D *skeleton_ = nullptr;
    SkeletonIK3D *left_hand_ik_ = nullptr;
    SkeletonIK3D *right_hand_ik_ = nullptr;
    SkeletonIK3D *left_foot_ik_ = nullptr;
    SkeletonIK3D *right_foot_ik_ = nullptr;
    Node3D *camera_pivot_ = nullptr;
    SpringArm3D *spring_arm_ = nullptr;
    Camera3D *camera_ = nullptr;
    RayCast3D *wall_ray_ = nullptr;
    RayCast3D *low_wall_ray_ = nullptr;
    RayCast3D *head_ray_ = nullptr;
    RayCast3D *obstacle_top_ray_ = nullptr;
    RayCast3D *floor_ray_ = nullptr;
    std::vector<RayCast3D *> landing_rays_;

    MovementState state_ = MovementState::IDLE;
    StringName current_animation_;
    Vector3 action_direction_ = Vector3(0.0, 0.0, -1.0);
    Vector3 wall_normal_ = Vector3(0.0, 0.0, 1.0);
    Vector3 wall_contact_point_;
    Vector3 jump_start_;
    Vector3 landing_target_;
    Vector3 vault_start_;
    Vector3 vault_target_;
    Vector3 mantle_start_;
    Vector3 mantle_lift_target_;
    Vector3 mantle_target_;
    Vector3 wall_top_point_;
    Vector3 visual_base_position_;
    double state_time_ = 0.0;
    float jump_duration_ = 0.68F;
    float jump_apex_height_ = 1.35F;
    float takeoff_duration_ = 0.18F;
    float vault_duration_ = 0.58F;
    float mantle_duration_ = 0.88F;
    float wall_clearance_ = 0.52F;
    bool has_guided_landing_ = false;
    bool parkour_jump_pending_landing_ = false;
    float camera_yaw_ = 0.0F;
    float camera_pitch_ = -0.18F;
    bool was_on_floor_ = false;
};

} // namespace godot
