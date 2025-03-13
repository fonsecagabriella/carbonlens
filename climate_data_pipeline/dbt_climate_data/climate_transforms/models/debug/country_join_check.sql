{{ config(materialized='table') }}

WITH source_countries AS (
    SELECT DISTINCT country 
    FROM {{ source('raw_data', 'combined_climate_economic') }}
),

sovereign_countries AS (
    SELECT alpha_3 AS country_code
    FROM {{ ref('stg_sovereign_countries') }}
),

join_check AS (
    SELECT
        sc.country AS source_country,
        CASE WHEN sov.country_code IS NOT NULL 
             THEN 'Found match' 
             ELSE 'No match' 
        END AS match_status
    FROM source_countries sc
    LEFT JOIN sovereign_countries sov
        ON sc.country = sov.country_code
)

SELECT
    match_status,
    COUNT(*) as country_count,
    ARRAY_AGG(source_country LIMIT 10) as sample_countries
FROM join_check
GROUP BY match_status