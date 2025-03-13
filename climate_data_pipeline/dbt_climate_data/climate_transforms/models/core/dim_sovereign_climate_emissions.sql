{{ config(materialized='table') }}

WITH filtered_data AS (
    SELECT * FROM {{ ref('stg_sovereign_climate_economic') }}
)

SELECT
    country,
    year,
    co2_emissions,
    ch4_emissions,
    n2o_emissions,
    co2e_100yr_global_warming_potential,
    co2e_20yr_global_warming_potential,


    -- Calculate total emissions (if not already available)
    co2_emissions + ch4_emissions + n2o_emissions AS calculated_total_emissions,

    -- Calculate percentages for analysis
    CASE
        WHEN (co2_emissions + ch4_emissions + n2o_emissions) > 0
        THEN (co2_emissions / (co2_emissions + ch4_emissions + n2o_emissions)) * 100
        ELSE 0
    END AS co2_percentage,

    CASE
        WHEN (co2_emissions + ch4_emissions + n2o_emissions) > 0
        THEN (ch4_emissions / (co2_emissions + ch4_emissions + n2o_emissions)) * 100
        ELSE 0
    END AS ch4_percentage,

    CASE
        WHEN (co2_emissions + ch4_emissions + n2o_emissions) > 0
        THEN (n2o_emissions / (co2_emissions + ch4_emissions + n2o_emissions)) * 100
        ELSE 0
    END AS n2o_percentage,

    -- Co2 Emission Intensity Category
    CASE
        WHEN (co2_emissions + ch4_emissions + n2o_emissions) < 1000000 THEN 'Low Emitters'
        WHEN (co2_emissions + ch4_emissions + n2o_emissions) >= 1000000
            AND (co2_emissions + ch4_emissions + n2o_emissions) < 100000000 THEN 'Medium Emitters'
        WHEN (co2_emissions + ch4_emissions + n2o_emissions) >= 100000000 THEN 'High Emitters'
        ELSE 'Unknown'
    END AS emission_intensity_category,

    -- GHG Composition
    CASE
        WHEN co2_emissions / NULLIF((co2_emissions + ch4_emissions + n2o_emissions), 0) * 100 > 70 
            THEN 'CO₂-Dominant'
        WHEN ch4_emissions / NULLIF((co2_emissions + ch4_emissions + n2o_emissions), 0) * 100 > 50 
            THEN 'Methane-Dominant'
        ELSE 'Mixed Emissions'
    END AS ghg_composition,

    -- Short vs. Long-Term Climate Impact
    CASE
        WHEN co2e_20yr_global_warming_potential > co2e_100yr_global_warming_potential THEN 'Fast Warming Country'
        WHEN ABS(co2e_20yr_global_warming_potential - co2e_100yr_global_warming_potential) <= 0.05 * co2e_100yr_global_warming_potential THEN 'Balanced Warming'
        WHEN co2e_20yr_global_warming_potential < co2e_100yr_global_warming_potential THEN 'Slow Warming Country'
        ELSE 'Unknown'
    END AS climate_impact_category

FROM filtered_data

WHERE
    country IS NOT NULL
    AND (co2_emissions + ch4_emissions + n2o_emissions) > 0