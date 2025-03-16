# Climate Data Pipeline - Cloud Implementation

This project implements a complete data pipeline for analyzing climate and economic data in the cloud. The pipeline extracts data from the World Bank and Climate Trace, processes it with Spark, loads it into a data warehouse, and transforms it using dbt.

## Prerequisites

- Google Cloud Platform account with billing enabled
- Local installation of:
  - [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
  - [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
  - [Python 3.7+](https://www.python.org/downloads/)

## Project Structure

```
climate-data-terraform/
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars        # Variable values
├── deploy.sh               # Deployment script
├── modules/                # Terraform modules
│   ├── composer/           # Cloud Composer (Airflow) setup
│   ├── dataproc/           # Dataproc (Spark) setup
│   ├── dbt/                # dbt setup
│   └── upload/             # File uploading
├── scripts/                # Helper scripts
│   ├── spark_processor.py  # Unified Spark processing script
│   ├── profiles.yml        # dbt profiles template
│   ├── cloudbuild.yaml     # Cloud Build configuration
│   ├── upload_dags.sh      # Script to upload DAGs to Composer
│   └── setup_dbt_vm.sh     # Script to set up dbt
└── data/                   # Sample data directory
    ├── world_bank/         # World Bank data samples
    ├── climate_trace/      # Climate Trace data samples
    └── dbt_seeds/          # Seed files for dbt
```

## Step-by-Step Setup Instructions

### 1. Set Up Your Google Cloud Project

1. Create a new GCP project or use an existing one:
   ```bash
   gcloud projects create YOUR_PROJECT_ID --name="Climate Data Pipeline"
   gcloud config set project YOUR_PROJECT_ID
   ```

2. Enable billing for your project through the GCP Console

3. Create a service account for Terraform:
   ```bash
   # Create service account
   gcloud iam service-accounts create terraform-admin --display-name "Terraform Admin"
   
   # Grant necessary permissions
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:terraform-admin@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/owner"
   
   # Create and download key
   gcloud iam service-accounts keys create terraform-admin-key.json \
     --iam-account=terraform-admin@YOUR_PROJECT_ID.iam.gserviceaccount.com
   
   # Set environment variable for authentication
   export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/terraform-admin-key.json
   ```

### 2. Configure Your Deployment

1. Edit `terraform.tfvars` to set your project-specific values:
   ```
   project_id = "YOUR_PROJECT_ID"
   region = "us-central1"
   zone = "us-central1-a"
   # Other variables as needed
   ```

2. Prepare your data files (optional):
   - Place World Bank data samples in `data/world_bank/`
   - Place Climate Trace data samples in `data/climate_trace/`
   - Place seed files in `data/dbt_seeds/`

### 3. Deploy the Infrastructure

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Validate your configuration:
   ```bash
   terraform validate
   ```

3. Preview the changes:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```
   
   Alternatively, use the deployment script for a complete setup:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

5. The deployment will output several important values:
   - Cloud Composer Airflow URI
   - Bucket names
   - BigQuery dataset names

### 4. Access Your Pipeline Components

1. Access the Airflow UI:
   ```bash
   echo "Airflow UI: $(terraform output -raw composer_airflow_uri)"
   ```

2. Navigate to the BigQuery console to see your datasets:
   ```bash
   gcloud alpha bq datasets list --project=$(terraform output -raw project_id)
   ```

3. View your GCS buckets:
   ```bash
   gsutil ls -p $(terraform output -raw project_id)
   ```

### 5. Run Your Pipeline

1. In the Airflow UI, trigger the `climate_data_pipeline_multi_year` DAG to extract data
2. Monitor the extraction and processing in the Airflow UI
3. Once processing is complete, verify the data in BigQuery
4. Trigger the dbt transformation:
   ```bash
   gcloud builds triggers run dbt-climate-transforms --branch=main
   ```

5. Verify the transformed data in BigQuery

### 6. Clean Up Resources (Optional)

To avoid ongoing charges, you can remove all the resources:

```bash
terraform destroy
```

## Troubleshooting

1. **Cloud Composer Deployment Issues**:
   - Cloud Composer can take 20-30 minutes to provision
   - Check the GCP Console for error messages

2. **DAG not showing in Airflow**:
   - Verify the DAGs were uploaded: 
     ```bash
     gsutil ls gs://$(terraform output -raw composer_gcs_bucket | cut -d'/' -f3)/dags/
     ```
   - Check the Airflow logs for import errors

3. **Spark Processing Errors**:
   - Check the Dataproc job logs in the GCP Console
   - Verify the paths in your Spark scripts

4. **dbt Transformation Issues**:
   - Check the Cloud Build logs for errors
   - Verify access permissions to BigQuery datasets

## Performance Tuning

For improved performance:

1. **Adjust Dataproc Configuration**:
   - Modify `dataproc_cluster_name`, `machine_type_worker`, and `num_worker_instances` in `terraform.tfvars`

2. **Optimize BigQuery Tables**:
   - Adjust partitioning and clustering in dbt models to match your query patterns

3. **Improve Cloud Composer**:
   - Increase `composer_node_count` for higher throughput

## Next Steps

1. Create visualizations with Looker Studio or other BI tools
2. Implement monitoring and alerting
3. Add more data sources
4. Implement automated testing
5. Set up CI/CD for your pipeline