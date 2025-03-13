{{ config(materialized='table') }}

sovereign_countries AS (
    SELECT * FROM {{ ref('stg_sovereign_countries') }}
),

combined_data AS (
    SELECT
        sc.country_name,
        cd.country,
        cd.year,
        sc.region,
        sc.sub_region,
        cd.calculated_total_emissions,
        cd.co2_emissions,
        cd.ch4_emissions,
        cd.n2o_emissions,
        cd.ghg_composition,
        ed.population,
        ed.gdp_per_capita,
        ed.income_category,
        -- Calculate per capita emissions
        cd.calculated_total_emissions / NULLIF(ed.population, 0) AS emissions_per_capita,
        -- Calculate carbon intensity of economy (emissions per unit of GDP)
        CASE 
            WHEN ed.gdp_per_capita > 0 AND ed.population > 0 
            THEN cd.calculated_total_emissions / (ed.gdp_per_capita * ed.population / 1000000)
            ELSE NULL
        END AS emissions_per_million_gdp
    FROM {{ ref('dim_sovereign_climate_emissions') }} cd
    LEFT JOIN {{ ref('dim_sovereign_socioeconomic') }} ed
        ON cd.country = ed.country AND cd.year = ed.year
    INNER JOIN sovereign_countries sc
        ON cd.country = sc.country_code
    WHERE 
        cd.calculated_total_emissions > 0
        AND ed.population > 0
),

-- Calculate global totals for each year
global_totals AS (
    SELECT
        year,
        SUM(calculated_total_emissions) AS global_emissions,
        SUM(population) AS global_population
    FROM combined_data
    GROUP BY year
),

-- Add rankings and global percentages
ranked_data AS (
    SELECT
        cd.*,
        -- Calculate percent of global emissions
        ROUND(cd.calculated_total_emissions / NULLIF(gt.global_emissions, 0) * 100, 2) AS pct_of_global_emissions,
        -- Calculate percent of global population
        ROUND(cd.population / NULLIF(gt.global_population, 0) * 100, 2) AS pct_of_global_population,
        -- Rank countries by total emissions within each year
        ROW_NUMBER() OVER (PARTITION BY cd.year ORDER BY cd.calculated_total_emissions DESC) AS emissions_rank,
        -- Rank countries by per capita emissions within each year
        ROW_NUMBER() OVER (PARTITION BY cd.year ORDER BY cd.emissions_per_capita DESC) AS per_capita_rank,
        -- Rank countries by carbon intensity (emissions per GDP) within each year
        ROW_NUMBER() OVER (PARTITION BY cd.year ORDER BY cd.emissions_per_million_gdp DESC) AS carbon_intensity_rank
    FROM combined_data cd
    JOIN global_totals gt
        ON cd.year = gt.year
)

SELECT
    country,
    country_name,
    year,
    region,
    sub_region,
    calculated_total_emissions,
    co2_emissions,
    ch4_emissions,
    n2o_emissions,
    ROUND(co2_emissions / NULLIF(calculated_total_emissions, 0) * 100, 2) AS co2_percentage,
    ROUND(ch4_emissions / NULLIF(calculated_total_emissions, 0) * 100, 2) AS ch4_percentage,
    ROUND(n2o_emissions / NULLIF(calculated_total_emissions, 0) * 100, 2) AS n2o_percentage,
    population,
    gdp_per_capita,
    income_category,
    ROUND(emissions_per_capita, 2) AS emissions_per_capita,
    ROUND(emissions_per_million_gdp, 2) AS emissions_per_million_gdp,
    pct_of_global_emissions,
    pct_of_global_population,
    emissions_rank,
    per_capita_rank,
    carbon_intensity_rank,
    -- Imbalance indicator (emissions share vs population share)
    ROUND(pct_of_global_emissions / NULLIF(pct_of_global_population, 0), 2) AS emissions_to_population_ratio,
    ghg_composition
FROM ranked_data
WHERE 
    -- Show only top emitters (by absolute or per capita)
    emissions_rank <= 50 OR per_capita_rank <= 50
ORDER BY year DESC, calculated_total_emissions DESC