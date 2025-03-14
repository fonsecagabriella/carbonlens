{{ config(
    materialized='table',
    partition_by={
        "field": "year",
        "data_type": "date"
    }
) }}


WITH netherlands_data AS (
    SELECT
        cd.year,
        cd.co2_emissions,
        cd.ch4_emissions,
        cd.n2o_emissions,
        cd.calculated_total_emissions,
        cd.co2e_100yr_global_warming_potential,
        cd.co2e_20yr_global_warming_potential,
        cd.ghg_composition,
        cd.emission_intensity_category,
        cd.climate_impact_category,
        ed.population,
        ed.gdp_per_capita,
        ed.gini_index,
        dd.life_expectancy,
        dd.school_enrollment
    FROM {{ ref('dim_sovereign_climate_emissions') }} cd
    LEFT JOIN {{ ref('dim_sovereign_socioeconomic') }} ed
        ON cd.country = ed.country AND cd.year = ed.year
    LEFT JOIN {{ ref('dim_sovereign_development_wellbeing') }} dd
        ON cd.country = dd.country AND cd.year = dd.year
    WHERE 
        cd.country = 'NLD' -- ISO code for Netherlands
        AND cd.calculated_total_emissions > 0
),

-- Calculate year-over-year changes
yoy_changes AS (
    SELECT
        year,
        calculated_total_emissions,
        co2_emissions,
        ch4_emissions,
        n2o_emissions,
        population,
        gdp_per_capita,
        -- YoY changes for key metrics
        ROUND((calculated_total_emissions - LAG(calculated_total_emissions) OVER (ORDER BY year)) / 
              NULLIF(LAG(calculated_total_emissions) OVER (ORDER BY year), 0) * 100, 2) 
              AS yoy_emissions_change_pct,
        ROUND((population - LAG(population) OVER (ORDER BY year)) / 
              NULLIF(LAG(population) OVER (ORDER BY year), 0) * 100, 2) 
              AS yoy_population_change_pct,
        ROUND((gdp_per_capita - LAG(gdp_per_capita) OVER (ORDER BY year)) / 
              NULLIF(LAG(gdp_per_capita) OVER (ORDER BY year), 0) * 100, 2) 
              AS yoy_gdp_per_capita_change_pct
    FROM netherlands_data
)

SELECT
    nd.year,
    nd.population,
    nd.gdp_per_capita,
    nd.gini_index,
    nd.life_expectancy,
    nd.school_enrollment,
    nd.calculated_total_emissions,
    nd.co2_emissions,
    nd.ch4_emissions,
    nd.n2o_emissions,
    -- Per capita emissions
    ROUND(nd.calculated_total_emissions / NULLIF(nd.population, 0), 2) AS emissions_per_capita,
    -- Emissions per GDP
    ROUND(nd.calculated_total_emissions / NULLIF(nd.gdp_per_capita * nd.population / 1000000, 0), 2) AS emissions_per_million_gdp,
    -- Emissions breakdown
    ROUND(nd.co2_emissions / NULLIF(nd.calculated_total_emissions, 0) * 100, 2) AS co2_percentage,
    ROUND(nd.ch4_emissions / NULLIF(nd.calculated_total_emissions, 0) * 100, 2) AS ch4_percentage,
    ROUND(nd.n2o_emissions / NULLIF(nd.calculated_total_emissions, 0) * 100, 2) AS n2o_percentage,
    -- Year-over-year changes
    yc.yoy_emissions_change_pct,
    yc.yoy_population_change_pct,
    yc.yoy_gdp_per_capita_change_pct,
    -- Calculated metrics
    CASE 
        WHEN yc.yoy_emissions_change_pct < 0 AND yc.yoy_gdp_per_capita_change_pct > 0 
        THEN 'Decoupling'
        WHEN yc.yoy_emissions_change_pct > 0 AND yc.yoy_gdp_per_capita_change_pct > 0 
             AND yc.yoy_emissions_change_pct < yc.yoy_gdp_per_capita_change_pct 
        THEN 'Relative decoupling'
        WHEN yc.yoy_emissions_change_pct > 0 AND yc.yoy_gdp_per_capita_change_pct > 0 
             AND yc.yoy_emissions_change_pct >= yc.yoy_gdp_per_capita_change_pct 
        THEN 'No decoupling'
        ELSE 'Other'
    END AS economic_emissions_relationship,
    -- Climate characteristics
    nd.ghg_composition,
    nd.emission_intensity_category,
    nd.climate_impact_category
FROM netherlands_data nd
LEFT JOIN yoy_changes yc
    ON nd.year = yc.year
ORDER BY nd.year DESC