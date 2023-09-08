import boto3
import uuid
import json
import re
import os
from datetime import datetime, timezone, timedelta

def lambda_handler(event, context):
    # Get target ecr repo from EventBridge rule
    repository_name = event['ecr_repo']
    region = "us-east-1"
    # Extract version components
    def version_key(tag):
        version_parts = re.findall(r'\d+', tag)
        return [int(part) for part in version_parts]
    
    # Ensure no execution running, one task at a time
    try:
        codepipeline = boto3.client('codepipeline')
        response = codepipeline.list_pipeline_executions(
            pipelineName=os.environ['CODEPIPELINE_NAME'],
            maxResults=10
        )
        in_progress_executions = [
            execution['pipelineExecutionId'] for execution in response['pipelineExecutionSummaries']
            if execution['status'] == 'InProgress'
        ]
        if len(in_progress_executions) != 0:
            raise ValueError('rollback lambda function failed because pipeline is still running')
    except ValueError as ve:
        print(f"pipeline error: {ve}")
        return {
            'status': "FAILED",
            'error': str(ve)
        }
    
    # Rollback production ECR repo
    # ECR image Rollback strategy:
    # 1. Get the last numerical version number before LATEST
    # 2. Delete the current LATEST version on ECR
    # 3. Retag LATEST to the last numerical version
    # 4. Delete the numerical version number and solely retain the LATEST tag
    try:
        # Create a Boto3 ECR client
        ecr_client = boto3.client("ecr", region_name=region)
        # 1. Get the last numerical version number before LATEST
        response_describe = ecr_client.describe_images(repositoryName=repository_name)
        image_tags = [tag for image in response_describe["imageDetails"] for tag in image.get("imageTags", [])]
        # Sort the image tags based on version components
        sorted_image_tags = sorted(image_tags, key=version_key)
        LAST_VERSION = sorted_image_tags[len(sorted_image_tags)-1]
        # Get rollback target version
        response_get = ecr_client.batch_get_image(
            repositoryName=repository_name,
            imageIds=[
                {
                    'imageTag': LAST_VERSION
                }
            ]
        )
        print(f"Rollback to image version: {LAST_VERSION}")
        # 2. Delete the current LATEST version on ECR
        response_delete = ecr_client.batch_delete_image(
            repositoryName=repository_name,
            imageIds=[
                {
                    'imageTag': 'latest'
                },
            ]
        )
        # 3. Retag LATEST to the last numerical version
        response_put = ecr_client.put_image(
            repositoryName=repository_name,
            imageManifest=response_get['images'][0]['imageManifest'],
            imageTag='latest',
        )
        # 4. Delete the numerical version number and solely retain the LATEST tag
        response = ecr_client.batch_delete_image(
            repositoryName=repository_name,
            imageIds=[
                {
                    'imageTag': LAST_VERSION
                },
            ]
        )
    except Exception as e:
        print(f"Rollback Error: {e}")
        return {
            'status': "FAILED",
            'error': str(e)
        }
    
    # Write rollback logs to dynamodb record table
    try:
        client = boto3.client('dynamodb')
        tz = timezone(timedelta(hours=+8))
        now=datetime.now(tz).isoformat(timespec="seconds")
        before_major, before_minor = LAST_VERSION.split(".")
        before_minor = str(int(before_minor) + 1)
        version_before = f"{before_major}.{before_minor}"
        print(f"Rollback from v{version_before} to v{LAST_VERSION}")
        response_db = client.put_item(
            TableName=os.environ['DYNAMODB_TABLE_NAME'],
            Item={
                'execution_id':{
                    'S': "rollback_" + str(uuid.uuid4())
                },
                'ecr_repo':{
                    'S': repository_name
                },
                'date':{
                    'S': now
                },
                'action':{
                    'S': "rollback"
                },
                'version_before':{
                    'S': version_before
                },
                'version_after':{
                    'S': f"{LAST_VERSION} (latest)"
                },
            }
        )
        print('Rollback completed')
    except Exception as e:
        print(f"DynamoDB Error: {e}")
        return {
            'status': "FAILED",
            'error': str(e)
        }