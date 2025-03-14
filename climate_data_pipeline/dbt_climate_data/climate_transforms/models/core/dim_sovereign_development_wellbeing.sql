{{ config(
    materialized='table',
    partition_by={
        "field": "year",
        "data_type": "date"
    },
    cluster_by=["country"]
) }}

WITH filtered_data AS (
    SELECT * FROM {{ ref('stg_sovereign_climate_economic') }}
)

SELECT
    country,
    DATE(CAST(year AS INT64), 1, 1) AS year,
    school_enrollment,
    life_expectancy,

    -- Education Access Category
    CASE
        WHEN school_enrollment < 60 THEN 'Low enrollment'
        WHEN school_enrollment >= 60 AND school_enrollment < 90 THEN 'Medium enrollment'
        WHEN school_enrollment >= 90 THEN 'High enrollment'
        ELSE 'Unknown'
    END AS education_access_category,

    -- Life Expectancy Group
    CASE
        WHEN life_expectancy < 60 THEN 'Low life Expectancy'
        WHEN life_expectancy >= 60 AND life_expectancy < 75 THEN 'Medium life expectancy'
        WHEN life_expectancy >= 75 THEN 'High life expectancy'
        ELSE 'Unknown'
    END AS life_expectancy_group

FROM filtered_data

WHERE
    country IS NOT NULL