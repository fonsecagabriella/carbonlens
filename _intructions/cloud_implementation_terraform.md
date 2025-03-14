# Cloud implementation with terraform

Assuming you have installed terraform, follow the next steps:


## Authentication

1. Initialize gcloud and authenticate
`gcloud init`
`gcloud auth application-default login`

2. Create a service account for Terraform
- Note: These steps can also be done via GCS, if you prefer.


    `gcloud iam service-accounts create terraform-admin --display-name "Terraform Admin"`

    2.1 Grant necessary permissions to the service account

    ```gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:terraform-admin@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/owner"
    ```

    2.2 Create and download the service account key
    ```
    gcloud iam service-accounts keys create terraform-admin-key.json \
    --iam-account=terraform-admin@YOUR_PROJECT_ID.iam.gserviceaccount.com
    ```

## Terraform project

Create your terraform project structure

````
climate_data_terraform/
├── main.tf           # Main Terraform configuration
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── terraform.tfvars  # Variable values
├── modules/
│   ├── storage/      # For GCS buckets
│   ├── bigquery/     # For BigQuery datasets and tables
│   ├── composer/     # For Cloud Composer (managed Airflow)
│   └── networking/   # For VPC and networking
└── scripts/          # Store your Python and SQL scripts here

````
