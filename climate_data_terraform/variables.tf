variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for zonal resources"
  type        = string
  default     = "us-central1-a"
}

variable "storage_class" {
  description = "Storage class for GCS buckets"
  type        = string
  default     = "STANDARD"
}

variable "data_lake_bucket" {
  description = "Name of the data lake bucket"
  type        = string
  default     = "climate_data_lake"
}

variable "raw_data_bucket" {
  description = "Name of the raw data bucket"
  type        = string
  default     = "climate_raw_data"
}

variable "processed_data_bucket" {
  description = "Name of the processed data bucket"
  type        = string
  default     = "climate_processed_data"
}

variable "raw_dataset" {
  description = "BigQuery dataset for raw data"
  type        = string
  default     = "climate_raw"
}

variable "warehouse_dataset" {
  description = "BigQuery dataset for data warehouse"
  type        = string
  default     = "climate_warehouse"
}

variable "composer_environment_name" {
  description = "Name of the Cloud Composer environment"
  type        = string
  default     = "climate-data-composer"
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

variable "extraction_years" {
  description = "List of years to extract data for"
  type        = list(number)
  default     = [2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023]
}