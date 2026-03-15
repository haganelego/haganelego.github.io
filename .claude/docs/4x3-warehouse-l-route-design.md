# 4x3 Warehouse Vertex-Offset L-Route Agent Schedule Design

> Design document for the vertex-offset L-shaped agent route patterns in the 4x3 warehouse simulation.
> Created: 2026-02-24
> Updated: 2026-02-24 (v2: Vertex-offset with robot route connectivity)

## Warehouse Layout

```
World: 25.0m (x) x 28.0m (y)
Walls: x = +/-12.5, y = +/-14.0
Obstacle grid: 4 columns x 3 rows
  Centers X: [-8.25, -2.75, 2.75, 8.25]
  Centers Y: [-7.0, 0.0, 7.0]
  Size: 2.5m (x) x 4.0m (y) x 2.0m (z)
  Half-size: hx = 1.25, hy = 2.0
Corridor width: 3.0m
Offset: 1.5m (half corridor width)
```

### Corridor Segments (13 total)

**Vertical aisles (5):**
| Segment | X coordinate | Y range |
|---------|-------------|---------|
| V1 | x = -11.0 | y: -3.5 to 3.5 |
| V2 | x = -5.5 | y: -3.5 to 3.5 |
| V3 | x = 0.0 | y: -3.5 to 3.5 |
| V4 | x = 5.5 | y: -3.5 to 3.5 |
| V5 | x = 11.0 | y: -3.5 to 3.5 |

**Horizontal segments at y = 3.5 (4):**
| Segment | X range |
|---------|---------|
| H1 | x: -11.0 to -5.5 |
| H2 | x: -5.5 to 0.0 |
| H3 | x: 0.0 to 5.5 |
| H4 | x: 5.5 to 11.0 |

**Horizontal segments at y = -3.5 (4):**
| Segment | X range |
|---------|---------|
| H5 | x: -11.0 to -5.5 |
| H6 | x: -5.5 to 0.0 |
| H7 | x: 0.0 to 5.5 |
| H8 | x: 5.5 to 11.0 |

### Center Nodes (10 intersections)

```
(-11, 3.5)---H1---(-5.5, 3.5)---H2---(0, 3.5)---H3---(5.5, 3.5)---H4---(11, 3.5)
     |                  |                |                |                  |
    V1                 V2               V3               V4                V5
     |                  |                |                |                  |
(-11,-3.5)---H5---(-5.5,-3.5)---H6---(0,-3.5)---H7---(5.5,-3.5)---H8---(11,-3.5)
```

### Turnaround Nodes (Obstacle Edges)

Agents turn around at obstacle edges (1.5m offset from center nodes), NOT at center nodes.

**Vertical corridor turnarounds** (x = corridor center, y = obstacle edge):
| y value | Origin |
|---------|--------|
| 2.0 | Middle-row obstacle top edge (cy=0, hy=2.0) |
| -2.0 | Middle-row obstacle bottom edge |
| 5.0 | Top-row obstacle bottom edge (cy=7, hy=2.0) |
| -5.0 | Bottom-row obstacle top edge (cy=-7, hy=2.0) |

**Horizontal corridor turnarounds** (y = +-3.5, x = obstacle edge):
| x value | Origin |
|---------|--------|
| -9.5 | Col1 left edge (cx=-8.25, hx=1.25) |
| -7.0 | Col1 right edge |
| -4.0 | Col2 left edge (cx=-2.75) |
| -1.5 | Col2 right edge |
| 1.5 | Col3 left edge (cx=2.75) |
| 4.0 | Col3 right edge |
| 7.0 | Col4 left edge (cx=8.25) |
| 9.5 | Col4 right edge |

## Design Principles

1. **5 agents** (worker0-worker4), each covering **2 connected segments**
2. **L-shaped routes**: V+H combination with L-turn at center node
3. **Vertex-offset turnarounds**: Agents reverse at obstacle edges, not center nodes
4. **Exception**: Worker4 covers 2 adjacent H segments (straight patrol)
5. **10 occupied + 3 free** segments per day
6. **Free V corridor fully traversable**: Both endpoint center nodes are FREE
7. **Robot can traverse top-to-bottom** every day via the free V corridor
8. **Each day has unique route patterns** for CR-ALTM day-context learning

## Critical Constraint: Robot Route Connectivity

