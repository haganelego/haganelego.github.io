# Project Design Document

> This document tracks design decisions made during conversations.
> Updated automatically by the `design-tracker` skill.

## Overview

<!-- Project purpose and goals -->

## Architecture

<!-- System structure, components, data flow -->

```
[Component diagram or description here]
```

## Implementation Plan

### Patterns & Approaches

<!-- Design patterns, architectural approaches -->

| Pattern | Purpose | Notes |
|---------|---------|-------|
| Two-stage trajectory search (cheap prefilter → Sinkhorn) | Reduce number of POT/Sinkhorn calls while preserving match quality | Use coarse features or downsampled OT to keep top candidates, then full POT |

### Libraries & Roles

<!-- Libraries and their responsibilities -->

| Library | Role | Version | Notes |
|---------|------|---------|-------|
| | | | |

### Key Decisions

<!-- Important decisions and their rationale -->

| Decision | Rationale | Alternatives Considered | Date |
|----------|-----------|------------------------|------|
| Prefer SmacPlanner2D for PMB2 global planning, using `cost_travel_multiplier` to tune detours around high-cost human-trajectory areas via YAML-only changes. | Explicit cost-avoidance weighting, official Nav2 planner, simple parameter tuning for cost vs distance tradeoff. | ThetaStarPlanner (w_euc_cost / w_traversal_cost), NavFn with `use_astar`. | 2026-02-17 |
| Treat observation reflection as a measurement layer distinct from memory-based prediction, with separately tuned (likely faster) temporal decay. | Observation encodes current-state evidence, while memory-based prediction provides a future prior; tying decay risks double counting and miscalibration. | Share Weibull parameters across components; omit observation reflection. | 2026-02-18 |
| Normalize combined human-aware costmaps using a fixed-scale weighted sum (divide by total active weights) and/or a pointwise saturating nonlinearity (logistic/tanh or Poisson-rate-to-probability), avoiding global per-frame normalization like max/percentile/equalization. | Fixed-scale or pointwise squashing preserves spatial independence and yields stable interpretability across time, while global normalization causes distant costs to fluctuate when new peaks appear. | Per-frame max/percentile normalization; histogram/quantile equalization. | 2026-02-18 |
| Exclude start position from first goal pool refill of each day via `_excluded_goal_id` in RobotGoalScheduler, with fallback if pool becomes empty. | Prevents robot from being sent back to its starting position as the first goal. Group alternation already provides partial protection, but explicit exclusion adds a safety net. | Exclude from all refills (rejected: user wants first selection only); no exclusion (insufficient). | 2026-02-20 |
| Fix day-transition robot teleport to Day 1 starting position (2.875, 8.75, -1.57) via `day_start_x/y/yaw` parameters in ExperimentOrchestrator, replacing random selection. | Ensures consistent experimental conditions across days; robot always starts from the same position. | Random position (previous behavior); per-day configurable positions. | 2026-02-20 |
| Cache day-context heatmaps as a single `npz` with named arrays and grid/source metadata; validate cache via source file mtime/hash and grid config to avoid stale loads; prefer full-cache rewrite with `np.savez` (uncompressed) unless storage pressure warrants compression. | Single `npz` simplifies bundling 30 arrays and metadata; explicit metadata + validation ensures coherence; full rewrite avoids complexity since files are small; uncompressed favors startup load speed. | Per-day `npy` files with incremental updates; `np.savez_compressed` by default; no metadata/validation. | 2026-02-23 |
| Prioritize a two-stage POT search (cheap prefilter → full Sinkhorn) and cache sequence detection per cycle to reach sub-2s search time. | Largest runtime contributor is number of Sinkhorn calls and repeated sequence scans; two-stage filtering and caching offer the highest impact/effort. | Parallelize Sinkhorn across processes; rely solely on tighter endpoint thresholds. | 2026-02-23 |
| 4x3 warehouse L-route agent design: 5 agents with L-shaped (V+H) routes, 3 free segments per day forming T-junction or S-shaped dead-ends. Day 1/2 are vertical mirrors; Day 3 uses different free vertical (V2). Accepted T-junction topology over pure L-shape; accepted V1+H5 route duplication across Day 1 & 3. | L-shapes force robot to encounter turns; T-junction dead-ends still require turns to reach endpoints; Day 1/2 symmetry tests precise spatial binding in CR-ALTM. | Pure L-shape dead-ends (2 free segments); breaking Day 1/2 symmetry; rotating V1/V5 occupancy. | 2026-02-24 |

