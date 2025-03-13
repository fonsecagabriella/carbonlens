{{ config(materialized='table') }}

-- Simple check of source data existence
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT country) as distinct_countries
FROM {{ source('raw_data', 'combined_climate_economic') }}