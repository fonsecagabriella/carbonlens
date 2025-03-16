#!/bin/bash
# Script to create the required directory structure for the project

# Create main directories
mkdir -p modules/composer
mkdir -p modules/dataproc
mkdir -p modules/dbt
mkdir -p modules/upload
mkdir -p scripts
mkdir -p data/world_bank
mkdir -p data/climate_trace
mkdir -p data/dbt_seeds

# Copy your existing DAGs and scripts
if [ -d "climate_data_pipeline" ]; then
  echo "Copying existing DAGs and scripts..."
  cp -r climate_data_pipeline/dags .
  mkdir -p climate_data_pipeline/scripts
fi

# Create placeholder files for sample data
touch data/world_bank/README.md
cat > data/world_bank/README.md <<EOL
# World Bank Data
Place your World Bank indicator CSV files here, e.g.:
- world_bank_indicators_2016.csv
- world_bank_indicators_2017.csv
- etc.
EOL

touch data/climate_trace/README.md
cat > data/climate_trace/README.md <<EOL
# Climate Trace Data
Place your Climate Trace emissions CSV files here, e.g.:
- global_emissions_2016.csv
- global_emissions_2017.csv
- etc.
EOL

touch data/dbt_seeds/README.md
cat > data/dbt_seeds/README.md <<EOL
# dbt Seed Files
Place your dbt seed files here, such as:
- countries.csv
- other reference data
EOL

# Copy countries.csv from your existing project if available
if [ -f "climate_data_pipeline/dbt_climate_data/climate_transforms/seeds/countries.csv" ]; then
  echo "Copying countries.csv seed file..."
  cp climate_data_pipeline/dbt_climate_data/climate_transforms/seeds/countries.csv data/dbt_seeds/
fi

echo "Directory structure created successfully!"
echo "Next steps:"
echo "1. Add your Terraform files (main.tf, variables.tf, etc.)"
echo "2. Configure terraform.tfvars with your GCP project details"
echo "3. Run 'terraform init' to initialize your project"