## TODO

<!-- Features to implement -->

- [ ] Refactor spatiotemporal_compression to only process newly added memory instances (not full memory). Requires splitting the CR-ALTM library API into snapshot → compute → merge steps to reduce lock hold time.
- [ ] Two-stage memory architecture (staging buffer + compressed store) for compression scope isolation and independent lock granularity. Observations enter buffer; compression moves clustered centroids to store; search/prediction queries both.
- [ ] Implement incremental current-day context heatmap from `observation_buffer` with cached raw accumulation and delta updates (avoid full manager scan).
- [ ] Add dedup/offset tracking so each observation contributes exactly once to the cached raw heatmap.
- [ ] Preserve past-day context cache across day boundaries with bounded retention (e.g., LRU), and define invalidation on compression or data rewrites.
- [ ] Fix current-day raw reset wiping pre-submit overflow on day start; initialize `_current_day_number` before any accumulation or gate reset when unset.
- [ ] Handle day-boundary buffers: split/flush `observation_buffer` by day to avoid cross-day contamination in current-day raw cache.
- [ ] Guarantee buffered observations are eventually accumulated when search stays running (e.g., periodic commit or timeout on `_search_future`).
- [ ] Use an absolute simulation timestamp (e.g., `day_index * day_length + sequence_elapsed`) or store `day_index` with each component to avoid negative ages on day reset.
- [ ] Add pause/lag detection for simulation time; gate observation appends and decay updates when sim time is not advancing to prevent unbounded component growth.
- [ ] Re-express Weibull decay parameters in simulation seconds and document target expiry horizons (e.g., per-day vs multi-day retention).
- [ ] Implement two-stage candidate filtering for POT search (cheap feature gate and/or downsampled OT before full Sinkhorn).
- [ ] Cache `detect_sequences()` results per cycle with versioning keyed by `gap_threshold` and record count.
- [ ] Add day/sequence indices to avoid O(N) scans in `search_by_day()` and `extract_future_steps()`.
- [ ] Vectorize/batch cost-matrix construction across anchors where feasible to reduce Python loop overhead.
- [ ] Evaluate approximate OT (sliced/downsampled) as a prefilter; quantify false-negative risk.

## Open Questions

<!-- Unresolved issues, things to investigate -->

- [ ] Validate shared vs separate decay via ablation and calibration metrics (e.g., NLL/Brier, horizon-specific).
- [ ] Decide whether current-day context should use per-record covariance (manager-derived) or a uniform covariance (observation-style), and evaluate impact on cross-day comparability.

## Changelog

| Date | Changes |
|------|---------|
| 2026-02-17 | Recorded planner recommendation and tuning rationale for human-trajectory cost avoidance. |
| 2026-02-18 | Recorded recommendation to separate observation vs prediction decay and added evaluation open question. |
| 2026-02-18 | Recorded recommendation to avoid global per-frame normalization; prefer fixed-scale or pointwise saturating normalization for combined costmaps. |
| 2026-02-19 | Added TODOs and open question for incremental current-day context heatmap caching, dedup, cache retention, and covariance choice. |
| 2026-02-19 | Added TODOs for day-boundary handling and ensuring current-day raw accumulation is not lost. |
| 2026-02-19 | Added TODOs for simulation-time decay safety: absolute timestamps, pause gating, and sim-second parameterization. |
| 2026-02-20 | Added start position exclusion for goal scheduler and fixed day-transition teleport position. |
| 2026-02-23 | Recorded caching decision for day-context heatmaps: single `npz`, metadata/validation, full rewrite, uncompressed by default. |
| 2026-02-23 | Added performance-focused decisions and TODOs for two-stage POT search, sequence caching, and indexing. |
| 2026-02-24 | Added 4x3 warehouse L-route agent schedule design. See `.claude/docs/4x3-warehouse-l-route-design.md` for full details. |
