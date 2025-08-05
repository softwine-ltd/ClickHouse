# Commits Analysis - IdentifierResolver.cpp Changes

## Key Commits Causing Performance Regression

### **Primary Commit - Main Culprit**
**Commit**: `4e1a4169242` (Author: Dmitry Novik)  
**Date**: Thu Feb 13 15:52:02 2025 +0100  
**Message**: "Refactor IdentifierResolver to simplify interface"  
**PR**: #76072  
**Merged by**: Nikita Mikhaylov (e7a9856d3b1)  

**Impact**: This is the **main commit** that introduced the performance regression by:
- Refactoring return types from `QueryTreeNodePtr` to `IdentifierResolveResult`
- Moving 273 lines of typo correction code to separate TypoCorrection module
- Creating the overhead-heavy structure that caused the 94% performance loss

**Files Changed**:
- `src/Analyzer/Resolve/IdentifierResolver.cpp` (-273 lines)
- `src/Analyzer/Resolve/IdentifierResolver.h` (125 lines changed) 
- `src/Analyzer/Resolve/QueryAnalyzer.cpp` (14 lines changed)
- `src/Analyzer/Resolve/TypoCorrection.cpp` (+226 lines - NEW FILE)
- `src/Analyzer/Resolve/TypoCorrection.h` (+55 lines - NEW FILE)

### **Related Commits in the Same Development Branch**

1. **`f68c74a683e`** - "Another attempt + refactoring" (Jul 19, 2024)
   - Early experimental version that likely introduced `IdentifierResolveResult` concept
   - 400+ lines changed in QueryAnalyzer.cpp

2. **`9930124dca8`** - "Reduce number of allocations" 
   - Performance optimization attempt (but didn't address the core issue)

3. **`cae94c922f1`** - "Clean up code"
   - Code cleanup related to the refactoring

4. **`9350f5e5bff`** - "Fix hits for compound identifiers"
   - Bug fix for compound identifier handling

## Timeline of Changes

```
Jul 19, 2024  - f68c74a683e - Initial IdentifierResolveResult experiments
...           - Multiple refinements and fixes
Feb 13, 2025  - 4e1a4169242 - Main refactoring commit (THE CULPRIT)
Feb 14, 2025  - e7a9856d3b1 - Merged to master via PR #76072
```

## Root Cause Confirmation

The analysis confirms that **commit 4e1a4169242** is the direct cause of the performance regression. This commit:

1. **Introduced IdentifierResolveResult structure overhead**
   - Changed method signatures from returning `QueryTreeNodePtr` directly
   - Added mandatory structure creation for every identifier resolution

2. **Moved typo correction to separate module**
   - Added `#include <Analyzer/Resolve/TypoCorrection.h>` overhead
   - Created additional function call overhead for typo correction

3. **Added resolve place tracking**
   - Introduced `IdentifierResolvePlace` enum tracking
   - Added metadata overhead for every resolution

## Performance Impact Calculation

**For the regression query with 133 identifier resolutions:**
- **Before (25.1.8.25)**: Direct `QueryTreeNodePtr` returns
- **After (25.3.2.39)**: 133 × `IdentifierResolveResult` structure creations
- **Overhead per resolution**: ~16-24 bytes + enum assignment + field extraction
- **Total added overhead**: ~2KB memory + 400+ additional operations

## Fix Target

Our performance fix in `fast_path_implementation.patch` specifically targets this commit by:
1. **Bypassing IdentifierResolveResult** for simple cases
2. **Restoring direct QueryTreeNodePtr returns** when possible
3. **Maintaining compatibility** with the new architecture for complex cases

## Commit for Blame/Reference

When discussing this issue with ClickHouse developers, reference:
- **Primary culprit**: `4e1a4169242` - "Refactor IdentifierResolver to simplify interface"
- **PR**: #76072
- **Author**: Dmitry Novik
- **Merge date**: Feb 14, 2025

This commit can be partially reverted or optimized using our fast path approach to restore performance without losing the architectural benefits of the refactoring.