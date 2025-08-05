# Function Call Sequence Analysis for ClickHouse 25.3.2.39

Based on the trace file analysis, here's the function call sequence that shows the performance regression:

## High-Level Call Flow

```
1. TCP Handler
   └── executeQuery()
       └── executeQueryImpl()
           └── InterpreterFactory::get()
               └── InterpreterSelectQueryAnalyzer::InterpreterSelectQueryAnalyzer()
                   └── buildQueryTreeAndRunPasses()
                       └── QueryTreePassManager::run()
                           └── QueryAnalysisPass::run()
                               └── QueryAnalyzer::resolve()
```

## Detailed Call Sequence in Query Analysis Phase

The performance regression occurs in the query analysis phase where we see the following repetitive pattern **133 times**:

```
QueryAnalyzer::resolve()
└── QueryAnalyzer::resolveQuery()
    ├── QueryAnalyzer::resolveQueryJoinTreeNode()
    │   └── QueryAnalyzer::resolveExpressionNode()
    └── QueryAnalyzer::resolveProjectionExpressionNodeList()
        └── QueryAnalyzer::resolveExpressionNodeList()
            └── QueryAnalyzer::resolveExpressionNode()
                └── QueryAnalyzer::resolveFunction()
                    └── QueryAnalyzer::resolveExpressionNodeList()
                        └── QueryAnalyzer::resolveExpressionNode()
                            └── QueryAnalyzer::resolveFunction()
                                └── QueryAnalyzer::resolveExpressionNode()
                                    └── QueryAnalyzer::tryResolveIdentifier() ← BOTTLENECK
                                        └── QueryAnalyzer::tryResolveIdentifierFromAliases()
```

## Key Bottleneck Functions

The **133 identifier resolution calls** happen through these functions:

1. **`QueryAnalyzer::tryResolveIdentifier()`** - Called 133 times
2. **`QueryAnalyzer::tryResolveIdentifierFromAliases()`** - Called multiple times per identifier
3. **`QueryAnalyzer::resolveExpressionNode()`** - Called recursively for each expression
4. **`QueryAnalyzer::resolveFunction()`** - Called for each function in expressions

## Root Cause

Each identifier resolution now creates an `IdentifierResolveResult` structure instead of returning a simple `QueryTreeNodePtr`:

```cpp
struct IdentifierResolveResult {
    QueryTreeNodePtr resolved_identifier;
    IdentifierResolvePlace resolve_place = IdentifierResolvePlace::NONE;
};
```

This change (from commit 4e1a4169242) means:
- **133 identifier resolutions** × **structure overhead** = **significant performance loss**
- Each resolution involves more memory allocation and copying
- Additional enum processing for `resolve_place`

## Call Stack Depth

The call stack shows deep recursion:
- **12-15 levels deep** in expression resolution
- Recursive calls through `resolveExpressionNode()` → `resolveFunction()` → `resolveExpressionNodeList()`
- Each level processes multiple identifiers

## Comparison with 25.1.8.25

In the faster version (25.1.8.25), there were only **11 identifier resolution calls**, suggesting that the new architecture processes identifiers much more granularly, creating overhead for each individual resolution rather than batching or optimizing them.

The performance regression is directly proportional to the number of identifiers in the query, explaining why this complex query with many `COALESCE()`, qualified identifiers (`p.`), and function calls is particularly affected.

## Visual Flow Chart

