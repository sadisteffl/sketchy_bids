import boto3
import os
import json

def lambda_handler(event, context):

    print(f"Received event: {json.dumps(event)}")

    ssm_document_name = os.environ['SSM_DOCUMENT_NAME']
    
    try:
        bucket_name = event['detail']['requestParameters']['bucketName']
        
        ssm_client = boto3.client('ssm')
        
        response = ssm_client.start_automation_execution(
            DocumentName=ssm_document_name,
            Parameters={
                'BucketName': [bucket_name]
            }
        )
        
        print(f"Started SSM Automation execution for bucket: {bucket_name}")
        print(f"Execution ID: {response['AutomationExecutionId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(f"Successfully started remediation for bucket: {bucket_name}")
        }
            
    except KeyError as e:
        print(f"Error: Could not extract bucket name from event. Missing key: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps(f"Error processing event: {e}")
        }
    except Exception as e:
        print(f"An error occurred: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"An unexpected error occurred: {e}")
        }