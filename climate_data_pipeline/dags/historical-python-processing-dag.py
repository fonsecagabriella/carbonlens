from datetime import datetime, timedelta
import os
import json
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateExternalTableOperator

# Import the Python processing functions
import sys
sys.path.append(os.path.join(os.environ.get('AIRFLOW_HOME', ''), 'scripts'))
from python_processor import process_world_bank_data, process_climate_trace_data, combine_datasets

# Set up GCP credentials in your DAG
os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = '/Users/gabi/codes/climate_trace/climate_data_pipeline/config/peppy.json'

# Define default arguments
default_args = {
    'owner': 'zoomcamp',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define GCS bucket and paths
GCS_BUCKET = "zoomcamp-climate-trace"  # Update this to your bucket name
GCS_PATH = f"gs://{GCS_BUCKET}"

# Define BigQuery dataset
BQ_DATASET = 'zoomcamp_climate_warehouse'
BQ_PROJECT = Variable.get("gcp_project")  # Make sure this variable exists in Airflow

# Get the years to process
# Default to current year if the variable doesn't exist
current_year = datetime.now().year

# Get years as a JSON list or convert a single value to a list
try:
    # First try to get the variable as JSON
    processing_years_str = Variable.get("processing_years", default_var=str(current_year))
    
    # Handle the case where the string itself might be surrounded by quotes
    if processing_years_str.startswith('[') and processing_years_str.endswith(']'):
        # It looks like a JSON array string, try to parse it
        try:
            PROCESSING_YEARS = json.loads(processing_years_str)
        except json.JSONDecodeError:
            # If it's not valid JSON but has brackets, strip them and try again
            stripped_str = processing_years_str.strip('[]')
            # Split by comma and strip whitespace
            PROCESSING_YEARS = [y.strip() for y in stripped_str.split(',')]
    else:
        # It's a single value
        PROCESSING_YEARS = [processing_years_str]
except Exception as e:
    print(f"Error processing processing_years variable: {e}")
    # Fallback to current year
    PROCESSING_YEARS = [str(current_year)]

# Ensure PROCESSING_YEARS is a list even if a single value is provided
if not isinstance(PROCESSING_YEARS, list):
    PROCESSING_YEARS = [PROCESSING_YEARS]

# Convert any string years to integers, with error handling
processed_years = []
for year in PROCESSING_YEARS:
    try:
        processed_years.append(int(year))
    except ValueError:
        # Skip invalid years but log the error
        print(f"Warning: Skipping invalid year format: {year}")

# Update the list with only valid years
PROCESSING_YEARS = processed_years

# Ensure we have at least one year
if not PROCESSING_YEARS:
    print(f"No valid years found. Defaulting to current year: {current_year}")
    PROCESSING_YEARS = [current_year]



# Create the DAG
dag = DAG(
    'climate_data_historical_processing',
    default_args=default_args,
    description='Process climate and world bank data with Python, create BigQuery tables - data warehouse',
    schedule_interval=None,  # Run manually
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['climate_data'],
)

# Function to generate process_world_bank_data tasks dynamically
def create_wb_processing_task(year):
    return PythonOperator(
        task_id=f'process_world_bank_data_{year}',
        python_callable=process_world_bank_data,
        op_kwargs={
            'input_path': f"{GCS_PATH}/world_bank/world_bank_indicators_{year}.csv",
            'output_path': f"{GCS_PATH}/processed/world_bank"
        },
        dag=dag,
    )

# Function to generate process_climate_trace_data tasks dynamically
def create_ct_processing_task(year):
    return PythonOperator(
        task_id=f'process_climate_trace_data_{year}',
        python_callable=process_climate_trace_data,
        op_kwargs={
            'input_path': f"{GCS_PATH}/climate_trace/global_emissions_{year}.csv",
            'output_path': f"{GCS_PATH}/processed/climate_trace"
        },
        dag=dag,
    )

# Function to generate BigQuery table creation tasks for World Bank data
def create_wb_bq_table_task(year):
    return BigQueryCreateExternalTableOperator(
        task_id=f'create_wb_bq_table_{year}',
        table_resource={
            'tableReference': {
                'projectId': BQ_PROJECT,
                'datasetId': BQ_DATASET,
                'tableId': f'world_bank_data_{year}',
            },
            'externalDataConfiguration': {
                'sourceFormat': 'PARQUET',
                'sourceUris': [f"{GCS_PATH}/processed/world_bank/{year}/data.parquet"],
                'autodetect': True
            },
        },
        dag=dag,
    )

# Function to generate BigQuery table creation tasks for Climate Trace data
def create_ct_bq_table_task(year):
    return BigQueryCreateExternalTableOperator(
        task_id=f'create_ct_bq_table_{year}',
        table_resource={
            'tableReference': {
                'projectId': BQ_PROJECT,
                'datasetId': BQ_DATASET,
                'tableId': f'climate_trace_data_{year}',
            },
            'externalDataConfiguration': {
                'sourceFormat': 'PARQUET',
                'sourceUris': [f"{GCS_PATH}/processed/climate_trace/{year}/data.parquet"],
                'autodetect': True
            },
        },
        dag=dag,
    )

# Generate tasks for each year
wb_process_tasks = []
ct_process_tasks = []
wb_bq_tasks = []
ct_bq_tasks = []

for year in PROCESSING_YEARS:
    # Create processing tasks
    wb_task = create_wb_processing_task(year)
    ct_task = create_ct_processing_task(year)
    
    # Create BigQuery table tasks
    wb_bq_task = create_wb_bq_table_task(year)
    ct_bq_task = create_ct_bq_table_task(year)
    
    # Set up dependencies
    wb_task >> wb_bq_task
    ct_task >> ct_bq_task
    
    # Add to lists for later combine step
    wb_process_tasks.append(wb_task)
    ct_process_tasks.append(ct_task)
    wb_bq_tasks.extend([wb_bq_task])
    ct_bq_tasks.extend([ct_bq_task])

# Task to combine all datasets
combine_data = PythonOperator(
    task_id='combine_data',
    python_callable=combine_datasets,
    op_kwargs={
        'world_bank_path': f"{GCS_PATH}/processed/world_bank",
        'climate_trace_path': f"{GCS_PATH}/processed/climate_trace",
        'output_path': f"{GCS_PATH}/processed/combined"
    },
    dag=dag,
    trigger_rule=TriggerRule.ALL_DONE,  # Run even if previous tasks fail
)

# Create BigQuery external table for combined data
create_combined_bq_table = BigQueryCreateExternalTableOperator(
    task_id='create_combined_bq_table',
    table_resource={
        'tableReference': {
            'projectId': BQ_PROJECT,
            'datasetId': BQ_DATASET,
            'tableId': 'combined_climate_economic',
        },
        'externalDataConfiguration': {
            'sourceFormat': 'PARQUET',
            'sourceUris': [f"{GCS_PATH}/processed/combined/combined_data.parquet"],
            'autodetect': True
        },
    },
    trigger_rule=TriggerRule.ALL_DONE,  # Run even if previous tasks fail
    dag=dag,
)

# Set dependencies
for wb_task, ct_task in zip(wb_process_tasks, ct_process_tasks):
    [wb_task, ct_task] >> combine_data

# Connect combine task to final table creation
combine_data >> create_combined_bq_table