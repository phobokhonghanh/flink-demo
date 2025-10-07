import jobs.boto3 as boto3
endpoint = ""
access = ""
secret = ""
s3_client = boto3.client(
    's3',
    endpoint_url=endpoint,
    aws_access_key_id=access,
    aws_secret_access_key=secret
)

# Test connection
try:
    response = s3_client.list_buckets()
    print("S3 connection successful")
except Exception as e:
    print(f"S3 connection failed: {e}")