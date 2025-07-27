-- Advanced Component Tests - Focus on Complex JOINs

-- =====================================================
-- TEST 7: Progressive JOIN Complexity
-- =====================================================

-- 7A: Pixel Orders + Array Join (Simplified)
EXPLAIN
SELECT count(*)
FROM (
    SELECT order_id, source, campaign_id, adset_id, ad_id
    FROM sonic_system.pixel_orders_data
    WHERE integration_id in ('shop-worldwide-mystore.myshopify.com')
        and event_date between '2025-03-28' and '2025-03-30'
) ARRAY JOIN ad_clicks_lifetime as a;

-- 7B: Add Orders JOIN
EXPLAIN  
SELECT count(*)
FROM (
    SELECT p.order_id, a.source, a.campaign_id
    FROM sonic_system.pixel_orders_data p
    ARRAY JOIN ad_clicks_lifetime as a
    WHERE p.integration_id in ('shop-worldwide-mystore.myshopify.com')
        and p.event_date between '2025-03-28' and '2025-03-30'
) p
LEFT JOIN sonic_system.orders o ON p.order_id = o.order_id
WHERE o.integration_id in ('shop-worldwide-mystore.myshopify.com')
    and o.event_date between '2025-03-28' and '2025-03-30';

-- 7C: Add Single Ads Attributes JOIN  
EXPLAIN
SELECT count(*)
FROM (
    SELECT p.order_id, a.source, a.campaign_id, a.adset_id, a.ad_id
    FROM sonic_system.pixel_orders_data p
    ARRAY JOIN ad_clicks_lifetime as a
    WHERE p.integration_id in ('shop-worldwide-mystore.myshopify.com')
        and p.event_date between '2025-03-28' and '2025-03-30'
) p
LEFT JOIN sonic_system.orders o ON p.order_id = o.order_id
LEFT JOIN sonic_system.ads_attributes ads ON ads.ad_id = p.ad_id
    AND ads.campaign_id = p.campaign_id
WHERE o.integration_id in ('shop-worldwide-mystore.myshopify.com')
    and o.event_date between '2025-03-28' and '2025-03-30'
    and ads.integration_id in ('act_2334963033288375', 'shop-worldwide-mystore.myshopify.com');

-- =====================================================
-- TEST 8: Isolated Ads Attributes JOINs
-- =====================================================

-- 8A: Test nested ads+adsets+campaigns JOIN separately
EXPLAIN
WITH campaigns as (
    select distinct campaign_id, campaign_name
    from sonic_system.campaigns_attributes final
    where integration_id in ('act_2334963033288375', 'shop-worldwide-mystore.myshopify.com')
        and campaign_id = '120218577773450050'
),
adsets as (
    select distinct adset_id, adset_name, campaign_id
    from sonic_system.adsets_attributes final  
    where integration_id in ('act_2334963033288375', 'shop-worldwide-mystore.myshopify.com')
        and campaign_id = '120218577773450050'
),
ads as (
    select distinct ad_id, ad_name, campaign_id, adset_id
    from sonic_system.ads_attributes final
    where integration_id in ('act_2334963033288375', 'shop-worldwide-mystore.myshopify.com')
        and campaign_id = '120218577773450050'
)
SELECT count(*)
FROM ads
JOIN adsets on ads.adset_id = adsets.adset_id and ads.campaign_id = adsets.campaign_id  
JOIN campaigns on ads.campaign_id = campaigns.campaign_id;

-- =====================================================
-- TEST 9: Progressive Main Query Build-up
-- =====================================================

-- 9A: Base query without window function
EXPLAIN
SELECT count(*)
FROM sonic_system.pixel_orders_data p
ARRAY JOIN ad_clicks_lifetime as a
WHERE p.integration_id in ('shop-worldwide-mystore.myshopify.com')
    and p.event_date between '2025-03-28' and '2025-03-30'
    and p.model = 'lastPlatformClick';

-- 9B: Add window function
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
    FROM sonic_system.pixel_orders_data p
    ARRAY JOIN ad_clicks_lifetime as a
    WHERE p.integration_id in ('shop-worldwide-mystore.myshopify.com')
        and p.event_date between '2025-03-28' and '2025-03-30'
        and p.model = 'lastPlatformClick'
) WHERE rn = 1;

-- =====================================================
-- TEST 10: Final Aggregation Performance
-- =====================================================

-- Test the final aggregation logic in isolation
EXPLAIN
WITH base_simple as (
    SELECT order_id, 'facebook-ads' as source, 'test_adset' as adset_id
    FROM sonic_system.pixel_orders_data  
    WHERE integration_id in ('shop-worldwide-mystore.myshopify.com')
        and event_date between '2025-03-28' and '2025-03-30'
    LIMIT 1000
),
orders_with_channels AS (
    SELECT order_id,
        groupUniqArray(source) AS overlaps,
        groupUniqArray(adset_id) AS adset_ids,
        arrayJoin(adset_ids) entity_id
    FROM base_simple
    GROUP BY order_id
),
channel_totals AS (
    SELECT entity_id,
        count(order_id) total_orders
    FROM orders_with_channels  
    GROUP BY entity_id
)
SELECT count(*) FROM channel_totals;