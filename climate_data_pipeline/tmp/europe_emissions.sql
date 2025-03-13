{{ config(materialized='table') }}

sovereign_countries AS (
    SELECT * FROM {{ ref('stg_sovereign_countries') }}
    WHERE region = 'Europe'
),

climate_data AS (
    SELECT * FROM {{ ref('dim_sovereign_climate_emissions') }}
),

economic_data AS (
    SELECT * FROM {{ ref('dim_sovereign_socioeconomic') }}
),

development_data AS (
    SELECT * FROM {{ ref('dim_sovereign_development_wellbeing') }}
),

-- Combine data for European countries
europe_data AS (
    SELECT
        sc.country_name,
        cd.country,
        cd.year,
        sc.sub_region,
        cd.co2_emissions,
        cd.ch4_emissions,
        cd.n2o_emissions,
        cd.calculated_total_emissions,
        cd.ghg_composition,
        cd.emission_intensity_category,
        cd.climate_impact_category,
        ed.population,
        ed.gdp_per_capita,
        ed.income_category,
        ed.inequality_category,
        dd.life_expectancy,
        dd.education_access_category,
        dd.life_expectancy_group,
        -- Calculate emissions per capita
        ROUND(cd.calculated_total_emissions / NULLIF(ed.population, 0), 2) AS emissions_per_capita,
        -- Calculate emissions per million dollars of GDP
        ROUND(cd.calculated_total_emissions / NULLIF(ed.gdp_per_capita * ed.population / 1000000, 0), 2) AS emissions_per_million_gdp
    FROM climate_data cd
    INNER JOIN sovereign_countries sc
        ON cd.country = sc.country_code
    LEFT JOIN economic_data ed
        ON cd.country = ed.country AND cd.year = ed.year
    LEFT JOIN development_data dd
        ON cd.country = dd.country AND cd.year = dd.year
    WHERE 
        cd.calculated_total_emissions > 0
)

SELECT
    country,
    country_name,
    year,
    sub_region,
    population,
    gdp_per_capita,
    calculated_total_emissions,
    co2_emissions,
    ch4_emissions,
    n2o_emissions,
    emissions_per_capita,
    emissions_per_million_gdp,
    ghg_composition,
    emission_intensity_category,
    climate_impact_category,
    income_category,
    inequality_category,
    education_access_category,
    life_expectancy_group,
    -- YoY change calculation (with window function)
    ROUND((calculated_total_emissions - LAG(calculated_total_emissions) OVER (PARTITION BY country ORDER BY year)) / 
          NULLIF(LAG(calculated_total_emissions) OVER (PARTITION BY country ORDER BY year), 0) * 100, 2) 
          AS yoy_emissions_change_pct
FROM europe_data
ORDER BY year DESC, calculated_total_emissions DESC