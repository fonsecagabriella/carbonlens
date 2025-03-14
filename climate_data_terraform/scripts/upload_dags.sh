#!/bin/bash

# This script uploads your DAG files to Cloud Composer
# It should be run after Terraform has created the Cloud Composer environment

# Set variables
PROJECT_ID=$1
COMPOSER_ENV=$2
REGION=$3
DAG_SRC_DIR=$4

if [ -z "$PROJECT_ID" ] || [ -z "$COMPOSER_ENV" ] || [ -z "$REGION" ] || [ -z "$DAG_SRC_DIR" ]; then
    echo "Usage: $0 <project-id> <composer-env-name> <region> <dag-source-directory>"
    exit 1
fi

# Get the GCS bucket used by Cloud Composer
COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
    --project $PROJECT_ID \
    --location $REGION \
    --format="get(config.dagGcsPrefix)" | sed 's/\/dags//')

if [ -z "$COMPOSER_BUCKET" ]; then
    echo "Failed to get the Cloud Composer bucket."
    exit 1
fi

echo "Uploading DAGs to $COMPOSER_BUCKET/dags"

# Upload DAGs
gsutil -m cp -r $DAG_SRC_DIR/*.py $COMPOSER_BUCKET/dags/

# Upload dependencies (Python files)
if [ -d "$DAG_SRC_DIR/../scripts" ]; then
    echo "Uploading Python scripts to $COMPOSER_BUCKET/data/scripts"
    gsutil -m cp -r $DAG_SRC_DIR/../scripts/*.py $COMPOSER_BUCKET/data/scripts/
fi

# Upload dbt project
if [ -d "$DAG_SRC_DIR/../dbt_climate_data" ]; then
    echo "Uploading dbt project to $COMPOSER_BUCKET/data/dbt_climate_data"
    gsutil -m cp -r $DAG_SRC_DIR/../dbt_climate_data $COMPOSER_BUCKET/data/
fi

echo "Upload complete!"