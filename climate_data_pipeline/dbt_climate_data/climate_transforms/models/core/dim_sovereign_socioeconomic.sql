{{ config(
    materialized='table',
    partition_by={
        "field": "year",
        "data_type": "date"
    },
    cluster_by=["country", "income_category"]
) }}

WITH filtered_data AS (
    SELECT * FROM {{ ref('stg_sovereign_climate_economic') }}
)

SELECT
    country,
    DATE(CAST(year AS INT64), 1, 1) AS year,
    population,
    gdp_per_capita,
    gini_index,
    poverty_gap_2_15_usd,
    unemployment_rate,
    school_enrollment,
    life_expectancy,

    -- Economic and emissions categorization
    -- Classification based on World Bank indicators
    -- https://blogs.worldbank.org/en/opendata/world-bank-country-classifications-by-income-level-for-2024-2025
    CASE
        WHEN gdp_per_capita > 14005 THEN 'High income'
        WHEN gdp_per_capita BETWEEN 4516 AND 14005 THEN 'Upper-middle income'
        WHEN gdp_per_capita BETWEEN 1146 AND 4515 THEN 'Lower-middle income'
        WHEN gdp_per_capita < 1146 THEN 'Low income'
        ELSE 'Unknown'
    END AS income_category,

    -- Gini index classification
    -- http://documents.worldbank.org/curated/en/099549506102441825
    CASE
        WHEN gini_index > 40 THEN 'High inequality'
        WHEN gini_index < 40 THEN 'Moderate or low inequality'
        ELSE 'Unknown'
    END AS inequality_category,


    -- Poverty gap classification
    -- https://www.worldbank.org/en/topic/poverty/brief/poverty-measurement
    -- Poverty Intensity (Poverty Gap)
    CASE
        WHEN poverty_gap_2_15_usd < 5 THEN 'Low Poverty'
        WHEN poverty_gap_2_15_usd >= 5 AND poverty_gap_2_15_usd < 20 THEN 'Moderate Poverty'
        WHEN poverty_gap_2_15_usd >= 20 THEN 'Severe Poverty'
        ELSE 'Unknown'
    END AS poverty_intensity,

    -- Employment Status (Unemployment Rate)
    CASE
        WHEN unemployment_rate < 5 THEN 'Low Unemployment'
        WHEN unemployment_rate >= 5 AND unemployment_rate < 15 THEN 'Moderate Unemployment'
        WHEN unemployment_rate >= 15 THEN 'High Unemployment'
        ELSE 'Unknown'
    END AS employment_status

FROM filtered_data
WHERE
    population > 0
    AND gdp_per_capita IS NOT NULL