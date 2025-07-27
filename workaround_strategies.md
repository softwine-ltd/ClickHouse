# ClickHouse Performance Regression Workarounds

## Immediate Workarounds (Test These First)

### 1. Force Specific Join Algorithms
```sql
-- Try forcing different join algorithms
SET join_algorithm = 'parallel_hash';
-- OR
SET join_algorithm = 'grace_hash'; 
-- OR  
SET join_algorithm = 'full_sorting_merge';
```

### 2. Memory/Threading Adjustments
```sql
-- Reduce parallelization to avoid overhead
SET max_threads = 8;  -- or 4
SET max_execution_threads = 8;

-- Adjust join-specific memory settings
SET max_bytes_in_join = 1000000000;  -- 1GB limit
SET join_on_disk_max_files_to_merge = 32;  -- reduce from default 64

-- Force smaller hash tables 
SET max_rows_in_join = 10000000;
```

### 3. Query Execution Settings
```sql
-- Disable potentially problematic optimizations
SET query_plan_enable_optimizations = 0;  -- nuclear option
-- OR more targeted:
SET query_plan_filter_push_down = 0;
SET query_plan_merge_expressions = 0;
SET optimize_aggregation_in_order = 0;
```

## Query Rewriting Strategies

### 4. CTE Materialization
Break the complex currency_conversion CTE into a temporary table:
```sql
-- Instead of WITH currency_conversion AS (...)
CREATE TEMPORARY TABLE currency_conversion_temp AS
SELECT * except(currency, integration_id),
    currency_upper as currency,
    rate from_rate,
    MAX(CASE WHEN currency = 'USD' THEN rate END) OVER (PARTITION BY date) AS to_rate,
    from_rate / to_rate as currency_rate
FROM sonic_system.currency_convert_to_usd final
WHERE date between '2025-03-28' and '2025-03-30';

-- Then use currency_conversion_temp in main query
```

### 5. Simplify Array Joins
```sql
-- If the ARRAY JOIN is causing issues, consider pre-processing:
CREATE TEMPORARY TABLE exploded_clicks AS
SELECT order_id, source, campaign_id, adset_id, ad_id, click_ts, click_date, linear_weight
FROM (
    SELECT * FROM sonic_system.pixel_orders_data 
    WHERE event_date between '2025-03-28' and '2025-03-30'
) ARRAY JOIN ad_clicks_lifetime as a;
```

### 6. Join Order Optimization
```sql
-- Force specific join order by restructuring query
-- Move smaller tables to the right side of joins explicitly
-- Consider using EXISTS instead of JOINs for filtering operations
```

## System-Level Workarounds

### 7. Resource Allocation
In your Kubernetes pod spec:
```yaml
resources:
  limits:
    cpu: "24"      # Increase from 16
    memory: 120Gi  # Increase from 80Gi
  requests:
    cpu: "12"      # Increase from 8  
    memory: 40Gi   # Increase from 20Gi
```

### 8. ClickHouse Configuration Overrides
Add to your ConfigMap (`chi-sonic-sharded-common-configd`):
```xml
<clickhouse>
    <profiles>
        <default>
            <!-- Force older behavior -->
            <max_threads>8</max_threads>
            <join_algorithm>hash</join_algorithm>
            <query_plan_join_swap_table>false</query_plan_join_swap_table>
            
            <!-- Memory optimizations -->
            <max_memory_usage>32000000000</max_memory_usage>
            <max_bytes_in_join>8000000000</max_bytes_in_join>
            
            <!-- Disable potentially problematic features -->
            <use_query_condition_cache>0</use_query_condition_cache>
            <enable_filesystem_cache>0</enable_filesystem_cache>
        </default>
    </profiles>
</clickhouse>
```

## Targeted Query Optimizations

### 9. Window Function Optimization
```sql
-- Replace row_number() with more efficient alternatives where possible
-- Consider if DISTINCT or GROUP BY can replace window functions
```

### 10. Parts Selection Optimization
The query has complex part selection logic. Try:
```sql
-- Simplify the parts selection:
SET optimize_skip_unused_shards = 0;
SET force_optimize_skip_unused_shards = 0;
```

### 11. Date Range Optimization
```sql
-- If possible, reduce the date range to test if it's data-volume related
-- event_date between '2025-03-29' and '2025-03-29'  -- single day
```

## Version Rollback Strategy

### 12. Selective Rollback
If workarounds don't help:
```bash
# Change image in pod.yaml:
image: clickhouse:25.1.8.25
# OR try intermediate versions:
image: clickhouse:25.2.1.11-stable
```

## Testing Priority

**Test in this order:**
1. **Join algorithm forcing** (quick test)
2. **Thread reduction** (quick test)
3. **Memory limits** (quick test)  
4. **CTE materialization** (requires query rewrite)
5. **Configuration overrides** (requires pod restart)
6. **Version rollback** (requires pod restart)

## Monitoring During Tests

```sql
-- Check memory usage during query execution
SELECT 
    query, 
    memory_usage, 
    peak_memory_usage,
    query_duration_ms
FROM system.query_log 
WHERE query LIKE '%currency_conversion%'
ORDER BY event_time DESC 
LIMIT 5;
```

## Expected Results

- **Join algorithm changes**: Could provide 20-50% improvement
- **Thread reduction**: May reduce overhead in complex queries
- **CTE materialization**: Could provide significant improvement for repeated CTE usage
- **Memory adjustments**: May prevent swapping/memory pressure issues

The goal is to find a combination that restores performance to ~1.8 seconds without requiring a ClickHouse version change.