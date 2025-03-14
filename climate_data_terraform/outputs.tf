output "project_id" {
  value       = var.project_id
  description = "The GCP project ID"
}

output "data_lake_bucket" {
  value       = google_storage_bucket.data_lake_bucket.name
  description = "The data lake bucket name"
}

output "raw_data_bucket" {
  value       = google_storage_bucket.raw_data_bucket.name
  description = "The raw data bucket name"
}

output "processed_data_bucket" {
  value       = google_storage_bucket.processed_data_bucket.name
  description = "The processed data bucket name"
}

output "raw_bigquery_dataset" {
  value       = google_bigquery_dataset.raw_dataset.dataset_id
  description = "The BigQuery dataset for raw data"
}

output "warehouse_bigquery_dataset" {
  value       = google_bigquery_dataset.warehouse_dataset.dataset_id
  description = "The BigQuery dataset for warehouse data"
}

output "composer_environment_name" {
  value       = google_composer_environment.climate_composer.name
  description = "The Cloud Composer environment name"
}

output "composer_gcs_bucket" {
  value       = google_composer_environment.climate_composer.config.0.dag_gcs_prefix
  description = "The Cloud Composer GCS bucket for DAGs and other resources"
}

output "composer_airflow_uri" {
  value       = google_composer_environment.climate_composer.config.0.airflow_uri
  description = "The URI of the Apache Airflow Web UI hosted within the Cloud Composer environment"
}

output "dataproc_cluster_name" {
  value       = google_dataproc_cluster.spark_cluster.name
  description = "The Dataproc cluster name"
}