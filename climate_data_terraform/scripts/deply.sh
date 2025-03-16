#!/bin/bash
# Master deployment script for the climate data pipeline

# Set variables
export TF_VAR_project_id=${PROJECT_ID:-$(gcloud config get-value project)}
export REGION=${REGION:-"us-central1"}
export ZONE=${ZONE:-"us-central1-a"}

echo "Starting deployment for project: $TF_VAR_project_id in $REGION"

# 1. Initialize and apply Terraform
echo "Step 1: Initializing Terraform..."
terraform init

echo "Step 2: Applying Terraform configuration..."
terraform apply -auto-approve

# Capture Terraform outputs
DATA_LAKE_BUCKET=$(terraform output -raw data_lake_bucket)
RAW_DATA_BUCKET=$(terraform output -raw raw_data_bucket)
PROCESSED_DATA_BUCKET=$(terraform output -raw processed_data_bucket)
COMPOSER_ENV=$(terraform output -raw composer_environment_name)
COMPOSER_BUCKET=$(terraform output -raw composer_gcs_bucket | sed 's|gs://\([^/]*\)/.*|\1|')
DBT_BUCKET=$(terraform output -json | jq -r '.dbt_setup_dbt_bucket_name.value')

echo "Step 3: Uploading initial data to raw data bucket..."
# Upload sample data files (you'd need to have these files ready)
if [ -d "data" ]; then
    gsutil -m cp -r data/world_bank/* gs://$RAW_DATA_BUCKET/world_bank/
    gsutil -m cp -r data/climate_trace/* gs://$RAW_DATA_BUCKET/climate_trace/
    echo "Sample data uploaded."
else
    echo "No data directory found. Skipping data upload."
fi

echo "Step 4: Uploading scripts to data lake bucket..."
# Upload Spark and processing scripts
gsutil -m cp -r scripts/spark_processor.py gs://$DATA_LAKE_BUCKET/scripts/

echo "Step 5: Updating and uploading Airflow DAGs to Cloud Composer..."
# Update DAGs for cloud environment
python scripts/update_dags_for_cloud.py \
    --dags-dir=climate_data_pipeline/dags \
    --project-id=$TF_VAR_project_id \
    --gcs-bucket=$COMPOSER_BUCKET

# Upload DAGs to Cloud Composer
bash scripts/upload_dags.sh \
    $TF_VAR_project_id \
    $COMPOSER_ENV \
    $REGION \
    climate_data_pipeline/dags

echo "Step 6: Setting up dbt in the cloud..."
# Upload dbt project to the dbt bucket
gsutil -m cp -r climate_data_pipeline/dbt_climate_data gs://$DBT_BUCKET/

# Create a Cloud Build trigger for dbt
gcloud builds triggers create manual \
    --name="dbt-climate-transforms" \
    --repo="https://github.com/yourusername/climate_data_pipeline" \
    --branch="main" \
    --build-config="scripts/cloudbuild.yaml" \
    --substitutions=_PROJECT_ID=$TF_VAR_project_id,_BQ_DATASET=climate_warehouse,_REGION=$REGION,_DBT_BUCKET=$DBT_BUCKET \
    --project=$TF_VAR_project_id

CLOUD_BUILD_TRIGGER=$(gcloud builds triggers describe dbt-climate-transforms --format="value(id)" --project=$TF_VAR_project_id)

# Set up Cloud Scheduler for dbt
bash scripts/setup_dbt_scheduler.sh \
    $TF_VAR_project_id \
    $REGION \
    "terraform-admin@$TF_VAR_project_id.iam.gserviceaccount.com" \
    $CLOUD_BUILD_TRIGGER \
    "0 0 * * *"  # Run daily at midnight

echo "Deployment complete!"
echo ""
echo "Your climate data pipeline is now set up in the cloud."
echo "You can access the Cloud Composer Airflow UI at: $(terraform output -raw composer_airflow_uri)"
echo ""
echo "Next steps:"
echo "1. Trigger the Airflow DAG to extract and process data"
echo "2. Monitor the execution in the Airflow UI"
echo "3. Once data is processed, run the dbt models to transform the data"
echo "4. Create data visualizations with your preferred BI tool"