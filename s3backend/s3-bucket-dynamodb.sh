#!/bin/bash

# Set your bucket name and region
bucket_name="kops-socks-shop"
region="eu-west-2"
dynamodb_name="kops-socks-table"

#Create the s3 bucket
aws s3api create-bucket --bucket $bucket_name --region $region --create-bucket-configuration LocationConstraint=$region

# Check if the bucket creation was successful
if [ $? -eq 0 ]; then
  echo "S3 bucket $bucket_name created successfully."
else
  echo "Failed to create S3 bucket $bucket_name."
fi

#Create dynamodb table
aws dynamodb create-table --table-name $dynamodb_name --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=10 --region $region

#Check if table is created successfully
if [ $? -eq 0 ]; then
  echo "dynamodb table $dynamodb_name created successfully."
else
  echo "Failed to create S3 bucket $dynamodb_name."
fi