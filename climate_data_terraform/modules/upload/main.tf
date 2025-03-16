variable "raw_data_bucket" {
  description = "The GCS bucket for raw data"
  type        = string
}

variable "data_lake_bucket" {
  description = "The GCS bucket for data lake"
  type        = string
}

variable "local_scripts_path" {
  description = "Local path to the scripts directory"
  type        = string
  default     = "scripts"
}

variable "local_data_path" {
  description = "Local path to the data directory"
  type        = string
  default     = "data"
}

# Upload the Spark processing script to the data lake bucket
resource "google_storage_bucket_object" "spark_processor" {
  name   = "scripts/spark_processor.py"
  source = "${var.local_scripts_path}/spark_processor.py"
  bucket = var.data_lake_bucket
}

# Upload the dbt profiles template to the data lake bucket
resource "google_storage_bucket_object" "dbt_profiles" {
  name   = "scripts/profiles.yml"
  source = "${var.local_scripts_path}/profiles.yml"
  bucket = var.data_lake_bucket
}

# Upload sample World Bank data if available
resource "google_storage_bucket_object" "world_bank_sample" {
  count  = fileexists("${var.local_data_path}/world_bank/world_bank_indicators_2020.csv") ? 1 : 0
  name   = "world_bank/world_bank_indicators_2020.csv"
  source = "${var.local_data_path}/world_bank/world_bank_indicators_2020.csv"
  bucket = var.raw_data_bucket
}

# Upload sample Climate Trace data if available
resource "google_storage_bucket_object" "climate_trace_sample" {
  count  = fileexists("${var.local_data_path}/climate_trace/global_emissions_2020.csv") ? 1 : 0
  name   = "climate_trace/global_emissions_2020.csv"
  source = "${var.local_data_path}/climate_trace/global_emissions_2020.csv"
  bucket = var.raw_data_bucket
}

# Upload the seed files for dbt
resource "google_storage_bucket_object" "countries_seed" {
  count  = fileexists("${var.local_data_path}/dbt_seeds/countries.csv") ? 1 : 0
  name   = "dbt_seeds/countries.csv"
  source = "${var.local_data_path}/dbt_seeds/countries.csv"
  bucket = var.data_lake_bucket
}