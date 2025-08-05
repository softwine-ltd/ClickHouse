# Query Optimization Strategies for ClickHouse Performance

## Analysis of Current Query Issues

### **Identifier Resolution Hotspots Identified**
- **83 COALESCE operations** (54 + 29) - Each creates multiple identifier resolutions
- **32 qualified identifiers** with `p.` prefix - Forces table expression resolution
- **30 IF statements** - Complex conditional identifier resolution
- **12 qualified identifiers** with `o.` prefix - Additional table resolution overhead
- **8 CASE statements** - Complex branching logic

### **Root Cause in Query Structure**
The query structure that maximizes identifier resolution overhead:
1. **Nested CTEs**: Multiple levels of Common Table Expressions
2. **Qualified identifiers**: Extensive use of `p.column` and `o.column`
3. **Repeated patterns**: Same expressions duplicated multiple times
4. **Complex coalescing**: Many null-handling operations

## **Optimization Strategy 1: Reduce Qualified Identifiers**

### **Problem**
```sql
-- Current: Forces table expression resolution 32 times
p.integration_id, p.processed_at, p.order_ts, p.provider_id, p.order_name...
```

### **Solution: Use Explicit Column Selection**
```sql
-- Optimized: Pre-select columns to reduce qualification overhead
WITH pixel_data AS (
    SELECT 
        integration_id,
        processed_at,
        order_ts,
        provider_id,
        order_name,
        source_name,
        -- ... other needed columns
    FROM pixel_orders_table p
),
order_data AS (
    SELECT 
        customer_id,
        created_at,
        customer_first_name,
        -- ... other needed columns  
    FROM orders_table o
)
SELECT 
    -- Use unqualified identifiers (much faster resolution)
    integration_id,
    processed_at,
    order_ts
FROM pixel_data
LEFT JOIN order_data USING (order_id)
```

## **Optimization Strategy 2: Factor Out Repeated Expressions**

### **Problem: Repeated Weight Calculation (appears 10+ times)**
```sql
-- Repeated pattern causing multiple identifier resolutions
if(model in ('Linear Paid', 'Linear All'), linear_weight, 1)
```

### **Solution: Calculate Once**
```sql
WITH base_data AS (
    SELECT *,
        -- Calculate weight once, reuse everywhere
        if(model in ('Linear Paid', 'Linear All'), linear_weight, 1) AS calculated_weight,
        -- Pre-calculate currency rate
        coalesce(currency_rate, 1) AS final_currency_rate
    FROM source_data
)
SELECT 
    -- Use pre-calculated values (single identifier resolution each)
    COALESCE(order_price, total_price, 0) * calculated_weight * final_currency_rate AS gross_sales,
    COALESCE(order_price, total_price, 0) * calculated_weight * final_currency_rate AS order_revenue,
    COALESCE(gross_product_sales, 0) * calculated_weight * final_currency_rate AS gross_product_sales
FROM base_data
```

## **Optimization Strategy 3: Simplify COALESCE Chains**

### **Problem: Complex Null Handling**
```sql
-- Each COALESCE creates multiple identifier resolutions
COALESCE(p.order_ts, o.created_at)
COALESCE(p.order_date_timezone, 'Australia/Melbourne')
COALESCE(o.customer_id, p.customer_id)
```

### **Solution: Pre-resolve in CTE**
```sql
WITH resolved_data AS (
    SELECT 
        -- Resolve nulls once upfront
        CASE 
            WHEN p.order_ts IS NOT NULL THEN p.order_ts 
            ELSE o.created_at 
        END AS final_order_ts,
        
        CASE 
            WHEN p.order_date_timezone IS NOT NULL THEN p.order_date_timezone 
            ELSE 'Australia/Melbourne' 
        END AS final_timezone,
            
        CASE 
            WHEN o.customer_id IS NOT NULL THEN o.customer_id 
            ELSE p.customer_id 
        END AS final_customer_id
    FROM source_data
)
```

## **Optimization Strategy 4: Minimize Table Expression Complexity**

### **Problem: Complex Join Structure**
The current query has deeply nested subqueries with array joins and multiple table expressions that force complex identifier resolution.

### **Solution: Flatten Structure**
```sql
-- Instead of nested subqueries, use flat CTEs
WITH 
currency_rates AS (
    SELECT date, currency_upper as currency, rate as currency_rate
    FROM sonic_system.currency_convert_to_usd 
    WHERE date BETWEEN '2025-03-28' AND '2025-03-30'
),
pixel_orders AS (
    SELECT order_id, integration_id, processed_at, order_ts, linear_weight, model
    FROM sonic_system.pixel_orders_data
    WHERE event_date BETWEEN '2025-03-28' AND '2025-03-30'
),
orders_clean AS (
    SELECT order_id, customer_id, created_at, total_price
    FROM sonic_system.orders  
    WHERE event_date BETWEEN '2025-03-28' AND '2025-03-30'
)
-- Simple joins with minimal identifier complexity
SELECT p.order_id, p.integration_id, o.customer_id
FROM pixel_orders p
LEFT JOIN orders_clean o ON p.order_id = o.order_id
LEFT JOIN currency_rates c ON p.event_date = c.date
```

## **Optimization Strategy 5: Use Settings to Optimize Analyzer**

### **Performance Settings**
```sql
-- Reduce analyzer overhead
SET enable_analyzer = 1;
SET query_plan_enable_optimizations = 1;
SET query_plan_optimize_projection = 1;

-- Reduce expression evaluation overhead  
SET compile_expressions = 1;
SET min_count_to_compile_expression = 3;

-- Optimize identifier resolution
SET single_join_prefer_left_table = 1;  -- Reduces ambiguous identifier resolution
```

## **Strategy 6: Query Structure Simplification**

### **Current Complex Structure**
```sql
SELECT ... FROM (
    WITH cte1 AS (...) 
    SELECT ... FROM (
        SELECT ... FROM table1 p 
        LEFT JOIN (SELECT ... FROM table2) o
    )
) WHERE ...
```

### **Optimized Flat Structure**  
```sql
WITH 
cte1 AS (...),
cte2 AS (...),
final_data AS (
    SELECT ... FROM table1 p LEFT JOIN table2 o ON p.id = o.id
)
SELECT ... FROM final_data WHERE ...
```

## **Expected Performance Improvements**

### **Strategy 1 (Reduce Qualified Identifiers)**
- **Reduction**: 32 table expression resolutions → ~5-10
- **Performance gain**: 20-30%

### **Strategy 2 (Factor Repeated Expressions)**  
- **Reduction**: ~40 redundant expression evaluations → 4-5 pre-calculated
- **Performance gain**: 30-40%

### **Strategy 3 (Simplify COALESCE)**
- **Reduction**: 83 COALESCE operations → 20-30 simple CASE statements
- **Performance gain**: 15-25%

### **Combined Strategies**
- **Total expected improvement**: 50-70% faster query planning
- **Identifier resolutions**: 133 → 40-60 (60-70% reduction)
- **Combined with code fix**: 90-95% performance recovery

## **Implementation Priority**

1. **Quick wins** (Strategy 2): Factor out repeated weight calculations
2. **Medium impact** (Strategy 1): Reduce qualified identifiers  
3. **Structural** (Strategy 4): Flatten query structure
4. **Settings** (Strategy 5): Optimize analyzer settings
5. **Complex** (Strategy 3): Simplify COALESCE patterns