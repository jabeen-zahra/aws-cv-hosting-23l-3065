#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <bucket-name> <ec2-address> <lambda-address>"
  exit 1
fi

BUCKET=$1
EC2_ADDR=$2
LAMBDA_ADDR=$3
OUT="evidence.txt"

> "$OUT"

echo "== caller ==" >> "$OUT"
aws sts get-caller-identity >> "$OUT" 2>&1

echo "== public-access ==" >> "$OUT"
aws s3api get-public-access-block --bucket "$BUCKET" >> "$OUT" 2>&1

echo "== versioning ==" >> "$OUT"
aws s3api get-bucket-versioning --bucket "$BUCKET" >> "$OUT" 2>&1

echo "== objects ==" >> "$OUT"
aws s3 ls "s3://$BUCKET/site/" >> "$OUT" 2>&1

echo "== ec2-policy ==" >> "$OUT"
aws iam get-role-policy --role-name cv-ec2-role-23l-3065 --policy-name cv-ec2-s3-access >> "$OUT" 2>&1

echo "== lambda-policy ==" >> "$OUT"
aws iam list-attached-role-policies --role-name cv-lambda-role-23l-3065 >> "$OUT" 2>&1
aws iam get-role-policy --role-name cv-lambda-role-23l-3065 --policy-name cv-lambda-s3-access >> "$OUT" 2>&1

echo "== security-group ==" >> "$OUT"
aws ec2 describe-security-groups --group-ids sg-0846ff62992c08334 >> "$OUT" 2>&1

echo "== instance ==" >> "$OUT"
aws ec2 describe-instances --instance-ids i-0a97fa0d04bc8130e --query "Reservations[0].Instances[0].{Type:InstanceType,IMDS:MetadataOptions.HttpTokens,Profile:IamInstanceProfile.Arn}" >> "$OUT" 2>&1

echo "== endpoints ==" >> "$OUT"
echo "--- EC2 ---" >> "$OUT"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\nContent-Type: %{content_type}\n" "http://$EC2_ADDR/" >> "$OUT" 2>&1
echo "--- Lambda ---" >> "$OUT"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\nContent-Type: %{content_type}\n" "https://$LAMBDA_ADDR/" >> "$OUT" 2>&1
echo "--- Direct S3 (should be denied) ---" >> "$OUT"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "https://$BUCKET.s3.ap-southeast-2.amazonaws.com/site/index.html" >> "$OUT" 2>&1

echo "== lambda-logs ==" >> "$OUT"
aws logs tail /aws/lambda/cv-func-23l-3065 --since 10m --region ap-southeast-2 >> "$OUT" 2>&1

echo "== log-retention ==" >> "$OUT"
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/cv-func-23l-3065 --region ap-southeast-2 >> "$OUT" 2>&1

echo "DONE"