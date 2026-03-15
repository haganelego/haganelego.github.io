# Experiment Launch Configuration Guide

`4x3_warehouse_scheduled_2x.launch.py` の設定と構成に関するドキュメント。

---

## Overview

このランチファイルは、倉庫環境における人間とロボットのナビゲーション実験を実行する。
複数日にわたる実験を自動的にサイクルし、各日ごとに異なるワーカースケジュールを適用する。

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Launch File                              │
│  4x3_warehouse_scheduled_2x.launch.py                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐ │
│  │ HuNav    │───>│ WorldGen     │───>│ Gazebo (gzserver +    │ │
│  │ Loader   │2s  │              │3s  │ gzclient)             │ │
│  └──────────┘    └──────────────┘    └───────────────────────┘ │
│                                                                 │
│  ┌──────────────────┐    ┌──────────────┐   ┌──────────────┐  │
│  │ AgentManager     │───>│ Sequence     │   │ TimeManager  │  │
│  │ (GT or Normal)   │10s │ Controller   │   │              │  │
│  └──────────────────┘    └──────────────┘   └──────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ ExperimentOrchestrator (day cycling)                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ PMB2 Robot │  │ RobotGoal    │  │ CR-ALTM Navigation     │ │
│  │ + Nav2     │  │ Scheduler    │  │                        │ │
│  └────────────┘  └──────────────┘  └────────────────────────┘ │
│                                                                 │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Navigation │  │ Proximity    │  │ HuNav Evaluator        │ │
│  │ CostMetrics│  │ Metrics      │  │ (24+ metrics)          │ │
│  └────────────┘  └──────────────┘  └────────────────────────┘ │
│                                                                 │
│  ┌──────────────────┐                                          │
│  │ Human Detector   │                                          │
│  │ (YOLO + sync)    │                                          │
│  └──────────────────┘                                          │
└─────────────────────────────────────────────────────────────────┘
```

### Node Startup Order

```
hunav_loader
    ↓ (2s delay)
hunav_gazebo_world_generator
    ↓ (3s delay)
gzserver + gzclient + pmb2_gazebo (parallel)
    ↓ (immediate)
hunav_agent_manager (GT or Normal mode)
    ↓ (10s delay)
sequence_controller + time_manager (parallel)

Other nodes (metrics, human_detector, goal_scheduler, cr_altm, orchestrator)
    → Launch immediately (wait for /experiment_start topic to begin)
```

---

## Configuration Files

### File Map

```
hunav_gazebo_wrapper/
├── launch/
│   ├── 4x3_warehouse_scheduled_2x.launch.py   ← Main launch file
│   └── params.yaml                             ← Gazebo ROS params
├── scenarios/
│   ├── agents_4x3_warehouse_scheduled_2x.yaml  ← Agent definitions
│   └── schedules/
│       ├── 4x3_amida_2x_day1.yaml              ← Day 1 schedule
│       ├── 4x3_amida_2x_day2.yaml              ← Day 2 schedule
│       ├── 4x3_amida_2x_day3.yaml              ← Day 3 schedule
│       ├── ...                                  ← Day 4-9
│       └── eol/                                 ← End-of-life schedules
├── maps/
│   ├── 4x3_amida_2x.yaml                       ← Map metadata
│   └── 4x3_amida_2x.pgm                        ← Occupancy grid
└── worlds/
    └── 4x3_warehouse_scheduled_2x.world         ← Gazebo world

hunav_evaluator/
└── config/
    ├── experiment_orchestrator_4x3_2x.yaml      ← Day cycling config
    ├── robot_goal_scheduler_4x3_2x.yaml         ← Robot goal positions
    ├── gazebo_unpause_on_start.yaml             ← Unpause config (unused)
    └── metrics.yaml                             ← Evaluation metrics
