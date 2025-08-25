# twitter-airflow-data-engineering-project
Goal: Extract tweets from X (Twitter) API v2, transform with Pandas, and store CSVs in Amazon S3, all orchestrated by Apache Airflow on an EC2 instance.

What this shows

-Orchestrating a daily ETL in Airflow (DAGs, retries, logs)

-Using Tweepy (X API v2) for extraction

-Transforming raw JSON → tidy table with Pandas

-Uploading to S3 with boto3 (IAM role, no AWS keys in code)
