-- Test to verify we have a reasonable number of sovereign countries
-- Most lists of sovereign countries have between 190-250 countries
-- If we have significantly less or more, it might indicate a filtering issue

WITH sovereign_count AS (
    SELECT COUNT(*) as num_countries
    FROM {{ ref('stg_sovereign_countries') }}
)

SELECT *
FROM sovereign_count
WHERE num_countries < 180 OR num_countries > 250