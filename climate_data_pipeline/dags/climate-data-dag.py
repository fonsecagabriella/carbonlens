from datetime import datetime, timedelta
import os
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.transfers.local_to_gcs import LocalFilesystemToGCSOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateExternalTableOperator
# Import Variable to store and retrieve configuration
from airflow.models import Variable
import json

# Import the data extractor
import sys
sys.path.append(os.path.join(os.environ.get('AIRFLOW_HOME', ''), 'scripts'))
from data_extractor import run_world_bank_pipeline, run_climate_trace_pipeline


# Define default arguments
default_args = {
    'owner': 'zoomcamp',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define paths
DATA_DIR = os.path.join(os.environ.get('AIRFLOW_HOME', ''), 'data')
WORLD_BANK_DIR = os.path.join(DATA_DIR, 'world_bank')
CLIMATE_TRACE_DIR = os.path.join(DATA_DIR, 'climate_trace')

# Define GCS bucket
GCS_BUCKET = 'zoomcamp-climate-trace'

# Get the years to process
# Default to current year if the variable doesn't exist
current_year = datetime.now().year

# Get years as a JSON list or convert a single value to a list
try:
    # First try to get the variable as JSON
    extraction_years_str = Variable.get("extraction_years", default_var=str(current_year))
    
    # Handle the case where the string itself might be surrounded by quotes
    if extraction_years_str.startswith('[') and extraction_years_str.endswith(']'):
        # It looks like a JSON array string, try to parse it
        try:
            EXTRACTION_YEARS = json.loads(extraction_years_str)
        except json.JSONDecodeError:
            # If it's not valid JSON but has brackets, strip them and try again
            stripped_str = extraction_years_str.strip('[]')
            # Split by comma and strip whitespace
            EXTRACTION_YEARS = [y.strip() for y in stripped_str.split(',')]
    else:
        # It's a single value
        EXTRACTION_YEARS = [extraction_years_str]
except Exception as e:
    print(f"Error processing extraction_years variable: {e}")
    # Fallback to current year
    EXTRACTION_YEARS = [str(current_year)]

# Ensure EXTRACTION_YEARS is a list even if a single value is provided
if not isinstance(EXTRACTION_YEARS, list):
    EXTRACTION_YEARS = [EXTRACTION_YEARS]

# Convert any string years to integers, with error handling
processed_years = []
for year in EXTRACTION_YEARS:
    try:
        processed_years.append(int(year))
    except ValueError:
        # Skip invalid years but log the error
        print(f"Warning: Skipping invalid year format: {year}")

# Update the list with only valid years
EXTRACTION_YEARS = processed_years

# Ensure we have at least one year
if not EXTRACTION_YEARS:
    print(f"No valid years found. Defaulting to current year: {current_year}")
    EXTRACTION_YEARS = [current_year]

# Create the DAG
dag = DAG(
    'climate_data_pipeline_multi_year',
    default_args=default_args,
    description='Extract climate and world bank data for multiple years, load to datalake - CGS',
    schedule_interval=timedelta(days=90),  # Runs every 3 months
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['climate_data'],
)

# Function generators for dynamic task creation
def generate_extract_world_bank_task(year):
    """Generate a task to extract World Bank data for a specific year"""
    
    def extract_world_bank_data(year, **kwargs):
        return run_world_bank_pipeline(year, WORLD_BANK_DIR)
    
    return PythonOperator(
        task_id=f'extract_world_bank_data_{year}',
        python_callable=extract_world_bank_data,
        op_kwargs={'year': year},
        dag=dag,
    )

def generate_extract_climate_trace_task(year):
    """Generate a task to extract Climate Trace data for a specific year"""
    
    def extract_climate_trace_data(year, **kwargs):
        return run_climate_trace_pipeline(year, CLIMATE_TRACE_DIR)
    
    return PythonOperator(
        task_id=f'extract_climate_trace_data_{year}',
        python_callable=extract_climate_trace_data,
        op_kwargs={'year': year},
        dag=dag,
    )

def generate_upload_world_bank_task(year):
    """Generate a task to upload World Bank data to GCS for a specific year"""
    
    return LocalFilesystemToGCSOperator(
        task_id=f'upload_world_bank_to_gcs_{year}',
        src=f"{WORLD_BANK_DIR}/world_bank_indicators_{year}.csv",
        dst=f'world_bank/world_bank_indicators_{year}.csv',
        bucket=GCS_BUCKET,
        gcp_conn_id='google_cloud_default',
        dag=dag,
    )

def generate_upload_climate_trace_task(year):
    """Generate a task to upload Climate Trace data to GCS for a specific year"""
    
    return LocalFilesystemToGCSOperator(
        task_id=f'upload_climate_trace_to_gcs_{year}',
        src=f"{CLIMATE_TRACE_DIR}/global_emissions_{year}.csv",
        dst=f'climate_trace/global_emissions_{year}.csv',
        bucket=GCS_BUCKET,
        gcp_conn_id='google_cloud_default',
        dag=dag,
    )

# Create tasks for each year
for year in EXTRACTION_YEARS:
    # Create extraction tasks
    extract_wb_task = generate_extract_world_bank_task(year)
    extract_ct_task = generate_extract_climate_trace_task(year)
    
    # Create upload tasks
    upload_wb_task = generate_upload_world_bank_task(year)
    upload_ct_task = generate_upload_climate_trace_task(year)
    
    # Set dependencies for this year's tasks
    extract_wb_task >> upload_wb_task
    extract_ct_task >> upload_ct_task