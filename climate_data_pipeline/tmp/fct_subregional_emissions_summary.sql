{{ config(materialized='table') }}

WITH sovereign_countries AS (
    SELECT
        alpha_3 AS country_code,
        region,
        sub_region
    FROM {{ ref('stg_sovereign_countries') }}
    WHERE sub_region IS NOT NULL AND sub_region != ''
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
        cd.ghg_composition,
        cd.emission_intensity_category,
        ed.population,
        ed.gdp_per_capita,
        ed.income_category,
        -- Calculate emissions per unit of GDP (carbon intensity of economy)
        CASE 
            WHEN ed.gdp_per_capita > 0 AND ed.population > 0 
            THEN cd.calculated_total_emissions / (ed.gdp_per_capita * ed.population)
            ELSE NULL
        END AS emissions_per_gdp
    FROM climate_data cd
    INNER JOIN sovereign_countries sc
        ON cd.country = sc.country_code
    LEFT JOIN economic_data ed
        ON cd.country = ed.country AND cd.year = ed.year
    WHERE 
        cd.calculated_total_emissions > 0
        AND sc.sub_region IS NOT NULL
)

-- Aggregate emissions data by sub-region and year
SELECT
    region,
    sub_region,
    year,
    COUNT(DISTINCT country) AS country_count,
    SUM(calculated_total_emissions) AS total_emissions,
    SUM(co2_emissions) AS co2_emissions,
    SUM(ch4_emissions) AS ch4_emissions,
    SUM(n2o_emissions) AS n2o_emissions,
    SUM(population) AS total_population,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    -- Percentage breakdown by GHG type
    ROUND(SUM(co2_emissions) / NULLIF(SUM(calculated_total_emissions), 0) * 100, 2) AS co2_percentage,
    ROUND(SUM(ch4_emissions) / NULLIF(SUM(calculated_total_emissions), 0) * 100, 2) AS ch4_percentage,
    ROUND(SUM(n2o_emissions) / NULLIF(SUM(calculated_total_emissions), 0) * 100, 2) AS n2o_percentage,
    -- Per capita metrics
    ROUND(SUM(calculated_total_emissions) / NULLIF(SUM(population), 0), 2) AS emissions_per_capita,
    -- Average emissions per GDP (economic carbon intensity)
    ROUND(AVG(emissions_per_gdp), 8) AS avg_emissions_per_gdp,
    -- Most common emission profile in the sub-region
    -- This uses a simple mode approximation
    (
        SELECT ghg_composition
        FROM joined_data j2
        WHERE 
            j2.sub_region = joined_data.sub_region 
            AND j2.year = joined_data.year
        GROUP BY ghg_composition
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) AS dominant_ghg_composition
FROM joined_data
GROUP BY region, sub_region, year
ORDER BY year DESC, total_emissions DESC