```

### 1. Agent Configuration (`agents_4x3_warehouse_scheduled_2x.yaml`)

11人のワーカーエージェント (worker0-worker10) を定義する。

| Parameter | Value | Description |
|-----------|-------|-------------|
| Agents | 11 (worker0-10) | Warehouse workers |
| Max velocity | 1.5 m/s | Maximum speed |
| Behavior velocity | 0.6 m/s | Normal walking speed |
| Radius | 0.4 m | Collision radius |
| Behavior type | 1 (REGULAR) | Social Force Model |
| Goal radius | 0.5 m | Goal arrival tolerance |
| Cyclic goals | true | Repeat goals in loop |

**World boundaries:**
- X: -17.5 ~ +17.5 (35.0m)
- Y: -20.0 ~ +20.0 (40.0m)

**Obstacles (5.0m x 8.0m, 12 blocks):**
- X positions: -12.0, -4.0, 4.0, 12.0
- Y positions: -11.0, 0.0, 11.0

### 2. Schedule Files (`schedules/4x3_amida_2x_day*.yaml`)

各日のワーカー移動パターンを定義する。
SequenceController が読み込み、AgentManager に goal を配信する。

```yaml
# Example structure
schedule_manager:
  ros__parameters:
    total_days: 5
    sequences_per_day: 1
    sequence_duration: 300.0
    agents: [worker0, worker1, ..., worker10]
    day_1:
      worker0:
        init_pose: {x: -16.0, y: 14.0, z: 1.25, h: -1.57}
        sequence_1:
          action_id: "worker0_day1"
          goals:
            - {x: -16.0, y: 14.0, z: 0.0, h: -1.57}
            - {x: -16.0, y: 8.0,  z: 0.0, h: 0.0}
            - {x: -16.0, y: 14.0, z: 0.0, h: -1.57}
          duration: 300.0
          cyclic: true
```

**Available schedule files (9 days):**

| File | Description |
|------|-------------|
| `4x3_amida_2x_day1.yaml` | Day 1 pattern |
| `4x3_amida_2x_day2.yaml` | Day 2 pattern |
| `4x3_amida_2x_day3.yaml` | Day 3 pattern |
| `4x3_amida_2x_day4.yaml` | Day 4 pattern |
| `4x3_amida_2x_day5.yaml` | Day 5 pattern |
| `4x3_amida_2x_day6.yaml` | Day 6 pattern |
| `4x3_amida_2x_day7.yaml` | Day 7 pattern |
| `4x3_amida_2x_day8.yaml` | Day 8 pattern |
| `4x3_amida_2x_day9.yaml` | Day 9 pattern |

### 3. Experiment Orchestrator (`experiment_orchestrator_4x3_2x.yaml`)

多日間実験のサイクリングを制御する。

```yaml
experiment_orchestrator:
  ros__parameters:
    day_duration: 300.0           # 1日 = 300秒
    total_experiment_days: 9      # 実験の合計日数
    schedule_files:               # 循環するスケジュール
      - "4x3_amida_2x_day1.yaml"
      - "4x3_amida_2x_day2.yaml"
      - "4x3_amida_2x_day3.yaml"
    robot_positions_x: [-16.0, -8.0, 0.0, 8.0, 16.0, ...]  # 10箇所
    robot_positions_y: [18.0, 18.0, ..., -18.0, ...]
    day_start_x: 0.0             # 日開始位置
    day_start_y: 18.0
    day_start_yaw: -1.57
```

**Schedule cycling mechanism:**
```
Day 1 → day1.yaml (index 0)
Day 2 → day2.yaml (index 1)
Day 3 → day3.yaml (index 2)
Day 4 → day1.yaml (index 0, cycles back)
Day 5 → day2.yaml (index 1)
...
Formula: file_index = (day - 1) % num_schedule_files
```

**Day transition (6 phases):**
1. **PAUSE** — Gazebo physics pause
2. **SAVE** — CR-ALTM memory save (`memory_day{N}.npy`)
3. **RESET** — Metrics reset, state clear
4. **RELOAD** — `/reload_schedule` service → SequenceController
5. **RESPAWN** — Agent/robot teleport to init positions
6. **RESTART** — Unpause, reset time

### 4. Robot Goal Scheduler (`robot_goal_scheduler_4x3_2x.yaml`)

ロボットのナビゲーション目標を自動的に切り替える。

**Goal layout (10 positions):**

```
                    Top row (y=18.5)
    ┌───────────────────────────────────────┐
    │  G1        G2       G3       G4   G5  │
    │(-16,18.5)(-8,18.5)(0,18.5)(8,18.5)(16,18.5)
    │                                       │
    │            Warehouse                  │
    │                                       │
    │  G6        G7       G8       G9   G10 │
    │(-16,-18.5)(-8,-18.5)(0,-18.5)(8,-18.5)(16,-18.5)
    └───────────────────────────────────────┘
                   Bottom row (y=-18.5)
