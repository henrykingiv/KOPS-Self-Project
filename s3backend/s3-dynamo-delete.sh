#!/bin/bash

# Set your bucket, dynamodb name and region
bucket_name="kops-socks-shop"
region="eu-west-2"
dynamodb_name="kops-socks-table"

#Delete S3 Bucket
aws s3 rb s3://$bucket_name --force

# Check if the bucket deletion was successful
if [ $? -eq 0 ]; then
  echo "S3 bucket $bucket_name deleted successfully."
else
  echo "Failed to create S3 bucket $bucket_name"
fi

#Delete dynamodb table
aws dynamodb delete-table --table-name $dynamodb_name --region $region

if [ $? -eq 0 ]; then
  echo "Dynamodb $dynamodb_name deleted successfully."
else
  echo "Failed to delete dynamodb $dynamodb_name"
fi