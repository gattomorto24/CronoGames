from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
TEXTURE = ROOT / "assets" / "textures" / "sandstone_plaster_basecolor.png"
OUTPUT = ROOT / "assets" / "models" / "bazaar_district.glb"
BLEND_OUTPUT = ROOT / "source_art" / "bazaar" / "bazaar_district.blend"
RNG = random.Random(0xC17A2026)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        if datablocks is not bpy.data.materials:
            continue


def pbr_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
    texture_path: Path | None = None,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    surface = material.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = color
    surface.inputs["Roughness"].default_value = roughness
    surface.inputs["Metallic"].default_value = metallic
    if texture_path:
        image = bpy.data.images.load(str(texture_path), check_existing=True)
        image.colorspace_settings.name = "sRGB"
        texture = material.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.interpolation = "Linear"
        texture.extension = "REPEAT"
        material.node_tree.links.new(
            texture.outputs["Color"],
            surface.inputs["Base Color"],
        )
        bump = material.node_tree.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.18
        bump.inputs["Distance"].default_value = 0.12
        material.node_tree.links.new(texture.outputs["Color"], bump.inputs["Height"])
        material.node_tree.links.new(bump.outputs["Normal"], surface.inputs["Normal"])
    return material


WALL = pbr_material(
    "M_WornSandstone",
    (0.61, 0.34, 0.17, 1.0),
    0.88,
    texture_path=TEXTURE,
)
WALL_DARK = pbr_material("M_DeepOchre", (0.31, 0.12, 0.055, 1.0), 0.92)
STONE = pbr_material("M_CutStone", (0.40, 0.30, 0.21, 1.0), 0.82)
WOOD = pbr_material("M_AgedWood", (0.16, 0.055, 0.022, 1.0), 0.76)
WOOD_LIGHT = pbr_material("M_WornWood", (0.34, 0.15, 0.055, 1.0), 0.72)
METAL = pbr_material("M_DarkIron", (0.055, 0.060, 0.065, 1.0), 0.36, 0.68)
ROOF = pbr_material("M_DustyRoof", (0.38, 0.25, 0.16, 1.0), 0.95)
GLASS = pbr_material("M_OxidizedGlass", (0.025, 0.12, 0.14, 1.0), 0.22, 0.05)
FABRICS = [
    pbr_material("M_FabricCrimson", (0.48, 0.018, 0.025, 1.0), 0.82),
    pbr_material("M_FabricIndigo", (0.12, 0.025, 0.32, 1.0), 0.84),
    pbr_material("M_FabricTurquoise", (0.015, 0.34, 0.35, 1.0), 0.78),
    pbr_material("M_FabricSaffron", (0.90, 0.29, 0.015, 1.0), 0.86),
]
GREEN = pbr_material("M_Leaves", (0.075, 0.22, 0.055, 1.0), 0.92)
POT = pbr_material("M_Terracotta", (0.42, 0.12, 0.055, 1.0), 0.88)
GROUND = pbr_material("M_StreetStone", (0.26, 0.20, 0.15, 1.0), 0.96)

# Catania-inspired palette from the supplied reference: pale volcanic stone,
# sun-warmed plaster, oxidised shutters and terracotta roofs.
PLASTERS = [
    pbr_material("M_LimestoneCream", (0.72, 0.60, 0.43, 1.0), 0.91),
    pbr_material("M_SunlitIvory", (0.86, 0.74, 0.56, 1.0), 0.89),
    pbr_material("M_FadedOchre", (0.73, 0.43, 0.18, 1.0), 0.92),
    pbr_material("M_WarmSalmon", (0.65, 0.30, 0.21, 1.0), 0.90),
    pbr_material("M_AgedRose", (0.56, 0.27, 0.22, 1.0), 0.93),
]
LAVA_STONE = pbr_material("M_LavaStone", (0.095, 0.085, 0.078, 1.0), 0.94)
PALE_STONE = pbr_material("M_PaleBaroqueStone", (0.74, 0.67, 0.56, 1.0), 0.86)
TERRACOTTA = pbr_material("M_TerracottaTiles", (0.45, 0.14, 0.065, 1.0), 0.94)
TERRACOTTA_LIGHT = pbr_material("M_SunlitTerracotta", (0.62, 0.23, 0.09, 1.0), 0.91)
SHUTTER_GREEN = pbr_material("M_OxidisedShutters", (0.055, 0.18, 0.15, 1.0), 0.82)
ROAD = pbr_material("M_DarkAvenue", (0.055, 0.052, 0.050, 1.0), 0.97)
SIDEWALK = pbr_material("M_PalePavement", (0.48, 0.43, 0.36, 1.0), 0.92)
MOUNTAIN = pbr_material("M_EtnaRock", (0.075, 0.12, 0.19, 1.0), 1.0)
SNOW = pbr_material("M_EtnaSnow", (0.82, 0.85, 0.86, 1.0), 0.86)


def finish_mesh(
    obj: bpy.types.Object,
    material: bpy.types.Material,
    bevel: float = 0.03,
    smooth: bool = False,
) -> bpy.types.Object:
    if obj.data and hasattr(obj.data, "materials"):
        obj.data.materials.append(material)
    # Preserve rounded silhouettes on physical architecture and landmarks.
    # Tiny decorative pieces are viewed in batches and do not justify one
    # modifier apiece.
    keep_bevel = (
        obj.name.endswith(("-col", "-colonly"))
        or obj.name.startswith(("baroque", "church", "cathedral", "etna"))
    )
    if bevel > 0.0 and keep_bevel:
        modifier = obj.modifiers.new("Edge wear", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def box(
    name: str,
    location: tuple[float, float, float],
    size: tuple[float, float, float],
    material: bpy.types.Material,
    bevel: float = 0.035,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish_mesh(obj, material, bevel)
    # UV projection is only useful for the one image-textured material.
    # Running Smart Project on thousands of solid-colour mouldings dominated
    # the previous export time without changing their appearance.
    if material == WALL:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=0.78, island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    vertices: int = 20,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    finish_mesh(obj, material, 0.02, True)
    return obj


def rope(
    name: str,
    points: list[tuple[float, float, float]],
    radius: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def arch_trim(
    prefix: str,
    facade_x: float,
    center_y: float,
    spring_z: float,
    radius: float,
) -> None:
    segments = 9
    for index in range(segments):
        angle = math.pi * index / (segments - 1)
        y = center_y + math.cos(angle) * radius
        z = spring_z + math.sin(angle) * radius
        stone = box(
            f"{prefix}_arch_stone_{index:02d}",
            (facade_x, y, z),
            (0.26, 0.32, 0.42),
            STONE,
            0.045,
        )
        stone.rotation_euler[0] = angle - math.pi * 0.5


def barred_window(
    prefix: str,
    x: float,
    y: float,
    z: float,
    width: float = 1.15,
    height: float = 1.45,
) -> None:
    box(f"{prefix}_window_recess", (x, y, z), (0.12, width, height), GLASS, 0.02)
    trim = 0.13
    box(f"{prefix}_lintel", (x, y, z + height * 0.5), (0.18, width + 0.3, trim), STONE)
    box(f"{prefix}_sill", (x, y, z - height * 0.5), (0.22, width + 0.36, trim), STONE)
    for side in (-1.0, 1.0):
        box(
            f"{prefix}_jamb_{side:+.0f}",
            (x, y + side * width * 0.5, z),
            (0.18, trim, height),
            STONE,
        )
    # Tall green shutters and pale surrounds replace the barred bazaar
    # windows, matching the Mediterranean façades in the reference.
    for side in (-1.0, 1.0):
        box(
            f"{prefix}_shutter_{side:+.0f}",
            (x + 0.035, y + side * (width * 0.5 + 0.20), z),
            (0.075, 0.32, height * 0.92),
            SHUTTER_GREEN,
            0.018,
        )


def balcony(
    prefix: str,
    x: float,
    facade_y: float,
    z: float,
    width: float,
) -> None:
    depth = 1.15
    outward = -1.0 if x < 0.0 else 1.0
    box(
        f"{prefix}_balcony_slab",
        (x + outward * depth * 0.45, facade_y, z),
        (depth, width, 0.18),
        STONE,
    )
    for bracket_y in (-width * 0.34, width * 0.34):
        bracket = box(
            f"{prefix}_bracket",
            (x + outward * 0.32, facade_y + bracket_y, z - 0.36),
            (0.62, 0.18, 0.72),
            WOOD,
            0.025,
        )
        bracket.rotation_euler[1] = outward * math.radians(28.0)
    rail_z = z + 0.66
    box(
        f"{prefix}_rail_top",
        (x + outward * 0.96, facade_y, rail_z),
        (0.07, width, 0.08),
        METAL,
        0.01,
    )
    for index in range(9):
        rail_y = facade_y - width * 0.45 + width * 0.9 * index / 8.0
        box(
            f"{prefix}_rail_{index:02d}",
            (x + outward * 0.96, rail_y, rail_z - 0.33),
            (0.035, 0.035, 0.68),
            METAL,
            0.005,
        )


def rooftop_clutter(prefix: str, x: float, y: float, top: float, width: float, depth: float) -> None:
    if RNG.random() < 0.7:
        tank_x = x + width * 0.23
        tank_y = y + depth * 0.18
        cylinder(f"{prefix}_water_tank", (tank_x, tank_y, top + 0.75), 0.52, 1.35, METAL, 24)
        for leg_x in (-0.32, 0.32):
            for leg_y in (-0.32, 0.32):
                box(
                    f"{prefix}_tank_leg",
                    (tank_x + leg_x, tank_y + leg_y, top + 0.12),
                    (0.07, 0.07, 0.28),
                    METAL,
                    0.008,
                )
    if RNG.random() < 0.6:
        pot_x = x - width * 0.25
        pot_y = y - depth * 0.18
        cylinder(f"{prefix}_pot", (pot_x, pot_y, top + 0.28), 0.3, 0.54, POT, 16)
        for leaf in range(7):
            angle = math.tau * leaf / 7.0
            stem = cylinder(
                f"{prefix}_plant_{leaf:02d}",
                (
                    pot_x + math.cos(angle) * 0.16,
                    pot_y + math.sin(angle) * 0.16,
                    top + 0.72 + (leaf % 2) * 0.12,
                ),
                0.09,
                0.62,
                GREEN,
                10,
            )
            stem.rotation_euler[0] = math.sin(angle) * 0.28
            stem.rotation_euler[1] = math.cos(angle) * 0.28


def mesh_object(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    material: bpy.types.Material,
    bevel: float = 0.0,
    smooth: bool = False,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    finish_mesh(obj, material, bevel, smooth)
    return obj


def gable_roof(
    prefix: str,
    x: float,
    y: float,
    eave_height: float,
    width: float,
    depth: float,
    ridge_height: float,
) -> float:
    overhang = 0.32
    half_width = width * 0.5 + overhang
    half_depth = depth * 0.5 + overhang
    ridge_z = eave_height + ridge_height
    vertices = [
        (x - half_width, y - half_depth, eave_height),
        (x + half_width, y - half_depth, eave_height),
        (x - half_width, y + half_depth, eave_height),
        (x + half_width, y + half_depth, eave_height),
        (x - half_width, y, ridge_z),
        (x + half_width, y, ridge_z),
    ]
    faces = [
        (0, 1, 5, 4),
        (4, 5, 3, 2),
        (0, 4, 2),
        (1, 3, 5),
        (0, 2, 3, 1),
    ]
    roof = mesh_object(
        f"{prefix}_pitched_roof-col",
        vertices,
        faces,
        TERRACOTTA,
        0.025,
    )
    roof["parkour_surface"] = True

    slope_angle = math.atan2(ridge_height, half_depth)
    tile_rows = 5
    for side in (-1.0, 1.0):
        for row in range(tile_rows):
            amount = (row + 0.35) / tile_rows
            tile_y = y + side * half_depth * amount
            tile_z = ridge_z - ridge_height * amount + 0.055
            ridge = box(
                f"{prefix}_tile_course_{side:+.0f}_{row:02d}",
                (x, tile_y, tile_z),
                (half_width * 2.02, 0.075, 0.065),
                TERRACOTTA_LIGHT if row % 3 == 0 else TERRACOTTA,
                0.014,
            )
            ridge.rotation_euler[0] = side * slope_angle

    box(
        f"{prefix}_roof_ridge",
        (x, y, ridge_z + 0.08),
        (half_width * 2.08, 0.18, 0.18),
        TERRACOTTA_LIGHT,
        0.045,
    )
    return ridge_z


def facade_bands(
    prefix: str,
    facade_x: float,
    center_y: float,
    depth: float,
    height: float,
    outward: float,
) -> None:
    for level in range(1, max(2, int(height // 3.0))):
        band_z = min(height - 0.32, level * 3.0)
        box(
            f"{prefix}_cornice_{level:02d}",
            (facade_x + outward * 0.08, center_y, band_z),
            (0.20, depth + 0.18, 0.16),
            PALE_STONE,
            0.018,
        )
    for side in (-1.0, 1.0):
        box(
            f"{prefix}_corner_quoin_{side:+.0f}",
            (
                facade_x + outward * 0.08,
                center_y + side * (depth * 0.5 - 0.18),
                height * 0.5,
            ),
            (0.20, 0.38, height),
            PALE_STONE,
            0.025,
        )


def building(
    index: int,
    x: float,
    y: float,
    width: float,
    depth: float,
    height: float,
    faces_street_positive_x: bool,
    wall_material: bpy.types.Material | None = None,
    pitched: bool = True,
) -> dict[str, float]:
    prefix = f"building_{index:02d}"
    material = wall_material or PLASTERS[index % len(PLASTERS)]
    shell = box(
        f"{prefix}-col",
        (x, y, height * 0.5),
        (width, depth, height),
        material,
        0.075,
    )
    shell["parkour_surface"] = True
    top = height
    roof_top = top
    if pitched:
        roof_top = gable_roof(
            prefix,
            x,
            y,
            top + 0.02,
            width,
            depth,
            RNG.uniform(1.1, 1.75),
        )
    else:
        parapet_height = 0.62
        parapet_width = 0.22
        box(f"{prefix}_parapet_n", (x, y - depth * 0.5, top + parapet_height * 0.5), (width, parapet_width, parapet_height), PALE_STONE)
        box(f"{prefix}_parapet_s", (x, y + depth * 0.5, top + parapet_height * 0.5), (width, parapet_width, parapet_height), PALE_STONE)
        box(f"{prefix}_parapet_w", (x - width * 0.5, y, top + parapet_height * 0.5), (parapet_width, depth, parapet_height), PALE_STONE)
        box(f"{prefix}_parapet_e", (x + width * 0.5, y, top + parapet_height * 0.5), (parapet_width, depth, parapet_height), PALE_STONE)
        box(f"{prefix}_roof", (x, y, top + 0.06), (width - 0.18, depth - 0.18, 0.12), ROOF, 0.02)

    facade_x = x + (-width * 0.5 - 0.05 if faces_street_positive_x else width * 0.5 + 0.05)
    outward = -1.0 if faces_street_positive_x else 1.0
    facade_bands(prefix, facade_x, y, depth, height, outward)
    door_z = 1.25
    box(f"{prefix}_door", (facade_x, y, door_z), (0.12, 1.35, 2.5), WOOD, 0.04)
    for board in range(5):
        box(
            f"{prefix}_door_board_{board:02d}",
            (
                facade_x + (-0.08 if faces_street_positive_x else 0.08),
                y - 0.5 + board * 0.25,
                door_z,
            ),
            (0.035, 0.07, 2.26),
            WOOD_LIGHT,
            0.008,
        )
    if abs(x) < 11.0 or index % 5 == 0:
        arch_trim(
            prefix,
            facade_x + (-0.12 if faces_street_positive_x else 0.12),
            y,
            2.36,
            0.82,
        )
    else:
        box(
            f"{prefix}_portal_lintel",
            (facade_x + outward * 0.08, y, 2.62),
            (0.20, 1.9, 0.28),
            PALE_STONE,
            0.02,
        )

    window_x = facade_x + (-0.08 if faces_street_positive_x else 0.08)
    for floor in range(1, max(2, int(height // 3.0))):
        window_z = 1.55 + floor * 2.45
        if window_z + 0.9 >= height:
            continue
        for offset in (-depth * 0.25, depth * 0.25):
            barred_window(
                f"{prefix}_f{floor}_{offset:+.1f}",
                window_x,
                y + offset,
                window_z,
                1.0,
                1.28,
            )

    if height > 7.1 and index % 3 == 0:
        balcony(prefix, window_x, y, min(height - 1.35, 4.45), min(3.6, depth * 0.62))
    if not pitched:
        rooftop_clutter(prefix, x, y, top, width, depth)
    return {
        "x": x,
        "y": y,
        "width": width,
        "depth": depth,
        "height": height,
        "roof_top": roof_top,
    }


def fabric_canopy(index: int, y: float, width: float, height: float) -> None:
    segments_x = 9
    vertices = []
    faces = []
    for side in range(2):
        x = -width * 0.5 if side == 0 else width * 0.5
        for segment in range(segments_x):
            amount = segment / (segments_x - 1)
            fabric_y = y - 2.1 + amount * 4.2
            sag = math.sin(amount * math.pi) * 0.52
            vertices.append((x, fabric_y, height - sag))
    for segment in range(segments_x - 1):
        a = segment
        b = segment + 1
        c = segments_x + segment + 1
        d = segments_x + segment
        faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new(f"canopy_{index:02d}_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(f"canopy_{index:02d}", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(FABRICS[index % len(FABRICS)])
    solidify = obj.modifiers.new("Fabric thickness", "SOLIDIFY")
    solidify.thickness = 0.035


def market_stall(index: int, x: float, y: float, rotation: float = 0.0) -> None:
    root = bpy.data.objects.new(f"stall_{index:02d}", None)
    bpy.context.collection.objects.link(root)
    root.location = (x, y, 0.0)
    root.rotation_euler[2] = rotation
    for post_x in (-1.15, 1.15):
        for post_y in (-0.65, 0.65):
            post = box(
                f"stall_{index:02d}_post",
                (post_x, post_y, 1.55),
                (0.10, 0.10, 3.1),
                WOOD,
                0.018,
            )
            post.parent = root
    counter = box(f"stall_{index:02d}_counter", (0.0, 0.0, 1.02), (2.5, 1.35, 0.18), WOOD_LIGHT)
    counter.parent = root
    canopy = box(f"stall_{index:02d}_awning", (0.0, 0.0, 3.08), (2.8, 1.75, 0.10), FABRICS[index % len(FABRICS)], 0.03)
    canopy.parent = root
    for basket in range(5):
        angle = math.tau * basket / 5.0
        fruit = cylinder(
            f"stall_{index:02d}_basket_{basket:02d}",
            (math.cos(angle) * 0.72, math.sin(angle) * 0.36, 1.24),
            0.22,
            0.22,
            POT,
            14,
        )
        fruit.parent = root


def street_pavers() -> None:
    box("main_avenue", (0.0, 1.5, -0.075), (8.4, 113.0, 0.15), ROAD, 0.02)
    for side in (-1.0, 1.0):
        box(
            f"main_sidewalk_{side:+.0f}",
            (side * 4.75, 1.5, 0.015),
            (1.05, 113.0, 0.18),
            SIDEWALK,
            0.025,
        )
        box(
            f"sidewalk_lava_curb_{side:+.0f}",
            (side * 4.23, 1.5, 0.13),
            (0.18, 113.0, 0.26),
            LAVA_STONE,
            0.018,
        )

    for index, cross_y in enumerate((-43.0, -21.0, 1.0, 23.0, 45.0)):
        box(
            f"cross_street_{index:02d}",
            (0.0, cross_y, -0.055),
            (98.0, 2.25, 0.13),
            ROAD,
            0.018,
        )
        for edge in (-1.0, 1.0):
            box(
                f"cross_street_{index:02d}_curb_{edge:+.0f}",
                (0.0, cross_y + edge * 1.28, 0.08),
                (98.0, 0.18, 0.16),
                LAVA_STONE,
                0.015,
            )

    for dash in range(-9, 10):
        box(
            f"avenue_center_dash_{dash:+03d}",
            (0.0, dash * 5.6 + 1.5, 0.018),
            (0.10, 2.5, 0.025),
            PALE_STONE,
            0.008,
        )


def bell_tower(prefix: str, x: float, y: float, base_height: float) -> None:
    box(
        f"{prefix}_tower-col",
        (x, y, base_height * 0.5),
        (5.7, 5.7, base_height),
        PALE_STONE,
        0.08,
    )
    for level in range(4):
        band_z = 3.0 + level * 3.0
        box(
            f"{prefix}_tower_band_{level:02d}",
            (x, y, band_z),
            (6.05, 6.05, 0.25),
            LAVA_STONE,
            0.025,
        )
    for side_x, side_y in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        opening = box(
            f"{prefix}_belfry_opening_{side_x:+d}_{side_y:+d}",
            (
                x + side_x * 2.88,
                y + side_y * 2.88,
                base_height - 2.1,
            ),
            (
                0.16 if side_x else 1.45,
                0.16 if side_y else 1.45,
                2.6,
            ),
            LAVA_STONE,
            0.06,
        )
        opening.rotation_euler[2] = 0.0
    cylinder(
        f"{prefix}_tower_crown",
        (x, y, base_height + 1.25),
        3.25,
        2.5,
        TERRACOTTA,
        24,
    )
    cylinder(
        f"{prefix}_tower_lantern",
        (x, y, base_height + 3.0),
        1.05,
        1.8,
        PALE_STONE,
        16,
    )


def dome_landmark(prefix: str, x: float, y: float) -> None:
    cylinder(f"{prefix}_nave-col", (x, y, 4.3), 6.0, 8.6, PALE_STONE, 32)
    cylinder(f"{prefix}_drum", (x, y, 10.0), 4.6, 3.0, PLASTERS[1], 32)
    for index in range(12):
        angle = math.tau * index / 12.0
        box(
            f"{prefix}_drum_pilaster_{index:02d}",
            (
                x + math.cos(angle) * 4.62,
                y + math.sin(angle) * 4.62,
                10.0,
            ),
            (0.32, 0.32, 3.2),
            PALE_STONE,
            0.025,
        )
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=40,
        ring_count=20,
        location=(x, y, 13.15),
    )
    dome = bpy.context.object
    dome.name = f"{prefix}_terracotta_dome-col"
    dome.scale = (4.75, 4.75, 3.25)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish_mesh(dome, TERRACOTTA, 0.02, True)
    cylinder(f"{prefix}_lantern", (x, y, 16.35), 0.78, 1.8, PALE_STONE, 16)


def church_complex() -> None:
    x = -27.0
    y = 29.0
    box("baroque_church_nave-col", (x, y, 5.2), (16.0, 18.0, 10.4), PALE_STONE, 0.09)
    gable_roof("baroque_church", x, y, 10.42, 16.0, 18.0, 3.1)
    facade_y = y - 9.12
    box("baroque_church_facade", (x, facade_y, 6.6), (16.6, 0.42, 13.2), PALE_STONE, 0.06)
    for column_x in (-6.1, -3.15, 3.15, 6.1):
        cylinder(
            f"church_column_{column_x:+.2f}",
            (x + column_x, facade_y - 0.34, 5.4),
            0.42,
            9.5,
            PALE_STONE,
            20,
        )
    box("church_portal", (x, facade_y - 0.28, 2.35), (3.1, 0.34, 4.7), WOOD, 0.08)
    for level in (3.0, 7.3, 11.0):
        box(
            f"church_facade_cornice_{level:.1f}",
            (x, facade_y - 0.18, level),
            (17.1, 0.55, 0.32),
            LAVA_STONE,
            0.025,
        )
    bell_tower("baroque", x - 10.0, y - 3.0, 18.5)


def volcano_backdrop() -> None:
    center_y = 104.0
    rings = [
        (0.0, 67.0, 18.0),
        (8.0, 50.0, 14.0),
        (18.0, 31.0, 9.0),
        (27.0, 15.0, 5.2),
        (34.0, 2.8, 1.2),
    ]
    segments = 40
    vertices: list[tuple[float, float, float]] = []
    for ring_index, (height, radius_x, radius_y) in enumerate(rings):
        for segment in range(segments):
            angle = math.tau * segment / segments
            ridge_noise = 1.0 + 0.055 * math.sin(angle * 5.0 + ring_index)
            vertices.append(
                (
                    math.cos(angle) * radius_x * ridge_noise,
                    center_y + math.sin(angle) * radius_y,
                    height + 0.45 * math.sin(angle * 7.0),
                )
            )
    faces: list[tuple[int, ...]] = []
    for ring_index in range(len(rings) - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            a = ring_index * segments + segment
            b = ring_index * segments + next_segment
            c = (ring_index + 1) * segments + next_segment
            d = (ring_index + 1) * segments + segment
            faces.append((a, b, c, d))
    mountain = mesh_object("etna_backdrop", vertices, faces, MOUNTAIN, 0.0, True)
    mountain["background_landmark"] = True

    snow_vertices = vertices[3 * segments :]
    snow_faces: list[tuple[int, ...]] = []
    for ring_index in range(1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            snow_faces.append(
                (
                    ring_index * segments + segment,
                    ring_index * segments + next_segment,
                    (ring_index + 1) * segments + next_segment,
                    (ring_index + 1) * segments + segment,
                )
            )
    mesh_object("etna_snow_cap", snow_vertices, snow_faces, SNOW, 0.0, True)


def distant_gable_roof(
    prefix: str,
    x: float,
    y: float,
    z: float,
    width: float,
    depth: float,
    rise: float,
) -> None:
    half_width = width * 0.54
    half_depth = depth * 0.54
    vertices = [
        (x - half_width, y - half_depth, z),
        (x + half_width, y - half_depth, z),
        (x - half_width, y + half_depth, z),
        (x + half_width, y + half_depth, z),
        (x, y - half_depth, z + rise),
        (x, y + half_depth, z + rise),
    ]
    faces = [
        (0, 2, 5, 4),
        (1, 4, 5, 3),
        (0, 4, 1),
        (2, 3, 5),
    ]
    mesh_object(prefix, vertices, faces, TERRACOTTA_LIGHT, 0.0, False)


def distant_city_backdrop() -> None:
    # Visual-only continuation between the playable rooftops and Etna.
    # It batches by material and therefore adds skyline depth without adding
    # physics bodies or parkour probes.
    box("distant_avenue", (0.0, 75.0, -0.06), (8.4, 42.0, 0.12), ROAD, 0.0)
    backdrop_index = 0
    x_centers = (
        -57.0, -50.0, -43.0, -36.0, -29.0, -22.0, -15.0, -8.0,
        8.0, 15.0, 22.0, 29.0, 36.0, 43.0, 50.0, 57.0,
    )
    for row, center_y in enumerate((54.0, 62.0, 70.0, 78.0, 86.0)):
        for column, center_x in enumerate(x_centers):
            width = RNG.uniform(5.8, 6.65)
            depth = RNG.uniform(6.3, 7.25)
            height = RNG.uniform(4.2, 8.0) + row * 0.32
            if (row, column) in ((2, 12), (3, 4), (4, 10)):
                height += RNG.uniform(6.0, 10.0)
            material = PLASTERS[(backdrop_index + row * 2) % len(PLASTERS)]
            box(
                f"distant_building_{backdrop_index:03d}",
                (center_x, center_y, height * 0.5),
                (width, depth, height),
                material,
                0.0,
            )
            distant_gable_roof(
                f"distant_roof_{backdrop_index:03d}",
                center_x,
                center_y,
                height + 0.02,
                width,
                depth,
                RNG.uniform(0.75, 1.45),
            )
            if row <= 2 and column % 2 == 0:
                box(
                    f"distant_window_band_{backdrop_index:03d}",
                    (center_x, center_y - depth * 0.505, height * 0.56),
                    (width * 0.62, 0.08, 0.48),
                    SHUTTER_GREEN,
                    0.0,
                )
            backdrop_index += 1


def build_district() -> None:
    street_pavers()
    church_complex()
    dome_landmark("cathedral_dome", 25.0, 18.0)

    buildings: list[dict[str, float]] = []
    inner_left: list[dict[str, float]] = []
    inner_right: list[dict[str, float]] = []
    x_centers = (-35.2, -26.4, -17.6, -8.7, 8.7, 17.6, 26.4, 35.2)
    y_centers = (-44.0, -33.0, -22.0, -11.0, 0.0, 11.0, 22.0, 33.0, 44.0)
    building_index = 0
    for row, center_y in enumerate(y_centers):
        for column, center_x in enumerate(x_centers):
            # Reserve silhouettes for the baroque church and cathedral dome.
            if abs(center_x + 27.0) < 10.0 and abs(center_y - 29.0) < 12.0:
                continue
            if abs(center_x - 25.0) < 8.0 and abs(center_y - 18.0) < 8.0:
                continue

            width = RNG.uniform(7.45, 8.15)
            depth = RNG.uniform(9.15, 9.75)
            height = RNG.uniform(6.4, 10.7)
            if row >= 7:
                height += RNG.uniform(0.5, 2.4)
            pitched = RNG.random() < 0.88
            record = building(
                building_index,
                center_x + RNG.uniform(-0.18, 0.18),
                center_y + RNG.uniform(-0.15, 0.15),
                width,
                depth,
                height,
                center_x > 0.0,
                PLASTERS[(row + column) % len(PLASTERS)],
                pitched,
            )
            buildings.append(record)
            if abs(center_x + 8.7) < 0.5:
                inner_left.append(record)
            if abs(center_x - 8.7) < 0.5:
                inner_right.append(record)
            building_index += 1

    for index in (2, 7):
        left = inner_left[index]
        right = inner_right[index]
        bridge_height = min(left["height"], right["height"]) - 0.20
        box(
            f"roof_bridge_{index:02d}-col",
            (0.0, (left["y"] + right["y"]) * 0.5, bridge_height),
            (9.4, 1.05, 0.22),
            PALE_STONE,
            0.05,
        )
        for rail_y in (-0.48, 0.48):
            box(
                f"roof_bridge_{index:02d}_rail",
                (0.0, (left["y"] + right["y"]) * 0.5 + rail_y, bridge_height + 0.52),
                (9.4, 0.06, 0.08),
                LAVA_STONE,
                0.012,
            )

    for index in (1, 5, 8):
        left = inner_left[index]
        right = inner_right[index]
        rope_height = min(left["height"], right["height"]) + 0.44
        center_y = (left["y"] + right["y"]) * 0.5
        rope_points = [
            (-5.15, center_y, rope_height),
            (0.0, center_y, rope_height - 0.62),
            (5.15, center_y, rope_height),
        ]
        rope(
            f"tightrope_{index:02d}_visual",
            rope_points,
            0.075,
            WOOD,
        )
        # Hidden, slightly wider traversal surface. The visible rope stays
        # thin, while the player receives the forgiving balance zone expected
        # from an intention-driven parkour game.
        rope(
            f"tightrope_{index:02d}-colonly",
            rope_points,
            0.22,
            WOOD,
        )

    # Sparse service lines preserve the earlier traversal language without
    # connecting every façade.
    for index, line_y in enumerate((-35, 12, 44)):
        height = 6.8 + (index % 3) * 0.52
        rope(
            f"utility_line_{index:02d}",
            [
                (-5.2, float(line_y), height),
                (0.0, float(line_y) + 0.35, height - 0.38),
                (5.2, float(line_y) - 0.2, height + 0.08),
            ],
            0.022,
            METAL,
        )
    distant_city_backdrop()
    volcano_backdrop()


def optimize_static_geometry() -> None:
    """Bake modifiers and batch static decoration by material.

    Collision-hint meshes stay independent so Godot can turn every ``-col``
    object into a usable physics body. Everything else is merged into a small
    number of render batches. This keeps the authored facade detail without
    paying for more than a thousand scene nodes and draw submissions.
    """
    for obj in list(bpy.context.scene.objects):
        if obj.type not in {"MESH", "CURVE"}:
            continue
        world_transform = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world_transform

    runtime_geometry = [
        obj for obj in bpy.context.scene.objects if obj.type in {"MESH", "CURVE"}
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in runtime_geometry:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = runtime_geometry[0]
    # One batch conversion bakes every bevel/solidify and turns ropes into
    # meshes. Applying modifiers object-by-object is several minutes slower.
    bpy.ops.object.convert(target="MESH")

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    batches: dict[str, list[bpy.types.Object]] = {}
    for obj in meshes:
        if obj.name.endswith(("-col", "-colonly")):
            continue
        material_name = obj.data.materials[0].name if obj.data.materials else "Unassigned"
        batches.setdefault(material_name, []).append(obj)

    for material_name, objects in batches.items():
        if not objects:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        active = objects[0]
        bpy.context.view_layer.objects.active = active
        if len(objects) > 1:
            bpy.ops.object.join()
        active.name = f"district_batch_{material_name.removeprefix('M_').lower()}"

    for obj in list(bpy.context.scene.objects):
        if obj.type == "EMPTY" and not obj.children:
            bpy.data.objects.remove(obj, do_unlink=True)


def export() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    optimize_static_geometry()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUTPUT))
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT),
        export_format="GLB",
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    print(f"Exported {OUTPUT}")


reset_scene()
build_district()
export()
