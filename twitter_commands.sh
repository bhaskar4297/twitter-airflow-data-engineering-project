#!/bin/bash
# Twitter ETL Airflow Project Setup Script
# Run on fresh Ubuntu EC2 instance

# -----------------------------
# 1. System update & Python setup
# -----------------------------
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt install -y python3-pip python3-venv

# -----------------------------
# 2. Create & activate Airflow venv
# -----------------------------
python3 -m venv ~/airflow-venv
source ~/airflow-venv/bin/activate

# -----------------------------
# 3. Install dependencies
# -----------------------------
# Upgrade pip, setuptools, wheel
python -m pip install --upgrade pip setuptools wheel

# Install Airflow (specify version for stability)
export AIRFLOW_VERSION=2.9.2
export PYTHON_VERSION="$(python -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')"
export CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"

# Extra Python libraries
pip install pandas tweepy s3fs boto3

# -----------------------------
# 4. Initialize Airflow
# -----------------------------
mkdir -p ~/airflow
cd ~/airflow
airflow db init

# -----------------------------
# 5. Start Airflow (standalone)
# -----------------------------
# Airflow standalone will create an admin user automatically
airflow standalone &

# -----------------------------
# 6. Setup project DAG folder
# -----------------------------
mkdir -p ~/airflow/twitter_dag
cd ~/airflow/twitter_dag

# Copy DAG + ETL Python files into this folder
# twitter_dag.py   (your Airflow DAG)
# twitter_etl.py   (your ETL script)

# -----------------------------
# 7. Set Airflow variable for Twitter Bearer Token
# -----------------------------
# (replace with your real token or keep empty if not testing API)
# airflow variables set TW_BEARER_TOKEN "YOUR_TWITTER_BEARER_TOKEN"
