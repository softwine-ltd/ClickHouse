-- SET query_profiler_real_time_period_ns = 10000000;
-- SET query_profiler_cpu_time_period_ns = 10000000;
-- SET max_ast_depth = 100;
--   SET max_expanded_ast_elements = 5000;
  SET max_parser_depth = 100;

-- ===================================
-- TEMPORARY TABLES TO REPLACE CTEs
-- ===================================

-- 1. Convert currency_conversion CTE to temporary table
DROP TEMPORARY TABLE IF EXISTS temp_currency_conversion;
CREATE TEMPORARY TABLE temp_currency_conversion AS
SELECT *
except(currency, integration_id),
    currency_upper as currency,
    rate from_rate,
    MAX(
        CASE
            WHEN currency = 'USD' THEN rate
        END
    ) OVER (PARTITION BY date) AS to_rate,
    from_rate / to_rate as currency_rate
FROM sonic_system.currency_convert_to_usd final
WHERE date between '2025-03-28' and '2025-03-30';

-- 2. Convert orders_product_info_cte to temporary table
DROP TEMPORARY TABLE IF EXISTS temp_orders_product_info;
CREATE TEMPORARY TABLE temp_orders_product_info AS
select cast(null as Nullable(String)) as integration_id,
    cast(null as Nullable(String)) as provider_id,
    cast(null as Nullable(String)) as order_id,
    cast(null as Nullable(String)) as products_info;

-- 3. Convert campaigns CTE to temporary table  
DROP TEMPORARY TABLE IF EXISTS temp_campaigns;
CREATE TEMPORARY TABLE temp_campaigns AS
select distinct campaign_id,
    campaign_name,
    campaign_created_at,
    campaign_status,
    campaign_daily_budget,
    campaign_lifetime_budget,
    campaign_bid_strategy,
    campaign_type
from sonic_system.campaigns_attributes final
where _partition_id in (
        toString(sipHash64('act_2334963033288375') % 1000),
        toString(sipHash64('act_982017648865684') % 1000),
        toString(sipHash64('act_327284493307469') % 1000),
        toString(sipHash64('act_365685005786694') % 1000),
        toString(sipHash64('act_985581122993968') % 1000),
        toString(sipHash64('8339477503') % 1000),
        toString(sipHash64('shop-worldwide-mystore.myshopify.com') % 1000),
        toString(sipHash64('null') % 1000),
        toString(
            sipHash64('ef0d9302-01f6-4f4c-b06a-8b9bb554356a') % 1000
        )
    )
    and integration_id in (
        'act_2334963033288375',
        'act_982017648865684',
        'act_327284493307469',
        'act_365685005786694',
        'act_985581122993968',
        '8339477503',
        'shop-worldwide-mystore.myshopify.com',
        'null',
        'ef0d9302-01f6-4f4c-b06a-8b9bb554356a'
    )
    and campaign_id = '120218577773450050';

