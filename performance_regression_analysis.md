# ClickHouse Performance Regression Analysis

## Problem Statement
ClickHouse query performance regression between versions:
- **25.1.8.25**: 1.786 seconds 
- **25.3.2.39**: 3.634 seconds (~2x slower)

The regression affects a complex CTE-based analytical query with multiple joins and window functions.

## Initial Investigation Results

### Query Analysis
- Complex query with multiple CTEs including `currency_conversion`
- Multiple `LEFT JOIN` operations with complex nested subqueries
- Window functions with `row_number() OVER()` partitioning
- Array joins on `ad_clicks_lifetime` data
- Complex part selection logic using `system.parts`

### EXPLAIN Plan Comparison
From `diff_2.txt`, key differences between versions:
- **Old version (25.1.8.25)**: Uses `JOIN FillRightFirst` consistently
- **New version (25.3.2.39)**: Shows nested `Expression` and `Join` nodes without explicit join strategies

## Code Investigation: Join Pipeline Types

### Pipeline Type Determination Path
```
chooseJoinAlgorithm() → tryCreateJoin() → specific join class → pipelineType()
```

### Join Types and Pipeline Types
- **`HashJoin`**: Returns `JoinPipelineType::FillRightFirst` (optimized)
- **`FullSortingMergeJoin`**: Returns `JoinPipelineType::YShaped` (less optimized)
- **`ConcurrentHashJoin`**: Inherits default `FillRightFirst`
- **`GraceHashJoin`**: Inherits default `FillRightFirst`

### Critical Performance Impact of Pipeline Type
When pipeline type is **NOT** `FillRightFirst`:
- Filter pushdown is disabled (`allowPushDownToRight()` returns false)
- Join optimizations are disabled (`optimizeJoin.cpp:111`)
- Query planner uses less efficient strategies

## Key Discovery: Pipeline Type Analysis

### EXPLAIN PIPELINE Evidence
Analysis of `exp_cte_new_3.txt` reveals:
- **Multiple `FillingRightJoinSide` transforms** throughout the pipeline
- **`JoiningTransform × N 2 → 1`** pattern confirming hash join execution
- **Pipeline IS using `FillRightFirst`** in the newer version

### Hypothesis Revision
❌ **Initial Hypothesis**: Performance regression caused by switching from `HashJoin` to `FullSortingMergeJoin`
✅ **Revised Understanding**: The newer version still uses `FillRightFirst` correctly

## Current Status: Root Cause Still Unknown

The performance regression is **NOT** caused by:
- Loss of `FillRightFirst` pipeline type
- Switch to `FullSortingMergeJoin` or other join algorithms
- Disabled join optimizations

## Potential Root Causes (Revised)

1. **Different Hash Join Implementation**: 
   - `ConcurrentHashJoin` vs regular `HashJoin`
   - Hash table sizing or memory allocation changes

2. **Join Ordering/Optimization Logic Changes**:
   - Different cost estimation between versions
   - Changed heuristics within same pipeline type

3. **Threading/Parallelization Changes**:
   - Evidence: `JoiningTransform × 16` vs `JoiningTransform × 4` in different parts
   - Possible over-parallelization causing overhead

4. **Memory Usage Pattern Changes**:
   - Hash table construction efficiency
   - Memory pressure affecting performance

5. **Query Plan Optimization Regressions**:
   - Less efficient intermediate result processing
   - Suboptimal operator ordering within same pipeline structure

## Next Investigation Steps

1. **Identify exact join algorithm being used** in both versions
2. **Compare threading/parallelization settings** between versions
3. **Analyze memory usage patterns** during query execution
4. **Look for specific changes in hash join implementation** between versions
5. **Check for cost estimation or query optimization changes**

## Files Analyzed
- `/home/projects/ClickHouse/base_cte.sql` - The problematic query
- `/home/projects/ClickHouse/diff_2.txt` - EXPLAIN plan comparison
- `/home/projects/ClickHouse/exp_cte_new_3.txt` - EXPLAIN PIPELINE output
- `/home/projects/ClickHouse/src/Interpreters/IJoin.h` - Pipeline type definitions
- `/home/projects/ClickHouse/src/Planner/PlannerJoins.cpp` - Join algorithm selection
- `/home/projects/ClickHouse/src/Processors/QueryPlan/JoinStep.cpp` - Join execution logic

## Conclusion
The performance regression is more subtle than initially thought. While the overall pipeline architecture remains the same (`FillRightFirst`), there are likely implementation-level changes in hash join execution, parallelization, or query optimization that are causing the 2x slowdown.