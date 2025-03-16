#!/bin/bash
# Script to set up Cloud Scheduler for running dbt on a schedule

# Variables
PROJECT_ID=$1
REGION=$2
SERVICE_ACCOUNT=$3
CLOUD_BUILD_TRIGGER=$4
SCHEDULE=$5

if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$SERVICE_ACCOUNT" ] || [ -z "$CLOUD_BUILD_TRIGGER" ] || [ -z "$SCHEDULE" ]; then
    echo "Usage: $0 <project-id> <region> <service-account> <cloud-build-trigger> <schedule>"
    echo "Example schedule: '0 0 * * *' (daily at midnight)"
    exit 1
fi

# Enable Cloud Scheduler API
gcloud services enable cloudscheduler.googleapis.com --project $PROJECT_ID

# Create Cloud Scheduler job
gcloud scheduler jobs create http dbt-daily-run \
    --schedule="$SCHEDULE" \
    --uri="https://cloudbuild.googleapis.com/v1/projects/$PROJECT_ID/triggers/$CLOUD_BUILD_TRIGGER:run" \
    --http-method=POST \
    --oauth-service-account-email=$SERVICE_ACCOUNT \
    --oauth-token-scope=https://www.googleapis.com/auth/cloud-platform \
    --location=$REGION \
    --project=$PROJECT_ID \
    --description="Run dbt models daily" \
    --headers="Content-Type=application/json" \
    --message-body="{\"branchName\":\"main\"}"

echo "Cloud Scheduler job 'dbt-daily-run' created."
echo "It will run on the schedule: $SCHEDULE"