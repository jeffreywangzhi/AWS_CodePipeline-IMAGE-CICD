#!/bin/bash

# Define the ECR repo options
echo "Please select the ECR repo you want to rollback by entering option number:"
options=("ecr-prod/repo-1" "ecr-prod/repo-2")

# Prompt the user to select an ECR repo
select opt in "${options[@]}"; do
    case $opt in
        "ecr-prod/repo-1")
            chosen_option="ecr-prod/repo-1"
            break
            ;;
        "ecr-prod/repo-2")
            chosen_option="ecr-prod/repo-2"
            break
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done

echo "Chosen option: $chosen_option"

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