**Problem** (v1 design): Free zones formed T-junctions where V3 endpoints were blocked by L-turns, preventing robot from traversing top-to-bottom.

**Solution** (v2 design): Each day frees a different V corridor (V3/V4/V2) and ensures BOTH endpoint center nodes are free from L-turn blockages, guaranteeing robot passage `y=12.0 <-> y=-12.0`.

## Route Assignments

### Day 1 (Free: V3+H2+H6 -- Z-left shape)

| Agent | Route | Turnaround Points | L-turn Center |
|-------|-------|-------------------|---------------|
| Worker0 | V1+H5 | (-11,2.0), (-7.0,-3.5) | (-11,-3.5) |
| Worker1 | V2+H1 | (-5.5,-2.0), (-9.5,3.5) | (-5.5,3.5) |
| Worker2 | V4+H3 | (5.5,-2.0), (1.5,3.5) | (5.5,3.5) |
| Worker3 | V5+H4 | (11,-2.0), (7.0,3.5) | (11,3.5) |
| Worker4 | H7+H8 | (1.5,-3.5), (9.5,-3.5) | passes (5.5,-3.5) |

**Blocked center nodes (5):** (-11,-3.5), (-5.5,3.5), (5.5,3.5), (11,3.5), (5.5,-3.5)
**Free center nodes (5):** (-11,3.5), (-5.5,-3.5), **(0,3.5)**, **(0,-3.5)**, (11,-3.5)

**Robot route:** V3 top-to-bottom traversable. Enter from y>3.5 -> (0,3.5) FREE -> V3 -> (0,-3.5) FREE -> exit to y<-3.5.

### Day 2 (Free: V4+H3+H8 -- Reverse-S shape)

| Agent | Route | Turnaround Points | L-turn Center |
|-------|-------|-------------------|---------------|
| Worker0 | V1+H1 | (-11,-2.0), (-7.0,3.5) | (-11,3.5) |
| Worker1 | V2+H5 | (-5.5,2.0), (-9.5,-3.5) | (-5.5,-3.5) |
| Worker2 | V3+H2 | (0,-2.0), (-4.0,3.5) | (0,3.5) |
| Worker3 | V5+H4 | (11,-2.0), (7.0,3.5) | (11,3.5) |
| Worker4 | H6+H7 | (-4.0,-3.5), (4.0,-3.5) | passes (0,-3.5) |

**Blocked center nodes (5):** (-11,3.5), (-5.5,-3.5), (0,3.5), (11,3.5), (0,-3.5)
**Free center nodes (5):** (-11,-3.5), (-5.5,3.5), **(5.5,3.5)**, **(5.5,-3.5)**, (11,-3.5)

**Robot route:** V4 top-to-bottom traversable. Enter from y>3.5 -> (5.5,3.5) FREE -> V4 -> (5.5,-3.5) FREE -> exit to y<-3.5.

### Day 3 (Free: V2+H1+H6 -- S-shape)

| Agent | Route | Turnaround Points | L-turn Center |
|-------|-------|-------------------|---------------|
| Worker0 | V1+H5 | (-11,2.0), (-7.0,-3.5) | (-11,-3.5) |
| Worker1 | V3+H7 | (0,2.0), (4.0,-3.5) | (0,-3.5) |
| Worker2 | V4+H4 | (5.5,-2.0), (9.5,3.5) | (5.5,3.5) |
| Worker3 | V5+H8 | (11,2.0), (7.0,-3.5) | (11,-3.5) |
| Worker4 | H2+H3 | (-4.0,3.5), (4.0,3.5) | passes (0,3.5) |

**Blocked center nodes (5):** (-11,-3.5), (0,-3.5), (5.5,3.5), (11,-3.5), (0,3.5)
**Free center nodes (5):** (-11,3.5), **(-5.5,3.5)**, **(-5.5,-3.5)**, (5.5,-3.5), (11,3.5)

**Robot route:** V2 top-to-bottom traversable. Enter from y>3.5 -> (-5.5,3.5) FREE -> V2 -> (-5.5,-3.5) FREE -> exit to y<-3.5.

## Robot Route Summary

