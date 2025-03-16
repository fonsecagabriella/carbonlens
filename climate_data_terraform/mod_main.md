terraform {
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

# Create Cloud Composer environment
resource "google_composer_environment" "climate_composer" {
  name   = var.composer_environment_name
  region = var.region
  
  depends_on = [
    google_project_service.composer_api,
    google_compute_subnetwork.composer_subnetwork
  ]

  config {
    node_count = var.composer_node_count

    node_config {
      zone         = var.zone
      machine_type = var.composer_machine_type
      disk_size_gb = var.composer_disk_size_gb
      
      network    = google_compute_network.composer_network.id
      subnetwork = google_compute_subnetwork.composer_subnetwork.id
      
      service_account = google_service_account.composer_service_account.email
    }

    software_config {
      image_version = "composer-2.0.31-airflow-2.2.5"
      
      python_version = "3"
      
      env_variables = {
        AIRFLOW_VAR_PROJECT_ID = var.project_id
        AIRFLOW_VAR_RAW_BUCKET = google_storage_bucket.raw_data_bucket.name
        AIRFLOW_VAR_PROCESSED_BUCKET = google_storage_bucket.processed_data_bucket.name
        AIRFLOW_VAR_RAW_DATASET = var.raw_dataset
        AIRFLOW_VAR_WAREHOUSE_DATASET = var.warehouse_dataset
        AIRFLOW_VAR_EXTRACTION_YEARS = jsonencode(var.extraction_years)
      }
    }
  }
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

# Dataproc Cluster for Spark Processing (on-demand)
resource "google_dataproc_cluster" "spark_cluster" {
  name     = "climate-spark-cluster"
  region   = var.region
  depends_on = [google_project_service.dataproc_api]

  cluster_config {
    staging_bucket = google_storage_bucket.data_lake_bucket.name

    master_config {
      num_instances = 1
      machine_type  = "n1-standard-4"
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }

    worker_config {
      num_instances = 2
      machine_type  = "n1-standard-4"
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }

    software_config {
      image_version = "2.0-debian10"
      optional_components = ["JUPYTER"]
      
      override_properties = {
        "dataproc:dataproc.allow.zero.workers" = "false"
      }
    }
  }
}

# Set up dbt in the cloud
module "dbt_setup" {
  source = "./modules/dbt"
  
  project_id       = var.project_id
  region           = var.region
  dbt_bucket_name  = "dbt-climate-data-${var.project_id}"
  bigquery_dataset = google_bigquery_dataset.warehouse_dataset.dataset_id
}

# Create a VM for running dbt (alternative to using Cloud Build)
resource "google_compute_instance" "dbt_vm" {
  name         = "dbt-runner"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    email  = module.dbt_setup.dbt_service_account_email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3-pip git
    pip3 install dbt-bigquery
    
    # Create directories for dbt
    mkdir -p /opt/dbt/climate_transforms
    
    # Clone your dbt repo (if it's in GitHub/GitLab)
    # git clone https://github.com/yourusername/climate_transforms.git /opt/dbt/climate_transforms
    
    # Set up dbt profiles
    mkdir -p /root/.dbt
    cat > /root/.dbt/profiles.yml <<EOL
    climate_transforms:
      target: prod
      outputs:
        prod:
          type: bigquery
          method: oauth
          project: ${var.project_id}
          dataset: ${google_bigquery_dataset.warehouse_dataset.dataset_id}
          location: ${var.region}
          threads: 4
    EOL
  EOF

  depends_on = [
    module.dbt_setup,
    google_bigquery_dataset.warehouse_dataset
  ]
}