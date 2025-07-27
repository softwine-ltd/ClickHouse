# Root Cause Analysis: ClickHouse Performance Regression

## 🎯 **ROOT CAUSE IDENTIFIED**

The performance regression between ClickHouse 25.1.8.25 (1.786s) and 25.3.2.39 (3.634s) was caused by a **query optimization that was introduced and then quickly reverted** within the same release.

## Timeline of the Issue

### The Problematic Optimization: "Join to Subquery"
- **Introduced**: Commit `5313dc785a3` (March 13, 2025) - Merge pull request #75942
- **Reverted**: Commit `80dd503364e` (March 13, 2025) - Same day!
- **Both changes are present in v25.3.2.39**

### What the Optimization Did
The `convertJoinToIn` optimization automatically converted certain **INNER JOINs to IN subqueries**:

```sql
-- Before optimization:
SELECT t1.id FROM t1 INNER JOIN t2 ON t1.id = t2.id

-- After optimization (conceptually):
SELECT t1.id FROM t1 WHERE t1.id IN (SELECT t2.id FROM t2)
```

### Optimization Criteria
The transformation was applied when:
1. **INNER JOIN** with `JoinStrictness::All`
2. **Hash or Parallel Hash** join algorithms only
3. **All output columns come from left side** only
4. **Simple equality predicates** in join condition
5. **Reading from MergeTree** tables

### Why It Caused Performance Regression

#### 1. **Suboptimal for Complex Queries**
The target query has:
- **Complex nested CTEs** with multiple joins
- **Window functions** and aggregations
- **Complex join predicates** beyond simple equality
- **Multiple output columns from both sides**

#### 2. **Loss of Hash Join Optimizations**
Converting JOIN to IN subquery loses:
- **Efficient hash table building** from right side
- **`FillRightFirst` pipeline optimizations**
- **Join-specific memory management**
- **Parallel join execution benefits**

#### 3. **Increased Complexity**
IN subqueries can be less efficient for:
- **Large result sets** from right side
- **Complex filtering conditions**
- **Memory usage patterns** (building sets vs hash tables)

## Evidence from Code Analysis

### Setting Introduction
```cpp
// In SettingsChangesHistory.cpp
{"query_plan_convert_join_to_in", false, false, "New setting"}
```
The optimization was **disabled by default** but may have been activated during query planning.

### Optimization Logic
From `convertJoinToIn.cpp`:
```cpp
// Only for hash joins
if (join_algorithm != JoinAlgorithm::HASH && join_algorithm != JoinAlgorithm::PARALLEL_HASH)
    return 0;

// Only for INNER joins
if (!isInner(join_info.kind))
    return 0;

// Only when all outputs come from left side
if (!(left && !right))
    return 0;
```

### Why It Was Reverted
The optimization was reverted **the same day** it was merged, indicating:
1. **Immediate performance issues** discovered
2. **Correctness problems** with complex queries
3. **Regression in critical workloads**

## Impact on Target Query

The complex CTE query with multiple joins and window functions was likely:
1. **Incorrectly identified** as a candidate for JOIN→IN conversion
2. **Partially transformed**, creating suboptimal execution plans
3. **Lost hash join optimizations** for critical join operations
4. **Increased memory pressure** from multiple IN subqueries

## Why EXPLAIN PIPELINE Still Shows FillRightFirst

The pipeline analysis showing `FillingRightJoinSide` indicates that:
1. **Not all joins were converted** to IN subqueries
2. **Some joins remained as hash joins** with `FillRightFirst`
3. **Mixed execution strategy** caused overall performance degradation
4. **Suboptimal join ordering** due to partial transformation

## Resolution Strategy

### Immediate Fix
The issue should be resolved by:
1. **Upgrading to a version after the revert** (post-March 13, 2025)
2. **Explicitly disabling the optimization**: `SET query_plan_convert_join_to_in = 0`
3. **Using hash join explicitly**: `SET join_algorithm = 'hash'` (already tried)

### Long-term Monitoring
1. **Track this optimization** in future ClickHouse releases
2. **Test complex analytical queries** before production deployment
3. **Monitor for similar query plan regression** patterns

## Conclusion

This is a **textbook example** of a well-intentioned optimization that:
- ✅ Works well for **simple INNER JOINs**
- ❌ **Degrades performance** for complex analytical workloads
- ❌ Was **quickly reverted** due to regression impact
- ❌ **Temporarily affected** version 25.3.2.39 during the brief window

The performance regression was **not** due to fundamental architecture changes but rather a **temporary optimization experiment** that proved problematic for real-world complex queries.