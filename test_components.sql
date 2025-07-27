-- Component Testing Strategy for Performance Regression
-- Test each component in isolation on both versions

-- =====================================================
-- TEST 1: Base Pixel Orders Data (Simplest component)
-- =====================================================
EXPLAIN
SELECT count(*) 
FROM (
    SELECT *
    FROM sonic_system.pixel_orders_data FINAL
    WHERE event_date >= today() - 2
    UNION ALL
    SELECT *
    FROM sonic_system.pixel_orders_data
    WHERE event_date < today() - 2
        and (_part IN (
            SELECT name
            FROM (
                SELECT partition, name, level,
                    row_number() OVER (PARTITION BY partition ORDER BY level DESC) AS rn
                FROM system.parts
                WHERE active AND (`table` = 'pixel_orders_data') AND (database = 'sonic_system')
            )
            WHERE rn = 1
        ))
)
WHERE integration_id in ('shop-worldwide-mystore.myshopify.com')
    and event_date between '2025-03-28' and '2025-03-30';

-- =====================================================
-- TEST 2: Orders Data Component
-- =====================================================
EXPLAIN
SELECT count(*)
FROM (
    SELECT *
    FROM sonic_system.orders FINAL
    WHERE event_date >= today() - 2
    UNION ALL
    SELECT *
    FROM sonic_system.orders
    WHERE event_date < today() - 2
        and (_part IN (
            SELECT name
            FROM (
                SELECT partition, name, level,
                    row_number() OVER (PARTITION BY partition ORDER BY level DESC) AS rn
                FROM system.parts
                WHERE active AND (`table` = 'orders') AND (database = 'sonic_system')
            )
            WHERE rn = 1
        ))
)
WHERE integration_id in ('shop-worldwide-mystore.myshopify.com')
    and event_date between '2025-03-28' and '2025-03-30';

-- =====================================================
-- TEST 3: Simple JOIN between Pixel Orders and Orders
-- =====================================================
EXPLAIN
SELECT count(*)
FROM (
    SELECT p.order_id, p.integration_id
    FROM sonic_system.pixel_orders_data p
    WHERE p.integration_id in ('shop-worldwide-mystore.myshopify.com')
        and p.event_date between '2025-03-28' and '2025-03-30'
) p
LEFT JOIN (
    SELECT o.order_id, o.integration_id  
    FROM sonic_system.orders o
    WHERE o.integration_id in ('shop-worldwide-mystore.myshopify.com')
        and o.event_date between '2025-03-28' and '2025-03-30'
) o ON p.order_id = o.order_id;

-- =====================================================
-- TEST 4: Window Function Performance
-- =====================================================
EXPLAIN
SELECT count(*)
FROM (
    SELECT *,
        row_number() OVER (
            PARTITION BY order_id, model, source
            ORDER BY CASE attribution_type
                    WHEN 'regular' THEN 1
                    WHEN 'meta_shop' THEN 2
                    WHEN 'tiktok_shop' THEN 2
                    WHEN 'attributed from shopify' THEN 3
                    WHEN 'attributed from triplesurvey' THEN 4
                    WHEN 'attributed from kno' THEN 5
                    WHEN 'attributed from enquirelabs' THEN 6
                    ELSE 7
                END ASC
        ) AS rn
    FROM sonic_system.pixel_orders_data
    WHERE integration_id in ('shop-worldwide-mystore.myshopify.com')
        and event_date between '2025-03-28' and '2025-03-30'
        and model = 'lastPlatformClick'
);

-- =====================================================
-- TEST 5: Ads Attributes Single Table
-- =====================================================
EXPLAIN
SELECT count(*)
FROM sonic_system.ads_attributes final
WHERE _partition_id in (
    toString(sipHash64('act_2334963033288375') % 1000),
    toString(sipHash64('shop-worldwide-mystore.myshopify.com') % 1000)
)
and integration_id in ('act_2334963033288375', 'shop-worldwide-mystore.myshopify.com')
and campaign_id = '120218577773450050';

-- =====================================================
-- TEST 6: Currency Conversion Component
-- =====================================================
EXPLAIN
WITH currency_conversion AS (
    SELECT * except(currency, integration_id),
        currency_upper as currency,
        rate from_rate,
        MAX(CASE WHEN currency = 'USD' THEN rate END) OVER (PARTITION BY date) AS to_rate,
        from_rate / to_rate as currency_rate
    FROM sonic_system.currency_convert_to_usd final
    WHERE date between '2025-03-28' and '2025-03-30'
)
SELECT count(*) FROM currency_conversion;