{{ config(materialized='view') }}

-- This model identifies sovereign countries from the countries.csv file
-- Typically, sovereign countries have both alpha-2 and alpha-3 codes,
-- and a recognized country code.

WITH country_list AS (
    SELECT
        name AS country_name,
        `alpha-2` AS alpha_2,  -- Use backticks for column names with hyphens
        `alpha-3` AS alpha_3,  -- Use backticks for column names with hyphens
        `country-code` AS country_code,
        region,
        `sub-region` AS sub_region
    FROM {{ ref('countries') }}
),

sovereign_countries AS (
    SELECT
        country_name,
        alpha_2,
        alpha_3,
        country_code,
        region,
        sub_region
    FROM country_list
    WHERE
        -- Filter for entries that have valid country codes
        alpha_3 IS NOT NULL
        AND alpha_3 != ''
        AND country_code IS NOT NULL
        -- Exclude obvious non-sovereign territories
        AND country_name NOT LIKE '%Territory%'
        AND country_name NOT LIKE '%Island%'
        AND country_name NOT LIKE '%Dependencies%'
        AND country_name NOT LIKE '%Dependency%'
)

SELECT * FROM sovereign_countries