| Day | Free Zone | Shape | Free V | V Endpoints | Robot top<->bottom | Dead-end branches |
|-----|-----------|-------|--------|-------------|-------------------|-------------------|
| 1 | V3+H2+H6 | Z-left | V3 | (0,3.5) + (0,-3.5) | via V3 | H2->blocked, H6->free |
| 2 | V4+H3+H8 | Rev-S | V4 | (5.5,3.5) + (5.5,-3.5) | via V4 | H3->blocked, H8->free |
| 3 | V2+H1+H6 | S | V2 | (-5.5,3.5) + (-5.5,-3.5) | via V2 | H1->free, H6->blocked |

**All 3 days have robot top-to-bottom traversal guaranteed** via different V corridors (V3->V4->V2).

## Segment Occupancy Summary

| Segment | Day 1 | Day 2 | Day 3 | Always occupied? |
|---------|-------|-------|-------|-----------------|
| V1 | W0 (V1+H5) | W0 (V1+H1) | W0 (V1+H5) | Yes |
| V2 | W1 (V2+H1) | W1 (V2+H5) | **Free** | No |
| V3 | **Free** | W2 (V3+H2) | W1 (V3+H7) | No |
| V4 | W2 (V4+H3) | **Free** | W2 (V4+H4) | No |
| V5 | W3 (V5+H4) | W3 (V5+H4) | W3 (V5+H8) | Yes |
| H1 | W1 | W0 | **Free** | No |
| H2 | **Free** | W2 | W4 | No |
| H3 | W2 | **Free** | W4 | No |
| H4 | W3 | W3 | W2 | Yes |
| H5 | W0 | W1 | W0 | Yes |
| H6 | **Free** | W4 | **Free** | No |
| H7 | W4 | W4 | W1 | No |
| H8 | W4 | **Free** | W3 | No |

**Always occupied**: V1, V5, H4, H5 (4 segments) -- baseline for CR-ALTM
**Variable**: V2, V3, V4, H1, H2, H3, H6, H7, H8 (9 segments) -- day-context discriminators

## Route Pair Uniqueness

| Route Pair | Day 1 | Day 2 | Day 3 | Unique? |
|-----------|-------|-------|-------|---------|
| V1+H5 | W0 | - | W0 | Day 1 & 3 shared |
| V1+H1 | - | W0 | - | Day 2 only |
| V2+H1 | W1 | - | - | Day 1 only |
| V2+H5 | - | W1 | - | Day 2 only |
| V3+H2 | - | W2 | - | Day 2 only |
| V3+H7 | - | - | W1 | Day 3 only |
| V4+H3 | W2 | - | - | Day 1 only |
| V4+H4 | - | - | W2 | Day 3 only |
| V5+H4 | W3 | W3 | - | Day 1 & 2 shared |
| V5+H8 | - | - | W3 | Day 3 only |
| H7+H8 | W4 | - | - | Day 1 only |
| H6+H7 | - | W4 | - | Day 2 only |
| H2+H3 | - | - | W4 | Day 3 only |

**Shared**: V1+H5 (Day 1 & 3), V5+H4 (Day 1 & 2). Each day has sufficient unique route pairs for day-context discrimination.

## Design Improvements over v1

| Aspect | v1 (Old) | v2 (Current) |
|--------|----------|-------------|
| Turnaround points | Center nodes | Obstacle edges (1.5m offset) |
| Robot traversal | Blocked (T-junctions) | Guaranteed every day |
| Free V corridors | V3 only (Day 1&2), V2 (Day 3) | V3, V4, V2 (one per day) |
| V corridor diversity | 2 unique Vs | 3 unique Vs |
| Always-occupied segments | 6 | 4 |
| Variable segments | 7 | 9 |
| Spatial diversity | Limited | High |

## Files

| File | Description |
|------|-------------|
| `scenarios/agents_4x3_warehouse_scheduled.yaml` | Agent properties (5 workers) |
| `scenarios/schedules/4x3_amida_day1.yaml` | Day 1 schedule (V3+H2+H6 free) |
| `scenarios/schedules/4x3_amida_day2.yaml` | Day 2 schedule (V4+H3+H8 free) |
| `scenarios/schedules/4x3_amida_day3.yaml` | Day 3 schedule (V2+H1+H6 free) |
| `config/experiment_orchestrator_4x3.yaml` | Experiment orchestrator (9 days, 3 patterns x 3 cycles) |
| `config/robot_goal_scheduler_4x3.yaml` | Robot goal positions |
| `launch/4x3_warehouse_scheduled.launch.py` | Launch file |
