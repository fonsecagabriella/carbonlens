# Tests in the Climate Data Project

Testing is a critical component of any data pipeline to ensure data quality, integrity, and reliability.
In this project, I've implemented several types of tests using dbt's testing framework to validate the climate and economic data processing.


1. [dbt tests](#dbt-tests)
    - [Schema tests](#dbt-tests)
    - [Custom SQL tests](#dbt-tests)
    - [Diagnostic models](#dbt-tests)

2. [Testing workflow integration](#testing-workflow-integration)

3. [Future test enhancements](#future-test-enhancements)

---


<div id="dbt-tests"></div>
## Types of Tests Implemented in dbt

### 1. Schema Tests

Schema tests are defined in the [`schema.yml`](./../climate_data_pipeline/dbt_climate_data/climate_transforms/models/schema.yml) file and apply to specific columns in models:

- **Not Null Tests**: Applied to critical fields such as country codes, years, and region names to ensure they don't contain NULL values which could break downstream analytics.
  
- **Unique Tests**: Applied to the `alpha_3` field in the `stg_sovereign_countries` model to ensure no duplicate country entries exist.

### 2. Custom SQL Tests

Custom SQL tests have been created to address specific validation requirements:

- [**`test_sovereign_countries.sql`**](./../climate_data_pipeline/dbt_climate_data/climate_transforms/tests/test_sovereign_countries.sql): Verifies that the sovereign countries table contains a reasonable number of countries (between 180-250). This helps catch issues with country filtering logic or data import processes.

```sql
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

```


### 3. Diagnostic Models

While not formal tests, diagnostic models have been created to help debug and validate data:

- [`country_join_check`](./../climate_data_pipeline/dbt_climate_data/climate_transforms/models/debug/country_join_check.sql): Analyzes how well country codes from the source data match with the reference sovereign country list.

- [`source_data_check`](./../climate_data_pipeline/dbt_climate_data/climate_transforms/models/debug/source_data_check.sql): Provides basic statistics about the source data to verify its completeness.


---

## Testing Workflow Integration
Tests are integrated into the Airflow DAG workflow as seen in [`dbt-transform-dag.py`](./../climate_data_pipeline/dags/dbt-transform-dag.py):

```python
dbt_test = BashOperator(
    task_id='dbt_test',
    bash_command=f'cd {DBT_PROJECT_DIR} && dbt test',
    dag=dag,
)
```

This ensures tests run automatically after dbt models are built, providing continuous data quality checks throughout the pipeline execution.

---

## Future Test Enhancements
Potential enhancements to the testing strategy could include:

- Advanced Data Quality Tests: Tests to check that emissions values fall within expected ranges based on historical data or scientific benchmarks.
- Relationship Tests: Additional tests to verify relationships between fact and dimension tables.
- Date Range Tests: Tests to check that time series data falls within expected date ranges.
- Freshness Tests: Tests to verify that data is being updated according to expected schedules.
- Integration Tests: Tests that verify the end-to-end pipeline produces expected results.

These tests contribute to maintaining high data quality throughout the pipeline, making climate analysis more reliable and trustworthy for decision-making.

