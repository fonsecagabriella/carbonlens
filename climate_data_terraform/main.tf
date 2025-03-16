# Set up dbt in the cloud
module "dbt_setup" {
  source = "./modules/dbt"
  
  project_id       = var.project_id
  region           = var.region
  dbt_bucket_name  = "dbt-climate-data-${var.project_id}"
  bigquery_dataset = google_bigquery_dataset.warehouse_dataset.dataset_id
}

# Enable Cloud Build API
resource "google_project_service" "cloudbuild_api" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Scheduler API
resource "google_project_service" "cloudscheduler_api" {
  project = var.project_id
  service = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# Create a Cloud Build trigger for running dbt
resource "google_cloudbuild_trigger" "dbt_trigger" {
  name        = "dbt-climate-transforms"
  description = "Trigger for running dbt transformations"
  
  trigger_template {
    branch_name = "main"
    repo_name   = "climate-data-pipeline"
  }
  
  substitutions = {
    _PROJECT_ID = var.project_id
    _BQ_DATASET = google_bigquery_dataset.warehouse_dataset.dataset_id
    _REGION     = var.region
    _DBT_BUCKET = module.dbt_setup.dbt_bucket_name
  }
  
  filename = "scripts/cloudbuild.yaml"
  
  depends_on = [
    google_project_service.cloudbuild_api,
    module.dbt_setup,
    google_bigquery_dataset.warehouse_dataset
  ]
}

# Cloud Scheduler job to regularly run dbt
resource "google_cloud_scheduler_job" "dbt_scheduler" {
  name             = "dbt-daily-run"
  description      = "Run dbt transformations daily"
  schedule         = "0 0 * * *"  # Run at midnight every day
  time_zone        = "UTC"
  region           = var.region
  
  http_target {
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${var.project_id}/triggers/${google_cloudbuild_trigger.dbt_trigger.trigger_id}:run"
    http_method = "POST"
    
    oauth_token {
      service_account_email = module.dbt_setup.dbt_service_account_email
    }
    
    body = base64encode("{\"branchName\":\"main\"}")
  }
  
  depends_on = [
    google_project_service.cloudscheduler_api,
    google_cloudbuild_trigger.dbt_trigger
  ]
}

# Upload scripts and initial data to buckets
module "file_upload" {
  source = "./modules/upload"
  
  raw_data_bucket    = google_storage_bucket.raw_data_bucket.name
  data_lake_bucket   = google_storage_bucket.data_lake_bucket.name
  local_scripts_path = "scripts"
  local_data_path    = "data"
  
  depends_on = [
    google_storage_bucket.raw_data_bucket,
    google_storage_bucket.data_lake_bucket
  ]
}terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "composer_api" {
  project = var.project_id
  service = "composer.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "bigquery_api" {
  project = var.project_id
  service = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage_api" {
  project = var.project_id
  service = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dataproc_api" {
  project = var.project_id
  service = "dataproc.googleapis.com"
  disable_on_destroy = false
}

# Create Storage Buckets
resource "google_storage_bucket" "data_lake_bucket" {
  name          = "${var.data_lake_bucket}-${var.project_id}"
  location      = var.region
  force_destroy = true
  storage_class = var.storage_class
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "raw_data_bucket" {
  name          = "${var.raw_data_bucket}-${var.project_id}"
  location      = var.region
  force_destroy = true
  storage_class = var.storage_class
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "processed_data_bucket" {
  name          = "${var.processed_data_bucket}-${var.project_id}"
  location      = var.region
  force_destroy = true
  storage_class = var.storage_class
  uniform_bucket_level_access = true
}

# Create BigQuery Datasets
resource "google_bigquery_dataset" "raw_dataset" {
  dataset_id    = var.raw_dataset
  friendly_name = "Climate Raw Data"
  description   = "Raw climate and world bank data"
  location      = var.region
  depends_on    = [google_project_service.bigquery_api]
}

resource "google_bigquery_dataset" "warehouse_dataset" {
  dataset_id    = var.warehouse_dataset
  friendly_name = "Climate Data Warehouse"
  description   = "Processed climate and economic data for analytics"
  location      = var.region
  depends_on    = [google_project_service.bigquery_api]
}

# Create a VPC for Cloud Composer
resource "google_compute_network" "composer_network" {
  name                    = "composer-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "composer_subnetwork" {
  name          = "composer-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = google_compute_network.composer_network.id
}

# Create Cloud Composer environment using the module
module "composer" {
  source = "./modules/composer"
  
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  composer_environment_name = var.composer_environment_name
  composer_node_count     = var.composer_node_count
  composer_machine_type   = var.composer_machine_type
  composer_disk_size_gb   = var.composer_disk_size_gb
  network_name            = google_compute_network.composer_network.id
  subnetwork_name         = google_compute_subnetwork.composer_subnetwork.id
  service_account_email   = google_service_account.composer_service_account.email
  local_dags_path         = "climate_data_pipeline/dags"
  
  env_variables = {
    AIRFLOW_VAR_PROJECT_ID = var.project_id
    AIRFLOW_VAR_RAW_BUCKET = google_storage_bucket.raw_data_bucket.name
    AIRFLOW_VAR_PROCESSED_BUCKET = google_storage_bucket.processed_data_bucket.name
    AIRFLOW_VAR_RAW_DATASET = var.raw_dataset
    AIRFLOW_VAR_WAREHOUSE_DATASET = var.warehouse_dataset
    AIRFLOW_VAR_EXTRACTION_YEARS = jsonencode(var.extraction_years)
  }
  
  depends_on = [
    google_project_service.composer_api,
    google_compute_subnetwork.composer_subnetwork,
    google_service_account.composer_service_account
  ]
}

# Service Account for Cloud Composer
resource "google_service_account" "composer_service_account" {
  account_id   = "composer-service-account"
  display_name = "Service Account for Cloud Composer"
}

# IAM permissions for the Composer Service Account
resource "google_project_iam_member" "composer_worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}

resource "google_project_iam_member" "bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}

resource "google_project_iam_member" "dataproc_admin" {
  project = var.project_id
  role    = "roles/dataproc.admin"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"
}

# Set up Dataproc for Spark processing
module "dataproc" {
  source = "./modules/dataproc"
  
  project_id           = var.project_id
  region               = var.region
  zone                 = var.zone
  dataproc_cluster_name = "climate-spark-cluster"
  staging_bucket       = google_storage_bucket.data_lake_bucket.name
  machine_type_master  = "n1-standard-4"
  machine_type_worker  = "n1-standard-4"
  num_master_instances = 1
  num_worker_instances = 2
  service_account_email = google_service_account.composer_service_account.email
  
  depends_on = [
    google_project_service.dataproc_api,
    google_storage_bucket.data_lake_bucket
  ]
}