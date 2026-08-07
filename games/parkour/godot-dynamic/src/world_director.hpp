#pragma once

#include <godot_cpp/classes/node3d.hpp>

namespace godot {

class CharacterBody3D;
class Node;
class ParkourActor;

class WorldDirector : public Node3D {
    GDCLASS(WorldDirector, Node3D)

public:
    WorldDirector() = default;
    ~WorldDirector() override = default;

    void _ready() override;
    void _process(double delta) override;

protected:
    static void _bind_methods();

private:
    void create_input_map();
    void create_environment();
    void load_authored_district();
    bool load_advanced_parkour_player();
    void configure_advanced_movement_surfaces(Node *node);
    void create_physics_floor();
    void create_open_plaza_parkour_routes();
    void create_outlying_camps();
    void create_dynamic_parkour_routes();
    void create_combat_enemies();
    void create_overview_camera();
    void create_climb_test_wall();
    void create_mantle_test_wall();
    void create_advanced_ledge_test_obstacle();
    void create_advanced_flat_wall_test_obstacle();
    void create_dynamic_slide_test_obstacle();
    void create_dynamic_predicted_jump_test_course();
    void create_dynamic_vault_test_obstacle();
    void create_dynamic_reach_test_obstacle();
    void create_dynamic_wall_to_wall_test_course();
    void create_dynamic_edge_guard_test_platform();
    void create_vault_test_obstacle();
    void create_balance_test_rope();
    void create_stealth_world_systems();
    void create_interface();
    void capture_snapshot();
    void capture_dynamic_action_snapshot();
    void capture_dynamic_ledge_snapshot();
    void capture_dynamic_vault_snapshot();
    void capture_dynamic_wall_climb_snapshot();
    void capture_climb_snapshot();
    void capture_jump_snapshot();

    ParkourActor *player_ = nullptr;
    CharacterBody3D *advanced_player_ = nullptr;
    bool snapshot_requested_ = false;
    bool dynamic_action_snapshot_requested_ = false;
    bool dynamic_ledge_snapshot_requested_ = false;
    bool dynamic_vault_snapshot_requested_ = false;
    bool dynamic_wall_climb_snapshot_requested_ = false;
    bool climb_snapshot_requested_ = false;
    bool jump_snapshot_requested_ = false;
    bool movement_test_requested_ = false;
    bool climb_test_requested_ = false;
    bool mantle_test_requested_ = false;
    bool smart_jump_test_requested_ = false;
    bool stumble_test_requested_ = false;
    bool vault_test_requested_ = false;
    bool balance_test_requested_ = false;
    bool advanced_movement_test_requested_ = false;
    bool advanced_jump_test_requested_ = false;
    bool advanced_ledge_test_requested_ = false;
    bool advanced_flat_wall_test_requested_ = false;
    bool dynamic_slide_test_requested_ = false;
    bool dynamic_predicted_jump_test_requested_ = false;
    bool dynamic_vault_test_requested_ = false;
    bool dynamic_reach_test_requested_ = false;
    bool dynamic_wall_to_wall_test_requested_ = false;
    bool dynamic_edge_guard_test_requested_ = false;
    bool advanced_jump_command_sent_ = false;
    bool advanced_jump_command_released_ = false;
    bool saw_advanced_jump_state_ = false;
    bool saw_advanced_midair_state_ = false;
    bool saw_advanced_landing_state_ = false;
    bool saw_advanced_ledge_climb_state_ = false;
    bool saw_advanced_ledge_completion_state_ = false;
    bool saw_advanced_flat_wall_climb_ = false;
    bool saw_dynamic_wall_jump_ = false;
    bool saw_dynamic_opposite_wall_regrab_ = false;
    bool saw_precision_landing_ = false;
    bool saw_stumble_recovery_ = false;
    bool jump_command_sent_ = false;
    bool saw_parkour_jump_ = false;
    int landing_pose_frames_ = 0;
    int dynamic_wall_test_stage_ = 0;
    Vector3 movement_test_start_;
    float advanced_jump_max_height_ = -1000.0F;
    float minimum_climb_clearance_ = 1000.0F;
    float minimum_mantle_clearance_ = 1000.0F;
    int rendered_frames_ = 0;
};

} // namespace godot
