#!/bin/bash

# variables
PRE_SIGNED_EXPIRES='6000' # 100 min
VERSION='latest'
IMAGE_NAME='repo-1'
ACCOUNT_ID=`aws sts get-caller-identity --query "Account" --output text`

# echo color
RED='\033[0;31m'
GREEN='\033[0;32m'
DEFAULT='\033[0;0m'

if [ "$1" = "build" ]; then
    # get latest debian
    latest_export_debian=`aws s3 ls s3://destination/ --output text --query "Contents[].{Key: Key}" | sort | tail -n 1 | awk '{print $4}'`
    echo -e "${GREEN} latest export debian : ${latest_export_debian}"

    # get pre signed url
    echo -e "${DEFAULT} getting presigned url for ${PRE_SIGNED_EXPIRES} seconds ..."
    pre_signed=`aws s3 presign s3://destination/${latest_export_debian} --expires-in ${PRE_SIGNED_EXPIRES}`
    echo -e "${GREEN} done ..."

    # downloading latest debian
    echo -e "${DEFAULT} downloading ${latest_export_debian}"
    curl ${pre_signed} -o ../../repo-1/repo-1.deb
    echo -e "${GREEN} done ..."

    # building docker image
    echo -e "${DEFAULT} building docker image"
    DOCKER_BUILDKIT=1 docker build --network=host -t ${IMAGE_NAME}:${VERSION} ../../repo-1/
    echo -e "${GREEN} done ..."

    # delete download file
    echo -e "${DEFAULT} deleting ../../repo-1/repo-1.deb"
    rm ../../repo-1/repo-1.deb
    echo -e "${GREEN} done ...${DEFAULT}"
elif [ "$1" = "build-nocache" ]; then
    # get latest debian
    latest_export_debian=`aws s3 ls s3://destination/ --output text --query "Contents[].{Key: Key}" | sort | tail -n 1 | awk '{print $4}'`
    echo -e "${GREEN} latest export debian : ${latest_export_debian}"

    # get pre signed url
    echo -e "${DEFAULT} getting presigned url for ${PRE_SIGNED_EXPIRES} seconds ..."
    pre_signed=`aws s3 presign s3://destination/${latest_export_debian} --expires-in ${PRE_SIGNED_EXPIRES}`
    echo -e "${GREEN} done ..."

    # downloading latest debian
    echo -e "${DEFAULT} downloading ${latest_export_debian}"
    curl ${pre_signed} -o ../../repo-1/repo-1.deb
    echo -e "${GREEN} done ..."

    # building docker image
    echo -e "${DEFAULT} building docker image"
    DOCKER_BUILDKIT=1 docker build --network=host -t ${IMAGE_NAME}:${VERSION} ../../repo-1/ --no-cache
    echo -e "${GREEN} done ..."

    # delete download file
    echo -e "${DEFAULT} deleting ../../repo-1/repo-1.deb"
    rm ../../repo-1/repo-1.deb
    echo -e "${GREEN} done ...${DEFAULT}"
elif [ "$1" = "upload" ]; then
    # login to aws ECR
    echo -e "${DEFAULT} logging in to AWS ECR"
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
    echo -e "${GREEN} done ..."

    # tag image
    echo -e "${DEFAULT} tagging image ..."
    docker tag ${IMAGE_NAME}:${VERSION} ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecr-dev/${IMAGE_NAME}:${VERSION}
    echo -e "${GREEN} done ..."

    # ECR image Update strategy:
    # 1. Get the last numerical version number before LATEST
    # 2. Retag numerical version number to current LATEST
    # 3. Push the new image to ECR (ECR auto update LATEST tag)
    # Get current pipeline execution id from cli

    # 1. Get the last numerical version number before LATEST
    LAST_VERSION=`aws ecr describe-images --repository-name ecr-dev/${IMAGE_NAME} --region us-east-1 --query 'imageDetails[].[imageTags[]]' --output text | sort -V | tail -n 2`
    LAST_VERSION=$(echo "$LAST_VERSION" | awk 'NR==1')

    # if ECR repo contains only one image version
    if [[ $LAST_VERSION =~ [[:space:]] ]]; then
        # 3. Push the new image to ECR (ECR auto update LATEST tag)
        echo "Last Version is: 0.1"
        echo -e "${DEFAULT} push image to ECR ..."
        docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecr-dev/${IMAGE_NAME}:${VERSION}
        echo -e "${GREEN} done ..."
        echo -e "${DEFAULT}"
    else
        MAJOR_NUM="${LAST_VERSION%%.*}"
        VERSION_NUM="${LAST_VERSION#*.}"
        ((VERSION_NUM++))
        LAST_VERSION="${MAJOR_NUM}.${VERSION_NUM}"
        echo "Last Version is:${LAST_VERSION}"

        # 2. Retag numerical version number to current LATEST
        echo -e "${DEFAULT} retagging latest image on ECR"
        MANIFEST=$(aws ecr batch-get-image --region us-east-1 --repository-name ecr-dev/${IMAGE_NAME} --image-ids imageTag=latest --output text --query images[].imageManifest)
        aws ecr put-image --region us-east-1 --repository-name ecr-dev/${IMAGE_NAME} --image-tag ${LAST_VERSION} --image-manifest "$MANIFEST" > /null
        echo -e "${GREEN} done ..."

        # 3. Push the new image to ECR (ECR auto update LATEST tag)
        echo -e "${DEFAULT} push image to ECR ..."
        docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecr-dev/${IMAGE_NAME}:${VERSION}
        echo -e "${GREEN} done ..."
        echo -e "${DEFAULT}"
    fi
