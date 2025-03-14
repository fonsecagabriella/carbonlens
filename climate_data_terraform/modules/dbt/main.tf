variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "dbt_service_account_id" {
  description = "Service account ID for dbt"
  type        = string
  default     = "dbt-service-account"
}

variable "dbt_bucket_name" {
  description = "Name of the bucket to store dbt files"
  type        = string
}

variable "bigquery_dataset" {
  description = "BigQuery dataset for dbt to use"
  type        = string
}

# Create service account for dbt
resource "google_service_account" "dbt_service_account" {
  account_id   = var.dbt_service_account_id
  display_name = "Service Account for dbt"
  project      = var.project_id
}

# Grant BigQuery Admin role to the service account
resource "google_project_iam_member" "dbt_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dbt_service_account.email}"
}

# Grant Storage Admin role to the service account
resource "google_project_iam_member" "dbt_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dbt_service_account.email}"
}

# Create a GCS bucket for dbt
resource "google_storage_bucket" "dbt_bucket" {
  name          = var.dbt_bucket_name
  location      = var.region
  force_destroy = true
  
  versioning {
    enabled = true
  }
}

# Output the service account key (for use with dbt)
resource "google_service_account_key" "dbt_key" {
  service_account_id = google_service_account.dbt_service_account.name
}

output "dbt_service_account_email" {
  value = google_service_account.dbt_service_account.email
}

output "dbt_bucket_name" {
  value = google_storage_bucket.dbt_bucket.name
}

output "dbt_service_account_key" {
  value     = google_service_account_key.dbt_key.private_key
  sensitive = true
}