SET join_algorithm = 'hash';
  SET query_plan_join_swap_table = false;

      WITH base as (
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
                WITH currency_conversion AS (
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
                    WHERE date between '2025-03-28' and '2025-03-30'
                )
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
                                    WITH currency_conversion AS (
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
                                        WHERE date between '2025-03-28' and '2025-03-30'
                                    ),
                                    orders_product_info_cte AS (
                                        select cast(null as Nullable(String)) as integration_id,
                                            cast(null as Nullable(String)) as provider_id,
                                            cast(null as Nullable(String)) as order_id,
                                            cast(null as Nullable(String)) as products_info
                                    )
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
                                        LEFT JOIN orders_product_info_cte USING (integration_id, order_id)
                                        LEFT JOIN currency_conversion cur ON cur.date = ot.event_date
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
                        with campaigns as (
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
                                and campaign_id = '120218577773450050'
                        ),
                        adsets as (
                            select distinct IF(
                                    adset_id = '0'
                                    OR adset_id IS NULL,
                                    '',
                                    adset_id
                                ) AS adset_id,
                                adset_name,
                                adset_status,
                                adset_status,
                                campaign_id,
                                adset_daily_budget,
                                adset_lifetime_budget,
                                adset_bid_strategy,
                                adset_bid_amount,
                                null as adset_targeting_arr,
                                ai_recommendation,
                                ai_target_spend,
                                ai_conversion_pacing,
                                ai_roas_pacing,
                                ai_nc_roas_pacing,
                                ai_benchmark_analysis,
                                ai_optimal_budget_mta_mmm,
                                ai_optimal_budget_mta,
                                ai_roas_forecast,
                                ai_creative_fatigue,
                                ai_model_comparison,
                                ai_campaign_ltv,
                                ai_campaign_delayed_attribution,
                                ai_creative_tags,
                                ai_creative_hooks
                            from (
                                    select *
                                    from sonic_system.adsets_attributes final
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
                                        and campaign_id = '120218577773450050'
                                ) adsets
                                left join (
                                    select id as adset_id,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_recommendation'
                                        ) AS ai_recommendation,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_target_spend'
                                        ) AS ai_target_spend,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_conversion_pacing'
                                        ) AS ai_conversion_pacing,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_roas_pacing'
                                        ) AS ai_roas_pacing,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_nc_roas_pacing'
                                        ) AS ai_nc_roas_pacing,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_benchmark_analysis'
                                        ) AS ai_benchmark_analysis,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_optimal_budget_mta_mmm'
                                        ) AS ai_optimal_budget_mta_mmm,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_optimal_budget_mta'
                                        ) AS ai_optimal_budget_mta,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_roas_forecast'
                                        ) AS ai_roas_forecast,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_creative_fatigue'
                                        ) AS ai_creative_fatigue,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_model_comparison'
                                        ) AS ai_model_comparison,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_campaign_ltv'
                                        ) AS ai_campaign_ltv,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_campaign_delayed_attribution'
                                        ) AS ai_campaign_delayed_attribution,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_creative_tags'
                                        ) AS ai_creative_tags,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_creative_hooks'
                                        ) AS ai_creative_hooks
                                    from (
                                            select *,
                                                row_number() over (
                                                    partition by id,
                                                    metric
                                                    order by created_at desc
                                                ) as rn
                                            from sonic_system.pixel_ai_metrics
                                            where entity = 'adset'
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
                                        )
                                    where rn = 1
                                    group by id
                                ) ai using (adset_id)
                        ),
                        ads as (
                            select distinct IF(
                                    ad_id = '0'
                                    OR ad_id IS NULL,
                                    '',
                                    ad_id
                                ) AS ad_id,
                                ad_name,
                                case
                                    when ad_status = '1' then 'ACTIVE'
                                    when ad_status = '2' then 'PAUSED'
                                    when ad_status = '3' then 'PAUSED'
                                    else ad_status
                                end as ad_status,
                                ad_type,
                                ad_title,
                                campaign_id,
                                IF(
                                    adset_id = '0'
                                    OR adset_id IS NULL,
                                    '',
                                    adset_id
                                ) AS adset_id,
                                provider_id,
                                account_id,
                                integration_id,
                                ad_bid_amount,
                                if(ad_thumbnail = '', null, ad_thumbnail) as ad_thumbnail,
                                if(provider_id = 'google-ads', null, url_template) url_template,
                                destination_url,
                                ai_recommendation,
                                ai_target_spend,
                                ai_conversion_pacing,
                                ai_roas_pacing,
                                ai_nc_roas_pacing,
                                ai_benchmark_analysis,
                                ai_optimal_budget_mta_mmm,
                                ai_optimal_budget_mta,
                                ai_roas_forecast,
                                ai_creative_fatigue,
                                ai_model_comparison,
                                ai_campaign_ltv,
                                ai_campaign_delayed_attribution,
                                ai_creative_tags,
                                ai_creative_hooks
                            from (
                                    select *
                                    from sonic_system.ads_attributes final
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
                                        and campaign_id = '120218577773450050'
                                ) ads
                                left join (
                                    select id as ad_id,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_recommendation'
                                        ) AS ai_recommendation,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_target_spend'
                                        ) AS ai_target_spend,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_conversion_pacing'
                                        ) AS ai_conversion_pacing,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_roas_pacing'
                                        ) AS ai_roas_pacing,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_nc_roas_pacing'
                                        ) AS ai_nc_roas_pacing,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_benchmark_analysis'
                                        ) AS ai_benchmark_analysis,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_optimal_budget_mta_mmm'
                                        ) AS ai_optimal_budget_mta_mmm,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_optimal_budget_mta'
                                        ) AS ai_optimal_budget_mta,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_roas_forecast'
                                        ) AS ai_roas_forecast,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_creative_fatigue'
                                        ) AS ai_creative_fatigue,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_model_comparison'
                                        ) AS ai_model_comparison,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_campaign_ltv'
                                        ) AS ai_campaign_ltv,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_campaign_delayed_attribution'
                                        ) AS ai_campaign_delayed_attribution,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_creative_tags'
                                        ) AS ai_creative_tags,
                                        anyIf (
                                            cast(
                                                tuple(value, reason, created_at),
                                                'Tuple(value String, reason String, created_at String)'
                                            ),
                                            metric = 'ai_creative_hooks'
                                        ) AS ai_creative_hooks
                                    from (
                                            select *,
                                                row_number() over (
                                                    partition by id,
                                                    metric
                                                    order by created_at desc
                                                ) as rn
                                            from sonic_system.pixel_ai_metrics
                                            where entity = 'ad'
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
                                        )
                                    where rn = 1
                                    group by id
                                ) ai using (ad_id)
                        ),
                        creatives as (
                            select null as provider_id,
                                null as integration_ids,
                                null as campaign_id,
                                null as adset_id,
                                null as ad_id,
                                null as numberOfAssets,
                                null as asset_id,
                                null as ad_copy,
                                null as ad_image_url,
                                null as ad_type,
                                null as video_url,
                                null as creative_id,
                                null as creative_distribution_format,
                                null as creative_cta_type,
                                null as creative_format,
                                null as video_url_iframe,
                                null as video_url_source,
                                null as video_duration
                        )
                        SELECT ads.provider_id as provider_id,
                            ads.account_id as account_id,
                            ads.integration_id as integration_id,
                            campaigns.campaign_id as campaign_id,
                            campaign_name,
                            campaign_created_at,
                            campaign_status,
                            campaign_type,
                            adsets.adset_id as adset_id,
                            adset_name,
                            adset_status,
                            ads.ad_id as ad_id,
                            ad_name,
                            ad_status,
                            null as asset_id,
                            campaign_daily_budget,
                            null as suggested_budget,
                            null as i_roas,
                            null as i_revenue,
                            ads.ai_recommendation as ai_recommendation,
                            ads.ai_target_spend as ai_target_spend,
                            ads.ai_conversion_pacing as ai_conversion_pacing,
                            ads.ai_roas_pacing as ai_roas_pacing,
                            ads.ai_nc_roas_pacing as ai_nc_roas_pacing,
                            ads.ai_benchmark_analysis as ai_benchmark_analysis,
                            ads.ai_optimal_budget_mta_mmm as ai_optimal_budget_mta_mmm,
                            ads.ai_optimal_budget_mta as ai_optimal_budget_mta,
                            ads.ai_roas_forecast as ai_roas_forecast,
                            ads.ai_creative_fatigue as ai_creative_fatigue,
                            ads.ai_model_comparison as ai_model_comparison,
                            ads.ai_campaign_ltv as ai_campaign_ltv,
                            ads.ai_campaign_delayed_attribution as ai_campaign_delayed_attribution,
                            ads.ai_creative_tags as ai_creative_tags,
                            ads.ai_creative_hooks as ai_creative_hooks,
                            adset_daily_budget,
                            campaign_lifetime_budget,
                            adset_lifetime_budget,
                            campaign_bid_strategy,
                            adset_bid_strategy,
                            adset_targeting_arr as adset_targeting,
                            ad_bid_amount,
                            adset_bid_amount,
                            ad_thumbnail,
                            ad_copy,
                            if(
                                startsWith(ad_image_url, 'https://storage'),
                                ad_image_url,
                                if(
                                    startsWith(ad_thumbnail, 'https://storage'),
                                    ad_thumbnail,
                                    coalesce(ad_image_url, ad_thumbnail)
                                )
                            ) as ad_image_url,
                            url_template,
                            ads.ad_type as ad_type,
                            video_url,
                            numberOfAssets,
                            destination_url,
                            ad_title,
                            creative_id,
                            creative_distribution_format,
                            creative_cta_type,
                            creative_format,
                            video_url_iframe,
                            video_url_source,
                            video_duration
                        FROM ads
                            join adsets on ads.adset_id = adsets.adset_id
                            and ads.campaign_id = adsets.campaign_id
                            join campaigns on ads.campaign_id = campaigns.campaign_id
                            left join creatives on creatives.ad_id = ads.ad_id
                    ) as ads on ads.provider_id = p.source
                    and ads.campaign_id = p.campaign_id
                    and ads.adset_id = p.adset_id
                    and ads.ad_id = if(
                        COALESCE(p.source, '') = 'google-ads'
                        and COALESCE(p.ad_id, '') = COALESCE(p.campaign_id, ''),
                        '',
                        coalesce(p.ad_id, '')
                    )
                    LEFT JOIN currency_conversion cur ON cur.date = p.event_date
                    AND p.shop_currency = cur.currency
            )
        WHERE model = 'Triple Attribution'
            AND attribution_window = 'lifetime'
            AND event_date BETWEEN '2025-03-28' AND '2025-03-30'
            and channel not in ('Direct', 'organic', 'triplesurvey-none')
    ),
    orders_with_channels AS (
        SELECT order_id,
            groupUniqArray (source) AS overlaps,
            groupUniqArray (adset_id) AS adset_ids,
            arrayJoin (adset_ids) entity_id
        FROM base
        GROUP BY order_id
    ),
    channel_totals AS (
        SELECT entity_id,
            count(order_id) total_orders,
            count(if(length(overlaps) > 1, order_id, null)) AS total_orders_with_overlap
        FROM orders_with_channels
        GROUP BY entity_id
    ),
    overlaps_count AS (
        SELECT a.adset_id AS entity_id,
            b.source AS overlap_channel,
            count(DISTINCT a.order_id) AS overlap_orders
        FROM base a
            JOIN base b ON a.order_id = b.order_id
        WHERE a.source != b.source
        GROUP BY 1,
            2
    ),
    campaigns_from_channel AS (
        SELECT DISTINCT adset_id
        FROM base
        WHERE source = 'facebook-ads'
            AND campaign_id = '120218577773450050'
    )
    SELECT ct.entity_id AS entity_id,
        ct.total_orders,
        ct.total_orders_with_overlap,
        groupArray ((oc.overlap_channel, oc.overlap_orders)) AS overlapping_channels
    FROM channel_totals ct
        LEFT JOIN overlaps_count oc ON ct.entity_id = oc.entity_id
        JOIN campaigns_from_channel fc ON ct.entity_id = fc.adset_id
    where entity_id not like 'ref__%'
    GROUP BY ct.entity_id,
        ct.total_orders,
        ct.total_orders_with_overlap SETTINGS group_by_use_nulls = 1,
        join_use_nulls = 1,
        max_memory_usage = 32000000000