{{ config(materialized='table') }}

WITH economic_emissions AS (
    SELECT
        ed.country,
        ed.year,
        ed.income_category,
        ed.gdp_per_capita,
        ed.population,
        cd.calculated_total_emissions,
        cd.co2_emissions,
        cd.ch4_emissions,
        cd.n2o_emissions,
        -- Calculate per capita and per GDP metrics
        cd.calculated_total_emissions / NULLIF(ed.population, 0) AS emissions_per_capita,
        CASE 
            WHEN ed.gdp_per_capita > 0 AND ed.population > 0 
            THEN cd.calculated_total_emissions / (ed.gdp_per_capita * ed.population / 1000000)
            ELSE NULL
        END AS emissions_per_million_gdp
    FROM {{ ref('dim_sovereign_socioeconomic') }} ed
    INNER JOIN {{ ref('dim_sovereign_climate_emissions') }} cd
        ON ed.country = cd.country AND ed.year = cd.year
    WHERE 
        ed.income_category IS NOT NULL
        AND cd.calculated_total_emissions > 0
        AND ed.population > 0
)

SELECT
    year,
    income_category,
    COUNT(DISTINCT country) AS country_count,
    -- Total emissions by income category
    SUM(calculated_total_emissions) AS total_emissions,
    SUM(co2_emissions) AS co2_emissions,
    SUM(ch4_emissions) AS ch4_emissions,
    SUM(n2o_emissions) AS n2o_emissions,
    -- Average emissions metrics
    ROUND(AVG(emissions_per_capita), 2) AS avg_emissions_per_capita,
    ROUND(AVG(emissions_per_million_gdp), 2) AS avg_emissions_per_million_gdp,
    -- Totals for population and GDP
    SUM(population) AS total_population,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    -- Category share of global emissions (calculated with window function)
    ROUND(SUM(calculated_total_emissions) /
          SUM(SUM(calculated_total_emissions)) OVER (PARTITION BY year) * 100, 2) 
          AS percentage_of_global_emissions,
    -- Category share of global population (calculated with window function)
    ROUND(SUM(population) /
          SUM(SUM(population)) OVER (PARTITION BY year) * 100, 2)
          AS percentage_of_global_population,
    -- Emissions intensity ratio (% emissions / % population)
    ROUND(
        (SUM(calculated_total_emissions) / SUM(SUM(calculated_total_emissions)) OVER (PARTITION BY year)) /
        NULLIF((SUM(population) / SUM(SUM(population)) OVER (PARTITION BY year)), 0),
        2
    ) AS emissions_to_population_ratio
FROM economic_emissions
GROUP BY year, income_category
ORDER BY year DESC, total_emissions DESC