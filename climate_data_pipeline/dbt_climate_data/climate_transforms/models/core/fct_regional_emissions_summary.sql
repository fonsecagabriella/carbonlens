{{ config(materialized='table') }}

WITH sovereign_countries AS (
    SELECT
        alpha_3 AS country_code,
        region,
        sub_region
    FROM {{ ref('stg_sovereign_countries') }}
    WHERE region IS NOT NULL AND region != ''
),

climate_data AS (
    SELECT * FROM {{ ref('dim_sovereign_climate_emissions') }}
),

economic_data AS (
    SELECT * FROM {{ ref('dim_sovereign_socioeconomic') }}
),

-- Combine climate data with region information
joined_data AS (
    SELECT
        sc.region,
        sc.sub_region,
        cd.country,
        cd.year,
        cd.co2_emissions,
        cd.ch4_emissions,
        cd.n2o_emissions,
        cd.calculated_total_emissions,
        cd.emission_intensity_category,
        ed.population,
        ed.gdp_per_capita,
        ed.income_category
    FROM climate_data cd
    INNER JOIN sovereign_countries sc
        ON cd.country = sc.country_code
    LEFT JOIN economic_data ed
        ON cd.country = ed.country AND cd.year = ed.year
    WHERE
        cd.calculated_total_emissions > 0
        AND sc.region IS NOT NULL
)

-- Aggregate emissions data by region and year
SELECT
    region,
    year,
    COUNT(DISTINCT country) AS country_count,
    SUM(calculated_total_emissions) AS total_emissions,
    SUM(co2_emissions) AS co2_emissions,
    SUM(ch4_emissions) AS ch4_emissions,
    SUM(n2o_emissions) AS n2o_emissions,
    SUM(population) AS total_population,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    -- Calculate per capita metrics
    ROUND(SUM(calculated_total_emissions) / NULLIF(SUM(population), 0), 2) AS emissions_per_capita,
    -- Count countries by income category
    COUNT(CASE WHEN income_category = 'High income' THEN 1 END) AS high_income_count,
    COUNT(CASE WHEN income_category = 'Upper-middle income' THEN 1 END) AS upper_middle_income_count,
    COUNT(CASE WHEN income_category = 'Lower-middle income' THEN 1 END) AS lower_middle_income_count,
    COUNT(CASE WHEN income_category = 'Low income' THEN 1 END) AS low_income_count
FROM joined_data
GROUP BY region, year
ORDER BY year DESC, total_emissions DESC