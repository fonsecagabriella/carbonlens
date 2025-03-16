variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "composer_environment_name" {
  description = "Name of the Cloud Composer environment"
  type        = string
}

variable "composer_node_count" {
  description = "Number of nodes in the Composer environment"
  type        = number
  default     = 3
}

variable "composer_machine_type" {
  description = "Machine type for Composer nodes"
  type        = string
  default     = "n1-standard-1"
}

variable "composer_disk_size_gb" {
  description = "Disk size for Composer nodes in GB"
  type        = number
  default     = 20
}

variable "network_name" {
  description = "Name of the VPC network to use for Composer"
  type        = string
}

variable "subnetwork_name" {
  description = "Name of the subnetwork to use for Composer"
  type        = string
}

variable "service_account_email" {
  description = "Service account email to use for Composer"
  type        = string
}

variable "env_variables" {
  description = "Environment variables for Airflow"
  type        = map(string)
  default     = {}
}

variable "local_dags_path" {
  description = "Local path to the DAGs directory"
  type        = string
  default     = "climate_data_pipeline/dags"
}

# Create the Cloud Composer environment
resource "google_composer_environment" "composer" {
  name   = var.composer_environment_name
  region = var.region
  
  config {
    node_count = var.composer_node_count

    node_config {
      zone         = var.zone
      machine_type = var.composer_machine_type
      disk_size_gb = var.composer_disk_size_gb
      
      network    = var.network_name
      subnetwork = var.subnetwork_name
      
      service_account = var.service_account_email
    }

    software_config {
      image_version = "composer-2.0.31-airflow-2.2.5"
      python_version = "3"
      
      env_variables = var.env_variables
    }
  }
}

# Script to upload DAG files to Composer
resource "null_resource" "upload_dags" {
  # Trigger this resource when any DAG file changes
  triggers = {
    dags_sha = join(",", [for f in fileset(var.local_dags_path, "*.py") : filesha256("${var.local_dags_path}/${f}")])
  }
  
  # Get the GCS bucket used by Cloud Composer
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Composer environment to be ready
      echo "Waiting for Cloud Composer environment to be ready..."
      while [ "$(gcloud composer environments describe ${google_composer_environment.composer.name} --location=${var.region} --format='value(state)')" != "RUNNING" ]; do
        sleep 10
      done
      
      # Get the GCS bucket
      COMPOSER_BUCKET=$(gcloud composer environments describe ${google_composer_environment.composer.name} \
          --location=${var.region} \
          --format="get(config.dagGcsPrefix)" | sed 's/\/dags//')
      
      echo "Uploading DAGs to $COMPOSER_BUCKET/dags"
      
      # Upload DAGs
      gsutil -m cp -r ${var.local_dags_path}/*.py $COMPOSER_BUCKET/dags/
      
      # Upload helper scripts
      if [ -d "${var.local_dags_path}/../scripts" ]; then
        echo "Uploading Python scripts to $COMPOSER_BUCKET/data/scripts"
        gsutil -m mkdir -p $COMPOSER_BUCKET/data/scripts
        gsutil -m cp -r ${var.local_dags_path}/../scripts/*.py $COMPOSER_BUCKET/data/scripts/
      fi
      
      # Upload dbt project
      if [ -d "${var.local_dags_path}/../dbt_climate_data" ]; then
        echo "Uploading dbt project to $COMPOSER_BUCKET/data/dbt_climate_data"
        gsutil -m mkdir -p $COMPOSER_BUCKET/data
        gsutil -m cp -r ${var.local_dags_path}/../dbt_climate_data $COMPOSER_BUCKET/data/
      fi
      
      echo "Upload complete!"
    EOT
  }
  
  depends_on = [
    google_composer_environment.composer
  ]
}

output "composer_environment_name" {
  value = google_composer_environment.composer.name
}

output "composer_gcs_bucket" {
  value = google_composer_environment.composer.config.0.dag_gcs_prefix
}

output "composer_airflow_uri" {
  value = google_composer_environment.composer.config.0.airflow_uri
}