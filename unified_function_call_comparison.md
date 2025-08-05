# Unified Function Call Sequence Comparison: 25.1.8.25 vs 25.3.2.39

This unified flowchart shows where the two versions diverge and reconverge, highlighting the exact source of the performance regression.

## Unified Flow Chart with Version Split

```mermaid
flowchart TD
    %% Common initial flow
    A[TCP Handler] --> B[executeQuery]
    B --> C[executeQueryImpl]
    C --> D[InterpreterFactory::get]
    D --> E[InterpreterSelectQueryAnalyzer]
    E --> F[buildQueryTreeAndRunPasses]
    F --> G[QueryTreePassManager::run]
    G --> H[QueryAnalysisPass::run]
    H --> I[QueryAnalyzer::resolve]
    
    %% Common query analysis start
    I --> J[QueryAnalyzer::resolveQuery]
    J --> K[QueryAnalyzer::resolveQueryJoinTreeNode]
    J --> L[QueryAnalyzer::resolveProjectionExpressionNodeList]
    
    K --> M[QueryAnalyzer::resolveExpressionNode]
    L --> N[QueryAnalyzer::resolveExpressionNodeList]
    N --> M
    
    M --> O[QueryAnalyzer::resolveFunction]
    O --> P[QueryAnalyzer::resolveExpressionNodeList]
    P --> Q[QueryAnalyzer::resolveExpressionNode - Recursive]
    
    %% CRITICAL SPLIT POINT - Where versions differ
    Q --> R{Version Split<br/>Identifier Resolution}
    
    %% Fast version path (25.1.8.25)
    R -->|v25.1.8.25<br/>FAST PATH| S1[Direct Identifier Check]
    S1 --> S2[isNameOfInFunction]
    S2 --> S3[Simple String Comparison]
    S3 --> S4[QueryTreeNodePtr Return]
    S4 --> S5[11 total calls<br/>1.8 seconds]
    
    %% Slow version path (25.3.2.39)
    R -->|v25.3.2.39<br/>SLOW PATH| T1[QueryAnalyzer::tryResolveIdentifier]
    T1 --> T2[QueryAnalyzer::tryResolveIdentifierFromAliases]
    T2 --> T3[IdentifierResolveResult Creation]
    T3 --> T4[Memory Allocation]
    T4 --> T5[Structure Copy + Enum Processing]
    T5 --> T6[133 total calls<br/>3.5 seconds]
    
    %% Paths reconverge at result processing
    S5 --> U[Result Processing]
    T6 --> U
    
    %% Common final flow
    U --> V[Query Tree Hash Calculation]
    V --> W[Type Resolution]
    W --> X[Query Plan Building]
    X --> Y[Pipeline Execution]
    
    %% Performance impact annotations
    S1 -.->|×11 calls| PERF1[EFFICIENT<br/>Simple Operations]
    T1 -.->|×133 calls| PERF2[BOTTLENECK<br/>Complex Structures]
    
    %% Recursion depth annotations
    Q -.->|8-10 levels<br/>v25.1.8.25| DEPTH1[Shallow Recursion]
    Q -.->|12-15 levels<br/>v25.3.2.39| DEPTH2[Deep Recursion]
    
    %% Architecture change annotation
    R -.-> CHANGE[ARCHITECTURE CHANGE<br/>Commit 4e1a4169242<br/>QueryTreeNodePtr → IdentifierResolveResult]
    
    %% Styling
    classDef common fill:#e6f3ff,stroke:#0066cc,stroke-width:2px
    classDef fast fill:#00b894,stroke:#00a085,stroke-width:3px,color:#fff
    classDef slow fill:#e84393,stroke:#d63031,stroke-width:3px,color:#fff
    classDef split fill:#fdcb6e,stroke:#e17055,stroke-width:4px,color:#000
    classDef reconverge fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px,color:#fff
    classDef performance fill:#ff7675,stroke:#d63031,stroke-width:2px,color:#fff
    
    class A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,U,V,W,X,Y common
    class S1,S2,S3,S4,S5,PERF1,DEPTH1 fast
    class T1,T2,T3,T4,T5,T6,PERF2,DEPTH2 slow
    class R split
    class U,V,W,X,Y reconverge
    class CHANGE performance
```

## Detailed Split Analysis

```mermaid
graph TD
    A[Same Query Input] --> B[Same Initial Processing]
    B --> SPLIT{Architecture Fork<br/>Commit 4e1a4169242}
    
    %% Fast version branch
    SPLIT -->|v25.1.8.25<br/>Old Architecture| FAST[Fast Identifier Resolution]
    FAST --> F1[Direct QueryTreeNodePtr]
    F1 --> F2[Cached Column References]
    F2 --> F3[Minimal Memory Allocation]
    F3 --> F4[11 Resolution Calls]
    F4 --> F5[183 Trace Events]
    F5 --> RESULT1[1.8 Second Execution]
    
    %% Slow version branch  
    SPLIT -->|v25.3.2.39<br/>New Architecture| SLOW[Complex Identifier Resolution]
    SLOW --> S1[IdentifierResolveResult Structure]
    S1 --> S2[tryResolveIdentifier Overhead]
    S2 --> S3[Multiple Memory Allocations]
    S3 --> S4[133 Resolution Calls]
    S4 --> S5[329 Trace Events]
    S5 --> RESULT2[3.5 Second Execution]
    
    %% Results comparison
    RESULT1 --> COMPARISON[Performance Impact]
    RESULT2 --> COMPARISON
    COMPARISON --> IMPACT[94% Regression<br/>12x More Calls<br/>80% More Trace Events]
    
    %% Styling for split analysis
    classDef input fill:#e6f3ff,stroke:#0066cc,stroke-width:2px
    classDef fork fill:#fdcb6e,stroke:#e17055,stroke-width:4px,color:#000
    classDef fast_path fill:#00b894,stroke:#00a085,stroke-width:2px,color:#fff
    classDef slow_path fill:#e84393,stroke:#d63031,stroke-width:2px,color:#fff
    classDef results fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px,color:#fff
    classDef impact fill:#ff7675,stroke:#d63031,stroke-width:3px,color:#fff
    
    class A,B input
    class SPLIT fork
    class FAST,F1,F2,F3,F4,F5,RESULT1 fast_path
    class SLOW,S1,S2,S3,S4,S5,RESULT2 slow_path
    class COMPARISON results
    class IMPACT impact
```

