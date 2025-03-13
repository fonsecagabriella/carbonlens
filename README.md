# CarbonLens - A Climate and Social Indicators Data Pipeline

**CarbonLens provides a clear lens to explore the intersection of emissions and development. 🌎 🌱📊**

This project implements an end-to-end data pipeline that:

- Extracts emissions data from [Climate Trace API](https://climatetrace.org/)
- Extracts social/economic indicators from [World Bank API](https://data.worldbank.org/)
- Loads the datasets into a datalake -> data warehouse
- Transforms the data to be fed to a dashboard
- Visualizes the data in an interactive dashboard

<img src="./_intructions/images/carbonLens-data-pipeline.png" width="80%">

## 🌎 Project Background
This data engineering project leverages two key global datasets: [Climate Trace emissions](https://climatetrace.org/) data and [World Bank socioeconomic indicators](https://data.worldbank.org/indicator/). By combining these complementary datasets, we can explore relationships between countries' carbon footprints and their social/economic development metrics.

### ‼️ The Problem
Climate change analysis often lacks integration between emissions data and socioeconomic factors. Researchers and policymakers struggle to connect environmental impact with human development indicators, making it difficult to identify:

- Countries achieving economic growth with lower emissions
- Correlations between emissions and development metrics
- Equitable approaches to emissions reduction based on development status

### ✅ The Goal
Build an end-to-end data pipeline that:

- Extracts emissions data from Climate Trace API for all countries
- Extracts socioeconomic indicators from World Bank API (population, GDP, etc.)
- Integrates these datasets into a unified data warehouse
- Creates a dashboard with visualizations showing key relationships between emissions and development indicators

With the dashboard we should be able to answer questions like:

- How do emissions vary by economic development level?
- Which countries have the highest emissions?
- Is there a correlation between GDP and emissions?
- How has the emissions profile changed over time?

**This will enable data-driven insights into the complex interplay between development and environmental impact across different countries and regions.**

### 📊 The Dashboard

The dashboard can be found [on this link](https://lookerstudio.google.com/u/0/reporting/e02b247a-e5d1-47d0-a8c3-8b1a254029a2/page/BGa9E).
If at the time of reading this the board is not longer available (GCS is not cheap, after all 🤷🏽‍♀️), you can have an impression [by checking here](./dashboard/).


-------

##  Pipeline Flow Structure

This section explains the climate data pipeline architecture, which follows a modern data engineering approach by combining batch data extraction, cloud storage, processing with Spark/Python, transformation with dbt, and visualization in a dashboard. The pipeline integrates climate emissions data from Climate Trace with socioeconomic indicators from the World Bank to analyze relationships between economic development and greenhouse gas emissions.

### Technologies applied

- Airflow: Orchestrates the entire workflow (scheduling, monitoring, and managing tasks).
- GCS (Datalake): Stores the raw Climate Trace data.
- Spark: Processes and transforms large-scale data inside BigQuery.
- dbt: Performs further transformations and modeling for analytics (e.g., cleaning, aggregating).
- BigQuery: Acts as your data warehouse to store both raw and transformed data.
- Looker Studio: Visualizes the processed data to answer project questions.

### Flow diagram
```
                 +-----------------------------+
                 |  Climate Trace + World Bank |
                 +-----------------------------+
                               │
                               ▼
           +----------------------------------+
           |    Airflow (Data Extraction)     |
           +----------------------------------+
                               │
                               ▼
               +-------------------------+
               |    GCS (Data Lake)      |
               +-------------------------+
                               │
                               ▼
        +------------------------------------------+
        |    Airflow + Spark (Batch Processing)    |
        |        (Transforming Raw Data)           |
        +------------------------------------------+
                               │
                               ▼
          +---------------------------------+
          |    BigQuery (Data Warehouse)    |
          +---------------------------------+
                               │
                               ▼
        +----------------------------------------+
        |   Airflow + dbt (Data Transformation)  |
        +----------------------------------------+
                               │
                               ▼
      +------------------------------------------+
      |      BigQuery (Analytics Layer)          |
      +------------------------------------------+
                               │
                               ▼
          +-------------------------------+
          |   Looker Studio (Dashboard)   |
          +-------------------------------+
```

### Flow Explanation:
- [Climate Trace emissions](https://climatetrace.org/) and [World Bank socioeconomic indicators](https://data.worldbank.org/indicator/): Source datasets.

- Airflow (Extraction): Orchestrates the data extraction from both sources. 

- GCS (Datalake): Stores raw and intermediate datasets.

- Airflow + Spark (Batch Processing): Performs large-scale data transformations.

- BigQuery (Warehouse): Stores processed data from initial processing.

- Airflow + dbt (Transformation): Models and further transforms data in BigQuery.

- BigQuery (Analytics Layer): Optimized tables for reporting.

- Looker Studio: Visualizes the data through interactive dashboards.


### Project Components
1. Data Lake Extraction Scripts

**Climate Trace Emissions Extractor**
Extracts global emissions data by country:
`climate_claude.py` - Fetches emissions data from Climate Trace API

**World Bank Data Extractor**
Extracts population and social indicators by country:
`world_bank_extractor.py` - Fetches population, GDP, and other indicators


2. dbt Models
For clarity, the explanation for the dbt models used in this project [can be found here](./_intructions/dbt_explanation.md).

<img src="./_intructions/images/dbt-lineage-graph.png" width="80%">

### How to replicate this project
If you'd like to replicate this project, you can find [all the instructions here](./_intructions/_instructions.md).

### Evaluation criteria (for Zoomcamp classmates)
- Problem description
4 points: Problem is well described and it's clear what the problem the project solves

- Cloud
2 points: The project is developed in the cloud
4 points: The project is developed in the cloud and IaC tools are used

- Data ingestion (choose either batch or stream)
**Batch / Workflow orchestration**
4 points: End-to-end pipeline: multiple steps in the DAG, uploading data to data lake

- Data warehouse
2 points: Tables are created in DWH, but not optimized
4 points: Tables are partitioned and clustered in a way that makes sense for the upstream queries (with explanation)

- Transformations (dbt, spark, etc)
4 points: Tranformations are defined with dbt, Spark or similar technologies

- Dashboard
4 points: A dashboard with 2 tiles

- Reproducibility
4 points: Instructions are clear, it's easy to run the code, and the code works