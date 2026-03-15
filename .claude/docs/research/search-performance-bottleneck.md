# CR-ALTM Search Phase Performance Bottleneck Analysis

**Date**: 2026-02-24
**Agents**: Claude (Explore), Gemini (POT acceleration research)
**Problem**: `_run_background_search()` takes 15+ seconds

## Architecture Overview

```
_run_background_search()
├── search_fragmented_query()           [~5-10s] ★ CRITICAL
│   └── search_pattern_endpoint_aligned()
│       ├── detect_sequences()          [O(N)]
│       ├── Anchor discovery            [O(N)]
│       ├── For each anchor:            [50-200 iterations]
│       │   ├── build_cost_matrix()     [O(M×N)]
│       │   └── entropic_partial_wasserstein()  [Sinkhorn: O(M×N×K)]
│       └── _deduplicate_results()      [O(matches²)]
├── predict_match_heatmap() × N         [~1-3s]
│   ├── extract_future_steps()          [calls detect_sequences again]
│   └── Gaussian splatting (einsum)     [O(S×G)]
└── Context heatmaps                    [~1-3s]
    ├── accumulate_match_day_similarities()
    └── predict_day_context_heatmap() × days
        ├── search_by_day()             [O(N) full scan]
        └── _evaluate_gaussians_batched [O(N×G)]
```

## Bottleneck Ranking

| # | Bottleneck | File:Line | Est. Time | Severity |
|---|-----------|-----------|-----------|----------|
| 1 | Sequential Sinkhorn per anchor | search.py:300-302 | 5-8s | CRITICAL |
| 2 | Too many anchors (no peak detection) | search.py:206-218 | - | HIGH |
| 3 | Cost matrix per anchor | cost_matrix.py:152-178 | 2-3s | HIGH |
| 4 | detect_sequences() called repeatedly | instance.py:293-314 | 0.5-1s | MODERATE |
| 5 | search_by_day() O(N) scan | manager.py:289-295 | 0.5-1s | MODERATE |
| 6 | _deduplicate_results() O(matches²) | search.py:350-389 | 0.5-1s | MINOR |

### Total: ~15-20s with 5000+ records and 50-200 anchors

## Root Cause Analysis

### 1. Sequential Sinkhorn (CRITICAL)
- `ot.partial.entropic_partial_wasserstein()` default `numItermax=1000`
- Each call: ~50-100ms for 50×50 matrix
- 200 anchors × 75ms = 15 seconds just for Sinkhorn

### 2. Anchor explosion without peak detection
- `use_peak_detection=True` in launch but ALL points within threshold checked
- endpoint_threshold=1.0 still catches many points in dense areas

### 3. No early termination
- Even after finding excellent top-k matches, ALL remaining anchors processed
- No budget/timeout mechanism

## Optimization Plan (Gemini + Claude consensus)

### Phase 1: Immediate (10 min) — Target: 15s → 1-3s

1. **Sinkhorn iterations cap**: `numItermax=50, stopThr=1e-5` (search.py:300)
2. **Anchor limit per sequence**: max 3 nearest anchors (search.py:214-218)
3. **Centroid pre-filter**: Skip OT if centroid distance > max_cost * 2.5 (search.py:241)

### Phase 2: Short-term (30 min) — Target: 1-3s → 0.5-1s

4. **EMD-based partial OT**: `ot.partial.partial_wasserstein()` instead of Sinkhorn
5. **Cache detect_sequences()**: Call once, pass to all consumers
6. **Index search_by_day()**: Pre-build day→indices map

### Phase 3: Medium-term (hours) — Target: < 0.5s

7. **Batch OT with ott-jax**: `jax.vmap` for parallel Sinkhorn
8. **Spatial hashing**: Grid-based pre-filter before anchor search
9. **Query downsampling**: Reduce M from 50 to 25 for initial screening

## Key Code Locations

- **Search entry**: `cr_altm_navigation_node.py:1081` (`search_fragmented_query`)
- **POT solver**: `search.py:300-302` (`entropic_partial_wasserstein`)
- **Cost matrix**: `cost_matrix.py:152-178` (`build_cost_matrix`)
- **Anchor loop**: `search.py:226-337` (main bottleneck loop)
- **Prediction**: `prediction.py:280-376` (`predict_match_heatmap`)
- **Day context**: `prediction.py:420-467` (`predict_day_context_heatmap`)
- **Manager search**: `manager.py:270-295` (`search_by_day`)

## Current Parameters (from launch file)

```python
endpoint_threshold = 1.0
use_peak_detection = True
prediction_min_observations = 30
n_prediction_steps = 20
top_k = 5 (but top_k=None passed to search!)  # ← Note: all matches returned
direct_max_matches = 10
direct_similarity_threshold = 0.5
Grid = 40×30 = 1200 cells
```

**IMPORTANT**: In `_run_background_search()` line 1087, `top_k=None` is passed
to `search_fragmented_query`, meaning ALL matches above threshold are returned.
This forces processing of every anchor rather than stopping at top-k.
