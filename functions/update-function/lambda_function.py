import boto3
import uuid
import re
import os
from datetime import datetime, timezone, timedelta

def lambda_handler(event, context):
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
            raise ValueError('update lambda function failed because pipeline is still running')
    except ValueError as ve:
        print(f"Pipeline Error: {ve}")
        return {
            'status': "FAILED",
            'error': str(ve)
        }
    
    try:
        # Get the last numerical version number before LATEST
        ecr_client = boto3.client("ecr")
        ecr_repository = event['detail']['repository-name']
        response_describe = ecr_client.describe_images(repositoryName=ecr_repository)
        image_tags = [tag for image in response_describe["imageDetails"] for tag in image.get("imageTags", [])]
        # Sort the image tags based on version components
        sorted_image_tags = sorted(image_tags, key=version_key)
        LAST_VERSION = sorted_image_tags[len(sorted_image_tags)-1]
        before_major, before_minor = LAST_VERSION.split(".")
        before_minor = str(int(before_minor))
        latest_minor = str(int(before_minor) + 1)
        version_before = f"{before_major}.{before_minor}"
        version_latest = f"{before_major}.{latest_minor}"
        print("version_before:" + version_before)
        print("version_after:" + f"{version_latest} (latest)")
        # Start image update pipeline
        codepipeline = boto3.client('codepipeline')
        response_pipeline = codepipeline.start_pipeline_execution(
            name=os.environ['CODEPIPELINE_NAME']
        )
        # Write update logs to dynamodb record table
        client = boto3.client('dynamodb')
        tz = timezone(timedelta(hours=+8))
        now=datetime.now(tz).isoformat(timespec="seconds")
        response_db = client.put_item(
            TableName=os.environ['DYNAMODB_TABLE_NAME'],
            Item={
                'execution_id':{
                    'S': response_pipeline["pipelineExecutionId"]
                },
                'ecr_repo':{
                    'S': ecr_repository
                },
                'date':{
                    'S': now
                },
                'action':{
                    'S': "update"
                },
                'version_before':{
                    'S': version_before
                },
                'version_after':{
                    'S': f"{version_latest} (latest)"
                },
            }
        )
        print(response_db['ResponseMetadata'])
    except Exception as e:
        print(f"Update Error: {e}")
        return {
            'status': "CodePipeline failed",
            'error': str(e)
        }