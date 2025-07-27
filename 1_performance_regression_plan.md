# ClickHouse Performance Regression Analysis Plan

## Problem Statement
- **Original Version**: 25.1.8.25 (7-8 seconds)
- **New Version**: 25.4.1.2934 (15 seconds)
- **Performance Degradation**: 2x slower
- **Query**: Complex analytical query in `long_query.sql`

## Key Observations
- Execution plan shows removal of `JOIN FillRightFirst` operations
- JOIN strategy changed from `FillRightFirst` to regular `JOIN`
- Setting `join_algorithm = 'hash'` had no impact on query planning
- Query involves complex nested JOINs with ads attributes and window functions

## Divide and Conquer Strategy

### Phase 1: Basic Component Testing (`test_components.sql`)

#### Test 1: Base Pixel Orders Data
- Simple UNION ALL optimization test
- Focus: Basic table access patterns

#### Test 2: Orders Data Component  
- Similar UNION ALL pattern for orders table
- Focus: Compare with pixel orders performance

#### Test 3: Simple JOIN (Pixel Orders + Orders)
- Basic two-table JOIN operation
- Focus: JOIN algorithm behavior changes

#### Test 4: Window Function Performance
- Isolated window function with complex CASE ordering
- Focus: Window operation optimization changes

#### Test 5: Ads Attributes Single Table
- Single table access with partition pruning
- Focus: Partition selection performance

#### Test 6: Currency Conversion Component
- Window function with MAX() OVER()
- Focus: Currency calculation performance

### Phase 2: Advanced Component Testing (`advanced_tests.sql`)

#### Test 7: Progressive JOIN Complexity
- **7A**: Pixel Orders + Array Join (Simplified)
- **7B**: Add Orders JOIN  
- **7C**: Add Single Ads Attributes JOIN
- Focus: Identify where complexity causes degradation

#### Test 8: Isolated Ads Attributes JOINs
- Test nested ads+adsets+campaigns JOIN separately
- Focus: Complex multi-table JOIN performance

#### Test 9: Progressive Main Query Build-up
- **9A**: Base query without window function
- **9B**: Add window function
- Focus: Window function impact on complex queries

#### Test 10: Final Aggregation Performance
- Test final groupArray and aggregation logic
- Focus: Final result processing performance

## Execution Strategy

### 1. Run Basic Tests
```bash
# On version 25.1.8.25
clickhouse-client --query "$(cat test_components.sql)" > results_old_basic.txt

# On version 25.4.1.2934  
clickhouse-client --query "$(cat test_components.sql)" > results_new_basic.txt

# Compare execution plans
diff results_old_basic.txt results_new_basic.txt
```

### 2. Run Advanced Tests
```bash
# On version 25.1.8.25
clickhouse-client --query "$(cat advanced_tests.sql)" > results_old_advanced.txt

# On version 25.4.1.2934
clickhouse-client --query "$(cat advanced_tests.sql)" > results_new_advanced.txt

# Compare results
diff results_old_advanced.txt results_new_advanced.txt
```

### 3. Performance Timing
```bash
# Add timing to each test
time clickhouse-client --query "TEST_QUERY_HERE"
```

## Key Areas of Investigation

### 1. ARRAY JOIN Operations
- **Why**: Execution plan shows significant changes in array processing
- **What to look for**: Performance degradation in Test 7A and 9A
- **Potential issue**: Array processing algorithm changes

### 2. Window Functions  
- **Why**: Complex CASE expressions in ORDER BY clause
- **What to look for**: Performance degradation in Test 4 and 9B
- **Potential issue**: Window function optimization changes

### 3. Multiple Nested JOINs
- **Why**: Complex ads attributes section with 3-way JOINs
- **What to look for**: Performance degradation in Test 8A and 7C
- **Potential issue**: JOIN algorithm selection logic

### 4. UNION ALL Optimizations
- **Why**: Both pixel_orders_data and orders use UNION ALL patterns
- **What to look for**: Performance degradation in Test 1 and 2
- **Potential issue**: Union processing optimization changes

## Decision Tree Based on Results

### If Basic Tests (1-6) Show No Difference
→ **Focus on Advanced Tests**: Issue is in complex JOIN interactions
→ **Priority**: Tests 7, 8, 9

### If ARRAY JOIN (Test 7A, 9A) Shows Issues  
→ **Root Cause**: Array processing algorithm changes
→ **Solution**: Look for array-related settings or version-specific optimizations

### If Window Functions (Test 4, 9B) Degrade
→ **Root Cause**: Window optimization changes  
→ **Solution**: Check window-related settings and algorithms

### If Ads JOINs (Test 8A, 7C) Are Slow
→ **Root Cause**: JOIN algorithm selection logic
→ **Solution**: Force specific JOIN algorithms or investigate JOIN ordering

### If UNION ALL (Test 1, 2) Shows Issues
→ **Root Cause**: Union processing changes
→ **Solution**: Check union-related optimizations and settings

## Expected Outcomes

1. **Identify the specific component** causing 2x degradation
2. **Understand the root cause** (algorithm change, optimization regression, etc.)
3. **Provide targeted solution**:
   - Settings to restore old behavior
   - Query rewrite to work around issue  
   - Report to ClickHouse team if it's a regression

## Files Created
- `test_components.sql` - Basic component tests
- `advanced_tests.sql` - Complex component tests  
- `performance_regression_plan.md` - This plan document
- `long_query.sql` - Original problematic query
- `diff_1.txt` - Execution plan comparison

## Next Steps
1. Execute Phase 1 testing on both versions
2. Analyze results and identify degraded components
3. Execute Phase 2 focused testing
4. Implement solution based on findings