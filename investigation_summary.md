# ClickHouse Performance Regression Investigation Summary

## Problem Statement
- **Performance regression**: 2x slowdown from 1.786s to 3.634s
- **Version change**: 25.1.8.25 → 25.3.2.39
- **Query type**: Complex CTE-based analytical query with multiple joins
- **Environment**: Kubernetes cluster with external configuration mounts

## Investigation Results

### ✅ What We've Confirmed

1. **Configuration unchanged**: External ConfigMaps mounted, same settings between versions
2. **Pipeline type preserved**: Both versions use `FillRightFirst` (confirmed via EXPLAIN PIPELINE)
3. **Join algorithm consistent**: Hash joins still being used
4. **No impact from suspected causes**:
   - ❌ Join to Subquery optimization (was added and reverted same day)
   - ❌ query_plan_join_swap_table setting change (tested, no impact)
   - ❌ Pipeline type regression (still shows FillingRightJoinSide)

### 🔍 Key Findings

#### Pod Configuration Analysis
From `pod.yaml`:
- **Image**: `clickhouse:25.3.2.39`
- **Resources**: 16 CPU limit, 80Gi memory limit
- **Config mounts**:
  - `/etc/clickhouse-server/config.d/` ← `chi-sonic-sharded-common-configd`
  - `/etc/clickhouse-server/users.d/` ← `chi-sonic-sharded-common-usersd`
  - `/etc/clickhouse-server/conf.d/` ← `chi-sonic-sharded-deploy-confd-main-0-0`

#### Version Commit Analysis
- **25.1.8.25**: `990179ead8b70778910b7ec8c7cdd14d798918a0` (fast)
- **25.3.2.39**: `3ec1fd3f6908a2eb035fe773c0658aa4d16c0dd4` (slow)
- **Commits between**: 5,783 changes

#### Investigated Changes (No Root Cause Found)
1. **Join to Subquery optimization**: Added March 13, reverted same day - not the cause
2. **Partial merge join fs cache**: Added and reverted - not the cause  
3. **query_plan_join_swap_table**: Changed from 'false' to 'auto' in 24.12 - tested, no impact
4. **ConcurrentHashJoin fixes**: Memory reservation and used_flags fixes - should improve performance
5. **HashJoin improvements**: Memory pre-allocation changes - should improve performance

### ❌ Ruled Out Causes

- **Join algorithm changes**: Still using hash joins with FillRightFirst
- **Configuration differences**: External mounts ensure same config
- **Pipeline type regression**: EXPLAIN PIPELINE shows consistent FillingRightJoinSide
- **Major optimization reversals**: Key reverts happened same-day and are included in both versions
- **Settings changes**: No impactful default setting changes found

### 🎯 Current Status

**Root cause remains unidentified** despite extensive investigation of:
- Join algorithm selection logic
- Query plan optimizations  
- Pipeline type determination
- Settings and configuration changes
- Memory management improvements
- Threading/parallelization changes

## Recommended Next Steps

### Option 1: Systematic Git Bisect
The most effective approach to identify the exact problematic commit:
```bash
git bisect start 3ec1fd3f6908a2eb035fe773c0658aa4d16c0dd4 990179ead8b70778910b7ec8c7cdd14d798918a0
# Test query performance at each bisect point
```

### Option 2: Focused Investigation Areas
If bisect is not feasible, investigate:
1. **Memory allocators/management** changes
2. **Block processing efficiency** modifications  
3. **Query statistics/cost estimation** updates
4. **Threading/parallelization** logic changes
5. **Data structure optimization** regressions

### Option 3: Workaround Testing
Test query variations to identify sensitivity:
1. **Simplify CTEs** to isolate problematic sections
2. **Force specific join algorithms** systematically
3. **Adjust memory-related settings** 
4. **Test with different parallelization settings**

## Technical Details

### Query Characteristics
- Multiple nested CTEs with currency conversion
- Complex join predicates beyond simple equality
- Window functions with row_number() OVER()
- Array joins on ad_clicks_lifetime data
- System.parts metadata queries for part selection

### Evidence Files
- `base_cte.sql`: The problematic query
- `diff_2.txt`: EXPLAIN plan comparison showing loss of FillRightFirst (misleading)
- `exp_cte_new_3.txt`: EXPLAIN PIPELINE showing FillingRightJoinSide (actual pipeline type)
- `pod.yaml`: Kubernetes configuration confirming external config mounts

## Conclusion

This investigation has successfully ruled out the most obvious causes but has not yet identified the specific code change causing the 2x performance regression. The issue appears to be a subtle change in query execution logic, memory management, or optimization heuristics rather than a major algorithmic shift.

A systematic git bisect approach would be the most efficient way to pinpoint the exact problematic commit among the 5,783 changes between versions.