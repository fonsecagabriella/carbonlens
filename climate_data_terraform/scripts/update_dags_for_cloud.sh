#!/usr/bin/env python3

"""
This script updates the DAG files to work in a Cloud Composer environment.
It replaces local file paths with GCS paths and updates connections.
"""

import os
import re
import glob
import argparse

def update_file(file_path, project_id, gcs_bucket):
    """Update a DAG file with cloud-specific settings."""
    
    with open(file_path, 'r') as file:
        content = file.read()
    
    # Replace local file paths with GCS paths
    content = re.sub(
        r'os\.path\.join\(os\.environ\.get\([\'"]AIRFLOW_HOME[\'"](, [\'"]\w+[\'"]\))+',
        f'"gs://{gcs_bucket}/data"',
        content
    )
    
    # Update bucket names
    content = re.sub(
        r'GCS_BUCKET = [\'"][\w-]+[\'"]',
        f'GCS_BUCKET = "{gcs_bucket.split("/")[2]}"',
        content
    )
    
    # Update project references
    content = re.sub(
        r'[\'"]projectId[\'"]: [\'"]{{ var\.value\.gcp_project }}[\'"]',
        f'"projectId": "{project_id}"',
        content
    )
    
    # Update BigQuery dataset references if needed
    content = re.sub(
        r'BQ_DATASET = [\'"][\w_]+[\'"]',
        f'BQ_DATASET = "climate_warehouse"',
        content
    )
    
    # Update imports for Cloud Composer
    content = content.replace(
        'import sys\nsys.path.append(',
        '# Import using Cloud Composer data folder\nimport sys\nsys.path.append("gs://' + gcs_bucket + '/data'
    )
    
    # Write the updated content back
    with open(file_path, 'w') as file:
        file.write(content)
    
    print(f"Updated {file_path}")

def main():
    parser = argparse.ArgumentParser(description='Update DAG files for Cloud Composer')
    parser.add_argument('--dags-dir', required=True, help='Directory containing DAG files')
    parser.add_argument('--project-id', required=True, help='GCP Project ID')
    parser.add_argument('--gcs-bucket', required=True, help='GCS Bucket for Cloud Composer')
    
    args = parser.parse_args()
    
    # Get all Python files in the DAGs directory
    dag_files = glob.glob(os.path.join(args.dags_dir, '*.py'))
    
    for file_path in dag_files:
        update_file(file_path, args.project_id, args.gcs_bucket)
    
    print(f"Updated {len(dag_files)} DAG files.")

if __name__ == '__main__':
    main()