#!/bin/bash

# Define ECR image transfer options
echo "Please select the transfer type by entering option number:"
options_type=("dev-to-test" "test-to-prod")
# Prompt the user to select a transfer type
select type in "${options_type[@]}"; do
    case $type in
        "dev-to-test")
            chosen_option_src="dev"
            chosen_option_des="test"
            chosen_option_type="dev-to-test"
            break
            ;;
        "test-to-prod")
            chosen_option_src="test"
            chosen_option_des="prod"
            chosen_option_type="test-to-prod"
            break
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done

# Define the ECR repo options
echo "Please select the ECR image you want to transfer by entering option number:"
options_image=("repo-1" "repo-2")
# Prompt the user to select an ECR repo
select image in "${options_image[@]}"; do
    case $image in
        "repo-1")
            chosen_option_image="repo-1"
            break
            ;;
        "repo-2")
            chosen_option_image="repo-2"
            break
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done

# Confirm transfer options
echo "Chosen transfer type: $chosen_option_type"
echo "Chosen ECR image: $chosen_option_image"
read -p "Confirm image transfer from ecr-${chosen_option_src}/${chosen_option_image}:latest to ecr-${chosen_option_des}/${chosen_option_image}:latest ? (y/n): " confirmation

# Pushing ECR image to TEST/PROD repo
# ECR image Update strategy:
# 1. Get the last numerical version number before LATEST in destination ECR repository
# 2. Retag numerical version number to current LATEST in destination ECR repository
# 3. Push the new image from source to destination (ECR auto update LATEST tag)
if [ "$confirmation" == "y" ]; then
  # Login to aws ECR
  echo "logging in to AWS ECR"
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin aws-account.dkr.ecr.us-east-1.amazonaws.com
  echo "done ..."
  # 1. Get the last numerical version number before LATEST
  LAST_VERSION=`aws ecr describe-images --repository-name "ecr-${chosen_option_des}/${chosen_option_image}" --region us-east-1 --query 'imageDetails[].[imageTags[]]' --output text | sort -V | tail -n 2`
  LAST_VERSION=$(echo "$LAST_VERSION" | awk 'NR==1')

  if [[ $LAST_VERSION =~ [[:space:]] ]]; then
    # 3. Push the new image to ECR (ECR auto update LATEST tag)
    echo "LAST_VERSION:0.1"
    docker pull aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_src}/${chosen_option_image}
    docker tag aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_src}/${chosen_option_image} aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_des}/${chosen_option_image}
    docker push aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_des}/${chosen_option_image}
  else
    MAJOR_NUM="${LAST_VERSION%%.*}"
    VERSION_NUM="${LAST_VERSION#*.}"
    ((VERSION_NUM++))
    LAST_VERSION="${MAJOR_NUM}.${VERSION_NUM}"
    echo "LAST_VERSION:${LAST_VERSION}"
    # 2. Retag numerical version number to current LATEST
    echo "retagging latest image on ECR"
    MANIFEST=$(aws ecr batch-get-image --region us-east-1 --repository-name "ecr-${chosen_option_des}/${chosen_option_image}" --image-ids imageTag=latest --output text --query images[].imageManifest)
    aws ecr put-image --region us-east-1 --repository-name "ecr-${chosen_option_des}/${chosen_option_image}" --image-tag ${LAST_VERSION} --image-manifest "$MANIFEST"
    echo "done ..."
    # 3. Push the new image to ECR (ECR auto update LATEST tag)
    docker pull aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_src}/${chosen_option_image}
    docker tag aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_src}/${chosen_option_image} aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_des}/${chosen_option_image}
    docker push aws-account.dkr.ecr.us-east-1.amazonaws.com/ecr-${chosen_option_des}/${chosen_option_image}
  fi
else
  echo "transfer canceled"
fi

