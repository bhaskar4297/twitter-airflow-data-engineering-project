# twitter-airflow-data-engineering-project
Twitter ETL Pipeline with Apache Airflow & AWS

Goal: Extract tweets from X (Twitter) API v2, transform with Pandas, and store CSVs in Amazon S3, all orchestrated by Apache Airflow on an EC2 instance.

What this shows

-Orchestrating a daily ETL in Airflow (DAGs, retries, logs)
-Using Tweepy (X API v2) for extraction
-Transforming raw JSON → tidy table with Pandas
-Uploading to S3 with boto3 (IAM role, no AWS keys in code)

1) Tech stack

Python · Apache Airflow · Tweepy · Pandas · Boto3 · AWS EC2 · AWS S3 (IAM role)

2) Architecture

Extract: Tweepy Client pulls recent tweets for a handle (no RTs/replies).

Transform: Select columns (text, created_at, likes, retweets, user).

Load: Save CSV locally, then upload to S3 with boto3.

Orchestrate: Airflow DAG runs daily; logs + retries visible in UI.

3) Setup
3.1 EC2 + venv (recommended)
# Ubuntu
sudo apt update
sudo apt install -y python3-venv

# create & activate venv
python3 -m venv ~/airflow-venv
source ~/airflow-venv/bin/activate
python -m pip install --upgrade pip setuptools wheel

3.2 Install Airflow (with constraints)
export AIRFLOW_VERSION=2.9.2
export PYTHON_VERSION=$(python -c 'import sys;print(".".join(map(str, sys.version_info[:2])))')
export CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"

3.3 Install project deps
pip install -r requirements.txt

3.4 Airflow home & init
export AIRFLOW_HOME=~/airflow
airflow db init
airflow users create --username admin --firstname Admin --lastname User --role Admin --email admin@example.com --password admin

3.5 S3 permissions

Attach an IAM Role to the EC2 instance with at least:

{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect":"Allow","Action":["s3:PutObject","s3:ListBucket"],
     "Resource":["arn:aws:s3:::<YOUR_BUCKET>","arn:aws:s3:::<YOUR_BUCKET>/*"]}
  ]
}


No AWS keys in code—boto3 will use this role automatically.

4) Project files
4.1 dags/twitter_etl.py (no secrets in code)
# dags/twitter_etl.py

This file does not contain secrets. It reads the bearer token from Airflow Variable or env var.

4.2 dags/twitter_dag.py
# dags/twitter_dag.py

5) Configure secrets (no tokens in Git)

Pick ONE of the following:

A) Airflow Variable (recommended)
# inside your venv or not
airflow variables set TW_BEARER_TOKEN 'YOUR_REAL_TOKEN'
# optional: set username/bucket as variables or env vars
airflow variables set S3_BUCKET 'your-bucket-name'
airflow variables set TW_USERNAME 'wtfruchss'

Airflow automatically exposes Variables to code as env vars AIRFLOW_VAR_<KEY>.

B) Environment variables
export TW_BEARER_TOKEN='YOUR_REAL_TOKEN'
export S3_BUCKET='your-bucket-name'
export TW_USERNAME='wtfruchss'

Never commit tokens; they live only in Airflow Variables or env vars.

6) Put files where Airflow can see them

This project assumes Airflow is set to watch ~/airflow/twitter_dag:

export AIRFLOW_HOME=~/airflow
mkdir -p ~/airflow/twitter_dag
cp -r dags/* ~/airflow/twitter_dag/


(Alternatively, set dags_folder to your repo’s dags/.)

7) Run Airflow services

Two terminals, both inside your venv:

Terminal 1 (webserver)

source ~/airflow-venv/bin/activate
export AIRFLOW_HOME=~/airflow
airflow webserver -p 8080


Terminal 2 (scheduler)

source ~/airflow-venv/bin/activate
export AIRFLOW_HOME=~/airflow
airflow scheduler


Open the UI: http://<EC2-Public-IP>:8080 → Toggle twitter_dag → Trigger DAG → Check Logs.

8) Output

Local: ~/airflow/twitter_dag/refined_tweets_<timestamp>.csv

S3: s3://<YOUR_BUCKET>/refined_tweets_<timestamp>.csv

9) Troubleshooting

Task stuck in queued → scheduler not running in same venv; restart it.

Empty UI logs → confirm AIRFLOW_HOME matches in both terminals; check ~/airflow/logs.

Rate limit waits → Tweepy will sleep if wait_on_rate_limit=True; increase execution_timeout if needed.

S3 AccessDenied → verify EC2 IAM role allows s3:PutObject to your bucket.

DAG not visible → ensure files sit under the configured dags_folder and Airflow owns/reads them.

10) Security

No secrets in code or repo.

Use Airflow Variables or env vars for the bearer token.

Prefer IAM role for S3 access (already used here).

Add these to .gitignore:
