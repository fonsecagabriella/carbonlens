{{ config(materialized='view') }}

-- This model filters the combined dataset to include only sovereign countries

WITH sovereign_countries AS (
    SELECT alpha_3 AS country_code
    FROM {{ ref('stg_sovereign_countries') }}
),

combined_data AS (
    SELECT * FROM {{ ref('stg_combined_climate_economic') }}
)

SELECT
    c.*
FROM combined_data c
INNER JOIN sovereign_countries s
    ON c.country = s.country_code