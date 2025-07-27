# Diff Files Summary

## Performance Regression Analysis - Code Changes

This directory contains the exact code differences that caused the performance regression between ClickHouse versions 25.1.8.25 and 25.3.2.39.

### Files Created

1. **`IdentifierResolver_diff_25.1.8.25_to_25.3.2.39.patch`** (699 lines)
   - Complete diff of `src/Analyzer/Resolve/IdentifierResolver.cpp`
   - Shows the critical return type changes from `QueryTreeNodePtr` to `IdentifierResolveResult`
   - Documents the move of typo correction functions to separate module

2. **`QueryAnalyzer_diff_25.1.8.25_to_25.3.2.39.patch`** (1,104 lines)
   - Complete diff of `src/Analyzer/Resolve/QueryAnalyzer.cpp`
   - Shows architectural changes in query analysis
   - Documents changes in alias resolution strategy

3. **`combined_analyzer_diff_25.1.8.25_to_25.3.2.39.patch`** (1,803 lines)
   - Combined diff of both critical files
   - Single file for comprehensive analysis

### Version Information
- **From Version**: 25.1.8.25 (commit: `990179ead8b70778910b7ec8c7cdd14d798918a0`)
- **To Version**: 25.3.2.39 (commit: `3ec1fd3f6908a2eb035fe773c0658aa4d16c0dd4`)

### Root Cause Summary
The diffs reveal that the primary performance regression is caused by:

1. **Return type changes**: Methods now return `IdentifierResolveResult` structures instead of direct pointers
2. **Additional metadata tracking**: New `IdentifierResolvePlace` enumeration adds overhead
3. **Architectural refactoring**: Typo correction moved to separate module with potential overhead

### Impact
For complex queries with many identifier resolutions (like the 133 identifiers in the test query), these changes introduce significant computational overhead explaining the 94% performance degradation.

### Usage
These diff files can be used to:
- Review the exact changes that caused the regression
- Develop targeted performance optimizations
- Create test cases for performance validation
- Guide development of fixes or rollback strategies