-- ===================================
-- MAIN QUERY USING TEMPORARY TABLES
-- ===================================

        SELECT order_id,
            if(
                channel = 'organic_and_social',
                concat('ref__', campaign_id),
                channel
            ) as source,
            campaign_id,
            adset_id,
            ad_id
        FROM (
                select event_date,
                    p.integration_id AS integration_id,
                    formatDateTime(
                        COALESCE(p.processed_at, p.order_ts),
                        '%H',
                        'Australia/Melbourne'
                    ) event_hour,
                    toString(
                        COALESCE(p.order_ts, o.created_at),
                        COALESCE(p.order_date_timezone, 'Australia/Melbourne')
                    ) as created_at,
                    p.provider_id as platform,
                    order_date_timezone as shop_timezone,
                    order_id,
                    p.order_name,
                    p.source_name as source_name,
                    if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) AS orders_quantity,
                    COALESCE(tw_total_items, 0) AS product_quantity_sold_in_order,
                    COALESCE(o.customer_id, p.customer_id) as customer_id,
                    coalesce(tw_is_first_order, is_new_customer) AS is_new_customer,
                    customer_first_name,
                    customer_last_name,
                    customer_email,
                    shipping_country_code AS customer_from_country_code,
                    shipping_province_code AS customer_from_state_code,
                    customer_from_city,
                    fulfillment_status,
                    currency,
                    COALESCE(order_price, total_price, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) AS gross_sales,
                    COALESCE(order_price, total_price, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) AS order_revenue,
                    COALESCE(gross_product_sales, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) AS gross_product_sales,
                    COALESCE(tw_total_shipping_price, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) AS shipping_price,
                    coalesce(tw_total_shipping_tax, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as shipping_tax,
                    COALESCE(tw_total_tax, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) AS taxes,
                    coalesce(shipping_costs, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as shipping_costs,
                    coalesce(payment_gateway_fees_and_costs, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as payment_gateway_costs,
                    coalesce(cogs, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as cogs,
                    cogs as cost_of_goods,
                    coalesce(total_handling_fees, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as handling_fees,
                    COALESCE(total_discounts, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) AS discount_amount,
                    coalesce(refund_money, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as refund_money,
                    coalesce(tw_custom_expenses, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as custom_expenses,
                    coalesce(tw_custom_gross_sales, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as custom_gross_sales,
                    coalesce(tw_custom_net_revenue, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as custom_net_revenue,
                    coalesce(tw_custom_gross_profit, 0) * if(
                        model in ('Linear Paid', 'Linear All'),
                        linear_weight,
                        1
                    ) * coalesce(currency_rate, 1) as custom_gross_profit,
                    coalesce(tw_custom_total_items_quantity, 0) as custom_total_items_quantity,
                    coalesce(tw_custom_orders_quantity, 0) as custom_orders_quantity,
                    coalesce(tw_custom_status, CAST(NULL AS Nullable(String))) as custom_status,
                    coalesce(tw_custom_number, 0) as custom_number,
                    coalesce(tw_custom_string, CAST(NULL AS Nullable(String))) as custom_string,
                    coalesce(discount_code, 'no discount') as discount_code,
                    products_info,
                    tags,
                    customer_tags,
                    is_subscription_order,
                    is_first_order_in_subscription,
                    p.triple_id,
                    p.session_id,
                    case
                        when COALESCE(source, '') = 'tw_referrer' then 'organic_and_social'
                        when COALESCE(attribution_type, '') = 'meta_shop' then 'facebook-ads'
                        when (
                            COALESCE(source, '') = 'Direct'
                            and lower(source_name) = 'tiktok'
                        )
                        or COALESCE(attribution_type, '') = 'tiktok_shop' then 'tiktok-ads'
                        else COALESCE(source, '')
                    end as channel,
                    if(
                        COALESCE(attribution_type, '') = 'meta_shop',
                        'meta_shop',
                        if(
                            (
                                COALESCE(source, '') = 'Direct'
                                and lower(source_name) = 'tiktok'
                            )
                            or COALESCE(attribution_type, '') = 'tiktok_shop',
                            'tiktok_shop',
                            coalesce(p.campaign_id, '')
                        )
                    ) as campaign_id,
                    COALESCE(p.adset_id, '') as adset_id,
                    COALESCE(p.ad_id, '') as ad_id,
                    linear_weight,
                    if(
                        COALESCE(attribution_type, '') = 'meta_shop',
                        'meta_shop',
                        if(
                            (
                                COALESCE(source, '') = 'Direct'
                                and lower(source_name) = 'tiktok'
                            )
                            or COALESCE(attribution_type, '') = 'tiktok_shop',
                            'tiktok_shop',
                            campaign_name
                        )
                    ) as campaign_name,
                    adset_name,
                    ad_name,
                    utm_medium,
                    click_ts,
                    click_date,
                    CASE
                        WHEN coalesce(model, '') = 'totalImpact' THEN 'Total Impact'
                        WHEN coalesce(model, '') = 'linearAll' THEN 'Linear All'
                        WHEN coalesce(model, '') = 'fullFirstClick' THEN 'First Click'
                        WHEN coalesce(model, '') = 'fullLastClick' THEN 'Last Click'
                        WHEN coalesce(model, '') = 'lastPlatformClick' THEN 'Triple Attribution'
                        WHEN coalesce(model, '') = 'linear' THEN 'Linear Paid'
                        ELSE coalesce(model, '')
                    END AS model,
                    'lifetime' as attribution_window,
                    landing_page,
                    device,
                    browser,
                    country as session_country,
                    city as session_city,
                    discount_codes as discount_codes,
                    shipping_country as shipping_country,
                    financial_status as financial_status,
                    account_id
                from (
                        select * replace(
                                if(p.order_name <> '', p.order_name, o.order_name) as order_name,
                                coalesce(o.customer_first_name, p.customer_first_name) as customer_first_name,
                                coalesce(o.customer_last_name, p.customer_last_name) as customer_last_name,
                                coalesce(o.shipping_country, p.shipping_country) as shipping_country,
                                coalesce(o.order_id, p.order_id) as order_id,
                                coalesce(o.event_date, p.event_date) as event_date
                            ),
                            FROM (
                                SELECT *
                                except(
                                        tags,
                                        shipping_country_code,
                                        customer_email,
                                        total_discounts,
                                        gross_product_sales,
                                        source_name
                                    ),
                                    row_number() OVER (
                                        PARTITION BY order_id,
                                        model,
                                        source
                                        ORDER BY CASE
                                                attribution_type
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
                                FROM (
                                        SELECT *
                                        except(
                                                ad_clicks_lifetime,
                                                ad_clicks_28d,
                                                ad_clicks_14d,
                                                ad_clicks_7d,
                                                ad_clicks_1d,
                                                notes
                                            ),
                                            a.source as source,
                                            a.campaign_id as campaign_id,
                                            a.adset_id as adset_id,
                                            a.ad_id as ad_id,
                                            a.click_ts as click_ts,
                                            a.click_date as click_date,
                                            a.linear_weight as linear_weight,
                                            a.utm_medium as utm_medium,
                                            'unbounded' as attribution_window
                                        FROM (
                                                select *
                                                from (
                                                        SELECT *
                                                        FROM sonic_system.pixel_orders_data FINAL
                                                        WHERE event_date >= today() - 2
                                                        UNION ALL
                                                        SELECT *
                                                        FROM sonic_system.pixel_orders_data
                                                        WHERE event_date < today() - 2
                                                            and (
                                                                _part IN (
                                                                    SELECT name
                                                                    FROM (
                                                                            SELECT partition,
                                                                                name,
                                                                                level,
                                                                                row_number() OVER (
                                                                                    PARTITION BY partition
                                                                                    ORDER BY level DESC
                                                                                ) AS rn
                                                                            FROM system.parts
                                                                            WHERE active
                                                                                AND (`table` = 'pixel_orders_data')
                                                                                AND (database = 'sonic_system')
                                                                        )
                                                                    WHERE rn = 1
                                                                )
                                                            )
                                                    )
                                                where integration_id in ('shop-worldwide-mystore.myshopify.com')
                                                    and event_date between '2025-03-28' and '2025-03-30'
                                            ) ARRAY
                                            JOIN ad_clicks_lifetime as a
                                    )
                                WHERE integration_id in ('shop-worldwide-mystore.myshopify.com')
                                    AND model = 'lastPlatformClick'
                                    and attribution_window = 'unbounded'
                                    and event_date between '2025-03-28' and '2025-03-30'
                            ) AS p
                            LEFT JOIN (
                                (
                                    SELECT order_id,
                                        order_name,
                                        cast(coalesce(total_price, 0) as Float32) as order_price,
                                        tw_is_first_order,
                                        tw_ignore_order,
                                        if(empty(tags), array(''), tags) as tags,
                                        tw_total_items,
                                        shipping_country_code,
                                        customer_from_city,
                                        customer_first_name,
                                        customer_last_name,
                                        customer_email,
                                        shipping_province_code,
                                        customer_id,
                                        tw_shipping_price as tw_total_shipping_price,
                                        fulfillment_status,
                                        0 as tw_total_shipping_tax,
                                        CASE
                                            WHEN total_price = 0
                                            AND coalesce(source_name, '') != '1662707' THEN 0
                                            ELSE total_tax
                                        END as tw_total_tax,
                                        0 as payment_gateway_fees_and_costs,
                                        0 as total_cost_of_goods,
                                        0 as total_handling_fees,
                                        total_discounts,
                                        CASE
                                            WHEN length(discount_codes) > 0 THEN COALESCE(
                                                arrayStringConcat(
                                                    arrayMap(
                                                        x->if(x.code IS NOT NULL, x.code, ''),
                                                        discount_codes
                                                    ),
                                                    ', '
                                                ),
                                                'no discount'
                                            )
                                            ELSE 'no discount'
                                        END AS discount_code,
                                        toBool (has (tags, 'Subscription')) AS is_subscription_order,
                                        toBool (has (tags, 'Subscription First Order')) AS is_first_order_in_subscription,
                                        source_name,
                                        ABS(COALESCE(tw_total_refund, 0)) AS refund_money,
                                        gross_product_sales,
                                        arrayMap(
                                            li->CAST(
                                                tuple(
                                                    li.product_id,
                                                    LOWER(li.title),
                                                    li.sku,
                                                    li.variant_id,
                                                    li.price * coalesce(currency_rate, 1),
                                                    li.total_discount * coalesce(currency_rate, 1),
                                                    li.net_discount * coalesce(currency_rate, 1),
                                                    li.quantity,
                                                    li.gift_card,
                                                    0
                                                    /*TODO:li.cogs_per_line_item * coalesce(currency_rate, 1)*/
                                                ),
                                                'Tuple(           product_id Nullable(String),           product_name Nullable(String),           product_sku Nullable(String),           variant_id Nullable(String),           product_name_price Nullable(Decimal(18, 5)),           discount_amount_for_product Nullable(Decimal(18, 5)),           net_discount_amount_for_product Nullable(Decimal(18, 5)),           product_name_quantity_sold Nullable(Int64),            is_gift_card Nullable(Bool),           single_product_cost Nullable(Decimal(18, 5))         )'
                                            ),
                                            line_items
                                        ) AS products_info,
                                        line_items,
                                        discount_codes,
                                        financial_status,
                                        tw_total_price,
                                        tw_custom_expenses,
                                        tw_custom_gross_sales,
                                        tw_custom_net_revenue,
                                        tw_custom_gross_profit,
                                        tw_custom_total_items_quantity,
                                        tw_custom_orders_quantity,
                                        tw_custom_status,
                                        tw_custom_number,
                                        tw_custom_string,
                                        shipping_country,
                                        event_date,
                                        created_at
                                    FROM (
                                            (
                                                select *
                                                from (
                                                        SELECT *
                                                        FROM sonic_system.orders FINAL
                                                        WHERE event_date >= today() - 2
                                                        UNION ALL
                                                        SELECT *
                                                        FROM sonic_system.orders
                                                        WHERE event_date < today() - 2
                                                            and (
                                                                _part IN (
                                                                    SELECT name
                                                                    FROM (
                                                                            SELECT partition,
                                                                                name,
                                                                                level,
                                                                                row_number() OVER (
                                                                                    PARTITION BY partition
                                                                                    ORDER BY level DESC
                                                                                ) AS rn
                                                                            FROM system.parts
                                                                            WHERE active
                                                                                AND (`table` = 'orders')
                                                                                AND (database = 'sonic_system')
                                                                        )
                                                                    WHERE rn = 1
                                                                )
                                                            )
                                                    )
                                                where integration_id in ('shop-worldwide-mystore.myshopify.com')
                                                    and event_date between '2025-03-28' and '2025-03-30'
                                            )
                                        ) ot
                                        LEFT JOIN temp_orders_product_info USING (integration_id, order_id)
                                        LEFT JOIN temp_currency_conversion cur ON cur.date = ot.event_date
                                        AND ot.currency = cur.currency
                                    where integration_id in ('shop-worldwide-mystore.myshopify.com')
                                        and event_date between '2025-03-28' and '2025-03-30'
                                )
                            ) o ON p.order_id = o.order_id
                            left join (
                                SELECT order_id as subscription_order_id,
                                    any(o.integration_id) as subscription_integration_id,
                                    any(created_at) as created_at,
                                    any(s.canceled_at) as cancelled_at,
                                    any(is_first_order_in_subscription) as is_first_in_subscription,
                                    COUNT(
                                        CASE
                                            WHEN is_first_order_in_subscription THEN subscription_id
                                        END
                                    ) subscription_id_signed,
                                    COUNT(
                                        CASE
                                            WHEN s.canceled_at between '2025-03-28' and '2025-03-30' THEN subscription_id
                                        END
                                    ) subscription_id_canceled
                                FROM sonic_system.subscription_orders AS o ARRAY
                                    JOIN line_items AS li
                                    LEFT JOIN (
                                        select *
                                        from sonic_system.subscriptions
                                        WHERE integration_id in ('ef0d9302-01f6-4f4c-b06a-8b9bb554356a')
                                    ) AS s ON s.integration_id = o.integration_id
                                    AND s.subscription_id = li.subscription_ids
                                WHERE o.integration_id in ('ef0d9302-01f6-4f4c-b06a-8b9bb554356a')
                                    AND event_date between '2025-03-28' and '2025-03-30'
                                GROUP BY order_id
                            ) s on p.order_id = s.subscription_order_id
                        WHERE (
                                tw_ignore_order is null
                                or not tw_ignore_order
                            )
                            and (
                                (
                                    model != 'lastPlatformClick'
                                    or rn = 1
                                    or source in ('tw_referrer', 'influencers')
                                )
                            )
                    ) as p
                    left join (
                        SELECT ads.provider_id as provider_id,
                            ads.account_id as account_id,
                            ads.integration_id as integration_id,
                            campaigns.campaign_id as campaign_id,
                            campaign_name,
                            campaign_created_at,
                            campaign_status,
                            campaign_type,
                            null as adset_id,
                            null as adset_name,
                            null as adset_status,
                            null as ad_id,
                            null as ad_name,
                            null as ad_status,
                            null as asset_id,
                            campaign_daily_budget,
                            null as suggested_budget,
                            null as i_roas,
                            null as i_revenue,
                            null as ai_recommendation,
                            null as ai_target_spend,
                            null as ai_conversion_pacing,
                            null as ai_roas_pacing,
                            null as ai_nc_roas_pacing,
                            null as ai_benchmark_analysis,
                            null as ai_optimal_budget_mta_mmm,
                            null as ai_optimal_budget_mta,
                            null as ai_roas_forecast,
                            null as ai_creative_fatigue,
                            null as ai_model_comparison,
                            null as ai_campaign_ltv,
                            null as ai_campaign_delayed_attribution,
                            null as ai_creative_tags,
                            null as ai_creative_hooks,
                            null as adset_daily_budget,
                            campaign_lifetime_budget,
                            null as adset_lifetime_budget,
                            campaign_bid_strategy,
                            null as adset_bid_strategy,
                            null as adset_targeting,
                            null as ad_bid_amount,
                            null as adset_bid_amount,
                            null as ad_thumbnail,
                            null as ad_copy,
                            null as ad_image_url,
                            null as url_template,
                            null as ad_type,
                            null as video_url,
                            null as numberOfAssets,
                            null as destination_url,
                            null as ad_title,
                            null as creative_id,
                            null as creative_distribution_format,
                            null as creative_cta_type,
                            null as creative_format,
                            null as video_url_iframe,
                            null as video_url_source,
                            null as video_duration
                        FROM temp_campaigns campaigns
                        CROSS JOIN (
                            SELECT DISTINCT provider_id, account_id, integration_id
                            FROM sonic_system.ads_attributes final
                            WHERE campaign_id = '120218577773450050'
                            LIMIT 1
                        ) ads
                    ) as ads on ads.provider_id = p.source
                    and ads.campaign_id = p.campaign_id
                    LEFT JOIN temp_currency_conversion cur ON cur.date = p.event_date
                    AND p.shop_currency = cur.currency
            )
        WHERE model = 'Triple Attribution'
            AND attribution_window = 'lifetime'
            AND event_date BETWEEN '2025-03-28' AND '2025-03-30'
            and channel not in ('Direct', 'organic', 'triplesurvey-none');

-- ===================================
-- CLEANUP TEMPORARY TABLES
-- ===================================
DROP TEMPORARY TABLE IF EXISTS temp_currency_conversion;
DROP TEMPORARY TABLE IF EXISTS temp_orders_product_info;
DROP TEMPORARY TABLE IF EXISTS temp_campaigns;