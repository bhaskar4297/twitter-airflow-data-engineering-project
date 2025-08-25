import os
import tweepy
import pandas as pd
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

def run_twitter_etl():
    # Read from env if set, otherwise fall back to the string you put here
    bearer_token = os.getenv(
        "TW_BEARER_TOKEN",
        "your tocken",
    )

    # Wait is fine (you said you’re OK with ~15 min sleeps)
    client = tweepy.Client(bearer_token=bearer_token, wait_on_rate_limit=True)

    username = "wtfruchss"  # no @
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

    # ---- save locally then upload via boto3 ----
    ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    local_path = f"Path"
    df.to_csv(local_path, index=False)

    bucket = "bhaskar-airflow-bucket"
    key = f"refined_tweets_{ts}.csv"

    s3 = boto3.client("s3")  # uses your EC2 IAM role automatically
    try:
        s3.upload_file(local_path, bucket, key)
        print(f"Uploaded to s3://{bucket}/{key}")
    except ClientError as e:
        # Let Airflow show a clear error if upload fails
        raise RuntimeError(f"S3 upload failed: {e}") from e


if __name__ == "__main__":
    run_twitter_etl()
