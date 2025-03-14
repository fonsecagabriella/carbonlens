{{ config(
    materialized='table',
    partition_by={
        "field": "year",
        "data_type": "date"
    },
    cluster_by=["country"]
) }}


WITH gdp_emissions_data AS (
    SELECT
        sc.country_name,
        cd.country,
        cd.year,
        sc.region,
        sc.sub_region,
        ed.gdp_per_capita,
        ed.population,
        -- Total GDP calculation
        ed.gdp_per_capita * ed.population AS total_gdp,
        cd.calculated_total_emissions,
        cd.co2_emissions,
        -- Emissions per capita
        cd.calculated_total_emissions / NULLIF(ed.population, 0) AS emissions_per_capita,
        -- Carbon intensity (emissions per million $ of GDP)
        CASE 
            WHEN ed.gdp_per_capita > 0 AND ed.population > 0 
            THEN cd.calculated_total_emissions / (ed.gdp_per_capita * ed.population / 1000000)
            ELSE NULL
        END AS emissions_per_million_gdp
    FROM {{ ref('dim_sovereign_climate_emissions') }} cd
    INNER JOIN {{ ref('dim_sovereign_socioeconomic') }} ed
        ON cd.country = ed.country AND cd.year = ed.year
    INNER JOIN {{ ref('stg_sovereign_countries') }} sc
        ON cd.country = sc.alpha_3
    WHERE 
        cd.calculated_total_emissions > 0 
        AND ed.gdp_per_capita > 0
        AND ed.population > 0
),

-- Calculate global and regional averages
averages AS (
    SELECT
        year,
        region,
        AVG(gdp_per_capita) AS avg_regional_gdp_per_capita,
        AVG(emissions_per_capita) AS avg_regional_emissions_per_capita,
        AVG(emissions_per_million_gdp) AS avg_regional_carbon_intensity
    FROM gdp_emissions_data
    GROUP BY year, region
),

-- Calculate decoupling metrics (comparing emissions growth to GDP growth)
decoupling AS (
    SELECT
        d1.country,
        d1.year,
        d1.gdp_per_capita,
        d1.calculated_total_emissions,
        d1.total_gdp,
        d1.emissions_per_capita,
        d1.emissions_per_million_gdp,
        -- Year-over-year changes
        ROUND((d1.total_gdp - d2.total_gdp) / NULLIF(d2.total_gdp, 0) * 100, 2) AS gdp_growth_pct,
        ROUND((d1.calculated_total_emissions - d2.calculated_total_emissions) / NULLIF(d2.calculated_total_emissions, 0) * 100, 2) AS emissions_growth_pct,
        -- 5-year changes (if data available)
        CASE 
            WHEN d5.country IS NOT NULL THEN 
                ROUND((d1.total_gdp - d5.total_gdp) / NULLIF(d5.total_gdp, 0) * 100, 2)
            ELSE NULL
        END AS gdp_growth_5yr_pct,
        CASE 
            WHEN d5.country IS NOT NULL THEN 
                ROUND((d1.calculated_total_emissions - d5.calculated_total_emissions) / NULLIF(d5.calculated_total_emissions, 0) * 100, 2)
            ELSE NULL
        END AS emissions_growth_5yr_pct
    FROM gdp_emissions_data d1
    LEFT JOIN gdp_emissions_data d2
        ON d1.country = d2.country AND d1.year = d2.year + 1
    LEFT JOIN gdp_emissions_data d5
        ON d1.country = d5.country AND d1.year = d5.year + 5
)

SELECT
    ged.country,
    ged.country_name,
    ged.year,
    ged.region,
    ged.sub_region,
    ged.gdp_per_capita,
    ged.population,
    ged.total_gdp,
    ged.calculated_total_emissions,
    ROUND(ged.emissions_per_capita, 2) AS emissions_per_capita,
    ROUND(ged.emissions_per_million_gdp, 2) AS emissions_per_million_gdp,
    -- Region averages for comparison
    ROUND(avg.avg_regional_gdp_per_capita, 2) AS avg_regional_gdp_per_capita,
    ROUND(avg.avg_regional_emissions_per_capita, 2) AS avg_regional_emissions_per_capita,
    ROUND(avg.avg_regional_carbon_intensity, 2) AS avg_regional_carbon_intensity,
    -- Comparison to regional average (percentage above/below)
    ROUND((ged.gdp_per_capita / NULLIF(avg.avg_regional_gdp_per_capita, 0) - 1) * 100, 2) AS gdp_vs_regional_avg_pct,
    ROUND((ged.emissions_per_capita / NULLIF(avg.avg_regional_emissions_per_capita, 0) - 1) * 100, 2) AS emissions_vs_regional_avg_pct,
    -- Growth metrics
    d.gdp_growth_pct,
    d.emissions_growth_pct,
    d.gdp_growth_5yr_pct,
    d.emissions_growth_5yr_pct,
    -- Decoupling status
    CASE 
        WHEN d.gdp_growth_pct > 0 AND d.emissions_growth_pct < 0 
        THEN 'Absolute decoupling'
        WHEN d.gdp_growth_pct > 0 AND d.emissions_growth_pct > 0 AND d.gdp_growth_pct > d.emissions_growth_pct 
        THEN 'Relative decoupling'
        WHEN d.gdp_growth_pct > 0 AND d.emissions_growth_pct > 0 AND d.gdp_growth_pct <= d.emissions_growth_pct 
        THEN 'No decoupling'
        WHEN d.gdp_growth_pct < 0 AND d.emissions_growth_pct < 0 AND ABS(d.gdp_growth_pct) < ABS(d.emissions_growth_pct)
        THEN 'Recession with larger emissions reduction'
        WHEN d.gdp_growth_pct < 0 AND d.emissions_growth_pct < 0 AND ABS(d.gdp_growth_pct) >= ABS(d.emissions_growth_pct)
        THEN 'Recession with smaller emissions reduction'
        ELSE 'Other'
    END AS decoupling_status,
    -- Long-term decoupling (5-year)
    CASE 
        WHEN d.gdp_growth_5yr_pct > 0 AND d.emissions_growth_5yr_pct < 0 
        THEN 'Absolute decoupling'
        WHEN d.gdp_growth_5yr_pct > 0 AND d.emissions_growth_5yr_pct > 0 AND d.gdp_growth_5yr_pct > d.emissions_growth_5yr_pct 
        THEN 'Relative decoupling'
        WHEN d.gdp_growth_5yr_pct > 0 AND d.emissions_growth_5yr_pct > 0 AND d.gdp_growth_5yr_pct <= d.emissions_growth_5yr_pct 
        THEN 'No decoupling'
        ELSE 'Other'
    END AS decoupling_status_5yr
FROM gdp_emissions_data ged
LEFT JOIN averages avg
    ON ged.year = avg.year AND ged.region = avg.region
LEFT JOIN decoupling d
    ON ged.country = d.country AND ged.year = d.year