else
    # login to aws ECR
    echo -e "${DEFAULT} logging in to AWS ECR"
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
    echo -e "${GREEN} done ..."

    # get latest debian
    latest_export_debian=`aws s3 ls s3://destination/ --output text --query "Contents[].{Key: Key}" | sort | tail -n 1 | awk '{print $4}'`
    echo -e "${GREEN} latest export debian : ${latest_export_debian}"

    # get pre signed url
    echo -e "${DEFAULT} getting presigned url for ${PRE_SIGNED_EXPIRES} seconds ..."
    pre_signed=`aws s3 presign s3://destination/${latest_export_debian} --expires-in ${PRE_SIGNED_EXPIRES}`
    echo -e "${GREEN} done ..."

    # downloading latest debian
    echo -e "${DEFAULT} downloading ${latest_export_debian}"
    curl ${pre_signed} -o ../../repo-1/repo-1.deb
    echo -e "${GREEN} done ..."

    # building docker image
    echo -e "${DEFAULT} building docker image"
    DOCKER_BUILDKIT=1 docker build --network=host -t ${IMAGE_NAME}:${VERSION} ../../repo-1/
    echo -e "${GREEN} done ..."

    # delete download file
    echo -e "${DEFAULT} deleting ../../repo-1/repo-1.deb"
    rm ../../repo-1/repo-1.deb
    echo -e "${GREEN} done ..."

    # tag image
    echo -e "${DEFAULT} tagging image ..."
    docker tag ${IMAGE_NAME}:${VERSION} ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecr-dev/${IMAGE_NAME}:${VERSION}
    echo -e "${GREEN} done ..."

    # ECR image Update strategy:
    # 1. Get the last numerical version number before LATEST
    # 2. Retag numerical version number to current LATEST
    # 3. Push the new image to ECR (ECR auto update LATEST tag)
    # Get current pipeline execution id from cli

    # 1. Get the last numerical version number before LATEST
    LAST_VERSION=`aws ecr describe-images --repository-name ecr-dev/${IMAGE_NAME} --region us-east-1 --query 'imageDetails[].[imageTags[]]' --output text | sort -V | tail -n 2`
    LAST_VERSION=$(echo "$LAST_VERSION" | awk 'NR==1')

    # if ECR repo contains only one image version
    if [[ $LAST_VERSION =~ [[:space:]] ]]; then
        # 3. Push the new image to ECR (ECR auto update LATEST tag)
        echo "Last Version is: 0.1"
        echo -e "${DEFAULT} push image to ECR ..."
        docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecr-dev/${IMAGE_NAME}:${VERSION}
        echo -e "${GREEN} done ..."
        echo -e "${DEFAULT}"
    else
        MAJOR_NUM="${LAST_VERSION%%.*}"
        VERSION_NUM="${LAST_VERSION#*.}"
        ((VERSION_NUM++))
        LAST_VERSION="${MAJOR_NUM}.${VERSION_NUM}"
        echo "Last Version is:${LAST_VERSION}"

        # 2. Retag numerical version number to current LATEST
        echo -e "${DEFAULT} retagging latest image on ECR"
        MANIFEST=$(aws ecr batch-get-image --region us-east-1 --repository-name ecr-dev/${IMAGE_NAME} --image-ids imageTag=latest --output text --query images[].imageManifest)
        aws ecr put-image --region us-east-1 --repository-name ecr-dev/${IMAGE_NAME} --image-tag ${LAST_VERSION} --image-manifest "$MANIFEST" > /null
        echo -e "${GREEN} done ..."

        # 3. Push the new image to ECR (ECR auto update LATEST tag)
        echo -e "${DEFAULT} push image to ECR ..."
        docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecr-dev/${IMAGE_NAME}:${VERSION}
        echo -e "${GREEN} done ..."
        echo -e "${DEFAULT}"
    fi
fi
