# #!/bin/bash

# IMAGE_NAME=''
# ECR_ENV=''

# login to aws ECR
echo "logging in to AWS ECR"
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin aws-account.dkr.ecr.us-east-1.amazonaws.com
echo " done ..."

#1. Delete batch image by specifying image tag or digest
# aws ecr batch-delete-image \
#   --region us-east-1 \
#   --repository-name ecr-${ECR_ENV}/${IMAGE_NAME} \
#   --image-ids imageTag=0.2

#2. Retag image by specifying image tag or digest
# MANIFEST=$(aws ecr batch-get-image --region us-east-1 --repository-name ecr-${ECR_ENV}/${IMAGE_NAME} --image-ids imageDigest=sha256:@@@ --output text --query images[].imageManifest)
# aws ecr put-image --region us-east-1 --repository-name ecr-${ECR_ENV}/${IMAGE_NAME} --image-tag 0.2 --image-manifest "$MANIFEST" > /null
# echo "done ..."

