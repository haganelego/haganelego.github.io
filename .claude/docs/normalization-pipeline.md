# Normalization Pipeline - CR-ALTM Navigation System

## Overview

This document traces every normalization and scaling step that heatmap data
goes through, from raw Gaussian values to the final OccupancyGrid values
published to ROS.

## Pipeline Diagram

```
Raw Gaussian Splat (per observation/prediction step)
  │
  ▼
[N1-N5] Per-component heatmap creation ──→ [0, 1]
  │
  │  RecalledComponent.heatmap stored
  │
  ▼
[N6] Per-component max-norm in _combine_components ──→ [0, 1] each
  │
  ▼
[N7] Final max-norm after weighted sum ──→ [0, 1]
  │
  ▼
[N8-N10] Library-side re-normalization (redundant) ──→ [0, 1]
  │
  ▼
[N11] Scale to int8 (× 100) ──→ [0, 100]
  │
  ▼
[N12] sqrt boost ──→ [0, 100] (nonlinear)
  │
  ▼
[N13] Cap at 95 ──→ [0, 95]
  │
  ▼
OccupancyGrid published to /predicted_human_costmap
```

---

## Stage A: Per-Component Heatmap Creation

### Observation Component (`_build_observation_heatmap`)

| ID  | Location (node.py) | Operation | Range |
|-----|--------------------|-----------|-------|
| N1  | :781 | `np.clip(heatmap, None, prediction_clip_max)` | [0, ∞) → [0, 3.0] |
| N2  | :783-784 | `heatmap / heatmap.max()` | [0, 3.0] → [0, 1] |

Raw Gaussian splatting: `heatmap += alpha * exp(-0.5 * mahalanobis²)`
where `alpha` = memory record strength (typically 1.0).

### Direct Prediction (`predict_match_heatmap` in prediction.py)

| ID  | Location (prediction.py) | Operation | Range |
|-----|--------------------------|-----------|-------|
| N3  | :371-374 | Per-step: `clip(clip_max)` then `/ step_max` | each step → [0, 1] |
| N4  | :381-383 | All steps blended: `combined / max_val` | accumulated → [0, 1] |

Blending uses exponential decay: `combined += exp(-step_idx / n_steps) * step_heatmap`.
Weight returned alongside heatmap: `total_weight = similarity × time_sim × mean_strength`.

### Day Context (`predict_day_context_heatmap` in prediction.py)

| ID  | Location (prediction.py) | Operation | Range |
|-----|--------------------------|-----------|-------|
| N5  | :430-433 | `clip(clip_max)` then `/ max_val` | [0, ∞) → [0, 1] |

Splats ALL memory records for a given day.

---

## Stage B: Component Combination (`_combine_components`)

| ID  | Location (node.py) | Operation | Range |
|-----|--------------------|-----------|-------|
| N6  | :862-867 | Per-component: `combined_X / combined_X.max()` (×3) | accumulated → [0, 1] each |
| N7  | :875-877 | `combined / combined.max()` | [0, 1.8] → [0, 1] |

Accumulation formula:
```
combined = direct + observation_balance × observation + context_balance × context
```

Each component accumulates multiple RecalledComponents with Weibull time-decay:
```
effective_weight = base_weight × experience_weight × weibull_decay(age)
```

### Known Issue: N7 causes relative suppression

When a strong peak appears in one component (e.g., a recent observation),
`combined.max()` increases, and ALL other areas are divided by this larger
denominator. This makes distant prediction/context areas appear to lose cost
whenever a new observation is added.

---

## Stage C: OccupancyGrid Conversion & Publishing

### Library-side (`to_occupancy_grid` + `to_ros_data`)

| ID  | Location | Operation | Range | Note |
|-----|----------|-----------|-------|------|
| N8  | prediction.py :683 | `heatmap / max` | [0,1] → [0,1] | Redundant (input already [0,1]) |
| N9  | prediction.py :688 | `data[data < threshold] = 0` | threshold=0.1 | Noise removal |
| N10 | grid_config.py :273 | `/ max` again | [0,1] → [0,1] | Redundant |
| N11 | grid_config.py :281 | `× 100` cast to int8 | [0,1] → [0,100] | ROS format |

### Node-side (`_publish_occupancy_grid`)

| ID  | Location (node.py) | Operation | Range |
|-----|--------------------|-----------|-------|
| N12 | :1102-1106 | `sqrt(region/100) × 100` where region > 0 | Nonlinear boost |
| N13 | :1109 | `where(region >= 95, 95, region)` | [0,100] → [0,95] |

Sqrt scaling effect: `4→20, 10→32, 25→50, 50→71, 100→100`.
Cap at 95 prevents predictions from exceeding obstacle costs.

---

## Bottleneck Analysis

| Priority | ID | Issue | Impact |
|----------|----|-------|--------|
| **High** | N7 | Final max-norm causes relative suppression | New peaks suppress all other areas |
| **Medium** | N6 | Per-component max-norm distorts accumulated decay weights | Older components' relative contribution shifts |
| **Low** | N8, N10 | Redundant re-normalization in library | No current harm, but fragile |
| **Low** | N3+N4 | Double normalization in predict_match_heatmap | Step-level density info lost |

---

## Parameters Affecting Normalization

| Parameter | Default | Used At |
|-----------|---------|---------|
| `prediction_clip_max` | 3.0 | N1, N3, N5 |
| `observation_balance` | 0.5 | N7 (weighted sum) |
| `context_balance` | 0.3 | N7 (weighted sum) |
| `recall_decay_shape` | 1.5 | N6 (effective_weight) |
| `recall_decay_scale` | 0.04 | N6 (effective_weight) |
| `observation_decay_shape` | 1.5 | N6 (effective_weight) |
| `observation_decay_scale` | 0.12 | N6 (effective_weight) |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-18 | Initial documentation of full normalization pipeline |
