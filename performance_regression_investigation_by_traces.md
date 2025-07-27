# ClickHouse Performance Regression Investigation

## Overview
Investigation of performance degradation between ClickHouse versions:
- **Version 25.1.8.25**: 1.8 seconds execution time
- **Version 25.3.2.39**: 3.5 seconds execution time
- **Performance Loss**: 94% slower (nearly 2x degradation)

## Query Details
- **Query File**: `base_cte.sql`
- **Query Type**: Complex multi-table JOIN with CTEs, currency conversion, and extensive expression processing
- **Complexity**: Multiple subqueries, array joins, window functions, and complex CASE/COALESCE expressions

## Trace Analysis Results

### Overall Trace Volume
- **25.1.8.25**: 183 trace lines
- **25.3.2.39**: 329 trace lines
- **Increase**: +80% more trace events

### Detailed Phase Analysis

#### 1. **Identifier Resolution** - MOST CRITICAL
- **25.1.8.25**: 11 calls
- **25.3.2.39**: 133 calls
- **Regression**: +1109% (11x increase)
- **Impact**: Resolving column names, aliases, and table references

#### 2. **Function Resolution** - SEVERE
- **25.1.8.25**: 113 calls
- **25.3.2.39**: 242 calls
- **Regression**: +114% (2.1x increase)
- **Impact**: Processing `formatDateTime`, `toString`, `arrayMap`, etc.

#### 3. **Join Tree Resolution** - SEVERE
- **25.1.8.25**: 125 calls
- **25.3.2.39**: 256 calls
- **Regression**: +105% (2.0x increase)
- **Impact**: Multi-table joins and array joins processing

#### 4. **Query Tree Building & Passes** - SIGNIFICANT
- **25.1.8.25**: 146 calls
- **25.3.2.39**: 287 calls
- **Regression**: +96% (2.0x increase)
- **Impact**: Query tree initialization and pass management

#### 5. **Expression Resolution** - SIGNIFICANT
- **25.1.8.25**: 140 calls
- **25.3.2.39**: 272 calls
- **Regression**: +94% (1.9x increase)
- **Impact**: Complex expressions like `COALESCE`, `CASE WHEN`, arithmetic

#### 6. **Query Plan Optimization** - MODERATE
- **25.1.8.25**: 4 calls
- **25.3.2.39**: 7 calls
- **Regression**: +75% (1.8x increase)
- **Impact**: Optimization passes including join algorithm selection

## Root Cause Analysis

### Primary Issue
The performance regression is concentrated in the **query analysis and planning phase**, not execution. The most dramatic increase is in **identifier resolution** (11x), suggesting algorithmic inefficiencies in resolving complex nested identifiers within CTEs and subqueries.

### Secondary Issues
- **Function resolution** and **join tree resolution** both show ~2x increases
- **Expression processing** overhead has nearly doubled
- Overall **query analyzer** is performing significantly more work for the same query

## Relevant Code Files Identified

### Core Components
- `src/Analyzer/Resolve/QueryAnalyzer.h/.cpp` - Main analyzer implementation
- `src/Analyzer/Resolve/IdentifierResolver.h/.cpp` - Identifier resolution logic (PRIMARY TARGET)
- `src/Analyzer/QueryTreePassManager.h/.cpp` - Pass management system

### Key Methods to Investigate
- `tryResolveIdentifier()` - Most critical (11x regression)
- `resolveFunction()` - Function resolution logic
- `resolveQueryJoinTreeNode()` - Join processing
- `resolveExpressionNode()` - Expression handling

## Investigation Strategy

### Priority 1: Identifier Resolution
1. Compare `IdentifierResolver.cpp` between versions 25.1.8.25 and 25.3.2.39
2. Focus on `tryResolveIdentifier()` method changes
3. Look for redundant processing or inefficient algorithms

### Priority 2: Function & Join Resolution
1. Examine `QueryAnalyzer.cpp` changes in:
   - `resolveFunction()` method
   - `resolveQueryJoinTreeNode()` method
2. Check for performance regressions in complex expression handling

### Priority 3: Pass Management
1. Review `QueryTreePassManager.cpp` for changes in pass execution
2. Look for additional passes or inefficient pass ordering

## Next Steps
1. **Git blame/diff analysis** on identified files between the two versions
2. **Profiling** the specific methods showing regressions
3. **Code review** of algorithmic changes in identifier resolution
4. **Performance testing** with simplified queries to isolate the issue

## Status
- ✅ Trace analysis completed
- ✅ Performance bottlenecks identified
- ✅ Code files located
- 🔄 **Next**: Code comparison between versions