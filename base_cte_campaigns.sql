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