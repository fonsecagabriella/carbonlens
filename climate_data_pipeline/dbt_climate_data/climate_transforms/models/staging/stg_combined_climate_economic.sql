{{ config(materialized='view') }}

SELECT
    country,
    year,
    -- World Bank indicators
    CAST(sp_pop_totl AS NUMERIC) AS population,
    CAST(ny_gdp_pcap_cd AS NUMERIC) AS gdp_per_capita,
    CAST(sp_dyn_le00_in AS NUMERIC) AS life_expectancy,
    CAST(se_sec_enrr AS NUMERIC) AS school_enrollment,
    CAST(sl_uem_totl_zs AS NUMERIC) AS unemployment_rate,
    CAST(si_pov_gini AS NUMERIC) AS gini_index,
    CAST(si_pov_gaps AS NUMERIC) AS poverty_gap_2_15_usd,
    -- Climate Trace indicators
    CAST(co2 AS NUMERIC) AS co2_emissions,
    CAST(ch4 AS NUMERIC) AS ch4_emissions,
    CAST(n2o AS NUMERIC) AS n2o_emissions,
    CAST(co2e_100yr AS NUMERIC) AS co2e_100yr_global_warming_potential,
    CAST(co2e_20yr AS NUMERIC) AS co2e_20yr_global_warming_potential
FROM {{ source('raw_data', 'combined_climate_economic') }}
WHERE country IS NOT NULL