## Recursion Pattern Comparison

```mermaid
graph TD
    START[resolveExpressionNode Entry] --> CHECK{Node Type Check}
    
    %% Common processing
    CHECK -->|Function| FUNC[resolveFunction]
    CHECK -->|List| LIST[resolveExpressionNodeList]
    CHECK -->|Identifier| ID_SPLIT{Version Fork}
    
    %% Fast version identifier handling
    ID_SPLIT -->|v25.1.8.25| FAST_ID[Simple Identifier Lookup]
    FAST_ID --> FAST_CHECK[isNameOfInFunction]
    FAST_CHECK --> FAST_RETURN[Direct QueryTreeNodePtr]
    FAST_RETURN --> FAST_DONE[Return to Caller]
    
    %% Slow version identifier handling
    ID_SPLIT -->|v25.3.2.39| SLOW_ID[tryResolveIdentifier]
    SLOW_ID --> SLOW_ALIAS[tryResolveIdentifierFromAliases]
    SLOW_ALIAS --> SLOW_STRUCT[Create IdentifierResolveResult]
    SLOW_STRUCT --> SLOW_ALLOC[Memory Allocation]
    SLOW_ALLOC --> SLOW_COPY[Structure Copy]
    SLOW_COPY --> SLOW_ENUM[Set resolve_place Enum]
    SLOW_ENUM --> SLOW_DONE[Return to Caller]
    
    %% Both paths continue with common recursion
    FUNC --> RECURSE[Recursive resolveExpressionNodeList]
    LIST --> RECURSE
    FAST_DONE --> RECURSE
    SLOW_DONE --> RECURSE
    
    RECURSE --> DEPTH_CHECK{Recursion Depth}
    DEPTH_CHECK -->|v25.1.8.25<br/>8-10 levels| SHALLOW[Efficient Stack Usage]
    DEPTH_CHECK -->|v25.3.2.39<br/>12-15 levels| DEEP[High Memory Pressure]
    
    SHALLOW --> CONTINUE[Continue Processing]
    DEEP --> CONTINUE
    CONTINUE --> START
    
    %% Performance annotations
    FAST_RETURN -.->|×11 times| FAST_PERF[Low Overhead]
    SLOW_ENUM -.->|×133 times| SLOW_PERF[High Overhead]
    
    %% Styling
    classDef common fill:#e6f3ff,stroke:#0066cc,stroke-width:1px
    classDef split fill:#fdcb6e,stroke:#e17055,stroke-width:3px,color:#000
    classDef fast fill:#00b894,stroke:#00a085,stroke-width:2px,color:#fff
    classDef slow fill:#e84393,stroke:#d63031,stroke-width:2px,color:#fff
    classDef performance fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px,color:#fff
    
    class START,CHECK,FUNC,LIST,RECURSE,DEPTH_CHECK,CONTINUE common
    class ID_SPLIT split
    class FAST_ID,FAST_CHECK,FAST_RETURN,FAST_DONE,SHALLOW,FAST_PERF fast
    class SLOW_ID,SLOW_ALIAS,SLOW_STRUCT,SLOW_ALLOC,SLOW_COPY,SLOW_ENUM,SLOW_DONE,DEEP,SLOW_PERF slow
    class CONTINUE performance
```

## Key Insights from Unified View

### 🎯 Exact Divergence Point
The performance regression occurs **precisely** at identifier resolution within `QueryAnalyzer::resolveExpressionNode()`.

### 🚀 Fast Path (25.1.8.25)
- **Single function call**: `isNameOfInFunction()`
- **Direct return**: `QueryTreeNodePtr` 
- **Minimal overhead**: Simple string comparison
- **Efficient recursion**: 8-10 levels maximum

### 🐌 Slow Path (25.3.2.39)
- **Complex call chain**: `tryResolveIdentifier()` → `tryResolveIdentifierFromAliases()` → structure creation
- **Structure overhead**: `IdentifierResolveResult` with memory allocation
- **Deep recursion**: 12-15 levels causing memory pressure

### 🔄 Reconvergence Point
Both versions reconverge at **result processing** and continue with identical query plan building and execution.

### 📊 Impact Multiplier
The **12x increase** in identifier calls (11 → 133) combined with **per-call structure overhead** creates the **94% performance regression**.

This unified view clearly shows that the architectural change affects **only the identifier resolution phase** while leaving all other query processing identical between versions.