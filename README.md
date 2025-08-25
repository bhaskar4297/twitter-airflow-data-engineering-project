Twitter ETL Pipeline with Apache Airflow & AWS

Goal: Extract tweets from X (Twitter) API v2, transform with Pandas, and store CSVs in Amazon S3, all orchestrated by Apache Airflow on an EC2 instance.

✨ What this shows

Orchestrating a daily ETL in Airflow (DAGs, retries, logs)

Using Tweepy (X API v2) for extraction

Transforming raw JSON → tidy table with Pandas

Uploading to S3 with boto3 (IAM role, no AWS keys in code)

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
import os
import tweepy
import pandas as pd
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

def run_twitter_etl():
    """
    Extract tweets via X API v2, transform with Pandas,
    save CSV locally, then upload to S3.
    """

    # Get bearer token at runtime (Airflow Variable or env var)
    bearer_token = os.getenv("TW_BEARER_TOKEN") or os.getenv("AIRFLOW_VAR_TW_BEARER_TOKEN")
    if not bearer_token:
        raise ValueError("Twitter Bearer Token not found. Set Airflow Variable 'TW_BEARER_TOKEN' or env var TW_BEARER_TOKEN")

    client = tweepy.Client(bearer_token=bearer_token, wait_on_rate_limit=True)

    username = os.getenv("TW_USERNAME", "wtfruchss")  # no '@'
    user = client.get_user(username=username)
    user_id = user.data.id

    tweets = tweepy.Paginator(
        client.get_users_tweets,
        id=user_id,
        exclude=["retweets", "replies"],
        tweet_fields=["created_at", "public_metrics"],
        max_results=40,
    ).flatten(limit=50)

    rows = []
    for t in tweets:
        m = t.public_metrics or {}
        rows.append({
            "user": username,
            "text": t.text,
            "favorite_count": m.get("like_count"),
            "retweet_count": m.get("retweet_count"),
            "created_at": t.created_at,
        })

    df = pd.DataFrame(rows)

    # Save locally
    ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    local_path = f"/home/ubuntu/airflow/twitter_dag/refined_tweets_{ts}.csv"
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    df.to_csv(local_path, index=False)

    # Upload to S3 (IAM role)
    bucket = os.getenv("S3_BUCKET", "<YOUR_BUCKET>")
    key = f"refined_tweets_{ts}.csv"

    s3 = boto3.client("s3")
    try:
        s3.upload_file(local_path, bucket, key)
        print(f"Uploaded to s3://{bucket}/{key}")
    except ClientError as e:
        raise RuntimeError(f"S3 upload failed: {e}") from e


This file does not contain secrets. It reads the bearer token from Airflow Variable or env var.

4.2 dags/twitter_dag.py
# dags/twitter_dag.py
from datetime import timedelta, datetime
from airflow import DAG
from airflow.operators.python import PythonOperator
from twitter_etl import run_twitter_etl

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": datetime(2024, 1, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="twitter_dag",
    default_args=default_args,
    description="Daily Twitter ETL to S3",
    schedule=timedelta(days=1),
    catchup=False,
    tags=["twitter", "etl"],
) as dag:
    run_etl = PythonOperator(
        task_id="complete_twitter_etl",
        python_callable=run_twitter_etl,
        # execution_timeout=timedelta(minutes=30),  # optional
    )

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

# .gitignore
__pycache__/
*.pyc
.venv/
airflow-venv/
logs/
env/
.env
.airflowenv
*.pem
*.key
*.json

📄 requirements.txt
apache-airflow==2.9.2
tweepy==4.14.0
pandas==2.2.2
boto3==1.34.0
s3fs==2023.12.2
