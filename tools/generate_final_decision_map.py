"""Deterministically author the typed final-decision map; no game-time dependency."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZE = (32768, 24576)
BLUE = (2064, 22544)


def rotate(point):
    return tuple(a - b for a, b in zip(SIZE, point))


def vec(point):
    return f"Vector2({point[0]}, {point[1]})"


def route(points):
    # Godot text resources serialize packed arrays as flat scalar sequences.
    return "PackedVector2Array(" + ", ".join(str(c) for p in points for c in p) + ")"


def ids(values):
    return "Array[StringName]([" + ", ".join(f'&"{v}"' for v in values) + "])"


def generate():
    types = ["map_definition", "map_lane_definition", "map_supply_point_definition",
             "map_wild_region_definition", "map_connector_definition"]
    blocks = []
    refs = {name: [] for name in types[1:]}

    def add(kind, name, **fields):
        refs[kind].append(name)
        blocks.append(f'[sub_resource type="Resource" id="{name}"]\nscript = ExtResource("{kind}")\n' +
                      "\n".join(f"{k} = {v}" for k, v in fields.items()) + "\n")

    # Three broad lanes wrap around two jungle halves. Every authored object has
    # a 180-degree partner; IDs encode faction, lane and tier instead of landmarks.
    top = [BLUE, (2048, 18432), (2048, 7168), (3072, 4096), (6144, 2048),
           (10240, 2048), (26624, 2048), rotate(BLUE)]
    mid = [BLUE, (6656, 19456), (10688, 16384), (14080, 13824),
           (18688, 10752), (22080, 8192), (26112, 5120), rotate(BLUE)]
    # mid is constructed in exact rotated pairs; no bonus point clutters the center.
    blue_mid = [(6656, 19456), (10688, 16384), (14080, 13824)]
    mid = [BLUE] + blue_mid + [rotate(p) for p in reversed(blue_mid)] + [rotate(BLUE)]
    lane_routes = {"top": top, "mid": mid, "bottom": [rotate(p) for p in reversed(top)]}
    tier_names = ["high", "inner", "outer"]
    for lane, points in lane_routes.items():
        point_ids = ["blue_base"] + [f"blue_{lane}_{t}" for t in tier_names]
        point_ids += [f"red_{lane}_{t}" for t in reversed(tier_names)] + ["red_base"]
        add("map_lane_definition", lane, lane_id=f'&"{lane}"',
            mirror_id='&"%s"' % {"top": "bottom", "bottom": "top", "mid": "mid"}[lane],
            display_name_key=f'&"FINAL_LANE_{lane.upper()}"', width_cells=32,
            route_points=route(points), supply_point_ids=ids(point_ids))

    def point(name, partner, pos, tier, lane="", owner=0):
        base, wild = tier == 1, tier in (5, 6)
        income = {1: 12, 2: 4, 3: 6, 4: 8, 5: 3, 6: 7}[tier]
        radius = {1: 512, 2: 384, 3: 352, 4: 320, 5: 224, 6: 320}[tier]
        capture = {1: 180, 2: 160, 3: 120, 4: 100, 5: 60, 6: 100}[tier]
        add("map_supply_point_definition", name, point_id=f'&"{name}"', mirror_id=f'&"{partner}"',
            display_name_key=f'&"FINAL_POINT_{name.upper()}"', position=vec(pos), tier=tier,
            owner_faction_id=owner, supply_per_settlement=income, radius=radius,
            capture_ticks=capture, lane_id=f'&"{lane}"',
            is_base=str(base).lower(), is_wild=str(wild).lower())

    point("blue_base", "red_base", BLUE, 1, owner=1)
    point("red_base", "blue_base", rotate(BLUE), 1, owner=2)
    blue_positions = {
        "top": [(2048, 18432), (2048, 12288), (2048, 7168)],
        "mid": blue_mid,
        "bottom": [(6144, 22528), (12288, 22528), (22528, 22528)],
    }
    for lane, positions in blue_positions.items():
        mirrored_lane = {"top": "bottom", "bottom": "top", "mid": "mid"}[lane]
        for index, pos in enumerate(positions):
            name, partner = f"blue_{lane}_{tier_names[index]}", f"red_{mirrored_lane}_{tier_names[index]}"
            point(name, partner, pos, index + 2, lane)
            point(partner, name, rotate(pos), index + 2, mirrored_lane)

    # Two small depots and one major depot in EACH jungle half. Each is also a
    # cross-lane passage, so taking a cache opens a useful staging position.
    crossings = [
        ("rear", [(2048, 18432), (4864, 16384), blue_mid[0]],
         ["blue_top_high", "jungle_upper_rear", "blue_mid_high"], 5),
        ("major", [(2048, 12288), (8192, 9216), blue_mid[1]],
         ["blue_top_inner", "jungle_upper_major", "blue_mid_inner"], 6),
        ("forward", [(20480, 2048), (18432, 6144), rotate(blue_mid[1])],
         ["red_top_inner", "jungle_upper_forward", "red_mid_inner"], 5),
    ]
    def mirror_id(name):
        parts = name.split("_")
        return "_".join({"blue":"red", "red":"blue", "top":"bottom", "bottom":"top",
                         "upper":"lower"}.get(part, part) for part in parts)

    for name, path, nodes, tier in crossings:
        for half in ("upper", "lower"):
            other = "lower" if half == "upper" else "upper"
            transformed = path if half == "upper" else [rotate(p) for p in path]
            transformed_ids = nodes if half == "upper" else [mirror_id(n) for n in nodes]
            lane = "top" if half == "upper" else "bottom"
            add("map_connector_definition", f"{half}_{name}",
                connector_id=f'&"{half}_{name}"', mirror_id=f'&"{other}_{name}"',
                from_lane_id=f'&"{lane}"', to_lane_id='&"mid"', width_cells=10,
                route_points=route(transformed), supply_point_ids=ids(transformed_ids))
            add("map_wild_region_definition", f"wild_{half}_{name}",
                region_id=f'&"wild_{half}_{name}"', mirror_id=f'&"wild_{other}_{name}"',
                display_name_key=f'&"FINAL_WILD_{half.upper()}"', center=vec(transformed[1]),
                width_cells=40 if tier == 6 else 24, depth_cells=32 if tier == 6 else 24,
                connected_lane_ids=ids([lane, "mid"]))
            point(f"jungle_{half}_{name}", f"jungle_{other}_{name}", transformed[1], tier)
    # A winding river crossing links the outer fronts without adding another node.
    river = [(2048,7168), (8192,4096), (12288,8192), (16384,12288),
             (20480,16384), (24576,20480), (30720,17408)]
    # Use an exactly symmetric path even if later control points are adjusted.
    river = river[:3] + [(16384,12288)] + [rotate(p) for p in reversed(river[:3])]
    add("map_connector_definition", "river", connector_id='&"river"', mirror_id='&"river"',
        from_lane_id='&"top"', to_lane_id='&"bottom"', width_cells=16,
        route_points=route(river), supply_point_ids=ids(["blue_top_outer", "red_bottom_outer"]))

    # Longitudinal jungle roads join all three depots to the existing river.
    # On screen the lower half reads S -> river -> L -> S after rotation.
    jungle_spine = [crossings[0][1][1], crossings[1][1][1], river[2], crossings[2][1][1]]
    for half in ("upper", "lower"):
        other = "lower" if half == "upper" else "upper"
        path = jungle_spine if half == "upper" else [rotate(p) for p in jungle_spine]
        add("map_connector_definition", f"{half}_river_link",
            connector_id=f'&"{half}_river_link"', mirror_id=f'&"{other}_river_link"',
            from_lane_id='&"top"' if half == "upper" else '&"bottom"',
            to_lane_id='&"mid"', width_cells=10, route_points=route(path),
            supply_point_ids=ids([f"jungle_{half}_{name}" for name in ["rear", "major", "forward"]]))

    header = f'[gd_resource type="Resource" script_class="MapDefinition" load_steps={len(types) + len(blocks) + 1} format=3]\n\n'
    header += "\n".join(f'[ext_resource type="Script" path="res://src/data/{t}.gd" id="{t}"]' for t in types)
    footer = '''[resource]
script = ExtResource("map_definition")
definition_id = &"final_decision"
grid_size = Vector2i(1024, 768)
player_spawn_cell = Vector2i(64, 704)
enemy_spawn_cell = Vector2i(959, 63)
camera_start_cell = Vector2i(64, 704)
require_central_symmetry = true
main_lane_width_cells = 32
side_lane_width_cells = 10
'''
    for field, kind in [("lanes", "map_lane_definition"), ("supply_points", "map_supply_point_definition"),
                        ("wild_regions", "map_wild_region_definition"), ("connectors", "map_connector_definition")]:
        footer += f'{field} = Array[ExtResource("{kind}")]([' + ", ".join(f'SubResource("{n}")' for n in refs[kind]) + "])\n"
    (ROOT / "data/maps/final_decision.tres").write_text(header + "\n\n" + "\n".join(blocks) + "\n" + footer, encoding="utf-8")


if __name__ == "__main__":
    generate()
