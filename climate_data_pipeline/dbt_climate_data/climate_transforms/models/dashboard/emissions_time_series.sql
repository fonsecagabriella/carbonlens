{{ config(materialized='table') }}

WITH sovereign_countries AS (
    SELECT * FROM {{ ref('stg_sovereign_countries') }}
),

emissions_data AS (
    SELECT
        ce.country,
        sc.country_name,
        sc.region,
        sc.sub_region,
        ce.year,
        ce.calculated_total_emissions,
        ce.co2_emissions,
        ce.ch4_emissions,
        ce.n2o_emissions,
        ce.ghg_composition,
        se.population,
        se.gdp_per_capita,
        se.income_category,
        -- Calculate per capita metrics
        ce.calculated_total_emissions / NULLIF(se.population, 0) AS emissions_per_capita
    FROM {{ ref('dim_sovereign_climate_emissions') }} ce
    LEFT JOIN {{ ref('dim_sovereign_socioeconomic') }} se
        ON ce.country = se.country AND ce.year = se.year
    LEFT JOIN sovereign_countries sc
        ON ce.country = sc.alpha_3  -- Changed from sc.country_code to match your other models
    WHERE ce.calculated_total_emissions > 0
),

-- Calculate year-over-year changes
yoy_changes AS (
    SELECT
        ed.*,
        -- Previous year's values
        LAG(calculated_total_emissions) OVER (PARTITION BY country ORDER BY year) AS prev_year_emissions,
        LAG(emissions_per_capita) OVER (PARTITION BY country ORDER BY year) AS prev_year_emissions_per_capita,
        -- Year-over-year change
        calculated_total_emissions - LAG(calculated_total_emissions) OVER (PARTITION BY country ORDER BY year) AS absolute_emissions_change,
        ROUND((calculated_total_emissions - LAG(calculated_total_emissions) OVER (PARTITION BY country ORDER BY year)) / 
              NULLIF(LAG(calculated_total_emissions) OVER (PARTITION BY country ORDER BY year), 0) * 100, 2) AS yoy_emissions_change_pct,
        -- Emissions composition change
        ROUND(co2_emissions / NULLIF(calculated_total_emissions, 0) * 100, 2) - 
        ROUND(LAG(co2_emissions) OVER (PARTITION BY country ORDER BY year) / 
              NULLIF(LAG(calculated_total_emissions) OVER (PARTITION BY country ORDER BY year), 0) * 100, 2) AS co2_percentage_point_change
    FROM emissions_data ed
),

-- Calculate baseline year (e.g., 2000 or earliest available) for long-term comparison
baseline AS (
    SELECT
        country,
        MIN(year) AS baseline_year
    FROM emissions_data
    GROUP BY country
),

-- Add baseline comparison
baseline_comparison AS (
    SELECT
        yc.*,
        b.baseline_year,
        baseline_data.calculated_total_emissions AS baseline_emissions,
        baseline_data.emissions_per_capita AS baseline_emissions_per_capita,
        -- Calculate change from baseline
        ROUND((yc.calculated_total_emissions - baseline_data.calculated_total_emissions) / 
              NULLIF(baseline_data.calculated_total_emissions, 0) * 100, 2) AS pct_change_from_baseline,
        -- Calculate compound annual growth rate (CAGR)
        CASE 
            WHEN yc.year > b.baseline_year THEN
                ROUND((POWER((yc.calculated_total_emissions / NULLIF(baseline_data.calculated_total_emissions, 0)), 
                             1.0 / NULLIF((yc.year - b.baseline_year), 0)) - 1) * 100, 2)
            ELSE NULL
        END AS emissions_cagr
    FROM yoy_changes yc
    INNER JOIN baseline b
        ON yc.country = b.country
    LEFT JOIN emissions_data baseline_data
        ON b.country = baseline_data.country AND CAST(b.baseline_year AS STRING) = CAST(baseline_data.year AS STRING)  -- Convert both to same type
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
    ghg_composition,
    population,
    gdp_per_capita,
    income_category,
    ROUND(emissions_per_capita, 2) AS emissions_per_capita,
    -- Year-over-year change metrics
    absolute_emissions_change,
    yoy_emissions_change_pct,
    co2_percentage_point_change,
    -- Long-term comparisons
    baseline_year,
    baseline_emissions,
    baseline_emissions_per_capita,
    pct_change_from_baseline,
    emissions_cagr,
    -- Classify emissions trend
    CASE 
        WHEN emissions_cagr < -2 THEN 'Rapid decrease'
        WHEN emissions_cagr BETWEEN -2 AND -0.5 THEN 'Moderate decrease'
        WHEN emissions_cagr BETWEEN -0.5 AND 0.5 THEN 'Stable'
        WHEN emissions_cagr BETWEEN 0.5 AND 2 THEN 'Moderate increase'
        WHEN emissions_cagr > 2 THEN 'Rapid increase'
        ELSE 'Insufficient data'
    END AS long_term_trend
FROM baseline_comparison
ORDER BY year DESC, calculated_total_emissions DESC