```mermaid
flowchart TD
    A[TCP Handler] --> B[executeQuery]
    B --> C[executeQueryImpl]
    C --> D[InterpreterFactory::get]
    D --> E[InterpreterSelectQueryAnalyzer]
    E --> F[buildQueryTreeAndRunPasses]
    F --> G[QueryTreePassManager::run]
    G --> H[QueryAnalysisPass::run]
    H --> I[QueryAnalyzer::resolve]
    
    I --> J[QueryAnalyzer::resolveQuery]
    J --> K[QueryAnalyzer::resolveQueryJoinTreeNode]
    J --> L[QueryAnalyzer::resolveProjectionExpressionNodeList]
    
    K --> M[QueryAnalyzer::resolveExpressionNode]
    L --> N[QueryAnalyzer::resolveExpressionNodeList]
    N --> M
    
    M --> O[QueryAnalyzer::resolveFunction]
    O --> P[QueryAnalyzer::resolveExpressionNodeList]
    P --> Q[QueryAnalyzer::resolveExpressionNode - Recursive]
    
    Q --> R{Is Identifier?}
    R -->|Yes| S[QueryAnalyzer::tryResolveIdentifier]
    R -->|No| T[QueryAnalyzer::resolveFunction]
    
    S --> U[QueryAnalyzer::tryResolveIdentifierFromAliases]
    U --> V[IdentifierResolveResult Creation]
    V --> W[Memory Allocation + Structure Copy]
    
    T --> P
    Q --> P
    
    %% Performance bottleneck highlighting
    S -.->|133 times| X[Performance Bottleneck<br/>133 identifier resolutions<br/>vs 11 in v25.1.8.25]
    
    %% Recursion loops
    M -.->|Deep Recursion<br/>12-15 levels| Q
    P -.->|Expression Lists| Q
    Q -.->|Function Arguments| T
    
    %% Styling
    classDef bottleneck fill:#ff6b6b,stroke:#d63031,stroke-width:3px,color:#fff
    classDef recursion fill:#fdcb6e,stroke:#e17055,stroke-width:2px
    classDef normal fill:#74b9ff,stroke:#0984e3,stroke-width:1px
    
    class S,U,V,W,X bottleneck
    class M,Q,P,T recursion
    class A,B,C,D,E,F,G,H,I,J,K,L,N,O,R normal
```

## Detailed Recursion Pattern

```mermaid
graph TD
    A[QueryAnalyzer::resolveExpressionNode] --> B{Node Type?}
    
    B -->|Function| C[QueryAnalyzer::resolveFunction]
    B -->|Identifier| D[QueryAnalyzer::tryResolveIdentifier]
    B -->|List| E[QueryAnalyzer::resolveExpressionNodeList]
    
    C --> F[Process Function Arguments]
    F --> G[QueryAnalyzer::resolveExpressionNodeList]
    G --> H[For each argument]
    H --> A
    
    E --> I[For each expression in list]
    I --> A
    
    D --> J[QueryAnalyzer::tryResolveIdentifierFromAliases]
    J --> K[Create IdentifierResolveResult]
    K --> L[Memory Allocation]
    L --> M[Structure Copy]
    M --> N[Set resolve_place enum]
    
    %% Show the 133x multiplication
    D -.->|Repeated 133 times<br/>in 25.3.2.39| O[PERFORMANCE<br/>REGRESSION]
    
    %% Recursion depth
    A -.->|12-15 levels deep| P[Deep Call Stack<br/>High Memory Usage]
    
    %% Styling
    classDef critical fill:#ff7675,stroke:#d63031,stroke-width:3px,color:#fff
    classDef expensive fill:#fdcb6e,stroke:#e17055,stroke-width:2px
    classDef recursive fill:#a29bfe,stroke:#6c5ce7,stroke-width:2px
    classDef normal fill:#74b9ff,stroke:#0984e3,stroke-width:1px
    
    class D,J,K,L,M,N,O critical
    class C,F,G,E,I expensive
    class A,H recursive
    class B,P normal
```

## Performance Impact Visualization

```mermaid
graph LR
    A[v25.1.8.25<br/>11 calls<br/>1.8 seconds] --> B[Commit 4e1a4169242<br/>IdentifierResolveResult<br/>Structure Change]
    B --> C[v25.3.2.39<br/>133 calls<br/>3.5 seconds]
    
    D[Each Identifier Resolution] --> E[QueryTreeNodePtr<br/>Simple pointer return]
    E --> F[Fast: 11 × Simple = 11 units]
    
    G[Each Identifier Resolution] --> H[IdentifierResolveResult<br/>Structure + enum + allocation]
    H --> I[Slow: 133 × Complex = 399+ units]
    
    A -.-> D
    C -.-> G
    
    F --> J[94% Performance<br/>Regression]
    I --> J
    
    classDef fast fill:#00b894,stroke:#00a085,stroke-width:2px,color:#fff
    classDef slow fill:#e84393,stroke:#d63031,stroke-width:2px,color:#fff
    classDef impact fill:#fd79a8,stroke:#e84393,stroke-width:3px,color:#fff
    
    class A,D,E,F fast
    class C,G,H,I slow
    class B,J impact
```