```

- **Group A** (top): Goal IDs 1-5
- **Group B** (bottom): Goal IDs 6-10
- ロボットは Group A → Group B → Group A ... と交互に移動
- `seed` パラメータで再現可能なランダム選択

### 5. Map Configuration (`4x3_amida_2x.yaml`)

```yaml
image: 4x3_amida_2x.pgm    # Occupancy grid image
resolution: 0.05             # 5cm per pixel
origin: [-17.5, -20.0, 0]   # Bottom-left corner in world frame
```

### 6. Evaluation Metrics (`metrics.yaml`)

24+ の評価指標を計算する。

**Navigation metrics (NavigationCostMetrics node):**
- Robot odometry tracking
- Goal arrival detection (tolerance: 0.3m)
- Navigation cost computation

**Proximity metrics (ProximityMetrics node):**
- Intimate space intrusions (< 1.0m)
- Personal space intrusions (< 1.5m)
- Close approach events (< 3.0m)

**HuNav evaluator metrics:**
- `time_to_reach_goal`, `path_length`
- `minimum_distance_to_people`, `social_force_on_robot`
- `robot_on_person_collision`, etc.

---

## Launch Arguments

### Experiment Control

| Argument | Default | Description |
|----------|---------|-------------|
| `schedule_file` | `4x3_amida_2x_day1.yaml` | Initial schedule file (Day 1) |
| `agent_file` | `agents_4x3_warehouse_scheduled_2x.yaml` | Agent configuration |
| `auto_mode` | `true` | Automatic sequence progression |
| `sequence_duration` | `300.0` | Duration per sequence (seconds) |
| `day_duration` | `300.0` | Duration per day (seconds) |
| `total_experiment_days` | `30` | Total experiment days |
| `start_day` | `1` | Starting day number |
| `experiment_output_directory` | `{workspace}/outputs` | Results output dir |
| `wait_for_experiment_start` | `true` | Wait for `/experiment_start` topic |
| `experiment_start_topic` | `/experiment_start` | Start signal topic |
| `experiment_start_on_true` | `true` | Start on `True` message |

### Robot Configuration

| Argument | Default | Description |
|----------|---------|-------------|
| `robot_name` | `pmb2` | Robot model name in Gazebo |
| `gzpose_x` | `0.0` | Initial X position |
| `gzpose_y` | `18.0` | Initial Y position |
| `gzpose_Y` | `-1.57` | Initial yaw (facing -Y) |
| `navigation` | `True` | Enable Nav2 stack |
| `ground_truth_localization` | `True` | Use GT odom (skip AMCL) |
| `odom_topic` | `/ground_truth_odom` | Odometry topic |
| `robot_goal_seed` | `0` | Goal selection random seed |
| `robot_initial_goal_id` | `3` | First goal (determines initial group) |
| `robot_position_seed` | `-1` | Position selection seed (-1=random) |

### CR-ALTM Configuration

| Argument | Default | Description |
|----------|---------|-------------|
| `memory_directory` | `{workspace}/outputs` | Memory file directory |
| `cr_altm_log_level` | `info` | Log verbosity |
| `enable_observation` | `true` | Observation component |
| `enable_direct` | `true` | Direct match component |
| `enable_context` | `true` | Context component |
| `direct_balance` | `1.0` | Direct match weight |
| `w_spatial` | `1.0` | POT spatial weight |
| `w_rel` | `2.0` | POT relative time weight |
| `w_abs` | `0.5` | POT absolute time weight |
| `distance_metric` | `euclidean` | `euclidean` or `bhattacharyya` |
| `sinkhorn_max_iter` | `100` | Max Sinkhorn iterations |
| `centroid_prefilter_threshold` | `3.0` | Pre-filter threshold (m) |
| `fragment_spatial_threshold` | `1.0` | Fragment split distance (m) |
| `fragment_temporal_threshold` | `3.0` | Fragment split time gap (steps) |
| `fragment_agreement_bonus` | `0.0` | Multi-fragment agreement boost |

### Gazebo & World

| Argument | Default | Description |
|----------|---------|-------------|
| `base_world` | `4x3_warehouse_scheduled_2x.world` | Gazebo world file |
| `use_gazebo_obs` | `True` | Use Gazebo obstacles |
| `update_rate` | `100.0` | Plugin update rate |
| `ignore_models` | `ground_plane 4x3_warehouse_scheduled_2x` | Ignored models |
| `verbose` | `true` | Gazebo verbosity |

---

## Usage Examples

### Basic launch (interactive start)

```bash
# Wait for /experiment_start topic (default)
ros2 launch hunav_gazebo_wrapper 4x3_warehouse_scheduled_2x.launch.py
```

### Immediate start (no external trigger)

```bash
ros2 launch hunav_gazebo_wrapper 4x3_warehouse_scheduled_2x.launch.py \
    wait_for_experiment_start:=false
