#!/bin/bash
# Script to set up dbt on a GCP VM

# Variables
PROJECT_ID=$1
BQ_DATASET=$2
REGION=$3
DBT_BUCKET=$4
SERVICE_ACCOUNT_KEY_PATH=$5

if [ -z "$PROJECT_ID" ] || [ -z "$BQ_DATASET" ] || [ -z "$REGION" ] || [ -z "$DBT_BUCKET" ] || [ -z "$SERVICE_ACCOUNT_KEY_PATH" ]; then
    echo "Usage: $0 <project-id> <bq-dataset> <region> <dbt-bucket> <service-account-key-path>"
    exit 1
fi

# Install required packages
sudo apt-get update
sudo apt-get install -y python3-pip git

# Install dbt
pip3 install --user dbt-core dbt-bigquery

# Create dbt project directory
mkdir -p ~/dbt_climate_data

# Download dbt project from GCS bucket
echo "Downloading dbt project from gs://$DBT_BUCKET"
gsutil -m cp -r gs://$DBT_BUCKET/dbt_climate_data ~/dbt_climate_data

# Set up dbt profile
mkdir -p ~/.dbt
cat > ~/.dbt/profiles.yml <<EOL
climate_transforms:
  target: prod
  outputs:
    prod:
      type: bigquery
      method: service-account
      project: $PROJECT_ID
      dataset: $BQ_DATASET
      threads: 4
      timeout_seconds: 300
      location: $REGION
      priority: interactive
      retries: 3
      keyfile: $SERVICE_ACCOUNT_KEY_PATH
EOL

echo "dbt setup complete! You can now run dbt commands."
echo "To run the dbt models, use: cd ~/dbt_climate_data/climate_transforms && dbt run"