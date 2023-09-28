#!/bin/bash

# Define ECR environment options
echo "Please select the ECR environment you want to rollback by entering option number:"
options_env=("ecr-dev" "ecr-test" "ecr-prod")

# Prompt the user to select an ECR environment
select env in "${options_env[@]}"; do
    case $env in
        "ecr-dev")
            chosen_option_env="dev"
            break
            ;;
        "ecr-test")
            chosen_option_env="test"
            break
            ;;
        "ecr-prod")
            chosen_option_env="prod"
            break
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done

# Define the ECR repo options
echo "Please select the ECR image you want to rollback by entering option number:"
options=("repo-1" "repo-2")

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

echo "Chosen ECR environment: $chosen_option_env"
echo "Chosen ECR image: $chosen_option_image"
chosen_option="ecr-${chosen_option_env}/${chosen_option_image}"

# Ask for rollback confirmation
read -p "Confirm rollback in ${chosen_option}? (y/n): " confirmation
if [ "$confirmation" == "y" ]; then
    echo "Rollback confirmed, start processing."
    aws lambda invoke \
        --function-name image-cicd-rollback-function \
        --cli-binary-format raw-in-base64-out \
        --payload '{ "ecr_repo": "'"$chosen_option"'" }' \
        --invocation-type RequestResponse \
        --region us-east-1 \
        out \
        --log-type Tail \
        --query 'LogResult' \
        --output text | base64 -d
else
    echo "Rollback cancelled"
fi