```

### Custom experiment duration

```bash
ros2 launch hunav_gazebo_wrapper 4x3_warehouse_scheduled_2x.launch.py \
    wait_for_experiment_start:=false \
    day_duration:=600.0 \
    sequence_duration:=600.0 \
    total_experiment_days:=30
```

### Resume from Day 5

```bash
ros2 launch hunav_gazebo_wrapper 4x3_warehouse_scheduled_2x.launch.py \
    start_day:=5 \
    memory_directory:=/path/to/previous/outputs
```

### CR-ALTM ablation study (observation only)

```bash
ros2 launch hunav_gazebo_wrapper 4x3_warehouse_scheduled_2x.launch.py \
    wait_for_experiment_start:=false \
    enable_observation:=true \
    enable_direct:=false \
    enable_context:=false
```

### Disable ground truth localization (use AMCL)

```bash
ros2 launch hunav_gazebo_wrapper 4x3_warehouse_scheduled_2x.launch.py \
    ground_truth_localization:=False \
    odom_topic:=/odom
```

### Custom output directory

```bash
ros2 launch hunav_gazebo_wrapper 4x3_warehouse_scheduled_2x.launch.py \
    experiment_output_directory:=/home/user/experiment_results/run_001
```

---

## Communication Topics & Services

### Key Topics

| Topic | Type | Publisher | Subscriber |
|-------|------|-----------|------------|
| `/simulation_time` | `SimulationTime` | TimeManager | ExperimentOrchestrator, CR-ALTM |
| `/schedule_info` | `ScheduleInfo` | SequenceController | AgentManager |
| `/human_states` | `HumanStates` | AgentManager | ProximityMetrics, HuNavEvaluator |
| `/detected_persons` | `DetectedPersons` | HumanDetector | CR-ALTM |
| `/predicted_human_costmap` | `OccupancyGrid` | CR-ALTM | Nav2 Costmap |
| `/goal_pose` | `PoseStamped` | RobotGoalScheduler | Nav2 |
| `/experiment_start` | `Bool` | External | Multiple nodes |

### Key Services

| Service | Provider | Caller | Purpose |
|---------|----------|--------|---------|
| `/reload_schedule` | SequenceController | ExperimentOrchestrator | Load new schedule YAML |
| `/reset_time` | TimeManager | ExperimentOrchestrator | Reset day timer |
| `/pause_physics` | Gazebo | ExperimentOrchestrator | Pause simulation |
| `/unpause_physics` | Gazebo | ExperimentOrchestrator | Resume simulation |
| `/set_entity_state` | Gazebo | ExperimentOrchestrator | Teleport entities |

---

## Conditional Behavior

### Ground Truth Localization (`ground_truth_localization`)

| Mode | `True` (default) | `False` |
|------|-------------------|---------|
| Localization | Gazebo ground truth | AMCL |
| Odom topic | `/ground_truth_odom` | `/odom` |
| AgentManager TF frame | `odom` | `map` |
| Static TF publishers | `map→odom`, `pmb2→base_footprint` | None |
| AMCL log level | Suppressed (level 40) | Normal |

### Experiment Start (`wait_for_experiment_start`)

| Mode | `true` (default) | `false` |
|------|-------------------|---------|
| TimeManager | Waits for topic | Starts immediately |
| SequenceController | Waits for topic | Starts immediately |
| RobotGoalScheduler | Waits for topic | Publishes goals immediately |
| HumanDetector | Waits for topic | Starts detection immediately |

---

## Output Files

Experiment results are saved to `experiment_output_directory`:

```
outputs/
├── memory_day1.npy          # CR-ALTM memory (Day 1)
├── memory_day2.npy          # CR-ALTM memory (Day 2)
├── ...
├── navigation_costs/        # NavigationCostMetrics output
├── proximity_metrics/       # ProximityMetrics output
└── robot_goals/             # RobotGoalScheduler log
```
