#!/usr/bin/env python3
"""
Spark processor for climate data transformation.
This script is designed to run on Dataproc and can handle various job types:
- world_bank: Process World Bank data
- climate_trace: Process Climate Trace data
- combine_datasets: Combine both datasets
"""

import argparse
import os
from pyspark.sql import SparkSession
import pyspark.sql.functions as F

def create_spark_session():
    """Create a Spark session for data processing."""
    spark = SparkSession.builder \
        .appName("ClimateDataProcessing") \
        .config("spark.executor.memory", "4g") \
        .config("spark.driver.memory", "4g") \
        .getOrCreate()
    
    return spark

def process_world_bank_data(spark, input_path, output_path, year):
    """Process World Bank indicators data."""
    print(f"Processing World Bank data for year {year}")
    
    # Read the CSV file
    df = spark.read.option("header", True) \
                  .option("inferSchema", True) \
                  .csv(input_path)
    
    # Perform transformations
    # 1. Filter for year if specified
    if year:
        df = df.filter(F.col("year") == year)
    
    # 2. Select and rename relevant columns
    wb_df = df.select(
        F.col("country").alias("country_code"),
        F.col("year"),
        F.col("SP.POP.TOTL").alias("population"),
        F.col("NY.GDP.PCAP.CD").alias("gdp_per_capita"),
        F.col("SP.DYN.LE00.IN").alias("life_expectancy"),
        F.col("SE.SEC.ENRR").alias("school_enrollment"),
        F.col("SL.UEM.TOTL.ZS").alias("unemployment_rate"),
        F.col("SI.POV.GINI").alias("gini_index"),
        F.col("SI.POV.GAPS").alias("poverty_gap")
    )
    
    # 3. Add additional derived columns if needed
    wb_df = wb_df.withColumn("data_source", F.lit("world_bank"))
    
    # 4. Write the processed data as Parquet
    output_path_with_year = f"{output_path}/{year}" if year else output_path
    wb_df.write.mode("overwrite").parquet(output_path_with_year)
    
    print(f"Processed World Bank data saved to {output_path_with_year}")
    return output_path_with_year

def process_climate_trace_data(spark, input_path, output_path, year):
    """Process Climate Trace emissions data."""
    print(f"Processing Climate Trace data for year {year}")
    
    # Read the CSV file
    df = spark.read.option("header", True) \
                  .option("inferSchema", True) \
                  .csv(input_path)
    
    # Perform transformations
    # 1. Filter for year if specified
    if year:
        df = df.filter(F.col("year") == year)
    
    # 2. Select and rename relevant columns
    ct_df = df.select(
        F.col("country").alias("country_code"),
        F.col("year"),
        F.col("co2").alias("co2_emissions"),
        F.col("ch4").alias("ch4_emissions"),
        F.col("n2o").alias("n2o_emissions"),
        F.col("co2e_100yr").alias("co2e_100yr_gwp"),
        F.col("co2e_20yr").alias("co2e_20yr_gwp")
    )
    
    # 3. Add additional derived columns
    ct_df = ct_df.withColumn("data_source", F.lit("climate_trace"))
    
    # 4. Write the processed data as Parquet
    output_path_with_year = f"{output_path}/{year}" if year else output_path
    ct_df.write.mode("overwrite").parquet(output_path_with_year)
    
    print(f"Processed Climate Trace data saved to {output_path_with_year}")
    return output_path_with_year

def combine_datasets(spark, world_bank_path, climate_trace_path, output_path, year):
    """Combine World Bank and Climate Trace datasets."""
    print(f"Combining datasets for year {year}")
    
    # Read the processed World Bank data
    wb_path = f"{world_bank_path}/{year}" if year else world_bank_path
    wb_df = spark.read.parquet(wb_path)
    
    # Read the processed Climate Trace data
    ct_path = f"{climate_trace_path}/{year}" if year else climate_trace_path
    ct_df = spark.read.parquet(ct_path)
    
    # Join the datasets on country_code and year
    combined_df = wb_df.join(
        ct_df,
        (wb_df.country_code == ct_df.country_code) & (wb_df.year == ct_df.year),
        "inner"
    )
    
    # Select columns for the final dataset
    final_df = combined_df.select(
        wb_df.country_code.alias("country"),
        wb_df.year,
        # World Bank indicators
        wb_df.population,
        wb_df.gdp_per_capita,
        wb_df.life_expectancy,
        wb_df.school_enrollment,
        wb_df.unemployment_rate,
        wb_df.gini_index,
        wb_df.poverty_gap,
        # Climate Trace indicators
        ct_df.co2_emissions,
        ct_df.ch4_emissions,
        ct_df.n2o_emissions,
        ct_df.co2e_100yr_gwp,
        ct_df.co2e_20yr_gwp
    )
    
    # Write the combined data as Parquet
    output_path_with_year = f"{output_path}/{year}" if year else f"{output_path}/combined_data"
    final_df.write.mode("overwrite").parquet(output_path_with_year)
    
    print(f"Combined data saved to {output_path_with_year}")
    return output_path_with_year

def main():
    parser = argparse.ArgumentParser(description='Process climate data with Spark')
    parser.add_argument('--job_type', required=True, choices=['world_bank', 'climate_trace', 'combine_datasets'],
                        help='Type of job to run')
    parser.add_argument('--year', type=str, help='Year to process')
    parser.add_argument('--input_path', help='Input path for data')
    parser.add_argument('--output_path', help='Output path for processed data')
    parser.add_argument('--world_bank_path', help='Path to processed World Bank data (for combine job)')
    parser.add_argument('--climate_trace_path', help='Path to processed Climate Trace data (for combine job)')
    
    args = parser.parse_args()
    
    # Create Spark session
    spark = create_spark_session()
    
    # Default paths based on GCS bucket structure if not provided
    gcs_bucket = os.environ.get('GCS_BUCKET', 'climate-data-lake')
    
    if args.job_type == 'world_bank':
        input_path = args.input_path or f"gs://{gcs_bucket}/raw/world_bank/world_bank_indicators_{args.year}.csv"
        output_path = args.output_path or f"gs://{gcs_bucket}/processed/world_bank"
        process_world_bank_data(spark, input_path, output_path, args.year)
    
    elif args.job_type == 'climate_trace':
        input_path = args.input_path or f"gs://{gcs_bucket}/raw/climate_trace/global_emissions_{args.year}.csv"
        output_path = args.output_path or f"gs://{gcs_bucket}/processed/climate_trace"
        process_climate_trace_data(spark, input_path, output_path, args.year)
    
    elif args.job_type == 'combine_datasets':
        world_bank_path = args.world_bank_path or f"gs://{gcs_bucket}/processed/world_bank"
        climate_trace_path = args.climate_trace_path or f"gs://{gcs_bucket}/processed/climate_trace"
        output_path = args.output_path or f"gs://{gcs_bucket}/processed/combined"
        combine_datasets(spark, world_bank_path, climate_trace_path, output_path, args.year)
    
    spark.stop()

if __name__ == "__main__":
    main()